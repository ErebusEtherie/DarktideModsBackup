return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`TraumaOutlines` encountered an error loading the Darktide Mod Framework.")

		new_mod("TraumaOutlines", {
			mod_script       = "TraumaOutlines/scripts/mods/TraumaOutlines/TraumaOutlines",
			mod_data         = "TraumaOutlines/scripts/mods/TraumaOutlines/TraumaOutlines_data",
			mod_localization = "TraumaOutlines/scripts/mods/TraumaOutlines/TraumaOutlines_localization",
		})
	end,
	packages = {},
}
