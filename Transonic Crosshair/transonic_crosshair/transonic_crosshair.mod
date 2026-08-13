return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`transonic_crosshair` encountered an error loading the Darktide Mod Framework.")

		new_mod("transonic_crosshair", {
			mod_script       = "transonic_crosshair/scripts/mods/transonic_crosshair/transonic_crosshair",
			mod_data         = "transonic_crosshair/scripts/mods/transonic_crosshair/transonic_crosshair_data",
			mod_localization = "transonic_crosshair/scripts/mods/transonic_crosshair/transonic_crosshair_localization",
		})
	end,
	packages = {},
	version = "1.0.2",
}
