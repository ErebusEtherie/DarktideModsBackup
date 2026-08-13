return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Weapon_XP_Farm` encountered an error loading the Darktide Mod Framework.")

		new_mod("Weapon_XP_Farm", {
			mod_script       = "Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/Weapon_XP_Farm",
			mod_data         = "Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/Weapon_XP_Farm_data",
			mod_localization = "Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/Weapon_XP_Farm_localization",
		})
	end,
	packages = {},
}
