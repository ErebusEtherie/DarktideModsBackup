return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`UngaBunga` encountered an error loading the Darktide Mod Framework.")

		new_mod("UngaBunga", {
			mod_script       = "UngaBunga/scripts/mods/UngaBunga/UngaBunga",
			mod_data         = "UngaBunga/scripts/mods/UngaBunga/UngaBunga_data",
			mod_localization = "UngaBunga/scripts/mods/UngaBunga/UngaBunga_localization",
		})
	end,
	packages = {},
}
