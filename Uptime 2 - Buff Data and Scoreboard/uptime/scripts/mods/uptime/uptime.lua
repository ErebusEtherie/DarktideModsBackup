-- File: uptime/scripts/mods/uptime/uptime.lua
--[[
  Uptime Mod - Main File

  This mod tracks buff uptime during missions and provides a history view to review past data.

  Features:
  - Track buff uptime during missions
  - View detailed statistics for each buff
  - Browse history of past tracking sessions
  - Toggle tracking with a simple command
--]]

local mod = get_mod("uptime"); if not mod then return end
mod.version = "Uptime2 v2.10"

local view_name = "uptime_view"

local TRACK_DAMAGE_OFF = "off"
local TRACK_DAMAGE_VIEW = "view"
local TRACK_DAMAGE_VIEW_AND_TACTICAL = "view_and_tactical"
local TRACK_DAMAGE_VIEW_TACTICAL_END = "view_tactical_end"
local TRACK_DAMAGE_DEFAULT = TRACK_DAMAGE_VIEW_AND_TACTICAL

local VALID_TRACK_DAMAGE_MODES = {
    [TRACK_DAMAGE_OFF] = true,
    [TRACK_DAMAGE_VIEW] = true,
    [TRACK_DAMAGE_VIEW_AND_TACTICAL] = true,
    [TRACK_DAMAGE_VIEW_TACTICAL_END] = true,
}

local SETTINGS_TO_CACHE = {
    "track_meat_grinder",
    "delete_old_entries",
    "legacy_history_compatibility",
    "number_of_save_files",
    "show_uptime_mode",
    "show_uptime_combat_mode",
    "show_combat_percentage_per_stack",
    "show_combat_max_stack_mode",
    "show_average_stacks_combat",
    "track_damage",
}

local function repair_track_damage_setting(track_damage_mode)
    if VALID_TRACK_DAMAGE_MODES[track_damage_mode] then
        return track_damage_mode
    end

    mod:set("track_damage", TRACK_DAMAGE_DEFAULT, true)

    return TRACK_DAMAGE_DEFAULT
end

local function cache_setting(setting_id)
    if setting_id == "track_meat_grinder" then
        mod.track_meat_grinder = mod:get("track_meat_grinder")
    elseif setting_id == "delete_old_entries" then
        mod.delete_old_entries = mod:get("delete_old_entries")
    elseif setting_id == "legacy_history_compatibility" then
        mod.legacy_history_compatibility = mod:get("legacy_history_compatibility")
    elseif setting_id == "number_of_save_files" then
        mod.number_of_save_files = tonumber(mod:get("number_of_save_files")) or 30
    elseif setting_id == "show_uptime_mode" then
        mod.show_uptime_mode = mod:get("show_uptime_mode") or "none"
    elseif setting_id == "show_uptime_combat_mode" then
        mod.show_uptime_combat_mode = mod:get("show_uptime_combat_mode") or "percentage"
    elseif setting_id == "show_combat_percentage_per_stack" then
        mod.show_combat_percentage_per_stack = mod:get("show_combat_percentage_per_stack")
    elseif setting_id == "show_combat_max_stack_mode" then
        mod.show_combat_max_stack_mode = mod:get("show_combat_max_stack_mode") or "percentage"
    elseif setting_id == "show_average_stacks_combat" then
        mod.show_average_stacks_combat = mod:get("show_average_stacks_combat")
    elseif setting_id == "track_damage" then
        mod.track_damage_mode = repair_track_damage_setting(mod:get("track_damage"))
    end
end

function mod.cache_uptime_settings()
    for i = 1, #SETTINGS_TO_CACHE do
        cache_setting(SETTINGS_TO_CACHE[i])
    end
end

function mod.on_setting_changed(setting_id)
    cache_setting(setting_id)
end

function mod.scoreboard_tracking_enabled()
    return mod.track_damage_mode == TRACK_DAMAGE_VIEW
        or mod.track_damage_mode == TRACK_DAMAGE_VIEW_AND_TACTICAL
        or mod.track_damage_mode == TRACK_DAMAGE_VIEW_TACTICAL_END
end

function mod.tactical_scoreboard_enabled()
    return mod.track_damage_mode == TRACK_DAMAGE_VIEW_AND_TACTICAL
        or mod.track_damage_mode == TRACK_DAMAGE_VIEW_TACTICAL_END
end

function mod.end_view_scoreboard_enabled()
    return mod.track_damage_mode == TRACK_DAMAGE_VIEW_TACTICAL_END
end

mod.cache_uptime_settings()

-- ===== Load Required Files =====
-- Core functionality
mod:io_dofile("uptime/scripts/mods/uptime/libs/_libs")
mod:io_dofile("uptime/scripts/mods/uptime/libs/scoreboard_stats")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_damage_tracking") -- DAMAGE TRACKING INCLUSION
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_tracking")        -- Buff tracking calculations
mod:io_dofile("uptime/scripts/mods/uptime/data/uptime_io")                  -- File I/O operations
mod:io_dofile("uptime/scripts/mods/uptime/uptime_ui")                       -- UI components
mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history")          -- History functionality
mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_tactical_overlay")

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
    local track_mission = mission_name ~= "hub_ship" and
        (mod.track_meat_grinder or mission_name ~= "tg_shooting_range")
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

-- ===== Print Mod Version to console_log =====
mod.on_all_mods_loaded = function()
    mod:info(mod.version)
end
