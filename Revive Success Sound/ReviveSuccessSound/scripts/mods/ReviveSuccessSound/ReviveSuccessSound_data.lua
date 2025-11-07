local mod = get_mod("ReviveSuccessSound")
return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "option_completion_sound",
                type = "dropdown",
                default_value = "wwise/events/ui/play_ui_empower_weapon",
                options = {
                    {
                        text = "sound_option_minigame_progress_last",
                        value = "wwise/events/player/play_device_auspex_scanner_minigame_progress_last"
                    },
                    {
                        text = "sound_option_minigame_sinus",
                        value = "wwise/events/player/play_device_auspex_scanner_minigame_sinus_aligned"
                    },
                    {
                        text = "sound_option_minigame_success",
                        value = "wwise/events/player/play_device_auspex_scanner_minigame_progress",
                    },
                    {
                        text = "sound_option_confirm",
                        value = "wwise/events/ui/play_ui_character_create_confirm_create_character"
                    },
                    {
                        text = "sound_option_empower",
                        value = "wwise/events/ui/play_ui_empower_weapon"
                    },
                    {
                        text = "sound_option_empower_max",
                        value = "wwise/events/ui/play_ui_empower_weapon_max"
                    },
                    {
                        text = "sound_option_item_granted",
                        value = "wwise/events/ui/play_ui_eor_item_granted_tier_3"
                    },
                    {
                        text = "sound_option_upgrade_item",
                        value = "wwise/events/ui/play_ui_npc_interacts_forge_upgrade_item"
                    },
                    {
                        text = "sound_option_level_up",
                        value = "wwise/events/ui/play_ui_eor_mastery_xp_level_up"
                    },
                    {
                        text = "sound_option_new_objective",
                        value = "wwise/events/ui/play_hud_tg_new_objective"
                    },
                    {
                        text = "sound_option_overload",
                        value = "wwise/events/weapon/play_plasmagun_overheat_intensity_02"
                    },
                    {
                        text = "sound_option_penance_reward",
                        value = "wwise/events/ui/play_ui_penances_reward_reached"
                    },
                    {
                        text = "sound_option_player_ready",
                        value = "wwise/events/ui/play_ui_mission_lobby_players_rdy"
                    },
                    {
                        text = "sound_option_traits_rank_up",
                        value = "wwise/events/ui/play_ui_mastery_traits_rank_up"
                    },
                    {
                        text = "sound_option_traits_rank_up_max",
                        value = "wwise/events/ui/play_ui_mastery_traits_rank_up_max"
                    },
                    {
                        text = "sound_option_stinger",
                        value = "wwise/events/ui/play_ui_eor_start_stinger"
                    },
                    {
                        text = "sound_option_warning",
                        value = "wwise/events/ui/play_hud_notifications_warning"
                    },
                }
            },
            {
                setting_id = "option_amplify",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "option_play_for_others",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "option_debug_mode",
                type = "checkbox",
                default_value = false,
            },
        }
    }
}
