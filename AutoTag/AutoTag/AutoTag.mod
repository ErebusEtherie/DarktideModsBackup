return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AutoTag` encountered an error loading the Darktide Mod Framework.")

		new_mod("AutoTag", {
			mod_script       = "AutoTag/scripts/mods/AutoTag/AutoTag",
			mod_data         = "AutoTag/scripts/mods/AutoTag/AutoTag_data",
			mod_localization = "AutoTag/scripts/mods/AutoTag/AutoTag_localization",
		})
	end,
	packages = {},
}
