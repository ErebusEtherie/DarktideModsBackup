return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`InstantCharacterChange` encountered an error loading the Darktide Mod Framework.")

		new_mod("InstantCharacterChange", {
			mod_script       = "InstantCharacterChange/scripts/mods/InstantCharacterChange/InstantCharacterChange",
			mod_data         = "InstantCharacterChange/scripts/mods/InstantCharacterChange/InstantCharacterChange_data",
			mod_localization = "InstantCharacterChange/scripts/mods/InstantCharacterChange/InstantCharacterChange_localization",
		})
	end,
	packages = {},
}
