return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`weapon_action_details` encountered an error loading the Darktide Mod Framework.")

		new_mod("weapon_action_details", {
			mod_script       = "weapon_action_details/scripts/mods/weapon_action_details/weapon_action_details",
			mod_data         = "weapon_action_details/scripts/mods/weapon_action_details/weapon_action_details_data",
			mod_localization = "weapon_action_details/scripts/mods/weapon_action_details/weapon_action_details_localization",
		})
	end,
	packages = {},
}
