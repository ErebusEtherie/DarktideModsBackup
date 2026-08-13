return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LoadingBar` encountered an error loading the Darktide Mod Framework.")

		new_mod("LoadingBar", {
			mod_script       = "LoadingBar/scripts/mods/LoadingBar/LoadingBar",
			mod_data         = "LoadingBar/scripts/mods/LoadingBar/LoadingBar_data",
			mod_localization = "LoadingBar/scripts/mods/LoadingBar/LoadingBar_localization",
		})
	end,
	packages = {},
}
