return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`HealthScaling` encountered an error loading the Darktide Mod Framework.")

		new_mod("HealthScaling", {
			mod_script       = "HealthScaling/scripts/mods/HealthScaling/HealthScaling",
			mod_data         = "HealthScaling/scripts/mods/HealthScaling/HealthScaling_data",
			mod_localization = "HealthScaling/scripts/mods/HealthScaling/HealthScaling_localization",
		})
	end,
	packages = {},
}
