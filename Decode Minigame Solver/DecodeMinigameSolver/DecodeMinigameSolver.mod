return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DecodeMinigameSolver` encountered an error loading the Darktide Mod Framework.")

		new_mod("DecodeMinigameSolver", {
			mod_script       = "DecodeMinigameSolver/scripts/DecodeMinigameSolver",
			mod_data         = "DecodeMinigameSolver/scripts/DecodeMinigameSolver_data",
			mod_localization = "DecodeMinigameSolver/scripts/DecodeMinigameSolver_localization",
		})
	end,
	packages = {},
}
