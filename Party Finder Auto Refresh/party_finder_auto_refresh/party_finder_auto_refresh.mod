return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`party_finder_auto_refresh` encountered an error loading the Darktide Mod Framework.")

		new_mod("party_finder_auto_refresh", {
			mod_script       = "party_finder_auto_refresh/scripts/mods/party_finder_auto_refresh/party_finder_auto_refresh",
			mod_data         = "party_finder_auto_refresh/scripts/mods/party_finder_auto_refresh/party_finder_auto_refresh_data",
			mod_localization = "party_finder_auto_refresh/scripts/mods/party_finder_auto_refresh/party_finder_auto_refresh_localization",
		})
	end,
	packages = {},
}
