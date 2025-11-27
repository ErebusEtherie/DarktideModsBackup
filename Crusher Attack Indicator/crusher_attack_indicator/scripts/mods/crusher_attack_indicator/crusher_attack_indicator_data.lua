local mod = get_mod("crusher_attack_indicator")

local mod_name = mod:localize("mod_name")
local mod_description = mod:localize("mod_description")

return {
	name = mod_name,
	description = mod_description,
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "enabled",
				type = "checkbox",
				default_value = true,
				title = "enabled",
				tooltip = "enabled"
			},
			{
				setting_id = "persistent_yellow",
				type = "checkbox",
				default_value = false,
				title = "persistent_yellow",
				tooltip = "persistent_yellow_tooltip"
			},
			{
				setting_id = "ring_radius",
				type = "numeric",
				range = {1, 10},
				default_value = 2.0,
				decimals = 1,
				title = "ring_radius",
				tooltip = "ring_radius_tooltip"
			},
			{
				setting_id = "warning_settings",
				type = "group",
				title = "warning_settings",
				sub_widgets = {
					{
						setting_id = "warning_color_red",
						type = "numeric",
						range = {0, 100},
						default_value = 100,
						title = "warning_color_red",
						tooltip = "warning_color_red_tooltip"
					},
					{
						setting_id = "warning_color_green", 
						type = "numeric",
						range = {0, 100},
						default_value = 100,
						title = "warning_color_green",
						tooltip = "warning_color_green_tooltip"
					},
					{
						setting_id = "warning_color_blue",
						type = "numeric",
						range = {0, 100},
						default_value = 0,
						title = "warning_color_blue",
						tooltip = "warning_color_blue_tooltip"
					},
					{
						setting_id = "warning_color_alpha",
						type = "numeric",
						range = {0, 100},
						default_value = 80,
						title = "warning_color_alpha",
						tooltip = "warning_color_alpha_tooltip"
					}
				}
			},
			{
				setting_id = "attack_settings",
				type = "group",
				title = "attack_settings",
				sub_widgets = {
					{
						setting_id = "attack_color_red",
						type = "numeric",
						range = {0, 100},
						default_value = 100,
						title = "attack_color_red",
						tooltip = "attack_color_red_tooltip"
					},
					{
						setting_id = "attack_color_green", 
						type = "numeric",
						range = {0, 100},
						default_value = 0,
						title = "attack_color_green",
						tooltip = "attack_color_green_tooltip"
					},
					{
						setting_id = "attack_color_blue",
						type = "numeric",
						range = {0, 100},
						default_value = 0,
						title = "attack_color_blue",
						tooltip = "attack_color_blue_tooltip"
					},
					{
						setting_id = "attack_color_alpha",
						type = "numeric",
						range = {0, 100},
						default_value = 80,
						title = "attack_color_alpha",
						tooltip = "attack_color_alpha_tooltip"
					}
				}
			}
		}
	}
}