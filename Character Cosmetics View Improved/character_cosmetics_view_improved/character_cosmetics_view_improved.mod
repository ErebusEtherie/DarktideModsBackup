return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`character_cosmetics_view_improved` encountered an error loading the Darktide Mod Framework.")

		new_mod("character_cosmetics_view_improved", {
			mod_script       = "character_cosmetics_view_improved/scripts/mods/character_cosmetics_view_improved/character_cosmetics_view_improved",
			mod_data         = "character_cosmetics_view_improved/scripts/mods/character_cosmetics_view_improved/character_cosmetics_view_improved_data",
			mod_localization = "character_cosmetics_view_improved/scripts/mods/character_cosmetics_view_improved/character_cosmetics_view_improved_localization",
		})
	end,
	packages = {},
}
