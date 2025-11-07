local mod = get_mod("reforged_in_fury_males")

return {
    name = " Reforged In Fury Males ",
    description = mod:localize("mod_description"),
    is_togglable = false,
    options = {
        widgets = {
            -- Male Agitator
            {
                setting_id = "zealot_voice_selection_male_a",
                type = "group",
                sub_widgets = {
                    -- Banisher Events (Male Agitator)
                    { setting_id = "loc_zealot_male_a__ability_banisher_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_10", type = "checkbox", default_value = false },

                    -- Banisher Impact Events (Male Agitator)
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_banisher_impact_10", type = "checkbox", default_value = false },

                    -- Maniac Events (Male Agitator)
                    { setting_id = "loc_zealot_male_a__ability_maniac_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_10", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_11", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_12", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_13", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_14", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_a__ability_maniac_15", type = "checkbox", default_value = false },
                },
            },

            -- Male Fanatic
            {
                setting_id = "zealot_voice_selection_male_b",
                type = "group",
                sub_widgets = {
                    -- Banisher Events (Male Fanatic)
                    { setting_id = "loc_zealot_male_b__ability_banisher_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_10", type = "checkbox", default_value = false },

                    -- Banisher Impact Events (Male Fanatic)
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_banisher_impact_10", type = "checkbox", default_value = false },

                    -- Maniac Events (Male Fanatic)
                    { setting_id = "loc_zealot_male_b__ability_maniac_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_10", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_11", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_12", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_13", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_14", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_b__ability_maniac_15", type = "checkbox", default_value = false },
                },
            },

            -- Male Judge
            {
                setting_id = "zealot_voice_selection_male_c",
                type = "group",
                sub_widgets = {
                    -- Banisher Events (Male Judge)
                    { setting_id = "loc_zealot_male_c__ability_banisher_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_10", type = "checkbox", default_value = false },

                    -- Banisher Impact Events (Male Judge)
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_banisher_impact_10", type = "checkbox", default_value = false },

                    -- Maniac Events (Male Judge)
                    { setting_id = "loc_zealot_male_c__ability_maniac_01", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_02", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_03", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_04", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_05", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_06", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_07", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_08", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_09", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_10", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_11", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_12", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_13", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_14", type = "checkbox", default_value = false },
                    { setting_id = "loc_zealot_male_c__ability_maniac_15", type = "checkbox", default_value = false },
                },
            },
        },
    },
}
