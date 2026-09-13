---@type mod
local mod = get_mod("dopamine")

if mod.settings_schema then
	return mod.settings_schema
end

local b = mod.dl_hud.settings_menu.schema_builder

local tab, heading, checkbox, numeric, keybind, dropdown, button =
	b.tab, b.heading, b.checkbox, b.numeric, b.keybind, b.dropdown, b.button

b.register_defaults(mod.dl.settings.defaults)

local statline_segment_options = function()
	return {
		{ label = "slot_none", value = "none" },
		{ label = "statline_stat_current_combo", value = "current_combo" },
		{ label = "statline_stat_best_combo", value = "best_combo" },
		{ label = "statline_stat_last_combo", value = "last_combo" },
		{ label = "statline_stat_total_kills", value = "total_kills" },
		{ label = "statline_stat_kills_interval", value = "kills_interval" },
		{ label = "statline_stat_dps", value = "dps" },
		{ label = "statline_stat_fatigue_pct", value = "fatigue_pct" },
		{ label = "statline_stat_fury_pct", value = "fury_pct" },
	}
end

local lr_slot_options = function()
	return {
		{ label = "slot_none", value = "none" },
		{ label = "slot_element_score", value = "score" },
		{ label = "slot_element_fury", value = "fury" },
		{ label = "slot_element_objective", value = "objective" },
		{ label = "slot_element_stats", value = "stats" },
	}
end

local center_slot_options = function()
	return {
		{ label = "slot_none", value = "none" },
		{ label = "slot_element_fury", value = "fury" },
	}
end

local dopamine_palette = {
	{ key = "dopamine_rank_d", value = mod.constants.COLOR.FURY_RANK.D },
	{ key = "dopamine_rank_c", value = mod.constants.COLOR.FURY_RANK.C },
	{ key = "dopamine_rank_b", value = mod.constants.COLOR.FURY_RANK.B },
	{ key = "dopamine_rank_a", value = mod.constants.COLOR.FURY_RANK.A },
	{ key = "dopamine_rank_s", value = mod.constants.COLOR.FURY_RANK.S },
	{ key = "dopamine_rank_ss", value = mod.constants.COLOR.FURY_RANK.SS },
	{ key = "dopamine_rank_sss", value = mod.constants.COLOR.FURY_RANK.SSS },
	{ key = "dopamine_rank_x", value = mod.constants.COLOR.FURY_RANK.X },
	{ key = "dopamine_white", value = mod.constants.COLOR.UI_FOREGROUND },
	{ key = "dopamine_green", value = mod.constants.COLOR.NUMBERS.GREEN },
	{ key = "dopamine_orange", value = mod.constants.COLOR.NUMBERS.ORANGE },
	{ key = "dopamine_yellow", value = mod.constants.COLOR.NUMBERS.YELLOW },
	{ key = "dopamine_red", value = mod.constants.COLOR.NUMBERS.RED },
}

local gw_palette = mod.dl.colors.sort_colors(mod.dl.colors.reg.gw)

local fury_palette = table.clone(dopamine_palette)

