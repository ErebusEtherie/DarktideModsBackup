return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BrokerStimTimer` encountered an error loading the Darktide Mod Framework.")

		new_mod("BrokerStimTimer", {
			mod_script = "BrokerStimTimer/scripts/mods/BrokerStimTimer/BrokerStimTimer",
			mod_data = "BrokerStimTimer/scripts/mods/BrokerStimTimer/BrokerStimTimer_data",
			mod_localization = "BrokerStimTimer/scripts/mods/BrokerStimTimer/BrokerStimTimer_localization",
		})
	end,
	packages = {},
}

