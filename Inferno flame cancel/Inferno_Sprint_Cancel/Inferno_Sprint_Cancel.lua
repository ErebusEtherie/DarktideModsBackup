local mod = get_mod("Inferno_Sprint_Cancel")

local Managers   = Managers
local ScriptUnit = ScriptUnit
local string_find = string.find
local pairs      = pairs
local tonumber   = tonumber

-- ── weapon identification ─────────────────────────────────────────────────────
local TARGET_WEAPON_KEY   = "forcestaff_p2"
local SHOOT_ACTION_KEY    = "shoot_flame"

-- ── debug helper ──────────────────────────────────────────────────────────────
local function dbg(...)
    if not mod:get("debug_enabled") then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    mod:echo("[ISC] " .. table.concat(parts, " "))
end

-- ── input cache ───────────────────────────────────────────────────────────────
local move_forward  = 0
local move_backward = 0
local move_left     = 0
local move_right    = 0
local m1_held       = false   -- true while action_one_hold is active

-- ── state machine ─────────────────────────────────────────────────────────────
-- Phases:
--   "idle"       – waiting for a shoot action to start
--   "armed"      – shoot detected, waiting sprint_delay before injecting
--   "sprinting"  – injecting sprint press + hold
--   "release"    – one clean frame of false to drop sprint
--   "loop_delay" – sprint done, waiting loop_end_delay before next cycle
local State = {
    phase        = "idle",
    armed_at_t   = 0,
    sprint_end_t = 0,
    loop_end_t   = 0,
    press_sent   = false,
}

local function reset_state()
    State.phase        = "idle"
    State.armed_at_t   = 0
    State.sprint_end_t = 0
    State.loop_end_t   = 0
    State.press_sent   = false
    move_forward       = 0
    move_backward      = 0
    move_left          = 0
    move_right         = 0
    m1_held            = false
end

-- ── player / weapon helpers ───────────────────────────────────────────────────
local function get_player_unit()
    local pm = Managers.player
    if not pm then return nil end
    local player = pm:local_player_safe(1)
    if player and not player.bot_player then
        return player.player_unit
    end
    return nil
end

local function get_wielded_weapon_name(unit)
    if not unit then return nil, "no unit" end
    local weapon_extension = ScriptUnit.has_extension(unit, "weapon_system")
    if not weapon_extension then return nil, "no weapon_system extension" end
    local inventory = weapon_extension._inventory_component
    if not inventory then return nil, "no _inventory_component" end
    local wielded_slot = inventory.wielded_slot
    if not wielded_slot then return nil, "no wielded_slot" end
    local weapons = weapon_extension._weapons
    if not weapons then return nil, "no _weapons table" end
    local current_weapon = weapons[wielded_slot]
    if not current_weapon then return nil, "no weapon in slot: " .. tostring(wielded_slot) end
    local weapon_template = current_weapon.weapon_template
    if not weapon_template then return nil, "no weapon_template in slot: " .. tostring(wielded_slot) end
    local name = weapon_template.name
    if not name then return nil, "weapon_template.name is nil" end
    return name, wielded_slot
end

local function get_running_action(unit)
    local weapon_extension = ScriptUnit.has_extension(unit, "weapon_system")
    local action_handler   = weapon_extension and weapon_extension._action_handler
    if action_handler and action_handler._registered_components then
        for _, handler_data in pairs(action_handler._registered_components) do
            local running_action = handler_data.running_action
            if running_action then
                return running_action:action_settings().name
            end
        end
    end
    return "idle"
end

