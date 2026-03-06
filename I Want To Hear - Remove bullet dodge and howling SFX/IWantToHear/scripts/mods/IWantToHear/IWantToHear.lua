local mod = get_mod("IWantToHear")
local enabled = true


mod:hook("WwiseWorld","trigger_resource_event",function(func, s, file_path, ...)
    if enabled and not mod:get("bullet") and file_path == "wwise/events/player/play_player_dodge_ranged_success" then return end
    if enabled and not mod:get("dog") and file_path == "wwise/events/minions/play_enemy_chaos_hound_spawn" then return end

    return func(s, file_path, ...)
end)

function mod.on_enabled()
    enabled = true
end
function mod.on_disabled()
    enabled = false
end