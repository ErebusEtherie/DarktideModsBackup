return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`whats_in_the_box` encountered an error loading the Darktide Mod Framework.")

		new_mod("whats_in_the_box", {
			mod_script       = "whats_in_the_box/scripts/mods/whats_in_the_box/whats_in_the_box",
			mod_data         = "whats_in_the_box/scripts/mods/whats_in_the_box/whats_in_the_box_data",
			mod_localization = "whats_in_the_box/scripts/mods/whats_in_the_box/whats_in_the_box_localization",
		})
	end,
	packages = {},
}
