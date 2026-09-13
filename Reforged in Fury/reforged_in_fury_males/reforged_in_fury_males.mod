return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`reforged_in_fury_males` encountered an error loading the Darktide Mod Framework.")

		new_mod("reforged_in_fury_males", {
			mod_script       = "reforged_in_fury_males/scripts/mods/reforged_in_fury_males/reforged_in_fury_males",
			mod_data         = "reforged_in_fury_males/scripts/mods/reforged_in_fury_males/reforged_in_fury_males_data",
			mod_localization = "reforged_in_fury_males/scripts/mods/reforged_in_fury_males/reforged_in_fury_males_localization",
		})
	end,
	packages = {},
}
