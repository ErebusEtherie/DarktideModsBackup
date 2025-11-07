return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`clear_smoke` encountered an error loading the Darktide Mod Framework.")

		new_mod("clear_smoke", {
			mod_script       = "clear_smoke/scripts/mods/clear_smoke/clear_smoke",
			mod_data         = "clear_smoke/scripts/mods/clear_smoke/clear_smoke_data",
			mod_localization = "clear_smoke/scripts/mods/clear_smoke/clear_smoke_localization",
		})
	end,
	packages = {},
}
