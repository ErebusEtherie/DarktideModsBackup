-- Keep selection policy identical in the editor, local validator and host validator.
local Rules = {}

-- Audited independent keystone/modifier effects, including the Zealot's
-- cooldown and Broker's dodge choices. Never relax the whole node type.
-- mark_1 also needs the per-instance duration bridge in talent_effects.lua.
local compatible_keystone_upgrades = {
	psyker_mark_increased_max_stacks = "mark_1",
	psyker_mark_increased_duration = "mark_1",
	psyker_reduced_warp_charge_cost_and_venting_speed = "soul_1",
	psyker_toughness_on_soul = "soul_1",
	psyker_warpfire_generate_souls = "soul_2",
	psyker_aura_souls_on_kill = "soul_2",
	psyker_empowered_grenades_passive_improved = "emp_1",
	psyker_empowered_ability_on_elite_kills = "emp_1",
	ogryn_leadbelcher_crits = "blo_1",
	ogryn_blo_melee = "blo_1",
	ogryn_blo_ally_ranged_buffs = "blo_2",
	ogryn_blo_wield_speed = "blo_2",
	ogryn_heavy_hitter_tdr = "hh_1",
	ogryn_heavy_hitter_max_stacks_improves_toughness = "hh_1",
	ogryn_heavy_hitter_cleave = "hh_2",
	ogryn_heavy_hitter_stagger = "hh_2",
	zealot_restore_stealth_cd_on_damage = "cdr_1",
	zealot_backstab_kills_restore_cd = "cdr_1",
	zealot_crits_grant_cd = "cdr_1",
	broker_passive_improved_dodges = "dodge_upgrade",
	broker_passive_longer_dodges = "dodge_upgrade",
	cryptic_chordclaw_capacitance_restoration = "chordclaw_2",
	cryptic_chordclaw_consecutive_bonus = "chordclaw_2",
}

-- Audited skill modifiers, with dog_1 using native keystone icons. Match the
-- talent ID and original group/type; do not relax ability or Blitz slots.
local compatible_skill_upgrades = {
	veteran_combat_ability_ranged_roamer_outlines = "stance_1",
	veteran_combat_ability_ogryn_outlines = "stance_1",
	zealot_channel_grants_toughness_damage_reduction = "prayer_1",
	zealot_channel_grants_damage = "prayer_1",
	psyker_discharge_damage_debuff = "shout_1",
	psyker_warpfire_on_shout = "shout_1",
	psyker_overcharge_weakspot_kill_bonuses = "stance_1",
	psyker_overcharge_reduced_warp_charge = "stance_1",
	ogryn_charge_applies_bleed = "ogryn_charge_2",
	ogryn_charge_trample = "ogryn_charge_2",
	ogryn_taunt_staggers_reduce_cooldown = "taunt_1",
	ogryn_taunt_damage_taken_increase = "taunt_1",
	ogryn_special_ammo_armor_pen = "speshul_modifiers",
	ogryn_special_ammo_fire_shots = "speshul_modifiers",
	adamant_companion_focus_ranged = "dog_1",
	adamant_companion_focus_elite = "dog_1",
}

-- Exact native nodes whose sole incompatibility is the missing companion.
-- Keep their other restrictions unless explicitly allowed above.
local companion_nodes = {
	adamant_companion_coherency = "aura",
	adamant_whistle = "tactical",
	adamant_toughness_regen_near_companion = "default",
	adamant_dog_attacks_electrocute = "default",
	adamant_dog_pounces_bleed_nearby = "default",
	adamant_stance_dog_bloodlust = "ability_modifier",
	adamant_dog_applies_brittleness = "default",
	adamant_dog_damage_after_ability = "ability_modifier",
	adamant_pinning_dog_bonus_moving_towards = "keystone_modifier",
	adamant_companion_focus_ranged = "keystone",
	adamant_companion_focus_elite = "keystone",
	adamant_pinning_dog_elite_damage = "default",
	adamant_pinning_dog_kills_buff_allies = "default",
}

function Rules.incompatible_talent(node, rules)
	local incompatible = node.requirements and node.requirements.incompatible_talent
	if rules and rules.unlock_all_keystones == true
		and incompatible == "adamant_disable_companion" and companion_nodes[node.talent] == node.type then
		return nil
	end
	return incompatible
end

function Rules.keep_companion(talents)
	if not talents or not talents.adamant_disable_companion then return false end
	for talent in pairs(companion_nodes) do
		if talents[talent] then return true end
	end
	return false
end

-- Native Stimm Lab stat/keyword/proc branches. These do not replace weapons,
-- actions or ability forms. Require both the private specialization policy and
-- exact native talent/group/type, leaving ordinary trees and future nodes alone.
local compatible_stimm_nodes = {
	broker_stimm_combat_4a = "combat_1", broker_stimm_combat_4b = "combat_1", broker_stimm_combat_4c = "combat_1",
	broker_stimm_combat_5a = "combat_2", broker_stimm_combat_5b = "combat_2", broker_stimm_combat_5c = "combat_2",
	broker_stimm_durability_5a = "durability", broker_stimm_durability_5b = "durability",
	broker_stimm_concentration_5a = "concentration", broker_stimm_concentration_5b = "concentration", broker_stimm_concentration_5c = "concentration",
	broker_stimm_celerity_5a = "celerity", broker_stimm_celerity_5b = "celerity", broker_stimm_celerity_5c = "celerity",
}

function Rules.exclusive_group(node, rules)
	local group = node.requirements and node.requirements.exclusive_group
	if rules and rules.rl_unlock_stimm == true and node.type == "broker_stimm"
		and group ~= nil and compatible_stimm_nodes[node.talent] == group then return nil end
	-- Arbites also uses the keystone icon for companion branches (dog_1).
	-- Only the actual aura/keystone choice groups are relaxed.
	if rules and ((node.type == "aura" and (group == "aura" or group == "aura_1") and rules.unlock_all_auras == true)
		or (node.type == "keystone" and (group == "keystone" or group == "keystone_1") and rules.unlock_all_keystones == true)) then
		return nil
	end
	local compatible_type = node.type == "keystone_modifier"
		or (node.type == "ability_modifier" and group == "chordclaw_2")
	if rules and rules.unlock_all_keystones == true and compatible_type
		and group ~= nil and compatible_keystone_upgrades[node.talent] == group then
		return nil
	end
	if rules and rules.unlock_all_keystones == true and group ~= nil
		and compatible_skill_upgrades[node.talent] == group
		and node.type == (group == "dog_1" and "keystone" or "ability_modifier") then
		return nil
	end
	return group
end

function Rules.configure_layout(layout, original, rules)
	local originals = {}
	for _, node in ipairs(original.nodes) do
		originals[node.widget_name] = node
	end
	for _, node in ipairs(layout.nodes) do
		local source = originals[node.widget_name]
		if source then
			node.requirements = node.requirements or {}
			node.requirements.exclusive_group = Rules.exclusive_group(source, rules)
			node.requirements.incompatible_talent = Rules.incompatible_talent(source, rules)
		end
	end
	return layout
end

function Rules.copy_layout(original, rules)
	return Rules.configure_layout(table.clone_instance(original), original, rules)
end

return Rules
