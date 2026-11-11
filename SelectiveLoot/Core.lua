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

-- Trace des fouilles dans le chat (/sl debug), pour diagnostiquer en jeu.
local function Debug(msg)
	if ns.db and ns.db.debug then
		DEFAULT_CHAT_FRAME:AddMessage(Color("gray", "[SL debug] " .. msg))
	end
end

-- Texte affichable sans risque, même si le jeu renvoie une valeur secrète.
local function Safe(v)
	if type(issecretvalue) == "function" and issecretvalue(v) then return "(masqué)" end
	return tostring(v)
end

---------------------------------------------------------------------------
-- Utilitaires API
---------------------------------------------------------------------------
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local SLOT_NONE = (Enum.LootSlotType and Enum.LootSlotType.None) or 0
local SLOT_ITEM = (Enum.LootSlotType and Enum.LootSlotType.Item) or 1
local SLOT_MONEY = (Enum.LootSlotType and Enum.LootSlotType.Money) or 2
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
-- Notifications internes (options, affichage du butin)
---------------------------------------------------------------------------
local listeners = {}
function ns.On(fn) listeners[#listeners + 1] = fn end
function ns.Fire(what, ...)
	for _, fn in ipairs(listeners) do fn(what, ...) end
end

---------------------------------------------------------------------------
-- Données sauvegardées
---------------------------------------------------------------------------
local DEFAULTS = {
	enabled = true,          -- filtre actif
	corpseInfo = true,       -- « Fouillé » dans l'infobulle des cadavres
	unlootedHint = true,     -- « Pas encore fouillé » dans l'infobulle
	autoConfirmBind = true,  -- confirme les objets liés quand ramassés
	feed = true,             -- affiche le butin ramassé à l'écran
	feedLeft = true,         -- y affiche aussi les objets ignorés laissés
	feedScale = 1,           -- taille de la liste (1 = 100 %)
	feedTime = 5,            -- secondes avant que les lignes s'effacent
	feedLines = 8,           -- nombre maximum de lignes
	feedFrameAlpha = 1,      -- opacité du cartouche parchemin derrière le nom
}
local FEED_KEYS = { "feed", "feedLeft", "feedScale", "feedTime", "feedLines", "feedFrameAlpha" }

-- Réglages : communs au compte (SelectiveLootDB).
-- Liste d'ignorés : propre à chaque personnage (SelectiveLootCharDB).
local function InitDB()
	SelectiveLootDB = SelectiveLootDB or {}
	SelectiveLootCharDB = SelectiveLootCharDB or {}
	local db, char = SelectiveLootDB, SelectiveLootCharDB

	-- Avant la 1.2.0, la liste était commune au compte : le premier personnage
	-- connecté avec cette version la récupère, puis elle disparaît des réglages communs.
	if not char.ignored and db.ignored then
		char.ignored = db.ignored
	end
	db.ignored = nil
	db.feedPos = nil  -- ancienne clé de position, remplacée par feedAnchor
	db.feedBg = nil   -- ancien fond noir des lignes, remplacé par le cartouche (feedFrameAlpha)
	char.ignored = char.ignored or {}

	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
	ns.db = db
	ns.ignored = char.ignored
end

function ns.ResetOptions()
	for k, v in pairs(DEFAULTS) do ns.db[k] = v end
	ns.db.feedAnchor = nil
	ns.Fire("OPTIONS")
end

-- « Par défaut » sur la page Affichage du butin : seulement ses réglages et la position.
function ns.ResetFeedOptions()
	for _, k in ipairs(FEED_KEYS) do ns.db[k] = DEFAULTS[k] end
	ns.db.feedAnchor = nil
	ns.Fire("OPTIONS")
end

function ns.IsIgnored(itemID)
	return itemID ~= nil and ns.ignored[itemID] == true
end

function ns.SetIgnored(itemID, ignored)
	ns.ignored[itemID] = ignored and true or nil
	ns.Fire("LIST")
	ns.WithItemLink(itemID, function(link)
		if ignored then
			Print(link .. "  " .. ICON.no .. " " .. Color("red", "ignoré au ramassage"))
		else
			Print(link .. "  " .. ICON.ok .. " " .. Color("green", "ramassé à nouveau"))
		end
	end)
end

function ns.IgnoredCount()
	local n = 0
	for _ in pairs(ns.ignored) do n = n + 1 end
	return n
end

function ns.ClearList()
	wipe(ns.ignored)
	ns.Fire("LIST")
	Print(Color("green", "liste d'ignorés vidée : tout sera ramassé."))
end

---------------------------------------------------------------------------
-- Cadavres fouillés (mémoire de session)
-- corpses[guid] = { left = objets ignorés laissés, t = heure de la fouille }
---------------------------------------------------------------------------
local corpses, corpseCount = {}, 0
local CORPSE_MAX, CORPSE_TTL = 400, 600  -- au-delà de 400, on oublie ceux de plus de 10 min

local function RememberCorpse(guid, left, now)
	if not corpses[guid] then corpseCount = corpseCount + 1 end
	corpses[guid] = { left = left, t = now }
	if corpseCount > CORPSE_MAX then
		corpseCount = 0
		for g, c in pairs(corpses) do
			if now - c.t > CORPSE_TTL then
				corpses[g] = nil
			else
				corpseCount = corpseCount + 1
			end
		end
	end
end

local function SourceGUIDs(slot)
	local guids, info = {}, { GetLootSourceInfo(slot) }
	for i = 1, #info, 2 do
		local guid = info[i]
		if guid and not IsSecret(guid) then
			guids[#guids + 1] = guid
		end
	end
	return guids
end

---------------------------------------------------------------------------
-- Ramassage filtré
---------------------------------------------------------------------------
local handled          -- { key, time } : dernière fenêtre de butin traitée
local session          -- { pending = {[slot]=true}, npending, filtered, waitingBind }
local snapshot = {}    -- [slot] = ce que contenait l'emplacement, pour l'affichage du butin

-- Mémorise le contenu d'un emplacement avant qu'il soit ramassé.
local function TakeSnapshot(slot, slotType, link, itemID)
	local texture, name, quantity, _, quality, locked = GetLootSlotInfo(slot)
	if locked or slotType == SLOT_NONE or IsSecret(name) then return nil end
	if IsSecret(quality) then quality = nil end
	if IsSecret(quantity) then quantity = nil end
	if type(name) == "string" then name = name:gsub("\n", " ") end
	return {
		texture = texture,
		name = name,
		quantity = quantity or 1,
		quality = quality,
		link = link,
		itemID = itemID,
		money = slotType == SLOT_MONEY,
	}
end

local function FinishSession(s, fromTimer)
	if session ~= s then return end
	if fromTimer and s.waitingBind then return end  -- confirmation en cours : on attend le joueur
	session = nil
	if s.filtered > 0 then
		Debug("fermeture de la fenêtre (objets ignorés laissés)")
		CloseLoot()
	end
end

local function OnLootReady(autoLoot)
	local db = ns.db
	local numItems = GetNumLootItems()
	if numItems == 0 then
		Debug("LOOT_READY : fenêtre vide, rien à faire")
		return
	end

	-- Sources de chaque emplacement (cadavres, filon…) ; elles identifient aussi la fenêtre.
	local slotGUIDs, seen, parts = {}, {}, {}
	for slot = 1, numItems do
		slotGUIDs[slot] = SourceGUIDs(slot)
		for _, guid in ipairs(slotGUIDs[slot]) do
			if not seen[guid] then
				seen[guid] = true
				parts[#parts + 1] = guid
			end
		end
	end
	table.sort(parts)
	local key, now = table.concat(parts, ","), GetTime()

	-- Le jeu peut signaler la même fenêtre deux fois (LOOT_READY puis LOOT_OPENED) :
	-- on ignore un doublon de la même source pendant 2 s au plus (0,5 s si la source est
	-- inconnue). Ainsi, un LOOT_CLOSED manquant ne peut pas bloquer les fouilles suivantes.
	local window = key == "" and 0.5 or 2
	if handled and handled.key == key and now - handled.time < window then
		Debug("doublon ignoré (même source)")
		return
	end
	handled = { key = key, time = now }

	-- autoLoot = butin auto du jeu ou Maj+clic : le client ramasse déjà tout.
	local filtering = db.enabled and not autoLoot
	Debug(("fouille : %d emplacement(s), butin auto du jeu/Maj = %s, filtre = %s"):format(
		numItems, tostring(autoLoot and true or false), filtering and "oui" or "non"))
	local s = { pending = {}, npending = 0, filtered = 0 }
	local sources = {}
	wipe(snapshot)

	for slot = 1, numItems do
		local isFiltered = false
		local locked = select(6, GetLootSlotInfo(slot))
		local slotType = GetLootSlotType(slot)
		local link = GetLootSlotLink(slot)
		local itemID = slotType == SLOT_ITEM and ItemIDFromLink(link) or nil
		snapshot[slot] = TakeSnapshot(slot, slotType, link, itemID)

		if filtering and not locked then
			if itemID then
				isFiltered = ns.IsIgnored(itemID) and not IsQuestItem(itemID)
			end
			if isFiltered then
				s.filtered = s.filtered + 1
				Debug(("  %d : %s -> laissé"):format(slot, Safe(link or "?")))
				if snapshot[slot] then ns.Fire("LEFT", snapshot[slot]) end
				-- Un objet laissé n'est pas « ramassé » : si un autre joueur le prend,
				-- il ne doit pas apparaître dans l'affichage du butin.
				snapshot[slot] = nil
			else
				s.pending[slot] = true
				s.npending = s.npending + 1
				Debug(("  %d : %s -> ramassé"):format(slot,
					Safe(link or (snapshot[slot] and snapshot[slot].name) or "?")))
				LootSlot(slot)
			end
		elseif locked then
			Debug(("  %d : verrouillé (jet de dés)"):format(slot))
			snapshot[slot] = nil
		end

		for _, guid in ipairs(slotGUIDs[slot]) do
			sources[guid] = (sources[guid] or 0) + (isFiltered and 1 or 0)
		end
	end

	if db.enabled then
		for guid, left in pairs(sources) do
			RememberCorpse(guid, left, now)
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
	local looted = snapshot[slot]
	if looted then
		snapshot[slot] = nil
		ns.Fire("LOOTED", looted)
	end

	local s = session
	if s and s.pending[slot] then
		Debug(("  %d : ramassé, confirmé par le jeu"):format(slot))
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
	Debug("LOOT_CLOSED")
	handled = nil
	session = nil
	wipe(snapshot)
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

	local corpse = corpses[guid]
	if corpse then
		if not db.corpseInfo then return end
		local remaining = corpse.left
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
	elseif cmd == "debug" then
		ns.db.debug = not ns.db.debug
		if ns.db.debug then
			Print(ICON.wait .. " " .. Color("gold", "trace des fouilles activée.") .. " Retape "
				.. Color("white", "/sl debug") .. " pour l'arrêter.")
			Print(("état : filtre %s, butin auto du jeu %s, %d objet(s) ignoré(s)"):format(
				ns.db.enabled and Color("green", "actif") or Color("red", "désactivé"),
				ns.IsGameAutoLootOn() and Color("red", "activé") or Color("green", "désactivé"),
				ns.IgnoredCount()))
		else
			Print(ICON.ok .. " " .. Color("green", "trace des fouilles arrêtée."))
		end
	elseif cmd == "move" then
		ns.SetFeedUnlocked(not ns.IsFeedUnlocked())
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
	ns.Fire("INIT")
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
handlers.LOOT_OPENED = OnLootReady  -- secours si LOOT_READY manque ; les doublons sont ignorés
handlers.LOOT_SLOT_CLEARED = OnLootSlotCleared
handlers.LOOT_BIND_CONFIRM = OnLootBindConfirm
handlers.LOOT_CLOSED = OnLootClosed

for event in pairs(handlers) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	handlers[event](...)
end)
