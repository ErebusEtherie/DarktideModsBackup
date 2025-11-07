return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`QuietPsykhanium` encountered an error loading the Darktide Mod Framework.")

		new_mod("QuietPsykhanium", {
			mod_script       = "QuietPsykhanium/scripts/mods/QuietPsykhanium/QuietPsykhanium",
			mod_data         = "QuietPsykhanium/scripts/mods/QuietPsykhanium/QuietPsykhanium_data",
			mod_localization = "QuietPsykhanium/scripts/mods/QuietPsykhanium/QuietPsykhanium_localization",
		})
	end,
	packages = {},
}
