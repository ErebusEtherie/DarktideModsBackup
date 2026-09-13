

---@type mod
local mod = get_mod("dopamine")

require("scripts/ui/view_elements/view_element_base")

local Text = require("scripts/utilities/ui/text")

local Manager = mod:core(mod.mission_summary_manager, "utils/mission_summary/manager")
local Presentation = mod:core(mod.mission_summary_presentation, "hud/mission_summary/presentation")
local C = mod:core(mod.mission_summary_constants, "hud/mission_summary/constants")

local Definitions = mod:io_dofile("dopamine/scripts/mods/dopamine/hud/mission_summary/definitions")

local math_floor = math.floor
local math_min = math.min
local math_max = math.max

---@param v number
local function clamp01(v)
	return math_max(0, math_min(1, v or 0))
end

---@param rect table screen-px rect
local function point_in(rect, x, y)
	return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

---@param style table text pass style
---@param color argb_table
---@param alpha number|nil
local function set_text_color(style, color, alpha)
	style.text_color[1] = math_floor(color[1] * (alpha or 1) + 0.5)
	style.text_color[2] = color[2]
	style.text_color[3] = color[3]
	style.text_color[4] = color[4]
end

---@param widget table
---@param value_id string
---@param text string
---@param color argb_table|nil
---@param alpha number|nil
local function set_text(widget, value_id, text, color, alpha)
	widget.content[value_id] = text or ""
	if color then
		set_text_color(widget.style[value_id], color, alpha)
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

---@param color argb_table
---@param amount number
---@return argb_table
local function darken(color, amount)
	local keep = 1 - amount
	return {
		color[1],
		math_floor(color[2] * keep + 0.5),
		math_floor(color[3] * keep + 0.5),
		math_floor(color[4] * keep + 0.5),
	}
end

---@param values table|nil
---@param row table
local function run_text(values, row)
	if not values then
		return ""
	end
	if row.is_time then
		return Presentation.format_time(values.time)
	end
	if row.is_date then
		return Presentation.format_date(values.timestamp)
	end
	if row.is_secrets then
		return Presentation.secrets_text(values.idols_found, values.skulls_found)
	end
	return Presentation.format_stat(values[row.id])
end

---@param values table|nil
---@param row table
local function magnitude_text(values, row)
	if not values then
		return ""
	end
	local pool
	if row.pool == "total" then
		pool = (values.regular_health or 0)
			+ (values.elite_health or 0)
			+ (values.special_health or 0)
			+ (values.boss_max_health or 0)
	elseif row.pool then
		pool = values[row.pool] or 0
	end
	return Presentation.format_magnitude(values[row.id], pool)
end

---@param values table
---@param id string
---@return number
local function event_count(values, id)
	local counts = values.event_counts
	return counts and counts[id] or 0
end

---@param values table|nil
---@param row table
local function event_text(values, row)
	if not values then
		return ""
	end

	if row.combine then
		local a = event_count(values, row.combine[1])
		local b = event_count(values, row.combine[2])
		return Presentation.format_stat(a) .. "/" .. Presentation.format_stat(b)
	end

	if row.combine_stat_time then
		local c = row.combine_stat_time
		local objectives = values[c.stat] or 0
		local seconds = event_count(values, c.time_event)
		return Presentation.format_stat(objectives) .. "/" .. Presentation.format_time(seconds)
	end

	if row.is_coherency_pct then
		local time = values.time or 0
		local pct = time > 0 and (values.coherency_time or 0) / time or 0
		return math_floor(pct * 100 + 0.5) .. "%"
	end

	local n
	if row.stat then
		n = values[row.id]
	else
		n = event_count(values, row.id)
	end
	if row.is_time then
		return Presentation.format_time(n)
	end
	if row.is_percent then

		return math_floor((n or 0) * 100 + 0.5) .. "%"
	end
	return Presentation.format_stat(n)
end

local FIELD_CATEGORY = {

	kills = "violence",
	damage = "violence",
	boss_damage = "violence",
	elite_damage = "violence",
	special_damage = "violence",
	regular_damage = "violence",
	boss_kills = "violence",
	elite_kills = "violence",
	special_kills = "violence",
	regular_kills = "violence",

	objectives = "unity",
	rescues = "unity",
	stims = "unity",
	coherency_time = "unity",

	health_lost = "finesse",
	downs = "finesse",

	style_points = "style",
	best_combo = "style",
}

local FLOAT_FIELDS = {
	health_lost = true,
}

local BLOCK_CATEGORY = {
	victims = "violence",
	magnitude = "violence",
	method = "style",
	style = "style",
	competence = "finesse",
	team = "unity",
}

---@param intro table|nil
---@param cat string
---@return boolean
local function category_lerp_paused(intro, cat)
	if not intro or not intro.active then
		return false
	end
	return intro.paused_cat == cat
end

