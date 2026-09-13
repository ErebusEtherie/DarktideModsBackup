return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`hud_studio` encountered an error loading the Darktide Mod Framework.")

		new_mod("hud_studio", {
			mod_script       = "hud_studio/scripts/mods/hud_studio/hud_studio",
			mod_data         = "hud_studio/scripts/mods/hud_studio/hud_studio_data",
			mod_localization = "hud_studio/scripts/mods/hud_studio/hud_studio_localization",
		})
	end,
	packages = {},
}
