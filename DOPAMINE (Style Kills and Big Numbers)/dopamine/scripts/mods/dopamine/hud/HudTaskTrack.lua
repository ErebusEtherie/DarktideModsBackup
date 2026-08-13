

---@type mod
local mod = get_mod("dopamine")

local TaskManager = mod:core(mod.task_manager, "utils/task/manager")
local TaskPresentation = mod:core(mod.task_presentation, "hud/task/presentation")
local Rumble = mod:core(mod.rumble, "utils/rumble")
local Definitions = mod:io_dofile("dopamine/scripts/mods/dopamine/hud/task/definitions")
local Constants = mod:core(mod.constants, "hud/constants")

local TaskConstants = mod:core(mod.task_constants, "hud/task/constants").PRESENTATION

local math_clamp = math.clamp
local math_floor = math.floor
local math_max = math.max

---@class HudTaskTrack : HudElementBase
---@field _task_slide_y table<integer, number> -- lerped Y per task uid
---@field _task_enter_t table<integer, number> -- remaining enter time per task uid
---@field _task_seen table<integer, boolean> -- uids present this frame (cleanup pass)
---@field _panel_alpha number -- eased panel/title alpha (0.5 idle .. 1 populated)
---@field _theme "simple"|"ui"|nil -- last applied theme; guards texture re-points
local HudTaskTrack = class("HudTaskTrack", "HudElementBase")

---@param parent table
---@param draw_layer number
---@param start_scale number
HudTaskTrack.init = function(self, parent, draw_layer, start_scale)
	HudTaskTrack.super.init(self, parent, draw_layer + Constants.HUD_Z_BOOST, start_scale, {
		scenegraph_definition = Definitions.scenegraph_definition,
		widget_definitions = Definitions.widget_definitions,
	})

	self._task_slide_y = {}
	self._task_enter_t = {}
	self._task_seen = {}

	self._panel_alpha = 0

	self._theme = nil

end

---@param style table -- a text style pass
local function hide_text_pass(style)
	style.text_color[1] = 0
end

---@param style table -- a text style pass (mutated in place)
---@param alpha number
---@param offset_x number|nil
---@param offset_y number|nil
---@param scale number|nil
---@param color argb_table -- base ARGB; only channels 2-4 are read here
---@param font_size number
local function set_text_pass(style, alpha, offset_x, offset_y, scale, color, font_size)
	style.text_color[1] = math_floor(255 * math_clamp(alpha, 0, 1))
	style.text_color[2] = color[2] or 255
	style.text_color[3] = color[3] or 255
	style.text_color[4] = color[4] or 255
	style.offset[1] = offset_x or 0
	style.offset[2] = offset_y or 0
	style.font_size = math_floor(font_size * (scale or 1))
end

---@param layout TaskLayout
---@param rumble_x number|nil
---@param rumble_y number|nil
HudTaskTrack._apply_side_layout = function(self, layout, rumble_x, rumble_y)
	self:set_scenegraph_position(
		"taskTrackRoot",
		layout.root_margin_x + (rumble_x or 0),
		layout.offset_y + (rumble_y or 0),
		19,
		layout.halign,
		layout.root_valign
	)

	local rows_widget = self._widgets_by_name.task_rows
	if rows_widget then
		for slot = 1, TaskConstants.MAX_SLOTS do
			TaskPresentation.apply_text_align(rows_widget.style["line_" .. slot], layout)
			TaskPresentation.apply_text_align(rows_widget.style["timer_" .. slot], layout)
		end
	end

	local panel_widget = self._widgets_by_name.task_panel
	if panel_widget then
		TaskPresentation.apply_panel_align(panel_widget.style.background, layout)
		TaskPresentation.apply_panel_texture_uv(panel_widget.style.background, layout)

		panel_widget.style.border.horizontal_alignment = layout.halign
	end

	local title_widget = self._widgets_by_name.task_title
	if title_widget then
		TaskPresentation.apply_text_align(title_widget.style.title, layout)
	end
end

