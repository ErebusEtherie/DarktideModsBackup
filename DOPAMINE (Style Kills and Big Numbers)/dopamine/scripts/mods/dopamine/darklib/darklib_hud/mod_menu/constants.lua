

---@param Module DLH_ModMenu
---@param mod DL_Mod
return function(Module, mod)
	if Module.constants then
		return Module.constants
	end

	local Constants = {

		PANEL_WIDTH = 1183,
		PANEL_HEIGHT = 1040,
		PANEL_OFFSET_Y = 0,

		PANEL_OFFSET_X = 30,
		NAV_OFFSET_X = 0,

		NAV_WIDTH = 360,

		NAV_HEIGHT = 1080,
		ASIDE_WIDTH = 300,
		NAV_LIST_TOP = 190,
		NAV_BTN_H = 86,
		NAV_BTN_GAP = 0,
		MAX_MODULE_BUTTONS = 6,

		SECRET_BTN = { offset_x = 0, offset_y = 60, w = 75, h = 75 },
		SECRET_BTN_PROXIMITY = 115, 
		SECRET_BTN_NEAR_ALPHA = 80,

		ASIDE_LIST_TOP = 80,
		ASIDE_ROW_H = 30,
		ASIDE_PAD_X = 26,
		MAX_ASIDE_ROWS = 32,

		TITLE_BAND_H = 70,

		TITLE_HEIGHT = 80,

		FONTS = {
			overlay_title = mod.dl.fonts.validated("mono_tide_medium", "proxima_nova_bold"),
			bootup_sequence = mod.dl.fonts.validated("mono_tide_medium", "proxima_nova_bold"),
			title = mod.dl.fonts.validated("machine_medium", "proxima_nova_bold"),
			heading = mod.dl.fonts.validated("proxima_nova_bold"),
			info = mod.dl.fonts.validated("mono_tide_medium"),

			aside_label = mod.dl.fonts.validated("proxima_nova_medium", "proxima_nova_bold"),
			aside_value = mod.dl.fonts.validated("mono_tide_medium", "proxima_nova_medium"),
		},

		FONT_SIZE = {
			nav_heading = 46,
			info = 16,
			module_button = 22,

			content_title = 32,
			aside_label = 18,
			aside_value = 18,
			aside_heading = 16,
		},

		MATERIAL = {
			divider = "content/ui/materials/dividers/horizontal_frame_big_upper",
			divider_x = "content/ui/materials/dividers/horizontal_frame_big_middle",
			scrollbar = "content/ui/materials/scrollbars/scrollbar_metal_handle",
			double_chain = "content/ui/materials/frames/end_of_round/reward_default_middle",
			panel = "content/ui/materials/backgrounds/mastery_tree/bg",
			mechanicus_star = "content/ui/materials/effects/crafting_recipe_background",
			shadow = "content/ui/materials/frames/dropshadow_large",
			frame_top = "content/ui/materials/frames/screen/lobby_01_upper",
			frame_top_under = "content/ui/materials/frames/achievements/wintrack_frame_background",
			frame_top_curved = "content/ui/materials/frames/screen/metal_01_upper",
			gradient_to_r = "content/ui/materials/gradients/gradient_horizontal",
			gradient_to_t = "content/ui/materials/gradients/gradient_vertical",
			frame_bottom = "content/ui/materials/frames/screen/lobby_01_lower",
			frame_bottom_2 = "content/ui/materials/frames/screen/mission_board_01_lower",
			smoke_gradient_to_tl = "content/ui/materials/backgrounds/mutators/mutator_vent",
			chain_cog = "content/ui/materials/frames/mastery_tree/wintrack_frame_corner_right",
			divider_skull = "content/ui/materials/dividers/skull_rendered_center_02",
			terminal_wobbly = "content/ui/materials/effects/button_attention",
			frame_top_simple = "content/ui/materials/dividers/horizontal_frame_big_upper",

			terminal_basic = "content/ui/materials/backgrounds/terminal_basic",
			vox_fluff = "content/ui/materials/backgrounds/voice_matrix_fluff",
			headline_terminal = "content/ui/materials/backgrounds/headline_terminal",

			button_idle = "content/ui/materials/buttons/ready_idle",
			button_active = "content/ui/materials/buttons/ready_active",
			button_selected_edge = "content/ui/materials/buttons/background_selected_edge",

			secret_icon = "content/ui/materials/icons/difficulty/flat/difficulty_skull_uprising",
		},

		COLOR = {
			BACKDROP = { 150, 0, 0, 0 },
			PANEL_BG = { 255, 25, 37, 37 },
			PANEL = { 255, 175, 175, 175 },
			ASIDE_PANEL = { 255, 225, 225, 225 },

			CONTENT_PANEL_BG = { 255, 25, 37, 37 },
			CONTENT_PANEL = { 100, 190, 210, 180 },
			CONTENT_TITLE = { 255, 216, 229, 207 },

			NAV_HEADING = { 255, 219, 187, 125 },
			MODULE_BTN_BG = { 255, 255, 255, 255 },
			MODULE_BTN_BG_HOVER = { 150, 64, 70, 82 },
			MODULE_BTN_BG_ACTIVE = { 180, 219, 187, 125 },

			MODULE_BTN_TEXT = { 255, 244, 252, 237 },

			ASIDE_LABEL = { 255, 150, 156, 150 },
			ASIDE_VALUE = { 255, 196, 202, 196 },

			ASIDE_HEADING = { 255, 219, 187, 125 },
		},

		Z = {

			BACKDROP = 800, 
			BACKDROP_CHAIN = 801,
			BACKDROP_COG = 802,
			BACKDROP_FRAME = 800,
			SIDE = 804,
			PANEL = 805,
			PANEL_CONTENT = 825,

			PANEL_FRAME = 860,
		},
	}

	Module.constants = Constants

	return Constants
end