---@param intro table|nil
---@param cat string
---@return boolean
local function category_lerping(intro, cat)
	if not intro or not intro.active then
		return false
	end
	local p = intro.progress[cat]
	return p ~= nil and p > 0 and p < 1
end

local function post_mission_colors(intro, cat)
	if not intro or intro == nil then
		return C.COLOR.LABEL, C.COLOR.VALUE
	end
	local playing = intro.active and intro.playing
	local active_or_finished = (category_lerping(intro, cat) or category_lerp_paused(intro, cat))
	return (playing and (active_or_finished and C.COLOR.LABEL_ACTIVE_RECAP or C.COLOR.INACTIVE_RECAP) or C.COLOR.LABEL),
		(playing and (active_or_finished and C.COLOR.VALUE_ACTIVE_RECAP or C.COLOR.INACTIVE_RECAP) or C.COLOR.VALUE)
end

local EVENT_CATEGORY = {}
do
	for i = 1, #C.VICTIMS_EVENTS do
		EVENT_CATEGORY[C.VICTIMS_EVENTS[i].id] = "violence"
	end
	for i = 1, #C.METHOD_EVENTS do
		local row = C.METHOD_EVENTS[i]
		if row.combine then
			for j = 1, #row.combine do
				EVENT_CATEGORY[row.combine[j]] = "style"
			end
		else
			EVENT_CATEGORY[row.id] = "style"
		end
	end
	for i = 1, #C.STYLE_EVENTS do
		local row = C.STYLE_EVENTS[i]
		if not row.stat then
			EVENT_CATEGORY[row.id] = "style"
		end
	end
	EVENT_CATEGORY.objective_time = "unity"
end

---@param t number  raw 0..1
---@param in_frac number   share of the duration spent easing in
---@param out_frac number  share spent easing out
---@return number
local function ease_trapezoid(t, in_frac, out_frac)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local mid = 1 - in_frac - out_frac
	local v = 1 / (mid + (in_frac + out_frac) * 0.5)
	if in_frac > 0 and t < in_frac then

		return v * t * t / (2 * in_frac)
	end
	local p_in = v * in_frac * 0.5 
	if t <= in_frac + mid then

		return p_in + v * (t - in_frac)
	end

	local s = t - (in_frac + mid)
	return p_in + v * mid + v * (s - s * s / (2 * out_frac))
end

---@param remaining number|nil  seconds left in the shake
---@param clock number          a rising time value driving the rumble
---@return number dx, number dy
local function shake_offset(remaining, clock)
	if not remaining or remaining <= 0 then
		return 0, 0
	end
	local envelope = remaining / math_max(C.RANK_SETTLE_SHAKE_T, 0.0001)
	return mod.dl.animation.rumble(clock, C.RANK_SETTLE_SHAKE * envelope)
end

local MissionSummaryElement = class("DopamineMissionSummaryElement@" .. tostring({}), "ViewElementBase")

MissionSummaryElement.init = function(self, parent, draw_layer, start_scale, context)
	self._definitions = Definitions
	MissionSummaryElement.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = self._definitions.scenegraph_definition,
		widget_definitions = self._definitions.widget_definitions,
	})

	self._geo = Presentation.geometry()
	self._hover_row = nil
	self._hover_button = false
	self._hover_mission = nil

	self._has_level = false
	self._level_progress = 0
	self._ui_renderer = nil

	self._intro_key = nil
	self._intro_elapsed = nil
	self._cat_settled = {}
	self._cat_shake = {}
	self._composite_settled = false
	self._composite_shake = 0

	self._big_base_offset = {}

	self._hell_yeah_alpha = 0
	self._hover_hell_yeah = false

	self._hell_yeah_shadow_t = 0

	self._hover_delete = false

	self._skip_alpha = 0
	self._hover_skip = false
	self._skip_recap_requested = false
end

---@return number left, number top, number scale
MissionSummaryElement._panel_screen_frame = function(self)
	local width = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
	local height = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080
	local scale = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale) or 1

	local left = width * 0.5 + C.PANEL_OFFSET_X * scale - C.PANEL_WIDTH * scale * 0.5
	local top = height * 0.5 + C.PANEL_OFFSET_Y * scale - C.PANEL_HEIGHT * scale * 0.5
	return left, top, scale
end

MissionSummaryElement._screen_rect = function(self, rect, left, top, scale)
	return { x = left + rect.x * scale, y = top + rect.y * scale, w = rect.w * scale, h = rect.h * scale }
end

