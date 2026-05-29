return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SoundFilter` encountered an error loading the Darktide Mod Framework.")

		new_mod("SoundFilter", {
			mod_script       = "SoundFilter/scripts/mods/SoundFilter/SoundFilter",
			mod_data         = "SoundFilter/scripts/mods/SoundFilter/SoundFilter_data",
			mod_localization = "SoundFilter/scripts/mods/SoundFilter/SoundFilter_localization",
		})
	end,
	packages = {},
}
