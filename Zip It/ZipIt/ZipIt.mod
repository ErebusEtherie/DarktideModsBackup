return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ZipIt` encountered an error loading the Darktide Mod Framework.")

		new_mod("ZipIt", {
			mod_script       = "ZipIt/scripts/mods/ZipIt/ZipIt",
			mod_data         = "ZipIt/scripts/mods/ZipIt/ZipIt_data",
			mod_localization = "ZipIt/scripts/mods/ZipIt/ZipIt_localization",
		})
	end,
	packages = {},
}
