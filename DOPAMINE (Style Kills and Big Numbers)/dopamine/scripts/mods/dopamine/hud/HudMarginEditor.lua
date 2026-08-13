

---@type mod
local mod = get_mod("dopamine")

local Layout = mod:core(mod.layout, "hud/layout")
local Definitions = mod:io_dofile("dopamine/scripts/mods/dopamine/hud/margin_editor/definitions")
local Constants = mod:core(mod.constants, "hud/constants")

local Hud = require("scripts/utilities/ui/hud")

local math_abs = math.abs

local DEBUG_HANDLES_ALWAYS_VISIBLE = false

local GRAB_PX = 40

local DIVIDER_ALPHA = 255
local HOVER_GLOW_ALPHA = 90
local DRAG_GLOW_ALPHA = 160

local PANEL_IDLE_SCALE = 0.45
local PANEL_ACTIVE_SCALE = 0.6

local VISIBLE = {
	margin_left = function()
		return true
	end,
	margin_right = function()
		return true
	end,
	offset_left = function()
		return Layout.column_bottom_y("left") ~= nil
	end,
	offset_right = function()
		return Layout.column_bottom_y("right") ~= nil
	end,
	offset_center = function()
		return Layout.fury_centered()
	end,
}

---@class HudMarginEditor
---@field _drag_key string | nil  -- key of the handle currently held
---@field _grab_offset number     -- screen-px delta from cursor to edge at grab
---@field _hover_key string | nil
---@field _cursor_pushed boolean | nil
local HudMarginEditor = class("HudMarginEditor", "HudElementBase")

HudMarginEditor.init = function(self, parent, draw_layer, start_scale)
	HudMarginEditor.super.init(self, parent, draw_layer + Constants.HUD_Z_BOOST, start_scale, {
		scenegraph_definition = Definitions.scenegraph_definition,
		widget_definitions = Definitions.widget_definitions,
	})

	self._drag_key = nil
	self._grab_offset = 0
	self._hover_key = nil
end

HudMarginEditor.destroy = function(self, ui_renderer)
	self:_pop_cursor()
	HudMarginEditor.super.destroy(self, ui_renderer)
end

---@return number
local function hud_scale()
	local scale = Hud.hud_scale()
	if not scale or scale == 0 then
		return 1
	end
	return scale
end

