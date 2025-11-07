return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PlayerDeathfeed` encountered an error loading the Darktide Mod Framework.")

		new_mod("PlayerDeathfeed", {
			mod_script       = "PlayerDeathfeed/scripts/mods/PlayerDeathfeed/PlayerDeathfeed",
			mod_data         = "PlayerDeathfeed/scripts/mods/PlayerDeathfeed/PlayerDeathfeed_data",
			mod_localization = "PlayerDeathfeed/scripts/mods/PlayerDeathfeed/PlayerDeathfeed_localization",
		})
	end,
	packages = {},
}
