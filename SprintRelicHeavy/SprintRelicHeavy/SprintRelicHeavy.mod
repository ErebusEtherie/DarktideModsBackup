return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SprintRelicHeavy` encountered an error loading the Darktide Mod Framework.")

		new_mod("SprintRelicHeavy", {
			mod_script = "SprintRelicHeavy/scripts/mods/SprintRelicHeavy/SprintRelicHeavy",
			mod_data = "SprintRelicHeavy/scripts/mods/SprintRelicHeavy/SprintRelicHeavy_data",
			mod_localization = "SprintRelicHeavy/scripts/mods/SprintRelicHeavy/SprintRelicHeavy_localization",
		})
	end,
	packages = {},
}
