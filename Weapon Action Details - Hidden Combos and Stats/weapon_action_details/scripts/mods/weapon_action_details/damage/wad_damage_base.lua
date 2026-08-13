-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_damage_base.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")
local DamageCalculation = mod:original_require("scripts/utilities/attack/damage_calculation")
local DamageProfile = mod:original_require("scripts/utilities/attack/damage_profile")
local PowerLevel = mod:original_require("scripts/utilities/attack/power_level")
local PowerLevelSettings = mod:original_require("scripts/settings/damage/power_level_settings")
local SuppressionTemplates = mod:original_require("scripts/settings/equipment/suppression_templates")
local WeaponHandlingTemplates = mod:original_require(
    "scripts/settings/equipment/weapon_handling_templates/weapon_handling_templates")
local WeaponTweakTemplates = mod:original_require("scripts/extension_systems/weapon/utilities/weapon_tweak_templates")
local WeaponTweakTemplateSettings = mod:original_require(
    "scripts/settings/equipment/weapon_templates/weapon_tweak_template_settings")

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local ARMOR_TYPES = ArmorSettings.types
local EMPTY_TABLE = {}
local template_types = WeaponTweakTemplateSettings and WeaponTweakTemplateSettings.template_types or EMPTY_TABLE

local DAMAGE_CHARGE_LEVELS_BY_WEAPON_TEMPLATE = {
    forcestaff_p2_m1 = {
        action_shoot_flame = 1,
        action_shoot_charged_flame = 1,
    },
}

local SUPPRESSION_AMOUNT_KEYS = {
    amount = true,
    suppression_amount = true,
    suppression_value = true,
    impact_suppression_value = true,
}
local SUPPRESSION_RADIUS_KEYS = {
    radius = true,
    suppression_radius = true,
    impact_radius = true,
}

-- ============================================================================
-- BASE HELPERS & AGGREGATORS
-- ============================================================================

function mod.action_assumed_charge_level(action_name, action, weapon_tweak_templates, weapon_template,
                                         charge_action_name, charge_action)
    if type(mod.action_charge_level_bounds) ~= "function" then
        return 1
    end

    local min_charge, max_charge = mod.action_charge_level_bounds(action_name, action, charge_action_name, charge_action,
        weapon_template, weapon_tweak_templates)

    if type(min_charge) ~= "number" or type(max_charge) ~= "number" then
        return 1
    end

    local selected_charge = 1

    if mod.wad_charge_level == mod.WAD_CHARGE_LEVEL_30 then
        selected_charge = 0.3
    elseif mod.wad_charge_level == mod.WAD_CHARGE_LEVEL_1 then
        selected_charge = 0.01
    end

    return math.clamp(selected_charge, min_charge, max_charge)
end

function mod.action_damage_charge_level(action_name, action, weapon_tweak_templates, weapon_template,
                                        charge_action_name, charge_action)
    local weapon_template_name = weapon_template and weapon_template.name
    local weapon_damage_charge_levels = type(weapon_template_name) == "string" and
        DAMAGE_CHARGE_LEVELS_BY_WEAPON_TEMPLATE[weapon_template_name]
    local damage_charge_level = weapon_damage_charge_levels and weapon_damage_charge_levels[action_name]

    if type(damage_charge_level) == "number" then
        return damage_charge_level
    end

    local fire_configuration = type(action) == "table" and action.fire_configuration

    if type(charge_action) ~= "table" and
        (type(action) ~= "table" or action.use_charge ~= true) and
        (type(fire_configuration) ~= "table" or fire_configuration.use_charge ~= true) then
        return 1
    end

    return mod.action_assumed_charge_level(action_name, action, weapon_tweak_templates, weapon_template,
        charge_action_name, charge_action)
end

function mod.resolve_lerp_value(value)
    if type(value) ~= "table" then
        return value
    end

    local lerp_basic = value.lerp_basic
    local lerp_perfect = value.lerp_perfect

    if type(lerp_basic) == "number" and type(lerp_perfect) == "number" then
        return math.lerp(lerp_basic, lerp_perfect, 0.5)
    end

    return nil
end

function mod.new_action_damage_values()
    return {
        attack = {},
        impact = {},
        cleave = {},
    }
end

