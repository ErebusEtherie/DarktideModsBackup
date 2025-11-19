-- Teammate status detection module for minimap
-- Based on RingHud's status.lua

local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

local Status = {}

-- Safe helper to get health extension
local function _health_ext(unit)
    return unit
        and ScriptUnit.has_extension(unit, "health_system")
        and ScriptUnit.extension(unit, "health_system")
        or nil
end

-- Safe helper to get unit data system
local function _uds(unit)
    return unit
        and ScriptUnit.has_extension(unit, "unit_data_system")
        and ScriptUnit.extension(unit, "unit_data_system")
        or nil
end

-- Returns teammate status:
--   "dead", "hogtied", "pounced", "netted", "warp_grabbed", "mutant_charged",
--   "consumed", "grabbed", "knocked_down", "ledge_hanging", or nil
-- Priority matches the base game's nameplate logic
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

    return nil
end

-- Status icon materials - glowing versions (for use with rings)
Status.icons_glowing = {
    -- Pounced by dog - dog/hound icon (glowing)
    pounced = "content/ui/materials/mission_board/circumstances/hunting_grounds_01",
    
    -- Warp grabbed by daemonhost - daemonhost icon
    warp_grabbed = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals",
    
    -- Consumed/grabbed by burster - Nurgle trefoil (glowing)
    consumed = "content/ui/materials/mission_board/circumstances/nurgle_manifestation_01",
    grabbed = "content/ui/materials/mission_board/circumstances/nurgle_manifestation_01",
    
    -- Knocked down/bleeding out - maelstrom skull (glowing)
    knocked_down = "content/ui/materials/mission_board/circumstances/maelstrom_01",
    
    -- Netted by trapper - chevron icon (glowing)
    netted = "content/ui/materials/mission_board/circumstances/special_waves_03",
    
    -- Ledge hanging - maelstrom skull (glowing)
    ledge_hanging = "content/ui/materials/mission_board/circumstances/maelstrom_01",
    
    -- Mutant charged - downward chevron (glowing)
    mutant_charged = "content/ui/materials/mission_board/circumstances/less_resistance_01",
    
    -- Dead - maelstrom winged skull (glowing)
    dead = "content/ui/materials/mission_board/circumstances/maelstrom_02",
    
    -- Hogtied - maelstrom winged skull (glowing)
    hogtied = "content/ui/materials/mission_board/circumstances/maelstrom_02",
}

-- Status icon materials - non-glowing versions (can be recolored)
Status.icons = {
    -- Pounced by dog - dog/hound icon (plain)
    pounced = "content/ui/materials/icons/circumstances/hunting_grounds_01",
    
    -- Warp grabbed by daemonhost - daemonhost icon
    warp_grabbed = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals",
    
    -- Consumed/grabbed - Nurgle trefoil (plain)
    consumed = "content/ui/materials/icons/circumstances/nurgle_manifestation_01",
    grabbed = "content/ui/materials/icons/circumstances/nurgle_manifestation_01",
    
    -- Knocked down/bleeding out - maelstrom skull (plain)
    knocked_down = "content/ui/materials/icons/circumstances/maelstrom_01",
    
    -- Netted by trapper - chevron icon (plain)
    netted = "content/ui/materials/icons/circumstances/special_waves_03",
    
    -- Ledge hanging - maelstrom skull (plain)
    ledge_hanging = "content/ui/materials/icons/circumstances/maelstrom_01",
    
    -- Mutant charged - downward chevron (plain)
    mutant_charged = "content/ui/materials/icons/circumstances/less_resistance_01",
    
    -- Dead - maelstrom winged skull (plain)
    dead = "content/ui/materials/icons/circumstances/maelstrom_02",
    
    -- Hogtied - maelstrom winged skull (plain)
    hogtied = "content/ui/materials/icons/circumstances/maelstrom_02",
}

return Status
