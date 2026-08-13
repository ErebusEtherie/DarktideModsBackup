local mod = get_mod("GauntletTrajectory")

local data = {
	name = mod:localize("mod_title"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "trajectory_options",
				type       = "group",
				sub_widgets = {
					{
						setting_id      = "arc_show_delay",
						type            = "numeric",
						default_value   = 0.1,
						range           = { 0, 2 },
						decimals_number = 2,
						step_size_value = 0.01,
						title           = "arc_show_delay",
						tooltip         = "arc_show_delay_description",
					},
					{
						setting_id    = "stop_on_impact",
						type          = "checkbox",
						default_value = true,
						title         = "stop_on_impact",
						tooltip       = "stop_on_impact_description",
					},
					{
						setting_id    = "use_sway_and_recoil",
						type          = "checkbox",
						default_value = true,
						title         = "use_sway_and_recoil",
						tooltip       = "use_sway_and_recoil_description",
					},
					{
						setting_id      = "arc_start_offset_x",
						type            = "numeric",
						default_value   = 0.15,
						range           = { -2, 2 },
						decimals_number = 2,
						step_size_value = 0.01,
						title           = "arc_start_offset_x",
						tooltip         = "arc_start_offset_x_description",
					},
					{
						setting_id      = "arc_start_offset_y",
						type            = "numeric",
						default_value   = 1.5,
						range           = { -2, 5 },
						decimals_number = 2,
						step_size_value = 0.01,
						title           = "arc_start_offset_y",
						tooltip         = "arc_start_offset_y_description",
					},
					{
						setting_id      = "arc_start_offset_z",
						type            = "numeric",
						default_value   = -0.2,
						range           = { -2, 2 },
						decimals_number = 2,
						step_size_value = 0.01,
						title           = "arc_start_offset_z",
						tooltip         = "arc_start_offset_z_description",
					},
					{
						setting_id    = "hide_crosshair_during_ads",
						type          = "checkbox",
						default_value = true,
						title         = "hide_crosshair_during_ads",
						tooltip       = "hide_crosshair_during_ads_description",
					},
				},
			},
		},
	},
}

return data
