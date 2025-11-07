local mod = get_mod("ScannerSuccessSound")
return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
		widgets = {
            {
				setting_id = "enable_debug_mode",
				type = "checkbox",
				default_value = false,
			},
            {
				setting_id = "use_audio",
				type = "checkbox",
				default_value = false,
			},
			{
                setting_id = "scan_sound",
				type = "dropdown",
				default_value = "sfx_scanning_sucess.events.scanner_equip",
        		options = {
                    {text = "scan_option_default", value = "sfx_scanning_sucess.events.scanner_equip"},
                    {text = "scan_option_ability_ogryn_taunt", value = "ability_shout.events.ogryn_taunt_shout"},
                    {text = "scan_option_ability_vent", value = "ability_shout.events.psyker_shout"},
                    {text = "scan_option_ability_voc", value = "ability_shout.events.veteran_combat_ability"},
                    {text = "scan_option_ability_book", value = "ability_shout.events.zealot_relic"},
                    -- {text = "scan_option_vet_ejaculate", value = "sfx_about_to_explode.events.plasmagun_p1_m1"}, -- too quiet and doesn't stop
                    -- Weapon sounds only work if you have the relevant item on you
                    --  ex. vet with psword and revolver can use psword activate sound, but not plasma eject
                    --{text = "scan_option_plasma_eject", value = "plasma_flask_disconnect.events.plasmagun_p1_m1"},
                    --{text = "scan_option_special_forcesword", value = "sfx_special_activate.events.forcesword_p1_m1"},
                    --{text = "scan_option_special_ogryn_powermaul", value = "sfx_special_activate.events.ogryn_powermaul_p1_m1"}, -- crusher too
                    --{text = "scan_option_special_powermaul", value = "sfx_special_activate.events.powermaul_p1_m1"},
                    --{text = "scan_option_special_powersword_2h", value = "sfx_special_activate.events.powersword_2h_p1_m1"},
                    --{text = "scan_option_special_powersword", value = "sfx_special_activate.events.powersword_p1_m1"},
                    --{text = "scan_option_special_thunderhammer", value = "sfx_special_activate.events.thunderhammer_2h_p1_m1"},
                }
			},
        }
	}
}
