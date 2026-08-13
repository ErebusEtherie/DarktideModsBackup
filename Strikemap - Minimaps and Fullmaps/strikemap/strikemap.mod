return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`strikemap` encountered an error loading the Darktide Mod Framework.")

		new_mod("strikemap", {
			mod_script = "strikemap/scripts/mods/strikemap/strikemap",
			mod_data = "strikemap/scripts/mods/strikemap/strikemap_data",
			mod_localization = "strikemap/scripts/mods/strikemap/strikemap_localization",
		})
	end,
	packages = {},
}
