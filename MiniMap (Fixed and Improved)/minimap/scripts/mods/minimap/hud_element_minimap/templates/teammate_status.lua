
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

local Status = {}

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

Status.icons_glowing = {
    pounced = "content/ui/materials/mission_board/circumstances/hunting_grounds_01",

    warp_grabbed = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals",

    consumed = "content/ui/materials/mission_board/circumstances/nurgle_manifestation_01",
    grabbed = "content/ui/materials/mission_board/circumstances/nurgle_manifestation_01",

    knocked_down = "content/ui/materials/mission_board/circumstances/maelstrom_01",

    netted = "content/ui/materials/mission_board/circumstances/special_waves_03",

    ledge_hanging = "content/ui/materials/mission_board/circumstances/maelstrom_01",

    mutant_charged = "content/ui/materials/mission_board/circumstances/less_resistance_01",

    dead = "content/ui/materials/mission_board/circumstances/maelstrom_02",

    hogtied = "content/ui/materials/mission_board/circumstances/maelstrom_02",
}

Status.icons = {
    pounced = "content/ui/materials/icons/circumstances/hunting_grounds_01",

    warp_grabbed = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_heinous_rituals",

    consumed = "content/ui/materials/icons/circumstances/nurgle_manifestation_01",
    grabbed = "content/ui/materials/icons/circumstances/nurgle_manifestation_01",

    knocked_down = "content/ui/materials/icons/circumstances/maelstrom_01",

    netted = "content/ui/materials/icons/circumstances/special_waves_03",

    ledge_hanging = "content/ui/materials/icons/circumstances/maelstrom_01",

    mutant_charged = "content/ui/materials/icons/circumstances/less_resistance_01",

    dead = "content/ui/materials/icons/circumstances/maelstrom_02",

    hogtied = "content/ui/materials/icons/circumstances/maelstrom_02",
}

return Status
