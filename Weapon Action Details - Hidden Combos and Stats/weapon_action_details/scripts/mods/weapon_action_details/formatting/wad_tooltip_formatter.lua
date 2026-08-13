-- File: weapon_action_details/scripts/mods/weapon_action_details/formatting/wad_tooltip_formatter.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")
local DamageCalculation = mod:original_require("scripts/utilities/attack/damage_calculation")
local DamageProfile = mod:original_require("scripts/utilities/attack/damage_profile")
local PowerLevel = mod:original_require("scripts/utilities/attack/power_level")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local Localize = Localize

local DAMAGE_TEXT_COLOR = mod.WAD_DAMAGE_TEXT_COLOR
local IMPACT_TEXT_COLOR = mod.WAD_IMPACT_TEXT_COLOR
local CRIT_TEXT_COLOR = mod.WAD_CRIT_TEXT_COLOR
local DAMAGE_GLYPH = mod.WAD_DAMAGE_GLYPH
local IMPACT_GLYPH = mod.WAD_IMPACT_GLYPH
local CRIT_GLYPH = mod.WAD_CRIT_GLYPH
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET
local ARMOR_TYPES = ArmorSettings.types

local ARMOR_DAMAGE_ORDER = mod.ARMOR_DAMAGE_ORDER
local EMPTY_TABLE = {}

mod.WAD_ACTION_TOOLTIP_GRID_TARGET_COUNT = 5

local TARGET_COUNT = mod.WAD_ACTION_TOOLTIP_GRID_TARGET_COUNT

local function armor_display_name(armor_type)
    local armor_localizations = UISettings.weapon_stats_armor_types or EMPTY_TABLE
    local localization_key = armor_localizations[armor_type]

    return localization_key and Localize(localization_key) or armor_type
end

local function target_header_text()
    return Localize(mod.WAD_LOC.STATS_DISPLAY_CLEAVE_TARGETS_STAT)
end

local function format_grid_number(value)
    return type(value) == "number" and string.format("%.0f", value) or "-"
end

function mod.action_tooltip_damage_grid_cell_text(damage_value, impact_value, critical_damage_value,
                                                  critical_impact_value)
    local has_normal_values = type(damage_value) == "number" or type(impact_value) == "number"
    local has_critical_values = type(critical_damage_value) == "number" or type(critical_impact_value) == "number"

    if not has_normal_values and not has_critical_values then
        return ""
    end

    local normal_text = string.format("%s%s %s%s  %s%s %s%s",
        DAMAGE_TEXT_COLOR, DAMAGE_GLYPH, format_grid_number(damage_value), RICH_TEXT_RESET,
        IMPACT_TEXT_COLOR, IMPACT_GLYPH, format_grid_number(impact_value), RICH_TEXT_RESET)

    if not has_critical_values then
        return normal_text
    end

    return string.format("%s\n%s%s%s %s%s%s  %s%s%s",
        normal_text,
        CRIT_TEXT_COLOR, CRIT_GLYPH, RICH_TEXT_RESET,
        DAMAGE_TEXT_COLOR, format_grid_number(critical_damage_value), RICH_TEXT_RESET,
        IMPACT_TEXT_COLOR, format_grid_number(critical_impact_value), RICH_TEXT_RESET)
end

function mod.action_tooltip_damage_grid_legend_text()
    return string.format("%s%s %s%s  %s%s %s%s  %s%s %s%s",
        DAMAGE_TEXT_COLOR, DAMAGE_GLYPH, Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT), RICH_TEXT_RESET,
        IMPACT_TEXT_COLOR, IMPACT_GLYPH, Localize(mod.WAD_LOC.STAGGER), RICH_TEXT_RESET,
        CRIT_TEXT_COLOR, CRIT_GLYPH, Localize(mod.WAD_LOC.WEAPON_DETAILS_CRIT), RICH_TEXT_RESET)
end

function mod.action_tooltip_damage_grid_column_headers()
    local headers = {}

    for target_index = 1, TARGET_COUNT do
        headers[target_index] = {
            target_index = target_index,
            text = tostring(target_index),
        }
    end

    return headers
end

local function armor_type_disallowed(disallowed_armor_types, armor_type)
    if type(disallowed_armor_types) ~= "table" then
        return false
    end

    for i = 1, #disallowed_armor_types do
        if disallowed_armor_types[i] == armor_type then
            return true
        end
    end

    return false
end

local function add_scaled_values_by_armor(target, source, scale, disallowed_armor_types)
    if not source then
        return
    end

    for i = 1, #ARMOR_DAMAGE_ORDER do
        local armor_type = ARMOR_DAMAGE_ORDER[i]
        local value = source[armor_type]

        if type(value) == "number" and not armor_type_disallowed(disallowed_armor_types, armor_type) then
            target[armor_type] = (target[armor_type] or 0) + value * scale
        end
    end