-- ── input hook ────────────────────────────────────────────────────────────────
local function input_hook(func, self, action_name)
    local result = func(self, action_name)

    -- Always track movement and M1 hold state.
    if action_name == "move_forward"   then move_forward  = result end
    if action_name == "move_backward"  then move_backward = result end
    if action_name == "move_left"      then move_left     = result end
    if action_name == "move_right"     then move_right    = result end
    if action_name == "action_one_hold" then m1_held      = result end

    if not mod:is_enabled() then return result end
    if Managers.ui and Managers.ui:using_input() then return result end

    -- Only override sprint-related actions.
    if action_name ~= "sprint" and action_name ~= "sprinting" then
        return result
    end

    local t = Managers.time:time("gameplay") or 0

    -- phase: armed — waiting out sprint_delay
    if State.phase == "armed" then
        if not m1_held then
            dbg("armed → idle (m1 released)")
            State.phase = "idle"
            return result
        end
        local sprint_delay = tonumber(mod:get("sprint_delay")) or 0.1
        if (t - State.armed_at_t) >= sprint_delay then
            local sprint_duration = tonumber(mod:get("sprint_duration")) or 0.08
            State.phase        = "sprinting"
            State.sprint_end_t = t + sprint_duration
            State.press_sent   = false
            dbg("armed → sprinting for " .. sprint_duration .. "s")
        end
        return result
    end

    -- phase: sprinting — inject sprint press + hold
    if State.phase == "sprinting" then
        if not m1_held then
            dbg("sprinting → idle (m1 released)")
            State.phase = "idle"
            return false
        end
        if t > State.sprint_end_t then
            State.phase = "release"
            dbg("sprinting → release")
            return false
        end
        if action_name == "sprint" then
            if not State.press_sent then
                State.press_sent = true
                dbg("inject sprint press")
                return true
            end
            return false
        end
        if action_name == "sprinting" then
            return true
        end
    end

    -- phase: release — one clean frame of false to drop sprint
    if State.phase == "release" then
        if not m1_held then
            dbg("release → idle (m1 released)")
            State.phase = "idle"
            return false
        end
        -- M1 still held — queue the loop delay before next cycle.
        local loop_end_delay = tonumber(mod:get("loop_end_delay")) or 0.05
        State.phase      = "loop_delay"
        State.loop_end_t = t + loop_end_delay
        dbg("release → loop_delay for " .. loop_end_delay .. "s")
        return false
    end

    -- phase: loop_delay — pause before next armed cycle
    if State.phase == "loop_delay" then
        if not m1_held then
            dbg("loop_delay → idle (m1 released)")
            State.phase = "idle"
            return result
        end
        if t >= State.loop_end_t then
            -- Restart the cycle.
            State.phase      = "armed"
            State.armed_at_t = t
            State.press_sent = false
            dbg("loop_delay → armed (looping)")
        end
        return result
    end

    return result
end

mod:hook(CLASS.InputService, "_get",          input_hook)
mod:hook(CLASS.InputService, "_get_simulate", input_hook)

-- ── update loop ───────────────────────────────────────────────────────────────
local _last_action     = "idle"
local _diag_throttle_t = 0

mod.update = function(dt)
    if not mod:is_enabled() then return end

    local unit = get_player_unit()

    -- Diagnostic block: prints every 2s when debug is on.
    if mod:get("debug_enabled") then
        local main_t = Managers.time and Managers.time:time("main") or 0
        if main_t > _diag_throttle_t + 2.0 then
            _diag_throttle_t = main_t
            if not unit then
                mod:echo("[ISC] diag: no player unit")
            else
                local wname, info = get_wielded_weapon_name(unit)
                if wname then
                    local match = string_find(wname, TARGET_WEAPON_KEY) ~= nil
                    mod:echo("[ISC] diag: wielded='" .. wname
                        .. "' slot=" .. tostring(info)
                        .. " match=" .. tostring(match)
                        .. " phase=" .. State.phase
                        .. " m1=" .. tostring(m1_held))
                else
                    mod:echo("[ISC] diag: weapon lookup failed: " .. tostring(info))
                end
                local cur_action = get_running_action(unit)
                mod:echo("[ISC] diag: action='" .. tostring(cur_action) .. "'")
            end
        end
    end

    -- Only watch for new shoot starts when idle.
    if State.phase ~= "idle" then return end
    if not unit then return end

    local wname = get_wielded_weapon_name(unit)
    if not wname or not string_find(wname, TARGET_WEAPON_KEY) then
        if _last_action ~= "idle" then
            _last_action = "idle"
        end
        return
    end

    local current_action = get_running_action(unit)
    local was_shooting   = string_find(_last_action,    SHOOT_ACTION_KEY) ~= nil
    local is_shooting    = string_find(current_action,  SHOOT_ACTION_KEY) ~= nil

    if _last_action ~= current_action then
        dbg("action: " .. _last_action .. " → " .. current_action)
    end

    -- Rising edge: shoot just started → arm the sprint inject.
    if not was_shooting and is_shooting then
        local t = Managers.time:time("gameplay") or 0
        State.phase      = "armed"
        State.armed_at_t = t
        State.press_sent = false
        dbg("ARMED — shoot started, waiting delay")
    end

    _last_action = current_action
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────
mod.on_disabled = function()
    reset_state()
    _last_action     = "idle"
    _diag_throttle_t = 0
end

mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" and status == "exit" then
        reset_state()
        _last_action     = "idle"
        _diag_throttle_t = 0
    end
end