function mod.add_damage_values_by_armor(target, source)
    if not target or not source then return end

    for i = 1, #mod.ARMOR_DAMAGE_ORDER do
        local armor_type = mod.ARMOR_DAMAGE_ORDER[i]
        local value = source[armor_type]

        if type(value) == "number" then
            target[armor_type] = (target[armor_type] or 0) + value
        end
    end
end

function mod.armor_type_disallowed(disallowed_armor_types, armor_type)
    if type(disallowed_armor_types) ~= "table" then return false end

    for i = 1, #disallowed_armor_types do
        if disallowed_armor_types[i] == armor_type then
            return true
        end
    end

    return false
end

function mod.add_scaled_damage_values_by_armor(target, source, scale, disallowed_armor_types)
    if not target or not source then return end

    for i = 1, #mod.ARMOR_DAMAGE_ORDER do
        local armor_type = mod.ARMOR_DAMAGE_ORDER[i]
        local value = source[armor_type]

        if type(value) == "number" and not mod.armor_type_disallowed(disallowed_armor_types, armor_type) then
            target[armor_type] = (target[armor_type] or 0) + value * scale
        end
    end
end

function mod.damage_values_have_positive_value(values_by_armor)
    if not values_by_armor then return false end

    for i = 1, #mod.ARMOR_DAMAGE_ORDER do
        local armor_type = mod.ARMOR_DAMAGE_ORDER[i]
        local value = values_by_armor[armor_type]

        if type(value) == "number" and value > 0 then
            return true
        end
    end

    return false
end

-- ============================================================================
-- CORE DAMAGE MATH
-- ============================================================================

local function calculate_cleave_value(cleave_min, cleave_range, scaled_cleave_power_level, cleave_distribution,
                                      power_type, current_lerps)
    local distribution = cleave_distribution and cleave_distribution[power_type]

    if type(distribution) == "table" then
        local lerp_value = DamageProfile.lerp_value_from_path(current_lerps, "cleave_distribution", "attack")
        distribution = DamageProfile.lerp_damage_profile_entry(distribution, lerp_value)
    end

    if type(distribution) ~= "number" then return 0 end

    local cleave_power_level = scaled_cleave_power_level * distribution
    local cleave_percentage = PowerLevel.power_level_percentage(cleave_power_level)

    return cleave_min + cleave_range * cleave_percentage
end

function mod.damage_profile_target_index(damage_profile)
    local targets = damage_profile and damage_profile.targets
    if not targets then return nil end
    return targets[1] and 1 or "default_target"
end

function mod.action_damage_profile_lerp_values(damage_profile_lerp_values, action_name, damage_profile, target_index)
    local action_lerps = damage_profile_lerp_values and damage_profile_lerp_values[action_name]
    local damage_profile_name = damage_profile and damage_profile.name
    local current_lerps = action_lerps and damage_profile_name and action_lerps[damage_profile_name] or action_lerps or
        {}

    local targets = current_lerps.targets
    local target_settings_lerp_values = targets and (targets[target_index] or targets.default_target) or EMPTY_TABLE

    return current_lerps, target_settings_lerp_values
end

