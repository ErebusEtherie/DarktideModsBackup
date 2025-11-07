return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`NoPingSounds` encountered an error loading the Darktide Mod Framework.")

		new_mod("NoPingSounds", {
			mod_script       = "NoPingSounds/scripts/Mod",
			mod_data         = "NoPingSounds/scripts/Mod_data",
			mod_localization = "NoPingSounds/scripts/Mod_lang",
		})
	end,
	packages = {},
}
