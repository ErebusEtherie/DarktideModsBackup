return {
	mod_name = {
		en = "Custom Character Bots",
	},
	mod_description = {
		en = "Uses your saved characters as Solo Play bot profiles, with BetterBots integration and optional experimental behavior helpers.",
	},
	auto_fetch_on_load = {
		en = "Auto-cache saved characters",
	},
	auto_fetch_on_load_description = {
		en = "Automatically fetches your saved character list when the profile service becomes available, including character select and the Mourningstar.",
	},
	detailed_logging = {
		en = "Show debug status",
	},
	detailed_logging_description = {
		en = "Shows automatic cache status in chat and writes detailed profile summaries to the game log.",
	},
	enable_one_bot_swap = {
		en = "Enable Custom Character Bots",
	},
	enable_one_bot_swap_description = {
		en = "Main switch for replacing vanilla bot profiles with your cached saved characters.",
	},
	solo_only = {
		en = "Solo host only",
	},
	solo_only_description = {
		en = "Only replace bots when the session reports a local Solo Play host type.",
	},
	skip_experimental_archetypes = {
		en = "Use core classes only",
	},
	skip_experimental_archetypes_description = {
		en = "Only auto-select Veteran, Zealot, Psyker, or Ogryn saved characters. Disable this when testing newer classes.",
	},
	allow_duplicate_profiles = {
		en = "Allow duplicate characters",
	},
	allow_duplicate_profiles_description = {
		en = "Allow multiple bots to use the same saved character profile in one test run.",
	},
	combat_loadout_mode = {
		en = "Combat loadout mode",
	},
	combat_loadout_mode_description = {
		en = "Controls whether bots keep saved weapons with compatibility patches or receive safer vanilla bot weapons.",
	},
	combat_loadout_bot_safe_weapons = {
		en = "Bot-safe weapons",
	},
	combat_loadout_saved_loadout = {
		en = "Saved loadout weapons",
	},
	enable_bot_vo_support = {
		en = "Voice and tagging support",
	},
	enable_bot_vo_support_description = {
		en = "Lets custom bots call out low ammo, low health, tagged specialists, stim thanks, and revive thanks.",
	},
	enable_playerlike_behavior = {
		en = "Experimental CCB bot behavior",
	},
	enable_playerlike_behavior_description = {
		en = "Only runs when Experimental features is enabled and BetterBots behavior mode is off. Lets CCB try its own scouting, sprinting, dodging, looting, ability use, and tagging helpers.",
	},
	prefer_betterbots_behavior = {
		en = "BetterBots plugin mode",
	},
	prefer_betterbots_behavior_description = {
		en = "Recommended. Custom Character Bots provides saved-character profiles, while BetterBots handles combat, revives, abilities, grenades, movement, pickups, and safety behavior.",
	},
	enable_experimental_features = {
		en = "Experimental features",
	},
	enable_experimental_features_description = {
		en = "Allows CCB's own unfinished behavior-learning and player-like behavior systems to run. Leave this off when testing the BetterBots plugin path.",
	},
	enable_behavior_learning = {
		en = "Experimental behavior learning",
	},
	enable_behavior_learning_description = {
		en = "Only records and applies lightweight per-character play tendencies when Experimental features is enabled.",
	},
	preferred_profile_index = {
		en = "Preferred character index",
	},
	preferred_profile_index_description = {
		en = "Use the numbered character from /ccb_profiles, or choose random non-duplicate selection.",
	},
	preferred_profile_index_random = {
		en = "Random",
	},
	preferred_profile_index_1 = {
		en = "Character #1",
	},
	preferred_profile_index_2 = {
		en = "Character #2",
	},
	preferred_profile_index_3 = {
		en = "Character #3",
	},
	preferred_profile_index_4 = {
		en = "Character #4",
	},
	preferred_profile_index_5 = {
		en = "Character #5",
	},
	preferred_profile_index_6 = {
		en = "Character #6",
	},
	preferred_profile_index_7 = {
		en = "Character #7",
	},
	preferred_profile_index_8 = {
		en = "Character #8",
	},
	max_bots_to_swap = {
		en = "Bots to replace",
	},
	max_bots_to_swap_description = {
		en = "Maximum number of bot slots to replace with saved characters after each /ccb_reset.",
	},
	keybind_fetch_profiles = {
		en = "Refresh saved characters",
	},
	keybind_fetch_profiles_description = {
		en = "Runs the same saved-character lookup as the /ccb_profiles chat command.",
	},
}
