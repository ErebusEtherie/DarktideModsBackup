local mod = get_mod("CustomCharacterBots")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "enable_one_bot_swap",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "max_bots_to_swap",
				type = "numeric",
				default_value = 1,
				range = { 1, 3 },
				unit_text = "bots",
				decimals_number = 0,
			},
			{
				setting_id = "preferred_profile_index",
				type = "dropdown",
				default_value = 0,
				options = {
					{ text = "preferred_profile_index_random", value = 0 },
					{ text = "preferred_profile_index_1", value = 1 },
					{ text = "preferred_profile_index_2", value = 2 },
					{ text = "preferred_profile_index_3", value = 3 },
					{ text = "preferred_profile_index_4", value = 4 },
					{ text = "preferred_profile_index_5", value = 5 },
					{ text = "preferred_profile_index_6", value = 6 },
					{ text = "preferred_profile_index_7", value = 7 },
					{ text = "preferred_profile_index_8", value = 8 },
				},
			},
			{
				setting_id = "combat_loadout_mode",
				type = "dropdown",
				default_value = "saved_loadout",
				options = {
					{ text = "combat_loadout_saved_loadout", value = "saved_loadout" },
					{ text = "combat_loadout_bot_safe_weapons", value = "bot_safe_weapons" },
				},
			},
			{
				setting_id = "allow_duplicate_profiles",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "skip_experimental_archetypes",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "solo_only",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "prefer_betterbots_behavior",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "enable_experimental_features",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "enable_playerlike_behavior",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "enable_behavior_learning",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "enable_bot_vo_support",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "auto_fetch_on_load",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "detailed_logging",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "keybind_fetch_profiles",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "fetch_profiles",
			},
		},
	},
}
