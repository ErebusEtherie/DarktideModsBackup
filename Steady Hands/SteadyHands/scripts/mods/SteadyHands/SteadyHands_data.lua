local mod = get_mod("SteadyHands")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "preset_mode",
				type = "dropdown",
				default_value = "balanced",
				options = {
					{text = "preset_vanilla_plus", value = "vanilla_plus"},
					{text = "preset_balanced", value = "balanced"},
					{text = "preset_minimal", value = "minimal"},
					{text = "preset_custom", value = "custom"},
				},
			},
			{
				setting_id = "camera_recoil_scale",
				type = "numeric",
				default_value = 65,
				range = {0, 100},
			},
			{
				setting_id = "weapon_recoil_scale",
				type = "numeric",
				default_value = 70,
				range = {0, 100},
			},
			{
				setting_id = "ads_sway_scale",
				type = "numeric",
				default_value = 75,
				range = {0, 100},
			},
			{
				setting_id = "hipfire_sway_scale",
				type = "numeric",
				default_value = 85,
				range = {0, 100},
			},
			{
				setting_id = "recoil_blend_speed",
				type = "numeric",
				default_value = 70,
				range = {0, 100},
			},
			{
				setting_id = "reduce_camera_shake",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "reduce_screen_bob",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "debug_mode",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "echo_runtime_values",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "apply_preset_hotkey",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "cycle_preset_hotkey",
			},
			{
				setting_id = "dump_debug_hotkey",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "dump_debug_hotkey",
			},
		},
	},
}