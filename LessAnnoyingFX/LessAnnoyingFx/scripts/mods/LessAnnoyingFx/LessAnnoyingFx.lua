local mod = get_mod("LessAnnoyingFx")

mod.enable_debug_mode = true
--mod.no_strobe="content/fx/particles/abilities/chainlightning/protectorate_chainlightning_attack_looping_no_target"
local function update()

end
mod:hook_require("scripts/settings/particles/player_character_particle_aliases", function(particles)
	print("LessAnnoyingFx:Hooking into player_character_particle_aliases ")
	--skip trail by making it not meet the "switch" condition as the "skip" condition doesn't exist.
	if mod:get("setting_power_trail") then
		particles.sweep_trail_extra.switch[2] = "skip" -- "special_active"	
		print("LessAnnoyingFx:Skipping Power Weapon Trail")
	else
		particles.sweep_trail_extra.switch[2] = "special_active" -- "special_active"	
		print("LessAnnoyingFx:Power Weapon Trail Default")
	end

	local no_strobe_fx ="content/fx/particles/abilities/chainlightning/protectorate_chainlightning_attack_looping_no_target"
	if mod:get("setting_psyker_smite") then
		particles.chain_lightning_link.particles.psyker_chain_lightning.low = no_strobe_fx
		particles.chain_lightning_link.particles.psyker_chain_lightning.high = no_strobe_fx
		--particles.chain_lightning_impact.particles.psyker_chain_lightning="content/fx/particles/abilities/chainlightning/protectorate_chainlightning_attack_looping_no_target"

		print("LessAnnoyingFx:Changing Pysker Smite to no-strobe")
	else
		particles.chain_lightning_link.particles.psyker_chain_lightning.low =
		"content/fx/particles/abilities/chainlightning/protectorate_chainlightning_attack_looping_01"
		particles.chain_lightning_link.particles.psyker_chain_lightning.high =
		"content/fx/particles/abilities/chainlightning/protectorate_chainlightning_bfg_01"
		print("LessAnnoyingFx:Setting Pysker Smite to Defaults")
	end

	--no_strobe_fx = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_01"
	if mod:get("setting_psyker_lightning") then
		particles.chain_lightning_link.particles.forcestaff_p3_m1.low = no_strobe_fx
		particles.chain_lightning_link.particles.forcestaff_p3_m1.mid = no_strobe_fx
		particles.chain_lightning_link.particles.forcestaff_p3_m1.high = no_strobe_fx
		print("LessAnnoyingFx:Changing Pysker Lightning Staff to no-strobe")
	else
		particles.chain_lightning_link.particles.forcestaff_p3_m1.low = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_01"
		particles.chain_lightning_link.particles.forcestaff_p3_m1.mid = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_02"
		particles.chain_lightning_link.particles.forcestaff_p3_m1.high = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_03"
		print("LessAnnoyingFx:Setting Pysker Lightning Staff to Defaults")
	end
end)

mod.on_setting_changed = function()
	
end
-- chain_lightning_link = {
-- 	switch = {
-- 		"wielded_weapon_template",
-- 		"power"
-- 	},
-- 	particles = {
-- 		default = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_03",
-- 		forcestaff_p3_m1 = {
-- 			no_target = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_01",
-- 			mid = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_02",
-- 			low = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_01",
-- 			high = "content/fx/particles/weapons/force_staff/force_staff_chainlightning_attacking_link_03"
-- 		},
-- 		psyker_chain_lightning = {
-- 			no_target = "content/fx/particles/abilities/chainlightning/protectorate_chainlightning_attack_looping_no_target",
-- 			high = "content/fx/particles/abilities/chainlightning/protectorate_chainlightning_bfg_01",
-- 			low = "content/fx/particles/abilities/chainlightning/protectorate_chainlightning_attack_looping_01"
-- 		}
-- 	}
-- },
mod:command("TraceHooks", "TraceHooks", function()
	mod:io_dofile("LessAnnoyingFx/scripts/mods/LessAnnoyingFx/TraceHooks")
end)

--World.create_particles(world, effect_name, position, rotation, scale, optional_particle_group_id)
-- mod:hook_safe("World", "create_particles", function(world, effect_name, position, rotation, scale, optional_particle_group_id)
-- 	if (string.find(effect_name,"weapons")~=nil or string.find(effect_name,"abilities")~=nil) then
-- 		print(debug.traceback())
-- 		print(effect_name)
-- 	end

-- end)
