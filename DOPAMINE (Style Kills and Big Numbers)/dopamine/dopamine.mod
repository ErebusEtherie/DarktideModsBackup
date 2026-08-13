return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`dopamine` encountered an error loading the Darktide Mod Framework.")

		new_mod("dopamine", {
			mod_script       = "dopamine/scripts/mods/dopamine/dopamine",
			mod_data         = "dopamine/scripts/mods/dopamine/dopamine_data",
			mod_localization = "dopamine/scripts/mods/dopamine/dopamine_localization",
		})
	end,
	packages = {},
}
