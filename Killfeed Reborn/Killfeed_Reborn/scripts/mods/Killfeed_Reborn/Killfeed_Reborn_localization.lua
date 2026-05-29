local mod = get_mod("Killfeed_Reborn")

local loc = {
    mod_name = {
        en = "Killfeed Reborn",
    },
    mod_description = {
        en = "Replaces your Killfeed with more calculated, fun, and personalized phrases.\n\n"
            .. "{#color(210,180,120)}Author: {#color(200,220,180)}BadId34{#reset()}\n"
            .. "{#color(210,180,120)}Version: {#color(200,220,180)}1.8.4{#reset()}",
    },
    debug_settings = {
        en = "{#color(210,0,255)}Debug Settings{#reset()}",
    },

    killfeed_settings_group = {
        en = "Killfeed Settings",
    },

    killfeed_color_group = {
        en = "Killfeed Colors",
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
        en = "{#color(255,0,180)}F{#color(255,36,191)}u{#color(255,73,201)}n{#color(255,109,212)}n{#color(255,146,223)}y {#color(255,182,234)}P{#color(255,219,244)}h{#color(255,255,255)}r{#color(255,251,219)}a{#color(255,248,182)}s{#color(255,244,146)}e {#color(255,241,109)}N{#color(255,237,73)}e{#color(255,234,36)}o{#color(255,230,0)}n{#reset()}",
    },
    neon_description = {
        en = "Applies neon colors to Funny phrase rolls.",
    },

    output_to_file = {
        en = "Output to File",
    },
    output_to_file_description = {
        en = "Saves Killfeed to a local file. Path: %APPDATA%/Fatshark/Darktide/Killfeed_Reborn_output/",
    },

    category_check = {
        en = "Category Check",
    },
    category_check_description = {
        en = "Displays the chosen phrase category in the killfeed.",
    },

    local_player = {
        en = "Local Player",
    },
    local_player_description = {
        en = "File shows only local player kills (true) or all players (false).",
    },

    killer_1_color_group = { en = "Killer 1" },
    killer_2_color_group = { en = "Killer 2" },
    killer_3_color_group = { en = "Killer 3" },
    killer_4_color_group = { en = "Killer 4" },
    action_color_group = { en = "Player Kill Phrase" },
    death_action_color_group = { en = "Player Death Phrase" },
    victim_color_group = { en = "Target" },

}

for _, prefix in ipairs({ "killer_1", "killer_2", "killer_3", "killer_4", "action", "death_action", "victim" }) do
    loc[prefix .. "_r"] = { en = "Red" }
    loc[prefix .. "_g"] = { en = "Green" }
    loc[prefix .. "_b"] = { en = "Blue" }
end

for value = 1, 25 do
    loc["num_" .. value] = { en = tostring(value) }
end

local function colorize_text(text, r, g, b)
    return "{#color(" .. r .. "," .. g .. "," .. b .. ")}" .. text .. "{#reset()}"
end

local default_colors = {
    killer_1_r = 255, killer_1_g = 230, killer_1_b = 130,
    killer_2_r = 120, killer_2_g = 180, killer_2_b = 255,
    killer_3_r = 140, killer_3_g = 230, killer_3_b = 170,
    killer_4_r = 255, killer_4_g = 150, killer_4_b = 210,
    action_r = 255, action_g = 255, action_b = 255,
    death_action_r = 175, death_action_g = 0, death_action_b = 255,
    victim_r = 255, victim_g = 90, victim_b = 90,
}

local color_groups = {
    {
        key = "killfeed_color_group",
        static = true,
    },
    {
        key = "killer_1_color_group",
        r = "killer_1_r",
        g = "killer_1_g",
        b = "killer_1_b",
    },
    {
        key = "killer_2_color_group",
        r = "killer_2_r",
        g = "killer_2_g",
        b = "killer_2_b",
    },
    {
        key = "killer_3_color_group",
        r = "killer_3_r",
        g = "killer_3_g",
        b = "killer_3_b",
    },
    {
        key = "killer_4_color_group",
        r = "killer_4_r",
        g = "killer_4_g",
        b = "killer_4_b",
    },
    {
        key = "action_color_group",
        r = "action_r",
        g = "action_g",
        b = "action_b",
    },
    {
        key = "death_action_color_group",
        r = "death_action_r",
        g = "death_action_g",
        b = "death_action_b",
    },
    {
        key = "victim_color_group",
        r = "victim_r",
        g = "victim_g",
        b = "victim_b",
    },
}

local function apply_colours()
    for i = 1, #color_groups do
        local group = color_groups[i]
        if not group.static then
            local r = mod:get(group.r)
            local g = mod:get(group.g)
            local b = mod:get(group.b)

            if r == nil then
                r = default_colors[group.r]
            end

            if g == nil then
                g = default_colors[group.g]
            end

            if b == nil then
                b = default_colors[group.b]
            end

            if r ~= nil and g ~= nil and b ~= nil then
                for language, text in pairs(loc[group.key]) do
                    local clean = string.gsub(text, "{#.-}", "")
                    clean = string.gsub(clean, "{#reset%(%)%}", "")
                    loc[group.key][language] = colorize_text(clean, r, g, b)
                end
            end
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
