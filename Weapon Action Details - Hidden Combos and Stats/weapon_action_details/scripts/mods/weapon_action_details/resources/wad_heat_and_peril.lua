-- File: weapon_action_details/scripts/mods/weapon_action_details/resources/wad_heat_and_peril.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local ArchetypeWarpChargeTemplates = mod:original_require("scripts/settings/warp_charge/archetype_warp_charge_templates")
local WeaponChargeTemplates = mod:original_require(
    "scripts/settings/equipment/weapon_handling_templates/weapon_charge_templates")
local WeaponTweakTemplateSettings = mod:original_require(
    "scripts/settings/equipment/weapon_templates/weapon_tweak_template_settings")
local WeaponWarpChargeTemplates = mod:original_require("scripts/settings/warp_charge/weapon_warp_charge_templates")

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local template_types = WeaponTweakTemplateSettings.template_types
local HEAT_TEXT_COLOR = mod.WAD_HEAT_TEXT_COLOR
local HEAT_GLYPH = mod.WAD_HEAT_GLYPH
local PERIL_TEXT_COLOR = mod.WAD_PERIL_TEXT_COLOR
local PERIL_GLYPH = mod.WAD_PERIL_GLYPH
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET
local DEFAULT_VENT_STARTING_PERCENTAGE = 1
local CHARGE_LEVEL_EPSILON = 0.005
local CHARGED_FLAME_STREAM_WEAPON_TEMPLATE = "forcestaff_p2_m1"
local CHARGED_FLAME_STREAM_ACTION = "action_shoot_charged_flame"

local ACTION_KINDS_THAT_PAY_WARP_CHARGE = {
    activate_special = true,
    block = true,
    chain_lightning = true,
    damage_target = true,
    explosion = true,
    flamer_gas = true,
    flamer_gas_burst = true,
    push = true,
    shoot = true,
    shoot_hit_scan = true,
    shoot_pellets = true,
    shoot_projectile = true,
    spawn_projectile = true,
    toggle_special = true,
    toggle_special_with_block = true,
    trigger_explosion = true,
}

local ACTION_KINDS_THAT_USE_FULL_CHARGE_TOTAL = {
    overload_charge = true,
    overload_charge_position_finder = true,
    overload_charge_target_finder = true,
    overload_charge_weapon_special = true,
    target_finder = true,
}

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

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

local function add_value(current_value, added_value)
    if type(added_value) ~= "number" then
        return current_value
    end

    return (current_value or 0) + added_value
end

function mod.format_percentage_points(value)
    local rounded_value = math.round(value * 10) / 10

    if rounded_value == 0 then
        return nil
    end

    if rounded_value == math.floor(rounded_value) then
        return string.format("%+d%%", rounded_value)
    end

    return string.format("%+.1f%%", rounded_value)
end

local function template_from_lookup(weapon_tweak_templates, template_type, template_name, base_templates)
    if type(template_name) == "table" then
        return template_name
    end

    if type(template_name) ~= "string" or template_name == "" or template_name == "none" then
        return nil
    end

    local resolved_templates = weapon_tweak_templates and weapon_tweak_templates[template_type]
    local resolved_template = resolved_templates and resolved_templates[template_name]

    if resolved_template then
        return resolved_template
    end

    return base_templates and base_templates[template_name] or nil
end

function mod.charge_template(template_name, weapon_tweak_templates)
    return template_from_lookup(weapon_tweak_templates, template_types.charge, template_name,
        WeaponChargeTemplates)
end

function mod.action_charge_template(action, weapon_tweak_templates)
    return mod.charge_template(action and action.charge_template, weapon_tweak_templates)
end

-- ============================================================================
-- HEAT MATH (Plasma, Lasguns)
-- ============================================================================

local function special_charge_template(weapon_template, weapon_tweak_templates)
    return mod.charge_template(weapon_template and weapon_template.special_charge_template,
        weapon_tweak_templates)
end

local function action_is_shoot(action)
    local kind = action and action.kind

    return type(kind) == "string" and string.find(kind, "shoot", 1, true) == 1
end

local function action_exits_when_fully_charged(action)
    local running_action_state_to_action_input = action and action.running_action_state_to_action_input

    return type(running_action_state_to_action_input) == "table" and
        running_action_state_to_action_input.fully_charged ~= nil
end

local function selected_charge_level(action_name, action, weapon_template, weapon_tweak_templates,
                                     charge_action_name, charge_action)
    return mod.action_assumed_charge_level(action_name, action, weapon_tweak_templates, weapon_template,
        charge_action_name, charge_action)
end

local function charge_progress_for_level(charge_template, charge_level)
    if type(charge_level) ~= "number" or charge_level <= 0 then
        return 0
    end

    local min_charge = mod.resolve_lerp_value(charge_template and charge_template.min_charge) or 0
    local remaining_charge_range = 1 - min_charge

    if remaining_charge_range <= 0 then
        return 0
    end

    return math.clamp((charge_level - min_charge) / remaining_charge_range, 0, 1)
