return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`shorten_usernames` mod must be lower than DMF in load order.")

		new_mod("shorten_usernames", {
			mod_script       = "shorten_usernames/scripts/mods/shorten_usernames/shorten_usernames",
			mod_data         = "shorten_usernames/scripts/mods/shorten_usernames/shorten_usernames_data",
			mod_localization = "shorten_usernames/scripts/mods/shorten_usernames/shorten_usernames_localization",
		})
	end,
	packages = {},
}
