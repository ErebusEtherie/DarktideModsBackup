return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`RemoveTagSkulls` encountered an error loading the Darktide Mod Framework.")

		new_mod("RemoveTagSkulls", {
			mod_script       = "RemoveTagSkulls/scripts/RemoveTagSkulls",
			mod_data         = "RemoveTagSkulls/scripts/RemoveTagSkulls_data",
			mod_localization = "RemoveTagSkulls/scripts/RemoveTagSkulls_localization",
		})
	end,
	packages = {},
}
