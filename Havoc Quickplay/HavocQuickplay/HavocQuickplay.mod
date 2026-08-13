return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`HavocQuickplay` encountered an error loading the Darktide Mod Framework.")

		new_mod("HavocQuickplay", {
			mod_script       = "HavocQuickplay/scripts/mods/HavocQuickplay/HavocQuickplay",
			mod_data         = "HavocQuickplay/scripts/mods/HavocQuickplay/HavocQuickplay_data",
			mod_localization = "HavocQuickplay/scripts/mods/HavocQuickplay/HavocQuickplay_localization",
		})
	end,
	packages = {},
}
