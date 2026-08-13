local localizations = {
    mod_name = {
        en = "Scanner Success Sound",
    },
    mod_description = {
        en = "Changes sound that plays when scan completes",
    },
    enable_debug_mode = {
		en = "Debug Mode",
	},
	enable_debug_mode_description = {
		en = "Enables verbose logging",
	},
    use_audio = {
		en = "Custom Audio",
	},
	use_audio_description = {
		en = "Use sound from Simple Audio or the Audio Plugin, with Simple Audio having priority.\nIf this is enabled, the option from the dropdown menu will NOT be used.",
	},
    error_no_audio_frameworks = {
        en = "Simple Audio or the Audio plugin is required for this option!",
    },
    audio_volume = {
        en = "Volume for Custom Audio",
    },
    audio_volume_description = {
        en = "Adjusts volume of sound.\nNote: SimpleAudio supports 0 to 200%, but Audio only supports 0 to 100%. If you use a value above 100 for Audio, it will just stay at 100.",
    },
    audio_volume_units = {
        -- Lua needs %% to show a %, else it goes for regex
        en = "%%",
    },
    scan_sound = {
        en = "Auspex Scanner Completion Sound"
    },
}

-- I don't know why I put these out here lol
localizations['scan_option_default'] = { en = "Default" }
localizations['scan_option_ability_ogryn_taunt'] = { en = Localize("loc_ability_ogryn_taunt_shout") }
localizations['scan_option_ability_vent'] = { en = Localize("loc_talent_psyker_shout_vent_warp_charge") }
localizations['scan_option_ability_voc'] = { en = Localize("loc_talent_veteran_combat_ability_stagger_nearby_enemies") }
localizations['scan_option_ability_book'] = { en = Localize("loc_talent_zealot_bolstering_prayer") }
--localizations['scan_option_plasma_eject'] = { en = "Plasma Eject" }
--localizations['scan_option_special_forcesword'] = { en = "Special Activation: Force Sword" }
--localizations['scan_option_special_ogryn_powermaul'] = { en = "Special Activation: Crusher/Ogryn Power Maul" }
--localizations['scan_option_special_powermaul'] = { en = "Special Activation: Shock Maul" }
--localizations['scan_option_special_powersword_2h'] = { en = "Special Activation: Relic Blade" }
--localizations['scan_option_special_powersword'] = { en = "Special Activation: Power Sword" }
--localizations['scan_option_special_thunderhammer'] = { en = "Special Activation: Thunder Hammer" }

return localizations