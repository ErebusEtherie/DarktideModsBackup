return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AudioReplacer` encountered an error loading the Darktide Mod Framework.")

		new_mod("AudioReplacer", {
			mod_script       = "AudioReplacer/scripts/mods/AudioReplacer/AudioReplacer",
			mod_data         = "AudioReplacer/scripts/mods/AudioReplacer/AudioReplacer_data",
			mod_localization = "AudioReplacer/scripts/mods/AudioReplacer/AudioReplacer_localization",
		})
	end,
	packages = {},
}
