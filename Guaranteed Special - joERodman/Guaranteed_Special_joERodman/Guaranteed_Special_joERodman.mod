return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Guaranteed_Special_joERodman` requires Darktide Mod Framework.")

		new_mod("Guaranteed_Special_joERodman", {
			mod_script = "Guaranteed_Special_joERodman/scripts/mods/Guaranteed_Special_joERodman/Guaranteed_Special_joERodman",
			mod_data = "Guaranteed_Special_joERodman/scripts/mods/Guaranteed_Special_joERodman/Guaranteed_Special_joERodman_data",
			mod_localization = "Guaranteed_Special_joERodman/scripts/mods/Guaranteed_Special_joERodman/Guaranteed_Special_joERodman_localization",
		})
	end,
	load_after = {
		"modding_tools",
		"MultiBind",
		"Skitarius",
	},
	packages = {},
}
