local mod = get_mod("AudioReplacer")

local mod_data = {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	localize = false,
}

mod_data.options = {
	widgets = {
		{
			setting_id  = "cultist_mutant_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "cultist_mutant_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "cultist_mutant_spawn",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "cultist_mutant_grunts",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "cultist_mutant_charge",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "cultist_mutant_punch",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "cultist_mutant_grab",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "chaos_hound_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "chaos_hound_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_hound_bark",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_hound_jump",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_hound_growl",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_hound_hurt",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_hound_group",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_hound_maul",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "renegade_netgunner_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "renegade_netgunner_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "renegade_netgunner_attack",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "pox_bomber_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "pox_bomber_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "pox_bomber_tick",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "pox_bomber_wind_up",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "pox_bomber_explosion",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		-- {
		-- 	setting_id  = "cultist_flamer_settings",
		-- 	type        = "group",
		-- 	sub_widgets = {
		-- 		{
		-- 			setting_id    = "cultist_flamer_enabled",
		-- 			type          = "checkbox",
		-- 			default_value = false,
		-- 			sub_widgets   = { --[[...]] } -- optional
		-- 		},
		-- 		{
		-- 			setting_id    = "cultist_flamer_flame",
		-- 			type          = "checkbox",
		-- 			default_value = false,
		-- 			sub_widgets   = { --[[...]] } -- optional
		-- 		},
		-- 	}
		-- },
		{
			setting_id  = "player_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "player_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_catapult",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_relic",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_charge",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_taunt",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_slide",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_shout",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_psyker_shield",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_netted",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_killshot",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_stealth",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_death",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_shriek",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_medpack",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_stim",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_stimheal",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_frag",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_krak",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_smoke",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_stun",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_fire",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_bigfrag",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "elite_killed",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "special_killed",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "ogryn_barrage",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "zealot_dash",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "psyker_gaze",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "arby_stance",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "arby_charge",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "ranged_indicator",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "warp_explosion",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "warp_critical",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "scream_silencer",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			},
		},
		{
			setting_id  = "adamant_dog_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "adamant_dog_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "dog_breath",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "dog_attack",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "dog_jump",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "dog_explosion",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "renegade_radio_operator_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "renegade_radio_operator_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "renegade_radio_operator_stinger",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "renegade_plasma_gunner_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "renegade_plasma_gunner_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "renegade_plasma_gunner_charge",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "chaos_ogryn_gunner_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "chaos_ogryn_gunner_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_ogryn_gunner_death",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_ogryn_gunner_attack",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_ogryn_gunner_hurt",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "chaos_ogryn_gunner_melee",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "renegade_grenadier_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "renegade_grenadier_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "renegade_grenadier_fuse",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "renegade_grenadier_footsteps",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "renegade_grenadier_explosion",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "renegade_grenadier_ready",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
		{
			setting_id  = "horde_ambush_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "horde_ambush_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "horde_incoming_warning",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
				{
			setting_id  = "weapon_settings",
			type        = "group",
			sub_widgets = {
				{
					setting_id    = "weapon_enabled",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_revolver",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "player_ogryn_blunt",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "shotgun_fire",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "shotgun_reload",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "shotgun_pump",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "shotgun_special",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "force_block",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "rumbler_reload",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "rumbler_shot",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "gauntlet_shot",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "explosion_echo",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "arby_shieldblast",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "arby_pump",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "arby_shotgun_fire",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "forcesword_charge",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "staff_fire",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
				{
					setting_id    = "staff_impact",
					type          = "checkbox",
					default_value = false,
					sub_widgets   = { --[[...]] } -- optional
				},
			}
		},
	}
}

return mod_data