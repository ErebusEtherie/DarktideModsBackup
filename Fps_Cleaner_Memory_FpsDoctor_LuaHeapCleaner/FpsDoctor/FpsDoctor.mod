return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`FpsDoctor` encountered an error loading the Darktide Mod Framework.")

		new_mod("FpsDoctor", {
			mod_script       = "FpsDoctor/scripts/mods/FpsDoctor/FpsDoctor",
			mod_data         = "FpsDoctor/scripts/mods/FpsDoctor/FpsDoctor_data",
			mod_localization = "FpsDoctor/scripts/mods/FpsDoctor/FpsDoctor_localization",
		})
	end,
	packages = {},
	version = "1.6.5",
}
