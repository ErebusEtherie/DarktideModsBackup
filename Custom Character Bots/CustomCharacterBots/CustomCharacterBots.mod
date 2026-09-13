return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Custom Character Bots` requires the Darktide Mod Framework.")

		new_mod("CustomCharacterBots", {
			mod_script = "CustomCharacterBots/scripts/mods/CustomCharacterBots/CustomCharacterBots",
			mod_data = "CustomCharacterBots/scripts/mods/CustomCharacterBots/CustomCharacterBots_data",
			mod_localization = "CustomCharacterBots/scripts/mods/CustomCharacterBots/CustomCharacterBots_localization",
		})
	end,
	packages = {},
	version = "0.2.3",
}
