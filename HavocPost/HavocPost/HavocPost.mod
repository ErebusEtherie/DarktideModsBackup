return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`HavocPost` encountered an error loading the Darktide Mod Framework.")

		new_mod("HavocPost", {
			mod_script       = "HavocPost/scripts/mods/HavocPost/HavocPost",
			mod_data         = "HavocPost/scripts/mods/HavocPost/HavocPost_data",
			mod_localization = "HavocPost/scripts/mods/HavocPost/HavocPost_localization",
		})
	end,
	packages = {},
}