---@return number
local function screen_width()
	return (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
end

---@return number
local function full_design_height()
	local height = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080
	return height / hud_scale()
end

---@param handle table
---@return number
local function display_value(handle)
	return Layout.editable_value(handle.key) + (handle.display or 0)
end

---@param handle table
---@return number
local function edge_screen_pos(handle)
	local value = display_value(handle) * hud_scale()

	if handle.axis == "x" and handle.side == "right" then
		return screen_width() - value
	end
	return value
end

---@param handle table
---@param pos number
---@return number
local function value_from_screen_pos(handle, pos)
	local scale = hud_scale()
	local shift = handle.display or 0
	if handle.axis == "x" and handle.side == "right" then
		return (screen_width() - pos) / scale - shift
	end
	return pos / scale - shift
end

---@param handle table
---@return number left, number right
local function band_screen_span(handle)
	local scale = hud_scale()
	local length = Definitions.BAND_LENGTH * scale

	if handle.side == "left" then
		local start = Layout.margin_value("left") * scale
		return start, start + length
	elseif handle.side == "right" then
		local finish = screen_width() - Layout.margin_value("right") * scale
		return finish - length, finish
	end

	local center = screen_width() * 0.5
	return center - length * 0.5, center + length * 0.5
end

---@param handle table
---@return boolean
local function handle_visible(handle)
	local check = VISIBLE[handle.key]
	return not check or check()
end

---@return boolean
function HudMarginEditor.edit_mode()
	return mod.margin_editor_active == true
end

---@return boolean
HudMarginEditor.using_input = function(self)
	return self.edit_mode()
end

HudMarginEditor._push_cursor = function(self)
	if self._cursor_pushed then
		return
	end
	Managers.input:push_cursor(self.__class_name)
	self._cursor_pushed = true
end

HudMarginEditor._pop_cursor = function(self)
	if not self._cursor_pushed then
		return
	end
	Managers.input:pop_cursor(self.__class_name)
	self._cursor_pushed = nil
end

HudMarginEditor._end_drag = function(self)
	if not self._drag_key then
		return
	end
	Layout.commit_editable(self._drag_key)
	self._drag_key = nil
end

HudMarginEditor._update_drag = function(self, input_service)
	local cursor = input_service and input_service:get("cursor")
	if not cursor then
		self:_end_drag()
		self._hover_key = nil
		return
	end

	local cursor_x, cursor_y = cursor[1], cursor[2]
	local handles = Definitions.handles

	if self._drag_key then
		if input_service:get("left_hold") then
			local handle
			for i = 1, #handles do
				if handles[i].key == self._drag_key then
					handle = handles[i]
					break
				end
			end
			if handle then

				local along = handle.axis == "x" and cursor_x or cursor_y
				local target = along - self._grab_offset
				Layout.set_editable_override(handle.key, value_from_screen_pos(handle, target))
			end
		else
			self:_end_drag()
		end
		return
	end

	local hover_handle, hover_distance = nil, nil
	for i = 1, #handles do
		local handle = handles[i]
		if handle_visible(handle) then
			local horizontal = handle.axis == "x"
			local along = horizontal and cursor_x or cursor_y
			local distance = math_abs(along - edge_screen_pos(handle))

			local in_span = true
			if not horizontal then
				local span_start, span_end = band_screen_span(handle)
				in_span = cursor_x >= span_start and cursor_x <= span_end
			end

			if in_span and distance <= GRAB_PX and (not hover_distance or distance < hover_distance) then
				hover_handle, hover_distance = handle, distance
			end
		end
	end

	self._hover_key = hover_handle and hover_handle.key or nil

	if hover_handle and input_service:get("left_pressed") then
		self._drag_key = hover_handle.key
		local along = hover_handle.axis == "x" and cursor_x or cursor_y
		self._grab_offset = along - edge_screen_pos(hover_handle)

		Layout.set_editable_override(hover_handle.key, Layout.editable_value(hover_handle.key))
	end
end

HudMarginEditor._layout_handle = function(self, handle, widget)

	local value = display_value(handle)
	local bleed = Definitions.PANEL_BLEED
	local inset = Definitions.PANEL_MATERIAL_INSET
	local line = Definitions.LINE_WIDTH

	local panel_bg = widget.style.panel_bg
	local panel = widget.style.panel
	local line_style = widget.style.line

	if handle.axis == "x" then
		local height = full_design_height()
		local margin_x = Layout.margin_x(handle.side)

		self:_set_scenegraph_size("node_" .. handle.key, line, height)
		self:set_scenegraph_position("node_" .. handle.key, margin_x, 0, Definitions.Z, handle.side, "top")

		panel_bg.size[1] = value + line
		panel_bg.size[2] = height
		panel_bg.offset[1] = handle.side == "left" and -value or 0
		panel_bg.offset[2] = 0

		panel.size[1] = value + bleed + line + inset
		panel.size[2] = height + bleed * 2
		panel.offset[1] = handle.side == "left" and -(value + bleed) or -inset
		panel.offset[2] = -bleed

		line_style.size[1] = line
		line_style.size[2] = height
	else

		local length = Definitions.BAND_LENGTH
		local x = handle.side == "center" and 0 or Layout.margin_x(handle.side)

		self:_set_scenegraph_size("node_" .. handle.key, length, line)
		self:set_scenegraph_position("node_" .. handle.key, x, value, Definitions.Z, handle.side, "top")

		panel_bg.size[1] = length
		panel_bg.size[2] = value + line
		panel_bg.offset[1] = 0
		panel_bg.offset[2] = -value

		panel.size[1] = length + bleed * 2
		panel.size[2] = value + bleed + line + inset
		panel.offset[1] = -bleed
		panel.offset[2] = -(value + bleed)

		line_style.size[1] = length
		line_style.size[2] = line
	end
end

HudMarginEditor._update_handles = function(self)
	local handles = Definitions.handles

	for i = 1, #handles do
		local handle = handles[i]
		local widget = self._widgets_by_name["handle_" .. handle.key]
		if widget then

			local visible = handle_visible(handle)
			widget.content.visible = visible

			if visible then
				self:_layout_handle(handle, widget)

				local dragging = self._drag_key == handle.key
				local active = dragging or self._hover_key == handle.key

				local panel_scale = active and PANEL_ACTIVE_SCALE or PANEL_IDLE_SCALE
				widget.style.panel.color[1] = Definitions.PANEL_ALPHA * panel_scale
				widget.style.panel_bg.color[1] = Definitions.PANEL_BG_ALPHA * panel_scale

				local glow = 0
				if dragging then
					glow = DRAG_GLOW_ALPHA
				elseif active then
					glow = HOVER_GLOW_ALPHA
				end
				widget.style.divider.color[1] = DIVIDER_ALPHA
				widget.style.glow.color[1] = glow
			end
		end
	end
end

HudMarginEditor.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudMarginEditor.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	if not self.edit_mode() then

		self:_end_drag()
		self._hover_key = nil
		self:_pop_cursor()
		self:_update_handles()
		return
	end

	self:_push_cursor()

	local ignore_hud = true
	if Managers.ui:using_input(ignore_hud) then
		self:_end_drag()
		self._hover_key = nil
	else
		local view_input = Managers.ui:input_service()

		if view_input and view_input:get("back") then
			self:_end_drag()
			self._hover_key = nil
			mod.margin_editor_active = false
			self:_pop_cursor()
			self:_update_handles()
			return
		end

		self:_update_drag(view_input)
	end

	self:_update_handles()
end

HudMarginEditor._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	if not (DEBUG_HANDLES_ALWAYS_VISIBLE or self.edit_mode()) then
		return
	end

	HudMarginEditor.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudMarginEditor
