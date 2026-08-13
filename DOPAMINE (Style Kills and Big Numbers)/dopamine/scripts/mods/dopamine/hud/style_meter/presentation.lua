

---@type mod
local mod = get_mod("dopamine")

if mod.style_meter_presentation then
	return mod.style_meter_presentation
end

local EventRegistry = mod:core(mod.event_registry, "utils/event/registry")
local Constants = mod:core(mod.style_meter_constants, "hud/style_meter/constants").PRESENTATION
local Layout = mod:core(mod.layout, "hud/layout")
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")

local math_clamp = math.clamp

local color_ui_foreground = mod.constants.COLOR.UI_FOREGROUND

local _pulse_color_scratch = {}

---@class StyleMeterPresentation
local StyleMeterPresentation = {}

function StyleMeterPresentation.event_font_type()

	return mod.dl.fonts.validated(mod.dl.settings.style_meter_font_type)
end

function StyleMeterPresentation.apply_widget_fonts(widgets_by_name)
	local event_font_type = StyleMeterPresentation.event_font_type()

	local event_list_widget = widgets_by_name.event_list
	if event_list_widget then
		event_list_widget.style.mult_label.font_type = event_font_type
		event_list_widget.style.mult_value.font_type = event_font_type
		for slot = 1, Constants.MAX_SLOTS do
			event_list_widget.style["slot_" .. slot].font_type = event_font_type
			event_list_widget.style["slot_" .. slot .. "_count"].font_type = event_font_type
		end
	end

	local combo_popup_widget = widgets_by_name.combo_sp_popup
	if combo_popup_widget then
		combo_popup_widget.style.combo_main.font_type = event_font_type
		combo_popup_widget.style.combo_mult.font_type = event_font_type
	end

	local sp_popup_widget = widgets_by_name.sp_popups
	if sp_popup_widget then
		sp_popup_widget.style.popup.font_type = mod.dl.fonts.reg.mono_tide_medium
	end

	local sp_counter_widget = widgets_by_name.sp_counter
	if sp_counter_widget then
		sp_counter_widget.style.sp_label.font_type = mod.dl.fonts.reg.mono_tide_medium
		sp_counter_widget.style.sp_value.font_type = mod.dl.fonts.reg.mono_tide_medium
	end
end

---@return boolean
function StyleMeterPresentation.style_enabled()
	return Layout.score_enabled()
end

function StyleMeterPresentation.layout_side()

	local side = Layout.score_side()
	local left = side == "left"

	local offset_y = Layout.score_anchor_y()

	return {
		align = side,
		left = left,
		halign = left and "left" or "right",
		root_valign = "top",
		root_offset_y = offset_y,

		root_margin_x = Layout.margin_x(side),
		text_pad_x = left and -Constants.SP_TEXT_PAD_X or Constants.SP_TEXT_PAD_X,
		exit_slide_sign = left and -1 or 1,
	}
end

function StyleMeterPresentation.apply_text_align(style, layout)
	if not style then
		return
	end

	local halign = layout.halign
	style.horizontal_alignment = halign
	style.text_horizontal_alignment = halign
end

function StyleMeterPresentation.apply_panel_align(style, layout)
	if not style then
		return
	end

	style.horizontal_alignment = layout.halign
end

function StyleMeterPresentation.apply_panel_texture_uv(style, layout)
	if not style then
		return
	end

	if not style.uvs then
		style.uvs = {
			{ 0, 0 },
			{ 1, 1 },
		}
	end

	local uvs = style.uvs
	if layout.left then
		uvs[1][1] = 1
		uvs[1][2] = 0
		uvs[2][1] = 0
		uvs[2][2] = 1
	else
		uvs[1][1] = 0
		uvs[1][2] = 0
		uvs[2][1] = 1
		uvs[2][2] = 1
	end
end

function StyleMeterPresentation.slot_y(slot_index)
	return Constants.EVENT_STACK_OFFSET_Y - (slot_index - 1) * Layout.event_slot_height()
end

function StyleMeterPresentation.multiplier_row_y()
	return StyleMeterPresentation.slot_y(mod.dl.settings.max_event_slots) - Layout.event_slot_height() - Constants.MULT_ROW_GAP
end

function StyleMeterPresentation.event_font_size()
	return Layout.event_font_size()
end

