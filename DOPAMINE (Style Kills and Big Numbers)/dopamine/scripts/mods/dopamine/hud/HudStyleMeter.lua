

---@type mod
local mod = get_mod("dopamine")

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local StyleMeterPresentation = mod:core(mod.style_meter_presentation, "hud/style_meter/presentation")
local Constants = mod:core(mod.constants, "hud/constants")
local StyleMeterConstants = mod:core(mod.style_meter_constants, "hud/style_meter/constants").PRESENTATION
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")
local Rumble = mod:core(mod.rumble, "utils/rumble")

local Definitions = mod:io_dofile("dopamine/scripts/mods/dopamine/hud/style_meter/definitions")

local math_clamp = math.clamp
local math_floor = math.floor
local math_max = math.max

local color_ui_foreground = mod.constants.COLOR.UI_FOREGROUND
local color_numbers_green = mod.constants.COLOR.NUMBERS.GREEN
local color_numbers_green_muted = mod.constants.COLOR.NUMBERS.GREEN_MUTED

local HudStyleMeter = class("HudStyleMeter", "HudElementBase")

HudStyleMeter.init = function(self, parent, draw_layer, start_scale)
	HudStyleMeter.super.init(self, parent, draw_layer + Constants.HUD_Z_BOOST, start_scale, {
		scenegraph_definition = Definitions.scenegraph_definition,
		widget_definitions = Definitions.widget_definitions,
	})

	self._display_sp = 0
	self._display_style_mult = 1
	self._mult_at_base_timer = 0
	self._mult_row_alpha = 1

	self._mult_bar_alpha = 0
	self._slot_enter_timer = {}
	self._slot_previous_event_id = {}
	self._slot_slide_y = {}
	self._popup_display_amount = 0
	self._combo_display_amount = 0
	self._combo_display_seeded = false

	for slot = 1, StyleMeterConstants.MAX_SLOTS do
		self._slot_enter_timer[slot] = 0
		self._slot_previous_event_id[slot] = nil
		self._slot_slide_y[slot] = StyleMeterPresentation.slot_y(slot)
	end

	self._event_panel_alpha = 0
end

local function hide_text_pass(style)
	style.text_color[1] = 0
end

local function set_text_pass(style, alpha, offset_x, offset_y, scale, color, font_size)
	font_size = font_size or StyleMeterPresentation.event_font_size()
	color = color or color_ui_foreground
	style.text_color[1] = math_floor(255 * math_clamp(alpha, 0, 1))
	style.text_color[2] = color[2] or 255
	style.text_color[3] = color[3] or 255
	style.text_color[4] = color[4] or 255
	style.offset[1] = offset_x or 0
	style.offset[2] = offset_y or 0
	style.font_size = math_floor(font_size * (scale or 1))
end

local function find_exiting_at_slot(exiting, slot_index)
	for i = 1, #exiting do
		local event = exiting[i]
		if event.slot_hint == slot_index then
			return event
		end
	end

	return nil
end

HudStyleMeter._apply_side_layout = function(self, layout, rumble_x, rumble_y)
	self:set_scenegraph_position(
		"styleMeterRoot",
		layout.root_margin_x + (rumble_x or 0),
		layout.root_offset_y + (rumble_y or 0),
		19,
		layout.halign,
		layout.root_valign
	)

	local event_list_widget = self._widgets_by_name.event_list
	if event_list_widget then
		StyleMeterPresentation.apply_text_align(event_list_widget.style.mult_label, layout)
		StyleMeterPresentation.apply_text_align(event_list_widget.style.mult_value, layout)
		for slot = 1, StyleMeterConstants.MAX_SLOTS do
			StyleMeterPresentation.apply_text_align(event_list_widget.style["slot_" .. slot], layout)
			StyleMeterPresentation.apply_text_align(event_list_widget.style["slot_" .. slot .. "_count"], layout)
		end
	end

	local sp_counter_widget = self._widgets_by_name.sp_counter
	if sp_counter_widget then
		StyleMeterPresentation.apply_text_align(sp_counter_widget.style.sp_label, layout)
		StyleMeterPresentation.apply_text_align(sp_counter_widget.style.sp_value, layout)
	end

	local sp_panel_widget = self._widgets_by_name.sp_panel
	if sp_panel_widget then
		StyleMeterPresentation.apply_panel_align(sp_panel_widget.style.background, layout)
		StyleMeterPresentation.apply_panel_texture_uv(sp_panel_widget.style.background, layout)
		StyleMeterPresentation.apply_panel_align(sp_panel_widget.style.border_right, layout)
	end

	local event_panel_widget = self._widgets_by_name.event_panel
	if event_panel_widget then
		StyleMeterPresentation.apply_panel_align(event_panel_widget.style.background, layout)
		StyleMeterPresentation.apply_panel_texture_uv(event_panel_widget.style.background, layout)
	end

	local sp_popup_widget = self._widgets_by_name.sp_popups
	if sp_popup_widget then
		StyleMeterPresentation.apply_text_align(sp_popup_widget.style.popup, layout)
	end

	local combo_popup_widget = self._widgets_by_name.combo_sp_popup
	if combo_popup_widget then
		StyleMeterPresentation.apply_text_align(combo_popup_widget.style.combo_main, layout)
		StyleMeterPresentation.apply_text_align(combo_popup_widget.style.combo_mult, layout)
	end
