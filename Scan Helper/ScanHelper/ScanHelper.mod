return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ScanHelper` encountered an error loading the Darktide Mod Framework.")

		new_mod("ScanHelper", {
			mod_script       = "ScanHelper/scripts/mods/ScanHelper/ScanHelper",
			mod_data         = "ScanHelper/scripts/mods/ScanHelper/ScanHelper_data",
			mod_localization = "ScanHelper/scripts/mods/ScanHelper/ScanHelper_localization",
		})
	end,
	packages = {},
}
