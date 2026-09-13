---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.editor_constants then
	return mod.editor_constants
end

local Constants = {

	CLASS_NAME = "HudEditor",

	VISIBILITY_GROUPS = { "alive" },

	Z = {

		GRID = 399,
		BLOCK = 400,
		CANVAS = 400,
		PANEL_BLOCKS = 450,
		PANEL_PROPERTIES = 500,
		PANEL_THRESHOLD = 550,

		PANEL_CONDITION = 600,
		PANEL_IDE = 700,
		PANEL_BROWSER = 650,

		PANEL_LIBRARY = 660,
		PANEL = 450,
		POPPER = 700,
	},

	PANEL = {
		RULE_W = 1,

		TITLE_H = 26, 
		PAD = 8, 
		BLOCKS_WIDTH = 350,
		DESIGNER_WIDTH = 450,

		DESIGNER_WIDTH_LABELLED = 542,
		DESIGNER_MIN_H = 150,

		SECTION_H = 24, 
		SECTION_HEAD_PAD = 8, 
		FIELD_LABEL_H = 15, 
		FIELD_H = 20, 
		FIELD_GAP = 8, 
		NOTE_LINE_H = 15, 
		SECTION_GAP = 3, 
		STEP_W = 22,

		MODE_COL_W = 120, 
		COL_GAP = 6,

		LABEL_COL_W = 86,
		DROPDOWN_OPTION_H = 22, 
		DROPDOWN_MAX_VISIBLE = 12, 
		CARET_W = 1,

		MULTILINE_LINE_H = 18, 
		MULTILINE_PAD = 4,

		IDE_WIDTH = 1000, 
		IDE_FLUFF_H = 12,
		IDE_SIG_H = 18, 
		IDE_MIN_ROWS = 4, 
		IDE_BODY_INDENT = 20, 
		IDE_CLOSE_W = 20,

		BROWSER_WIDTH = 700,

		THRESHOLD_WIDTH = 380,

		CONDITION_WIDTH = 900,

		PICKER_W = 285, 
		PICKER_H = 150,
		PICKER_KNOB = 5, 
	},

	BEGIN_DRAG_THRESHOLD = 1,

	BLOCK_GRAB_PAD = 0,

	NODE_ROTATE_HANDLE = 10,

	NODE_ROTATE_DEG_PER_PX = 1,

	NODE_ROTATE_SNAP = 15,

	BLOCK_SCALE_HANDLE = 10,

	BLOCK_SCALE_PER_PX = 0.01,

	BLOCK_SCALE_SNAP = 0.1,

	NODE_EXTENT = {
		rect = { 80, 24 },
		text = { 160, 28 },
		progress_bar = { 100, 20 },
		texture = { 48, 48 },
		default = { 80, 24 },
	},

	COLOR = {
		PANEL_RULE = { 255, 56, 56, 56 },
		TITLE_TEXT = { 255, 255, 255, 255 },
		ROW_TEXT = { 255, 210, 210, 220 },
		ROW_NODE_TEXT = { 255, 240, 240, 240 }, 
		ROW_SELECTED = { 255, 107, 107, 107 },

		CTRL_BG = { 255, 69, 69, 69 }, 
		CTRL_BG_HOVER = { 235, 48, 48, 48 },
		CTRL_BORDER = { 150, 0, 0, 0 },
		CTRL_TEXT = { 255, 225, 225, 225 }, 
		CTRL_BG_DISABLED = { 255, 52, 52, 52 }, 
		CTRL_TEXT_MUTED = { 255, 200, 200, 200 }, 
		CTRL_TEXT_HOVER = { 255, 235, 235, 235 }, 
		CHECK_ON = { 255, 240, 240, 240 }, 
		CHECK_OFF = { 255, 110, 110, 110 }, 
		STEP_BG = { 255, 69, 69, 69 }, 
		SCROLL_THUMB = { 255, 40, 40, 40 },
		STEP_BG_HOVER = { 245, 62, 64, 86 },
		STEP_TEXT = { 255, 230, 230, 242 },
		FOCUS_BORDER = { 255, 120, 180, 255 },

		NOTE_TEXT = { 255, 140, 145, 160 }, 
	},
}

mod.editor_constants = Constants

return Constants
