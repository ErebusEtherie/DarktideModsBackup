return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`RecolorBossHealthBars` encountered an error loading the Darktide Mod Framework.")

		new_mod("RecolorBossHealthBars", {
			mod_script       = "RecolorBossHealthBars/scripts/mods/RecolorBossHealthBars/RecolorBossHealthBars",
			mod_data         = "RecolorBossHealthBars/scripts/mods/RecolorBossHealthBars/RecolorBossHealthBars_data",
			mod_localization = "RecolorBossHealthBars/scripts/mods/RecolorBossHealthBars/RecolorBossHealthBars_localization",
		})
	end,
	packages = {},
}
