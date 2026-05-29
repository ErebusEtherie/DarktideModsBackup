return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BetterEnemyTag` encountered an error loading the Darktide Mod Framework.")

		new_mod("BetterEnemyTag", {
			mod_script       = "BetterEnemyTag/scripts/mods/BetterEnemyTag/BetterEnemyTag",
			mod_data         = "BetterEnemyTag/scripts/mods/BetterEnemyTag/BetterEnemyTag_data",
			mod_localization = "BetterEnemyTag/scripts/mods/BetterEnemyTag/BetterEnemyTag_localization",
		})
	end,
	packages = {},
}
