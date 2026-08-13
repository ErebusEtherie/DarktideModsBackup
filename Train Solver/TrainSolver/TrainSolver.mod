return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`TrainSolver` encountered an error loading the Darktide Mod Framework.")

		new_mod("TrainSolver", {
			mod_script       = "TrainSolver/scripts/mods/TrainSolver/TrainSolver",
			mod_data         = "TrainSolver/scripts/mods/TrainSolver/TrainSolver_data",
			mod_localization = "TrainSolver/scripts/mods/TrainSolver/TrainSolver_localization",
		})
	end,
	packages = {},
}
