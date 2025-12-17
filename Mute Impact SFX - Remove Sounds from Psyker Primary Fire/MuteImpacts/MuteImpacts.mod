return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`%%title` encountered an error loading the Darktide Mod Framework.")

		new_mod("MuteImpacts", {
			mod_script       = "MuteImpacts/scripts/mods/MuteImpacts/MuteImpacts",
			mod_data         = "MuteImpacts/scripts/mods/MuteImpacts/MuteImpacts_data",
			mod_localization = "MuteImpacts/scripts/mods/MuteImpacts/MuteImpacts_localization",
		})
	end,
	require = {
		"DarktideLocalServer",
		"Audio",
	},
	load_after = {
		"Audio",
	},
	version = "1.0.3",
	packages = {},
}
