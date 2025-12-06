local loc = {
	mod_name = {
		en = "Broker Stim Timer",
	},
	mod_description = {
		en = "A detachable timer for the broker stim ability that can be positioned anywhere on screen.",
	},
	position_group = {
		en = "Position",
	},
	icon_x = {
		en = "Icon Position X",
	},
	icon_y = {
		en = "Icon Position Y",
	},
	text_x = {
		en = "Text Position X",
	},
	text_y = {
		en = "Text Position Y",
	},
	display_group = {
		en = "Display",
	},
	font_size = {
		en = "Font Size",
	},
	icon_size = {
		en = "Icon Size",
	},
	show_active = {
		en = "Show Active Timer",
	},
	show_cooldown = {
		en = "Show Cooldown Timer",
	},
	show_decimals = {
		en = "Show Decimals",
	},
	show_when_ready = {
		en = "Show when ready",
	},
	show_icon = {
		en = "Show Icon",
	},
	show_timer = {
		en = "Show Timer",
	},
	active = {
		en = "Active Color",
	},
	active_preset = {
		en = "Color Preset",
	},
	active_r = {
		en = "Red",
	},
	active_g = {
		en = "Green",
	},
	active_b = {
		en = "Blue",
	},
	cooldown = {
		en = "Cooldown Color",
	},
	cooldown_preset = {
		en = "Color Preset",
	},
	cooldown_r = {
		en = "Red",
	},
	cooldown_g = {
		en = "Green",
	},
	cooldown_b = {
		en = "Blue",
	},
	ready = {
		en = "Ready Color",
	},
	ready_preset = {
		en = "Color Preset",
	},
	ready_r = {
		en = "Red",
	},
	ready_g = {
		en = "Green",
	},
	ready_b = {
		en = "Blue",
	},
	default = {
		en = "Default",
	},
}

local default_stage_colors = {
	active = {r = 226, g = 199, b = 126},
	cooldown = {r = 246, g = 69, b = 69},
	ready = {r = 74, g = 177, b = 85},
}

for stage, c in pairs(default_stage_colors) do
	local text = string.format("{#color(%s,%s,%s)}Default{#reset()}", c.r, c.g, c.b)
	loc["default_" .. stage] = { en = text }
end

for _, color_name in ipairs(Color.list or {}) do
	local c = Color[color_name](255, true)
	local text = string.format("{#color(%s,%s,%s)}%s{#reset()}", c[2], c[3], c[4], string.gsub(color_name, "_", " "))
	loc[color_name] = { en = text }
end

return loc

