

---@type mod
local mod = get_mod("dopamine")

if mod.task_constants then
	return mod.task_constants
end

local StyleHud = mod:core(mod.style_meter_constants, "hud/style_meter/constants").PRESENTATION

local UI_SCALE = StyleHud.UI_SCALE

local function scaled(value)
	return math.floor(value * UI_SCALE + 0.5)
end

---@class TaskLogicConstants
local LOGIC = {

	CHECK_INTERVAL = 10,

	TRIGGER_COOLDOWN = 30,

	MAX_ACTIVE_TASKS = 5,

	PRIORITY_RESERVED_SLOTS = 1,

	HORDE_TASK_DELAY = 3,

	HORDE_TASK_WINDOW = 10,

	RANDOM_TIMER_CHANCE = 0.5,

	TASK_ENTER_TIME = 0.2, 
	TASK_RESOLVE_TIME = 0.9, 
	TASK_EXIT_TIME = 0.25,

	TASK_RUMBLE_PULSE_TIME = 0.35,
	TASK_RUMBLE_MAX_AMP = 10,

	DIFFICULTY = {
		[1] = "easy",
		[2] = "medium",
		[3] = "hard",
	},

	DIFFICULTY_ICON = {
		[3] = "",
	},
}

---@class TaskConstants
---@field LOGIC TaskLogicConstants
local TaskConstants = {
	LOGIC = LOGIC,
	PRESENTATION = {

		MAX_SLOTS = LOGIC.MAX_ACTIVE_TASKS + 1,

		PANEL_SLOTS = LOGIC.MAX_ACTIVE_TASKS,

		UI_SCALE = UI_SCALE,

		TEXT_WIDTH = 1000,
		ROOT_WIDTH = StyleHud.ROOT_WIDTH,
		PANEL_WIDTH = 250,
		PANEL_TEXTURE = StyleHud.EVENT_PANEL_TEXTURE,
		PANEL_BG_COLOR = StyleHud.EVENT_PANEL_BG_COLOR,
		PANEL_FADE_SPEED = StyleHud.EVENT_PANEL_FADE_SPEED,
		PANEL_VERTICAL_PAD = 12,

		ROOT_MARGIN_X = 50,
		ROOT_OFFSET_Y = 0,
		TEXT_PAD_X = 14,

		RIGHT_ALIGN_MARGIN_X = 50,

		ROW_HEIGHT = scaled(50), 
		LINE_FONT_SIZE = 22, 
		TIMER_FONT_SIZE = 16, 
		STATUS_FONT_SIZE = 22, 
		TIMER_LINE_OFFSET_Y = scaled(24),

		TITLE_FONT_SIZE = StyleHud.SP_LABEL_FONT_SIZE,
		TITLE_AREA_HEIGHT = scaled(18), 
		TITLE_TOP_PAD = scaled(8), 
		ENTER_OFFSET_X = 24, 
		EXIT_SLIDE = 24,

		ENTER_TIME = LOGIC.TASK_ENTER_TIME,
		RESOLVE_TIME = LOGIC.TASK_RESOLVE_TIME,
		EXIT_TIME = LOGIC.TASK_EXIT_TIME,
		SLIDE_TIME = 0.2, 
		STATUS_POP_TIME = 0.4, 
		STATUS_POP_OVERSHOOT = 0.35,

		TIMER_WARN_SECONDS = 20,

		COLOR_REWARD = mod.constants.COLOR.NUMBERS.GREEN,
		COLOR_MULT = mod.constants.COLOR.NUMBERS.GREEN_MUTED,
		COLOR_CURRENT = mod.constants.COLOR.UI_FOREGROUND,
		COLOR_TARGET = mod.constants.COLOR.UI_FOREGROUND_MUTED,
		COLOR_LABEL = mod.constants.COLOR.UI_FOREGROUND,
		COLOR_TIMER = mod.constants.COLOR.UI_FOREGROUND_MUTED,
		COLOR_TIMER_WARN = mod.constants.COLOR.NUMBERS.RED, 
		COLOR_DONE_RGB = mod.constants.COLOR.NUMBERS.GREEN,
		COLOR_FAILED_RGB = mod.constants.COLOR.NUMBERS.RED,
		COLOR_LINE_BASE = mod.constants.COLOR.UI_FOREGROUND,

		TITLE_COLOR_UI = mod.constants.COLOR.UI_BORDER,
		TITLE_COLOR_SIMPLE = mod.constants.COLOR.UI_FOREGROUND_MUTED,

		UI_PANEL_TEXTURE = StyleHud.SP_PANEL_TEXTURE,
		UI_PANEL_BG_COLOR = StyleHud.SP_PANEL_BG_COLOR,
		UI_BORDER_COLOR = StyleHud.SP_PANEL_BORDER_COLOR,
		UI_BORDER_WIDTH = 4,

		Z_PANEL = 0,
		Z_BORDER = 2, 
		Z_ROWS = 10,
		Z_TITLE = 11, 
	},
}

mod.task_constants = TaskConstants

return mod.task_constants
