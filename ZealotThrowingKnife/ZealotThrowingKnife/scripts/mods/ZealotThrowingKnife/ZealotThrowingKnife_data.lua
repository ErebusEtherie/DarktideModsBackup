local mod = get_mod("ZealotThrowingKnife")

local create_checkbox = function(id, default, title)
	return {
		setting_id = id,
		type = "checkbox",
		default_value = default,
		title = title or id,
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	allow_rehooking = true,
	options = {
		widgets = {
			-- Global settings group
			{
				setting_id = "global_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "mod_enabled",
						type = "checkbox",
						default_value = true,
						text = "mod_enabled",
						tooltip = "mod_enabled_tooltip",
					},
					{
						setting_id = "mod_enable_toggle",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "toggle_mod",
						text = "mod_enable_toggle",
						tooltip = "mod_enable_toggle_tooltip",
					},
					{
						setting_id = "switch_ranged_no_throw",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "switch_to_ranged_no_throw",
						text = "switch_ranged_no_throw",
						tooltip = "switch_ranged_no_throw_tooltip",
					},
					{
						setting_id = "mod_enable_verbose",
						type = "checkbox",
						default_value = false,
						text = "mod_enable_verbose",
						tooltip = "mod_enable_verbose_tooltip",
					},
					{
						setting_id = "mod_enable_debug",
						type = "checkbox",
						default_value = false,
						text = "mod_enable_debug",
						tooltip = "mod_enable_debug_tooltip",
					},
				},
			},
			{
				setting_id = "weapon_settings",
				type = "group",
				sub_widgets = {
					-- Flamer
					{
						setting_id = "group_flamer",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_flamer_p1_m1", true, "flamer_p1_m1"),
						},
					},
					-- Bolter
					{
						setting_id = "group_bolter",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_bolter_p1_m1", true, "bolter_p1_m1"),
							create_checkbox("enable_bolter_p1_m2", true, "bolter_p1_m2"),
						},
					},
					-- Boltpistol
					{
						setting_id = "group_boltpistol",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_boltpistol_p1_m1", true, "boltpistol_p1_m1"),
							create_checkbox("enable_boltpistol_p1_m2", true, "boltpistol_p1_m2"),
						},
					},
					-- Stub Revolver
					{
						setting_id = "group_stubrevolver",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_stubrevolver_p1_m1", true, "stubrevolver_p1_m1"),
							create_checkbox("enable_stubrevolver_p1_m2", true, "stubrevolver_p1_m2"),
						},
					},
					-- Shotguns
					{
						setting_id = "group_shotgun",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_shotgun_p1_m1", true, "shotgun_p1_m1"),
							create_checkbox("enable_shotgun_p1_m2", true, "shotgun_p1_m2"),
							create_checkbox("enable_shotgun_p1_m3", true, "shotgun_p1_m3"),
							create_checkbox("enable_shotgun_p2_m1", true, "shotgun_p2_m1"),
						},
					},
					-- Autogun
					{
						setting_id = "group_autogun",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_autogun_p1_m1", true, "autogun_p1_m1"),
							create_checkbox("enable_autogun_p1_m2", true, "autogun_p1_m2"),
							create_checkbox("enable_autogun_p1_m3", true, "autogun_p1_m3"),
							create_checkbox("enable_autogun_p2_m1", true, "autogun_p2_m1"),
							create_checkbox("enable_autogun_p2_m2", true, "autogun_p2_m2"),
							create_checkbox("enable_autogun_p2_m3", true, "autogun_p2_m3"),
							create_checkbox("enable_autogun_p3_m1", true, "autogun_p3_m1"),
							create_checkbox("enable_autogun_p3_m2", true, "autogun_p3_m2"),
							create_checkbox("enable_autogun_p3_m3", true, "autogun_p3_m3"),
						},
					},
					-- Autopistol
					{
						setting_id = "group_autopistol",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_autopistol_p1_m1", true, "autopistol_p1_m1"),
						},
					},
					-- Laspistol
					{
						setting_id = "group_laspistol",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_laspistol_p1_m1", true, "laspistol_p1_m1"),
							create_checkbox("enable_laspistol_p1_m3", true, "laspistol_p1_m3"),
						},
					},
					-- Lasgun (only p1 and p3, removed p2 Lucius)
					{
						setting_id = "group_lasgun",
						type = "group",
						sub_widgets = {
							create_checkbox("enable_lasgun_p1_m1", true, "lasgun_p1_m1"),
							create_checkbox("enable_lasgun_p1_m2", true, "lasgun_p1_m2"),
							create_checkbox("enable_lasgun_p1_m3", true, "lasgun_p1_m3"),
							create_checkbox("enable_lasgun_p3_m1", true, "lasgun_p3_m1"),
							create_checkbox("enable_lasgun_p3_m2", true, "lasgun_p3_m2"),
							create_checkbox("enable_lasgun_p3_m3", true, "lasgun_p3_m3"),
						},
					},
				},
			},
		}
	}
}
