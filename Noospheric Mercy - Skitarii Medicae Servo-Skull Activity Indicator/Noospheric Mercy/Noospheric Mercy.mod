return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Noospheric Mercy` encountered an error loading the Darktide Mod Framework.")

		new_mod("Noospheric Mercy", {
			mod_script       = "Noospheric Mercy/scripts/mods/Noospheric Mercy/Noospheric Mercy",
			mod_data         = "Noospheric Mercy/scripts/mods/Noospheric Mercy/Noospheric Mercy_data",
			mod_localization = "Noospheric Mercy/scripts/mods/Noospheric Mercy/Noospheric Mercy_localization",
		})
	end,
	version = "2.2.0",
	packages = {},
}