end

local function action_charge_heat_values(action_name, action, weapon_template, weapon_tweak_templates,
                                         charge_action_name, charge_action)
    local source_action = type(charge_action) == "table" and charge_action or action
    local source_action_name = type(charge_action_name) == "string" and charge_action_name or action_name

    if not source_action or source_action.overload_module_class_name ~= "overheat" then
        return nil, nil
    end

    local charge_template = mod.resolved_action_charge_template(source_action_name, source_action, weapon_template,
        weapon_tweak_templates)
    local overheat_percent = mod.resolve_lerp_value(charge_template and charge_template.overheat_percent)

    if type(overheat_percent) ~= "number" then
        return nil, nil
    end

    local charge_level = selected_charge_level(action_name, action, weapon_template, weapon_tweak_templates,
        charge_action_name, charge_action)
    local charge_progress = charge_progress_for_level(charge_template, charge_level)
    local charge_total = overheat_percent * charge_progress * 100
    local full_charge_rate

    if charge_level >= 1 - CHARGE_LEVEL_EPSILON and not action_exits_when_fully_charged(source_action) then
        local full_charge_overheat_percent = mod.resolve_lerp_value(charge_template.full_charge_overheat_percent)

        if type(full_charge_overheat_percent) == "number" then
            full_charge_rate = full_charge_overheat_percent * 100
        end
    end

    return charge_total, full_charge_rate
end

local function action_shoot_heat_value(action, action_name, weapon_template, weapon_tweak_templates,
                                       charge_action_name, charge_action)
    if not action_is_shoot(action) then
        return nil
    end

    local charge_template = mod.resolved_action_charge_template(action_name, action, weapon_template,
        weapon_tweak_templates)
    local overheat_percent = mod.resolve_lerp_value(charge_template and charge_template.overheat_percent)

    if type(overheat_percent) ~= "number" then
        return nil
    end

    local charge_level = charge_template.use_charge and
        selected_charge_level(action_name, action, weapon_template, weapon_tweak_templates, charge_action_name,
            charge_action) or 1

    return overheat_percent * charge_level * 100
end

local function action_special_heat_values(action, weapon_template, weapon_tweak_templates, use_special_state)
    local charge_template = special_charge_template(weapon_template, weapon_tweak_templates)
    local overheat_overtime = charge_template and charge_template.overheat_overtime

    if type(overheat_overtime) ~= "table" then
        return nil, nil
    end

    local overheat_percent = mod.resolve_lerp_value(overheat_overtime.overheat_percent)

    if type(overheat_percent) ~= "number" then
        return nil, nil
    end

    if action and mod.WAD_SPECIAL_ACTIVATION_ACTION_KINDS[action.kind] then
        local charge_duration = mod.resolve_lerp_value(overheat_overtime.charge_duration)

        if type(charge_duration) == "number" and charge_duration > 0 then
            return nil, overheat_percent / charge_duration * 100
        end
    elseif use_special_state and action and action.kind == "sweep" then
        return overheat_percent * 100, nil
    end

    return nil, nil
end

local function action_vent_heat_value(action, weapon_template)
    if not action or action.kind ~= "vent_overheat" then
        return nil
    end

    local overheat_configuration = weapon_template and weapon_template.overheat_configuration
    local vent_duration = mod.resolve_lerp_value(overheat_configuration and overheat_configuration.vent_duration)

    if type(vent_duration) ~= "number" or vent_duration <= 0 then
        return nil
    end

    local starting_percentage = mod.resolve_lerp_value(overheat_configuration and
        overheat_configuration.fixed_starting_percentage) or DEFAULT_VENT_STARTING_PERCENTAGE

    return -(starting_percentage / vent_duration) * 100
end

function mod.action_heat_percentage_points(action, action_name, weapon_template, weapon_tweak_templates,
                                           use_special_state, charge_action_name, charge_action)
    local vent_value = action_vent_heat_value(action, weapon_template)

    if type(vent_value) == "number" then
        return nil, vent_value
    end

    local immediate_value, per_second_value = action_charge_heat_values(action_name, action, weapon_template,
        weapon_tweak_templates, charge_action_name, charge_action)
    local shoot_value = action_shoot_heat_value(action, action_name, weapon_template, weapon_tweak_templates,
        charge_action_name, charge_action)
    local special_immediate_value, special_per_second_value = action_special_heat_values(action, weapon_template,
        weapon_tweak_templates, use_special_state)

    immediate_value = add_value(immediate_value, shoot_value)
    immediate_value = add_value(immediate_value, special_immediate_value)
    per_second_value = add_value(per_second_value, special_per_second_value)

    return immediate_value, per_second_value
