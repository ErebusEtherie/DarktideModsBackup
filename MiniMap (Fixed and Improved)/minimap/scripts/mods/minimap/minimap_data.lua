local mod = get_mod("minimap")

local color_presets = {}
for _, name in ipairs(Color.list or {}) do
    local c = Color[name](255, true)
    color_presets[#color_presets+1] = { id = name, name = name, r = c[2], g = c[3], b = c[4] }
end
table.sort(color_presets, function(a,b) return a.name < b.name end)

local function preset_options(setting_prefix, default_r, default_g, default_b)
    local opts = {}
    if default_r and default_g and default_b then
        local default_key = "default_" .. setting_prefix
        table.insert(opts, { text = default_key, value = "default" })
    else
        table.insert(opts, { text = "default", value = "default" })
    end
    for i, p in ipairs(color_presets) do
        opts[#opts+1] = { text = p.name, value = p.id }
    end
    return opts
end

local function create_color_group(setting_prefix, default_r, default_g, default_b)
    return {
        setting_id = setting_prefix,
        type = "group",
        sub_widgets = {
            {
                setting_id = setting_prefix .. "_preset",
                type = "dropdown",
                default_value = "default",
                options = preset_options(setting_prefix, default_r, default_g, default_b),
            },
            {
                setting_id = setting_prefix .. "_r",
                type = "numeric",
                default_value = default_r,
                range = {0, 255},
            },
            {
                setting_id = setting_prefix .. "_g",
                type = "numeric",
                default_value = default_g,
                range = {0, 255},
            },
            {
                setting_id = setting_prefix .. "_b",
                type = "numeric",
                default_value = default_b,
                range = {0, 255},
            },
        }
    }
end

local color_options = {}
for _, color_name in ipairs(Color.list) do
    table.insert(color_options, {
            text = color_name,
            value = color_name
    })
end
table.sort(color_options, function(a, b) return a.text < b.text end)

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
                            {text = "center", value = "center"},
                            {text = "left", value = "left"},
                            {text = "right", value = "right"},
                        },
                    },
                    {
                        setting_id = "minimap_vertical_alignment",
                        type = "dropdown",
                        default_value = "bottom",
                        options = {
                            {text = "center", value = "center"},
                            {text = "top", value = "top"},
                            {text = "bottom", value = "bottom"},
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
                    {
                        setting_id = "minimap_background_color_preset",
                        type = "dropdown",
                        default_value = "ui_grey_light",
                        options = preset_options(),
                    },
                    {
                        setting_id = "minimap_background_color_r",
                        type = "numeric",
                        default_value = 180,
                        range = {0, 255},
                    },
                    {
                        setting_id = "minimap_background_color_g",
                        type = "numeric",
                        default_value = 180,
                        range = {0, 255},
                    },
                    {
                        setting_id = "minimap_background_color_b",
                        type = "numeric",
                        default_value = 180,
                        range = {0, 255},
                    },
                    {
                        setting_id = "minimap_background_opacity",
                        type = "numeric",
                        default_value = 64,
                        range = {0, 255},
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
                        setting_id = "unit_threat_adamant_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "player_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "objective_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "tagged_interaction_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "status_icon_style",
                        type = "dropdown",
                        default_value = "glowing_with_rings",
                        options = {
                            {text = "hidden", value = "hidden"},
                            {text = "non_glowing", value = "non_glowing"},
                            {text = "non_glowing_with_rings", value = "non_glowing_with_rings"},
                            {text = "glowing_with_rings", value = "glowing_with_rings"},
                            {text = "glowing_no_rings", value = "glowing_no_rings"},
                        },
                    },
                    {
                        setting_id = "hide_bots",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
            {
                setting_id = "distance_markers",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "distance_marker_players",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "distance_marker_companions",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "distance_marker_enemies",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "distance_marker_objectives",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "distance_marker_interactables",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "distance_marker_pings",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "distance_marker_only_out_of_range",
                        type = "checkbox",
                        default_value = false,
                    },
                },
            },
            {
                setting_id = "dog_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "dog_icon_style",
                        type = "dropdown",
                        default_value = "unicode_icon",
                        options = {
                            {text = "dog_icon", value = "dog_icon"},
                            {text = "class_icon", value = "class_icon"},
                            {text = "unicode_icon", value = "unicode_icon"},
                        },
                    },
                    {
                        setting_id = "own_dog_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "teammate_dog_vis",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
            {
                setting_id = "minimap_visibility",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "show_in_hub",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "show_in_shooting_range",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "show_when_dead",
                        type = "checkbox",
                        default_value = false,
                    },
                },
            },
            {
                setting_id = "enemy_radar",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "enemy_radar_enabled",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "enemy_radar_priority_mode",
                        type = "dropdown",
                        default_value = "threat",
                        options = {
                            {text = "enemy_radar_priority_mode_threat", value = "threat"},
                            {text = "enemy_radar_priority_mode_distance", value = "distance"},
                        },
                    },
                    {
                        setting_id = "enemy_radar_vertical_distance",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "enemy_radar_vertical_distance_enabled",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "enemy_radar_vertical_distance_threshold",
                                type = "numeric",
                                default_value = 3.0,
                                range = {0.5, 10.0},
                                decimals_number = 1,
                            },
                            {
                                setting_id = "enemy_radar_vertical_distance_transparency",
                                type = "numeric",
                                default_value = 40,
                                range = {0, 255},
                            },
                        },
                    },
                    {
                        setting_id = "enemy_radar_filters",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "enemy_radar_filter_elite",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "enemy_radar_filter_special",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "enemy_radar_filter_boss",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "enemy_radar_filter_horde",
                                type = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id = "enemy_radar_filter_fodder",
                                type = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id = "enemy_radar_filter_roamer",
                                type = "checkbox",
                                default_value = false,
                            },
                        },
                    },
                    {
                        setting_id = "enemy_radar_limits",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "enemy_radar_limit_elite",
                                type = "numeric",
                                default_value = 10,
                                range = {0, 50},
                            },
                            {
                                setting_id = "enemy_radar_limit_special",
                                type = "numeric",
                                default_value = 10,
                                range = {0, 50},
                            },
                            {
                                setting_id = "enemy_radar_limit_boss",
                                type = "numeric",
                                default_value = 5,
                                range = {0, 20},
                            },
                            {
                                setting_id = "enemy_radar_limit_horde",
                                type = "numeric",
                                default_value = 5,
                                range = {0, 50},
                            },
                            {
                                setting_id = "enemy_radar_limit_fodder",
                                type = "numeric",
                                default_value = 5,
                                range = {0, 50},
                            },
                            {
                                setting_id = "enemy_radar_limit_roamer",
                                type = "numeric",
                                default_value = 5,
                                range = {0, 50},
                            },
                        },
                    },
                    {
                        setting_id = "enemy_radar_melee_ring",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "enemy_radar_melee_ring_enabled",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "enemy_radar_melee_range",
                                type = "numeric",
                                default_value = 2.5,
                                range = {1, 5},
                                decimals_number = 1,
                            },
                            {
                                setting_id = "enemy_radar_melee_ring_color_preset",
                                type = "dropdown",
                                default_value = "ui_grey_light",
                                options = preset_options(),
                            },
                            {
                                setting_id = "enemy_radar_melee_ring_color_r",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                            {
                                setting_id = "enemy_radar_melee_ring_color_g",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                            {
                                setting_id = "enemy_radar_melee_ring_color_b",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                            {
                                setting_id = "enemy_radar_melee_ring_opacity",
                                type = "numeric",
                                default_value = 40,
                                range = {0, 255},
                            },
                        },
                    },
                },
            },
            {
                setting_id = "enemy_colors",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "enemy_colors_specials",
                        type = "group",
                        sub_widgets = {
                            create_color_group("color_chaos_hound", 255, 0, 200),
                            create_color_group("color_renegade_netgunner", 200, 0, 255),
                            create_color_group("color_renegade_sniper", 255, 0, 150),
                            create_color_group("color_flamer", 255, 80, 0),
                            create_color_group("color_grenadier", 180, 255, 0),
                            create_color_group("color_chaos_poxwalker_bomber", 220, 255, 0),
                        },
                    },
                    {
                        setting_id = "enemy_colors_elites",
                        type = "group",
                        sub_widgets = {
                            create_color_group("color_executor", 150, 0, 200),
                            create_color_group("color_berzerker", 220, 0, 0),
                            create_color_group("color_renegade_plasma_gunner", 0, 220, 255),
                            create_color_group("color_chaos_ogryn_bulwark", 255, 200, 0),
                        },
                    },
                    {
                        setting_id = "enemy_colors_generic",
                        type = "group",
                        sub_widgets = {
                            create_color_group("color_special", 255, 0, 255),
                            create_color_group("color_elite_ranged", 255, 100, 0),
                            create_color_group("color_elite_melee", 255, 165, 0),
                            create_color_group("color_monster", 255, 0, 0),
                            create_color_group("color_captain", 128, 0, 128),
                            create_color_group("color_horde", 150, 150, 150),
                            create_color_group("color_roamer", 180, 180, 180),
                        },
                    },
                },
            },
        }
    }
}
