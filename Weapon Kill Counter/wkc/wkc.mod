return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`wkc` encountered an error loading the Darktide Mod Framework.")

		new_mod("wkc", {
			mod_script       = "wkc/scripts/mods/wkc/wkc",
			mod_data         = "wkc/scripts/mods/wkc/wkc_data",
			mod_localization = "wkc/scripts/mods/wkc/wkc_localization",
		})
	end,
	load_after = {
		"Vox Manifold",
	},
	packages = {},
}
