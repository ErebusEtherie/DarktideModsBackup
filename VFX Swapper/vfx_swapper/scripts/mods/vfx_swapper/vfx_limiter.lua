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
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_crit_trail"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_charged_muzzle_crit"] = "lasgun_vfx",
	["content/fx/particles/weapons/rifles/lasgun/lasgun_chargefull"] = "lasgun_vfx",
	["content/fx/particles/weapons/foce_sword/forcesword_2h_stage2_loop"] = "voidstrike_explosion_vfx",
	["content/fx/particles/screenspace/player_screen_broker_stimm_syringe"] = "scum_stimm_screen",
	["content/fx/particles/screenspace/screen_rage_persistant"] = "scum_rampage_screen",
	["content/fx/particles/screenspace/screen_broker_punk_rage"] = "scum_rampage_screen",
	["content/fx/particles/impacts/flesh/gib_flesh_bits_01"] = "poxwalker_vfx",
	["content/fx/particles/impacts/flesh/poxwalker_maggots_small_01"] = "poxwalker_vfx",
	["content/fx/particles/weapons/rifles/arc_rifle/arc_rifle_beamlinger"] = "arc_vfx",
	["content/fx/particles/weapons/rifles/galvanic/galvanic_rifle_muzzle"] = "galv_vfx",
	["content/fx/particles/weapons/rifles/arc_rifle/arc_rifle_lightning"] = "arc_vfx",

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
        return
    end

	return func(world, particle_name, ...)
end)
