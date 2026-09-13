return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`GhostHost` encountered an error loading the Darktide Mod Framework.")

		new_mod("GhostHost", {
			mod_script       = "DTRealmsGhostHost/scripts/mods/GhostHost/GhostHost",
			mod_data         = "DTRealmsGhostHost/scripts/mods/GhostHost/GhostHost_data",
			mod_localization = "DTRealmsGhostHost/scripts/mods/GhostHost/GhostHost_localization",
		})
	end,
	packages = {},
	version = "0.1.1",
}
