return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Killfeed_Reborn` encountered an error loading the Darktide Mod Framework.")

		new_mod("Killfeed_Reborn", {
			mod_script       = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn",
			mod_data         = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn_data",
			mod_localization = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn_localization",
		})
	end,
	packages = {},
}
