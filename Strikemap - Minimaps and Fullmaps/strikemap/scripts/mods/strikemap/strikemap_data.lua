local mod = get_mod("strikemap")

local function checkbox(setting_id, default_value, tooltip)
	return {
		setting_id = setting_id,
		type = "checkbox",
		default_value = default_value,
		tooltip = tooltip,
	}
end

local function numeric(setting_id, default_value, min, max, step, tooltip)
	return {
		setting_id = setting_id,
		type = "numeric",
		default_value = default_value,
		range = { min, max },
		step_size_value = step,
		tooltip = tooltip,
	}
end

local function dropdown(setting_id, default_value, tooltip, options)
	return {
		setting_id = setting_id,
		type = "dropdown",
		default_value = default_value,
		tooltip = tooltip,
		options = options,
	}
end

local function keybind(setting_id, function_name)
	return {
		setting_id = setting_id,
		type = "keybind",
		default_value = {},
		keybind_trigger = "pressed",
		keybind_type = "function_call",
		function_name = function_name,
	}
end

-- Opens/closes a registered DMF UIView (handles cursor + input blocking).
local function keybind_view(setting_id, view_name)
	return {
		setting_id = setting_id,
		type = "keybind",
		default_value = {},
		keybind_trigger = "pressed",
		keybind_type = "view_toggle",
		view_name = view_name,
	}
end

local COLOR_NAMES = {
	"red",
	"crimson",
	"scarlet",
	"vermilion",
	"coral",
	"salmon",
	"orange",
	"tangerine",
	"amber",
	"gold",
	"yellow",
	"lemon",
	"chartreuse",
	"lime",
	"green",
	"emerald",
	"jade",
	"mint",
	"teal",
	"turquoise",
	"cyan",
	"aqua",
	"sky",
	"azure",
	"blue",
	"cobalt",
	"indigo",
	"violet",
	"purple",
	"plum",
	"magenta",
	"pink",
	"hot_pink",
	"rose",
	"lavender",
	"white",
	"ivory",
	"silver",
	"steel",
}

local function color_options()
	local options = {}

	for i = 1, #COLOR_NAMES do
		options[i] = { text = "color_" .. COLOR_NAMES[i], value = COLOR_NAMES[i] }
	end

	return options
end

local function color_dropdown(setting_id, default_value, tooltip)
	return dropdown(setting_id, default_value, tooltip or setting_id .. "_tooltip", color_options())
end

