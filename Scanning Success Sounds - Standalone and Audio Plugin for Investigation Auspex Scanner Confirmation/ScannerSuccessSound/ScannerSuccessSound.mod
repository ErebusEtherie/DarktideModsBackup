return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`ScannerSuccessSound` encountered an error loading the Darktide Mod Framework.")

        new_mod("ScannerSuccessSound", {
            mod_script       = "ScannerSuccessSound/scripts/mods/ScannerSuccessSound/ScannerSuccessSound",
            mod_data         = "ScannerSuccessSound/scripts/mods/ScannerSuccessSound/ScannerSuccessSound_data",
            mod_localization = "ScannerSuccessSound/scripts/mods/ScannerSuccessSound/ScannerSuccessSound_localization",
        })
    end,
    packages = {},
	load_after = {
		 "DarktideLocalServer",
		 "Audio",
	},
}
