return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`EmperorsGuidance` encountered an error loading the Darktide Mod Framework.")

		new_mod("EmperorsGuidance", {
			mod_script       = "EmperorsGuidance/scripts/mods/EmperorsGuidance/EmperorsGuidance",
			mod_data         = "EmperorsGuidance/scripts/mods/EmperorsGuidance/EmperorsGuidance_data",
			mod_localization = "EmperorsGuidance/scripts/mods/EmperorsGuidance/EmperorsGuidance_localization",
		})
	end,
	load_after = {
    "StickySprint",
    "DecodeMinigameSolver",
	"FullAuto"
    },
	packages = {},
}
