local mod = get_mod("StimmSupplyRings")

local default_colors = {
	["attack_speed"] = {255, 0, 0, 255},
	["cooldown"] = {255, 255, 255, 0},
	["strength"] = {255, 255, 0, 0},
	["toughness"] = {255, 200, 0, 255},
}

local function create_ring_widget(ring)
	return {
		setting_id = ring .. "_settings",
		type = "group",
		sub_widgets = {
			{
				setting_id = "show_" .. ring,
				type = "checkbox",
				title = "enabled",
				default_value = true,
			},
			{
				setting_id = ring .. "_color",
				type = "color",
				title = "color",
				default_value = default_colors[ring],
				has_alpha = false,
			},
		},
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "general_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "min_investment",
						type = "numeric",
						range = { 1, 5 },
						default_value = 2,
						step_size_value = 1,
						tooltip = "min_investment_tooltip",
					},
					{
						setting_id = "min_opacity",
						type = "numeric",
						range = { 1, 100 },
						default_value = 3,
						step_size_value = 1,
						unit_text = "unit_percent",
					},
					{
						setting_id = "max_opacity",
						type = "numeric",
						range = { 2, 100 },
						default_value = 30,
						step_size_value = 1,
						unit_text = "unit_percent",
					},
					{
						setting_id = "opacity_scaling_power",
						type = "numeric",
						range = { 0, 3 },
						default_value = 2,
						step_size_value = 1,
						tooltip = "opacity_scaling_power_tooltip",
					},
					{
						setting_id = "enable_logging",
						type = "checkbox",
						default_value = false,
						tooltip = "enable_logging_tooltip",
					},
				},
			},
			create_ring_widget("attack_speed"),
			create_ring_widget("cooldown"),
			create_ring_widget("strength"),
			create_ring_widget("toughness"),
		},
	},
}