end

local function damage_profile_target_settings(damage_profile, target_index)
    local targets = damage_profile and damage_profile.targets

    if not targets then
        return nil
    end

    return DamageProfile.target_settings(damage_profile, target_index)
end

local function calculate_damage_profile_target_hit_zone_values(action_name, action, damage_profile, action_power_level,
                                                               damage_profile_lerp_values, target_index,
                                                               dropoff_scalar, weapon_tweak_templates, weapon_template,
                                                               charge_action_name, charge_action, hit_zone)
    local target_settings = damage_profile_target_settings(damage_profile, target_index)

    if not target_settings then
        return nil, nil
    end

    local charge_level = mod.action_damage_charge_level(action_name, action, weapon_tweak_templates, weapon_template,
        charge_action_name, charge_action)
    local armor_penetrating = false

    hit_zone = hit_zone or mod.wad_damage_hit_zone

    local hit_weakspot = mod.WAD_DAMAGE_HIT_ZONE_IS_WEAKSPOT[hit_zone] == true
    local is_critical_strike = mod.WAD_DAMAGE_HIT_ZONE_IS_CRITICAL[hit_zone] == true
    local current_lerps, target_settings_lerp_values = mod.action_damage_profile_lerp_values(
        damage_profile_lerp_values, action_name, damage_profile, target_index)
    local old_current_target_settings_lerp_values = current_lerps.current_target_settings_lerp_values
    local range_min, range_max = DamageProfile.ranges(damage_profile, current_lerps)
    local has_ranged_interval = type(range_min) == "number" and type(range_max) == "number" and
        range_max >= range_min
    local resolved_dropoff_scalar = has_ranged_interval and type(dropoff_scalar) == "number" and
        dropoff_scalar or false

    current_lerps.current_target_settings_lerp_values = target_settings_lerp_values

    if target_settings.power_level_multiplier then
        local power_level_lerp_value = DamageProfile.lerp_value_from_path(current_lerps, "targets", 1,
            "power_level_multiplier")

        action_power_level = action_power_level * DamageProfile.lerp_damage_profile_entry(
            target_settings.power_level_multiplier, power_level_lerp_value)
    end

    local base_attack, base_impact = DamageCalculation.base_ui_damage(damage_profile, target_settings,
        action_power_level, charge_level, resolved_dropoff_scalar, current_lerps)
    local attack_values = {}
    local impact_values = {}

    for i = 1, #ARMOR_DAMAGE_ORDER do
        local armor_type = ARMOR_DAMAGE_ORDER[i]
        local attack_armor_mod = DamageProfile.armor_damage_modifier("attack", damage_profile, target_settings,
            current_lerps, armor_type, is_critical_strike, resolved_dropoff_scalar, armor_penetrating, charge_level)
        local impact_armor_mod = DamageProfile.armor_damage_modifier("impact", damage_profile, target_settings,
            current_lerps, armor_type, is_critical_strike, resolved_dropoff_scalar, armor_penetrating, charge_level)
        local finesse_mult = (hit_weakspot or is_critical_strike) and
            DamageCalculation.ui_finesse_multiplier(damage_profile, target_settings, armor_type, hit_weakspot,
                is_critical_strike, current_lerps) or 1

        attack_values[armor_type] = base_attack * attack_armor_mod * finesse_mult
        impact_values[armor_type] = base_impact * impact_armor_mod * finesse_mult
    end

    current_lerps.current_target_settings_lerp_values = old_current_target_settings_lerp_values

    return attack_values, impact_values
end

local function add_damage_profile_target_values_to_totals(values_for_target, action, action_name, damage_profile,
                                                          damage_profile_lerp_values, power_level, scale,
                                                          disallowed_armor_types, target_index,
                                                          dropoff_scalar, weapon_tweak_templates, weapon_template,
                                                          charge_action_name, charge_action, hit_zone)
    if not damage_profile then
        return false
    end

    local attack_values, impact_values = calculate_damage_profile_target_hit_zone_values(action_name, action,
        damage_profile, power_level, damage_profile_lerp_values, target_index, dropoff_scalar,
        weapon_tweak_templates, weapon_template, charge_action_name, charge_action, hit_zone)

    add_scaled_values_by_armor(values_for_target.attack, attack_values, scale, disallowed_armor_types)
    add_scaled_values_by_armor(values_for_target.impact, impact_values, scale, disallowed_armor_types)

    return attack_values ~= nil or impact_values ~= nil
end

