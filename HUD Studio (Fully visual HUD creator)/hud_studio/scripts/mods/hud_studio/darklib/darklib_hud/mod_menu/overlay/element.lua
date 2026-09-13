

require("scripts/ui/view_elements/view_element_base")

local BOOTUP_CHARS_PER_STEP = 40
local BOOTUP_TICKS_PER_STEP = 1
local LABEL_CHARS_PER_STEP = 2
local LABEL_TICKS_PER_STEP = 2

local BOOTUP_HOLD_TICKS = 8

local function typer(full, chars, ticks)
	full = full or ""
	return { full = full, len = #full, revealed = 0, tick = 0, chars = chars, ticks = ticks }
end

local function typer_done(tp)
	return tp.revealed >= tp.len
end

local function typer_step(tp)
	if tp.revealed >= tp.len then
		return nil
	end
	tp.tick = tp.tick + 1
	if tp.tick < tp.ticks then
		return nil
	end
	tp.tick = 0
	tp.revealed = math.min(tp.len, tp.revealed + tp.chars)
	return string.sub(tp.full, 1, tp.revealed)
end

local function loc_or(mod, key, fallback)
	local text = mod:localize(key)
	if not text or text == "<" .. key .. ">" then
		return fallback
	end
	return text
end

local ModMenuOverlayElement = class("DLModMenuOverlayElement@" .. tostring({}), "ViewElementBase")

ModMenuOverlayElement.init = function(self, parent, draw_layer, start_scale, context)

	local mod = get_mod(context and context.mod_name)
	self._mod = mod

	local _module = mod.dl_hud.__hud_modules["mod_menu"]
	self._module = _module

	local defs = _module.overlay_definitions
	self._definitions = defs
	ModMenuOverlayElement.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = defs.scenegraph_definition,
		widget_definitions = defs.widget_definitions,
	})

	local panel_node = self._ui_scenegraph and self._ui_scenegraph.overlay_panel
	self._panel_base_y = (panel_node and panel_node.position[2]) or 0

	self._bootup_full = _module.bootup_print or ""
	self._open_label = loc_or(mod, "access_granted", "- ACCESS GRANTED -")
	self._close_label = loc_or(mod, "terminated", "- TERMINATED -")

	self:play_open()
end

---@param text string
ModMenuOverlayElement._set_bootup_text = function(self, text)
	local widget = self._widgets_by_name.overlay_panel
	if widget then
		widget.content.bootup_sequence_text = text or ""
	end
end

---@param text string
ModMenuOverlayElement.set_label = function(self, text)
	local widget = self._widgets_by_name.overlay_panel
	if widget then
		widget.content.overlay_title = text or ""
	end
end

ModMenuOverlayElement.play_open = function(self)
	self._bootup = typer(self._bootup_full, BOOTUP_CHARS_PER_STEP, BOOTUP_TICKS_PER_STEP)
	self._label = typer(self._open_label, LABEL_CHARS_PER_STEP, LABEL_TICKS_PER_STEP)
	self._open_done = false
	self._close_done = false
	self._phase = "open_bootup"
	self:_set_bootup_text("")
	self:set_label("")
end

---@return boolean
ModMenuOverlayElement.is_open_done = function(self)
	return self._open_done == true
end

ModMenuOverlayElement.clear_text = function(self)
	self._phase = "idle"
	self:_set_bootup_text("")
	self:set_label("")
end

ModMenuOverlayElement.play_close = function(self)
	self._label = typer(self._close_label, LABEL_CHARS_PER_STEP, LABEL_TICKS_PER_STEP)
	self._close_done = false
	self._phase = "close_label"
	self:_set_bootup_text("")
	self:set_label("")
end

---@return boolean
ModMenuOverlayElement.is_close_done = function(self)
	return self._close_done == true
end

---@param offset number
ModMenuOverlayElement.set_slide_offset = function(self, offset)
	self:_set_scenegraph_position("overlay_panel", nil, self._panel_base_y + (offset or 0))
end

ModMenuOverlayElement.update = function(self, dt, t, input_service)
	ModMenuOverlayElement.super.update(self, dt, t, input_service)

	local phase = self._phase

	if phase == "open_bootup" then

		local slice = typer_step(self._bootup)
		if slice then
			self:_set_bootup_text(slice)
		end
		if typer_done(self._bootup) then
			self._hold_tick = 0
			self._phase = "open_bootup_hold"
		end
	elseif phase == "open_bootup_hold" then

		self._hold_tick = (self._hold_tick or 0) + 1
		if self._hold_tick >= BOOTUP_HOLD_TICKS then
			self._phase = "open_label"
		end
	elseif phase == "open_label" then

		local slice = typer_step(self._label)
		if slice then
			self:set_label(slice)
		end
		if typer_done(self._label) then
			self._phase = "idle"
			self._open_done = true
		end
	elseif phase == "close_label" then

		local slice = typer_step(self._label)
		if slice then
			self:set_label(slice)
		end
		if typer_done(self._label) then
			self._phase = "idle"
			self._close_done = true
		end
	end

end

return ModMenuOverlayElement
