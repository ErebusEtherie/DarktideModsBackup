return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Inventory2D` encountered an error loading the Darktide Mod Framework.")

		new_mod("Inventory2D", {
			mod_script       = "Inventory2D/main",
			mod_data         = "Inventory2D/mod_data",
			mod_localization = "Inventory2D/loc",
		})
	end,
	packages = {},
}
