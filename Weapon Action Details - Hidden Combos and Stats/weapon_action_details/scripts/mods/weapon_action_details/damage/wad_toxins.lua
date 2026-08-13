-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_toxins.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local BuffSettings = mod:original_require("scripts/settings/buff/buff_settings")
local DamageProfileTemplates = mod:original_require("scripts/settings/damage/damage_profile_templates")
local ExplosionTemplates = mod:original_require("scripts/settings/damage/explosion_templates")
local WeaponBuffTemplates = mod:original_require("scripts/settings/buff/weapon_buff_templates")
local Localize = Localize

local RENDING_MULTIPLIER = BuffSettings.stat_buffs.rending_multiplier
local NEUROTOXIN_BUFF_NAME = "neurotoxin_interval_buff3"
local NEUROTOXIN_DAMAGE_PROFILE_NAME = "toxin_variant_3"
local NEUROTOXIN_MAX_POWER_LEVEL = 500
local NEUROTOXIN_BUFF_TEMPLATE = WeaponBuffTemplates and WeaponBuffTemplates[NEUROTOXIN_BUFF_NAME]
local NEUROTOXIN_DAMAGE_PROFILE = DamageProfileTemplates and DamageProfileTemplates[NEUROTOXIN_DAMAGE_PROFILE_NAME]
local SAW_RENDING_BUFF_TEMPLATE = WeaponBuffTemplates and WeaponBuffTemplates.saw_rending_debuff
local TOXIN_DEATH_EXPLOSION_TEMPLATE = WeaponBuffTemplates and WeaponBuffTemplates.toxin_death_explosion
local TOXIN_DEATH_GAS_TEMPLATE = WeaponBuffTemplates and WeaponBuffTemplates.toxin_death_explosion_gas

local WEAPON_TOXIN_DATA = {
    needlepistol_p1_m1 = {
        special_death_effect = "explosion",
    },
    needlepistol_p1_m2 = {
        special_death_effect = "gas",
    },
    saw_p1_m1 = {
        special_replaces_neurotoxin = true,
    },
}

local neurotoxin_damage_table
local neurotoxin_armor_grid

local function neurotoxin_power_level(stack_count, max_stacks)
    return stack_count / max_stacks * NEUROTOXIN_MAX_POWER_LEVEL
end

local function build_neurotoxin_tables()
    if neurotoxin_damage_table and neurotoxin_armor_grid then
        return true
    end

    local max_stacks = NEUROTOXIN_BUFF_TEMPLATE and NEUROTOXIN_BUFF_TEMPLATE.max_stacks
    local interval = NEUROTOXIN_BUFF_TEMPLATE and NEUROTOXIN_BUFF_TEMPLATE.interval

    neurotoxin_damage_table, neurotoxin_armor_grid = mod.interval_effect_damage_tables(
        NEUROTOXIN_DAMAGE_PROFILE_NAME,
        NEUROTOXIN_DAMAGE_PROFILE,
        max_stacks,
        interval,
        neurotoxin_power_level
    )

    return neurotoxin_damage_table ~= nil and neurotoxin_armor_grid ~= nil
end

local function neurotoxin_action_entry()
    if not build_neurotoxin_tables() then
        return nil
    end

    local detail_text = mod.interval_effect_general_information_text(
        NEUROTOXIN_BUFF_TEMPLATE,
        NEUROTOXIN_DAMAGE_PROFILE
    )

    if not detail_text then
        return nil
    end

    return {
        armor_grid = neurotoxin_armor_grid,
        damage_table = neurotoxin_damage_table,
        detail_text = detail_text,
        display_name = Localize(mod.WAD_LOC.TERM_GLOSSARY_BROKER_TOXIN) .. "•" ..
            Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.skull,
        kind = "interval_buff",
        name = NEUROTOXIN_BUFF_NAME,
        stack_header = Localize(mod.WAD_LOC.TERM_GLOSSARY_BROKER_TOXIN),
        damage_header = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_UNARMORED),
        armor_damage_header = Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT),
        is_effect_table = true,
    }
end

local function death_effect_detail_text(buff_template, explosion_template)
    local duration = buff_template and buff_template.duration
    local radius = explosion_template and explosion_template.radius

    if type(duration) ~= "number" or type(radius) ~= "number" then
        return nil
    end

    local text = string.format("%s: %gs  %s: %gm",
        Localize(mod.WAD_LOC.INTERFACE_SETTING_CHAT_BUBBLES_LIFETIME_MULTIPLIER), duration,
        Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_RADIUS), radius)
    local close_radius = explosion_template.close_radius

    if type(close_radius) == "number" then
        text = text .. string.format("  %s: %gm", Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_INNER_BLAST_RADIUS),
            close_radius)
    end

    return text
end

local function toxin_death_explosion_entry()
    local explosion_template = ExplosionTemplates and ExplosionTemplates.primer_explosion
    local detail_text = death_effect_detail_text(TOXIN_DEATH_EXPLOSION_TEMPLATE, explosion_template)

    if not detail_text then
        return nil
    end

    return {
        damage_text = mod:localize("toxin_death_explosion_description"),
        detail_text = detail_text,
        display_name = Localize(mod.WAD_LOC.TERM_GLOSSARY_BROKER_TOXIN) .. "•" .. mod:localize("death_explosion"),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.skull,
        kind = "proc_buff",
        name = "toxin_death_explosion",
    }
end

local function toxin_death_gas_entry()
    local explosion_template = ExplosionTemplates and ExplosionTemplates.primer_gas
    local detail_text = death_effect_detail_text(TOXIN_DEATH_GAS_TEMPLATE, explosion_template)

    if not detail_text then
        return nil
    end

    local damaging_toxin_name = Localize(mod.WAD_LOC.TERM_GLOSSARY_BROKER_TOXIN) .. "•" ..
        Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT)

    return {
        damage_text = mod:localize("toxin_death_gas_description", damaging_toxin_name),
        detail_text = detail_text,
        display_name = Localize(mod.WAD_LOC.TERM_GLOSSARY_BROKER_TOXIN) .. "•" .. mod:localize("gas_death_burst"),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.skull,
        kind = "proc_buff",
        name = "toxin_death_explosion_gas",
    }
end

local function saw_brittleness_entry()
    local duration = SAW_RENDING_BUFF_TEMPLATE and SAW_RENDING_BUFF_TEMPLATE.duration
    local max_stacks = SAW_RENDING_BUFF_TEMPLATE and SAW_RENDING_BUFF_TEMPLATE.max_stacks
    local stat_buffs = SAW_RENDING_BUFF_TEMPLATE and SAW_RENDING_BUFF_TEMPLATE.stat_buffs
    local rending_value = stat_buffs and stat_buffs[RENDING_MULTIPLIER]

    if type(duration) ~= "number" or type(max_stacks) ~= "number" or type(rending_value) ~= "number" then
        return nil
    end

    local maximum_rending = rending_value * max_stacks

    return {
        damage_text = string.format("%s: %.1f%%  %s: %d (%.1f%%)",
            mod:localize("brittleness_per_stack"), rending_value * 100,
            Localize(mod.WAD_LOC.EXPERTISE_CRAFTING_MODIFIERS_MAX), max_stacks, maximum_rending * 100),
        detail_text = string.format("%s: %gs",
            Localize(mod.WAD_LOC.INTERFACE_SETTING_CHAT_BUBBLES_LIFETIME_MULTIPLIER), duration),
        display_name = Localize(mod.WAD_LOC.TERM_GLOSSARY_BROKER_TOXIN) .. "•" ..
            Localize(mod.WAD_LOC.TRAIT_BESPOKE_REND_ARMOR_ON_CHARGED_SHOTS),
        icon = mod.PRESET_ICON_MATERIALS and mod.PRESET_ICON_MATERIALS.skull,
        kind = "buff",
        name = "saw_rending_debuff",
    }
end

function mod.toxin_action_entries(weapon_template_name, is_special_filter)
    local weapon_data = type(weapon_template_name) == "string" and WEAPON_TOXIN_DATA[weapon_template_name]

    if not weapon_data then
        return nil
    end

    local entries = {}

    if not is_special_filter then
        local neurotoxin_entry = neurotoxin_action_entry()

        if neurotoxin_entry then
            entries[#entries + 1] = neurotoxin_entry
        end

        return entries
    end

    if weapon_data.special_replaces_neurotoxin then
        local brittleness_entry = saw_brittleness_entry()

        if brittleness_entry then
            entries[#entries + 1] = brittleness_entry
        end

        return entries
    end

    local neurotoxin_entry = neurotoxin_action_entry()

    if neurotoxin_entry then
        entries[#entries + 1] = neurotoxin_entry
    end

    local death_effect_entry = weapon_data.special_death_effect == "explosion" and
        toxin_death_explosion_entry() or weapon_data.special_death_effect == "gas" and
        toxin_death_gas_entry()

    if death_effect_entry then
        entries[#entries + 1] = death_effect_entry
    end

    return entries
end
