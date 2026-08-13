return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AutoBlitz` encountered an error loading the Darktide Mod Framework.")

		new_mod("AutoBlitz", {
			mod_script       = "AutoBlitz/scripts/mods/AutoBlitz/AutoBlitz",
			mod_data         = "AutoBlitz/scripts/mods/AutoBlitz/AutoBlitz_data",
			mod_localization = "AutoBlitz/scripts/mods/AutoBlitz/AutoBlitz_localization",
		})
	end,
	packages = {},
}
