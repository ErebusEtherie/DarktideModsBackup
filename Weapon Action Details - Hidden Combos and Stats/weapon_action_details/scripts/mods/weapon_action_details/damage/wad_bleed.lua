-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_bleed.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local DamageProfileTemplates = mod:original_require("scripts/settings/damage/damage_profile_templates")
local WeaponBuffTemplates = mod:original_require("scripts/settings/buff/weapon_buff_templates")
local Localize = Localize

local BLEED_BUFF_NAME = "bleed"
local BLEED_DAMAGE_PROFILE_NAME = "bleeding"
local BLEED_MAX_POWER_LEVEL = 500
local BLEED_BUFF_TEMPLATE = WeaponBuffTemplates and WeaponBuffTemplates[BLEED_BUFF_NAME]
local BLEED_DAMAGE_PROFILE = DamageProfileTemplates and DamageProfileTemplates[BLEED_DAMAGE_PROFILE_NAME]
local BLEED_WEAPON_TEMPLATES = {
    combatknife_p1_m1 = true,
    combatknife_p1_m2 = true,
}

local bleed_damage_table
local bleed_armor_grid

local function bleed_power_level(stack_count, max_stacks)
    local stack_fraction = stack_count / max_stacks
    local smoothstep_multiplier = stack_fraction * stack_fraction * (3 - 2 * stack_fraction)

    return smoothstep_multiplier * BLEED_MAX_POWER_LEVEL
end

local function build_bleed_tables()
    if bleed_damage_table and bleed_armor_grid then
        return true
    end

    local max_stacks = BLEED_BUFF_TEMPLATE and BLEED_BUFF_TEMPLATE.max_stacks
    local interval = BLEED_BUFF_TEMPLATE and BLEED_BUFF_TEMPLATE.interval

    bleed_damage_table, bleed_armor_grid = mod.interval_effect_damage_tables(
        BLEED_DAMAGE_PROFILE_NAME,
        BLEED_DAMAGE_PROFILE,
        max_stacks,
        interval,
        bleed_power_level
    )

    return bleed_damage_table ~= nil and bleed_armor_grid ~= nil
end

local function bleed_action_entry()
    if not build_bleed_tables() then
        return nil
    end

    local detail_text = mod.interval_effect_general_information_text(BLEED_BUFF_TEMPLATE, BLEED_DAMAGE_PROFILE)

    if not detail_text then
        return nil
    end

    return {
        armor_grid = bleed_armor_grid,
        damage_table = bleed_damage_table,
        detail_text = detail_text,
        display_name = Localize(mod.WAD_LOC.WEAPON_INVENTORY_TRAITS_TITLE_TEXT) .. "•" ..
            Localize(mod.WAD_LOC.TRAIT_BESPOKE_BLEED_ON_ACTIVATED_HIT) .. "/" ..
            Localize(mod.WAD_LOC.TRAIT_BESPOKE_BLEED_ON_NON_WEAKSPOT_HIT),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.blood_drop,
        kind = "interval_buff",
        name = BLEED_BUFF_NAME,
        stack_header = Localize(mod.WAD_LOC.TRAIT_BESPOKE_BLEED_ON_ACTIVATED_HIT),
        damage_header = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_UNARMORED),
        armor_damage_header = Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT),
        is_effect_table = true,
    }
end

function mod.bleed_action_entries(weapon_template_name, is_special_filter)
    if is_special_filter or type(weapon_template_name) ~= "string" or
        not BLEED_WEAPON_TEMPLATES[weapon_template_name] then
        return nil
    end

    local entry = bleed_action_entry()

    return entry and { entry } or nil
end
