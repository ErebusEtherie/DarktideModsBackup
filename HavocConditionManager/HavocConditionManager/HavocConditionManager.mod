return {
	run = function ()
		fassert(rawget(_G, "new_mod"), "`HavocConditionManager` encountered an error loading the Darktide Mod Framework.")

		new_mod("HavocConditionManager", {
			mod_script = "HavocConditionManager/scripts/mods/HavocConditionManager/HavocConditionManager",
			mod_data = "HavocConditionManager/scripts/mods/HavocConditionManager/HavocConditionManager_data",
			mod_localization = "HavocConditionManager/scripts/mods/HavocConditionManager/HavocConditionManager_localization",
		})
	end,
	packages = {},
}
