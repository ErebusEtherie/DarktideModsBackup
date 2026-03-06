return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`veil_shield` encountered an error loading the Darktide Mod Framework.")

		new_mod("veil_shield", {
			mod_script       = "veil_shield/scripts/mods/veil_shield/veil_shield",
			mod_data         = "veil_shield/scripts/mods/veil_shield/veil_shield_data",
			mod_localization = "veil_shield/scripts/mods/veil_shield/veil_shield_localization",
		})
	end,
	packages = {},
}
