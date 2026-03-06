local mod = get_mod("machine_gods_beacon")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "environment_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "environment_control_mode",
						type = "dropdown",
						default_value = "all",
						options = {
							{text = "mode_none", value = "none"},
							{text = "mode_all", value = "all"},
							{text = "mode_normal", value = "normal"},
							{text = "mode_modified", value = "modified"},
						},
						title = "environment_control_mode_title",
						tooltip = "environment_control_mode_tooltip",
					},
				},
			},
			{
				setting_id = "light_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "light_control_mode",
						type = "dropdown",
						default_value = "all",
						options = {
							{text = "mode_none", value = "none"},
							{text = "mode_all", value = "all"},
							{text = "mode_normal", value = "normal"},
							{text = "mode_modified", value = "modified"},
						},
						title = "light_control_mode_title",
					},
					{setting_id = "light_percentage", type = "numeric", default_value = 33, range = {0, 100}, title = "light_percentage_title"},
					{
						setting_id = "light_selection",
						type = "dropdown",
						default_value = "alternating",
						options = {
							{text = "light_selection_incremental", value = "incremental"},
							{text = "light_selection_alternating", value = "alternating"},
							{text = "light_selection_spread", value = "spread"},
							{text = "light_selection_random", value = "random"},
						},
						title = "light_selection_title",
					},
				},
			},
			{
				setting_id = "flicker_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "light_state",
						type = "dropdown",
						default_value = "flicker_random",
						options = {
							{text = "light_state_static", value = "static"},
							{text = "light_state_flicker", value = "flicker"},
							{text = "light_state_flicker_cascade", value = "flicker_cascade"},
							{text = "light_state_flicker_random", value = "flicker_random"},
						},
						title = "light_state_title",
					},
					{
						setting_id = "flicker_default",
						type = "dropdown",
						default_value = "on",
						options = {{text = "flicker_default_on", value = "on"}, {text = "flicker_default_off", value = "off"}},
						title = "flicker_default_title",
					},
					{
						setting_id = "flicker_interval",
						type = "numeric",
						default_value = 5.0,
						range = {0.5, 30.0},
						decimals_number = 1,
						title = "flicker_interval_title",
					},
					{
						setting_id = "flicker_percentage",
						type = "numeric",
						default_value = 33,
						range = {1, 100},
						title = "flicker_percentage_title",
					},
					{
						setting_id = "flicker_duration",
						type = "numeric",
						default_value = 0.5,
						range = {0.5, 3.0},
						decimals_number = 2,
						title = "flicker_duration_title",
					},
					{
						setting_id = "flicker_cooldown",
						type = "numeric",
						default_value = 3.0,
						range = {0.5, 30.0},
						decimals_number = 1,
						title = "flicker_cooldown_title",
					},
					{setting_id = "enable_stutter", type = "checkbox", default_value = false, title = "enable_stutter_title"},
					{setting_id = "stutter_count", type = "numeric", default_value = 3, range = {2, 10}, title = "stutter_count_title"},
				},
			},
			{
				setting_id = "debug_group",
				type = "group",
				sub_widgets = {{setting_id = "debug_mode", type = "checkbox", default_value = false, title = "debug_mode_title"}},
			},
		},
	},
}
