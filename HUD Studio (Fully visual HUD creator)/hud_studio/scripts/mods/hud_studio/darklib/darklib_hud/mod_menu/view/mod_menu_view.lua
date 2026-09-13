

local math_floor = math.floor

---@param rect table screen-px rect
local function point_in(rect, x, y)
	return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

---@param style table text pass style
---@param color argb_table
local function set_text_color(style, color)
	style.text_color[1] = color[1]
	style.text_color[2] = color[2]
	style.text_color[3] = color[3]
	style.text_color[4] = color[4]
end

---@param widget table
---@param value_id string
---@param text string
---@param color argb_table|nil
local function set_text(widget, value_id, text, color)
	widget.content[value_id] = text or ""
	if color then
		set_text_color(widget.style[value_id], color)
	end
end

---@param style table rect pass style
---@param color argb_table
local function set_rect_color(style, color)
	style.color[1] = color[1]
	style.color[2] = color[2]
	style.color[3] = color[3]
	style.color[4] = color[4]
end

local ModMenuView = class("DLModMenuView", "BaseView")

ModMenuView.init = function(self, settings, context)

	local mod = get_mod(context and context.mod_name)
	self._mod = mod

	local _module = mod.dl_hud.__hud_modules["mod_menu"]
	self._module = _module
	self._manager = _module.manager
	self._constants = _module.constants
	self._presentation = _module.presentation

	self._definitions = _module.hud_definitions
	ModMenuView.super.init(self, self._definitions, settings)

	self._pass_draw = true

	self._pass_input = false
	self._hover_module = nil

	self._hover_secret = false
	self._near_secret = false

	self._page_elements = {}

	self._overlay = nil
end

local PAGE_DRAW_LAYER = 830

local OVERLAY_DRAW_LAYER = 850

local SLIDE_NODES = {
	{ id = "panel_chain_left", order = 0 },
	{ id = "panel_chain_right", order = 0 },
	{ id = "panel_frame_left", order = 1 },
	{ id = "panel_frame_right", order = 1 },
	{ id = "chain_connector_frame_left", order = 1 },
	{ id = "chain_connector_frame_right", order = 1 },
}

local OVERLAY_SLIDE_ORDER = 1

local MAX_SLIDE_ORDER = OVERLAY_SLIDE_ORDER
for i = 1, #SLIDE_NODES do
	if SLIDE_NODES[i].order > MAX_SLIDE_ORDER then
		MAX_SLIDE_ORDER = SLIDE_NODES[i].order
	end
end

local ANIM = {

	FADE_IN_TICKS = 8, 
	SLIDE_START_DELAY = 6, 
	SLIDE_STAGGER = 0, 
	SLIDE_TICKS = 14, 
	SLIDE_ENTER_OFFSET = 90, 
	OVERLAY_HOLD_TICKS = 20, 
	OVERLAY_FADE_OUT_TICKS = 12,

	OVERLAY_FADE_IN_TICKS = 8, 
	CLOSE_LABEL_DELAY = 8, 
	CLOSE_LABEL_HOLD_TICKS = 15, 
	CLOSE_SLIDE_STAGGER = 2, 
	CLOSE_SLIDE_TICKS = 22, 
	SLIDE_EXIT_OFFSET = -90, 
	CLOSE_FADE_DELAY = 10, 
	FADE_OUT_TICKS = 18, 
}

local OPEN_SLIDE_END = ANIM.SLIDE_START_DELAY + MAX_SLIDE_ORDER * ANIM.SLIDE_STAGGER + ANIM.SLIDE_TICKS

---@param p number
---@return number clamped 0..1
local function clamp01(p)
	if p < 0 then
		return 0
	elseif p > 1 then
		return 1
	end
	return p
end

---@return number
local function slide_progress(tick, order, start_delay, stagger, dur)
	return clamp01((tick - (start_delay + order * stagger)) / dur)
end

ModMenuView.on_enter = function(self)

	ModMenuView.super.on_enter(self)

	local mod = self._mod
	local pages = self._manager.pages()
	for i = 1, #pages do
		local page = pages[i]
		if page.element_path and not self._page_elements[page.id] then
			local class = mod:io_dofile(page.element_path)
			if class then
				local element = self:_add_element(class, page.id, PAGE_DRAW_LAYER, page.element_context)
				self._page_elements[page.id] = element
			end
		end
	end

	if not self._overlay and self._module.overlay_element_path then
		local overlay_class = mod:io_dofile(self._module.overlay_element_path)
		if overlay_class then
			self._overlay =
				self:_add_element(overlay_class, "mod_menu_overlay", OVERLAY_DRAW_LAYER, { mod_name = mod:get_name() })
		end
	end

	self:_anim_init()
