local mod = get_mod("GauntletTrajectory")

local data = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id  = "trajectory_options",
				type        = "group",
				sub_widgets = {
					{
						setting_id      = "arc_show_delay",
						type            = "numeric",
						default_value   = 0.1,
						range           = { 0, 2 },
						decimals_number = 2,
						unit_text       = "second",
						title           = "arc_show_delay",
						tooltip         = "arc_show_delay_description",
					},
					{
						setting_id    = "use_sway_and_recoil",
						type          = "checkbox",
						default_value = true,
						title         = "use_sway_and_recoil",
						tooltip       = "use_sway_and_recoil_description",
					},
					{
						setting_id    = "use_custom_arc_start_offset",
						type          = "checkbox",
						default_value = false,
						title         = "use_custom_arc_start_offset",
						tooltip       = "use_custom_arc_start_offset_description",
						sub_widgets   = {
							{
								setting_id      = "arc_start_offset_x",
								type            = "numeric",
								default_value   = 0.15,
								range           = { -2, 2 },
								decimals_number = 2,
								unit_text       = "meter",
								title           = "arc_start_offset_x",
								tooltip         = "arc_start_offset_x_description",
							},
							{
								setting_id      = "arc_start_offset_y",
								type            = "numeric",
								default_value   = 1.5,
								range           = { -2, 5 },
								decimals_number = 2,
								unit_text       = "meter",
								title           = "arc_start_offset_y",
								tooltip         = "arc_start_offset_y_description",
							},
							{
								setting_id      = "arc_start_offset_z",
								type            = "numeric",
								default_value   = -0.2,
								range           = { -2, 2 },
								decimals_number = 2,
								unit_text       = "meter",
								title           = "arc_start_offset_z",
								tooltip         = "arc_start_offset_z_description",
							},
						},
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
			{
				setting_id  = "keep_arc_options",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "keep_arc_while_aiming",
						type          = "checkbox",
						default_value = true,
						title         = "keep_arc_while_aiming",
						tooltip       = "keep_arc_while_aiming_description",
					},
				},
			},
			{
				setting_id  = "explosion_circle_options",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "show_explosion_radius",
						type          = "checkbox",
						default_value = true,
						title         = "show_explosion_radius",
						tooltip       = "show_explosion_radius_description",
						sub_widgets   = {
							{
								setting_id      = "explosion_radius",
								type            = "numeric",
								default_value   = 0,
								range           = { 0, 10 },
								decimals_number = 1,
								unit_text       = "meter",
								title           = "explosion_radius",
								tooltip         = "explosion_radius_description",
							},
							{
								setting_id    = "explosion_circle_color",
								type          = "color",
								default_value = { 128, 216, 229, 207 },
								has_alpha     = true,
								title         = "explosion_circle_color",
								tooltip       = "explosion_circle_color_description",
							},
						},
					},
				},
			},
			{
				setting_id  = "target_outline_options",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "show_target_outline",
						type          = "checkbox",
						default_value = false,
						title         = "show_target_outline",
						tooltip       = "show_target_outline_description",
						sub_widgets   = {
							{
								setting_id      = "target_outline_priority",
								type            = "numeric",
								default_value   = 1,
								range           = { 1, 10 },
								decimals_number = 0,
								title           = "target_outline_priority",
								tooltip         = "target_outline_priority_description",
							},
							{
								setting_id    = "target_outline_color",
								type          = "color",
								default_value = { 255, 108, 115, 104 },
								has_alpha     = false,
								title         = "target_outline_color",
								tooltip       = "target_outline_color_description",
							},
						},
					},
				},
			},
		},
	},
}

return data