function StyleMeterPresentation.multiplier_value_max_font_size()
	return StyleMeterPresentation.event_font_size() + 16
end

function StyleMeterPresentation.multiplier_label_font_size()
	return Layout.multiplier_label_font_size()
end

function StyleMeterPresentation.event_panel_layout()
	local vertical_pad = Layout.event_panel_vertical_pad()

	local top_y = Layout.event_panel_bottom_rel()
	local mult_row_y = StyleMeterPresentation.multiplier_row_y()
	local bottom_y = mult_row_y
		- math.floor(StyleMeterPresentation.multiplier_label_font_size() * 0.5 + vertical_pad + 0.5)
	local height = top_y - bottom_y
	local center_y = bottom_y + height * 0.5

	return center_y, height
end

function StyleMeterPresentation.meter_has_events(snapshot)
	local multiplier = snapshot.target_style_mult or 1
	local base_multiplier = snapshot.style_mult_base or 1

	if multiplier > base_multiplier + 0.001 then
		return true
	end

	local events_by_slot = snapshot.events or {}

	for slot = 1, Constants.MAX_SLOTS do
		if events_by_slot[slot] then
			return true
		end
	end

	local exiting = snapshot.exiting or {}
	return #exiting > 0
end

function StyleMeterPresentation.sp_font_size()
	return Layout.sp_font_size()
end

function StyleMeterPresentation.sp_label_font_size()
	return Layout.sp_label_font_size()
end

function StyleMeterPresentation.sp_popup_font_size()
	return Layout.sp_popup_font_size()
end

function StyleMeterPresentation.sp_block_y()
	return Layout.sp_block_y()
end

function StyleMeterPresentation.sp_panel_layout()
	local block_y = StyleMeterPresentation.sp_block_y()
	local top = block_y
		+ Constants.SP_LABEL_OFFSET_Y
		- math.floor(StyleMeterPresentation.sp_label_font_size() * 0.5 + Constants.SP_PANEL_TOP_PAD)
	local bottom = block_y
		+ Constants.SP_VALUE_OFFSET_Y
		+ math.floor(StyleMeterPresentation.sp_font_size() * 0.5 + Constants.SP_PANEL_BOTTOM_PAD)
	local height = bottom - top

	return top + height * 0.5, height
end

function StyleMeterPresentation.sp_popup_offset_x()
	return Constants.SP_POPUP_OFFSET_X * (Layout.score_side() == "right" and -2 or 1)
end

function StyleMeterPresentation.sp_popup_y()
	return StyleMeterPresentation.sp_block_y()
		+ Constants.SP_VALUE_OFFSET_Y
		+ math.floor(StyleMeterPresentation.sp_font_size() * 0.5 + Constants.SP_POPUP_GAP)
end

function StyleMeterPresentation.event_name(event)
	if event.label_key then
		return mod:localize(event.label_key)
	end

	return event.label or ""
end

function StyleMeterPresentation.event_count_suffix(event)
	if event.count and event.count > 1 then
		return "x" .. tostring(event.count)
	end

	return nil
end

function StyleMeterPresentation.event_label(event, layout)
	local label = StyleMeterPresentation.event_name(event)
	local count_suffix = StyleMeterPresentation.event_count_suffix(event)
	local plus = " + "

	if layout and not layout.left then
		if count_suffix then
			return count_suffix .. " " .. label .. plus
		end

		return label .. plus
	end

	if count_suffix then
		return plus .. label .. " " .. count_suffix
	end

	return plus .. label
end

function StyleMeterPresentation.event_color(event_id)
	local definition = EventRegistry.by_id(event_id)
	return (definition and definition.color) or color_ui_foreground
end

function StyleMeterPresentation.format_sp(value)
	return mod.dl.str.format_number(value)
end

function StyleMeterPresentation.format_sp_popup(value)
	return "+" .. StyleMeterPresentation.format_sp(value) .. " SP"
end

function StyleMeterPresentation.format_combo_multiplier(multiplier)
	multiplier = multiplier or 0
	if multiplier <= 0 then
		return ""
	end

	local text = string.format("%.2f", multiplier):gsub("%.?0+$", "")
	return "×" .. text
end

function StyleMeterPresentation.format_style_multiplier(multiplier)
	multiplier = multiplier or 1
	return "×" .. string.format("%.2f", multiplier)
end

