return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Compass Range Finder` encountered an error loading the Darktide Mod Framework.")

		new_mod("Compass Range Finder", {
			mod_script       = "Compass Range Finder/scripts/mods/Compass Range Finder/Compass Range Finder",
			mod_data         = "Compass Range Finder/scripts/mods/Compass Range Finder/Compass Range Finder_data",
			mod_localization = "Compass Range Finder/scripts/mods/Compass Range Finder/Compass Range Finder_localization",
		})
	end,
	version = "1.3",
	after = {
		"Extra Opportunities",
	},
	packages = {},
}
