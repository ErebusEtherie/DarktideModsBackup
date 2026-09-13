local mod = get_mod("RespawnRewind")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{ setting_id = "enabled",       type = "checkbox", default_value = true },
			{ setting_id = "show_runback",  type = "checkbox", default_value = true },
			{ setting_id = "runback_margin", type = "numeric", default_value = 0, range = { 0, 30 } },
			{
				-- Map practice. The master toggle gates the whole set, the two under it choose which half
				-- you get. All off by default: this is a study aid, not something to have on in a run.
				setting_id = "practice_group", type = "group",
				sub_widgets = {
					{ setting_id = "practice_enabled",  type = "checkbox", default_value = false },
					{ setting_id = "practice_beacons",  type = "checkbox", default_value = true },
					{ setting_id = "practice_lines",    type = "checkbox", default_value = true },
					{ setting_id = "practice_numbers",  type = "checkbox", default_value = true },
				},
			},
			{ setting_id = "marker_size",   type = "numeric",  default_value = 64, range = { 8, 124 } },
			{ setting_id = "through_walls", type = "checkbox", default_value = true },
			{ setting_id = "show_distance", type = "checkbox", default_value = true },
			{
				setting_id = "marker_icon", type = "dropdown", default_value = "skull",
				options = {
					{ text = "icon_skull",      value = "skull" },
					{ text = "icon_assistance", value = "assistance" },
					{ text = "icon_location",   value = "location" },
					{ text = "icon_attention",  value = "attention" },
					{ text = "icon_objective",  value = "objective" },
					{ text = "icon_resupply",   value = "resupply" },
					{ text = "icon_default",    value = "default" },
				},
			},
		},
	},
}