end

HudStyleMeter._update_multiplier = function(self, dt, snapshot, layout, ui_renderer)
	local event_list_widget = self._widgets_by_name.event_list
	if not event_list_widget then
		return
	end

	local styles = event_list_widget.style
	local content = event_list_widget.content
	local target_mult = snapshot.target_style_mult or 1
	local base_mult = snapshot.style_mult_base or 1
	local lerp_speed = StyleMeterConstants.MULT_LERP_TIME > 0 and (1 / StyleMeterConstants.MULT_LERP_TIME) or 10

	self._display_style_mult = self._display_style_mult
		+ (target_mult - self._display_style_mult) * math_clamp(dt * lerp_speed, 0, 1)

	local at_base = target_mult <= base_mult + 0.001
	if at_base then
		self._mult_at_base_timer = self._mult_at_base_timer + dt
	else
		self._mult_at_base_timer = 0
	end

	local row_alpha_target = 1
	if self._mult_at_base_timer > StyleMeterConstants.MULT_AT_BASE_HOLD then
		row_alpha_target = 0
	end

	self._mult_row_alpha = self._mult_row_alpha
		+ (row_alpha_target - self._mult_row_alpha) * math_clamp(dt * StyleMeterConstants.MULT_ROW_FADE_SPEED, 0, 1)
	local row_alpha = self._mult_row_alpha

	local label_text = StyleMeterPresentation.style_multiplier_label(layout)
	local value_text = StyleMeterPresentation.format_style_multiplier(self._display_style_mult)
	if not layout.left then
		value_text = value_text .. " "
	end
	local row_y = StyleMeterPresentation.multiplier_row_y()
	local value_font_size = StyleMeterPresentation.style_multiplier_value_font(self._display_style_mult)
	local value_color = StyleMeterPresentation.style_multiplier_value_color(self._display_style_mult)
	local inline_gap = math.floor(6 * StyleMeterConstants.UI_SCALE + 0.5)
	local label_width = 0
	local value_width = 0

	if ui_renderer then
		label_width = UIRenderer.text_size(
			ui_renderer,
			label_text,
			styles.mult_label.font_type,
			StyleMeterPresentation.multiplier_label_font_size(),
			styles.mult_label.size
		)
		value_width = UIRenderer.text_size(
			ui_renderer,
			value_text,
			styles.mult_value.font_type,
			math_floor(value_font_size),
			styles.mult_value.size
		)
	end

	local label_x
	local value_x

	if layout.left then
		styles.mult_label.horizontal_alignment = "left"
		styles.mult_label.text_horizontal_alignment = "left"
		styles.mult_value.horizontal_alignment = "left"
		styles.mult_value.text_horizontal_alignment = "left"
		label_x = 0
		value_x = label_width + inline_gap + 12
	else
		styles.mult_label.horizontal_alignment = "right"
		styles.mult_label.text_horizontal_alignment = "right"
		styles.mult_value.horizontal_alignment = "right"
		styles.mult_value.text_horizontal_alignment = "right"
		value_x = 0
		label_x = -(value_width + inline_gap) - 12
	end

	set_text_pass(
		styles.mult_label,
		row_alpha,
		label_x,
		row_y,
		1,
		color_ui_foreground,
		StyleMeterPresentation.multiplier_label_font_size()
	)
	set_text_pass(styles.mult_value, row_alpha, value_x, row_y, pulse_scale, value_color, value_font_size)

	content.mult_label = label_text
	content.mult_value = value_text

	self:_update_multiplier_bar(dt, snapshot, layout, row_y, value_font_size)
