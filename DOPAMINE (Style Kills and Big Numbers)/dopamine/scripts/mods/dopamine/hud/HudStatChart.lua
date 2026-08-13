

---@type mod
local mod = get_mod("dopamine")

local StatsManager = mod:core(mod.stats_manager, "utils/stats/manager")
local StatChartPresentation = mod:core(mod.stat_chart_presentation, "hud/stat_chart/presentation")
local Rumble = mod:core(mod.rumble, "utils/rumble")
local Constants = mod:core(mod.constants, "hud/constants")
local StatChartConstants = mod:core(mod.stat_chart_constants, "hud/stat_chart/constants").PRESENTATION

local Definitions = mod:io_dofile("dopamine/scripts/mods/dopamine/hud/stat_chart/definitions")

local math_clamp = math.clamp
local math_floor = math.floor

---@class HudStatChart : HudElementBase
---@field _row_slide_y table<string, number> -- lerped row-top Y per account id
---@field _row_enter_t table<string, number> -- remaining enter time per account id
---@field _bar_frac table<string, number>    -- lerped bar fraction per account id
---@field _seen table<string, boolean>       -- account ids present this frame (cleanup pass)
---@field _panel_alpha number                -- eased panel/title alpha (0.5 idle .. 1 populated)
local HudStatChart = class("HudStatChart", "HudElementBase")

HudStatChart.init = function(self, parent, draw_layer, start_scale)
	HudStatChart.super.init(self, parent, draw_layer  + Constants.HUD_Z_BOOST, start_scale, {
		scenegraph_definition = Definitions.scenegraph_definition,
		widget_definitions = Definitions.widget_definitions,
	})

	self._row_slide_y = {}
	self._row_enter_t = {}
	self._bar_frac = {}
	self._seen = {}
	self._panel_alpha = 0
end

---@param style table -- a text style pass
local function hide_text_pass(style)
	style.text_color[1] = 0
end

---@param style table -- a text style pass (mutated in place)
---@param alpha number
---@param offset_x number
---@param offset_y number
---@param color argb_table
local function set_text_pass(style, alpha, offset_x, offset_y, color)
	style.text_color[1] = math_floor(255 * math_clamp(alpha, 0, 1))
	style.text_color[2] = color[2] or 255
	style.text_color[3] = color[3] or 255
	style.text_color[4] = color[4] or 255
	style.offset[1] = offset_x
	style.offset[2] = offset_y
end

---@param style table -- a rect style pass (mutated in place)
---@param alpha number -- 0..1 multiplier on the base alpha
---@param base_alpha number -- the pass's full-opacity alpha channel
---@param offset_x number
---@param offset_y number
---@param width number
---@param color argb_table
local function set_rect_pass(style, alpha, base_alpha, offset_x, offset_y, width, color)
	style.color[1] = math_floor(base_alpha * math_clamp(alpha, 0, 1))
	style.color[2] = color[2] or 255
	style.color[3] = color[3] or 255
	style.color[4] = color[4] or 255
	style.offset[1] = offset_x
	style.offset[2] = offset_y
	style.size[1] = width
	style.size[2] = StatChartConstants.BAR_HEIGHT
end

---@param layout StatChartLayout
---@param rumble_x number
---@param rumble_y number
HudStatChart._apply_side_layout = function(self, layout, rumble_x, rumble_y)
	self:set_scenegraph_position(
		"statChartRoot",
		layout.root_margin_x + rumble_x,
		layout.offset_y + rumble_y,
		19,
		layout.halign,
		layout.root_valign
	)

	local rows_widget = self._widgets_by_name.chart_rows
	if rows_widget then

		local value_text_halign = layout.left and "right" or "left"
		for row = 1, StatChartConstants.MAX_ROWS do
			StatChartPresentation.apply_text_align(rows_widget.style["name_" .. row], layout)
			StatChartPresentation.apply_panel_align(rows_widget.style["track_" .. row], layout)
			StatChartPresentation.apply_panel_align(rows_widget.style["fill_" .. row], layout)

			local value_style = rows_widget.style["value_" .. row]
			value_style.horizontal_alignment = layout.halign
			value_style.text_horizontal_alignment = value_text_halign
		end
	end

	local panel_widget = self._widgets_by_name.chart_panel
	if panel_widget then
		StatChartPresentation.apply_panel_align(panel_widget.style.background, layout)
		StatChartPresentation.apply_panel_texture_uv(panel_widget.style.background, layout)
		panel_widget.style.border.horizontal_alignment = layout.halign
	end

	local title_widget = self._widgets_by_name.chart_title
	if title_widget then
		StatChartPresentation.apply_text_align(title_widget.style.title, layout)
	end
end

---@param dt number
---@param snapshot StatChartSnapshot
---@param layout StatChartLayout
HudStatChart._update_panel = function(self, dt, snapshot, layout)
	local panel_widget = self._widgets_by_name.chart_panel
	if panel_widget then
		local top_y, height = StatChartPresentation.panel_layout()

		local style = panel_widget.style.background
		style.offset[1] = 0
		style.offset[2] = top_y
		style.size[1] = StatChartConstants.PANEL_WIDTH
		style.size[2] = height

		local border = panel_widget.style.border
		border.offset[1] = 0
		border.offset[2] = top_y
		border.size[1] = StatChartConstants.PANEL_BORDER_WIDTH
		border.size[2] = height
	end

	local target_alpha = snapshot.count > 0 and 1 or 0.5
	self._panel_alpha = self._panel_alpha
		+ (target_alpha - self._panel_alpha) * math_clamp(dt * StatChartConstants.PANEL_FADE_SPEED, 0, 1)

	if panel_widget then
		panel_widget.alpha_multiplier = self._panel_alpha
	end

	local title_widget = self._widgets_by_name.chart_title
	if title_widget then
		title_widget.content.title = StatChartPresentation.title_text()
		local title_style = title_widget.style.title
		title_style.offset[1] = layout.text_pad_x
		title_style.offset[2] = StatChartPresentation.title_y()
		title_style.text_color[1] = 255
		title_widget.alpha_multiplier = self._panel_alpha
	end
