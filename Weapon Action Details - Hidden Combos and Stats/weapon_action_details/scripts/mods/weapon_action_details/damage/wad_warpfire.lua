-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_warpfire.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local DamageProfileTemplates = mod:original_require("scripts/settings/damage/damage_profile_templates")
local WeaponBuffTemplates = mod:original_require("scripts/settings/buff/weapon_buff_templates")
local Localize = Localize

local WARPFIRE_ACTION_NAME = "warp_fire"
-- The game hard-codes 500 inside the warp_fire interval callback.
local WARPFIRE_MAX_POWER_LEVEL = 500
local WARPFIRE_BUFF_TEMPLATE = WeaponBuffTemplates and WeaponBuffTemplates.warp_fire
local WARPFIRE_DAMAGE_PROFILE = DamageProfileTemplates and DamageProfileTemplates.warpfire
local warpfire_damage_table
local warpfire_armor_grid

function mod.action_applies_warpfire(action)
    local fire_configuration = type(action) == "table" and action.fire_configuration
    local flamer_gas_template = type(fire_configuration) == "table" and
        fire_configuration.flamer_gas_template

    return type(flamer_gas_template) == "table" and
        flamer_gas_template.dot_buff_name == WARPFIRE_ACTION_NAME
end

function mod.weapon_has_warpfire(actions)
    if type(actions) ~= "table" then
        return false
    end

    for _, action in pairs(actions) do
        if mod.action_applies_warpfire(action) then
            return true
        end
    end

    return false
end

local function warpfire_power_level(stack_count, max_stacks)
    local stack_fraction = stack_count / max_stacks
    local smoothstep_multiplier = stack_fraction * stack_fraction * (3 - 2 * stack_fraction)

    return smoothstep_multiplier * WARPFIRE_MAX_POWER_LEVEL
end

local function build_warpfire_tables()
    if warpfire_damage_table and warpfire_armor_grid then
        return true
    end

    local max_stacks = WARPFIRE_BUFF_TEMPLATE and WARPFIRE_BUFF_TEMPLATE.max_stacks
    local interval = WARPFIRE_BUFF_TEMPLATE and WARPFIRE_BUFF_TEMPLATE.interval

    warpfire_damage_table, warpfire_armor_grid = mod.interval_effect_damage_tables(
        WARPFIRE_ACTION_NAME,
        WARPFIRE_DAMAGE_PROFILE,
        max_stacks,
        interval,
        warpfire_power_level
    )

    return warpfire_damage_table ~= nil and warpfire_armor_grid ~= nil
end

function mod.warpfire_action_entry()
    if not build_warpfire_tables() then
        return nil
    end

    local detail_text = mod.interval_effect_general_information_text(WARPFIRE_BUFF_TEMPLATE, WARPFIRE_DAMAGE_PROFILE)

    if not detail_text then
        return nil
    end

    return {
        armor_grid = warpfire_armor_grid,
        damage_table = warpfire_damage_table,
        detail_text = detail_text,
        display_name = Localize(mod.WAD_LOC.CLASS_PSYKER_NAME) .. "•" ..
            Localize(mod.WAD_LOC.STATS_DISPLAY_BURN_STAT),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.flame,
        kind = "interval_buff",
        name = WARPFIRE_ACTION_NAME,
        stack_header = Localize(mod.WAD_LOC.STATS_DISPLAY_BURN_STAT),
        damage_header = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_UNARMORED),
        armor_damage_header = Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT),
        is_effect_table = true,
    }
end
