return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`RitualDangerZones` encountered an error loading the Darktide Mod Framework.")

		new_mod("RitualDangerZones", {
			mod_script       = "RitualDangerZones/scripts/mods/RitualDangerZones/RitualDangerZones",
			mod_data         = "RitualDangerZones/scripts/mods/RitualDangerZones/RitualDangerZones_data",
			mod_localization = "RitualDangerZones/scripts/mods/RitualDangerZones/RitualDangerZones_localization",
		})
	end,
	packages = {},
}
