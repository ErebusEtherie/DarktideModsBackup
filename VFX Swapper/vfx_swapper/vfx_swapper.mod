return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`vfx_swapper` encountered an error loading the Darktide Mod Framework.")

		new_mod("vfx_swapper", {
			mod_script       = "vfx_swapper/scripts/mods/vfx_swapper/vfx_swapper",
			mod_data         = "vfx_swapper/scripts/mods/vfx_swapper/vfx_swapper_data",
			mod_localization = "vfx_swapper/scripts/mods/vfx_swapper/vfx_swapper_localization",
		})
	end,
	packages = {},
}
