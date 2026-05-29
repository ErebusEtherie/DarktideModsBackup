return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ErrorTracker` encountered an error loading the Darktide Mod Framework.")

		new_mod("ErrorTracker", {
			mod_script       = "ErrorTracker/scripts/mods/ErrorTracker/ErrorTracker",
			mod_data         = "ErrorTracker/scripts/mods/ErrorTracker/ErrorTracker_data",
			mod_localization = "ErrorTracker/scripts/mods/ErrorTracker/ErrorTracker_localization",
		})
	end,
	packages = {},
}
