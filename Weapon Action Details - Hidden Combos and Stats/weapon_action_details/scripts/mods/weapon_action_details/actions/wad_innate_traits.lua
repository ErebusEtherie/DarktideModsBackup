-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_innate_traits.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local BuffSettings = mod:original_require("scripts/settings/buff/buff_settings")
local WeaponBuffTemplates = mod:original_require("scripts/settings/buff/weapon_buff_templates")
local WeaponTemplates = mod:original_require("scripts/settings/equipment/weapon_templates/weapon_templates")
local Localize = Localize

local MELEE_POWER_LEVEL_MODIFIER = BuffSettings.stat_buffs.melee_power_level_modifier

local function percentage_text(value)
    local percentage = value * 100
    local rounded_percentage = math.floor(percentage + 0.5)

    if math.abs(percentage - rounded_percentage) < 0.001 then
        return string.format("%d%%", rounded_percentage)
    end

    return string.format("%.1f%%", percentage)
end

local function windup_power_entry(parent_buff_name, title_localization_key, fallback_icon_name)
    local parent_template = WeaponBuffTemplates and WeaponBuffTemplates[parent_buff_name]
    local child_buff_name = parent_template and parent_template.child_buff_template
    local child_template = child_buff_name and WeaponBuffTemplates[child_buff_name]
    local conditional_stat_buffs = child_template and child_template.conditional_stat_buffs
    local power_level_modifier = conditional_stat_buffs and
        conditional_stat_buffs[MELEE_POWER_LEVEL_MODIFIER]
    local max_stacks = parent_template and parent_template.max_stacks

    if type(power_level_modifier) ~= "number" or type(max_stacks) ~= "number" then
        return nil
    end

    local description = Localize(
        mod.WAD_LOC.TRAIT_BESPOKE_POWER_BONUS_BASED_ON_CHARGE_TIME_DESC,
        true,
        {
            power_level = percentage_text(power_level_modifier),
            stacks = tostring(max_stacks),
        }
    )

    return {
        detail_text = description,
        display_name = Localize(title_localization_key),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS[fallback_icon_name],
        kind = parent_template.class_name or "weapon_trait_parent_proc_buff",
        name = parent_buff_name,
    }
end

local function windup_increases_power_entry()
    return windup_power_entry(
        "windup_increases_power_default_parent",
        mod.WAD_LOC.WEAPON_KEYWORD_HEAVY_WINDUP,
        "crossed_swords"
    )
end

local function windup_increases_special_power_entry()
    return windup_power_entry(
        "windup_increases_special_power_default_parent",
        mod.WAD_LOC.WEAPON_KEYWORD_HEAVY_SPECIAL_WINDUP,
        "crossed_swords"
    )
end

local function melee_power_bonus_scaled_on_special_charges_entry(weapon_template_name)
    local buff_name = "melee_power_bonus_scaled_on_special_charges"
    local buff_template = WeaponBuffTemplates and WeaponBuffTemplates[buff_name]
    local power_level_modifier_per_charge = buff_template and
        buff_template.melee_power_level_modifier_per_charge
    local weapon_template = WeaponTemplates and WeaponTemplates[weapon_template_name]
    local weapon_special_tweak_data = weapon_template and weapon_template.weapon_special_tweak_data
    local max_charges = weapon_special_tweak_data and
        (weapon_special_tweak_data.max_num_charges or weapon_special_tweak_data.max_charges)

    if type(power_level_modifier_per_charge) ~= "number" or type(max_charges) ~= "number" then
        return nil
    end

    local description = Localize(
        mod.WAD_LOC.WEAPON_KEYWORD_MELEE_POWER_BONUS_SCALED_ON_SPECIAL_CHARGES_MOUSEOVER
    )
    local per_charge_text = string.format("%s / %s",
        percentage_text(power_level_modifier_per_charge),
        Localize(mod.WAD_LOC.GLOSSARY_TERM_CHARGE))
    local maximum_charges_text = string.format("%s: %d",
        Localize(mod.WAD_LOC.EXPERTISE_CRAFTING_MODIFIERS_MAX),
        max_charges)

    return {
        detail_text = string.format("%s  %s  %s", description, per_charge_text, maximum_charges_text),
        display_name = Localize(mod.WAD_LOC.WEAPON_KEYWORD_MELEE_POWER_BONUS_SCALED_ON_SPECIAL_CHARGES),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.lightning,
        kind = buff_template.class_name or "buff",
        name = buff_name,
    }
end

local INNATE_TRAIT_ENTRY_BUILDERS_BY_WEAPON_TEMPLATE = {
    crowbar_p1_m1 = {
        windup_increases_power_entry,
    },
    powersword_p3_m1 = {
        windup_increases_special_power_entry,
        melee_power_bonus_scaled_on_special_charges_entry,
    },
}

function mod.innate_trait_action_entries(weapon_template_name, is_special_filter)
    if is_special_filter or type(weapon_template_name) ~= "string" then
        return nil
    end

    local builders = INNATE_TRAIT_ENTRY_BUILDERS_BY_WEAPON_TEMPLATE[weapon_template_name]

    if not builders then
        return nil
    end

    local entries = {}

    for i = 1, #builders do
        local entry = builders[i](weapon_template_name)

        if entry then
            entries[#entries + 1] = entry
        end
    end

    return #entries > 0 and entries or nil
end
