return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SlotFix` encountered an error loading the Darktide Mod Framework.")

		new_mod("SlotFix", {
			mod_script       = "SlotFix/scripts/mods/SlotFix/SlotFix",
			mod_data         = "SlotFix/scripts/mods/SlotFix/SlotFix_data",
			mod_localization = "SlotFix/scripts/mods/SlotFix/SlotFix_localization",
		})
	end,
	packages = {},
}
