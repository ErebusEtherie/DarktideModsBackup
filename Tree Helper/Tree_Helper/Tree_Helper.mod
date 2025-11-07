return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Tree_Helper` encountered an error loading the Darktide Mod Framework.")

		new_mod("Tree_Helper", {
			mod_script       = "Tree_Helper/scripts/mods/Tree_Helper/Tree_Helper",
			mod_data         = "Tree_Helper/scripts/mods/Tree_Helper/Tree_Helper_data",
			mod_localization = "Tree_Helper/scripts/mods/Tree_Helper/Tree_Helper_localization",
		})
	end,
	packages = {},
}
