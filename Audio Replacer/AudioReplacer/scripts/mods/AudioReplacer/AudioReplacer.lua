local mod = get_mod("AudioReplacer")
local Audio
local silent = {}

local warp_explosion_audio = {
	"player/warp_explosion_1.opus",
	"player/warp_explosion_2.opus",
	"player/warp_explosion_3.opus",
	"player/warp_explosion_4.opus",
	"player/warp_explosion_5.opus",
	"player/warp_explosion_6.opus",
}

local warp_critical_audio = {
    "player/warp_critical_1.opus",
}
	
local mutant_footstep_audio = {
	"mutant/footstep_1.opus",
	"mutant/footstep_2.opus",
	"mutant/footstep_3.opus",
	"mutant/footstep_4.opus",
	"mutant/footstep_5.opus",
	"mutant/footstep_6.opus",
}

local plasmagunner_charge_audio = {
	"plasmagunner/charge_1.opus",
}

local stub_revolver_audio = {
	"weapons/stub_revolver_1.opus",
	"weapons/stub_revolver_2.opus",
	"weapons/stub_revolver_3.opus",
	"weapons/stub_revolver_4.opus",
	"weapons/stub_revolver_5.opus",
	"weapons/stub_revolver_6.opus",
}

local shotgun_fire_audio = {
    "weapons/shotgun_fire_1.opus",
	"weapons/shotgun_fire_2.opus",
	"weapons/shotgun_fire_3.opus",
	"weapons/shotgun_fire_4.opus",
	"weapons/shotgun_fire_5.opus",
	"weapons/shotgun_fire_6.opus",
	"weapons/shotgun_fire_7.opus",
}

local shotgun_reload_audio = {
    "weapons/shotgun_reload_1.opus",
	"weapons/shotgun_reload_2.opus",
	"weapons/shotgun_reload_3.opus",
	"weapons/shotgun_reload_4.opus",
	"weapons/shotgun_reload_5.opus",
	"weapons/shotgun_reload_6.opus",
	"weapons/shotgun_reload_7.opus",
	"weapons/shotgun_reload_8.opus",
}

local shotgun_special_audio = {
    "weapons/shotgun_special_1.opus",
	"weapons/shotgun_special_2.opus",
}

local shotgun_forward_audio = {
    "weapons/shotgun_forward_1.opus",
}

local shotgun_back_audio = {
    "weapons/shotgun_back_1.opus",
}

local ogryn_insert_audio = {
    "weapons/ogryn_insert_1.opus",
	"weapons/ogryn_insert_2.opus",
	"weapons/ogryn_insert_3.opus",
	"weapons/ogryn_insert_4.opus",
	"weapons/ogryn_insert_5.opus",
	"weapons/ogryn_insert_6.opus",
	"weapons/ogryn_insert_7.opus",
}

local ogryn_open_audio = {
    "weapons/ogryn_open_1.opus",
	"weapons/ogryn_open_2.opus",
	"weapons/ogryn_open_3.opus",
	"weapons/ogryn_open_4.opus",
	"weapons/ogryn_open_5.opus",
	"weapons/ogryn_open_6.opus",
	"weapons/ogryn_open_7.opus",
}

local rumbler_shot_audio = {
    "weapons/rumbler_shot_1.opus",
}

local gauntlet_shot_audio = {
    "weapons/gauntlet_shot_1.opus",
}

local explosion_echo_audio = {
    "weapons/explosion_echo.opus",
}

local force_block_audio = {
    "weapons/force_block_1.opus",
	"weapons/force_block_2.opus",
	"weapons/force_block_3.opus",
	"weapons/force_block_4.opus",
	"weapons/force_block_5.opus",
	"weapons/force_block_6.opus",
	"weapons/force_block_7.opus",
}

local mutant_grab_audio = {
	"mutant/grab_1.mp3",
}

local mutant_charge_audio = {
	"mutant/charge_1.opus",
}

local mutant_punch_audio = {
	"mutant/punch_1.opus",
}

local netgunner_attack_audio = {
	"netgunner/attack_1.opus",
}

local player_yeet_audio = {
	"player/yeet_1.opus",
	"player/yeet_2.opus",
	"player/yeet_3.opus",
	"player/yeet_4.opus",
	"player/yeet_5.opus",
}

local player_relic_audio = {
	"player/relic_1.opus",
}

local player_charge_audio = {
	"player/charge_1.opus",
}

local player_shout_audio = {
	"player/shout_1.opus",
	"player/shout_2.opus",
}

local player_slide_audio = {
	"player/slide_1.opus",
	"player/slide_2.opus",
	"player/slide_3.opus",
	"player/slide_4.opus",
	"player/slide_5.opus",
}

local player_taunt_audio = {
	"player/taunt_1.opus",
	"player/taunt_2.opus",
}

local player_killshot_audio = {
	"player/killshot_1.opus",
}

local player_stealth_audio = {
	"player/stealth_1.opus",
	"player/stealth_2.opus",
	"player/stealth_3.opus",
	"player/stealth_4.opus",
	"player/stealth_5.opus",
	"player/stealth_6.opus",
	"player/stealth_7.opus",
}

local player_shriek_audio = {
	"player/shriek_1.opus",
}

local player_netted_audio = {
	"player/netted_1.opus",
	"player/netted_2.opus",
}

local player_shield_audio = {
	"player/shield_1.opus",
	"player/shield_2.opus",
	"player/shield_3.opus",
	"player/shield_4.opus",
	"player/shield_5.opus",
}

