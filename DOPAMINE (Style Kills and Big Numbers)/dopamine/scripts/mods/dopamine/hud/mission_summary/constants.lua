

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_constants then
	return mod.mission_summary_constants
end

local icons = mod.dl.icons.icons
local RANK = mod.constants.COLOR.FURY_RANK
local NUMBERS = mod.constants.COLOR.NUMBERS

local thousands = function(n)
	return n * 1000
end

local millions = function(n)
	return n * 1000000
end

local Shell = mod.dl_hud.mod_menu.constants

---@class MissionSummaryConstants
local Constants = {

	PANEL_WIDTH = Shell.PANEL_WIDTH,
	PANEL_HEIGHT = Shell.PANEL_HEIGHT,
	PANEL_OFFSET_X = Shell.PANEL_OFFSET_X,
	PANEL_OFFSET_Y = Shell.PANEL_OFFSET_Y,
	TITLE_BAND_H = Shell.TITLE_BAND_H,

	CONTENT_PAD_X = 30,
	CONTENT_TOP = Shell.TITLE_BAND_H,
	CONTENT_BOTTOM = 30,

	HEADER_H = 70,
	HEADER_GAP = 0,

	HEADER_NAME_FRAC = 0.35,
	HEADER_NAME_GAP = 60,

	PROGRESS_POINTS_W = 100, 
	PROGRESS_RANK_W = 60, 
	PROGRESS_NEXT_W = 60, 
	PROGRESS_BAR_H = 14, 
	PROGRESS_GAP = 24,

	BODY_GAP = 16, 
	HIGHSCORES_FRAC = 0.243,

	STATS_TOP_FRAC = 0.34,
	STATS_ROW_GAP = 0,

	STATS_BOTTOM_GAP = 22,

	COL3_BLOCK_GAP = 8,

	HEADING_H = 32,
	HEADING_RULE_H = 2,

	STATS_ROW_H = 30,

	EVENT_ROW_H = 27,

	BIG_ROW_H = 40,

	RANK_BOX_BOTTOM_LINE = 34,

	MAX_HIGHSCORE_ROWS = 10,

	HIGHSCORE_SLOTS = 12,

	HIGHSCORE_ROW_H = 46,
	HIGHSCORE_ROW_GAP = 5,
	HIGHSCORE_ICON_W = 30,

	HIGHSCORE_DATE_W = 80,

	LIVE_BUTTON_H = 42,
	LIVE_BUTTON_GAP = 10,

	GRID_GAP = 18, 
	MISSION_GRID_COLS = 4,
	MISSION_GRID_ROWS = 6,
	MAX_MISSION_TILES = 24, 
	MISSION_TILE_H = 36,
	MISSION_TILE_GAP_X = 12,
	MISSION_TILE_GAP_Y = 7,
	MISSION_GRID_TITLE_H = 34,
	MISSION_GRID_TITLE_GAP = 8,
	MISSION_TILE_PAD_X = 10, 
	MISSION_TILE_LEVEL_W = 46,

	RANK_MAX_GLYPHS = 3,
	RANK_OVERLAP_X = 64,

	RUN_ROWS = {

		{ id = "date", label_key = "mission_summary_date", is_date = true },
		{ id = "time", label_key = "mission_summary_time", is_time = true },

		{ id = "secrets", label_key = "mission_summary_secrets", is_secrets = true },
		{ id = "plasteel", label_key = "mission_summary_plasteel", icon = icons.plasteel },
		{ id = "diamantine", label_key = "mission_summary_diamantine", icon = icons.diamantine },
	},

	BIG_ROWS = {
		{ id = "violence", label_key = "mission_summary_violence", kind = "rank" },
		{ id = "finesse", label_key = "mission_summary_finesse", kind = "rank" },
		{ id = "unity", label_key = "mission_summary_unity", kind = "rank" },
		{ id = "style", label_key = "mission_summary_style", kind = "amount" },
	},

	MAGNITUDE_ROWS = {
		{ id = "damage", label_key = "mission_summary_damage", pool = "total" },
		{ id = "elite_damage", label_key = "mission_summary_elites", sub = true, pool = "elite_health" },
		{ id = "special_damage", label_key = "mission_summary_specials", sub = true, pool = "special_health" },
		{ id = "boss_damage", label_key = "mission_summary_bosses", sub = true, pool = "boss_max_health" },
	},

	MAGNITUDE_ROW_H = 27,
	MAGNITUDE_METHOD_GAP = 14,
	MAGNITUDE_SUB_INDENT = 18,
	MAGNITUDE_CONNECTOR_X = 5,
	MAGNITUDE_CONNECTOR_W = 9,
	MAGNITUDE_CONNECTOR_THICK = 2,

	VICTIMS_EVENTS = {
		{ id = "horde_kill", label_key = "horde" },
		{ id = "rager_kill", label_key = "rager" },
		{ id = "shotgunner_kill", label_key = "shotgunner" },
		{ id = "gunner_kill", label_key = "gunner" },
		{ id = "bulwark_kill", label_key = "bulwark" },
		{ id = "crusher_kill", label_key = "crusher" },
		{ id = "trapper_kill", label_key = "trapper" },
		{ id = "hound_kill", label_key = "hound" },
		{ id = "mutant_kill", label_key = "mutant" },
		{ id = "pox_burster_kill", label_key = "poxburster" },
		{ id = "mauler_kill", label_key = "mauler" },
		{ id = "flamer_kill", label_key = "flamer" },
		{ id = "bomber_kill", label_key = "bomber" },
		{ id = "sniper_kill", label_key = "sniper" },
	},
	METHOD_EVENTS = {

		{
			id = "berserk_magdump",
			combine = { "berserk", "mag_dump" },
			label_key = "mission_summary_berserker_magdump",
		},

		{ id = "flow", label_key = "mission_summary_hotswap" },
		{ id = "multi_kill" },
		{ id = "close_headshot" },
		{ id = "far_headshot" },
		{ id = "ranged_in_melee" },
		{ id = "melee_kill", label_key = "mission_summary_melee_kill" },
		{ id = "ranged_kill", label_key = "mission_summary_ranged_kill" },
	},
	STYLE_EVENTS = {
		{ id = "best_combo", stat = true, label_key = "mission_summary_best_combo" },
		{ id = "slide_kill" },
		{ id = "dodge" },
		{ id = "perfect_block" },
		{ id = "parry" },
	},

	COMPETENCE_EVENTS = {
		{ id = "health_lost", stat = true, is_percent = true, label_key = "mission_summary_damage_taken" },
		{ id = "downs", stat = true, label_key = "mission_summary_downs" },
	},

	TEAM_EVENTS = {
		{
			id = "objectives_time",
			combine_stat_time = { stat = "objectives", time_event = "objective_time" },
			label_key = "mission_summary_objectives_time",
		},
		{ id = "rescues", stat = true, label_key = "mission_summary_rescues" },
		{ id = "stims", stat = true, label_key = "mission_summary_allies_stimmed" },
		{ id = "coherency", is_coherency_pct = true, label_key = "mission_summary_coherency" },
	},

	HEADINGS = {
		highscores = "mission_summary_high_score",
		run = "mission_summary_run_heading",
		victims = "mission_summary_victims_heading",
		magnitude = "mission_summary_magnitude_heading",
		method = "mission_summary_method_heading",
		style = "mission_summary_style_heading",
		competence = "mission_summary_competence_heading",
		team = "mission_summary_team_heading",
	},

	SECRETS = {
		idol_glyph = icons.skull_emblem,
		idol_total = 3,
		skull_glyph = icons.skull_laurel,
		skull_total = 1,
	},

	CLASS_ICONS = {
		veteran = icons.emblem_veteran,
		zealot = icons.emblem_zealot,
		psyker = icons.emblem_psyker,
		ogryn = icons.emblem_ogryn,
		adamant = icons.emblem_arbitrator,
		cryptic = icons.emblem_skitarii,
		broker = icons.emblem_hive_scum,
	},

	STYLE_RANK_SP_ROUNDING = {
		default = thousands(50),
		uprising = thousands(5),
		malice = thousands(10),
		heresy = thousands(25),
		damnation = thousands(50),
		auric_damnation = thousands(50),
		havoc_0_10 = thousands(50),
		havoc_10_20 = thousands(50),
		havoc_20_30 = thousands(100),
		havoc_30_35 = thousands(100),
		havoc_35_40 = thousands(100),
	},

	RANK_THRESHOLDS = {
		{ min = millions(5), letter = "X", color = RANK.X },
		{ min = millions(2.5), letter = "SSS", color = RANK.SSS },
		{ min = millions(1.5), letter = "SS", color = RANK.SS },
		{ min = millions(1), letter = "S", color = RANK.S },
		{ min = thousands(750), letter = "A", color = RANK.A },
		{ min = thousands(500), letter = "B", color = RANK.B },
		{ min = thousands(250), letter = "C", color = RANK.C },
		{ min = 0, letter = "D", color = RANK.D },
	},

	RANK_THRESHOLDS_BY_DIFFICULTY = {

		uprising = {
			{ min = thousands(400), letter = "X", color = RANK.X },
			{ min = thousands(200), letter = "SSS", color = RANK.SSS },
			{ min = thousands(100), letter = "SS", color = RANK.SS },
			{ min = thousands(75), letter = "S", color = RANK.S },
			{ min = thousands(50), letter = "A", color = RANK.A },
			{ min = thousands(25), letter = "B", color = RANK.B },
			{ min = thousands(10), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		malice = {
			{ min = thousands(600), letter = "X", color = RANK.X },
			{ min = thousands(350), letter = "SSS", color = RANK.SSS },
			{ min = thousands(200), letter = "SS", color = RANK.SS },
			{ min = thousands(100), letter = "S", color = RANK.S },
			{ min = thousands(75), letter = "A", color = RANK.A },
			{ min = thousands(40), letter = "B", color = RANK.B },
			{ min = thousands(20), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		heresy = {
			{ min = thousands(875), letter = "X", color = RANK.X },
			{ min = thousands(700), letter = "SSS", color = RANK.SSS },
			{ min = thousands(500), letter = "SS", color = RANK.SS },
			{ min = thousands(350), letter = "S", color = RANK.S },
			{ min = thousands(200), letter = "A", color = RANK.A },
			{ min = thousands(100), letter = "B", color = RANK.B },
			{ min = thousands(50), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		damnation = {
			{ min = millions(1), letter = "X", color = RANK.X },
			{ min = thousands(900), letter = "SSS", color = RANK.SSS },
			{ min = thousands(750), letter = "SS", color = RANK.SS },
			{ min = thousands(650), letter = "S", color = RANK.S },
			{ min = thousands(500), letter = "A", color = RANK.A },
			{ min = thousands(400), letter = "B", color = RANK.B },
			{ min = thousands(225), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		auric_damnation = {
			{ min = millions(1.5), letter = "X", color = RANK.X },
			{ min = millions(1.15), letter = "SSS", color = RANK.SSS },
			{ min = thousands(900), letter = "SS", color = RANK.SS },
			{ min = thousands(800), letter = "S", color = RANK.S },
			{ min = thousands(675), letter = "A", color = RANK.A },
			{ min = thousands(450), letter = "B", color = RANK.B },
			{ min = thousands(350), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},

		havoc_0_10 = {
			{ min = millions(1.5), letter = "X", color = RANK.X },
			{ min = millions(1.15), letter = "SSS", color = RANK.SSS },
			{ min = thousands(900), letter = "SS", color = RANK.SS },
			{ min = thousands(800), letter = "S", color = RANK.S },
			{ min = thousands(675), letter = "A", color = RANK.A },
			{ min = thousands(450), letter = "B", color = RANK.B },
			{ min = thousands(350), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		havoc_10_20 = {
			{ min = millions(1.65), letter = "X", color = RANK.X },
			{ min = millions(1.25), letter = "SSS", color = RANK.SSS },
			{ min = millions(1), letter = "SS", color = RANK.SS },
			{ min = thousands(850), letter = "S", color = RANK.S },
			{ min = thousands(700), letter = "A", color = RANK.A },
			{ min = thousands(500), letter = "B", color = RANK.B },
			{ min = thousands(350), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		havoc_20_30 = {
			{ min = millions(1.85), letter = "X", color = RANK.X },
			{ min = millions(1.5), letter = "SSS", color = RANK.SSS },
			{ min = millions(1.25), letter = "SS", color = RANK.SS },
			{ min = millions(1.1), letter = "S", color = RANK.S },
			{ min = thousands(925), letter = "A", color = RANK.A },
			{ min = thousands(800), letter = "B", color = RANK.B },
			{ min = thousands(650), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		havoc_30_35 = {
			{ min = millions(2.45), letter = "X", color = RANK.X },
			{ min = millions(2.15), letter = "SSS", color = RANK.SSS },
			{ min = millions(1.85), letter = "SS", color = RANK.SS },
			{ min = millions(1.5), letter = "S", color = RANK.S },
			{ min = millions(1.25), letter = "A", color = RANK.A },
			{ min = millions(1), letter = "B", color = RANK.B },
			{ min = thousands(750), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
		havoc_35_40 = {
			{ min = millions(3.25), letter = "X", color = RANK.X },
			{ min = millions(2.75), letter = "SSS", color = RANK.SSS },
			{ min = millions(2.5), letter = "SS", color = RANK.SS },
			{ min = millions(2.25), letter = "S", color = RANK.S },
			{ min = millions(2), letter = "A", color = RANK.A },
			{ min = millions(1.75), letter = "B", color = RANK.B },
			{ min = millions(1.5), letter = "C", color = RANK.C },
			{ min = 0, letter = "D", color = RANK.D },
		},
	},

	LEVEL_THRESHOLDS = {
		{ min = 0, letter = "D", color = RANK.D },
		{ min = millions(9.99999), letter = "C", color = RANK.C },
		{ min = millions(17.499999), letter = "A", color = RANK.A },
		{ min = millions(29.99999), letter = "S", color = RANK.S },
		{ min = millions(49.99999), letter = "SS", color = RANK.SS },
		{ min = millions(74.99999), letter = "SSS", color = RANK.SSS },
		{ min = millions(99.99999), letter = "X", color = RANK.X },
	},
	LEVEL_PRESTIGE_STEP = millions(25),

	PERF_PT_MAX = 10,
	PERF_PT_BY_TIER = {
		D = 0,
		C = 2,
		B = 3.5,
		A = 5,
		S = 6.5,
		SS = 8,
		SSS = 9,
		X = 10,
	},

	VIOLENCE_CATEGORY_POINTS = {
		elite = {
			{ pct = 60, points = 5 },
			{ pct = 40, points = 4 },
			{ pct = 25, points = 3 },
			{ pct = 15, points = 2 },
			{ pct = 5, points = 1 },
		},

		special = {
			{ pct = 60, points = 5 },
			{ pct = 40, points = 4 },
			{ pct = 25, points = 3 },
			{ pct = 15, points = 2 },
			{ pct = 5, points = 1 },
		},

		boss = {
			{ pct = 75, points = 5 },
			{ pct = 50, points = 4 },
			{ pct = 30, points = 3 },
			{ pct = 15, points = 2 },
			{ pct = 5, points = 1 },
		},

		regular = {
			{ pct = 70, points = 4 },
			{ pct = 50, points = 3 },
			{ pct = 30, points = 2 },
			{ pct = 15, points = 1 },
		},
	},

	VIOLENCE_POINT_THRESHOLDS = {
		{ min = 15, letter = "X", color = RANK.X },
		{ min = 13, letter = "SSS", color = RANK.SSS },
		{ min = 11, letter = "SS", color = RANK.SS },
		{ min = 8, letter = "S", color = RANK.S },
		{ min = 6, letter = "A", color = RANK.A },
		{ min = 4, letter = "B", color = RANK.B },
		{ min = 3, letter = "C", color = RANK.C },
		{ min = 0, letter = "D", color = RANK.D },
	},

	UNITY_COHERENCY_POINTS = { 
		{ pct = 90, points = 10 },
		{ pct = 80, points = 9 },
		{ pct = 70, points = 7 },
		{ pct = 60, points = 5 },
		{ pct = 50, points = 3 },
		{ pct = 40, points = 2 },
		{ pct = 25, points = 1 },
	},
	UNITY_OBJECTIVE_POINTS = { 
		{ count = 3, points = 4 },
		{ count = 2, points = 3 },
		{ count = 1, points = 2 },
	},
	UNITY_STIM_POINTS = 1, 
	UNITY_STIM_POINTS_MAX = 2, 
	UNITY_RESCUE_POINTS = 1, 
	UNITY_RESCUE_POINTS_MAX = 3,

	UNITY_POINT_THRESHOLDS = {
		{ min = 13, letter = "X", color = RANK.X },
		{ min = 12, letter = "SSS", color = RANK.SSS },
		{ min = 10, letter = "SS", color = RANK.SS },
		{ min = 8, letter = "S", color = RANK.S },
		{ min = 6, letter = "A", color = RANK.A },
		{ min = 4, letter = "B", color = RANK.B },
		{ min = 2, letter = "C", color = RANK.C },
		{ min = 0, letter = "D", color = RANK.D },
	},

	FINESSE_MAX_POINTS = 10, 
	FINESSE_DOWN_PENALTY = 3, 
	FINESSE_DAMAGE_PENALTY_MAX = 3,

	FINESSE_DOWN_HEALTH_POOLS = 0.5,

	FINESSE_DAMAGE_PENALTY = {
		{ pools = 4, penalty = 3 },
		{ pools = 3, penalty = 2 },
		{ pools = 2, penalty = 1.5 },
		{ pools = 1.5, penalty = 1 },
	},

	FINESSE_POINT_THRESHOLDS = {
		{ min = 9, letter = "X", color = RANK.X },
		{ min = 8.5, letter = "SSS", color = RANK.SSS },
		{ min = 7.5, letter = "SS", color = RANK.SS },
		{ min = 6.5, letter = "S", color = RANK.S },
		{ min = 5.0, letter = "A", color = RANK.A },
		{ min = 3, letter = "B", color = RANK.B },
		{ min = 2.0, letter = "C", color = RANK.C },
		{ min = 0, letter = "D", color = RANK.D },
	},

	FACTOR_POINT_WEIGHT = { violence = 1.2, unity = 1.1, finesse = 0.9, style = 0.8 },
	COMPOSITE_THRESHOLDS = {
		{ min = 9.2, letter = "X", color = RANK.X },
		{ min = 8.3, letter = "SSS", color = RANK.SSS },
		{ min = 7.2, letter = "SS", color = RANK.SS },
		{ min = 6.0, letter = "S", color = RANK.S },
		{ min = 4.6, letter = "A", color = RANK.A },
		{ min = 3.2, letter = "B", color = RANK.B },
		{ min = 1.6, letter = "C", color = RANK.C },
		{ min = 0, letter = "D", color = RANK.D },
	},

	INTRO_CATEGORY_ORDER = { "violence", "finesse", "unity", "style" },
	CATEGORY_LERP = 4, 
	CATEGORY_PAUSE = 0.35,

	INTRO_EASE_IN_FRAC = 0.2,
	INTRO_EASE_OUT_FRAC = 0.4,

	INTRO_EASE_IN_FRAC_FIRST = 0.5,

	RANK_SETTLE_SHAKE = 12,
	RANK_SETTLE_SHAKE_T = 0.35,

	HELL_YEAH_BUTTON_H = 56,
	HELL_YEAH_FADE = 0.15,

	HELL_YEAH_SHADOW_MIN = 2,
	HELL_YEAH_SHADOW_MAX = 5,
	HELL_YEAH_SHADOW_HOVER_TIME = 0.03,

	SKIP_RECAP_DELAY = 1.0, 
	SKIP_RECAP_FADE = 0.25, 
	SKIP_RECAP_ICON_SIZE = 42, 
	SKIP_RECAP_ICON_GAP = 12,

	FONTS = {
		title = mod.dl.fonts.validated("machine_medium", "proxima_nova_bold"),
		heading = mod.dl.fonts.validated("proxima_nova_bold"),
		big_label = mod.dl.fonts.validated("proxima_nova_bold"),
		label_bold = mod.dl.fonts.validated("proxima_nova_bold"),
		label = mod.dl.fonts.validated("proxima_nova_medium"),
		big_value = mod.dl.fonts.validated("mono_tide_bold", "proxima_nova_medium"),
		value = mod.dl.fonts.validated("mono_tide_medium", "proxima_nova_medium"),
		value_bold = mod.dl.fonts.validated("mono_tide_bold", "proxima_nova_bold"),
		rank = mod.dl.fonts.validated("rexlia", "machine_medium"),
		icon = mod.dl.fonts.validated("mono_tide_medium", "proxima_nova_medium"),
	},

	FONT_SIZE = {
		mission_name = 40,
		level_points = 26,
		level_label = 30, 
		level_next = 30, 
		heading = 20,
		run_label = 15,
		run_value = 15,
		big_label = 20,
		big_value_rank = 24,
		big_value = 21,

		big_label_active = 27,
		big_value_active = 35,
		rank = 100,

		rank_shadow = 108,
		event_label = 15,
		event_value = 15,

		magnitude_pool = 13,
		highscore_rank = 16,
		highscore_points = 16,
		highscore_difficulty = 14,
		highscore_icon = 24,
		grid_title = 22,
		tile_name = 15,
		tile_level = 14,
		button = 20,
		hell_yeah = 34,
	},

	MATERIAL = {
		frame_tile = "content/ui/materials/frames/frame_tile_2px",
		hr = "content/ui/materials/dividers/skull_rendered_center_03",

		skip_recap_icon = "content/ui/materials/hud/interactions/icons/pocketable_syringe_speed",
	},

	COLOR = {
		WHITE = mod.constants.COLOR.UI_FOREGROUND,
		MUTED = mod.constants.COLOR.UI_FOREGROUND_MUTED,
		LABEL = mod.constants.COLOR.UI_FOREGROUND_MUTED,
		VALUE = mod.constants.COLOR.UI_FOREGROUND,
		INACTIVE_RECAP = { 150, 175, 175, 175 },
		LABEL_ACTIVE_RECAP = mod.constants.COLOR.UI_FOREGROUND,
		VALUE_ACTIVE_RECAP = mod.constants.COLOR.UI_FOREGROUND,
		HEADING = { 255, 226, 199, 126 },
		TITLE = { 255, 226, 199, 126 },
		RULE = { 250, 99, 114, 102 },

		IDOL_FOUND = mod.constants.COLOR.NUMBERS.ORANGE,
		IDOL_MISSING = { 120, 120, 120, 120 },

		SKULL_FOUND = mod.constants.COLOR.NUMBERS.RED,
		SKULL_MISSING = { 120, 120, 120, 120 },

		PROGRESS_BAR_BG = { 200, 15, 20, 20 },
		PROGRESS_BAR_FILL = { 255, 226, 199, 126 },
		PROGRESS_NEXT = mod.constants.COLOR.UI_FOREGROUND_MUTED,

		RANK_BOX_BG = { 200, 15, 20, 20 },
		RANK_BOX_BORDER = { 255, 99, 114, 102 },
		RANK_SHADOW = { 255, 0, 0, 0 },

		ROW_BG = { 90, 15, 20, 20 },
		ROW_BG_HOVER = { 150, 64, 70, 82 },
		ROW_BG_SELECTED = { 180, 226, 199, 126 },

		ROW_BG_EMPTY = { 15, 0, 0, 0 },
		ROW_TEXT = mod.constants.COLOR.UI_FOREGROUND,
		ROW_DIFFICULTY = mod.constants.COLOR.UI_FOREGROUND_MUTED,

		CURRENT_RUN = mod.constants.COLOR.UI_RED,
		NEW_RUN = NUMBERS.ORANGE,

		TILE_PROGRESS_FILL = { 75, 226, 199, 126 },

		WIN = mod.constants.COLOR.NUMBERS.GREEN,
		LOSS = mod.constants.COLOR.UI_RED,

		BUTTON_LIVE_MISSION_BG = { 90, 15, 20, 20 },
		BUTTON_BG = { 200, 46, 57, 51 },
		BUTTON_BG_HOVER = { 220, 64, 70, 82 },
		BUTTON_TEXT = { 255, 226, 199, 126 },

		DELETE_RUN_BG = { 0, 40, 15, 15 },
		DELETE_RUN_BG_HOVER = { 75, 110, 30, 30 },
		DELETE_RUN_TEXT = mod.constants.COLOR.UI_RED,

		HELL_YEAH_BG = { 235, 226, 199, 126 },
		HELL_YEAH_TEXT = { 255, 20, 16, 10 },

		HELL_YEAH_SHADOW = { 200, 0, 0, 0 },

		SKIP_RECAP_BG = { 90, 15, 20, 20 },
		SKIP_RECAP_BG_HOVER = { 105, 15, 20, 20 },
		SKIP_RECAP_TEXT = { 255, 226, 199, 126 },

		NUMBERS = NUMBERS,
	},

	Z = {
		ROW_BG = 0,
		CONTENT = 1,
		TEXT = 2,
	},
}

mod.mission_summary_constants = Constants

return mod.mission_summary_constants
