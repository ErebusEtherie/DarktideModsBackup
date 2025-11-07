return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`HeatPercentage` encountered an error loading the Darktide Mod Framework.")

		new_mod("HeatPercentage", {
			mod_script       = "HeatPercentage/scripts/mods/HeatPercentage/HeatPercentage",
			mod_data         = "HeatPercentage/scripts/mods/HeatPercentage/HeatPercentage_data",
			mod_localization = "HeatPercentage/scripts/mods/HeatPercentage/HeatPercentage_localization",
		})
	end,
	packages = {},
}
