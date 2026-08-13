return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ServoSkullHoundCommander` encountered an error loading the Darktide Mod Framework.")

		new_mod("ServoSkullHoundCommander", {
			mod_script       = "ServoSkullHoundCommander/scripts/mods/ServoSkullHoundCommander/ServoSkullHoundCommander",
			mod_data         = "ServoSkullHoundCommander/scripts/mods/ServoSkullHoundCommander/ServoSkullHoundCommander_data",
			mod_localization = "ServoSkullHoundCommander/scripts/mods/ServoSkullHoundCommander/ServoSkullHoundCommander_localization",
		})
	end,
	packages = {},
	version = "0.3.0",
}
