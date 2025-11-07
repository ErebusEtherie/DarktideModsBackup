return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`LessDoT` encountered an error loading the Darktide Mod Framework.")

		new_mod("LessDoT", {
			mod_script       = "LessDoT/scripts/mods/LessDoT/LessDoT",
			mod_data         = "LessDoT/scripts/mods/LessDoT/LessDoT_data",
			mod_localization = "LessDoT/scripts/mods/LessDoT/LessDoT_localization",
		})
	end,
	packages = {},
}
