return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`menu_hotkeys` encountered an error loading the Darktide Mod Framework.")

		new_mod("menu_hotkeys", {
			mod_script       = "menu_hotkeys/menu_hotkeys",
			mod_data         = "menu_hotkeys/menu_hotkeys_data",
			mod_localization = "menu_hotkeys/menu_hotkeys_localization",
		})
	end,
	packages = {},
}
