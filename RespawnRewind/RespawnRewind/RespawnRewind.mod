return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`RespawnRewind` encountered an error loading the Darktide Mod Framework.")

		new_mod("RespawnRewind", {
			mod_script       = "RespawnRewind/scripts/mods/RespawnRewind/RespawnRewind",
			mod_data         = "RespawnRewind/scripts/mods/RespawnRewind/RespawnRewind_data",
			mod_localization = "RespawnRewind/scripts/mods/RespawnRewind/RespawnRewind_localization",
		})
	end,
	packages = {},
}
