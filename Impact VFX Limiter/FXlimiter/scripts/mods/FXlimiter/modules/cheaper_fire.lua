local mod = get_mod("FXlimiter")

mod:hook_require("scripts/settings/liquid_area/liquid_area_templates", function(liquidareatemplates)
	if mod:get("cheaper_fire") then
	
		--fire barrel/flamer backpack explosion vfx is cheaper than the regular fire vfx so we use those
		liquidareatemplates.renegade_grenadier_fire_grenade.vfx_name_filled = "content/fx/particles/liquid_area/fire_lingering"
		liquidareatemplates.renegade_grenadier_fire_grenade.vfx_name_rim = "content/fx/particles/liquid_area/fire_lingering_edge"
		
		--replace flamer with cheaper
		liquidareatemplates.renegade_flamer_liquid_paint.vfx_name_filled = "content/fx/particles/liquid_area/fire_lingering"
		
		--cultist flamer
		liquidareatemplates.cultist_flamer_liquid_paint.vfx_name_filled = "content/fx/particles/liquid_area/fire_lingering_cultist"
		
		liquidareatemplates.interrupted_cultist_flamer_backpack.vfx_name_filled = "content/fx/particles/liquid_area/fire_lingering_cultist"
		liquidareatemplates.interrupted_cultist_flamer_backpack.vfx_name_rim = "content/fx/particles/enemies/cultist_flamer/cultist_flame_edge_ignition"
		
		--remove the dynamic lighting
		liquidareatemplates.renegade_flamer_liquid_paint.additional_unit_vfx = nil
		liquidareatemplates.cultist_flamer_liquid_paint.additional_unit_vfx = nil
	end
end)