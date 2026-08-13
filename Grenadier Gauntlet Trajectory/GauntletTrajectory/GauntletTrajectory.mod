return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`GauntletTrajectory` encountered an error loading the Darktide Mod Framework.")

		new_mod("GauntletTrajectory", {
			mod_script       = "GauntletTrajectory/scripts/mods/gauntlet_trajectory/gauntlet_trajectory",
			mod_data         = "GauntletTrajectory/scripts/mods/gauntlet_trajectory/gauntlet_trajectory_data",
			mod_localization = "GauntletTrajectory/scripts/mods/gauntlet_trajectory/gauntlet_trajectory_localization",
		})
	end,
	packages = {},
}