end

HudStyleMeter._update_multiplier_bar = function(self, dt, snapshot, layout, row_y, value_font_size)
	local event_list_widget = self._widgets_by_name.event_list
	local styles = event_list_widget.style
	local track_style = styles.mult_bar_track
	local fill_style = styles.mult_bar_fill

	if not track_style or not fill_style then
		return
	end

	local target_alpha = snapshot.bonus_mult_active and 1 or 0
	self._mult_bar_alpha = self._mult_bar_alpha
		+ (target_alpha - self._mult_bar_alpha) * math_clamp(dt * StyleMeterConstants.MULT_BAR_FADE_SPEED, 0, 1)

	local bar_alpha = self._mult_bar_alpha

	bar_alpha = bar_alpha * self._mult_row_alpha

	if bar_alpha <= 0.001 then
		track_style.color[1] = 0
		fill_style.color[1] = 0
		return
	end

	local full_width = StyleMeterConstants.MULT_BAR_WIDTH
	local fill_width = full_width * math_clamp(snapshot.bonus_mult_fraction or 0, 0, 1)

	local bar_y = row_y + value_font_size * 0.5 + StyleMeterConstants.MULT_BAR_GAP

	local align = layout.left and "left" or "right"
	track_style.horizontal_alignment = align
	fill_style.horizontal_alignment = align

	track_style.size[1] = full_width
	track_style.offset[1] = align == "left" and 12 or -12
	track_style.offset[2] = bar_y
	track_style.color[1] = StyleMeterConstants.MULT_BAR_TRACK_ALPHA * bar_alpha

	fill_style.size[1] = fill_width
	fill_style.offset[1] = align == "left" and 12 or -12
	fill_style.offset[2] = bar_y
	fill_style.color[1] = 255 * bar_alpha
end

