local mod = get_mod("uptime")
local psyker_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/psyker_talents")
local ogryn_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/ogryn_talents")
local zealot_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/zealot_talents")
local veteran_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/veteran_talents")
local arbites_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/adamant_talents")
local scum_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/broker_talents")
local ArchetypeTalents = require("scripts/settings/ability/archetype_talents/archetype_talents")
local all_trees = {
    psyker_talents, ogryn_talents, zealot_talents, veteran_talents, arbites_talents, scum_talents
}

local buff_to_talent = {
    adamant_terminus_warrant_ranged = "adamant_terminus_warrant",
    adamant_terminus_warrant_melee = "adamant_terminus_warrant",
    adamant_forceful_stacks = "adamant_forceful",

    veteran_weapon_switch_melee_visual = "veteran_weapon_switch_passive",
    veteran_weapon_switch_ranged_visual = "veteran_weapon_switch_passive",
    veteran_weapon_switch_melee_buff = "veteran_weapon_switch_passive",
    veteran_snipers_focus_stat_buff_increased_stacks = "veteran_snipers_focus",
    veteran_snipers_focus_stat_buff = "veteran_snipers_focus",
    -- this talent has the incorrect related_talent currently
    veteran_improved_tag_allied_buff = "veteran_improved_tag_dead_coherency_bonus",

    psyker_toughness_on_melee_buff = "psyker_toughness_on_melee",

    broker_punk_rage_stance = "broker_ability_punk_rage",
    broker_punk_rage_exhaustion = "broker_ability_punk_rage",
    broker_punk_rage_ramping_melee_power = "broker_ability_punk_rage_sub_2",
    broker_keystone_adrenaline_junkie_proc = "broker_keystone_adrenaline_junkie",
    broker_keystone_adrenaline_junkie_stack = "broker_keystone_adrenaline_junkie",
    broker_passive_melee_cleave_on_melee_kill_buff = "broker_passive_melee_cleave_on_melee_kill",
    broker_passive_replenish_toughness_on_ranged_toughness_damage_regen = "broker_passive_replenish_toughness_on_ranged_toughness_damage",
    broker_keystone_chemical_dependency_stack = "broker_keystone_chemical_dependency",
    broker_passive_damage_on_reload_buff = "broker_passive_damage_on_reload",
    broker_vultures_mark_dodge_on_ranged_crit_dodge_buff = "broker_keystone_vultures_mark_dodge_on_ranged_crit",
    vultures_mark = "broker_keystone_vultures_mark_on_kill",
    broker_focus_sub_2_damage = "broker_ability_focus_sub_2",
    syringe_broker_buff_stimm_field = "broker_ability_stimm_field"
}

function get_talent(talent_id)
    for _, tree in pairs(all_trees) do
        if tree.talents[talent_id] then
            return tree.talents[talent_id]
        end
    end
    return nil
end

function get_talent_for_buff(buff)
    local buff_name = buff.name or ""
    if buff_to_talent[buff_name] then
        local talent_id = buff_to_talent[buff_name]
        return get_talent(talent_id)
    end
    for player_archetype, archetype_talents in pairs(ArchetypeTalents) do
        for talent_name, definition in pairs(archetype_talents) do
            local talent_buff_passive_template_name = definition.passive and definition.passive.buff_template_name
            local talent_buff_coherency_template_name = definition.coherency and definition.coherency.buff_template_name

            local related_talent_name = buff.related_talents and buff.related_talents[1]
            if talent_buff_passive_template_name == buff_name or talent_buff_coherency_template_name == buff_name or talent_name == related_talent_name then
                return definition
            end
        end
    end

end

return {
    get_talent = get_talent,
    get_talent_for_buff = get_talent_for_buff,
}