local function add_sticky_damage_values_by_target(values_by_target, action, action_name, damage_profile_lerp_values,
                                                  use_special_damage_profile, weapon_tweak_templates, weapon_template,
                                                  charge_action_name, charge_action, hit_zone)
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
    local values_for_target = values_by_target[1]
    local added_damage = false

    -- Sticky damage is repeatedly applied to the attached first target, not to later cleave targets.
    if normal_instances > 0 then
        added_damage = add_damage_profile_target_values_to_totals(values_for_target, action, action_name,
            normal_damage_profile, damage_profile_lerp_values, power_level, normal_instances,
            disallowed_armor_types, 1, false, weapon_tweak_templates, weapon_template, charge_action_name,
            charge_action, hit_zone) or added_damage
    end

    added_damage = add_damage_profile_target_values_to_totals(values_for_target, action, action_name, last_damage_profile,
        damage_profile_lerp_values, power_level, 1, disallowed_armor_types, 1, false, weapon_tweak_templates,
        weapon_template, charge_action_name, charge_action, hit_zone) or added_damage

    return added_damage
end

local function new_values_by_target()
    local values_by_target = {}

    for target_index = 1, TARGET_COUNT do
        values_by_target[target_index] = {
            attack = {},
            impact = {},
        }
    end

    return values_by_target
end

local function action_tooltip_damage_grid_values_at_dropoff(action, action_name, damage_profile_lerp_values,
                                                            use_special_damage_profile, dropoff_scalar,
                                                            weapon_tweak_templates, weapon_template,
                                                            charge_action_name, charge_action, hit_zone)
    local values_by_target = new_values_by_target()
    local num_templates = Action.num_damage_templates(action)
    local has_damage_profile = false

    for template_i = 1, num_templates do
        local damage_profile = mod.selected_damage_profile(action, template_i, use_special_damage_profile)

        if damage_profile then
            local action_power_level = Action.stat_power_level(action, template_i)

            for target_index = 1, TARGET_COUNT do
                has_damage_profile = add_damage_profile_target_values_to_totals(values_by_target[target_index],
                    action, action_name, damage_profile, damage_profile_lerp_values, action_power_level, 1, nil,
                    target_index, dropoff_scalar, weapon_tweak_templates, weapon_template, charge_action_name,
                    charge_action, hit_zone) or has_damage_profile
            end

            local explosion_template = Action.explosion_template(action, template_i)
            local inner_damage_profile = explosion_template and explosion_template.close_damage_profile

            if inner_damage_profile and inner_damage_profile ~= damage_profile then
                local explosion_power_level = explosion_template.static_power_level or action_power_level

                for target_index = 1, TARGET_COUNT do
                    has_damage_profile = add_damage_profile_target_values_to_totals(values_by_target[target_index],
                        action, action_name, inner_damage_profile, damage_profile_lerp_values, explosion_power_level, 1,
                        nil, target_index, dropoff_scalar, weapon_tweak_templates, weapon_template,
                        charge_action_name, charge_action, hit_zone) or has_damage_profile
                end
            end
        end
    end

    if add_sticky_damage_values_by_target(values_by_target, action, action_name, damage_profile_lerp_values,
            use_special_damage_profile, weapon_tweak_templates, weapon_template, charge_action_name,
            charge_action, hit_zone) then
        has_damage_profile = true
    end

    return has_damage_profile and values_by_target or nil
end

local function selected_tooltip_damage_grid_values(near_values_by_target, far_values_by_target, range_by_armor)
    local values_by_target = new_values_by_target()
    local has_values = false

    for target_index = 1, TARGET_COUNT do
        local near_values = near_values_by_target and near_values_by_target[target_index]
        local far_values = far_values_by_target and far_values_by_target[target_index]

        for i = 1, #ARMOR_DAMAGE_ORDER do
            local armor_type = ARMOR_DAMAGE_ORDER[i]
            local armor_range = range_by_armor and range_by_armor[armor_type]
            local use_far = armor_range and armor_range.dropoff_scalar == 1
            local selected_values = use_far and far_values or near_values
            local fallback_values = use_far and near_values or far_values
            local attack_value = selected_values and selected_values.attack[armor_type]
            local impact_value = selected_values and selected_values.impact[armor_type]

            if type(attack_value) ~= "number" and fallback_values then
                attack_value = fallback_values.attack[armor_type]
            end

            if type(impact_value) ~= "number" and fallback_values then
                impact_value = fallback_values.impact[armor_type]
            end

            if type(attack_value) == "number" then
                values_by_target[target_index].attack[armor_type] = attack_value
                has_values = true
            end

            if type(impact_value) == "number" then
                values_by_target[target_index].impact[armor_type] = impact_value
                has_values = true
            end
        end
    end

    if has_values then
        values_by_target.range_by_armor = range_by_armor
        values_by_target.range_mode = mod.wad_range_mode or mod.WAD_RANGE_MODE_OPTIMAL
    end

    return has_values and values_by_target or nil
end

