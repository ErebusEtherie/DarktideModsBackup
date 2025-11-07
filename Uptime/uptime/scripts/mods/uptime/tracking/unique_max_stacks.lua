local mod = get_mod("uptime")
local TalentSettings = mod:original_require("scripts/settings/talent/talent_settings")

local max_stacks = {
    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/settings/buff/archetype_buff_templates/ogryn_buff_templates.lua
    ogryn_reduce_damage_taken_per_bleed = TalentSettings.ogryn_2.defensive_1.max_stacks,
    ogryn_hitting_multiple_with_melee_grants_melee_damage_bonus = TalentSettings.ogryn_2.offensive_2_3.max_targets,

    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/settings/buff/archetype_buff_templates/psyker_buff_templates.lua
    psyker_overcharge_stance = TalentSettings.psyker.overcharge_stance.max_stacks,
    psyker_nearby_soulblaze_reduced_damage = TalentSettings.psyker.nearby_soublaze_defense.max_stacks,

    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/bb5ee8f4309f1bc9bf9327d2ef59a088ca1aa5d4/scripts/settings/buff/archetype_buff_templates/zealot_buff_templates.lua#L606
    zealot_martyrdom_base = TalentSettings.zealot_2.passive_1.martyrdom_max_stacks,

    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/bb5ee8f4309f1bc9bf9327d2ef59a088ca1aa5d4/scripts/settings/buff/archetype_buff_templates/zealot_buff_templates.lua#L3002C1-L3003C1
    zealot_offensive_vs_many = TalentSettings.zealot.zealot_offensive_vs_many.max_stack,

    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/bb5ee8f4309f1bc9bf9327d2ef59a088ca1aa5d4/scripts/settings/buff/archetype_buff_templates/zealot_buff_templates.lua#L1544
    zealot_toughness_regen_in_melee = 6,

    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/bb5ee8f4309f1bc9bf9327d2ef59a088ca1aa5d4/scripts/settings/buff/archetype_buff_templates/zealot_buff_templates.lua#L1137
    zealot_preacher_melee_increase_next_melee_proc = TalentSettings.zealot_3.zealot_preacher_melee_increase_next_melee_proc,

    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/bb5ee8f4309f1bc9bf9327d2ef59a088ca1aa5d4/scripts/settings/ability/archetype_talents/talents/veteran_talents.lua#L2956
    veteran_improved_tag = TalentSettings.veteran.veteran_tag.max_stacks
}

return max_stacks