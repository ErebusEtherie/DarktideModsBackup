return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`what_are_you` encountered an error loading the Darktide Mod Framework.")

		new_mod("what_are_you", {
			mod_script       = "what_are_you/scripts/mods/what_are_you/what_are_you",
			mod_data         = "what_are_you/scripts/mods/what_are_you/what_are_you_data",
			mod_localization = "what_are_you/scripts/mods/what_are_you/what_are_you_localization",
		})
	end,
	packages = {},
}
