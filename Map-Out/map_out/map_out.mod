return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`map_out` encountered an error loading the Darktide Mod Framework.")

		new_mod("map_out", {
			mod_script       = "map_out/scripts/mods/map_out/map_out",
			mod_data         = "map_out/scripts/mods/map_out/map_out_data",
			mod_localization = "map_out/scripts/mods/map_out/map_out_localization",
		})
	end,
	packages = {},
}
