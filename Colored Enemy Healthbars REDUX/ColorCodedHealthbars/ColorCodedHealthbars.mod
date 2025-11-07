return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`ColorCodedHealthbars` encountered an error loading the Darktide Mod Framework.")

		new_mod("ColorCodedHealthbars", {
			mod_script       = "ColorCodedHealthbars/scripts/mods/ColorCodedHealthbars/ColorCodedHealthbars",
			mod_data         = "ColorCodedHealthbars/scripts/mods/ColorCodedHealthbars/ColorCodedHealthbars_data",
			mod_localization = "ColorCodedHealthbars/scripts/mods/ColorCodedHealthbars/ColorCodedHealthbars_localization",
		})
	end,
	packages = {},
}