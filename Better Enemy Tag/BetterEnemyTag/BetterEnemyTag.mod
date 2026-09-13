return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BetterEnemyTag` encountered an error loading the Darktide Mod Framework.")

		new_mod("BetterEnemyTag", {
			mod_script       = "BetterEnemyTag/scripts/mods/BetterEnemyTag/BetterEnemyTag",
			mod_data         = "BetterEnemyTag/scripts/mods/BetterEnemyTag/BetterEnemyTag_data",
			mod_localization = "BetterEnemyTag/scripts/mods/BetterEnemyTag/BetterEnemyTag_localization",
		})
	end,
	packages = {
		"packages/ui/views/scanner_display_view/scanner_display_view",
		"packages/ui/views/character_appearance_view/character_appearance_view",
		"packages/ui/views/inventory_background_view/inventory_background_view",
		"packages/ui/hud/world_markers/world_markers",
		"packages/ui/hud/interaction/interaction",
		"packages/ui/hud/team_player_panel/team_player_panel",
	},
}
