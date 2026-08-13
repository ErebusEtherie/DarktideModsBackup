
---@type mod
local mod = get_mod("dopamine")

if mod.fury_meter_presentation then
	return mod.fury_meter_presentation
end

local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local Layout = mod:core(mod.layout, "hud/layout")

local Constants = mod:core(mod.fury_meter_constants, "hud/fury_meter/constants").PRESENTATION

local math_clamp = math.clamp
local math_max = math.max
local math_floor = math.floor

local _fatigue_stat_color = {}
local _bar_layout = {}
local _statline_segments = {}

---@class FuryMeterPresentation
local FuryMeterPresentation = {}

local FURY_RANKS = {
	{ threshold = 0, key = "fury_level_D", palette_index = 1 },
	{ threshold = 20, key = "fury_level_C", palette_index = 2 },
	{ threshold = 40, key = "fury_level_B", palette_index = 3 },
	{ threshold = 60, key = "fury_level_A", palette_index = 4 },
	{ threshold = 80, key = "fury_level_S", palette_index = 5 },
}

local FURY_RANKS_OVERKILL = mod.fury_meter_constants.LOGIC.FURY_RANKS_OVERKILL

local _fill_stops = {}
for i = 1, #FURY_RANKS do
	_fill_stops[i] = { position = FURY_RANKS[i].threshold / 100, color = nil }
end

local function fury_meter_theme_id()
	return mod.dl.settings.fury_meter_theme or "ui"
end

function FuryMeterPresentation.theme_gritty()
	return fury_meter_theme_id() == "gritty"
end

function FuryMeterPresentation.theme_ui()
	return fury_meter_theme_id() == "ui"
end

function FuryMeterPresentation.fury_display_color(fury, out)
	local palette = mod.dl.settings.fury_color_palette or {}

	for i = 1, #FURY_RANKS do
		_fill_stops[i].color = palette[FURY_RANKS[i].palette_index] or Constants.STAT_VALUE_COLOR
	end

	return mod.dl.colors.gradient_color(
		math_clamp(fury / 100, 0, 1),
		_fill_stops,
		out,
		Constants.FILL_COLOR_STOP_HOLD
	)
end

function FuryMeterPresentation.overkill_stage_count()
	return #FURY_RANKS_OVERKILL - 1
end

function FuryMeterPresentation.overkill_display_color(stage, fury)
	local palette = mod.dl.settings.fury_color_palette or {}
	local rank = FURY_RANKS_OVERKILL[stage]

	if stage == #FURY_RANKS_OVERKILL - 1 then
		local max_rank = FURY_RANKS_OVERKILL[stage + 1]

		if max_rank and (fury or 0) >= max_rank.threshold then
			rank = max_rank
		end
	end

	return {
		ghost = (rank and palette[rank.palette_index - 1]) or Constants.STAT_VALUE_COLOR,
		bar = (rank and palette[rank.palette_index]) or Constants.STAT_VALUE_COLOR
	}
end

function FuryMeterPresentation.overkill_fill_fraction(stage, fury)
	local rank = FURY_RANKS_OVERKILL[stage]
	local next_rank = FURY_RANKS_OVERKILL[stage + 1]

	if not rank or not next_rank then
		return 0
	end

	local span = next_rank.threshold - rank.threshold

	if span <= 0 then
		return fury >= rank.threshold and 1 or 0
	end

	return math_clamp((fury - rank.threshold) / span, 0, 1)
end

function FuryMeterPresentation.fury_rank_font_type()
	return mod.dl.fonts.validated(mod.dl.settings.fury_rank_font_type, "rexlia")
end

function FuryMeterPresentation.fatigue_stat_value_color(fatigue_pct)
	local threshold = ComboState.config.high_fatigue_threshold_pct

	if not threshold or threshold <= 0 or fatigue_pct <= threshold then
		return Constants.STAT_VALUE_COLOR
	end

	local span = 100 - threshold

	if span <= 0 then
		return mod.dl.settings.fatigue_tint_color or Constants.STAT_VALUE_COLOR
	end

	local blend = math_clamp((fatigue_pct - threshold) / span, 0, 1)

	return mod.dl.colors.lerp_color(
		Constants.STAT_VALUE_COLOR,
		mod.dl.settings.fatigue_tint_color or Constants.STAT_VALUE_COLOR,
		blend,
		_fatigue_stat_color
	)
end

function FuryMeterPresentation.rumble_enabled()
	return mod.dl.settings.enable_rumble_global ~= false
end