function mod.action_tooltip_damage_grid_values(action, action_name, damage_profile_lerp_values,
                                               use_special_damage_profile, weapon_tweak_templates, weapon_template,
                                               charge_action_name, charge_action, hit_zone, range_by_armor)
    if not action then
        return nil
    end

    if range_by_armor == nil then
        local action_damage_values = mod.action_damage_values_by_armor(action, action_name, damage_profile_lerp_values,
            use_special_damage_profile, weapon_tweak_templates, weapon_template, charge_action_name, charge_action)

        range_by_armor = action_damage_values and action_damage_values.range_by_armor or false
    end

    if not range_by_armor then
        return action_tooltip_damage_grid_values_at_dropoff(action, action_name, damage_profile_lerp_values,
            use_special_damage_profile, false, weapon_tweak_templates, weapon_template, charge_action_name,
            charge_action, hit_zone)
    end

    local near_values_by_target = action_tooltip_damage_grid_values_at_dropoff(action, action_name,
        damage_profile_lerp_values, use_special_damage_profile, 0, weapon_tweak_templates, weapon_template,
        charge_action_name, charge_action, hit_zone)
    local far_values_by_target = action_tooltip_damage_grid_values_at_dropoff(action, action_name,
        damage_profile_lerp_values, use_special_damage_profile, 1, weapon_tweak_templates, weapon_template,
        charge_action_name, charge_action, hit_zone)

    if not near_values_by_target and not far_values_by_target then
        return nil
    end

    near_values_by_target = near_values_by_target or far_values_by_target
    far_values_by_target = far_values_by_target or near_values_by_target

    return selected_tooltip_damage_grid_values(near_values_by_target, far_values_by_target, range_by_armor)
end

function mod.action_tooltip_damage_grid_data(action, action_name, damage_profile_lerp_values,
                                             use_special_damage_profile, weapon_tweak_templates, weapon_template,
                                             charge_action_name, charge_action)
    local hit_zone = mod.wad_damage_hit_zone
    local critical_hit_zone = mod.WAD_DAMAGE_HIT_ZONE_IS_WEAKSPOT[hit_zone] and
        mod.WAD_DAMAGE_HIT_ZONE_CRITICAL_WEAKSPOT or mod.WAD_DAMAGE_HIT_ZONE_CRITICAL
    local values_by_target = mod.action_tooltip_damage_grid_values(action, action_name, damage_profile_lerp_values,
        use_special_damage_profile, weapon_tweak_templates, weapon_template, charge_action_name, charge_action,
        hit_zone)

    if not values_by_target then
        return nil
    end

    local critical_values_by_target = mod.action_tooltip_damage_grid_values(action, action_name,
        damage_profile_lerp_values, use_special_damage_profile, weapon_tweak_templates, weapon_template,
        charge_action_name, charge_action, critical_hit_zone, values_by_target.range_by_armor or false)
    local rows = {}
    local has_values = false

    for armor_index = 1, #ARMOR_DAMAGE_ORDER do
        local armor_type = ARMOR_DAMAGE_ORDER[armor_index]
        local row = {
            armor_type = armor_type,
            display_name = armor_display_name(armor_type),
            cells = {},
        }

        for target_index = 1, TARGET_COUNT do
            local values_for_target = values_by_target[target_index]
            local critical_values_for_target = critical_values_by_target and critical_values_by_target[target_index]
            local damage_value = values_for_target and values_for_target.attack[armor_type]
            local impact_value = values_for_target and values_for_target.impact[armor_type]
            local critical_damage_value = critical_values_for_target and
                critical_values_for_target.attack[armor_type]
            local critical_impact_value = critical_values_for_target and
                critical_values_for_target.impact[armor_type]

            row.cells[target_index] = {
                target_index = target_index,
                damage = damage_value,
                impact = impact_value,
                critical_damage = critical_damage_value,
                critical_impact = critical_impact_value,
                text = mod.action_tooltip_damage_grid_cell_text(damage_value, impact_value, critical_damage_value,
                    critical_impact_value),
            }

            if type(damage_value) == "number" or type(impact_value) == "number" or
                type(critical_damage_value) == "number" or type(critical_impact_value) == "number" then
                has_values = true
            end
        end

        rows[#rows + 1] = row
    end

    if not has_values then
        return nil
    end

    return {
        target_count = TARGET_COUNT,
        hit_zone = hit_zone,
        critical_hit_zone = critical_hit_zone,
        range_mode = values_by_target.range_mode,
        range_by_armor = values_by_target.range_by_armor,
        legend_text = mod.action_tooltip_damage_grid_legend_text(),
        target_header_text = target_header_text(),
        column_headers = mod.action_tooltip_damage_grid_column_headers(),
        armor_rows = rows,
        values_by_target = values_by_target,
        critical_values_by_target = critical_values_by_target,
    }
end
