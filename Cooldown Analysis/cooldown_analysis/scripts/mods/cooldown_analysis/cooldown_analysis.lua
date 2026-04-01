--[[
    cooldown_analysis.lua — Main entry point

    Tracks combat ability cooldown durations for all archetypes.
    For Psyker, also records Warp Siphon (Souls) stacks at each ability use.

    Sessions are saved to:
        %AppData%/Fatshark/Darktide/cooldown_analysis/

    Open the history view with the keybind (default F10), or type !ca in chat.
    Click any session in the list to see its bar chart.
--]]

local mod = get_mod("cooldown_analysis")

-- ===== Load libraries and sub-modules =====
mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/libs/_libs")
mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/data/cooldown_io")
mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/tracking/cooldown_tracking")

-- ===== State =====
mod._last_cooldown_session  = nil
mod._current_mission_params = nil

-- ===== View names =====
local HISTORY_VIEW_NAME = "cooldown_history_view"
local CHART_VIEW_NAME   = "cooldown_chart_view"

-- ===== Register history (session list) view =====
local function register_history_view()
    mod:add_require_path("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view")
    mod:add_require_path("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view_definitions")
    mod:add_require_path("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view_settings")
    mod:add_require_path("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view_blueprints")

    mod:register_view({
        view_name = HISTORY_VIEW_NAME,
        view_settings = {
            init_view_function = function(_) return true end,
            class               = "CooldownHistoryView",
            disable_game_world  = false,
            display_name        = "Cooldown History",
            game_world_blur     = 1.1,
            load_always         = true,
            load_in_hub         = true,
            package             = "packages/ui/views/options_view/options_view",
            path                = "cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view",
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
    mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view")
end

-- ===== Register chart (per-session bar chart) view =====
local function register_chart_view()
    mod:add_require_path("cooldown_analysis/scripts/mods/cooldown_analysis/view/cooldown_view")
    mod:add_require_path("cooldown_analysis/scripts/mods/cooldown_analysis/view/cooldown_view_definitions")

    mod:register_view({
        view_name = CHART_VIEW_NAME,
        view_settings = {
            init_view_function = function(_) return true end,
            class               = "CooldownChartView",
            disable_game_world  = false,
            display_name        = "Cooldown Chart",
            game_world_blur     = 0,
            load_always         = true,
            load_in_hub         = true,
            package             = "packages/ui/views/options_view/options_view",
            path                = "cooldown_analysis/scripts/mods/cooldown_analysis/view/cooldown_view",
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
    mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/view/cooldown_view")
end

register_history_view()
register_chart_view()

-- ===== Helpers =====

function mod:now()
    if not Managers.time:has_timer("gameplay") then return 0 end
    return Managers.time:time("gameplay")
end

local function close_all_views()
    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
    end
    if Managers.ui:view_active(HISTORY_VIEW_NAME) and not Managers.ui:is_view_closing(HISTORY_VIEW_NAME) then
        Managers.ui:close_view(HISTORY_VIEW_NAME, true)
    end
end

-- ===== Chat commands =====

-- !ca — open/close history view
mod:command("ca", "Open/close cooldown history", function()
    if Managers.ui:view_active(HISTORY_VIEW_NAME) or Managers.ui:view_active(CHART_VIEW_NAME) then
        close_all_views()
    else
        Managers.ui:open_view(HISTORY_VIEW_NAME, nil, false, false, nil, nil)
    end
end)

-- !cac — open chart for most recent session directly
mod:command("cac", "Open cooldown chart for last session", function()
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
        local ok, is_psyker = pcall(function()
            local player = Managers.player:local_player(1)
            return player and player:archetype_name() == "psyker"
        end)
        local psyker = ok and is_psyker or false

        mod._current_mission_params = params
        mod:start_cooldown_tracking(psyker)
    end

    func(self, parent, params, creation_context, ...)
end)

mod:hook(CLASS.StateGameplay, "on_exit", function(func, self, exit_params, ...)
    mod:end_cooldown_tracking()
    func(self, exit_params, ...)
end)

-- Safety net: end tracking if the talent builder is opened mid-mission
-- (same pattern as uptime/peril tracker)
mod:hook_safe(CLASS.TalentBuilderView, "on_exit", function()
    mod:end_cooldown_tracking()
end)
