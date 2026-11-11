-- SelectiveLoot : ramasse tout le butin sauf les objets de la liste d'ignorés.
-- Cible : World of Warcraft: Forever (API moderne, Interface 16001).

local ADDON, ns = ...

BINDING_HEADER_SELECTIVELOOT = "SelectiveLoot"
BINDING_NAME_SELECTIVELOOT_TOGGLE = "Ignorer / ramasser l'objet survolé"
ns.BINDING = "SELECTIVELOOT_TOGGLE"

---------------------------------------------------------------------------
-- Style : couleurs natives du jeu et icônes « appel » (prêt / pas prêt / en attente)
--   vert  = c'est bon       rouge = problème / ignoré
--   jaune = à faire         gris  = info secondaire
---------------------------------------------------------------------------
ns.HEX = {
	green = "ff19ff19",  -- GREEN_FONT_COLOR
	red   = "ffff2020",  -- RED_FONT_COLOR
	gold  = "ffffd100",  -- NORMAL_FONT_COLOR
	white = "ffffffff",  -- HIGHLIGHT_FONT_COLOR
	gray  = "ff9d9d9d",
}
function ns.Color(key, text)
	return "|c" .. ns.HEX[key] .. text .. "|r"
end
ns.ICON = {
	ok   = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
	no   = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t",
	wait = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:0|t",
}
local Color, ICON = ns.Color, ns.ICON

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(Color("gold", "SelectiveLoot") .. " : " .. msg)
end
local Print = ns.Print

---------------------------------------------------------------------------
-- Utilitaires API
---------------------------------------------------------------------------
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local SLOT_ITEM = (Enum.LootSlotType and Enum.LootSlotType.Item) or 1
local QUEST_CLASS = (Enum.ItemClass and Enum.ItemClass.Questitem) or 12

-- Forever applique les « valeurs secrètes » de Midnight : on ne lit jamais une valeur secrète.
function ns.IsSecret(v)
	return type(issecretvalue) == "function" and issecretvalue(v)
end
local IsSecret = ns.IsSecret

local function ItemIDFromLink(link)
	if type(link) ~= "string" or IsSecret(link) then return nil end
	return tonumber(link:match("item:(%d+)"))
end

-- Accepte un lien, un ID ou un nom d'objet déjà en cache.
function ns.ItemIDFromText(text)
	if type(text) ~= "string" or IsSecret(text) then return nil end
	text = strtrim(text)
	if text == "" then return nil end
	local id = ItemIDFromLink(text) or tonumber(text) or GetItemInfoInstant(text)
	if id and GetItemInfoInstant(id) then return id end
end

function ns.WithItemLink(itemID, fn)
	local item = Item:CreateFromItemID(itemID)
	item:ContinueOnItemLoad(function()
		fn(item:GetItemLink() or ("objet #" .. itemID))
	end)
end

local function IsQuestItem(itemID)
	local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
	return classID == QUEST_CLASS
end

function ns.IsGameAutoLootOn()
	return C_CVar.GetCVarBool("autoLootDefault")
end

function ns.DisableGameAutoLoot()
	C_CVar.SetCVar("autoLootDefault", "0")
	ns.Fire("STATUS")
end

