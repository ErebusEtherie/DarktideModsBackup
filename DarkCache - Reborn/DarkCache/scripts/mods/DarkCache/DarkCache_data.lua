local mod = get_mod("DarkCache")

return {
	name = mod:localize("i18n_mod_title"),
	description = mod:localize("i18n_mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		localize = true,
		widgets = {
			{
				setting_id = "opt_enabled",
				type = "checkbox",
				title = "i18n_enabled",
				tooltip_text = "i18n_enabled_tooltip",
				default_value = true,
			},
			{
				setting_id = "opt_group_icons",
				type = "group",
				title = "i18n_group_icons",
				sub_widgets = {
					{
						setting_id = "opt_memory_budget",
						type = "numeric",
						title = "i18n_memory_budget",
						tooltip_text = "i18n_memory_budget_tooltip",
						default_value = 256,
						range = {32, 2048},
						decimals_number = 0,
						unit_text = "megabytes",
					},
					{
						setting_id = "opt_cache_cosmetics",
						type = "checkbox",
						title = "i18n_cache_cosmetics",
						tooltip_text = "i18n_cache_cosmetics_tooltip",
						default_value = true,
					},
					{
						setting_id = "opt_cache_weapons",
						type = "checkbox",
						title = "i18n_cache_weapons",
						tooltip_text = "i18n_cache_weapons_tooltip",
						default_value = true,
					},
					{
						setting_id = "opt_cache_portraits",
						type = "checkbox",
						title = "i18n_cache_portraits",
						tooltip_text = "i18n_cache_portraits_tooltip",
						default_value = true,
					},
					{
						setting_id = "opt_clear_cache",
						type = "keybind",
						title = "i18n_clear_cache",
						tooltip_text = "i18n_clear_cache_tooltip",
						default_value = {},
						keybind_global = true,
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "clear_cache",
					},
				},
			},
			{
				setting_id = "opt_group_levels",
				type = "group",
				title = "i18n_group_levels",
				sub_widgets = {
					{
						setting_id = "opt_cache_hub",
						type = "checkbox",
						title = "i18n_cache_hub",
						tooltip_text = "i18n_cache_hub_tooltip",
						default_value = true,
					},
					{
						setting_id = "opt_cache_psykhanium",
						type = "checkbox",
						title = "i18n_cache_psykhanium",
						tooltip_text = "i18n_cache_psykhanium_tooltip",
						default_value = true,
					},
				},
			},
			{
				setting_id = "opt_group_advanced",
				type = "group",
				title = "i18n_group_advanced",
				sub_widgets = {
					{
						setting_id = "opt_capture_frame_delay",
						type = "numeric",
						title = "i18n_capture_frame_delay",
						tooltip_text = "i18n_capture_frame_delay_tooltip",
						default_value = 5,
						range = {1, 8},
						decimals_number = 0,
					},
					{
						setting_id = "opt_debug",
						type = "checkbox",
						title = "i18n_debug",
						tooltip_text = "i18n_debug_tooltip",
						default_value = false,
					},
				},
			},
		},
	},
}
