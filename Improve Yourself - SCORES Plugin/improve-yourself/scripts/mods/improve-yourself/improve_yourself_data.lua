local mod = get_mod("improve-yourself")
local widgets = {
    {
        setting_id = "group_general",
        type = "group",
        text = "settings_general",
        sub_widgets = {
            { setting_id = "end_board_preference", type = "dropdown", default_value = "improve_yourself", tooltip_text = "end_board_preference_description", options = {
                { text = "end_board_improve_yourself", value = "improve_yourself" },
                { text = "end_board_regular_scoreboard", value = "regular_scoreboard" },
            } },
            { setting_id = "tactical_overlay_preference", type = "dropdown", default_value = "improve_yourself", tooltip_text = "tactical_overlay_preference_description", options = {
                { text = "tactical_overlay_improve_yourself", value = "improve_yourself" },
                { text = "tactical_overlay_scores", value = "scores" },
            } },
            { setting_id = "history_start_view", type = "dropdown", default_value = "bars", tooltip_text = "history_start_view_description", options = {
                { text = "history_start_view_numbers", value = "numbers" },
                { text = "history_start_view_bars", value = "bars" },
            } },
            { setting_id = "color_scheme", type = "dropdown", default_value = "goal_oriented", tooltip_text = "color_scheme_description", options = {
                { text = "color_scheme_goal_oriented", value = "goal_oriented" },
                { text = "color_scheme_team_comparison", value = "team_comparison" },
            } },
            { setting_id = "default_role", type = "dropdown", default_value = "generalist", tooltip_text = "default_role_description", options = {
                { text = "role_generalist", value = "generalist" },
                { text = "role_frontline", value = "frontline" },
                { text = "role_horde_control", value = "horde_control" },
                { text = "role_ranged_specialist", value = "ranged_specialist" },
                { text = "role_elite_boss", value = "elite_boss" },
                { text = "role_support_control", value = "support_control" },
            } },
        },
    },
    {
        setting_id = "group_role_generalist",
        type = "group",
        text = "role_generalist",
        sub_widgets = {
            { setting_id = "section_generalist_defense", type = "group", text = "settings_section_defense", sub_widgets = {
                { setting_id = "goal_generalist_damage_taken", type = "numeric", default_value = 27, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_times_downed", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_times_disabled", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_deaths", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_generalist_offense", type = "group", text = "settings_section_offense", sub_widgets = {
                { setting_id = "goal_generalist_damage_dealt", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_weakspot_hits", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_melee_kills", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_ranged_kills", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_lesser_enemies", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_melee_ranged_threats", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_special_threats", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_boss_damage_dealt", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_generalist_team", type = "group", text = "settings_section_team", sub_widgets = {
                { setting_id = "goal_generalist_coherency_efficiency", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_revived_operative", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_team_saves", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_generalist_ammo_score", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
        },
    },
    {
        setting_id = "group_role_frontline",
        type = "group",
        text = "role_frontline",
        sub_widgets = {
            { setting_id = "section_frontline_defense", type = "group", text = "settings_section_defense", sub_widgets = {
                { setting_id = "goal_frontline_damage_taken", type = "numeric", default_value = 30, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_times_downed", type = "numeric", default_value = 30, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_times_disabled", type = "numeric", default_value = 30, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_deaths", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_frontline_offense", type = "group", text = "settings_section_offense", sub_widgets = {
                { setting_id = "goal_frontline_damage_dealt", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_weakspot_hits", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_melee_kills", type = "numeric", default_value = 30, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_ranged_kills", type = "numeric", default_value = 15, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_lesser_enemies", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_melee_ranged_threats", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_special_threats", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_boss_damage_dealt", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_frontline_team", type = "group", text = "settings_section_team", sub_widgets = {
                { setting_id = "goal_frontline_coherency_efficiency", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_revived_operative", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_team_saves", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_frontline_ammo_score", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
        },
    },
    {
        setting_id = "group_role_horde_control",
        type = "group",
        text = "role_horde_control",
        sub_widgets = {
            { setting_id = "section_horde_control_defense", type = "group", text = "settings_section_defense", sub_widgets = {
                { setting_id = "goal_horde_control_damage_taken", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_times_downed", type = "numeric", default_value = 27, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_times_disabled", type = "numeric", default_value = 27, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_deaths", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_horde_control_offense", type = "group", text = "settings_section_offense", sub_widgets = {
                { setting_id = "goal_horde_control_damage_dealt", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_weakspot_hits", type = "numeric", default_value = 15, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_melee_kills", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_ranged_kills", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_lesser_enemies", type = "numeric", default_value = 30, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_melee_ranged_threats", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_special_threats", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_boss_damage_dealt", type = "numeric", default_value = 15, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_horde_control_team", type = "group", text = "settings_section_team", sub_widgets = {
                { setting_id = "goal_horde_control_coherency_efficiency", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_revived_operative", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_team_saves", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_horde_control_ammo_score", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
        },
    },
    {
        setting_id = "group_role_ranged_specialist",
        type = "group",
        text = "role_ranged_specialist",
        sub_widgets = {
            { setting_id = "section_ranged_specialist_defense", type = "group", text = "settings_section_defense", sub_widgets = {
                { setting_id = "goal_ranged_specialist_damage_taken", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_times_downed", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_times_disabled", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_deaths", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_ranged_specialist_offense", type = "group", text = "settings_section_offense", sub_widgets = {
                { setting_id = "goal_ranged_specialist_damage_dealt", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_weakspot_hits", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_melee_kills", type = "numeric", default_value = 15, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_ranged_kills", type = "numeric", default_value = 32, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_lesser_enemies", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_melee_ranged_threats", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_special_threats", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_boss_damage_dealt", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_ranged_specialist_team", type = "group", text = "settings_section_team", sub_widgets = {
                { setting_id = "goal_ranged_specialist_coherency_efficiency", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_revived_operative", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_team_saves", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_ranged_specialist_ammo_score", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
        },
    },
    {
        setting_id = "group_role_elite_boss",
        type = "group",
        text = "role_elite_boss",
        sub_widgets = {
            { setting_id = "section_elite_boss_defense", type = "group", text = "settings_section_defense", sub_widgets = {
                { setting_id = "goal_elite_boss_damage_taken", type = "numeric", default_value = 27, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_times_downed", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_times_disabled", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_deaths", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_elite_boss_offense", type = "group", text = "settings_section_offense", sub_widgets = {
                { setting_id = "goal_elite_boss_damage_dealt", type = "numeric", default_value = 28, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_weakspot_hits", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_melee_kills", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_ranged_kills", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_lesser_enemies", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_melee_ranged_threats", type = "numeric", default_value = 30, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_special_threats", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_boss_damage_dealt", type = "numeric", default_value = 32, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_elite_boss_team", type = "group", text = "settings_section_team", sub_widgets = {
                { setting_id = "goal_elite_boss_coherency_efficiency", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_revived_operative", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_team_saves", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_elite_boss_ammo_score", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
        },
    },
    {
        setting_id = "group_role_support_control",
        type = "group",
        text = "role_support_control",
        sub_widgets = {
            { setting_id = "section_support_control_defense", type = "group", text = "settings_section_defense", sub_widgets = {
                { setting_id = "goal_support_control_damage_taken", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_times_downed", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_times_disabled", type = "numeric", default_value = 22, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_deaths", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_support_control_offense", type = "group", text = "settings_section_offense", sub_widgets = {
                { setting_id = "goal_support_control_damage_dealt", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_weakspot_hits", type = "numeric", default_value = 15, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_melee_kills", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_ranged_kills", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_lesser_enemies", type = "numeric", default_value = 18, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_melee_ranged_threats", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_special_threats", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_boss_damage_dealt", type = "numeric", default_value = 15, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
            { setting_id = "section_support_control_team", type = "group", text = "settings_section_team", sub_widgets = {
                { setting_id = "goal_support_control_coherency_efficiency", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_revived_operative", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_team_saves", type = "numeric", default_value = 25, range = {0, 100}, tooltip_text = "goal_setting_description" },
                { setting_id = "goal_support_control_ammo_score", type = "numeric", default_value = 20, range = {0, 100}, tooltip_text = "goal_setting_description" },
            } },
        },
    },
    {
        setting_id = "group_developer",
        type = "group",
        text = "group_developer",
        sub_widgets = {
            {
                setting_id = "auto_damage_diagnostics",
                type = "checkbox",
                default_value = false,
                tooltip_text = "auto_damage_diagnostics_description",
            },
        },
    },
}

return {
    name = mod:localize("mod_title"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    allow_rehooking = true,
    options = { widgets = widgets },
}
