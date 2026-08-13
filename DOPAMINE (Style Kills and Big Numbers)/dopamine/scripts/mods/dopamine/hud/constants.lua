
---@type mod
local mod = get_mod("dopamine")

if mod.constants then
	return mod.constants
end

local named_colors = {
	red_lighter = { 255, 239, 75, 75 },
	red = { 255, 255, 45, 45 },
	red_darker = { 255, 170, 10, 10 },
	pink = { 255, 213, 1, 248 },
	clay_orange = { 255, 255, 150, 55 },
	orange = { 255, 249, 113, 48 },
	yellow = { 255, 255, 230, 0 },
	vibrant_yellow = { 255, 255, 255, 0 },
	lime = { 255, 180, 255, 0 },
	teal_green = { 255, 44, 245, 166 },
	mint_green = { 255, 1, 235, 184 },
	mint_green_lighter = { 255, 1, 205, 154 },
	green = { 255, 90, 225, 80 },
	blue = { 255, 43, 144, 231 },
	blue_lighter = { 255, 35, 132, 252 },
	purple = { 255, 150, 90, 252 },
}

---@class Constants
local Constants = {

	PULSE = {
		AMP_MAX = 20,
		AMP_HIGH = 12,
		AMP_MID = 8,
		AMP_LOW = 4,
		AMP_VLOW = 1,
		T = 0.35,
	},
	TRAN_SLIDE = {
		T_FAST = 0.2,
		T_SLOW = 0.4,
	},
	COLOR = {

		UI_FOREGROUND = { 255, 244, 252, 237 }, 
		UI_FOREGROUND_MUTED = { 255, 175, 175, 175 }, 
		UI_BORDER = { 255, 169, 191, 153 }, 
		UI_BORDER_MUTED = { 255, 101, 133, 96 }, 
		UI_RED = { 255, 246, 70, 70 }, 
		named_colors = named_colors,

		MAX_FURY = named_colors.teal_green, 
		FURY_RANK = {
			D = named_colors.purple,
			C = named_colors.blue,
			B = named_colors.green,
			A = named_colors.lime,
			S = named_colors.yellow,
			SS = named_colors.orange,
			SSS = named_colors.red_lighter,
			X = named_colors.teal_green,
			XX = named_colors.teal_green,
		},
		FURY_RANK_INTERACTION = {
			HOVER = {
				D = named_colors.purple,
				C = named_colors.blue,
				B = named_colors.green,
				A = named_colors.lime,
				S = named_colors.yellow,
				SS = named_colors.orange,
				SSS = named_colors.red_lighter,
				X = named_colors.teal_green,
				XX = named_colors.teal_green,
			}
		},
		FURY_METER_FILL = {
			ORANGE = { 255, 251, 193, 87 },
			RED = { 255, 246, 70, 70 },
		},

		GRITTY_FRAME_GRAY = { 255, 205, 205, 205 },
		GRITTY_SHADOW_GRAY = { 255, 70, 70, 70 },

		NUMBERS = {
			GREEN_MUTED = { 255, 200, 220, 140 },
			GREEN = { 255, 180, 255, 120 },
			ORANGE = { 255, 251, 193, 87 },
			RED = { 255, 246, 64, 56 },
			YELLOW = { 255, 255, 210, 90 },
		},
	},
	HUD_Z_BOOST = 300,
}

mod.constants = Constants

return Constants
