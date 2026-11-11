-- SelectiveLoot : panneau d'options dans Options > AddOns, construit avec les modèles natifs du jeu.

local ADDON, ns = ...
local Color, ICON = ns.Color, ns.ICON

local PAD = 16
local ROW_H = 24
local BTN_W = 130

local panel = CreateFrame("Frame")
panel.name = "SelectiveLoot"
panel:Hide()

---------------------------------------------------------------------------
-- Aides de mise en page (positions absolues depuis le haut du panneau)
---------------------------------------------------------------------------
local y = -PAD

local function Text(font, text, parent)
	local fs = (parent or panel):CreateFontString(nil, "ARTWORK", font)
	fs:SetJustifyH("LEFT")
	if text then fs:SetText(text) end
	return fs
end

local function Header(text)
	y = y - 12
	local fs = Text("GameFontNormal", text)
	fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.3)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y - 17)
	line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, y - 17)
	y = y - 26
	return fs
end

local function Button(text, width)
	local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	b:SetSize(width or BTN_W, 22)
	b:SetText(text)
	return b
end

local function PlayCheckSound(checked)
	if SOUNDKIT then
		PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end
end

-- Ligne d'état : icône + texte coloré, bouton(s) alignés à droite.
local function StatusLine()
	local top = y
	local fs = Text("GameFontHighlight")
	fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, top - 5)
	fs:SetWidth(420)
	fs:SetWordWrap(false)
	local btn = Button("")
	btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, top)
	y = top - 28
	return fs, btn
end

local function SetStatus(fs, ok, okText, badText)
	if ok then
		fs:SetText(ICON.ok .. " " .. Color("green", okText))
	else
		fs:SetText(ICON.no .. " " .. Color("red", badText))
	end
end

---------------------------------------------------------------------------
-- En-tête
---------------------------------------------------------------------------
local title = Text("GameFontNormalLarge", "SelectiveLoot")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
if version then
	Text("GameFontDisableSmall", "v" .. version):SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
end
y = y - 24
local subtitle = Text("GameFontHighlightSmall", "Ramasse tout le butin, sauf les objets que tu as choisi d'ignorer.")
subtitle:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
y = y - 14

---------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------
Header("État")

local filterLine, filterBtn = StatusLine()
filterBtn:SetScript("OnClick", function()
	ns.db.enabled = not ns.db.enabled
	PlayCheckSound(ns.db.enabled)
	ns.Fire("OPTIONS")
end)

local autoLootLine, autoLootBtn = StatusLine()
autoLootBtn:SetText("Corriger")
autoLootBtn:SetScript("OnClick", function()
	ns.DisableGameAutoLoot()
end)

local keyLine, keyBtn = StatusLine()
local keyClearBtn = Button("Effacer", 80)
keyClearBtn:SetPoint("RIGHT", keyBtn, "LEFT", -6, 0)

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------
Header("Infobulles et confirmations")

local checkboxes = {}
local function Checkbox(key, label, desc)
	local top = y
	local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	cb:SetSize(26, 26)
	cb:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, top)
	if cb.Text then cb.Text:SetText("") end
	if cb.text then cb.text:SetText("") end

	local fs = Text("GameFontHighlight", label)
	fs:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 30, top - 4)
	local d = Text("GameFontDisableSmall", desc)
	d:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
	cb:SetHitRectInsets(0, -(fs:GetStringWidth() + 8), 0, 0)

	cb:SetScript("OnClick", function(self)
		local checked = self:GetChecked() and true or false
		ns.db[key] = checked
		PlayCheckSound(checked)
		ns.Fire("OPTIONS")
	end)
	cb.key = key
	checkboxes[#checkboxes + 1] = cb
	y = top - 40
end

Checkbox("corpseInfo",
	"Afficher « Fouillé » sur les cadavres",
	"Ligne verte dans l'infobulle d'un cadavre que tu as déjà fouillé.")
Checkbox("unlootedHint",
	"Signaler les cadavres pas encore fouillés",
	"Ligne jaune dans l'infobulle tant qu'il reste du butin pour toi.")
Checkbox("autoConfirmBind",
	"Confirmer automatiquement les objets liés quand ramassés",
	"Sinon, le jeu te demande de confirmer à chaque fois.")

---------------------------------------------------------------------------
-- Liste des objets ignorés
---------------------------------------------------------------------------
local listHeader = Header("Objets ignorés")

-- Champ d'ajout : ID, lien, nom, ou glisser-déposer
local inputTop = y
local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
input:SetSize(280, 22)
input:SetAutoFocus(false)
input:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 6, inputTop)

local placeholder = Text("GameFontDisable", "ID, lien, ou glisse un objet ici", input)
placeholder:SetPoint("LEFT", input, "LEFT", 2, 0)

local addBtn = Button("Ajouter", 90)
addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)

local feedback = Text("GameFontHighlightSmall")
feedback:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
feedback:SetWidth(200)
feedback:SetWordWrap(false)
y = inputTop - 30

