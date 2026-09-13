return {
	run = function()
		-- If DMF has not loaded yet, `new_mod` does not exist. Erroring here with a clear
		-- message is much kinder than the nil-call crash the user would otherwise get.
		if not rawget(_G, "new_mod") then
			error("Pilgrimage must be lower than Darktide Mod Framework in your mod load order.")
		end

		new_mod("Pilgrimage", {
			mod_script       = "Pilgrimage/scripts/mods/Pilgrimage/Pilgrimage",
			mod_data         = "Pilgrimage/scripts/mods/Pilgrimage/Pilgrimage_data",
			mod_localization = "Pilgrimage/scripts/mods/Pilgrimage/Pilgrimage_localization",
		})
	end,
	-- Optional ordering only. If EWC is installed, its public plugin API must
	-- exist before Pilgrimage publishes the owned skin catalogue. Missing EWC
	-- remains a supported configuration.
	load_after = {
		"extended_weapon_customization",
		"Realms",
	},

	-- No engine asset packages yet. When we spawn a physical terminal unit in the hub,
	-- its package goes in this list.
	packages = {},
}
