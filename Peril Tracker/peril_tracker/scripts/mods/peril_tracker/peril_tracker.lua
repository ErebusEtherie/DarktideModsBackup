--[[
    peril_tracker.lua — Main entry point

    Tracks peril % every N seconds during a mission (Psyker only).
    Sessions are saved to /AppData/Roaming/Fatshark/Darktide/peril_tracker/
    as JSON files, and can be reviewed in the history view (default F9).
--]]

local mod = get_mod("peril_tracker")

-- ===== Load libraries and sub-modules =====
mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/libs/_libs")
mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/data/peril_io")
mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/tracking/peril_tracking")

-- ===== Stored session (read by chart view) =====
mod._last_peril_session = nil

-- ===== View names =====
local HISTORY_VIEW_NAME = "peril_history_view"
local CHART_VIEW_NAME   = "peril_chart_view"

-- ===== Register history view =====
local function register_history_view()
    mod:add_require_path("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view")
    mod:add_require_path("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view_definitions")
    mod:add_require_path("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view_settings")
    mod:add_require_path("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view_blueprints")

    mod:register_view({
        view_name = HISTORY_VIEW_NAME,
        view_settings = {
            init_view_function = function(_) return true end,
            class               = "PerilHistoryView",
            disable_game_world  = false,
            display_name        = "Peril History",
            game_world_blur     = 1.1,
            load_always         = true,
            load_in_hub         = true,
            package             = "packages/ui/views/options_view/options_view",
            path                = "peril_tracker/scripts/mods/peril_tracker/history/peril_history_view",
            state_bound         = true,
            enter_sound_events  = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events   = { "wwise/events/ui/play_ui_back_short" },
            wwise_states        = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = {
            close_all             = true,
            close_previous        = true,
            close_transition_time = nil,
            transition_time       = nil,
        },
    })
    mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view")
end

-- ===== Register chart view =====
local function register_chart_view()
    mod:add_require_path("peril_tracker/scripts/mods/peril_tracker/view/peril_view")
    mod:add_require_path("peril_tracker/scripts/mods/peril_tracker/view/peril_view_definitions")

    mod:register_view({
        view_name = CHART_VIEW_NAME,
        view_settings = {
            init_view_function = function(_) return true end,
            class               = "PerilChartView",
            disable_game_world  = false,
            display_name        = "Peril Chart",
            game_world_blur     = 0,
            load_always         = true,
            load_in_hub         = true,
            package             = "packages/ui/views/options_view/options_view",
            path                = "peril_tracker/scripts/mods/peril_tracker/view/peril_view",
            state_bound         = true,
            enter_sound_events  = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events   = { "wwise/events/ui/play_ui_back_short" },
            wwise_states        = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = {
            close_all             = false,
            close_previous        = true,
            close_transition_time = nil,
            transition_time       = nil,
        },
    })
    mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/view/peril_view")
end

register_history_view()
register_chart_view()

-- ===== Helpers =====

function mod:now()
    if not Managers.time:has_timer("gameplay") then return 0 end
    return Managers.time:time("gameplay")
end

-- ===== Chat commands =====

local function close_all_views()
    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
    end
    if Managers.ui:view_active(HISTORY_VIEW_NAME) and not Managers.ui:is_view_closing(HISTORY_VIEW_NAME) then
        Managers.ui:close_view(HISTORY_VIEW_NAME, true)
    end
end

-- !pt  — open/close history view
mod:command("pt", "Open/close peril history", function()
    if Managers.ui:view_active(HISTORY_VIEW_NAME) or Managers.ui:view_active(CHART_VIEW_NAME) then
        close_all_views()
    else
        Managers.ui:open_view(HISTORY_VIEW_NAME, nil, false, false, nil, nil)
    end
end)

-- !ptc — open chart for most recent session directly
mod:command("ptc", "Open peril chart for last session", function()
    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
    else
        Managers.ui:open_view(CHART_VIEW_NAME, nil, false, false, nil, nil)
    end
end)

-- ===== Mission hooks =====

mod:hook(CLASS.StateGameplay, "on_enter", function(func, self, parent, params, creation_context, ...)
    local mission_name    = params.mission_name
    local is_real_mission = mission_name ~= "hub_ship" and mission_name ~= "tg_shooting_range"
    if is_real_mission then
        -- Only track for Psyker — warp charge is Psyker-exclusive
        local ok, is_psyker = pcall(function()
            local player = Managers.player:local_player(1)
            return player and player:archetype_name() == "psyker"
        end)
        if ok and is_psyker then
            mod:start_peril_tracking()
            mod._current_mission_params = params
        end
    end
    func(self, parent, params, creation_context, ...)
end)

mod:hook(CLASS.StateGameplay, "on_exit", function(func, self, exit_params, ...)
    mod:end_peril_tracking()
    func(self, exit_params, ...)
end)

mod:hook_safe(CLASS.TalentBuilderView, "on_exit", function()
    mod:end_peril_tracking()
end)
