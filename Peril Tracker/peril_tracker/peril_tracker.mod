return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`peril_tracker` encountered an error loading the Darktide Mod Framework.")

		new_mod("peril_tracker", {
			mod_script       = "peril_tracker/scripts/mods/peril_tracker/peril_tracker",
			mod_data         = "peril_tracker/scripts/mods/peril_tracker/peril_tracker_data",
			mod_localization = "peril_tracker/scripts/mods/peril_tracker/peril_tracker_localization",
		})
	end,
	packages = {},
}
