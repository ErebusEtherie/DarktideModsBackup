return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`RingHud` encountered an error loading the Darktide Mod Framework.")

		new_mod("RingHud", {
			mod_script       = "RingHud/scripts/mods/RingHud/RingHud",
			mod_data         = "RingHud/scripts/mods/RingHud/RingHud_data",
			mod_localization = "RingHud/scripts/mods/RingHud/RingHud_localization",
		})
	end,
	packages = {},
}
