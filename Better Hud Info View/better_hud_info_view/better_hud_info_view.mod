return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`better_hud_info_view` encountered an error loading the Darktide Mod Framework.")

		new_mod("better_hud_info_view", {
			mod_script       = "better_hud_info_view/scripts/mods/better_hud_info_view/better_hud_info_view",
			mod_data         = "better_hud_info_view/scripts/mods/better_hud_info_view/better_hud_info_view_data",
			mod_localization = "better_hud_info_view/scripts/mods/better_hud_info_view/better_hud_info_view_localization",
		})
	end,
	packages = {},
}