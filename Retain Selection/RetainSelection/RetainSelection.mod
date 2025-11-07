return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`RetainSelection` encountered an error loading the Darktide Mod Framework.")

		new_mod("RetainSelection", {
			mod_script       = "RetainSelection/scripts/mods/RetainSelection/RetainSelection",
			mod_data         = "RetainSelection/scripts/mods/RetainSelection/RetainSelection_data",
			mod_localization = "RetainSelection/scripts/mods/RetainSelection/RetainSelection_localization",
		})
	end,
	packages = {},
}
