-- File: Targeter/scripts/mods/Targeter/core/selection.lua
-- Decide which crosshair template to render based on weapon, action state, and target state.

local mod = get_mod("Targeter")
if not mod then return end

local Action                                 = require("scripts/utilities/action/action")
local PlayerCharacterConstants               = require("scripts/settings/player_character/player_character_constants")
local WeaponTemplate                         = require("scripts/utilities/weapon/weapon_template")

local Action_current_action                  = Action.current_action
local WeaponTemplate_current_weapon_template = WeaponTemplate.current_weapon_template
local WeaponTemplate_is_melee                = WeaponTemplate.is_melee
local string_find                            = string.find
local slot_configuration                     = PlayerCharacterConstants.slot_configuration

-- Optimization: O(1) Constant Lookup Tables
local TARGET_STATE_MAP                       = {
    weakspot_locked = "weakspot",
    target_locked = "enemy",
    default = "default"
}

local RELOAD_ACTIONS                         = {
    reload_state = true,
    reload_shotgun = true,
    ranged_load_special = true
}

local function _get_ammo(val)
    if type(val) == "number" then return val end
    if type(val) == "table" then return val[1] or 0 end
    return 0
end

mod:hook_origin("HudElementCrosshair", "_get_current_crosshair_type", function(self)
    if mod.game_mode_is_hub then
        return "none"
    end

    local parent = self._parent
    local player_extensions = parent and parent:player_extensions()
    if not player_extensions then return "none" end

    local unit_data_extension = player_extensions.unit_data
    if not unit_data_extension then return "none" end

    local weapon_action_component = unit_data_extension:read_component("weapon_action")
    if not weapon_action_component then return "none" end

    local weapon_template = WeaponTemplate_current_weapon_template(weapon_action_component)
    if not weapon_template then return "none" end

    local inventory_component = unit_data_extension:read_component("inventory")
    local wielded_slot = inventory_component and inventory_component.wielded_slot
    local slot_cfg = wielded_slot and slot_configuration[wielded_slot]
    local slot_type = slot_cfg and slot_cfg.slot_type or nil

    local inventory_slot_component = (slot_type == "weapon") and unit_data_extension:read_component(wielded_slot) or nil
    mod.inventory_slot_component = inventory_slot_component

    local current_action_name, action_settings = Action_current_action(weapon_action_component, weapon_template)
    local action_kind = current_action_name ~= "none" and action_settings.kind or "no_action"

    if action_kind == "inspect" then
        return (weapon_template.crosshair and weapon_template.crosshair.crosshair_type) or "none"
    end

    local template_name = weapon_template.name
    if template_name == "unarmed" or template_name == "zealot_relic" then
        return "none"
    end

    local is_melee = WeaponTemplate_is_melee and WeaponTemplate_is_melee(weapon_template) or false
    local weapon_class

    if is_melee then
        weapon_class = "melee_class"

        if string_find(template_name, "dual_shivs") then
            local charges = inventory_slot_component and inventory_slot_component.num_special_charges or 0
            if charges > 0 then
                weapon_class = "melee_throwing_class"
            end
        elseif mod.has_zealot_throwing_knives and mod.has_zealot_throwing_knives() then
            local ability_ext = player_extensions.ability
            local charges = 0
            if ability_ext and ability_ext.remaining_ability_charges then
                charges = ability_ext:remaining_ability_charges("grenade_ability") or 0
            end

            if charges > 0 then
                weapon_class = "melee_throwing_class"
            end
        end
    elseif template_name == "psyker_smite" then
        weapon_class = "psyker_smite_class"
    elseif template_name == "psyker_throwing_knives" then
        weapon_class = "psyker_throwing_knives_class"
    elseif template_name == "missile_launcher" then
        weapon_class = "broker_missile_launcher_class"
    else
        weapon_class = mod.WeaponClassifier.determine_ranged_weapon_class(weapon_template) or "melee_class"
    end

    local blocking = false
    if is_melee then
        local block_component = unit_data_extension:read_component("block")
        blocking = block_component and block_component.is_blocking or false
    end

    local alternate_fire_component = unit_data_extension:read_component("alternate_fire")
    local ads_condition_ranged = ((alternate_fire_component and alternate_fire_component.is_active) or
            (action_settings and (action_settings.kind == "aim" or action_settings.kind == "overload_charge"))) and true or
        false

    if weapon_class == "shotpistol_shield_p1_class" and inventory_slot_component then
        if not RELOAD_ACTIONS[action_kind] then
            local current_clip = _get_ammo(inventory_slot_component.current_ammunition_clip)
            local current_reserve = _get_ammo(inventory_slot_component.current_ammunition_reserve)

            if ads_condition_ranged then
                if current_clip == 0 then weapon_class = "melee_class" end
            elseif (current_clip + current_reserve) == 0 then
                weapon_class = "melee_class"
            end
        end
    end

    if mod._ads_poll_active then
        local now = mod._last_t or (mod.now and mod.now() or 0)
        local last_true = mod._ads_state.last_true_t
        if type(last_true) ~= "number" then
            last_true = 0
            mod._ads_state.last_true_t = 0
        end

        if ads_condition_ranged then
            mod._ads_state.last_true_t = now
        elseif (now - last_true) > (mod.ADS_END_GRACE or 0.2) then
            mod._ads_poll_active = false
        end
    end

    local action_key = "primary"
    if blocking or (mod._ads_poll_active and ads_condition_ranged) then
        action_key = "secondary"
    elseif inventory_slot_component and inventory_slot_component.special_active then
        action_key = "special"
    end

    local crosshair_state = mod.crosshair_state or "default"
    local target_state = TARGET_STATE_MAP[crosshair_state] or "default"

    local default_profile = mod.DEFAULT_PROFILE
    local profile = (mod.shape_profiles and mod.shape_profiles[weapon_class]) or default_profile
    local action_tbl = profile[action_key] or default_profile[action_key]

    return action_tbl and action_tbl[target_state] or default_profile[action_key][target_state] or "dot"
end)
