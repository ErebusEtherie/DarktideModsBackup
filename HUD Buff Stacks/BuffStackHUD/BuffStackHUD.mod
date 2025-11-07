return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BuffStackHUD` encountered an error loading the Darktide Mod Framework.")

		new_mod("BuffStackHUD", {
			mod_script       = "BuffStackHUD/scripts/mods/BuffStackHUD/BuffStackHUD",
			mod_data         = "BuffStackHUD/scripts/mods/BuffStackHUD/BuffStackHUD_data",
			mod_localization = "BuffStackHUD/scripts/mods/BuffStackHUD/BuffStackHUD_localization",
		})
	end,
	packages = {},
}
