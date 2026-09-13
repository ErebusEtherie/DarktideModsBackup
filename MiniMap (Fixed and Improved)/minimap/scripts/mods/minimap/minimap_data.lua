local mod = get_mod("minimap")

local color_presets = {}
for _, name in ipairs(Color.list or {}) do
    local c = Color[name](255, true)
    color_presets[#color_presets+1] = { id = name, name = name, r = c[2], g = c[3], b = c[4] }
end
table.sort(color_presets, function(a,b) return a.name < b.name end)



local function create_color_group(setting_prefix, default_r, default_g, default_b)
    return {
        setting_id = setting_prefix,
        type = "color",
        default_value = { 255, default_r, default_g, default_b },
        title = setting_prefix,
    }
end

local function create_enemy_category_group(category_id, group_id, filter_default, default_color, limit_default, limit_max)
    return {
        setting_id = group_id,
        type = "group",
        tab = mod:localize("tab_enemy_radar"),
        sub_widgets = {
            {
                setting_id = "enemy_radar_filter_" .. category_id,
                type = "checkbox",
                default_value = filter_default,
                title = "title_enable_radar",
            },
            {
                setting_id = "color_" .. category_id,
                type = "color",
                default_value = default_color,
                title = "title_color",
            },
            {
                setting_id = "enemy_radar_limit_" .. category_id,
                type = "numeric",
                default_value = limit_default,
                range = { 0, limit_max or 50 },
                title = "limit_category",
            },
            {
                setting_id = "enemy_name_filter_" .. category_id,
                type = "checkbox",
                default_value = false,
                title = "show_name_category",
            },
        },
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
                setting_id = "minimap_style_settings",
                type = "group",
                tab = mod:localize("tab_general"),
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
                        setting_id = "minimap_background_color",
                        type = "color",
                        default_value = { 255, 180, 180, 180 },
                        title = "minimap_background_color",
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
                setting_id = "class_icon_settings",
                type = "group",
                tab = mod:localize("tab_icons"),
                sub_widgets = {
                    {
                        setting_id = "display_class_icon",
                        type = "checkbox",
                        default_value = true,
                    },
                }
            },
            {
                setting_id = "icon_visibility",
                type = "group",
                tab = mod:localize("tab_icons"),
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
                    {
                        setting_id = "teammate_facing_arrows",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
            {
                setting_id = "distance_markers",
                type = "group",
                tab = mod:localize("tab_icons"),
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
                    {
                        setting_id = "distance_marker_vertical_distance",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "distance_marker_vertical_symbols",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "distance_marker_vertical_threshold",
                                type = "numeric",
                                default_value = 2.5,
                                range = {0.5, 10.0},
                                decimals_number = 1,
                            },
                            {
                                setting_id = "distance_marker_vertical_transparency",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                            {
                                setting_id = "distance_marker_vertical_arrow_size",
                                type = "numeric",
                                default_value = 20,
                                range = {10, 40},
                            },
                            {
                                setting_id = "distance_marker_vertical_arrow_color",
                                type = "color",
                                default_value = { 255, 255, 255, 255 },
                                title = "distance_marker_vertical_arrow_color",
                            },
                            {
                                setting_id = "distance_marker_vertical_arrow_opacity",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                        },
                    },
                },
            },
            {
                setting_id = "display_names",
                type = "group",
                tab = mod:localize("tab_icons"),
                sub_widgets = {
                    {
                        setting_id = "display_name_players",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "display_name_companions",
                        type = "checkbox",
                        default_value = false,
                    },
                },
            },
            {
                setting_id = "dog_settings",
                type = "group",
                tab = mod:localize("tab_icons"),
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
                tab = mod:localize("tab_general"),
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
                setting_id = "enemy_radar_settings",
                type = "group",
                tab = mod:localize("tab_enemy_radar"),
                sub_widgets = {
                    {
                        setting_id = "enemy_radar_enabled",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "enemy_radar_scan_range",
                        type = "numeric",
                        default_value = 50.0,
                        range = {5.0, 100.0},
                        decimals_number = 1,
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
                        setting_id = "enemy_name_filter_only_pinged",
                        type = "checkbox",
                        default_value = false,
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
                                setting_id = "enemy_radar_melee_ring_color",
                                type = "color",
                                default_value = { 255, 165, 165, 165 },
                                title = "enemy_radar_melee_ring_color",
                            },
                            {
                                setting_id = "enemy_radar_melee_ring_opacity",
                                type = "numeric",
                                default_value = 40,
                                range = {0, 255},
                            },
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
                                default_value = 2.5,
                                range = {0.5, 10.0},
                                decimals_number = 1,
                            },
                            {
                                setting_id = "enemy_radar_vertical_distance_transparency",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                        },
                    },
                    {
                        setting_id = "enemy_clustering",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "enemy_clustering_enabled",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "enemy_clustering_radius",
                                type = "numeric",
                                default_value = 3.0,
                                range = {1.0, 10.0},
                                decimals_number = 1,
                            },
                            {
                                setting_id = "enemy_clustering_threshold",
                                type = "numeric",
                                default_value = 3,
                                range = {2, 10},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "enemy_clustering_show_type",
                                type = "checkbox",
                                default_value = true,
                            },
                        },
                    },
                },
            },
            create_enemy_category_group("human_boss", "group_human_bosses", true, { 255, 255, 50, 100 }, 5, 20),
            create_enemy_category_group("monster", "group_monsters", true, { 255, 255, 0, 0 }, 5, 20),
            create_enemy_category_group("disabler", "group_disablers", true, { 255, 0, 255, 0 }, 10, 50),
            create_enemy_category_group("ranged_special", "group_ranged_specials", true, { 255, 0, 255, 255 }, 10, 50),
            create_enemy_category_group("poxburster", "group_poxbursters", true, { 255, 255, 255, 0 }, 10, 50),
            create_enemy_category_group("ranged_elite", "group_ranged_elites", true, { 255, 0, 0, 255 }, 10, 50),
            create_enemy_category_group("crushers_maulers", "group_crushers_maulers", true, { 255, 255, 80, 0 }, 10, 50),
            create_enemy_category_group("melee_elite", "group_melee_elites", true, { 255, 81, 53, 146 }, 10, 50),
            create_enemy_category_group("shooters", "group_shooters", false, { 255, 245, 245, 135 }, 10, 50),
            create_enemy_category_group("chaff", "group_chaff", false, { 255, 105, 55, 20 }, 10, 50),
            {
                setting_id = "strike_map_dimensions",
                type = "group",
                tab = mod:localize("tab_strike_map"),
                sub_widgets = {
                    {
                        setting_id = "strike_map_height",
                        type = "numeric",
                        default_value = 3.0,
                        range = {0.0, 20.0},
                        decimals_number = 1,
                    },
                    {
                        setting_id = "strike_map_half_height",
                        type = "numeric",
                        default_value = 2.5,
                        range = {0.0, 10.0},
                        decimals_number = 1,
                    },
                    {
                        setting_id = "strike_map_depth",
                        type = "numeric",
                        default_value = 7.0,
                        range = {0.0, 20.0},
                        decimals_number = 1,
                    },
                },
            },
            {
                setting_id = "strike_map_lines",
                type = "group",
                tab = mod:localize("tab_strike_map"),
                sub_widgets = {
                    {
                        setting_id = "strike_map_line_thickness_contours",
                        type = "numeric",
                        default_value = 0.85,
                        range = {0.0, 10.0},
                        decimals_number = 2,
                    },
                    {
                        setting_id = "strike_map_line_thickness_stairs",
                        type = "numeric",
                        default_value = 1.4,
                        range = {0.0, 10.0},
                        decimals_number = 2,
                    },
                    {
                        setting_id = "strike_map_line_thickness_slopes",
                        type = "numeric",
                        default_value = 0.8,
                        range = {0.0, 10.0},
                        decimals_number = 2,
                    },
                },
            },
            {
                setting_id = "strike_map_floors",
                type = "group",
                tab = mod:localize("tab_strike_map"),
                sub_widgets = {
                    {
                        setting_id = "strike_map_floor_above",
                        type = "group",
                        sub_widgets = {
                            create_color_group("color_strike_map_floor_above", 120, 150, 185),
                            {
                                setting_id = "color_strike_map_floor_above_opacity",
                                type = "numeric",
                                default_value = 60,
                                range = {0, 255},
                            },
                        },
                    },
                    {
                        setting_id = "strike_map_floor_current",
                        type = "group",
                        sub_widgets = {
                            create_color_group("color_strike_map_floor_current", 101, 133, 96),
                            {
                                setting_id = "color_strike_map_floor_current_opacity",
                                type = "numeric",
                                default_value = 120,
                                range = {0, 255},
                            },
                        },
                    },
                    {
                        setting_id = "strike_map_floor_below",
                        type = "group",
                        sub_widgets = {
                            create_color_group("color_strike_map_floor_below", 120, 98, 76),
                            {
                                setting_id = "color_strike_map_floor_below_opacity",
                                type = "numeric",
                                default_value = 80,
                                range = {0, 255},
                            },
                        },
                    },
                },
            },
        }
    }
}