for i = 1, #gw_palette do
	fury_palette[#fury_palette + 1] = gw_palette[i]
end

local color_dropdown = function(key)
	local options, default_str = mod.dl.data.dropdown_color_options(fury_palette, mod.dl.settings.defaults[key])

	for i = 1, #options do
		options[i].color = options[i].text
	end

	return dropdown(key):default(default_str):options(options)
end

local font_options = function(key)
	local options = mod.dl.data.dropdown_font_options(key)

	for i = 1, #options do
		local font_type = options[i].value
		options[i].text = nil
		options[i].label_key = font_type
		options[i].font_type = font_type
	end

	return options
end

---@type DLH_SettingsMenuSchema
local Schema = {}

local debug_schema = {
	tab("tab_fine_tuning"):rows({
		{
			numeric("fury_min_damage_gain"):range(0.5, 10.0):unit("%"):step(0.5):span(3),
			numeric("fury_max_damage_gain"):range(5.0, 15.0):unit("%"):span(3),
		},
		{ numeric("fury_drain_seconds"):range(5, 20):span(6) },
		{ numeric("max_fury_fatigue_add"):range(0, 100):span(6) },
		heading("fine_tuning_fatigue"):as_row(),
		{
			numeric("fatigue_min_damage_gain"):range(0.0, 20.0):span(3),
			numeric("fatigue_max_damage_gain"):range(0.0, 50.0):span(3),
		},
		{ numeric("fury_fatigue_drain_rate_pct"):range(50, 300):step(50):span(6) },
		{ numeric("fury_min_gain_mult"):range(0.00, 1.00):span(6) },
		heading("fine_tuning_grace"):as_row(),
		{
			numeric("grace_duration"):range(0.0, 1.5):span(2),
			numeric("grace_max"):range(1.0, 1.5):span(2),
			numeric("grace_min_duration_mult"):range(0.05, 0.25):step(0.05):span(2),
		},
	}),
	tab("tab_debug"):rows({
		heading("heading_debug_events"):as_row(),
		{ checkbox("debug_enable_permanent_events"):span(6) },
		heading("heading_debug_fury"):as_row(),
		{
			keybind("debug_lock_fury_toggle"):call("__debug__toggle_fury_lock"):span(2),
			keybind("debug_add_10_fury"):call("__debug__add_10_debug_fury"):span(2),
			keybind("debug_take_10_fury"):call("__debug__take_10_debug_fury"):span(2),
		},
		{ checkbox("debug_log_fury_fatigue_gain"):span(3), checkbox("debug_lock_fury_fatigue"):span(3) },
		{
			numeric("debug_fury_pct"):range(0, 200):step(10):span(3),
			numeric("debug_fatigue_pct"):range(0, 100):step(20):span(3),
		},
		{ checkbox("debug_show_test_callout"):span(6) },
		heading("debug_tasks"):as_row(),
		{
			checkbox("debug_trigger_tasks_manually"):span(2),
			keybind("debug_cycle_objective_keybind"):call("__debug__cycle_objective"):span(2),
			keybind("debug_trigger_objective_keybind"):call("__debug__trigger_task"):span(2),
		},
		heading("debug_layout"):as_row(),
		{ checkbox("debug_layout_boxes"):span(6) },
		{ keybind("debug_toggle_mission_speaker_speaker"):call("__debug__toggle_mission_speaker"):span(6) },
		heading("debug_mission_summary"):as_row(),
		{
			keybind("debug_simulate_end_mission"):call("__debug__simulate_end_mission"):span(3),
			keybind("debug_create_dummy_entry"):call("__debug__create_dummy_entry"):span(3),
		},
	}),
}

local user_schema = {
	tab("tab_accessibility"):rows({
		heading("heading_rumbling"):description():as_row(),
		{
			checkbox("enable_rumble_global"):label("master_toggle"):span(2),
			checkbox("enable_rumble_on_gain"):span(2):disabled(function()
				return mod.dl.settings.enable_rumble_global ~= true
			end),
			checkbox("enable_bar_rumble_on_expire"):span(2):disabled(function()
				return mod.dl.settings.enable_rumble_global ~= true
			end),
		},
	}),
	tab("tab_missions"):rows({
		heading("heading_missions"):as_row(),
		{
			checkbox("enable_mission_summary"):span(3),
			checkbox("skip_mission_recap"):span(3):disabled(function()
				return mod.dl.settings.enable_mission_summary ~= true
			end),
		},
		heading("heading_danger_zone"):description():as_row(),
		{
			dropdown("wipe_history_confirmation")
				:options({
					"confirmed",
					"unconfirmed",
				})
				:span(6),
		},
		{
			button("wipe_history")
				:span(6)
				:disabled(function()
					return mod:get("wipe_history_confirmation") ~= "confirmed"
				end)
				:on_click(function(event)
					if mod:get("wipe_history_confirmation") ~= "confirmed" then
						return
					end
					local History = mod:core(mod.mission_summary_history, "utils/mission_summary/history_store")
					local removed = History.clear_all()
					mod:echo("Cleared " .. tostring(removed) .. " mission summary record(s).")
				end),
		},
	}),
	tab("tab_difficulty"):rows({

		heading("heading_fury_bar", "fury"):as_row(),
		{ numeric("fury_damage_reference"):range(50, 300):step(25):span(4) },
		{ numeric("fury_damage_penalty"):unit("%"):range(0.05, 1.00):step(0.05):span(4) },

		{ numeric("fury_damage_mult"):unit("x"):range(0.3, 0.5):step(0.05):span(4) },
	}),
	tab("tab_performance"):rows({
		heading("heading_markers_performance"):as_row(),
		{
			numeric("max_active_markers"):range(2, 16):span(3),
		},
		heading("heading_statline_performance"):as_row(),
		{
			numeric("statline_dps_update_hz"):range(1, 16):span(3):unit("hz"),
		},
	}),
	tab("tab_layout"):rows({
		heading("heading_margin_editor"):description():as_row(),
		{
			button("margin_editor_toggle_keybind")
				:on_click(function(event)
					event.close_menu()
					mod.__toggle_margin_editor()
				end)
				:span(6),
		},
		heading("heading_layout_left"):as_row(),
		{
			dropdown("slot_left"):label("slot_1"):options(lr_slot_options()):span(3),
			dropdown("chat_reposition")
				:options({
					{ label = "hud_reposition_on", value = "on" },
					{ label = "hud_reposition_off", value = "off" },
				})
				:span(3),
		},
		{
			dropdown("slot_left_2"):label("slot_2"):options(lr_slot_options()):span(3),
			dropdown("killfeed_disable")
				:options({
					{ label = "killfeed_disable_on", value = "on" },
					{ label = "killfeed_disable_off", value = "off" },
				})
				:span(3),
		},
		{
			dropdown("slot_left_3"):label("slot_3"):options(lr_slot_options()):span(3),
		},
		{
			dropdown("slot_left_4"):label("slot_4"):options(lr_slot_options()):span(3),
		},
		heading("heading_layout_center"):as_row(),
		{ dropdown("slot_center"):label("slot_1"):options(center_slot_options()):span(3) },
		heading("heading_layout_right"):as_row(),
		{
			dropdown("slot_right_1"):label("slot_1"):options(lr_slot_options()):span(3),
			dropdown("mission_speaker_reposition")
				:options({
					{ label = "hud_reposition_on", value = "on" },
					{ label = "hud_reposition_off", value = "off" },
				})
				:span(3),
		},
		{
			dropdown("slot_right_2"):label("slot_2"):options(lr_slot_options()):span(3),
		},
		{
			dropdown("slot_right_3"):label("slot_3"):options(lr_slot_options()):span(3),
		},
		{
			dropdown("slot_right_4"):label("slot_4"):options(lr_slot_options()):span(3),
		},
	}),
	tab("tab_customisation"):rows({

		heading("heading_customisation_fury_rank"):as_row(),
		{
			checkbox("enable_fury_rank_text"):label("master_toggle"):span(3),
			checkbox("enable_class_specific_fury_ranks"):span(3):disabled(function()
				return mod.dl.settings.enable_fury_rank_text ~= true
			end),
		},
		heading("heading_customisation_fury_bar"):as_row(),
		{
			dropdown("fury_meter_theme")
				:label("theme")
				:options({
					{ label = "fury_meter_theme_ui", value = "ui" },
					{ label = "fury_meter_theme_gritty", value = "gritty" },
				})
				:span(6),
		},
		{
			numeric("fury_meter_width"):label("width"):unit("px"):range(200, 600):step(25):span(3),
			numeric("fury_meter_height"):label("height"):unit("px"):range(2, 20):span(3),
		},
		heading("headings_customisation_events"):as_row(),
		{ numeric("max_event_slots"):range(6, 12):span(6) },
		{
			checkbox("enable_breed_kill_events"):span(3),
			checkbox("enable_colored_breed_kills"):span(3):disabled(function()
				return mod.dl.settings.enable_breed_kill_events ~= true
			end),
		},
		heading("heading_popups_customisation"):as_row(),
		{
			checkbox("enable_kill_markers"):label("master_toggle"):span(2),
			checkbox("enable_immersive_markers"):span(2):disabled(function()
				return mod.dl.settings.enable_kill_markers ~= true
			end),
			numeric("marker_fade_duration")
				:label("duration")
				:unit("s")
				:range(0.25, 3.00)
				:step(0.25)
				:span(2)
				:disabled(function()
					return mod.dl.settings.enable_kill_markers ~= true
				end),
		},
		heading("heading_customisation_statline"):as_row(),
		{
			dropdown("statline_segment_1"):label("slot_1"):options(statline_segment_options()):span(3),
			dropdown("statline_segment_2"):label("slot_2"):options(statline_segment_options()):span(3),
		},
		{
			dropdown("statline_segment_3"):label("slot_3"):options(statline_segment_options()):span(3),
			dropdown("statline_segment_4"):label("slot_4"):options(statline_segment_options()):span(3),
		},
		{
			numeric("statline_kpm_interval_seconds"):range(5, 60):step(5):span(6):hidden(function()
				return not mod.dl.settings.statline_active_stats
					or mod.dl.settings.statline_active_stats.kills_interval ~= true
			end),
		},
		heading("heading_fury_colors"):as_row(),
		{ color_dropdown("fury_color_stop_1"):span(3) },
		{ color_dropdown("fury_color_stop_2"):span(3) },
		{ color_dropdown("fury_color_stop_3"):span(3) },
		{ color_dropdown("fury_color_stop_4"):span(3) },
		{ color_dropdown("fury_color_stop_5"):span(3) },
		{ color_dropdown("fury_color_stop_6"):span(3) },
		{ color_dropdown("fury_color_stop_7"):span(3) },
		{ color_dropdown("fury_color_stop_8"):span(3) },
		{ color_dropdown("fury_color_stop_9"):span(3) },
		heading("headings_customisation_tasks"):as_row(),
		{
			dropdown("task_track_theme")
				:label("theme")
				:options({
					{ label = "task_track_theme_simple", value = "simple" },
					{ label = "task_track_theme_ui", value = "ui" },
				})
				:span(6),
		},
		heading("heading_stat_chart_customisation"):as_row(),
		{ color_dropdown("stat_chart_bar_color"):span(6) },
		{ keybind("stat_chart_cycle_keybind"):call("__cycle_stat_chart"):span(6) },
	}),
	tab("tab_fonts"):rows({
		heading("heading_style_meter_fonts"):as_row(),
		{
			dropdown("style_meter_font_type"):options(font_options("style_meter_font_type")):span(3),
			numeric("events_font_size"):range(-8, 8):span(3),
		},
		{ numeric("sp_counter_font_size"):range(-8, 8):span(3):at(4) },
		heading("heading_fury_fonts"):as_row(),
		{
			dropdown("fury_rank_font_type"):options(font_options("fury_rank_font_type")):span(3),
			numeric("fury_rank_font_size"):range(30, 60):step(2):span(3),
		},
		{ numeric("statline_font_size"):range(8, 20):span(3):at(4) },

		heading("heading_marker_fonts"):as_row(),
		{
			dropdown("marker_font_type"):options(font_options("marker_font_type")):span(3),
			numeric("marker_font_size"):range(8, 22):span(3),
		},
	}),
	tab("tab_fury_and_fatigue"):rows({
		heading("fatigue_tuning"):as_row(),
		{
			numeric("fatigue_kill_mult"):range(0.05, 1.00):step(0.05):span(3),
			numeric("fatigue_damage_mult"):range(0.05, 1.00):step(0.05):span(3),
		},
		{
			numeric("fatigue_milestone_interval"):range(1, 20):span(3),
			numeric("fatigue_milestone_reduction"):unit("%"):range(1, 100):span(3),
		},
		{
			numeric("breed_relief_elite_fatigue"):unit("%"):range(1, 50):span(3),
			numeric("breed_relief_special_fatigue"):unit("%"):range(1, 50):span(3),
		},

		heading("fatigue_timer"):as_row(),
		{
			numeric("fatigue_passive_ramp_seconds"):unit("s"):range(30, 120):span(3),
			numeric("fatigue_passive_per_second"):unit("%/s"):range(1, 10):span(3),
		},
		heading("grace_tuning"):as_row(),
		{
			numeric("grace_per_damage"):range(0.005, 0.025):step(0.005):span(3),
			numeric("grace_drain_percent"):unit("%"):range(1, 20):span(3),
		},
	}),
}

local debug = mod:get("__debug__")

if debug then
	for index, value in ipairs(debug_schema) do
		table.insert(Schema, index, value)
	end
end

for index, value in ipairs(user_schema) do
	table.insert(Schema, index + (debug and #debug_schema or 0), value)
end

mod.settings_schema = Schema

return Schema
