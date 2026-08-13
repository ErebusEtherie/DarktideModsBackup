-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_damage_dropoff.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local DamageProfile = mod:original_require("scripts/utilities/attack/damage_profile")

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local RANGE_VALUE_EPSILON = 0.005

-- ============================================================================
-- DROPOFF CALCULATIONS
-- ============================================================================

local function action_damage_values_at_dropoff(action, action_name, damage_profile_lerp_values,
                                               use_special_damage_profile, dropoff_scalar, weapon_tweak_templates,
                                               weapon_template, charge_action_name, charge_action)
    local num_templates = Action.num_damage_templates(action)
    local values_by_armor = mod.new_action_damage_values()
    local has_damage_profile = false

    for template_i = 1, num_templates do
        local damage_profile = mod.selected_damage_profile(action, template_i, use_special_damage_profile)

        if damage_profile then
            local action_power_level = Action.stat_power_level(action, template_i)
            local attack_values, impact_values, cleave_values =
                mod.calculate_damage_profile_hit_zone_values(action_name, action, damage_profile, action_power_level,
                    damage_profile_lerp_values, dropoff_scalar, template_i == 1, weapon_tweak_templates,
                    weapon_template, charge_action_name, charge_action)

            mod.add_damage_values_by_armor(values_by_armor.attack, attack_values)
            mod.add_damage_values_by_armor(values_by_armor.impact, impact_values)
            mod.add_damage_values_by_armor(values_by_armor.cleave, cleave_values)

            local explosion_template = Action.explosion_template(action, template_i)
            local inner_damage_profile = explosion_template and explosion_template.close_damage_profile

            if inner_damage_profile and inner_damage_profile ~= damage_profile then
                local explosion_power_level = explosion_template.static_power_level or action_power_level
                local explosion_attack_values, explosion_impact_values =
                    mod.calculate_damage_profile_hit_zone_values(action_name, action, inner_damage_profile,
                        explosion_power_level, damage_profile_lerp_values, dropoff_scalar, false,
                        weapon_tweak_templates, weapon_template, charge_action_name, charge_action)

                mod.add_damage_values_by_armor(values_by_armor.attack, explosion_attack_values)
                mod.add_damage_values_by_armor(values_by_armor.impact, explosion_impact_values)
            end

            has_damage_profile = true
        end
    end

    if mod.add_sticky_damage_values_by_armor(values_by_armor, action, action_name, damage_profile_lerp_values,
            use_special_damage_profile, weapon_tweak_templates, weapon_template, charge_action_name, charge_action) then
        has_damage_profile = true
    end

    return has_damage_profile and values_by_armor or nil
end

local function add_damage_profile_range(range_data, action_name, damage_profile, damage_profile_lerp_values)
    local target_index = mod.damage_profile_target_index(damage_profile)

    if not target_index then
        return
    end

    local current_lerps, _ = mod.action_damage_profile_lerp_values(damage_profile_lerp_values, action_name,
        damage_profile, target_index)
    local range_min, range_max = DamageProfile.ranges(damage_profile, current_lerps)

    if type(range_min) ~= "number" or type(range_max) ~= "number" or range_max < range_min then
        return
    end

    range_data.min = range_data.min and math.min(range_data.min, range_min) or range_min
    range_data.max = range_data.max and math.max(range_data.max, range_max) or range_max
end

local function action_damage_range(action, action_name, damage_profile_lerp_values, use_special_damage_profile)
    local range_data = {}
    local num_templates = Action.num_damage_templates(action)

    for template_i = 1, num_templates do
        local damage_profile = mod.selected_damage_profile(action, template_i, use_special_damage_profile)

        if damage_profile then
            add_damage_profile_range(range_data, action_name, damage_profile, damage_profile_lerp_values)

            local explosion_template = Action.explosion_template(action, template_i)
            local inner_damage_profile = explosion_template and explosion_template.close_damage_profile

            if inner_damage_profile and inner_damage_profile ~= damage_profile then
                add_damage_profile_range(range_data, action_name, inner_damage_profile, damage_profile_lerp_values)
            end
        end
    end

    return range_data.min and range_data.max and range_data or nil
end

local function range_values_differ(near_value, far_value)
    local has_near_value = type(near_value) == "number"
    local has_far_value = type(far_value) == "number"

    if has_near_value ~= has_far_value then
        return true
    end

    return has_near_value and math.abs(near_value - far_value) > RANGE_VALUE_EPSILON
