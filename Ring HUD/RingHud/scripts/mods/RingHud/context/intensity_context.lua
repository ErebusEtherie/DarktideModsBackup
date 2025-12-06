-- File: RingHud/scripts/mods/RingHud/context/intensity_context.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local PlayerUnitStatus   = require("scripts/utilities/attack/player_unit_status")

mod.intensity            = mod.intensity or {}
local I                  = mod.intensity

-- Optional team status helper (preferred source for dead/hogtied)
local TeamStatus         = rawget(mod, "team_status") -- set by team/status.lua

-- ===== Internal state =========================================================
I._MUSIC_FAILSAFE_SEC    = 180
I._music_high_until_t    = 0
I._music_last_state      = false

I._timer_high_until_t    = 0
I._timer_last_state      = false
I._was_high_intensity    = false -- New state tracker

-- Derived sources
I._event_obj_active      = false -- any active mid_event / end_event
I._music_prox_active     = false -- music proximity trigger currently active (event-started)
I._team_collapse_active  = false -- >=3 dead/hogtied teammates while local alive

-- Poll throttles
I._next_music_poll_t     = 0     -- throttle: 1 Hz while _music_prox_active
I._next_objective_poll_t = 0     -- throttle: 1 Hz if manager isn't polling
I._obj_polled_this_frame = false -- vanilla HUD manager can set this true per frame

-- Optional raw flag compatibility
I._raw_high_intensity    = rawget(mod, "high_intensity") == true

-- ===== Clock helper ===========================================================
local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("ui") or MT:time("gameplay") or os.clock()
    end
    return os.clock()
end

-- ===== Local player/unit helpers =============================================
local function _local_player_unit()
    local MP = Managers.player
    local local_player = MP and MP.local_player_safe and MP:local_player_safe(1)
    return local_player and local_player.player_unit or nil
end

function I.local_player_dead_or_hogtied()
    local u = _local_player_unit()
    if not (u and Unit.alive(u)) then return true end

    if TeamStatus and TeamStatus.for_unit then
        local kind = TeamStatus.for_unit(u)
        return kind == "dead" or kind == "hogtied" or kind == "knocked_down" or kind == "ledge_hanging"
    end

    -- Fallback (direct)
    local uds = ScriptUnit.has_extension(u, "unit_data_system") and ScriptUnit.extension(u, "unit_data_system") or nil
    local he  = ScriptUnit.has_extension(u, "health_system") and ScriptUnit.extension(u, "health_system") or nil
    if not (uds and he) then return false end

    local cs = uds.read_component and uds:read_component("character_state")
    if not cs then return false end

    if PlayerUnitStatus.is_dead and PlayerUnitStatus.is_dead(cs, he) then return true end
    if PlayerUnitStatus.is_hogtied and PlayerUnitStatus.is_hogtied(cs) then return true end
    if PlayerUnitStatus.is_disabled and PlayerUnitStatus.is_disabled(cs) then return true end
    return false
end

-- ===== Legacy music/timer sources (kept for compatibility) ====================
function I.set_music_high(is_high)
    local now = _now()
    I._music_last_state = (is_high == true)
    if I._music_last_state then
        I._music_high_until_t = now + (I._MUSIC_FAILSAFE_SEC or 180)
    end
end

function I.is_music_high()
    local now = _now()
    if I._music_last_state then return true end
    return now < (I._music_high_until_t or 0)
end

function I.set_timer_active(is_active, ttl_seconds)
    local now = _now()
    I._timer_last_state = (is_active == true)
    if I._timer_last_state and tonumber(ttl_seconds) and ttl_seconds > 0 then
        I._timer_high_until_t = now + ttl_seconds
    elseif not I._timer_last_state then
        I._timer_high_until_t = 0
    end
end

function I.is_timer_active()
    local now = _now()
    if I._timer_last_state then return true end
    return now < (I._timer_high_until_t or 0)
end

-- ===== Music proximity (event-started, polling-ended) =========================

-- Polls proximity on the local player (used during active window)
local function _music_proximity_now()
    local u = _local_player_unit()
    if not (u and Unit.alive(u)) then return false end

    local mpe = ScriptUnit.has_extension(u, "music_parameter_system") and
        ScriptUnit.extension(u, "music_parameter_system") or nil
    if not mpe then return false end

    -- Be defensive about method presence; treat any true as proximity.
    if mpe.vector_horde_near and mpe:vector_horde_near() then return true end
    if mpe.ambush_horde_near and mpe:ambush_horde_near() then return true end
    if mpe.last_man_standing and mpe:last_man_standing() then return true end
    if mpe.boss_near and mpe:boss_near() then return true end

    return false
end

