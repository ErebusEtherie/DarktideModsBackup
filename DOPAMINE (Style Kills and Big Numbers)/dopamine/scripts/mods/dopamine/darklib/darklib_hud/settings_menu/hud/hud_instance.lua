

local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local ViewElementBase = require("scripts/ui/view_elements/view_element_base")

local Text = require("scripts/utilities/ui/text")

local Keyboard = rawget(_G, "Keyboard")
local Mouse = rawget(_G, "Mouse")

local function clamp(value, lo, hi)
	if value < lo then
		return lo
	elseif value > hi then
		return hi
	end
	return value
end

local function round_to(value, decimals)
	return tonumber(string.format("%." .. decimals .. "f", value)) or value
end

local function values_equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) == "table" then
		for k, v in pairs(a) do
			if b[k] ~= v then
				return false
			end
		end
		for k, v in pairs(b) do
			if a[k] ~= v then
				return false
			end
		end
		return true
	end
	return a == b
end

local function fraction_of(def, value)
	local span = def.max - def.min
	if span <= 0 then
		return 0
	end
	return clamp((value - def.min) / span, 0, 1)
end

local function tint(widget, style_id, color)
	local style = widget.style[style_id]
	if not style or not style.color then
		return
	end
	local c = style.color
	c[1], c[2], c[3], c[4] = color[1], color[2], color[3], color[4]
end

local function tint_text(widget, style_id, color)
	local style = widget.style[style_id]
	if not style or not style.text_color then
		return
	end
	local c = style.text_color
	c[1], c[2], c[3], c[4] = color[1], color[2], color[3], color[4]
end

local function bind_display(bind)
	if bind.device == "mouse" then
		return "Mouse: " .. bind.name
	end
	return string.upper(bind.name)
end

---@param bind table
---@return boolean
local function bind_pressed(bind)
	if bind.device == "mouse" then
		if Mouse and Mouse.button_index and Mouse.pressed then
			local index = Mouse.button_index(bind.name)
			return index ~= nil and Mouse.pressed(index) or false
		end
		return false
	end
	if Keyboard and Keyboard.button_index and Keyboard.pressed then
		local index = Keyboard.button_index(bind.name)
		return index ~= nil and Keyboard.pressed(index) or false
	end
	return false
end

---@return boolean
local function device_button_held(device, name)
	if not device or not device.button_index or not device.button then
		return false
	end
	local ok, index = pcall(device.button_index, name)
	if not ok or not index then
		return false
	end
	local held, value = pcall(device.button, index)
	return held and type(value) == "number" and value > 0
end

---@return boolean
local function left_mouse_held()
	return device_button_held(Mouse, "left") or device_button_held(Mouse, "mouse_left")
end

---@param key string | nil
---@return string | nil
local function localized_or_nil(mod, key)
	if not key then
		return nil
	end
	local text = mod:localize(key)
	if not text or text == "<" .. key .. ">" then
		return nil
	end
	return text
end

local function part_screen_rect(cell, part, left, top, scale)
	return {
		x = left + (cell.x + part.x) * scale,
		y = top + (cell.y + part.y) * scale,
		w = part.w * scale,
		h = part.h * scale,
	}
end

local function panel_rect_screen(rect, left, top, scale)
	return {
		x = left + rect.x * scale,
		y = top + rect.y * scale,
		w = rect.w * scale,
		h = rect.h * scale,
	}
end

---@class DLH_SettingsMenuHudInstance
---@field _mod DL_Mod
---@field _module DLH_SettingsMenu
---@field _definitions DLH_SettingsMenuHudDefinitions
---@field _layout DLH_SettingsMenuLayoutManager
---@field _constants DLH_SettingsMenuConstants
---@field _manager DLH_SettingsMenuManager
---@field _cursor_pushed boolean | nil
---@field _controls table[]  -- each carries .hidden / .disabled, refreshed per frame by _update_states
---@field _by_key table<string, table>
---@field _tabs DLH_SettingsMenuTab[]
---@field _has_tabs boolean          -- whether the left tab column is shown
---@field _tab_hits DLH_SettingsMenuRect[]  -- panel-local rects for tab buttons, by index
---@field _active_tab number         -- index into _tabs of the shown tab
---@field _hover_key string | nil
---@field _hover_tab number | nil    -- index of the tab button under the cursor
---@field _capturing string | nil   -- schema key of the keybind box in capture mode
---@field _capture_armed boolean    -- skips the click frame that opened capture
---@field _drag_key string | nil    -- schema key of the numeric slider being dragged
---@field _drag_value number        -- pending value while dragging; committed on release
---@field _tab_units table<number, number>  -- grid units of content per tab index (for scroll clamp)
---@field _tab_row_starts table<number, number[]>  -- first unit of each row, per tab index
---@field _scroll_by_tab table<number, number>  -- scroll offset as a row index into _tab_row_starts, per tab index
---@field _scroll_accum number       -- banked mouse-wheel delta, spent one row at a time
---@field _open_dropdown string | nil  -- schema key of the dropdown whose list is showing
---@field _dropdown_scroll number     -- that list's scroll offset, in whole option rows
---@field _dropdown_accum number      -- banked wheel delta for the open list
---@field _hover_option number | nil  -- index into the open list of the option under the cursor
---@field _input_guard number | nil   -- frames of input claim still owed after a close

local HudSettingsMenu = class("DarkLibHudSettingsMenu@" .. tostring({}), "ViewElementBase")

