return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Bubblelicious` encountered an error loading the Darktide Mod Framework.")

		new_mod("Bubblelicious", {
			mod_script       = "Bubblelicious/scripts/mods/Bubblelicious/Bubblelicious",
			mod_data         = "Bubblelicious/scripts/mods/Bubblelicious/Bubblelicious_data",
			mod_localization = "Bubblelicious/scripts/mods/Bubblelicious/Bubblelicious_localization",
		})
	end,
	packages = {},
	version = "1.7.1",
}