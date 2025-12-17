return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PlasmaGunLagFix` encountered an error loading the Darktide Mod Framework.")

		new_mod("PlasmaGunLagFix", {
			mod_script       = "PlasmaGunLagFix/scripts/mods/PlasmaGunLagFix/PlasmaGunLagFix",
			mod_data         = "PlasmaGunLagFix/scripts/mods/PlasmaGunLagFix/PlasmaGunLagFix_data",
			mod_localization = "PlasmaGunLagFix/scripts/mods/PlasmaGunLagFix/PlasmaGunLagFix_localization",
		})
	end,
	packages = {},
}
