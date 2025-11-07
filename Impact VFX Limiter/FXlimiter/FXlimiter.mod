return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`FXlimiter` encountered an error loading the Darktide Mod Framework.")

		new_mod("FXlimiter", {
			mod_script       = "FXlimiter/scripts/mods/FXlimiter/FXlimiter",
			mod_data         = "FXlimiter/scripts/mods/FXlimiter/FXlimiter_data",
			mod_localization = "FXlimiter/scripts/mods/FXlimiter/FXlimiter_localization",
		})
	end,
	packages = {},
}
