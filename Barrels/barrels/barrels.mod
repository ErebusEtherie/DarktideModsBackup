-- barrels.mod
return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`barrels` encountered an error loading the Darktide Mod Framework.")
		new_mod("barrels", {
			mod_script = "barrels/scripts/mods/barrels/barrels",
			mod_data = "barrels/scripts/mods/barrels/barrels_data",
			mod_localization = "barrels/scripts/mods/barrels/barrels_localization",
		})
	end,
	packages = {},
}
