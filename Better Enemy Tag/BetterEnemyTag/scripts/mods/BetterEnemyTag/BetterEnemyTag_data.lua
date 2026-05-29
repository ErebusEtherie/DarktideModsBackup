local mod = get_mod("BetterEnemyTag")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id  = "display_settings",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "reduce_screen_margin",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "enhanced_distance_scale",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "disable_aim_scale_up",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "hide_distance_text",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "hide_off_screen_icon",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id      = "opacity_normal",
						type            = "numeric",
						default_value   = 1,
						range           = { 0, 1 },
						decimals_number = 2,
					},
					{
						setting_id    = "fade_when_aim",
						type          = "checkbox",
						default_value = true,
						sub_widgets   = {
							{
								setting_id      = "opacity_aim",
								type            = "numeric",
								default_value   = 0.5,
								range           = { 0, 1 },
								decimals_number = 2,
							},
						}
					}
				}
			},
			{
				setting_id  = "normal_tag_color",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "override_normal_tag_color",
						type          = "checkbox",
						default_value = false,
						title         = "override_tag_color",
					},
					{
						setting_id    = "normal_tag_color_red",
						type          = "numeric",
						default_value = 246,
						range         = { 0, 255 },
						title         = "red",
					},
					{
						setting_id    = "normal_tag_color_green",
						type          = "numeric",
						default_value = 69,
						range         = { 0, 255 },
						title         = "green",
					},
					{
						setting_id    = "normal_tag_color_blue",
						type          = "numeric",
						default_value = 69,
						range         = { 0, 255 },
						title         = "blue",
					},
				},
			},
			{
				setting_id  = "veteran_tag_color",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "override_veteran_tag_color",
						type          = "checkbox",
						default_value = false,
						title         = "override_tag_color",
					},
					{
						setting_id    = "veteran_tag_color_red",
						type          = "numeric",
						default_value = 255,
						range         = { 0, 255 },
						title         = "red",
					},
					{
						setting_id    = "veteran_tag_color_green",
						type          = "numeric",
						default_value = 204,
						range         = { 0, 255 },
						title         = "green",
					},
					{
						setting_id    = "veteran_tag_color_blue",
						type          = "numeric",
						default_value = 100,
						range         = { 0, 255 },
						title         = "blue",
					},
				},
			},
			{
				setting_id  = "companion_tag_color",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "override_companion_tag_color",
						type          = "checkbox",
						default_value = false,
						title         = "override_tag_color",
					},
					{
						setting_id    = "companion_tag_color_red",
						type          = "numeric",
						default_value = 184,
						range         = { 0, 255 },
						title         = "red",
					},
					{
						setting_id    = "companion_tag_color_green",
						type          = "numeric",
						default_value = 20,
						range         = { 0, 255 },
						title         = "green",
					},
					{
						setting_id    = "companion_tag_color_blue",
						type          = "numeric",
						default_value = 96,
						range         = { 0, 255 },
						title         = "blue",
					},
				},
			},
		}
	}
}