function mod.calculate_damage_profile_hit_zone_values(action_name, action, damage_profile, action_power_level,
                                                      damage_profile_lerp_values, dropoff_scalar, include_cleave,
                                                      weapon_tweak_templates, weapon_template, charge_action_name,
                                                      charge_action)
    local target_index = mod.damage_profile_target_index(damage_profile)
    if not target_index then return nil, nil end

    local target_settings = DamageProfile.target_settings(damage_profile, target_index)
    if not target_settings then return nil, nil end

    local charge_level = mod.action_damage_charge_level(action_name, action, weapon_tweak_templates,
        weapon_template, charge_action_name, charge_action)
    local armor_penetrating = false

    local hit_zone = mod.wad_damage_hit_zone
    local hit_weakspot = mod.WAD_DAMAGE_HIT_ZONE_IS_WEAKSPOT[hit_zone] == true
    local is_critical_strike = mod.WAD_DAMAGE_HIT_ZONE_IS_CRITICAL[hit_zone] == true

    local current_lerps, target_settings_lerp_values = mod.action_damage_profile_lerp_values(damage_profile_lerp_values,
        action_name, damage_profile, target_index)
    local old_current_target_settings_lerp_values = current_lerps.current_target_settings_lerp_values

    local range_min, range_max = DamageProfile.ranges(damage_profile, current_lerps)
    local has_ranged_interval = type(range_min) == "number" and type(range_max) == "number" and range_max >= range_min
    local resolved_dropoff_scalar = has_ranged_interval and type(dropoff_scalar) == "number" and dropoff_scalar or false

    current_lerps.current_target_settings_lerp_values = target_settings_lerp_values

    -- Cleave uses the action's original power level. First-target power modifiers affect damage and impact only.
    local cleave_action_power_level = action_power_level

    if target_settings.power_level_multiplier then
        local power_level_lerp_value = DamageProfile.lerp_value_from_path(current_lerps, "targets", 1,
            "power_level_multiplier")
        action_power_level = action_power_level *
            DamageProfile.lerp_damage_profile_entry(target_settings.power_level_multiplier, power_level_lerp_value)
    end

    local base_attack, base_impact = DamageCalculation.base_ui_damage(damage_profile, target_settings, action_power_level,
        charge_level, resolved_dropoff_scalar, current_lerps)
    local base_cleave

    if include_cleave ~= false then
        local scaled_cleave_power_level = PowerLevel.scale_by_charge_level(cleave_action_power_level, charge_level,
            damage_profile.charge_level_scaler)
        scaled_cleave_power_level = PowerLevel.scale_power_level_to_power_type_curve(scaled_cleave_power_level, "cleave",
            nil, nil, nil, nil, nil, damage_profile)

        local cleave_output = PowerLevelSettings.cleave_output
        local cleave_min, cleave_max = cleave_output.min, cleave_output.max
        local cleave_range = cleave_max - cleave_min
        local cleave_distribution = damage_profile.cleave_distribution or PowerLevelSettings.default_cleave_distribution

        base_cleave = math.max(
            calculate_cleave_value(cleave_min, cleave_range, scaled_cleave_power_level, cleave_distribution, "attack",
                current_lerps),
            calculate_cleave_value(cleave_min, cleave_range, scaled_cleave_power_level, cleave_distribution, "impact",
                current_lerps)
        )
    end

    local attack_values = {}
    local impact_values = {}
    local cleave_values = base_cleave and {} or nil

    for i = 1, #mod.ARMOR_DAMAGE_ORDER do
        local armor_type = mod.ARMOR_DAMAGE_ORDER[i]
        local attack_armor_mod = DamageProfile.armor_damage_modifier("attack", damage_profile, target_settings,
            current_lerps, armor_type, is_critical_strike, resolved_dropoff_scalar, armor_penetrating, charge_level)
        local impact_armor_mod = DamageProfile.armor_damage_modifier("impact", damage_profile, target_settings,
            current_lerps, armor_type, is_critical_strike, resolved_dropoff_scalar, armor_penetrating, charge_level)
        local finesse_mult = (hit_weakspot or is_critical_strike) and
            DamageCalculation.ui_finesse_multiplier(damage_profile, target_settings, armor_type, hit_weakspot,
                is_critical_strike, current_lerps) or 1

        attack_values[armor_type] = base_attack * attack_armor_mod * finesse_mult
        impact_values[armor_type] = base_impact * impact_armor_mod * finesse_mult

        if cleave_values then
            cleave_values[armor_type] = base_cleave
        end
    end

    current_lerps.current_target_settings_lerp_values = old_current_target_settings_lerp_values

    return attack_values, impact_values, cleave_values
end

-- ============================================================================
-- STAT EXTRACTION (Crit, Max Shots, Suppression)
-- ============================================================================

function mod.action_critical_strike_chance_bonus(action, action_name, weapon_template, weapon_tweak_templates)
    if not action then return nil end

    local chance_modifier
    local weapon_handling = weapon_tweak_templates and weapon_tweak_templates[template_types.weapon_handling]

    if weapon_handling and weapon_template and action_name then
        local _, lerped_identifier = WeaponTweakTemplates.get_template_identifiers(weapon_template,
            template_types.weapon_handling, action_name)
        local action_stats = lerped_identifier and weapon_handling[lerped_identifier]
        local critical_strike = action_stats and action_stats.critical_strike

        chance_modifier = critical_strike and critical_strike.chance_modifier
    end

    if chance_modifier == nil then
        local weapon_handling_template_name = action.weapon_handling_template or "none"
        local weapon_handling_template = WeaponHandlingTemplates[weapon_handling_template_name]
        local critical_strike = weapon_handling_template and weapon_handling_template.critical_strike

        chance_modifier = critical_strike and critical_strike.chance_modifier
    end

    chance_modifier = mod.resolve_lerp_value(chance_modifier)
    return type(chance_modifier) == "number" and chance_modifier ~= 0 and chance_modifier or nil