local player_death_audio = {
	"player/death_1.opus",
}

local player_medpack_audio = {
	"player/medpack_1.opus",
}

local player_stim_audio = {
	"player/stim_1.opus",
}

local player_stimheal_audio = {
	"player/stimheal_1.opus",
}

local player_frag_audio = {
	"player/frag_1.opus",
}

local player_krak_audio = {
	"player/krak_1.opus",
}

local player_smoke_audio = {
	"player/smoke_1.opus",
}

local player_stun_audio = {
	"player/stun_1.opus",
}

local player_fire_audio = {
	"player/fire_1.opus",
}

local player_bigfrag_audio = {
	"player/bigfrag_1.opus",
}

local player_ogryn_blunt_audio = {
	"player/ogryn_blunt_1.opus",
    "player/ogryn_blunt_2.opus",
	"player/ogryn_blunt_3.opus",
	"player/ogryn_blunt_4.opus",
	"player/ogryn_blunt_5.opus",
}

local player_psyker_gaze_audio = {
    "player/psyker_gaze_1.opus",
}

local forcesword_charge_audio = {
	"weapons/forcesword_charge_1.opus",
	"weapons/forcesword_charge_2.opus",
	"weapons/forcesword_charge_3.opus",
}

local staff_primary_audio = {
	"weapons/staff_fire_1.opus",
}

local staff_impact_audio = {
	"weapons/staff_fire_1.opus",
}

local mutant_breath_audio = {
	"mutant/scream_1.opus",
	"mutant/scream_2.opus",
	"mutant/scream_3.opus",
}

local mutant_death_audio = {
	"mutant/oof.opus",
}

local mutant_spawn_audio = {
	"mutant/spawn_1.opus",
}

local pox_hound_jump_audio = {
	"pox_hound/jump_1.opus",
	"pox_hound/jump_2.opus",
	"pox_hound/jump_3.opus",
}

local pox_hound_bark_audio = {
	"pox_hound/bark_1.opus",
	"pox_hound/bark_2.opus",
	"pox_hound/bark_3.opus",
	"pox_hound/bark_4.opus",
}

local pox_hound_hurt_audio = {
	"pox_hound/hurt_1.opus",
	"pox_hound/hurt_2.opus",
	"pox_hound/hurt_3.opus",
	"pox_hound/hurt_4.opus",
	"pox_hound/hurt_5.opus",
	"pox_hound/hurt_6.opus",
}

local pox_hound_group_audio = {
	"pox_hound/group_1.opus",
}

local pox_hound_maul_audio = {
    "pox_hound/maul_1.opus",
}

local flamer_flame_audio = {
	"pox_hound/hurt_6.opus",
}

local pox_bomber_tick_audio = {
	"pox_bomber/tick_1.opus",
}

local pox_bomber_wind_up_audio = {
	"pox_bomber/wind_up_1.opus",
}

local pox_bomber_explosion_audio = {
	"pox_bomber/explosion_1.opus",
}

local enemy_killed_audio = {
    "player/enemy_killed_1.opus",
	"player/enemy_killed_2.opus",
	"player/enemy_killed_3.opus",
	"player/enemy_killed_4.opus",
	"player/enemy_killed_5.opus",
	"player/enemy_killed_6.opus",
	"player/enemy_killed_7.opus",
}

local ogryn_barrage_audio = {
    "player/ogryn_barrage_1.opus",
	"player/ogryn_barrage_2.opus",
}

local zealot_dash_audio = {
    "player/zealot_dash_1.opus",
	"player/zealot_dash_2.opus",
	"player/zealot_dash_3.opus",
	"player/zealot_dash_4.opus",
	"player/zealot_dash_5.opus",
	"player/zealot_dash_6.opus",
	"player/zealot_dash_7.opus",
	"player/zealot_dash_8.opus",
	"player/zealot_dash_9.opus",
}

local arby_stance_audio = {
    "player/arby_stance_1.opus",
}

local arby_charge_audio = {
    "player/arby_charge_1.opus",
	"player/arby_charge_2.opus",
	"player/arby_charge_3.opus",
	"player/arby_charge_4.opus",
	"player/arby_charge_5.opus",
}

local arby_shieldblast_audio = {
    "weapons/shieldblast_1.opus",
}

local radio_operator_audio = {
    "radio_operator/radio_stinger_1.opus",
}

local horde_warning_audio = {
    "horde/horde_warning_1.opus",
	"horde/horde_warning_2.opus",
	"horde/horde_warning_3.opus",
	"horde/horde_warning_4.opus",
	"horde/horde_warning_5.opus",
	"horde/horde_warning_6.opus",
}

local dog_breath_audio = {
    "player/dog_breath_1.opus",
	"player/dog_breath_2.opus",
	"player/dog_breath_3.opus",
	"player/dog_breath_4.opus",
}

local dog_attack_audio = {
    "player/dog_attack_1.opus",
	"player/dog_attack_2.opus",
	"player/dog_attack_3.opus",
}

local dog_jump_audio = {
    "player/dog_jump_1.opus",
	"player/dog_jump_2.opus",
	"player/dog_jump_3.opus",
}

local ranged_warning_audio = {
    "player/ranged_warning_1.opus",
}

local reaper_death_audio = {
    "reaper/death_1.opus",
	"reaper/death_2.opus",
	"reaper/death_3.opus",
	"reaper/death_4.opus",
	"reaper/death_5.opus",
	"reaper/death_6.opus",
}

