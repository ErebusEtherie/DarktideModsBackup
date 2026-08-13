return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SimpleBuffFilter` encountered an error loading the Darktide Mod Framework.")

		new_mod("SimpleBuffFilter", {
			mod_script       = "SimpleBuffFilter/scripts/mods/SimpleBuffFilter/SimpleBuffFilter",
			mod_data         = "SimpleBuffFilter/scripts/mods/SimpleBuffFilter/SimpleBuffFilter_data",
			mod_localization = "SimpleBuffFilter/scripts/mods/SimpleBuffFilter/SimpleBuffFilter_localization",
		})
	end,
	packages = {},
}
