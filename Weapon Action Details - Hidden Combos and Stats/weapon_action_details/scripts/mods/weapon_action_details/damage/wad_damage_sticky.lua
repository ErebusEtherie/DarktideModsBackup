-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_damage_sticky.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function add_damage_profile_values_to_totals(values_by_armor, action, action_name, damage_profile,
                                                   damage_profile_lerp_values, power_level, scale,
                                                   disallowed_armor_types, dropoff_scalar, weapon_tweak_templates,
                                                   weapon_template, charge_action_name, charge_action)
    if not damage_profile then
        return false
    end

    local attack_values, impact_values = mod.calculate_damage_profile_hit_zone_values(action_name, action,
        damage_profile, power_level, damage_profile_lerp_values, dropoff_scalar, false, weapon_tweak_templates,
        weapon_template, charge_action_name, charge_action)

    mod.add_scaled_damage_values_by_armor(values_by_armor.attack, attack_values, scale, disallowed_armor_types)
    mod.add_scaled_damage_values_by_armor(values_by_armor.impact, impact_values, scale, disallowed_armor_types)

    return attack_values ~= nil or impact_values ~= nil
end

-- ============================================================================
-- EXPORTED FUNCTIONS
-- ============================================================================

function mod.add_sticky_damage_values_by_armor(values_by_armor, action, action_name, damage_profile_lerp_values,
                                               use_special_damage_profile, weapon_tweak_templates, weapon_template,
                                               charge_action_name, charge_action)
    local hit_stickyness_settings = mod.selected_hit_stickyness_settings(action, use_special_damage_profile)

    if not mod.sticky_damage_applies(hit_stickyness_settings, use_special_damage_profile) then
        return false
    end

    local damage = hit_stickyness_settings.damage

    if type(damage) ~= "table" then
        return false
    end

    local instances = damage.instances or 1

    if type(instances) ~= "number" or instances <= 0 then
        return false
    end

    local disallowed_armor_types = hit_stickyness_settings.disallowed_armor_types
    local normal_damage_profile = damage.damage_profile
    local last_damage_profile = damage.last_damage_profile or normal_damage_profile
    local power_level = mod.sticky_damage_power_level(hit_stickyness_settings, damage)
    local normal_instances = instances - 1
    local added_damage = false

    -- Calculate the "sawing" ticks.
    if normal_instances > 0 then
        added_damage = add_damage_profile_values_to_totals(values_by_armor, action, action_name, normal_damage_profile,
            damage_profile_lerp_values, power_level, normal_instances, disallowed_armor_types, false,
            weapon_tweak_templates, weapon_template, charge_action_name, charge_action) or added_damage
    end

    -- Calculate the final "rip" tick.
    added_damage = add_damage_profile_values_to_totals(values_by_armor, action, action_name, last_damage_profile,
        damage_profile_lerp_values, power_level, 1, disallowed_armor_types, false, weapon_tweak_templates,
        weapon_template, charge_action_name, charge_action) or added_damage

    return added_damage
end
