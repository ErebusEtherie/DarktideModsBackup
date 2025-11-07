return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`GasOutline` encountered an error loading the Darktide Mod Framework.")

		new_mod("GasOutline", {
			mod_script       = "GasOutline/scripts/mods/GasOutline/GasOutline",
			mod_data         = "GasOutline/scripts/mods/GasOutline/GasOutline_data",
			mod_localization = "GasOutline/scripts/mods/GasOutline/GasOutline_localization",
		})
	end,
	packages = {},
}