local function stimm_color_options()
	local options = {
		{ text = "stimm_color_by_type", value = "by_type" },
	}
	local colors = color_options()

	for i = 1, #colors do
		options[#options + 1] = colors[i]
	end

	return options
end

local function enemy_icon_options()
	return {
		{ text = "style_enemy_priority", value = "enemy_priority" },
		{ text = "style_skull", value = "skull" },
		{ text = "style_enemy", value = "enemy" },
		{ text = "style_dot", value = "dot" },
		{ text = "style_diamond", value = "diamond" },
		{ text = "style_square", value = "square" },
		{ text = "style_triangle", value = "triangle" },
		{ text = "style_cross", value = "cross" },
	}
end

local ENEMY_TYPES = {
	{ key = "chaos_poxwalker", color = "red", icon = "dot" },
	{ key = "chaos_newly_infected", color = "red", icon = "dot" },
	{ key = "chaos_lesser_mutated_poxwalker", color = "red", icon = "dot" },
	{ key = "chaos_mutated_poxwalker", color = "red", icon = "dot" },
	{ key = "chaos_armored_infected", color = "red", icon = "dot" },
	{ key = "renegade_melee", color = "red", icon = "dot" },
	{ key = "renegade_assault", color = "red", icon = "dot" },
	{ key = "renegade_rifleman", color = "red", icon = "dot" },
	{ key = "cultist_melee", color = "red", icon = "dot" },
	{ key = "cultist_assault", color = "red", icon = "dot" },
	{ key = "cultist_rifleman", color = "red", icon = "dot" },
	{ key = "renegade_executor", color = "orange", icon = "enemy" },
	{ key = "chaos_ogryn_executor", color = "orange", icon = "enemy" },
	{ key = "chaos_ogryn_bulwark", color = "orange", icon = "enemy" },
	{ key = "chaos_ogryn_gunner", color = "orange", icon = "enemy" },
	{ key = "renegade_berzerker", color = "orange", icon = "enemy" },
	{ key = "cultist_berzerker", color = "orange", icon = "enemy" },
	{ key = "renegade_gunner", color = "orange", icon = "enemy" },
	{ key = "cultist_gunner", color = "orange", icon = "enemy" },
	{ key = "renegade_shocktrooper", color = "orange", icon = "enemy" },
	{ key = "cultist_shocktrooper", color = "orange", icon = "enemy" },
	{ key = "renegade_plasma_gunner", color = "orange", icon = "enemy" },
	{ key = "renegade_flamer", color = "yellow", icon = "enemy_priority" },
	{ key = "cultist_flamer", color = "yellow", icon = "enemy_priority" },
	{ key = "renegade_netgunner", color = "yellow", icon = "enemy_priority" },
	{ key = "renegade_grenadier", color = "yellow", icon = "enemy_priority" },
	{ key = "cultist_grenadier", color = "yellow", icon = "enemy_priority" },
	{ key = "renegade_sniper", color = "yellow", icon = "enemy_priority" },
	{ key = "cultist_mutant", color = "yellow", icon = "enemy_priority" },
	{ key = "chaos_hound", color = "yellow", icon = "enemy_priority" },
	{ key = "chaos_armored_hound", color = "yellow", icon = "enemy_priority" },
	{ key = "chaos_ogryn_houndmaster", color = "yellow", icon = "enemy_priority" },
	{ key = "chaos_poxwalker_bomber", color = "yellow", icon = "enemy_priority" },
	{ key = "renegade_radio_operator", color = "yellow", icon = "enemy_priority" },
	{ key = "cultist_ritualist", color = "yellow", icon = "enemy_priority" },
	{ key = "chaos_plague_ogryn", color = "red", icon = "enemy_priority" },
	{ key = "chaos_spawn", color = "red", icon = "enemy_priority" },
	{ key = "chaos_beast_of_nurgle", color = "red", icon = "enemy_priority" },
	{ key = "chaos_daemonhost", color = "red", icon = "enemy_priority" },
	{ key = "renegade_captain", color = "red", icon = "enemy_priority" },
	{ key = "cultist_captain", color = "red", icon = "enemy_priority" },
	{ key = "renegade_twin_captain", color = "red", icon = "enemy_priority" },
	{ key = "cultist_twin_captain", color = "red", icon = "enemy_priority" },
}

local function enemy_type_widgets()
	local widgets = {
		checkbox("enemy_type_overrides", false, "enemy_type_overrides_tooltip"),
	}

	for i = 1, #ENEMY_TYPES do
		local enemy_type = ENEMY_TYPES[i]
		local prefix = "enemy_type_" .. enemy_type.key

		widgets[#widgets + 1] = dropdown(prefix .. "_icon", enemy_type.icon, "enemy_type_icon_tooltip", enemy_icon_options())
		widgets[#widgets + 1] = color_dropdown(prefix .. "_color", enemy_type.color, "enemy_type_color_tooltip")
		widgets[#widgets + 1] = numeric(prefix .. "_scale", 100, 50, 250, 10, "enemy_type_scale_tooltip")
	end

	return widgets
end

return {
	name = "Strikemap",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "strikemap_general",
				type = "group",
				tab = "General",
				sub_widgets = {
					checkbox("enable_minimap", true, "enable_minimap_tooltip"),
					dropdown("map_theme", "terminal", "map_theme_tooltip", {
						{ text = "theme_terminal", value = "terminal" },
						{ text = "theme_round", value = "round" },
						{ text = "theme_clean", value = "clean" },
						{ text = "theme_clean_circle", value = "clean_circle" },
						{ text = "theme_ghost", value = "ghost" },
					}),
					dropdown("floor_style", "tactical", "floor_style_tooltip", {
						{ text = "floor_style_tactical", value = "tactical" },
						{ text = "floor_style_classic", value = "classic" },
					}),
					checkbox("show_veil", true, "show_veil_tooltip"),
					checkbox("show_hatchwork", false, "show_hatchwork_tooltip"),
					dropdown("map_corner", "top_right", "map_corner_tooltip", {
						{ text = "corner_top_right", value = "top_right" },
						{ text = "corner_top_left", value = "top_left" },
						{ text = "corner_top_center", value = "top_center" },
						{ text = "corner_bottom_right", value = "bottom_right" },
						{ text = "corner_bottom_left", value = "bottom_left" },
						{ text = "corner_bottom_center", value = "bottom_center" },
						{ text = "corner_center", value = "center" },
					}),
					numeric("map_offset_x", 0, -600, 600, 10, "map_offset_x_tooltip"),
					numeric("map_offset_y", 0, -400, 400, 10, "map_offset_y_tooltip"),
					numeric("map_size", 280, 180, 440, 20, "map_size_tooltip"),
					numeric("map_zoom", 55, 25, 130, 5, "map_zoom_tooltip"),
					numeric("map_opacity", 60, 0, 100, 5, "map_opacity_tooltip"),
					numeric("map_contents_opacity", 100, 10, 100, 5, "map_contents_opacity_tooltip"),
					checkbox("rotate_with_camera", true, "rotate_with_camera_tooltip"),
					dropdown("marker_visibility_mode", "team_los", "marker_visibility_mode_tooltip", {
						{ text = "marker_visibility_team_los", value = "team_los" },
						{ text = "marker_visibility_self_los", value = "self_los" },
						{ text = "marker_visibility_all", value = "all" },
					}),
					checkbox("show_sight_cones", true, "show_sight_cones_tooltip"),
					checkbox("show_scanner_sweep", true, "show_scanner_sweep_tooltip"),
					checkbox("integrate_objectives", true, "integrate_objectives_tooltip"),
					checkbox("show_when_no_map", true, "show_when_no_map_tooltip"),
					checkbox("fullmap_rotate", false, "fullmap_rotate_tooltip"),
					checkbox("record_reports", true, "record_reports_tooltip"),
					checkbox("record_psykhanium", false, "record_psykhanium_tooltip"),
					checkbox("auto_open_report", true, "auto_open_report_tooltip"),
					checkbox("feed_stream_replay", true, "feed_stream_replay_tooltip"),
					dropdown("auto_replay_speed", 8, "auto_replay_speed_tooltip", {
						{ text = "replay_speed_4", value = 4 },
						{ text = "replay_speed_8", value = 8 },
						{ text = "replay_speed_16", value = 16 },
						{ text = "replay_speed_32", value = 32 },
						{ text = "replay_speed_64", value = 64 },
					}),
					checkbox("expedition_live_map", true, "expedition_live_map_tooltip"),
					numeric("floors_above", 12, 0, 20, 1, "floors_above_tooltip"),
					numeric("floors_below", 16, 0, 24, 1, "floors_below_tooltip"),
				},
			},
			{
				setting_id = "strikemap_allies",
				type = "group",
				tab = "Allies",
				sub_widgets = {
					checkbox("show_teammates", true, "show_teammates_tooltip"),
					checkbox("show_ally_health", true, "show_ally_health_tooltip"),
					checkbox("show_ally_facing", true, "show_ally_facing_tooltip"),
					checkbox("show_ally_distress", true, "show_ally_distress_tooltip"),
					checkbox("show_ally_badges", true, "show_ally_badges_tooltip"),
					dropdown("ally_style", "class_icon", "ally_style_tooltip", {
						{ text = "style_class_icon", value = "class_icon" },
						{ text = "style_diamond", value = "diamond" },
						{ text = "style_dot", value = "dot" },
						{ text = "style_ring", value = "ring" },
					}),
					dropdown("ally_color_mode", "slot_colors", "ally_color_mode_tooltip", {
						{ text = "ally_color_mode_slot", value = "slot_colors" },
						{ text = "ally_color_mode_fixed", value = "fixed" },
					}),
					color_dropdown("ally_color", "cyan"),
					checkbox("show_player_pings", true, "show_player_pings_tooltip"),
					checkbox("show_objectives", true, "show_objectives_tooltip"),
					checkbox("show_live_gates", true, "show_live_gates_tooltip"),
					checkbox("show_tactical_updates", true, "show_tactical_updates_tooltip"),
					dropdown("objective_style", "icon", "objective_style_tooltip", {
						{ text = "style_icon", value = "icon" },
						{ text = "style_diamond", value = "diamond" },
					}),
					color_dropdown("objective_color", "gold"),
				},
			},
			{
				setting_id = "strikemap_items",
				type = "group",
				tab = "Items",
				sub_widgets = {
					checkbox("show_medicae", true, "show_medicae_tooltip"),
					dropdown("medicae_style", "icon", "medicae_style_tooltip", {
						{ text = "style_icon", value = "icon" },
						{ text = "style_cross", value = "cross" },
					}),
					color_dropdown("medicae_color", "green"),
					checkbox("show_medicae_charges", true, "show_medicae_charges_tooltip"),
					checkbox("show_supplies", true, "show_supplies_tooltip"),
					color_dropdown("supplies_color", "amber"),
					checkbox("show_books", true, "show_books_tooltip"),
					color_dropdown("books_color", "violet"),
					checkbox("show_ammo_pickups", true, "show_ammo_pickups_tooltip"),
					color_dropdown("ammo_pickups_color", "amber"),
					checkbox("show_grenades", true, "show_grenades_tooltip"),
					color_dropdown("grenades_color", "orange"),
					checkbox("show_ammo_crates", true, "show_ammo_crates_tooltip"),
					color_dropdown("ammo_crates_color", "amber"),
					checkbox("show_med_crates", true, "show_med_crates_tooltip"),
					color_dropdown("med_crates_color", "green"),
					checkbox("show_stimms", true, "show_stimms_tooltip"),
					dropdown("stimms_color", "by_type", "stimms_color_tooltip", stimm_color_options()),
					checkbox("show_materials", false, "show_materials_tooltip"),
					color_dropdown("materials_color", "steel"),
				},
			},
			{
				setting_id = "strikemap_enemies",
				type = "group",
				tab = "Enemies",
				sub_widgets = {
					checkbox("show_monsters", true, "show_monsters_tooltip"),
					dropdown("monster_icon", "enemy_priority", "monster_icon_tooltip", enemy_icon_options()),
					color_dropdown("monster_color", "red"),
					checkbox("show_specials", true, "show_specials_tooltip"),
					dropdown("special_icon", "enemy_priority", "special_icon_tooltip", enemy_icon_options()),
					color_dropdown("special_color", "yellow"),
					checkbox("show_elites", true, "show_elites_tooltip"),
					dropdown("elite_icon", "enemy", "elite_icon_tooltip", enemy_icon_options()),
					color_dropdown("elite_color", "orange"),
					checkbox("show_horde", true, "show_horde_tooltip"),
					dropdown("horde_icon", "dot", "horde_icon_tooltip", enemy_icon_options()),
					color_dropdown("horde_color", "red"),
				},
			},
			{
				setting_id = "strikemap_enemy_types",
				type = "group",
				tab = "Enemy Types",
				sub_widgets = enemy_type_widgets(),
			},
			{
				setting_id = "strikemap_performance",
				type = "group",
				tab = "Performance",
				sub_widgets = {
					numeric("perf_enemy_scan_range", 90, 30, 90, 10, "perf_enemy_scan_range_tooltip"),
					dropdown("perf_enemy_tick", 150, "perf_enemy_tick_tooltip", {
						{ text = "perf_tick_fast", value = 150 },
						{ text = "perf_tick_balanced", value = 250 },
						{ text = "perf_tick_relaxed", value = 400 },
					}),
					dropdown("perf_horde_los", "cone", "perf_horde_los_tooltip", {
						{ text = "perf_los_cone", value = "cone" },
						{ text = "perf_los_raycast", value = "raycast" },
					}),
					dropdown("perf_map_tri_budget", 1400, "perf_map_tri_budget_tooltip", {
						{ text = "perf_tris_400", value = 400 },
						{ text = "perf_tris_900", value = 900 },
						{ text = "perf_tris_1400", value = 1400 },
						{ text = "perf_tris_unlimited", value = 0 },
					}),
					dropdown("perf_fullmap_fidelity", "high", "perf_fullmap_fidelity_tooltip", {
						{ text = "perf_quality_high", value = "high" },
						{ text = "perf_quality_low", value = "low" },
					}),
					dropdown("perf_effects_quality", "high", "perf_effects_quality_tooltip", {
						{ text = "perf_quality_high", value = "high" },
						{ text = "perf_quality_low", value = "low" },
						{ text = "perf_quality_off", value = "off" },
					}),
					dropdown("perf_ally_status_rate", 100, "perf_ally_status_rate_tooltip", {
						{ text = "perf_status_every_frame", value = 0 },
						{ text = "perf_status_10hz", value = 100 },
						{ text = "perf_status_4hz", value = 250 },
					}),
					dropdown("perf_report_autosave", 60, "perf_report_autosave_tooltip", {
						{ text = "perf_autosave_30", value = 30 },
						{ text = "perf_autosave_60", value = 60 },
						{ text = "perf_autosave_end", value = 0 },
					}),
					checkbox("perf_combat_tracking", true, "perf_combat_tracking_tooltip"),
					dropdown("perf_debrief_tri_budget", 12000, "perf_debrief_tri_budget_tooltip", {
						{ text = "perf_tris_3000", value = 3000 },
						{ text = "perf_tris_6000", value = 6000 },
						{ text = "perf_tris_12000", value = 12000 },
					}),
					dropdown("perf_debrief_heat_cell", 4, "perf_debrief_heat_cell_tooltip", {
						{ text = "perf_heat_fine", value = 4 },
						{ text = "perf_heat_coarse", value = 8 },
					}),
				},
			},
			{
				setting_id = "strikemap_keybinds",
				type = "group",
				tab = "Keybinds",
					sub_widgets = {
						keybind("kb_toggle_strikemap", "toggle_strikemap"),
					keybind("kb_toggle_fullmap", "toggle_fullmap"),
					keybind("kb_zoom_in", "strikemap_zoom_in"),
					keybind("kb_zoom_out", "strikemap_zoom_out"),
						keybind_view("kb_toggle_reports", "strikemap_report_view"),
					},
			},
			{
				setting_id = "strikemap_compat",
				type = "group",
				tab = "Compatibility",
				sub_widgets = {
					checkbox("compat_api_enabled", true, "compat_api_enabled_tooltip"),
					checkbox("compat_geometry_only", false, "compat_geometry_only_tooltip"),
					checkbox("compat_auto_geometry_only", false, "compat_auto_geometry_only_tooltip"),
				},
			},
		},
	},
}
