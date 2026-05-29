return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`TheEmperorProtects` encountered an error loading the Darktide Mod Framework.")

		new_mod("TheEmperorProtects", {
			mod_script       = "TheEmperorProtects/scripts/mods/TheEmperorProtects/TheEmperorProtects",
			mod_data         = "TheEmperorProtects/scripts/mods/TheEmperorProtects/TheEmperorProtects_data",
			mod_localization = "TheEmperorProtects/scripts/mods/TheEmperorProtects/TheEmperorProtects_localization",
		})
	end,
	packages = {},
}
