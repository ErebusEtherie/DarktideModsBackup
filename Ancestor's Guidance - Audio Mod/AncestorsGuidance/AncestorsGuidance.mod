return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`AncestorsGuidance` encountered an error loading the Darktide Mod Framework.")

		new_mod("AncestorsGuidance", {
			mod_script       = "AncestorsGuidance/scripts/mods/AncestorsGuidance/AncestorsGuidance",
			mod_data         = "AncestorsGuidance/scripts/mods/AncestorsGuidance/AncestorsGuidance_data",
			mod_localization = "AncestorsGuidance/scripts/mods/AncestorsGuidance/AncestorsGuidance_localization",
		})
	end,
	packages = {},
}
