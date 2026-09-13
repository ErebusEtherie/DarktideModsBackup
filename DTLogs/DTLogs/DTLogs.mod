return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DTLogs` encountered an error loading the Darktide Mod Framework.")

		new_mod("DTLogs", {
			mod_script       = "DTLogs/scripts/mods/DTLogs/DTLogs",
			mod_data         = "DTLogs/scripts/mods/DTLogs/DTLogs_data",
			mod_localization = "DTLogs/scripts/mods/DTLogs/DTLogs_localization",
		})
	end,
	packages = {},
}
