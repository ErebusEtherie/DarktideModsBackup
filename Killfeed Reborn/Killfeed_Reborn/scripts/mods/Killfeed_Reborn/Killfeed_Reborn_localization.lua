local mod = get_mod("Killfeed_Reborn")
local color_defaults = mod:io_dofile("Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/color_defaults")
local neon_formatting = mod:io_dofile("Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/neon_formatting")

local loc = {
    mod_name = {
        en = "Killfeed Reborn",
    },
    mod_description = {
        en = "Replaces your combat_feed with more calculated and fun phrases for player kills and deaths.\n\n"
            .. "{#color(210,180,120)}Author: {#color(200,220,180)}BadId34{#reset()}\n"
            .. "{#color(210,180,120)}Version: {#color(200,220,180)}2.2.0{#reset()}",
    },

    killfeed_settings_group = {
        en = "Killfeed Settings",
    },

    killfeed_color_group = {
        en = "Killer Colors",
    },

    phrase_color_group = {
        en = "Phrase Colors",
    },
    neon_settings_group = {
        en = "NEON Phrase Preview",
    },

    metrics = {
        en = "Feed Scope",
    },
    metrics_description = {
        en = "Show kill and death messages for your TEAM or just your SELF.",
    },
    metrics_team = {
        en = "TEAM",
    },
    metrics_self = {
        en = "SELF",
    },

    message_duration = {
        en = "Message Duration",
    },
    message_duration_description = {
        en = "Sets the time before the Killfeed message starts to fade out.",
    },

    fade_out = {
        en = "Fade Out",
    },
    fade_out_description = {
        en = "Sets the time it takes for the Killfeed message to fade out.",
    },

    max_messages = {
        en = "Max Messages",
    },
    max_messages_description = {
        en = "Sets how many Killfeed messages can be visible at once.",
    },

    other_settings_group = {
        en = "Other",
    },

    chat_colors = {
        en = "Chat Colors",
    },
    chat_colors_description = {
        en = "Applies \"Killer Colors\" to respective player names in chat. Switch <OFF> if using another chat color mod.",
    },
    unknown_profile_logging = {
        en = "Profile logging",
    },
    unknown_profile_logging_description = {
        en = "Enables logging of unclassified profiles if one is detected. Will notify the player in the combat feed and log to appdata > Fatshark > Darktide > Killfeed_Reborn.",
    },

    phrase_settings = {
        en = "Phrase Chance",
    },

    generic_specific = {
        en = "Generic/Specific",
    },
    generic_specific_description = {
        en = "Sets the % chance that your rolled phrase is Generic over specific. i.e: MELE vs SHARP",
    },

    funny_chance = {
        en = "Funny",
    },
    funny_chance_description = {
        en = "Sets the % chance that an awarded \"Specific\" phrase is instead a \"Funny\" phrase.",
    },

    neon = {
        en = "Funny Phrase Neon",
    },
    neon_description = {
        en = "Applies neon colors to Funny phrase rolls.",
    },
    neon_everything = {
        en = "NEON Everything",
    },
    neon_everything_description = {
        en = "Applies NEON colors to all kill and death phrases.",
    },
    neon_start_color_group = {
        en = "Neon Start",
    },
    neon_middle_color_group = {
        en = "Neon Middle",
    },
    neon_end_color_group = {
        en = "Neon End",
    },

    killer_1_color_group = { en = "Killer 1" },
    killer_2_color_group = { en = "Killer 2" },
    killer_3_color_group = { en = "Killer 3" },
    killer_4_color_group = { en = "Killer 4" },
    action_color_group = { en = "Player Kill Phrase" },
    death_action_color_group = { en = "Player Death Phrase" },
    victim_color_group = { en = "Target" },

}

for _, prefix in ipairs({
    "killer_1",
    "killer_2",
    "killer_3",
    "killer_4",
    "action",
    "death_action",
    "victim",
    "neon_start",
    "neon_middle",
    "neon_end",
}) do
    loc[prefix .. "_r"] = { en = "Red" }
    loc[prefix .. "_g"] = { en = "Green" }
    loc[prefix .. "_b"] = { en = "Blue" }
end

for value = 1, 25 do
    loc["num_" .. value] = { en = tostring(value) }
end

local color_groups = {
    {
        key = "killer_1_color_group",
        prefix = "killer_1",
    },
    {
        key = "killer_2_color_group",
        prefix = "killer_2",
    },
    {
        key = "killer_3_color_group",
        prefix = "killer_3",
    },
    {
        key = "killer_4_color_group",
        prefix = "killer_4",
    },
    {
        key = "action_color_group",
        prefix = "action",
    },
    {
        key = "death_action_color_group",
        prefix = "death_action",
    },
    {
        key = "victim_color_group",
        prefix = "victim",
    },
    {
        key = "neon_start_color_group",
        prefix = "neon_start",
    },
    {
        key = "neon_middle_color_group",
        prefix = "neon_middle",
    },
    {
        key = "neon_end_color_group",
        prefix = "neon_end",
    },
}

local function current_color(prefix)
    local defaults = color_defaults[prefix]

    return {
        mod:get(prefix .. "_r") or defaults[1],
        mod:get(prefix .. "_g") or defaults[2],
        mod:get(prefix .. "_b") or defaults[3],
    }
end

local function apply_colours()
    local colors = {
        current_color("neon_start"),
        current_color("neon_middle"),
        current_color("neon_end"),
    }

    for language, text in pairs(loc.neon_settings_group) do
        local clean = string.gsub(text, "{#.-}", "")
        clean = string.gsub(clean, "{#reset%(%)%}", "")
        loc.neon_settings_group[language] = neon_formatting.gradient(clean, colors)
    end

    for i = 1, #color_groups do
        local group = color_groups[i]
        local color = current_color(group.prefix)

        for language, text in pairs(loc[group.key]) do
            local clean = string.gsub(text, "{#.-}", "")
            clean = string.gsub(clean, "{#reset%(%)%}", "")
            loc[group.key][language] = neon_formatting.colorize(clean, color)
        end
    end

    return loc
end

apply_colours()

mod.apply_colours = function()
    apply_colours()
    return loc
end

return loc
