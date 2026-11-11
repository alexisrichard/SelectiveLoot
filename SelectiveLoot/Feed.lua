-- SelectiveLoot : affichage à l'écran du butin ramassé (et des objets ignorés laissés).
-- Remplace la fenêtre de butin, que l'addon vide et referme aussitôt.
--
-- Chaque ligne reprend le style des objets de la fenêtre de butin / des récompenses de
-- quête : icône dans un emplacement d'objet, quantité en chiffres sur l'icône, nom sur
-- le cartouche parchemin, couleur de qualité. Apparition et disparition en fondu.
--
-- Déplacement :
--   - options de l'addon ouvertes : un aperçu encadré en doré est affiché, à glisser ;
--   - en jeu : Ctrl + clic gauche maintenu sur la liste ;
--   - /sl move : déverrouille / verrouille le cadre.

local ADDON, ns = ...
local Color, ICON, L = ns.Color, ns.ICON, ns.L

local ROW_H = 44         -- hauteur d'une ligne (espacement des récompenses de quête)
local ICON_SIZE = 32
local ICON_LEFT = 12     -- marge pour que la bordure de l'emplacement reste dans le cadre
local NAME_W = 170       -- largeur du cartouche du nom
local MAX_W = ICON_LEFT + ICON_SIZE + NAME_W - 10
local APPEAR_TIME = 0.25
local FADE_TIME = 1.5
-- En bas à gauche, au-dessus du chat : hors de la zone du menu Options, que l'aperçu
-- (affiché au-dessus du menu) ne doit pas recouvrir.
local DEFAULT_POINT = { "BOTTOMLEFT", 20, 260 }

local BACKDROP = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local anchor = CreateFrame("Frame", "SelectiveLootFeed", UIParent, "BackdropTemplate")
anchor:SetWidth(MAX_W + 8)
anchor:SetFrameStrata("MEDIUM")
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(false)
anchor:RegisterForDrag("LeftButton")

local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
label:SetPoint("BOTTOM", anchor, "TOP", 0, 4)  -- au-dessus du cadre, pour ne pas cacher les lignes
label:Hide()  -- texte posé à INIT, une fois la langue connue

local unlocked = false   -- /sl move
local previewing = false -- options de l'addon ouvertes
local ctrlHeld = false   -- Ctrl enfoncé (déplacement en jeu)
local dragging = false
local active, pool = {}, {}

local function Setting(key, default)
	local v = ns.db and ns.db[key]
	if v == nil then return default end
	return v
end

-- Lignes figées (pas de fondu) : pendant un déplacement ou un aperçu.
local function Frozen()
	return unlocked or previewing or ctrlHeld or dragging
end

