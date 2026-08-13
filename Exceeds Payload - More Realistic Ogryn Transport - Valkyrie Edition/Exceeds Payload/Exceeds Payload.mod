return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Exceeds Payload` encountered an error loading the Darktide Mod Framework.")

		new_mod("Exceeds Payload", {
			mod_script       = "Exceeds Payload/scripts/mods/Exceeds Payload/Exceeds Payload",
			mod_data         = "Exceeds Payload/scripts/mods/Exceeds Payload/Exceeds Payload_data",
			mod_localization = "Exceeds Payload/scripts/mods/Exceeds Payload/Exceeds Payload_localization",
		})
	end,
	version = "1.0",
	packages = {},
}
