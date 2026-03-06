return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Targeter` encountered an error loading the Darktide Mod Framework.")

		new_mod("Targeter", {
			mod_script       = "Targeter/scripts/mods/Targeter/Targeter",
			mod_data         = "Targeter/scripts/mods/Targeter/Targeter_data",
			mod_localization = "Targeter/scripts/mods/Targeter/Targeter_localization",
		})
	end,
	packages = {},
}