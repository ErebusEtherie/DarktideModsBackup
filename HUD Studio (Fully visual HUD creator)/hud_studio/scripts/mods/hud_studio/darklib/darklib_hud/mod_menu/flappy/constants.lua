

---@param Module DLH_ModMenu
---@param mod DL_Mod
return function(Module, mod)
	if Module.flappy_constants then
		return Module.flappy_constants
	end

	local Shell = Module.constants

	local Constants = {

		FIELD_W = Shell.PANEL_WIDTH - 52,
		FIELD_H = Shell.PANEL_HEIGHT - 140,
		FIELD_OFFSET_X = Shell.PANEL_OFFSET_X,
		FIELD_OFFSET_Y = Shell.PANEL_OFFSET_Y + 30,
		GROUND_H = 52,

		BIRD_SIZE = 52,
		BIRD_X = 230, 
		BIRD_START_FRAC = 0.42, 
		BOB_AMPLITUDE = 14, 
		BOB_SPEED = 3,

		GRAVITY = 2600,
		FLAP_VELOCITY = -720, 
		MAX_FALL_SPEED = 1250,
		SCROLL_SPEED = 300,

		PIPE_W = 118,
		PIPE_GAP = 250, 
		PIPE_SPACING = 430, 
		PIPE_POOL = 4, 
		PIPE_FIRST_X = 900, 
		GAP_MARGIN = 110,

		COLOR = {
			FIELD_BG = { 0, 12, 22, 20 },
			PIPE = { 255, 18, 24, 23 },
			GROUND = { 255, 30, 40, 30 },
			BIRD = { 255, 219, 187, 125 },
			BIRD_EYE = { 255, 20, 24, 20 },
			SCORE = { 255, 236, 244, 230 },
			PROMPT = { 255, 219, 187, 125 },
			GAMEOVER = { 255, 226, 120, 96 },
			HINT = { 255, 170, 180, 168 },
		},

		FONTS = {
			score = mod.dl.fonts.validated("machine_medium", "proxima_nova_bold"),
			prompt = mod.dl.fonts.validated("proxima_nova_bold"),
		},

		FONT_SIZE = {
			score = 72,
			prompt = 30,
			gameover = 46,
			hint = 22,
		},
	}

	Module.flappy_constants = Constants

	return Constants
end
