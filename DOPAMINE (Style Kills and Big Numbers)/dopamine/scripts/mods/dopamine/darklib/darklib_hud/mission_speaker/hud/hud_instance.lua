local math_clamp = math.clamp
local math_min = math.min
local math_random_range = math.random_range
local math_sin = math.sin
local math_bounce = math.bounce
local math_ease_out_exp = math.ease_out_exp

local ease_out = function(x, power)
	if x <= 0 then
		return 0
	elseif x >= 1 then
		return 1
	end

	return 1 - (1 - x) ^ (power or 2)
end

local function tune_distortion(remaining, duration)
	if duration <= 0 or remaining <= 0 then
		return 0
	end
	local progress = 1 - remaining / duration
	return math_ease_out_exp(math_bounce(progress))
end

local HudMissionSpeaker = class("DarkLibHudMissionSpeaker@" .. tostring({}), "HudElementBase")

HudMissionSpeaker.init = function(self, parent, draw_layer, start_scale, context)

	local mod = get_mod(context.mod_name)

	self.__class_name = context.class_name

	self._module = mod.dl_hud.__hud_modules["mission_speaker"]

	self._definitions = self._module.hud_definitions

	HudMissionSpeaker.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = self._definitions.scenegraph_definition,
		widget_definitions = self._definitions.widget_definitions,
	})

	self._anim = 0

	self._visibility_mult = 1

	self._sub_anim = 0

	self._panel_anim = 0

	self._visible_state = false
	self._state_t = math.huge

	self._tune_t = 0

	self._static_t = 0
	self._bar_timer = 0
	self._current_speaker_id = nil

	self._side = nil

	self._bar_widgets = {}
	for i = 1, self._module.constants.PRESENTATION.BAR_AMOUNT do
		self._bar_widgets[i] = self._widgets_by_name["bar_" .. i]
	end
end

HudMissionSpeaker._resolve_side = function(self)

	local _module = self._module

	return _module.presentation_manager.alignment_side()
end

HudMissionSpeaker._apply_side_layout = function(self, side)

	local _module = self._module
	local _presentation_manager = _module.presentation_manager
	local _constants = _module.constants

	local flipped = side == "left"
	local mirror = flipped and -1 or 1
	local widgets = self._widgets_by_name

	widgets.popup.style.frame.horizontal_alignment = flipped and "left" or "right"
	widgets.popup.style.portrait.offset[1] = flipped and _constants.PRESENTATION.PORTRAIT_NUDGE_X.LEFT
		or _constants.PRESENTATION.PORTRAIT_NUDGE_X.RIGHT

	local text_x = _presentation_manager.text_offset_x() * mirror
	for _, key in ipairs({ "title_text", "name_text" }) do
		local style = widgets[key].style[key]
		style.horizontal_alignment = flipped and "left" or "right"
		style.text_horizontal_alignment = flipped and "left" or "right"
		style.offset[1] = text_x
	end

	local subtitle_style = widgets.subtitle.style.subtitle
	subtitle_style.horizontal_alignment = flipped and "left" or "right"
	subtitle_style.text_horizontal_alignment = flipped and "left" or "right"

	local radio_style = widgets.radio.style.soundwave
	radio_style.horizontal_alignment = flipped and "right" or "left"
	radio_style.offset[1] = _constants.PRESENTATION.RADIO_OFFSET[1] * mirror

	for i = 1, _constants.PRESENTATION.BAR_AMOUNT do
		local bar_x = _presentation_manager.bar_offset_x(i) * mirror
		local bar_style = self._bar_widgets[i].style
		bar_style.background.offset[1] = bar_x
		bar_style.bar.offset[1] = bar_x
		bar_style.frame.offset[1] = bar_x
	end

	self._side = side
end

HudMissionSpeaker._apply_speaker = function(self, speaker_id)

	local _module = self._module
	local _constants = _module.constants

	local resolved = _module.manager.resolve_speaker(speaker_id)
	local widgets = self._widgets_by_name

	widgets.popup.style.portrait.material_values.main_texture = resolved.icon

	local name_text = resolved.full_name and self:_localize(resolved.full_name) or ""
	widgets.name_text.content.name_text = name_text

	self._current_speaker_id = speaker_id
	self._tune_t = _constants.PRESENTATION.TUNE_TIME
end

HudMissionSpeaker._update_bars = function(self, dt)

	local _module = self._module
	local _constants = _module.constants

	self._bar_timer = self._bar_timer - dt
	if self._bar_timer > 0 then
		return
	end
	self._bar_timer = _constants.PRESENTATION.BAR_TICK

	local bar_widgets = self._bar_widgets
	local num_bars = #bar_widgets
	local bar_height = _constants.PRESENTATION.BAR_SIZE[2]
	local anim_progress =
		math_min((1 + math_sin(Application.time_since_launch() * 6) * 0.5) * math_random_range(0.3, 0.8), 1)

	for i = num_bars, 1, -1 do
		local new_bar_height

		if i > 1 then
			new_bar_height = bar_widgets[i - 1].style.bar.size[2]
		else
			new_bar_height = bar_height * anim_progress
		end

		bar_widgets[i].style.bar.size[2] = new_bar_height
	end
end

