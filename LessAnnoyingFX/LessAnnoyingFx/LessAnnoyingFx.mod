return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LessAnnoyingFx` encountered an error loading the Darktide Mod Framework.")

		new_mod("LessAnnoyingFx", {
			mod_script       = "LessAnnoyingFx/scripts/mods/LessAnnoyingFx/LessAnnoyingFx",
			mod_data         = "LessAnnoyingFx/scripts/mods/LessAnnoyingFx/LessAnnoyingFx_data",
			mod_localization = "LessAnnoyingFx/scripts/mods/LessAnnoyingFx/LessAnnoyingFx_localization",
		})
	end,
	packages = {},
}