end

function mod.reload_state_heat_percentage_points_per_second(reload_state_name, reload_state, weapon_template)
    if type(reload_state) ~= "table" then
        return nil
    end

    local reduction_rate
    local functionality = reload_state.functionality

    if type(functionality) == "table" and functionality.clear_overheat ~= nil then
        local overheat_clear_speed = mod.resolve_lerp_value(reload_state.overheat_clear_speed) or 1

        if type(overheat_clear_speed) == "number" then
            reduction_rate = add_value(reduction_rate, -overheat_clear_speed * 100)
        end
    end

    local overheat_configuration = weapon_template and weapon_template.overheat_configuration
    local reload_state_overrides = overheat_configuration and overheat_configuration.reload_state_overrides
    local reload_state_override = mod.resolve_lerp_value(reload_state_overrides and
        reload_state_overrides[reload_state_name])

    if type(reload_state_override) == "number" then
        reduction_rate = add_value(reduction_rate, -reload_state_override * 100)
    end

    return reduction_rate
end

function mod.format_heat_percentage_points(immediate_value, per_second_value)
    local value_parts = {}
    local immediate_text = type(immediate_value) == "number" and mod.format_percentage_points(immediate_value)
    local per_second_text = type(per_second_value) == "number" and mod.format_percentage_points(per_second_value)

    if immediate_text then
        value_parts[#value_parts + 1] = immediate_text
    end

    if per_second_text then
        value_parts[#value_parts + 1] = per_second_text .. "/s"
    end

    if #value_parts == 0 then
        return nil
    end

    return string.format("%s%s %s%s", HEAT_TEXT_COLOR, HEAT_GLYPH, table.concat(value_parts, "•"),
        RICH_TEXT_RESET)
end

function mod.action_heat_text(action, action_name, weapon_template, weapon_tweak_templates, use_special_state,
                              charge_action_name, charge_action)
    local immediate_value, per_second_value = mod.action_heat_percentage_points(action, action_name, weapon_template,
        weapon_tweak_templates, use_special_state, charge_action_name, charge_action)

    return mod.format_heat_percentage_points(immediate_value, per_second_value)
end

function mod.reload_state_heat_text(reload_state_name, reload_state, weapon_template)
    local per_second_value = mod.reload_state_heat_percentage_points_per_second(reload_state_name, reload_state,
        weapon_template)

    return mod.format_heat_percentage_points(nil, per_second_value)
end

-- ============================================================================
-- PERIL MATH (Force Staves, Force Swords)
-- ============================================================================

function mod.action_weapon_warp_charge_template(action, weapon_template, weapon_tweak_templates)
    local warp_charge_template_name = action and action.warp_charge_template or
        weapon_template and weapon_template.warp_charge_template or "default"

    return template_from_lookup(weapon_tweak_templates, template_types.warp_charge, warp_charge_template_name,
        WeaponWarpChargeTemplates)
end

local function action_should_pay_warp_charge(action)
    if not action or not action.charge_template then
        return false
    end

    if ACTION_KINDS_THAT_PAY_WARP_CHARGE[action.kind] or ACTION_KINDS_THAT_USE_FULL_CHARGE_TOTAL[action.kind] then
        return true
    end

    return action.overload_module_class_name == "warp_charge" or action.pay_warp_charge_time ~= nil
end

local function action_uses_full_charge_total(action, charge_template)
    if not action or not charge_template then
        return false
    end

    return action.overload_module_class_name == "warp_charge" or
        ACTION_KINDS_THAT_USE_FULL_CHARGE_TOTAL[action.kind] == true
end

local function charged_flame_stream_cycle_count(action_name, action, weapon_template,
                                                weapon_tweak_templates, charge_template, charge_level)
    local weapon_template_name = weapon_template and weapon_template.name

    if weapon_template_name ~= CHARGED_FLAME_STREAM_WEAPON_TEMPLATE or
        action_name ~= CHARGED_FLAME_STREAM_ACTION or type(action) ~= "table" or
        type(charge_level) ~= "number" or charge_level <= 0 then
        return nil
    end

    local charge_cost = mod.resolve_lerp_value(charge_template and charge_template.charge_cost)
    local rate_of_fire = mod.action_rate_of_fire_per_second(action, weapon_template, weapon_tweak_templates,
        action_name)

    if type(charge_cost) ~= "number" or charge_cost <= 0 or
        type(rate_of_fire) ~= "number" or rate_of_fire <= 0 then
        return nil
    end

    return charge_level / charge_cost * rate_of_fire
end

local function action_charge_peril_value(action_name, action, weapon_template, weapon_tweak_templates,
                                         charge_level)
    if not action_should_pay_warp_charge(action) then
        return nil
    end

    local charge_template = mod.resolved_action_charge_template(action_name, action, weapon_template,
        weapon_tweak_templates)

    if not charge_template then
        return nil
    end

    local value = 0
    local has_value = false
    local start_warp_charge_percent = mod.resolve_lerp_value(charge_template.start_warp_charge_percent)
    local warp_charge_percent = mod.resolve_lerp_value(charge_template.warp_charge_percent)
    local full_charge_warp_charge_percent = mod.resolve_lerp_value(charge_template.full_charge_warp_charge_percent)

    if type(start_warp_charge_percent) == "number" then
        value = value + start_warp_charge_percent
        has_value = true
    end

    if action_uses_full_charge_total(action, charge_template) then
        local charge_progress = charge_progress_for_level(charge_template, charge_level)

        if type(warp_charge_percent) == "number" then
            value = value + warp_charge_percent * charge_progress
            has_value = true
        elseif type(full_charge_warp_charge_percent) == "number" then
            value = value + full_charge_warp_charge_percent * charge_progress
            has_value = true
        end
    elseif type(warp_charge_percent) == "number" then
        local payment_count = charge_template.use_charge and charge_level or 1
        local stream_cycle_count = charged_flame_stream_cycle_count(action_name, action, weapon_template,
            weapon_tweak_templates, charge_template, charge_level)

        if type(stream_cycle_count) == "number" then
            payment_count = stream_cycle_count
        end

        value = value + warp_charge_percent * payment_count
        has_value = true
    elseif type(full_charge_warp_charge_percent) == "number" then
        value = value + full_charge_warp_charge_percent * charge_level
        has_value = true
    end

    return has_value and value * 100 or nil
end

function mod.action_charge_peril_percentage_points(action, action_name, weapon_template, weapon_tweak_templates,
                                                   charge_action_name, charge_action)
    local charge_level = selected_charge_level(action_name, action, weapon_template, weapon_tweak_templates,
        charge_action_name, charge_action)
    local value = action_charge_peril_value(action_name, action, weapon_template, weapon_tweak_templates, charge_level)

    if type(charge_action) == "table" and charge_action ~= action then
        value = add_value(value, action_charge_peril_value(charge_action_name, charge_action, weapon_template,
            weapon_tweak_templates, charge_level))
    end

    return value
end

function mod.action_vent_peril_percentage_points_per_second(action, weapon_template, weapon_tweak_templates)
    if not action or action.kind ~= "vent_warp_charge" then
        return nil
    end

    local archetype_warp_charge_template = ArchetypeWarpChargeTemplates.psyker or ArchetypeWarpChargeTemplates.default

    if not archetype_warp_charge_template then
        return nil
    end

    local weapon_warp_charge_template = mod.action_weapon_warp_charge_template(action, weapon_template,
        weapon_tweak_templates)
    local base_vent_duration = archetype_warp_charge_template.vent_duration
    local min_vent_time_fraction = archetype_warp_charge_template.min_vent_time_fraction or 0
    local vent_duration_modifier = mod.resolve_lerp_value(weapon_warp_charge_template and
        weapon_warp_charge_template.vent_duration_modifier) or 1

    if type(base_vent_duration) ~= "number" or base_vent_duration <= 0 then
        return nil
    end

    local adjusted_base_vent_duration = base_vent_duration * min_vent_time_fraction +
        base_vent_duration * (1 - min_vent_time_fraction) * DEFAULT_VENT_STARTING_PERCENTAGE
    local vent_duration = adjusted_base_vent_duration * vent_duration_modifier

    if vent_duration <= 0 then
        return nil
    end

    return -(DEFAULT_VENT_STARTING_PERCENTAGE / vent_duration) * 100
end

function mod.action_peril_percentage_points(action, action_name, weapon_template, weapon_tweak_templates,
                                            charge_action_name, charge_action)
    local vent_peril = mod.action_vent_peril_percentage_points_per_second(action, weapon_template,
        weapon_tweak_templates)

    if type(vent_peril) == "number" then
        return vent_peril, true
    end

    return mod.action_charge_peril_percentage_points(action, action_name, weapon_template, weapon_tweak_templates,
        charge_action_name, charge_action), false
end

function mod.format_peril_percentage_points(value, is_per_second)
    if type(value) ~= "number" then
        return nil
    end

    local value_text = mod.format_percentage_points(value)

    if not value_text then
        return nil
    end

    if is_per_second then
        value_text = value_text .. "/s"
    end

    return string.format("%s%s %s%s", PERIL_TEXT_COLOR, PERIL_GLYPH, value_text, RICH_TEXT_RESET)
end

function mod.action_peril_text(action, action_name, weapon_template, weapon_tweak_templates, charge_action_name,
                               charge_action)
    local value, is_per_second = mod.action_peril_percentage_points(action, action_name, weapon_template,
        weapon_tweak_templates, charge_action_name, charge_action)

    return mod.format_peril_percentage_points(value, is_per_second)
end
