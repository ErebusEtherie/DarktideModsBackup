return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LetMePlayHavoc` encountered an error loading the Darktide Mod Framework.")

		new_mod("LetMePlayHavoc", {
			mod_script       = "LetMePlayHavoc/scripts/mods/LetMePlayHavoc/LetMePlayHavoc",
			mod_data         = "LetMePlayHavoc/scripts/mods/LetMePlayHavoc/LetMePlayHavoc_data",
			mod_localization = "LetMePlayHavoc/scripts/mods/LetMePlayHavoc/LetMePlayHavoc_localization",
		})
	end,
	packages = {},
}
