return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`improved_scoreboard_panel` encountered an error loading the Darktide Mod Framework.")

		new_mod("improved_scoreboard_panel", {
			mod_script       = "improved_scoreboard_panel/scripts/mods/improved_scoreboard_panel/improved_scoreboard_panel",
			mod_data         = "improved_scoreboard_panel/scripts/mods/improved_scoreboard_panel/improved_scoreboard_panel_data",
			mod_localization = "improved_scoreboard_panel/scripts/mods/improved_scoreboard_panel/improved_scoreboard_panel_localization",
		})
	end,
	load_after = {
		"improved_character_menu",
	},
	version = "2.0.6",
	mod_id = "902",
	packages = {},
}
