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

local function _inventory(unit)
    local uds = _uds(unit)
    return uds and uds:read_component("inventory") or nil
end

local function _visual_loadout(unit)
    return unit
        and ScriptUnit.has_extension(unit, "visual_loadout_system")
        and ScriptUnit.extension(unit, "visual_loadout_system")
        or nil
end

local function _minigame_state(unit)
    local uds = _uds(unit)
    return uds and uds:read_component("minigame_character_state") or nil
end

local function _scanning_component(unit)
    local uds = _uds(unit)
    return uds and uds:read_component("scanning") or nil
end

local function _weapon_action_component(unit)
    local uds = _uds(unit)
    return uds and uds:read_component("weapon_action") or nil
end

local function _interaction_component(unit)
    local uds = _uds(unit)
    return uds and uds:read_component("interaction") or nil
end

function Status.for_unit(unit)
    if not unit or not HEALTH_ALIVE[unit] then
        return "dead"
    end

    local he = _health_ext(unit)
    if not (he and he.is_alive and he:is_alive()) then
        return "dead"
    end

    local uds = _uds(unit)
    local cs = uds and uds:read_component("character_state") or nil
    local ds = uds and uds:read_component("disabled_character_state") or nil

    local knocked_down = cs and PlayerUnitStatus.is_knocked_down(cs) or false
    local hogtied = cs and PlayerUnitStatus.is_hogtied(cs) or false
    local ledge_hanging = cs and PlayerUnitStatus.is_ledge_hanging(cs) or false

    local pounced = ds and PlayerUnitStatus.is_pounced(ds) or false
    local netted = ds and PlayerUnitStatus.is_netted(ds) or false
    local warp_grabbed = ds and PlayerUnitStatus.is_warp_grabbed(ds) or false
    local mutant_charged = ds and PlayerUnitStatus.is_mutant_charged(ds) or false
    local consumed = ds and PlayerUnitStatus.is_consumed(ds) or false
    local grabbed = ds and PlayerUnitStatus.is_grabbed(ds) or false

    local auspex_active = false
    local scanning_component = _scanning_component(unit)
    local minigame_state = _minigame_state(unit)
    
    if scanning_component and scanning_component.is_active then
        auspex_active = true
    elseif minigame_state and minigame_state.pocketable_device_active then
        auspex_active = true
    end
    
    local auspex_mod = get_mod("better_downed_indicators")
    if auspex_mod and auspex_mod._auspex_active_units and auspex_mod._auspex_active_units[unit] then
        auspex_active = true
    end
    
    local inventory = _inventory(unit)
    local luggable = false
    if inventory and inventory.wielded_slot == "slot_luggable" then
        luggable = true
    end

    -- Check for interactions (use tracked state from RPC hooks - works for all players)
    local interaction_status = nil
    local interaction_mod = get_mod("better_downed_indicators")
    if interaction_mod and interaction_mod._interaction_active_units and interaction_mod._interaction_active_units[unit] then
        local interaction_data = interaction_mod._interaction_active_units[unit]
        local interaction_type = interaction_data.type
        if interaction_type == "health_station" then
            interaction_status = "healing"
        elseif interaction_type == "revive" or interaction_type == "remove_net" or interaction_type == "pull_up" or interaction_type == "rescue" then
            interaction_status = "helping"
        elseif interaction_type then
            -- Catch-all for other interactions (setup_decoding, door_control_panel, scripted_scenario, moveable_platform, chest, etc.)
            -- Only show for long-press interactions
            local InteractionSettings = require("scripts/settings/interaction/interaction_settings")
            local interaction_templates = require("scripts/settings/interaction/interaction_templates")
            local template = interaction_templates[interaction_type]
            if template and template.duration and template.duration > 0 then
                interaction_status = "interacting"
            end
        end
    end
    
    -- Fallback: check interaction component directly (for local player reliability)
    local interaction_component = _interaction_component(unit)
    if not interaction_status and interaction_component then
        local InteractionSettings = require("scripts/settings/interaction/interaction_settings")
        local interaction_states = InteractionSettings.states
        local state = interaction_component.state
        if state == interaction_states.is_interacting then
            local interaction_type = interaction_component.type
            if interaction_type == "health_station" then
                interaction_status = "healing"
            elseif interaction_type == "revive" or interaction_type == "remove_net" or interaction_type == "pull_up" or interaction_type == "rescue" then
                interaction_status = "helping"
            elseif interaction_type then
                -- Check if it's a long-press interaction (includes setup_decoding, door_control_panel, etc.)
                local interaction_templates = require("scripts/settings/interaction/interaction_templates")
                local template = interaction_templates[interaction_type]
                if template and template.duration and template.duration > 0 then
                    interaction_status = "interacting"
                end
            end
        end
    end

    if hogtied then return "hogtied" end
    if pounced then return "pounced" end
    if netted then return "netted" end
    if warp_grabbed then return "warp_grabbed" end
    if mutant_charged then return "mutant_charged" end
    if consumed then return "consumed" end
    if grabbed then return "grabbed" end
    if knocked_down then return "knocked_down" end
    if ledge_hanging then return "ledge_hanging" end
    if auspex_active then return "auspex" end
    if interaction_status == "healing" then return "healing" end
    if interaction_status == "helping" then return "helping" end
    if interaction_status == "interacting" then return "interacting" end
    if luggable then return "luggable" end

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
    dead = "content/ui/materials/icons/player_states/dead",
    respawning = "content/ui/materials/icons/player_states/dead",
    hogtied = "content/ui/materials/mission_board/circumstances/maelstrom_02",
    auspex = "content/ui/materials/icons/pocketables/hud/auspex_scanner",
    luggable = "content/ui/materials/icons/player_states/lugged",
    healing = "content/ui/materials/hud/interactions/icons/respawn",
    helping = "content/ui/materials/hud/interactions/icons/help",
    interacting = "content/ui/materials/hud/interactions/icons/objective_side",
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
    dead = "content/ui/materials/icons/player_states/dead",
    respawning = "content/ui/materials/icons/player_states/dead",
    hogtied = "content/ui/materials/icons/circumstances/maelstrom_02",
    auspex = "content/ui/materials/icons/pocketables/hud/auspex_scanner",
    luggable = "content/ui/materials/icons/player_states/lugged",
    healing = "content/ui/materials/hud/interactions/icons/respawn",
    helping = "content/ui/materials/hud/interactions/icons/help",
    interacting = "content/ui/materials/hud/interactions/icons/objective_side",
}

return Status