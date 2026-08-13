return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`NoPetsLeftBehind` encountered an error loading the Darktide Mod Framework.")

		new_mod("NoPetsLeftBehind", {
			mod_script       = "NoPetsLeftBehind/scripts/mods/NoPetsLeftBehind/NoPetsLeftBehind",
			mod_data         = "NoPetsLeftBehind/scripts/mods/NoPetsLeftBehind/NoPetsLeftBehind_data",
			mod_localization = "NoPetsLeftBehind/scripts/mods/NoPetsLeftBehind/NoPetsLeftBehind_localization",
		})
	end,
	packages = {},
}
