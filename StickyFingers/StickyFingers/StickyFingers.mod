return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`StickyFingers` encountered an error loading the Darktide Mod Framework.")

		new_mod("StickyFingers", {
			mod_script       = "StickyFingers/scripts/mods/StickyFingers/StickyFingers",
			mod_data         = "StickyFingers/scripts/mods/StickyFingers/StickyFingers_data",
			mod_localization = "StickyFingers/scripts/mods/StickyFingers/StickyFingers_localization",
		})
	end,
	packages = {},
}
