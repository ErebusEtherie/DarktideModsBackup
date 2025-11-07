local mod = get_mod("minimap")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "display_class_icon",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "minimap_style_settings",
                type = "group",
                sub_widgets = {
                    {
						setting_id = "minimap_horizontal_alignment",
						type = "dropdown",
						default_value = "center",
						options = {
							{text = "center",   value = "center"},
							{text = "left",   value = "left"},
							{text = "right",   value = "right"},
						  },
					},
					{
                        setting_id = "minimap_vertical_alignment",
                        type = "dropdown",
                        default_value = "bottom",
                        options = {
                            {text = "center",   value = "center"},
                            {text = "top",   value = "top"},
                            {text = "bottom",   value = "bottom"},
                          },
                    },
                    {
						setting_id = "minimap_offset_x",
						type = "numeric",
						default_value = 0,
						range = {-200, 200},
					},
					{
						setting_id = "minimap_offset_y",
						type = "numeric",
						default_value = -30,
						range = {-200, 200},
					},
                }
            },
            {
                setting_id = "icon_visibility",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "location_attention_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "location_ping_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "location_threat_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "unit_threat_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "player_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "assistance_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "objective_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "damaged_enemy_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "tagged_interaction_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
        }
    }
}
