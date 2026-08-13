return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SkitariiUIFix` encountered an error loading the Darktide Mod Framework.")

		new_mod("SkitariiUIFix", {
			mod_script       = "SkitariiUIFix/scripts/mods/SkitariiUIFix/SkitariiUIFix",
			mod_data         = "SkitariiUIFix/scripts/mods/SkitariiUIFix/SkitariiUIFix_data",
			mod_localization = "SkitariiUIFix/scripts/mods/SkitariiUIFix/SkitariiUIFix_localization",
		})
	end,
	packages = {},
	version = "0.7.1",
}
