return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`InventoryHider` encountered an error loading the Darktide Mod Framework.")

		new_mod("InventoryHider", {
			mod_script       = "InventoryHider/scripts/mods/InventoryHider/InventoryHider",
			mod_data         = "InventoryHider/scripts/mods/InventoryHider/InventoryHider_data",
			mod_localization = "InventoryHider/scripts/mods/InventoryHider/InventoryHider_localization",
		})
	end,
	packages = {},
}
