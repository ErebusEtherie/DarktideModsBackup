return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`improved_character_menu` encountered an error loading the Darktide Mod Framework.")

		new_mod("improved_character_menu", {
			mod_script       = "improved_character_menu/scripts/mods/improved_character_menu/improved_character_menu",
			mod_data         = "improved_character_menu/scripts/mods/improved_character_menu/improved_character_menu_data",
			mod_localization = "improved_character_menu/scripts/mods/improved_character_menu/improved_character_menu_localization",
		})
	end,
	load_after = {
		"CustomUIColors",
		"psych_ward",
	},
	version = "1.0.4",
	mod_id = "849",
	packages = {},
}
