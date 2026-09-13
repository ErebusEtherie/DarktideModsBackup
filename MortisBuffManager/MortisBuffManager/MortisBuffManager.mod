return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MortisBuffManager` could not load the Darktide Mod Framework.")

		new_mod("MortisBuffManager", {
			mod_script = "MortisBuffManager/scripts/mods/MortisBuffManager/MortisBuffManager",
			mod_data = "MortisBuffManager/scripts/mods/MortisBuffManager/MortisBuffManager_data",
			mod_localization = "MortisBuffManager/scripts/mods/MortisBuffManager/MortisBuffManager_localization",
		})
	end,
	-- Mortis Buff templates reference particles and other gameplay resources that
	-- ordinary adventure/Havoc levels do not load. Keep the native Mortis level
	-- package resident on every peer for the lifetime of the Mod; otherwise a
	-- networked periodic Buff can crash a host or guest when its first VFX fires.
	packages = {
		"content/levels/horde/missions/mission_psykhanium",
        "packages/ui/constant_elements/mission_buffs/mission_buffs",
	},
}
