return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`IWantToHear` encountered an error loading the Darktide Mod Framework.")

		new_mod("IWantToHear", {
			mod_script       = "IWantToHear/scripts/mods/IWantToHear/IWantToHear",
			mod_data         = "IWantToHear/scripts/mods/IWantToHear/IWantToHear_data",
			mod_localization = "IWantToHear/scripts/mods/IWantToHear/IWantToHear_localization",
		})
	end,
	packages = {},
}
