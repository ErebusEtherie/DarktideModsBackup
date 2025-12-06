local mod = get_mod("BrokerAutoStim")

	return {
		name = mod:localize("mod_name"),
		description = mod:localize("mod_description"),
		is_togglable = true,
		options = {
			widgets = {
				{
					setting_id      = "toggle_hotkey",
					type            = "keybind",
					default_value   = {},
					keybind_trigger = "pressed",
					keybind_type    = "function_call",
					function_name   = "toggle_auto_stim"
				},
				{
					setting_id    = "only_with_chemical_dependency",
					type          = "checkbox",
					default_value = false
				},
				{
					setting_id      = "stim_trigger_mode",
					type            = "dropdown",
					default_value   = "combat_only",
					options         = {
						{
							text = "stim_trigger_mode_combat_only",
							value = "combat_only"
						},
						{
							text = "stim_trigger_mode_non_combat_only",
							value = "non_combat_only"
						},
						{
							text = "stim_trigger_mode_after_ability",
							value = "after_ability_end"
						},
						{
							text = "stim_trigger_mode_before_ability",
							value = "on_ability_use"
						},
						{
							text = "stim_trigger_mode_always_stim",
							value = "always_stim"
						}
					},
					sub_widgets = {
						{
							setting_id      = "combat_duration",
							type            = "numeric",
							default_value   = 5.0,
							range           = { 0.5, 90.0 },
							decimals_number = 1
						},
						{
							setting_id      = "out_of_combat_timeout",
							type            = "numeric",
							default_value   = 5.0,
							range           = { 1.0, 30.0 },
							decimals_number = 1
						}
					}
				},
				{
					setting_id    = "enable_debug",
					type          = "checkbox",
					default_value = false
				},
			}
		}
	}
