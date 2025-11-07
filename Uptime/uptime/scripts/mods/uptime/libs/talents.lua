local mod = get_mod("uptime")
local psyker_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/psyker_talents")
local ogryn_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/ogryn_talents")
local zealot_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/zealot_talents")
local veteran_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/veteran_talents")
local arbites_talents = mod:original_require("scripts/settings/ability/archetype_talents/talents/adamant_talents")
local ArchetypeTalents = require("scripts/settings/ability/archetype_talents/archetype_talents")
local all_trees = {
    psyker_talents, ogryn_talents, zealot_talents, veteran_talents, arbites_talents
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

    psyker_toughness_on_melee_buff = "psyker_toughness_on_melee"
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
    local related_talent_name = buff.related_talents and buff.related_talents[1]
    local buff_name = buff.name or ""
    if buff_to_talent[buff_name] then
        local talent_id = buff_to_talent[buff_name]
        return get_talent(talent_id)
    end
    for player_archetype, archetype_talents in pairs(ArchetypeTalents) do
        for talent_name, definition in pairs(archetype_talents) do
            local talent_buff_passive_template_name = definition.passive and definition.passive.buff_template_name
            local talent_buff_coherency_template_name = definition.coherency and definition.coherency.buff_template_name

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