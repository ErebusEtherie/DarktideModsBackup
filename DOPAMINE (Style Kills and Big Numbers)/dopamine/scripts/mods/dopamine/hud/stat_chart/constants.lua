

---@type mod
local mod = get_mod("dopamine")

if mod.stat_chart_constants then
	return mod.stat_chart_constants
end

local StyleHud = mod:core(mod.style_meter_constants, "hud/style_meter/constants").PRESENTATION

local UI_SCALE = StyleHud.UI_SCALE

local function scaled(value)
	return math.floor(value * UI_SCALE + 0.5)
end

---@class StatChartMetric
---@field id string          -- stable id, also the accumulator field name
---@field title_key string   -- localization key for the panel header
local METRICS = {
	{ id = "damage", title_key = "stat_chart_metric_damage" },
	{ id = "kills", title_key = "stat_chart_metric_kills" },
}

---@class StatChartLogicConstants
local LOGIC = {

	METRICS = METRICS,
	MAX_ROWS = 4,
}

---@class StatChartConstants
---@field LOGIC StatChartLogicConstants
local StatChartConstants = {
	LOGIC = LOGIC,
	PRESENTATION = {

		MAX_ROWS = LOGIC.MAX_ROWS,

		UI_SCALE = UI_SCALE,

		TEXT_WIDTH = 1000,
		ROOT_WIDTH = StyleHud.ROOT_WIDTH,
		PANEL_WIDTH = 250,

		ROOT_MARGIN_X = 50,
		ROOT_OFFSET_Y = 0,
		RIGHT_ALIGN_MARGIN_X = 50, 
		TEXT_PAD_X = 14,

		PANEL_TEXTURE = StyleHud.SP_PANEL_TEXTURE,
		PANEL_BG_COLOR = StyleHud.SP_PANEL_BG_COLOR,
		PANEL_BORDER_COLOR = StyleHud.SP_PANEL_BORDER_COLOR,
		PANEL_BORDER_WIDTH = 4, 
		PANEL_FADE_SPEED = StyleHud.EVENT_PANEL_FADE_SPEED,
		PANEL_VERTICAL_PAD = 12,

		TITLE_FONT_SIZE = StyleHud.SP_LABEL_FONT_SIZE,
		TITLE_AREA_HEIGHT = scaled(18), 
		TITLE_TOP_PAD = scaled(8), 
		TITLE_COLOR = mod.constants.COLOR.UI_BORDER,

		ROW_HEIGHT = scaled(38), 
		NAME_FONT_SIZE = 13, 
		NAME_OFFSET_Y = scaled(8), 
		BAR_OFFSET_Y = scaled(26), 
		BAR_HEIGHT = scaled(12), 
		BAR_MAX_WIDTH = 210, 
		BAR_BG_ALPHA = 60, 
		VALUE_FONT_SIZE = 16,

		NAME_COLOR = mod.constants.COLOR.UI_FOREGROUND,
		VALUE_COLOR = mod.constants.COLOR.UI_FOREGROUND,
		BAR_TRACK_COLOR = mod.constants.COLOR.UI_BORDER_MUTED,

		ENTER_TIME = 0.2, 
		SLIDE_TIME = 0.2, 
		BAR_LERP_SPEED = 6,

		Z_PANEL = 0,
		Z_BORDER = 2, 
		Z_BAR_TRACK = 8, 
		Z_BAR_FILL = 9, 
		Z_TEXT = 11, 
		Z_TITLE = 12, 
	},
}

mod.stat_chart_constants = StatChartConstants

return mod.stat_chart_constants
