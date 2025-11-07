local mod = get_mod("uptime")

-- Register uptime history view
mod.register_uptime_history_view = function(self)
    self:add_require_path("uptime/scripts/mods/uptime/history/uptime_history_view")
    self:add_require_path("uptime/scripts/mods/uptime/history/uptime_history_view_definitions")
    self:add_require_path("uptime/scripts/mods/uptime/history/uptime_history_view_settings")
    self:register_view({
        view_name = "uptime_history_view",
        view_settings = {
            init_view_function = function (ingame_ui_context)
                return true
            end,
            class = "UptimeHistoryView",
            disable_game_world = false,
            display_name = "Uptime History",
            game_world_blur = 1.1,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/options_view/options_view",
            path = "uptime/scripts/mods/uptime/history/uptime_history_view",
            state_bound = true,
            enter_sound_events = {
                "wwise/events/ui/play_ui_enter_short"
            },
            exit_sound_events = {
                "wwise/events/ui/play_ui_back_short"
            },
            wwise_states = {
                options = "ingame_menu"
            },
        },
        view_transitions = {},
        view_options = {
            close_all = true,
            close_previous = true,
            close_transition_time = nil,
            transition_time = nil
        }
    })
    self:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_view")
end

-- Show uptime history view
mod.show_uptime_history_view = function(self)
    if Managers.ui:view_active("uptime_history_view") and not Managers.ui:is_view_closing("uptime_history_view") then
        Managers.ui:close_view("uptime_history_view", true)
    else
        Managers.ui:open_view("uptime_history_view", nil, false, false, nil, {}, {use_transition_ui = false})
    end
end