---@param panel_widget table
HudTaskTrack._apply_theme = function(self, panel_widget)
	local ui = TaskPresentation.is_ui_theme()

	panel_widget.content.background = ui and TaskConstants.UI_PANEL_TEXTURE or TaskConstants.PANEL_TEXTURE

	local bg_color = ui and TaskConstants.UI_PANEL_BG_COLOR or TaskConstants.PANEL_BG_COLOR
	local style = panel_widget.style.background
	for i = 1, 4 do
		style.color[i] = bg_color[i]
	end
end

---@param dt number
---@param snapshot TaskSnapshot
---@param layout TaskLayout
HudTaskTrack._update_panel = function(self, dt, snapshot, layout)
	local panel_widget = self._widgets_by_name.task_panel
	if not panel_widget then
		return
	end

	local theme = TaskPresentation.theme()
	if theme ~= self._theme then
		self:_apply_theme(panel_widget)
		self._theme = theme
	end
	local ui = theme == "ui"

	local top_y, height = TaskPresentation.panel_layout()

	local style = panel_widget.style.background
	style.offset[1] = 0
	style.offset[2] = top_y
	style.size[1] = TaskConstants.PANEL_WIDTH
	style.size[2] = height

	local border = panel_widget.style.border
	border.offset[1] = 0
	border.offset[2] = top_y
	border.size[1] = TaskConstants.UI_BORDER_WIDTH
	border.size[2] = height
	border.color[1] = ui and TaskConstants.UI_BORDER_COLOR[1] or 0

	local target_alpha = snapshot.count > 0 and 1 or 0.5
	self._panel_alpha = self._panel_alpha
		+ (target_alpha - self._panel_alpha) * math_clamp(dt * TaskConstants.PANEL_FADE_SPEED, 0, 1)
	panel_widget.alpha_multiplier = self._panel_alpha

	self:_update_title(layout)
end

---@param layout TaskLayout
HudTaskTrack._update_title = function(self, layout)
	local title_widget = self._widgets_by_name.task_title
	if not title_widget then
		return
	end

	title_widget.content.title = TaskPresentation.title_text()

	local title_style = title_widget.style.title
	local color = TaskPresentation.title_color()
	for i = 1, 4 do
		title_style.text_color[i] = color[i]
	end
	title_style.offset[1] = layout.text_pad_x
	title_style.offset[2] = TaskPresentation.title_y()

	title_widget.alpha_multiplier = self._panel_alpha
end

---@param dt number
---@param task ActiveTask
---@return number slide_y, number enter_t
HudTaskTrack._resolve_slide = function(self, dt, task)
	local uid = task.uid
	local target_y = TaskPresentation.slot_y(task.slot)

	if self._task_slide_y[uid] == nil then
		self._task_slide_y[uid] = target_y
		self._task_enter_t[uid] = TaskConstants.ENTER_TIME
	end

	if self._task_enter_t[uid] > 0 then
		self._task_enter_t[uid] = math_max(0, self._task_enter_t[uid] - dt)
	end

	self._task_slide_y[uid] = self._task_slide_y[uid]
		+ (target_y - self._task_slide_y[uid]) * math_clamp(dt / math_max(TaskConstants.SLIDE_TIME, 0.001), 0, 1)

	self._task_seen[uid] = true
	return self._task_slide_y[uid], self._task_enter_t[uid]
end