local function UpdatePlaceholder()
	placeholder:SetShown(input:GetText() == "" and not input:HasFocus())
end

local function Feedback(kind, text)
	local icon = kind == "green" and ICON.ok or kind == "red" and ICON.no or ICON.wait
	feedback:SetText(icon .. " " .. Color(kind, text))
end

local function AddItem(itemID)
	if ns.IsIgnored(itemID) then
		Feedback("gold", "Déjà dans la liste.")
		return
	end
	ns.SetIgnored(itemID, true)
	Feedback("green", "Ajouté.")
end

local function AddFromInput()
	local itemID = ns.ItemIDFromText(input:GetText())
	if not itemID then
		Feedback("red", "Objet introuvable.")
		return
	end
	AddItem(itemID)
	input:SetText("")
	input:ClearFocus()
end

local function AddFromCursor()
	local kind, itemID = GetCursorInfo()
	if kind == "item" and itemID then
		ClearCursor()
		AddItem(itemID)
		return true
	end
end

input:SetScript("OnEnterPressed", AddFromInput)
input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
input:SetScript("OnTextChanged", UpdatePlaceholder)
input:SetScript("OnEditFocusGained", UpdatePlaceholder)
input:SetScript("OnEditFocusLost", UpdatePlaceholder)
input:SetScript("OnReceiveDrag", AddFromCursor)
input:HookScript("OnMouseDown", AddFromCursor)
addBtn:SetScript("OnClick", function()
	if not AddFromCursor() then AddFromInput() end
end)

-- Cadre de la liste
local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
box:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
box:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, 46)
box:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
box:SetBackdropColor(0, 0, 0, 0.5)
box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
box:EnableMouse(true)
box:SetScript("OnReceiveDrag", AddFromCursor)
box:SetScript("OnMouseUp", AddFromCursor)

local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -28, 6)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)

local empty = Text("GameFontDisable",
	"Aucun objet ignoré.\n\nSurvole un objet et appuie sur ton raccourci,\nou glisse-le dans le champ ci-dessus.", box)
empty:SetJustifyH("CENTER")
empty:SetPoint("CENTER", box, "CENTER")

local rows = {}
local function GetRow(i)
	if rows[i] then return rows[i] end
	local row = CreateFrame("Button", nil, content)
	row:SetHeight(ROW_H)
	row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
	row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	if i % 2 == 0 then
		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(1, 1, 1, 0.04)
	end

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

	row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.remove:SetSize(70, 20)
	row.remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.remove:SetText("Retirer")
	row.remove:SetScript("OnClick", function(self)
		ns.SetIgnored(self:GetParent().itemID, false)
	end)

	row.idText = Text("GameFontDisableSmall", nil, row)
	row.idText:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)

	row.name = Text("GameFontHighlight", nil, row)
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row.idText, "LEFT", -8, 0)
	row.name:SetWordWrap(false)

	row:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.itemID)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row:SetScript("OnClick", function(self)
		if IsModifiedClick() then
			local _, link = C_Item.GetItemInfo(self.itemID)
			if link then HandleModifiedItemClick(link) end
		end
	end)

	rows[i] = row
	return row
end

local function ItemDisplayName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if not name then
		C_Item.RequestLoadItemDataByID(itemID)
		return Color("gray", "Chargement…")
	end
	local quality = C_Item.GetItemQualityByID(itemID)
	local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	return qc and (qc.hex .. name .. "|r") or name
end

local clearBtn = Button("Tout retirer", 110)
clearBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, 14)
clearBtn:SetScript("OnClick", function()
	StaticPopup_Show("SELECTIVELOOT_CLEAR")
end)

local bypassHint = Text("GameFontDisableSmall", "Astuce : Maj+clic sur un cadavre ramasse tout, filtre compris.")
bypassHint:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, 20)

