-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_burning.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local DamageProfileTemplates = mod:original_require("scripts/settings/damage/damage_profile_templates")
local WeaponBuffTemplates = mod:original_require("scripts/settings/buff/weapon_buff_templates")
local WeaponTweakTemplates = mod:original_require(
    "scripts/extension_systems/weapon/utilities/weapon_tweak_templates"
)
local WeaponTweakTemplateSettings = mod:original_require(
    "scripts/settings/equipment/weapon_templates/weapon_tweak_template_settings"
)
local Localize = Localize

local template_types = WeaponTweakTemplateSettings and WeaponTweakTemplateSettings.template_types or {}
local BURNING_BUFF_NAME = "flamer_assault"
local BURNING_DAMAGE_PROFILE_NAME = "burning"
local BURNING_MAX_POWER_LEVEL = 500
local BURNING_BUFF_TEMPLATE = WeaponBuffTemplates and WeaponBuffTemplates[BURNING_BUFF_NAME]
local BURNING_DAMAGE_PROFILE = DamageProfileTemplates and DamageProfileTemplates[BURNING_DAMAGE_PROFILE_NAME]
local BURNING_WEAPON_TEMPLATES = {
    flamer_p1_m1 = true,
}

local burning_tables_by_max_stacks = {}

local function burning_power_level(stack_count, global_max_stacks)
    local stack_fraction = stack_count / global_max_stacks
    local smoothstep_multiplier = stack_fraction * stack_fraction * (3 - 2 * stack_fraction)

    return smoothstep_multiplier * BURNING_MAX_POWER_LEVEL
end

local function resolved_burning_template(weapon_template, weapon_tweak_templates)
    local burninating_template_type = template_types.burninating
    local resolved_templates = burninating_template_type and weapon_tweak_templates and
        weapon_tweak_templates[burninating_template_type]

    if type(resolved_templates) ~= "table" or type(weapon_template) ~= "table" then
        return nil
    end

    local _, resolved_identifier = WeaponTweakTemplates.get_template_identifiers(
        weapon_template,
        burninating_template_type,
        "base"
    )

    local resolved_template = resolved_identifier and resolved_templates[resolved_identifier]

    return type(resolved_template) == "table" and resolved_template or nil
end

local function resolved_burning_max_stacks(weapon_template, weapon_tweak_templates)
    local resolved_template = resolved_burning_template(weapon_template, weapon_tweak_templates)
    local resolved_max_stacks = resolved_template and resolved_template.max_stacks
    local global_max_stacks = BURNING_BUFF_TEMPLATE and
        (BURNING_BUFF_TEMPLATE.max_stacks_cap or BURNING_BUFF_TEMPLATE.max_stacks)

    if type(resolved_max_stacks) ~= "number" or type(global_max_stacks) ~= "number" then
        return nil
    end

    return math.clamp(math.ceil(resolved_max_stacks), 1, global_max_stacks)
end

local function build_burning_tables(max_stacks)
    local cached_tables = burning_tables_by_max_stacks[max_stacks]

    if cached_tables then
        return cached_tables.damage_table, cached_tables.armor_grid
    end

    local damage_interval = BURNING_BUFF_TEMPLATE and BURNING_BUFF_TEMPLATE.interval
    local global_max_stacks = BURNING_BUFF_TEMPLATE and
        (BURNING_BUFF_TEMPLATE.max_stacks_cap or BURNING_BUFF_TEMPLATE.max_stacks)
    local damage_table, armor_grid = mod.interval_effect_damage_tables(
        BURNING_BUFF_NAME,
        BURNING_DAMAGE_PROFILE,
        max_stacks,
        damage_interval,
        burning_power_level,
        global_max_stacks
    )

    if damage_table and armor_grid then
        burning_tables_by_max_stacks[max_stacks] = {
            armor_grid = armor_grid,
            damage_table = damage_table,
        }
    end

    return damage_table, armor_grid
end

local function burning_action_entry(weapon_template, weapon_tweak_templates)
    local max_stacks = resolved_burning_max_stacks(weapon_template, weapon_tweak_templates)

    if not max_stacks then
        return nil
    end

    local damage_table, armor_grid = build_burning_tables(max_stacks)

    if not damage_table or not armor_grid then
        return nil
    end

    local detail_text = mod.interval_effect_general_information_text(
        BURNING_BUFF_TEMPLATE,
        BURNING_DAMAGE_PROFILE,
        max_stacks
    )

    if not detail_text then
        return nil
    end

    local burn_name = Localize(mod.WAD_LOC.STATS_DISPLAY_BURN_STAT)

    return {
        armor_grid = armor_grid,
        damage_table = damage_table,
        detail_text = detail_text,
        display_name = burn_name,
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.flame,
        kind = "interval_buff",
        name = BURNING_BUFF_NAME,
        stack_header = burn_name,
        damage_header = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_UNARMORED),
        armor_damage_header = Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT),
        is_effect_table = true,
    }
end

function mod.burning_action_entries(weapon_template_name, is_special_filter, weapon_template, weapon_tweak_templates)
    if is_special_filter or type(weapon_template_name) ~= "string" or
        not BURNING_WEAPON_TEMPLATES[weapon_template_name] then
        return nil
    end

    local entry = burning_action_entry(weapon_template, weapon_tweak_templates)

    return entry and { entry } or nil
end
