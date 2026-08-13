return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`enhanced_character_selection` encountered an error loading the Darktide Mod Framework.")

		new_mod("enhanced_character_selection", {
			mod_script       = "enhanced_character_selection/scripts/mods/enhanced_character_selection/enhanced_character_selection",
			mod_data         = "enhanced_character_selection/scripts/mods/enhanced_character_selection/enhanced_character_selection_data",
			mod_localization = "enhanced_character_selection/scripts/mods/enhanced_character_selection/enhanced_character_selection_localization",
		})
	end,
	packages = {},
}
