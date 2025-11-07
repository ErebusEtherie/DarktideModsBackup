return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Decode_Helper` encountered an error loading the Darktide Mod Framework.")

		new_mod("Decode_Helper", {
			mod_script       = "Decode_Helper/scripts/mods/Decode_Helper/Decode_Helper",
			mod_data         = "Decode_Helper/scripts/mods/Decode_Helper/Decode_Helper_data",
			mod_localization = "Decode_Helper/scripts/mods/Decode_Helper/Decode_Helper_localization",
		})
	end,
	packages = {},
}
