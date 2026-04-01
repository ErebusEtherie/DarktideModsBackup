-- File: ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_briefing.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local LobbyView = require("scripts/ui/views/lobby_view/lobby_view")
local MissionIntroView = require("scripts/ui/views/mission_intro_view/mission_intro_view")
local LocalWaitForMissionBriefingDoneState = require(
    "scripts/loading/local_states/local_wait_for_mission_briefing_done_state")

mod.zipit2_register_briefing_hooks = mod.zipit2_register_briefing_hooks or function()
    if mod._zipit2_briefing_hooks_registered then
        return
    end

    mod._zipit2_briefing_hooks_registered = true

    mod:hook(LobbyView, "on_enter", function(func, self, ...)
        local st = mod._zipit2_state
        st.in_lobby_view = true
        st.started_from_lobby = true
        st.blocked_briefing_vo = false

        return func(self, ...)
    end)

    mod:hook(LobbyView, "on_exit", function(func, self, ...)
        mod._zipit2_state.in_lobby_view = false

        return func(self, ...)
    end)

    mod:hook(MissionIntroView, "on_enter", function(func, self, ...)
        local st = mod._zipit2_state
        st.in_mission_intro_view = true
        st.blocked_briefing_vo = false

        return func(self, ...)
    end)

    mod:hook(MissionIntroView, "on_exit", function(func, self, ...)
        mod._zipit2_state.in_mission_intro_view = false

        return func(self, ...)
    end)

    mod:hook(LocalWaitForMissionBriefingDoneState, "update", function(func, self, dt)
        local st = mod._zipit2_state
        st.in_briefing_state = true

        local mode = mod._zipit2_settings.briefing_mute_mode
        local should_skip = false

        if st.started_from_lobby then
            should_skip = mode == "lobby_only" or mode == "both"
        else
            should_skip = mode == "rejoin_only" or mode == "both"
        end

        if should_skip or st.blocked_briefing_vo then
            st.in_briefing_state = false
            st.started_from_lobby = false
            st.blocked_briefing_vo = false

            return "mission_briefing_done"
        end

        local result = func(self, dt)

        if result == "mission_briefing_done" then
            st.in_briefing_state = false
            st.started_from_lobby = false
            st.blocked_briefing_vo = false
        end

        return result
    end)
end
