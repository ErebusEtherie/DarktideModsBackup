---@type mod
local mod = get_mod("dopamine")

local function default_marker_font_size()
	local height = 1080
	if RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height then
		height = RESOLUTION_LOOKUP.height
	end

	if height >= 1440 then
		return 17
	end

	return 15
end

mod:set("wipe_history_confirmation", "unconfirmed")

if mod:get("global_sp_multiplier") ~= 1 then
	mod:set("global_sp_multiplier", 1)
end

---@class DL_ModSettings
---@field fury_color_palette argb_table[]
---@field statline_active_stats table<StatlineItem, boolean>
local DEFAULTS = {

	fancy_transitions = true,

	enable_rumble_global = true,
	enable_rumble_on_gain = true,
	enable_bar_rumble_on_expire = true,
	enable_fury_rank_text = true,
	enable_class_specific_fury_ranks = true,
	fury_meter_theme = "ui",
	fury_rank_font_type = mod.dl.fonts.reg.rexlia,
	fury_rank_font_size = 46,
	fury_meter_width = 450,
	fury_meter_height = 10,

	fury_meter_offset_y = 275,

	fury_color_stop_1 = mod.constants.COLOR.UI_FOREGROUND,
	fury_color_stop_2 = mod.constants.COLOR.FURY_RANK.C,
	fury_color_stop_3 = mod.constants.COLOR.FURY_RANK.B,
	fury_color_stop_4 = mod.constants.COLOR.FURY_RANK.A,
	fury_color_stop_5 = mod.constants.COLOR.FURY_RANK.S,
	fury_color_stop_6 = mod.constants.COLOR.FURY_RANK.SS,
	fury_color_stop_7 = mod.constants.COLOR.FURY_RANK.SSS,
	fury_color_stop_8 = mod.constants.COLOR.FURY_RANK.X,
	fury_color_stop_9 = mod.constants.COLOR.FURY_RANK.XX,

	fatigue_tint_color = mod.constants.COLOR.FURY_METER_FILL.ORANGE,

	enable_kill_markers = true,
	enable_immersive_markers = true,
	max_active_markers = 10,
	marker_fade_duration = 1.25,
	marker_font_size = default_marker_font_size(),
	marker_font_type = mod.dl.fonts.reg.mono_tide_bold,
	events_font_size = 0,
	sp_counter_font_size = 0,

	slot_left = "fury",
	slot_left_2 = "score",
	slot_left_3 = "none",
	slot_left_4 = "none",
	slot_center = "none",
	slot_right_1 = "stats",
	slot_right_2 = "objective",
	slot_right_3 = "none",
	slot_right_4 = "none",

	chat_reposition = (get_mod("custom_hud") and "off") or "on",
	killfeed_disable = (get_mod("custom_hud") and "off") or "on",

	mission_speaker_reposition = (get_mod("custom_hud") and "off") or "on",

	hud_offset_left = 220,
	hud_offset_right = 220,

	hud_margin_left = 50,
	hud_margin_right = 50,
	style_meter_font_type = mod.dl.fonts.reg.mono_tide_medium,
	statline_font_size = 16,
	statline_segment_1 = "best_combo",
	statline_segment_2 = "total_kills",
	statline_segment_3 = "dps",
	statline_segment_4 = "fatigue_pct",
	statline_dps_update_hz = 8,

	statline_kpm_interval_seconds = 30,

	global_sp_multiplier = 1,

	grace_drain_mult = 0.1,
	fury_kill_mult = 1,
	fury_damage_mult = 0.3,
	fatigue_kill_mult = 0.1,
	fatigue_damage_mult = 0.15,
	fury_damage_penalty = 0.25,
	grace_per_damage = 0.02,
	grace_drain_percent = 3,
	fatigue_milestone_interval = 10,
	fatigue_milestone_reduction = 15,
	breed_relief_elite_fatigue = 5,
	breed_relief_elite_ramp = 5,
	breed_relief_special_fatigue = 10,
	breed_relief_special_ramp = 10,
	fatigue_passive_ramp_seconds = 120,
	fatigue_passive_per_second = 5,
	fury_min_damage_gain = 2.5,
	fury_max_damage_gain = 15,
	fury_drain_seconds = 10,
	max_fury_fatigue_add = 20,
	fury_fatigue_drain_rate_pct = 300,
	fatigue_min_damage_gain = 0.1,
	fatigue_max_damage_gain = 4.0,
	fury_min_gain_mult = 0.1,
	grace_duration = 0.25,
	grace_max = 1.25,
	grace_min_duration_mult = 0.05,
	fury_damage_reference = 100,

	enable_mission_summary = true,
	skip_mission_recap = false,
	wipe_history_confirmation = "unconfirmed",

	enable_colored_breed_kills = false,
	enable_breed_kill_events = false,
	max_event_slots = 6,
	task_track_theme = "ui",

	stat_chart_bar_color = mod.constants.COLOR.NUMBERS.YELLOW,

	debug_layout_boxes = false,
	debug_enable_permanent_events = false,
	debug_trigger_tasks_manually = false,
	debug_log_fury_fatigue_gain = false,
	debug_lock_fury_fatigue = false,
	debug_fury_pct = 0,
	debug_fatigue_pct = 0,
	debug_show_test_callout = false,
}

mod.dl.data.set_defaults(DEFAULTS)

mod.dl.settings.derive("fury_color_palette", function()
	local s = mod.dl.settings
	return {
		s.fury_color_stop_1,
		s.fury_color_stop_2,
		s.fury_color_stop_3,
		s.fury_color_stop_4,
		s.fury_color_stop_5,
		s.fury_color_stop_6,
		s.fury_color_stop_7,
		s.fury_color_stop_8,
		s.fury_color_stop_9,
	}
end)

mod.dl.settings.derive("statline_active_stats", function()
	local s = mod.dl.settings
	local active = {}
	active[s.statline_segment_1] = true
	active[s.statline_segment_2] = true
	active[s.statline_segment_3] = true
	active[s.statline_segment_4] = true
	return active
end)

mod.settings_widgets = {
	mod.dl.data.keybind("mod_menu_keybind", "__toggle_mod_menu"),
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,

	hot_reload = { "localization", "data", "script" },
	options = {
		widgets = mod.settings_widgets,
	},
}
