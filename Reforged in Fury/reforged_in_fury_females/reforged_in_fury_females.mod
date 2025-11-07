return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`reforged_in_fury_females` encountered an error loading the Darktide Mod Framework.")

		new_mod("reforged_in_fury_females", {
			mod_script       = "reforged_in_fury_females/scripts/mods/reforged_in_fury_females/reforged_in_fury_females",
			mod_data         = "reforged_in_fury_females/scripts/mods/reforged_in_fury_females/reforged_in_fury_females_data",
			mod_localization = "reforged_in_fury_females/scripts/mods/reforged_in_fury_females/reforged_in_fury_females_localization",
		})
	end,
	packages = {},
}
