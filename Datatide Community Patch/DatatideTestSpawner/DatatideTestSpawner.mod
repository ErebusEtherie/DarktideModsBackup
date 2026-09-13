return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DatatideTestSpawner` encountered an error loading the Darktide Mod Framework.")

		new_mod("DatatideTestSpawner", {
			mod_script       = "DatatideTestSpawner/scripts/mods/DatatideTestSpawner/DatatideTestSpawner",
			mod_data         = "DatatideTestSpawner/scripts/mods/DatatideTestSpawner/DatatideTestSpawner_data",
			mod_localization = "DatatideTestSpawner/scripts/mods/DatatideTestSpawner/DatatideTestSpawner_localization",
		})
	end,
	packages = {},
}
