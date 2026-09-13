local mod = get_mod("enemy_outlines")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "only_targeting_me",
                type = "checkbox",
                default_value = false,
                title = "title_only_targeting_me",
                tooltip = "desc_only_targeting_me",
            },
            {
                setting_id = "group_aimed",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_aimed",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_aimed",
                    },
                    {
                        setting_id = "aimed_color",
                        type = "color",
                        default_value = {255, 255, 255, 255},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_human_bosses",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_human_bosses",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_human_bosses",
                    },
                    {
                        setting_id = "human_boss_color",
                        type = "color",
                        default_value = {255, 255, 50, 100},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_monsters",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_monsters",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_monsters",
                    },
                    {
                        setting_id = "monster_color",
                        type = "color",
                        default_value = {255, 255, 0, 0},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_disablers",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_disablers",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_disablers",
                    },
                    {
                        setting_id = "disabler_color",
                        type = "color",
                        default_value = {255, 0, 255, 0},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_ranged_specials",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_ranged_specials",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_ranged_specials",
                    },
                    {
                        setting_id = "ranged_special_color",
                        type = "color",
                        default_value = {255, 0, 255, 255},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_poxbursters",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_poxbursters",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_poxbursters",
                    },
                    {
                        setting_id = "poxburster_color",
                        type = "color",
                        default_value = {255, 255, 255, 0},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_ranged_elites",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_ranged_elites",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_ranged_elites",
                    },
                    {
                        setting_id = "ranged_elite_color",
                        type = "color",
                        default_value = {255, 0, 0, 255},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_melee_elites",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_melee_elites",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_melee_elites",
                    },
                    {
                        setting_id = "melee_elite_color",
                        type = "color",
                        default_value = {255, 81, 53, 146},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_crushers_maulers",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_crushers_maulers",
                        type = "checkbox",
                        default_value = true,
                        title = "title_outline_crushers_maulers",
                    },
                    {
                        setting_id = "crushers_maulers_color",
                        type = "color",
                        default_value = {255, 255, 80, 0},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_shooters",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_shooters",
                        type = "checkbox",
                        default_value = false,
                        title = "title_outline_shooters",
                    },
                    {
                        setting_id = "shooters_color",
                        type = "color",
                        default_value = {255, 245, 245, 135},
                        title = "title_color",
                    },
                }
            },
            {
                setting_id = "group_chaff",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "outline_chaff",
                        type = "checkbox",
                        default_value = false,
                        title = "title_outline_chaff",
                    },
                    {
                        setting_id = "chaff_color",
                        type = "color",
                        default_value = {255, 105, 55, 20},
                        title = "title_color",
                    },
                }
            },
        }
    }
}
