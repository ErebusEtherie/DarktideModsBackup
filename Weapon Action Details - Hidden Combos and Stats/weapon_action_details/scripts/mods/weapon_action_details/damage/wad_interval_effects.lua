-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_interval_effects.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")
local Localize = Localize

local ARMOR_TYPES = ArmorSettings.types
local EMPTY_ACTION = {}
local INTERVAL_EFFECT_ARMOR_ORDER = {
    ARMOR_TYPES.armored,
    ARMOR_TYPES.resistant,
    ARMOR_TYPES.berserker,
    ARMOR_TYPES.super_armor,
    ARMOR_TYPES.disgustingly_resilient,
}
local ARMOR_LOCALIZATION_KEYS = {
    [ARMOR_TYPES.armored] = mod.WAD_LOC.WEAPON_STATS_DISPLAY_ARMORED,
    [ARMOR_TYPES.berserker] = mod.WAD_LOC.WEAPON_STATS_DISPLAY_BERZERKER,
    [ARMOR_TYPES.disgustingly_resilient] = mod.WAD_LOC.WEAPON_STATS_DISPLAY_DISGUSTINGLY_RESILIENT,
    [ARMOR_TYPES.resistant] = mod.WAD_LOC.GLOSSARY_ARMOUR_TYPE_RESISTANT,
    [ARMOR_TYPES.super_armor] = mod.WAD_LOC.WEAPON_STATS_DISPLAY_SUPER_ARMOR,
}

local function interval_effect_damage_values(action_name, damage_profile, power_level)
    if type(action_name) ~= "string" or type(damage_profile) ~= "table" or type(power_level) ~= "number" then
        return nil
    end

    local previous_hit_zone = mod.wad_damage_hit_zone

    mod.wad_damage_hit_zone = mod.WAD_DAMAGE_HIT_ZONE_BODY

    local attack_values = mod.calculate_damage_profile_hit_zone_values(
        action_name,
        EMPTY_ACTION,
        damage_profile,
        power_level,
        nil,
        nil,
        false
    )

    mod.wad_damage_hit_zone = previous_hit_zone

    return attack_values
end

function mod.interval_effect_damage_tables(action_name, damage_profile, max_stacks, damage_interval, power_level_func,
                                           power_level_max_stacks)
    if type(action_name) ~= "string" or type(damage_profile) ~= "table" or
        type(max_stacks) ~= "number" or max_stacks < 1 or type(damage_interval) ~= "number" or
        damage_interval <= 0 or type(power_level_func) ~= "function" then
        return nil, nil
    end

    local damage_table = {}
    local max_stack_damage_values

    for stack_count = 1, max_stacks do
        local power_level = power_level_func(stack_count, power_level_max_stacks or max_stacks)
        local damage_values = interval_effect_damage_values(action_name, damage_profile, power_level)
        local unarmored_damage = damage_values and damage_values[ARMOR_TYPES.unarmored]

        if type(unarmored_damage) ~= "number" then
            return nil, nil
        end

        damage_table[stack_count] = {
            label = tostring(stack_count),
            value = string.format("%s%s %.0f / %gs%s", mod.WAD_DAMAGE_TEXT_COLOR, mod.WAD_DAMAGE_GLYPH,
                unarmored_damage, damage_interval, mod.WAD_RICH_TEXT_RESET),
        }
        max_stack_damage_values = damage_values
    end

    local unarmored_damage = max_stack_damage_values and max_stack_damage_values[ARMOR_TYPES.unarmored]

    if type(unarmored_damage) ~= "number" or unarmored_damage <= 0 then
        return nil, nil
    end

    local armor_grid = {}

    for i = 1, #INTERVAL_EFFECT_ARMOR_ORDER do
        local armor_type = INTERVAL_EFFECT_ARMOR_ORDER[i]
        local armor_damage = max_stack_damage_values[armor_type]

        if type(armor_damage) == "number" then
            local armor_localization_key = ARMOR_LOCALIZATION_KEYS[armor_type]

            armor_grid[#armor_grid + 1] = {
                armor_type = armor_type,
                label = armor_localization_key and Localize(armor_localization_key) or tostring(armor_type),
                base_values = string.format("%s%s %.0f%%%s", mod.WAD_DAMAGE_TEXT_COLOR, mod.WAD_DAMAGE_GLYPH,
                    armor_damage / unarmored_damage * 100, mod.WAD_RICH_TEXT_RESET),
            }
        end
    end

    return damage_table, armor_grid
end

function mod.interval_effect_general_information_text(buff_template, damage_profile, max_stacks_override)
    if type(buff_template) ~= "table" then
        return nil
    end

    local duration = buff_template.duration
    local max_stacks = max_stacks_override or buff_template.max_stacks_cap or buff_template.max_stacks

    if type(duration) ~= "number" or type(max_stacks) ~= "number" then
        return nil
    end

    local parts = {
        string.format("%s: %gs",
            Localize(mod.WAD_LOC.INTERFACE_SETTING_CHAT_BUBBLES_LIFETIME_MULTIPLIER), duration),
        string.format("%s: %d",
            Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_MAX_BURN_STACKS), max_stacks),
    }

    if type(damage_profile) == "table" and damage_profile.ignore_shield == true then
        parts[#parts + 1] = string.format("%s%s %s%s",
            mod.WAD_DAMAGE_TEXT_COLOR,
            mod.WAD_DAMAGE_GLYPH,
            mod:localize("ignore_shield"),
            mod.WAD_RICH_TEXT_RESET)
    end

    return table.concat(parts, "  ")
end
