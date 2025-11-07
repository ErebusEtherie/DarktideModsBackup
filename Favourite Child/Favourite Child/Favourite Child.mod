return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Favourite Child` encountered an error loading the Darktide Mod Framework.")

		new_mod("Favourite Child", {
			mod_script       = "Favourite Child/scripts/mods/Favourite Child/Favourite Child",
			mod_data         = "Favourite Child/scripts/mods/Favourite Child/Favourite Child_data",
			mod_localization = "Favourite Child/scripts/mods/Favourite Child/Favourite Child_localization",
		})
	end,
	version = "1.2.0",
	packages = {},
}