end

local function armor_range_affects_performance(near_values, far_values, armor_type)
    local near_attack = near_values and near_values.attack[armor_type]
    local far_attack = far_values and far_values.attack[armor_type]
    local near_impact = near_values and near_values.impact[armor_type]
    local far_impact = far_values and far_values.impact[armor_type]

    return range_values_differ(near_attack, far_attack) or range_values_differ(near_impact, far_impact)
end

local function optimal_armor_uses_far_range(near_values, far_values, armor_type)
    local near_attack = near_values and near_values.attack[armor_type]
    local far_attack = far_values and far_values.attack[armor_type]

    if type(near_attack) == "number" and type(far_attack) == "number" and
        math.abs(near_attack - far_attack) > RANGE_VALUE_EPSILON then
        return far_attack > near_attack
    elseif type(far_attack) == "number" and type(near_attack) ~= "number" then
        return true
    end

    local near_impact = near_values and near_values.impact[armor_type]
    local far_impact = far_values and far_values.impact[armor_type]

    return type(far_impact) == "number" and
        (type(near_impact) ~= "number" or far_impact > near_impact + RANGE_VALUE_EPSILON)
end

local function selected_armor_uses_far_range(range_mode, near_values, far_values, armor_type)
    if range_mode == mod.WAD_RANGE_MODE_FAR then
        return true
    elseif range_mode == mod.WAD_RANGE_MODE_NEAR then
        return false
    end

    return optimal_armor_uses_far_range(near_values, far_values, armor_type)
end

local function selected_action_damage_values(near_values, far_values, range_data)
    local range_mode = mod.wad_range_mode or mod.WAD_RANGE_MODE_OPTIMAL
    local values_by_armor = mod.new_action_damage_values()
    local range_by_armor = {}
    local range_affects_performance = false

    for i = 1, #mod.ARMOR_DAMAGE_ORDER do
        local armor_type = mod.ARMOR_DAMAGE_ORDER[i]
        local use_far = selected_armor_uses_far_range(range_mode, near_values, far_values, armor_type)
        local selected_values = use_far and far_values or near_values

        local attack_value = selected_values and selected_values.attack[armor_type]
        local impact_value = selected_values and selected_values.impact[armor_type]
        local cleave_value = selected_values and selected_values.cleave[armor_type]

        if type(attack_value) == "number" then
            values_by_armor.attack[armor_type] = attack_value
        end

        if type(impact_value) == "number" then
            values_by_armor.impact[armor_type] = impact_value
        end

        if type(cleave_value) == "number" then
            values_by_armor.cleave[armor_type] = cleave_value
        end

        range_by_armor[armor_type] = {
            symbol = use_far and ">" or "<",
            distance = use_far and range_data.max or range_data.min,
            dropoff_scalar = use_far and 1 or 0,
        }

        if armor_range_affects_performance(near_values, far_values, armor_type) then
            range_affects_performance = true
        end
    end

    values_by_armor.range_by_armor = range_affects_performance and range_by_armor or nil
    values_by_armor.range_affects_performance = range_affects_performance

    return values_by_armor
end

-- ============================================================================
-- EXPORTED ORCHESTRATOR
-- ============================================================================

function mod.action_damage_values_by_armor(action, action_name, damage_profile_lerp_values, use_special_damage_profile,
                                           weapon_tweak_templates, weapon_template, charge_action_name, charge_action)
    if not action then
        return nil
    end

    local range_data = action_damage_range(action, action_name, damage_profile_lerp_values, use_special_damage_profile)

    if not range_data then
        return action_damage_values_at_dropoff(action, action_name, damage_profile_lerp_values,
            use_special_damage_profile, false, weapon_tweak_templates, weapon_template, charge_action_name,
            charge_action)
    end

    local near_values = action_damage_values_at_dropoff(action, action_name, damage_profile_lerp_values,
        use_special_damage_profile, 0, weapon_tweak_templates, weapon_template, charge_action_name, charge_action)
    local far_values = action_damage_values_at_dropoff(action, action_name, damage_profile_lerp_values,
        use_special_damage_profile, 1, weapon_tweak_templates, weapon_template, charge_action_name, charge_action)

    if not near_values and not far_values then
        return nil
    end

    near_values = near_values or far_values
    far_values = far_values or near_values

    return selected_action_damage_values(near_values, far_values, range_data)
end