local reaper_attack_audio = {
    "reaper/attack_1.opus",
	"reaper/attack_2.opus",
	"reaper/attack_3.opus",
	"reaper/attack_4.opus",
	"reaper/attack_5.opus",
	"reaper/attack_6.opus",
	"reaper/attack_7.opus",
}

local reaper_hurt_audio = {
	"reaper/hurt_1.opus",
	"reaper/hurt_2.opus",
	"reaper/hurt_3.opus",
	"reaper/hurt_4.opus",
	"reaper/hurt_5.opus",
	"reaper/hurt_6.opus",
	"reaper/hurt_7.opus",
}

local reaper_melee_audio = {
	"reaper/melee_1.opus",
	"reaper/melee_2.opus",
	"reaper/melee_3.opus",
	"reaper/melee_4.opus",
	"reaper/melee_5.opus",
}

local dog_explosion_audio = {
	"player/dogsplosion_1.opus",
}

local grenadier_voice_audio = {
	"grenadier/voice_1.opus",
}

local grenadier_fuse_audio = {
	"grenadier/fuse_1.opus",
}

local grenadier_footstep_audio = {
	"grenadier/step_1.opus",
	"grenadier/step_2.opus",
	"grenadier/step_3.opus",
	"grenadier/step_4.opus",
}

local grenadier_bomb_audio = {
	"grenadier/bomb_1.opus",
}

local grenadier_ready_audio = {
	"grenadier/ready_1.opus",
}

local grenadier_spawn_audio = {
	"grenadier/spawn_1.opus",
	"grenadier/spawn_2.opus",
	"grenadier/spawn_3.opus",
	"grenadier/spawn_4.opus",
	"grenadier/spawn_5.opus",
	"grenadier/spawn_6.opus",
}

local grenadier_yell_audio = {
	"grenadier/yell_1.opus",
	"grenadier/yell_2.opus",
}

local ganger_rage_audio = {
	"player/ganger_rage_1.opus",
}

local ganger_rage_end_audio = {
	"player/ganger_rage_end_1.opus",
	"player/ganger_rage_end_2.opus",
}

local ganger_focus_audio = {
	"player/ganger_focus_1.opus",
	"player/ganger_focus_2.opus",
	"player/ganger_focus_3.opus",
	"player/ganger_focus_4.opus",
}

local ganger_focus_end_audio = {
	"player/ganger_focus_end_1.opus",
}

local enemies = {
	"cultist_mutant",
	"chaos_hound",
	"player",
	"renegade_netgunner",
	"pox_bomber",
	"renegade_radio_operator",
	"adamant_dog",
	"chaos_ogryn_gunner",
	"renegade_plasma_gunner",
	"renegade_grenadier",
	
	--"cultist_flamer"
}

-- This is for long playing sounds you want interrupted by another.
-- <The interrupting sound> = "<the sound to be interrupted>"
-- In this case the rage_stop is interrupting the rage_start
local ongoing_sound_replacements = {
	play_player_ability_broker_rage_stop = "play_player_ability_broker_rage_start",
	play_player_ability_broker_focus_stop = "play_player_ability_broker_focus_start"
}

