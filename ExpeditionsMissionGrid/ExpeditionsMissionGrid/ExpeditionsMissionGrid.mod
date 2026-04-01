return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ExpeditionsMissionGrid` encountered an error loading the Darktide Mod Framework.")

		new_mod("ExpeditionsMissionGrid", {
			mod_script = "ExpeditionsMissionGrid/scripts/mods/ExpeditionsMissionGrid/ExpeditionsMissionGrid",
			mod_data = "ExpeditionsMissionGrid/scripts/mods/ExpeditionsMissionGrid/ExpeditionsMissionGrid_data",
			mod_localization = "ExpeditionsMissionGrid/scripts/mods/ExpeditionsMissionGrid/ExpeditionsMissionGrid_localization",
		})
	end,
	packages = {},
}
