

---@type mod
local mod = get_mod("dopamine")

if mod.style_meter_constants then
	return mod.style_meter_constants
end

local UI_SCALE = 1

local function scaled(value)
	return math.floor(value * UI_SCALE + 0.5)
end

local LOGIC = {

	MAX_EVENT_SLOTS_LIMIT = 12,

	EVENTS_LIFETIME = {
		DEBUG = 999,
		DEFAULT = 4.5,
	},

	SP_LERP_SPEED = 3.5,

	SP_POPUP_HOLD_TIME = 2, 
	SP_POPUP_OUT_WAIT = 0.4,

	COMBO_FINISH_RUMBLE_REF_KILLS = 50,

	SP_COMBO_RECAP_LERP_TIME = 2.25,

	MULTI_KILL_WINDOW = 0.1,

	STYLE_MULT_LERP_TIME = 0.05,

	SLIDE_MULT_RATE = 6,

	EVENT_MULT = {
		dodge = 0.5,
	},
}

---@class StyleMeterConstants
local StyleMeterConstants = {
	LOGIC = LOGIC,
	PRESENTATION = {

		MAX_SLOTS = LOGIC.MAX_EVENT_SLOTS_LIMIT,

		UI_SCALE = UI_SCALE,

		TEXT_WIDTH = 600, 
		ROOT_WIDTH = 700, 
		ROOT_HEIGHT = scaled(160),

		EVENT_PANEL_TEXTURE = "content/ui/materials/gradients/gradient_horizontal",
		EVENT_PANEL_WIDTH = 450,
		EVENT_PANEL_VERTICAL_PAD = 12, 
		EVENT_PANEL_BG_COLOR = { 60, 0, 0, 0 }, 
		EVENT_PANEL_FADE_SPEED = 6,

		ROOT_MARGIN_X = 50,
		SP_TEXT_PAD_X = -14, 
		SP_PANEL_WIDTH = 400, 
		EXIT_SLIDE = 18,

		ROOT_OFFSET_Y = 0, 
		EVENT_STACK_OFFSET_Y = -52, 
		SLOT_HEIGHT = 34, 
		SP_COUNTER_GAP = 10,

		SP_PANEL_TEXTURE = "content/ui/materials/hud/backgrounds/terminal_background_weapon",
		SP_LABEL_OFFSET_Y = 12, 
		SP_VALUE_OFFSET_Y = 35, 
		SP_PANEL_TOP_PAD = 8, 
		SP_PANEL_BOTTOM_PAD = 5, 
		SP_POPUP_GAP = 11, 
		SP_POPUP_OFFSET_X = 6, 
		SP_PANEL_BG_COLOR = mod.constants.COLOR.UI_BORDER_MUTED, 
		SP_PANEL_BORDER_COLOR = mod.constants.COLOR.UI_BORDER,

		SLOT_FONT_SIZE = 30, 
		SP_FONT_SIZE = 32, 
		SP_LABEL_FONT_SIZE = 15, 
		SP_POPUP_FONT_SIZE = 23, 
		SP_COMBO_MULT_FONT_SIZE = 18,

		ENTER_OFFSET_Y = -24, 
		EXIT_EVICT_DROP_Y = scaled(24),

		SP_LERP_SPEED = LOGIC.SP_LERP_SPEED,

		SP_POPUP_HOLD_TIME = LOGIC.SP_POPUP_HOLD_TIME,
		SP_POPUP_OUT_WAIT = LOGIC.SP_POPUP_OUT_WAIT,
		SP_POPUP_AMOUNT_LERP_SPEED = 10, 
		SP_POPUP_RISE_DRIFT = 26,

		SP_COMBO_RECAP_LERP_TIME = LOGIC.SP_COMBO_RECAP_LERP_TIME,
		SP_COMBO_RECAP_LINE_GAP = scaled(18), 
		SP_COMBO_INLINE_GAP = scaled(8),

		MULT_ROW_GAP = scaled(6), 
		MULT_LABEL_FONT_SIZE = 30, 
		MULT_VALUE_FONT_SIZE_MIN = 30, 
		MULT_VALUE_FONT_SIZE_MAX = 38, 
		MULT_VALUE_HEAT = 15, 
		MULT_LERP_TIME = LOGIC.STYLE_MULT_LERP_TIME,
		MULT_VALUE_COLOR_LOW = mod.constants.COLOR.UI_FOREGROUND, 
		MULT_VALUE_COLOR_HIGH = mod.constants.COLOR.NUMBERS.RED, 
		MULT_AT_BASE_HOLD = 1, 
		MULT_ROW_FADE_SPEED = 6,

		MULT_BAR_WIDTH = scaled(180), 
		MULT_BAR_HEIGHT = scaled(8), 
		MULT_BAR_GAP = scaled(8), 
		MULT_BAR_TRACK_COLOR = mod.constants.COLOR.UI_BORDER_MUTED, 
		MULT_BAR_TRACK_ALPHA = 60, 
		MULT_BAR_FILL_COLOR = mod.constants.COLOR.NUMBERS.ORANGE, 
		MULT_BAR_FADE_SPEED = 8,

		Z_EVENT_PANEL = 0, 
		Z_EVENT_ROWS = 10, 
		Z_MULT_BAR_TRACK = 10, 
		Z_MULT_BAR_FILL = 11, 
		Z_SP = 8, 
		Z_POPUP = 12, 
		Z_SP_PANEL = 1, 
	},
}

mod.style_meter_constants = StyleMeterConstants

return mod.style_meter_constants
