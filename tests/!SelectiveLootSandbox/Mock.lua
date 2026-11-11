-- Simulation des API du jeu absentes de wow-addons-sandbox, pour tester SelectiveLoot.
-- Ce fichier se charge AVANT SelectiveLoot (le « ! » le place en tête de l'ordre de chargement).
-- NE PAS installer dans le jeu.

---------------------------------------------------------------------------
-- Objets
---------------------------------------------------------------------------
-- id = { nom, qualité, classID, icône, prix de vente (pc) }
local ITEMS = {
	[2589]  = { "Linen Cloth", 1, 7, "Interface\\Icons\\INV_Fabric_Linen_01", 13 },
	[4306]  = { "Silk Cloth", 1, 7, "Interface\\Icons\\INV_Fabric_Silk_01", 150 },
	[2318]  = { "Light Leather", 1, 7, "Interface\\Icons\\INV_Misc_LeatherScrap_03", 15 },
	[7073]  = { "Broken Fang", 0, 15, "Interface\\Icons\\INV_Misc_Bone_08", 6 },
	[7074]  = { "Chipped Claw", 0, 15, "Interface\\Icons\\INV_Misc_MonsterClaw_04", 4 },
	[6197]  = { "Brotherhood Boots", 2, 4, "Interface\\Icons\\INV_Boots_05", 412 },
	[50001] = { "Timber Wolf Fang", 1, 12, "Interface\\Icons\\INV_Misc_MonsterFang_01", 0 },
}

ITEM_QUALITY_COLORS = {}
for q, hex in pairs({ [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee" }) do
	local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
	ITEM_QUALITY_COLORS[q] = { r = r, g = g, b = b, hex = "|cff" .. hex }
end

local function Link(id)
	local it = ITEMS[id]
	return ITEM_QUALITY_COLORS[it[2]].hex .. "|Hitem:" .. id .. "::::::::60:::::|h[" .. it[1] .. "]|h|r"
end

local function Money(copper)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. " Gold" end
	if s > 0 then parts[#parts + 1] = s .. " Silver" end
	if c > 0 or #parts == 0 then parts[#parts + 1] = c .. " Copper" end
	return table.concat(parts, " ")
end

local function ResolveID(x)
	if type(x) == "number" then return ITEMS[x] and x end
	if type(x) ~= "string" then return nil end
	local id = tonumber(x:match("item:(%d+)")) or tonumber(x)
	if id then return ITEMS[id] and id end
	for k, it in pairs(ITEMS) do
		if it[1]:lower() == x:lower() then return k end
	end
end

C_Item.GetItemInfo = function(x)
	local id = ResolveID(x)
	if not id then return end
	local it = ITEMS[id]
	return it[1], Link(id), it[2], 10, 1, "", "", 20, "", it[4], it[5], it[3], 0
end
C_Item.GetItemInfoInstant = function(x)
	local id = ResolveID(x)
	if not id then return end
	local it = ITEMS[id]
	return id, "", "", "", it[4], it[3], 0
end
C_Item.GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id][1] end
C_Item.GetItemQualityByID = function(id) return ITEMS[id] and ITEMS[id][2] end
C_Item.GetItemIconByID = function(id) return ITEMS[id] and ITEMS[id][4] end
C_Item.RequestLoadItemDataByID = function() end
GetItemInfo, GetItemInfoInstant = C_Item.GetItemInfo, C_Item.GetItemInfoInstant

Item = Item or {}
function Item:CreateFromItemID(id)
	return {
		IsItemEmpty = function() return ITEMS[id] == nil end,
		ContinueOnItemLoad = function(_, fn) fn() end,
		GetItemLink = function() return ITEMS[id] and Link(id) end,
	}
end

---------------------------------------------------------------------------
-- Divers
---------------------------------------------------------------------------
Enum = Enum or {}
Enum.LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 }
Enum.ItemClass = Enum.ItemClass or {}
Enum.ItemClass.Questitem = 12
Enum.TooltipDataType = { Item = 0, Unit = 2 }

SOUNDKIT = SOUNDKIT or { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857 }
GameTooltip_Hide = function() GameTooltip:Hide() end
YES, NO = "Yes", "No"
HandleModifiedItemClick = function() end
ConfirmLootSlot = function() end

local function GameMessage(text)
	DEFAULT_CHAT_FRAME:AddMessage(text, 0, 0.67, 0)
end

-- CVars (le butin automatique du jeu démarre ACTIVÉ pour tester l'alerte)
local cvars = { autoLootDefault = "1" }
C_CVar.GetCVar = function(n) return cvars[n] end
C_CVar.GetCVarBool = function(n) return cvars[n] == "1" end
C_CVar.SetCVar = function(n, v)
	cvars[n] = tostring(v)
	__FireEvent("CVAR_UPDATE", n, v)
end

---------------------------------------------------------------------------
-- Curseur (prendre un objet du sac puis cliquer sur le champ d'ajout)
---------------------------------------------------------------------------
local cursorItem
local cursorLabel = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cursorLabel:SetPoint("TOP", UIParent, "TOP", 0, -6)
local function UpdateCursor()
	cursorLabel:SetText(cursorItem and ("On cursor: " .. Link(cursorItem) .. "  (right-click in the bag to put it back)") or "")
end
GetCursorInfo = function()
	if cursorItem then return "item", cursorItem, Link(cursorItem) end
end
ClearCursor = function()
	cursorItem = nil
	UpdateCursor()
end

---------------------------------------------------------------------------
-- Raccourcis clavier
---------------------------------------------------------------------------
local binds = { X = "SITORSTAND" }
BINDING_NAME_SITORSTAND = "Sit / Stand"

GetBindingKey = function(action)
	local keys = {}
	for k, a in pairs(binds) do
		if a == action then keys[#keys + 1] = k end
	end
	table.sort(keys)
	return keys[1], keys[2]
end
GetBindingAction = function(key) return binds[key] or "" end
SetBinding = function(key, action)
	binds[key] = action
	return true
end
SaveBindings = function() __FireEvent("UPDATE_BINDINGS") end
GetCurrentBindingSet = function() return 1 end
GetBindingText = function(key)
	return (key:gsub("CTRL", "Ctrl"):gsub("SHIFT", "Shift"):gsub("ALT", "Alt"))
end

local MODS = { SHIFT = true, CONTROL = true, ALT = true, LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
local keyCatcher = CreateFrame("Frame", nil, UIParent)
keyCatcher:SetSize(1, 1)
keyCatcher:SetPoint("TOPLEFT")
keyCatcher:EnableKeyboard(true)
keyCatcher:SetPropagateKeyboardInput(true)
keyCatcher:SetScript("OnKeyDown", function(_, key)
	if MODS[key] then return end
	local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
		.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
	if binds[combo] == "SELECTIVELOOT_TOGGLE" and SelectiveLoot_ToggleHoveredItem then
		SelectiveLoot_ToggleHoveredItem()
	end
end)

---------------------------------------------------------------------------
-- Infobulles : TooltipDataProcessor + contenu d'objet/unité
---------------------------------------------------------------------------
local postCalls = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		postCalls[kind] = postCalls[kind] or {}
		table.insert(postCalls[kind], fn)
	end,
}
local function RunPost(tip, kind, data)
	for _, fn in ipairs(postCalls[kind] or {}) do fn(tip, data) end
end

local tipItem
local origSetOwner = GameTooltip.SetOwner
GameTooltip.SetOwner = function(self, ...)
	tipItem = nil
	return origSetOwner(self, ...)
end
GameTooltip.SetItemByID = function(self, id)
	local it = ITEMS[id]
	if not it then
		self:SetText("Item " .. tostring(id))
		return
	end
	tipItem = id
	self:ClearLines()
	local c = ITEM_QUALITY_COLORS[it[2]]
	self:AddLine(it[1], c.r, c.g, c.b)
	if it[3] == 12 then self:AddLine("Quest Item", 1, 1, 1) end
	if it[5] > 0 then self:AddLine("Sell Price: " .. Money(it[5]), 1, 1, 1) end
	RunPost(self, Enum.TooltipDataType.Item, { type = 0, id = id })
	self:Show()
end
GameTooltip.GetItem = function()
	if tipItem then return ITEMS[tipItem][1], Link(tipItem), tipItem end
end
GameTooltip.RefreshData = function(self)
	if tipItem then self:SetItemByID(tipItem) end
end

---------------------------------------------------------------------------
-- Menu Options de Blizzard (Settings)
---------------------------------------------------------------------------
local settingsWin = CreateFrame("Frame", "SettingsPanel", UIParent, "DialogBorderTemplate")
settingsWin:SetSize(880, 640)
settingsWin:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
settingsWin:SetFrameStrata("HIGH")
settingsWin:Hide()
local swTitle = settingsWin:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
swTitle:SetPoint("TOP", settingsWin, "TOP", 0, -16)
swTitle:SetText("Options")

local nav = settingsWin:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
nav:SetPoint("TOPLEFT", settingsWin, "TOPLEFT", 24, -50)
nav:SetJustifyH("LEFT")
nav:SetText("|cff9d9d9dGame|r\n\n|cffffd100AddOns|r")

local canvas = CreateFrame("Frame", nil, settingsWin)
canvas:SetPoint("TOPLEFT", settingsWin, "TOPLEFT", 220, -44)
canvas:SetPoint("BOTTOMRIGHT", settingsWin, "BOTTOMRIGHT", -16, 50)

local defaultsBtn = CreateFrame("Button", nil, settingsWin, "UIPanelButtonTemplate")
defaultsBtn:SetSize(120, 22)
defaultsBtn:SetPoint("BOTTOMLEFT", settingsWin, "BOTTOMLEFT", 20, 16)
defaultsBtn:SetText("Defaults")
local closeBtn = CreateFrame("Button", nil, settingsWin, "UIPanelButtonTemplate")
closeBtn:SetSize(120, 22)
closeBtn:SetPoint("BOTTOMRIGHT", settingsWin, "BOTTOMRIGHT", -20, 16)
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function() settingsWin:Hide() end)

local categories, navButtons = {}, {}
local current

local function Select(cat)
	if current and current ~= cat then current.frame:Hide() end
	current = cat
	local f = cat.frame
	f:SetParent(canvas)
	f:ClearAllPoints()
	f:SetAllPoints(canvas)
	defaultsBtn:SetScript("OnClick", function() if f.OnDefault then f.OnDefault() end end)
	settingsWin:Show()
	f:Hide()
	f:Show()
	for c, b in pairs(navButtons) do
		b.text:SetTextColor(c == cat and 1 or 0.8, c == cat and 0.82 or 0.8, c == cat and 0 or 0.8)
	end
end

local function Register(frame, name, depth)
	local cat = { frame = frame, name = name }
	function cat:GetID() return name end
	categories[name] = cat
	local b = CreateFrame("Button", nil, settingsWin)
	b:SetSize(180, 18)
	local n = 0
	for _ in pairs(navButtons) do n = n + 1 end
	b:SetPoint("TOPLEFT", settingsWin, "TOPLEFT", 30 + depth * 14, -96 - n * 20)
	b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.text:SetText(name)
	b:SetScript("OnClick", function() Select(cat) end)
	navButtons[cat] = b
	return cat
end

Settings = {
	RegisterCanvasLayoutCategory = function(frame, name) return Register(frame, name, 0) end,
	RegisterCanvasLayoutSubcategory = function(_, frame, name) return Register(frame, name, 1) end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function(id)
		if categories[id] then Select(categories[id]) end
	end,
}
function settingsWin:SelectCategory(cat) Select(cat) end
closeBtn:SetScript("OnClick", function()
	if current then current.frame:Hide() end
	settingsWin:Hide()
end)

---------------------------------------------------------------------------
-- Sac à dos
---------------------------------------------------------------------------
local bag = {
	{ id = 2589, count = 12 }, { id = 7073, count = 3 }, { id = 2318, count = 5 },
	{ id = 4306, count = 4 }, { id = 7074, count = 2 }, { id = 6197, count = 1 },
}
local bagFrame = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
bagFrame:SetSize(8 * 40 + 20, 4 * 40 + 40)
bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 20)
local bagTitle = bagFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
bagTitle:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 12, -10)
bagTitle:SetText("Backpack")

local bagButtons = {}
local function RefreshBag()
	for i = 1, 32 do
		local b = bagButtons[i]
		if not b then
			b = CreateFrame("Button", nil, bagFrame)
			b:SetSize(36, 36)
			b:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10 + ((i - 1) % 8) * 40, -30 - math.floor((i - 1) / 8) * 40)
			local bg = b:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(0.12, 0.12, 0.12, 1)
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetPoint("TOPLEFT", 2, -2)
			b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
			b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
			b:SetScript("OnEnter", function(self)
				if self.itemID then
					GameTooltip:SetOwner(self, "ANCHOR_LEFT")
					GameTooltip:SetItemByID(self.itemID)
				end
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			b:SetScript("OnClick", function(self, button)
				if button == "RightButton" then
					ClearCursor()
				elseif self.itemID then
					cursorItem = self.itemID
					UpdateCursor()
				end
			end)
			bagButtons[i] = b
		end
		local e = bag[i]
		b.itemID = e and e.id
		b.icon:SetTexture(e and ITEMS[e.id][4] or nil)
		b.icon:SetShown(e ~= nil)
		b.count:SetText(e and e.count > 1 and e.count or "")
	end
end

local function AddToBag(id, count)
	for _, e in ipairs(bag) do
		if e.id == id then
			e.count = e.count + count
			RefreshBag()
			return
		end
	end
	bag[#bag + 1] = { id = id, count = count }
	RefreshBag()
end

---------------------------------------------------------------------------
-- Cadavres et butin
---------------------------------------------------------------------------
local function NewCorpses()
	return {
		{ guid = "Creature-0-1-0-1-299-0001", name = "Timber Wolf", info = "Level 6 Beast",
			loot = { { id = 2318, count = 2 }, { id = 7073, count = 1 }, { money = 23 } } },
		{ guid = "Creature-0-1-0-1-116-0002", name = "Defias Bandit", info = "Level 9 Humanoid",
			loot = { { id = 2589, count = 3 }, { id = 7074, count = 1 }, { id = 6197, count = 1 }, { money = 112 } } },
		{ guid = "Creature-0-1-0-1-1125-0003", name = "Rockhide Boar", info = "Level 7 Beast",
			loot = { { id = 50001, count = 1 }, { id = 7073, count = 2 } } },
		{ guid = "Creature-0-1-0-1-117-0004", name = "Defias Bandit", info = "Level 10 Humanoid",
			loot = { { id = 4306, count = 1 }, { id = 2589, count = 2 } } },
	}
end
local corpses = NewCorpses()
local function CorpseByGUID(guid)
	for _, c in ipairs(corpses) do
		if c.guid == guid then return c end
	end
end

CanLootUnit = function(guid)
	local c = CorpseByGUID(guid)
	local has = c ~= nil and #c.loot > 0
	return has, has
end

-- Fenêtre de butin du jeu (simplifiée)
local lootWin = CreateFrame("Frame", "LootFrame", UIParent, "TooltipBackdropTemplate")
lootWin:SetSize(220, 60)
lootWin:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 320, -60)
lootWin:SetFrameStrata("DIALOG")
lootWin:Hide()
local lootTitle = lootWin:CreateFontString(nil, "ARTWORK", "GameFontNormal")
lootTitle:SetPoint("TOPLEFT", lootWin, "TOPLEFT", 12, -10)
local lootText = lootWin:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
lootText:SetPoint("TOPLEFT", lootTitle, "BOTTOMLEFT", 0, -6)
lootText:SetJustifyH("LEFT")

local lootSlots, lootCorpse
local RefreshCorpses

local function RefreshLootWin()
	if not lootSlots then
		lootWin:Hide()
		return
	end
	local lines = {}
	for _, e in ipairs(lootSlots) do
		if not e.cleared then
			lines[#lines + 1] = e.money and Money(e.money) or (Link(e.id) .. (e.count > 1 and (" x" .. e.count) or ""))
		end
	end
	lootTitle:SetText("Loot: " .. lootCorpse.name)
	lootText:SetText(table.concat(lines, "\n"))
	lootWin:SetHeight(40 + #lines * 14)
	lootWin:Show()
end

GetNumLootItems = function() return lootSlots and #lootSlots or 0 end
GetLootSlotType = function(s)
	local e = lootSlots and lootSlots[s]
	if not e or e.cleared then return 0 end
	return e.money and 2 or 1
end
GetLootSlotLink = function(s)
	local e = lootSlots and lootSlots[s]
	if e and e.id and not e.cleared then return Link(e.id) end
end
GetLootSlotInfo = function(s)
	local e = lootSlots and lootSlots[s]
	if not e or e.cleared then return end
	if e.money then
		return "Interface\\Icons\\INV_Misc_Coin_01", Money(e.money), 0, nil, 0, false, false, nil, true
	end
	local it = ITEMS[e.id]
	return it[4], it[1], e.count, nil, it[2], false, it[3] == 12, nil, true
end
GetLootSourceInfo = function()
	return lootCorpse and lootCorpse.guid, 1
end

CloseLoot = function()
	if not lootSlots then return end
	lootSlots, lootCorpse = nil, nil
	RefreshLootWin()
	__FireEvent("LOOT_CLOSED")
	RefreshCorpses()
end

LootSlot = function(s)
	local e = lootSlots and lootSlots[s]
	if not e or e.cleared or e.pending then return end
	e.pending = true
	local corpse, slots = lootCorpse, lootSlots
	C_Timer.After(0.15, function()
		if lootSlots ~= slots then return end
		e.cleared = true
		for i, x in ipairs(corpse.loot) do
			if x == e.src then
				table.remove(corpse.loot, i)
				break
			end
		end
		if e.money then
			GameMessage("You loot " .. Money(e.money) .. ".")
		else
			AddToBag(e.id, e.count)
			GameMessage("You receive loot: " .. Link(e.id) .. (e.count > 1 and ("x" .. e.count) or "") .. ".")
		end
		__FireEvent("LOOT_SLOT_CLEARED", s)
		RefreshLootWin()
		RefreshCorpses()
		local remaining = false
		for _, x in ipairs(slots) do
			if not x.cleared then remaining = true end
		end
		if not remaining then CloseLoot() end
	end)
end

local function OpenLoot(c, forceAuto)
	if lootSlots then CloseLoot() end
	if #c.loot == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("This corpse is empty.", 1, 0.1, 0.1)
		return
	end
	lootCorpse, lootSlots = c, {}
	for _, src in ipairs(c.loot) do
		lootSlots[#lootSlots + 1] = { src = src, id = src.id, count = src.count or 1, money = src.money }
	end
	local autoLoot = (cvars.autoLootDefault == "1") ~= (forceAuto or IsShiftKeyDown() or false)
	__FireEvent("LOOT_READY", autoLoot)
	if autoLoot and lootSlots then
		for s = 1, #lootSlots do LootSlot(s) end
	end
	if lootSlots then
		__FireEvent("LOOT_OPENED", autoLoot)
	end
	if lootSlots then RefreshLootWin() end
end

-- Panneau « monde »
local world = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
world:SetSize(280, 330)
world:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -40)
local worldTitle = world:CreateFontString(nil, "ARTWORK", "GameFontNormal")
worldTitle:SetPoint("TOPLEFT", world, "TOPLEFT", 12, -10)
worldTitle:SetText("Corpses (simulation)")
local worldHelp = world:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
worldHelp:SetPoint("TOPLEFT", worldTitle, "BOTTOMLEFT", 0, -4)
worldHelp:SetJustifyH("LEFT")
worldHelp:SetText("Hover = tooltip   Click = loot\nRight-click = Shift+click (loot all)")

local corpseButtons = {}
function RefreshCorpses()
	for i, c in ipairs(corpses) do
		local b = corpseButtons[i]
		if not b then
			b = CreateFrame("Button", nil, world, "UIPanelButtonTemplate")
			b:SetSize(256, 30)
			b:SetPoint("TOPLEFT", world, "TOPLEFT", 12, -50 - (i - 1) * 36)
			b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			b:SetScript("OnEnter", function(self)
				local corpse = corpses[self.index]
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(corpse.name, 1, 0.1, 0.1)
				GameTooltip:AddLine(corpse.info, 1, 1, 1)
				GameTooltip:AddLine("Corpse", 0.6, 0.6, 0.6)
				RunPost(GameTooltip, Enum.TooltipDataType.Unit, { type = 2, guid = corpse.guid })
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			b:SetScript("OnClick", function(self, button)
				OpenLoot(corpses[self.index], button == "RightButton")
				if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then
					self:GetScript("OnEnter")(self)
				end
			end)
			corpseButtons[i] = b
		end
		b.index = i
		local sparkle = #c.loot > 0 and "  |cffffd100(sparkles)|r" or "  |cff9d9d9d(empty)|r"
		b:SetText(c.name .. sparkle)
	end
end

local respawn = CreateFrame("Button", nil, world, "UIPanelButtonTemplate")
respawn:SetSize(124, 22)
respawn:SetPoint("BOTTOMLEFT", world, "BOTTOMLEFT", 12, 14)
respawn:SetText("Respawn")
respawn:SetScript("OnClick", function()
	if lootSlots then CloseLoot() end
	corpses = NewCorpses()
	RefreshCorpses()
end)
local optsBtn = CreateFrame("Button", nil, world, "UIPanelButtonTemplate")
optsBtn:SetSize(124, 22)
optsBtn:SetPoint("BOTTOMRIGHT", world, "BOTTOMRIGHT", -12, 14)
optsBtn:SetText("Options (/sl)")
optsBtn:SetScript("OnClick", function()
	if SelectiveLoot_OpenOptions then SelectiveLoot_OpenOptions() end
end)

RefreshBag()
RefreshCorpses()
