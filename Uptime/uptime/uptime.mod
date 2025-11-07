return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`uptime` encountered an error loading the Darktide Mod Framework.")

		new_mod("uptime", {
			mod_script       = "uptime/scripts/mods/uptime/uptime",
			mod_data         = "uptime/scripts/mods/uptime/uptime_data",
			mod_localization = "uptime/scripts/mods/uptime/uptime_localization",
		})
	end,
	packages = {},
}
