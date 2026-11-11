-- SelectiveLoot: translations. English is the reference language: any text missing
-- from another language falls back to English.
--
-- Language choice (SelectiveLootDB.language):
--   "auto" : game language (French client -> French, anything else -> English)
--   "enUS" / "frFR" : forced
-- The choice applies when the interface loads; changing it asks for a /reload.

local ADDON, ns = ...

local LOCALES = {}
ns.LOCALES = LOCALES

LOCALES.enUS = {
	SEP = ": ",
	SECRET = "(hidden)",
	ITEM_FALLBACK = "item #%d",
	BINDING_NAME = "Ignore / loot the hovered item",

	-- Chat
	NOW_IGNORED = "ignored when looting",
	NOW_LOOTED = "looted again",
	LIST_CLEARED = "ignore list cleared: everything will be looted.",
	HOVER_FIRST = "hover over an item first (bags, loot, bank…).",
	ITEM_NOT_FOUND = "item not found.",
	ITEM_NOT_FOUND_HINT = " Use a link (Shift+click) or an item ID.",
	DEBUG_ON = "loot trace enabled.",
	DEBUG_ON_HINT = " Type %s again to stop it.",
	DEBUG_STATE = "state: filter %s, game auto loot %s, %d ignored item(s)",
	DEBUG_OFF = "loot trace stopped.",
	WORD_ON = "on",
	WORD_OFF = "off",
	FILTER_ON_MSG = "filter enabled.",
	FILTER_OFF_MSG = "filter disabled: everything is looted normally.",
	AUTOLOOT_WARNING = "the game's auto loot is on: the filter can't work.",
	AUTOLOOT_WARNING_HINT = " Type %s to fix it.",
	NO_BIND_IN_COMBAT = "key bindings can't be changed in combat.",
	FEED_UNLOCKED = "loot frame unlocked.",
	FEED_UNLOCKED_HINT = " Drag it, then type %s to lock it.",
	FEED_LOCKED = "loot frame locked.",

	-- Tooltips
	TT_IGNORED = "Ignored when looting",
	TT_IGNORED_OFF = "Ignored when looting (filter off)",
	TT_LOOTED = "Looted",
	TT_LEFT_ONE = " — %d ignored item left",
	TT_LEFT_MANY = " — %d ignored items left",
	TT_NOT_LOOTED = "Not looted yet",

	-- Loot display
	FEED_PREVIEW_LABEL = "Loot preview",
	FEED_PREVIEW_DRAG = "(drag the frame)",
	FEED_LEFT_ON_CORPSE = "Left on the corpse",
	PREVIEW_ITEM1 = "Light Leather",
	PREVIEW_ITEM2 = "Traveler's Boots",
	PREVIEW_MONEY = "1 Silver 12 Copper",
	PREVIEW_ITEM3 = "Broken Fang",

	-- Options: main page
	SUBTITLE = "Loots everything except the items you chose to ignore.",
	H_STATUS = "Status",
	FILTER_ON = "Filter on",
	FILTER_OFF = "Filter off: everything is looted normally",
	ENABLE = "Enable",
	DISABLE = "Disable",
	AUTOLOOT_OFF = "Game auto loot off",
	AUTOLOOT_ON = "Game auto loot on: filter blocked",
	FIX = "Fix",
	KEY_SET = "Key binding: %s",
	KEY_NONE = "No key binding set",
	KEY_CHANGE = "Change…",
	KEY_DEFINE = "Set…",
	KEY_CLEAR = "Clear",
	KEY_CANCEL = "Cancel",
	KEY_PRESS = "Press the key you want… (Esc to cancel)",
	H_TOOLTIPS = "Tooltips and confirmations",
	OPT_CORPSE = "Show “Looted” on corpses",
	OPT_CORPSE_DESC = "Green line in the tooltip of a corpse you already looted.",
	OPT_UNLOOTED = "Flag corpses you haven't looted yet",
	OPT_UNLOOTED_DESC = "Yellow line in the tooltip while there is still loot for you.",
	OPT_BIND = "Automatically confirm bind-on-pickup items",
	OPT_BIND_DESC = "Otherwise, the game asks you to confirm every time.",
	H_LANGUAGE = "Language",
	LANG_AUTO = "Automatic (game language)",
	H_PAGES = "Other pages",
	BTN_FEED_PAGE = "Loot display…",
	BTN_LIST_PAGE = "Ignored items (%d)…",
	BYPASS_HINT = "Tip: Shift+click a corpse to loot everything, ignored items included.",
	RELOAD_PROMPT = "SelectiveLoot: the new language applies after reloading the interface.\n\nReload now?",
	REBIND_PROMPT = "The key %s is already used by:\n“%s”\n\nReplace it with SelectiveLoot?",

	-- Options: loot display page
	PAGE_FEED = "Loot display",
	FEED_SUBTITLE = "On-screen list of what you loot. The preview stays visible while the options are open.",
	H_DISPLAY = "Display",
	OPT_FEED = "Show looted items on screen",
	OPT_FEED_DESC = "Replaces the loot window: each line fades out after a few seconds.",
	OPT_FEED_LEFT = "Also show ignored items left behind",
	OPT_FEED_LEFT_DESC = "Grayed out, with a red cross.",
	H_APPEARANCE = "Appearance",
	SL_SIZE = "Size",
	SL_TIME = "Display time",
	SL_LINES = "Maximum lines",
	SL_ALPHA = "Name plate opacity",
	H_POSITION = "Position",
	POS_HINT = "Drag the gold-framed preview to place it.\nIn game: hold %s and drag the list with the left mouse button.",
	RESET_POS = "Default position",

	-- Options: ignored items page
	PAGE_LIST = "Ignored items",
	LIST_TITLE_COUNT = "Ignored items (%d)",
	LIST_SUBTITLE = "This character's own list. These items stay on corpses, mining nodes and herbs.",
	LIST_PLACEHOLDER = "ID, link, or drop an item here",
	ADD = "Add",
	ALREADY = "Already in the list.",
	ADDED = "Added.",
	NOT_FOUND = "Item not found.",
	LIST_EMPTY = "No ignored items.\n\nHover over an item and press your key binding,\nor drop it in the field above.",
	REMOVE = "Remove",
	LOADING = "Loading…",
	REMOVE_ALL = "Remove all",
	CLEAR_PROMPT = "Remove every item from the ignore list?\n\nEverything will be looted again.",
}

