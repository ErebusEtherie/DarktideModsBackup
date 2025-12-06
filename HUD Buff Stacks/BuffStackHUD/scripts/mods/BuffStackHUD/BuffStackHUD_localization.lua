local mod = get_mod("BuffStackHUD")
local BuffTemplates = require("scripts/settings/buff/buff_templates")

mod.buff_names = {}
mod.buff_max = 6

local loc = {
	mod_name = {
		en = "HUD Buff Stacks",
	},
	mod_description = {
		en = "Show a timer and stack of various stackable buffs on the HUD.",
	},
	enable = {
		en = "Enabled"
	},
	showlabel = {
		en = "Show Label"
	},
	color = {
		en = "Color"
	},
	lock_slot_group = {
		en = "Lock Slots"
	},
	hud_element_settings_group = {
		en = "HUD Appearance"
	},
	stack_font_size = {
		en = "Stack Number Size"
	},
	label_font_size = {
		en = "Buff Name Size"
	},
	chaos_beast_of_nurgle_hit_by_vomit = {
		en = "Beast of Nurgle Vomit"
	},
	fire_burninating = {
		en = "Burning"
	},
	flamer_assault = {
		en = "Burning (Flamer)"
	},
	ogryn_big_bully_heavy_hits_buff = {
		en = Localize("loc_talent_ogryn_big_bully_heavy_hits")
	},
	ogryn_charge_trample_buff = {
		en = Localize("loc_talent_ogryn_ability_charge_trample")
	},
	ogryn_crit_chance_on_kill_effect = {
		en = Localize("loc_talent_ogryn_crit_chance_on_kill")
	},
	ogryn_heavy_hitter_damage_effect = {
		en = Localize("loc_talent_ogryn_heavy_hitter_max_stacks_improves_toughness")
	},
	ogryn_blo_stacking_buff = {
		en = Localize("loc_talent_ogryn_chance_to_not_consume_ammo")
	},
	ogryn_block_increases_power_active_buff = {
		en = Localize("loc_talent_ogryn_block_increases_power_name")
	},
	ogryn_damage_taken_by_all_increases_strength_tdr_buff = {
		en = Localize("loc_talent_ogryn_damage_taken_by_all_increases_strength_tdr")
	},
	ogryn_melee_improves_ranged_stacking_buff = {
		en = Localize("loc_talent_ogryn_melee_improves_ranged")
	},
	ogryn_stacking_attack_speed_active_buff = {
		en = Localize("loc_talent_ogryn_stacking_attack_speed_name")
	},
	ogryn_taunt_restore_toughness_over_time = {
		en = Localize("loc_talent_ogryn_taunt_restore_toughness")
	},
	psyker_crits_empower_warp_buff = {
		en = Localize("loc_talent_psyker_crits_empower_next_attack")
	},
	psyker_cycle_stacking_non_warp_damage = {
		en = Localize("loc_talent_psyker_kills_stack_other_weapon_damage") .. " (Nonwrap)"
	},
	psyker_cycle_stacking_warp_damage = {
		en = Localize("loc_talent_psyker_kills_stack_other_weapon_damage") .. " (Wrap)"
	},
	psyker_force_staff_quick_attack_debuff = {
		en = Localize("loc_talent_psyker_force_staff_quick_attack_bonus")
	},
	psyker_overcharge_stance_damage = {
		en = Localize("loc_talent_psyker_combat_ability_overcharge_stance")
	},
	psyker_overcharge_stance_finesse_damage = {
		en = Localize("loc_ability_psyker_overcharge_weakspot")
	},
	psyker_shout_warp_generation_reduction = {
		en = Localize("loc_talent_psyker_shout_reduces_warp_charge_generation")
	},
	psyker_stacking_movement_buff = {
		en = Localize("loc_talent_psyker_crits_regen_tougness_and_movement_speed")
	},
	psyker_throwing_knife_stacking_speed_buff = {
		en = Localize("loc_talent_psyker_throwing_knives_reduced_cooldown")
	},
	veteran_damage_after_sprinting_buff = {
		en = Localize("loc_talent_veteran_damage_damage_after_sprinting")
	},
	veteran_dodging_crit_buff = {
		en = Localize("loc_talent_veteran_dodging_grants_crit")
	},
	veteran_ranged_weakspot_toughenss_buff = {
		en = Localize("loc_talent_veteran_toughness_on_weakspot_kill")
	},
	veteran_weapon_switch_ranged_buff = {
		en = Localize("loc_talent_veteran_weapon_switch")
	},
	zealot_bleeding_crits_effect = {
		en = Localize("loc_talent_zealot_bleed_melee_crit_chance")
	},
	zealot_channel_toughness_bonus = {
		en = Localize("loc_talent_zealot_bolstering_prayer")
	},
	zealot_multi_hits_increase_impact_effect = {
		en = Localize("loc_talent_zealot_multi_hits_increase_impact")
	},
	zealot_stacking_melee_damage_effect = {
		en = Localize("loc_talent_zealot_increased_damage_stacks_on_hit")
	},
	zealot_stacking_melee_damage_after_dodge_effect = {
		en = Localize("loc_talent_zealot_stacking_melee_damage_after_dodge")
	},
	zealot_backstabs_increase_backstab_damage_effect = {
		en = Localize("loc_talent_zealot_backstabs_increase_backstab_damage")
	},
	zealot_heavy_multihits_increase_melee_damage_effect = {
		en = Localize("loc_talent_zealot_heavy_multihits_increase_melee_damage")
	},
	zealot_kills_increase_damage_of_next_melee_effect = {
		en = Localize("loc_talent_zealot_kills_increase_damage_of_next_melee")
	},
	zealot_stacking_rending_buff = {
		en = Localize("loc_talent_zealot_crits_rend")
	},
	zealot_stacking_weakspot_power_effect = {
		en = Localize("loc_talent_zealot_stacking_weakspot_power")
	},
	adamant_crit_chance_on_kill_effect = {
		en = Localize("loc_talent_adamant_crit_chance_on_kill")
	},
	adamant_forceful_stacks = {
		en = Localize("loc_talent_adamant_forceful")
	},
	adamant_forceful_strength_stacks = {
		en = Localize("loc_talent_adamant_forceful_refresh_on_ability")
	},
	adamant_hunt_stance_damage = {
		en = Localize("loc_talent_adamant_stance_elite_kills_stack_damage")
	},
	adamant_stacking_damage_buff = {
		en = Localize("loc_talent_adamant_stacking_damage")
	},
	adamant_stacking_weakspot_strength_buff = {
		en = Localize("loc_talent_adamant_stacking_weakspot_strength")
	},
	adamant_staggers_reduce_damage_taken_buff = {
		en = Localize("loc_talent_adamant_staggers_reduce_damage_taken")
	},
	adamant_wield_speed_on_melee_kill_buff = {
		en = Localize("loc_talent_adamant_wield_speed_on_melee_kill")
	},
	broker_focus_sub_2_damage = {
		en = Localize("loc_talent_broker_ability_focus_sub_2")
	},
	broker_keystone_adrenaline_junkie_stack = {
		en = Localize("loc_talent_broker_keystone_adrenaline_junkie")
	},
	broker_keystone_chemical_dependency_stack = {
		en = Localize("loc_talent_broker_keystone_chemical_dependency")
	},
	broker_passive_melee_cleave_on_melee_kill_buff = {
		en = Localize("loc_talent_broker_passive_melee_cleave_on_melee_kill")
	},
	broker_passive_sprinting_reduces_threat_buff = {
		en = Localize("loc_talent_broker_passive_sprinting_reduces_threat")
	},
	vultures_mark = {
		en = Localize("loc_talent_broker_keystone_vultures_mark_on_kill")
	},
	weapon_trait_bespoke_chainaxe_p1_guaranteed_melee_crit_on_activated_kill_effect = {
		en = "Chain Axe Guarantee Crit"
	},
	weapon_trait_bespoke_combataxe_p2_guaranteed_melee_crit_after_crit_weakspot_kill_effect_percentage = {
		en = "Combat Axe Guarantee Crit"
	},
}

local hide_buffs = {
	bleed = 1,
	increase_damage_received_while_electrocuted = 1,
	increase_damage_received_while_staggered = 1,
	increase_damage_taken = 1,
	increase_impact_received_while_staggered = 1,
	power_maul_sticky_tick = 1,
	psyker_biomancer_warpfire_debuff = 1,
	rending_burn_debuff = 1,
	rending_debuff = 1,
	rending_debuff_medium = 1,
	warp_fire = 1,
	weapon_trait_bespoke_ogryn_powermaul_slabshield_p1_block_grants_power_bonus_child = 1,
	weapon_trait_bespoke_combataxe_p1_stacking_rending_on_one_hit_kill_child = 1,
	weapon_trait_bespoke_autogun_p1_increase_damage_on_close_kill_child = 1,
	hordes_ailment_minion_burning = 1,
	hordes_ailment_minion_bleed = 1,
	hordes_buff_elemental_weakness = 1,
	exploding_toxin_interval_buff = 1,
	hordes_buff_broker_flash_grenade_increase_damage_taken_effect = 1,
	neurotoxin_interval_buff = 1,
	neurotoxin_interval_buff2 = 1,
	neurotoxin_interval_buff3 = 1,
	saw_rending_debuff = 1,
}

local override_buffs = {
	veteran_weapon_switch_ranged_visual = "Weapon Specialist (Stored)",
	psyker_guaranteed_ranged_shot_on_stacked = Localize("loc_talent_psyker_weakspot_grants_crit"),
	zealot_fanatic_rage = Localize("loc_talent_zealot_fanatic_rage"),
}

mod.group_overrides = {
	disrupt_destiny = {
		loc = {
			en = Localize("loc_talent_psyker_marked_enemies_passive")
		},
		buffs = {
			"psyker_marked_enemies_passive_bonus_stacking",
			"psyker_marked_enemies_passive_bonus_stacking_increased_duration",
			"psyker_marked_enemies_passive_bonus_stacking_increased_stacks",
		}
	},
	wrap_battery = {
		loc = {
			en = Localize("loc_talent_psyker_souls")
		},
		buffs = {
			"psyker_souls",
			"psyker_souls_increased_max_stacks",
		}
	},
	empowered_psionics = {
		loc = {
			en = Localize("loc_talent_psyker_empowered_ability")
		},
		buffs = {
			"psyker_empowered_grenades_passive_visual_buff",
			"psyker_empowered_grenades_passive_visual_buff_increased",
		}
	},
	veteran_focus = {
		loc = {
			en = Localize("loc_talent_veteran_snipers_focus")
		},
		buffs = {
			"veteran_snipers_focus_stat_buff",
			"veteran_snipers_focus_stat_buff_increased_stacks",
		}
	},
	veteran_tag = {
		loc = {
			en = Localize("loc_talent_veteran_improved_tag_dead_coherency_bonus")
		},
		buffs = {
			"veteran_improved_tag_allied_buff",
			"veteran_improved_tag_allied_buff_increased_stacks",
		}
	},
	zealot_quickness = {
		loc = {
			en = Localize("loc_talent_zealot_quickness")
		},
		buffs = {
			"zealot_quickness_active",
			"zealot_quickness_active_increased_duration",
		}
	},
	uncanny_strike = {
		loc = {
			en = "Uncanny Strike"
		},
		buffs = {
			"stacking_rending_on_weakspot_parent",
			"stacking_rending_on_weakspot_child",
			"weapon_trait_bespoke_combataxe_p3_stacking_rending_on_weakspot_child",
			"weapon_trait_bespoke_combatknife_p1_stacking_rending_on_weakspot_child",
			"weapon_trait_bespoke_combatsword_p3_stacking_rending_on_weakspot_child",
			"weapon_trait_bespoke_forcesword_p1_stacking_rending_on_weakspot_child",
			"weapon_trait_bespoke_dual_shivs_p1_stacking_rending_on_weakspot_child",
		}
	},
	staff_charger = {
		loc = {
			en = "Warp Flurry"
		},
		buffs = {
			"weapon_trait_bespoke_forcestaff_p1_faster_charge_on_chained_secondary_attacks_child",
			"weapon_trait_bespoke_forcestaff_p2_faster_charge_on_chained_secondary_attacks_child",
			"weapon_trait_bespoke_forcestaff_p3_faster_charge_on_chained_secondary_attacks_child",
			"weapon_trait_bespoke_forcestaff_p4_faster_charge_on_chained_secondary_attacks_child",
		}
	},
	weap_trait_consecutive_hits_increases_close_damage_child = {
		loc = {
			en = "Dumdum"
		},
		buffs = {
			"weapon_trait_bespoke_autogun_p1_consecutive_hits_increases_close_damage_child",
			"weapon_trait_bespoke_lasgun_p3_consecutive_hits_increases_close_damage_child",
			"weapon_trait_bespoke_laspistol_p1_consecutive_hits_increases_close_damage_child",
		},
	},
	weap_trait_increase_close_damage_on_close_kill_child = {
		loc = {
			en = "Fire Frenzy"
		},
		buffs = {
			"weapon_trait_bespoke_autogun_p1_increase_close_damage_on_close_kill_child",
			"weapon_trait_bespoke_autogun_p2_increase_close_damage_on_close_kill_child",
			"weapon_trait_bespoke_bolter_p1_increase_close_damage_on_close_kill_child",
			"weapon_trait_bespoke_heavystubber_p1_increase_close_damage_on_close_kill_child",
			"weapon_trait_bespoke_ogryn_heavystubber_p2_increase_close_damage_on_close_kill_child",
			"weapon_trait_bespoke_ogryn_rippergun_p1_increase_close_damage_on_close_kill_child",
			"weapon_trait_bespoke_shotgun_p1_increase_close_damage_on_close_kill_child",
			"weapon_trait_bespoke_shotgun_p2_increase_close_damage_on_close_kill_child",
		},
	},
	weap_trait_increase_power_on_close_kill_child = {
		loc = {
			en = "Deathspitter"
		},
		buffs = {
			"weapon_trait_bespoke_autogun_p1_increase_power_on_close_kill_child",
			"weapon_trait_bespoke_autogun_p2_increase_power_on_close_kill_child",
			"weapon_trait_bespoke_lasgun_p3_increase_power_on_close_kill_child",
			"weapon_trait_bespoke_ogryn_heavystubber_p1_increase_power_on_close_kill_child",
			"weapon_trait_bespoke_ogryn_heavystubber_p2_increase_power_on_close_kill_child",
			"weapon_trait_bespoke_shotgun_p1_increase_power_on_close_kill_child",
			"weapon_trait_bespoke_shotgun_p2_increase_power_on_close_kill_child",
		},
	},
	weap_trait_reload_speed_on_close_kill_child = {
		loc = {
			en = "Speedload"
		},
		buffs = {
			"weapon_trait_bespoke_autogun_p1_reload_speed_on_slide_child",
			"weapon_trait_bespoke_autogun_p2_reload_speed_on_slide_child",
			"weapon_trait_bespoke_autopistol_p1_reload_speed_on_slide_child",
			"weapon_trait_bespoke_lasgun_p3_reload_speed_on_slide_child",
			"weapon_trait_bespoke_laspistol_p1_reload_speed_on_slide_child",
			"weapon_trait_bespoke_shotgun_p2_reload_speed_on_slide_child",
			"weapon_trait_bespoke_stubrevolver_p1_reload_speed_on_slide_child",
		},
	},
	weap_trait_stacking_power_bonus_on_staggering_enemies_child = {
		loc = {
			en = "Pinning Fire"
		},
		buffs = {
			"weapon_trait_bespoke_autopistol_p1_stacking_power_bonus_on_staggering_enemies_child",
			"weapon_trait_bespoke_bolter_p1_stacking_power_bonus_on_staggering_enemies_child",
			"weapon_trait_bespoke_ogryn_heavystubber_p2_stacking_power_bonus_on_staggering_enemies_child",
		},
	},
	weap_trait_increase_power_on_hit_child = {
		loc = {
			en = "Headtaker"
		},
		buffs = {
			"weapon_trait_bespoke_chainaxe_p1_increase_power_on_hit_child",
			"weapon_trait_bespoke_combataxe_p1_increase_power_on_hit_child",
			"weapon_trait_bespoke_combataxe_p2_increase_power_on_hit_child",
			"weapon_trait_bespoke_combatsword_p2_increase_power_on_hit_child",
			"weapon_trait_bespoke_ogryn_pickaxe_2h_p1_increase_power_on_hit_child",
			"weapon_trait_bespoke_thunderhammer_2h_p1_increase_power_on_hit_child",
		},
	},
	weap_trait_increase_power_on_kill_child = {
		loc = {
			en = "Slaughterer"
		},
		buffs = {
			"weapon_trait_bespoke_chainaxe_p1_increase_power_on_kill_child",
			"weapon_trait_bespoke_forcesword_p1_increase_power_on_kill_child",
			"weapon_trait_bespoke_ogryn_combatblade_p1_increase_power_on_kill_child",
			"weapon_trait_bespoke_ogryn_pickaxe_2h_p1_increase_power_on_kill_child",
			"weapon_trait_bespoke_powermaul_2h_p1_increase_power_on_kill_child",
			"weapon_trait_bespoke_powersword_p1_increase_power_on_kill_child",
			"weapon_trait_bespoke_thunderhammer_2h_p1_increase_power_on_kill_child",
		},
	},
	weap_trait_chained_hits_increases_crit_chance_child = {
		loc = {
			en = "Shred"
		},
		buffs = {
			"weapon_trait_bespoke_chainsword_2h_p1_chained_hits_increases_crit_chance_child",
			"weapon_trait_bespoke_chainsword_p1_chained_hits_increases_crit_chance_child",
			"weapon_trait_bespoke_combataxe_p1_chained_hits_increases_crit_chance_child",
			"weapon_trait_bespoke_combataxe_p2_chained_hits_increases_crit_chance_child",
			"weapon_trait_bespoke_combatsword_p1_chained_hits_increases_crit_chance_child",
			"weapon_trait_bespoke_combatsword_p3_chained_hits_increases_crit_chance_child",
			"weapon_trait_bespoke_forcesword_2h_p1_chained_hits_increases_crit_chance_child",
			"weapon_trait_bespoke_forcesword_p1_chained_hits_increases_crit_chance_child",
		},
	},
	weap_trait_chained_hits_increases_melee_cleave_child = {
		loc = {
			en = "Wrath"
		},
		buffs = {
			"weapon_trait_bespoke_chainsword_2h_p1_chained_hits_increases_melee_cleave_child",
			"weapon_trait_bespoke_chainsword_p1_chained_hits_increases_melee_cleave_child",
			"weapon_trait_bespoke_combatsword_p1_chained_hits_increases_melee_cleave_child",
			"weapon_trait_bespoke_combatsword_p2_chained_hits_increases_melee_cleave_child",
			"weapon_trait_bespoke_forcesword_2h_p1_chained_hits_increases_melee_cleave_child",
			"weapon_trait_bespoke_ogryn_pickaxe_2h_p1_chained_hits_increases_melee_cleave_child",
			"weapon_trait_bespoke_powersword_2h_p1_chained_hits_increases_melee_cleave_child",
			"weapon_trait_bespoke_powersword_p1_chained_hits_increases_melee_cleave_child",
		},
	},
	weap_trait_chained_hits_increases_power_child = {
		loc = {
			en = "Decimator"
		},
		buffs = {
			"weapon_trait_bespoke_combataxe_p1_chained_hits_increases_power_child",
			"weapon_trait_bespoke_combataxe_p2_chained_hits_increases_power_child",
			"weapon_trait_bespoke_combataxe_p3_chained_hits_increases_power_child",
			"weapon_trait_bespoke_ogryn_gauntlet_p1_chained_melee_hits_increases_power_child"
		},
	},
	weap_trait_consecutive_melee_hits_same_target_increases_melee_power_child = {
		loc = {
			en = "Relentless Strikes"
		},
		buffs = {
			"weapon_trait_bespoke_combataxe_p2_consecutive_melee_hits_same_target_increases_melee_power_child",
			"weapon_trait_bespoke_combatsword_p3_consecutive_melee_hits_same_target_increases_melee_power_child"
		},
	},
	weap_trait_consecutive_hits_increases_stagger_child = {
		loc = {
			en = "Trauma"
		},
		buffs = {
			"weapon_trait_bespoke_combataxe_p3_consecutive_hits_increases_stagger_child",
			"weapon_trait_bespoke_combatsword_p1_consecutive_hits_increases_stagger_child",
			"weapon_trait_bespoke_powermaul_2h_p1_consecutive_hits_increases_stagger_child",
			"weapon_trait_bespoke_powermaul_p1_consecutive_hits_increases_stagger_child",
			"weapon_trait_bespoke_thunderhammer_2h_p1_consecutive_hits_increases_stagger_child",
		},
	},
	weap_trait_stacking_increase_impact_on_hit_child = {
		loc = {
			en = "Hammerblow"
		},
		buffs = {
			"weapon_trait_bespoke_combataxe_p3_stacking_increase_impact_on_hit_child",
			"weapon_trait_bespoke_combatsword_p1_stacking_increase_impact_on_hit_child",
			"weapon_trait_bespoke_powermaul_2h_p1_stacking_increase_impact_on_hit_child",
			"weapon_trait_bespoke_powermaul_p1_stacking_increase_impact_on_hit_child",
			"weapon_trait_bespoke_thunderhammer_2h_p1_stacking_increase_impact_on_hit_child",
		},
	},
	weap_trait_chained_weakspot_hits_increases_power_child = {
		loc = {
			en = "Executor"
		},
		buffs = {
			"weapon_trait_bespoke_combatknife_p1_chained_weakspot_hits_increases_power_child",
			"weapon_trait_bespoke_forcesword_p1_chained_weakspot_hits_increases_power_child",
			"weapon_trait_bespoke_stubrevolver_p1_chained_weakspot_hits_increases_power_child",
		},
	},
	weap_trait_heavy_chained_hits_increases_killing_blow_chance_child = {
		loc = {
			en = "Haymaker"
		},
		buffs = {
			"weapon_trait_bespoke_combatknife_p1_heavy_chained_hits_increases_killing_blow_chance_child",
			"weapon_trait_bespoke_ogryn_club_p2_heavy_chained_hits_increases_killing_blow_chance_child",
		},
	},
	weap_trait_rending_on_multiple_hits_child = {
		loc = {
			en = "Bladed Momentum"
		},
		buffs = {
			"weapon_trait_bespoke_combatsword_p2_rending_on_multiple_hits_child",
		},
	},
	weap_trait_elite_kills_grants_stackable_power_child = {
		loc = {
			en = "Superiority"
		},
		buffs = {
			"weapon_trait_bespoke_forcesword_p1_elite_kills_grants_stackable_power_child",
		},
	},
	weap_trait_consecutive_hits_increases_ranged_power_child = {
		loc = {
			en = "Overwhelming Fire"
		},
		buffs = {
			"weapon_trait_bespoke_ogryn_heavystubber_p1_consecutive_hits_increases_ranged_power_child",
			"weapon_trait_bespoke_ogryn_heavystubber_p2_consecutive_hits_increases_ranged_power_child",
		},
	},
	weap_trait_chained_weakspot_hits_increase_finesse_and_reduce_overheat_child = {
		loc = {
			en = "Cranial Grounding"
		},
		buffs = {
			"weapon_trait_bespoke_powersword_2h_p1_chained_weakspot_hits_increase_finesse_and_reduce_overheat_child"
		},
	},
	weap_trait_stacking_buff_on_continuous_fire = {
		loc = {
			en = "Blaze Away"
		},
		buffs = {
			"weapon_trait_bespoke_autopistol_p1_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_flamer_p1_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_forcestaff_p2_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_ogryn_gauntlet_p1_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_ogryn_heavystubber_p1_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_ogryn_heavystubber_p2_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_ogryn_rippergun_p1_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_ogryn_thumper_p1_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_ogryn_thumper_p2_power_bonus_on_continuous_fire",
			"weapon_trait_bespoke_plasmagun_p1_power_bonus_on_continuous_fire",
		}
	},
}
mod.group_buffs = {}
mod.child_parent_buffs = {}

for group_name, group in pairs(mod.group_overrides) do
	if group.buffs then
		for _, b in ipairs(group.buffs) do
			mod.group_buffs[b] = group_name
			loc[b] = group.loc
		end
	end
end

local parent_buffs = {}

for buff_name, buff in pairs(BuffTemplates) do
	if buff.child_buff_template then
		mod.child_parent_buffs[buff.child_buff_template] = buff_name
		parent_buffs[buff.child_buff_template] = buff
	end
end

for buff_name, buff in pairs(BuffTemplates) do
	if not mod.group_buffs[buff_name] then
		if override_buffs[buff_name] then
			mod.buff_names[#mod.buff_names + 1] = buff_name
			loc[buff_name] = { en = override_buffs[buff_name] or buff_name }
		elseif buff.max_stacks and buff.max_stacks > 1 and not hide_buffs[buff_name] then
			if buff.duration and buff.duration > 0 then
				mod.buff_names[#mod.buff_names + 1] = buff_name
			elseif mod.group_buffs[buff_name] == nil then
				local parent_buff = parent_buffs[buff_name]
				if parent_buff and parent_buff.child_duration and parent_buff.base_child_buff_template then
					mod:echo(parent_buff.base_child_buff_template)
					mod:echo(buff_name)
					local group_key = "autogen_" .. parent_buff.base_child_buff_template
					mod.group_overrides[group_key] = mod.group_overrides[group_key] or { 
						loc = {
							en = Localize("loc_" .. parent_buff.base_child_buff_template)
						},
						buffs = {},
					}
					mod.group_overrides[group_key].buffs[#mod.group_overrides[group_key].buffs + 1] = buff_name
					mod.group_buffs[buff_name] = group_key
					loc[buff_name] = mod.group_overrides[group_key].loc
				end
			end
		end
	end
end

for _, buff_name in ipairs(mod.buff_names) do
	loc["enable_" .. buff_name] = loc["enable"]
	loc["color_" .. buff_name] = loc["color"]
	loc["showlabel_" .. buff_name] = loc["showlabel"]

	local key = "group_" .. buff_name

	loc[key] = loc[key] or {}
	loc[key]["en"] = buff_name
	if loc[buff_name] and loc[buff_name].en then
		loc[key]["en"] = loc[buff_name].en
	end
end

for group_name, group in pairs(mod.group_overrides) do
	loc["enable_g_" .. group_name] = loc["enable"]
	loc["color_g_" .. group_name] = loc["color"]
	loc["showlabel_g_" .. group_name] = loc["showlabel"]
	loc["group_g_" .. group_name] = group.loc or {}
end

table.sort(mod.buff_names, function(a, b)
	return a < b
end)

for i, name in ipairs(Color.list) do
    local c = Color[name](255, true)
    local text = string.format("{#color(%s,%s,%s)}%s{#reset()}", c[2], c[3], c[4], string.gsub(name, "_", " "))

    loc[name] = {}
    loc[name].en = text
end

for i = 1, mod.buff_max do
	loc["lock_slot_" .. i] = { en = "Slot " .. i }
end

return loc
