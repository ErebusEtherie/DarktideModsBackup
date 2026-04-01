local mod = get_mod("RitualZones")

local Definitions =
	mod:io_dofile("RitualZones/scripts/mods/RitualZones/RitualZones_hud_element_definitions")
local TextUtilities
do
	local ok, utilities = pcall(require, "scripts/utilities/ui/text")
	if ok then
		TextUtilities = utilities
	end
end

local HudElementRitualZones = class("HudElementRitualZones", "HudElementBase")
local DEFAULT_RGB = { 255, 255, 255 }
local DEFAULT_TRIGGER_RGB = { 255, 80, 80 }

local function is_finite_number(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clamp(value, min_value, max_value)
	if value < min_value then
		return min_value
	end
	if value > max_value then
		return max_value
	end
	return value
end

local function set_color(target, rgb, alpha)
	if not target or not rgb then
		return
	end
	target[1] = alpha or 255
	target[2] = rgb[1] or 255
	target[3] = rgb[2] or 255
	target[4] = rgb[3] or 255
end

local function format_distance_label(distance, percent, style)
	if not is_finite_number(distance) then
		return "--"
	end
	local safe_percent = percent or 0
	if style == "percent" then
		return string.format("%.0f%%", safe_percent)
	end
	if style == "meters_percent" then
		return string.format("%.0fm (%.0f%%)", distance, safe_percent)
	end
	return string.format("%.0fm", distance)
end

local function format_distance_label_precise(distance, percent, style)
	if not is_finite_number(distance) then
		return "--"
	end
	local safe_percent = percent or 0
	if style == "percent" then
		return string.format("%.0f%%", safe_percent)
	end
	if style == "meters_percent" then
		return string.format("%.2fm (%.0f%%)", distance, safe_percent)
	end
	return string.format("%.2fm", distance)
end

local trigger_label_cache = {}

local function should_show_hud()
	if mod and type(mod.should_show_hud) == "function" then
		return mod:should_show_hud()
	end
	if mod and type(mod.get) == "function" then
		return mod:get("hud_enabled") and true or false
	end
	return false
end

local function get_trigger_label(trigger_id)
	local cached = trigger_label_cache[trigger_id]
	if cached then
		return cached
	end
	local label = "Trigger"
	if trigger_id == "spawn_trigger" then
		label = mod:localize("label_ritual_spawn_trigger")
	elseif trigger_id == "ritual_start" then
		label = mod:localize("label_ritual_start_trigger")
	elseif trigger_id == "ritual_speedup" then
		label = mod:localize("label_ritual_speedup_trigger")
	end
	trigger_label_cache[trigger_id] = label
	return label
end

local function set_widget_visible(widget, visible)
	if widget and widget.content then
		widget.content.visible = visible and true or false
	end
end

local function set_widget_offset(widget, x, y)
	if not widget then
		return
	end
	local offset = widget.offset
	if not offset then
		offset = { 0, 0, 0 }
		widget.offset = offset
	end
	offset[1] = x
	offset[2] = y
end

local function clear_table_values(target)
	if not target then
		return
	end
	for key in pairs(target) do
		target[key] = nil
	end
end

local function smooth_value(current, target, speed, dt)
	if not is_finite_number(target) then
		return current or 0
	end
	if not is_finite_number(current) then
		return target
	end
	if not speed or speed <= 0 or not dt or dt <= 0 then
		return target
	end
	local alpha = 1 - math.exp(-speed * dt)
	return current + (target - current) * alpha
end

local function set_smooth_target(self, widget_name, x, y)
	if not self._smooth_targets then
		self._smooth_targets = {}
	end
	self._smooth_targets[widget_name] = { x = x, y = y }
end

local function apply_smooth_targets(self, dt, speed)
	local targets = self._smooth_targets
	if not targets then
		return
	end
	if not self._smooth_positions then
		self._smooth_positions = {}
	end
	for name, target in pairs(targets) do
		local widget = self._widgets_by_name[name]
		if widget then
			local pos = self._smooth_positions[name]
			if not pos then
				pos = { x = target.x, y = target.y }
				self._smooth_positions[name] = pos
			end
			local new_x = smooth_value(pos.x, target.x, speed, dt)
			local new_y = smooth_value(pos.y, target.y, speed, dt)
			pos.x = new_x
			pos.y = new_y
			set_widget_offset(widget, new_x, new_y)
		end
	end
end

local function apply_tick_offset(widget, offset_x, offset_y)
	if not widget or not widget.style or not widget.style.tick then
		return
	end
	local tick = widget.style.tick
	local offset = tick.offset
	if not offset then
		offset = { 0, 0, 0 }
		tick.offset = offset
	end
	if not tick._base_offset then
		tick._base_offset = { offset[1] or 0, offset[2] or 0 }
	end
	offset[1] = (tick._base_offset[1] or 0) + (offset_x or 0)
	offset[2] = (tick._base_offset[2] or 0) + (offset_y or 0)
end

local function get_axis_position(fraction, length, invert, padding)
	local safe_fraction = clamp(fraction or 0, 0, 1)
	if invert then
		safe_fraction = 1 - safe_fraction
	end
	local axis = math.floor(safe_fraction * length) - (length / 2)
	if padding and padding > 0 then
		local half = length / 2
		local min_pos = -half + padding
		local max_pos = half - padding
		if min_pos > max_pos then
			axis = 0
		else
			axis = clamp(axis, min_pos, max_pos)
		end
	end
	return axis
end

local function axis_to_offset(axis, orientation)
	if orientation == "vertical" then
		return 0, -axis
	end
	return axis, 0
end

local function get_progress_fraction(distance, total_distance, reference_distance, relative_range, relative_mode)
	if not is_finite_number(distance) then
		return 0
	end
	if relative_mode and is_finite_number(reference_distance) and relative_range and relative_range > 0 then
		return clamp((distance - reference_distance + relative_range) / (relative_range * 2), 0, 1)
	end
	if total_distance and total_distance > 0 then
		return clamp(distance / total_distance, 0, 1)
	end
	return 0
end

local function resolve_label_layout(axis, bar_width, base_offset, label_width, label_side, is_horizontal, base_align)
	if not is_horizontal then
		return base_offset, base_align
	end

	if label_side == "flip" then
		return -base_offset, "right"
	end

	if label_side ~= "auto" then
		return base_offset, base_align
	end

	local half = bar_width / 2
	local width = label_width or 0
	local fits_right = (axis + base_offset + width) <= half
	local fits_left = (axis - base_offset - width) >= -half

	if fits_right then
		return base_offset, "left"
	end
	if fits_left then
		return -base_offset, "right"
	end

	local right_space = half - axis
	local left_space = half + axis
	if right_space >= left_space then
		return base_offset, "left"
	end
	return -base_offset, "right"
end

local function get_label_range(axis, label_offset, label_width)
	local width = label_width or 0
	local start = axis + (label_offset or 0)
	if (label_offset or 0) < 0 then
		start = start - width
	end
	local finish = start + width
	if finish < start then
		start, finish = finish, start
	end
	return start, finish
end

local function get_label_lane_for_range(range_min, range_max, lanes, gap)
	if not lanes then
		return 1
	end
	local padding = gap or 0
	for i = 1, #lanes do
		local lane = lanes[i]
		if not lane or range_min > (lane.max + padding) or range_max < (lane.min - padding) then
			if lane then
				lane.min = math.min(lane.min, range_min)
				lane.max = math.max(lane.max, range_max)
			else
				lanes[i] = { min = range_min, max = range_max }
			end
			return i
		end
	end
	lanes[#lanes + 1] = { min = range_min, max = range_max }
	return #lanes
end

local function get_label_stack_offset(axis, base_offset, lanes, threshold, spacing)
	if not lanes or not threshold or threshold <= 0 or not spacing or spacing <= 0 then
		return 0
	end
	local lane = nil
	for i = 1, #lanes do
		local lane_value = lanes[i]
		if type(lane_value) == "number" then
			if math.abs(axis - lane_value) >= threshold then
				lanes[i] = axis
				lane = i
				break
			end
		elseif type(lane_value) == "table" then
			if axis > (lane_value.max + threshold) or axis < (lane_value.min - threshold) then
				lane_value.min = math.min(lane_value.min, axis)
				lane_value.max = math.max(lane_value.max, axis)
				lane = i
				break
			end
		end
	end
	if not lane then
		lane = #lanes + 1
		lanes[lane] = axis
	end
	if lane <= 1 then
		return 0
	end
	local sign = (base_offset or 0) >= 0 and 1 or -1
	return sign * spacing * (lane - 1)
end

local function get_label_stack_spacing(font_size, padding_y, base_spacing, is_horizontal)
	local spacing = base_spacing or 0
	if is_horizontal then
		local safe_font = tonumber(font_size) or 12
		local line_height = math.floor(safe_font * 1.15)
		local padded_height = line_height + (padding_y or 0) * 2 + 2
		if padded_height > spacing then
			spacing = padded_height
		end
	end
	return spacing
end

local function is_position_available(axis, occupied, min_spacing)
	for i = 1, #occupied do
		if math.abs(axis - occupied[i]) < min_spacing then
			return false
		end
	end
	return true
end

local function sort_entries_by_distance(entries)
	table.sort(entries, function(a, b)
		local ad = a.distance or 0
		local bd = b.distance or 0
		if ad == bd then
			return (a.name or "") < (b.name or "")
		end
		return ad < bd
	end)
end

local function build_prioritized_entries(entries)
	local prioritized = {}
	local local_entry = nil
	local leader_entry = nil
	for i = 1, #entries do
		local entry = entries[i]
		if entry.is_local then
			local_entry = entry
		elseif entry.is_leader then
			leader_entry = entry
		end
	end

	if local_entry then
		prioritized[#prioritized + 1] = local_entry
	end
	if leader_entry and leader_entry ~= local_entry then
		prioritized[#prioritized + 1] = leader_entry
	end

	local others = {}
	for i = 1, #entries do
		local entry = entries[i]
		if entry ~= local_entry and entry ~= leader_entry then
			others[#others + 1] = entry
		end
	end
	if #others > 1 then
		sort_entries_by_distance(others)
	end
	for i = 1, #others do
		prioritized[#prioritized + 1] = others[i]
	end

	return prioritized
end

local function wrap_label(ui_renderer, text, style, wrap_width)
	if not text or text == "" or not ui_renderer or not style or not TextUtilities or not TextUtilities.word_wrap then
		return text, 1
	end
	if not wrap_width or wrap_width <= 0 then
		return text, 1
	end
	local rows = TextUtilities.word_wrap(ui_renderer, text, style, wrap_width)
	if not rows or #rows == 0 then
		return text, 1
	end
	return table.concat(rows, "\n"), #rows
end

local function apply_label_style(
	widget,
	label_text,
	font_size,
	label_x,
	label_y,
	label_align,
	color,
	alpha,
	ui_renderer,
	wrap_width,
	bg_enabled,
	bg_alpha,
	bg_padding_x,
	bg_padding_y
)
	if not widget or not widget.style or not widget.style.label then
		if widget and widget.content then
			widget.content.label = label_text or ""
		end
		return
	end

	local style = widget.style.label
	style.font_size = font_size
	style.offset[1] = label_x
	style.offset[2] = label_y
	style.text_horizontal_alignment = label_align

	if color then
		set_color(style.text_color, color, alpha or 255)
	end

	local final_label, line_count = wrap_label(ui_renderer, label_text or "", style, wrap_width)
	local line_height = math.floor(font_size * 1.15)
	local text_width = 0
	local text_height = line_height * line_count
	local measure_width = wrap_width and wrap_width > 0 and wrap_width or 1000
	if TextUtilities and ui_renderer and TextUtilities.text_size then
		local measured_width, measured_height = TextUtilities.text_size(ui_renderer, final_label, style, { measure_width, 1000 })
		text_width = measured_width or 0
		if measured_height and measured_height > text_height then
			text_height = measured_height
		end
	else
		text_width = wrap_width and wrap_width > 0 and wrap_width or (style.size and style.size[1]) or 0
	end

	if wrap_width and wrap_width > 0 then
		style.size[1] = wrap_width
		style.size[2] = math.max(style.size[2] or 0, line_height * line_count)
	else
		style.size[1] = math.max(1, math.ceil(text_width))
		style.size[2] = math.max(style.size[2] or 0, line_height * line_count)
	end

	local bg_style = widget.style.label_bg
	if bg_style then
		if bg_enabled and final_label and final_label ~= "" then
			local pad_x = bg_padding_x or 4
			local pad_y = bg_padding_y or 2
			local size_width = style.size and style.size[1] or math.ceil(text_width)
			local text_start_x = label_x
			if label_align == "right" then
				text_start_x = label_x + (size_width - text_width)
			elseif label_align == "center" then
				text_start_x = label_x + ((size_width - text_width) / 2)
			end
			bg_style.offset[1] = math.floor(text_start_x - pad_x)
			bg_style.offset[2] = math.floor(label_y - pad_y)
			bg_style.size[1] = math.max(1, math.ceil(text_width + (pad_x * 2)))
			bg_style.size[2] = math.max(1, math.ceil(text_height + (pad_y * 2)))
			bg_style.color[1] = bg_alpha or 180
			bg_style.color[2] = 0
			bg_style.color[3] = 0
			bg_style.color[4] = 0
		else
			bg_style.size[1] = 0
			bg_style.size[2] = 0
		end
	end

	if widget.content then
		widget.content.label = final_label or ""
	end
end

local function get_position_offset(fraction, length, orientation, invert)
	local safe_fraction = clamp(fraction or 0, 0, 1)
	if invert then
		safe_fraction = 1 - safe_fraction
	end
	if orientation == "vertical" then
		local y = (length / 2) - math.floor(safe_fraction * length)
		return 0, y
	end
	local x = -((length / 2) - math.floor(safe_fraction * length))
	return x, 0
end

function HudElementRitualZones:init(parent, draw_layer, start_scale)
	HudElementRitualZones.super.init(self, parent, draw_layer, start_scale, Definitions)
	self._max_players = Definitions.max_players or 4
	self._max_triggers = Definitions.max_triggers or 24
	self._update_timer = 0
	self._smooth_positions = {}
	self._smooth_targets = {}
end

function HudElementRitualZones:_hide_all()
	for _, widget in pairs(self._widgets_by_name) do
		if widget and widget.content then
			widget.content.visible = false
		end
	end
	clear_table_values(self._smooth_targets)
	clear_table_values(self._smooth_positions)
end

function HudElementRitualZones:update(dt, t, ui_renderer, render_settings, input_service)
	HudElementRitualZones.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	if not should_show_hud() then
		self:_hide_all()
		return
	end

	local state = mod._hud_state
	if not state then
		self:_hide_all()
		return
	end

	local update_interval = tonumber(mod:get("hud_update_interval")) or 0.2
	if update_interval < 0.05 then
		update_interval = 0.05
	end
	self._update_timer = self._update_timer + (dt or 0)
	local do_sample = false
	if self._update_timer >= update_interval then
		self._update_timer = 0
		do_sample = true
	end

	local orientation = mod:get("hud_orientation") or "horizontal"
	local invert = mod:get("hud_invert") == true
	local is_horizontal = orientation ~= "vertical"
	local center_on_player = mod:get("hud_center_on_player") == true
	local relative_range = clamp(tonumber(mod:get("hud_relative_range")) or 100, 5, 1000)
	local font_size = tonumber(mod:get("hud_font_size")) or 18
	local label_mode = mod:get("hud_label_mode") or "name_distance"
	local distance_style = mod:get("hud_distance_style") or "meters"
	local label_side = mod:get("hud_label_side") or "auto"
	local bg_opacity = tonumber(mod:get("hud_bg_opacity")) or 140
	local show_triggers = mod:get("hud_show_triggers") == true
	local show_trigger_labels = mod:get("hud_show_trigger_labels") == true
	local show_self = mod:get("hud_show_self") == true
	local show_all = mod:get("hud_show_all") == true
	local show_max = mod:get("hud_show_max") == true
	local show_leader = mod:get("hud_show_leader") == true
	local show_leader_name = mod:get("hud_show_leader_name") == true
	local show_stats = mod:get("hud_show_stats") == true
	local label_stack_enabled = mod:get("hud_label_stack_enabled") ~= false
	local label_stack_spacing = clamp(tonumber(mod:get("hud_label_stack_spacing")) or 14, 0, 80)
	local label_bg_enabled = mod:get("hud_label_bg_enabled") ~= false
	local label_bg_opacity = clamp(tonumber(mod:get("hud_label_bg_opacity")) or 180, 0, 255)
	local label_bg_padding_x = clamp(tonumber(mod:get("hud_label_bg_padding_x")) or 6, 0, 30)
	local label_bg_padding_y = clamp(tonumber(mod:get("hud_label_bg_padding_y")) or 3, 0, 30)
	local label_wrap_width = clamp(tonumber(mod:get("hud_label_wrap_width")) or 0, 0, 1000)
	local legacy_label_offset_y = clamp(tonumber(mod:get("hud_label_offset_y")) or 0, -200, 200)
	local stats_pos_x = tonumber(mod:get("hud_stats_pos_x")) or 20
	local stats_pos_y = tonumber(mod:get("hud_stats_pos_y")) or 360
	local stats_width = clamp(tonumber(mod:get("hud_stats_width")) or 240, 120, 1000)
	local stats_font_size = clamp(tonumber(mod:get("hud_stats_font_size")) or (font_size - 2), 10, 36)
	local player_tick_offset_x = clamp(tonumber(mod:get("hud_player_tick_offset_x")) or 0, -200, 200)
	local player_tick_offset_y = clamp(tonumber(mod:get("hud_player_tick_offset_y")) or 0, -200, 200)
	local max_tick_offset_x = clamp(tonumber(mod:get("hud_max_tick_offset_x")) or 0, -200, 200)
	local max_tick_offset_y = clamp(tonumber(mod:get("hud_max_tick_offset_y")) or 0, -200, 200)
	local trigger_tick_offset_x = clamp(tonumber(mod:get("hud_trigger_tick_offset_x")) or 0, -200, 200)
	local trigger_tick_offset_y = clamp(tonumber(mod:get("hud_trigger_tick_offset_y")) or 0, -200, 200)
	local smoothing_speed = 12
	local length
	local thickness
	local marker_size
	local hud_pos_x
	local hud_pos_y
	local label_offset_x = 0
	local label_offset_y = 0
	if is_horizontal then
		length = tonumber(mod:get("hud_length_horizontal"))
		thickness = tonumber(mod:get("hud_thickness_horizontal"))
		marker_size = tonumber(mod:get("hud_marker_size_horizontal"))
		hud_pos_x = tonumber(mod:get("hud_pos_x_horizontal"))
		hud_pos_y = tonumber(mod:get("hud_pos_y_horizontal"))
		label_offset_x = clamp(tonumber(mod:get("hud_label_offset_x_horizontal")) or 0, -200, 200)
		label_offset_y = clamp(tonumber(mod:get("hud_label_offset_y_horizontal")) or legacy_label_offset_y or 0, -200, 200)
	else
		length = tonumber(mod:get("hud_length_vertical"))
		thickness = tonumber(mod:get("hud_thickness_vertical"))
		marker_size = tonumber(mod:get("hud_marker_size_vertical"))
		hud_pos_x = tonumber(mod:get("hud_pos_x_vertical"))
		hud_pos_y = tonumber(mod:get("hud_pos_y_vertical"))
		label_offset_x = clamp(tonumber(mod:get("hud_label_offset_x_vertical")) or 0, -200, 200)
		label_offset_y = clamp(tonumber(mod:get("hud_label_offset_y_vertical")) or legacy_label_offset_y or 0, -200, 200)
	end
	length = length or 260
	thickness = thickness or 10
	marker_size = marker_size or 8
	hud_pos_x = hud_pos_x or 20
	hud_pos_y = hud_pos_y or 240

	if not do_sample then
		apply_smooth_targets(self, dt or 0, smoothing_speed)
		return
	end

	clear_table_values(self._smooth_targets)

	length = math.max(60, length)
	thickness = math.max(4, thickness)
	marker_size = clamp(marker_size, 4, 24)
	font_size = math.max(10, font_size)
	bg_opacity = clamp(math.floor(bg_opacity + 0.5), 0, 255)

	local bar_width = orientation == "vertical" and thickness or length
	local bar_height = orientation == "vertical" and length or thickness

	local scenegraph = self._ui_scenegraph
	local container = scenegraph.timeline_container
	if container then
		local label_reserve = label_wrap_width > 0 and math.max(180, label_wrap_width + 40) or 180
		label_reserve = label_reserve + (label_stack_enabled and label_stack_spacing * 2 or 0)
		local height_reserve = is_horizontal and math.max(100, (font_size * 2) + marker_size) or 100
		if label_stack_enabled and is_horizontal then
			height_reserve = height_reserve + (label_stack_spacing * 3)
		end
		self:set_scenegraph_position("timeline_container", hud_pos_x, hud_pos_y)
		self:_set_scenegraph_size("timeline_container", bar_width + label_reserve, bar_height + height_reserve)
	end

	local bar_node = scenegraph.timeline_bar
	if bar_node then
		self:_set_scenegraph_size("timeline_bar", bar_width, bar_height)
	end
	local stats_node = scenegraph.timeline_stats
	if stats_node then
		self:set_scenegraph_position("timeline_stats", stats_pos_x, stats_pos_y)
		self:_set_scenegraph_size("timeline_stats", stats_width, nil)
	end

	local widgets = self._widgets_by_name
	local bg_widget = widgets.timeline_bg
	if bg_widget and bg_widget.style then
		local background = bg_widget.style.background
		if background then
			background.size[1] = bar_width
			background.size[2] = bar_height
			background.color[1] = bg_opacity
		end
		local line = bg_widget.style.line
		if line then
			line.size[1] = math.max(1, bar_width - 2)
			line.size[2] = math.max(1, bar_height - 2)
			line.offset[1] = 1
			line.offset[2] = 1
			if state.colors and state.colors.line then
				set_color(line.color, state.colors.line, 255)
			end
		end
		if bg_widget.content then
			bg_widget.content.visible = true
		end
	end

	local total_distance = state.path_total
	if not is_finite_number(total_distance) or total_distance <= 0 then
		total_distance = state.max_progress_distance or state.leader_distance or state.player_distance or 0
	end
	if not is_finite_number(total_distance) or total_distance <= 0 then
		self:_hide_all()
		if bg_widget and bg_widget.content then
			bg_widget.content.visible = true
		end
		return
	end

	local base_label_offset = (thickness / 2) + 10
	local font_label_offset = math.max(0, math.floor(font_size * 0.8))
	local label_offset = math.max(base_label_offset, font_label_offset)
	local label_flip = label_side == "flip"
	local label_x = is_horizontal and math.max(12, marker_size + 6) or (label_flip and -label_offset or label_offset)
	local label_y = 0
	if is_horizontal then
		local signed_extra = label_flip and -label_offset_y or label_offset_y
		label_y = (label_flip and -label_offset or label_offset) + signed_extra
	else
		label_y = label_offset_y
	end
	label_x = label_x + label_offset_x
	local label_align = (not is_horizontal and label_flip) and "right" or "left"
	local label_width = label_wrap_width > 0 and label_wrap_width or 220
	local label_gap = math.max(4, label_bg_padding_x)
	local label_stack_step = get_label_stack_spacing(font_size, label_bg_padding_y, label_stack_spacing, is_horizontal)
	local label_lanes = {
		left = {},
		right = {},
	}

	local reference_distance = center_on_player and (state.player_distance or state.leader_distance) or nil

	local player_tick = math.max(2, math.floor(marker_size / 2))
	local trigger_tick = math.max(1, math.floor(marker_size / 3))

	local entry_count = state.entry_count or 0
	local display_entries = {}
	for i = 1, entry_count do
		local entry = state.entries[i]
		local include = show_all or (show_self and entry.is_local) or (show_leader and entry.is_leader)
		if include then
			display_entries[#display_entries + 1] = entry
		end
	end
	if #display_entries > 1 then
		display_entries = build_prioritized_entries(display_entries)
	end

	local player_padding = math.floor(player_tick / 2)
	local player_min_spacing = math.max(2, player_tick + 2)
	local occupied_positions = {}
	local display_index = 0
	for i = 1, #display_entries do
		if display_index >= self._max_players then
			break
		end
		local entry = display_entries[i]
		local fraction = get_progress_fraction(
			entry.distance,
			total_distance,
			reference_distance,
			relative_range,
			center_on_player
		)
		local axis = get_axis_position(fraction, length, invert, player_padding)
		if is_position_available(axis, occupied_positions, player_min_spacing) then
			display_index = display_index + 1
			local widget_name = "player_marker_" .. display_index
			local widget = widgets[widget_name]
			if widget and widget.style then
				local x, y = axis_to_offset(axis, orientation)
				set_smooth_target(self, widget_name, x, y)
				if widget.style.tick then
					if is_horizontal then
						widget.style.tick.size[1] = player_tick
						widget.style.tick.size[2] = bar_height + 6
					else
						widget.style.tick.size[1] = bar_width + 6
						widget.style.tick.size[2] = player_tick
					end
					apply_tick_offset(widget, player_tick_offset_x, player_tick_offset_y)
					local rgb = state.colors and state.colors.other or DEFAULT_RGB
					if entry.is_local and state.colors and state.colors.self then
						rgb = state.colors.self
					elseif entry.is_leader and state.colors and state.colors.leader then
						rgb = state.colors.leader
					end
					local alpha = entry.alive and 255 or 160
					set_color(widget.style.tick.color, rgb, alpha)
				end
				if widget.content then
					local name = entry.name or (entry.is_local and "You") or "Player"
					local percent = clamp((entry.distance / total_distance) * 100, 0, 100)
					local distance_label = format_distance_label(entry.distance, percent, distance_style)
					local label = ""
					if label_mode == "name" then
						label = name
					elseif label_mode == "distance" then
						label = distance_label
					elseif label_mode == "name_distance" then
						label = string.format("%s %s", name, distance_label)
					end
					if label_mode ~= "off" and entry.is_leader and show_leader_name then
						if label == "" then
							label = "Leader"
						else
							label = string.format("%s (Leader)", label)
						end
					end
					local entry_label_x, entry_label_align =
						resolve_label_layout(axis, bar_width, label_x, label_width, label_side, is_horizontal, label_align)
					local entry_label_y = label_y
					if label_stack_enabled and label ~= "" then
						local side_key = entry_label_x >= 0 and "right" or "left"
						local range_min, range_max = get_label_range(axis, entry_label_x, label_width)
						local lane = get_label_lane_for_range(range_min, range_max, label_lanes[side_key], label_gap)
						local sign = ((is_horizontal and label_y or entry_label_x) or 0) >= 0 and 1 or -1
						local stack_offset = (lane - 1) * label_stack_step * sign
						if is_horizontal then
							entry_label_y = label_y + stack_offset
						else
							entry_label_x = entry_label_x + stack_offset
						end
					end
					apply_label_style(
						widget,
						label,
						font_size,
						entry_label_x,
						entry_label_y,
						entry_label_align,
						state.colors and state.colors.text,
						255,
						ui_renderer,
						label_wrap_width,
						label_bg_enabled,
						label_bg_opacity,
						label_bg_padding_x,
						label_bg_padding_y
					)
					widget.content.visible = true
				end
			end
			occupied_positions[#occupied_positions + 1] = axis
		end
	end

	for i = display_index + 1, self._max_players do
		set_widget_visible(widgets["player_marker_" .. i], false)
	end

	if show_triggers then
		local trigger_padding = math.floor(trigger_tick / 2)
		local trigger_count = math.min(state.trigger_count or 0, self._max_triggers)
		local trigger_reference_distance = state.reference_distance or 0
		local ahead_trigger_index = nil
		if center_on_player and reference_distance and relative_range and relative_range > 0 then
			local min_ahead = nil
			for i = 1, trigger_count do
				local trigger = state.triggers[i]
				local distance = trigger and trigger.distance
				if distance and distance > (reference_distance + relative_range) then
					if not min_ahead or distance < min_ahead then
						min_ahead = distance
						ahead_trigger_index = i
					end
				end
			end
		end
		for i = 1, trigger_count do
			local trigger = state.triggers[i]
			local widget_name = "trigger_marker_" .. i
			local widget = widgets[widget_name]
			if widget and widget.style then
				local distance = trigger and trigger.distance
				local hide_trigger = false
				if not distance then
					hide_trigger = true
				end
				if not hide_trigger and center_on_player and reference_distance and relative_range and relative_range > 0 then
					if distance < (reference_distance - relative_range) then
						hide_trigger = true
					elseif distance > (reference_distance + relative_range) and i ~= ahead_trigger_index then
						hide_trigger = true
					end
				end
				if hide_trigger then
					set_widget_visible(widget, false)
				else
					local fraction = get_progress_fraction(
						distance,
						total_distance,
						reference_distance,
						relative_range,
						center_on_player
					)
					local axis = get_axis_position(fraction, length, invert, trigger_padding)
					local x, y = axis_to_offset(axis, orientation)
					set_smooth_target(self, widget_name, x, y)
					if widget.style.tick then
						if is_horizontal then
							widget.style.tick.size[1] = trigger_tick
							widget.style.tick.size[2] = bar_height + 4
						else
							widget.style.tick.size[1] = bar_width + 4
							widget.style.tick.size[2] = trigger_tick
						end
						apply_tick_offset(widget, trigger_tick_offset_x, trigger_tick_offset_y)
						local rgb = state.colors and state.colors.trigger_spawn or DEFAULT_TRIGGER_RGB
						if trigger.color == "orange" then
							rgb = state.colors and state.colors.trigger_start or rgb
						elseif trigger.color == "yellow" then
							rgb = state.colors and state.colors.trigger_speedup or rgb
						end
						local alpha = distance <= trigger_reference_distance and 120 or 255
						set_color(widget.style.tick.color, rgb, alpha)
					end
					if widget.content then
						local trigger_font = math.max(10, font_size - 4)
						local label = show_trigger_labels and get_trigger_label(trigger.id) or ""
						local trigger_label_x, trigger_label_align = resolve_label_layout(
							axis,
							bar_width,
							label_x,
							label_width,
							label_side,
							is_horizontal,
							label_align
						)
						local trigger_label_y = label_y
						if label_stack_enabled and label ~= "" then
							local side_key = trigger_label_x >= 0 and "right" or "left"
							local range_min, range_max = get_label_range(axis, trigger_label_x, label_width)
							local lane = get_label_lane_for_range(range_min, range_max, label_lanes[side_key], label_gap)
							local sign = ((is_horizontal and label_y or trigger_label_x) or 0) >= 0 and 1 or -1
							local stack_offset = (lane - 1) * label_stack_step * sign
							if is_horizontal then
								trigger_label_y = label_y + stack_offset
							else
								trigger_label_x = trigger_label_x + stack_offset
							end
						end
						apply_label_style(
							widget,
							label,
							trigger_font,
							trigger_label_x,
							trigger_label_y,
							trigger_label_align,
							state.colors and state.colors.text,
							200,
							ui_renderer,
							label_wrap_width,
							label_bg_enabled,
							label_bg_opacity,
							label_bg_padding_x,
							label_bg_padding_y
						)
						widget.content.visible = true
					end
				end
			end
		end
		for i = trigger_count + 1, self._max_triggers do
			set_widget_visible(widgets["trigger_marker_" .. i], false)
		end
	else
		for i = 1, self._max_triggers do
			set_widget_visible(widgets["trigger_marker_" .. i], false)
		end
	end

	local max_widget = widgets.max_marker
	if show_max and max_widget and state.max_progress_distance then
		local max_distance = state.max_progress_distance
		local fraction = get_progress_fraction(
			max_distance,
			total_distance,
			reference_distance,
			relative_range,
			center_on_player
		)
		local max_padding = math.floor(player_tick / 2)
		local axis = get_axis_position(fraction, length, invert, max_padding)
		local x, y = axis_to_offset(axis, orientation)
		set_smooth_target(self, "max_marker", x, y)
		if max_widget.style and max_widget.style.tick then
			if is_horizontal then
				max_widget.style.tick.size[1] = player_tick
				max_widget.style.tick.size[2] = bar_height + 6
			else
				max_widget.style.tick.size[1] = bar_width + 6
				max_widget.style.tick.size[2] = player_tick
			end
			apply_tick_offset(max_widget, max_tick_offset_x, max_tick_offset_y)
			if state.colors and state.colors.max then
				set_color(max_widget.style.tick.color, state.colors.max, 255)
			end
		end
		if max_widget.content then
			local percent = clamp((max_distance / total_distance) * 100, 0, 100)
			local distance_label = format_distance_label(max_distance, percent, distance_style)
			local label = "Max"
			if label_mode == "distance" then
				label = distance_label
			elseif label_mode == "name_distance" then
				label = string.format("Max %s", distance_label)
			elseif label_mode == "off" then
				label = ""
			end
			local max_label_x, max_label_align =
				resolve_label_layout(axis, bar_width, label_x, label_width, label_side, is_horizontal, label_align)
			local max_label_y = label_y
			if label_stack_enabled and label ~= "" then
				local side_key = max_label_x >= 0 and "right" or "left"
				local range_min, range_max = get_label_range(axis, max_label_x, label_width)
				local lane = get_label_lane_for_range(range_min, range_max, label_lanes[side_key], label_gap)
				local sign = ((is_horizontal and label_y or max_label_x) or 0) >= 0 and 1 or -1
				local stack_offset = (lane - 1) * label_stack_step * sign
				if is_horizontal then
					max_label_y = label_y + stack_offset
				else
					max_label_x = max_label_x + stack_offset
				end
			end
			local max_font = math.max(10, font_size - 2)
			apply_label_style(
				max_widget,
				label,
				max_font,
				max_label_x,
				max_label_y,
				max_label_align,
				state.colors and state.colors.text,
				255,
				ui_renderer,
				label_wrap_width,
				label_bg_enabled,
				label_bg_opacity,
				label_bg_padding_x,
				label_bg_padding_y
			)
			max_widget.content.visible = true
		end
	else
		set_widget_visible(max_widget, false)
	end

	local stats_widget = widgets.timeline_stats
	if show_stats and stats_widget and stats_widget.style and stats_widget.content then
		local stats_bg_padding = 6
		local stats_line_spacing = 0.8
		local stats_lines = {}
		local max_distance = state.max_progress_distance
		if max_distance then
			local percent = clamp((max_distance / total_distance) * 100, 0, 100)
			stats_lines[#stats_lines + 1] =
				string.format("Max: %s", format_distance_label_precise(max_distance, percent, distance_style))
		else
			stats_lines[#stats_lines + 1] = "Max: --"
		end
		if state.leader_distance then
			local percent = clamp((state.leader_distance / total_distance) * 100, 0, 100)
			local leader_name = state.leader_name or "Leader"
			stats_lines[#stats_lines + 1] =
				string.format(
					"Leader: %s %s",
					leader_name,
					format_distance_label_precise(state.leader_distance, percent, distance_style)
				)
		end
		if state.player_distance then
			local percent = clamp((state.player_distance / total_distance) * 100, 0, 100)
			stats_lines[#stats_lines + 1] =
				string.format("You: %s", format_distance_label_precise(state.player_distance, percent, distance_style))
		end

		stats_lines[#stats_lines + 1] = string.format("Players: %d", #display_entries)
		for i = 1, #display_entries do
			local entry = display_entries[i]
			if entry and entry.distance then
				local name = entry.name or "Player"
				if entry.is_local then
					name = name .. " (You)"
				elseif entry.is_leader then
					name = name .. " (Leader)"
				end
				local percent = clamp((entry.distance / total_distance) * 100, 0, 100)
				local distance_label = format_distance_label_precise(entry.distance, percent, distance_style)
				stats_lines[#stats_lines + 1] = string.format("%s: %s", name, distance_label)
			end
		end

		local stats_text = table.concat(stats_lines, "\n")
		local text_style = stats_widget.style.text
		text_style.font_size = stats_font_size
		text_style.text_horizontal_alignment = "left"
		text_style.text_vertical_alignment = "top"
		text_style.line_spacing = stats_line_spacing
		if state.colors and state.colors.text then
			set_color(text_style.text_color, state.colors.text, 255)
		end

		local wrapped_text, line_count = wrap_label(ui_renderer, stats_text, text_style, stats_width)
		text_style.size[1] = stats_width
		local line_height = math.max(1, math.floor(stats_font_size * stats_line_spacing))
		text_style.size[2] = math.max(text_style.size[2] or 0, line_height * line_count)
		local measured_height = text_style.size[2]
		if TextUtilities and ui_renderer and TextUtilities.text_size then
			local _, height = TextUtilities.text_size(ui_renderer, wrapped_text, text_style, { stats_width, 1000 })
			measured_height = height or measured_height
		end
		if measured_height > (text_style.size[2] or 0) then
			text_style.size[2] = measured_height
		end
		text_style.offset[1] = stats_bg_padding
		text_style.offset[2] = stats_bg_padding
		local bg_style = stats_widget.style.stats_bg
		if bg_style and wrapped_text and wrapped_text ~= "" then
			bg_style.offset[1] = 0
			bg_style.offset[2] = 0
			bg_style.size[1] = math.max(1, math.ceil(stats_width + (stats_bg_padding * 2)))
			bg_style.size[2] = math.max(1, math.ceil(math.max(measured_height, text_style.size[2]) + (stats_bg_padding * 2)))
			bg_style.color[1] = 180
			bg_style.color[2] = 0
			bg_style.color[3] = 0
			bg_style.color[4] = 0
		elseif bg_style then
			bg_style.size[1] = 0
			bg_style.size[2] = 0
		end
		if stats_node then
			self:_set_scenegraph_size("timeline_stats", nil, bg_style.size[2])
		end

		stats_widget.content.text = wrapped_text
		stats_widget.content.visible = true
	else
		set_widget_visible(stats_widget, false)
		if stats_widget and stats_widget.style and stats_widget.style.stats_bg then
			stats_widget.style.stats_bg.size[1] = 0
			stats_widget.style.stats_bg.size[2] = 0
		end
	end

	apply_smooth_targets(self, dt or 0, smoothing_speed)
end

function HudElementRitualZones:draw(dt, t, ui_renderer, render_settings, input_service)
	if not should_show_hud() then
		return
	end
	if not mod._hud_state then
		return
	end
	HudElementRitualZones.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudElementRitualZones
