local mod = get_mod("Killfeed_Reborn")
local color_defaults = mod:io_dofile("Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/color_defaults")

local function rgb_widget(setting_id, default_value)
    return {
        setting_id = setting_id,
        type = "numeric",
        default_value = default_value,
        range = { 0, 255 },
    }
end

local function color_group(setting_id, prefix, defaults)
    return {
        setting_id = setting_id,
        type = "group",
        sub_widgets = {
            rgb_widget(prefix .. "_r", defaults[1]),
            rgb_widget(prefix .. "_g", defaults[2]),
            rgb_widget(prefix .. "_b", defaults[3]),
        },
    }
end

local function killer_color_group(slot, defaults)
    return color_group("killer_" .. slot .. "_color_group", "killer_" .. slot, defaults)
end

local function number_options(min_value, max_value)
    local options = {}

    for value = min_value, max_value do
        options[#options + 1] = {
            text = "num_" .. value,
            value = value,
        }
    end

    return options
end

return {
    name = "{#color(210,180,120)}Killfe{#reset()}{#color(255,255,255)}ed Reb{#reset()}{#color(255,90,90)}orn{#reset()}",
    description = mod:localize("mod_description"),
	is_togglable = true,

    options = {
        widgets = {
            --------------------------------------------------
            -- KILLFEED SETTINGS
            --------------------------------------------------
            {
                setting_id = "killfeed_settings_group",
                type = "group",
                tab = "General",
                sub_widgets = {
                    {
                        setting_id = "metrics",
                        type = "dropdown",
                        default_value = "team",
                        options = {
                            { text = "metrics_team", value = "team" },
                            { text = "metrics_self", value = "self" },
                        },
                    },
                    {
                        setting_id = "message_duration",
                        type = "dropdown",
                        default_value = 5,
                        options = number_options(5, 20),
                    },
                    {
                        setting_id = "fade_out",
                        type = "dropdown",
                        default_value = 1,
                        options = number_options(1, 10),
                    },
                    {
                        setting_id = "max_messages",
                        type = "dropdown",
                        default_value = 8,
                        options = number_options(4, 25),
                    },
                    {
                        setting_id = "other_settings_group",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "chat_colors",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "unknown_profile_logging",
                                type = "checkbox",
                                default_value = false,
                            },
                        },
                    },
                },
            },

            --------------------------------------------------
            -- KILLER COLORS
            --------------------------------------------------
            {
                setting_id = "killfeed_color_group",
                type = "group",
                tab = "Killer Colors",
                sub_widgets = {
                    killer_color_group(1, color_defaults.killer_1),
                    killer_color_group(2, color_defaults.killer_2),
                    killer_color_group(3, color_defaults.killer_3),
                    killer_color_group(4, color_defaults.killer_4),
                }
            },

            --------------------------------------------------
            -- PHRASE COLORS
            --------------------------------------------------
            {
                setting_id = "phrase_color_group",
                type = "group",
                tab = "Phrase Colors",
                sub_widgets = {
                    color_group("action_color_group", "action", color_defaults.action),
                    color_group("death_action_color_group", "death_action", color_defaults.death_action),
                    color_group("victim_color_group", "victim", color_defaults.victim),
                }
            },

            --------------------------------------------------
            -- NEON
            --------------------------------------------------
            {
                setting_id = "neon_settings_group",
                type = "group",
                tab = "NEON",
                sub_widgets = {
                    {
                        setting_id = "neon",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "neon_everything",
                        type = "checkbox",
                        default_value = false,
                    },
                    color_group("neon_start_color_group", "neon_start", color_defaults.neon_start),
                    color_group("neon_middle_color_group", "neon_middle", color_defaults.neon_middle),
                    color_group("neon_end_color_group", "neon_end", color_defaults.neon_end),
                }
            },

            --------------------------------------------------
            -- PHRASE MIXING
            --------------------------------------------------
            {
                setting_id = "phrase_settings",
                type = "group",
                tab = "Phrase Chance",
                sub_widgets = {
                    {
                        setting_id = "generic_specific",
                        type = "numeric",
                        default_value = 70,
                        range = {0,100},
                    },
                    {
                        setting_id = "funny_chance",
                        type = "numeric",
                        default_value = 10,
                        range = {0,50},
                    },
                },
            },

        }
    }
}
