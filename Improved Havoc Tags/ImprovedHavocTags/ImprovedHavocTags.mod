return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ImprovedHavocTags` encountered an error loading the Darktide Mod Framework.")

		new_mod("ImprovedHavocTags", {
			mod_script       = "ImprovedHavocTags/scripts/mods/ImprovedHavocTags/ImprovedHavocTags",
			mod_data         = "ImprovedHavocTags/scripts/mods/ImprovedHavocTags/ImprovedHavocTags_data",
			mod_localization = "ImprovedHavocTags/scripts/mods/ImprovedHavocTags/ImprovedHavocTags_localization",
		})
	end,
	packages = {},
}
