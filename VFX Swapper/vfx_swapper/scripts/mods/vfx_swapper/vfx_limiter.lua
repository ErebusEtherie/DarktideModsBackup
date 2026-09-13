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
	["content/fx/particles/weapons/force_staff/force_staff_explosion"] = "voidstrike_explosion_vfx",
	["content/fx/particles/abilities/psyker_smite_projectile_impact_01"] = "voidstrike_explosion_vfx",
	["content/fx/particles/impacts/weapons/force_staff/force_impact_01"] = "voidstrike_explosion_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_crit_trail"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_chargefull"] = "lasgun_vfx",
	["content/fx/particles/screenspace/player_screen_broker_stimm_syringe"] = "scum_stimm_screen",
	["content/fx/particles/screenspace/screen_rage_persistant"] = "scum_rampage_screen",
	["content/fx/particles/screenspace/screen_broker_punk_rage"] = "scum_rampage_screen",
	["content/fx/particles/impacts/flesh/gib_flesh_bits_01"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/poxwalker_maggots_small_01"] = "poxwalker_vfx",
	["content/fx/particles/weapons/rifles/arc_rifle/arc_rifle_beamlinger"] = "arc_vfx",
	["content/fx/particles/weapons/rifles/galvanic/galvanic_rifle_muzzle"] = "galv_vfx",
	["content/fx/particles/weapons/rifles/arc_rifle/arc_rifle_lightning"] = "arc_vfx",
	["content/fx/particles/weapons/grenades/chem_grenade/chem_grenade_player_initial_blast"] = "chem_grenade_vfx",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_ks"] = "plasma_muzzle",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_beam_linger"] = "plasma_beam",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_small"] = "plasma_vfx",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_medium"] = "plasma_vfx",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_charged_explosion_large"] = "plasma_vfx",
	["content/fx/particles/weapons/rifles/plasma_gun/plasma_muzzle_bfg"] = "plasma_muzzle",
	["content/fx/particles/impacts/flesh/blood_splatter_gib_torso_small_01"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/poxwalker_splatter_gib_torso_small_01"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/arc_lightning_gib_torso_small_01"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/gib_splatter_arc_lightning_01"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/protectorate_chainlightning_gib_torso_small_03"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/protectorate_chainlightning_gib_torso_small_02"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/protectorate_chainlightning_gib_torso_small_01"] = "poxwalker_vfx",
	["content/fx/particles/weapons/rifles/autogun/autogun_muzzle_crit"] = "autogun_vfx",
	["content/fx/particles/weapons/rifles/autogun/autogun_muzzle"] = "autogun_vfx",
	["content/fx/particles/weapons/rifles/autogun/autogun_muzzle_03"] = "autogun_vfx",
	["content/fx/particles/weapons/rifles/autogun/autogun_muzzle_3p"] = "autogun_vfx",
	["content/fx/particles/weapons/rifles/autogun/autogun_muzzle_03_crit"] = "autogun_vfx",
	["content/fx/particles/weapons/rifles/autogun/autogun_muzzle_02"] = "autogun_vfx",
	["content/fx/particles/weapons/flame_staff/psyker_flame_staff_charge"] = "kill_flamer_vfx",
	["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_target_01"] = "ritual_vfx",
	["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_01"] = "ritual_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_chargeup"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_standard_linger"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger_bfg"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger"] = "lasgun_vfx",
	["content/fx/particles/weapons/swords/forcesword/psyker_block"] = "forcesword_vfx",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_wisps_fingerstips"] = "forcesword_vfx",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_stage2_loop"] = "forcesword_vfx",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_charge"] = "forcesword_vfx",
	["content/fx/particles/impacts/weapons/force_sword/force_sword_stuck_looping"] = "forcesword_vfx",
}
local blocked_vfx_active = {}
local _any_blocked = false

local function refresh_blocked_vfx_cache()
    _any_blocked = false
    for particle_name, setting_id in pairs(blocked_vfx) do
        local active = mod:get(setting_id) or false
        blocked_vfx_active[particle_name] = active
        if active then _any_blocked = true end
    end
end

mod._refresh_vfx_limiter_cache = refresh_blocked_vfx_cache

refresh_blocked_vfx_cache()

mod:hook("World", "create_particles", function(func, world, particle_name, ...)
	if _any_blocked and blocked_vfx_active[particle_name] then
		local id = func(world, particle_name, ...)
		World.stop_spawning_particles(world, id)
		return id
	end

	return func(world, particle_name, ...)
end)
