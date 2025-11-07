return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`helbore_passive_charge` encountered an error loading the Darktide Mod Framework.")

		new_mod("helbore_passive_charge", {
			mod_script       = "helbore_passive_charge/scripts/mods/helbore_passive_charge/helbore_passive_charge",
			mod_data         = "helbore_passive_charge/scripts/mods/helbore_passive_charge/helbore_passive_charge_data",
			mod_localization = "helbore_passive_charge/scripts/mods/helbore_passive_charge/helbore_passive_charge_localization",
		})
	end,
	packages = {},
}
