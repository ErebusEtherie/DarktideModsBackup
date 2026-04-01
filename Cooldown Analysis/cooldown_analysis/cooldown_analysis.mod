return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`cooldown_analysis` encountered an error loading the Darktide Mod Framework.")

		new_mod("cooldown_analysis", {
			mod_script       = "cooldown_analysis/scripts/mods/cooldown_analysis/cooldown_analysis",
			mod_data         = "cooldown_analysis/scripts/mods/cooldown_analysis/cooldown_analysis_data",
			mod_localization = "cooldown_analysis/scripts/mods/cooldown_analysis/cooldown_analysis_localization",
		})
	end,
	packages = {},
}
