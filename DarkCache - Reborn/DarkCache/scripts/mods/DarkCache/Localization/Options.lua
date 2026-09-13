-- The measured figures are appended to these tooltips at runtime by
-- DarkCache_menu, which can refresh them without a restart.
return {
	i18n_enabled = {
		en = "Enable caching",
		fr = "Activer la mise en cache",
	},
	i18n_enabled_tooltip = {
		en = "Master switch. Off, the game behaves exactly as it does unmodded.",
		fr = "Interrupteur principal. Désactivé, le jeu se comporte exactement comme sans le mod.",
	},

	-- ---------------------------------------------------------------- icons
	i18n_group_icons = {
		en = "Item icons",
		fr = "Icônes d'objets",
	},
	i18n_memory_budget = {
		en = "Video memory allowance (MB)",
		fr = "Mémoire vidéo allouée (Mo)",
	},
	i18n_memory_budget_tooltip = {
		en = "Video memory the icon cache may use; when it is full the icon you looked at longest ago goes. Roughly 25 icons per 1.6 MB. Type /darkcache to see what is held.",
		fr = "Mémoire vidéo que le cache d'icônes peut occuper ; une fois pleine, l'icône vue il y a le plus longtemps est libérée. Environ 25 icônes par 1,6 Mo. Tapez /darkcache pour voir ce qui est retenu.",
	},
	megabytes = {
		en = "MB",
		fr = "Mo",
	},
	i18n_cache_cosmetics = {
		en = "Cosmetics",
		fr = "Cosmétiques",
	},
	i18n_cache_cosmetics_tooltip = {
		en = "Outfits, headgear, torso, legs, sets. The slowest icons to render, and most of what fills a vendor.",
		fr = "Tenues, couvre-chefs, torse, jambes, ensembles. Les icônes les plus lentes à rendre, et l'essentiel de ce qui remplit un marchand.",
	},
	i18n_cache_weapons = {
		en = "Weapons, skins and companion gear",
		fr = "Armes, apparences et équipement de compagnon",
	},
	i18n_cache_weapons_tooltip = {
		en = "Weapons, gadgets, weapon skins, trinkets and companion gear.",
		fr = "Armes, gadgets, apparences d'armes, breloques et équipement de compagnon.",
	},
	i18n_cache_portraits = {
		en = "Player portraits",
		fr = "Portraits de joueurs",
	},
	i18n_cache_portraits_tooltip = {
		en = "Character portraits: social menu, lobby, end of mission, character creation.",
		fr = "Portraits de personnages : menu social, lobby, fin de mission, création de personnage.",
	},
	i18n_clear_cache = {
		en = "Empty the icon cache now",
		fr = "Vider le cache d'icônes maintenant",
	},
	i18n_clear_cache_tooltip = {
		en = "Releases every cached icon at once. It also empties itself at every loading screen.",
		fr = "Libère d'un coup toutes les icônes en cache. Il se vide aussi tout seul à chaque écran de chargement.",
	},

	-- --------------------------------------------------------------- levels
	i18n_group_levels = {
		en = "Levels kept in memory",
		fr = "Niveaux gardés en mémoire",
	},
	i18n_group_levels_tooltip = {
		en = "Keeping a level in memory means it is not read off the disk again every time you come back to it.",
		fr = "Garder un niveau en mémoire évite de le relire sur le disque à chaque retour.",
	},

	-- Appended to the tooltips above from what the mod measured on this machine.
	i18n_level_cost = {
		en = "Measured here: %d MB video memory and %d MB system memory.",
		fr = "Mesuré ici : %d Mo de mémoire vidéo et %d Mo de mémoire système.",
	},
	i18n_level_cost_time = {
		en = "Loads in %s s instead of %s s.",
		fr = "Se charge en %s s au lieu de %s s.",
	},
	i18n_level_cost_unknown = {
		en = "Its cost is measured the first time it loads, and shown here afterwards.",
		fr = "Son coût est mesuré au premier chargement, puis affiché ici.",
	},
	i18n_levels_total = {
		en = "With what is enabled here: about %d MB video memory and %d MB system memory held.",
		fr = "Avec ce qui est activé ici : environ %d Mo de mémoire vidéo et %d Mo de mémoire système retenus.",
	},
	i18n_levels_total_unknown = {
		en = "Each level's cost is measured the first time it loads.",
		fr = "Le coût de chaque niveau est mesuré à son premier chargement.",
	},

	i18n_group_advanced = {
		en = "Advanced",
		fr = "Avancé",
	},
	i18n_capture_frame_delay = {
		en = "Frames before capture",
		fr = "Images avant capture",
	},
	i18n_capture_frame_delay_tooltip = {
		en = "How long an item settles before its picture is taken. 5 is the game's own value; lower is faster but can freeze an icon on a half-loaded texture.",
		fr = "Temps laissé à un objet pour se stabiliser avant d'être photographié. 5 est la valeur du jeu ; plus bas est plus rapide mais peut figer une icône sur une texture à moitié chargée.",
	},
	i18n_debug = {
		en = "Developer report",
		fr = "Rapport de développement",
	},
	i18n_debug_tooltip = {
		en = "Enables the /debugdarkcache chat command, which reports memory and load times per level and per icon family. Also logs cache activity to the game log. With this off the command is not offered at all.",
		fr = "Active la commande de chat /debugdarkcache, qui détaille mémoire et temps de chargement par niveau et par famille d'icônes. Journalise aussi l'activité du cache. Désactivée, la commande n'est pas proposée.",
	},
}
