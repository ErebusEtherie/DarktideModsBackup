-- File: ZipIt2/scripts/mods/ZipIt2/ZipIt2.lua
local mod = get_mod("ZipIt2")
if not mod then return end

mod.version = "ZipIt2 1.0.0"

if mod._zipit2_loaded then return end
mod._zipit2_loaded                         = true

-- ---------------------------------------------------------------------------
-- Requires
-- ---------------------------------------------------------------------------
local DialogueExtension                    = require("scripts/extension_systems/dialogue/dialogue_extension")
local LocalWaitForMissionBriefingDoneState = require(
    "scripts/loading/local_states/local_wait_for_mission_briefing_done_state")
local LobbyView                            = require("scripts/ui/views/lobby_view/lobby_view")
local MissionIntroView                     = require("scripts/ui/views/mission_intro_view/mission_intro_view")

local type, string, rawget, _G             = type, string, rawget, _G

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
mod._zipit2_state                          = mod._zipit2_state or {
    in_lobby_view = false,
    in_mission_intro_view = false,
    in_briefing_state = false,
    started_from_lobby = false,
    blocked_briefing_vo = false,
}

-- ---------------------------------------------------------------------------
-- Settings cache (single read on init; only updated via mod.on_setting_changed)
-- ---------------------------------------------------------------------------
mod._zipit2_settings                       = mod._zipit2_settings or {
    briefing_mute_mode = "rejoin_only",
    player_enabled = {},
    minor_enabled = {},
    major = {},
}

local S                                    = mod._zipit2_settings

local function _ensure_major_state(class_key)
    local state = S.major[class_key]
    if not state then
        state = { briefings_enabled = true, chatter = "none" }
        S.major[class_key] = state
    end
    return state
end

local function _cache_all_settings_once()
    S.player_enabled = {}
    S.minor_enabled = {}
    S.major = {}

    local mode = mod:get("briefing_mute_mode")
    S.briefing_mute_mode = (type(mode) == "string" and mode ~= "") and mode or "rejoin_only"

    local ids = mod._zipit2_setting_ids
    if type(ids) ~= "table" then return end

    if type(ids.player) == "table" then
        local count = #ids.player
        for i = 1, count do
            local setting_id = ids.player[i]
            local voice = string.sub(setting_id, 14) -- #"mute_player__" + 1
            local val = mod:get(setting_id)
            S.player_enabled[voice] = (val ~= "both")
        end
    end

    if type(ids.major_briefing) == "table" then
        local count = #ids.major_briefing
        for i = 1, count do
            local setting_id = ids.major_briefing[i]
            local class_key = string.match(setting_id, "^mute_major__(.+)__briefings$")
            if class_key then
                _ensure_major_state(class_key).briefings_enabled = mod:get(setting_id) == true
            end
        end
    end

    if type(ids.major_chatter) == "table" then
        local count = #ids.major_chatter
        for i = 1, count do
            local setting_id = ids.major_chatter[i]
            local class_key = string.match(setting_id, "^mute_major__(.+)__chatter$")
            if class_key then
                local v = mod:get(setting_id)
                if v ~= "none" and v ~= "hub" and v ~= "mission" and v ~= "both" then v = "none" end
                _ensure_major_state(class_key).chatter = v
            end
        end
    end

    if type(ids.minor) == "table" then
        local count = #ids.minor
        for i = 1, count do
            local setting_id = ids.minor[i]
            local group_key = string.sub(setting_id, 13) -- #"mute_minor__" + 1
            S.minor_enabled[group_key] = mod:get(setting_id) == true
        end
    end
end

_cache_all_settings_once()

function mod.on_setting_changed(setting_id)
    if setting_id == "briefing_mute_mode" then
        local mode = mod:get(setting_id)
        mode = (type(mode) == "string" and mode ~= "") and mode or "rejoin_only"
        S.briefing_mute_mode = mode
        return
    end

    if type(setting_id) ~= "string" then return end

    if string.find(setting_id, "mute_player__", 1, true) == 1 then
        local voice = string.sub(setting_id, 14)
        local val = mod:get(setting_id)
        S.player_enabled[voice] = (val ~= "both")
        return
    end

    if string.find(setting_id, "mute_minor__", 1, true) == 1 then
        local group_key = string.sub(setting_id, 13)
        S.minor_enabled[group_key] = mod:get(setting_id) == true
        return
    end

    if string.find(setting_id, "mute_major__", 1, true) == 1 then
        local class_key, suffix = string.match(setting_id, "^mute_major__(.+)__([a-z]+)$")
        if not class_key or not suffix then return end

        if suffix == "briefings" then
            local enabled = mod:get(setting_id) == true
            _ensure_major_state(class_key).briefings_enabled = enabled
            return
        end

        if suffix == "chatter" then
            local v = mod:get(setting_id)
            if v ~= "none" and v ~= "hub" and v ~= "mission" and v ~= "both" then v = "none" end
            _ensure_major_state(class_key).chatter = v
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Core Check
-- ---------------------------------------------------------------------------
local function _should_mute_voice_profile(voice_profile)
    if type(voice_profile) ~= "string" or voice_profile == "" then return false end

    local d = mod._zipit2_discovery
    if not d then return false end

    local st = mod._zipit2_state
    local s = mod._zipit2_settings
    local in_briefings = st.in_lobby_view or st.in_mission_intro_view or st.in_briefing_state

    if in_briefings then
        local mode = s.briefing_mute_mode
        local should_skip = false
        if st.started_from_lobby then
            should_skip = (mode == "lobby_only" or mode == "both")
        else
            should_skip = (mode == "rejoin_only" or mode == "both")
        end
        if should_skip then return true end
    end

    if d.player_voice_set[voice_profile] then
        return s.player_enabled[voice_profile] == false
    end

    local major_key = d.major_voice_to_class[voice_profile]
    if major_key then
        local major_state = s.major[major_key]
        if not major_state then return false end

        if in_briefings then
            return major_state.briefings_enabled == false
        end

        local chatter = major_state.chatter
        if chatter == "none" then return false end
        if chatter == "both" then return true end

        local _Managers = rawget(_G, "Managers")
        local mech = _Managers and _Managers.mechanism
        local is_hub = mech and mech:mechanism_name() == "hub"

        if is_hub then
            return chatter == "mission"
        else
            return chatter == "hub"
        end
    end

    local minor_key = d.minor_voice_to_group[voice_profile]
    if minor_key then
        return s.minor_enabled[minor_key] == false
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Hooks: view state tracking
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Hooks: fast briefing skip
-- ---------------------------------------------------------------------------
mod:hook(LocalWaitForMissionBriefingDoneState, "update", function(func, self, dt)
    local st = mod._zipit2_state
    st.in_briefing_state = true

    local mode = mod._zipit2_settings.briefing_mute_mode
    local should_skip = false

    if st.started_from_lobby then
        should_skip = (mode == "lobby_only" or mode == "both")
    else
        should_skip = (mode == "rejoin_only" or mode == "both")
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

-- ---------------------------------------------------------------------------
-- Hooks: VO suppression
-- ---------------------------------------------------------------------------
mod:hook(DialogueExtension, "play_event", function(func, self, event)
    if not mod:is_enabled() then return func(self, event) end

    local voice_profile = self and self._vo_profile_name
    if voice_profile and _should_mute_voice_profile(voice_profile) then
        local st = mod._zipit2_state
        if st.in_lobby_view or st.in_mission_intro_view or st.in_briefing_state then
            st.blocked_briefing_vo = true
        end
        return
    end
    return func(self, event)
end)