HudSettingsMenu.init = function(self, parent, draw_layer, start_scale, context)

	local mod = get_mod(context.mod_name)
	self._mod = mod

	local _module = mod.dl_hud.__hud_modules["settings_menu"]
	self._module = _module
	self._definitions = _module.hud_definitions
	self._layout = _module.layout_manager
	self._constants = _module.constants
	self._manager = _module.manager

	HudSettingsMenu.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = self._definitions.scenegraph_definition,
		widget_definitions = self._definitions.widget_definitions,
	})

	self._tabs = _module.tabs
	self._has_tabs = _module.has_tabs

	local Layout = self._layout
	local C = self._constants
	self._controls = {}
	self._by_key = {}
	for tab_index = 1, #self._tabs do
		local tab = self._tabs[tab_index]

		local header_h = Layout.tab_header_height(tab)
		for j = 1, #tab.controls do
			local def = tab.controls[j]
			local cell = Layout.cell_rect(def.col, def.row, def.col_span, def.row_span, header_h)

			local parts
			if def.type == "numeric" then
				parts = Layout.numeric_parts(cell.w)
			elseif def.type == "checkbox" then
				parts = Layout.checkbox_parts(cell.w)
			elseif def.type == "keybind" then
				parts = Layout.keybind_parts(cell.w)
			elseif def.type == "dropdown" then
				parts = Layout.dropdown_parts(cell.w)
			elseif def.type == "button" then
				parts = Layout.button_parts(cell.w, def.label_key ~= nil)
			end

			local has_reset = def.type == "numeric"
				or def.type == "checkbox"
				or def.type == "keybind"
				or def.type == "dropdown"
			local control = {
				def = def,
				cell = cell,
				parts = parts,
				has_reset = has_reset,
				widget_name = "widget_" .. def.key,
				tab_index = tab_index,

				cell_base_y = cell.y,

				display_row = def.row,
				display_bottom = def.row + (def.row_span or C.ROW_UNITS) - 1,
			}
			self._controls[#self._controls + 1] = control
			self._by_key[def.key] = control
		end
	end

	self._tab_rows = {}
	for i = 1, #self._tabs do
		self._tab_rows[i] = {}
	end
	local seen_row = {}
	for i = 1, #self._controls do
		local control = self._controls[i]
		local def = control.def
		local ti = control.tab_index
		local key = ti .. ":" .. def.row
		local row = seen_row[key]
		if not row then
			row = {
				controls = {},

				span = def.row_span or C.ROW_UNITS,

				heading = false,
			}
			seen_row[key] = row
			local rows = self._tab_rows[ti]
			rows[#rows + 1] = row
		end
		row.controls[#row.controls + 1] = control
		if def.type == "heading" then
			row.heading = true
		end
	end

	self._tab_row_starts = {}
	self:_update_states()

	self._scroll_by_tab = {}
	self._scroll_accum = 0

	self._tab_hits = {}
	if self._has_tabs then
		for i = 1, #self._tabs do
			self._tab_hits[i] = Layout.tab_rect(i)
		end
	end

	self._reset_all_hit = self._has_tabs and Layout.reset_all_rect() or nil
	self._tab_reset_hit = self._has_tabs and Layout.tab_reset_rect(self._tabs[1]) or nil
	self._fancy_hit = self._has_tabs and Layout.fancy_transitions_rect() or nil
	self._hover_reset_all = false
	self._hover_reset_tab = false
	self._hover_fancy = false

	self._active_tab = 1
	local saved_id = self._manager.active_tab_id()
	if saved_id then
		for i = 1, #self._tabs do
			if self._tabs[i].id == saved_id then
				self._active_tab = i
				break
			end
		end
	end

	local saved_scroll = self._manager.scroll_offset()
	if saved_scroll then
		self._scroll_by_tab[self._active_tab] = saved_scroll
	end

	self._input_guard = nil

	self._hover_key = nil
	self._hover_tab = nil
	self._capturing = nil
	self._capture_armed = false
	self._drag_key = nil
	self._drag_value = 0

	self._open_dropdown = nil
	self._dropdown_scroll = 0
	self._dropdown_accum = 0
	self._hover_option = nil
end

---@return boolean
HudSettingsMenu.is_open = function(self)
	return self:visible()
end

HudSettingsMenu._text_size = function(self, ui_renderer, text, style, optional_size, use_max_extents)
	return Text.text_size(ui_renderer, text, style, optional_size, use_max_extents)
end

HudSettingsMenu._reflow_tabs = function(self)
	local C = self._constants
	local unit_step = self._layout.unit_step()
	local tail = C.SCROLL_TAIL_ROWS * C.ROW_UNITS
	local units = {}

	for ti = 1, #self._tabs do
		local rows = self._tab_rows[ti]
		local starts = {}

		local cursor = 1
		for r = 1, #rows do
			local row = rows[r]
			local visible = false
			for k = 1, #row.controls do
				if not row.controls[k].hidden then
					visible = true
					break
				end
			end

			if visible then
				if row.heading then
					cursor = cursor + C.HEADING_SPACER_UNITS
				end

				starts[#starts + 1] = (#starts == 0) and 1 or cursor
				for k = 1, #row.controls do
					local control = row.controls[k]
					control.display_row = cursor
					control.display_bottom = cursor + row.span - 1
					control.cell.y = control.cell_base_y + (cursor - control.def.row) * unit_step
				end
				cursor = cursor + row.span
			else

				for k = 1, #row.controls do
					local control = row.controls[k]
					control.display_row = cursor
					control.display_bottom = cursor
				end
			end
		end

		self._tab_row_starts[ti] = starts

		local content = cursor - 1
		if tail > 0 then

			local window = self._layout.visible_units(self._layout.tab_header_height(self._tabs[ti]))
			if content > window then
				content = content + tail
			end
		end
		units[ti] = content
	end

	self._tab_units = units
end

HudSettingsMenu._update_states = function(self)
	local manager = self._manager
	local hidden_changed = false

	for i = 1, #self._controls do
		local control = self._controls[i]
		local hidden = manager.is_hidden(control.def)
		if hidden ~= control.hidden then
			hidden_changed = true
		end
		control.hidden = hidden
		control.disabled = not hidden and manager.is_disabled(control.def)
	end

	if hidden_changed then
		self:_reflow_tabs()
	end

	local capturing = self._capturing and self._by_key[self._capturing]
	if capturing and (capturing.hidden or capturing.disabled) then
		self:_cancel_capture()
	end

	local dragging = self._drag_key and self._by_key[self._drag_key]
	if dragging and (dragging.hidden or dragging.disabled) then
		self:_cancel_drag()
	end

	local open = self._open_dropdown and self._by_key[self._open_dropdown]
	if open and (open.hidden or open.disabled) then
		self:_close_dropdown()
	end
end

---@return number
HudSettingsMenu._numeric_value = function(self, def)
	if self._drag_key == def.key then
		return clamp(self._drag_value, def.min, def.max)
	end
	local value = self._mod:get(def.key)
	if type(value) ~= "number" then
		value = def.default_value
	end
	return clamp(value, def.min, def.max)
end

HudSettingsMenu._step_numeric = function(self, def, direction)
	local value = self:_numeric_value(def)
	value = clamp(round_to(value + direction * def.step_size, def.decimals_count), def.min, def.max)
	self._manager.commit_value(def, value)
end

---@return boolean
HudSettingsMenu._checkbox_value = function(self, def)
	local value = self._mod:get(def.key)
	if type(value) ~= "boolean" then
		value = def.default_value == true
	end
	return value
end

HudSettingsMenu._toggle_checkbox = function(self, def)
	self._manager.commit_value(def, not self:_checkbox_value(def))
end

---@return any
HudSettingsMenu._default_for = function(self, def)
	if def.default_value ~= nil then
		return def.default_value
	end
	return self._mod.dl.settings.defaults[def.key]
end

---@return boolean
HudSettingsMenu._is_default = function(self, def)
	local current = self._mod:get(def.key)
	local default = self:_default_for(def)

	if def.type == "keybind" then
		local current_unbound = type(current) ~= "table" or not current.name
		local default_unbound = type(default) ~= "table" or not default.name
		if current_unbound and default_unbound then
			return true
		end
		return values_equal(current, default)
	end

	if current == nil then
		return true
	end
	return values_equal(current, default)
end

HudSettingsMenu._reset_control = function(self, def)
	self._manager.commit_value(def, self:_default_for(def))
	if self._capturing == def.key then
		self:_cancel_capture()
	end
	if self._drag_key == def.key then
		self:_cancel_drag()
	end
	if self._open_dropdown == def.key then
		self:_close_dropdown()
	end
end

---@param controls table[] schema entries
HudSettingsMenu._reset_controls = function(self, controls)
	for i = 1, #controls do
		local def = controls[i]
		if def.type ~= "heading" and def.type ~= "button" then
			self._manager.commit_value(def, self:_default_for(def))
		end
	end

	self:_cancel_capture()
	self:_cancel_drag()
	self:_close_dropdown()
end

HudSettingsMenu._reset_tab = function(self)
	self:_reset_controls(self._tabs[self._active_tab].controls)
end

HudSettingsMenu._reset_all = function(self)
	local defs = {}
	for i = 1, #self._controls do
		defs[i] = self._controls[i].def
	end
	self:_reset_controls(defs)
end

HudSettingsMenu._press_button = function(self, def)
	self._manager.press_button(def)
end

---@return string
HudSettingsMenu._bind_text = function(self, def)
	if self._capturing == def.key then
		return self._constants.STRINGS.PRESS_KEY
	end
	local bind = self._mod:get(def.key)
	if type(bind) ~= "table" or not bind.name then
		return self._constants.STRINGS.UNBOUND
	end
	return bind_display(bind)
end

---@return number
HudSettingsMenu._dropdown_index = function(self, def)
	local options = def.option_list
	local value = self._mod:get(def.key)
	if value == nil then
		value = def.default_value
	end
	for i = 1, #options do
		if options[i].value == value then
			return i
		end
	end
	return 1
end

---@return string
HudSettingsMenu._option_label = function(self, option)
	if not option then
		return ""
	end
	local label = option.text or self._mod:localize(option.label_key)
	if option.color then
		label = self._mod.dl.str.rich_text(label, { color = option.color })
	end
	return label
end

---@return string
HudSettingsMenu._option_font = function(self, option)
	return (option and option.font_type) or self._module.passes.font.value
end

---@return string
HudSettingsMenu._dropdown_text = function(self, def)
	return self:_option_label(def.option_list[self:_dropdown_index(def)])
end

---@return number
HudSettingsMenu._dropdown_max_scroll = function(self, def)
	return math.max(0, #def.option_list - self._constants.DROPDOWN_MAX_VISIBLE)
end

HudSettingsMenu._open_dropdown_list = function(self, def)
	self._open_dropdown = def.key

	self._dropdown_scroll = clamp(self:_dropdown_index(def) - 1, 0, self:_dropdown_max_scroll(def))
	self._dropdown_accum = 0
	self._hover_option = nil
end

HudSettingsMenu._close_dropdown = function(self)
	self._open_dropdown = nil
	self._hover_option = nil
	self._dropdown_accum = 0
end

HudSettingsMenu._toggle_dropdown = function(self, def)
	if self._open_dropdown == def.key then
		self:_close_dropdown()
	else
		self:_open_dropdown_list(def)
	end
end

HudSettingsMenu._select_option = function(self, def, index)
	local option = def.option_list[index]
	if option then
		self._manager.commit_value(def, option.value)
	end
	self:_close_dropdown()
end

---@return DLH_SettingsMenuRect rect, number visible, number count
HudSettingsMenu._dropdown_rect = function(self, control)
	local C = self._constants
	local count = #control.def.option_list
	local visible = self._layout.dropdown_visible_options(count)
	local row = control.parts.row
	local height = visible * C.DROPDOWN_OPTION_HEIGHT

	local row_top = control.cell.y - self:_scroll_offset_px() + row.y
	local top_bound, bottom_bound = self._layout.viewport_bounds(self:_active_header_h())

	local y = row_top + C.CONTROL_HEIGHT
	if y + height > bottom_bound and row_top - height >= top_bound then
		y = row_top - height
	end

	return { x = control.cell.x + row.x, y = y, w = row.w, h = height }, visible, count
end

HudSettingsMenu._handle_dropdown_scroll = function(self, input_service)
	local control = self._by_key[self._open_dropdown]
	if not control then
		return
	end

	local max_scroll = self:_dropdown_max_scroll(control.def)
	if max_scroll <= 0 then
		self._dropdown_accum = 0
		return
	end

	local axis = input_service and input_service:get("scroll_axis")
	local delta = axis and axis[2] or 0
	if delta ~= 0 then
		self._dropdown_accum = self._dropdown_accum + delta
	end

	local step = self._constants.SCROLL_WHEEL_STEP
	local scroll = self._dropdown_scroll
	while self._dropdown_accum >= step do
		scroll = scroll - 1
		self._dropdown_accum = self._dropdown_accum - step
	end
	while self._dropdown_accum <= -step do
		scroll = scroll + 1
		self._dropdown_accum = self._dropdown_accum + step
	end
	self._dropdown_scroll = clamp(scroll, 0, max_scroll)
end

---@return boolean
HudSettingsMenu._update_dropdown_interaction = function(self, cx, cy, left, top, scale, pressed)
	local control = self._by_key[self._open_dropdown]
	if not control then
		self:_close_dropdown()
		return false
	end

	local rect, visible = self:_dropdown_rect(control)
	local screen = panel_rect_screen(rect, left, top, scale)
	if not self._layout.point_in(screen, cx, cy) then
		return false
	end

	local slot = math.floor((cy - screen.y) / (self._constants.DROPDOWN_OPTION_HEIGHT * scale)) + 1
	local index = self._dropdown_scroll + slot
	if slot >= 1 and slot <= visible and control.def.option_list[index] then
		self._hover_option = index
		if pressed then
			self:_select_option(control.def, index)
		end
	end
	return true
end

---@return number left, number top, number scale
HudSettingsMenu._panel_screen_frame = function(self)
	local width = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
	local height = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080
	local scale = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale) or 1

	local panel_node = self._ui_scenegraph and self._ui_scenegraph.panel
	local offset_x = panel_node and panel_node.position[1] or 0
	local offset_y = panel_node and panel_node.position[2] or 0

	local left = width * 0.5 + offset_x * scale - self._constants.PANEL_WIDTH * scale * 0.5
	local top = height * 0.5 + offset_y * scale - self._constants.PANEL_HEIGHT * scale * 0.5
	return left, top, scale
end

---@param cursor table
---@return boolean
HudSettingsMenu._cursor_outside_panel = function(self, cursor)
	local left, top, scale = self:_panel_screen_frame()
	local right = left + self._constants.PANEL_WIDTH * scale
	local bottom = top + self._constants.PANEL_HEIGHT * scale
	return cursor[1] < left or cursor[1] > right or cursor[2] < top or cursor[2] > bottom
end

HudSettingsMenu._update_backdrop_size = function(self)
	local width = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
	local height = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080
	local inverse_scale = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale) or 1

	self:_set_scenegraph_size("backdrop", width * inverse_scale, height * inverse_scale)
end

HudSettingsMenu._begin_capture = function(self, def)
	self._capturing = def.key

	self._capture_armed = false
end

HudSettingsMenu._cancel_capture = function(self)
	self._capturing = nil
	self._capture_armed = false
end

HudSettingsMenu._commit_capture = function(self, device, name)
	local control = self._by_key[self._capturing]
	if control then
		self._manager.commit_value(control.def, { device = device, name = name })
	end
	self:_cancel_capture()
end

HudSettingsMenu._clear_bind = function(self, def)
	self._manager.commit_value(def, false)
end

HudSettingsMenu._update_capture = function(self)
	if not self._capture_armed then
		self._capture_armed = true
		return
	end

	if Keyboard and Keyboard.any_pressed then
		local id = Keyboard.any_pressed()
		if id then
			local name = Keyboard.button_name(id)
			if name == "esc" then
				local control = self._by_key[self._capturing]
				if control then
					self:_clear_bind(control.def)
				end
				self:_cancel_capture()
			else
				self:_commit_capture("keyboard", name)
			end
			return
		end
	end

	if Mouse and Mouse.any_pressed then
		local id = Mouse.any_pressed()
		if id then
			self:_commit_capture("mouse", Mouse.button_name(id))
		end
	end
end

---@return number
HudSettingsMenu._drag_value_at = function(self, control, cx, left, top, scale)
	local def = control.def
	local box = part_screen_rect(control.cell, control.parts.value, left, top, scale)
	local fraction = clamp((cx - box.x) / box.w, 0, 1)
	local raw = def.min + fraction * (def.max - def.min)
	local steps = math.floor((raw - def.min) / def.step_size + 0.5)
	return clamp(round_to(def.min + steps * def.step_size, def.decimals_count), def.min, def.max)
end

HudSettingsMenu._begin_drag = function(self, control, cx, left, top, scale)
	self._drag_key = control.def.key
	self._drag_value = self:_drag_value_at(control, cx, left, top, scale)
end

HudSettingsMenu._commit_drag = function(self)
	local control = self._by_key[self._drag_key]
	if control then
		self._manager.commit_value(control.def, self._drag_value)
	end
	self._drag_key = nil
end

HudSettingsMenu._cancel_drag = function(self)
	self._drag_key = nil
end

---@return number
HudSettingsMenu._active_header_h = function(self)
	return self._layout.tab_header_height(self._tabs[self._active_tab])
end

---@return number
HudSettingsMenu._max_scroll = function(self)
	local starts = self._tab_row_starts[self._active_tab]
	local content = self._tab_units[self._active_tab] or 0
	local visible = self._layout.visible_units(self:_active_header_h())
	if not starts or content <= visible then
		return 0
	end
	for i = 1, #starts do
		if starts[i] + visible - 1 >= content then
			return i - 1
		end
	end
	return math.max(0, #starts - 1)
end

---@return number
HudSettingsMenu._current_scroll = function(self)
	return clamp(self._scroll_by_tab[self._active_tab] or 0, 0, self:_max_scroll())
end

---@return number
HudSettingsMenu._first_visible_unit = function(self)
	local starts = self._tab_row_starts[self._active_tab]
	return (starts and starts[self:_current_scroll() + 1]) or 1
end

---@return number
HudSettingsMenu._scroll_offset_px = function(self)
	return (self:_first_visible_unit() - 1) * self._layout.unit_step()
end

HudSettingsMenu._handle_scroll = function(self, input_service)
	local max_scroll = self:_max_scroll()
	if max_scroll <= 0 then
		self._scroll_accum = 0
		return
	end

	local axis = input_service and input_service:get("scroll_axis")
	local delta = axis and axis[2] or 0
	if delta ~= 0 then
		self._scroll_accum = self._scroll_accum + delta
	end

	local step = self._constants.SCROLL_WHEEL_STEP
	local previous = self._scroll_by_tab[self._active_tab] or 0
	local scroll = previous
	while self._scroll_accum >= step do
		scroll = scroll - 1
		self._scroll_accum = self._scroll_accum - step
	end
	while self._scroll_accum <= -step do
		scroll = scroll + 1
		self._scroll_accum = self._scroll_accum + step
	end
	scroll = clamp(scroll, 0, max_scroll)
	self._scroll_by_tab[self._active_tab] = scroll

	if scroll ~= previous then
		self._manager.set_scroll_offset(scroll)
	end
end

HudSettingsMenu._set_active_tab = function(self, index)
	if index == self._active_tab then
		return
	end
	self._active_tab = index
	self._manager.set_active_tab_id(self._tabs[index].id)

	self._manager.set_scroll_offset(self._scroll_by_tab[index] or 0)

	self:_cancel_capture()
	self:_cancel_drag()
	self:_close_dropdown()
	self._scroll_accum = 0
end

---@return boolean
HudSettingsMenu._update_interaction = function(self, input_service)
	self._hover_key = nil
	self._hover_tab = nil
	self._hover_reset_all = false
	self._hover_reset_tab = false
	self._hover_fancy = false

	local Layout = self._layout

	local cursor = input_service:get("cursor")
	if not cursor then
		if self._drag_key then
			self:_commit_drag()
		end
		return false
	end

	local left, top, scale = self:_panel_screen_frame()
	local cx, cy = cursor[1], cursor[2]

	local ctop = top - self:_scroll_offset_px() * scale

	if self._drag_key then
		if input_service:get("left_hold") then
			local control = self._by_key[self._drag_key]
			if control then
				self._drag_value = self:_drag_value_at(control, cx, left, ctop, scale)
			end
			self._hover_key = self._drag_key .. ":value"
		else
			self:_commit_drag()
		end
		return true
	end

	local pressed = input_service:get("left_pressed")

	if self._open_dropdown then
		self._hover_option = nil
		if self:_update_dropdown_interaction(cx, cy, left, top, scale, pressed) then
			return true
		end
		if pressed then
			self:_close_dropdown()
			return true
		end
	end

	if self._has_tabs then
		for i = 1, #self._tabs do
			local rect = panel_rect_screen(self._tab_hits[i], left, top, scale)
			if Layout.point_in(rect, cx, cy) then
				self._hover_tab = i
				if pressed then
					self:_set_active_tab(i)
				end
				return true
			end
		end
	end

	if self._reset_all_hit then
		local rect = panel_rect_screen(self._reset_all_hit, left, top, scale)
		if Layout.point_in(rect, cx, cy) then
			self._hover_reset_all = true
			if pressed then
				self:_reset_all()
			end
			return true
		end
	end
	if self._tab_reset_hit then
		local rect = panel_rect_screen(self._tab_reset_hit, left, top, scale)
		if Layout.point_in(rect, cx, cy) then
			self._hover_reset_tab = true
			if pressed then
				self:_reset_tab()
			end
			return true
		end
	end
	if self._fancy_hit then
		local rect = panel_rect_screen(self._fancy_hit, left, top, scale)
		if Layout.point_in(rect, cx, cy) then
			self._hover_fancy = true
			if pressed then
				self:_toggle_fancy()
			end
			return true
		end
	end

	local first_unit = self:_first_visible_unit()
	local last_unit = first_unit + self._layout.visible_units(self:_active_header_h()) - 1

	for i = 1, #self._controls do
		local control = self._controls[i]

		if control.tab_index ~= self._active_tab then
			goto continue
		end

		if control.hidden then
			goto continue
		end
		local def = control.def

		if control.display_row < first_unit or control.display_bottom > last_unit then
			goto continue
		end
		local parts = control.parts
		local cell = control.cell

		local act = pressed and not control.disabled

		if control.has_reset and not control.disabled and not self:_is_default(def) then
			local reset = part_screen_rect(cell, parts.reset, left, ctop, scale)
			if Layout.point_in(reset, cx, cy) then
				self._hover_key = def.key .. ":reset"
				if act then
					self:_reset_control(def)
				end
				return true
			end
		end

		if def.type == "numeric" then
			local minus = part_screen_rect(cell, parts.minus, left, ctop, scale)
			local plus = part_screen_rect(cell, parts.plus, left, ctop, scale)
			local value_box = part_screen_rect(cell, parts.value, left, ctop, scale)
			if Layout.point_in(minus, cx, cy) then
				self._hover_key = def.key .. ":minus"
				if act then
					self:_step_numeric(def, -1)
				end
				return true
			elseif Layout.point_in(plus, cx, cy) then
				self._hover_key = def.key .. ":plus"
				if act then
					self:_step_numeric(def, 1)
				end
				return true
			elseif Layout.point_in(value_box, cx, cy) then
				self._hover_key = def.key .. ":value"
				if act then
					self:_begin_drag(control, cx, left, ctop, scale)
				end
				return true
			end
		elseif def.type == "checkbox" then

			local hit = part_screen_rect(cell, parts.row, left, ctop, scale)
			if Layout.point_in(hit, cx, cy) then
				self._hover_key = def.key .. ":box"
				if act then
					self:_toggle_checkbox(def)
				end
				return true
			end
		elseif def.type == "keybind" then
			local clear = part_screen_rect(cell, parts.clear, left, ctop, scale)
			local box = part_screen_rect(cell, parts.box, left, ctop, scale)
			if Layout.point_in(clear, cx, cy) then
				self._hover_key = def.key .. ":clear"
				if act then
					self:_clear_bind(def)
				end
				return true
			elseif Layout.point_in(box, cx, cy) then
				self._hover_key = def.key .. ":box"
				if act then
					self:_begin_capture(def)
				end
				return true
			end
		elseif def.type == "button" then

			local hit = part_screen_rect(cell, parts.row, left, ctop, scale)
			if Layout.point_in(hit, cx, cy) then
				self._hover_key = def.key .. ":box"
				if act then
					self:_press_button(def)
				end
				return true
			end
		elseif def.type == "dropdown" then

			local arrow = part_screen_rect(cell, parts.arrow, left, ctop, scale)
			local row = part_screen_rect(cell, parts.row, left, ctop, scale)
			if Layout.point_in(arrow, cx, cy) then
				self._hover_key = def.key .. ":arrow"
				if act then
					self:_toggle_dropdown(def)
				end
				return true
			elseif Layout.point_in(row, cx, cy) then
				self._hover_key = def.key .. ":box"
				if act then
					self:_toggle_dropdown(def)
				end
				return true
			end
		end

		::continue::
	end

	return false
end

HudSettingsMenu._refresh = function(self)
	local COLOR = self._constants.COLOR
	local STRINGS = self._constants.STRINGS

	local offset_px = self:_scroll_offset_px()
	local first_unit = self:_first_visible_unit()
	local last_unit = first_unit + self._layout.visible_units(self:_active_header_h()) - 1

	local _, panel_top, scale = self:_panel_screen_frame()

	for i = 1, #self._controls do
		local control = self._controls[i]
		local def = control.def
		local widget = self._widgets_by_name[control.widget_name]
		if widget then

			local in_tab = control.tab_index == self._active_tab
			if in_tab then

				self:_set_scenegraph_position("cell_" .. def.key, control.cell.x, control.cell.y - offset_px)
			end
			widget.visible = in_tab
				and not control.hidden
				and control.display_row >= first_unit
				and control.display_bottom <= last_unit

			local disabled = control.disabled
			tint_text(widget, "label", disabled and COLOR.LABEL_DISABLED or COLOR.LABEL)

			if def.type == "numeric" then
				local value = self:_numeric_value(def)
				widget.content.value = string.format("%." .. def.decimals_count .. "f", value)
					.. (def.unit_suffix or "")

				widget.style.value_fill.size[1] = fraction_of(def, value) * control.parts.value.w
				tint(widget, "value_bg", disabled and COLOR.CONTROL_DISABLED or COLOR.CONTROL)
				tint(widget, "value_fill", disabled and COLOR.VALUE_FILL_DISABLED or COLOR.VALUE_FILL)
				tint_text(widget, "value", disabled and COLOR.VALUE_DISABLED or COLOR.VALUE)
				tint_text(widget, "minus_txt", disabled and COLOR.BUTTON_TEXT_DISABLED or COLOR.BUTTON_TEXT)
				tint_text(widget, "plus_txt", disabled and COLOR.BUTTON_TEXT_DISABLED or COLOR.BUTTON_TEXT)
				tint(
					widget,
					"minus",
					disabled and COLOR.CONTROL_BUTTON_DISABLED
						or (self._hover_key == def.key .. ":minus" and COLOR.CONTROL_HOVER or COLOR.CONTROL_BUTTON)
				)
				tint(
					widget,
					"plus",
					disabled and COLOR.CONTROL_BUTTON_DISABLED
						or (self._hover_key == def.key .. ":plus" and COLOR.CONTROL_HOVER or COLOR.CONTROL_BUTTON)
				)
			elseif def.type == "checkbox" then
				local on = self:_checkbox_value(def)
				widget.content.state = on and STRINGS.ON or STRINGS.OFF
				local fill = COLOR.CHECK_OFF
				if on then
					fill = disabled and COLOR.CONTROL_ACTIVE_DISABLED or COLOR.CONTROL_ACTIVE
				end
				tint(widget, "fill", fill)
				tint(
					widget,
					"box",
					disabled and COLOR.CONTROL_DISABLED
						or (self._hover_key == def.key .. ":box" and COLOR.CONTROL_HOVER or COLOR.CONTROL)
				)

				local target = on and COLOR.VALUE or COLOR.LABEL
				if disabled then
					target = on and COLOR.VALUE_DISABLED or COLOR.LABEL_DISABLED
				end
				tint_text(widget, "state", target)
			elseif def.type == "keybind" then
				widget.content.bind = self:_bind_text(def)
				local color = COLOR.CONTROL
				if disabled then
					color = COLOR.CONTROL_DISABLED
				elseif self._capturing == def.key then
					color = COLOR.CONTROL_ACTIVE
				elseif self._hover_key == def.key .. ":box" then
					color = COLOR.CONTROL_HOVER
				end
				tint(widget, "box", color)
				tint_text(widget, "bind", disabled and COLOR.VALUE_DISABLED or COLOR.VALUE)
				tint_text(widget, "clear_txt", disabled and COLOR.BUTTON_TEXT_DISABLED or COLOR.BUTTON_TEXT)
				tint(
					widget,
					"clear",
					disabled and COLOR.CONTROL_BUTTON_DISABLED
						or (self._hover_key == def.key .. ":clear" and COLOR.CONTROL_HOVER or COLOR.CONTROL_BUTTON)
				)
			elseif def.type == "dropdown" then
				widget.content.selected = self:_dropdown_text(def)
				widget.style.selected.font_type = self:_option_font(def.option_list[self:_dropdown_index(def)])

				local open = self._open_dropdown == def.key
				tint(
					widget,
					"box",
					disabled and COLOR.CONTROL_DISABLED
						or ((open or self._hover_key == def.key .. ":box") and COLOR.CONTROL_HOVER or COLOR.CONTROL)
				)
				tint(
					widget,
					"arrow",
					disabled and COLOR.CONTROL_BUTTON_DISABLED
						or (self._hover_key == def.key .. ":arrow" and COLOR.CONTROL_HOVER or COLOR.CONTROL_BUTTON)
				)
				tint_text(widget, "selected", disabled and COLOR.VALUE_DISABLED or COLOR.VALUE)
				tint_text(widget, "arrow_txt", disabled and COLOR.BUTTON_TEXT_DISABLED or COLOR.BUTTON_TEXT)
			elseif def.type == "button" then

				tint(
					widget,
					"box",
					disabled and COLOR.CONTROL_DISABLED
						or (self._hover_key == def.key .. ":box" and COLOR.CONTROL_HOVER or COLOR.CONTROL)
				)
				tint_text(widget, "caption", disabled and COLOR.BUTTON_TEXT_DISABLED or COLOR.BUTTON_TEXT)
			elseif def.type == "heading" then

				tint_text(widget, "heading", disabled and COLOR.LABEL_DISABLED or COLOR.HEADING)
				tint(widget, "heading_rule", disabled and COLOR.LABEL_DISABLED or COLOR.HEADING_RULE)
				tint_text(widget, "description", disabled and COLOR.LABEL_DISABLED or COLOR.TAB_DESC)
				self:_snap_heading_rule(control, widget, offset_px, panel_top, scale)
			end

			if control.has_reset then
				local color
				if disabled or self:_is_default(def) then
					color = COLOR.RESET_ICON_HIDDEN
				elseif self._hover_key == def.key .. ":reset" then
					color = COLOR.RESET_ICON_HOVER
				else
					color = COLOR.RESET_ICON
				end
				tint(widget, "reset", color)
			end
		end
	end

	if self._has_tabs then
		for i = 1, #self._tabs do
			local tab = self._tabs[i]
			local selected = i == self._active_tab
			local widget = self._widgets_by_name["tab_" .. tab.id]
			if widget then
				local hotspot = widget.content.hotspot
				local hover = self._hover_tab == i
				hotspot.is_selected = selected
				hotspot.is_hover = hover
				hotspot.anim_select_progress = selected and 1 or 0
				hotspot.anim_hover_progress = hover and 1 or 0
			end

			local header = self._widgets_by_name["tab_header_" .. tab.id]
			if header then
				header.visible = selected
			end
		end
	end

	self:_refresh_reset_buttons()
	self:_refresh_scrollbar()
	self:_refresh_dropdown_popup()
	self:_refresh_tooltip()
end

HudSettingsMenu._refresh_reset_buttons = function(self)
	local COLOR = self._constants.COLOR

	local reset_all = self._widgets_by_name["reset_all"]
	if reset_all then
		tint(reset_all, "box", self._hover_reset_all and COLOR.CONTROL_HOVER or COLOR.CONTROL)
	end

	local tab_reset = self._widgets_by_name["tab_reset"]
	if tab_reset then
		tint(tab_reset, "box", self._hover_reset_tab and COLOR.CONTROL_HOVER or COLOR.CONTROL)
	end

	local fancy = self._widgets_by_name["fancy_transitions"]
	if fancy then
		tint(fancy, "box", self._hover_fancy and COLOR.CONTROL_HOVER or COLOR.CONTROL)
		tint(fancy, "fill", self._mod.dl.settings.fancy_transitions and COLOR.CONTROL_ACTIVE or COLOR.CHECK_OFF)
	end
end

HudSettingsMenu._toggle_fancy = function(self)
	local current = self._mod.dl.settings.fancy_transitions
	self._mod:set("fancy_transitions", not current, true)
end

HudSettingsMenu._refresh_dropdown_popup = function(self)
	local widget = self._widgets_by_name["dropdown_popup"]
	if not widget then
		return
	end

	local control = self._open_dropdown and self._by_key[self._open_dropdown]
	if not control then
		widget.visible = false
		return
	end

	local first_unit = self:_first_visible_unit()
	local last_unit = first_unit + self._layout.visible_units(self:_active_header_h()) - 1
	if
		control.tab_index ~= self._active_tab
		or control.hidden
		or control.disabled
		or control.display_row < first_unit
		or control.display_bottom > last_unit
	then
		self:_close_dropdown()
		widget.visible = false
		return
	end

	widget.visible = true

	local C = self._constants
	local COLOR = C.COLOR
	local rect, visible, count = self:_dropdown_rect(control)
	self:_set_scenegraph_position("dropdown_popup", rect.x, rect.y)
	self:_set_scenegraph_size("dropdown_popup", rect.w, rect.h)

	local def = control.def
	local options = def.option_list
	local selected = self:_dropdown_index(def)
	local text_w = rect.w - C.DROPDOWN_TEXT_PAD * 2

	for slot = 1, C.DROPDOWN_MAX_VISIBLE do
		local option = slot <= visible and options[self._dropdown_scroll + slot] or nil

		widget.style["option_" .. slot].size[1] = rect.w
		widget.style["option_text_" .. slot].size[1] = text_w

		widget.style["option_text_" .. slot].font_type = self:_option_font(option)

		if option then
			widget.content["option_" .. slot] = self:_option_label(option)
			local color = COLOR.DROPDOWN_OPTION
			if self._hover_option == self._dropdown_scroll + slot then
				color = COLOR.CONTROL_HOVER
			elseif self._dropdown_scroll + slot == selected then
				color = COLOR.DROPDOWN_SELECTED
			end
			tint(widget, "option_" .. slot, color)
		else

			widget.content["option_" .. slot] = ""
			tint(widget, "option_" .. slot, COLOR.DROPDOWN_OPTION)
		end
	end

	local thumb = widget.style.popup_thumb
	if count > visible then
		local thumb_h = math.max(16, rect.h * visible / count)
		local max_scroll = count - visible
		thumb.offset[1] = rect.w - C.SCROLLBAR_WIDTH
		thumb.offset[2] = (rect.h - thumb_h) * (max_scroll > 0 and self._dropdown_scroll / max_scroll or 0)
		thumb.size[2] = thumb_h
		tint(widget, "popup_thumb", COLOR.SCROLLBAR_THUMB)
	else
		tint(widget, "popup_thumb", COLOR.DROPDOWN_OPTION)
	end
end

---@return table | false
HudSettingsMenu._tooltip_for = function(self, control)
	if control.tooltip ~= nil then
		return control.tooltip
	end

	local def = control.def
	local mod = self._mod
	local content = localized_or_nil(mod, def.description_key or (def.key .. "_description"))

	local tooltip = false
	if content then

		local title = localized_or_nil(mod, def.label_key or def.text_key)
		tooltip = { title = title and string.upper(title) or "", content = content }
	end

	control.tooltip = tooltip
	return tooltip
end

HudSettingsMenu._refresh_tooltip = function(self)
	local widget = self._widgets_by_name["tooltip"]
	if not widget then
		return
	end

	if self._open_dropdown then
		widget.visible = false
		return
	end

	local hover
	if self._hover_key then
		for i = 1, #self._controls do
			local c = self._controls[i]
			local key = c.def.key
			if c.tab_index == self._active_tab and self._hover_key:sub(1, #key + 1) == key .. ":" then
				hover = c
				break
			end
		end
	end

	local tooltip = hover and self:_tooltip_for(hover)
	if not tooltip then
		widget.visible = false
		return
	end

	local def = hover.def
	local C = self._constants
	widget.visible = true

	local title_text = tooltip.title
	local content_text = tooltip.content
	widget.content.title = title_text
	widget.content.content = content_text

	if self._tooltip_key ~= def.key and self._ui_renderer then
		self._tooltip_key = def.key
		self:_layout_tooltip(widget, title_text, content_text)
	end

	local cell = hover.cell
	local panel = self._ui_scenegraph and self._ui_scenegraph.panel
	local panel_x = panel and panel.position[1] or 0
	local panel_y = panel and panel.position[2] or 0

	local x = panel_x + (cell.x + cell.w - C.PANEL_WIDTH * 0.5 + C.TOOLTIP_GAP + C.TOOLTIP_WIDTH * 0.5)
	local y = panel_y + (cell.y - self:_scroll_offset_px() + cell.h * 0.5 - C.PANEL_HEIGHT * 0.5)
	self:_set_scenegraph_position("tooltip", x, y)
end

---@return number
HudSettingsMenu._wrapped_text_height = function(self, ui_renderer, text, style)
	local _, height = self:_text_size(ui_renderer, text, style, { style.size[1], 100000 }, true)
	return height
end

HudSettingsMenu._layout_tooltip = function(self, widget, title_text, content_text)
	local C = self._constants
	local ui_renderer = self._ui_renderer

	local PAD_TOP = 34
	local TITLE_DIVIDER_GAP = 10
	local DIVIDER_H = 20
	local DIVIDER_CONTENT_GAP = 10
	local PAD_BOTTOM = 40

	local style = widget.style

	local title_h = self:_wrapped_text_height(ui_renderer, title_text, style.title)
	local content_h = self:_wrapped_text_height(ui_renderer, content_text, style.content)

	local title_y = PAD_TOP
	local divider_y = title_y + title_h + TITLE_DIVIDER_GAP
	local content_y = divider_y + DIVIDER_H + DIVIDER_CONTENT_GAP
	local total_h = content_y + content_h + PAD_BOTTOM

	style.title.offset[2] = title_y
	style.title.size[2] = title_h
	style.divider.offset[2] = divider_y
	style.content.offset[2] = content_y
	style.content.size[2] = content_h

	self:_set_scenegraph_size("tooltip", C.TOOLTIP_WIDTH, math.max(total_h, C.TOOLTIP_MIN_HEIGHT))
end

HudSettingsMenu._layout_heading_rules = function(self)
	local ui_renderer = self._ui_renderer
	if not ui_renderer then
		return
	end
	self._heading_rules_done = true

	local GAP = 12

	for i = 1, #self._controls do
		local control = self._controls[i]
		local def = control.def
		if def.type == "heading" then
			local widget = self._widgets_by_name[control.widget_name]
			local rule = widget and widget.style.heading_rule
			if rule then
				local heading_style = widget.style.heading
				local text = self._mod:localize(def.label_key)

				local text_w = self:_text_size(ui_renderer, text, heading_style, { control.cell.w, 200 }, false)
				local start_x = text_w + GAP
				local width = control.cell.w - start_x
				rule.offset[1] = start_x
				rule.size[1] = math.max(0, width)
			end
		end
	end
end

HudSettingsMenu._snap_heading_rule = function(self, control, widget, offset_px, panel_top, scale)
	local rule = widget.style.heading_rule
	local heading = widget.style.heading
	if not rule or not heading then
		return
	end

	local thickness = math.max(2, math.floor(scale + 0.5))

	local center_design = heading.size[2] * 0.5
	local center_screen = panel_top + (control.cell.y - offset_px + center_design) * scale
	local top_screen = math.floor(center_screen - thickness * 0.5 + 0.5)

	rule.offset[2] = (top_screen - panel_top) / scale - (control.cell.y - offset_px)
	rule.size[2] = thickness / scale
end

HudSettingsMenu._refresh_scrollbar = function(self)
	local widget = self._widgets_by_name["scrollbar"]
	if not widget then
		return
	end

	local header_h = self:_active_header_h()
	local content_units = self._tab_units[self._active_tab] or 0
	local visible_units = self._layout.visible_units(header_h)
	if content_units <= visible_units then
		widget.visible = false
		return
	end
	widget.visible = true

	local track = self._layout.scrollbar_rect(header_h)
	local track_h = track.h
	self:_set_scenegraph_position("scrollbar", track.x, track.y)
	self:_set_scenegraph_size("scrollbar", track.w, track_h)
	widget.style.track.size[2] = track_h

	local thumb_h = math.max(24, track_h * visible_units / content_units)

	local max_offset = content_units - visible_units
	local frac = max_offset > 0 and clamp((self:_first_visible_unit() - 1) / max_offset, 0, 1) or 0
	widget.style.thumb.size[2] = thumb_h
	widget.style.thumb.offset[2] = (track_h - thumb_h) * frac
end

HudSettingsMenu._dispatch_binds = function(self)
	if self._capturing or Managers.ui:using_input(true) then
		return
	end

	local mod = self._mod
	for i = 1, #self._controls do
		local control = self._controls[i]
		local def = control.def

		if def.type == "keybind" and def.function_name and not control.hidden and not control.disabled then
			local bind = mod:get(def.key)
			if type(bind) == "table" and bind.name and bind_pressed(bind) then
				local fn = mod[def.function_name]
				if type(fn) == "function" then
					fn(mod, true)
				end
			end
		end
	end
end

HudSettingsMenu.update = function(self, dt, t, input_service)
	HudSettingsMenu.super.update(self, dt, t, input_service)

	if not self:visible() then
		self:_cancel_capture()
		self:_cancel_drag()
		self:_close_dropdown()
		return
	end

	self:_update_menu(dt, t, input_service)
end

HudSettingsMenu._update_menu = function(self, dt, t, input_service)

	if not self._heading_rules_done and self._ui_renderer then
		self:_layout_heading_rules()
	end

	self:_update_states()

	if self._capturing then

		self._hover_key = nil
		self:_update_capture()
	else

		if self._open_dropdown then
			self:_handle_dropdown_scroll(input_service)
		else
			self:_handle_scroll(input_service)
		end

		self:_update_interaction(input_service)
	end

	self:_refresh()

	if self._update_scenegraph then
		UIScenegraph.update_scenegraph(self._ui_scenegraph, self._render_scale)
		self._update_scenegraph = nil
	end
end

HudSettingsMenu._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)

	self._ui_renderer = ui_renderer

	HudSettingsMenu.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudSettingsMenu
