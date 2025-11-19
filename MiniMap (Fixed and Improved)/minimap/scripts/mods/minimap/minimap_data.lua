local mod = get_mod("minimap")

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
                        setting_id = "minimap_background_color",
                        type = "dropdown",
                        default_value = "ui_grey_light",
                        options = color_options,
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
                                setting_id = "enemy_radar_melee_ring_color",
                                type = "dropdown",
                                default_value = "ui_grey_light",
                                options = color_options,
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
                            -- Disablers
                            {
                                setting_id = "color_chaos_hound_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_chaos_hound_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_chaos_hound_b",
                                type = "numeric",
                                default_value = 200,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_renegade_netgunner_r",
                                type = "numeric",
                                default_value = 200,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_renegade_netgunner_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_renegade_netgunner_b",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            -- Snipers
                            {
                                setting_id = "color_renegade_sniper_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_renegade_sniper_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_renegade_sniper_b",
                                type = "numeric",
                                default_value = 150,
                                range = {0, 255},
                            },
                            -- Flamers (Both Renegade & Cultist)
                            {
                                setting_id = "color_flamer_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_flamer_g",
                                type = "numeric",
                                default_value = 80,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_flamer_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            -- Grenadiers (Both Renegade & Cultist)
                            {
                                setting_id = "color_grenadier_r",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_grenadier_g",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_grenadier_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_chaos_poxwalker_bomber_r",
                                type = "numeric",
                                default_value = 220,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_chaos_poxwalker_bomber_g",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_chaos_poxwalker_bomber_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                        },
                    },
                    {
                        setting_id = "enemy_colors_elites",
                        type = "group",
                        sub_widgets = {
                            -- Executors (Both Ogryn & Renegade)
                            {
                                setting_id = "color_executor_r",
                                type = "numeric",
                                default_value = 150,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_executor_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_executor_b",
                                type = "numeric",
                                default_value = 200,
                                range = {0, 255},
                            },
                            -- Ragers (Both Renegade & Cultist Berzerkers)
                            {
                                setting_id = "color_berzerker_r",
                                type = "numeric",
                                default_value = 220,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_berzerker_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_berzerker_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            -- Plasma Gunner
                            {
                                setting_id = "color_renegade_plasma_gunner_r",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_renegade_plasma_gunner_g",
                                type = "numeric",
                                default_value = 220,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_renegade_plasma_gunner_b",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            -- Bulwark
                            {
                                setting_id = "color_chaos_ogryn_bulwark_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_chaos_ogryn_bulwark_g",
                                type = "numeric",
                                default_value = 200,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_chaos_ogryn_bulwark_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                        },
                    },
                    {
                        setting_id = "enemy_colors_generic",
                        type = "group",
                        sub_widgets = {
                            -- Generic Special (catch-all)
                            {
                                setting_id = "color_special_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_special_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_special_b",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            -- Elite Ranged
                            {
                                setting_id = "color_elite_ranged_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_elite_ranged_g",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_elite_ranged_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            -- Elite Melee
                            {
                                setting_id = "color_elite_melee_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_elite_melee_g",
                                type = "numeric",
                                default_value = 165,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_elite_melee_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            -- Monster
                            {
                                setting_id = "color_monster_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_monster_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_monster_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            -- Captain
                            {
                                setting_id = "color_captain_r",
                                type = "numeric",
                                default_value = 128,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_captain_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_captain_b",
                                type = "numeric",
                                default_value = 128,
                                range = {0, 255},
                            },
                            -- Horde
                            {
                                setting_id = "color_horde_r",
                                type = "numeric",
                                default_value = 150,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_horde_g",
                                type = "numeric",
                                default_value = 150,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_horde_b",
                                type = "numeric",
                                default_value = 150,
                                range = {0, 255},
                            },
                            -- Roamer
                            {
                                setting_id = "color_roamer_r",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_roamer_g",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                            {
                                setting_id = "color_roamer_b",
                                type = "numeric",
                                default_value = 180,
                                range = {0, 255},
                            },
                        },
                    },
                },
            },
        }
    }
}
