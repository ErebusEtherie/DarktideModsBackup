return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SortModMenu` encountered an error loading the Darktide Mod Framework.")

		new_mod("SortModMenu", {
			mod_script       = "SortModMenu/scripts/mods/SortModMenu/SortModMenu",
			mod_data         = "SortModMenu/scripts/mods/SortModMenu/SortModMenu_data",
			mod_localization = "SortModMenu/scripts/mods/SortModMenu/SortModMenu_localization",
		})
	end,
	packages = {},
}