LOCALES.frFR = {
	SEP = " : ",
	SECRET = "(masqué)",
	ITEM_FALLBACK = "objet #%d",
	BINDING_NAME = "Ignorer / ramasser l'objet survolé",

	-- Chat
	NOW_IGNORED = "ignoré au ramassage",
	NOW_LOOTED = "ramassé à nouveau",
	LIST_CLEARED = "liste d'ignorés vidée : tout sera ramassé.",
	HOVER_FIRST = "survole d'abord un objet (sac, butin, banque…).",
	ITEM_NOT_FOUND = "objet introuvable.",
	ITEM_NOT_FOUND_HINT = " Utilise un lien (Maj+clic) ou un ID.",
	DEBUG_ON = "trace des fouilles activée.",
	DEBUG_ON_HINT = " Retape %s pour l'arrêter.",
	DEBUG_STATE = "état : filtre %s, butin auto du jeu %s, %d objet(s) ignoré(s)",
	DEBUG_OFF = "trace des fouilles arrêtée.",
	WORD_ON = "activé",
	WORD_OFF = "désactivé",
	FILTER_ON_MSG = "filtre activé.",
	FILTER_OFF_MSG = "filtre désactivé : tout est ramassé normalement.",
	AUTOLOOT_WARNING = "le butin automatique du jeu est activé : le filtre ne peut pas fonctionner.",
	AUTOLOOT_WARNING_HINT = " Tape %s pour corriger.",
	NO_BIND_IN_COMBAT = "impossible de changer un raccourci en combat.",
	FEED_UNLOCKED = "cadre du butin déplaçable.",
	FEED_UNLOCKED_HINT = " Glisse-le, puis tape %s pour le verrouiller.",
	FEED_LOCKED = "cadre du butin verrouillé.",

	-- Infobulles
	TT_IGNORED = "Ignoré au ramassage",
	TT_IGNORED_OFF = "Ignoré au ramassage (filtre désactivé)",
	TT_LOOTED = "Fouillé",
	TT_LEFT_ONE = " — %d objet ignoré laissé",
	TT_LEFT_MANY = " — %d objets ignorés laissés",
	TT_NOT_LOOTED = "Pas encore fouillé",

	-- Affichage du butin
	FEED_PREVIEW_LABEL = "Aperçu du butin",
	FEED_PREVIEW_DRAG = "(glisse le cadre)",
	FEED_LEFT_ON_CORPSE = "Laissé sur le corps",
	PREVIEW_ITEM1 = "Cuir léger",
	PREVIEW_ITEM2 = "Bottes du voyageur",
	PREVIEW_MONEY = "1 pa 12 pc",
	PREVIEW_ITEM3 = "Croc brisé",

	-- Options : page principale
	SUBTITLE = "Ramasse tout le butin, sauf les objets que tu as choisi d'ignorer.",
	H_STATUS = "État",
	FILTER_ON = "Filtre actif",
	FILTER_OFF = "Filtre désactivé : tout est ramassé normalement",
	ENABLE = "Activer",
	DISABLE = "Désactiver",
	AUTOLOOT_OFF = "Butin automatique du jeu désactivé",
	AUTOLOOT_ON = "Butin automatique du jeu activé : filtre bloqué",
	FIX = "Corriger",
	KEY_SET = "Raccourci : %s",
	KEY_NONE = "Aucun raccourci défini",
	KEY_CHANGE = "Changer…",
	KEY_DEFINE = "Définir…",
	KEY_CLEAR = "Effacer",
	KEY_CANCEL = "Annuler",
	KEY_PRESS = "Appuie sur la touche voulue… (Échap pour annuler)",
	H_TOOLTIPS = "Infobulles et confirmations",
	OPT_CORPSE = "Afficher « Fouillé » sur les cadavres",
	OPT_CORPSE_DESC = "Ligne verte dans l'infobulle d'un cadavre que tu as déjà fouillé.",
	OPT_UNLOOTED = "Signaler les cadavres pas encore fouillés",
	OPT_UNLOOTED_DESC = "Ligne jaune dans l'infobulle tant qu'il reste du butin pour toi.",
	OPT_BIND = "Confirmer automatiquement les objets liés quand ramassés",
	OPT_BIND_DESC = "Sinon, le jeu te demande de confirmer à chaque fois.",
	H_LANGUAGE = "Langue",
	LANG_AUTO = "Automatique (langue du jeu)",
	H_PAGES = "Autres pages",
	BTN_FEED_PAGE = "Affichage du butin…",
	BTN_LIST_PAGE = "Objets ignorés (%d)…",
	BYPASS_HINT = "Astuce : Maj+clic sur un cadavre ramasse tout, objets ignorés compris.",
	RELOAD_PROMPT = "SelectiveLoot : la nouvelle langue s'applique après le rechargement de l'interface.\n\nRecharger maintenant ?",
	REBIND_PROMPT = "La touche %s est déjà utilisée par :\n« %s »\n\nLa remplacer par SelectiveLoot ?",

	-- Options : affichage du butin
	PAGE_FEED = "Affichage du butin",
	FEED_SUBTITLE = "Liste à l'écran de ce que tu ramasses. L'aperçu reste affiché tant que les options sont ouvertes.",
	H_DISPLAY = "Affichage",
	OPT_FEED = "Afficher le butin ramassé à l'écran",
	OPT_FEED_DESC = "Remplace la fenêtre de butin : chaque ligne s'efface après quelques secondes.",
	OPT_FEED_LEFT = "Afficher aussi les objets ignorés laissés",
	OPT_FEED_LEFT_DESC = "Grisés, avec une croix rouge.",
	H_APPEARANCE = "Apparence",
	SL_SIZE = "Taille",
	SL_TIME = "Durée d'affichage",
	SL_LINES = "Nombre de lignes maximum",
	SL_ALPHA = "Opacité du cartouche",
	H_POSITION = "Position",
	POS_HINT = "Glisse l'aperçu encadré en doré pour le placer.\nEn jeu : maintiens %s et fais glisser la liste avec le clic gauche.",
	RESET_POS = "Position par défaut",

	-- Options : objets ignorés
	PAGE_LIST = "Objets ignorés",
	LIST_TITLE_COUNT = "Objets ignorés (%d)",
	LIST_SUBTITLE = "Liste propre à ce personnage. Ces objets restent sur les cadavres, filons et plantes.",
	LIST_PLACEHOLDER = "ID, lien, ou glisse un objet ici",
	ADD = "Ajouter",
	ALREADY = "Déjà dans la liste.",
	ADDED = "Ajouté.",
	NOT_FOUND = "Objet introuvable.",
	LIST_EMPTY = "Aucun objet ignoré.\n\nSurvole un objet et appuie sur ton raccourci,\nou glisse-le dans le champ ci-dessus.",
	REMOVE = "Retirer",
	LOADING = "Chargement…",
	REMOVE_ALL = "Tout retirer",
	CLEAR_PROMPT = "Retirer tous les objets de la liste d'ignorés ?\n\nTout sera de nouveau ramassé.",
}

-- Languages offered in the options, in display order (names in their own language).
ns.LANGUAGES = {
	{ code = "auto" },
	{ code = "enUS", name = "English" },
	{ code = "frFR", name = "Français" },
}

function ns.ResolveLanguage(choice)
	if LOCALES[choice] then return choice end
	return GetLocale() == "frFR" and "frFR" or "enUS"
end

local current = LOCALES[ns.ResolveLanguage("auto")]
ns.language = ns.ResolveLanguage("auto")

-- ns.L.KEY: text in the active language, English if missing.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return current[key] or LOCALES.enUS[key] or key
	end,
})

function ns.SetLanguage(choice)
	ns.language = ns.ResolveLanguage(choice)
	current = LOCALES[ns.language]
end