local enemy_sound_replacements = {
	cultist_mutant = {
		--play_enemy_mutant_charger_bone_rattle = silent,
		play_enemy_mutant_charger_charge_growl = mutant_charge_audio,
		--play_mutant_charger_footstep_boots_heavy = mutant_footstep_audio,
		--play_enemy_mutant_charger_death = mutant_death_audio,
		play_enemy_mutant_charger_grunt = mutant_breath_audio,
		--play_enemy_mutant_charger_run_breath = silent,
		--play_enemy_mutant_charger_run_rattle = silent,
		play_enemy_mutant_charger_smash_ogryn = mutant_punch_audio,
		play_enemy_mutant_charger_smash_human = mutant_punch_audio,
		play_hud_player_states_mutant_charger_downed = mutant_grab_audio,
		play_hud_player_states_mutant_charger_downed_husk = mutant_grab_audio,
		play_mutant_charger_idle_shout_long = mutant_breath_audio,
		play_mutant_charger_idle_shout_short = mutant_breath_audio,
		play_minion_special_mutant_charger_spawn = mutant_spawn_audio
	},
	chaos_hound = {
		play_enemy_chaos_hound_vce_leap = pox_hound_jump_audio,
		play_enemy_chaos_hound_vce_growl = pox_hound_bark_audio,
		play_enemy_chaos_hound_hurt = pox_hound_hurt_audio,
		--sfx_growl_probability = pox_hound_bark_audio,
		play_enemy_chaos_hound_vce_bark = pox_hound_bark_audio,
		play_chaos_hound_spawn_stinger_circumstance = pox_hound_group_audio,
		play_enemy_chaos_hound_bite = pox_hound_maul_audio
	},
	player = {
		play_player_combat_experience_catapulted = player_yeet_audio,
		play_ability_zealot_bolstering_prayer = player_relic_audio,
		play_ability_ogryn_charge_start = player_charge_audio,
		play_ogryn_ability_taunt = player_taunt_audio,
		play_player_slide = player_slide_audio,
		play_ogryn_ability_taunt_husk = player_taunt_audio,
		play_player_slide_husk = player_slide_audio,
		play_veteran_ability_shout = player_shout_audio,
		play_veteran_ability_shout_husk = player_shout_audio,
		play_veteran_ability_stealth_on = player_stealth_audio,
		play_player_ability_veteran_killshot_stance_on = player_killshot_audio,
		play_psyker_ability_shout = player_shriek_audio,
		play_psyker_ability_shout_husk = player_shriek_audio,
		play_ability_psyker_protectorate_shield = player_shield_audio,
		play_ability_psyker_protectorate_shield_husk = player_shield_audio,
		play_ability_psyker_shield_dome = player_shield_audio,
		play_foley_player_netted_struggle = player_netted_audio,
		play_enemy_netgunner_net_pull = player_netted_audio,
		play_stub_revolver_p1_m2 = stub_revolver_audio,
		play_teammate_died = player_death_audio,
		play_medpack_deploy = player_medpack_audio,
		play_syringe_stab_self = player_stim_audio,
		play_syringe_heal_self = player_stimheal_audio,
		play_explosion_grenade_frag = player_frag_audio,
		play_explosion_grenade_krak = player_krak_audio,
		play_explosion_grenade_smoke = player_smoke_audio,
		play_explosion_grenade_shock = player_stun_audio,
		play_explosion_grenade_flame = player_fire_audio,
		play_explosion_grenade_frag_ogryn = player_bigfrag_audio,
		melee_hits_blunt_heavy_ogryn = player_ogryn_blunt_audio,
		play_elite_killed = enemy_killed_audio,
		play_special_killed = enemy_killed_audio,
		play_ability_ogryn_speshul_ammo = ogryn_barrage_audio,
		play_ability_zealot_maniac_dash_enter = zealot_dash_audio,
		play_ability_gunslinger_on = player_psyker_gaze_audio,
		play_signal_horde_poxwalkers_2d = horde_warning_audio,
		play_minion_horde_poxwalker_ambush_2d = horde_warning_audio,
		play_shotgun_p1_m3 = shotgun_fire_audio,
		play_weapon_shotgun_human_reload_insert_ammo = shotgun_reload_audio,
		play_shotgun_reload_insert_ammo_special_03 = shotgun_special_audio,
		play_shotgun_reload_pull = shotgun_back_audio,
		play_shotgun_reload_push = shotgun_forward_audio,
		play_force_shield_block = force_block_audio,
		play_ogryn_thumper_p1_m2 = rumbler_shot_audio,
		thumper_shotgun_open = ogryn_open_audio,
		thumper_shotgun_insert = ogryn_insert_audio,
		play_ogryn_gauntlet_fire = gauntlet_shot_audio,
		play_explosion_refl_gen = explosion_echo_audio,
		play_player_ability_adamant_damage_on = arby_stance_audio,
		play_player_ability_adamant_charge = arby_charge_audio,
		play_adamant_shield_maul_special_attack = arby_shieldblast_audio,
		play_backstab_indicator_ranged = ranged_warning_audio,
		play_shotgun_p4_reload_pull = shotgun_back_audio,
		play_shotgun_p4_reload_release = shotgun_forward_audio,
		play_shotgun_p4_m1 = shotgun_fire_audio,
		play_2h_forcesword_ability_charge_1 = forcesword_charge_audio,
		play_2h_forcesword_ability_charge_2 = forcesword_charge_audio,
		play_2h_forcesword_ability_charge_3 = forcesword_charge_audio,
		play_psyker_smite_fire = staff_primary_audio,
		play_explosion_force_sml = staff_impact_audio,
		play_psyker_warp_charge_overload_start = warp_explosion_audio,
		play_warp_charge_build_up_critical = warp_critical_audio,
		play_psyker_male_a__vce_scream_long = explosion_echo_audio,
		play_psyker_male_b__vce_scream_long = explosion_echo_audio,
		play_psyker_male_c__vce_scream_long = explosion_echo_audio,
		play_psyker_female_a__vce_scream_long = explosion_echo_audio,
		play_psyker_female_b__vce_scream_long = explosion_echo_audio,
		play_psyker_female_c__vce_scream_long = explosion_echo_audio,
		play_psyker_male_a__vce_hurt_heavy = explosion_echo_audio,
		play_psyker_male_b__vce_hurt_heavy = explosion_echo_audio,
		play_psyker_male_c__vce_hurt_heavy = explosion_echo_audio,
		play_psyker_female_a__vce_hurt_heavy = explosion_echo_audio,
		play_psyker_female_b__vce_hurt_heavy = explosion_echo_audio,
		play_psyker_female_c__vce_hurt_heavy = explosion_echo_audio,
		play_player_ability_broker_rage_start = ganger_rage_audio,
		play_player_ability_broker_rage_stop = ganger_rage_end_audio,
		play_player_ability_broker_focus_start = ganger_focus_audio,
		play_player_ability_broker_focus_stop = ganger_focus_end_audio,
	},
	cultist_flamer = {
		play_minion_flamethrower_green_start = flamer_flame_audio
	},
	renegade_netgunner = {
		play_weapon_netgunner_wind_up = netgunner_attack_audio
	},
	pox_bomber = {
		play_enemy_combat_poxwalker_bomber_beep_loop = pox_bomber_tick_audio,
		play_minion_poxwalker_bomber_wind_up = pox_bomber_wind_up_audio,
		play_explosion_bomber = pox_bomber_explosion_audio,
	},
	renegade_radio_operator = {
	    play_enemy_radio_operator_stinger = radio_operator_audio
    },
	adamant_dog = {
	    play_adamant_dog_vce_breath_loop_01 = dog_breath_audio,
		play_companion_bite_flesh = dog_attack_audio,
		play_adamant_dog_vce_attack_01 = dog_jump_audio,
		play_player_ability_adamant_dog_explosion = dog_explosion_audio,
	},
	chaos_ogryn_gunner = {
		play_enemy_chaos_ogryn_heavy_gunner__death_vce = reaper_death_audio,
		play_chaos_ogryn_heavy_gunner_into_aim = reaper_attack_audio,
		play_enemy_chaos_ogryn_heavy_gunner__hurt_vce = reaper_hurt_audio,
		play_enemy_chaos_ogryn_heavy_gunner__melee_attack_vce = reaper_melee_audio,
	},
	renegade_plasma_gunner = {
		play_minion_plasmapistol_charge = plasmagunner_charge_audio,
	},
	renegade_grenadier = {
		play_traitor_guard_grenadier_footsteps = grenadier_footstep_audio,
		play_explosion_grenade_flame_minion = grenadier_bomb_audio,
		play_minion_grenadier_fire_grenade_fuse = grenadier_fuse_audio,
		play_traitor_guard_grenadier_pull_sprint = grenadier_ready_audio,
	},
}

