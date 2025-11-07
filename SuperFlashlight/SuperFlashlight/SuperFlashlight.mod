return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SuperFlashlight` encountered an error loading the Darktide Mod Framework.")

		new_mod("SuperFlashlight", {
			mod_script       = "SuperFlashlight/scripts/mods/SuperFlashlight/SuperFlashlight",
			mod_data         = "SuperFlashlight/scripts/mods/SuperFlashlight/SuperFlashlight_data",
			mod_localization = "SuperFlashlight/scripts/mods/SuperFlashlight/SuperFlashlight_localization",
		})
	end,
	packages = {},
}
