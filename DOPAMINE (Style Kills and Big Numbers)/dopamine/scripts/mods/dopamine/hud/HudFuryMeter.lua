

---@type mod
local mod = get_mod("dopamine")

local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local FuryMeterConstants = mod:core(mod.fury_meter_constants, "hud/fury_meter/constants")
local FuryMeterPresentation = mod:core(mod.fury_meter_presentation, "hud/fury_meter/presentation")
local Rumble = mod:core(mod.rumble, "utils/rumble")
local Definitions = mod:io_dofile("dopamine/scripts/mods/dopamine/hud/fury_meter/definitions")
local Constants = mod:core(mod.constants, "hud/constants")

local math_clamp = math.clamp
local math_max = math.max
local math_floor = math.floor

local color_foreground_muted = mod.constants.COLOR.UI_FOREGROUND_MUTED

local _visible_statline_segments = {}

local HudFuryMeter = class("HudFuryMeter", "HudElementBase")

HudFuryMeter.init = function(self, parent, draw_layer, start_scale)
	HudFuryMeter.super.init(self, parent, draw_layer + Constants.HUD_Z_BOOST, start_scale, {
		scenegraph_definition = Definitions.scenegraph_definition,
		widget_definitions = Definitions.widget_definitions,
	})

	self._bar_alpha = 0

	self._was_active = false

	self._callout_text = ""
	self._callout_alpha = 0

	self._callout_shadow_text = ""
	self._callout_shadow_src = ""

	self._bar_color = { 255, 255, 255, 255 } 
	self._max_fury_blend = 0 
end

local function clear_callout_display(self)
	self._callout_text = ""
	self._callout_alpha = 0
	self._callout_shadow_text = ""
	self._callout_shadow_src = ""
end

local function sync_callout_shadow_text(self)
	if self._callout_text ~= self._callout_shadow_src then
		self._callout_shadow_src = self._callout_text
		self._callout_shadow_text = mod.dl.str.strip_rich_text(self._callout_text)
	end
end

HudFuryMeter._update_fury_rank_callout = function(self, dt)
	local was_active = self._was_active
	local fury = ComboState.fury

	if was_active and not ComboState.active then
		clear_callout_display(self)
	end

	if mod.dl.settings.debug_show_test_callout then
		self._callout_text = mod:localize("debug_callout_text")
	elseif mod.dl.settings.enable_fury_rank_text and fury > 0 then
		self._callout_text = FuryMeterPresentation.fury_rank_hud(fury) or ""
	else
		self._callout_text = ""
	end

	self._was_active = ComboState.active

	local alpha_target = 0
	if mod.dl.settings.debug_show_test_callout then
		alpha_target = 1
	elseif mod.dl.settings.enable_fury_rank_text and fury > 0 and self._callout_text ~= "" then
		alpha_target = 1
	end

	self._callout_alpha =
		math_clamp(self._callout_alpha + (alpha_target - self._callout_alpha) * math_clamp(dt * 8, 0, 1), 0, 1)

	if not ComboState.active and not mod.dl.settings.debug_show_test_callout and self._callout_alpha < 0.02 then
		self._callout_text = ""
	end

	sync_callout_shadow_text(self)
end