end

ModMenuView.on_exit = function(self)
	ModMenuView.super.on_exit(self)
end

---@return number left, number top, number scale
ModMenuView._nav_screen_frame = function(self)
	local scale = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale) or 1
	local node = self._ui_scenegraph and self._ui_scenegraph.nav_panel
	local pos = node and node.world_position
	local left = pos and pos[1] or 0
	local top = pos and pos[2] or 0
	return left, top, scale
end

ModMenuView._screen_rect = function(self, rect, left, top, scale)
	return { x = left + rect.x * scale, y = top + rect.y * scale, w = rect.w * scale, h = rect.h * scale }
end

---@param input_service any
ModMenuView._update_interaction = function(self, input_service)
	self._hover_module = nil
	self._hover_secret = false
	self._near_secret = false

	local cursor = input_service and input_service:get("cursor")
	if not cursor then
		return
	end

	local C = self._constants
	local Presentation = self._presentation
	local pages = self._manager.nav_pages()
	local nav_left, nav_top, scale = self:_nav_screen_frame()
	local cx, cy = cursor[1], cursor[2]
	local pressed = input_service:get("left_pressed")

	for i = 1, math.min(#pages, C.MAX_MODULE_BUTTONS) do
		local rect = self:_screen_rect(Presentation.nav_button_local(i), nav_left, nav_top, scale)
		if point_in(rect, cx, cy) then
			self._hover_module = i
			if pressed then
				self._manager.set_active_page(pages[i].id)
			end
			return
		end
	end

	local secret = self._manager.first_secret_page()
	if secret then
		local direct = self:_screen_rect(Presentation.secret_button_local(), nav_left, nav_top, scale)
		if point_in(direct, cx, cy) then
			self._hover_secret = true
			self._near_secret = true
			if pressed then
				self._manager.set_active_page(secret.id)
			end
		elseif point_in(self:_screen_rect(Presentation.secret_proximity_local(), nav_left, nav_top, scale), cx, cy) then
			self._near_secret = true
		end
	end
end

ModMenuView._refresh_nav = function(self)
	local C = self._constants
	local nav = self._widgets_by_name.nav_panel
	local pages = self._manager.nav_pages()
	local active_id = self._manager.active_page_id()

	local VISIBLE = { 220, 255, 255, 255 }
	local HIDDEN = { 0, 0, 0, 0 }

	for i = 1, C.MAX_MODULE_BUTTONS do
		local page = pages[i]
		if page then
			local active = page.id == active_id

			nav.content["module_btn_frame_" .. i] = active and C.MATERIAL.button_active or C.MATERIAL.button_idle
			set_rect_color(nav.style["module_btn_frame_" .. i], VISIBLE)

			set_text(nav, "module_btn_" .. i, page.label, C.COLOR.MODULE_BTN_TEXT)
		else

			set_rect_color(nav.style["module_btn_frame_" .. i], HIDDEN)
			set_rect_color(nav.style["module_btn_selected_" .. i], HIDDEN)
			set_rect_color(nav.style["module_btn_backdrop_" .. i], HIDDEN)
			set_text(nav, "module_btn_" .. i, "")
		end
	end
end

ModMenuView._refresh_secret = function(self)
	local nav = self._widgets_by_name.nav_panel
	if not nav then
		return
	end
	local alpha = 0
	if self._manager.first_secret_page() then
		if self._hover_secret then
			alpha = 255
		elseif self._near_secret then
			alpha = self._constants.SECRET_BTN_NEAR_ALPHA
		end
	end
	nav.style.secret_btn_icon.color[1] = alpha
end

ModMenuView._refresh_title = function(self)
	local panel = self._widgets_by_name.panel
	if panel then
		panel.content.title = self._manager.active_page_label()
	end
end

ModMenuView._refresh_aside = function(self)
	local C = self._constants
	local aside = self._widgets_by_name.aside_panel
	if not aside then
		return
	end

	local items = self._manager.aside_items()
	for i = 1, C.MAX_ASIDE_ROWS do
		local item = items[i]
		if item and item.heading then

			set_text(aside, "aside_heading_" .. i, item.label or "", C.COLOR.ASIDE_HEADING)
			set_text(aside, "aside_heading_r_" .. i, item.label_right or "", C.COLOR.ASIDE_HEADING)
			set_text(aside, "aside_label_" .. i, "")
			set_text(aside, "aside_value_" .. i, "")
		elseif item and not item.spacer then
			local value = item.value
			if type(value) == "function" then
				value = value()
			end
			set_text(aside, "aside_label_" .. i, item.label or "", C.COLOR.ASIDE_LABEL)
			set_text(aside, "aside_value_" .. i, value or "", C.COLOR.ASIDE_VALUE)
			set_text(aside, "aside_heading_" .. i, "")
			set_text(aside, "aside_heading_r_" .. i, "")
		else
			set_text(aside, "aside_label_" .. i, "")
			set_text(aside, "aside_value_" .. i, "")
			set_text(aside, "aside_heading_" .. i, "")
			set_text(aside, "aside_heading_r_" .. i, "")
		end
	end
end

ModMenuView.update = function(self, dt, t, input_service)
	self:_update_animation()

	local active = self._manager.active_page_id()
	local hidden = self:_content_hidden()
	for id, element in pairs(self._page_elements) do
		element:set_visibility(not hidden and id == active)
	end
	local panel = self._widgets_by_name.panel
	if panel then
		panel.visible = not hidden
	end

	if input_service and input_service:get("back") then
		self._manager.close()
	end

	self:_update_interaction(input_service)
	self:_refresh_nav()
	self:_refresh_secret()
	self:_refresh_title()
	self:_refresh_aside()

	return ModMenuView.super.update(self, dt, t, input_service)
end

---@return boolean
ModMenuView._content_hidden = function(self)
	local anim = self._anim
	if not anim then
		return false
	end
	local phase = anim.phase
	return phase == "open"
		or phase == "open_hold"
		or phase == "close_hold"
		or phase == "close_slide"
		or phase == "close_done"
end

---@param a number
ModMenuView._set_master_alpha = function(self, a)
	self._render_settings.alpha_multiplier = a
end

---@param offset_fn fun(order: integer): number
ModMenuView._apply_slide = function(self, offset_fn)
	for i = 1, #SLIDE_NODES do
		local node = SLIDE_NODES[i]
		local base = (self._slide_base_y and self._slide_base_y[node.id]) or 0
		self:_set_scenegraph_position(node.id, nil, base + offset_fn(node.order))
	end
end

ModMenuView._anim_init = function(self)
	local sg = self._ui_scenegraph
	self._slide_base_y = {}
	for i = 1, #SLIDE_NODES do
		local id = SLIDE_NODES[i].id
		self._slide_base_y[id] = (sg and sg[id] and sg[id].position[2]) or 0
	end

	self._play_close_called = false
	self._close_anim_done = false

	local fancy = self._manager.force_fancy() or self._mod.dl.settings.fancy_transitions ~= false

	self:_set_master_alpha(0)
	if fancy then

		self._anim = { mode = "open", phase = "open", tick = 0, settled = false }
		self:_apply_slide(function()
			return ANIM.SLIDE_ENTER_OFFSET
		end)
		if self._overlay then
			self._overlay:set_visibility(true)
			self._overlay:set_alpha_multiplier(1)
			self._overlay:set_slide_offset(ANIM.SLIDE_ENTER_OFFSET)
		end
	else

		self._anim = { mode = "open", phase = "open_fade_only", tick = 0 }
		if self._overlay then
			self._overlay:set_visibility(false)
		end
	end
end

ModMenuView._update_animation = function(self)
	local anim = self._anim
	if not anim then
		return
	end
	anim.tick = anim.tick + 1
	local tick = anim.tick
	local phase = anim.phase
	local overlay = self._overlay

	if phase == "open" then

		self:_set_master_alpha(clamp01(tick / ANIM.FADE_IN_TICKS))
		if tick <= OPEN_SLIDE_END then
			self:_apply_slide(function(order)
				local p = slide_progress(tick, order, ANIM.SLIDE_START_DELAY, ANIM.SLIDE_STAGGER, ANIM.SLIDE_TICKS)
				return ANIM.SLIDE_ENTER_OFFSET * (1 - p)
			end)
			if overlay then
				local op = slide_progress(
					tick,
					OVERLAY_SLIDE_ORDER,
					ANIM.SLIDE_START_DELAY,
					ANIM.SLIDE_STAGGER,
					ANIM.SLIDE_TICKS
				)
				overlay:set_slide_offset(ANIM.SLIDE_ENTER_OFFSET * (1 - op))
			end
		elseif not anim.settled then

			self:_apply_slide(function()
				return 0
			end)
			if overlay then
				overlay:set_slide_offset(0)
			end
			anim.settled = true
		end

		if (not overlay) or overlay:is_open_done() then
			self:_set_master_alpha(1)
			self:_apply_slide(function()
				return 0
			end)
			if overlay then
				overlay:set_slide_offset(0)
			end
			anim.phase = "open_hold"
			anim.tick = 0
		end
	elseif phase == "open_fade_only" then

		self:_set_master_alpha(clamp01(tick / ANIM.FADE_IN_TICKS))
		if tick >= ANIM.FADE_IN_TICKS then
			self:_set_master_alpha(1)
			anim.phase = "idle"
		end
	elseif phase == "open_hold" then

		if tick >= ANIM.OVERLAY_HOLD_TICKS then
			anim.phase = "open_overlay_fade"
			anim.tick = 0
		end
	elseif phase == "open_overlay_fade" then

		local p = clamp01(tick / ANIM.OVERLAY_FADE_OUT_TICKS)
		if overlay then
			overlay:set_alpha_multiplier(1 - p)
		end
		if p >= 1 then
			if overlay then
				overlay:set_visibility(false)
			end
			anim.phase = "idle"
		end
	elseif phase == "close_overlay_in" then

		self:_set_master_alpha(1)
		if overlay then
			overlay:set_alpha_multiplier(clamp01(tick / ANIM.OVERLAY_FADE_IN_TICKS))
		end
		if tick >= ANIM.CLOSE_LABEL_DELAY and not self._play_close_called then
			self._play_close_called = true
			if overlay then
				overlay:play_close()
			end
		end

		if (not overlay) or overlay:is_close_done() then
			anim.phase = "close_hold"
			anim.tick = 0
		end
	elseif phase == "close_hold" then

		if tick >= ANIM.CLOSE_LABEL_HOLD_TICKS then
			anim.phase = "close_slide"
			anim.tick = 0
		end
	elseif phase == "close_slide" then

		self:_apply_slide(function(order)
			local p = slide_progress(tick, order, 0, ANIM.CLOSE_SLIDE_STAGGER, ANIM.CLOSE_SLIDE_TICKS)
			return -ANIM.SLIDE_EXIT_OFFSET * p
		end)

		if overlay then
			local op = slide_progress(tick, OVERLAY_SLIDE_ORDER, 0, ANIM.CLOSE_SLIDE_STAGGER, ANIM.CLOSE_SLIDE_TICKS)
			overlay:set_slide_offset(-ANIM.SLIDE_EXIT_OFFSET * op)
		end
		if tick >= ANIM.CLOSE_FADE_DELAY then
			local p = clamp01((tick - ANIM.CLOSE_FADE_DELAY) / ANIM.FADE_OUT_TICKS)
			self:_set_master_alpha(1 - p)
			if p >= 1 then
				anim.phase = "close_done"
				self._close_anim_done = true
			end
		end
	elseif phase == "close_fade_only" then

		local p = clamp01(tick / ANIM.FADE_OUT_TICKS)
		self:_set_master_alpha(1 - p)
		if p >= 1 then
			anim.phase = "close_done"
			self._close_anim_done = true
		end
	end

end

ModMenuView.trigger_on_exit_animation = function(self)
	ModMenuView.super.trigger_on_exit_animation(self)

	if self._anim and self._anim.mode == "close" then
		return
	end
	self._play_close_called = false
	self._close_anim_done = false
	self:_set_master_alpha(1)

	local fancy = self._manager.force_fancy() or self._mod.dl.settings.fancy_transitions ~= false

	self._manager.clear_force_fancy()
	if fancy then
		self._anim = { mode = "close", phase = "close_overlay_in", tick = 0 }
		self:_apply_slide(function()
			return 0
		end)
		if self._overlay then
			self._overlay:set_visibility(true)
			self._overlay:set_alpha_multiplier(0)

			self._overlay:clear_text()
		end
	else

		self._anim = { mode = "close", phase = "close_fade_only", tick = 0 }
		if self._overlay then
			self._overlay:set_visibility(false)
		end
	end
end

---@return boolean
ModMenuView.on_exit_animation_done = function(self)
	return self._close_anim_done == true
end

return ModMenuView
