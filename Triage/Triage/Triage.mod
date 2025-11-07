return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Triage` encountered an error loading the Darktide Mod Framework.")

		new_mod("Triage", {
			mod_script       = "Triage/scripts/mods/Triage/Triage",
			mod_data         = "Triage/scripts/mods/Triage/Triage_data",
			mod_localization = "Triage/scripts/mods/Triage/Triage_localization",
		})
	end,	
  	version = "1.2",
	packages = {},
}
