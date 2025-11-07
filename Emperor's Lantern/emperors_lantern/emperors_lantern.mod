return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`emperors_lantern` encountered an error loading the Darktide Mod Framework.")

		new_mod("emperors_lantern", {
			mod_script       = "emperors_lantern/scripts/mods/emperors_lantern/emperors_lantern",
			mod_data         = "emperors_lantern/scripts/mods/emperors_lantern/emperors_lantern_data",
			mod_localization = "emperors_lantern/scripts/mods/emperors_lantern/emperors_lantern_localization",
		})
	end,
	packages = {},
}
