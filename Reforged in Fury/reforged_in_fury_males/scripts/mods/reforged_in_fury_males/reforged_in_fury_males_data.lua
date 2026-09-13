local mod = get_mod("reforged_in_fury_males")

local male_agitator = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_a")
local male_fanatic = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_b")
local male_judge = mod:io_dofile("reforged_in_fury_males/scripts/mods/reforged_in_fury_males/zealot_male_c")

return {
    name = "{#color(255,255,255)} {#color(255,255,255)}R{#color(225,255,225)}e{#color(195,255,195)}f{#color(155,250,180)}o{#color(110,240,175)}r{#color(70,220,190)}g{#color(35,185,215)}e{#color(15,145,240)}d {#color(15,105,250)}I{#color(25,70,245)}n {#color(65,65,235)}F{#color(110,70,220)}u{#color(155,70,195)}r{#color(195,65,165)}y {#color(225,55,125)}M{#color(245,45,90)}a{#color(250,35,60)}l{#color(235,25,40)}e{#color(215,15,25)}s {#color(185,15,15)}{#reset()}",
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
                }
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
                }
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
                }
            },
        },
    },
}
