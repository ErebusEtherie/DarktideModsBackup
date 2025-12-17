return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`StimmSupplyRings` encountered an error loading the Darktide Mod Framework.")

		new_mod("StimmSupplyRings", {
			mod_script       = "StimmSupplyRings/scripts/StimmSupplyRings",
			mod_data         = "StimmSupplyRings/scripts/StimmSupplyRings_data",
			mod_localization = "StimmSupplyRings/scripts/StimmSupplyRings_localization",
		})
	end,
	packages = {},
}
