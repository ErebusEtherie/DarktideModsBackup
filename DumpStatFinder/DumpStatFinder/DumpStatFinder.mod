return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DumpStatFinder` encountered an error loading the Darktide Mod Framework.")

		new_mod("DumpStatFinder", {
			mod_script       = "DumpStatFinder/scripts/mods/DumpStatFinder/DumpStatFinder",
			mod_data         = "DumpStatFinder/scripts/mods/DumpStatFinder/DumpStatFinder_data",
			mod_localization = "DumpStatFinder/scripts/mods/DumpStatFinder/DumpStatFinder_localization",
		})
	end,
	packages = {},
}
