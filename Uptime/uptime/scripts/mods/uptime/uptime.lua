--[[
  Uptime Mod - Main File
  
  This mod tracks buff uptime during missions and provides a history view to review past data.
  
  Features:
  - Track buff uptime during missions
  - View detailed statistics for each buff
  - Browse history of past tracking sessions
  - Toggle tracking with a simple command
--]]

local mod = get_mod("uptime")

local view_name = "uptime_view"
-- ===== Load Required Files =====
-- Core functionality
mod:io_dofile("uptime/scripts/mods/uptime/libs/_libs")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_tracking")  -- Buff tracking calculations
mod:io_dofile("uptime/scripts/mods/uptime/data/uptime_io")           -- File I/O operations
mod:io_dofile("uptime/scripts/mods/uptime/uptime_ui")           -- UI components
mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history")  -- History functionality

-- ===== Register Commands =====
-- Toggle uptime tracking (start/stop)
mod:command("u", "Toggle uptime tracking", function()
    if mod:try_start_tracking({ mission_name = "test", mechanism_data = {} }) then
        mod:debug("tracking started")
    else
        mod:debug("tracking ended")
        mod:try_end_tracking()
    end
end)

-- Open uptime history view
mod:command("uh", "Open uptime history view", function()
    mod:show_uptime_history_view()
end)
-- Open uptime history view
mod:command("uv", "Open uptime history view", function()
    mod:close_view()
end)

mod:command("uc", "close uptime history view", function()
    mod:close_view()
end)

function mod:close_view()
    if Managers.ui:view_active(view_name) and not Managers.ui:is_view_closing(view_name) then
        Managers.ui:close_view(view_name, true)
    end
end

-- ===== Game Hooks =====
-- Stop tracking when exiting talent builder to prevent false readings
mod:hook_safe(CLASS.TalentBuilderView, "on_exit", function(func, self, widget)
    -- When changing talents we suddenly get all buffs at once, so instead we just stop tracking
    mod:try_end_tracking()
end)

mod:hook(CLASS.StateGameplay, "on_enter", function(func, self, parent, params, creation_context, ...)
    local mission_name = params.mission_name
    local track_mission = mission_name ~= "hub_ship" and (mod:get("track_meat_grinder") or mission_name ~= "tg_shooting_range")
    if track_mission then
        local tracking_started = mod:try_start_tracking(params)
        if not tracking_started then
            mod:echo("FAILED to start tracking: " .. mod.libs.missions.localize_name(mission_name))
        end
    end
    func(self, parent, params, creation_context, ...)
end)

mod:hook(CLASS.StateGameplay, "on_exit", function(func, self, exit_params, ...)
    mod:try_end_tracking()
    func(self, exit_params, ...)
end)

-- ===== Initialize Views =====
-- Register and load the uptime history view
mod:register_uptime_history_view()
mod:register_uptime_view()