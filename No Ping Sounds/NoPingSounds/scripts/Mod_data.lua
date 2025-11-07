local mod = get_mod("NoPingSounds")
local widgets = {}

widgets[#widgets + 1] = {
	setting_id = "ping_mute_enemy",
	type = "checkbox",
	default_value = true,
	sub_widgets = {
		{
			setting_id = "ping_mute_enemy_in_front",
			type = "checkbox",
			default_value = true,
		},
	},
}
widgets[#widgets + 1] = {
	setting_id = "ping_mute_enemy_doubletag",
	type = "checkbox",
	default_value = true,
	sub_widgets = {
		{
			setting_id = "ping_mute_enemy_doubletag_in_front",
			type = "checkbox",
			default_value = true,
		},
	},
}
widgets[#widgets + 1] = {
	setting_id = "ping_mute_item",
	type = "checkbox",
	default_value = true,
}
widgets[#widgets + 1] = {
	setting_id = "ping_mute_location_ping",
	type = "checkbox",
	default_value = true,
}
widgets[#widgets + 1] = {
	setting_id = "ping_mute_location_attention",
	type = "checkbox",
	default_value = true,
}
widgets[#widgets + 1] = {
	setting_id = "ping_mute_location_threat",
	type = "checkbox",
	default_value = true,
}
widgets[#widgets + 1] = {
	setting_id = "debug",
	type = "checkbox",
	default_value = false,
	sub_widgets = {
		{
			setting_id = "debug_repeat_ping",
			type = "keybind",
			default_value = {},
			keybind_trigger = "pressed",
			keybind_type = "function_call",
			function_name = "debug_repeat_ping",
		},
		{
			setting_id = "ping_duration",
			type = "checkbox",
			default_value = false,
			sub_widgets = {
				{
					setting_id = "ping_duration_seconds",
					type = "numeric",
					default_value = 15,
					range = { 1, 60 * 2 },
				},
			},
		},
	},
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}
