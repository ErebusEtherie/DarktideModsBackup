return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`outline_colours` encountered an error loading the Darktide Mod Framework.")

		new_mod("outline_colours", {
			mod_script       = "outline_colours/scripts/mods/outline_colours/outline_colours",
			mod_data         = "outline_colours/scripts/mods/outline_colours/outline_colours_data",
			mod_localization = "outline_colours/scripts/mods/outline_colours/outline_colours_localization",
		})
	end,
	packages = {},
}
