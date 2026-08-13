local settings = {}
local color_defaults = get_mod("Killfeed_Reborn"):io_dofile("Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/color_defaults")

local function copy_color(prefix)
    local color = color_defaults[prefix]
    return { color[1], color[2], color[3] }
end

local function refresh_color(mod, target, prefix)
    local defaults = color_defaults[prefix]

    target[1] = mod:get(prefix .. "_r") or defaults[1]
    target[2] = mod:get(prefix .. "_g") or defaults[2]
    target[3] = mod:get(prefix .. "_b") or defaults[3]
end

-- Settings (cached values)
function settings.defaults()
    return {
        metrics = "team",
        message_duration = 5,
        fade_out = 1,
        generic_specific = 70,
        funny_chance = 10,
        neon = true,
        neon_everything = false,
        max_messages = 8,
        unknown_profile_logging = false,
        chat_colors = true,
    }
end

-- Colors (cached values)
function settings.default_colors()
    return {
        killers = {
            [1] = copy_color("killer_1"),
            [2] = copy_color("killer_2"),
            [3] = copy_color("killer_3"),
            [4] = copy_color("killer_4"),
        },
        action = copy_color("action"),
        death_action = copy_color("death_action"),
        error = copy_color("death_action"),
        victim = copy_color("victim"),
        neon = {
            copy_color("neon_start"),
            copy_color("neon_middle"),
            copy_color("neon_end"),
        },
    }
end

function settings.refresh(mod, cache, colors)
    cache.metrics = mod:get("metrics") or "team"
    cache.message_duration = mod:get("message_duration") or 5
    cache.fade_out = mod:get("fade_out") or 1
    cache.generic_specific = mod:get("generic_specific") or 70
    cache.funny_chance = mod:get("funny_chance") or 10
    cache.neon = mod:get("neon") ~= false
    cache.neon_everything = mod:get("neon_everything") == true
    cache.max_messages = mod:get("max_messages") or 8
    cache.unknown_profile_logging = mod:get("unknown_profile_logging") == true
    cache.chat_colors = mod:get("chat_colors") ~= false

    refresh_color(mod, colors.killers[1], "killer_1")
    refresh_color(mod, colors.killers[2], "killer_2")
    refresh_color(mod, colors.killers[3], "killer_3")
    refresh_color(mod, colors.killers[4], "killer_4")
    refresh_color(mod, colors.action, "action")
    refresh_color(mod, colors.death_action, "death_action")
    refresh_color(mod, colors.error, "death_action")
    refresh_color(mod, colors.victim, "victim")
    refresh_color(mod, colors.neon[1], "neon_start")
    refresh_color(mod, colors.neon[2], "neon_middle")
    refresh_color(mod, colors.neon[3], "neon_end")
end

return settings
