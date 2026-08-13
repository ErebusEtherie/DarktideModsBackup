return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AutoPing` encountered an error loading the Darktide Mod Framework.")

		new_mod("AutoPing", {
			mod_script       = "AutoPing/scripts/mods/AutoPing/AutoPing",
			mod_data         = "AutoPing/scripts/mods/AutoPing/AutoPing_data",
			mod_localization = "AutoPing/scripts/mods/AutoPing/AutoPing_localization",
		})
	end,
	packages = {},
}