HudStyleMeter._update_event_list = function(self, dt, snapshot, layout)
	local event_list_widget = self._widgets_by_name.event_list
	local styles = event_list_widget.style
	local content = event_list_widget.content
	local events_by_slot = snapshot.events or {}
	local exiting = snapshot.exiting or {}

	for slot = 1, StyleMeterConstants.MAX_SLOTS do
		local slot_style = styles["slot_" .. slot]
		local count_style = styles["slot_" .. slot .. "_count"]
		local target_y = StyleMeterPresentation.slot_y(slot)
		local active_event = events_by_slot[slot]
		local exiting_event = find_exiting_at_slot(exiting, slot)
		local render_event

		if exiting_event and active_event and exiting_event.id ~= active_event.id then
			render_event = exiting_event
		else
			render_event = exiting_event or active_event
		end

		if render_event then
			local render_label = StyleMeterPresentation.event_label(render_event, layout)
			local event_id = render_event.id
			if self._slot_previous_event_id[slot] ~= event_id then

				local transferred = false
				if active_event and not exiting_event then
					for other_slot = 1, StyleMeterConstants.MAX_SLOTS do
						if other_slot ~= slot and self._slot_previous_event_id[other_slot] == event_id then
							self._slot_slide_y[slot] = self._slot_slide_y[other_slot]
							self._slot_enter_timer[slot] = 0
							transferred = true
							break
						end
					end
				end
				if not transferred then
					self._slot_enter_timer[slot] = mod.constants.TRAN_SLIDE.T_FAST
				end
				self._slot_previous_event_id[slot] = event_id
			end

			if self._slot_enter_timer[slot] > 0 then
				self._slot_enter_timer[slot] = math.max(0, self._slot_enter_timer[slot] - dt)
			end

			self._slot_slide_y[slot] = self._slot_slide_y[slot]
				+ (target_y - self._slot_slide_y[slot])
					* math_clamp(dt / math.max(mod.constants.TRAN_SLIDE.T_FAST, 0.001), 0, 1)

			local offset_y = self._slot_slide_y[slot]
			local offset_x = 0
			local alpha = 1
			local scale = 1
			local color = StyleMeterPresentation.event_color(event_id)

			local enter_progress = 1 - math_clamp(self._slot_enter_timer[slot] / mod.constants.TRAN_SLIDE.T_FAST, 0, 1)
			if enter_progress < 1 and not exiting_event then
				offset_y = offset_y + StyleMeterConstants.ENTER_OFFSET_Y * (1 - mod.dl.animation.ease_out(enter_progress, 2))
				alpha = alpha * mod.dl.animation.ease_out(enter_progress, 2)
			end

			if exiting_event then
				local exit_progress = math_clamp(exiting_event.phase_t / mod.constants.TRAN_SLIDE.T_FAST, 0, 1)

				if exiting_event.phase == EventEnums.EVENT_PHASE.exit_evict then
					offset_y = offset_y + StyleMeterConstants.EXIT_EVICT_DROP_Y * mod.dl.animation.ease_in(exit_progress, 2)
					alpha = alpha * (1 - exit_progress)
				else
					offset_x = StyleMeterConstants.EXIT_SLIDE
						* layout.exit_slide_sign
						* mod.dl.animation.ease_in(exit_progress, 2)
					alpha = alpha * (1 - exit_progress)
				end
			elseif active_event and active_event.pulse_t > 0 then
				scale = mod.dl.animation.pop_scale(
					mod.constants.PULSE.T - active_event.pulse_t,
					mod.constants.PULSE.T,
					0.15
				)
			end

			set_text_pass(slot_style, alpha, offset_x, offset_y, scale, color, StyleMeterPresentation.event_font_size())
			content["slot_" .. slot] = render_label
			hide_text_pass(count_style)
			content["slot_" .. slot .. "_count"] = ""
		else
			hide_text_pass(slot_style)
			hide_text_pass(count_style)
			content["slot_" .. slot] = ""
			content["slot_" .. slot .. "_count"] = ""
			self._slot_previous_event_id[slot] = nil
			self._slot_slide_y[slot] = self._slot_slide_y[slot]
				+ (target_y - self._slot_slide_y[slot]) * math_clamp(dt * 10, 0, 1)
		end
	end
end

HudStyleMeter._update_event_panel = function(self, dt, snapshot)
	local event_panel_widget = self._widgets_by_name.event_panel
	if not event_panel_widget then
		return
	end

	local style = event_panel_widget.style.background
	local panel_center_y, panel_height = StyleMeterPresentation.event_panel_layout()
	local base_alpha = StyleMeterConstants.EVENT_PANEL_BG_COLOR[1]

	local target_alpha = (StyleMeterPresentation.meter_has_events(snapshot) or ComboState.fury > 0) and 1 or 0.5
	self._event_panel_alpha = self._event_panel_alpha
		+ (target_alpha - self._event_panel_alpha) * math_clamp(dt * StyleMeterConstants.EVENT_PANEL_FADE_SPEED, 0, 1)

	style.offset[1] = 0
	style.offset[2] = panel_center_y
	style.size[1] = StyleMeterConstants.EVENT_PANEL_WIDTH
	style.size[2] = panel_height
	style.color[1] = base_alpha
	event_panel_widget.alpha_multiplier = self._event_panel_alpha
end