local options_categories = {
	-- MUTANT
	play_enemy_mutant_charger_charge_growl = "cultist_mutant_charge",
	play_enemy_mutant_charger_smash_ogryn = "cultist_mutant_punch",
	play_enemy_mutant_charger_smash_human = "cultist_mutant_punch",
	play_mutant_charger_idle_shout_long = "cultist_mutant_grunts",
	play_mutant_charger_idle_shout_short = "cultist_mutant_grunts",
	play_enemy_mutant_charger_grunt = "cultist_mutant_grunts",
	play_hud_player_states_mutant_charger_downed = "cultist_mutant_grab",
	play_hud_player_states_mutant_charger_downed_husk = "cultist_mutant_grab",
	--play_mutant_charger_footstep_boots_heavy = "cultist_mutant_footsteps",
	play_minion_special_mutant_charger_spawn = "cultist_mutant_spawn",

	-- PLAYER
	play_player_combat_experience_catapulted = "player_catapult",
	play_ability_zealot_bolstering_prayer = "player_relic",
	play_ability_ogryn_charge_start = "player_charge",
	play_ogryn_ability_taunt = "player_taunt",
	play_player_slide = "player_slide",
	play_ogryn_ability_taunt_husk = "player_taunt",
	play_player_slide_husk = "player_slide",
	play_veteran_ability_shout = "player_shout",
	play_veteran_ability_shout_husk = "player_shout",
	play_veteran_ability_stealth_on = "player_stealth",
	play_player_ability_veteran_killshot_stance_on = "player_killshot",
	play_psyker_ability_shout = "player_shriek",
	play_psyker_ability_shout_husk = "player_shriek",
	play_ability_psyker_shield_dome = "player_psyker_shield",
	play_ability_psyker_shield_dome_husk = "player_psyker_shield",
	play_ability_psyker_protectorate_shield = "player_psyker_shield",
	play_ability_psyker_protectorate_shield_husk = "player_psyker_shield",
	play_foley_player_netted_struggle = "player_netted",
	play_enemy_netgunner_net_pull = "player_netted",
	play_stub_revolver_p1_m2 = "player_revolver",
	play_teammate_died = "player_death",
	play_medpack_deploy = "player_medpack",
	play_syringe_stab_self = "player_stim",
	play_syringe_heal_self = "player_stimheal",
	play_explosion_grenade_frag = "player_frag",
	play_explosion_grenade_krak = "player_krak",
	play_explosion_grenade_smoke = "player_smoke",
	play_explosion_grenade_shock = "player_stun",
	play_explosion_grenade_flame = "player_fire",
	play_explosion_grenade_frag_ogryn = "player_bigfrag",
	melee_hits_blunt_heavy_ogryn = "player_ogryn_blunt",
	play_elite_killed = "elite_killed",
	play_special_killed = "special_killed",
	play_ability_ogryn_speshul_ammo = "ogryn_barrage",
	play_ability_zealot_maniac_dash_enter = "zealot_dash",
	play_ability_gunslinger_on = "psyker_gaze",
	play_shotgun_reload_pull = "shotgun_pump",
	play_shotgun_reload_push = "shotgun_pump",
	play_shotgun_reload_insert_ammo_special_03 = "shotgun_special",
	play_weapon_shotgun_human_reload_insert_ammo = "shotgun_reload",
	play_shotgun_p1_m3 = "shotgun_fire",
	play_force_shield_block = "force_block",
	thumper_shotgun_open = "rumbler_reload",
	thumper_shotgun_insert = "rumbler_reload",
	play_ogryn_thumper_p1_m2 = "rumbler_shot",
	play_ogryn_gauntlet_fire = "gauntlet_shot",
	play_explosion_refl_gen = "explosion_echo",
	play_player_ability_adamant_damage_on = "arby_stance",
	play_player_ability_adamant_charge = "arby_charge",
	play_adamant_shield_maul_special_attack = "arby_shieldblast",
	play_adamant_dog_vce_breath_loop_01 = "dog_breath",
	play_companion_bite_flesh = "dog_attack",
	play_adamant_dog_vce_attack_01 = "dog_jump",
	play_backstab_indicator_ranged = "ranged_indicator",
	play_shotgun_p4_reload_pull = "arby_pump",
	play_shotgun_p4_reload_release = "arby_pump",
	play_shotgun_p4_m1 = "arby_shotgun_fire",
	play_player_ability_adamant_dog_explosion = "dog_explosion",
	play_2h_forcesword_ability_charge_1 = "forcesword_charge",
	play_2h_forcesword_ability_charge_2 = "forcesword_charge",
	play_2h_forcesword_ability_charge_3 = "forcesword_charge",
	play_psyker_smite_fire = "staff_fire",
	play_explosion_force_sml = "staff_impact",
	play_psyker_warp_charge_overload_start = "warp_explosion",
	play_warp_charge_build_up_critical = "warp_critical",
	play_psyker_male_a__vce_scream_long = "scream_silencer",
	play_psyker_male_b__vce_scream_long = "scream_silencer",
	play_psyker_male_c__vce_scream_long = "scream_silencer",
	play_psyker_female_a__vce_scream_long = "scream_silencer",
	play_psyker_female_b__vce_scream_long = "scream_silencer",
	play_psyker_female_c__vce_scream_long = "scream_silencer",
	play_psyker_male_a__vce_hurt_heavy = "scream_silencer",
	play_psyker_male_b__vce_hurt_heavy = "scream_silencer",
	play_psyker_male_c__vce_hurt_heavy = "scream_silencer",
	play_psyker_female_a__vce_hurt_heavy = "scream_silencer",
	play_psyker_female_b__vce_hurt_heavy = "scream_silencer",
	play_psyker_female_c__vce_hurt_heavy = "scream_silencer",
	play_player_ability_broker_rage_start = "ganger_rage",
	play_player_ability_broker_rage_stop = "ganger_rage",
	play_player_ability_broker_focus_start = "ganger_focus",
	play_player_ability_broker_focus_stop = "ganger_focus",

	-- DOG
	play_enemy_chaos_hound_vce_leap = "chaos_hound_jump",
	play_enemy_chaos_hound_vce_growl = "chaos_hound_growl",
	play_enemy_chaos_hound_hurt = "chaos_hound_hurt",
	sfx_growl_probability = "chaos_hound_growl",
	play_enemy_chaos_hound_vce_bark = "chaos_hound_bark",
	play_chaos_hound_spawn_stinger_circumstance = "chaos_hound_group",
	play_enemy_chaos_hound_bite = "chaos_hound_maul",

	-- FLAMER
	--play_minion_flamethrower_green_start = "cultist_flamer_flame"

	-- NETGUNNER
	play_weapon_netgunner_wind_up = "renegade_netgunner_attack",
	
	-- POX BOMBER
	play_minion_poxwalker_bomber_wind_up = "pox_bomber_wind_up",
	play_enemy_combat_poxwalker_bomber_beep_loop = "pox_bomber_tick",
	play_explosion_bomber = "pox_bomber_explosion",
	
	-- RADIO OPERATOR
	play_enemy_radio_operator_stinger = "renegade_radio_operator_stinger",
	
	-- HORDE WARNING
	play_signal_horde_poxwalkers_2d = "horde_incoming_warning",
	play_minion_horde_poxwalker_ambush_2d = "horde_incoming_warning",
	
	-- REAPER
	play_enemy_chaos_ogryn_heavy_gunner__death_vce = "chaos_ogryn_gunner_death",
	play_enemy_chaos_ogryn_heavy_gunner__hurt_vce = "chaos_ogryn_gunner_hurt",
	play_chaos_ogryn_heavy_gunner_into_aim = "chaos_ogryn_gunner_attack",
	play_enemy_chaos_ogryn_heavy_gunner__melee_attack_vce = "chaos_ogryn_gunner_melee",
	
	-- PLASMA GUNNER
	play_minion_plasmapistol_charge = "renegade_plasma_gunner_charge",
	
	-- RENEGADE GRENADIER
	play_minion_grenadier_fire_grenade_fuse = "renegade_grenadier_fuse",
	play_explosion_grenade_flame_minion = "renegade_grenadier_explosion",
	play_traitor_guard_grenadier_footsteps = "renegade_grenadier_footsteps",
	play_traitor_guard_grenadier_pull_sprint = "renegade_grenadier_ready",
}