function StyleMeterPresentation.style_multiplier_label(layout)
	local text = mod:localize("style_multiplier_label")

	if layout and layout.left then
		return " " .. text
	end

	return text
end

function StyleMeterPresentation.style_multiplier_heat(multiplier, base_multiplier)
	base_multiplier = base_multiplier or 1
	local heat_span = Constants.MULT_VALUE_HEAT or 8

	if not heat_span or heat_span <= 0 then
		return 0
	end

	return math_clamp((multiplier - base_multiplier) / heat_span, 0, 1)
end

function StyleMeterPresentation.style_multiplier_value_font(multiplier)
	local heat = StyleMeterPresentation.style_multiplier_heat(multiplier)
	local min_font_size = StyleMeterPresentation.event_font_size() or StyleMeterPresentation.event_font_size()
	local max_font_size = StyleMeterPresentation.multiplier_value_max_font_size() or min_font_size

	return min_font_size + (max_font_size - min_font_size) * heat
end

function StyleMeterPresentation.style_multiplier_value_color(multiplier)
	local heat = StyleMeterPresentation.style_multiplier_heat(multiplier)
	local low_color = Constants.MULT_VALUE_COLOR_LOW or color_ui_foreground
	local high_color = Constants.MULT_VALUE_COLOR_HIGH or color_ui_foreground

	return mod.dl.colors.lerp_color(low_color, high_color, heat, _pulse_color_scratch)
end

function StyleMeterPresentation.sp_popup_anim(phase, phase_t)
	local exit_slide = Constants.EXIT_SLIDE * StyleMeterPresentation.layout_side().exit_slide_sign

	if phase == EventEnums.SP_PHASE.rise then
		local progress = math_clamp(phase_t / mod.constants.TRAN_SLIDE.T_FAST, 0, 1)
		local eased = mod.dl.animation.ease_out(progress, 2)
		return eased, Constants.SP_POPUP_RISE_DRIFT * (1 - eased), 1, 0
	end

	if phase == EventEnums.SP_PHASE.hold or phase == EventEnums.SP_PHASE.wait then
		return 1, 0, 1, 0
	end

	if phase == EventEnums.SP_PHASE.out then
		local progress = math_clamp(phase_t / mod.constants.TRAN_SLIDE.T_SLOW, 0, 1)
		local eased = mod.dl.animation.ease_in(progress, 2)
		return 1 - eased, 0, 1, exit_slide * eased
	end

	return 0, 0, 1, 0
end

function StyleMeterPresentation.combo_popup_main_anim(phase, phase_t)
	if phase == EventEnums.SP_PHASE.rise then
		return StyleMeterPresentation.sp_popup_anim(EventEnums.SP_PHASE.rise, phase_t)
	end

	if phase == EventEnums.SP_PHASE.wait then
		return StyleMeterPresentation.sp_popup_anim(EventEnums.SP_PHASE.wait, phase_t)
	end

	if phase == EventEnums.SP_PHASE.out then
		return StyleMeterPresentation.sp_popup_anim(EventEnums.SP_PHASE.out, phase_t)
	end

	return 1, 0, 1, 0
end

function StyleMeterPresentation.combo_popup_display_amount(popup)
	local earned_sp = popup.combo_earned or popup.amount or 0
	local bonus_sp = popup.sp_bonus or earned_sp
	local phase = popup.phase

	if phase == EventEnums.SP_PHASE.recap then
		local progress = math_clamp((popup.phase_t or 0) / Constants.SP_COMBO_RECAP_LERP_TIME, 0, 1)
		local eased = mod.dl.animation.ease_out(progress, 2)
		return earned_sp + (bonus_sp - earned_sp) * eased
	end

	if phase == EventEnums.SP_PHASE.out then
		return bonus_sp
	end

	return nil
end

function StyleMeterPresentation.combo_popup_mult_anim(phase, phase_t)
	if phase == EventEnums.SP_PHASE.recap or phase == EventEnums.SP_PHASE.wait then
		return 1, 0, 1, 0
	end

	if phase == EventEnums.SP_PHASE.out then
		return StyleMeterPresentation.sp_popup_anim(EventEnums.SP_PHASE.out, phase_t)
	end

	return 0, 0, 1, 0
end

mod.style_meter_presentation = StyleMeterPresentation

return mod.style_meter_presentation