HudStyleMeter._update_sp_counter = function(self, dt, snapshot, layout)
	local sp_counter_widget = self._widgets_by_name.sp_counter
	local styles = sp_counter_widget.style
	local target_sp = snapshot.target_sp or 0

	self._display_sp = self._display_sp
		+ (target_sp - self._display_sp) * math_clamp(dt * StyleMeterConstants.SP_LERP_SPEED, 0, 1)

	local sp_y = StyleMeterPresentation.sp_block_y()

	styles.sp_label.offset[1] = layout.text_pad_x
	styles.sp_label.offset[2] = sp_y + StyleMeterConstants.SP_LABEL_OFFSET_Y - 2
	styles.sp_label.font_size = math_floor(StyleMeterPresentation.sp_label_font_size())
	styles.sp_value.offset[1] = layout.text_pad_x
	styles.sp_value.offset[2] = sp_y + StyleMeterConstants.SP_VALUE_OFFSET_Y
	styles.sp_value.font_size = math_floor(StyleMeterPresentation.sp_font_size())
	styles.sp_value.text_color[1] = 255

	local sp_panel_widget = self._widgets_by_name.sp_panel
	if sp_panel_widget then
		local panel_center_y, panel_height = StyleMeterPresentation.sp_panel_layout()
		local panel_styles = sp_panel_widget.style

		panel_styles.background.offset[1] = 0
		panel_styles.background.offset[2] = panel_center_y
		panel_styles.background.size[1] = StyleMeterConstants.SP_PANEL_WIDTH
		panel_styles.background.size[2] = panel_height
		panel_styles.border_right.offset[1] = 0
		panel_styles.border_right.offset[2] = panel_center_y
		panel_styles.border_right.size[1] = 4
		panel_styles.border_right.size[2] = panel_height
	end

	sp_counter_widget.content.sp_value = StyleMeterPresentation.format_sp(self._display_sp)
end

HudStyleMeter._meter_rumble_offset = function(self, t, snapshot)
	local period = mod.constants.PULSE.T
	local event_envelope = period > 0 and math_clamp((snapshot.event_rumble_pulse or 0) / period, 0, 1) or 0
	local event_amplitude = (snapshot.event_rumble_amp or 0) * event_envelope

	local amplitude = math_max(Rumble.common_amp(), event_amplitude)
	if amplitude <= 0 then
		return 0, 0
	end

	return mod.dl.animation.rumble(t, amplitude)
end

HudStyleMeter._update_sp_popups = function(self, dt, snapshot)
	local sp_popup_widget = self._widgets_by_name.sp_popups
	local style = sp_popup_widget.style.popup
	local content = sp_popup_widget.content
	local popup = snapshot.sp_popup
	local base_y = StyleMeterPresentation.sp_popup_y()
	local base_x = StyleMeterPresentation.sp_popup_offset_x()

	if snapshot.combo_popup or not popup then
		hide_text_pass(style)
		content.popup = ""
		self._popup_display_amount = 0
		return
	end

	local display_amount = self._popup_display_amount or 0
	display_amount = display_amount
		+ (popup.amount - display_amount) * math_clamp(dt * StyleMeterConstants.SP_POPUP_AMOUNT_LERP_SPEED, 0, 1)
	self._popup_display_amount = display_amount

	local popup_text = StyleMeterPresentation.format_sp_popup(display_amount)
	local alpha, drift_y, scale, drift_x = StyleMeterPresentation.sp_popup_anim(popup.phase, popup.phase_t)

	set_text_pass(
		style,
		alpha,
		base_x + drift_x,
		base_y + drift_y,
		scale,
		color_numbers_green,
		StyleMeterPresentation.sp_popup_font_size()
	)
	content.popup = popup_text
end