end

function mod.action_max_critical_shots(action, action_name, weapon_template, weapon_tweak_templates)
    if not action then return nil end

    local max_critical_shots
    local weapon_handling = weapon_tweak_templates and weapon_tweak_templates[template_types.weapon_handling]

    if weapon_handling and weapon_template and action_name then
        local _, lerped_identifier = WeaponTweakTemplates.get_template_identifiers(weapon_template,
            template_types.weapon_handling, action_name)
        local action_stats = lerped_identifier and weapon_handling[lerped_identifier]
        local critical_strike = action_stats and action_stats.critical_strike

        max_critical_shots = critical_strike and critical_strike.max_critical_shots
    end

    if max_critical_shots == nil then
        local weapon_handling_template_name = action.weapon_handling_template or "none"
        local weapon_handling_template = WeaponHandlingTemplates[weapon_handling_template_name]
        local critical_strike = weapon_handling_template and weapon_handling_template.critical_strike

        max_critical_shots = critical_strike and critical_strike.max_critical_shots
    end

    max_critical_shots = mod.resolve_lerp_value(max_critical_shots)
    return type(max_critical_shots) == "number" and max_critical_shots > 0 and max_critical_shots or nil
end

local function find_max_suppression_val(tbl, keys_dict)
    if type(tbl) ~= "table" then return nil end
    local max_val

    for k, v in pairs(tbl) do
        if keys_dict[k] then
            local val = mod.resolve_lerp_value(v)

            if type(val) == "number" and (not max_val or val > max_val) then
                max_val = val
            end
        elseif type(v) == "table" then
            local sub_val = find_max_suppression_val(v, keys_dict)

            if sub_val and (not max_val or sub_val > max_val) then
                max_val = sub_val
            end
        end
    end

    return max_val
end

function mod.action_suppression_values(action, action_name, weapon_template, weapon_tweak_templates)
    if not action or type(action_name) ~= "string" then return nil, nil end

    if action.kind ~= "shoot_hit_scan" and action.kind ~= "shoot_projectile" and action.kind ~= "shoot_pellets" then
        return nil, nil
    end

    local is_alternate_fire = string.find(action_name, "zoom", 1, true) or string.find(action_name, "brace", 1, true)
    local suppression_template_name

    if is_alternate_fire and weapon_template.alternate_fire_settings then
        suppression_template_name = weapon_template.alternate_fire_settings.suppression_template
    end

    suppression_template_name = suppression_template_name or action.suppression_template or
        weapon_template.suppression_template

    if not suppression_template_name or suppression_template_name == "none" then return nil, nil end

    local suppression_template = SuppressionTemplates and SuppressionTemplates[suppression_template_name]
    local amount, radius
    local template_type_suppression = template_types and template_types.suppression or "suppression"
    local weapon_suppression = weapon_tweak_templates and weapon_tweak_templates[template_type_suppression]

    if weapon_suppression and weapon_template and action_name then
        local _, lerped_identifier = WeaponTweakTemplates.get_template_identifiers(weapon_template,
            template_type_suppression, action_name)
        local suppression_stats = lerped_identifier and weapon_suppression[lerped_identifier]

        if suppression_stats then
            amount = find_max_suppression_val(suppression_stats, SUPPRESSION_AMOUNT_KEYS)
            radius = find_max_suppression_val(suppression_stats, SUPPRESSION_RADIUS_KEYS)
        end
    end

    if not amount and suppression_template then
        amount = find_max_suppression_val(suppression_template, SUPPRESSION_AMOUNT_KEYS)
    end

    if not radius and suppression_template then
        radius = find_max_suppression_val(suppression_template, SUPPRESSION_RADIUS_KEYS)
    end

    return type(amount) == "number" and amount > 0 and amount or nil,
        type(radius) == "number" and radius > 0 and radius or nil
end

-- ============================================================================
-- ORCHESTRATOR
-- ============================================================================

