local mod = get_mod("vfx_limiter")

local blocked_vfx = {
	["content/fx/particles/explosions/frag_grenade_01"] = "frag_grenade_vfx",
	["content/fx/particles/weapons/grenades/krak_grenade/krak_grenade_explosion"] = "krak_grenade_vfx",
	["content/fx/particles/explosions/box_grenade_ogryn"] = "box_grenade_ogryn_vfx",
	["content/fx/particles/explosions/frag_grenade_ogryn"] = "frag_bomb_ogryn_vfx",
	["content/fx/particles/weapons/grenades/stumm_grenade/stumm_grenade"] = "stumm_grenade_vfx",
	["content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_initial_blast"] = "fire_grenade_vfx",
	["content/fx/particles/enemies/netgunner/netgunner_muzzle_flash"] = "netgunner_vfx",
	["content/fx/particles/player_buffs/player_netted_idle"] = "net_elecric_vfx",
	["content/fx/particles/enemies/netgunner/netgunner_muzzle_flash"] = "net_elecric_vfx",
	["content/fx/particles/weapons/force_staff/force_staff_explosion"] = "voidstrike_explosion_vfx",
	["content/fx/particles/abilities/psyker_smite_projectile_impact_01"] = "voidstrike_explosion_vfx",
	
	["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_target_01"] = "ritual_vfx",
	["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_off_hand"] = "ritual_vfx",
	--["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_02"] = "ritual_vfx",
	["content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_off_left_hand"] = "ritual_vfx",
	--["content/fx/particles/enemies/chaos_mutator_daemonhost_shield"] = "ritual_vfx",
	--["content/fx/particles/enemies/daemonhost/daemonhost_ambient_fog"] = "ritual_vfx",
	
	["content/fx/particles/screenspace/player_screen_broker_stimm_syringe"] = "scum_stimm_screen",
	["content/fx/particles/screenspace/screen_rage_persistant"] = "scum_rampage_screen",
	["content/fx/particles/screenspace/screen_broker_punk_rage"] = "scum_rampage_screen",
	["content/fx/particles/weapons/pistols/needlepistol/needlepistol_explosion_primer_m2"] = "scum_сhem_explode",
}

local ritual_replacement = "content/fx/particles/impacts/flesh/blood_splatter_reduced_damage_01"

mod:hook("World", "create_particles", function(func, world, particle_name, position, rotation)
	local setting_id = blocked_vfx[particle_name]

	if particle_name == "content/fx/particles/enemies/cultist_ritualist/ritual_force_minions_heresy_01" then
		if mod:get("ritual_vfx") then
			particle_name = ritual_replacement
		end
	end

	if setting_id and mod:get(setting_id) and particle_name ~= ritual_replacement then
		return
	end
	
	--[[if string.find(particle_name, "blood") or string.find(particle_name, "bleed") or string.find(particle_name, "bleeding") then
		return
	end--]]
	
	--mod:echo(particle_name)
	return func(world, particle_name, position, rotation)
end)

mod:hook("HuskLiquidAreaExtension", "_set_liquid_filled", function(func, self, real_index)
	if mod:get("rotten_vfx") and self._area_template_name == "rotten_armor" then
		return
	end

	if self._area_template_name == "cultist_grenadier_gas" then
		self._vfx_name_filled = mod:get("replace_gas_vfx")
	end

	if self._area_template_name == "fire_grenade" then
		self._vfx_name_filled = mod:get("replace_immolation_vfx")
	end

	return func(self, real_index)
end)

mod:hook_safe("LiquidAreaExtension", "_set_filled", function(self, dt)
	if mod:get("rotten_vfx") and self._area_template_name == "rotten_armor" then
		self._time_to_remove = 0
	end

	if self._area_template_name == "cultist_grenadier_gas" then
		self._vfx_name_filled = mod:get("replace_gas_vfx")
	end

	if self._area_template_name == "fire_grenade" then
		self._vfx_name_filled = mod:get("replace_immolation_vfx")
	end
end)