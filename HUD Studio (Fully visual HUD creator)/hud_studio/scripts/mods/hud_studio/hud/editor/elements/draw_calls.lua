
local mod = get_mod("hud_studio")

if mod.draw_calls then
	return mod.draw_calls
end

local UIRenderer = require("scripts/managers/ui/ui_renderer")
local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Pixel = mod:core(mod.hud_studio_pixel, "blocks/pixel")
local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

local FONT = mod.dl.fonts.validated("arial")
local Gui = rawget(_G, "Gui")

local _v_align = {
	["top"] = Gui and Gui.VerticalAlignTop,
	["center"] = Gui and Gui.VerticalAlignCenter,
	["bottom"] = Gui and Gui.VerticalAlignBottom,
}

local _h_align = {
	["left"] = Gui and Gui.VerticalAlignLeft,
	["center"] = Gui and Gui.HorizontalAlignCenter,
	["right"] = Gui and Gui.HorizontalAlignRight,
}

local _text_align = {
	["left"] = {
		horizontal_alignment = Gui and Gui.VerticalAlignLeft,
		vertical_alignment = Gui and Gui.VerticalAlignCenter,
	},
	["center"] = {
		horizontal_alignment = Gui and Gui.HorizontalAlignCenter,
		vertical_alignment = Gui and Gui.VerticalAlignCenter,
	},
	["right"] = {
		horizontal_alignment = Gui and Gui.HorizontalAlignRight,
		vertical_alignment = Gui and Gui.VerticalAlignCenter,
	},
}

local CARET_TO_LEFT = "content/ui/materials/hud/backgrounds/weapon_frame_arrow"

local Draw = {
	ui_renderer = UIRenderer,
	cx = 0,
	cy = 0,
	pressed = false,
	hold = false,
	active_id = nil,
	hot_id = nil,
	hot_id_prev = nil,
}

function Draw:set_pointer(input_service)
	local cursor = input_service and input_service:get("cursor")
	local inv = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale) or 1
	if cursor then
		self.cx = cursor[1] * inv
		self.cy = cursor[2] * inv
	end
	self.pressed = (input_service and input_service:get("left_pressed")) or false
	self.hold = (input_service and input_service:get("left_hold")) or false

	self.hot_id_prev = self.hot_id
	self.hot_id = nil
end

function Draw:in_rect(x, y, w, h)
	return self.cx >= x and self.cx <= x + w and self.cy >= y and self.cy <= y + h
end

local _ui_scale = 1
local _hud_scale = 1

function Draw:ui_scale()
	_ui_scale = (self.ui_renderer and self.ui_renderer.scale) or (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale) or 1
	return _ui_scale
end

function Draw:hud_scale()
	local save_data = Managers.save:account_data()
	local interface_settings = save_data.interface_settings
	local hud_scale = interface_settings.hud_scale or 100

	_hud_scale = _ui_scale * (hud_scale / 100)

	return _hud_scale
end

function Draw:rect(x, y, z, w, h, color, rotation)
	x, y, w, h = Pixel.rect(x, y, w, h)
	if not rotation then
		UIRenderer.draw_rect(self.ui_renderer, Vector3(x, y, z), Vector2(w, h), color)
	else
		UIRenderer.draw_rect_rotated(
			self.ui_renderer,
			Vector2(w, h),
			Vector3(x, y, z),
			rotation,
			{ w / 2, h / 2 },
			color
		)
	end
end

function Draw:texture(material, x, y, z, w, h, color, uv, rotation)
	x, y, w, h = Pixel.rect(x, y, w, h)
	color = color or { 255, 255, 255, 255 }
	rotation = tonumber(rotation) or 0

	if rotation ~= 0 then

		UIRenderer.draw_texture_rotated(
			self.ui_renderer,
			material,
			{ w, h },
			Vector3(x, y, z),
			math.rad(rotation),
			{ w * 0.5, h * 0.5 },
			color,
			uv
		)
	elseif uv then
		UIRenderer.draw_texture_uv(self.ui_renderer, material, Vector3(x, y, z), Vector2(w, h), uv, color)
	else
		UIRenderer.draw_texture(self.ui_renderer, material, Vector3(x, y, z), Vector2(w, h), color)
	end
end

function Draw:caret(x, y, z, is_open, color)

	if not MaterialDeps.ready_to_draw(CARET_TO_LEFT) then
		return
	end
	self:texture(
		CARET_TO_LEFT,
		(x or 0) + 9,
		(y or 0) + 9 + (is_open and 0 or -1),
		z or 1,
		7,
		7,
		color or { 255, 255, 255, 255 },
		mod.dl.uv.flip_x(),
		is_open and -90 or 0
	)
end

local function draw_text(ui_renderer, text, size, x, y, z, w, h, color, font_type, align, shadow, custom_align)

	local opts
	if not custom_align then
		opts = _text_align[align or "left"] or _text_align["left"]
	else
		opts = {
			vertical_alignment = _v_align[custom_align[1] or "center"] or _v_align["center"],
			horizontal_alignment = _h_align[custom_align[2] or "left"] or _h_align["left"],
		}
	end
	opts.shadow = shadow and true or nil

	UIRenderer.draw_text(
		ui_renderer,
		tostring(text),
		size * _ui_scale,
		font_type or FONT,
		Vector3(Pixel.snap(x), Pixel.snap(y), z),
		Vector2(w, h),
		color,
		opts
	)