---@param dt number
---@param t number -- absolute UI time (rumble/animation phase)
---@param task ActiveTask
---@param layout TaskLayout
---@param line_style table -- row 1 text style pass
---@param timer_style table -- row 2 text style pass
---@return string row1_text, string row2_text
HudTaskTrack._render_task = function(self, dt, t, task, layout, line_style, timer_style)
	local slide_y, enter_t = self:_resolve_slide(dt, task)

	local offset_x = layout.text_pad_x
	local offset_y = slide_y
	local alpha = 1
	local scale = 1
	local phase = task.phase
	local resolving = phase == "resolve_done" or phase == "resolve_fail"
	local exiting = phase == "exit"
	local finishing = resolving or exiting

	if finishing and task.rumble_pulse and task.rumble_pulse > 0 then
		local envelope = math_clamp(task.rumble_pulse / math_max(mod.constants.PULSE.T, 0.001), 0, 1)
		local rumble_x, rumble_y = mod.dl.animation.rumble(t, mod.constants.PULSE.AMP_HIGH * envelope)
		offset_x = offset_x + rumble_x
		offset_y = offset_y + rumble_y
	end

	local enter_progress = 1 - math_clamp(enter_t / math_max(TaskConstants.ENTER_TIME, 0.001), 0, 1)
	if enter_progress < 1 and not finishing then
		offset_x = offset_x
			+ layout.exit_slide_sign * TaskConstants.ENTER_OFFSET_X * (1 - mod.dl.animation.ease_out(enter_progress, 2))
		alpha = alpha * mod.dl.animation.ease_out(enter_progress, 2)
	end

	if finishing then
		scale = mod.dl.animation.pop_scale(task.phase_t, TaskConstants.STATUS_POP_TIME, TaskConstants.STATUS_POP_OVERSHOOT)

		if exiting then
			local exit_progress = math_clamp(task.phase_t / math_max(TaskConstants.EXIT_TIME, 0.001), 0, 1)
			offset_x = offset_x
				+ layout.exit_slide_sign * TaskConstants.EXIT_SLIDE * mod.dl.animation.ease_in(exit_progress, 2)
			alpha = alpha * (1 - exit_progress)
		end
	end

	local row1_text = TaskPresentation.row1(task, layout, task.status)
	set_text_pass(line_style, alpha, offset_x, offset_y, scale, TaskConstants.COLOR_LINE_BASE, TaskConstants.LINE_FONT_SIZE)

	local row2_y = offset_y + TaskConstants.TIMER_LINE_OFFSET_Y
	local row2_text

	if finishing then
		row2_text = TaskPresentation.row2_status(task)
		set_text_pass(
			timer_style,
			alpha,
			offset_x,
			row2_y,
			scale,
			TaskConstants.COLOR_LINE_BASE,
			TaskConstants.STATUS_FONT_SIZE
		)
	else
		row2_text = TaskPresentation.row2_progress(task, layout)
		set_text_pass(timer_style, alpha, offset_x, row2_y, 1, TaskConstants.COLOR_LINE_BASE, TaskConstants.TIMER_FONT_SIZE)
	end

	return row1_text, row2_text
end

---@param t number
---@return number rumble_x, number rumble_y
HudTaskTrack._on_hit_rumble_offset = function(self, t)
	local amplitude = Rumble.common_amp()
	if amplitude <= 0 then
		return 0, 0
	end

	return mod.dl.animation.rumble(t, amplitude)
end

---@param dt number
---@param t number
---@param ui_renderer table
---@param render_settings table
---@param input_service table
HudTaskTrack.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudTaskTrack.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	if not TaskPresentation.tasks_enabled() then
		return
	end

	local snapshot = TaskManager.snapshot()
	local layout = TaskPresentation.layout_side()

	local rumble_x, rumble_y = self:_on_hit_rumble_offset(t)
	self:_apply_side_layout(layout, rumble_x, rumble_y)
	self:_update_panel(dt, snapshot, layout)

	local rows_widget = self._widgets_by_name.task_rows
	rows_widget.alpha_multiplier = 1
	local styles = rows_widget.style
	local content = rows_widget.content

	for uid in pairs(self._task_seen) do
		self._task_seen[uid] = nil
	end

	for slot = 1, TaskConstants.MAX_SLOTS do
		local task = snapshot.tasks[slot]
		local line_style = styles["line_" .. slot]
		local timer_style = styles["timer_" .. slot]

		if task then
			local line_text, timer_text = self:_render_task(dt, t, task, layout, line_style, timer_style)
			content["line_" .. slot] = line_text
			content["timer_" .. slot] = timer_text
		else
			hide_text_pass(line_style)
			hide_text_pass(timer_style)
			content["line_" .. slot] = ""
			content["timer_" .. slot] = ""
		end
	end

	for uid in pairs(self._task_slide_y) do
		if not self._task_seen[uid] then
			self._task_slide_y[uid] = nil
			self._task_enter_t[uid] = nil
		end
	end
end

---@param dt number
---@param t number
---@param input_service table
---@param ui_renderer table
---@param render_settings table
HudTaskTrack._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	if not TaskPresentation.tasks_enabled() then
		return
	end

	HudTaskTrack.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudTaskTrack
