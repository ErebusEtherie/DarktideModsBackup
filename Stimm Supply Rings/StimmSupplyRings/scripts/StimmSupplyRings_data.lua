local mod = get_mod("StimmSupplyRings")

local default_colors = {
	["attack_speed"] = {0, 0, 255},
	["cooldown"] = {255, 255, 0},
	["strength"] = {255, 0, 0},
	["toughness"] = {200, 0, 255},
}

local _create_color_channel = function(channel_prefix, channel, default)
	return {
		setting_id = channel_prefix .. "_" .. channel,
		type = "numeric",
		title = channel,
		default_value = default,
		range = { 0, 255 },
	}
end

local _create_color_sub_widgets = function(ring)
	local channel_prefix = ring .. "_color"
	return {
		setting_id = channel_prefix,
		type = "group",
		sub_widgets = {
			_create_color_channel(channel_prefix, "red", default_colors[ring][1]),
			_create_color_channel(channel_prefix, "green", default_colors[ring][2]),
			_create_color_channel(channel_prefix, "blue", default_colors[ring][3]),
		}
	}	
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "show_attack_speed",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_cooldown",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_strength",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "show_toughness",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "min_investment",
				type = "numeric",
				range = {1, 5},
				default_value = 2,
				tooltip = "min_investment_tooltip",
			},
			{
				setting_id = "min_opacity",
				type = "numeric",
				range = {1, 100},
				default_value = 3,
			},
			{
				setting_id = "max_opacity",
				type = "numeric",
				range = {2, 100},
				default_value = 30,
			},
			{
				setting_id = "opacity_scaling_power",
				type = "numeric",
				range = {0, 3},
				default_value = 2,
				tooltip = "opacity_scaling_power_tooltip",
			},
			{
				setting_id = "enable_logging",
				type = "checkbox",
				default_value = false,
				tooltip = "enable_logging_tooltip",
			},
			{
				setting_id = "color_customization",
				type = "group",
				sub_widgets = {
					_create_color_sub_widgets("attack_speed"),
					_create_color_sub_widgets("cooldown"),
					_create_color_sub_widgets("strength"),
					_create_color_sub_widgets("toughness"),
				}
			}
		}
	}
}
