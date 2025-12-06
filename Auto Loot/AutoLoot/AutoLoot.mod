return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AutoLoot` encountered an error loading the Darktide Mod Framework.")

		new_mod("AutoLoot", {
			mod_script       = "AutoLoot/scripts/mods/AutoLoot/AutoLoot",
			mod_data         = "AutoLoot/scripts/mods/AutoLoot/AutoLoot_data",
			mod_localization = "AutoLoot/scripts/mods/AutoLoot/AutoLoot_localization",
		})
	end,
	packages = {},
}
