return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ArtificialLatency` encountered an error loading the Darktide Mod Framework.")

		new_mod("ArtificialLatency", {
			mod_script       = "ArtificialLatency/scripts/mods/ArtificialLatency/ArtificialLatency",
			mod_data         = "ArtificialLatency/scripts/mods/ArtificialLatency/ArtificialLatency_data",
			mod_localization = "ArtificialLatency/scripts/mods/ArtificialLatency/ArtificialLatency_localization",
		})
	end,
	packages = {},
}