return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LessAnnoyingPing` encountered an error loading the Darktide Mod Framework.")

		new_mod("LessAnnoyingPing", {
			mod_script       = "LessAnnoyingPing/scripts/mods/LessAnnoyingPing/LessAnnoyingPing",
			mod_data         = "LessAnnoyingPing/scripts/mods/LessAnnoyingPing/LessAnnoyingPing_data",
			mod_localization = "LessAnnoyingPing/scripts/mods/LessAnnoyingPing/LessAnnoyingPing_localization",
		})
	end,
	packages = {},
}
