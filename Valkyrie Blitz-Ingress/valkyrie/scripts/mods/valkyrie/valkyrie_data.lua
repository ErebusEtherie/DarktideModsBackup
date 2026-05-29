-- valkyrie_data.lua
local mod = get_mod("valkyrie")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "mute_lobby_mission",
				type = "checkbox",
				default_value = true,
				title = "MuteLobbyTitle",
			},
			{
				setting_id = "silence_expeditions",
				type = "checkbox",
				default_value = true,
				title = "SilenceExpeditionsTitle",
			},
			{
				setting_id = "report_timing",
				type = "dropdown",
				default_value = "valkyrie_start",
				title = "ReportTimingTitle",
				tooltip = "ReportTimingTooltip",
				options = {
					{text = "ReportTimingNone", value = "none"},
					{text = "ReportTimingValkyrieStart", value = "valkyrie_start"},
					{text = "ReportTimingMissionStart", value = "mission_start"},
				},
			},
			{
				setting_id = "hide_mission_screen",
				type = "checkbox",
				default_value = true,
				title = "MissionHologramTitle",
			},
			{
				setting_id = "steady_camera",
				type = "checkbox",
				default_value = false,
				title = "SteadyCameraTitle",
			},
			{
				setting_id = "show_who",
				type = "dropdown",
				default_value = "default",
				title = "ShowWhoTitle",
				options = {
					{text = "ShowWhoDefault", value = "default"},
					{text = "ShowWhoNoOne", value = "no_one"},
					{text = "ShowWhoOnlyMe", value = "only_me"},
				},
			},
			{
				setting_id = "experimental",
				type = "dropdown",
				default_value = "none",
				title = "ExperimentalTitle",
				tooltip = "ExperimentalTooltip",
				options = {
					{text = "ExperimentalNone", value = "none"},
					{text = "ExperimentalExtraBots", value = "extra_bots"},
					{text = "ExperimentalNoUniforms", value = "no_uniforms"},
					{text = "ExperimentalWeaponPresentation", value = "weapon_presentation"},
				},
			},
		},
	},
}
