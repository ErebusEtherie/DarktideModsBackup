return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DodgeSlide` encountered an error loading the Darktide Mod Framework.")

		new_mod("DodgeSlide", {
			mod_script       = "DodgeSlide/scripts/mods/DodgeSlide/DodgeSlide",
			mod_data         = "DodgeSlide/scripts/mods/DodgeSlide/DodgeSlide_data",
			mod_localization = "DodgeSlide/scripts/mods/DodgeSlide/DodgeSlide_localization",
		})
	end,
	packages = {},
}