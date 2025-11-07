return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LessAnnoyingLoading` encountered an error loading the Darktide Mod Framework.")

		new_mod("LessAnnoyingLoading", {
			mod_script       = "LessAnnoyingLoading/scripts/mods/LessAnnoyingLoading/LessAnnoyingLoading",
			mod_data         = "LessAnnoyingLoading/scripts/mods/LessAnnoyingLoading/LessAnnoyingLoading_data",
			mod_localization = "LessAnnoyingLoading/scripts/mods/LessAnnoyingLoading/LessAnnoyingLoading_localization",
		})
	end,
	packages = {},
}
