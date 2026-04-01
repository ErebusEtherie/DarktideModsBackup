local mod = get_mod("vfx_swapper")

mod.hey_im_the_slim_version = true

local blocked_vfx = {
	["content/fx/particles/explosions/frag_grenade_01"] = "frag_grenade_vfx",
	["content/fx/particles/weapons/grenades/krak_grenade/krak_grenade_explosion"] = "krak_grenade_vfx",
	["content/fx/particles/explosions/box_grenade_ogryn"] = "box_grenade_ogryn_vfx",
	["content/fx/particles/explosions/frag_grenade_ogryn"] = "frag_bomb_ogryn_vfx",
	["content/fx/particles/weapons/grenades/stumm_grenade/stumm_grenade"] = "stumm_grenade_vfx",
	["content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_initial_blast"] = "fire_grenade_vfx",
	["content/fx/particles/enemies/netgunner/netgunner_muzzle_flash"] = "netgunner_vfx",
	["content/fx/particles/player_buffs/player_netted_idle"] = "net_electric_vfx",
	["content/fx/particles/enemies/netgunner/netgunner_muzzle_flash"] = "net_electric_vfx",
	["content/fx/particles/weapons/force_staff/force_staff_explosion"] = "voidstrike_explosion_vfx",
	["content/fx/particles/abilities/psyker_smite_projectile_impact_01"] = "voidstrike_explosion_vfx",

	-- ["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_charged"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_crit_trail"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_chargefull"] = "lasgun_vfx",
	-- ["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger"] = "lasgun_vfx",

	
	-- ["content/fx/particles/weapons/rifles/lasgun/lasgun_beam"] = "lasgun_vfx",
	-- ["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_enemy_rifleman"] = "lasgun_vfx",
	-- ["content/fx/particles/weapons/rifles/lasgun/lasgun_placeholder_muzzlesmoke"] = "lasgun_vfx",
	-- ["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_01"] = "ritual_vfx",
	-- ["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_target_01"] = "ritual_vfx",
	-- ["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_off_left_hand"] = "ritual_vfx",
	-- ["content/fx/particles/enemies/chaos_mutator_daemonhost_shield"] = "ritual_vfx",
	-- ["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_off_hand"] = "ritual_vfx",
	-- ["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_02"] = "ritual_vfx",
	-- ["content/fx/particles/enemies/daemonhost/daemonhost_ambient_fog"] = "ritual_vfx",
	
	["content/fx/particles/screenspace/player_screen_broker_stimm_syringe"] = "scum_stimm_screen",
	["content/fx/particles/screenspace/screen_rage_persistant"] = "scum_rampage_screen",
	["content/fx/particles/screenspace/screen_broker_punk_rage"] = "scum_rampage_screen",
}

mod:hook("World", "create_particles", function(func, world, particle_name, position, rotation, scale, group)
	-- if particle_name then
	-- 	mod:echo(particle_name)
	-- end
	local setting_id = blocked_vfx[particle_name]

	if setting_id and mod:get(setting_id) then
		return 
	end

	return func(world, particle_name, position, rotation, scale, group)
end)