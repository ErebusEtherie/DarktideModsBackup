return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MultiBind` encountered an error loading the Darktide Mod Framework.")

		new_mod("MultiBind", {
			mod_script       = "MultiBind/scripts/mods/MultiBind/MultiBind",
			mod_data         = "MultiBind/scripts/mods/MultiBind/MultiBind_data",
			mod_localization = "MultiBind/scripts/mods/MultiBind/MultiBind_localization",
		})
	end,
	packages = {},
}
