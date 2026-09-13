return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`testing_utilities` encountered an error loading the Darktide Mod Framework.")

		new_mod("testing_utilities", {
			mod_script       = "testing_utilities/scripts/mods/testing_utilities/testing_utilities",
			mod_data         = "testing_utilities/scripts/mods/testing_utilities/testing_utilities_data",
			mod_localization = "testing_utilities/scripts/mods/testing_utilities/testing_utilities_localization",
		})
	end,
	packages = {},
}
