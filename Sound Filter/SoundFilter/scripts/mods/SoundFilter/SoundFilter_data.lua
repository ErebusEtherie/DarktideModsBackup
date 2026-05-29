 local mod = get_mod("SoundFilter")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
        widgets = {
            {
                setting_id = "player_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "toughness", type = "checkbox", default_value = true, },
                    { setting_id = "health", type = "checkbox", default_value = true, },
                    { setting_id = "playerfootsteps", type = "checkbox", default_value = true, },
                    { setting_id = "weapon_locomotion", type = "checkbox", default_value = true, },
                    { setting_id = "ping", type = "checkbox", default_value = true, },
                    { setting_id = "playerdeath", type = "checkbox", default_value = true, },
                    { setting_id = "playerdown", type = "checkbox", default_value = true, },
                    { setting_id = "bursterBeep", type = "checkbox", default_value = true, },
                    { setting_id = "heartbeat", type = "checkbox", default_value = true, },
                    { setting_id = "gascloud", type = "checkbox", default_value = true, },
                    { setting_id = "beastvomit", type = "checkbox", default_value = true, },
                },
            },
            {
                setting_id = "explosion_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "play_explosion_grenade_frag", type = "checkbox", default_value = true, }, -- boxoboom, missile launcher, arbites grenade, shredder, gauntlet, rumbler
                    { setting_id = "play_explosion_refl_gen", type = "checkbox", default_value = true, }, -- poxbomber, explosive barrel, all above, gas mine, flamer explosion, airdrop bomb, valk missile, exp trap, stumm grenade, shredder, boombringer, krak, box, adamant grenade, 
                    { setting_id = "flamer_explosion", type = "checkbox", default_value = true, }, -- flamer tank explosion
                    { setting_id = "flamer_fuse", type = "checkbox", default_value = true, }, -- flamer fuse
                    { setting_id = "needles", type = "checkbox", default_value = true, },
                    { setting_id = "chemgrenade", type = "checkbox", default_value = true, },
                    { setting_id = "flashgrenade", type = "checkbox", default_value = true, },
                    { setting_id = "missile", type = "checkbox", default_value = true, },
                    { setting_id = "missile_fire", type = "checkbox", default_value = true, },
                    { setting_id = "remote_detonation", type = "checkbox", default_value = true, },
                    { setting_id = "vet_krakexp", type = "checkbox", default_value = true, },
                    { setting_id = "vet_krak_stuck", type = "checkbox", default_value = true, }, -- krak armor hit
                    { setting_id = "vet_krak_buildup", type = "checkbox", default_value = true, }, -- krak actual buildup/fuse
                    { setting_id = "vet_smokexp", type = "checkbox", default_value = true, },
                    { setting_id = "zealot_stunstorm_grenade", type = "checkbox", default_value = true, },
                    { setting_id = "zealot_immolation_grenade", type = "checkbox", default_value = true, },
                    { setting_id = "ogrynuke", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "enemy_spawn_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "pox_hound", type = "checkbox", default_value = true, },
                    { setting_id = "pox_hound_mutator", type = "checkbox", default_value = true, },
                    { setting_id = "sniper_mutator", type = "checkbox", default_value = true, },
                    { setting_id = "mutant", type = "checkbox", default_value = true, },
                    { setting_id = "netgunner", type = "checkbox", default_value = true, },
                    { setting_id = "burster", type = "checkbox", default_value = true, },
                    { setting_id = "chaos_spawn", type = "checkbox", default_value = true, },
                    { setting_id = "plague_ogryn", type = "checkbox", default_value = true, },
                    { setting_id = "beast_of_nurgle", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "havoc_mutator_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "rottenarmor", type = "checkbox", default_value = true, },
                    { setting_id = "blightspreads", type = "checkbox", default_value = true, },
                    { setting_id = "contaminatedstimms", type = "checkbox", default_value = true, },
                    { setting_id = "cranialcorruption", type = "checkbox", default_value = true, },
                }
            },
			{
                setting_id = "horde_spawn_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "signal", type = "checkbox", default_value = true, },
                    { setting_id = "ambush", type = "checkbox", default_value = true, },
                    { setting_id = "alarm", type = "checkbox", default_value = true, },

                }
            },
            {
                setting_id = "stimm_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "concentration", type = "checkbox", default_value = true, },
                    { setting_id = "powerred", type = "checkbox", default_value = true, },
                    { setting_id = "celerity", type = "checkbox", default_value = true, },
                    { setting_id = "brokers", type = "checkbox", default_value = true, },

                }
            },
            {
                setting_id = "psyker_specific_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "peril", type = "checkbox", default_value = true, },
                    { setting_id = "vent", type = "checkbox", default_value = true, },
                    { setting_id = "bubble", type = "checkbox", default_value = true, },
                    { setting_id = "walls", type = "checkbox", default_value = true, },
                    { setting_id = "ventingshriek", type = "checkbox", default_value = true, },
                    { setting_id = "scrier", type = "checkbox", default_value = true, },
                    { setting_id = "smite", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "zealot_specific_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "zealot_stealth", type = "checkbox", default_value = true, },
                    { setting_id = "zealot_chorus_pulse", type = "checkbox", default_value = true, },
                    { setting_id = "zealot_chorus_ambient", type = "checkbox", default_value = true, },
                    { setting_id = "zealot_passive", type = "checkbox", default_value = true, },
                    { setting_id = "zealot_charge", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "veteran_specific_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "vet_stance", type = "checkbox", default_value = true, },
                    { setting_id = "vet_stealth", type = "checkbox", default_value = true, },
                    { setting_id = "vet_shout", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "ogryn_specific_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "pointblankbarrage", type = "checkbox", default_value = true, },
                    { setting_id = "bullrush", type = "checkbox", default_value = true, },
                    { setting_id = "ogtaunt", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "arbitrator_specific_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "adamant_stance", type = "checkbox", default_value = true, },
                    { setting_id = "adamant_charge", type = "checkbox", default_value = true, },
                    { setting_id = "nuncio_aquila", type = "checkbox", default_value = true, },
                    { setting_id = "cyber_mastiff_attack", type = "checkbox", default_value = true, },
                    { setting_id = "cyber_mastiff_footstep", type = "checkbox", default_value = true, },
                    { setting_id = "remote_detonation_bark", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "hivescum_specific_sounds",
                type = "group",
                sub_widgets = {
                    { setting_id = "scum_focus", type = "checkbox", default_value = true, },
                    { setting_id = "scum_rage", type = "checkbox", default_value = true, },
                    { setting_id = "scum_stimm_field", type = "checkbox", default_value = true, },
                }
            },
            
            
		}
	}
}
