local mod = get_mod("BrokerStimTimer")

local color_options = {}
local seen_colors = {}

local function is_duplicated(color_array)
	local join = function(t)
		return string.format("%s,%s,%s", t[2], t[3], t[4])
	end
	
	local color_key = join(color_array)
	if seen_colors[color_key] then
		return true
	end
	seen_colors[color_key] = true
	return false
end

for _, name in ipairs(Color.list or {}) do
	local color_array = Color[name](255, true)
	if not is_duplicated(color_array) then
		color_options[#color_options+1] = { text = name, value = name }
	end
end
table.sort(color_options, function(a,b) return a.text < b.text end)
table.insert(color_options, 1, { text = "default", value = "default" })

local function stage_color_widgets(stage, default_r, default_g, default_b)
	local stage_color_options = table.clone(color_options)
	stage_color_options[1] = { text = "default_" .. stage, value = "default" }
	
	return {
		setting_id = stage,
		type = "group",
		sub_widgets = {
			{
				setting_id = stage .. "_preset",
				type = "dropdown",
				default_value = "default",
				options = stage_color_options,
			},
			{
				setting_id = stage .. "_r",
				type = "numeric",
				default_value = default_r,
				range = { 0, 255 },
			},
			{
				setting_id = stage .. "_g",
				type = "numeric",
				default_value = default_g,
				range = { 0, 255 },
			},
			{
				setting_id = stage .. "_b",
				type = "numeric",
				default_value = default_b,
				range = { 0, 255 },
			},
		}
	}
end

local widgets = {
	{
		setting_id = "display_group",
		type = "group",
		sub_widgets = {
			{
				setting_id = "font_size",
				type = "numeric",
				default_value = 25,
				range = { 10, 100 },
			},
			{
				setting_id = "icon_size",
				type = "numeric",
				default_value = 55,
				range = { 16, 128 },
			},
			{
				setting_id = "show_decimals",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "link_all_positions",
				type = "checkbox",
				default_value = true,
			},
		}
	},
	{
		setting_id = "shared_position_group",
		type = "group",
		sub_widgets = {
			{
				setting_id = "shared_icon_x",
				type = "numeric",
				default_value = 765,
				range = { 0, 3840 },
			},
			{
				setting_id = "shared_icon_y",
				type = "numeric",
				default_value = 620,
				range = { 0, 1080 },
			},
			{
				setting_id = "shared_text_x",
				type = "numeric",
				default_value = 761,
				range = { 0, 3840 },
			},
			{
				setting_id = "shared_text_y",
				type = "numeric",
				default_value = 670,
				range = { 0, 1080 },
			},
		}
	},
		{
			setting_id = "ready_group",
			type = "group",
			sub_widgets = {
				{
					setting_id = "ready_icon_x",
					type = "numeric",
					default_value = 565,
					range = { 0, 3840 },
				},
			{
				setting_id = "ready_icon_y",
				type = "numeric",
				default_value = 620,
				range = { 0, 1080 },
			},
			{
				setting_id = "ready_show_icon",
				type = "checkbox",
				default_value = true,
			},
		}
	},
		{
			setting_id = "active_group",
			type = "group",
			sub_widgets = {
				{
					setting_id = "active_icon_x",
					type = "numeric",
					default_value = 565,
					range = { 0, 3840 },
				},
				{
					setting_id = "active_icon_y",
					type = "numeric",
					default_value = 620,
					range = { 0, 1080 },
				},
				{
					setting_id = "active_text_x",
					type = "numeric",
					default_value = 561,
					range = { 0, 3840 },
				},
			{
				setting_id = "active_text_y",
				type = "numeric",
				default_value = 670,
				range = { 0, 1080 },
			},
			{
				setting_id = "active_show_icon",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "active_show_timer",
				type = "checkbox",
				default_value = true,
			},
		}
	},
		{
			setting_id = "cooldown_group",
			type = "group",
			sub_widgets = {
				{
					setting_id = "cooldown_icon_x",
					type = "numeric",
					default_value = 565,
					range = { 0, 3840 },
				},
				{
					setting_id = "cooldown_icon_y",
					type = "numeric",
					default_value = 620,
					range = { 0, 1080 },
				},
				{
					setting_id = "cooldown_text_x",
					type = "numeric",
					default_value = 561,
					range = { 0, 3840 },
				},
			{
				setting_id = "cooldown_text_y",
				type = "numeric",
				default_value = 670,
				range = { 0, 1080 },
			},
			{
				setting_id = "cooldown_show_icon",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "cooldown_show_timer",
				type = "checkbox",
				default_value = true,
			},
		}
	},
}

widgets[#widgets+1] = stage_color_widgets("active", 226, 199, 126)
widgets[#widgets+1] = stage_color_widgets("cooldown", 246, 69, 69)
widgets[#widgets+1] = stage_color_widgets("ready", 74, 177, 85)

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}


