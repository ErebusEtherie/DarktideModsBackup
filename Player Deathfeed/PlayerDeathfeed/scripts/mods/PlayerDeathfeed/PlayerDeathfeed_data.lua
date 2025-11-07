local mod = get_mod("PlayerDeathfeed")

local color_options = {}

for i, color_name in ipairs(Color.list) do
	table.insert(
		color_options,
		{
			text = color_name,
			value = color_name
		}
	)
end

table.sort(color_options, function(a, b) return a.text < b.text end)

local function get_color_options()
	return table.clone(color_options)
end

return {
	name = "PlayerDeathfeed",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "killfeed",
				type = "group",
				sub_widgets = {
					{
						setting_id = "show_killfeed",
						type = "checkbox",
						default_value = true,
					},
					--{
					--	setting_id = "report_down_feed",
					--	type = "checkbox",
					--	default_value = true,
					--},
					--{
					--	setting_id = "report_death_feed",
					--	type = "checkbox",
					--	default_value = true,
					--},
					{
						setting_id = "show_type_feed",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "show_damage_feed",
						type = "checkbox",
						default_value = false,
					},
				},
			},		
			{
				setting_id = "notification",
				type = "group",
				sub_widgets = {
					{
						setting_id = "show_notification",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "detailed_notification",
						tooltip = "detailed_description",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "damage_window",
						type = "numeric",
						default_value  = 4,
						range = {1, 10},
					},
					{
						setting_id = "note_time",
						type = "numeric",
						default_value  = 8,
						range = {1, 20},
					},
					{
						setting_id = "show_type_note",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_damage_note",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "show_disabled_note",
						type = "checkbox",
						default_value = true,
					},
					--{
					--	setting_id = "report_down_notification",
					--	type = "checkbox",
					--	default_value = true,
					--},
					{
						setting_id = "knock_color",
						type = "dropdown",
						default_value = "item_rarity_dark_5",
						options = get_color_options()
					},
					--{
					--	setting_id = "report_death_notification",
					--	type = "checkbox",
					--	default_value = true,
					--},
					{
						setting_id = "dead_color",
						type = "dropdown",
						default_value = "item_rarity_dark_6",
						options = get_color_options()
					},
				},
			},
			{
				setting_id = "echo",
				type = "group",
				sub_widgets = {
					{
						setting_id = "echo_feed",
						type = "checkbox",
						default_value = false,
					},
					--{
					--	setting_id = "echo_note",
					--	type = "checkbox",
					--	default_value = false,
					--},
				},
			},
			{
				setting_id = "Debug",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}