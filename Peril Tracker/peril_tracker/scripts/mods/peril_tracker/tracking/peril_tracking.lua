--[[
    peril_tracking.lua

    Overload detection: watches weapon_action component's current_action_name
    for transitions TO "action_warp_charge_explode" (PowerDI pattern).

    Fatal detection: hooks PlayerCharacterStateKnockedDown.on_exit and
    PlayerCharacterStateDead.on_exit (PlayerDeathfeed pattern).

    Combat tracking: hooks AttackReportManager.add_attack_result (uptime mod
    pattern). Any attack involving the local player extends the combat window
    by 5 seconds, matching uptime mod behaviour exactly.

    Psyker guard: only starts tracking if archetype is "psyker".
--]]

local mod = get_mod("peril_tracker")

local state = {
    active          = false,
    samples         = {},
    overloads       = {},
    combats         = {},   -- array of { start_time, end_time } in mission seconds
    last_sample_t   = -math.huge,
    mission_start_t = 0,
}

local last_action_name    = ""
local overload_active_idx = nil
local overload_active_t   = 0

local COMBAT_WINDOW = 5   -- seconds to extend combat on each attack (matches uptime mod)

local function debug(msg)
    if mod:get("debug_messages") then
        mod:echo(msg)
    end
end

local function is_local_player(unit)
    local player = Managers.player:local_player(1)
    return player and unit == player.player_unit
end

function mod:peril_tracking_active()
    return state.active
end

function mod:start_peril_tracking()
    state.active          = true
    state.samples         = {}
    state.overloads       = {}
    state.combats         = {}
    state.last_sample_t   = -math.huge
    state.mission_start_t = mod:now()
    last_action_name      = ""
    overload_active_idx   = nil
    overload_active_t     = 0
    debug("Peril tracking started.")
end

function mod:end_peril_tracking()
    if not state.active then return end
    state.active = false

    -- Cap the last combat window at mission end
    local end_t = mod:now() - state.mission_start_t
    if #state.combats > 0 then
        local last = state.combats[#state.combats]
        if last.end_time > end_t then
            last.end_time = end_t
        end
    end

    local n = #state.samples
    local o = #state.overloads
    debug(string.format("Peril tracking ended: %d samples, %d overloads.", n, o))

    local player = Managers.player and Managers.player:local_player(1)
    local params = mod._current_mission_params or {}

    local session = {
        samples   = state.samples,
        overloads = state.overloads,
        combats   = state.combats,
        duration  = end_t,
        map       = params.mission_name or "unknown",
        player    = player and player:name() or "unknown",
        archetype = player and player:archetype_name() or "unknown",
    }

    mod._last_peril_session = session

    if n > 0 then
        mod:save_peril_session(session)
    end
end

-- ===== Combat tracking (uptime mod pattern) =====

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, ...)
    if not state.active then return end

    local ok, is_relevant = pcall(function()
        return is_local_player(attacking_unit) or is_local_player(attacked_unit)
    end)
    if not ok or not is_relevant then return end

    local t = mod:now() - state.mission_start_t
    local combats = state.combats

    if #combats > 0 then
        local last = combats[#combats]
        if t <= last.end_time then
            last.end_time = t + COMBAT_WINDOW
        elseif t > last.end_time then
            table.insert(combats, { start_time = t, end_time = t + COMBAT_WINDOW })
        end
    else
        table.insert(combats, { start_time = t, end_time = t + COMBAT_WINDOW })
    end
end)

-- ===== Fatal detection (PlayerDeathfeed pattern) =====
-- Hook _process_attack_result and check if the local player is knocked down
-- or killed. This fires at the moment the hit lands — no state transition
-- timing issues, and confirmed multiplayer-safe by PlayerDeathfeed.

local AttackSettings = mod:original_require("scripts/settings/damage/attack_settings")
local attack_results = AttackSettings.attack_results

mod:hook_safe(CLASS.AttackReportManager, "_process_attack_result", function(self, buffer_data)
    if not state.active then return end
    if overload_active_idx == nil then return end

    local ok, relevant = pcall(function()
        local attacked_unit = buffer_data.attacked_unit
        if not is_local_player(attacked_unit) then return false end

        local attack_result = buffer_data.attack_result
        return attack_result == attack_results.knock_down
            or attack_result == attack_results.died
    end)
    if not ok or not relevant then return end

    local t = mod:now() - state.mission_start_t
    if (t - overload_active_t) > 5 then return end

    state.overloads[overload_active_idx].fatal = true
    overload_active_idx = nil
    debug("Overload was fatal.")
end)

-- ===== Per-frame hook =====

mod:hook_safe(CLASS.HudElementPlayerBuffs, "_update_buffs", function(self)
    if not state.active then return end
    if self.__class_name ~= "HudElementPlayerBuffs" or self._filter then return end

    local player_extensions = self._parent:player_extensions()
    local unit_data = player_extensions and player_extensions.unit_data
    if not unit_data then return end

    local now = mod:now()
    local t   = now - state.mission_start_t

    -- Watch for overload action transitions
    local ok_action, current_action = pcall(function()
        return unit_data:read_component("weapon_action").current_action_name
    end)

    if ok_action and current_action and current_action ~= last_action_name then
        if current_action == "action_warp_charge_explode" then
            local idx = #state.overloads + 1
            state.overloads[idx] = { time = t, fatal = false }
            overload_active_idx  = idx
            overload_active_t    = t
            debug(string.format("Overload detected at %.1fs.", t))
        end
        last_action_name = current_action
    end

    -- Clear overload_active_idx after 4 seconds if no fatal hook fired
    if overload_active_idx ~= nil and (t - overload_active_t) > 4 then
        overload_active_idx = nil
    end

    -- Regular timed peril sample
    local ok_peril, raw = pcall(function()
        return unit_data:read_component("warp_charge").current_percentage
    end)
    if ok_peril and raw ~= nil then
        local interval = mod:get("sample_interval") or 2
        if (now - state.last_sample_t) >= interval then
            state.samples[#state.samples + 1] = { time = t, peril = raw * 100 }
            state.last_sample_t = now
        end
    end
end)
