return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DefaultSprint` encountered an error loading the Darktide Mod Framework.")

		new_mod("DefaultSprint", {
			mod_script       = "DefaultSprint/scripts/mods/DefaultSprint/DefaultSprint",
			mod_data         = "DefaultSprint/scripts/mods/DefaultSprint/DefaultSprint_data",
			mod_localization = "DefaultSprint/scripts/mods/DefaultSprint/DefaultSprint_localization",
		})
	end,
	packages = {},
}
