-- File: uptime\scripts\mods\uptime\libs\talents.lua
local mod = get_mod("uptime"); if not mod then return end

local ArchetypeTalents = mod:original_require("scripts/settings/ability/archetype_talents/archetype_talents")

local pairs = pairs
local type = type

local TALENT_SUFFIXES = {
    "_stat_buff",
    "_ranged_visual",
    "_melee_visual",
    "_increased",
    "_regen",
    "_buff",
    "_stacks",
    "_stack",
    "_parent",
    "_child",
    "_duration",
    "_proc",
    "_stat",
    "_passive",
    "_ranged",
    "_melee",
    "_visual",
    "_effect",
    "_exhaustion",
    "_improved",
}

local buff_to_talent = {
    veteran_weapon_switch_melee_visual = "veteran_weapon_switch_passive",
    veteran_weapon_switch_ranged_visual = "veteran_weapon_switch_passive",
    veteran_weapon_switch_melee_buff = "veteran_weapon_switch_passive",
    -- this talent has the incorrect related_talent currently
    veteran_improved_tag_allied_buff = "veteran_improved_tag_dead_coherency_bonus",
    veteran_melee_crits_increase_damage = "veteran_crits_apply_rending",

    zealot_stamina_cost_multiplier_aura = "zealot_stamina_cost_multiplier_aura",

    ogryn_ranged_stance = "ogryn_special_ammo",

    broker_punk_rage_stance = "broker_ability_punk_rage",
    broker_punk_rage_exhaustion = "broker_ability_punk_rage",
    broker_punk_rage_ramping_melee_power = "broker_ability_punk_rage_sub_2",
    broker_vultures_mark_dodge_on_ranged_crit_dodge_buff = "broker_keystone_vultures_mark_dodge_on_ranged_crit",
    vultures_mark = "broker_keystone_vultures_mark_on_kill",
    broker_focus_sub_2_damage = "broker_ability_focus_sub_2",
    syringe_broker_buff_stimm_field = "broker_ability_stimm_field",

    cryptic_redline_toughness = "cryptic_redline_toughness",
    cryptic_crits_grant_tdr = "cryptic_crits_grant_tdr",
    cryptic_toughness_on_damage_taken = "cryptic_toughness_on_damage_taken",
}

local talents_by_id = {}
local talents_by_buff_name = {}

if type(ArchetypeTalents) == "table" then
    for _, archetype_talents in pairs(ArchetypeTalents) do
        if type(archetype_talents) == "table" then
            for talent_name, definition in pairs(archetype_talents) do
                if type(talent_name) == "string" and type(definition) == "table" then
                    talents_by_id[talent_name] = definition

                    local passive = definition.passive
                    local coherency = definition.coherency
                    local passive_buff_name = passive and passive.buff_template_name
                    local coherency_buff_name = coherency and coherency.buff_template_name

                    if type(passive_buff_name) == "string" and passive_buff_name ~= "" then
                        talents_by_buff_name[passive_buff_name] = definition
                    end

                    if type(coherency_buff_name) == "string" and coherency_buff_name ~= "" then
                        talents_by_buff_name[coherency_buff_name] = definition
                    end
                end
            end
        end
    end
end

local function strip_talent_suffixes(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local out = value
    local changed = true

    while changed do
        changed = false

        for i = 1, #TALENT_SUFFIXES do
            local suffix = TALENT_SUFFIXES[i]
            local suffix_length = #suffix

            if string.sub(out, -suffix_length) == suffix then
                out = string.sub(out, 1, -suffix_length - 1)
                changed = true
                break
            end
        end
    end

    return out
end

local function get_talent(talent_id)
    if type(talent_id) ~= "string" or talent_id == "" then
        return nil
    end

    return talents_by_id[talent_id]
end

local function get_talent_with_suffix_fallback(talent_id)
    local talent = get_talent(talent_id)

    if talent then
        return talent
    end

    local stripped_talent_id = strip_talent_suffixes(talent_id)

    if stripped_talent_id and stripped_talent_id ~= talent_id then
        return get_talent(stripped_talent_id)
    end

    return nil
end

local function get_related_talent_name(buff)
    if not buff then
        return nil
    end

    local related_talents = buff.related_talents or buff.realted_talents or buff.related_talent

    if type(related_talents) == "table" then
        return related_talents[1]
    elseif type(related_talents) == "string" then
        return related_talents
    end

    return nil
end

local function get_talent_for_buff(buff)
    if not buff then
        return nil
    end

    local buff_name = type(buff.name) == "string" and buff.name or ""
    local talent_id = buff_to_talent[buff_name]

    if talent_id then
        return get_talent(talent_id)
    end

    local talent = talents_by_buff_name[buff_name]

    if talent then
        return talent
    end

    local related_talent_name = get_related_talent_name(buff)

    talent = get_talent_with_suffix_fallback(related_talent_name)

    if talent then
        return talent
    end

    talent = get_talent_with_suffix_fallback(buff_name)

    if talent then
        return talent
    end

    local stripped_buff_name = strip_talent_suffixes(buff_name)

    if stripped_buff_name and stripped_buff_name ~= buff_name then
        return talents_by_buff_name[stripped_buff_name]
    end

    return nil
end

return {
    get_talent = get_talent,
    get_talent_for_buff = get_talent_for_buff,
}
