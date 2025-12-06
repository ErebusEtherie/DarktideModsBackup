-- File: RingHud/scripts/mods/RingHud/team/status.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local PlayerUnitStatus         = require("scripts/utilities/attack/player_unit_status")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")

local Status                   = {}

-- NOTE (RingHud):
--  • This module mirrors vanilla status resolution and intentionally DOES NOT
--    include custom statuses like "stimm". Our custom stimm glyph is injected
--    downstream via the VM/applier as a lowest-priority overlay
--    (vm.status_icon_kind == "stimm"), so any vanilla status returned here
--    will take precedence automatically.

-- ─────────────────────────────────────────────────────────────────────────────
-- Small safe helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function _health_ext(unit)
    return unit
        and ScriptUnit.has_extension(unit, "health_system")
        and ScriptUnit.extension(unit, "health_system")
        or nil
end

local function _uds(unit)
    return unit
        and ScriptUnit.has_extension(unit, "unit_data_system")
        and ScriptUnit.extension(unit, "unit_data_system")
        or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Status: returns one of
--   "dead", "hogtied", "pounced", "netted", "warp_grabbed", "mutant_charged",
--   "consumed", "grabbed", "knocked_down", "ledge_hanging", "luggable", or nil
-- Priority matches the base game’s nameplate logic.
-- ─────────────────────────────────────────────────────────────────────────────
function Status.for_unit(unit)
    if not unit or not HEALTH_ALIVE[unit] then
        return "dead"
    end

    local he = _health_ext(unit)
    if not (he and he.is_alive and he:is_alive()) then
        return "dead"
    end

    local uds            = _uds(unit)
    local cs             = uds and uds:read_component("character_state") or nil
    local ds             = uds and uds:read_component("disabled_character_state") or nil

    local knocked_down   = cs and PlayerUnitStatus.is_knocked_down(cs) or false
    local hogtied        = cs and PlayerUnitStatus.is_hogtied(cs) or false
    local ledge_hanging  = cs and PlayerUnitStatus.is_ledge_hanging(cs) or false

    local pounced        = ds and PlayerUnitStatus.is_pounced(ds) or false
    local netted         = ds and PlayerUnitStatus.is_netted(ds) or false
    local warp_grabbed   = ds and PlayerUnitStatus.is_warp_grabbed(ds) or false
    local mutant_charged = ds and PlayerUnitStatus.is_mutant_charged(ds) or false
    local consumed       = ds and PlayerUnitStatus.is_consumed(ds) or false
    local grabbed        = ds and PlayerUnitStatus.is_grabbed(ds) or false

    -- Priority order (keep in sync with vanilla)
    if hogtied then return "hogtied" end
    if pounced then return "pounced" end
    if netted then return "netted" end
    if warp_grabbed then return "warp_grabbed" end
    if mutant_charged then return "mutant_charged" end
    if consumed then return "consumed" end
    if grabbed then return "grabbed" end
    if knocked_down then return "knocked_down" end
    if ledge_hanging then return "ledge_hanging" end

    -- Luggable (only while alive & not otherwise disabled)
    local inv = uds and uds:read_component("inventory")
    if inv and inv.wielded_slot == "slot_luggable" then
        return "luggable"
    end

    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Ledge-hang countdown → fraction (1→0)
-- Uses gameplay time; clamps to [0,1].
-- If total window isn’t provided, falls back to PlayerCharacterConstants.
-- ─────────────────────────────────────────────────────────────────────────────
function Status.ledge_time_remaining_fraction(unit, total_window)
    local uds = _uds(unit); if not uds then return 0 end
    local comp = uds:read_component("ledge_hanging_character_state")
    local time_to_fall = comp and comp.time_to_fall_down
    if not time_to_fall then return 0 end

    local now   = (Managers.time and Managers.time:time("gameplay")) or 0
    local total = total_window or PlayerCharacterConstants.time_until_fall_down_from_hang_ledge or 0

    if total <= 0 then
        local rem = (time_to_fall - now)
        return math.clamp(rem, 0, 1)
    end

    return math.clamp((time_to_fall - now) / total, 0, 1)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Seconds until respawn for a given player (nil if unknown/not counting down)
-- ─────────────────────────────────────────────────────────────────────────────
function Status.respawn_secs_remaining(player)
    local gm = Managers and Managers.state and Managers.state.game_mode
    if not (gm and gm.player_time_until_spawn) then
        return nil
    end

    local ok, ready_time = pcall(function() return gm:player_time_until_spawn(player) end)
    if not ok or not ready_time or ready_time == 0 then
        return nil
    end

    local now  = (Managers.time and Managers.time:time("gameplay")) or 0
    local secs = (ready_time - now)
    return (secs < 0) and 0 or secs
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Is human-controlled (not a bot) for unit?  True for players when unsure.
-- ─────────────────────────────────────────────────────────────────────────────
function Status.is_human_player_unit(unit)
    if not unit then return false end
    local p = Managers.player and Managers.player:player_by_unit(unit)
    if not p then return false end

    if p.is_human_controlled then
        local ok, human = pcall(function() return p:is_human_controlled() end)
        if ok then return human end
    end
    if p.is_bot_player then
        local ok, is_bot = pcall(function() return p:is_bot_player() end)
        if ok then return not is_bot end
    end
    if p.is_bot then
        local ok, is_bot = pcall(function() return p:is_bot() end)
        if ok then return not is_bot end
    end

    return true
end

-- Also publish on mod.* so other files can reference with a `mod.` prefix if desired.
mod.team_status = Status

return Status
