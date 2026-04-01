return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SmoothTide` encountered an error loading the Darktide Mod Framework.")

		new_mod("SmoothTide", {
			mod_script       = "SmoothTide/scripts/mods/SmoothTide/SmoothTide",
			mod_data         = "SmoothTide/scripts/mods/SmoothTide/SmoothTide_data",
			mod_localization = "SmoothTide/scripts/mods/SmoothTide/SmoothTide_localization",
		})
	end,
	packages = {},
}
