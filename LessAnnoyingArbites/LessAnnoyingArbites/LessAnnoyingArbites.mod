return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LessAnnoyingArbites` encountered an error loading the Darktide Mod Framework.")

		new_mod("LessAnnoyingArbites", {
			mod_script       = "LessAnnoyingArbites/scripts/mods/LessAnnoyingArbites/LessAnnoyingArbites",
			mod_data         = "LessAnnoyingArbites/scripts/mods/LessAnnoyingArbites/LessAnnoyingArbites_data",
			mod_localization = "LessAnnoyingArbites/scripts/mods/LessAnnoyingArbites/LessAnnoyingArbites_localization",
		})
	end,
	packages = {},
}
