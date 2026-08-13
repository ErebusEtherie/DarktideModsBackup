return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AutoMedicaeServoSkull` encountered an error loading the Darktide Mod Framework.")

		new_mod("AutoMedicaeServoSkull", {
			mod_script       = "AutoMedicaeServoSkull/scripts/mods/AutoMedicaeServoSkull/AutoMedicaeServoSkull",
			mod_data         = "AutoMedicaeServoSkull/scripts/mods/AutoMedicaeServoSkull/AutoMedicaeServoSkull_data",
			mod_localization = "AutoMedicaeServoSkull/scripts/mods/AutoMedicaeServoSkull/AutoMedicaeServoSkull_localization",
		})
	end,
	packages = {},
}
