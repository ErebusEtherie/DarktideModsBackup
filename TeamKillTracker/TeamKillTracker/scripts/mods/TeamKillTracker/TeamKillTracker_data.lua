local mod = get_mod("TeamKillTracker")

return {
	name = mod:localize("mod_title"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "hud_counter_mode",
				type = "dropdown",
				default_value = 1,
				options = {
					{text = "hud_counter_mode_kills_damage", value = 1},
					{text = "hud_counter_mode_kills", value = 2},
					{text = "hud_counter_mode_damage", value = 3},
				},
			},
            {
                setting_id = "hide_team_kills",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "hide_user_kills",
                type = "checkbox",
                default_value = false,
            },
        },
	},
}