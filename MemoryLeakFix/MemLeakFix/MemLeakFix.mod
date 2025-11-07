return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MemLeakFix` encountered an error loading the Darktide Mod Framework.")

		new_mod("MemLeakFix", {
			mod_script       = "MemLeakFix/scripts/mods/MemLeakFix/MemLeakFix",
			mod_data         = "MemLeakFix/scripts/mods/MemLeakFix/MemLeakFix_data",
			mod_localization = "MemLeakFix/scripts/mods/MemLeakFix/MemLeakFix_localization",
		})
	end,
	packages = {},
}
