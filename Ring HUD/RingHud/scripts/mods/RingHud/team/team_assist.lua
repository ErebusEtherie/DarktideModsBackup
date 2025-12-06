-- File: RingHud/scripts/mods/RingHud/team/team_assist.lua
local mod = get_mod("RingHud"); if not mod then return end

---------------------------------------------------------------------
-- Optional require (no pcalls): probe package.preload/loaded first
---------------------------------------------------------------------
local VictimAssist
do
    local path = "scripts/extension_systems/character_state_machine/character_states/utilities/assist"
    local can_require =
        (package and type(package.preload) == "table" and package.preload[path] ~= nil)
        or (package and type(package.loaded) == "table" and package.loaded[path] ~= nil)
    if can_require then
        VictimAssist = require(path)
    end
end

-- Settings / status helpers
local InteractionSettings = require("scripts/settings/interaction/interaction_settings")
local PlayerUnitStatus    = require("scripts/utilities/attack/player_unit_status")

---------------------------------------------------------------------
-- Config / lookups
---------------------------------------------------------------------
-- victim status -> our interaction type (for UI semantics only)
local STATUS_TO_TYPE      = {
    hogtied       = "rescue",
    knocked_down  = "revive",
    netted        = "remove_net",
    ledge_hanging = "pull_up",
}

-- Fixed durations per request (seconds)
local DUR_BY_STATUS       = {
    netted        = 1.0, -- remove_net
    hogtied       = 3.0, -- rescue
    knocked_down  = 3.0, -- revive
    ledge_hanging = 3.0, -- pull_up
}
local DEFAULT_DURATION    = 3.0
local ONGOING_LEEWAY      = (InteractionSettings and InteractionSettings.ongoing_interaction_leeway) or 1.2

---------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------
local function _now()
    return (Managers.time and Managers.time:time("gameplay")) or 0
end

-- Returns one of: "hogtied","knocked_down","ledge_hanging","netted" or nil
local function _status_for_victim(unit)
    if not unit or not HEALTH_ALIVE[unit] then return nil end

    local uds = ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
    if not uds then return nil end

    local cs = uds:read_component("character_state")
    local ds = uds:read_component("disabled_character_state")

    if cs then
        if PlayerUnitStatus.is_hogtied(cs) then return "hogtied" end
        if PlayerUnitStatus.is_knocked_down(cs) then return "knocked_down" end
        if PlayerUnitStatus.is_ledge_hanging(cs) then return "ledge_hanging" end
    end
    if ds and PlayerUnitStatus.is_netted(ds) then
        return "netted"
    end
    return nil
end

local function _unit_display_name(unit)
    local spawn = Managers.state and Managers.state.player_unit_spawn
    if spawn and spawn.alive_players then
        local players = spawn:alive_players() or {}
        for i = 1, #players do
            local p = players[i]
            if p and p.player_unit == unit then
                local nm = (type(p.name) == "function") and p:name() or rawget(p, "name")
                if nm then return nm end
            end
        end
    end
    return tostring(unit)
end

local function _victim_components(unit)
    local uds = unit and ScriptUnit.has_extension(unit, "unit_data_system") and
        ScriptUnit.extension(unit, "unit_data_system")
    if not uds then return nil, nil, nil end
    local assisted   = uds:read_component("assisted_state_input")
    local interactee = uds:read_component("interactee")
    return uds, assisted, interactee
end

local function _assist_duration_for(unit, status)
    -- Prefer a synced duration exposed via the victim's interactee extension (if present on this build)
    local ext = ScriptUnit.has_extension(unit, "interactee_system") and ScriptUnit.extension(unit, "interactee_system")
    if ext and type(ext.interaction_length) == "function" then
        local len = ext:interaction_length()
        if type(len) == "number" and len > 0 then
            return len
        end
    end
    return DUR_BY_STATUS[status] or DEFAULT_DURATION
end

---------------------------------------------------------------------
-- Tracking (victim-side only)
---------------------------------------------------------------------
-- TRACK[unit] = { t0=number, dur=number, status=string }
local TRACK = setmetatable({}, { __mode = "k" }) -- weak keys to avoid leaks