-- Cadre doré et souris active seulement quand on peut déplacer la liste.
local function Movable()
	return unlocked or previewing or dragging or (ctrlHeld and #active > 0)
end

local function UpdateFrame()
	local movable = Movable()
	anchor:EnableMouse(movable)
	-- Avec Ctrl en jeu, seule la hauteur des lignes affichées capte la souris.
	local capturesAll = unlocked or previewing or dragging
	local emptyTop = capturesAll and 0 or math.max(0, anchor:GetHeight() - #active * ROW_H)
	anchor:SetHitRectInsets(0, 0, emptyTop, 0)
	if movable then
		anchor:SetBackdrop(BACKDROP)
		anchor:SetBackdropColor(0, 0, 0, 0.6)
		anchor:SetBackdropBorderColor(1, 0.82, 0, 1)
	else
		anchor:SetBackdrop(nil)
	end
	label:SetShown(unlocked or previewing)
	-- Au-dessus du menu Options pendant l'aperçu, pour rester visible et déplaçable.
	anchor:SetFrameStrata(previewing and "FULLSCREEN_DIALOG" or "MEDIUM")
end

---------------------------------------------------------------------------
-- Lignes
---------------------------------------------------------------------------
local function Layout()
	local n = #active
	for i, line in ipairs(active) do
		line:ClearAllPoints()
		line:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 4, (n - i) * ROW_H)
	end
end

local function Release(line)
	line.appear:Stop()
	line.fade:Stop()
	line:Hide()
	line.key, line.preview, line.data = nil, nil, nil
	for i, l in ipairs(active) do
		if l == line then
			table.remove(active, i)
			break
		end
	end
	pool[#pool + 1] = line
	Layout()
	UpdateFrame()
end

local function NewLine()
	local line = table.remove(pool)
	if line then return line end

	line = CreateFrame("Frame", nil, anchor)
	line:SetSize(MAX_W, ROW_H - 2)

	-- Icône dans un emplacement d'objet (comme un bouton de sac ou de butin)
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetSize(ICON_SIZE, ICON_SIZE)
	line.icon:SetPoint("LEFT", line, "LEFT", ICON_LEFT, 0)

	line.slot = line:CreateTexture(nil, "OVERLAY")
	line.slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	line.slot:SetSize(ICON_SIZE * 64 / 37, ICON_SIZE * 64 / 37)
	line.slot:SetPoint("CENTER", line.icon, "CENTER", 0, -1)

	-- Liseré de qualité (vert, bleu, violet…)
	line.border = line:CreateTexture(nil, "OVERLAY", nil, 1)
	line.border:SetTexture("Interface\\Common\\WhiteIconFrame")
	line.border:SetAllPoints(line.icon)

	-- Croix rouge des objets laissés
	line.cross = line:CreateTexture(nil, "OVERLAY", nil, 2)
	line.cross:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
	line.cross:SetSize(16, 16)
	line.cross:SetPoint("TOPLEFT", line.icon, "TOPLEFT", -4, 4)

	line.count = line:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	line.count:SetPoint("BOTTOMRIGHT", line.icon, "BOTTOMRIGHT", -1, 2)
	line.count:SetJustifyH("RIGHT")

	-- Cartouche parchemin du nom (récompenses de quête, fenêtre de butin)
	line.nameFrame = line:CreateTexture(nil, "BACKGROUND")
	line.nameFrame:SetTexture("Interface\\QuestFrame\\UI-QuestItemNameFrame")
	line.nameFrame:SetSize(NAME_W, 62)
	line.nameFrame:SetPoint("LEFT", line.icon, "RIGHT", -10, 0)

	line.name = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	line.name:SetWidth(NAME_W - 30)
	line.name:SetJustifyH("LEFT")
	line.name:SetMaxLines(2)

	line.sub = line:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
	line.sub:SetJustifyH("LEFT")
	line.sub:SetText(L.FEED_LEFT_ON_CORPSE)

	line.appear = line:CreateAnimationGroup()
	local fadeIn = line.appear:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(APPEAR_TIME)

	line.fade = line:CreateAnimationGroup()
	line.alpha = line.fade:CreateAnimation("Alpha")
	line.alpha:SetFromAlpha(1)
	line.alpha:SetToAlpha(0)
	line.alpha:SetDuration(FADE_TIME)
	line.fade:SetScript("OnFinished", function() Release(line) end)
	return line
end

local function Render(line)
	local d = line.data
	local qc = d.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[d.quality]

	line.icon:SetTexture(d.icon)
	line.icon:SetDesaturated(d.left and true or false)
	line.cross:SetShown(d.left and true or false)
	line.count:SetText(line.n > 1 and line.n or "")

	if qc and not d.left and not d.money and d.quality >= 2 then
		line.border:SetVertexColor(qc.r, qc.g, qc.b)
		line.border:Show()
	else
		line.border:Hide()
	end

	if d.left then
		line.name:SetText(Color("gray", d.name))
	elseif d.money then
		line.name:SetText(Color("white", d.name))
	else
		line.name:SetText((qc and qc.hex or "|cffffffff") .. d.name .. "|r")
	end

	-- Nom centré sur le cartouche ; une seconde ligne « Laissé sur le corps » si besoin.
	line.name:ClearAllPoints()
	line.sub:ClearAllPoints()
	if d.left then
		line.name:SetPoint("BOTTOMLEFT", line.nameFrame, "LEFT", 15, 1)
		line.sub:SetPoint("TOPLEFT", line.nameFrame, "LEFT", 15, -1)
		line.sub:Show()
	else
		line.name:SetPoint("LEFT", line.nameFrame, "LEFT", 15, 0)
		line.sub:Hide()
	end

	line.nameFrame:SetAlpha(Setting("feedFrameAlpha", 1))
end

-- Réaffiche la ligne et relance son fondu (sauf si la liste est figée).
local function Restart(line)
	line.fade:Stop()
	line:SetAlpha(1)
	line:Show()
	if not Frozen() then
		line.alpha:SetStartDelay(Setting("feedTime", 5))
		line.fade:Play()
	end
end

local function RefreshAll()
	for _, line in ipairs(active) do Restart(line) end
	UpdateFrame()
end

-- key : regroupe les lignes du même objet (quantités additionnées)
-- data : { icon, name, quality, left, money }
local function Push(key, data, count, preview)
	if key then
		for _, line in ipairs(active) do
			if line.key == key then
				line.n = line.n + count
				Render(line)
				Restart(line)
				return
			end
		end
	end
	while #active >= Setting("feedLines", 8) do Release(active[1]) end

	local line = NewLine()
	line.key, line.data, line.n, line.preview = key, data, count, preview
	active[#active + 1] = line
	Render(line)
	Restart(line)
	line.appear:Play()
	Layout()
	UpdateFrame()
end

local function ClearAll()
	while #active > 0 do Release(active[#active]) end
end

---------------------------------------------------------------------------
-- Entrées
---------------------------------------------------------------------------
local function OnLooted(s)
	if s.money then
		Push(nil, { icon = s.texture, name = s.name or "", money = true }, 1)
		return
	end
	local key = s.itemID and ("item:" .. s.itemID) or nil
	Push(key, { icon = s.texture, name = s.name or s.link or "?", quality = s.quality }, s.quantity)
end

local function OnLeft(s)
	local name = s.name or "?"
	local key = "left:" .. (s.itemID or name)
	Push(key, { icon = s.texture, name = name, quality = s.quality, left = true }, s.quantity)
end

-- Lignes d'exemple pour l'aperçu (retirées à la fin de l'aperçu).
local function ShowPreviewLines()
	for _, line in ipairs(active) do
		if line.preview then return end
	end
	Push(nil, { icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03", name = L.PREVIEW_ITEM1, quality = 1 }, 3, true)
	Push(nil, { icon = "Interface\\Icons\\INV_Boots_05", name = L.PREVIEW_ITEM2, quality = 2 }, 1, true)
	Push(nil, { icon = "Interface\\Icons\\INV_Misc_Coin_01", name = L.PREVIEW_MONEY, money = true }, 1, true)
	Push(nil, { icon = "Interface\\Icons\\INV_Misc_Bone_08", name = L.PREVIEW_ITEM3, quality = 0, left = true }, 2, true)
end

local function ClearPreviewLines()
	for i = #active, 1, -1 do
		if active[i].preview then Release(active[i]) end
	end
end

---------------------------------------------------------------------------
-- Position, taille et apparence
---------------------------------------------------------------------------
-- La position est enregistrée en coordonnées de l'écran (coin bas-gauche),
-- pour que changer la taille ne déplace pas la liste.
local function ApplyPosition()
	local scale = anchor:GetScale()
	local pos = ns.db.feedAnchor
	anchor:ClearAllPoints()
	if pos then
		anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1] / scale, pos[2] / scale)
	else
		anchor:SetPoint(DEFAULT_POINT[1], UIParent, DEFAULT_POINT[1], DEFAULT_POINT[2] / scale, DEFAULT_POINT[3] / scale)
	end
end

local function SavePosition()
	local scale = anchor:GetScale()
	local left, bottom = anchor:GetLeft(), anchor:GetBottom()
	if left and bottom then
		ns.db.feedAnchor = { left * scale, bottom * scale }
	end
end

local function ApplySettings()
	anchor:SetScale(Setting("feedScale", 1))
	anchor:SetHeight(Setting("feedLines", 8) * ROW_H)
	while #active > Setting("feedLines", 8) do Release(active[1]) end
	for _, line in ipairs(active) do Render(line) end
	ApplyPosition()
	Layout()
	RefreshAll()
end

function ns.ResetFeedPosition()
	ns.db.feedAnchor = nil
	ApplyPosition()
end

---------------------------------------------------------------------------
-- Modes de déplacement
---------------------------------------------------------------------------
function ns.IsFeedUnlocked()
	return unlocked
end

function ns.SetFeedUnlocked(on)
	unlocked = on and true or false
	if unlocked then
		ShowPreviewLines()
	elseif not previewing then
		ClearPreviewLines()
	end
	RefreshAll()
	if unlocked then
		ns.Print(ICON.wait .. " " .. Color("gold", L.FEED_UNLOCKED)
			.. L.FEED_UNLOCKED_HINT:format(Color("white", "/sl move")))
	else
		ns.Print(ICON.ok .. " " .. Color("green", L.FEED_LOCKED))
	end
	ns.Fire("FEED")
end

-- Aperçu affiché tant que les options de l'addon sont ouvertes.
function ns.SetFeedPreview(on)
	on = (on and ns.db and ns.db.feed) and true or false
	if on == previewing then return end
	previewing = on
	if previewing then
		ShowPreviewLines()
	elseif not unlocked then
		ClearPreviewLines()
	end
	RefreshAll()
end

anchor:SetScript("OnDragStart", function(self)
	if Movable() then
		dragging = true
		self:StartMoving()
	end
end)
anchor:SetScript("OnDragStop", function(self)
	if not dragging then return end
	self:StopMovingOrSizing()
	dragging = false
	SavePosition()
	ApplyPosition()
	RefreshAll()
end)

-- Ctrl enfoncé pendant que la liste est affichée : elle se fige, s'encadre en doré
-- et devient déplaçable. Le reste du temps, elle ne capte pas la souris.
local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function()
	local held = (IsControlKeyDown() and ns.db ~= nil and ns.db.feed) and true or false
	if held == ctrlHeld then return end
	ctrlHeld = held
	RefreshAll()
end)

---------------------------------------------------------------------------
ns.On(function(what, data)
	if what == "INIT" then
		label:SetText(L.FEED_PREVIEW_LABEL .. "  " .. Color("white", L.FEED_PREVIEW_DRAG))
		ApplySettings()
	elseif what == "OPTIONS" then
		if ns.db.feed then
			ApplySettings()
		else
			-- Affichage désactivé : plus d'aperçu ni de déplacement, liste effacée.
			unlocked, previewing = false, false
			ClearAll()
			UpdateFrame()
		end
	elseif what == "LOOTED" then
		if ns.db.feed then OnLooted(data) end
	elseif what == "LEFT" then
		if ns.db.feed and ns.db.feedLeft then OnLeft(data) end
	end
end)
