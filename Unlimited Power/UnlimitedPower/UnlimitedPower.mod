return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`UnlimitedPower` encountered an error loading the Darktide Mod Framework.")

		new_mod("UnlimitedPower", {
			mod_script       = "UnlimitedPower/scripts/mods/UnlimitedPower/UnlimitedPower",
			mod_data         = "UnlimitedPower/scripts/mods/UnlimitedPower/UnlimitedPower_data",
			mod_localization = "UnlimitedPower/scripts/mods/UnlimitedPower/UnlimitedPower_localization",
		})
	end,
	packages = {},
}
