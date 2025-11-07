local mod = get_mod("LessAnnoyingPing")
--SEE scripts/settings/ui/ui_sound_events.lua

return {
	name = "LessAnnoyingPing",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "setting_key_enable",
				default_value = {},
				type = "keybind",
				keybind_trigger = "pressed",
				keybind_type = "mod_toggle",
			},
			{
				setting_id = "setting_sound_replace",
				default_value = true,
				type = "checkbox",
				sub_widgets = {
					{
						setting_id = "setting_sound_to_play",
						type = "dropdown",
						default_value = "wwise/events/ui/play_smart_tag_location_default_enter",
						options = {
							{
								text = "smart_tag_eye",
								value = "wwise/events/ui/play_smart_tag_location_default_enter",
							},
							{
								text = "play_ui_mastery_trait_unlock_blocked",
								value = "wwise/events/ui/play_ui_mastery_trait_unlock_blocked",
							},
							{
								text = "auspex_bio_minigame_selection_wrong",
								value = "wwise/events/player/play_device_auspex_bio_minigame_selection_wrong",
							},
							{
								text = "auspex_scanner_minigame_progress",
								value = "wwise/events/player/play_device_auspex_scanner_minigame_progress",
							},
							{
								text = "auspex_scanner_minigame_progress_last",
								value = "wwise/events/player/play_device_auspex_scanner_minigame_progress_last",
							},
							{
								text = "play_ui_click",
								value = "wwise/events/ui/play_ui_click",
							},
							{
								text = "play_ui_character_loadout_discard_weapon_complete",
								value = "wwise/events/ui/play_ui_character_loadout_discard_weapon_complete",
							},
							{
								text = "play_ui_penances_wintrack_bar_start",
								value = "wwise/events/ui/play_ui_penances_wintrack_bar_start",
							},

							{
								text = "play_ui_mastery_trait_unlocked_rank_1",
								value = "wwise/events/ui/play_ui_mastery_trait_unlocked",
							},
							{
								text = "play_ui_mastery_trait_unlocked_rank_2",
								value = "wwise/events/ui/play_ui_mastery_trait_unlocked_rank_2",
							},
							{
								text = "play_ui_mastery_trait_unlocked_rank_3",
								value = "wwise/events/ui/play_ui_mastery_trait_unlocked_rank_3",
							},
							{
								text = "play_ui_mastery_trait_unlocked_rank_4",
								value = "wwise/events/ui/play_ui_mastery_trait_unlocked_rank_4",
							},
						},
					},
				},
			},
			{
				setting_id = "setting_skip_self_sound",
				default_value = false,
				type = "checkbox",
			},
			{
				setting_id = "setting_delay",
				type = "numeric",
				default_value = 100,
				range = { 100, 1000 },
			},
			{
				setting_id = "setting_skip_same_target",
				default_value = true,
				type = "checkbox",
				sub_widgets = {
					{
						setting_id = "setting_delay_same",
						type = "numeric",
						default_value = 666,
						range = { 100, 1000 },
					},
				},
			},

			{
				setting_id = "setting_enable_debug_mode",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