function FuryMeterPresentation.fury_rumble_amp(fill_fraction, kills)
	if not FuryMeterPresentation.rumble_enabled() then
		return 0
	end

	local lockout_amplitude = ComboState.at_max_fury() and mod.constants.PULSE.AMP_VLOW or 0

	local urgency_amplitude = 0
	local threshold = Constants.FURY_URGENCY_RUMBLE_THRESHOLD

	if
		mod.dl.settings.enable_bar_rumble_on_expire ~= false
		and ComboState.active
		and threshold > 0
		and fill_fraction < threshold
		and (kills or 0) >= ComboState.minimum_combo()
	then
		urgency_amplitude = mod.constants.PULSE.AMP_VLOW * (1 - fill_fraction / threshold)
	end

	return math_max(lockout_amplitude, urgency_amplitude)
end

function FuryMeterPresentation.fury_visible()
	return Layout.fury_visible()
end

function FuryMeterPresentation.bar_align_mode()
	if Layout.fury_centered() then
		return "center"
	end

	return "slotted"
end

function FuryMeterPresentation.bar_align_value()
	if FuryMeterPresentation.bar_align_mode() == "slotted" then
		return Layout.fury_side()
	end

	return "left"
end

function FuryMeterPresentation.bar_fill_offset_x(fill_anchor, bar_center_offset_x, bar_width, segment_width)
	if fill_anchor == "left" then
		return bar_center_offset_x - bar_width * 0.5 + segment_width * 0.5
	end

	if fill_anchor == "right" then
		return bar_center_offset_x + bar_width * 0.5 - segment_width * 0.5
	end

	return bar_center_offset_x
end

function FuryMeterPresentation.callout_block_height(font_size)
	return font_size + Constants.CALLOUT_ABOVE_GAP
end

function FuryMeterPresentation.bar_layout(bar_width, bar_height)
	local out = _bar_layout

	if Layout.fury_centered() then

		out.base_y = Layout.center_offset_y()
		out.fill_anchor = "center"
		out.container_halign = "center"
		out.container_margin_x = 0
		return out
	end

	local side = Layout.fury_side()

	out.base_y = Layout.fury_bar_center_y(bar_height)
	out.fill_anchor = side
	out.container_halign = side
	out.container_margin_x = Layout.margin_x(side)
	return out
end

function FuryMeterPresentation.statline_segment_empty(stat_id)
	return not stat_id or stat_id == "" or stat_id == "none"
end

function FuryMeterPresentation.statline_segments()
	local out = _statline_segments
	out[1] = mod.dl.settings.statline_segment_1
	out[2] = mod.dl.settings.statline_segment_2
	out[3] = mod.dl.settings.statline_segment_3
	out[4] = mod.dl.settings.statline_segment_4
	return out
end

function FuryMeterPresentation.stat_label(stat_id, fallback_key)
	if stat_id == "kills_interval" then
		local interval = mod.dl.settings.statline_kpm_interval_seconds or 30
		interval = math_clamp(math_floor(interval / 5 + 0.5) * 5, 5, 60)
		return mod:localize(string.format("statline_kills_interval_label_%d", interval))
	end

	return mod:localize(fallback_key)
end

function FuryMeterPresentation.stat_segment_value(stat_id, fury_pct, fatigue_pct)
	if stat_id == "current_combo" then
		return tostring(ComboState.kills)
	elseif stat_id == "best_combo" then
		return tostring(ComboState.best_kills)
	elseif stat_id == "last_combo" then
		return tostring(ComboState.last_combo_kills)
	elseif stat_id == "total_kills" then
		return tostring(ComboState.total_kills)
	elseif stat_id == "kills_interval" then
		return tostring(ComboState.kills_in_window())
	elseif stat_id == "dps" then
		return mod.dl.str.format_compact(ComboState.dps())
	elseif stat_id == "fatigue_pct" then
		return string.format("%d%%", fatigue_pct)
	elseif stat_id == "fury_pct" then
		return string.format("%d%%", fury_pct)
	end

	return ""
end

function FuryMeterPresentation.fury_rank_key(fury_pct)
	if not fury_pct or fury_pct <= 0 then
		return nil
	end

	for i = #FURY_RANKS_OVERKILL, 1, -1 do
		local rank = FURY_RANKS_OVERKILL[i]

		if fury_pct >= rank.threshold then
			return rank.key
		end
	end

	for i = #FURY_RANKS, 1, -1 do
		local rank = FURY_RANKS[i]

		if fury_pct >= rank.threshold then
			return rank.key
		end
	end

	return nil
end

function FuryMeterPresentation.fury_rank_hud(fury_pct)
	local key = FuryMeterPresentation.fury_rank_key(fury_pct)

	if not key then
		return nil
	end

	if mod.dl.settings.enable_class_specific_fury_ranks then
		local suffix = mod.dl.archetypes.suffix(mod.dl.player.archetype_name())

		if suffix then
			local class_key = key .. "_" .. suffix
			local attempt = mod:localize(class_key)

			if attempt ~= "<" .. class_key .. ">" then
				return attempt
			end
		end
	end

	return mod:localize(key)
end

mod.fury_meter_presentation = FuryMeterPresentation

return mod.fury_meter_presentation