-- ===== Mission objectives (mid_event/end_event) ===============================
-- Vanilla HUD manager can tell us it already polled this frame (to avoid our own scan).
function I.objectives_polled_this_frame()
    I._obj_polled_this_frame = true
end

local function _scan_event_objectives()
    local state = Managers.state
    local extm  = state and state.extension
    local mos   = extm and extm:system("mission_objective_system") or nil
    if not mos then return false end

    -- Prefer direct query if present
    if mos.objective_event_type and type(mos.objective_event_type) == "function" then
        local evt = mos:objective_event_type()
        if evt and evt ~= "None" and (evt == "mid_event" or evt == "end_event") then
            return true
        end
    end

    -- Fallback: scan active objectives and inspect their event_type
    local active = mos.active_objectives and mos:active_objectives()
    if type(active) == "table" then
        for objective, _ in pairs(active) do
            local ev
            if type(objective) == "table" then
                if type(objective.event_type) == "function" then
                    ev = objective:event_type()
                else
                    ev = rawget(objective, "event_type")
                end
            end
            if ev == "mid_event" or ev == "end_event" then
                return true
            end
        end
    end

    return false
end

-- ===== Team collapse (≥3 teammates dead/hogtied; local alive) ================
local function _scan_team_collapse()
    if I.local_player_dead_or_hogtied() then
        return false -- requires local alive
    end

    local pm = Managers.player
    if not (pm and pm.players) then return false end

    local players = pm:players()
    if type(players) ~= "table" then return false end

    local local_unit = _local_player_unit()
    local down = 0

    for _, ply in pairs(players) do
        local u = ply and ply.player_unit
        if u and Unit.alive(u) and u ~= local_unit then
            local dead_or_hog =
                (TeamStatus and TeamStatus.for_unit and (function()
                    local k = TeamStatus.for_unit(u)
                    return k == "dead" or k == "hogtied"
                end)())
                or (function()
                    local uds = ScriptUnit.has_extension(u, "unit_data_system") and
                        ScriptUnit.extension(u, "unit_data_system") or nil
                    local he  = ScriptUnit.has_extension(u, "health_system") and ScriptUnit.extension(u, "health_system") or
                        nil
                    if not (uds and he) then return false end
                    local cs = uds.read_component and uds:read_component("character_state")
                    if not cs then return false end
                    local dead = PlayerUnitStatus.is_dead and PlayerUnitStatus.is_dead(cs, he)
                    local hog  = PlayerUnitStatus.is_hogtied and PlayerUnitStatus.is_hogtied(cs)
                    return dead or hog
                end)()

            if dead_or_hog then
                down = down + 1
                if down >= 3 then return true end
            end
        end
    end
    return false
end

-- ===== Public update ==========================================================
function I.update(dt, t)
    local now = _now()

    -- Music proximity: Poll constantly at 1 Hz
    if now >= (I._next_music_poll_t or 0) then
        I._music_prox_active = _music_proximity_now()
        I._next_music_poll_t = now + 1.0
    end

    -- Event objectives: throttle to 1 Hz unless manager is already polling this frame
    local should_poll_objectives = false
    if I._obj_polled_this_frame then
        should_poll_objectives = true
    else
        -- If minimal feed is disabled, our manager may not poll—throttle to 1 Hz.
        if now >= (I._next_objective_poll_t or 0) then
            should_poll_objectives = true
            I._next_objective_poll_t = now + 1.0
        end
    end

    if should_poll_objectives then
        I._event_obj_active = _scan_event_objectives()
    end

    I._team_collapse_active = _scan_team_collapse()

    -- State change detection for echoes
    local is_active = I.high_intensity_active()
    if is_active ~= I._was_high_intensity then
        I._was_high_intensity = is_active
    end

    -- reset per-frame hints
    I._obj_polled_this_frame = false
end

-- ===== Aggregate ==============================================================
-- Precedence:
--   1) mod.high_intensity_active(mod) override hook (true ⇒ force on)
--   2) explicit raw flag (I._raw_high_intensity or mod.high_intensity)
--   3) derived sources (event objectives / music proximity / team collapse)
--   4) legacy music/timer sources
function I.high_intensity_active()
    if type(mod.high_intensity_active) == "function" then
        -- No pcall: assume user override is well-behaved.
        if mod.high_intensity_active(mod) == true then
            return true
        end
    end

    if I._raw_high_intensity or rawget(mod, "high_intensity") == true then
        return true
    end

    if I._event_obj_active or I._music_prox_active or I._team_collapse_active then
        return true
    end

    return I.is_music_high() or I.is_timer_active()
end

function I.set_high_intensity(b)
    I._raw_high_intensity = (b == true)
end

return I
