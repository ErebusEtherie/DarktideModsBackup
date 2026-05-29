return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SteadyHands` encountered an error loading the Darktide Mod Framework.")

		new_mod("SteadyHands", {
			mod_script       = "SteadyHands/scripts/mods/SteadyHands/SteadyHands",
			mod_data         = "SteadyHands/scripts/mods/SteadyHands/SteadyHands_data",
			mod_localization = "SteadyHands/scripts/mods/SteadyHands/SteadyHands_localization",
		})
	end,
	packages = {},
}
