local mod = get_mod("SoundFilter")

local Promise = require("scripts/foundation/utilities/promise")
local MasterItems = require("scripts/backend/master_items")
local ItemPackage = require("scripts/foundation/managers/package/utilities/item_package")
local MinionVisualLoadout = require("scripts/utilities/minion_visual_loadout")
local Component = require("scripts/utilities/component")

mod:hook("WwiseWorld","trigger_resource_event",function(func, s, file_path, ...)
    if not mod:get("pointblankbarrage") and (file_path == "wwise/events/player/play_ability_ogryn_speshul_ammo" or file_path == "wwise/events/player/play_ability_ogryn_speshul_ammo") then return
    elseif not mod:get("ogtaunt") and (file_path == "wwise/events/player/play_ogryn_ability_taunt") then return
    elseif not mod:get("ogrynuke") and (file_path == "wwise/events/weapon/play_explosion_grenade_frag_ogryn" or file_path == "wwise/events/weapon/play_explosion_expedition_big_grenade" or file_path == "wwise/events/weapon/play_explosion_refl_huge") then return
    elseif not mod:get("bullrush") and (file_path == "wwise/events/player/play_ability_ogryn_charge_stop" or file_path == "wwise/events/player/play_ability_ogryn_charge_start") then return
    elseif not mod:get("pox_hound") and (file_path == "wwise/events/minions/play_enemy_chaos_hound_spawn") then return
    elseif not mod:get("playerdeath") and (file_path == "wwise/events/player/play_teammate_died_husk") then return
    elseif not mod:get("playerdown") and (file_path == "wwise/events/player/play_teammate_knocked_down_husk") then return
    elseif not mod:get("heartbeat") and (file_path == "wwise/events/player/play_player_experience_heart_beat" or file_path == "wwise/events/player/stop_player_experience_heart_beat") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_footstep_boots_medium" or file_path == "wwise/events/player/play_footstep_boots_medium_jump" or file_path == "wwise/events/player/play_footstep_boots_medium_ladder" or file_path == "wwise/events/player/play_footstep_ogryn_dodge") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_footstep_boots_medium_land" or file_path == "wwise/events/player/play_land_gen" or file_path == "wwise/events/player/play_ogryn_land_gen" or file_path == "wwise/events/player/play_footsteps_boots_dodge") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_upper_body_gen" or file_path == "wwise/events/player/play_footstep_ogryn_jump" or file_path == "wwise/events/player/play_footstep_prosthetic") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_footstep_ogryn_land" or file_path == "wwise/events/player/play_footstep_boots_heavy" or file_path == "wwise/events/player/play_footstep_prosthetic_heavy" or file_path == "wwise/events/player/play_footstep_prosthetic_mech") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_player_foley_subtle" or file_path == "wwise/events/player/play_upper_body_plate_leather" or file_path == "wwise/events/player/play_ogryn_upper_body_cloth" or file_path == "wwise/events/player/play_foley_hands_ladder_metal") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_foley_material_cloth" or file_path == "wwise/events/player/play_foley_material_leather" or file_path == "wwise/events/player/play_gear_light_gen_a" or file_path == "wwise/events/player/play_foley_material_metal") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_ogryn_upper_body_cloth_chains" or file_path == "wwise/events/player/play_ogryn_upper_body_gen" or file_path == "wwise/events/player/play_ogryn_upper_body_leather" or file_path == "wwise/events/player/play_ogryn_upper_body_armor_metal") then return
    elseif not mod:get("playerfootsteps") and (file_path == "wwise/events/player/play_ogryn_foley_subtle" or file_path == "wwise/events/player/play_gear_backpack_fire_foley" or file_path == "wwise/events/player/play_gear_chain_med" or file_path == "wwise/events/player/play_gear_skulls_med") then return
    elseif not mod:get("weapon_locomotion") and (file_path == "wwise/events/weapon/play_rifle_subtle" or file_path == "wwise/events/weapon/play_ammo_belt_locomotion" or file_path == "wwise/events/weapon/play_ammo_belt_locomotion" or file_path == "wwise/events/weapon/play_heavy_locomotion") then return
    elseif not mod:get("weapon_locomotion") and (file_path == "wwise/events/weapon/play_thumper_locomotion_metal_plate" or file_path == "wwise/events/weapon/play_smg_locomotion" or file_path == "wwise/events/weapon/play_rifle_locomotion" or file_path == "wwise/events/weapon/play_liquid_locomotion") then return
    elseif not mod:get("weapon_locomotion") and (file_path == "wwise/events/weapon/play_item_luggable_foley" or file_path == "wwise/events/weapon/play_weapon_plasma_gun_movement_foley" or file_path == "wwise/events/weapon/play_foley_plasma_rifle_heavy_movement") then return   
    elseif not mod:get("gascloud") and (file_path == "wwise/events/player/play_player_gas_enter" or file_path == "wwise/events/player/play_player_gas_exit") then return
    elseif not mod:get("beastvomit") and (file_path == "wwise/events/player/play_player_vomit_enter" or file_path == "wwise/events/player/play_player_vomit_exit" or file_path == "wwise/events/player/play_player_get_hit_vomit") then return
    elseif not mod:get("pox_hound_mutator") and (file_path == "wwise/events/minions/play_chaos_hound_spawn_stinger_circumstance") then return
    elseif not mod:get("mutant") and (file_path == "wwise/events/minions/play_minion_special_mutant_charger_spawn") then return
    elseif not mod:get("netgunner") and (file_path == "wwise/events/minions/play_minion_special_netgunner_spawn") then return
    elseif not mod:get("burster") and (file_path == "wwise/events/minions/play_minion_special_poxwalker_bomber_spawn") then return
    elseif not mod:get("bursterBeep") and (file_path == "wwise/events/minions/play_enemy_combat_poxwalker_bomber_beep_loop") then return
    elseif not mod:get("sniper_mutator") and (file_path == "wwise/events/minions/play_minion_special_sniper_spawn_circumstance") then return
    elseif not mod:get("rottenarmor") and (file_path == "wwise/events/minions/play_nurgle_corpse_explode_rotten" or file_path == "wwise/events/minions/play_nurgle_corpse_explode") then return
    elseif not mod:get("rottenarmor") and (file_path == "wwise/events/minions/play_aoe_gas_loop" or file_path == "wwise/events/minions/stop_aoe_gas_loop") then return
    elseif not mod:get("blightspreads") and (file_path == "wwise/events/minions/play_nurgle_corpse_explode_loop" or file_path == "wwise/events/minions/stop_nurgle_corpse_explode_loop") then return
    elseif not mod:get("contaminatedstimms") and (file_path == "wwise/events/player/play_syringe_heal_husk_confirm") then return
    elseif not mod:get("cranialcorruption") and (file_path == "wwise/events/weapon/play_nurgle_head_parasite_explode") then return
    elseif not mod:get("play_explosion_grenade_frag") and (file_path == "wwise/events/weapon/play_explosion_grenade_frag") then return
    elseif not mod:get("play_explosion_refl_gen") and (file_path == "wwise/events/weapon/play_explosion_refl_gen") then return
    elseif not mod:get("flamer_explosion") and (file_path == "wwise/events/weapon/play_explosion_flamer_tank") then return
    elseif not mod:get("flamer_fuse") and (file_path == "wwise/events/weapon/play_flamer_explosion_fuse" or file_path == "wwise/events/weapon/stop_flamer_explosion_fuse") then return
    elseif not mod:get("flamer_fuse") and (file_path == "wwise/events/weapon/play_flamer_explosion_fuse_flame" or file_path == "wwise/events/weapon/stop_flamer_explosion_fuse_flame") then return
    
    elseif not mod:get("signal") and (file_path == "wwise/events/minions/play_signal_horde_poxwalkers_2d" or file_path == "wwise/events/minions/play_signal_horde_poxwalkers_3d" or file_path == "wwise/events/minions/play_mid_event_horde_signal") then return
    elseif not mod:get("ambush") and (file_path == "wwise/events/minions/play_minion_horde_poxwalker_ambush_2d" or file_path == "wwise/events/minions/play_minion_horde_poxwalker_ambush_3d") then return
    elseif not mod:get("alarm") and (file_path == "wwise/events/minions/play_terror_event_alarm" or file_path == "wwise/events/minions/play_terror_event_alarm_monster_01") then return
    
    elseif not mod:get("chaos_spawn") and file_path == "wwise/events/minions/play_chaos_spawn_spawn" then return
    elseif not mod:get("plague_ogryn") and file_path == "wwise/events/minions/play_enemy_plague_ogryn_spawn" then return
    elseif not mod:get("beast_of_nurgle") and file_path == "wwise/events/minions/play_beast_of_nurgle_vce_happy_scream" then return
    
    elseif not mod:get("toughness") and (file_path == "wwise/events/player/play_player_get_hit_fire_toughness" or file_path == "wwise/events/player/play_player_get_hit_2d_corruption_tick_toughness" or file_path == "wwise/events/player/play_toughness_hits") then return
    elseif not mod:get("health") and (file_path == "wwise/events/player/play_player_get_hit_light_2d" or file_path == "wwise/events/player/play_player_get_hit_2d_corruption_tick_toughness" or file_path == "wwise/events/player/play_toughness_hits") then return
    elseif not mod:get("ping") and (file_path == "wwise/events/ui/play_smart_tag_2d_default" or file_path == "wwise/events/ui/play_smart_tag_location_default_enter" or file_path == "wwise/events/ui/play_smart_tag_location_threat_enter" or file_path == "wwise/events/ui/play_smart_tag_location_default_enter_others" or file_path == "wwise/events/ui/play_smart_tag_location_threat_enter_others") then return

    elseif not mod:get("concentration") and (file_path == "wwise/events/player/play_syringe_ability_start" or file_path == "wwise/events/player/play_syringe_ability_stop") then return
    elseif not mod:get("powerred") and (file_path == "wwise/events/player/play_syringe_power_start" or file_path == "wwise/events/player/play_syringe_power_stop") then return
    elseif not mod:get("celerity") and (file_path == "wwise/events/player/play_syringe_speed_start" or file_path == "wwise/events/player/play_syringe_speed_stop") then return
    elseif not mod:get("brokers") and (file_path == "wwise/events/player/play_syringe_broker_start" or file_path == "wwise/events/player/play_syringe_broker_stop") then return

    elseif not mod:get("bubble") and (file_path == "wwise/events/player/play_psyker_shield_dome_enter" or file_path == "wwise/events/player/play_psyker_shield_dome_exit") then return
    elseif not mod:get("bubble") and (file_path == "wwise/events/player/play_ability_psyker_shield_dome" or file_path == "wwise/events/player/stop_ability_psyker_shield_dome") then return
    elseif not mod:get("walls") and (file_path == "wwise/events/player/play_ability_psyker_protectorate_shield" or file_path == "wwise/events/player/stop_ability_psyker_protectorate_shield") then return
    elseif not mod:get("scrier") and (file_path == "wwise/events/player/play_ability_gunslinger_on" or file_path == "wwise/events/player/play_ability_gunslinger_off") then return
    elseif not mod:get("vent") and (file_path == "wwise/events/player/play_psyker_venting" or file_path == "wwise/events/player/stop_psyker_venting") then return
    elseif not mod:get("peril") and (file_path == "wwise/events/player/play_warp_charge_build_up_warning" or file_path == "wwise/events/player/play_warp_charge_build_up_critical") then return
    elseif not mod:get("ventingshriek") and (file_path == "wwise/events/player/play_psyker_ability_shout") then return
    
    elseif not mod:get("missile") and (file_path == "wwise/events/weapon/play_outlaw_missile_launcher_projectile_loop" or file_path == "wwise/events/weapon/stop_outlaw_missile_launcher_projectile_loop") then return
    elseif not mod:get("missile_fire") and (file_path == "wwise/events/weapon/play_outlaw_missile_launcher_fire" or file_path == "wwise/events/weapon/play_explosion_refl_gen" or file_path == "wwise/events/weapon/play_player_wpn_refl_heavy" or file_path == "wwise/events/weapon/play_grenade_surface_impact_large") then return
    elseif not mod:get("needles") and (file_path == "wwise/events/weapon/play_explosion_needle_pistol_mk1") then return
    elseif not mod:get("needles") and (file_path == "wwise/events/weapon/play_explosion_needle_pistol_mk2") then return
    elseif not mod:get("needles") and (file_path == "wwise/events/weapon/play_explosion_needle_pistol_mk3") then return
    
    elseif not mod:get("vet_stealth") and (file_path == "wwise/events/player/play_veteran_ability_stealth_on" or file_path == "wwise/events/player/play_veteran_ability_stealth_off") then return
    elseif not mod:get("vet_stance") and (file_path == "wwise/events/player/play_player_ability_veteran_killshot_stance_on" or file_path == "wwise/events/player/play_player_ability_veteran_killshot_stance_off") then return
    elseif not mod:get("vet_shout") and (file_path == "wwise/events/player/play_veteran_ability_shout") then return
    elseif not mod:get("vet_krakexp") and (file_path == "wwise/events/weapon/play_explosion_grenade_krak") then return
    elseif not mod:get("vet_krak_buildup") and (file_path == "wwise/events/weapon/play_krak_build_up" or file_path == "wwise/events/player/stop_krak_build_up") then return
    elseif not mod:get("vet_krak_stuck") and (file_path == "wwise/events/weapon/play_krak_stuck") then return
    elseif not mod:get("vet_smokexp") and (file_path == "wwise/events/weapon/play_explosion_grenade_smoke" or file_path == "wwise/events/weapon/play_grenade_projectile_loop_smoke" or file_path == "wwise/events/weapon/stop_grenade_projectile_loop_smoke") then return
    
    elseif not mod:get("zealot_stealth") and (file_path == "wwise/events/player/play_zealot_ability_invisible_on" or file_path == "wwise/events/player/play_zealot_ability_invisible_off") then return
    elseif not mod:get("zealot_passive") and (file_path == "wwise/events/player/play_ability_zealot_maniac_resist_death_on" or file_path == "wwise/events/player/play_ability_zealot_maniac_resist_death_off") then return
    elseif not mod:get("zealot_chorus_pulse") and (file_path == "wwise/events/player/play_ability_zealot_bolstering_prayer") then return
    elseif not mod:get("zealot_chorus_ambient") and (file_path == "wwise/events/player/play_ability_zealot_bolstering_prayer_idle") then return
    elseif not mod:get("zealot_charge") and (file_path == "wwise/events/player/play_ability_zealot_maniac_dash_enter" or file_path == "wwise/events/player/play_ability_zealot_maniac_dash_exit") then return
    elseif not mod:get("zealot_stunstorm_grenade") and (file_path == "wwise/events/weapon/play_explosion_grenade_shock" or file_path == "wwise/events/weapon/play_explosion_refl_gen") then return
    elseif not mod:get("zealot_immolation_grenade") and (file_path == "wwise/events/weapon/play_explosion_grenade_flame" or file_path == "wwise/events/weapon/play_explosion_refl_small" or file_path == "wwise/events/weapon/play_aoe_liquid_fire_loop" or file_path == "wwise/events/weapon/stop_aoe_liquid_fire_loop" ) then return

    elseif not mod:get("scum_rage") and (file_path == "wwise/events/player/play_player_ability_broker_rage_start" or file_path == "wwise/events/player/play_player_ability_broker_rage_stop") then return
    elseif not mod:get("scum_focus") and (file_path == "wwise/events/player/play_player_ability_broker_focus_start" or file_path == "wwise/events/player/play_player_ability_broker_focus_stop") then return
    elseif not mod:get("scum_stimm_field") and (file_path == "wwise/events/player/play_stimm_field_crate_deploy" or file_path == "wwise/events/player/play_stimm_field_crate_wave" or file_path == "wwise/events/player/stop_stimm_field_crate_wave") then return   
    elseif not mod:get("chemgrenade") and (file_path == "wwise/events/weapon/play_explosion_chem_grenade_player" or file_path == "wwise/events/weapon/play_explosion_refl_small" or file_path == "wwise/events/weapon/play_aoe_chem_loop" or file_path == "wwise/events/weapon/stop_aoe_chem_loop") then return
    elseif not mod:get("flashgrenade") and (file_path == "wwise/events/weapon/play_explosion_flash_player") then return
    
    elseif not mod:get("adamant_stance") and (file_path == "wwise/events/player/play_player_ability_adamant_damage_on" or file_path == "wwise/events/player/play_player_ability_adamant_damage_off") then return
    elseif not mod:get("nuncio_aquila") and (file_path == "wwise/events/player/play_buff_drone_buff_loop" or file_path == "wwise/events/player/stop_buff_drone_buff_loop") then return
    elseif not mod:get("nuncio_aquila") and (file_path == "wwise/events/player/play_buff_drone_engine_loop" or file_path == "wwise/events/player/stop_buff_drone_engine_loop") then return
    elseif not mod:get("adamant_charge") and (file_path == "wwise/events/player/play_player_ability_adamant_charge") then return
    elseif not mod:get("remote_detonation") and (file_path == "wwise/events/player/play_player_ability_adamant_dog_explosion") then return
    elseif not mod:get("remote_detonation_bark") and (file_path == "wwise/events/player/play_adamant_dog_vce_bark_01") then return
    elseif not mod:get("cyber_mastiff_footstep") and (file_path == "wwise/events/player/play_npc_dog_footstep_metal_foot" or file_path == "wwise/events/player/play_npc_dog_footstep_normal_foot") then return
    elseif not mod:get("adamantdog") and (file_path == "wwise/events/player/play_adamant_dog_vce_attack_loop_01" or file_path == "wwise/events/player/stop_adamant_dog_vce_attack_loop_01" or file_path == "wwise/events/player/play_adamant_dog_vce_breath_loop_01" or file_path == "wwise/events/player/stop_adamant_dog_vce_breath_loop_01") then return

    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_chain_lightning_hit" or file_path == "wwise/events/weapon/stop_psyker_chain_lightning_hit") then return
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_chain_lightning_grenade_charged" or file_path == "wwise/events/weapon/stop_psyker_chain_lightning_grenade_charged") then return
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_chain_lightning_grenade" or file_path == "wwise/events/weapon/stop_psyker_chain_lightning_grenade") then return
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_lightning_bolt_charge" or file_path == "wwise/events/weapon/stop_psyker_lightning_bolt_charge") then return
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_chain_lightning_grenade_jump" or file_path == "wwise/events/weapon/play_player_wpn_refl_plasma") then return
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_chain_lightning_grenade_push") then return
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_smite_charge" or file_path == "wwise/events/weapon/stop_psyker_smite_charge") then return 
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_chain_lightning_heavy" or file_path == "wwise/events/weapon/stop_psyker_chain_lightning_heavy") then return
    elseif not mod:get("smite") and (file_path == "wwise/events/weapon/play_psyker_chain_lightning" or file_path == "wwise/events/weapon/stop_psyker_chain_lightning") then return
    end
    return func(s, file_path, ...)
end)


mod:hook_require("scripts/settings/breed/breeds/chaos/chaos_poxwalker_bomber_sounds", function(sound_data )
    sound_data.events.footstep = "wwise/events/minions/play_plague_ogryn_footsteps_land"
    sound_data.events.run_breath = "wwise/events/minions/play_enemy_plague_ogryn_vce_run_noise"
end)