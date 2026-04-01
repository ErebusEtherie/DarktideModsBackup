return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`voc_outline` encountered an error loading the Darktide Mod Framework.")

		new_mod("voc_outline", {
			mod_script       = "voc_outline/scripts/mods/voc_outline/voc_outline",
			mod_data         = "voc_outline/scripts/mods/voc_outline/voc_outline_data",
			mod_localization = "voc_outline/scripts/mods/voc_outline/voc_outline_localization",
		})
	end,
	packages = {},
}