local get_sound = function(sound_table)
	local random_sound = sound_table[math.random(1, #sound_table)]
	return random_sound
end

local VOLUME_OVERRIDE = {
    play_stub_revolver_p1_m2 = 40,
	play_ability_ogryn_charge_start = 200,
	play_ogryn_ability_taunt = 200,
	play_ability_psyker_protectorate_shield_husk = 80,
	play_explosion_grenade_flame = 70,
	melee_hits_blunt_heavy_ogryn = 40,
	play_ability_gunslinger_on = 150,
	play_enemy_radio_operator_stinger = 50,
	play_minion_horde_poxwalker_ambush_2d = 200,
	play_signal_horde_poxwalkers_2d = 200,
	thumper_shotgun_open = 40,
	play_adamant_dog_vce_breath_loop_01 = 90,
	play_companion_bite_flesh = 100,
	play_shotgun_p4_reload_pull = 75,
	play_shotgun_p4_reload_release = 75,
	play_chaos_ogryn_heavy_gunner_into_aim = 30,
	play_enemy_chaos_ogryn_heavy_gunner__death_vce = 80,
	play_enemy_chaos_ogryn_heavy_gunner__hurt_vce = 75,
	play_weapon_netgunner_wind_up = 25,
	play_2h_forcesword_ability_charge_2 = 0,
	play_2h_forcesword_ability_charge_3 = 0,
	play_minion_plasmapistol_charge = 25,
	play_psyker_warp_charge_overload_start = 100,
	play_warp_charge_build_up_critical = 10,
	play_player_ability_broker_rage_start = 70,
	play_player_ability_broker_rage_stop = 30,
	play_player_ability_broker_focus_start = 70,
	play_player_ability_broker_focus_stop = 70,
}

local ongoing_sounds = {}

local replace_audio = function(sound_table, position_or_unit_or_id, source_file) 
	local sound = get_sound(sound_table)
	if position_or_unit_or_id and type(position_or_unit_or_id) == "number" then
		position_or_unit_or_id = nil
	end
	if ongoing_sound_replacements[source_file] then
		if ongoing_sounds[ongoing_sound_replacements[source_file]] then
			Audio.stop_file(ongoing_sounds[ongoing_sound_replacements[source_file]])
			ongoing_sounds[source_file] = nil
		end
	end
	local volume = VOLUME_OVERRIDE[source_file] or 100		
	ongoing_sounds[source_file] = Audio.play_file(sound, {audio_type = "sfx",volume = volume, track_status = function() ongoing_sounds[source_file] = nil end}, position_or_unit_or_id, 0.02, 8, 80)
	return false
end

local enemy_wwise_path = "wwise/events/minions/"
local override_paths = {
	play_chaos_hound_spawn_stinger_circumstance = "wwise/events/minions/",
	play_player_combat_experience_catapulted = "wwise/events/player/",
	play_ability_zealot_bolstering_prayer = "wwise/events/player/",
	play_ability_ogryn_charge_start = "wwise/events/player/",
	play_ogryn_ability_taunt = "wwise/events/player/",
	play_player_slide = "wwise/events/player/",
	play_ogryn_ability_taunt_husk = "wwise/events/player/",
	play_player_slide_husk = "wwise/events/player/",
	play_hud_player_states_mutant_charger_downed_husk = "wwise/events/player/",
	play_veteran_ability_shout = "wwise/events/player/",
	play_veteran_ability_shout_husk = "wwise/events/player/",
	play_veteran_ability_stealth_on = "wwise/events/player/",
	play_player_ability_veteran_killshot_stance_on = "wwise/events/player/",
	play_psyker_ability_shout = "wwise/events/player/",
	play_psyker_ability_shout_husk = "wwise/events/player/",
	play_ability_psyker_shield_dome = "wwise/events/player/",
	play_ability_psyker_shield_dome_husk = "wwise/events/player/",
	play_ability_psyker_protectorate_shield = "wwise/events/player/",
	play_ability_psyker_protectorate_shield_husk = "wwise/events/player/",
	play_foley_player_netted_struggle = "wwise/events/player/",
	play_enemy_netgunner_net_pull = "wwise/events/weapon/",
	play_stub_revolver_p1_m2 = "wwise/events/weapon/",
	play_teammate_died = "wwise/events/player/",
	play_medpack_deploy = "wwise/events/player/",
	play_syringe_stab_self = "wwise/events/player/",
	play_syringe_heal_self = "wwise/events/player/",
	play_explosion_grenade_frag = "wwise/events/weapon/",
	play_explosion_grenade_krak = "wwise/events/weapon/",
	play_explosion_grenade_smoke = "wwise/events/weapon/",
	play_explosion_grenade_shock = "wwise/events/weapon/",
	play_explosion_grenade_flame = "wwise/events/weapon/",
	play_explosion_grenade_frag_ogryn = "wwise/events/weapon/",
	melee_hits_blunt_heavy_ogryn = "wwise/events/weapon/",
	play_elite_killed = "wwise/events/player/",
	play_special_killed = "wwise/events/player/",
	play_ability_ogryn_speshul_ammo = "wwise/events/player/",
	play_ability_zealot_maniac_dash_enter = "wwise/events/player/",
	play_ability_gunslinger_on = "wwise/events/player/",
	play_shotgun_p1_m3 = "wwise/events/weapon/",
	play_shotgun_reload_insert_ammo_special_03 = "wwise/events/weapon/",
	play_shotgun_reload_pull = "wwise/events/weapon/",
	play_shotgun_reload_push = "wwise/events/weapon/",
	play_weapon_shotgun_human_reload_insert_ammo = "wwise/events/weapon/",
	play_force_shield_block = "wwise/events/weapon/",
	thumper_shotgun_insert = "wwise/events/weapon/",
	thumper_shotgun_open = "wwise/events/weapon/",
	play_ogryn_thumper_p1_m2 = "wwise/events/weapon/",
	play_ogryn_gauntlet_fire = "wwise/events/weapon/",
	play_explosion_refl_gen = "wwise/events/weapon/",
	play_player_ability_adamant_damage_on = "wwise/events/player/",
	play_player_ability_adamant_charge = "wwise/events/player/",
	play_adamant_shield_maul_special_attack = "wwise/events/weapon/",
	play_adamant_dog_vce_breath_loop_01 = "wwise/events/player/",
	play_companion_bite_flesh = "wwise/events/weapon/",
	play_adamant_dog_vce_attack_01 = "wwise/events/player/",
	play_backstab_indicator_ranged = "wwise/events/player/",
	play_shotgun_p4_reload_pull = "wwise/events/weapon/",
	play_shotgun_p4_reload_release = "wwise/events/weapon/",
	play_shotgun_p4_m1 = "wwise/events/weapon/",
	play_player_ability_adamant_dog_explosion = "wwise/events/player/",
	play_2h_forcesword_ability_charge_1 = "wwise/events/weapon/",
	play_2h_forcesword_ability_charge_2 = "wwise/events/weapon/",
	play_2h_forcesword_ability_charge_3 = "wwise/events/weapon/",
	play_psyker_smite_fire = "wwise/events/weapon/",
	play_minion_plasmapistol_charge = "wwise/events/weapon/",
	play_explosion_force_sml = "wwise/events/weapon/",
	play_psyker_warp_charge_overload_start = "wwise/events/player/",
	play_warp_charge_build_up_critical = "wwise/events/player/",
	play_psyker_male_a__vce_scream_long = "wwise/events/player/",
	play_psyker_male_b__vce_scream_long = "wwise/events/player/",
	play_psyker_male_c__vce_scream_long = "wwise/events/player/",
	play_psyker_female_a__vce_scream_long = "wwise/events/player/",
	play_psyker_female_b__vce_scream_long = "wwise/events/player/",
	play_psyker_female_c__vce_scream_long = "wwise/events/player/",
	play_psyker_male_a__vce_hurt_heavy = "wwise/events/player/",
	play_psyker_male_b__vce_hurt_heavy = "wwise/events/player/",
	play_psyker_male_c__vce_hurt_heavy = "wwise/events/player/",
	play_psyker_female_a__vce_hurt_heavy = "wwise/events/player/",
	play_psyker_female_b__vce_hurt_heavy = "wwise/events/player/",
	play_psyker_female_c__vce_hurt_heavy = "wwise/events/player/",
	play_minion_grenadier_fire_grenade_fuse = "wwise/events/weapon/",
	play_explosion_grenade_flame_minion = "wwise/events/weapon/",
	loc_enemy_grenadier_a__spawned_01 = "wwise/externals/",
	loc_enemy_grenadier_a__spawned_02 = "wwise/externals/",
	loc_enemy_grenadier_a__spawned_03 = "wwise/externals/",
	loc_enemy_grenadier_a__spawned_04 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_01 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_02 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_03 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_04 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_05 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_06 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_07 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_08 = "wwise/externals/",
	loc_enemy_grenadier_a__throwing_grenade_09 = "wwise/externals/",
	play_player_ability_broker_rage_start = "wwise/events/player/",
	play_player_ability_broker_rage_stop = "wwise/events/player/",
	play_player_ability_broker_focus_start = "wwise/events/player/",
	play_player_ability_broker_focus_stop = "wwise/events/player/",
	--play_minion_flamethrower_green_start = "wwise/events/weapon/"
}

local SOURCE_ID_TO_UNIT_LOOKUP = {}
local CUSTOM_COOLDOWNS = {
	play_ability_zealot_bolstering_prayer = 10,
	play_explosion_grenade_flame = 10,
	play_ability_zealot_maniac_dash_enter = 2,
	play_enemy_radio_operator_stinger = 30,
	play_signal_horde_poxwalkers_2d = 30,
	play_minion_horde_poxwalker_ambush_2d = 30,
	play_enemy_chaos_hound_bite = 10,
	play_force_shield_block = 0.1,
	play_adamant_dog_vce_breath_loop_01 = 3,
	play_adamant_dog_vce_attack_01 = 2,
	play_enemy_mutant_charger_smash_ogryn = 3,
	play_warp_charge_build_up_critical = 3,
	play_psyker_warp_charge_overload_start = 3,
	play_player_ability_adamant_charge = 3,
	play_player_ability_broker_rage_start = 10,
}

local CURRENT_COOLDOWNS = {}
mod.on_all_mods_loaded = function()
	Audio = get_mod("Audio")
	mod:hook(WwiseWorld, "make_manual_source", function(func, wwise_world, unit, ...)
		local source_id = func(wwise_world, unit, ...)
		SOURCE_ID_TO_UNIT_LOOKUP[source_id] = unit
		return source_id
	end)

	for i=1, #enemies do
		local enemy_name = enemies[i]
		local enabled_setting_name = enemy_name .. "_enabled"
		if mod:get(enabled_setting_name) then
			local sound_replacements = enemy_sound_replacements[enemy_name]
			if sound_replacements then
				for source_file, replacement_table in pairs(sound_replacements) do
					if not options_categories[source_file] or mod:get(options_categories[source_file]) then
						local path = (override_paths[source_file] or enemy_wwise_path or "")
						path = path .. source_file
						Audio.hook_sound(path, function(sound_type, sound_name, delta, position_or_unit_or_id, optional_a, optional_b)
							local t = Managers.time:time("main")
							local cooldown = CUSTOM_COOLDOWNS[source_file]
							if cooldown then
								local current_cooldown = CURRENT_COOLDOWNS[source_file]
								if current_cooldown and t < current_cooldown then
									return true
								elseif not current_cooldown then
									CURRENT_COOLDOWNS[source_file] = t + cooldown
								elseif current_cooldown and t >= current_cooldown then
									CURRENT_COOLDOWNS[source_file] = t + cooldown
								end
							end

							--print(sound_type, sound_name, delta, position_or_unit_or_id, #replacement_table, optional_a, optional_b)
							if position_or_unit_or_id and type(position_or_unit_or_id) == "number" or optional_a and type(optional_a) == "number" then
								local unit = SOURCE_ID_TO_UNIT_LOOKUP[position_or_unit_or_id or optional_a]
								if unit then
									position_or_unit_or_id = unit
								end
							end
							if #replacement_table > 0 and (delta == nil or delta > 0.2) then
								local should_replace = replace_audio(replacement_table, position_or_unit_or_id, source_file)
								return should_replace
							elseif #replacement_table == 0 then
								return false
							end
							return true
						end)
					end
				end
			end
		end
	end
end
