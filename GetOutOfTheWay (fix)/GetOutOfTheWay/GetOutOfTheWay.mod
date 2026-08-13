return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`GetOutOfTheWay` encountered an error loading the Darktide Mod Framework.")

		new_mod("GetOutOfTheWay", {
			mod_script       = "GetOutOfTheWay/scripts/mods/GetOutOfTheWay/GetOutOfTheWay",
			mod_data         = "GetOutOfTheWay/scripts/mods/GetOutOfTheWay/GetOutOfTheWay_data",
			mod_localization = "GetOutOfTheWay/scripts/mods/GetOutOfTheWay/GetOutOfTheWay_localization",
		})
	end,
	packages = {},
}
