return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`vfx_limiter` encountered an error loading the Darktide Mod Framework.")

		new_mod("vfx_limiter", {
			mod_script       = "vfx_limiter/scripts/mods/vfx_limiter/vfx_limiter",
			mod_data         = "vfx_limiter/scripts/mods/vfx_limiter/vfx_limiter_data",
			mod_localization = "vfx_limiter/scripts/mods/vfx_limiter/vfx_limiter_localization",
		})
	end,
	packages = {},
}
