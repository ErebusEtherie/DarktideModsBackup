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
}

mod:hook("World", "create_particles", function(func, world, particle_name, position, rotation)
	local setting_id = blocked_vfx[particle_name]
	--mod:echo(particle_name)
	if setting_id and mod:get(setting_id) then
		return
	end

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