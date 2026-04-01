return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Inferno_Sprint_Cancel` encountered an error loading the Darktide Mod Framework.")

		new_mod("Inferno_Sprint_Cancel", {
			mod_script       = "Inferno_Sprint_Cancel/Inferno_Sprint_Cancel",
			mod_data         = "Inferno_Sprint_Cancel/Inferno_Sprint_Cancel_data",
			mod_localization = "Inferno_Sprint_Cancel/Inferno_Sprint_Cancel_localization",
		})
	end,
	packages = {},
}
