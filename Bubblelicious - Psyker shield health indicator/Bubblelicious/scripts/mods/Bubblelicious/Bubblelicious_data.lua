local mod = get_mod("Bubblelicious")

local settings = {
	{
		setting_id 	= "behavior_settings",
		type 		= "group",
		sub_widgets = {
			{
				setting_id	  = "show_as_non_psyker",
				type		  = "checkbox",
				default_value = false
			},
			{
				setting_id	  = "only_my_shields",
				type		  = "checkbox",
				default_value = true
			},
			{
				setting_id	  = "prioritize_closest_shield",
				type		  = "checkbox",
				default_value = false
			}
		},
	},
	{
		setting_id	= "effect_settings",
		type		= "group",
		sub_widgets = {
			{
				setting_id	  = "hud_element_scale",
				tooltip		  = "hud_element_scale_tooltip",
				type		  = "numeric",
				range		  = { 30, 130 },
				default_value = 100
			},
			{
				setting_id 	  = "color_shift_enabled",
				tooltip 	  = "color_shift_enabled_tooltip",
				type 		  = "checkbox",
				default_value = true
			},
			{
				setting_id 	  = "reflect_status_enabled",
				tooltip 	  = "reflect_status_enabled_tooltip",
				type 		  = "checkbox",
				default_value = false
			},
			{
				setting_id 	  = "border_pulse_enabled",
				tooltip 	  = "border_pulse_enabled_tooltip",
				type 		  = "checkbox",
				default_value = true
			},
			{
				setting_id    = "glow_threshold",
				tooltip 	  = "glow_threshold_tooltip",
				type 		  = "numeric",
				range 		  = { 5, 100 },
				default_value = 30
			}
		}
	},
	{
		setting_id	= "audio_settings",
		type		= "group",
		sub_widgets = {
			{
				setting_id	  = "voiceline_enabled",
				tooltip		  = "voiceline_enabled_tooltip",
				type		  = "checkbox",
				default_value = false
			},
			{
				setting_id	  = "vline_threshold",
				tooltip		  = "vline_threshold_tooltip",
				type		  = "numeric",
				range		  = { 5, 50 },
				default_value = 30
			}
		}
	},
	{
		setting_id = "color_settings",
		type = "group",
		sub_widgets = {
			{
				setting_id	  = "custom_colors_enabled",
				type		  = "checkbox",
				default_value = false
			},
			{
				setting_id 	= "start_color", --pastel green
				type 		= "group",
				sub_widgets = {
					{
						setting_id 	  = "start_color_red",
						type 		  = "numeric",
						range		  = { 0, 255 },
						default_value = 119
					},
					{
						setting_id 	  = "start_color_green",
						type 		  = "numeric",
						range		  = { 0, 255 },
						default_value = 221
					},
					{
						setting_id 	  = "start_color_blue",
						type 		  = "numeric",
						range 		  = { 0, 255 },
						default_value = 119
					}
				}
			},
			{
				setting_id 	= "mid_color", --pastel yellow
				type 		= "group",
				sub_widgets = {
					{
						setting_id 	  = "mid_color_red",
						type 		  = "numeric",
						range		  = { 0, 255 },
						default_value = 253
					},
					{
						setting_id 	  = "mid_color_green",
						type 		  = "numeric",
						range		  = { 0, 255 },
						default_value = 253
					},
					{
						setting_id 	  = "mid_color_blue",
						type 		  = "numeric",
						range 		  = { 0, 255 },
						default_value = 151
					}
				}
			},
			{
				setting_id 	= "end_color",	--pastel red
				type 		= "group",
				sub_widgets = {
					{
						setting_id 	  = "end_color_red",
						type 		  = "numeric",
						range		  = { 0, 255 },
						default_value = 255
					},
					{
						setting_id 	  = "end_color_green",
						type 		  = "numeric",
						range		  = { 0, 255 },
						default_value = 105
					},
					{
						setting_id 	  = "end_color_blue",
						type 		  = "numeric",
						range 		  = { 0, 255 },
						default_value = 97
					}
				}
			},
		}
	}
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = { widgets = settings }
}