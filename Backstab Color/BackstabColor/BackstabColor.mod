return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BackstabColor` encountered an error loading the Darktide Mod Framework.")

		new_mod("BackstabColor", {
			mod_script       = "BackstabColor/scripts/mods/BackstabColor/BackstabColor",
			mod_data         = "BackstabColor/scripts/mods/BackstabColor/BackstabColor_data",
			mod_localization = "BackstabColor/scripts/mods/BackstabColor/BackstabColor_localization",
		})
	end,
	packages = {},
}
