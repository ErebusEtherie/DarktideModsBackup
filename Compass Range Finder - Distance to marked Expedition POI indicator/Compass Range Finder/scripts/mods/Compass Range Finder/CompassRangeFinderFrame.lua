local mod = get_mod("Compass Range Finder")

local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIFonts = require("scripts/managers/ui/ui_fonts")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

local Vector3 = rawget(_G, "Vector3")
local math_ceil = math.ceil
local math_max = math.max

local text_options = {}
local text_color = {
	255,
	255,
	255,
	255,
}

local frame_background_color = {
	140,
	0,
	0,
	0,
}

local frame_border_color = {
	220,
	255,
	255,
	255,
}

local frame_border_outer_color = {
	120,
	0,
	0,
	0,
}

local frame_border_inner_color = {
	170,
	255,
	255,
	255,
}

local frame_corner_color = {
	255,
	255,
	255,
	255,
}

local font_style = UIFontSettings.hud_body
local font_type = font_style.font_type

UIFonts.get_font_options_by_style(font_style, text_options)
text_options.shadow = true

local frame_padding_x = 10
local frame_padding_top = 4
local frame_padding_bottom = 7
local text_width_buffer = 6
local border_thickness = 2
local outer_thickness = 1
local inner_inset = 2
local corner_size = 4

local text_position = { 0, 0, 0 }
local text_size = { 0, 0 }

local last_tint = {
	r = nil,
	g = nil,
	b = nil,
}

local FrameRenderer = {}

-- Helper: Update color channels for a color array
local function update_color_channels(array, color)
	array[2] = color[2]
	array[3] = color[3]
	array[4] = color[4]
end

local function apply_color_tint(color)
	if last_tint.r == color[2] and last_tint.g == color[3] and last_tint.b == color[4] then
		return
	end

	last_tint.r = color[2]
	last_tint.g = color[3]
	last_tint.b = color[4]

	text_color[1] = 255
	update_color_channels(text_color, color)
	update_color_channels(frame_border_color, color)
	update_color_channels(frame_border_inner_color, color)
	update_color_channels(frame_corner_color, color)
end

local function draw_box_border(ui_renderer, x, y, z, width, height, thickness, color)
	local top_left = Vector3(x, y, z)
	local top_size = Vector3(width, thickness, 1)
	local bottom_left = Vector3(x, y + height - thickness, z)
	local left_size = Vector3(thickness, height, 1)
	local right_top = Vector3(x + width - thickness, y, z)

	UIRenderer.draw_rect(ui_renderer, top_left, top_size, color)
	UIRenderer.draw_rect(ui_renderer, bottom_left, top_size, color)
	UIRenderer.draw_rect(ui_renderer, top_left, left_size, color)
	UIRenderer.draw_rect(ui_renderer, right_top, left_size, color)
end

FrameRenderer.draw = function(ui_renderer, distance, color, screen_position)
	local distance_text = tostring(distance) .. "m"

	local configured_font_size = mod:get("distance_font_size") or 22
	local resolution_lookup = rawget(_G, "RESOLUTION_LOOKUP")
	local renderer_scale = ui_renderer.scale or (resolution_lookup and resolution_lookup.scale) or 1
	local font_size = math_ceil(configured_font_size * renderer_scale)

	apply_color_tint(color)

	local measured_text_width, measured_text_height = UIRenderer.text_size(ui_renderer, distance_text, font_type, font_size)
	local text_width = math_ceil(measured_text_width) + text_width_buffer
	local text_height = math_ceil(measured_text_height)
	local frame_width = math_max(text_width + frame_padding_x * 2, text_height + frame_padding_top + frame_padding_bottom)
	local frame_height = text_height + frame_padding_top + frame_padding_bottom
	local frame_x = screen_position[1] - frame_width * 0.5
	local frame_y = screen_position[2]
	local frame_z = screen_position[3]

	text_position[1] = frame_x + (frame_width - text_width) * 0.5
	text_position[2] = frame_y + frame_padding_top
	text_position[3] = screen_position[3] + 1
	text_size[1] = math_max(frame_width - frame_padding_x * 2, 1)
	text_size[2] = math_max(frame_height - frame_padding_top - frame_padding_bottom, 1)

	local outer_x = frame_x - outer_thickness
	local outer_y = frame_y - outer_thickness
	local outer_z = frame_z
	local outer_w = frame_width + outer_thickness * 2
	local outer_h = frame_height + outer_thickness * 2

	UIRenderer.draw_rect(ui_renderer, Vector3(frame_x, frame_y, frame_z), Vector3(frame_width, frame_height, 1), frame_background_color)
	draw_box_border(ui_renderer, outer_x, outer_y, outer_z, outer_w, outer_h, outer_thickness, frame_border_outer_color)
	draw_box_border(ui_renderer, frame_x, frame_y, frame_z, frame_width, frame_height, border_thickness, frame_border_color)

	if frame_width > inner_inset * 2 and frame_height > inner_inset * 2 then
		local inner_x = frame_x + inner_inset
		local inner_y = frame_y + inner_inset
		local inner_z = frame_z
		local inner_w = frame_width - inner_inset * 2
		local inner_h = frame_height - inner_inset * 2

		draw_box_border(ui_renderer, inner_x, inner_y, inner_z, inner_w, inner_h, 1, frame_border_inner_color)
	end

	local corner_size_vector = Vector3(corner_size, corner_size, 1)
	local corner_positions = {
		Vector3(frame_x, frame_y, frame_z),
		Vector3(frame_x + frame_width - corner_size, frame_y, frame_z),
		Vector3(frame_x, frame_y + frame_height - corner_size, frame_z),
		Vector3(frame_x + frame_width - corner_size, frame_y + frame_height - corner_size, frame_z),
	}

	for _, corner_pos in ipairs(corner_positions) do
		UIRenderer.draw_rect(ui_renderer, corner_pos, corner_size_vector, frame_corner_color)
	end

	UIRenderer.draw_text(ui_renderer, distance_text, font_size, font_type, text_position, text_size, text_color, text_options)
end

return FrameRenderer
