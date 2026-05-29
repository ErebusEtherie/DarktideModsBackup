return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`valkyrie_dog` encountered an error loading the Darktide Mod Framework.")

		new_mod("valkyrie_dog", {
			mod_script       = "valkyrie_dog/scripts/mods/valkyrie_dog/valkyrie_dog",
			mod_data         = "valkyrie_dog/scripts/mods/valkyrie_dog/valkyrie_dog_data",
			mod_localization = "valkyrie_dog/scripts/mods/valkyrie_dog/valkyrie_dog_localization",
		})
	end,
	packages = {},
}
