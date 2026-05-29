return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`GiftShredder` encountered an error loading the Darktide Mod Framework.")

		new_mod("GiftShredder", {
			mod_script       = "GiftShredder/scripts/mods/GiftShredder/GiftShredder",
			mod_data         = "GiftShredder/scripts/mods/GiftShredder/GiftShredder_data",
			mod_localization = "GiftShredder/scripts/mods/GiftShredder/GiftShredder_localization",
		})
	end,
	packages = {},
}
