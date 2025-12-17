return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`A La Mode` encountered an error loading the Darktide Mod Framework.")

		new_mod("A la Mode", {
			mod_script       = "A La Mode/scripts/mods/A La Mode/A La Mode",
			mod_data         = "A La Mode/scripts/mods/A La Mode/A La Mode_data",
			mod_localization = "A La Mode/scripts/mods/A La Mode/A La Mode_localization",
		})
	end,
	packages = {},
	version = "3.1.0",
}