---------------------------------------------------------------------------
-- Notifications internes (pour rafraîchir le panneau d'options)
---------------------------------------------------------------------------
local listeners = {}
function ns.On(fn) listeners[#listeners + 1] = fn end
function ns.Fire(what)
	for _, fn in ipairs(listeners) do fn(what) end
end

---------------------------------------------------------------------------
-- Données sauvegardées
---------------------------------------------------------------------------
local DEFAULTS = {
	enabled = true,          -- filtre actif
	corpseInfo = true,       -- « Fouillé » dans l'infobulle des cadavres
	unlootedHint = true,     -- « Pas encore fouillé » dans l'infobulle
	autoConfirmBind = true,  -- confirme les objets liés quand ramassés
}

local function InitDB()
	SelectiveLootDB = SelectiveLootDB or {}
	local db = SelectiveLootDB
	db.ignored = db.ignored or {}
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
	ns.db = db
end

function ns.ResetOptions()
	for k, v in pairs(DEFAULTS) do ns.db[k] = v end
	ns.Fire("OPTIONS")
end

function ns.IsIgnored(itemID)
	return itemID ~= nil and ns.db.ignored[itemID] == true
end

function ns.SetIgnored(itemID, ignored)
	ns.db.ignored[itemID] = ignored and true or nil
	ns.Fire("LIST")
	ns.WithItemLink(itemID, function(link)
		if ignored then
			Print(link .. "  " .. ICON.no .. " " .. Color("red", "ignoré au ramassage"))
		else
			Print(link .. "  " .. ICON.ok .. " " .. Color("green", "ramassé à nouveau"))
		end
	end)
end

function ns.ClearList()
	wipe(ns.db.ignored)
	ns.Fire("LIST")
	Print(Color("green", "liste d'ignorés vidée : tout sera ramassé."))
end

---------------------------------------------------------------------------
-- Cadavres fouillés (mémoire de session)
-- corpses[guid] = nombre d'objets ignorés laissés sur le cadavre
---------------------------------------------------------------------------
local corpses = {}

local function CollectSourceGUIDs(slot, into)
	local info = { GetLootSourceInfo(slot) }
	for i = 1, #info, 2 do
		local guid = info[i]
		if guid and not IsSecret(guid) then
			into[#into + 1] = guid
		end
	end
end

---------------------------------------------------------------------------
-- Ramassage filtré
---------------------------------------------------------------------------
local handled = false  -- la fenêtre de butin actuelle a déjà été traitée
local session          -- { pending = {[slot]=true}, npending, filtered, waitingBind }

local function FinishSession(s, fromTimer)
	if session ~= s then return end
	if fromTimer and s.waitingBind then return end  -- confirmation en cours : on attend le joueur
	session = nil
	if s.filtered > 0 then
		CloseLoot()
	end
end

local function OnLootReady(autoLoot)
	if handled then return end
	handled = true

	local db = ns.db
	local numItems = GetNumLootItems()
	if numItems == 0 then return end

	-- autoLoot = butin auto du jeu ou Maj+clic : le client ramasse déjà tout.
	local filtering = db.enabled and not autoLoot
	local s = { pending = {}, npending = 0, filtered = 0 }
	local sources = {}

	for slot = 1, numItems do
		local guids = {}
		CollectSourceGUIDs(slot, guids)

		local isFiltered = false
		local locked = select(6, GetLootSlotInfo(slot))

		if filtering and not locked then
			if GetLootSlotType(slot) == SLOT_ITEM then
				local itemID = ItemIDFromLink(GetLootSlotLink(slot))
				isFiltered = ns.IsIgnored(itemID) and not IsQuestItem(itemID)
			end
			if isFiltered then
				s.filtered = s.filtered + 1
			else
				s.pending[slot] = true
				s.npending = s.npending + 1
				LootSlot(slot)
			end
		end

		for _, guid in ipairs(guids) do
			sources[guid] = (sources[guid] or 0) + (isFiltered and 1 or 0)
		end
	end

	if db.enabled then
		for guid, remaining in pairs(sources) do
			corpses[guid] = remaining
		end
	end

	if not filtering then return end

	session = s
	if s.npending == 0 then
		C_Timer.After(0, function() FinishSession(s) end)
	else
		-- Filet de sécurité si un objet ne part pas (sacs pleins…)
		C_Timer.After(1.5, function() FinishSession(s, true) end)
	end
end

local function OnLootSlotCleared(slot)
	local s = session
	if s and s.pending[slot] then
		s.pending[slot] = nil
		s.npending = s.npending - 1
		if s.npending <= 0 then
			s.waitingBind = false
			FinishSession(s)
		end
	end
end

local function OnLootBindConfirm(slot)
	local s = session
	if not (s and s.pending[slot]) then return end
	if ns.db.autoConfirmBind then
		ConfirmLootSlot(slot)
		StaticPopup_Hide("LOOT_BIND")
	else
		s.waitingBind = true
	end
end

local function OnLootClosed()
	handled = false
	session = nil
end

---------------------------------------------------------------------------
-- Infobulles
---------------------------------------------------------------------------
local function AddItemLine(tooltip, itemID)
	if not itemID or IsSecret(itemID) or not ns.IsIgnored(itemID) then return end
	if ns.db.enabled then
		tooltip:AddLine(ICON.no .. " " .. Color("red", "Ignoré au ramassage"))
	else
		tooltip:AddLine(ICON.no .. " " .. Color("gray", "Ignoré au ramassage (filtre désactivé)"))
	end
end

local function AddCorpseLine(tooltip, guid)
	if not guid or IsSecret(guid) then return end
	local db = ns.db

	local remaining = corpses[guid]
	if remaining ~= nil then
		if not db.corpseInfo then return end
		local line = ICON.ok .. " " .. Color("green", "Fouillé")
		if remaining > 0 then
			local s = remaining > 1 and "s" or ""
			line = line .. Color("gray", (" — %d objet%s ignoré%s laissé%s"):format(remaining, s, s, s))
		end
		tooltip:AddLine(line)
		return
	end

	if db.unlootedHint and CanLootUnit then
		local hasLoot, canLoot = CanLootUnit(guid)
		if not IsSecret(hasLoot) and not IsSecret(canLoot) and hasLoot and canLoot then
			tooltip:AddLine(ICON.wait .. " " .. Color("gold", "Pas encore fouillé"))
		end
	end
end

local function HookTooltips()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		AddItemLine(tooltip, data and data.id)
	end)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
		if tooltip ~= GameTooltip then return end
		local guid = data and data.guid
		if not guid or IsSecret(guid) then guid = UnitGUID("mouseover") end
		AddCorpseLine(tooltip, guid)
	end)
end

---------------------------------------------------------------------------
-- Raccourci clavier (Bindings.xml)
---------------------------------------------------------------------------
local function GetHoveredItemID()
	if not GameTooltip:IsShown() then return nil end
	local _, link, id = GameTooltip:GetItem()
	if id and not IsSecret(id) then return id end
	return ItemIDFromLink(link)
end

function SelectiveLoot_ToggleHoveredItem()
	if not ns.db then return end
	local itemID = GetHoveredItemID()
	if not itemID then
		Print(ICON.wait .. " " .. Color("gold", "survole d'abord un objet (sac, butin, banque…)."))
		return
	end
	ns.SetIgnored(itemID, not ns.IsIgnored(itemID))
	if GameTooltip.RefreshData then GameTooltip:RefreshData() end
end

---------------------------------------------------------------------------
-- Commandes /sl
---------------------------------------------------------------------------
SLASH_SELECTIVELOOT1 = "/sl"
SLASH_SELECTIVELOOT2 = "/selectiveloot"
SlashCmdList.SELECTIVELOOT = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()

	if cmd == "add" or cmd == "del" then
		local itemID = ns.ItemIDFromText(rest)
		if not itemID then
			Print(ICON.no .. " " .. Color("red", "objet introuvable.") .. " Utilise un lien (Maj+clic) ou un ID.")
			return
		end
		ns.SetIgnored(itemID, cmd == "add")
	elseif cmd == "on" or cmd == "off" then
		ns.db.enabled = (cmd == "on")
		ns.Fire("OPTIONS")
		if ns.db.enabled then
			Print(ICON.ok .. " " .. Color("green", "filtre activé."))
		else
			Print(ICON.no .. " " .. Color("red", "filtre désactivé : tout est ramassé normalement."))
		end
	else
		ns.OpenOptions()
	end
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
	if name ~= ADDON then return end
	InitDB()
	HookTooltips()
	frame:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_LOGIN()
	if ns.db.enabled and ns.IsGameAutoLootOn() then
		Print(ICON.no .. " " .. Color("red", "le butin automatique du jeu est activé : le filtre ne peut pas fonctionner.")
			.. " Tape " .. Color("white", "/sl") .. " pour corriger.")
	end
end

function handlers.ITEM_DATA_LOAD_RESULT() ns.Fire("ITEM") end
function handlers.CVAR_UPDATE() ns.Fire("STATUS") end
function handlers.UPDATE_BINDINGS() ns.Fire("STATUS") end

handlers.LOOT_READY = OnLootReady
handlers.LOOT_SLOT_CLEARED = OnLootSlotCleared
handlers.LOOT_BIND_CONFIRM = OnLootBindConfirm
handlers.LOOT_CLOSED = OnLootClosed

for event in pairs(handlers) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	handlers[event](...)
end)
