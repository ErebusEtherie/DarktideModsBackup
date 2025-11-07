return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`auto_rations` encountered an error loading the Darktide Mod Framework.")

		new_mod("auto_rations", {
			mod_script       = "auto_rations/scripts/mods/auto_rations/auto_rations",
			mod_data         = "auto_rations/scripts/mods/auto_rations/auto_rations_data",
			mod_localization = "auto_rations/scripts/mods/auto_rations/auto_rations_localization",
		})
	end,
	packages = {},
}
