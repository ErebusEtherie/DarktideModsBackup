return {
	run = function()
		fassert(rawget(_G, "new_mod"), "better_tox_gas must be lower than Darktide Mod Framework in your launcher's load order")
		new_mod("better_tox_gas", {
			mod_script       = "better_tox_gas/scripts/mods/better_tox_gas/better_tox_gas",
			mod_data         = "better_tox_gas/scripts/mods/better_tox_gas/better_tox_gas_data",
			mod_localization = "better_tox_gas/scripts/mods/better_tox_gas/better_tox_gas_localization",
		})
	end,
	packages = {},
}
