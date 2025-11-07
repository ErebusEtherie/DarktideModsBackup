return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AutoVault` encountered an error loading the Darktide Mod Framework.")

		new_mod("AutoVault", {
			mod_script       = "AutoVault/scripts/mods/AutoVault/AutoVault",
			mod_data         = "AutoVault/scripts/mods/AutoVault/AutoVault_data",
			mod_localization = "AutoVault/scripts/mods/AutoVault/AutoVault_localization",
		})
	end,
	packages = {},
}