local function _begin_track(unit, status, hint_dur)
    if not unit or not HEALTH_ALIVE[unit] then return end
    local dur = (hint_dur and hint_dur > 0) and hint_dur or _assist_duration_for(unit, status)
    local now = _now()

    local cur = TRACK[unit]
    if cur and cur.status == status then
        -- If we see another start quickly and existing hasn't expired, keep earliest t0 (avoids progress jump-back)
        if now <= (cur.t0 + cur.dur + ONGOING_LEEWAY) then
            return
        end
    end

    TRACK[unit] = { t0 = now, dur = dur, status = status }
    -- Debug:
    -- mod:echo("[RingHud] ASSIST START for %s (%s, dur=%.2fs)", _unit_display_name(unit), status, dur)
end

local function _stop_track(unit, reason)
    if TRACK[unit] then
        -- Debug:
        -- mod:echo("[RingHud] ASSIST END for %s (%s)", _unit_display_name(unit), tostring(reason))
        TRACK[unit] = nil
    end
end

---------------------------------------------------------------------
-- Public API (called by HUD)
---------------------------------------------------------------------
local M = {}

-- Returns: has_assist:boolean, progress:[0..1], is_pull_up:boolean
function M.progress_for_victim(victim_unit)
    if not victim_unit or not HEALTH_ALIVE[victim_unit] then
        return false, 0, false
    end

    local status = _status_for_victim(victim_unit)
    local uds, assisted, interactee = _victim_components(victim_unit)

    -- If no longer distressed, drop any running bar
    if not status then
        if TRACK[victim_unit] then _stop_track(victim_unit, "status_cleared") end
        return false, 0, false
    end

    -- Read victim-side signals (either can drive start/abort)
    local in_progress     = assisted and (assisted.in_progress == true) or false
    local interacted_with = interactee and (interactee.interacted_with == true) or false

    -- START: if we're distressed and either 'in_progress' or 'interacted_with' is true, ensure tracking exists
    if (in_progress or interacted_with) and not TRACK[victim_unit] then
        _begin_track(victim_unit, status, nil) -- duration resolved inside
    end

    -- ABORT: if we were tracking but neither signal is true anymore (and still distressed), stop early
    if TRACK[victim_unit] and (not in_progress and not interacted_with) then
        _stop_track(victim_unit, "abort_signals_cleared")
        return false, 0, false
    end

    local b = TRACK[victim_unit]
    if not b then
        return false, 0, false
    end

    -- If distressed kind changed mid-way, cancel (prevents wrong-type bar)
    if status ~= b.status then
        _stop_track(victim_unit, "status_changed")
        return false, 0, false
    end

    -- Progress
    local now = _now()
    local f = math.clamp((now - b.t0) / (b.dur > 0 and b.dur or 1e-6), 0, 1)

    -- Timeout (covers silent cancels if neither stop nor abort signals arrived)
    if now > (b.t0 + b.dur + ONGOING_LEEWAY) then
        _stop_track(victim_unit, "timeout")
        return false, 0, false
    end

    return true, f, (b.status == "ledge_hanging")
end

---------------------------------------------------------------------
-- Optional: VictimAssist hooks (also victim/anim based; complements polling)
-- If present on the build, these provide explicit start/abort/stop from the victim’s state machine.
---------------------------------------------------------------------
if VictimAssist then
    -- Start when the victim's assisted state flips in_progress=true
    local function _assist_start_from_anim(self)
        local comp = self._assisted_state_input_component
        if not comp then return end
        if not self._was_in_progress and comp.in_progress then
            local unit   = self._unit
            local status = _status_for_victim(unit)
            if status then
                _begin_track(unit, status, _assist_duration_for(unit, status))
            end
        end
    end

    -- Abort
    local function _assist_abort_from_anim(self)
        if self._was_in_progress and self._assisted_state_input_component and not self._assisted_state_input_component.in_progress then
            _stop_track(self._unit, "anim_abort")
        end
    end

    -- Stop (success)
    local function _assist_stop_from_anim(self)
        _stop_track(self._unit, "assist_stop")
    end

    mod:hook_safe(VictimAssist, "_try_start_anim", _assist_start_from_anim)
    mod:hook_safe(VictimAssist, "_try_abort_anim", _assist_abort_from_anim)
    mod:hook_safe(VictimAssist, "stop", _assist_stop_from_anim)
end

return M
