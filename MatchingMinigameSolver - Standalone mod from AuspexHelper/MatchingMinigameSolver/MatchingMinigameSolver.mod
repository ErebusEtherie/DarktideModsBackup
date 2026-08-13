return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MatchingMinigameSolver` encountered an error loading the Darktide Mod Framework.")

		new_mod("MatchingMinigameSolver", {
			mod_script = "MatchingMinigameSolver/scripts/mods/MatchingMinigameSolver/MatchingMinigameSolver",
			mod_data = "MatchingMinigameSolver/scripts/mods/MatchingMinigameSolver/MatchingMinigameSolver_data",
			mod_localization = "MatchingMinigameSolver/scripts/mods/MatchingMinigameSolver/MatchingMinigameSolver_localization",
		})
	end,
	packages = {},
}
