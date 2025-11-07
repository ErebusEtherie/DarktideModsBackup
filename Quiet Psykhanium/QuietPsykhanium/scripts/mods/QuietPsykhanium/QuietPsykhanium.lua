--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Quiet Psykhanium                                                                │
│ Mod Description: No more constant whispering in the psykhanium.                           |
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]

local mod = get_mod("QuietPsykhanium")

local playSound = function(soundfile)
    local world = Managers.world:world("level_world")
    local wwise_world = Managers.world:wwise_world(world)
    WwiseWorld.trigger_resource_event(wwise_world, soundfile)
end
local TIMER = 1
local timer = 0
local count = 0
mod:hook_safe("WwiseWorld","trigger_resource_event",function(s, file_path, ...)
    if file_path == "wwise/events/ui/play_hud_tg_exit_portal_loop" then
        timer = TIMER
        count = 0
        playSound("wwise/events/world/stop_all_mission_sounds")
    end
    -- if file_path == "wwise/events/ui/play_hud_tg_exit_portal_loop"
end)

mod.update = function(dt)
    if timer > 0 then
        timer = timer - dt
        if timer <= 0 then
            timer = TIMER
            count = count + 1
            if count < 3 then
                playSound("wwise/events/world/stop_all_mission_sounds")
            end
        end
    end
end