end

---@param dt number
---@param account_id string
---@param position integer -- 1 = top row
---@return number slide_y, number enter_t
HudStatChart._resolve_row = function(self, dt, account_id, position)
	local target_y = StatChartPresentation.row_top_y(position)

	if self._row_slide_y[account_id] == nil then
		self._row_slide_y[account_id] = target_y
		self._row_enter_t[account_id] = StatChartConstants.ENTER_TIME
		self._bar_frac[account_id] = 0
	end

	if self._row_enter_t[account_id] > 0 then
		self._row_enter_t[account_id] = math.max(0, self._row_enter_t[account_id] - dt)
	end

	self._row_slide_y[account_id] = self._row_slide_y[account_id]
		+ (target_y - self._row_slide_y[account_id]) * math_clamp(dt / math.max(StatChartConstants.SLIDE_TIME, 0.001), 0, 1)

	self._seen[account_id] = true
	return self._row_slide_y[account_id], self._row_enter_t[account_id]
end

---@param dt number
---@param entry StatAccount
---@param position integer
---@param snapshot StatChartSnapshot
---@param layout StatChartLayout
---@param styles table -- chart_rows style table
HudStatChart._render_row = function(self, dt, entry, position, snapshot, layout, styles)
	local account_id = entry.account_id
	local slide_y, enter_t = self:_resolve_row(dt, account_id, position)

	local enter_progress = 1 - math_clamp(enter_t / math.max(StatChartConstants.ENTER_TIME, 0.001), 0, 1)
	local alpha = mod.dl.animation.ease_out(enter_progress, 2)

	local target_frac = StatChartPresentation.bar_fraction(entry[snapshot.metric.id], snapshot.max_value)
	local frac = self._bar_frac[account_id] or 0
	frac = frac + (target_frac - frac) * math_clamp(dt * StatChartConstants.BAR_LERP_SPEED, 0, 1)
	self._bar_frac[account_id] = frac

	local fill_width = StatChartConstants.BAR_MAX_WIDTH * frac
	local bar_top = slide_y + StatChartConstants.BAR_OFFSET_Y

	local label_y = slide_y + StatChartConstants.NAME_OFFSET_Y

	local name_style = styles["name_" .. position]
	set_text_pass(name_style, alpha, layout.text_pad_x, label_y, StatChartConstants.NAME_COLOR)

	local value_style = styles["value_" .. position]
	value_style.size[1] = StatChartConstants.BAR_MAX_WIDTH
	set_text_pass(value_style, alpha, layout.text_pad_x, label_y, StatChartConstants.VALUE_COLOR)

	set_rect_pass(
		styles["track_" .. position],
		alpha,
		StatChartConstants.BAR_BG_ALPHA,
		layout.text_pad_x,
		bar_top,
		StatChartConstants.BAR_MAX_WIDTH,
		StatChartConstants.BAR_TRACK_COLOR
	)
	set_rect_pass(
		styles["fill_" .. position],
		alpha,
		175,
		layout.text_pad_x,
		bar_top,
		fill_width,
		StatChartPresentation.bar_color()
	)

	return entry.name or "", StatChartPresentation.format_value(entry[snapshot.metric.id])
end

---@param position integer
---@param styles table
HudStatChart._hide_row = function(self, position, styles)
	hide_text_pass(styles["name_" .. position])
	hide_text_pass(styles["value_" .. position])
	styles["track_" .. position].color[1] = 0
	styles["fill_" .. position].color[1] = 0
end

---@param t number
---@return number rumble_x, number rumble_y
HudStatChart._rumble_offset = function(self, t)
	local amplitude = Rumble.common_amp()
	if amplitude <= 0 then
		return 0, 0
	end
	return mod.dl.animation.rumble(t, amplitude / 1.5)
end

HudStatChart.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudStatChart.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	if not StatChartPresentation.chart_enabled() then
		return
	end

	local snapshot = StatsManager.snapshot()
	local layout = StatChartPresentation.layout_side()

	local rumble_x, rumble_y = self:_rumble_offset(t)
	self:_apply_side_layout(layout, rumble_x, rumble_y)
	self:_update_panel(dt, snapshot, layout)

	local rows_widget = self._widgets_by_name.chart_rows
	rows_widget.alpha_multiplier = 1
	local styles = rows_widget.style
	local content = rows_widget.content

	for id in pairs(self._seen) do
		self._seen[id] = nil
	end

	for position = 1, StatChartConstants.MAX_ROWS do
		local entry = snapshot.entries[position]
		if entry then
			local name_text, value_text = self:_render_row(dt, entry, position, snapshot, layout, styles)
			content["name_" .. position] = name_text
			content["value_" .. position] = value_text
		else
			self:_hide_row(position, styles)
			content["name_" .. position] = ""
			content["value_" .. position] = ""
		end
	end

	for id in pairs(self._row_slide_y) do
		if not self._seen[id] then
			self._row_slide_y[id] = nil
			self._row_enter_t[id] = nil
			self._bar_frac[id] = nil
		end
	end
end

HudStatChart._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	if not StatChartPresentation.chart_enabled() then
		return
	end

	HudStatChart.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudStatChart
