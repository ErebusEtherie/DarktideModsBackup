return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PsykerCriticalPerilQuiet` encountered an error loading the Darktide Mod Framework.")

		new_mod("PsykerCriticalPerilQuiet", {
			mod_script       = "PsykerCriticalPerilQuiet/scripts/mods/PsykerCriticalPerilQuiet/PsykerCriticalPerilQuiet",
			mod_data         = "PsykerCriticalPerilQuiet/scripts/mods/PsykerCriticalPerilQuiet/PsykerCriticalPerilQuiet_data",
			mod_localization = "PsykerCriticalPerilQuiet/scripts/mods/PsykerCriticalPerilQuiet/PsykerCriticalPerilQuiet_localization",
		})
	end,
	packages = {},
}
