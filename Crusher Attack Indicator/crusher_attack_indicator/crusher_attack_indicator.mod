return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`crusher_attack_indicator` encountered an error loading the Darktide Mod Framework.")

		new_mod("crusher_attack_indicator", {
			mod_script       = "crusher_attack_indicator/scripts/mods/crusher_attack_indicator/crusher_attack_indicator",
			mod_data         = "crusher_attack_indicator/scripts/mods/crusher_attack_indicator/crusher_attack_indicator_data",
			mod_localization = "crusher_attack_indicator/scripts/mods/crusher_attack_indicator/crusher_attack_indicator_localization",
		})
	end,
	packages = {},
}