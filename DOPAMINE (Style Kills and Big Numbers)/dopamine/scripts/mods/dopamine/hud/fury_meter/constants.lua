

---@type mod
local mod = get_mod("dopamine")

if mod.fury_meter_constants then
	return mod.fury_meter_constants
end

---@class FuryMeterConstants
local FuryMeterConstants = {
	LOGIC = {

		FURY_RANKS_OVERKILL = {
			{ threshold = 100, key = "fury_level_SS", palette_index = 6 },
			{ threshold = 133, key = "fury_level_SSS", palette_index = 7 },
			{ threshold = 166, key = "fury_level_X", palette_index = 8 },
			{ threshold = 200, key = "fury_level_XX", palette_index = 9 },
		},

		DAMAGE_PENALTY_THROTTLE = 0.75,

		DAMAGE_GAIN_THROTTLE = 0.15,

		LOW_FURY_DRAIN_RATE_REDUCTION_THRESHOLD_PCT = 25,

		LOW_FURY_DRAIN_RATE_REDUCTION_MAX_PCT = 25,

		MINIMUM_DAMAGE_FOR_FURY = 50,
	},
	PRESENTATION = {

		STAT_FONT_SIZE = 16, 
		CALLOUT_FONT_SIZE = 46,

		TEX_GRIT = "content/ui/materials/frames/masteries/panel_main_lower_frame",
		TEX_FILL = "content/ui/materials/hud/backgrounds/default_square",
		TEX_SHADOW = "content/ui/materials/frames/inner_shadow_medium",
		TEX_HIGHLIGHT = "content/ui/materials/scrollbars/scrollbar_metal_highlight",

		UI_BG_EMPTY = { 75, 0, 0, 0 }, 
		GRITTY_BG = { 175, 0, 0, 0 }, 
		GRITTY_FRAME_COLOR = { 235, 205, 205, 205 }, 
		GRITTY_SHADOW_COLOR = { 190, 70, 70, 70 }, 
		GRITTY_HIGHLIGHT_COLOR = { 90, 255, 255, 255 }, 
		CAP_TEXT_COLOR = { 255, 200, 200, 200 }, 
		STAT_VALUE_COLOR = { 255, 255, 255, 255 },

		UI_FRAME_H = 2, 
		UI_FRAME_TICK_W = 2, 
		UI_FRAME_TICK_DROP = 3, 
		UI_FRAME_ABOVE = 5,

		DEFAULT_BAR_WIDTH = 450, 
		DEFAULT_BAR_HEIGHT = 8, 
		STAT_ROW_HEIGHT = 24, 
		SEPARATOR_WIDTH = 8, 
		STATLINE_GAP = 4, 
		CALLOUT_ABOVE_GAP = 13, 
		CALLOUT_Z = 10,

		CALLOUT_SHADOW_ENABLE = true, 
		CALLOUT_SHADOW_OFFSET = { 2, 2 }, 
		CALLOUT_SHADOW_COLOR = { 60, 0, 5, 0 },

		CALLOUT_SHADOW_MAX_FURY_ONLY = false,

		STAT_SEGMENT_LAYOUT = {
			current_combo = { label_key = "statline_combo_label", label_width = 62, value_width = 44 },
			best_combo = { label_key = "statline_best_label", label_width = 50, value_width = 44 },
			last_combo = { label_key = "statline_last_label", label_width = 48, value_width = 44 },
			total_kills = { label_key = "statline_total_label", label_width = 58, value_width = 60 },
			kills_interval = { label_key = "statline_kills_interval_label", label_width = 66, value_width = 50 },
			dps = { label_key = "statline_dps_label", label_width = 36, value_width = 70 },
			fatigue_pct = { label_key = "statline_fatigue_label", label_width = 72, value_width = 48 },
			fury_pct = { label_key = "statline_fury_label", label_width = 48, value_width = 48 },
		},

		CALLOUT_TEXT_MAX_WIDTH = 800,

		FURY_URGENCY_RUMBLE_THRESHOLD = 0.15,

		DECAY_GHOST_HOLD_TIME = 0.05,
		DECAY_GHOST_SPEED = 8,

		GHOST_HALO_PAD = 1,

		MAX_FURY_COLOR_SPEED = 12,

		FILL_COLOR_STOP_HOLD = 0.95,
	},
}

local overkill_ranks = FuryMeterConstants.LOGIC.FURY_RANKS_OVERKILL
FuryMeterConstants.LOGIC.MAX_FURY_PCT = overkill_ranks[#overkill_ranks].threshold

mod.fury_meter_constants = FuryMeterConstants

return mod.fury_meter_constants