local function RefreshList()
	local ids = {}
	for id in pairs(ns.db.ignored) do ids[#ids + 1] = id end
	table.sort(ids, function(a, b)
		local na, nb = C_Item.GetItemNameByID(a) or "", C_Item.GetItemNameByID(b) or ""
		if na ~= nb then return na < nb end
		return a < b
	end)

	listHeader:SetText(("Objets ignorés (%d)"):format(#ids))
	content:SetWidth(math.max(1, scroll:GetWidth()))
	content:SetHeight(math.max(1, #ids * ROW_H))

	for i, id in ipairs(ids) do
		local row = GetRow(i)
		row.itemID = id
		row.icon:SetTexture(C_Item.GetItemIconByID(id))
		row.name:SetText(ItemDisplayName(id))
		row.idText:SetText("#" .. id)
		row:Show()
	end
	for i = #ids + 1, #rows do
		rows[i]:Hide()
	end

	empty:SetShown(#ids == 0)
	clearBtn:SetEnabled(#ids > 0)
end

---------------------------------------------------------------------------
-- Raccourci : capture d'une touche directement depuis le panneau
---------------------------------------------------------------------------
local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
	LALT = true, RALT = true, LMETA = true, RMETA = true,
	SHIFT = true, CTRL = true, ALT = true, CONTROL = true, META = true,
}
local capturing = false
local RefreshStatus

function ns.ApplyBinding(combo)
	if InCombatLockdown() then
		ns.Print(ICON.no .. " " .. Color("red", "impossible de changer un raccourci en combat."))
		return
	end
	local k1, k2 = GetBindingKey(ns.BINDING)
	if k1 then SetBinding(k1) end
	if k2 then SetBinding(k2) end
	if combo then SetBinding(combo, ns.BINDING) end
	SaveBindings(GetCurrentBindingSet())
	ns.Fire("STATUS")
end

local function StopCapture()
	capturing = false
	keyBtn:SetScript("OnKeyDown", nil)
	keyBtn:EnableKeyboard(false)
	RefreshStatus()
end

local function OnCaptureKey(self, key)
	if key == "ESCAPE" then
		StopCapture()
		return
	end
	if MODIFIER_KEYS[key] then return end

	local combo = (IsAltKeyDown() and "ALT-" or "")
		.. (IsControlKeyDown() and "CTRL-" or "")
		.. (IsShiftKeyDown() and "SHIFT-" or "")
		.. key
	StopCapture()

	local current = GetBindingAction(combo)
	if current and current ~= "" and current ~= ns.BINDING then
		local label = _G["BINDING_NAME_" .. current] or current
		StaticPopup_Show("SELECTIVELOOT_REBIND", GetBindingText(combo), label, combo)
	else
		ns.ApplyBinding(combo)
	end
end

keyBtn:SetScript("OnClick", function(self)
	if capturing then
		StopCapture()
		return
	end
	if InCombatLockdown() then
		ns.Print(ICON.no .. " " .. Color("red", "impossible de changer un raccourci en combat."))
		return
	end
	capturing = true
	self:SetText("Annuler")
	keyClearBtn:Hide()
	keyLine:SetText(ICON.wait .. " " .. Color("gold", "Appuie sur la touche voulue… (Échap pour annuler)"))
	self:EnableKeyboard(true)
	self:SetPropagateKeyboardInput(false)
	self:SetScript("OnKeyDown", OnCaptureKey)
end)

keyClearBtn:SetScript("OnClick", function()
	ns.ApplyBinding(nil)
end)

StaticPopupDialogs["SELECTIVELOOT_REBIND"] = {
	text = "La touche %s est déjà utilisée par :\n« %s »\n\nLa remplacer par SelectiveLoot ?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, combo) ns.ApplyBinding(combo) end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["SELECTIVELOOT_CLEAR"] = {
	text = "Retirer tous les objets de la liste d'ignorés ?\n\nTout sera de nouveau ramassé.",
	button1 = YES,
	button2 = NO,
	OnAccept = function() ns.ClearList() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Rafraîchissement
---------------------------------------------------------------------------
function RefreshStatus()
	local db = ns.db

	SetStatus(filterLine, db.enabled, "Filtre actif", "Filtre désactivé : tout est ramassé normalement")
	filterBtn:SetText(db.enabled and "Désactiver" or "Activer")

	local autoLootOff = not ns.IsGameAutoLootOn()
	SetStatus(autoLootLine, autoLootOff, "Butin automatique du jeu désactivé",
		"Butin automatique du jeu activé : filtre bloqué")
	autoLootBtn:SetShown(not autoLootOff)

	if capturing then return end
	local key = GetBindingKey(ns.BINDING)
	SetStatus(keyLine, key ~= nil, "Raccourci : " .. (key and GetBindingText(key) or ""),
		"Aucun raccourci défini")
	keyBtn:SetText(key and "Changer…" or "Définir…")
	keyClearBtn:SetShown(key ~= nil)
end

local function Refresh()
	if not ns.db then return end
	RefreshStatus()
	for _, cb in ipairs(checkboxes) do
		cb:SetChecked(ns.db[cb.key])
	end
	RefreshList()
end

panel:SetScript("OnShow", Refresh)
panel:SetScript("OnHide", function()
	if capturing then StopCapture() end
end)
ns.On(function()
	if panel:IsVisible() then Refresh() end
end)

-- Méthodes appelées par le menu Options de Blizzard
panel.OnCommit = function() end
panel.OnDefault = function() ns.ResetOptions() end
panel.OnRefresh = Refresh

---------------------------------------------------------------------------
-- Enregistrement dans Options > AddOns
---------------------------------------------------------------------------
local category
if Settings and Settings.RegisterCanvasLayoutCategory then
	category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
	if category and Settings.OpenToCategory then
		Settings.OpenToCategory(category:GetID())
	else
		-- Repli (client sans menu Options moderne) : fenêtre autonome
		panel:SetParent(UIParent)
		panel:ClearAllPoints()
		panel:SetPoint("CENTER")
		panel:SetSize(640, 600)
		panel:SetShown(not panel:IsShown())
	end
end

-- Menu des addons (bouton de la minicarte) et accès global
SelectiveLoot_OpenOptions = ns.OpenOptions
