return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DarkCache` encountered an error loading the Darktide Mod Framework.")

		new_mod("DarkCache", {
			mod_script       = "DarkCache/scripts/mods/DarkCache/DarkCache",
			mod_data         = "DarkCache/scripts/mods/DarkCache/DarkCache_data",
			mod_localization = "DarkCache/scripts/mods/DarkCache/DarkCache_localization",
		})
	end,
	packages = {},
}
