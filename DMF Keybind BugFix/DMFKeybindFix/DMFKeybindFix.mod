return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`DMFKeybindFix` encountered an error loading the Darktide Mod Framework.")

		new_mod("DMFKeybindFix", {
			mod_script       = "DMFKeybindFix/scripts/mods/DMFKeybindFix/DMFKeybindFix",
			mod_data         = "DMFKeybindFix/scripts/mods/DMFKeybindFix/DMFKeybindFix_data",
			mod_localization = "DMFKeybindFix/scripts/mods/DMFKeybindFix/DMFKeybindFix_localization",
		})
	end,
	packages = {},
}