end

local _fit_cache = {}
local _fit_cache_count = 0
local _fit_cache_scale = nil
local FIT_CACHE_MAX = 2048

function Draw:fit_text_size(text, size, font_type, max_w)
	text = tostring(text or "")
	if text == "" or not max_w or max_w <= 0 then
		return size
	end
	local scale = self:ui_scale()
	if scale ~= _fit_cache_scale then
		_fit_cache, _fit_cache_count, _fit_cache_scale = {}, 0, scale
	end
	local font = font_type or FONT
	local key = text .. "|" .. tostring(size) .. "|" .. tostring(font) .. "|" .. tostring(max_w)
	local cached = _fit_cache[key]
	if cached then
		return cached
	end
	local ok, fitted = pcall(UIRenderer.scaled_font_size_by_width, self.ui_renderer, text, font, size, max_w)
	if not ok or type(fitted) ~= "number" then
		return size
	end
	if _fit_cache_count >= FIT_CACHE_MAX then
		_fit_cache, _fit_cache_count = {}, 0
	end
	_fit_cache[key] = fitted
	_fit_cache_count = _fit_cache_count + 1
	return fitted
end

function Draw:text(text, size, x, y, z, w, h, color, font_type, shadow, align)
	draw_text(self.ui_renderer, text, size, x, y, z, w, h, color, font_type, "left", shadow, align)
end

function Draw:text_left(text, size, x, y, z, w, h, color, font_type, shadow)
	draw_text(self.ui_renderer, text, size, x, y, z, w, h, color, font_type, "left", shadow)
end

function Draw:text_center(text, size, x, y, z, w, h, color, font_type, shadow)
	draw_text(self.ui_renderer, text, size, x, y, z, w, h, color, font_type, "center", shadow)
end

function Draw:text_right(text, size, x, y, z, w, h, color, font_type, shadow)
	draw_text(self.ui_renderer, text, size, x, y, z, w, h, color, font_type, "right", shadow)
end

function Draw:text_left_fit(text, size, x, y, z, w, h, color, font_type, shadow, pad)
	local fit = self:fit_text_size(text, size, font_type, w - (pad or 0))
	draw_text(self.ui_renderer, text, fit, x, y, z, w, h, color, font_type, "left", shadow)
end

function Draw:text_center_fit(text, size, x, y, z, w, h, color, font_type, shadow, pad)
	local fit = self:fit_text_size(text, size, font_type, w - (pad or 0))
	draw_text(self.ui_renderer, text, fit, x, y, z, w, h, color, font_type, "center", shadow)
end

function Draw:control_outline(x, y, w, h, z, color)
	local width = 1
	self:rect(x - width, y - width, z, w + width, h + width, color)
end

function Draw:canvas_outline(x0, y0, x1, y1, z, color)
	local width = 1
	local w, h = x1 - x0, y1 - y0
	self:rect(x0, y0, z, w, width, color) 
	self:rect(x0, y1 - width, z, w, width, color) 
	self:rect(x0, y0, z, width, h, color) 
	self:rect(x1 - width, y0, z, width, h, color) 
end

local _outline_map = {
	thin = "content/ui/materials/frames/frame_tile_1px",
	dashed = "content/ui/materials/frames/line_thin_dashed_animated",
}

local COLOR = {
	OUTLINE = { 255, 73, 73, 73 },
}

function Draw:outline(x0, y0, x1, y1, z, color, style)
	local material = _outline_map[style or "thin"]

	if not MaterialDeps.ready_to_draw(material) then
		return
	end
	local w, h = x1 - x0, y1 - y0
	self:texture(material, x0, y0, z, w, h, color or COLOR.OUTLINE)
end

function Draw:hr(x, y, w, z, color)
	local material = "content/ui/materials/frames/frame_tile_1px"
	if not MaterialDeps.ready_to_draw(material) then
		return
	end
	self:texture(material, x, y - 1, z, w, 1, color or COLOR.OUTLINE)
end

function Draw:outline_dashed(x0, y0, x1, y1, z, color)
	self:outline(x0, y0, x1, y1, z, color, "dashed")
end

function Draw:field_outline(x0, y0, x1, y1, z)
	self:outline(x0, y0, x1, y1, z + 5, { 255, 100, 100, 100 })
end

local DrawCalls = {}

local _bound = setmetatable({}, { __mode = "k" })

function DrawCalls.bind(ui_renderer)
	local d = _bound[ui_renderer]
	if not d then
		d = setmetatable({ ui_renderer = ui_renderer }, { __index = Draw })
		_bound[ui_renderer] = d
	end
	return d
end

function DrawCalls.setup(ui_renderer)
	local d = DrawCalls.bind(ui_renderer)
	d:ui_scale()
	d:hud_scale()
	return d
end

mod.draw_calls = DrawCalls

return DrawCalls