HudFuryMeter._update_bar = function(self, dt, t)
	local bar_widget = self._widgets_by_name.bar
	local fury_meter_styles = bar_widget.style
	local stats_widget = self._widgets_by_name.stats
	local caps_widget = self._widgets_by_name.caps
	local callout_widget = self._widgets_by_name.callout
	local align_value = FuryMeterPresentation.bar_align_value()

	local fury = ComboState.fury
	local engaged = ComboState.active
		or ComboState.grace_timer > 0
		or ComboState.ghost_timer > 0
		or ComboState.ghost > fury + 0.1

	local kill_count = ComboState.kills

	local max_fury_target = ComboState.at_max_fury() and 1 or 0
	self._max_fury_blend = self._max_fury_blend
		+ (max_fury_target - self._max_fury_blend)
			* math_clamp(dt * FuryMeterConstants.PRESENTATION.MAX_FURY_COLOR_SPEED, 0, 1)

	local bar_alpha_target = engaged and 1 or 0.25
	self._bar_alpha =
		math_clamp(self._bar_alpha + (bar_alpha_target - self._bar_alpha) * math_clamp(dt * 6, 0, 1), 0, 1)
	bar_widget.alpha_multiplier = self._bar_alpha

	stats_widget.alpha_multiplier = 1
	caps_widget.alpha_multiplier = 1
	if callout_widget then
		callout_widget.alpha_multiplier = 1
	end

	local bar_width = mod.dl.settings.fury_meter_width or FuryMeterConstants.PRESENTATION.DEFAULT_BAR_WIDTH
	local bar_height = mod.dl.settings.fury_meter_height or FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT
	local callout_width = math_max(bar_width, FuryMeterConstants.PRESENTATION.CALLOUT_TEXT_MAX_WIDTH)
	local bar_layout = FuryMeterPresentation.bar_layout(bar_width, bar_height)
	local base_y = bar_layout.base_y
	local fill_anchor = bar_layout.fill_anchor

	local fill_fraction = math_clamp(fury / 100, 0, 1)
	local ghost_fraction = math_clamp(ComboState.ghost / 100, 0, 1)

	local rumble_amplitude =
		math_max(Rumble.common_amp(), FuryMeterPresentation.fury_rumble_amp(fill_fraction, kill_count))

	local rumble_x, rumble_y = 0, 0
	if rumble_amplitude > 0 then
		rumble_x, rumble_y = mod.dl.animation.rumble(t, rumble_amplitude)
	end

	local fury_rank_font_type = FuryMeterPresentation.fury_rank_font_type()
	local fury_rank_font_size = mod.dl.settings.fury_rank_font_size
	local metrics_font_type = mod.dl.fonts.reg.mono_tide_bold
	local segments = FuryMeterPresentation.statline_segments()
	local visible_segments = _visible_statline_segments
	for i = #visible_segments, 1, -1 do
		visible_segments[i] = nil
	end

	for segment = 1, 4 do
		if not FuryMeterPresentation.statline_segment_empty(segments[segment]) then
			visible_segments[#visible_segments + 1] = segment
		end
	end

	local has_statline = #visible_segments > 0
	local statline_block_height = FuryMeterConstants.PRESENTATION.STAT_ROW_HEIGHT
		+ FuryMeterConstants.PRESENTATION.STATLINE_GAP
	local bar_shift_y = has_statline and 0 or statline_block_height
	local bar_center_y = base_y + bar_shift_y
	local container_top_y = bar_center_y - bar_height * 0.5 - 72

	self:set_scenegraph_position(
		"furyMeterContainer",
		bar_layout.container_margin_x + rumble_x,
		container_top_y + rumble_y,
		19,
		bar_layout.container_halign,
		"top"
	)

	local container = self._ui_scenegraph.furyMeterContainer
	if container then
		container.size[1] = bar_width
		container.size[2] = math_max(
			bar_height,
			statline_block_height
				+ FuryMeterConstants.PRESENTATION.STAT_ROW_HEIGHT
				+ FuryMeterConstants.PRESENTATION.STATLINE_GAP
				+ FuryMeterPresentation.callout_block_height(fury_rank_font_size)
		)
	end

	local bar_base_x = 0
	local bar_base_y = bar_height * 0.5

	local origin_x = bar_base_x
	local origin_y = bar_base_y

	fury_meter_styles.grit.size[1] = bar_width + 6
	fury_meter_styles.grit.size[2] = bar_height + 6
	fury_meter_styles.grit.offset[1] = origin_x
	fury_meter_styles.grit.offset[2] = origin_y

	fury_meter_styles.bg.size[1] = bar_width
	fury_meter_styles.bg.size[2] = bar_height
	fury_meter_styles.bg.offset[1] = origin_x
	fury_meter_styles.bg.offset[2] = origin_y
	local background_color = FuryMeterPresentation.theme_ui() and FuryMeterConstants.PRESENTATION.UI_BG_EMPTY
		or FuryMeterConstants.PRESENTATION.GRITTY_BG
	fury_meter_styles.bg.color[1] = background_color[1]
	fury_meter_styles.bg.color[2] = background_color[2]
	fury_meter_styles.bg.color[3] = background_color[3]
	fury_meter_styles.bg.color[4] = background_color[4]

	fury_meter_styles.shadow.size[1] = bar_width
	fury_meter_styles.shadow.size[2] = bar_height
	fury_meter_styles.shadow.offset[1] = origin_x
	fury_meter_styles.shadow.offset[2] = origin_y

	fury_meter_styles.highlight.size[1] = bar_width
	fury_meter_styles.highlight.size[2] = bar_height
	fury_meter_styles.highlight.offset[1] = origin_x
	fury_meter_styles.highlight.offset[2] = origin_y

	local notch_height = bar_height * 0.8
	local notch_y = origin_y - bar_height * 0.1
	local frame_pad = FuryMeterConstants.PRESENTATION.UI_FRAME_ABOVE
	local frame_top = origin_y - bar_height * 0.5 - frame_pad - FuryMeterConstants.PRESENTATION.UI_FRAME_H
	local frame_half_width = (bar_width + 10) * 0.5
	local tick_center_y = frame_top
		+ (FuryMeterConstants.PRESENTATION.UI_FRAME_H + FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_DROP) * 0.5
	local rail_center_y = frame_top + FuryMeterConstants.PRESENTATION.UI_FRAME_H * 0.5

	local fill_width = bar_width * fill_fraction
	local fill_offset_x = FuryMeterPresentation.bar_fill_offset_x(fill_anchor, origin_x, bar_width, fill_width)

	local ghost_pad = FuryMeterConstants.PRESENTATION.GHOST_HALO_PAD
	local function place_ghost_pass(ghost_style, layer_fill_fraction, layer_ghost_fraction)
		local width = 0

		if layer_fill_fraction > 0 and layer_fill_fraction < 1 then
			local pad = fill_anchor == "center" and ghost_pad * 2 or ghost_pad
			width = math_max(bar_width * layer_ghost_fraction, bar_width * layer_fill_fraction + pad)
		elseif layer_ghost_fraction > layer_fill_fraction then
			width = bar_width * layer_ghost_fraction
		end

		ghost_style.size[1] = width
		ghost_style.size[2] = bar_height
		ghost_style.offset[1] = FuryMeterPresentation.bar_fill_offset_x(fill_anchor, origin_x, bar_width, width)
		ghost_style.offset[2] = origin_y
	end

	for notch = 1, 3 do
		local notch_style = fury_meter_styles["ui_notch_" .. notch]
		notch_style.size[2] = notch_height
		notch_style.offset[1] = origin_x + bar_width * 0.25 * (notch - 2)
		notch_style.offset[2] = notch_y
	end

	fury_meter_styles.ui_frame_l.size[2] = FuryMeterConstants.PRESENTATION.UI_FRAME_H
		+ FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_DROP
	fury_meter_styles.ui_frame_l.offset[1] = origin_x
		- frame_half_width
		+ FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_W * 0.5
	fury_meter_styles.ui_frame_l.offset[2] = tick_center_y

	fury_meter_styles.ui_frame_r.size[2] = FuryMeterConstants.PRESENTATION.UI_FRAME_H
		+ FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_DROP
	fury_meter_styles.ui_frame_r.offset[1] = origin_x
		+ frame_half_width
		- FuryMeterConstants.PRESENTATION.UI_FRAME_TICK_W * 0.5
	fury_meter_styles.ui_frame_r.offset[2] = tick_center_y

	fury_meter_styles.ui_frame_h.size[1] = bar_width + 10
	fury_meter_styles.ui_frame_h.size[2] = FuryMeterConstants.PRESENTATION.UI_FRAME_H
	fury_meter_styles.ui_frame_h.offset[1] = origin_x
	fury_meter_styles.ui_frame_h.offset[2] = rail_center_y

	place_ghost_pass(fury_meter_styles.ghost, fill_fraction, ghost_fraction)

	fury_meter_styles.fill.size[1] = fill_width
	fury_meter_styles.fill.size[2] = bar_height
	fury_meter_styles.fill.offset[1] = fill_offset_x
	fury_meter_styles.fill.offset[2] = origin_y

	local fury_color = FuryMeterPresentation.fury_display_color(fury, self._bar_color)
	fury_meter_styles.fill.color[1] = 255
	fury_meter_styles.fill.color[2] = fury_color[2]
	fury_meter_styles.fill.color[3] = fury_color[3]
	fury_meter_styles.fill.color[4] = fury_color[4]

	fury_meter_styles.ghost.color[1] = math_floor(fury_meter_styles.fill.color[1] * 0.5)
	fury_meter_styles.ghost.color[2] = fury_meter_styles.fill.color[2]
	fury_meter_styles.ghost.color[3] = fury_meter_styles.fill.color[3]
	fury_meter_styles.ghost.color[4] = fury_meter_styles.fill.color[4]

	for stage = 1, FuryMeterPresentation.overkill_stage_count() do
		local overkill_style = fury_meter_styles["fill_overkill_" .. stage]
		local overkill_fraction = FuryMeterPresentation.overkill_fill_fraction(stage, fury)
		local overkill_width = bar_width * overkill_fraction
		local overkill_color = FuryMeterPresentation.overkill_display_color(stage, fury)

		overkill_style.size[1] = overkill_width
		overkill_style.size[2] = bar_height
		overkill_style.offset[1] =
			FuryMeterPresentation.bar_fill_offset_x(fill_anchor, origin_x, bar_width, overkill_width)
		overkill_style.offset[2] = origin_y
		overkill_style.color[1] = 255
		overkill_style.color[2] = overkill_color.bar[2]
		overkill_style.color[3] = overkill_color.bar[3]
		overkill_style.color[4] = overkill_color.bar[4]

		local overkill_ghost_style = fury_meter_styles["ghost_overkill_" .. stage]
		place_ghost_pass(
			overkill_ghost_style,
			overkill_fraction,
			FuryMeterPresentation.overkill_fill_fraction(stage, ComboState.ghost)
		)
		overkill_ghost_style.color[1] = 50
		overkill_ghost_style.color[2] = math_floor(overkill_color.ghost[2] * 0.1)
		overkill_ghost_style.color[3] = math_floor(overkill_color.ghost[3] * 0.1)
		overkill_ghost_style.color[4] = math_floor(overkill_color.ghost[4] * 0.1)
	end

	local stats_y = bar_base_y
		+ bar_height * 0.5
		+ FuryMeterConstants.PRESENTATION.STATLINE_GAP
		+ FuryMeterConstants.PRESENTATION.STAT_ROW_HEIGHT * 0.5
	local next_stat_x = bar_base_x - bar_width * 0.5
	local stat_styles = stats_widget.style
	local fury_pct = math_clamp(math_floor(fury + 0.5), 0, FuryMeterConstants.LOGIC.MAX_FURY_PCT + 1)
	local fatigue_pct = math_clamp(math_floor(ComboState.fatigue + 0.5), 0, 100)

	local function place_stat_pass(pass_key, text, width, color)
		local stat_style = stat_styles[pass_key]
		stat_style.font_type = metrics_font_type
		stat_style.font_size = FuryMeterConstants.PRESENTATION.STAT_FONT_SIZE
		stat_style.size[1] = width
		stat_style.size[2] = FuryMeterConstants.PRESENTATION.STAT_ROW_HEIGHT
		stat_style.offset[1] = next_stat_x + width * 0.5
		stat_style.offset[2] = stats_y
		stat_style.text_color[1] = color[1]
		stat_style.text_color[2] = color[2]
		stat_style.text_color[3] = color[3]
		stat_style.text_color[4] = color[4]
		stats_widget.content[pass_key] = text
		next_stat_x = next_stat_x + width
	end

	for segment = 1, 4 do
		stats_widget.content["seg" .. segment .. "_lbl"] = ""
		stats_widget.content["seg" .. segment .. "_val"] = ""

		if segment < 4 then
			stats_widget.content["sep" .. segment] = ""
		end
	end

	for visible_index, segment in ipairs(visible_segments) do
		local stat_id = segments[segment]
		local segment_layout = FuryMeterConstants.PRESENTATION.STAT_SEGMENT_LAYOUT[stat_id]
			or FuryMeterConstants.PRESENTATION.STAT_SEGMENT_LAYOUT.best_combo

		if visible_index > 1 then
			place_stat_pass(
				"sep" .. visible_segments[visible_index - 1],
				"",
				FuryMeterConstants.PRESENTATION.SEPARATOR_WIDTH,
				color_foreground_muted
			)
		end

		place_stat_pass(
			"seg" .. segment .. "_lbl",
			FuryMeterPresentation.stat_label(stat_id, segment_layout.label_key),
			segment_layout.label_width,
			color_foreground_muted
		)

		local value_color = stat_id == "fatigue_pct" and FuryMeterPresentation.fatigue_stat_value_color(fatigue_pct)
			or FuryMeterConstants.PRESENTATION.STAT_VALUE_COLOR

		place_stat_pass(
			"seg" .. segment .. "_val",
			FuryMeterPresentation.stat_segment_value(stat_id, fury_pct, fatigue_pct),
			segment_layout.value_width,
			value_color
		)
	end

	local cap_text = kill_count > 0 and tostring(kill_count) or ""
	local cap_offset_x = bar_width * 0.5 + 24

	caps_widget.style.left.font_type = metrics_font_type
	caps_widget.style.right.font_type = metrics_font_type
	caps_widget.style.left.font_size = FuryMeterConstants.PRESENTATION.STAT_FONT_SIZE
	caps_widget.style.right.font_size = FuryMeterConstants.PRESENTATION.STAT_FONT_SIZE
	caps_widget.style.left.offset[1] = origin_x - cap_offset_x
	caps_widget.style.left.offset[2] = origin_y
	caps_widget.style.right.offset[1] = origin_x + cap_offset_x
	caps_widget.style.right.offset[2] = origin_y
	caps_widget.content.left = cap_text
	caps_widget.content.right = cap_text

	if not callout_widget then
		return
	end

	local callout_block = FuryMeterPresentation.callout_block_height(fury_rank_font_size)
	local callout_y = bar_base_y - bar_height * 0.5 - callout_block + fury_rank_font_size * 0.5

	local callout_x
	if align_value == "right" then
		callout_x = bar_base_x + bar_width * 0.5 - callout_width * 0.5
	else
		callout_x = bar_base_x - bar_width * 0.5 + callout_width * 0.5
	end
	local callout_style = callout_widget.style.callout_text

	callout_style.font_type = fury_rank_font_type
	callout_style.font_size = fury_rank_font_size
	callout_style.size[1] = callout_width
	callout_style.text_horizontal_alignment = align_value

	callout_style.offset[1] = callout_x
	callout_style.offset[2] = callout_y
	callout_style.offset[3] = FuryMeterConstants.PRESENTATION.CALLOUT_Z

	local max_blend = self._max_fury_blend
	local base_text_color = mod.constants.COLOR.UI_FOREGROUND
	local max_fury_text_color = mod.constants.COLOR.MAX_FURY
	callout_style.text_color[1] = 255
	callout_style.text_color[2] = base_text_color[2] + (max_fury_text_color[2] - base_text_color[2]) * max_blend
	callout_style.text_color[3] = base_text_color[3] + (max_fury_text_color[3] - base_text_color[3]) * max_blend
	callout_style.text_color[4] = base_text_color[4] + (max_fury_text_color[4] - base_text_color[4]) * max_blend
	callout_widget.content.callout_text = self._callout_text

	local shadow_style = callout_widget.style.callout_shadow
	if shadow_style then
		local shadow_const = FuryMeterConstants.PRESENTATION
		shadow_style.font_type = fury_rank_font_type
		shadow_style.font_size = fury_rank_font_size
		shadow_style.size[1] = callout_width
		shadow_style.text_horizontal_alignment = align_value

		shadow_style.offset[1] = callout_x + shadow_const.CALLOUT_SHADOW_OFFSET[1]
		shadow_style.offset[2] = callout_y + shadow_const.CALLOUT_SHADOW_OFFSET[2]
		shadow_style.offset[3] = shadow_const.CALLOUT_Z - 1

		local shadow_alpha = shadow_const.CALLOUT_SHADOW_COLOR[1]
		if ComboState.at_max_fury() then
			shadow_alpha = (shadow_alpha + 60) * max_blend
		else
			shadow_alpha = shadow_const.CALLOUT_SHADOW_COLOR[1]
		end
		shadow_style.text_color[1] = shadow_alpha

		callout_widget.content.callout_shadow = self._callout_shadow_text
	end
end

HudFuryMeter.update = function(self, dt, t, ui_renderer, render_settings, input_service)

	if FuryMeterPresentation.fury_visible() then

		mod.runtime_state.rumble_t = t
		self:_update_fury_rank_callout(dt)
		self:_update_bar(dt, t)
	end

	HudFuryMeter.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudFuryMeter._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	if not FuryMeterPresentation.fury_visible() then
		return
	end

	HudFuryMeter.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudFuryMeter
