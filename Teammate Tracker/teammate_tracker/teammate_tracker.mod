return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`teammate_tracker` encountered an error loading the Darktide Mod Framework.")

		new_mod("teammate_tracker", {
			mod_script       = "teammate_tracker/scripts/mods/teammate_tracker/teammate_tracker",
			mod_data         = "teammate_tracker/scripts/mods/teammate_tracker/teammate_tracker_data",
			mod_localization = "teammate_tracker/scripts/mods/teammate_tracker/teammate_tracker_localization",
		})
	end,
	
	load_after = {
		"true_level",
	},
	require = {
		"true_level",
	},
	version = "2.0.2",
	
	packages = {},
}