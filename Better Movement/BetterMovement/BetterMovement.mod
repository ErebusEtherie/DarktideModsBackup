return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BetterMovement` encountered an error loading the Darktide Mod Framework.")

		new_mod("BetterMovement", {
			mod_script       = "BetterMovement/scripts/mods/BetterMovement/BetterMovement",
			mod_data         = "BetterMovement/scripts/mods/BetterMovement/BetterMovement_data",
			mod_localization = "BetterMovement/scripts/mods/BetterMovement/BetterMovement_localization",
		})
	end,
	packages = {},
}