HudMissionSpeaker.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudMissionSpeaker.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local _module = self._module
	local _constants = _module.constants
	local _presentation_manager = _module.presentation_manager

	local side = self:_resolve_side()
	if side ~= self._side then
		self:_apply_side_layout(side)
	end
	local flipped = side == "left"

	local speaker_id = _module.manager.current_id()
	if speaker_id ~= self._current_speaker_id then
		self:_apply_speaker(speaker_id)
	end

	local visible = _module.manager.is_visible()
	if visible ~= self._visible_state then
		self._visible_state = visible
		self._state_t = 0
		self._static_t = _constants.PRESENTATION.VISIBLE_STATIC_TIME
	end
	self._state_t = self._state_t + dt

	local portrait_target = (visible or self._state_t < _constants.PRESENTATION.PANEL_OUT_DELAY) and 1 or 0
	local speed = portrait_target == 1 and _constants.PRESENTATION.ANIM_IN_SPEED
		or _constants.PRESENTATION.ANIM_OUT_SPEED
	self._anim = math_clamp(self._anim + (portrait_target - self._anim) * math_clamp(dt * speed, 0, 1), 0, 1)

	local panel_target = (visible and self._state_t >= _constants.PRESENTATION.PANEL_IN_DELAY) and 1 or 0
	local panel_speed = panel_target == 1 and _constants.PRESENTATION.ANIM_IN_SPEED
		or _constants.PRESENTATION.ANIM_OUT_SPEED
	self._panel_anim =
		math_clamp(self._panel_anim + (panel_target - self._panel_anim) * math_clamp(dt * panel_speed, 0, 1), 0, 1)

	local suppressed = _module.manager.is_game_speaker_active()
	local vis_target = suppressed and 0 or 1
	local vis_speed = suppressed and _constants.PRESENTATION.SUPPRESS_OUT_SPEED
		or _constants.PRESENTATION.SUPPRESS_IN_SPEED
	self._visibility_mult = math_clamp(
		self._visibility_mult + (vis_target - self._visibility_mult) * math_clamp(dt * vis_speed, 0, 1),
		0,
		1
	)

	local eased = ease_out(self._anim, 2)
	local portrait_alpha = eased * self._visibility_mult
	local panel_eased = ease_out(self._panel_anim, 2)
	local panel_alpha = panel_eased * self._visibility_mult

	local edge_align = flipped and "left" or "right"
	local rest_x = flipped and -_constants.PRESENTATION.MARGIN_X or _constants.PRESENTATION.MARGIN_X
	local slide_sign = flipped and -1 or 1
	local slide_x = rest_x + slide_sign * (1 - eased) * _constants.PRESENTATION.SLIDE_DISTANCE
	self:set_scenegraph_position(
		"missionSpeakerContainer",
		slide_x,
		_presentation_manager.offset_y(),
		_constants.PRESENTATION.Z,
		edge_align,
		"top"
	)

	if self._tune_t > 0 then
		self._tune_t = math.max(0, self._tune_t - dt)
	end

	if self._static_t > 0 then
		self._static_t = math.max(0, self._static_t - dt)
	end
	local distortion = math.max(
		tune_distortion(self._tune_t, _constants.PRESENTATION.TUNE_TIME),
		tune_distortion(self._static_t, _constants.PRESENTATION.VISIBLE_STATIC_TIME)
	)
	self._widgets_by_name.popup.style.portrait.material_values.distortion = distortion

	for key, widget in pairs(self._widgets_by_name) do
		if key == "popup" then
			widget.alpha_multiplier = portrait_alpha
		elseif key ~= "subtitle" then
			widget.alpha_multiplier = panel_alpha
		end
	end

	self:_update_subtitle(dt)

	if visible then
		self:_update_bars(dt)
	end
end

HudMissionSpeaker._update_subtitle = function(self, dt)
	local widget = self._widgets_by_name.subtitle
	if not widget then
		return
	end

	local _module = self._module
	local _constants = _module.constants

	local subtitle = _module.manager.subtitle()
	local has_subtitle = subtitle ~= nil and subtitle ~= ""
	local shown = self._visible_state and has_subtitle and self._state_t >= _constants.PRESENTATION.PANEL_IN_DELAY
	local target = shown and 1 or 0
	local speed = target == 1 and _constants.PRESENTATION.SUBTITLE_IN_SPEED
		or _constants.PRESENTATION.SUBTITLE_OUT_SPEED
	self._sub_anim = math_clamp(self._sub_anim + (target - self._sub_anim) * math_clamp(dt * speed, 0, 1), 0, 1)

	local eased = ease_out(self._sub_anim, 2)

	widget.content.subtitle = subtitle or ""
	widget.style.subtitle.offset[2] = _constants.PRESENTATION.SUBTITLE_OFFSET_Y
		+ (1 - eased) * _constants.PRESENTATION.SUBTITLE_SLIDE

	widget.alpha_multiplier = eased * self._visibility_mult
end

HudMissionSpeaker._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)

	local _module = self._module

	if self._anim <= 0.001 and not _module.manager.is_visible() then
		return
	end

	if self._visibility_mult <= 0.001 then
		return
	end

	HudMissionSpeaker.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudMissionSpeaker
