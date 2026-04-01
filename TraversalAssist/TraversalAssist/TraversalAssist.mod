return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`TraversalAssist` encountered an error loading the Darktide Mod Framework.")

		new_mod("TraversalAssist", {
			mod_script       = "TraversalAssist/scripts/mods/TraversalAssist/TraversalAssist",
			mod_data         = "TraversalAssist/scripts/mods/TraversalAssist/TraversalAssist_data",
			mod_localization = "TraversalAssist/scripts/mods/TraversalAssist/TraversalAssist_localization",
		})
	end,
	packages = {},
}