---@param snapshot MissionSummarySnapshot
---@param input_service any
---@param lerping boolean
---@param show_hell_yeah boolean
---@param show_skip boolean  the "skip recap" button is up (the recap is still counting up)
MissionSummaryElement._update_interaction = function(self, snapshot, input_service, lerping, show_hell_yeah, show_skip)
	self._hover_row = nil
	self._hover_button = false
	self._hover_mission = nil
	self._hover_hell_yeah = false
	self._hover_delete = false
	self._hover_skip = false

	local cursor = input_service and input_service:get("cursor")
	if not cursor then
		return
	end

	local left, top, scale = self:_panel_screen_frame()
	local cx, cy = cursor[1], cursor[2]
	local pressed = input_service:get("left_pressed")

	if show_skip then
		local rect = self:_screen_rect(self._geo.skip_recap, left, top, scale)
		if point_in(rect, cx, cy) then
			self._hover_skip = true
			if pressed then
				self:_skip_recap()
			end
			return
		end
	end

	if show_hell_yeah then
		local rect = self:_screen_rect(self._geo.hell_yeah, left, top, scale)
		if point_in(rect, cx, cy) then
			self._hover_hell_yeah = true
			if pressed then
				Manager.close()
			end
			return
		end
	end

	if snapshot.can_delete_run and not lerping then
		local rect = self:_screen_rect(self._geo.delete_run, left, top, scale)
		if point_in(rect, cx, cy) then
			self._hover_delete = true
			if pressed then
				Manager.delete_selected_run()
			end
			return
		end
	end

	if snapshot.browse then
		local count = math_min(#snapshot.mission_list, C.MAX_MISSION_TILES)
		for i = 1, count do
			local rect = self:_screen_rect(Presentation.mission_tile_panel(i), left, top, scale)
			if point_in(rect, cx, cy) then
				self._hover_mission = i
				if pressed then
					Manager.select_mission(snapshot.mission_list[i].id)
				end
				return
			end
		end
	end

	local rows = snapshot.rows or {}
	for i = 1, C.HIGHSCORE_SLOTS do
		local row = rows[i]
		if not lerping and row and row.selectable and row.lb_index then
			local rect = self:_screen_rect(Presentation.highscore_row_panel(i), left, top, scale)
			if point_in(rect, cx, cy) then
				self._hover_row = i
				if pressed then
					Manager.select_entry(row.lb_index)
				end
				return
			end
		end
	end

	if snapshot.can_show_live then
		local rect = self:_screen_rect(self._geo.live_button, left, top, scale)
		if point_in(rect, cx, cy) then
			self._hover_button = true
			if pressed then
				Manager.show_live()
			end
		end
	end
end

---@param snapshot MissionSummarySnapshot
MissionSummaryElement._refresh_header = function(self, snapshot)
	local header = self._widgets_by_name.header

	local title = snapshot.level_name or mod:localize("mission_summary_not_in_mission")
	set_text(header, "mission_name", title, C.COLOR.TITLE)

	local level = snapshot.level
	self._has_level = level ~= nil
	self._level_progress = level and level.progress or 0
	if level then
		set_text(header, "progress_points", Presentation.format_points(level.points), C.COLOR.VALUE)
		set_text(header, "progress_rank", level.label, level.color)
		set_text(header, "progress_next", level.next_label, C.COLOR.PROGRESS_NEXT)
		set_text(header, "progress_points_next", Presentation.format_points(level.next_min), C.COLOR.PROGRESS_NEXT)
	else
		set_text(header, "progress_points", "", C.COLOR.VALUE)
		set_text(header, "progress_rank", "", C.COLOR.WHITE)
		set_text(header, "progress_next", "", C.COLOR.PROGRESS_NEXT)
		set_text(header, "progress_points_next", "", C.COLOR.PROGRESS_NEXT)
	end
end

---@param ui_renderer table
---@param header table the header widget
---@param id string pass id
---@return number width
MissionSummaryElement._header_text_w = function(self, ui_renderer, header, id)
	local text = header.content[id]
	if not text or text == "" then
		return 0
	end
	local width = Text.text_size(ui_renderer, text, header.style[id], { self._geo.header.w, C.HEADER_H }, true)
	return width or 0
end

---@param ui_renderer table
MissionSummaryElement._layout_header = function(self, ui_renderer)
	local header = self._widgets_by_name.header
	local style = header.style
	local header_w = self._geo.header.w
	local gap = C.PROGRESS_GAP

	local name_w = self:_header_text_w(ui_renderer, header, "mission_name")
	local x = name_w + (name_w > 0 and C.HEADER_NAME_GAP or 0)

	if not self._has_level then

		style.progress_bar_bg.size[1] = 0
		style.progress_fill.size[1] = 0
		return
	end

	local points_w = self:_header_text_w(ui_renderer, header, "progress_points")
	style.progress_points.offset[1] = x
	style.progress_points.size[1] = header_w - x
	x = x + points_w + gap

	local rank_w = self:_header_text_w(ui_renderer, header, "progress_rank")
	style.progress_rank.offset[1] = x
	style.progress_rank.size[1] = header_w - x
	x = x + rank_w + gap

	local next_points_w = self:_header_text_w(ui_renderer, header, "progress_points_next")
	style.progress_points_next.offset[1] = 0
	style.progress_points_next.size[1] = header_w

	local next_w = self:_header_text_w(ui_renderer, header, "progress_next")
	local next_right = header_w - next_points_w - (next_points_w > 0 and gap or 0)
	style.progress_next.offset[1] = 0
	style.progress_next.size[1] = next_right

	local bar_x = x
	local bar_w = math_max(0, (next_right - next_w - gap) - bar_x)
	style.progress_bar_bg.offset[1] = bar_x
	style.progress_bar_bg.size[1] = bar_w
	style.progress_fill.offset[1] = bar_x
	style.progress_fill.size[1] = bar_w * clamp01(self._level_progress)
end

---@param ui_renderer table
MissionSummaryElement._layout_skip_recap = function(self, ui_renderer)
	local widget = self._widgets_by_name.skip_recap
	local box_w = self._geo.skip_recap.w
	local style = widget.style

	local label = widget.content.skip_text
	local text_w = 0
	if label and label ~= "" then
		text_w = Text.text_size(ui_renderer, label, style.skip_text, { box_w, C.HELL_YEAH_BUTTON_H }, true) or 0
	end

	local total = text_w + C.SKIP_RECAP_ICON_GAP + C.SKIP_RECAP_ICON_SIZE
	local start_x = math_max(0, (box_w - total) * 0.5)
	style.skip_text.offset[1] = start_x
	style.skip_text.size[1] = box_w - start_x
	style.skip_icon.offset[1] = start_x + text_w + C.SKIP_RECAP_ICON_GAP
end

---@param snapshot MissionSummarySnapshot
---@param empty boolean
MissionSummaryElement._refresh_run = function(self, snapshot, empty)
	local run = self._widgets_by_name.run
	local values = snapshot.values
	for i = 1, #C.RUN_ROWS do
		local row = C.RUN_ROWS[i]
		set_text(run, "run_v_" .. row.id, (empty and "") or run_text(values, row), C.COLOR.VALUE)
	end
end

---@param factors MissionFactors
---@param progress table<string, number>
---@return string letter, argb_table color
MissionSummaryElement._lerped_composite = function(self, factors, progress)
	local function letter_of(cat)
		local letter = Presentation.category_rank_at(cat, factors[cat], progress[cat] or 1)
		return letter
	end
	local lerped = {
		violence = { letter = letter_of("violence") },
		unity = { letter = letter_of("unity") },
		finesse = { letter = letter_of("finesse") },
		style = { letter = letter_of("style") },
	}
	return Presentation.composite_rank(lerped)
end

---@param snapshot MissionSummarySnapshot
---@param empty boolean
---@param intro table|nil
MissionSummaryElement._refresh_big = function(self, snapshot, empty, intro)
	local big = self._widgets_by_name.big_stats
	local rank_box = self._widgets_by_name.rank_box
	local factors = snapshot.factors
	local active = intro ~= nil and intro.active
	local clock = self._intro_elapsed or 0

	for i = 1, #C.BIG_ROWS do
		local row = C.BIG_ROWS[i]
		local id = "big_v_" .. row.id
		local factor = factors and factors[row.id]
		local row_lerping = category_lerping(intro, row.id)

		local style = big.style[id]
		local base = self._big_base_offset[id]
		if not base then
			base = { style.offset[1], style.offset[2] }
			self._big_base_offset[id] = base
		end

		local dx, dy = 0, 0
		local progress = active and (intro.progress[row.id] or 1) or nil
		if empty or not factor then
			set_text(big, id, "", C.COLOR.VALUE)
		elseif progress == 0 then

			set_text_color(big.style["big_l_" .. row.id], C.COLOR.INACTIVE_RECAP)
			set_text(big, id, "-", C.COLOR.INACTIVE_RECAP)
		else
			local letter, color, amount = factor.letter, factor.color, factor.amount
			if active then
				letter, color, amount = Presentation.category_rank_at(row.id, factor, progress)
				dx, dy = shake_offset(self._cat_shake[row.id], clock)
			end
			if row.id ~= "style" then
				set_text_color(big.style["big_l_" .. row.id], color)
			elseif row.id == "style" then
				set_text_color(big.style["big_l_" .. row.id], C.COLOR.VALUE)
			end
			if row.kind == "rank" then
				set_text(big, id, letter or "", color or C.COLOR.VALUE)
			else

				set_text(big, id, Presentation.format_points(amount or 0), C.COLOR.VALUE)
			end
		end
		style.offset[1] = base[1] + dx
		style.offset[2] = base[2] + dy

		local base_value_size = (row.kind == "rank") and C.FONT_SIZE.big_value_rank or C.FONT_SIZE.big_value

		style.font_size = row_lerping and C.FONT_SIZE.big_value_active or base_value_size
		big.style["big_l_" .. row.id].font_size = row_lerping and C.FONT_SIZE.big_label_active or C.FONT_SIZE.big_label
	end

	if empty or not factors then
		self:_refresh_rank_glyphs(rank_box, "", C.COLOR.MUTED, 0, 0)
		return
	end

	local letter, color
	if active then
		letter, color = self:_lerped_composite(factors, intro.progress)
	else
		letter, color = snapshot.rank_letter, snapshot.rank_color
	end
	local sx, sy = shake_offset(self._composite_shake, clock)
	self:_refresh_rank_glyphs(rank_box, letter or "", color or C.COLOR.WHITE, sx, sy)
end

---@param snapshot MissionSummarySnapshot
---@param empty boolean
---@param intro table|nil
MissionSummaryElement._refresh_magnitude = function(self, snapshot, empty, intro)
	local widget = self._widgets_by_name.magnitude
	local values = snapshot.values
	local label_color, value_color = post_mission_colors(intro, "violence")
	for i = 1, #C.MAGNITUDE_ROWS do
		local row = C.MAGNITUDE_ROWS[i]
		set_text_color(widget.style["mag_l_" .. row.id], label_color)
		set_text(widget, "mag_v_" .. row.id, (empty and "") or magnitude_text(values, row), value_color)
	end
end

---@param snapshot MissionSummarySnapshot
---@param empty boolean
---@param intro table|nil
MissionSummaryElement._refresh_events = function(self, snapshot, empty, intro)
	local values = snapshot.values
	self:_fill_event_list("victims", C.VICTIMS_EVENTS, values, empty, intro)
	self:_fill_event_list("method", C.METHOD_EVENTS, values, empty, intro)
	self:_fill_event_list("style", C.STYLE_EVENTS, values, empty, intro)
	self:_fill_event_list("competence", C.COMPETENCE_EVENTS, values, empty, intro)
	self:_fill_event_list("team", C.TEAM_EVENTS, values, empty, intro)
end

---@param name string
---@param rows table[]
---@param values table|nil
---@param empty boolean
---@param intro table|nil
MissionSummaryElement._fill_event_list = function(self, name, rows, values, empty, intro)
	local widget = self._widgets_by_name[name]
	local label_color, value_color = post_mission_colors(intro, BLOCK_CATEGORY[name])

	for i = 1, #rows do
		set_text(widget, name .. "_v_" .. i, (empty and "") or event_text(values, rows[i]), value_color)
		set_text_color(widget.style[name .. "_l_" .. i], label_color)
	end
end

---@param rank_box table
---@param text string
---@param color argb_table
---@param shake_x number|nil  horizontal rumble offset (px) applied to every glyph; 0/nil = none
---@param shake_y number|nil  vertical rumble offset (px) applied to every glyph; 0/nil = none
MissionSummaryElement._refresh_rank_glyphs = function(self, rank_box, text, color, shake_x, shake_y)
	local len = math_min(#text, C.RANK_MAX_GLYPHS)
	local step = C.RANK_OVERLAP_X
	shake_x = shake_x or 0
	shake_y = shake_y or 0

	for i = 1, C.RANK_MAX_GLYPHS do
		local id = "rank_letter_" .. i
		local shadow_id = "rank_shadow_" .. i
		if i <= len then
			local offset_x = (i - (len + 1) * 0.5) * step
			local glyph = string.sub(text, i, i)
			rank_box.style[id].offset[1] = offset_x + shake_x
			rank_box.style[id].offset[2] = shake_y
			rank_box.style[shadow_id].offset[1] = offset_x - 2 + shake_x
			rank_box.style[shadow_id].offset[2] = 1 + shake_y
			set_text(rank_box, id, glyph, color)
			set_text(rank_box, shadow_id, glyph)
		else
			set_text(rank_box, id, "", color)
			set_text(rank_box, shadow_id, "")
		end
	end
end

---@param widget table
---@param i integer
MissionSummaryElement._blank_highscore_row = function(self, widget, i)
	set_rect_color(widget.style["hs_bg_" .. i], C.COLOR.ROW_BG_EMPTY)
	set_text(widget, "hs_icon_" .. i, "")
	set_text(widget, "hs_rank_" .. i, "")
	set_text(widget, "hs_points_" .. i, "")
	set_text(widget, "hs_diff_" .. i, "")
	set_text(widget, "hs_date_" .. i, "")
end

---@param snapshot MissionSummarySnapshot
MissionSummaryElement._refresh_highscores = function(self, snapshot)
	local widget = self._widgets_by_name.highscores
	local rows = snapshot.rows or {}

	for i = 1, C.HIGHSCORE_SLOTS do
		local row = rows[i]

		set_text(widget, "hs_dots_" .. i, "")

		if not row then
			self:_blank_highscore_row(widget, i)
		elseif row.kind == "ellipsis" then
			self:_blank_highscore_row(widget, i)
			set_text(widget, "hs_dots_" .. i, "...", C.COLOR.ROW_DIFFICULTY)
		else
			local entry = row.entry
			local bg = C.COLOR.ROW_BG
			if row.gold then
				bg = C.COLOR.ROW_BG_SELECTED
			elseif row.selectable and self._hover_row == i then
				bg = C.COLOR.ROW_BG_HOVER
			end
			set_rect_color(widget.style["hs_bg_" .. i], bg)

			local letter = row.rank_letter or Presentation.rank_for_sp(entry.sp)
			local rank_color = row.rank_color or C.COLOR.ROW_TEXT

			local diff = Presentation.difficulty_display(entry)
			local won = entry.won ~= nil and (entry.won == 1 or entry.won == true) or false

			set_text(
				widget,
				"hs_icon_" .. i,
				Presentation.class_icon(entry.archetype),
				won and C.COLOR.WIN or C.COLOR.LOSS
			)
			set_text(widget, "hs_rank_" .. i, letter, rank_color)
			set_text(widget, "hs_points_" .. i, Presentation.format_points(entry.sp), C.COLOR.ROW_TEXT)

			set_text(widget, "hs_diff_" .. i, diff, C.COLOR.ROW_DIFFICULTY)

			if row.badge then
				set_text(widget, "hs_date_" .. i, row.badge, row.badge_color or C.COLOR.ROW_TEXT)
			else
				set_text(
					widget,
					"hs_date_" .. i,
					Presentation.format_date_short(entry.timestamp),
					C.COLOR.ROW_DIFFICULTY
				)
			end
		end
	end
end

---@param snapshot MissionSummarySnapshot
MissionSummaryElement._refresh_mission_grid = function(self, snapshot)
	local grid = self._widgets_by_name.mission_grid
	local show = snapshot.browse
	local list = snapshot.mission_list
	local tile_w = self._geo.mission_tile_w

	for i = 1, C.MAX_MISSION_TILES do
		local entry = show and list[i] or nil
		if entry then
			local bg = snapshot.selected_mission_id == entry.id and C.COLOR.ROW_BG_SELECTED
				or (self._hover_mission == i and C.COLOR.ROW_BG_HOVER or C.COLOR.ROW_BG)
			set_rect_color(grid.style["tile_bg_" .. i], bg)

			local level = entry.level
			grid.style["tile_fill_" .. i].size[1] = tile_w * clamp01(level and level.progress)
			set_text(grid, "tile_name_" .. i, entry.display, C.COLOR.ROW_TEXT)
			set_text(grid, "tile_level_" .. i, level and level.label or "", (level and level.color) or C.COLOR.WHITE)
		else
			set_rect_color(grid.style["tile_bg_" .. i], { 0, 0, 0, 0 })
			grid.style["tile_fill_" .. i].size[1] = 0
			set_text(grid, "tile_name_" .. i, "")
			set_text(grid, "tile_level_" .. i, "")
		end
	end
end

---@param snapshot MissionSummarySnapshot
MissionSummaryElement._refresh_live_button = function(self, snapshot)
	local button = self._widgets_by_name.live_button
	if snapshot.can_show_live then
		local bg = self._hover_button and C.COLOR.BUTTON_BG_HOVER or C.COLOR.BUTTON_LIVE_MISSION_BG
		set_rect_color(button.style.button_bg, bg)
		set_text_color(button.style.button_text, C.COLOR.BUTTON_TEXT)
	else
		set_rect_color(button.style.button_bg, { 0, 0, 0, 0 })
		set_text_color(button.style.button_text, C.COLOR.BUTTON_TEXT, 0)
	end
end

---@param show boolean
MissionSummaryElement._refresh_delete_run = function(self, show)
	local button = self._widgets_by_name.delete_run
	if not show then
		set_rect_color(button.style.del_bg, { 0, 0, 0, 0 })
		set_text_color(button.style.del_text, C.COLOR.DELETE_RUN_TEXT, 0)
		return
	end
	local bg = self._hover_delete and C.COLOR.DELETE_RUN_BG_HOVER or C.COLOR.DELETE_RUN_BG
	set_rect_color(button.style.del_bg, bg)
	set_text_color(button.style.del_text, C.COLOR.DELETE_RUN_TEXT)
end

---@param alpha number  0..1 fade
---@param rank_color argb_table|nil  the run's rank color; falls back to the standard gold
MissionSummaryElement._refresh_hell_yeah = function(self, alpha, rank_color)
	local button = self._widgets_by_name.hell_yeah
	if alpha <= 0 then
		set_rect_color(button.style.hy_bg, { 0, 0, 0, 0 })
		set_rect_color(button.style.hy_bg_shadow, { 0, 0, 0, 0 })
		set_text_color(button.style.hy_text, C.COLOR.HELL_YEAH_TEXT, 0)
		return
	end
	local base = rank_color or C.COLOR.HELL_YEAH_BG
	if self._hover_hell_yeah then
		base = darken(base, 0.15)
	end

	local shadow_off = C.HELL_YEAH_SHADOW_MIN
		+ 1
		+ (C.HELL_YEAH_SHADOW_MAX - C.HELL_YEAH_SHADOW_MIN) * self._hell_yeah_shadow_t
	button.style.hy_bg_shadow.offset[1] = shadow_off
	button.style.hy_bg_shadow.offset[2] = shadow_off

	set_rect_color(button.style.hy_bg_shadow, { math_floor(C.COLOR.HELL_YEAH_SHADOW[1] * alpha + 0.5), 0, 0, 0 })
	set_rect_color(button.style.hy_bg, { math_floor(base[1] * alpha + 0.5), base[2], base[3], base[4] })
	local luminance = 0.3 * base[2] + 0.5 * base[3] + 0.1 * base[4]
	local text_color = (luminance > 140) and C.COLOR.HELL_YEAH_TEXT or C.COLOR.WHITE
	set_text_color(button.style.hy_text, text_color, alpha)
end

---@param alpha number  0..1 fade
MissionSummaryElement._refresh_skip_recap = function(self, alpha)
	local button = self._widgets_by_name.skip_recap
	if alpha <= 0 then
		set_rect_color(button.style.skip_bg, { 0, 0, 0, 0 })
		set_text_color(button.style.skip_text, C.COLOR.SKIP_RECAP_TEXT, 0)
		set_rect_color(button.style.skip_icon, { 0, 0, 0, 0 })
		return
	end
	local bg = self._hover_skip and C.COLOR.SKIP_RECAP_BG_HOVER or C.COLOR.SKIP_RECAP_BG
	set_rect_color(button.style.skip_bg, { math_floor(bg[1] * alpha + 0.5), bg[2], bg[3], bg[4] })
	set_text_color(button.style.skip_text, C.COLOR.SKIP_RECAP_TEXT, alpha)

	local ic = C.COLOR.SKIP_RECAP_TEXT
	set_rect_color(button.style.skip_icon, { math_floor(ic[1] * alpha + 0.5), ic[2], ic[3], ic[4] })
end

---@class MissionRecapState
---@field active boolean                       -- there is a recap to animate
---@field playing boolean                      -- values are still moving (before the sequence ends)
---@field settled boolean                      -- the whole sequence has finished
---@field progress table<string, number>       -- per-category eased 0..1
---@field paused_cat string|nil                 -- the category in its post-lerp pause this frame, if any

MissionSummaryElement._skip_recap = function(self)
	self._skip_recap_requested = true
	for i = 1, #C.INTRO_CATEGORY_ORDER do
		self._cat_settled[C.INTRO_CATEGORY_ORDER[i]] = true
	end
	self._composite_settled = true
end

---@param snapshot MissionSummarySnapshot
---@param dt number
---@return MissionRecapState
MissionSummaryElement._intro_advance = function(self, snapshot, dt)
	local key = snapshot.intro
	if key ~= self._intro_key then
		self._intro_key = key
		self._intro_elapsed = key and 0 or nil
		self._cat_settled = {}
		self._cat_shake = {}
		self._composite_settled = false
		self._composite_shake = 0
		self._skip_recap_requested = false

		if key and mod.dl.settings.skip_mission_recap then
			self:_skip_recap()
		end
	end

	if not key then
		return { active = false, playing = false, settled = true, progress = {} }
	end

	local order = C.INTRO_CATEGORY_ORDER

	local lerp = math_max(C.CATEGORY_LERP, 0.0001)
	local pause = math_max(C.CATEGORY_PAUSE, 0)
	local stagger = lerp + pause

	local total = (#order - 1) * stagger + lerp

	if self._skip_recap_requested then

		self._intro_elapsed = total + C.RANK_SETTLE_SHAKE_T
	else
		self._intro_elapsed = math_min(total + C.RANK_SETTLE_SHAKE_T, (self._intro_elapsed or 0) + dt)
	end
	local elapsed = self._intro_elapsed

	local progress = {}
	for i = 1, #order do
		local cat = order[i]
		local start = (i - 1) * stagger
		local raw = clamp01((elapsed - start) / lerp)

		local in_frac = (i == 1) and C.INTRO_EASE_IN_FRAC_FIRST or C.INTRO_EASE_IN_FRAC
		progress[cat] = ease_trapezoid(raw, in_frac, C.INTRO_EASE_OUT_FRAC)

		if raw >= 1 and not self._cat_settled[cat] then
			self._cat_settled[cat] = true
			self._cat_shake[cat] = C.RANK_SETTLE_SHAKE_T
			if i == #order and not self._composite_settled then
				self._composite_settled = true
				self._composite_shake = C.RANK_SETTLE_SHAKE_T
			end
		end
	end

	for cat, remaining in pairs(self._cat_shake) do
		if remaining > 0 then
			self._cat_shake[cat] = math_max(0, remaining - dt)
		end
	end
	if self._composite_shake > 0 then
		self._composite_shake = math_max(0, self._composite_shake - dt)
	end

	local current_i = math_min(#order, math_floor(elapsed / stagger) + 1)
	local local_t = elapsed - (current_i - 1) * stagger
	local paused_cat = (local_t >= lerp) and order[current_i] or nil

	return {
		active = true,
		playing = elapsed < total,
		settled = elapsed >= total,
		progress = progress,
		paused_cat = paused_cat,
	}
end

---@param values table|nil
---@param progress table<string, number>
---@return table|nil
MissionSummaryElement._animate_values = function(self, values, progress)
	if not values then
		return nil
	end
	local out = {}
	for k, v in pairs(values) do
		out[k] = v
	end
	for field, cat in pairs(FIELD_CATEGORY) do
		local v = values[field]
		if type(v) == "number" then
			local scaled = v * (progress[cat] or 1)
			out[field] = FLOAT_FIELDS[field] and scaled or math_floor(scaled)
		end
	end
	if values.event_counts then
		local counts = {}
		for id, n in pairs(values.event_counts) do
			local cat = EVENT_CATEGORY[id]
			local p = cat and progress[cat] or 1
			counts[id] = (type(n) == "number") and math_floor(n * p) or n
		end
		out.event_counts = counts
	end
	return out
end

---@param snapshot MissionSummarySnapshot
---@param intro MissionRecapState
---@return MissionSummarySnapshot
MissionSummaryElement._animated_snapshot = function(self, snapshot, intro)
	local out = {}
	for k, v in pairs(snapshot) do
		out[k] = v
	end

	out.values = self:_animate_values(snapshot.values, intro.progress)

	if snapshot.level and snapshot.level_end_sp then
		local start_sp = snapshot.level_start_sp or 0
		local sp = start_sp + (snapshot.level_end_sp - start_sp) * (intro.progress.style or 1)
		out.level = Presentation.level_for_sp(sp)
	end

	return out
end

MissionSummaryElement.update = function(self, dt, t, input_service)
	MissionSummaryElement.super.update(self, dt, t, input_service)

	if not self:visible() then
		return
	end

	local snapshot = Manager.snapshot()
	local empty = snapshot.mode == "empty"

	local intro = self:_intro_advance(snapshot, dt)
	local draw = intro.playing and self:_animated_snapshot(snapshot, intro) or snapshot

	local lerping = intro.active and intro.playing
	local show_hell_yeah = intro.active and intro.settled
	if show_hell_yeah then
		self._hell_yeah_alpha = math_min(1, self._hell_yeah_alpha + dt / math_max(C.HELL_YEAH_FADE, 0.0001))
	else
		self._hell_yeah_alpha = 0
	end

	local show_skip = lerping and (self._intro_elapsed or 0) >= C.SKIP_RECAP_DELAY
	if show_skip then
		self._skip_alpha = math_min(1, self._skip_alpha + dt / math_max(C.SKIP_RECAP_FADE, 0.0001))
	else
		self._skip_alpha = 0
	end

	self:_update_interaction(snapshot, input_service, lerping, show_hell_yeah, show_skip)

	local shadow_target = self._hover_hell_yeah and 1 or 0
	local shadow_step = dt / math_max(C.HELL_YEAH_SHADOW_HOVER_TIME, 0.0001)
	if self._hell_yeah_shadow_t < shadow_target then
		self._hell_yeah_shadow_t = math_min(shadow_target, self._hell_yeah_shadow_t + shadow_step)
	else
		self._hell_yeah_shadow_t = math_max(shadow_target, self._hell_yeah_shadow_t - shadow_step)
	end

	self:_refresh_header(draw)
	self:_refresh_run(draw, empty)
	self:_refresh_big(draw, empty, intro)
	self:_refresh_magnitude(draw, empty, intro)
	self:_refresh_events(draw, empty, intro)
	self:_refresh_highscores(snapshot)
	self:_refresh_mission_grid(snapshot)
	self:_refresh_live_button(snapshot)

	self:_refresh_delete_run(snapshot.can_delete_run and not lerping)

	self:_refresh_hell_yeah(self._hell_yeah_alpha, snapshot.rank_color)
	self:_refresh_skip_recap(self._skip_alpha)

	if self._ui_renderer then
		self:_layout_header(self._ui_renderer)
		self:_layout_skip_recap(self._ui_renderer)
	end
end

MissionSummaryElement._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	self._ui_renderer = ui_renderer
	MissionSummaryElement.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return MissionSummaryElement
