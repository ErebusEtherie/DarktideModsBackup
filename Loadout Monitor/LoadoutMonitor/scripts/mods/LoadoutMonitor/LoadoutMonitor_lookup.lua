local mod = get_mod("LoadoutMonitor")

local feats_symbol = {
	Ability = mod:localize("player_Feats_symbol_Ability"),
	Blitz = mod:localize("player_Feats_symbol_Blitz"),
	Aura = mod:localize("player_Feats_symbol_Aura"),
	Keystone = mod:localize("player_Feats_symbol_Keystone"),
}
local talents = {
	veteran = {
		Ability = {"veteran_combat_ability_elite_and_special_outlines","veteran_combat_ability_stagger_nearby_enemies","veteran_invisibility_on_combat_ability"},
		Blitz = {"veteran_grenade_apply_bleed","veteran_krak_grenade","veteran_smoke_grenade"},
		Aura = {"veteran_aura_gain_ammo_on_elite_kill_improved","veteran_increased_damage_coherency","veteran_movement_speed_coherency"},
		Keystone = {"veteran_snipers_focus","veteran_improved_tag","veteran_weapon_switch_passive"},
	},
	zealot = {
		Ability = {"zealot_attack_speed_post_ability","zealot_bolstering_prayer","zealot_stealth"},
		Blitz = {"zealot_improved_stun_grenade","zealot_flame_grenade","zealot_throwing_knives"},
		Aura = {"zealot_toughness_damage_reduction_coherency_improved","zealot_corruption_healing_coherency_improved","zealot_stamina_cost_multiplier_aura"},
		Keystone = {"zealot_fanatic_rage","zealot_martyrdom","zealot_quickness_passive"},
	},
	psyker = {
		Ability = {"psyker_shout_vent_warp_charge","psyker_combat_ability_force_field","psyker_combat_ability_stance"},
		Blitz = {"psyker_brain_burst_improved","psyker_grenade_chain_lightning","psyker_grenade_throwing_knives"},
		Aura = {"psyker_aura_damage_vs_elites","psyker_cooldown_aura_improved","psyker_aura_crit_chance_aura"},
		Keystone = {"psyker_passive_souls_from_elite_kills","psyker_empowered_ability","psyker_new_mark_passive"},
	},
	ogryn = {
		Ability = {"ogryn_longer_charge","ogryn_taunt_shout","ogryn_special_ammo"},
		Blitz = {"ogryn_grenade_friend_rock","ogryn_grenade_frag","ogryn_box_explodes"},
		Aura = {"ogryn_melee_damage_coherency_improved","ogryn_toughness_regen_aura","ogryn_damage_vs_suppressed_coherency"},
		Keystone = {"ogryn_passive_heavy_hitter","ogryn_carapace_armor","ogryn_leadbelcher_no_ammo_chance"},
	},
	adamant = {
		Ability = {"adamant_stance","adamant_area_buff_drone_improved","adamant_charge"},
		Blitz = {"adamant_whistle","adamant_shock_mine","adamant_grenade_improved"},
		Aura = {"adamant_companion_coherency","adamant_reload_speed_aura","adamant_damage_vs_staggered_aura"},
		Keystone = {"adamant_execution_order","adamant_terminus_warrant","adamant_forceful"},
		Keystone_dog = {"adamant_companion_focus_elite","adamant_disable_companion","adamant_companion_focus_ranged"},
	},
	broker = {
		Ability = {"broker_ability_focus_improved","broker_ability_punk_rage","broker_ability_stimm_field"},
		Blitz = {"broker_blitz_flash_grenade_improved","broker_blitz_missile_launcher","broker_blitz_tox_grenade"},
		Aura = {"broker_aura_gunslinger_improved","broker_coherency_melee_damage","broker_coherency_anarchist"},
		Keystone = {"broker_keystone_vultures_mark_on_kill","broker_keystone_adrenaline_junkie","broker_keystone_chemical_dependency"},
	},
	cryptic = {
		Ability = {"cryptic_chordclaw","cryptic_discharge","cryptic_precision_stance"},
		Blitz = {"cryptic_servo_skull_improved","cryptic_grenade_ability_arc_grenade","cryptic_grenade_ability_force_field"},
		Aura = {"cryptic_coherency_regen_aura_improved","cryptic_aura_weapon_improved","cryptic_ammo_aura"},
		Keystone = {"cryptic_redline","cryptic_dissector","cryptic_overload_keystone"},
	},
}
local noteworthy_talents = {
	veteran = {
		{
			"veteran_better_deployables",{255,0,206,209}
		},
		{
			"veteran_combat_ability_revive_nearby_allies",{255,255,215,0}
		},
		
	},
	cryptic = {
		{
			"cryptic_servo_skull_inject_ally",{255,77,255,46},
		},	
	},
}

local trait_offsets = {
	bless = {280,},
	perk = {370,},
}
return {
	talents_index = talents,
	feats_symbol = feats_symbol,
	noteworthy_talents = noteworthy_talents,
	trait_offsets = trait_offsets,
	default_feats_order = {"Ability","Blitz","Aura","Keystone"},
	mod_text_color = {255,239,238,238},
	weapon_slot ={Melee = "slot_primary", Range = "slot_secondary"},
}