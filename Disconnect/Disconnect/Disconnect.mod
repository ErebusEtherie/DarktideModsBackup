return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Disconnect` encountered an error loading the Darktide Mod Framework.")

		new_mod("Disconnect", {
			mod_script       = "Disconnect/scripts/mods/Disconnect/Disconnect",
			mod_data         = "Disconnect/scripts/mods/Disconnect/Disconnect_data",
			mod_localization = "Disconnect/scripts/mods/Disconnect/Disconnect_localization",
		})
	end,
	packages = {},
}
