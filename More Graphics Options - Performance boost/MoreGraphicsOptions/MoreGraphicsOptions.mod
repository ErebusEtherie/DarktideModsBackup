return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MoreGraphicsOptions` encountered an error loading the Darktide Mod Framework.")

		new_mod("MoreGraphicsOptions", {
			mod_script       = "MoreGraphicsOptions/scripts/mods/MoreGraphicsOptions/MoreGraphicsOptions",
			mod_data         = "MoreGraphicsOptions/scripts/mods/MoreGraphicsOptions/MoreGraphicsOptions_data",
			mod_localization = "MoreGraphicsOptions/scripts/mods/MoreGraphicsOptions/MoreGraphicsOptions_localization",
		})
	end,
	packages = {},
}
