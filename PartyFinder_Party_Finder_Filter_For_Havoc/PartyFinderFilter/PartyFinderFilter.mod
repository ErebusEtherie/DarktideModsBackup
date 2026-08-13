return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PartyFinderFilter` encountered an error loading the Darktide Mod Framework.")

		new_mod("PartyFinderFilter", {
			mod_script       = "PartyFinderFilter/scripts/mods/PartyFinderFilter/PartyFinderFilter",
			mod_data         = "PartyFinderFilter/scripts/mods/PartyFinderFilter/PartyFinderFilter_data",
			mod_localization = "PartyFinderFilter/scripts/mods/PartyFinderFilter/PartyFinderFilter_localization",
		})
	end,
	packages = {},
}