HudStyleMeter._update_combo_sp_popup = function(self, dt, snapshot, layout, ui_renderer)
	local combo_popup_widget = self._widgets_by_name.combo_sp_popup
	if not combo_popup_widget then
		return
	end

	local styles = combo_popup_widget.style
	local content = combo_popup_widget.content
	local popup = snapshot.combo_popup
	local base_y = StyleMeterPresentation.sp_popup_y()
	local line_gap = StyleMeterConstants.SP_COMBO_RECAP_LINE_GAP
	local sp_popup_font = StyleMeterPresentation.sp_popup_font_size()

	if not popup then
		hide_text_pass(styles.combo_main)
		hide_text_pass(styles.combo_mult)
		content.combo_main = ""
		content.combo_mult = ""
		self._combo_display_amount = 0
		self._combo_display_seeded = false
		return
	end

	if not self._combo_display_seeded then
		if popup.seed_display then
			self._combo_display_amount = popup.seed_display
		end
		self._combo_display_seeded = true
	end

	local fixed_display_amount = StyleMeterPresentation.combo_popup_display_amount(popup)
	local display_amount

	if fixed_display_amount then
		display_amount = fixed_display_amount
		self._combo_display_amount = display_amount
	else
		display_amount = self._combo_display_amount or 0
		display_amount = display_amount
			+ (popup.amount - display_amount) * math_clamp(dt * StyleMeterConstants.SP_POPUP_AMOUNT_LERP_SPEED, 0, 1)
		self._combo_display_amount = display_amount
	end

	local main_alpha, main_drift_y, main_scale, main_drift_x =
		StyleMeterPresentation.combo_popup_main_anim(popup.phase, popup.phase_t)
	local mult_alpha, mult_drift_y, mult_scale, mult_drift_x =
		StyleMeterPresentation.combo_popup_mult_anim(popup.phase, popup.phase_t)

	local main_text = StyleMeterPresentation.format_sp_popup(display_amount)
	local mult_text = StyleMeterPresentation.format_combo_multiplier(popup.multiplier)
	local text_pad_x = layout and layout.text_pad_x or 0
	local main_x = main_drift_x + text_pad_x + StyleMeterPresentation.sp_popup_offset_x()
	local main_y = base_y + main_drift_y
	local mult_x = mult_drift_x + text_pad_x + StyleMeterPresentation.sp_popup_offset_x()

	local inline_mult = mult_text ~= "" and ui_renderer ~= nil
	if inline_mult then
		if layout and layout.left then
			local main_font_size = math_floor(sp_popup_font * main_scale)
			local main_text_width = UIRenderer.text_size(
				ui_renderer,
				main_text,
				styles.combo_main.font_type,
				main_font_size,
				styles.combo_main.size
			)
			mult_x = main_x + main_text_width + StyleMeterConstants.SP_COMBO_INLINE_GAP
		else
			local mult_font_size = math_floor(StyleMeterConstants.SP_COMBO_MULT_FONT_SIZE * mult_scale)
			local mult_text_width = UIRenderer.text_size(
				ui_renderer,
				mult_text,
				styles.combo_mult.font_type,
				mult_font_size,
				styles.combo_mult.size
			)
			main_x = mult_x - mult_text_width - StyleMeterConstants.SP_COMBO_INLINE_GAP
		end
	end

	set_text_pass(styles.combo_main, main_alpha, main_x, main_y, main_scale, color_numbers_green, sp_popup_font)
	set_text_pass(
		styles.combo_mult,
		mult_alpha,
		mult_x,
		inline_mult and main_y or base_y + line_gap + mult_drift_y,
		mult_scale,
		color_numbers_green_muted,
		StyleMeterConstants.SP_COMBO_MULT_FONT_SIZE
	)

	content.combo_main = main_text
	content.combo_mult = mult_text
end

HudStyleMeter.update = function(self, dt, t, ui_renderer, render_settings, input_service)

	if not StyleMeterPresentation.style_enabled() then
		HudStyleMeter.super.update(self, dt, t, ui_renderer, render_settings, input_service)
		return
	end

	local snapshot = EventManager.snapshot()
	local layout = StyleMeterPresentation.layout_side()
	local rumble_x, rumble_y = self:_meter_rumble_offset(t, snapshot)

	self:_apply_side_layout(layout, rumble_x, rumble_y)
	StyleMeterPresentation.apply_widget_fonts(self._widgets_by_name)

	local event_list_widget = self._widgets_by_name.event_list
	local sp_counter_widget = self._widgets_by_name.sp_counter
	local sp_panel_widget = self._widgets_by_name.sp_panel
	local sp_popup_widget = self._widgets_by_name.sp_popups
	local combo_popup_widget = self._widgets_by_name.combo_sp_popup

	event_list_widget.alpha_multiplier = 1
	if sp_panel_widget then
		sp_panel_widget.alpha_multiplier = 1
	end
	sp_counter_widget.alpha_multiplier = 1
	sp_popup_widget.alpha_multiplier = 1
	if combo_popup_widget then
		combo_popup_widget.alpha_multiplier = 1
	end

	self:_update_event_panel(dt, snapshot)
	self:_update_multiplier(dt, snapshot, layout, ui_renderer)
	self:_update_event_list(dt, snapshot, layout)
	self:_update_sp_counter(dt, snapshot, layout)
	self:_update_sp_popups(dt, snapshot)
	self:_update_combo_sp_popup(dt, snapshot, layout, ui_renderer)

	HudStyleMeter.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudStyleMeter._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	if not StyleMeterPresentation.style_enabled() then
		return
	end

	HudStyleMeter.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudStyleMeter
