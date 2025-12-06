return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`CharacterGrid` encountered an error loading the Darktide Mod Framework.")

		new_mod("CharacterGrid", {
			mod_script       = "CharacterGrid/scripts/mods/CharacterGrid/CharacterGrid",
			mod_data         = "CharacterGrid/scripts/mods/CharacterGrid/CharacterGrid_data",
			mod_localization = "CharacterGrid/scripts/mods/CharacterGrid/CharacterGrid_localization",
		})
	end,
	packages = {},
}