function mod.action_damage_breakdown_text(action, action_name, damage_profile_lerp_values, use_special_damage_profile,
                                          weapon_template, weapon_tweak_templates, item, charge_action_name,
                                          charge_action)
    local base_hit_zone = mod.wad_damage_hit_zone
    local crit_hit_zone = (base_hit_zone == mod.WAD_DAMAGE_HIT_ZONE_BODY) and mod.WAD_DAMAGE_HIT_ZONE_CRITICAL or
        mod.WAD_DAMAGE_HIT_ZONE_CRITICAL_WEAKSPOT

    -- Temporarily set hit zone to collect base data.
    mod.wad_damage_hit_zone = base_hit_zone

    local base_values = mod.action_damage_values_by_armor(action, action_name, damage_profile_lerp_values,
        use_special_damage_profile, weapon_tweak_templates, weapon_template, charge_action_name, charge_action)
    local base_stagger = mod.action_stagger_details(action, use_special_damage_profile)
    local base_cleave = mod.action_cleave_details(action, use_special_damage_profile)

    -- Temporarily set hit zone to collect critical data.
    mod.wad_damage_hit_zone = crit_hit_zone

    local crit_values = mod.action_damage_values_by_armor(action, action_name, damage_profile_lerp_values,
        use_special_damage_profile, weapon_tweak_templates, weapon_template, charge_action_name, charge_action)
    local crit_stagger = mod.action_stagger_details(action, use_special_damage_profile)
    local crit_cleave = mod.action_cleave_details(action, use_special_damage_profile)

    -- Restore configured hit zone.
    mod.wad_damage_hit_zone = base_hit_zone

    local base_data = {
        damage = base_values and base_values.attack,
        impact = base_values and base_values.impact,
        cleave = base_values and base_values.cleave,
        range = base_values and base_values.range_by_armor,
        stagger_details = base_stagger,
        cleave_details = base_cleave
    }

    local crit_data = {
        damage = crit_values and crit_values.attack,
        impact = crit_values and crit_values.impact,
        cleave = crit_values and crit_values.cleave,
        range = crit_values and crit_values.range_by_armor,
        stagger_details = crit_stagger,
        cleave_details = crit_cleave
    }

    local amt, rad = mod.action_suppression_values(action, action_name, weapon_template, weapon_tweak_templates)
    local shared_data = {
        critical_strike_chance_bonus = mod.action_critical_strike_chance_bonus(action, action_name, weapon_template,
            weapon_tweak_templates),
        max_critical_shots = mod.action_max_critical_shots(action, action_name, weapon_template, weapon_tweak_templates),
        suppression_amount = amt,
        suppression_radius = rad,
        peril_text = mod.action_peril_text(action, action_name, weapon_template, weapon_tweak_templates,
            charge_action_name, charge_action),
        heat_text = mod.action_heat_text(action, action_name, weapon_template, weapon_tweak_templates,
            use_special_damage_profile, charge_action_name, charge_action),
        stagger_categories = mod.action_stagger_categories(action, use_special_damage_profile),
        ignores_shield = mod.action_damage_profile_ignores_shield(action, use_special_damage_profile),
        shield_breaker = mod.action_damage_profile_is_shield_breaker(action, use_special_damage_profile),
        backstab_bonus = mod.action_backstab_bonus(action, use_special_damage_profile),
        pellet_data = mod.action_pellet_data(action, use_special_damage_profile)
    }

    shared_data.damage_per_second = mod.action_ranged_damage_per_second(
        action, action_name, item, weapon_template, weapon_tweak_templates,
        base_data.damage and base_data.damage[ARMOR_TYPES.unarmored]
    )
    shared_data.critical_damage_per_second = mod.action_ranged_damage_per_second(
        action, action_name, item, weapon_template, weapon_tweak_templates,
        crit_data.damage and crit_data.damage[ARMOR_TYPES.unarmored]
    )

    shared_data.ammo_text = mod.special_action_ammo_text(action_name, action, weapon_template) or
        mod.ranged_weapon_wield_ammo_text(action, action_name, item, weapon_template, weapon_tweak_templates,
            damage_profile_lerp_values)

    local damage_text, armor_grid = mod.format_combined_armor_modifier_text(base_data, crit_data, shared_data)
    local range_affects_performance = (base_values and base_values.range_affects_performance) or
        (crit_values and crit_values.range_affects_performance)

    return damage_text, armor_grid, range_affects_performance == true
end
