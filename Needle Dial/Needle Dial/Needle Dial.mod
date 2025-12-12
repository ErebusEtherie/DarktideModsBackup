return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Needle Dial` encountered an error loading the Darktide Mod Framework.")

		new_mod("Needle Dial", {
			mod_script       = "Needle Dial/scripts/mods/Needle Dial/Needle Dial",
			mod_data         = "Needle Dial/scripts/mods/Needle Dial/Needle Dial_data",
			mod_localization = "Needle Dial/scripts/mods/Needle Dial/Needle Dial_localization",
		})
	end,
	packages = {},
	version = "1.0.0",
}
