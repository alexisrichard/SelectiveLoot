-- SelectiveLoot : options dans Options > AddOns, construites avec les modèles natifs du jeu.
--   Page « SelectiveLoot »             : état, infobulles, liens vers les sous-pages
--   Sous-page « Affichage du butin »   : liste à l'écran (cases, curseurs, position)
--   Sous-page « Objets ignorés »       : la liste du personnage
-- L'aperçu de la liste du butin est affiché tant qu'une de ces pages est ouverte.
--
-- Les pages sont construites à ADDON_LOADED (événement INIT), une fois la langue
-- choisie connue : les réglages sauvegardés ne sont pas encore lus au chargement du fichier.

local ADDON, ns = ...
local Color, ICON, L = ns.Color, ns.ICON, ns.L

local PAD = 16
local ROW_H = 24
local BTN_W = 130

local checkboxes, sliders = {}, {}

local function PlayCheckSound(checked)
	if SOUNDKIT then
		PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end
end

---------------------------------------------------------------------------
-- Constructeur de page (positions absolues depuis le haut)
---------------------------------------------------------------------------
local function NewPage(name)
	local frame = CreateFrame("Frame")
	frame.name = name
	frame:Hide()
	local page = { frame = frame, y = -PAD }

	function page:Text(font, text, parent)
		local fs = (parent or frame):CreateFontString(nil, "ARTWORK", font)
		fs:SetJustifyH("LEFT")
		if text then fs:SetText(text) end
		return fs
	end

	function page:Button(text, width, parent)
		local b = CreateFrame("Button", nil, parent or frame, "UIPanelButtonTemplate")
		b:SetSize(width or BTN_W, 22)
		b:SetText(text)
		return b
	end

	function page:Title(title, subtitle)
		local t = self:Text("GameFontNormalLarge", title)
		t:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, self.y)
		self.y = self.y - 24
		local s = self:Text("GameFontHighlightSmall", subtitle)
		s:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, self.y)
		self.y = self.y - 14
		return t
	end

	function page:Header(text)
		self.y = self.y - 12
		local fs = self:Text("GameFontNormal", text)
		fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, self.y)
		local line = frame:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(1, 0.82, 0, 0.3)
		line:SetHeight(1)
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, self.y - 17)
		line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, self.y - 17)
		self.y = self.y - 26
		return fs
	end

	-- Ligne d'état : icône + texte coloré à gauche, bouton à droite.
	function page:StatusLine()
		local top = self.y
		local fs = self:Text("GameFontHighlight")
		fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, top - 5)
		fs:SetWidth(420)
		fs:SetWordWrap(false)
		local btn = self:Button("")
		btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, top)
		self.y = top - 28
		return fs, btn
	end

	function page:Checkbox(key, label, desc)
		local top = self.y
		local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
		cb:SetSize(26, 26)
		cb:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, top)
		if cb.Text then cb.Text:SetText("") end
		if cb.text then cb.text:SetText("") end

		cb.label = self:Text("GameFontHighlight", label)
		cb.label:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 30, top - 4)
		cb.desc = self:Text("GameFontDisableSmall", desc)
		cb.desc:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -2)
		cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 8), 0, 0)

		cb:SetScript("OnClick", function(self)
			local checked = self:GetChecked() and true or false
			ns.db[key] = checked
			PlayCheckSound(checked)
			ns.Fire("OPTIONS")
		end)
		cb.key = key
		checkboxes[#checkboxes + 1] = cb
		self.y = top - 40
		return cb
	end

	-- Curseur horizontal au style classique : libellé à gauche, valeur dorée à droite.
	function page:Slider(key, label, minV, maxV, step, format)
		local top = self.y
		local text = self:Text("GameFontHighlight", label)
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, top - 4)

		local s = CreateFrame("Slider", nil, frame, "BackdropTemplate")
		s:SetOrientation("HORIZONTAL")
		s:SetSize(220, 17)
		s:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 190, top - 2)
		s:SetBackdrop({
			bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
			edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
			tile = true, tileSize = 8, edgeSize = 8,
			insets = { left = 3, right = 3, top = 6, bottom = 6 },
		})
		s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
		s:SetMinMaxValues(minV, maxV)
		s:SetValueStep(step)
		s:SetObeyStepOnDrag(true)

		local value = self:Text("GameFontNormal")
		value:SetPoint("LEFT", s, "RIGHT", 12, 0)

		s:SetScript("OnValueChanged", function(_, v, userInput)
			v = math.floor(v / step + 0.5) * step
			value:SetText(format(v))
			if userInput and ns.db[key] ~= v then
				ns.db[key] = v
				ns.Fire("OPTIONS")
			end
		end)
		s.key, s.step = key, step
		sliders[#sliders + 1] = s
		self.y = top - 32
		return s
	end

	return page
end

local function SetStatus(fs, ok, okText, badText)
	if ok then
		fs:SetText(ICON.ok .. " " .. Color("green", okText))
	else
		fs:SetText(ICON.no .. " " .. Color("red", badText))
	end
end

local function Build()
	---------------------------------------------------------------------------
	-- Page principale
	---------------------------------------------------------------------------
	local main = NewPage("SelectiveLoot")
	local mainTitle = main:Title("SelectiveLoot", L.SUBTITLE)
	local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
	if version then
		main:Text("GameFontDisableSmall", "v" .. version):SetPoint("BOTTOMLEFT", mainTitle, "BOTTOMRIGHT", 6, 1)
	end

	main:Header(L.H_STATUS)

	local filterLine, filterBtn = main:StatusLine()
	filterBtn:SetScript("OnClick", function()
		ns.db.enabled = not ns.db.enabled
		PlayCheckSound(ns.db.enabled)
		ns.Fire("OPTIONS")
	end)

	local autoLootLine, autoLootBtn = main:StatusLine()
	autoLootBtn:SetText(L.FIX)
	autoLootBtn:SetScript("OnClick", function() ns.DisableGameAutoLoot() end)

	local keyLine, keyBtn = main:StatusLine()
	local keyClearBtn = main:Button(L.KEY_CLEAR, 80)
	keyClearBtn:SetPoint("RIGHT", keyBtn, "LEFT", -6, 0)

	main:Header(L.H_TOOLTIPS)
	main:Checkbox("corpseInfo",
		L.OPT_CORPSE, L.OPT_CORPSE_DESC)
	main:Checkbox("unlootedHint",
		L.OPT_UNLOOTED, L.OPT_UNLOOTED_DESC)
	main:Checkbox("autoConfirmBind",
		L.OPT_BIND, L.OPT_BIND_DESC)

	-- Langue : trois cases exclusives sur une ligne. La nouvelle langue s'applique
	-- au rechargement de l'interface (les textes sont posés à la construction).
	main:Header(L.H_LANGUAGE)
	local langButtons = {}
	local function RefreshLanguage()
		for _, cb in ipairs(langButtons) do
			cb:SetChecked(ns.db.language == cb.code)
		end
	end
	local prevLabel
	for _, lang in ipairs(ns.LANGUAGES) do
		local cb = CreateFrame("CheckButton", nil, main.frame, "UICheckButtonTemplate")
		cb:SetSize(26, 26)
		if prevLabel then
			cb:SetPoint("LEFT", prevLabel, "RIGHT", 18, 0)
		else
			cb:SetPoint("TOPLEFT", main.frame, "TOPLEFT", PAD, main.y)
		end
		if cb.Text then cb.Text:SetText("") end
		if cb.text then cb.text:SetText("") end
		local label = main:Text("GameFontHighlight", lang.name or L.LANG_AUTO)
		label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		cb:SetHitRectInsets(0, -(label:GetStringWidth() + 6), 0, 0)
		cb.code = lang.code
		cb:SetScript("OnClick", function(self)
			PlayCheckSound(true)
			if ns.db.language ~= self.code then
				ns.db.language = self.code
				local target = ns.ResolveLanguage(self.code)
				if target ~= ns.language then
					local popup = StaticPopupDialogs["SELECTIVELOOT_RELOAD"]
					popup.text = ns.LOCALES[target].RELOAD_PROMPT
					StaticPopup_Show("SELECTIVELOOT_RELOAD")
				end
			end
			RefreshLanguage()
		end)
		langButtons[#langButtons + 1] = cb
		prevLabel = label
	end
	main.y = main.y - 32

	StaticPopupDialogs["SELECTIVELOOT_RELOAD"] = {
		text = L.RELOAD_PROMPT,
		button1 = YES,
		button2 = NO,
		OnAccept = function() ReloadUI() end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	main:Header(L.H_PAGES)
	local feedPageBtn = main:Button(L.BTN_FEED_PAGE, 190)
	feedPageBtn:SetPoint("TOPLEFT", main.frame, "TOPLEFT", PAD, main.y)
	local manageBtn = main:Button(L.BTN_LIST_PAGE:format(0), 190)
	manageBtn:SetPoint("LEFT", feedPageBtn, "RIGHT", 8, 0)
	main.y = main.y - 30

	local bypassHint = main:Text("GameFontDisableSmall", L.BYPASS_HINT)
	bypassHint:SetPoint("BOTTOMRIGHT", main.frame, "BOTTOMRIGHT", -PAD, 20)

	---------------------------------------------------------------------------
	-- Sous-page : affichage du butin
	---------------------------------------------------------------------------
	local feedPage = NewPage(L.PAGE_FEED)
	feedPage:Title(L.PAGE_FEED, L.FEED_SUBTITLE)

	feedPage:Header(L.H_DISPLAY)
	feedPage:Checkbox("feed",
		L.OPT_FEED, L.OPT_FEED_DESC)
	local feedLeftCb = feedPage:Checkbox("feedLeft",
		L.OPT_FEED_LEFT, L.OPT_FEED_LEFT_DESC)

	feedPage:Header(L.H_APPEARANCE)
	feedPage:Slider("feedScale", L.SL_SIZE, 0.5, 2, 0.05,
		function(v) return ("%d %%"):format(math.floor(v * 100 + 0.5)) end)
	feedPage:Slider("feedTime", L.SL_TIME, 2, 20, 1,
		function(v) return ("%d s"):format(v) end)
	feedPage:Slider("feedLines", L.SL_LINES, 3, 15, 1,
		function(v) return ("%d"):format(v) end)
	feedPage:Slider("feedFrameAlpha", L.SL_ALPHA, 0, 1, 0.05,
		function(v) return ("%d %%"):format(math.floor(v * 100 + 0.5)) end)

	feedPage:Header(L.H_POSITION)
	local posHint = feedPage:Text("GameFontHighlight",
		L.POS_HINT:format(Color("gold", "Ctrl")))
	posHint:SetPoint("TOPLEFT", feedPage.frame, "TOPLEFT", PAD + 4, feedPage.y)
	feedPage.y = feedPage.y - 36
	local resetPosBtn = feedPage:Button(L.RESET_POS, 150)
	resetPosBtn:SetPoint("TOPLEFT", feedPage.frame, "TOPLEFT", PAD + 4, feedPage.y)
	resetPosBtn:SetScript("OnClick", function() ns.ResetFeedPosition() end)

	---------------------------------------------------------------------------
	-- Sous-page : objets ignorés
	---------------------------------------------------------------------------
	local list = NewPage(L.PAGE_LIST)
	local listTitle = list:Title(L.PAGE_LIST, L.LIST_SUBTITLE)
	list.y = list.y - 12

	local inputTop = list.y
	local input = CreateFrame("EditBox", nil, list.frame, "InputBoxTemplate")
	input:SetSize(280, 22)
	input:SetAutoFocus(false)
	input:SetPoint("TOPLEFT", list.frame, "TOPLEFT", PAD + 6, inputTop)

	local placeholder = list:Text("GameFontDisable", L.LIST_PLACEHOLDER, input)
	placeholder:SetPoint("LEFT", input, "LEFT", 2, 0)

	local addBtn = list:Button(L.ADD, 90)
	addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)

	local feedback = list:Text("GameFontHighlightSmall")
	feedback:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
	feedback:SetWidth(200)
	feedback:SetWordWrap(false)
	list.y = inputTop - 30

	local function UpdatePlaceholder()
		placeholder:SetShown(input:GetText() == "" and not input:HasFocus())
	end

	local function Feedback(kind, text)
		local icon = kind == "green" and ICON.ok or kind == "red" and ICON.no or ICON.wait
		feedback:SetText(icon .. " " .. Color(kind, text))
	end

	local function AddItem(itemID)
		if ns.IsIgnored(itemID) then
			Feedback("gold", L.ALREADY)
			return
		end
		ns.SetIgnored(itemID, true)
		Feedback("green", L.ADDED)
	end

	local function AddFromInput()
		local itemID = ns.ItemIDFromText(input:GetText())
		if not itemID then
			Feedback("red", L.NOT_FOUND)
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

	local box = CreateFrame("Frame", nil, list.frame, "BackdropTemplate")
	box:SetPoint("TOPLEFT", list.frame, "TOPLEFT", PAD, list.y)
	box:SetPoint("BOTTOMRIGHT", list.frame, "BOTTOMRIGHT", -PAD, 46)
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

	local empty = list:Text("GameFontDisable",
		L.LIST_EMPTY, box)
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

		row.remove = list:Button(L.REMOVE, 70, row)
		row.remove:SetHeight(20)
		row.remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.remove:SetScript("OnClick", function(self)
			ns.SetIgnored(self:GetParent().itemID, false)
		end)

		row.idText = list:Text("GameFontDisableSmall", nil, row)
		row.idText:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)

		row.name = list:Text("GameFontHighlight", nil, row)
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
			return Color("gray", L.LOADING)
		end
		local quality = C_Item.GetItemQualityByID(itemID)
		local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		return qc and (qc.hex .. name .. "|r") or name
	end

	local clearBtn = list:Button(L.REMOVE_ALL, 110)
	clearBtn:SetPoint("BOTTOMLEFT", list.frame, "BOTTOMLEFT", PAD, 14)
	clearBtn:SetScript("OnClick", function() StaticPopup_Show("SELECTIVELOOT_CLEAR") end)

	local function RefreshList()
		local ids = {}
		for id in pairs(ns.ignored) do ids[#ids + 1] = id end
		table.sort(ids, function(a, b)
			local na, nb = C_Item.GetItemNameByID(a) or "", C_Item.GetItemNameByID(b) or ""
			if na ~= nb then return na < nb end
			return a < b
		end)

		listTitle:SetText(L.LIST_TITLE_COUNT:format(#ids))
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
			ns.Print(ICON.no .. " " .. Color("red", L.NO_BIND_IN_COMBAT))
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
			ns.Print(ICON.no .. " " .. Color("red", L.NO_BIND_IN_COMBAT))
			return
		end
		capturing = true
		self:SetText(L.KEY_CANCEL)
		keyClearBtn:Hide()
		keyLine:SetText(ICON.wait .. " " .. Color("gold", L.KEY_PRESS))
		self:EnableKeyboard(true)
		self:SetPropagateKeyboardInput(false)
		self:SetScript("OnKeyDown", OnCaptureKey)
	end)

	keyClearBtn:SetScript("OnClick", function() ns.ApplyBinding(nil) end)

	StaticPopupDialogs["SELECTIVELOOT_REBIND"] = {
		text = L.REBIND_PROMPT,
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, combo) ns.ApplyBinding(combo) end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs["SELECTIVELOOT_CLEAR"] = {
		text = L.CLEAR_PROMPT,
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

		SetStatus(filterLine, db.enabled, L.FILTER_ON, L.FILTER_OFF)
		filterBtn:SetText(db.enabled and L.DISABLE or L.ENABLE)

		local autoLootOff = not ns.IsGameAutoLootOn()
		SetStatus(autoLootLine, autoLootOff, L.AUTOLOOT_OFF, L.AUTOLOOT_ON)
		autoLootBtn:SetShown(not autoLootOff)

		if capturing then return end
		local key = GetBindingKey(ns.BINDING)
		SetStatus(keyLine, key ~= nil, L.KEY_SET:format(key and GetBindingText(key) or ""), L.KEY_NONE)
		keyBtn:SetText(key and L.KEY_CHANGE or L.KEY_DEFINE)
		keyClearBtn:SetShown(key ~= nil)
	end

	local function RefreshMain()
		RefreshStatus()
		for _, cb in ipairs(checkboxes) do
			cb:SetChecked(ns.db[cb.key])
		end
		RefreshLanguage()

		manageBtn:SetText(L.BTN_LIST_PAGE:format(ns.IgnoredCount()))
	end

	local function RefreshFeedPage()
		-- Tout le reste de la page dépend de « afficher le butin »
		local feedOn = ns.db.feed
		for _, s in ipairs(sliders) do
			-- Ne pas repositionner un curseur déjà à la bonne valeur (celui qu'on fait glisser).
			if math.abs(s:GetValue() - ns.db[s.key]) > s.step / 2 then
				s:SetValue(ns.db[s.key])
			end
			s:SetEnabled(feedOn)
			s:SetAlpha(feedOn and 1 or 0.5)
		end
		feedLeftCb:SetEnabled(feedOn)
		feedLeftCb.label:SetFontObject(feedOn and "GameFontHighlight" or "GameFontDisable")
		resetPosBtn:SetEnabled(feedOn)
	end

	local function Refresh()
		if not ns.db then return end
		RefreshMain()
		RefreshFeedPage()
		RefreshList()
	end

	local pages = { main, feedPage, list }

	-- L'aperçu de la liste du butin reste affiché tant qu'une page de l'addon est ouverte.
	local function AnyPageVisible()
		for _, page in ipairs(pages) do
			if page.frame:IsVisible() then return true end
		end
		return false
	end

	local function UpdatePreview()
		if ns.SetFeedPreview then ns.SetFeedPreview(AnyPageVisible()) end
	end

	for _, page in ipairs(pages) do
		page.frame:SetScript("OnShow", function()
			Refresh()
			UpdatePreview()
		end)
		page.frame:SetScript("OnHide", function()
			if capturing then StopCapture() end
			-- En passant d'une page de l'addon à une autre, la suivante s'affiche juste après.
			C_Timer.After(0, UpdatePreview)
		end)
		page.frame.OnCommit = function() end
		page.frame.OnRefresh = Refresh
	end
	main.frame.OnDefault = function() ns.ResetOptions() end
	feedPage.frame.OnDefault = function() ns.ResetFeedOptions() end
	list.frame.OnDefault = function() end

	ns.On(function(what)
		if what == "LOOTED" or what == "LEFT" then return end
		if AnyPageVisible() then
			Refresh()
			if what == "OPTIONS" then UpdatePreview() end
		end
	end)

	---------------------------------------------------------------------------
	-- Enregistrement dans Options > AddOns
	---------------------------------------------------------------------------
	local category, feedCategory, listCategory
	if Settings and Settings.RegisterCanvasLayoutCategory then
		category = Settings.RegisterCanvasLayoutCategory(main.frame, main.frame.name)
		Settings.RegisterAddOnCategory(category)
		if Settings.RegisterCanvasLayoutSubcategory then
			feedCategory = Settings.RegisterCanvasLayoutSubcategory(category, feedPage.frame, feedPage.frame.name)
			listCategory = Settings.RegisterCanvasLayoutSubcategory(category, list.frame, list.frame.name)
		end
	end

	-- Repli (client sans menu Options moderne) : fenêtre autonome
	local function ShowStandalone(frame)
		frame:SetParent(UIParent)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER")
		frame:SetSize(640, 600)
		frame:Show()
	end

	function ns.OpenOptions()
		if category and Settings.OpenToCategory then
			Settings.OpenToCategory(category:GetID())
		else
			feedPage.frame:Hide()
			list.frame:Hide()
			if main.frame:IsShown() then main.frame:Hide() else ShowStandalone(main.frame) end
		end
	end

	local function OpenSubpage(subcategory, page)
		if subcategory and SettingsPanel and SettingsPanel.SelectCategory then
			SettingsPanel:SelectCategory(subcategory)
		elseif subcategory then
			Settings.OpenToCategory(subcategory:GetID())
		else
			for _, p in ipairs(pages) do p.frame:Hide() end
			ShowStandalone(page.frame)
		end
	end

	feedPageBtn:SetScript("OnClick", function() OpenSubpage(feedCategory, feedPage) end)
	manageBtn:SetScript("OnClick", function() OpenSubpage(listCategory, list) end)
end

ns.On(function(what)
	if what == "INIT" then Build() end
end)

-- Menu des addons (bouton de la minicarte) et accès global
function SelectiveLoot_OpenOptions()
	if ns.OpenOptions then ns.OpenOptions() end
end
