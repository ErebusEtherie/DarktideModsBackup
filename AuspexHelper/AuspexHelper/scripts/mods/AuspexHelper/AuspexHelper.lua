--[[
	File: AuspexHelper.lua
	Description: Main entry point for the Auspex Helper mod and module bootstrap.
	Overall Release Version: 1.0.0
	File Version: 1.0.0
	File Introduced in: 1.0.0
	Last Updated: 2026-03-14
	Author: LAUREHTE
]]

local mod = get_mod("AuspexHelper")

if not mod._message_filters_installed then
	mod._message_filters_installed = true
	mod._original_echo = mod.echo
	mod._original_notify = mod.notify
	mod._original_warn = mod.warn

	mod._messages_silenced = function(self)
		return self:get("debug_silence_messages") == true
	end

	function mod:echo(...)
		if self:_messages_silenced() then
			return
		end

		if self._original_echo then
			return self._original_echo(self, ...)
		end
	end

	function mod:notify(...)
		if self:_messages_silenced() then
			return
		end

		if self._original_notify then
			return self._original_notify(self, ...)
		end
	end

	function mod:warn(...)
		if self:_messages_silenced() then
			return
		end

		if self._original_warn then
			return self._original_warn(self, ...)
		end
	end
end

local MasterItems = require("scripts/backend/master_items")
local PlayerUnitVisualLoadout = require("scripts/extension_systems/visual_loadout/utilities/player_unit_visual_loadout")
local MinigameSettings = require("scripts/settings/minigame/minigame_settings")
local OutlineSettings = require("scripts/settings/outline/outline_settings")
local Pickups = require("scripts/settings/pickup/pickups")
local ScannerDisplayViewDecodeSearchSettings = require("scripts/ui/views/scanner_display_view/scanner_display_view_decode_search_settings")
local ScannerDisplayViewDecodeSymbolsSettings = require("scripts/ui/views/scanner_display_view/scanner_display_view_decode_symbols_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
mod._input_service_class = require("scripts/managers/input/input_service")
local OVERLAY_VIEW_NAME = "auspex_helper_overlay_view"
EXPEDITION_MINIMAP_VIEW_NAME = "auspex_helper_expedition_minimap_view"
local PREVIEW_VIEW_NAME = "auspex_helper_preview_view"
WORLD_SCAN_VIEW_NAME = "auspex_helper_world_scan_view"
WORLD_SCAN_ICONS_VIEW_NAME = "auspex_helper_world_scan_icons_view"
local STOCK_SCANNER_VIEW_NAME = "scanner_display_view"
local OVERLAY_VIEW_PATH = "AuspexHelper/scripts/mods/AuspexHelper/ui/auspex_practice_view"
mod._preview_close_timeout = 0.75
mod._preview_view_open_retry_interval = 0.25
local PREVIEW_VIEW_OPEN_TIMEOUT = 6
mod._practice_item_open_timeout = 2
local PRACTICE_DEVICE_SLOT = "slot_device"
local PRACTICE_SOUND_WEAPON_TEMPLATE = "communications_hack_device_pocketable"
PREVIEW_DECODE_SYMBOLS_12_TYPE = "decode_symbols_12"
PREVIEW_DECODE_SYMBOLS_12_STAGE_AMOUNT = 12
PREVIEW_DECODE_MAX_GRID_HEIGHT = 920
local LEGACY_EXPEDITION_MINIGAME_TYPE = rawget(MinigameSettings.types, "scan") or "scan"
local EXPEDITION_MINIGAME_TYPE = rawget(MinigameSettings.types, "decode_search") or rawget(MinigameSettings.types, "expedition") or LEGACY_EXPEDITION_MINIGAME_TYPE
local EXPEDITION_MAP_MINIGAME_TYPE = rawget(MinigameSettings.types, "expedition_map") or "expedition_map"
local EXPEDITION_MINIMAP_MINIGAME_TYPE = "auspex_helper_expedition_minimap"
local PICKUPS_BY_NAME = Pickups.by_name
mod._expedition_map_draw_offset_y = 0
if require("scripts/ui/views/scanner_display_view/scanner_display_view_expedition_map_settings").board_starting_offset_y ~= nil then
	require("scripts/ui/views/scanner_display_view/scanner_display_view_expedition_map_settings").board_starting_offset_y = 0
end
local PRACTICE_ITEM_IDS = {
	"content/items/pocketable/communications_hack_device_pocketable",
}

_is_auspex_helper_pass_through_view = function(view_name)
	return view_name == PREVIEW_VIEW_NAME
		or view_name == EXPEDITION_MINIMAP_VIEW_NAME
		or view_name == WORLD_SCAN_VIEW_NAME
		or view_name == WORLD_SCAN_ICONS_VIEW_NAME
end

_is_auspex_helper_overlay_pass_through_view = function(view_handler, view_name)
	if (view_name ~= OVERLAY_VIEW_NAME and view_name ~= EXPEDITION_MINIMAP_VIEW_NAME) or not view_handler or not view_handler._active_views_data then
		return false
	end

	local view_data = view_handler._active_views_data[view_name]
	local instance = view_data and view_data.instance
	local minigame_type = instance and instance._minigame_type

	if view_name == EXPEDITION_MINIMAP_VIEW_NAME then
		return instance ~= nil
	end

	return instance ~= nil and mod._is_expedition_map_minigame_type(minigame_type)
end

local scannable_units = {}
local scanner_world_helper_active = false
local preview_close_requested_at = nil
local preview_reopen_requested = false
local preview_close_view_name = nil
local preview_input_polling = false
local preview_input_simulation_active = false
local preview_input_simulation_service = nil
local practice_session = nil
local practice_scanner_item = nil
local practice_scanner_item_name = nil
local practice_scanner_item_lookup_complete = false
local practice_scanner_item_retry_at = 0
local MINIGAME_ENABLE_SETTINGS = {
	[MinigameSettings.types.decode_symbols] = "enable_decode_minigame",
	[PREVIEW_DECODE_SYMBOLS_12_TYPE] = "enable_decode_minigame",
	[MinigameSettings.types.drill] = "enable_drill_minigame",
	[MinigameSettings.types.frequency] = "enable_frequency_minigame",
	[MinigameSettings.types.balance] = "enable_balance_minigame",
	[EXPEDITION_MINIGAME_TYPE] = "enable_expedition_minigame",
	[LEGACY_EXPEDITION_MINIGAME_TYPE] = "enable_expedition_minigame",
	[EXPEDITION_MAP_MINIGAME_TYPE] = "enable_expedition_map_minigame",
	[EXPEDITION_MINIMAP_MINIGAME_TYPE] = "enable_expedition_map_minigame",
}
local SCANNER_HIDE_SETTING_IDS = {
	HudElementCrosshair = "scanner_hide_crosshair",
	HudElementCrosshairHud = "scanner_hide_crosshair_hud",
}
local SCANNER_EXCLUDED_ELEMENTS = {
	ConstantElementChat = true,
}
local SCANNER_SETTING_IDS = {
	enable_scanner_visibility = true,
	scanner_hide_crosshair = true,
	scanner_hide_crosshair_hud = true,
}
local scanner_ability_icons = {}
local scanner_equipped_active = false
local scanner_overlay_active = false
local scanner_searching_active = false
local scanner_current_alpha = 1
local scanner_subtitle_hook_applied = false
local decode_same_targets_count = 0
local decode_autosolve_cooldown = 0
local decode_autosolve_press_deadline = 0
local expedition_same_targets_count = 0
local expedition_autosolve_cooldown = 0
local expedition_autosolve_press_deadline = 0
local expedition_autosolve_move_cooldown = 0
local expedition_autosolve_input_pulse_until = 0
local frequency_autosolve_submit_cooldown = 0
local balance_cursor_x = 0
local balance_cursor_y = 0
local balance_previous_x = 0
local balance_previous_y = 0
local balance_velocity_x = 0
local balance_velocity_y = 0
local balance_distance = 0
local balance_input_window = 0
mod._empty_widgets_by_name = {}
mod._debug_category_setting_ids = {
	exp_autosolve = "debug_expedition_autosolve",
	exp_autosolve_input = "debug_expedition_autosolve",
	exp_markers = "debug_expedition_markers",
	exp_marker_projection = "debug_expedition_markers",
	exp_scanner_slots = "debug_expedition_slots",
	expedition_state = "debug_expedition_state",
	expedition_stuck = "debug_expedition_state",
	view_state = "debug_expedition_state",
	scanner_equipped = "debug_expedition_state",
	scanner_search = "debug_expedition_state",
	scanner_open_view = "debug_expedition_state",
	live_minigame = "debug_expedition_state",
	minigame_state = "debug_expedition_state",
	exp_map_overlay = "debug_expedition_state",
	exp_map_resolve = "debug_expedition_state",
	exp_map_minimap = "debug_expedition_state",
	overlay_view = "debug_expedition_state",
	live_overlay_open = "debug_expedition_state",
}
mod._debug_category_min_intervals = {
	exp_autosolve_input = 0.08,
	exp_map_minimap = 0.15,
}

mod._debug_enabled = function(key)
	if mod:get("debug_echoes") ~= false then
		return true
	end

	local setting_id = key and mod._debug_category_setting_ids[key] or nil

	return setting_id and mod:get(setting_id) == true or false
end

mod._debug_echo = function(...)
	if mod._debug_enabled() then
		local parts = {}

		for index = 1, select("#", ...) do
			parts[index] = tostring(select(index, ...))
		end

		local line = table.concat(parts, " ")

		pcall(print, line)
		mod:echo(...)
	end
end

mod._debug_event = function(key, message)
	if not mod._debug_enabled(key) then
		return
	end

	local events = mod._debug_events or {}

	mod._debug_events = events

	if message == nil then
		events[key] = nil

		return
	end

	message = tostring(message)

	if events[key] == message then
		return
	end

	local min_interval = key and mod._debug_category_min_intervals and mod._debug_category_min_intervals[key] or nil

	if min_interval and min_interval > 0 then
		local now = os.clock()
		local last_times = mod._debug_event_last_times or {}

		mod._debug_event_last_times = last_times

		local last_time = last_times[key] or 0

		if (now - last_time) < min_interval then
			return
		end

		last_times[key] = now
	end

	events[key] = message
	local line = string.format("[debug][%s] %s", tostring(key), message)

	pcall(print, line)
	mod:echo(line)
end

mod._debug_log_event = function(key, message)
	if not mod._debug_enabled(key) then
		return
	end

	local events = mod._debug_log_events or {}

	mod._debug_log_events = events

	if message == nil then
		events[key] = nil

		return
	end

	message = tostring(message)

	if events[key] == message then
		return
	end

	events[key] = message
	local line = string.format("[debug][%s] %s", tostring(key), message)

	pcall(print, line)

	if key == "exp_autosolve" then
		mod:echo(line)
	end
end

local _sync_scanner_hud_visibility
local _active_live_minigame
local _active_decode_autosolve_minigame
local _active_expedition_autosolve_minigame
local _active_frequency_autosolve_minigame
local _practice_session_blocks_live_autosolve

if not math.clamp then
	function math.clamp(value, minimum, maximum)
		return value < minimum and minimum or (value > maximum and maximum or value)
	end
end

local function _gameplay_time()
	local time_manager = Managers.time

	if not time_manager then
		return 0
	end

	if time_manager.has_timer and time_manager:has_timer("gameplay") then
		return time_manager:time("gameplay")
	end

	if time_manager.has_timer and time_manager:has_timer("main") then
		return time_manager:time("main")
	end

	return 0
end

local function _has_gameplay_timer()
	local time_manager = Managers.time

	return time_manager ~= nil and time_manager.has_timer ~= nil and time_manager:has_timer("gameplay")
end

local function _preview_supports_missing_gameplay_timer()
	return mod._preview_allow_missing_gameplay_timer == true
end

local function _ui_highlight_color(alpha_override)
	local alpha = alpha_override ~= nil and alpha_override or (mod:get("ui_color_alpha") or 210)

	return {
		alpha,
		mod:get("ui_color_red") or 255,
		mod:get("ui_color_green") or 165,
		mod:get("ui_color_blue") or 0,
	}
end

local function _world_scan_color(alpha_override)
	local alpha = alpha_override ~= nil and alpha_override or (mod:get("world_scan_color_alpha") or 255)

	return {
		alpha,
		mod:get("world_scan_color_red") or 0,
		mod:get("world_scan_color_green") or 255,
		mod:get("world_scan_color_blue") or 110,
	}
end

local function _world_scan_outline_color()
	local color = _world_scan_color()

	return {
		color[2] / 255,
		color[3] / 255,
		color[4] / 255,
	}
end

local function _world_scan_display_mode()
	return mod:get("world_scan_display_mode") or "highlight"
end

local function _world_scan_uses_highlight()
	local mode = _world_scan_display_mode()

	return mode == "highlight" or mode == "both"
end

local function _world_scan_uses_icon()
	local mode = _world_scan_display_mode()

	return mode == "icon" or mode == "both"
end

local function _is_expedition_minigame_type(minigame_type)
	return minigame_type == EXPEDITION_MINIGAME_TYPE or minigame_type == LEGACY_EXPEDITION_MINIGAME_TYPE
end

mod._is_expedition_map_minigame_type = function(minigame_type)
	return minigame_type == EXPEDITION_MAP_MINIGAME_TYPE
		or minigame_type == EXPEDITION_MINIMAP_MINIGAME_TYPE
end

_preview_display_minigame_type = function(minigame_type)
	if minigame_type == PREVIEW_DECODE_SYMBOLS_12_TYPE then
		return MinigameSettings.types.decode_symbols
	elseif _is_expedition_minigame_type(minigame_type) then
		return EXPEDITION_MINIGAME_TYPE
	end

	return minigame_type
end

local function _is_mod_active()
	return mod:is_enabled() and mod:get("enable_mod_override") ~= false
end

local function _should_highlight_world_scans()
	return _is_mod_active() and mod:get("enable_world_scans")
end

_world_scan_always_show = function()
	return _should_highlight_world_scans() and mod:get("world_scan_always_show") == true
end

_world_scan_effective_active = function()
	return _world_scan_always_show() or scanner_world_helper_active or scanner_equipped_active or scanner_searching_active
end

_world_scan_show_through_walls = function()
	return mod:get("world_scan_through_walls") ~= false
end

_world_scan_needs_visibility_refresh = function()
	return _should_highlight_world_scans() and not _world_scan_show_through_walls()
end

_world_scan_uses_item_overlay = function()
	return _should_highlight_world_scans() and mod:get("world_scan_item_overlay") == true
end

_scanner_scan_settings = function()
	if mod._scanner_scan_settings then
		return mod._scanner_scan_settings
	end

	local ok, scanner_equip_template = pcall(require, "scripts/settings/equipment/weapon_templates/devices/scanner_equip")
	local actions = ok and scanner_equip_template and scanner_equip_template.actions or nil
	local action_scan = actions and actions.action_scan or nil
	local action_scan_confirm = actions and actions.action_scan_confirm or nil
	local scan_settings = action_scan and action_scan.scan_settings or action_scan_confirm and action_scan_confirm.scan_settings

	if not scan_settings then
		scan_settings = {
			confirm_time = 1,
			fail_time_time = 0.6,
			outline_time = 0.5,
			distance = {
				far = 20,
				near = 6,
			},
			angle = {
				outer = 1.57075,
				inner = {
					far = 0.174533,
					near = 0.01,
				},
				line_of_sight_check = {
					horizontal = 0.174533,
					vertical = 0.698132,
				},
			},
			score_distribution = {
				angle = 0.2,
				distance = 0.8,
			},
		}
	end

	mod._scanner_scan_settings = scan_settings

	return scan_settings
end

local function _world_scan_collect_scannable_units(include_inactive)
	local state_managers = Managers.state
	local extension_manager = state_managers and state_managers.extension
	local result = {}

	if not extension_manager or not extension_manager:has_system("mission_objective_zone_system") then
		return result
	end

	local mission_objective_zone_system = extension_manager:system("mission_objective_zone_system")
	local mission_objective_system = extension_manager:has_system("mission_objective_system") and extension_manager:system("mission_objective_system") or nil

	if mission_objective_system then
		local active_objectives = mission_objective_system:active_objectives() or nil

		if active_objectives then
			for objective, _ in pairs(active_objectives) do
				local objective_name = objective and objective.name and objective:name() or nil
				local objective_group_id = objective and objective.group_id and objective:group_id() or nil
				local selected_units = nil

				if objective_name and objective_group_id ~= nil and mission_objective_zone_system.retrieve_selected_units_for_event then
					local ok, units = pcall(mission_objective_zone_system.retrieve_selected_units_for_event, mission_objective_zone_system, objective_name, objective_group_id)

					if ok then
						selected_units = units
					end
				end

				local zone_extension = objective_name and objective_group_id ~= nil and mission_objective_zone_system:current_active_zone(objective_name, objective_group_id) or nil
				local zone_units = zone_extension and zone_extension.scannable_units and zone_extension:scannable_units() or nil
				local candidate_sets = {
					selected_units,
					zone_units,
				}

				for set_index = 1, #candidate_sets do
					local units = candidate_sets[set_index]

					if units and #units > 0 then
						for i = 1, #units do
							local scannable_unit = units[i]

							if scannable_unit and Unit.alive(scannable_unit) then
								result[scannable_unit] = true
							end
						end
					end
				end
			end
		end
	end

	if next(result) ~= nil then
		return result
	end

	local active_scannables = mission_objective_zone_system and mission_objective_zone_system:scannable_units() or {}

	for scannable_unit, _ in pairs(active_scannables) do
		if Unit.alive(scannable_unit) then
			local scannable_extension = ScriptUnit.has_extension(scannable_unit, "mission_objective_zone_scannable_system")

			if scannable_extension and scannable_extension:is_active() then
				result[scannable_unit] = true
			end
		end
	end

	return result
end

_world_scan_player_context = function()
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(1) or nil
	local player_unit = player and player.player_unit or nil

	if not player_unit or not Unit.alive(player_unit) then
		return nil
	end

	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local interaction_extension = ScriptUnit.has_extension(player_unit, "interaction_system")
	local first_person = unit_data_extension and unit_data_extension:read_component("first_person")
	local physics_world = interaction_extension and interaction_extension._physics_world

	if not first_person or not physics_world then
		return nil
	end

	return player_unit, first_person, physics_world
end

_world_scan_has_active_scannables = function()
	if not scannable_units or next(scannable_units) == nil then
		_refresh_scannable_units()
	end

	for scannable_unit, _ in pairs(scannable_units) do
		if Unit.alive(scannable_unit) then
			local scannable_extension = ScriptUnit.has_extension(scannable_unit, "mission_objective_zone_scannable_system")

			if scannable_extension and (scannable_extension:is_active() or _world_scan_always_show()) then
				return true
			end
		end
	end

	return false
end

_request_world_scan_refresh = function(force_now)
	mod._world_scan_next_refresh_t = nil
	mod._world_scan_next_visibility_refresh_t = nil
	mod._debug_event("world_scan_refresh", string.format("requested force=%s active=%s searching=%s overlay=%s", tostring(force_now == true), tostring(_world_scan_effective_active()), tostring(scanner_searching_active), tostring(scanner_overlay_active)))

	if force_now and (_world_scan_effective_active() or scanner_searching_active or scanner_overlay_active) then
		_set_world_scan_highlights(_world_scan_effective_active())
		_refresh_world_scan_overlay_view()
		_refresh_world_scan_icons_view()
	end
end

_world_scan_unit_is_visible = function(scannable_unit, scannable_extension)
	if _world_scan_show_through_walls() then
		return true
	end

	local _, first_person, physics_world = _world_scan_player_context()
	local scan_settings = _scanner_scan_settings()

	if not first_person or not physics_world or not scan_settings then
		return true
	end

	local Scanning = require("scripts/utilities/scanning")
	local ok, result = pcall(Scanning.check_line_of_sight_to_unit, physics_world, first_person, scannable_unit, scan_settings, scannable_extension)

	if ok and result == true then
		return true
	end

	local from_position = first_person.position
	local target_position = scannable_extension and scannable_extension:center_poisition() or POSITION_LOOKUP[scannable_unit]

	if not from_position or not target_position then
		return true
	end

	local to_target = target_position - from_position
	local distance = Vector3.length(to_target)

	if distance <= 0.001 then
		return true
	end

	local blocked = PhysicsWorld.raycast(physics_world, from_position, Vector3.normalize(to_target), distance, "any", "collision_filter", "filter_interactable_line_of_sight_check")

	return not blocked
end

local function _is_minigame_enabled(minigame_type)
	if not _is_mod_active() then
		return false
	end

	local setting_id = MINIGAME_ENABLE_SETTINGS[minigame_type]

	if not setting_id then
		return true
	end

	return mod:get(setting_id) ~= false
end

local function _tag_minigame_type(minigame, minigame_type)
	if type(minigame) == "table" and minigame_type ~= nil then
		minigame._auspex_helper_minigame_type = minigame_type
	end

	return minigame
end

local function _minigame_type_hint(minigame)
	if type(minigame) ~= "table" then
		return nil
	end

	local hinted_type = rawget(minigame, "_auspex_helper_minigame_type") or rawget(minigame, "_minigame_type")

	if hinted_type then
		return hinted_type
	end

	if minigame.selected_level and minigame.world_pos_to_map_pos then
		return EXPEDITION_MAP_MINIGAME_TYPE
	end

	if minigame.current_decode_target
		and minigame.cursor_position
		and minigame.on_axis_set
		and (minigame.get_symbols_for_target or minigame.decode_targets or rawget(minigame, "_decode_targets"))
	then
		return EXPEDITION_MINIGAME_TYPE
	end

	if minigame.symbols and minigame.cursor_position and minigame.current_stage and minigame.on_axis_set and not minigame.current_decode_target then
		return EXPEDITION_MINIGAME_TYPE
	end

	return nil
end

local function _should_highlight_decode_targets()
	return _is_minigame_enabled(MinigameSettings.types.decode_symbols) and mod:get("enable_decode_helper")
end

local function _should_highlight_expedition_targets()
	return _is_minigame_enabled(EXPEDITION_MINIGAME_TYPE) and mod:get("enable_expedition_helper") ~= false
end

local function _should_highlight_drill_targets()
	return _is_minigame_enabled(MinigameSettings.types.drill) and mod:get("enable_drill_helper")
end

local function _should_show_drill_direction_arrows()
	return _is_minigame_enabled(MinigameSettings.types.drill) and mod:get("enable_drill_direction_arrows") ~= false
end

_is_drill_autosolve_enabled = function()
	return _is_minigame_enabled(MinigameSettings.types.drill) and mod:get("enable_drill_autosolve")
end

_drill_autosolve_speed = function()
	return math.clamp(mod:get("drill_autosolve_speed") or 1, 0.25, 3)
end

_drill_autosolve_step_delay = function()
	return math.max((MinigameSettings.drill_move_delay or 0.12) / _drill_autosolve_speed(), 0.02)
end

local function _is_scanner_visibility_enabled()
	return _is_mod_active() and mod:get("enable_scanner_visibility")
end

mod._expedition_map_zoom_scale = function()
	return math.clamp(mod:get("expedition_map_zoom_scale") or 1, 0.25, 3)
end

mod._expedition_map_marker_size = function()
	return math.clamp(mod:get("expedition_map_marker_size") or 24, 8, 48)
end

mod._expedition_map_marker_alpha = function()
	return math.clamp(mod:get("expedition_map_marker_alpha") or 255, 0, 255)
end

local function _is_decode_autosolve_enabled()
	return _is_minigame_enabled(MinigameSettings.types.decode_symbols) and mod:get("enable_decode_autosolve")
end

local function _is_expedition_autosolve_enabled()
	return _is_minigame_enabled(EXPEDITION_MINIGAME_TYPE) and mod:get("enable_expedition_autosolve")
end

local function _is_frequency_autosolve_enabled()
	return _is_minigame_enabled(MinigameSettings.types.frequency) and mod:get("enable_frequency_autosolve")
end

local function _is_balance_autosolve_enabled()
	return _is_minigame_enabled(MinigameSettings.types.balance) and mod:get("enable_balance_autosolve")
end

local function _clear_preview_close_request()
	preview_close_requested_at = nil
	preview_close_view_name = nil
end

local function _reset_scanner_fade_state()
	scanner_current_alpha = 1
end

local function _track_scanner_ability_icon(icon)
	if icon then
		scanner_ability_icons[icon] = true
	end
end

local function _untrack_scanner_ability_icon(icon)
	if icon then
		scanner_ability_icons[icon] = nil
	end
end

local function _is_buff_bar(class_name)
	return type(class_name) == "string" and (string.find(class_name, "^HudElementBuffBar") ~= nil or class_name == "HudElementPlayerBuffs")
end

local function _is_ability_icon(class_name)
	return type(class_name) == "string" and (string.find(class_name, "^HudElementPlayerAbility") ~= nil or string.find(class_name, "^HudElementPlayerSlotItemAbility") ~= nil)
end

local function _should_hide_scanner_element(class_name)
	if not _is_scanner_visibility_enabled() or SCANNER_EXCLUDED_ELEMENTS[class_name] then
		return false
	end

	if class_name == "ConstantElementChat" then
		return false
	end

	local setting_id = SCANNER_HIDE_SETTING_IDS[class_name]

	if setting_id then
		return mod:get(setting_id) ~= false
	end

	return false
end

local function _scanner_hidden_alpha()
	return 0
end

local function _overlay_scanner_view_active()
	local ui_manager = Managers.ui

	if not ui_manager then
		return false
	end

	local preview_active = ui_manager:view_active(PREVIEW_VIEW_NAME)
		or ui_manager:is_view_closing(PREVIEW_VIEW_NAME)
	local overlay_active = ui_manager:view_active(OVERLAY_VIEW_NAME)
		or ui_manager:is_view_closing(OVERLAY_VIEW_NAME)
	local expedition_overlay_active = overlay_active
		and _is_auspex_helper_overlay_pass_through_view(ui_manager._view_handler, OVERLAY_VIEW_NAME)

	return not not (preview_active or (overlay_active and not expedition_overlay_active))
end

mod._widget_has_visible_text = function(widget)
	if not widget then
		return false
	end

	local content = widget.content

	if not content or content.visible == false then
		return false
	end

	local text = content.text or content.display_text or content.value

	if type(text) ~= "string" or text == "" then
		return false
	end

	if widget.alpha_multiplier ~= nil and widget.alpha_multiplier <= 0.01 then
		return false
	end

	local style = widget.style

	if type(style) == "table" then
		for _, entry in pairs(style) do
			if type(entry) == "table" and entry.color and entry.color[1] ~= nil and entry.color[1] > 0 then
				return true
			end
		end
	end

	return true
end

mod._subtitles_element_has_active_lines = function(element)
	if not element then
		return false
	end

	local widget_sets = {
		rawget(element, "_widgets"),
		rawget(element, "_subtitle_widgets"),
		rawget(element, "_active_subtitle_widgets"),
	}

	for set_index = 1, #widget_sets do
		local widgets = widget_sets[set_index]

		if type(widgets) == "table" then
			for _, widget in pairs(widgets) do
				if mod._widget_has_visible_text(widget) then
					return true
				end
			end
		end
	end

	return false
end

mod._expedition_minimap_callout_suppressed = function()
	return (_gameplay_time() or 0) < (mod._expedition_minimap_callout_suppressed_until or 0)
end

mod._expedition_overlay_callout_freeze_active = function()
	return mod._expedition_minimap_callout_suppressed and mod._expedition_minimap_callout_suppressed() or false
end

local function _scanner_is_active()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or "unknown"

	if game_mode_name == "expedition" and not practice_session then
		return false
	end

	return scanner_equipped_active or scanner_searching_active or scanner_overlay_active
end

local function _refresh_scanner_overlay_state()
	local active = _overlay_scanner_view_active()

	if scanner_overlay_active == active then
		return
	end

	scanner_overlay_active = active
	mod._debug_event("scanner_overlay", string.format(
		"active=%s preview=%s overlay=%s world=%s world_icons=%s",
		tostring(scanner_overlay_active),
		tostring(Managers.ui and Managers.ui:view_active(PREVIEW_VIEW_NAME) or false),
		tostring(Managers.ui and Managers.ui:view_active(OVERLAY_VIEW_NAME) or false),
		tostring(Managers.ui and Managers.ui:view_active(WORLD_SCAN_VIEW_NAME) or false),
		tostring(Managers.ui and Managers.ui:view_active(WORLD_SCAN_ICONS_VIEW_NAME) or false)
	))
	_sync_scanner_hud_visibility()
end

_suppress_world_scan_views = function(duration)
	local suppress_until = _gameplay_time() + math.max(duration or 0, 0)

	if suppress_until > (mod._world_scan_views_suppressed_until or 0) then
		mod._world_scan_views_suppressed_until = suppress_until
	end
end

_world_scan_views_suppressed = function()
	return _gameplay_time() < (mod._world_scan_views_suppressed_until or 0)
end

local function _apply_scanner_alpha_to_widget(widget, alpha)
	if not widget then
		return
	end

	local fully_hidden = alpha <= 0.001

	if widget.content then
		widget.content.visible = not fully_hidden
	end

	widget.alpha_multiplier = alpha

	if widget.style then
		for _, style in pairs(widget.style) do
			if type(style) == "table" and style.color then
				if not style.__auspex_helper_original_alpha then
					style.__auspex_helper_original_alpha = style.color[1]
				end

				style.color[1] = fully_hidden and 0 or math.floor(style.__auspex_helper_original_alpha * alpha)
			end
		end
	end

	widget.dirty = true
end

local function _apply_scanner_alpha_to_element(element, alpha)
	if not element or SCANNER_EXCLUDED_ELEMENTS[element.__class_name] then
		return
	end

	if element._widgets then
		for _, widget in pairs(element._widgets) do
			_apply_scanner_alpha_to_widget(widget, alpha)
		end

		if element.set_dirty then
			element:set_dirty()
		end
	end

	if element._widgets_by_name then
		for _, widget in pairs(element._widgets_by_name) do
			_apply_scanner_alpha_to_widget(widget, alpha)
		end
	end

	if element._stamina_nodge_widget then
		_apply_scanner_alpha_to_widget(element._stamina_nodge_widget, alpha)
	end

	if element.__class_name == "HudElementStamina" and element._widgets_by_name then
		for widget_name, widget in pairs(element._widgets_by_name) do
			if widget_name == "gauge" or widget_name == "stamina_bar" or widget_name == "stamina_depleted_bar" then
				_apply_scanner_alpha_to_widget(widget, alpha)
			end
		end
	end

	if element._instance_data_tables then
		for _, data in pairs(element._instance_data_tables) do
			if data.instance then
				_apply_scanner_alpha_to_element(data.instance, alpha)
			end
		end
	end

	if element._player_weapons then
		for _, weapon_data in pairs(element._player_weapons) do
			if weapon_data.hud_element_player_weapon then
				_apply_scanner_alpha_to_element(weapon_data.hud_element_player_weapon, alpha)
			end
		end
	end

	if element._player_weapons_array then
		for _, weapon_data in ipairs(element._player_weapons_array) do
			if weapon_data.hud_element_player_weapon then
				_apply_scanner_alpha_to_element(weapon_data.hud_element_player_weapon, alpha)
			end
		end
	end

	if element._player_panel_by_unique_id then
		for _, panel_data in pairs(element._player_panel_by_unique_id) do
			if panel_data.panel then
				_apply_scanner_alpha_to_element(panel_data.panel, alpha)
			end
		end
	end

	if element._player_panels_array then
		for _, panel_data in ipairs(element._player_panels_array) do
			if panel_data.panel then
				_apply_scanner_alpha_to_element(panel_data.panel, alpha)
			end
		end
	end
end

local function _apply_scanner_current_alpha()
	local ui_manager = Managers.ui
	local hud = ui_manager and ui_manager:get_hud()

	if not hud then
		return
	end

	local function _set_element_alpha(element, class_name)
		if not element then
			return
		end

		if _should_hide_scanner_element(class_name) then
			_apply_scanner_alpha_to_element(element, scanner_current_alpha)
		else
			_apply_scanner_alpha_to_element(element, 1)
		end
	end

	for class_name, _ in pairs(SCANNER_HIDE_SETTING_IDS) do
		_set_element_alpha(hud:element(class_name), class_name)
	end

end

local function _set_scanner_hud_visibility(show)
	if not _is_scanner_visibility_enabled() then
		show = true
	end

	local target_alpha = show and 1 or _scanner_hidden_alpha()
	scanner_current_alpha = target_alpha

	_apply_scanner_current_alpha()
end

_sync_scanner_hud_visibility = function()
	_set_scanner_hud_visibility(not (_is_scanner_visibility_enabled() and _scanner_is_active()))
end

local function _set_scanner_equipped_state(active)
	scanner_equipped_active = active == true
	mod._debug_event("scanner_equipped", string.format("active=%s mode=%s", tostring(scanner_equipped_active), tostring((Managers.state and Managers.state.game_mode and Managers.state.game_mode:game_mode_name()) or "unknown")))
	_sync_scanner_hud_visibility()
end

_refresh_world_scan_overlay_view = function()
	local ui_manager = Managers.ui

	if not ui_manager then
		return
	end

	local active = ui_manager:view_active(WORLD_SCAN_VIEW_NAME)
	local closing = ui_manager:is_view_closing(WORLD_SCAN_VIEW_NAME)
	local blocked_by_minigame = ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)
		or ui_manager:view_active(PREVIEW_VIEW_NAME)
		or ui_manager:is_view_closing(PREVIEW_VIEW_NAME)
		or ui_manager:view_active(OVERLAY_VIEW_NAME)
		or ui_manager:is_view_closing(OVERLAY_VIEW_NAME)
	local should_open = _is_mod_active()
		and _world_scan_uses_item_overlay()
		and scanner_searching_active
		and _world_scan_has_active_scannables()
		and not _world_scan_views_suppressed()
		and not blocked_by_minigame

	if should_open then
		if not active and not closing then
			ui_manager:open_view(WORLD_SCAN_VIEW_NAME, nil, false, false, nil, {
				auspex_helper_is_practice = false,
				auspex_helper_world_scan_overlay = true,
				minigame_type = MinigameSettings.types.none,
			}, {
				use_transition_ui = false,
			})
			mod._debug_event("world_scan_overlay", string.format("open requested searching=%s scannables=%s blocked=%s", tostring(scanner_searching_active), tostring(_world_scan_has_active_scannables()), tostring(blocked_by_minigame)))
		end
	elseif active or closing then
		mod._debug_event("world_scan_overlay", string.format("close requested active=%s closing=%s searching=%s scannables=%s blocked=%s", tostring(active), tostring(closing), tostring(scanner_searching_active), tostring(_world_scan_has_active_scannables()), tostring(blocked_by_minigame)))
		ui_manager:close_view(WORLD_SCAN_VIEW_NAME, true)
	end

	_refresh_scanner_overlay_state()
end

_refresh_world_scan_icons_view = function()
	local ui_manager = Managers.ui

	if not ui_manager then
		return
	end

	local active = ui_manager:view_active(WORLD_SCAN_ICONS_VIEW_NAME)
	local closing = ui_manager:is_view_closing(WORLD_SCAN_ICONS_VIEW_NAME)
	local blocked_by_overlay = ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)
		or ui_manager:view_active(PREVIEW_VIEW_NAME)
		or ui_manager:is_view_closing(PREVIEW_VIEW_NAME)
		or ui_manager:view_active(OVERLAY_VIEW_NAME)
		or ui_manager:is_view_closing(OVERLAY_VIEW_NAME)
	local icon_units = mod._world_scan_icon_units
	local should_open = _is_mod_active()
		and _world_scan_uses_icon()
		and _world_scan_effective_active()
		and icon_units ~= nil
		and next(icon_units) ~= nil
		and not _world_scan_views_suppressed()
		and not blocked_by_overlay

	if should_open then
		if not active and not closing then
			ui_manager:open_view(WORLD_SCAN_ICONS_VIEW_NAME, nil, false, false, nil, {
				auspex_helper_is_practice = false,
				auspex_helper_world_scan_icons = true,
				minigame_type = MinigameSettings.types.none,
			}, {
				use_transition_ui = false,
			})
			mod._debug_event("world_scan_icons", string.format("open requested active_units=%s blocked=%s", tostring(icon_units ~= nil and next(icon_units) ~= nil), tostring(blocked_by_overlay)))
		end
	elseif active or closing then
		mod._debug_event("world_scan_icons", string.format("close requested active=%s closing=%s active_units=%s blocked=%s", tostring(active), tostring(closing), tostring(icon_units ~= nil and next(icon_units) ~= nil), tostring(blocked_by_overlay)))
		ui_manager:close_view(WORLD_SCAN_ICONS_VIEW_NAME, true)
	end
end

local function _set_scanner_searching_state(active)
	scanner_searching_active = active == true

	if not scanner_searching_active then
		mod._expedition_map_focus_latched = false
	end

	mod._debug_event("scanner_search", string.format("active=%s latched=%s mode=%s", tostring(scanner_searching_active), tostring(mod._expedition_map_focus_latched == true), tostring((Managers.state and Managers.state.game_mode and Managers.state.game_mode:game_mode_name()) or "unknown")))

	_refresh_world_scan_overlay_view()
	_sync_scanner_hud_visibility()
end

_scanner_search_input_active = function()
	local input_manager = Managers.input
	local input_service = input_manager and input_manager:get_input_service("Ingame")

	if not input_service or input_service:is_null_service() then
		return false
	end

	local action_two_pressed = not not input_service:_get("action_two_pressed")
	local action_two_hold = not not input_service:_get("action_two_hold")
	local expedition_map_minigame = mod._resolve_expedition_map_minigame and mod._resolve_expedition_map_minigame(false) or nil
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode = game_mode_manager and game_mode_manager.game_mode and game_mode_manager:game_mode() or nil
	local expedition_map_supported = expedition_map_minigame ~= nil or (game_mode and game_mode.map_minigame ~= nil)

	if scanner_equipped_active and expedition_map_supported and _is_minigame_enabled(EXPEDITION_MAP_MINIGAME_TYPE) then
		local ui_manager = Managers.ui
		local stock_view_active = ui_manager and (ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME))
		local overlay_view_active = ui_manager and (ui_manager:view_active(OVERLAY_VIEW_NAME) or ui_manager:is_view_closing(OVERLAY_VIEW_NAME))
		local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()
		local cached_live_minigame = rawget(mod, "_cached_live_minigame")
		local function looks_like_decode_active(minigame)
			return type(minigame) == "table" and (
				(minigame.current_decode_target and minigame.sweep_duration and minigame.is_on_target)
				or (minigame.symbols and minigame.cursor_position and minigame.current_stage and minigame.on_axis_set)
			)
		end
		local cached_decode_active = rawget(mod, "_cached_live_minigame_type") == MinigameSettings.types.decode_symbols
			and looks_like_decode_active(cached_live_minigame)

		if looks_like_decode_active(state_field_minigame) or looks_like_decode_active(state_method_minigame) or cached_decode_active then
			mod._expedition_map_focus_latched = false
			return false
		end

		if action_two_pressed then
			mod._expedition_map_focus_latched = not mod._expedition_map_focus_latched
		elseif stock_view_active or (mod._forced_expedition_map_overlay_active and overlay_view_active) then
			mod._expedition_map_focus_latched = true
		end

		return mod._expedition_map_focus_latched == true
	end

	mod._expedition_map_focus_latched = false

	return action_two_hold or action_two_pressed
end

local function _reset_decode_autosolve()
	decode_same_targets_count = 0
	decode_autosolve_cooldown = 0
	decode_autosolve_press_deadline = 0
end

local function _reset_expedition_autosolve()
	expedition_same_targets_count = 0
	expedition_autosolve_cooldown = 0
	expedition_autosolve_press_deadline = 0
	expedition_autosolve_move_cooldown = 0
	expedition_autosolve_input_pulse_until = 0
	mod._expedition_autosolve_release_deadline = 0
	mod._expedition_autosolve_submit_retry_at = 0
	mod._expedition_target_cell_cache = nil
	mod._expedition_autosolve_debug = nil

	local input_manager = Managers.input
	local input_service = input_manager and input_manager:get_input_service("Ingame")

	if input_service then
		local submit_actions = {
			"action_one_pressed",
			"action_one_hold",
			"interact_pressed",
			"interact_hold",
			"interact_primary_pressed",
			"interact_primary_hold",
			"jump_pressed",
			"jump_held",
		}

		for index = 1, #submit_actions do
			local action_name = submit_actions[index]

			if input_service:has(action_name) then
				input_service:stop_simulate_action(action_name)
			end
		end
	end
end

local function _start_expedition_submit_input_pulse(t)
	local input_manager = Managers.input
	local input_service = input_manager and input_manager:get_input_service("Ingame")

	if not input_service then
		return false
	end

	local submit_action_groups = {
		{
			"action_one_pressed",
			"action_one_hold",
		},
		{
			"interact_primary_pressed",
			"interact_primary_hold",
		},
		{
			"interact_pressed",
			"interact_hold",
		},
	}
	local started = false

	for group_index = 1, #submit_action_groups do
		local group = submit_action_groups[group_index]
		local group_available = false

		for action_index = 1, #group do
			if input_service:has(group[action_index]) then
				group_available = true
				break
			end
		end

		if group_available then
			for action_index = 1, #group do
				local action_name = group[action_index]

				if input_service:has(action_name) then
					input_service:start_simulate_action(action_name, true)
					started = true
				end
			end

			break
		end
	end

	if not started then
		return false
	end

	expedition_autosolve_input_pulse_until = math.max(expedition_autosolve_input_pulse_until or 0, t + 0.08)

	return true
end

local function _update_expedition_submit_input_pulse(t)
	if (expedition_autosolve_input_pulse_until or 0) <= 0 or t < expedition_autosolve_input_pulse_until then
		return
	end

	expedition_autosolve_input_pulse_until = 0

	local input_manager = Managers.input
	local input_service = input_manager and input_manager:get_input_service("Ingame")

	if input_service then
		local submit_actions = {
			"action_one_pressed",
			"action_one_hold",
			"interact_pressed",
			"interact_hold",
			"interact_primary_pressed",
			"interact_primary_hold",
			"jump_pressed",
			"jump_held",
		}

		for index = 1, #submit_actions do
			local action_name = submit_actions[index]

			if input_service:has(action_name) then
				input_service:stop_simulate_action(action_name)
			end
		end
	end
end

local function _reset_frequency_autosolve()
	frequency_autosolve_submit_cooldown = 0
end

_reset_drill_autosolve = function()
	mod._drill_autosolve_move_cooldown = 0
	mod._drill_autosolve_submit_cooldown = 0
	mod._drill_autosolve_press_deadline = 0
	mod._drill_autosolve_release_deadline = 0
	mod._drill_autosolve_second_press_deadline = 0
	mod._drill_autosolve_force_release = false
	mod._drill_autosolve_stage = nil
	mod._drill_autosolve_minigame = nil
	mod._drill_autosolve_stage_ready_time = 0
	mod._drill_autosolve_selected_stage = nil
	mod._drill_autosolve_selected_index = nil
	mod._drill_autosolve_selected_at = 0
end

mod._sync_drill_autosolve_stage = function(minigame)
	if not _looks_like_drill_minigame(minigame) then
		mod._drill_autosolve_stage = nil

		return
	end

	local current_stage = minigame:current_stage()

	if mod._drill_autosolve_stage == current_stage then
		return
	end

	mod._drill_autosolve_stage = current_stage
	mod._drill_autosolve_submit_cooldown = 0
	mod._drill_autosolve_press_deadline = 0
	mod._drill_autosolve_release_deadline = 0
	mod._drill_autosolve_second_press_deadline = 0
	mod._drill_autosolve_force_release = false
	mod._drill_autosolve_stage_ready_time = _gameplay_time() + 0.05
	mod._drill_autosolve_selected_stage = current_stage
	mod._drill_autosolve_selected_index = nil
	mod._drill_autosolve_selected_at = 0
end

mod._sync_drill_autosolve_minigame = function(minigame)
	if mod._drill_autosolve_minigame == minigame then
		return
	end

	mod._drill_autosolve_minigame = minigame
	_reset_drill_autosolve()
	mod._drill_autosolve_minigame = minigame
end

local function _decode_autosolve_cooldown_seconds()
	return (mod:get("decode_interact_cooldown") or 150) * 0.001
end

local function _expedition_autosolve_cooldown_seconds()
	return (mod:get("expedition_interact_cooldown") or 150) * 0.001
end

mod._expedition_move_interaction_seconds = function()
	return (mod:get("expedition_move_interaction_ms") or 90) * 0.001
end

local function _decode_target_precision()
	return (mod:get("decode_target_precision") or 4) * 0.1
end

mod._expedition_board_width = function()
	return MinigameSettings.decode_search_board_width or 5
end

mod._expedition_board_height = function()
	return MinigameSettings.decode_search_board_height or 5
end

mod._expedition_cursor_width = function()
	return MinigameSettings.decode_search_cursor_width or 1
end

mod._expedition_cursor_height = function()
	return MinigameSettings.decode_search_cursor_height or 1
end

_is_networked_live_session = function()
	local connection_manager = Managers.connection
	local host_type = connection_manager and connection_manager.host_type and connection_manager:host_type() or nil

	return host_type ~= nil and host_type ~= "singleplay" and host_type ~= "singleplay_backend_session"
end

mod._current_local_state_minigame = function()
	local player_unit = mod._cached_local_player_unit or nil

	if player_unit == false or not (player_unit and Unit.alive(player_unit)) then
		local player_manager = Managers.player
		local connection_manager = Managers.connection
		local player = nil

		if player_manager
			and player_manager.local_player_safe
		then
			local ok = nil

			ok, player = pcall(player_manager.local_player_safe, player_manager, 1)
			player = ok and player or nil
		end

		if not player
			and player_manager
			and player_manager.local_player
			and (player_manager._num_players or 0) > 0
			and (player_manager._num_human_players or 0) > 0
			and connection_manager
			and connection_manager.is_initialized
			and connection_manager:is_initialized()
		then
			local ok = nil

			ok, player = pcall(player_manager.local_player, player_manager, 1)
			player = ok and player or nil
		end

		player_unit = player and player.player_unit or nil
	end

	local character_state_machine_extension = player_unit and ScriptUnit.has_extension(player_unit, "character_state_machine_system")

	if not character_state_machine_extension or character_state_machine_extension:current_state_name() ~= "minigame" then
		return nil, nil
	end

	local current_state = character_state_machine_extension:current_state()
	local field_minigame = mod._unwrap_nested_minigame(current_state and current_state._minigame or nil)
	local method_minigame = mod._unwrap_nested_minigame(current_state and current_state.minigame and current_state:minigame() or nil)

	return field_minigame, method_minigame
end

_is_networked_live_minigame = function(minigame)
	if minigame == nil or _practice_session_blocks_live_autosolve() or not _is_networked_live_session() then
		return false
	end

	local cached_expedition_live_minigame = rawget(mod, "_cached_expedition_live_minigame")
	local raw_cached_live_minigame = rawget(mod, "_cached_live_minigame")

	if minigame == cached_expedition_live_minigame or minigame == raw_cached_live_minigame then
		return true
	end

	local cached_live_minigame = _active_live_minigame and _active_live_minigame() or nil
	local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()

	return minigame == cached_live_minigame or minigame == state_field_minigame or minigame == state_method_minigame
end

_decode_autosolve_prediction_seconds = function(minigame)
	if _is_networked_live_minigame(minigame) then
		return 0
	end

	return 0
end

_decode_autosolve_press_window_seconds = function(minigame)
	if _is_networked_live_minigame(minigame) then
		return 0.09
	end

	return 0.035
end

local function _expedition_autosolve_prediction_seconds(minigame)
	return 0
end

local function _expedition_autosolve_press_window_seconds(minigame)
	if _is_networked_live_minigame(minigame) then
		return 0.09
	end

	return 0.035
end

function mod._hold_expedition_overlay_open(duration)
	local until_t = (_gameplay_time() or 0) + (duration or 0.6)

	if until_t > (mod._forced_expedition_map_overlay_hold_until or 0) then
		mod._forced_expedition_map_overlay_hold_until = until_t
	end
end


local function _frequency_autosolve_strength()
	return mod:get("frequency_autosolve_strength") or 1
end

local PRIMARY_HOLD_ACTIONS = {
	action_one_hold = true,
	interact_hold = true,
	interact_primary_hold = true,
	jump_held = true,
}

local function _is_primary_hold_action(action_name)
	return PRIMARY_HOLD_ACTIONS[action_name] == true
end

local function _is_decode_on_target(minigame, time, stage_offset)
	if not minigame or not time then
		return false
	end

	local current_stage = minigame._current_stage

	if not current_stage then
		return false
	end

	current_stage = current_stage + (stage_offset or 0)

	local sweep_duration = minigame._decode_symbols_sweep_duration
	local targets = minigame._decode_targets or {}
	local target = targets[current_stage]

	if not target then
		return false
	end

	local precision = _decode_target_precision()

	local target_margin = 1 / (minigame._decode_symbols_items_per_stage - 1) * sweep_duration
	local start_target = (target - (1.5 - precision)) * target_margin
	local end_target = (target - (0.5 + precision)) * target_margin
	local cursor_time = minigame:_calculate_cursor_time(time + _decode_autosolve_prediction_seconds(minigame))

	return cursor_time > start_target and cursor_time < end_target
end

mod._normalize_expedition_symbol_id = function(symbol, fallback)
	if type(symbol) == "number" then
		return math.floor(symbol + 0.5)
	end

	if type(symbol) == "string" then
		local numeric = tonumber(symbol)

		if numeric ~= nil then
			return math.floor(numeric + 0.5)
		end

		return fallback
	end

	if type(symbol) ~= "table" then
		return fallback
	end

	local direct = symbol.symbol or symbol.symbol_id or symbol.id or symbol.value

	if direct ~= nil and direct ~= symbol then
		local normalized = mod._normalize_expedition_symbol_id(direct, fallback)

		if normalized ~= nil then
			return normalized
		end
	end

	for index = 1, #symbol do
		local normalized = mod._normalize_expedition_symbol_id(symbol[index], fallback)

		if normalized ~= nil then
			return normalized
		end
	end

	for key, value in pairs(symbol) do
		if key ~= "symbol" and key ~= "symbol_id" and key ~= "id" and key ~= "value" then
			local normalized = mod._normalize_expedition_symbol_id(value, fallback)

			if normalized ~= nil then
				return normalized
			end
		end
	end
	return fallback
end

mod._normalize_expedition_target_position = function(target)
	if type(target) ~= "table" then
		return nil
	end

	local x = nil
	local y = nil

	if target.x ~= nil or target.y ~= nil or target.target_x ~= nil or target.target_y ~= nil then
		x = target.x or target.target_x
		y = target.y or target.target_y
	elseif #target == 2 and type(target[1]) == "number" and type(target[2]) == "number" then
		x = target[1]
		y = target[2]
	end

	if x == nil or y == nil then
		return nil
	end

	local max_x = math.max(mod._expedition_board_width() - mod._expedition_cursor_width(), 0)
	local max_y = math.max(mod._expedition_board_height() - mod._expedition_cursor_height(), 0)

	if x >= 0 and x <= max_x then
		x = x + 1
	end

	if y >= 0 and y <= max_y then
		y = y + 1
	end

	return {
		x = math.clamp(math.floor(x + 0.5), 1, max_x + 1),
		y = math.clamp(math.floor(y + 0.5), 1, max_y + 1),
	}
end

mod._reconstruct_expedition_seed_targets = function(minigame)
	if not minigame or type(math.next_random) ~= "function" then
		return nil
	end

	local start_seed = rawget(minigame, "_start_seed")

	if type(start_seed) ~= "number" then
		return nil
	end

	local board_width = mod._expedition_board_width()
	local board_height = mod._expedition_board_height()
	local cursor_width = mod._expedition_cursor_width()
	local cursor_height = mod._expedition_cursor_height()
	local stage_amount = MinigameSettings.decode_search_stage_amount or 4
	local cache_key = table.concat({
		tostring(start_seed),
		tostring(board_width),
		tostring(board_height),
		tostring(cursor_width),
		tostring(cursor_height),
		tostring(stage_amount),
	}, "|")
	local cache = mod._expedition_seed_target_cache or {}
	local cached = cache[cache_key]

	if cached then
		return cached
	end

	local decode_search_symbols = MinigameSettings.decode_search_symbols

	if type(decode_search_symbols) ~= "table" or #decode_search_symbols == 0 then
		return nil
	end

	local seed = start_seed
	local symbol_count = #decode_search_symbols
	local total_items = board_width * board_height
	local board_symbols = {}
	local generated_symbols = {}

	for index = 1, symbol_count do
		local symbol_options = decode_search_symbols[index]

		if type(symbol_options) ~= "table" or #symbol_options == 0 then
			return nil
		end

		local random_index = nil
		seed, random_index = math.next_random(seed, 1, #symbol_options)
		board_symbols[index] = symbol_options[random_index]
	end

	for index = 1, total_items do
		local random_index = nil
		seed, random_index = math.next_random(seed, 1, symbol_count)
		generated_symbols[index] = board_symbols[random_index]
	end

	local max_x = math.max(board_width - cursor_width + 1, 1)
	local max_y = math.max(board_height - cursor_height + 1, 1)
	local last_x = math.floor(board_width / 2)
	local last_y = math.floor(board_height / 2)
	local positions = {}

	for stage = 1, stage_amount do
		local target_x = last_x
		local target_y = last_y

		while target_x == last_x and target_y == last_y do
			seed, target_x = math.next_random(seed, 1, max_x)
			seed, target_y = math.next_random(seed, 1, max_y)
		end

		last_x = target_x
		last_y = target_y
		positions[stage] = {
			x = target_x,
			y = target_y,
		}
	end

	cached = {
		symbols = mod._sanitize_expedition_board_symbols(generated_symbols),
		positions = positions,
	}
	cache[cache_key] = cached
	mod._expedition_seed_target_cache = cache

	return cached
end

mod._expedition_reconstructed_target_position = function(minigame, stage_offset)
	local reconstruction = mod._reconstruct_expedition_seed_targets(minigame)

	if not reconstruction then
		return nil
	end

	local live_symbols = minigame.symbols and minigame:symbols() or nil
	local expected_symbols = reconstruction.symbols

	if type(live_symbols) ~= "table" or type(expected_symbols) ~= "table" or #live_symbols ~= #expected_symbols then
		return nil
	end

	for index = 1, #expected_symbols do
		if mod._normalize_expedition_symbol_id(live_symbols[index], mod._default_expedition_symbol_id()) ~= expected_symbols[index] then
			return nil
		end
	end

	local current_stage = minigame and (minigame.current_stage and minigame:current_stage() or minigame._current_stage) or nil
	local target_stage = current_stage and (current_stage + (stage_offset or 0)) or nil

	if not target_stage then
		return nil
	end

	local position = reconstruction.positions and reconstruction.positions[target_stage] or nil

	if not position then
		return nil
	end

	return {
		x = position.x,
		y = position.y,
	}
end

mod._expedition_board_grid_at = function(symbols, target_x, target_y)
	if type(symbols) ~= "table" then
		return nil
	end

	local board_width = mod._expedition_board_width()
	local board_height = mod._expedition_board_height()
	local cursor_width = mod._expedition_cursor_width()
	local cursor_height = mod._expedition_cursor_height()
	local max_x = math.max(board_width - cursor_width + 1, 1)
	local max_y = math.max(board_height - cursor_height + 1, 1)
	local x = math.clamp(math.floor((target_x or 1) + 0.5), 1, max_x)
	local y = math.clamp(math.floor((target_y or 1) + 0.5), 1, max_y)
	local grid = {}

	for grid_y = 0, cursor_height - 1 do
		grid[grid_y + 1] = {}

		for grid_x = 0, cursor_width - 1 do
			local index = (y + grid_y - 1) * board_width + (x + grid_x)
			grid[grid_y + 1][grid_x + 1] = mod._normalize_expedition_symbol_id(symbols[index], mod._default_expedition_symbol_id()) or mod._default_expedition_symbol_id()
		end
	end

	return grid
end

mod._expedition_grid_for_cell = function(minigame, target_x, target_y)
	if not minigame then
		return nil
	end

	local symbols = minigame.symbols and minigame:symbols() or nil
	local board_grid = mod._expedition_board_grid_at(symbols, target_x, target_y)

	if board_grid then
		return board_grid
	end

	local getter = minigame.get_symbols_for_target

	if getter then
		local coord_offset = rawget(minigame, "_auspex_helper_target_coord_offset")

		if coord_offset == nil then
			local cursor = mod._expedition_cursor_position(minigame)
			local current_grid = nil
			local symbols = minigame.symbols and minigame:symbols() or nil

			if cursor and symbols then
				current_grid = mod._expedition_board_grid_at(symbols, cursor.x, cursor.y)
			end

			coord_offset = {
				x = 0,
				y = 0,
			}

			if cursor and current_grid then
				local offset_candidates = {
					{ x = -1, y = -1 },
					{ x = 0, y = 0 },
					{ x = -1, y = 0 },
					{ x = 0, y = -1 },
				}

				for index = 1, #offset_candidates do
					local candidate = offset_candidates[index]
					local ok, grid = pcall(getter, minigame, cursor.x + candidate.x, cursor.y + candidate.y)

					grid = ok and mod._normalize_expedition_symbol_grid(grid) or nil

					if mod._expedition_grids_equal(grid, current_grid) then
						coord_offset = candidate
						break
					end
				end
			end

			minigame._auspex_helper_target_coord_offset = coord_offset
		end

		local offset_x = type(coord_offset) == "table" and (coord_offset.x or 0) or coord_offset or 0
		local offset_y = type(coord_offset) == "table" and (coord_offset.y or 0) or coord_offset or 0
		local ok, grid = pcall(getter, minigame, (target_x or 1) + offset_x, (target_y or 1) + offset_y)

		grid = ok and mod._normalize_expedition_symbol_grid(grid) or nil

		if grid then
			return grid
		end
	end

	return nil
end

mod._expedition_raw_target = function(minigame, stage_offset)
	local current_stage = minigame and (minigame.current_stage and minigame:current_stage() or minigame._current_stage) or nil
	local target_positions = minigame and rawget(minigame, "_decode_target_positions") or nil
	local targets = minigame and (minigame._decode_targets or rawget(minigame, "decode_targets")) or nil

	if type(targets) == "function" then
		local ok, resolved_targets = pcall(targets, minigame)
		targets = ok and resolved_targets or nil
	end

	if not current_stage then
		return nil
	end

	if type(target_positions) == "table" and target_positions[current_stage + (stage_offset or 0)] ~= nil then
		return target_positions[current_stage + (stage_offset or 0)]
	end

	if not targets then
		return nil
	end

	return targets[current_stage + (stage_offset or 0)]
end

mod._expedition_target_position = function(minigame, stage_offset)
	return mod._normalize_expedition_target_position(mod._expedition_raw_target(minigame, stage_offset))
		or mod._expedition_reconstructed_target_position(minigame, stage_offset)
end

mod._expedition_target_symbols = function(minigame, stage_offset)
	local target = mod._expedition_raw_target(minigame, stage_offset)

	if not target or not minigame or not minigame.get_symbols_for_target then
		return nil
	end

	local x = target.x or target.target_x or target[1]
	local y = target.y or target.target_y or target[2]

	if x == nil or y == nil then
		return nil
	end

	return mod._normalize_expedition_symbol_grid(minigame:get_symbols_for_target(x, y))
end

mod._normalize_expedition_symbol_grid = function(grid)
	if type(grid) ~= "table" then
		return nil
	end

	if type(grid[1]) ~= "table" then
		local width = mod._expedition_cursor_width()
		local normalized = {}

		for index = 1, #grid do
			local y = math.floor((index - 1) / width) + 1
			local x = ((index - 1) % width) + 1

			normalized[y] = normalized[y] or {}
			normalized[y][x] = mod._normalize_expedition_symbol_id(grid[index], mod._default_expedition_symbol_id()) or mod._default_expedition_symbol_id()
		end

		return normalized
	end

	local normalized = {}

	for y = 1, #grid do
		local row = grid[y]

		if type(row) ~= "table" then
			return nil
		end

		normalized[y] = {}

		for x = 1, #row do
			normalized[y][x] = mod._normalize_expedition_symbol_id(row[x], mod._default_expedition_symbol_id()) or mod._default_expedition_symbol_id()
		end
	end

	return normalized
end

mod._expedition_grids_equal = function(left, right)
	left = mod._normalize_expedition_symbol_grid(left)
	right = mod._normalize_expedition_symbol_grid(right)

	if not left or not right or #left ~= #right then
		return false
	end

	for y = 1, #left do
		local left_row = left[y]
		local right_row = right[y]

		if not right_row or #left_row ~= #right_row then
			return false
		end

		for x = 1, #left_row do
			if left_row[x] ~= right_row[x] then
				return false
			end
		end
	end

	return true
end

mod._expedition_grid_debug_string = function(grid)
	grid = mod._normalize_expedition_symbol_grid(grid)

	if not grid then
		return "nil"
	end

	local rows = {}

	for y = 1, #grid do
		local row = grid[y]
		local parts = {}

		for x = 1, #row do
			parts[#parts + 1] = tostring(row[x] or "?")
		end

		rows[#rows + 1] = table.concat(parts, ",")
	end

	return table.concat(rows, "/")
end

mod._expedition_position_debug_string = function(position)
	if not position then
		return "nil"
	end

	return string.format("%s,%s", tostring(position.x or position[1] or "?"), tostring(position.y or position[2] or "?"))
end

mod._expedition_position_list_debug_string = function(positions)
	if type(positions) ~= "table" or #positions == 0 then
		return "none"
	end

	local parts = {}

	for index = 1, #positions do
		parts[index] = mod._expedition_position_debug_string(positions[index])
	end

	return table.concat(parts, ";")
end

mod._debug_expedition_autosolve = function(minigame, reason, extra)
	if not (mod._debug_enabled("exp_autosolve") and minigame and minigame.current_stage and minigame.cursor_position) then
		return
	end

	local current_stage = minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"
	local raw_target = mod._expedition_raw_target(minigame)
	local direct_target = mod._expedition_target_position(minigame)
	local chosen_target = extra and extra.chosen or nil
	local cached_target = mod._expedition_target_cell_cache

	if not chosen_target
		and cached_target
		and cached_target.minigame == minigame
		and cached_target.stage == current_stage
	then
		chosen_target = cached_target.result
	end

	local cursor = mod._expedition_cursor_position(minigame)
	local target_grid = mod._expedition_target_grid(minigame)
	local cursor_grid = mod._expedition_cursor_grid(minigame)
	local exact_match = mod._expedition_exact_target_match(minigame)
	local settled = cursor and chosen_target and cursor.x == chosen_target.x and cursor.y == chosen_target.y or false
	local raw_target_string = type(raw_target) == "table"
		and string.format("%s,%s", tostring(raw_target.x or raw_target.target_x or raw_target[1] or "?"), tostring(raw_target.y or raw_target.target_y or raw_target[2] or "?"))
		or tostring(raw_target)
	local move = extra and extra.move or nil
	local move_string = move and string.format("%s,%s", tostring(move.x or 0), tostring(move.y or 0)) or "nil"
	local note = extra and extra.note and tostring(extra.note) or ""
	local candidates = extra and extra.candidates or nil
	local signature = table.concat({
		tostring(reason or "tick"),
		tostring(current_stage),
		raw_target_string,
		mod._expedition_position_debug_string(direct_target),
		mod._expedition_position_debug_string(chosen_target),
		mod._expedition_position_debug_string(cursor),
		mod._expedition_grid_debug_string(target_grid),
		mod._expedition_grid_debug_string(cursor_grid),
		tostring(settled),
		tostring(exact_match),
		move_string,
		note,
		mod._expedition_position_list_debug_string(candidates),
	}, "|")
	local debug_state = mod._expedition_autosolve_debug or {}
	local now = _gameplay_time()

	if debug_state.signature == signature and now < (debug_state.next_t or 0) then
		return
	end

	mod._expedition_autosolve_debug = {
		signature = signature,
		next_t = now + 0.35,
	}

	mod._debug_log_event("exp_autosolve", string.format(
		"reason=%s stage=%s raw=%s direct=%s chosen=%s cursor=%s settled=%s exact=%s move=%s target_grid=%s cursor_grid=%s%s%s",
		tostring(reason or "tick"),
		tostring(current_stage),
		tostring(raw_target_string),
		mod._expedition_position_debug_string(direct_target),
		mod._expedition_position_debug_string(chosen_target),
		mod._expedition_position_debug_string(cursor),
		tostring(settled),
		tostring(exact_match),
		tostring(move_string),
		mod._expedition_grid_debug_string(target_grid),
		mod._expedition_grid_debug_string(cursor_grid),
		note ~= "" and (" note=" .. note) or "",
		candidates and (" candidates=" .. mod._expedition_position_list_debug_string(candidates)) or ""
	))
end

mod._expedition_cursor_grid = function(minigame)
	if not minigame then
		return nil
	end

	local cursor = mod._expedition_cursor_position(minigame)

	if not cursor then
		return nil
	end

	local symbols = minigame.symbols and minigame:symbols() or nil

	if symbols then
		return mod._expedition_board_grid_at(symbols, cursor.x, cursor.y)
	end

	return mod._expedition_grid_for_cell(minigame, cursor.x, cursor.y)
end

mod._expedition_exact_target_match = function(minigame)
	local cursor_grid = mod._expedition_cursor_grid(minigame)
	local target_grid = mod._expedition_target_grid(minigame)

	return mod._expedition_grids_equal(cursor_grid, target_grid)
end

mod._expedition_target_grid = function(minigame, stage_offset)
	local current_stage = minigame and (minigame.current_stage and minigame:current_stage() or minigame._current_stage) or nil
	local targets = minigame and (minigame._decode_targets or rawget(minigame, "decode_targets")) or nil

	if type(targets) == "function" then
		local ok, resolved_targets = pcall(targets, minigame)
		targets = ok and resolved_targets or nil
	end

	if not current_stage or not targets then
		return nil
	end

	local reconstructed_position = mod._expedition_reconstructed_target_position(minigame, stage_offset)

	if reconstructed_position then
		return mod._expedition_grid_for_cell(minigame, reconstructed_position.x, reconstructed_position.y)
	end

	local target = targets[current_stage + (stage_offset or 0)]
	local target_position = mod._normalize_expedition_target_position(target)
	if target_position then
		return mod._expedition_grid_for_cell(minigame, target_position.x, target_position.y)
	end

	return mod._normalize_expedition_symbol_grid(target)
end

local function _is_expedition_on_target(minigame, time, stage_offset)
	local cursor = mod._expedition_cursor_position(minigame)
	local target_position = ((stage_offset == nil or stage_offset == 0)
		and mod._expedition_target_cell(minigame))
		or mod._normalize_expedition_target_position(mod._expedition_raw_target(minigame, stage_offset))

	if not cursor or not target_position then
		return false
	end

	return cursor.x == target_position.x and cursor.y == target_position.y
end

local function _count_decode_same_targets(minigame)
	if not minigame then
		return 0
	end

	local current_stage = minigame._current_stage
	local targets = minigame._decode_targets

	if not current_stage or not targets or next(targets) == nil then
		return 0
	end

	local current_target = mod._normalize_expedition_symbol_id(targets[current_stage])
	local count = 0

	for index = current_stage, #targets do
		if mod._normalize_expedition_symbol_id(targets[index]) == current_target then
			count = count + 1
		else
			break
		end
	end

	return count
end

local function _count_expedition_same_targets(minigame)
	if not minigame then
		return 0
	end

	local current_stage = minigame.current_stage and minigame:current_stage() or minigame._current_stage
	local targets = minigame._decode_targets or rawget(minigame, "decode_targets")

	if type(targets) == "function" then
		local ok, resolved_targets = pcall(targets, minigame)
		targets = ok and resolved_targets or nil
	end

	if not current_stage or not targets or next(targets) == nil then
		return 0
	end

	local current_target = mod._normalize_expedition_symbol_grid(targets[current_stage])
	local count = 0

	for index = current_stage, #targets do
		local target = mod._normalize_expedition_symbol_grid(targets[index])

		if current_target and mod._expedition_grids_equal(target, current_target) then
			count = count + 1
		else
			break
		end
	end

	return count
end

mod._expedition_cursor_position = function(minigame)
	if not minigame or not minigame.cursor_position then
		return nil
	end

	local width = math.max(mod._expedition_board_width() - mod._expedition_cursor_width() + 1, 1)
	local height = math.max(mod._expedition_board_height() - mod._expedition_cursor_height() + 1, 1)
	local raw_cursor = rawget(minigame, "_cursor_position")
	local cursor_base = rawget(minigame, "_auspex_helper_cursor_base")

	if type(raw_cursor) == "table" then
		local raw_x = raw_cursor.x or raw_cursor[1]
		local raw_y = raw_cursor.y or raw_cursor[2]

		if raw_x ~= nil and raw_y ~= nil then
			if cursor_base == 0 then
				return {
					x = math.clamp(math.floor(raw_x + 0.5) + 1, 1, width),
					y = math.clamp(math.floor(raw_y + 0.5) + 1, 1, height),
				}
			elseif cursor_base == 1 then
				return {
					x = math.clamp(math.floor(raw_x + 0.5), 1, width),
					y = math.clamp(math.floor(raw_y + 0.5), 1, height),
				}
			end

			if raw_x >= 1 and raw_x <= width and raw_y >= 1 and raw_y <= height then
				return {
					x = math.clamp(math.floor(raw_x + 0.5), 1, width),
					y = math.clamp(math.floor(raw_y + 0.5), 1, height),
				}
			end

			if raw_x >= 0 and raw_x <= width - 1 then
				raw_x = raw_x + 1
			end

			if raw_y >= 0 and raw_y <= height - 1 then
				raw_y = raw_y + 1
			end

			return {
				x = math.clamp(math.floor(raw_x + 0.5), 1, width),
				y = math.clamp(math.floor(raw_y + 0.5), 1, height),
			}
		end
	end

	local first, second = minigame:cursor_position()
	local cursor_x = nil
	local cursor_y = nil

	if second ~= nil then
		cursor_x = first
		cursor_y = second
	elseif type(first) == "table" then
		cursor_x = first.x or first[1]
		cursor_y = first.y or first[2]
	else
		local width = mod._expedition_board_width()
		local index = math.floor((first or 1) + 0.5)

		if index >= 0 and index < width * mod._expedition_board_height() then
			index = index + 1
		end

		cursor_x = ((index - 1) % width) + 1
		cursor_y = math.floor((index - 1) / width) + 1
	end

	if cursor_x == nil or cursor_y == nil then
		return nil
	end

	if cursor_x >= 1 and cursor_x <= width and cursor_y >= 1 and cursor_y <= height then
		return {
			x = math.clamp(math.floor(cursor_x + 0.5), 1, width),
			y = math.clamp(math.floor(cursor_y + 0.5), 1, height),
		}
	end

	if cursor_x >= 0 and cursor_x <= width - 1 then
		cursor_x = cursor_x + 1
	end

	if cursor_y >= 0 and cursor_y <= height - 1 then
		cursor_y = cursor_y + 1
	end

	return {
		x = math.clamp(math.floor(cursor_x + 0.5), 1, width),
		y = math.clamp(math.floor(cursor_y + 0.5), 1, height),
	}
end

mod._expedition_target_symbol = function(minigame, stage_offset)
	local grid = mod._expedition_target_grid(minigame, stage_offset)

	return grid and grid[1] and grid[1][1] or nil
end

mod._expedition_target_cell = function(minigame)
	local cursor = mod._expedition_cursor_position(minigame)
	local raw_target = mod._expedition_raw_target(minigame)
	local direct_target = mod._expedition_target_position(minigame)
	local target_grid = mod._expedition_target_grid(minigame)
	local symbols = minigame and minigame.symbols and minigame:symbols() or nil
	local current_stage = minigame and (minigame.current_stage and minigame:current_stage() or minigame._current_stage) or nil
	local cache = mod._expedition_target_cell_cache
	local now = _gameplay_time()

	if direct_target and target_grid then
		local direct_grid = mod._expedition_grid_for_cell(minigame, direct_target.x, direct_target.y)

		if mod._expedition_grids_equal(direct_grid, target_grid) then
			return direct_target
		end
	end

	local raw_target_is_position = type(raw_target) == "table"
		and (
			raw_target.x ~= nil
			or raw_target.y ~= nil
			or raw_target.target_x ~= nil
			or raw_target.target_y ~= nil
			or (#raw_target == 2 and type(raw_target[1]) == "number" and type(raw_target[2]) == "number")
		)

	if target_grid and raw_target_is_position then
		local raw_x = raw_target.x or raw_target.target_x or raw_target[1]
		local raw_y = raw_target.y or raw_target.target_y or raw_target[2]

		if type(raw_x) == "number" and type(raw_y) == "number" then
			local candidates = {
				{
					x = math.floor(raw_x + 0.5),
					y = math.floor(raw_y + 0.5),
				},
				{
					x = math.floor(raw_x + 0.5) + 1,
					y = math.floor(raw_y + 0.5),
				},
				{
					x = math.floor(raw_x + 0.5),
					y = math.floor(raw_y + 0.5) + 1,
				},
				{
					x = math.floor(raw_x + 0.5) + 1,
					y = math.floor(raw_y + 0.5) + 1,
				},
			}
			local board_width = mod._expedition_board_width()
			local board_height = mod._expedition_board_height()
			local max_x = math.max(board_width - mod._expedition_cursor_width() + 1, 1)
			local max_y = math.max(board_height - mod._expedition_cursor_height() + 1, 1)
			local best_direct_match = nil
			local best_direct_distance = math.huge

			for index = 1, #candidates do
				local candidate = candidates[index]

				if candidate
					and candidate.x >= 1 and candidate.x <= max_x
					and candidate.y >= 1 and candidate.y <= max_y
				then
					local candidate_grid = mod._expedition_grid_for_cell(minigame, candidate.x, candidate.y)

					if mod._expedition_grids_equal(candidate_grid, target_grid) then
						local distance = cursor and (math.abs(candidate.x - cursor.x) + math.abs(candidate.y - cursor.y)) or 0

						if distance < best_direct_distance then
							best_direct_match = candidate
							best_direct_distance = distance
						end
					end
				end
			end

			if best_direct_match then
				return best_direct_match
			end
		end
	end

	if not cursor or not target_grid or not symbols then
		return nil
	end

	if cache
		and cache.minigame == minigame
		and cache.stage == current_stage
		and cache.cursor_x == cursor.x
		and cache.cursor_y == cursor.y
		and cache.symbols == symbols
		and cache.target == raw_target
		and (cache.expires_at or 0) > now
	then
		return cache.result
	end

	local board_width = mod._expedition_board_width()
	local max_x = math.max(board_width - mod._expedition_cursor_width() + 1, 1)
	local max_y = math.max(mod._expedition_board_height() - mod._expedition_cursor_height() + 1, 1)
	local best = nil
	local best_distance = math.huge
	local matches = {}

	for y = 1, max_y do
		for x = 1, max_x do
			local candidate = mod._expedition_grid_for_cell(minigame, x, y)

			if mod._expedition_grids_equal(candidate, target_grid) then
				matches[#matches + 1] = {
					x = x,
					y = y,
				}

				local distance = math.abs(x - cursor.x) + math.abs(y - cursor.y)

				if distance < best_distance then
					best = { x = x, y = y }
					best_distance = distance
				end
			end
		end
	end

	mod._expedition_target_cell_cache = {
		minigame = minigame,
		stage = current_stage,
		cursor_x = cursor.x,
		cursor_y = cursor.y,
		symbols = symbols,
		target = raw_target,
		expires_at = now + 0.05,
		result = best,
	}

	mod._debug_expedition_autosolve(minigame, "target_scan", {
		chosen = best,
		candidates = matches,
		note = "board_search",
	})

	return best
end

mod._expedition_autosolve_move_vector = function(minigame)
	if not _is_expedition_autosolve_enabled() or not (minigame and minigame.symbols and minigame.cursor_position and minigame.current_stage and minigame.on_axis_set) then
		return nil
	end

	local cursor = mod._expedition_cursor_position(minigame)
	local target = mod._expedition_target_cell(minigame)

	if not cursor or not target then
		mod._debug_expedition_autosolve(minigame, "no_target", {
			chosen = target,
			note = string.format("cursor=%s target=%s", tostring(cursor ~= nil), tostring(target ~= nil)),
		})
		return nil
	end

	local delta_x = target.x - cursor.x
	local delta_y = target.y - cursor.y

	if delta_x == 0 and delta_y == 0 then
		mod._debug_expedition_autosolve(minigame, "settled", {
			chosen = target,
			move = Vector3.zero(),
		})
		return Vector3.zero()
	end

	if delta_x ~= 0 then
		local move = Vector3(delta_x > 0 and 1 or -1, 0, 0)
		mod._debug_expedition_autosolve(minigame, "move", {
			chosen = target,
			move = move,
		})
		return move
	end

	local move = Vector3(0, delta_y > 0 and -1 or 1, 0)
	mod._debug_expedition_autosolve(minigame, "move", {
		chosen = target,
		move = move,
	})
	return move
end

mod._expedition_autosolve_submit_pending = function(minigame, now)
	local pending = mod._expedition_autosolve_pending_submit

	if not pending or pending.minigame ~= minigame then
		return false
	end

	now = now or _gameplay_time()

	local current_stage = minigame and (minigame.current_stage and minigame:current_stage() or minigame._current_stage) or nil

	if current_stage ~= pending.stage or now >= (pending.until_t or 0) then
		mod._expedition_autosolve_pending_submit = nil
		return false
	end

	return true
end

mod._mark_expedition_autosolve_submit = function(minigame, now)
	if not minigame then
		return
	end

	now = now or _gameplay_time()

	mod._expedition_autosolve_pending_submit = {
		minigame = minigame,
		stage = minigame.current_stage and minigame:current_stage() or minigame._current_stage,
		until_t = now + 0.45,
	}
end

_looks_like_drill_minigame = function(minigame)
	return minigame and minigame.targets and minigame.correct_targets and minigame.cursor_position and minigame.current_stage and minigame.search_percentage and minigame.uses_joystick and minigame:uses_joystick()
end

_drill_autosolve_move_vector = function(minigame)
	if not _is_drill_autosolve_enabled() or not _looks_like_drill_minigame(minigame) then
		return nil
	end

	if minigame:state() ~= MinigameSettings.game_states.gameplay then
		return nil
	end

	local stage = minigame:current_stage()
	local targets = minigame:targets()
	local correct_targets = minigame:correct_targets()
	local correct_target = stage and correct_targets and correct_targets[stage]
	local target = stage and targets and targets[stage] and correct_target and targets[stage][correct_target]
	local cursor_position = minigame:cursor_position()

	if not target or not cursor_position then
		return nil
	end

	local delta_x = target.x - cursor_position.x
	local delta_y = -(target.y - cursor_position.y)
	local length = math.sqrt(delta_x * delta_x + delta_y * delta_y)

	if length <= 0.01 then
		return Vector3.zero()
	end

	return Vector3(delta_x / length, delta_y / length, 0)
end

_should_submit_drill_autosolve = function(minigame, t)
	if not _is_drill_autosolve_enabled() or not _looks_like_drill_minigame(minigame) then
		return false
	end

	if minigame:state() ~= MinigameSettings.game_states.gameplay then
		return false
	end

	local stage = minigame:current_stage()
	local correct_targets = minigame:correct_targets()
	local selected_index = minigame.selected_index and minigame:selected_index() or nil
	local correct_target = stage and correct_targets and correct_targets[stage]
	local search_time = rawget(minigame, "_search_time")
	local networked_live = _is_networked_live_minigame(minigame)
	local submit_time = (t or _gameplay_time()) + (networked_live and 0.12 or 0)
	local search_ready = search_time and submit_time >= search_time + (MinigameSettings.drill_search_time or 0)
	local tracked_stage = mod._drill_autosolve_selected_stage
	local tracked_index = mod._drill_autosolve_selected_index

	if tracked_stage ~= stage or tracked_index ~= selected_index then
		mod._drill_autosolve_selected_stage = stage
		mod._drill_autosolve_selected_index = selected_index
		mod._drill_autosolve_selected_at = submit_time
	end

	if submit_time < (mod._drill_autosolve_stage_ready_time or 0) then
		return false
	end

	if submit_time < (mod._drill_autosolve_selected_at or 0) + (networked_live and 0.05 or 0.03) then
		return false
	end

	return search_ready and selected_index ~= nil and selected_index == correct_target
end

local function _reset_balance_autosolve()
	balance_input_window = 0
end

local function _balance_autosolve_strength()
	return mod:get("balance_autosolve_strength") or 0.66
end

_balance_autosolve_axis_value = function(axis_value, axis_velocity, distance, strength)
	local magnitude = math.abs(axis_value)

	if magnitude <= 0.035 then
		return nil
	end

	local velocity = math.abs(axis_velocity or 0)
	local moving_outward = (axis_value > 0 and (axis_velocity or 0) > 0) or (axis_value < 0 and (axis_velocity or 0) < 0)
	local outward_velocity = moving_outward and velocity or 0
	local center_factor = math.clamp((distance - 0.08) / 0.55, 0, 1)
	center_factor = center_factor * center_factor

	if distance < 0.18 and outward_velocity < 0.7 then
		return nil
	end

	local override_value = magnitude * strength * (0.18 + center_factor * 0.92)

	if outward_velocity > 0.4 then
		override_value = override_value + math.min(outward_velocity * 0.04, 0.2)
	end

	if distance >= 0.92 or outward_velocity >= 3.5 then
		local axis_share = magnitude / math.max(distance, 0.001)
		local recovery_strength = distance >= 0.985 and 1.35 or outward_velocity >= 5 and 1.3 or 1.15

		override_value = math.max(override_value, math.min(axis_share * recovery_strength, 1))
	end

	return math.clamp(override_value, 0, 1)
end

_balance_autosolve_move_vector = function(minigame)
	if not _is_balance_autosolve_enabled() or not minigame or not minigame.position then
		return nil
	end

	local position = minigame:position()
	local distance = minigame.distance and minigame:distance() or math.sqrt(position.x * position.x + position.y * position.y)

	if distance <= 0.02 then
		return nil
	end

	local strength = _balance_autosolve_strength()
	local x = 0
	local y = 0
	local input_x = _balance_autosolve_axis_value(position.x, balance_velocity_x, distance, strength)
	local input_y = _balance_autosolve_axis_value(position.y, balance_velocity_y, distance, strength)

	if input_x then
		x = position.x > 0 and -input_x or input_x
	end

	if input_y then
		y = position.y > 0 and input_y or -input_y
	end

	if x == 0 and y == 0 then
		return nil
	end

	return Vector3(x, y, 0)
end

local function _handle_decode_autosolve_input(action_name, result)
	if not _is_decode_autosolve_enabled() or not _is_primary_hold_action(action_name) then
		return result
	end

	local gameplay_time = _gameplay_time()
	local minigame = _active_decode_autosolve_minigame and _active_decode_autosolve_minigame() or nil
	local practice_minigame = _active_practice_minigame and _active_practice_minigame() or nil
	local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()

	if not minigame then
		decode_autosolve_press_deadline = 0

		return result
	end

	if minigame == practice_minigame
		or minigame == state_field_minigame
		or minigame == state_method_minigame
	then
		return result
	end

	if decode_autosolve_press_deadline > gameplay_time then
		return true
	end

	if _is_networked_live_minigame(minigame) then
		return result
	end

	if result or decode_autosolve_cooldown > 0 then
		return result
	end

	if not _is_decode_on_target(minigame, gameplay_time) then
		return result
	end

	local current_stage = minigame._current_stage
	local targets = minigame._decode_targets or {}
	local same_next_target = current_stage and targets[current_stage] ~= nil and targets[current_stage] == targets[current_stage + 1]
	local press_window = _decode_autosolve_press_window_seconds(minigame)

	decode_autosolve_press_deadline = gameplay_time + press_window
	decode_autosolve_cooldown = press_window + (same_next_target and 0.05 or _decode_autosolve_cooldown_seconds())

	return true
end

local function _early_looks_like_expedition_minigame(minigame)
	local minigame_type = _minigame_type_hint(minigame)

	if mod._is_expedition_map_minigame_type(minigame_type)
		or (minigame and minigame.selected_level and minigame.world_pos_to_map_pos)
	then
		return false
	end

	return minigame
		and minigame.current_stage
		and minigame.cursor_position
		and minigame.on_axis_set
		and (
			minigame.symbols
			or (
				minigame.current_decode_target
				and (minigame.get_symbols_for_target or minigame.decode_targets or rawget(minigame, "_decode_targets"))
			)
		)
end

local function _handle_expedition_autosolve_input(action_name, result)
	if not _is_expedition_autosolve_enabled() then
		return result
	end

	local session = practice_session

	if session and session.item_mode then
		return result
	end

	local minigame = _active_expedition_autosolve_minigame and _active_expedition_autosolve_minigame() or nil
	local gameplay_time = _gameplay_time()
	local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()
	local cached_expedition_live_minigame = rawget(mod, "_cached_expedition_live_minigame")
	local networked_live = minigame ~= nil and _is_networked_live_minigame(minigame)

	if not networked_live and (
		_early_looks_like_expedition_minigame(state_field_minigame)
		or _early_looks_like_expedition_minigame(state_method_minigame)
		or _early_looks_like_expedition_minigame(cached_expedition_live_minigame)
	)
	then
		return result
	end

	if not minigame then
		expedition_autosolve_press_deadline = 0
		mod._expedition_autosolve_release_deadline = 0
		mod._expedition_autosolve_pending_submit = nil
		return result
	end

	local submit_pending = mod._expedition_autosolve_submit_pending(minigame, gameplay_time)

	if (mod._expedition_autosolve_release_deadline or 0) > gameplay_time and _is_primary_hold_action(action_name) then
		return false
	end

	if expedition_autosolve_press_deadline > gameplay_time and _is_primary_hold_action(action_name) then
		return true
	end

	if action_name == "move" then
		local result_x = 0
		local result_y = 0
		local result_z = 0
		local result_magnitude = 0
		local allow_live_player_input = false
		local auto_move = nil
		local same_as_auto_move = false

		if type(result) == "userdata" then
			result_x = result.x or 0
			result_y = result.y or 0
			result_z = result.z or 0
			result_magnitude = math.sqrt(result_x * result_x + result_y * result_y + result_z * result_z)
		end

		auto_move = mod._expedition_autosolve_move_vector(minigame)
		same_as_auto_move = auto_move ~= nil
			and math.abs(result_x - (auto_move.x or 0)) <= 0.01
			and math.abs(result_y - (auto_move.y or 0)) <= 0.01
			and math.abs(result_z - (auto_move.z or 0)) <= 0.01

		-- Live expeditions can feed our own previous autosolve vector back into the next
		-- move read. Only treat a strong move vector as real player input when it is not
		-- just echoing the autosolver's current desired move.
		if result_magnitude >= 0.6 and not same_as_auto_move then
			allow_live_player_input = true
		end

		if mod._debug_enabled("exp_autosolve_input") then
			mod._debug_event("exp_autosolve_input", string.format(
				"action=move stage=%s live=%s raw=(%.2f,%.2f,%.2f) mag=%.2f auto=(%.2f,%.2f,%.2f) same_auto=%s cooldown=%.3f allow_live=%s",
				tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
				tostring(networked_live),
				result_x,
				result_y,
				result_z,
				result_magnitude,
				auto_move and (auto_move.x or 0) or 0,
				auto_move and (auto_move.y or 0) or 0,
				auto_move and (auto_move.z or 0) or 0,
				tostring(same_as_auto_move),
				expedition_autosolve_move_cooldown or 0,
				tostring(allow_live_player_input)
			))
		end

		if allow_live_player_input then
			if mod._debug_enabled("exp_autosolve_input") then
				mod._debug_event("exp_autosolve_input", string.format(
					"action=move branch=pass_through stage=%s live=%s raw=(%.2f,%.2f,%.2f) mag=%.2f",
					tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
					tostring(networked_live),
					result_x,
					result_y,
					result_z,
					result_magnitude
				))
			end

			return result
		end

		if networked_live then
			if submit_pending then
				if mod._debug_enabled("exp_autosolve_input") then
					mod._debug_event("exp_autosolve_input", string.format(
						"action=move branch=submit_pending stage=%s live=%s raw=(%.2f,%.2f,%.2f) mag=%.2f",
						tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
						tostring(networked_live),
						result_x,
						result_y,
						result_z,
						result_magnitude
					))
				end

				return result
			end

			if mod._debug_enabled("exp_autosolve_input") then
				mod._debug_event("exp_autosolve_input", string.format(
					"action=move branch=override_hold stage=%s live=%s raw=(%.2f,%.2f,%.2f) mag=%.2f auto=(%.2f,%.2f,%.2f) same_auto=%s",
					tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
					tostring(networked_live),
					result_x,
					result_y,
					result_z,
					result_magnitude,
					auto_move and (auto_move.x or 0) or 0,
					auto_move and (auto_move.y or 0) or 0,
					auto_move and (auto_move.z or 0) or 0,
					tostring(same_as_auto_move)
				))
			end

			return auto_move or result
		end

		if expedition_autosolve_move_cooldown > 0 then
			if mod._debug_enabled("exp_autosolve_input") then
				mod._debug_event("exp_autosolve_input", string.format(
					"action=move branch=cooldown stage=%s live=%s raw=(%.2f,%.2f,%.2f) mag=%.2f auto=(%.2f,%.2f,%.2f) same_auto=%s cooldown=%.3f",
					tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
					tostring(networked_live),
					result_x,
					result_y,
					result_z,
					result_magnitude,
					auto_move and (auto_move.x or 0) or 0,
					auto_move and (auto_move.y or 0) or 0,
					auto_move and (auto_move.z or 0) or 0,
					tostring(same_as_auto_move),
					expedition_autosolve_move_cooldown or 0
				))
			end

			return Vector3.zero()
		end

		if auto_move and ((auto_move.x or 0) ~= 0 or (auto_move.y or 0) ~= 0) then
			expedition_autosolve_move_cooldown = mod._expedition_move_interaction_seconds()
		end

		if mod._debug_enabled("exp_autosolve_input") then
			mod._debug_event("exp_autosolve_input", string.format(
				"action=move branch=override stage=%s live=%s raw=(%.2f,%.2f,%.2f) mag=%.2f auto=(%.2f,%.2f,%.2f) cooldown=%.3f",
				tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
				tostring(networked_live),
				result_x,
				result_y,
				result_z,
				result_magnitude,
				auto_move and (auto_move.x or 0) or 0,
				auto_move and (auto_move.y or 0) or 0,
				auto_move and (auto_move.z or 0) or 0,
				expedition_autosolve_move_cooldown or 0
			))
		end

		return auto_move or result
	end

	local auto_move = mod._expedition_autosolve_move_vector(minigame)

	if auto_move and expedition_autosolve_move_cooldown <= 0 then
		local override_value = nil

		if action_name == "move_left" and (auto_move.x or 0) < -0.15 then
			override_value = math.abs(auto_move.x or 0)
		elseif action_name == "move_right" and (auto_move.x or 0) > 0.15 then
			override_value = math.abs(auto_move.x or 0)
		elseif action_name == "move_forward" and (auto_move.y or 0) > 0.15 then
			override_value = math.abs(auto_move.y or 0)
		elseif action_name == "move_backward" and (auto_move.y or 0) < -0.15 then
			override_value = math.abs(auto_move.y or 0)
		end

		if override_value then
			local current_value = type(result) == "number" and result or (result and 1 or 0)

			return math.max(current_value, override_value)
		end
	end

	if result or not _is_primary_hold_action(action_name) or expedition_autosolve_cooldown > 0 then
		return result
	end

	if submit_pending then
		return result
	end

	if _is_expedition_on_target(minigame, gameplay_time) then
		if not mod._expedition_exact_target_match(minigame) then
			mod._debug_expedition_autosolve(minigame, "mismatch", {
				note = "input_gate_grid_mismatch",
			})
			return result
		end

		mod._debug_expedition_autosolve(minigame, "submit", {
			note = "input_gate_submit",
		})
		local press_window = _expedition_autosolve_press_window_seconds(minigame)

		mod._mark_expedition_autosolve_submit(minigame, gameplay_time)
		expedition_autosolve_press_deadline = gameplay_time + press_window
		expedition_autosolve_cooldown = press_window + _expedition_autosolve_cooldown_seconds()

		return true
	end

	return result
end

local function _frequency_autosolve_move_vector(minigame)
	local current = minigame and minigame.frequency and minigame:frequency() or nil
	local target = minigame and minigame.target_frequency and minigame:target_frequency() or nil

	if not current or not target then
		return nil
	end

	local margin = MinigameSettings.frequency_success_margin or 0.1
	local strength = _frequency_autosolve_strength()
	local range_x = math.max(MinigameSettings.frequency_width_max_scale - MinigameSettings.frequency_width_min_scale, 0.001)
	local range_y = math.max(MinigameSettings.frequency_height_max_scale - MinigameSettings.frequency_height_min_scale, 0.001)
	local delta_x = target.x - current.x
	local delta_y = target.y - current.y
	local input_x = math.abs(delta_x) <= margin * 0.35 and 0 or math.clamp(delta_x / (range_x * 0.2) * strength, -1, 1)
	local input_y = math.abs(delta_y) <= margin * 0.35 and 0 or math.clamp(delta_y / (range_y * 0.2) * strength, -1, 1)

	return Vector3(input_x, input_y, 0)
end

local function _handle_frequency_autosolve_input(action_name, result)
	if not _is_frequency_autosolve_enabled() then
		return result
	end

	local minigame = _active_frequency_autosolve_minigame and _active_frequency_autosolve_minigame() or nil

	if not minigame then
		return result
	end

	if action_name == "move" then
		if type(result) == "userdata" and (result.x ~= 0 or result.y ~= 0 or result.z ~= 0) then
			return result
		end

		return _frequency_autosolve_move_vector(minigame) or result
	end

	if result or not _is_primary_hold_action(action_name) or frequency_autosolve_submit_cooldown > 0 then
		return result
	end

	if minigame.is_visually_on_target and minigame:is_visually_on_target() then
		frequency_autosolve_submit_cooldown = 0.12

		return true
	end

	return result
end

_handle_drill_autosolve_input = function(action_name, result)
	if not _is_drill_autosolve_enabled() then
		return result
	end

	local minigame = _active_drill_autosolve_minigame and _active_drill_autosolve_minigame() or nil

	if not minigame then
		mod._sync_drill_autosolve_minigame(nil)
		return result
	end

	mod._sync_drill_autosolve_minigame(minigame)
	mod._sync_drill_autosolve_stage(minigame)

	if _is_primary_hold_action(action_name) then
		local gameplay_time = _gameplay_time()

		if (mod._drill_autosolve_press_deadline or 0) > gameplay_time then
			return true
		end

		if (mod._drill_autosolve_release_deadline or 0) > gameplay_time then
			return false
		end

		if (mod._drill_autosolve_second_press_deadline or 0) > gameplay_time then
			return true
		end

		if mod._drill_autosolve_force_release then
			mod._drill_autosolve_force_release = false

			return false
		end

		if not result and (mod._drill_autosolve_submit_cooldown or 0) <= 0 and _should_submit_drill_autosolve(minigame, gameplay_time) then
			mod._drill_autosolve_submit_cooldown = _drill_autosolve_step_delay()
			mod._drill_autosolve_press_deadline = gameplay_time + 0.08
			mod._drill_autosolve_release_deadline = gameplay_time + 0.12
			mod._drill_autosolve_second_press_deadline = gameplay_time + 0.2
			mod._drill_autosolve_force_release = true

			return true
		end

		return result
	end

	if action_name == "move" then
		local auto_move = _drill_autosolve_move_vector(minigame)

		if not auto_move then
			return result
		end

		return auto_move
	end

	local auto_move = _drill_autosolve_move_vector(minigame)

	if not auto_move then
		return result
	end

	local override_value = nil

	if action_name == "move_left" and (auto_move.x or 0) < -0.15 then
		override_value = math.abs(auto_move.x or 0)
	elseif action_name == "move_right" and (auto_move.x or 0) > 0.15 then
		override_value = math.abs(auto_move.x or 0)
	elseif action_name == "move_forward" and (auto_move.y or 0) > 0.15 then
		override_value = math.abs(auto_move.y or 0)
	elseif action_name == "move_backward" and (auto_move.y or 0) < -0.15 then
		override_value = math.abs(auto_move.y or 0)
	end

	if override_value then
		local current_value = type(result) == "number" and result or (result and 1 or 0)

		return math.max(current_value, override_value)
	end

	return result
end

local function _handle_balance_autosolve_input(action_name, result)
	if not _is_balance_autosolve_enabled() or balance_input_window <= 0 or balance_distance <= 0.2 then
		return result
	end

	local strength = _balance_autosolve_strength()
	local override_value = nil
	local edge_recovery = balance_distance >= 0.92

	if balance_cursor_x > 0 and action_name == "move_left" and (edge_recovery or balance_velocity_x > -0.5) then
		override_value = _balance_autosolve_axis_value(balance_cursor_x, balance_velocity_x, balance_distance, strength)
	elseif balance_cursor_x < 0 and action_name == "move_right" and (edge_recovery or balance_velocity_x < 0.5) then
		override_value = _balance_autosolve_axis_value(balance_cursor_x, balance_velocity_x, balance_distance, strength)
	elseif balance_cursor_y > 0 and action_name == "move_forward" and (edge_recovery or balance_velocity_y > -0.5) then
		override_value = _balance_autosolve_axis_value(balance_cursor_y, balance_velocity_y, balance_distance, strength)
	elseif balance_cursor_y < 0 and action_name == "move_backward" and (edge_recovery or balance_velocity_y < 0.5) then
		override_value = _balance_autosolve_axis_value(balance_cursor_y, balance_velocity_y, balance_distance, strength)
	end

	if override_value then
		local current_value = type(result) == "number" and result or 0

		return math.max(current_value, override_value)
	end

	return result
end

_refresh_scannable_units = function()
	scannable_units = _world_scan_collect_scannable_units(_world_scan_always_show())
	mod._world_scan_scannable_units = scannable_units

	local count = 0

	for _, _ in pairs(scannable_units) do
		count = count + 1
	end

	mod._debug_event("world_scan_units", string.format("count=%d always_show=%s", count, tostring(_world_scan_always_show())))
end

local function _apply_world_scan_outline_settings()
	local prop_outline_settings = OutlineSettings and OutlineSettings.PropOutlineExtension
	local outline_color = _world_scan_outline_color()
	local signature = string.format("%d:%d:%d:%s", outline_color[1] or 0, outline_color[2] or 0, outline_color[3] or 0, _world_scan_show_through_walls() and "1" or "0")

	if not prop_outline_settings then
		return
	end

	if mod._world_scan_outline_settings_signature == signature then
		return
	end

	mod._world_scan_outline_settings_signature = signature

	if prop_outline_settings.scanning then
		prop_outline_settings.scanning.color = outline_color
		prop_outline_settings.scanning.material_layers = {
			"scanning",
		}
	end

	if prop_outline_settings.scanning_confirm then
		prop_outline_settings.scanning_confirm.color = outline_color
		prop_outline_settings.scanning_confirm.material_layers = _world_scan_show_through_walls() and {
			"scanning",
			"scanning_reversed_depth",
		} or {
			"scanning",
		}
	end
end

_apply_world_scan_outline_color_to_unit = function(scannable_unit)
	if not scannable_unit or not Unit.alive(scannable_unit) then
		return
	end

	local color = _world_scan_outline_color()
	local color_vector = Vector3(color[1], color[2], color[3])
	local signature = string.format("%d:%d:%d", color[1] or 0, color[2] or 0, color[3] or 0)
	local applied_signatures = mod._world_scan_unit_color_signatures or {}

	mod._world_scan_unit_color_signatures = applied_signatures

	if applied_signatures[scannable_unit] == signature then
		return
	end

	pcall(Unit.set_vector3_for_material, scannable_unit, "scanning", "outline_color", color_vector)
	pcall(Unit.set_vector3_for_material, scannable_unit, "scanning_reversed_depth", "outline_color", color_vector)
	applied_signatures[scannable_unit] = signature
end

_set_world_scan_markers = function(active)
	local icon_units = mod._world_scan_icon_units or {}
	local enabled = active and _should_highlight_world_scans() and _world_scan_uses_icon() or false

	table.clear(icon_units)
	mod._world_scan_icon_units = icon_units

	if not enabled then
		_refresh_world_scan_icons_view()

		return
	end

	for scannable_unit, _ in pairs(scannable_units) do
		if Unit.alive(scannable_unit) then
			local scannable_extension = ScriptUnit.has_extension(scannable_unit, "mission_objective_zone_scannable_system")

			if scannable_extension and (scannable_extension:is_active() or _world_scan_always_show()) then
				local visible = _world_scan_show_through_walls() or _world_scan_unit_is_visible(scannable_unit, scannable_extension)

				if visible then
					icon_units[scannable_unit] = true
				end
			end
		end
	end

	_refresh_world_scan_icons_view()
end

_set_world_scan_highlights = function(active, refresh_units)
	local enabled = active and _should_highlight_world_scans() and _world_scan_uses_highlight() or false
	local highlighted_units = mod._world_scan_highlighted_units or {}
	local next_highlighted_units = {}

	_apply_world_scan_outline_settings()

	if refresh_units ~= false then
		_refresh_scannable_units()
	end

	for scannable_unit, _ in pairs(scannable_units) do
		if Unit.alive(scannable_unit) then
			local scannable_extension = ScriptUnit.has_extension(scannable_unit, "mission_objective_zone_scannable_system")

			if scannable_extension and (scannable_extension:is_active() or _world_scan_always_show()) then
				local visible = false

				if enabled then
					visible = _world_scan_show_through_walls() or _world_scan_unit_is_visible(scannable_unit, scannable_extension)
				end

				scannable_extension:set_scanning_outline(visible)
				scannable_extension:set_scanning_highlight(visible)

				if visible then
					next_highlighted_units[scannable_unit] = true
					_apply_world_scan_outline_color_to_unit(scannable_unit)
				elseif mod._world_scan_unit_color_signatures then
					mod._world_scan_unit_color_signatures[scannable_unit] = nil
				end
			end
		end
	end

	for highlighted_unit, _ in pairs(highlighted_units) do
		if not next_highlighted_units[highlighted_unit] and Unit.alive(highlighted_unit) then
			local highlighted_extension = ScriptUnit.has_extension(highlighted_unit, "mission_objective_zone_scannable_system")

			if highlighted_extension then
				highlighted_extension:set_scanning_outline(false)
				highlighted_extension:set_scanning_highlight(false)
			end
		end
	end

	mod._world_scan_highlighted_units = next_highlighted_units

	_set_world_scan_markers(active)
end

local function _ensure_decode_overlay_widgets(view, widget_count, widget_size)
	if widget_count <= 0 then
		view._auspex_helper_decode_widgets = nil

		return nil
	end

	local widgets = view._auspex_helper_decode_widgets
	local active_widget_size = widget_size or ScannerDisplayViewDecodeSymbolsSettings.decode_symbol_widget_size
	local previous_widget_size = view._auspex_helper_decode_widget_size

	if widgets and #widgets == widget_count and previous_widget_size and previous_widget_size[1] == active_widget_size[1] and previous_widget_size[2] == active_widget_size[2] then
		return widgets
	end

	widgets = {}

	for index = 1, widget_count do
		local widget_definition = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "highlight",
				value = "content/ui/materials/backgrounds/scanner/scanner_decode_symbol_highlight",
				style = {
					hdr = true,
					color = _ui_highlight_color(),
				},
			},
		}, "center_pivot", nil, active_widget_size)

		widgets[index] = UIWidget.init("auspex_helper_decode_" .. tostring(index), widget_definition)
	end

	view._auspex_helper_decode_widgets = widgets
	view._auspex_helper_decode_widget_size = {
		active_widget_size[1],
		active_widget_size[2],
	}

	return widgets
end

local function _ensure_expedition_overlay_widgets(view, widget_count)
	if widget_count <= 0 then
		view._auspex_helper_expedition_widgets = nil
		return nil
	end

	local widgets = view._auspex_helper_expedition_widgets

	if widgets and #widgets == widget_count then
		return widgets
	end

	widgets = {}

	for index = 1, widget_count do
		local widget_definition = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "highlight",
				value = "content/ui/materials/backgrounds/scanner/scanner_decode_symbol_highlight",
				style = {
					hdr = true,
					color = _ui_highlight_color(),
				},
			},
		}, "center_pivot", nil, ScannerDisplayViewDecodeSearchSettings.symbol_widget_size)

		widgets[index] = UIWidget.init("auspex_helper_expedition_" .. tostring(index), widget_definition)
	end

	view._auspex_helper_expedition_widgets = widgets

	return widgets
end

local DRILL_DIRECTION_ARROW_MATERIAL = "content/ui/materials/buttons/arrow_01"
local DRILL_DIRECTION_ARROW_SIZE = {
	44,
	44,
}
local DRILL_DIRECTION_WIDGET_SPECS = {
	left = {
		angle = math.rad(180),
		input_x = -1,
		input_y = 0,
		offset_x = -1,
		offset_y = 0,
		offset = { 0, 0, 7 },
	},
	right = {
		angle = 0,
		input_x = 1,
		input_y = 0,
		offset_x = 1,
		offset_y = 0,
		offset = { 0, 0, 7 },
	},
	up = {
		angle = math.rad(90),
		input_x = 0,
		input_y = 1,
		offset_x = 0,
		offset_y = -1,
		offset = { 0, 0, 7 },
	},
	down = {
		angle = math.rad(-90),
		input_x = 0,
		input_y = -1,
		offset_x = 0,
		offset_y = 1,
		offset = { 0, 0, 7 },
	},
}
local DRILL_DIRECTION_WIDGET_ORDER = {
	"left",
	"right",
	"up",
	"down",
}

local function _ensure_drill_direction_widgets(view)
	local widgets = view._auspex_helper_drill_direction_widgets

	if widgets then
		return widgets
	end

	widgets = {}

	for index = 1, #DRILL_DIRECTION_WIDGET_ORDER do
		local direction = DRILL_DIRECTION_WIDGET_ORDER[index]
		local spec = DRILL_DIRECTION_WIDGET_SPECS[direction]
		local widget_definition = UIWidget.create_definition({
			{
				pass_type = "rotated_texture",
				style_id = "arrow",
				value = DRILL_DIRECTION_ARROW_MATERIAL,
				style = {
					angle = spec.angle,
					color = {
						0,
						0,
						0,
						0,
					},
					offset = spec.offset,
					pivot = {},
				},
			},
		}, "center_pivot", nil, DRILL_DIRECTION_ARROW_SIZE)

		widgets[direction] = UIWidget.init("auspex_helper_drill_arrow_" .. direction, widget_definition)
	end

	view._auspex_helper_drill_direction_widgets = widgets

	return widgets
end

_drill_target_for_input = function(cursor_position, targets, selected_index, input_x, input_y)
	if not cursor_position or not targets or (input_x == 0 and input_y == 0) then
		return nil
	end

	local aim_radian = math.atan2(-input_y, input_x)
	local closest_index = nil
	local lowest_points = math.huge

	for index = 1, #targets do
		if index ~= selected_index then
			local target = targets[index]
			local radian = math.atan2(target.y - cursor_position.y, target.x - cursor_position.x)
			local angle = math.abs(radian - aim_radian)

			if angle > math.pi then
				angle = 2 * math.pi - angle
			end

			local distance = math.sqrt((cursor_position.x - target.x) * (cursor_position.x - target.x) + (cursor_position.y - target.y) * (cursor_position.y - target.y))
			local points = distance + angle * MinigameSettings.drill_move_distance_power

			if points < lowest_points and angle < math.pi / 3 then
				closest_index = index
				lowest_points = points
			end
		end
	end

	return closest_index
end

local function _set_drill_direction_widgets(view, minigame)
	local widgets = _ensure_drill_direction_widgets(view)
	local color = _ui_highlight_color()
	local hidden_color = {
		0,
		0,
		0,
		0,
	}
	local show_arrows = _should_show_drill_direction_arrows() and minigame and minigame.state and minigame:state() == MinigameSettings.game_states.gameplay
	local left_active = false
	local right_active = false
	local up_active = false
	local down_active = false
	local anchor_x = 0
	local anchor_y = 0
	local anchor_half_width = 48
	local anchor_half_height = 48

	if show_arrows then
		local stage = minigame:current_stage()
		local targets = minigame:targets()
		local stage_targets = stage and targets and targets[stage]
		local correct_targets = minigame:correct_targets()
		local cursor_position = minigame:cursor_position()
		local selected_index = minigame.selected_index and minigame:selected_index() or nil
		local correct_target = stage and correct_targets and correct_targets[stage]
		local target_widgets = stage and view._target_widgets and view._target_widgets[stage]
		local anchor_widget = target_widgets and target_widgets[selected_index]

		if anchor_widget then
			local anchor_size = anchor_widget.content and anchor_widget.content.size or DRILL_DIRECTION_ARROW_SIZE
			local anchor_offset = anchor_widget.offset or {
				0,
				0,
				0,
			}

			anchor_half_width = (anchor_size[1] or 96) * 0.5
			anchor_half_height = (anchor_size[2] or 96) * 0.5
			anchor_x = (anchor_offset[1] or 0) + anchor_half_width
			anchor_y = (anchor_offset[2] or 0) + anchor_half_height
		end

		if cursor_position and stage_targets and correct_target then
			left_active = _drill_target_for_input(cursor_position, stage_targets, selected_index, -1, 0) == correct_target
			right_active = _drill_target_for_input(cursor_position, stage_targets, selected_index, 1, 0) == correct_target
			up_active = _drill_target_for_input(cursor_position, stage_targets, selected_index, 0, 1) == correct_target
			down_active = _drill_target_for_input(cursor_position, stage_targets, selected_index, 0, -1) == correct_target
		else
			show_arrows = false
		end
	end

	local arrow_distance_x = anchor_half_width + DRILL_DIRECTION_ARROW_SIZE[1] * 0.5 + 12
	local arrow_distance_y = anchor_half_height + DRILL_DIRECTION_ARROW_SIZE[2] * 0.5 + 12

	for index = 1, #DRILL_DIRECTION_WIDGET_ORDER do
		local direction = DRILL_DIRECTION_WIDGET_ORDER[index]
		local widget = widgets[direction]
		local spec = DRILL_DIRECTION_WIDGET_SPECS[direction]
		local style = widget and widget.style and widget.style.arrow
		local offset = style and style.offset

		if offset then
			offset[1] = anchor_x + spec.offset_x * arrow_distance_x - DRILL_DIRECTION_ARROW_SIZE[1] * 0.5
			offset[2] = anchor_y + spec.offset_y * arrow_distance_y - DRILL_DIRECTION_ARROW_SIZE[2] * 0.5
		end
	end

	widgets.left.style.arrow.color = show_arrows and left_active and color or hidden_color
	widgets.right.style.arrow.color = show_arrows and right_active and color or hidden_color
	widgets.up.style.arrow.color = show_arrows and up_active and color or hidden_color
	widgets.down.style.arrow.color = show_arrows and down_active and color or hidden_color
end

mod._set_drill_direction_widgets = _set_drill_direction_widgets

mod:hook_require("scripts/ui/hud/elements/player_ability/hud_element_player_ability", function(HudElementPlayerAbility)
	mod:hook_safe(HudElementPlayerAbility, "init", function(self)
		_track_scanner_ability_icon(self)
	end)

	mod:hook_safe(HudElementPlayerAbility, "destroy", function(self)
		_untrack_scanner_ability_icon(self)
	end)
end)

mod:hook_require("scripts/ui/hud/elements/player_ability/hud_element_player_slot_item_ability", function(HudElementPlayerSlotItemAbility)
	mod:hook_safe(HudElementPlayerSlotItemAbility, "init", function(self)
		_track_scanner_ability_icon(self)
	end)

	mod:hook_safe(HudElementPlayerSlotItemAbility, "destroy", function(self)
		_untrack_scanner_ability_icon(self)
	end)
end)

local HudElementBase = rawget(_G, "HudElementBase")

if HudElementBase then
	mod:hook_safe(HudElementBase, "init", function(self)
		if not (_is_scanner_visibility_enabled() and _scanner_is_active()) then
			return
		end

		if not _should_hide_scanner_element(self.__class_name) then
			return
		end

		_apply_scanner_alpha_to_element(self, scanner_current_alpha)
	end)
end

mod:hook_require("scripts/ui/constant_elements/elements/subtitles/constant_element_subtitles", function(Subtitles)
	if scanner_subtitle_hook_applied then
		return
	end

	scanner_subtitle_hook_applied = true

	mod:hook(Subtitles, "_get_active_dialogue_system", function(func, self)
		local ui_manager = Managers.ui
		local active_views = ui_manager and ui_manager.active_views and ui_manager:active_views() or nil
		local view_handler = ui_manager and ui_manager._view_handler or nil
		local num_views = active_views and #active_views or 0

		if num_views > 0 then
			for index = 1, num_views do
				local view_name = active_views[index]

				if view_name
					and not _is_auspex_helper_pass_through_view(view_name)
					and not _is_auspex_helper_overlay_pass_through_view(view_handler, view_name)
				then
					local view = ui_manager:view_instance(view_name)
					local view_dialogue_system = view and view.dialogue_system and view:dialogue_system() or nil

					if self._stop_world_vo then
						self:_stop_world_vo(view_dialogue_system)
					end

					if view_dialogue_system then
						return view_dialogue_system
					end
				end
			end
		end

		local state_managers = Managers.state

		if state_managers then
			local extension_manager = state_managers.extension
			local system_name = "dialogue_system"

			return extension_manager and extension_manager:has_system(system_name) and extension_manager:system(system_name)
		end
	end)

	mod:hook_safe(Subtitles, "update", function(self)
		if mod._subtitles_element_has_active_lines and mod._subtitles_element_has_active_lines(self) then
			mod._expedition_minimap_callout_suppressed_until = math.max(mod._expedition_minimap_callout_suppressed_until or 0, (_gameplay_time() or 0) + 0.15)
		end
	end)
end)

local PreviewMinigameBase = {}

function PreviewMinigameBase:_init_base(stage_amount)
	self._action_held = nil
	self._completed = false
	self._current_stage = 1
	self._current_state = MinigameSettings.game_states.gameplay
	self._stage_amount = stage_amount or 1
	self._should_exit = false
end

function PreviewMinigameBase:is_completed()
	return self._completed or self._current_stage > self._stage_amount
end

function PreviewMinigameBase:complete()
	self._completed = true
	self._current_stage = self._stage_amount + 1
end

function PreviewMinigameBase:current_stage()
	return self._current_stage
end

function PreviewMinigameBase:state()
	return self._current_state
end

function PreviewMinigameBase:uses_action()
	return true
end

function PreviewMinigameBase:uses_joystick()
	return false
end

function PreviewMinigameBase:start(player)
	self._action_held = false
	self._player = player
	self._should_exit = false
end

function PreviewMinigameBase:stop()
	self._should_exit = true
end

function PreviewMinigameBase:setup_game()
	return
end

function PreviewMinigameBase:handle_state(state)
	if state == MinigameSettings.game_states.intro then
		return MinigameSettings.game_states.gameplay
	elseif state == MinigameSettings.game_states.transition and self:is_completed() then
		return MinigameSettings.game_states.outro
	end

	return state
end

function PreviewMinigameBase:set_state(state)
	self._current_state = self:handle_state(state)
end

function PreviewMinigameBase:action(held, t)
	if self._action_held == nil then
		if held then
			return false
		end

		self._action_held = false
	end

	if self._action_held ~= held then
		self._action_held = held

		if held then
			self:on_action_pressed(t or _gameplay_time())
		else
			self:on_action_released(t or _gameplay_time())
		end

		return true
	end

	return false
end

function PreviewMinigameBase:on_action_pressed(t)
	return
end

function PreviewMinigameBase:on_action_released(t)
	return
end

function PreviewMinigameBase:on_axis_set(t, x, y)
	return
end

function PreviewMinigameBase:update(dt, t)
	return
end

function PreviewMinigameBase:escape_action(action_two_pressed)
	if action_two_pressed then
		self._should_exit = true

		return true
	end

	return false
end

function PreviewMinigameBase:blocks_weapon_actions()
	return true
end

function PreviewMinigameBase:should_exit()
	return self._should_exit == true or self:is_completed()
end

function PreviewMinigameBase:angle_check()
	return false
end

function PreviewMinigameBase:unit()
	return nil
end

function PreviewMinigameBase:unequip_on_exit()
	return false
end

local function _practice_decode_speed_multiplier()
	return math.clamp(mod:get("practice_decode_speed_multiplier") or 1, 0.5, 3)
end

local function _practice_decode_sweep_duration()
	return math.max(MinigameSettings.decode_symbols_sweep_duration / _practice_decode_speed_multiplier(), 0.1)
end

_decode_layout = function(minigame)
	local base_widget_size = ScannerDisplayViewDecodeSymbolsSettings.decode_symbol_widget_size
	local base_spacing = ScannerDisplayViewDecodeSymbolsSettings.decode_symbol_spacing
	local stage_amount = minigame and minigame._stage_amount or MinigameSettings.decode_symbols_stage_amount
	local items_per_stage = MinigameSettings.decode_symbols_items_per_stage
	local total_height = base_widget_size[2] * stage_amount + base_spacing * (stage_amount - 1)
	local scale = total_height > PREVIEW_DECODE_MAX_GRID_HEIGHT and PREVIEW_DECODE_MAX_GRID_HEIGHT / total_height or 1
	local widget_size = {
		base_widget_size[1] * scale,
		base_widget_size[2] * scale,
	}
	local spacing = base_spacing * scale

	return {
		stage_amount = stage_amount,
		widget_size = widget_size,
		spacing = spacing,
		starting_offset_x = -(widget_size[1] * items_per_stage + spacing * (items_per_stage - 1)) * 0.5,
		starting_offset_y = -(widget_size[2] * stage_amount + spacing * (stage_amount - 1)) * 0.5,
	}
end

local function _practice_balance_time_multiplier()
	return math.clamp(mod:get("practice_balance_time_multiplier") or 3, 1, 10)
end

local function _practice_balance_difficulty()
	return math.clamp(mod:get("practice_balance_difficulty") or 1, 0.5, 3)
end

local function _configure_preview_balance_settings(minigame)
	local difficulty = _practice_balance_difficulty()
	local difficulty_root = math.sqrt(difficulty)
	local start_scale = 1 + (difficulty_root - 1) * 0.45

	minigame._balance_progress_rate = 0.28 / _practice_balance_time_multiplier()
	minigame._balance_push_ratio = MinigameSettings.balance_push_ratio * difficulty_root
	minigame._balance_disrupt_interval = MinigameSettings.balance_disrupt_interval / difficulty_root
	minigame._balance_disrupt_power = MinigameSettings.balance_disrupt_power * difficulty_root
	minigame._balance_move_ratio = MinigameSettings.balance_move_ratio / difficulty_root
	minigame._balance_max_speed = MinigameSettings.balance_max_speed * difficulty_root
	minigame._balance_start_distance_scale = start_scale
	minigame._balance_start_speed_scale = start_scale
end

local function _random_decode_targets(stage_amount)
	local targets = {}
	local previous_target = nil
	local target_stage_amount = stage_amount or MinigameSettings.decode_symbols_stage_amount
	local items_per_stage = MinigameSettings.decode_symbols_items_per_stage

	for stage = 1, target_stage_amount do
		local target = math.random(1, items_per_stage)

		if items_per_stage > 1 and previous_target and target == previous_target and math.random() < 0.65 then
			target = target % items_per_stage + 1
		end

		targets[stage] = target
		previous_target = target
	end

	return targets
end

local PreviewDecodeMinigame = setmetatable({}, { __index = PreviewMinigameBase })
PreviewDecodeMinigame.__index = PreviewDecodeMinigame

function PreviewDecodeMinigame:new()
	local stage_amount = MinigameSettings.decode_symbols_stage_amount
	local total_items = stage_amount * MinigameSettings.decode_symbols_items_per_stage
	local symbol_pool_size = MinigameSettings.decode_symbols_total_items
	local symbols = {}

	for index = 1, total_items do
		symbols[index] = (index - 1) % symbol_pool_size + 1
	end

	local minigame = setmetatable({
		_decode_targets = _random_decode_targets(stage_amount),
		_decode_symbols_sweep_duration = _practice_decode_sweep_duration(),
		_decode_symbols_items_per_stage = MinigameSettings.decode_symbols_items_per_stage,
		_start_time = _gameplay_time(),
		_symbols = symbols,
	}, PreviewDecodeMinigame)

	minigame:_init_base(stage_amount)

	return minigame
end

function PreviewDecodeMinigame:new_with_stage_amount(stage_amount)
	local total_items = stage_amount * MinigameSettings.decode_symbols_items_per_stage
	local symbol_pool_size = MinigameSettings.decode_symbols_total_items
	local symbols = {}

	for index = 1, total_items do
		symbols[index] = (index - 1) % symbol_pool_size + 1
	end

	local minigame = setmetatable({
		_decode_targets = _random_decode_targets(stage_amount),
		_decode_symbols_sweep_duration = _practice_decode_sweep_duration(),
		_decode_symbols_items_per_stage = MinigameSettings.decode_symbols_items_per_stage,
		_start_time = _gameplay_time(),
		_symbols = symbols,
	}, PreviewDecodeMinigame)

	minigame:_init_base(stage_amount)

	return minigame
end

function PreviewDecodeMinigame:start(player)
	PreviewMinigameBase.start(self, player)
	self._decode_symbols_sweep_duration = _practice_decode_sweep_duration()
	self._start_time = _gameplay_time()
end

function PreviewDecodeMinigame:start_time()
	return self._start_time
end

function PreviewDecodeMinigame:current_decode_target()
	return self._decode_targets[self._current_stage]
end

function PreviewDecodeMinigame:sweep_duration()
	return self._decode_symbols_sweep_duration
end

function PreviewDecodeMinigame:symbols()
	return self._symbols
end

function PreviewDecodeMinigame:_calculate_cursor_time(time)
	local delta_time = (time or _gameplay_time()) - self._start_time
	local sweep_duration = self:sweep_duration()
	local cursor_time = delta_time % (sweep_duration * 2)

	if sweep_duration < cursor_time then
		cursor_time = 2 * sweep_duration - cursor_time
	end

	return cursor_time
end

function PreviewDecodeMinigame:is_on_target(time)
	local target = self:current_decode_target()

	if not target then
		return false
	end

	local sweep_duration = self:sweep_duration()
	local target_margin = 1 / (self._decode_symbols_items_per_stage - 1) * sweep_duration
	local start_target = (target - 1.5) * target_margin
	local end_target = (target - 0.5) * target_margin
	local cursor_time = self:_calculate_cursor_time(time)

	return start_target < cursor_time and cursor_time < end_target
end

function PreviewDecodeMinigame:on_action_pressed(t)
	if self:is_on_target(t) then
		local is_last_stage = self._current_stage >= self._stage_amount

		self._current_stage = self._current_stage + 1

		if self._current_stage > self._stage_amount then
			self:play_sound("sfx_minigame_success_last")
			self:complete()
		elseif is_last_stage then
			self:play_sound("sfx_minigame_success_last")
		else
			self:play_sound("sfx_minigame_success")
		end
	else
		self._current_stage = math.max(self._current_stage - 1, 1)
		self:play_sound("sfx_minigame_fail")
	end
end

local PreviewDrillMinigame = setmetatable({}, { __index = PreviewMinigameBase })
PreviewDrillMinigame.__index = PreviewDrillMinigame
local DRILL_TARGET_TEMPLATES = {
	{
		{ x = -0.72, y = 0.23 },
		{ x = -0.21, y = -0.24 },
		{ x = 0.11, y = 0.34 },
		{ x = 0.64, y = -0.09 },
		{ x = 0.27, y = -0.39 },
	},
	{
		{ x = -0.61, y = -0.04 },
		{ x = -0.07, y = 0.29 },
		{ x = 0.46, y = -0.22 },
		{ x = 0.75, y = 0.21 },
		{ x = 0.05, y = -0.43 },
	},
	{
		{ x = -0.77, y = -0.17 },
		{ x = -0.29, y = 0.35 },
		{ x = 0.24, y = -0.32 },
		{ x = 0.68, y = 0.09 },
		{ x = 0.02, y = 0.03 },
	},
}

local function _randomized_drill_targets()
	local randomized_targets = {}

	for stage = 1, #DRILL_TARGET_TEMPLATES do
		local base_targets = DRILL_TARGET_TEMPLATES[stage]
		local mirror_x = math.random(0, 1) == 1 and -1 or 1
		local mirror_y = math.random(0, 1) == 1 and -1 or 1
		local rotation = (math.random() * 2 - 1) * 0.45
		local sin_rotation = math.sin(rotation)
		local cos_rotation = math.cos(rotation)
		local stage_targets = {}

		for index = 1, #base_targets do
			local base_target = base_targets[index]
			local x = base_target.x * mirror_x
			local y = base_target.y * mirror_y
			local rotated_x = x * cos_rotation - y * sin_rotation
			local rotated_y = x * sin_rotation + y * cos_rotation

			stage_targets[index] = {
				x = math.clamp(rotated_x + (math.random() * 2 - 1) * 0.05, -0.82, 0.82),
				y = math.clamp(rotated_y + (math.random() * 2 - 1) * 0.05, -0.48, 0.48),
			}
		end

		randomized_targets[stage] = stage_targets
	end

	return randomized_targets
end

local function _random_drill_correct_targets(targets)
	local correct_targets = {}

	for stage = 1, #targets do
		correct_targets[stage] = math.random(1, #targets[stage])
	end

	return correct_targets
end

function PreviewDrillMinigame:new()
	local targets = _randomized_drill_targets()
	local minigame = setmetatable({
		_correct_targets = _random_drill_correct_targets(targets),
		_cursor_position = {
			x = 0,
			y = 0,
		},
		_last_move = 0,
		_search_time = false,
		_selected_index = nil,
		_targets = targets,
		_transition_start_time = nil,
		_search_feedback_played = false,
	}, PreviewDrillMinigame)

	minigame:_init_base(MinigameSettings.drill_stage_amount)

	return minigame
end

function PreviewDrillMinigame:targets()
	return self._targets
end

function PreviewDrillMinigame:correct_targets()
	return self._correct_targets
end

function PreviewDrillMinigame:selected_index()
	return self._selected_index
end

function PreviewDrillMinigame:cursor_position()
	return self._cursor_position
end

function PreviewDrillMinigame:is_searching()
	return not not self._search_time
end

function PreviewDrillMinigame:search_percentage(time)
	if not self._search_time then
		return 0
	end

	return math.clamp(((time or _gameplay_time()) - self._search_time) / MinigameSettings.drill_search_time, 0, 1)
end

function PreviewDrillMinigame:is_on_target()
	return self._selected_index ~= nil and self._selected_index == self._correct_targets[self._current_stage]
end

function PreviewDrillMinigame:transition_percentage(time)
	if self._current_state ~= MinigameSettings.game_states.transition and self._current_state ~= MinigameSettings.game_states.outro then
		return 0
	end

	if not self._transition_start_time then
		return 0
	end

	return math.clamp(((time or _gameplay_time()) - self._transition_start_time) / MinigameSettings.drill_transition_time, 0, 1)
end

function PreviewDrillMinigame:handle_state(state)
	state = PreviewMinigameBase.handle_state(self, state)

	if state == MinigameSettings.game_states.transition or state == MinigameSettings.game_states.outro then
		self._transition_start_time = _gameplay_time()
	end

	return state
end

function PreviewDrillMinigame:uses_joystick()
	return true
end

function PreviewDrillMinigame:update(dt, t)
	if self._current_state == MinigameSettings.game_states.transition and t - self._transition_start_time >= MinigameSettings.drill_transition_time then
		self:set_state(MinigameSettings.game_states.gameplay)
		self._transition_start_time = nil
		self._search_feedback_played = false
		return
	elseif self._current_state == MinigameSettings.game_states.outro then
		if t - self._transition_start_time >= MinigameSettings.drill_transition_time then
			self._should_exit = true
			self._completed = true
			self._current_state = MinigameSettings.game_states.complete
		end

		return
	end

	if self._current_state ~= MinigameSettings.game_states.gameplay then
		return
	end

	if self._search_time and not self._search_feedback_played and self:search_percentage(t) >= 1 then
		self._search_feedback_played = true

		if self:is_on_target() then
			self:play_sound("sfx_minigame_bio_selection_right")
		else
			self:play_sound("sfx_minigame_bio_selection_wrong")
		end
	end
end

function PreviewDrillMinigame:on_action_pressed(t)
	if self._current_state ~= MinigameSettings.game_states.gameplay or not self._selected_index or not self._search_time then
		return
	end

	if self:search_percentage(t) < 1 then
		return
	end

	if self:is_on_target() then
		self._search_time = false
		self._search_feedback_played = false
		self._selected_index = nil
		self._cursor_position.x = 0
		self._cursor_position.y = 0
		local is_last_stage = self._current_stage >= self._stage_amount

		self._current_stage = math.min(self._current_stage + 1, self._stage_amount + 1)

		if self._current_stage > self._stage_amount then
			self:play_sound("sfx_minigame_bio_progress_last")
		else
			if is_last_stage then
				self:play_sound("sfx_minigame_bio_progress_last")
			else
				self:play_sound("sfx_minigame_bio_progress")
			end
		end

		self:set_state(MinigameSettings.game_states.transition)
	else
		self._search_time = false
		self._search_feedback_played = false
		self:play_sound("sfx_minigame_bio_fail")
	end
end

function PreviewDrillMinigame:should_exit()
	return self._current_state == MinigameSettings.game_states.complete
end

function PreviewDrillMinigame:on_axis_set(t, x, y)
	if self._current_state ~= MinigameSettings.game_states.gameplay or self:is_completed() or (x == 0 and y == 0) then
		return
	end

	if t <= self._last_move + MinigameSettings.drill_move_delay then
		return
	end

	self._last_move = t

	local aim_radian = math.atan2(-y, x)
	local targets = self._targets[self._current_stage]
	local cursor_position = self._cursor_position
	local closest_index = nil
	local lowest_points = math.huge

	for index = 1, #targets do
		if index ~= self._selected_index then
			local target = targets[index]
			local radian = math.atan2(target.y - cursor_position.y, target.x - cursor_position.x)
			local angle = math.abs(radian - aim_radian)

			if angle > math.pi then
				angle = 2 * math.pi - angle
			end

			local distance = math.sqrt((cursor_position.x - target.x) * (cursor_position.x - target.x) + (cursor_position.y - target.y) * (cursor_position.y - target.y))
			local points = distance + angle * MinigameSettings.drill_move_distance_power

			if points < lowest_points and angle < math.pi / 3 then
				closest_index = index
				lowest_points = points
			end
		end
	end

	if closest_index then
		local target = targets[closest_index]

		self._selected_index = closest_index
		self._cursor_position.x = target.x
		self._cursor_position.y = target.y
		self._search_time = t
		self._search_feedback_played = false
		self:play_sound("sfx_minigame_bio_selection")
	end
end

local PreviewBalanceMinigame = setmetatable({}, { __index = PreviewMinigameBase })
PreviewBalanceMinigame.__index = PreviewBalanceMinigame

local function _reset_preview_balance_state(minigame)
	local angle = math.random() * math.pi * 2
	local distance_scale = minigame._balance_start_distance_scale or 1
	local speed_scale = minigame._balance_start_speed_scale or 1
	local distance = math.min((0.28 + math.random() * 0.22) * distance_scale, 0.82)
	local drift_angle = angle + math.pi * 0.35

	minigame._last_axis_set = _gameplay_time()
	minigame._position.x = math.cos(angle) * distance
	minigame._position.y = -math.sin(angle) * distance
	minigame._speed.x = math.cos(drift_angle) * 0.85 * speed_scale
	minigame._speed.y = -math.sin(drift_angle) * 0.85 * speed_scale
	minigame._progression = 0
	minigame._disrupt_timer = math.min(minigame._balance_disrupt_interval or MinigameSettings.balance_disrupt_interval, 0.45)
	minigame._is_stuck_indication = false
	minigame._sound_alert_time = 0
end

function PreviewBalanceMinigame:new()
	local minigame = setmetatable({
		_disrupt_timer = MinigameSettings.balance_disrupt_interval,
		_last_axis_set = _gameplay_time(),
		_position = {
			x = 0,
			y = 0,
		},
		_progression = 0,
		_speed = {
			x = 0,
			y = 0,
		},
		_is_stuck_indication = false,
		_sound_alert_time = 0,
	}, PreviewBalanceMinigame)

	minigame:_init_base(1)
	_configure_preview_balance_settings(minigame)
	_reset_preview_balance_state(minigame)

	return minigame
end

function PreviewBalanceMinigame:start(player)
	PreviewMinigameBase.start(self, player)
	_configure_preview_balance_settings(self)
	_reset_preview_balance_state(self)
end

function PreviewBalanceMinigame:uses_action()
	return false
end

function PreviewBalanceMinigame:uses_joystick()
	return true
end

function PreviewBalanceMinigame:position()
	return self._position
end

function PreviewBalanceMinigame:distance()
	local position = self._position

	return math.sqrt(position.x * position.x + position.y * position.y)
end

function PreviewBalanceMinigame:progressing()
	return self:distance() < 1
end

function PreviewBalanceMinigame:progression()
	return self._progression
end

function PreviewBalanceMinigame:update(dt, t)
	local position = self._position
	local speed = self._speed

	position.x = position.x + speed.x * dt
	position.y = position.y + speed.y * dt

	local aim_away = math.atan2(-position.y, position.x)
	local distance = self:distance()

	if distance > 1.02 then
		position.x = math.cos(aim_away) * 1.01
		position.y = -math.sin(aim_away) * 1.01
		speed.x = 0
		speed.y = 0
	elseif distance < 1 then
		local power = (1 - distance) * (self._balance_push_ratio or MinigameSettings.balance_push_ratio) * dt

		speed.x = speed.x + math.cos(aim_away) * power
		speed.y = speed.y - math.sin(aim_away) * power
	end

	self._disrupt_timer = self._disrupt_timer - dt

	if self:progressing() then
		self._progression = math.min(self._progression + dt * (self._balance_progress_rate or 0.28), 1)

		if self._disrupt_timer <= 0 then
			self._disrupt_timer = self._disrupt_timer + (self._balance_disrupt_interval or MinigameSettings.balance_disrupt_interval)

			local aim_random = math.random() * math.pi * 2
			local power = self._balance_disrupt_power or MinigameSettings.balance_disrupt_power

			speed.x = speed.x + math.cos(aim_random) * power
			speed.y = speed.y - math.sin(aim_random) * power
		end
	else
		self._disrupt_timer = self._balance_disrupt_interval or MinigameSettings.balance_disrupt_interval
	end

	if self._sound_alert_time > 0 then
		self._sound_alert_time = self._sound_alert_time - dt
	else
		local is_stuck = not self:progressing()

		if is_stuck ~= self._is_stuck_indication then
			if is_stuck then
				self:play_sound("sfx_minigame_fail")
			end

			self._is_stuck_indication = is_stuck
			self._sound_alert_time = MinigameSettings.balance_sound_block or 0
		end
	end

	local max_speed = self._balance_max_speed or MinigameSettings.balance_max_speed

	speed.x = math.clamp(speed.x, -max_speed, max_speed)
	speed.y = math.clamp(speed.y, -max_speed, max_speed)

	if self._progression >= 1 and not self:is_completed() then
		self:play_sound("sfx_minigame_success_last")
		self:complete()
	end
end

function PreviewBalanceMinigame:on_axis_set(t, x, y)
	y = -y

	local dt = math.max(t - self._last_axis_set, 0)

	self._last_axis_set = t

	if x ~= 0 then
		self._speed.x = self._speed.x + x * (self._balance_move_ratio or MinigameSettings.balance_move_ratio) * dt
	end

	if y ~= 0 then
		self._speed.y = self._speed.y + y * (self._balance_move_ratio or MinigameSettings.balance_move_ratio) * dt
	end
end

local PreviewFrequencyMinigame = setmetatable({}, { __index = PreviewMinigameBase })
PreviewFrequencyMinigame.__index = PreviewFrequencyMinigame

local function _clamp_practice_frequency(point)
	return {
		x = math.clamp(point.x, MinigameSettings.frequency_width_min_scale, MinigameSettings.frequency_width_max_scale),
		y = math.clamp(point.y, MinigameSettings.frequency_height_min_scale, MinigameSettings.frequency_height_max_scale),
	}
end

local function _random_frequency_point()
	local min_x = MinigameSettings.frequency_width_min_scale
	local max_x = MinigameSettings.frequency_width_max_scale
	local min_y = MinigameSettings.frequency_height_min_scale
	local max_y = MinigameSettings.frequency_height_max_scale

	return {
		x = min_x + (max_x - min_x) * math.random(),
		y = min_y + (max_y - min_y) * math.random(),
	}
end

local function _random_frequency_stage_pair()
	for _ = 1, 16 do
		local start = _clamp_practice_frequency(_random_frequency_point())
		local target = _clamp_practice_frequency(_random_frequency_point())
		local delta_x = math.abs(start.x - target.x)
		local delta_y = math.abs(start.y - target.y)

		if delta_x + delta_y >= 0.9 and (delta_x >= 0.25 or delta_y >= 0.25) then
			return start, target
		end
	end

	return _clamp_practice_frequency({
		x = MinigameSettings.frequency_width_min_scale,
		y = MinigameSettings.frequency_height_min_scale,
	}), _clamp_practice_frequency({
		x = MinigameSettings.frequency_width_max_scale,
		y = MinigameSettings.frequency_height_max_scale,
	})
end

local function _random_frequency_patterns()
	local starts = {}
	local targets = {}

	for stage = 1, MinigameSettings.frequency_search_stage_amount do
		local start, target = _random_frequency_stage_pair()

		starts[stage] = start
		targets[stage] = target
	end

	return starts, targets
end

function PreviewFrequencyMinigame:new()
	local starts, targets = _random_frequency_patterns()
	local start_frequency = starts[1]
	local target_frequency = targets[1]
	local minigame = setmetatable({
		_frequency = {
			x = start_frequency.x,
			y = start_frequency.y,
		},
		_frequency_starts = starts,
		_frequency_targets = targets,
		_last_axis_set = _gameplay_time(),
		_target_frequency = {
			x = target_frequency.x,
			y = target_frequency.y,
		},
	}, PreviewFrequencyMinigame)

	minigame:_init_base(MinigameSettings.frequency_search_stage_amount)

	return minigame
end

function PreviewFrequencyMinigame:uses_joystick()
	return true
end

function PreviewFrequencyMinigame:frequency()
	return self._frequency
end

function PreviewFrequencyMinigame:target_frequency()
	return self._target_frequency
end

function PreviewFrequencyMinigame:_set_stage_targets(stage)
	local starts = self._frequency_starts
	local targets = self._frequency_targets
	local start = starts[stage] or starts[#starts]
	local target = targets[stage] or targets[#targets]

	self._frequency.x = start.x
	self._frequency.y = start.y
	self._target_frequency.x = target.x
	self._target_frequency.y = target.y
end

function PreviewFrequencyMinigame:_is_frequency_on_target(x, y)
	return math.abs(x - self._target_frequency.x) < MinigameSettings.frequency_success_margin and math.abs(y - self._target_frequency.y) < MinigameSettings.frequency_success_margin
end

function PreviewFrequencyMinigame:_adjust_value_with_auto_aim(current_value, target_value, change_ratio, dt, min_scale, max_scale, input)
	local new_value = math.clamp(current_value + input * change_ratio * dt, min_scale, max_scale)
	local to_target = math.abs(new_value - target_value)

	if MinigameSettings.frequency_help_enabled and to_target < MinigameSettings.frequency_help_margin then
		local adjustment = (1 - to_target / MinigameSettings.frequency_help_margin) * MinigameSettings.frequency_help_power * dt

		if to_target < adjustment then
			new_value = target_value
		else
			if new_value - target_value > 0 then
				adjustment = -adjustment
			end

			new_value = new_value + adjustment
		end
	end

	return new_value
end

function PreviewFrequencyMinigame:is_visually_on_target()
	local frequency = self._frequency

	return self:_is_frequency_on_target(frequency.x, frequency.y)
end

function PreviewFrequencyMinigame:on_action_pressed(t)
	local frequency = self._frequency

	if self:_is_frequency_on_target(frequency.x, frequency.y) then
		local is_last_stage = self._current_stage >= self._stage_amount

		self._current_stage = self._current_stage + 1

		if self._current_stage > self._stage_amount then
			self:play_sound("sfx_minigame_sinus_success_last")
			self:complete()
		else
			self:_set_stage_targets(self._current_stage)
			if is_last_stage then
				self:play_sound("sfx_minigame_sinus_success_last")
			else
				self:play_sound("sfx_minigame_success")
			end
		end
	else
		self._current_stage = math.max(self._current_stage - 1, 1)
		self:_set_stage_targets(self._current_stage)
		self:play_sound("sfx_minigame_bio_fail")
	end
end

function PreviewFrequencyMinigame:on_axis_set(t, x, y)
	local dt = math.max(t - self._last_axis_set, 0)

	self._last_axis_set = t

	if x ~= 0 then
		local old_x = self._frequency.x
		local new_x = self:_adjust_value_with_auto_aim(old_x, self._target_frequency.x, MinigameSettings.frequency_change_ratio_x, dt, MinigameSettings.frequency_width_min_scale, MinigameSettings.frequency_width_max_scale, x)

		if old_x ~= new_x then
			self._frequency.x = new_x
			self:play_sound("sfx_minigame_sinus_adjust_x")
		end
	end

	if y ~= 0 then
		local old_y = self._frequency.y
		local new_y = self:_adjust_value_with_auto_aim(old_y, self._target_frequency.y, MinigameSettings.frequency_change_ratio_y, dt, MinigameSettings.frequency_height_min_scale, MinigameSettings.frequency_height_max_scale, y)

		if old_y ~= new_y then
			self._frequency.y = new_y
			self:play_sound("sfx_minigame_sinus_adjust_y")
		end
	end
end

PreviewExpeditionMinigame = setmetatable({}, { __index = PreviewMinigameBase })
PreviewExpeditionMinigame.__index = PreviewExpeditionMinigame

mod._expedition_symbol_pool = function()
	local symbols = MinigameSettings.decode_search_symbols

	if type(symbols) == "table" and #symbols > 0 then
		local normalized = {}

		for index = 1, #symbols do
			local symbol_id = mod._normalize_expedition_symbol_id(symbols[index])

			if symbol_id ~= nil then
				normalized[#normalized + 1] = symbol_id
			end
		end

		if #normalized > 0 then
			return normalized
		end
	end

	local fallback = {}

	for symbol_id = 1, math.max(MinigameSettings.decode_symbols_total_items or 24, 24) do
		fallback[#fallback + 1] = symbol_id
	end

	return fallback
end

mod._make_preview_expedition_grid = function()
	local width = mod._expedition_board_width()
	local height = mod._expedition_board_height()
	local symbols = {}
	local pool = mod._expedition_symbol_pool()

	for index = 1, width * height do
		symbols[index] = pool[math.random(1, #pool)]
	end

	return symbols
end

mod._default_expedition_symbol_id = function()
	local pool = mod._expedition_symbol_pool()

	return pool[1] or 1
end

mod._sanitize_expedition_board_symbols = function(symbols)
	local normalized = {}
	local default_symbol = mod._default_expedition_symbol_id()
	local total_items = mod._expedition_board_width() * mod._expedition_board_height()

	for index = 1, total_items do
		normalized[index] = mod._normalize_expedition_symbol_id(symbols and symbols[index], default_symbol) or default_symbol
	end

	return normalized
end

mod._sanitize_expedition_target_symbols = function(symbols)
	local selected_symbols = {}
	local default_symbol = mod._default_expedition_symbol_id()
	local total_items = mod._expedition_cursor_width() * mod._expedition_cursor_height()

	if type(symbols) == "table" and type(symbols[1]) == "table" then
		for y = 1, #symbols do
			local row = symbols[y]

			if type(row) == "table" then
				for x = 1, #row do
					selected_symbols[#selected_symbols + 1] = mod._normalize_expedition_symbol_id(row[x], default_symbol) or default_symbol
				end
			else
				selected_symbols[#selected_symbols + 1] = mod._normalize_expedition_symbol_id(row, default_symbol) or default_symbol
			end
		end
	elseif type(symbols) == "table" then
		for index = 1, total_items do
			selected_symbols[index] = mod._normalize_expedition_symbol_id(symbols[index], default_symbol) or default_symbol
		end
	end

	for index = #selected_symbols + 1, total_items do
		selected_symbols[index] = default_symbol
	end

	return selected_symbols
end

mod._preview_expedition_symbols_for_target = function(symbols, target_x, target_y)
	local selected_symbols = {}
	local board_width = mod._expedition_board_width()
	local board_height = mod._expedition_board_height()
	local cursor_width = mod._expedition_cursor_width()
	local cursor_height = mod._expedition_cursor_height()

	if type(symbols) ~= "table" then
		return selected_symbols
	end

	target_x = math.clamp(math.floor((target_x or 0) + 0.5), 0, math.max(board_width - cursor_width, 0))
	target_y = math.clamp(math.floor((target_y or 0) + 0.5), 0, math.max(board_height - cursor_height, 0))

	local default_symbol = mod._default_expedition_symbol_id()

	for y = 0, cursor_height - 1 do
		for x = 0, cursor_width - 1 do
			local index = (target_y + y) * board_width + (target_x + x) + 1

			selected_symbols[#selected_symbols + 1] = mod._normalize_expedition_symbol_id(symbols[index], default_symbol) or default_symbol
		end
	end

	return selected_symbols
end

mod._make_preview_expedition_targets = function(symbols)
	local stage_amount = MinigameSettings.decode_search_stage_amount or 4
	local targets = {}
	local positions = {}
	local max_x = math.max(mod._expedition_board_width() - mod._expedition_cursor_width(), 0)
	local max_y = math.max(mod._expedition_board_height() - mod._expedition_cursor_height(), 0)

	for stage = 1, stage_amount do
		local target_x = math.random(0, max_x)
		local target_y = math.random(0, max_y)
		targets[stage] = mod._preview_expedition_symbols_for_target(symbols, target_x, target_y)
		positions[stage] = {
			x = target_x,
			y = target_y,
		}
	end

	return targets, positions
end

function PreviewExpeditionMinigame:new()
	local symbols = mod._sanitize_expedition_board_symbols(mod._make_preview_expedition_grid())
	local max_x = math.max(mod._expedition_board_width() - mod._expedition_cursor_width(), 0)
	local max_y = math.max(mod._expedition_board_height() - mod._expedition_cursor_height(), 0)
	local targets, target_positions = mod._make_preview_expedition_targets(symbols)
	local minigame = setmetatable({
		_auspex_helper_cursor_base = 0,
		_cursor_position = {
			x = math.floor(max_x * 0.5),
			y = math.floor(max_y * 0.5),
		},
		_decode_target_positions = target_positions,
		_decode_targets = targets,
		_last_axis_set = _gameplay_time(),
		_move_delay = MinigameSettings.decode_move_delay or 0.12,
		_symbols = symbols,
	}, PreviewExpeditionMinigame)

	minigame:_init_base(MinigameSettings.decode_search_stage_amount or 4)

	return minigame
end

function PreviewExpeditionMinigame:uses_joystick()
	return true
end

function PreviewExpeditionMinigame:symbols()
	return self._symbols
end

function PreviewExpeditionMinigame:set_symbols(symbols)
	if type(symbols) ~= "table" then
		return
	end

	self._symbols = mod._sanitize_expedition_board_symbols(symbols)

	if type(self._decode_target_positions) == "table" and next(self._decode_target_positions) ~= nil then
		self._decode_targets = {}

		for index = 1, #self._decode_target_positions do
			local position = self._decode_target_positions[index]
			local target_x = position and (position.x or position[1]) or nil
			local target_y = position and (position.y or position[2]) or nil

			if target_x ~= nil and target_y ~= nil then
				self._decode_targets[index] = mod._preview_expedition_symbols_for_target(self._symbols, target_x, target_y)
			end
		end
	else
		local targets, target_positions = mod._make_preview_expedition_targets(self._symbols)
		self._decode_targets = targets
		self._decode_target_positions = target_positions
	end
end

function PreviewExpeditionMinigame:cursor_position()
	return {
		x = (self._cursor_position.x or 0) + 1,
		y = (self._cursor_position.y or 0) + 1,
	}
end

function PreviewExpeditionMinigame:set_cursor_position(x, y)
	if type(x) == "table" then
		y = x.y or x[2]
		x = x.x or x[1]
	end

	if x == nil or y == nil then
		return
	end

	self._cursor_position = {
		x = math.clamp(math.floor(x + 0.5), 0, math.max(mod._expedition_board_width() - mod._expedition_cursor_width(), 0)),
		y = math.clamp(math.floor(y + 0.5), 0, math.max(mod._expedition_board_height() - mod._expedition_cursor_height(), 0)),
	}
end

function PreviewExpeditionMinigame:decode_targets()
	local targets = {}

	if type(self._decode_target_positions) == "table" and next(self._decode_target_positions) ~= nil then
		for index = 1, #self._decode_target_positions do
			local position = self._decode_target_positions[index]
			local target_x = position and (position.x or position[1]) or nil
			local target_y = position and (position.y or position[2]) or nil

			if target_x ~= nil and target_y ~= nil then
				targets[index] = mod._sanitize_expedition_target_symbols(self:get_symbols_for_target(target_x, target_y))
			end
		end
	else
		for index = 1, #(self._decode_targets or {}) do
			targets[index] = mod._sanitize_expedition_target_symbols(self._decode_targets[index])
		end
	end

	return targets
end

function PreviewExpeditionMinigame:current_decode_target()
	local stage = self._current_stage
	local target = type(self._decode_target_positions) == "table" and stage and self._decode_target_positions[stage] or nil

	if target then
		local target_x = target.x or target[1]
		local target_y = target.y or target[2]

		if target_x ~= nil and target_y ~= nil then
			return mod._sanitize_expedition_target_symbols(self:get_symbols_for_target(target_x, target_y))
		end
	end

	return mod._sanitize_expedition_target_symbols(self._decode_targets and stage and self._decode_targets[stage] or nil)
end

function PreviewExpeditionMinigame:time_since_move()
	return math.max((_gameplay_time() or 0) - (self._last_axis_set or 0), 0)
end

function PreviewExpeditionMinigame:get_symbols_for_target(target_x, target_y)
	return mod._sanitize_expedition_target_symbols(mod._preview_expedition_symbols_for_target(self._symbols, target_x, target_y))
end

function PreviewExpeditionMinigame:generate_board()
	local symbols = mod._sanitize_expedition_board_symbols(mod._make_preview_expedition_grid())
	local targets, target_positions = mod._make_preview_expedition_targets(symbols)

	self._symbols = symbols
	self._decode_targets = targets
	self._decode_target_positions = target_positions
end

function PreviewExpeditionMinigame:setup_game()
	if type(self._symbols) ~= "table" or #self._symbols == 0 or type(self._decode_targets) ~= "table" or next(self._decode_targets) == nil or type(self._decode_target_positions) ~= "table" or next(self._decode_target_positions) == nil then
		self:generate_board()
	end

	self._cursor_position = {
		x = math.floor(math.max(mod._expedition_board_width() - mod._expedition_cursor_width(), 0) * 0.5),
		y = math.floor(math.max(mod._expedition_board_height() - mod._expedition_cursor_height(), 0) * 0.5),
	}
	self._last_axis_set = _gameplay_time()
	self._current_stage = 1
	self:set_state(MinigameSettings.game_states.gameplay)
end

function PreviewExpeditionMinigame:is_on_target()
	local stage = self._current_stage
	local cursor = self._cursor_position
	local target = type(self._decode_target_positions) == "table" and stage and self._decode_target_positions[stage] or nil

	if cursor and target then
		local target_x = target.x or target[1]
		local target_y = target.y or target[2]

		if target_x ~= nil and target_y ~= nil then
			return cursor.x == target_x and cursor.y == target_y
		end
	end

	return _is_expedition_on_target(self)
end

function PreviewExpeditionMinigame:on_action_pressed(t)
	if not self:is_on_target() then
		self:play_sound("sfx_minigame_bio_fail")
		return
	end

	self._current_stage = self._current_stage + 1

	if self._current_stage > self._stage_amount then
		self:play_sound("sfx_minigame_success_last")
		self:complete()
	else
		self:play_sound("sfx_minigame_success")
	end
end

function PreviewExpeditionMinigame:on_axis_set(t, x, y)
	if math.max(math.abs(x or 0), math.abs(y or 0)) < 0.5 then
		return
	end

	if t - (self._last_axis_set or 0) < (self._move_delay or 0.12) then
		return
	end

	self._last_axis_set = t

	if math.abs(x or 0) >= math.abs(y or 0) then
		self._cursor_position.x = math.clamp(self._cursor_position.x + ((x or 0) > 0 and 1 or -1), 0, math.max(mod._expedition_board_width() - mod._expedition_cursor_width(), 0))
	else
		self._cursor_position.y = math.clamp(self._cursor_position.y + ((y or 0) > 0 and -1 or 1), 0, math.max(mod._expedition_board_height() - mod._expedition_cursor_height(), 0))
	end

	self:play_sound("sfx_minigame_scan_cursor_move")
end

local PREVIEW_MINIGAME_FACTORIES = {
	[MinigameSettings.types.decode_symbols] = function()
		return PreviewDecodeMinigame:new()
	end,
	[PREVIEW_DECODE_SYMBOLS_12_TYPE] = function()
		return PreviewDecodeMinigame:new_with_stage_amount(PREVIEW_DECODE_SYMBOLS_12_STAGE_AMOUNT)
	end,
	[MinigameSettings.types.drill] = function()
		return PreviewDrillMinigame:new()
	end,
	[MinigameSettings.types.balance] = function()
		return PreviewBalanceMinigame:new()
	end,
	[MinigameSettings.types.frequency] = function()
		return PreviewFrequencyMinigame:new()
	end,
	[EXPEDITION_MINIGAME_TYPE] = function()
		return PreviewExpeditionMinigame:new()
	end,
	[LEGACY_EXPEDITION_MINIGAME_TYPE] = function()
		return PreviewExpeditionMinigame:new()
	end,
}

local PreviewMinigameExtension = {}
PreviewMinigameExtension.__index = PreviewMinigameExtension

function PreviewMinigameExtension:new(minigame_type)
	local factory = PREVIEW_MINIGAME_FACTORIES[minigame_type]

	if not factory then
		return nil
	end

	local minigame = factory()

	_tag_minigame_type(minigame, minigame_type)

	return setmetatable({
		_minigame = minigame,
		_minigame_type = minigame_type,
	}, PreviewMinigameExtension)
end

function PreviewMinigameExtension:minigame_type()
	return self._minigame_type
end

function PreviewMinigameExtension:minigame()
	return self._minigame
end

local function _try_minigame_extension_minigame(minigame_extension, minigame_type)
	if not minigame_extension or not minigame_extension.minigame then
		return nil
	end

	local ok, minigame = nil, nil

	if minigame_type ~= nil then
		ok, minigame = pcall(minigame_extension.minigame, minigame_extension, minigame_type)
	else
		ok, minigame = pcall(minigame_extension.minigame, minigame_extension)
	end

	return ok and minigame or nil
end

function mod._cache_expedition_map_minigame(minigame)
	local candidate = minigame

	if type(candidate) == "table" and not (candidate.selected_level and candidate.world_pos_to_map_pos) then
		local nested = rawget(candidate, "_minigame") or rawget(candidate, "auspex_map") or rawget(candidate, "_map_minigame") or rawget(candidate, "map_minigame") or rawget(candidate, "minigame")

		if type(nested) == "function" then
			local ok, resolved = pcall(nested, candidate, EXPEDITION_MAP_MINIGAME_TYPE)

			if not ok or resolved == nil or resolved == candidate then
				ok, resolved = pcall(nested, candidate)
			end

			nested = ok and resolved or nil
		end

		if type(nested) == "table" then
			candidate = nested
		end
	end

	if candidate and candidate.selected_level and candidate.world_pos_to_map_pos then
		mod._cached_expedition_map_minigame = _tag_minigame_type(candidate, EXPEDITION_MAP_MINIGAME_TYPE)
	end

	return mod._cached_expedition_map_minigame
end

local function _local_player()
	local cached_player = mod._cached_local_player

	if cached_player ~= nil then
		return cached_player or nil
	end

	local player_manager = Managers.player

	if not player_manager then
		mod._cached_local_player = false
		return nil
	end

	local connection_manager = Managers.connection

	if connection_manager and connection_manager.is_initialized and not connection_manager:is_initialized() then
		mod._cached_local_player = false
		return nil
	end

	if player_manager.local_player_safe then
		local ok, player = pcall(player_manager.local_player_safe, player_manager, 1)

		if ok and player then
			mod._cached_local_player = player
			return player
		end
	end

	if not connection_manager or not connection_manager.is_initialized or not connection_manager:is_initialized() then
		mod._cached_local_player = false
		return nil
	end

	if (player_manager._num_players or 0) <= 0 or (player_manager._num_human_players or 0) <= 0 then
		mod._cached_local_player = false
		return nil
	end

	if not player_manager.local_player then
		mod._cached_local_player = false
		return nil
	end

	local ok, player = pcall(player_manager.local_player, player_manager, 1)

	mod._cached_local_player = ok and player or false

	return ok and player or nil
end

local function _local_player_unit()
	local cached_player_unit = mod._cached_local_player_unit

	if cached_player_unit ~= nil then
		return cached_player_unit or nil
	end

	local player = _local_player()
	local player_unit = player and player.player_unit or nil

	mod._cached_local_player_unit = player_unit and Unit.alive(player_unit) and player_unit or false

	return mod._cached_local_player_unit or nil
end

_active_live_minigame = function()
	local cached_live_minigame = mod._cached_live_minigame

	if cached_live_minigame ~= nil then
		return cached_live_minigame or nil
	end

	local player_unit = _local_player_unit()
	local character_state_machine_extension = player_unit and ScriptUnit.has_extension(player_unit, "character_state_machine_system")

	if not character_state_machine_extension or character_state_machine_extension:current_state_name() ~= "minigame" then
		mod._cached_live_minigame = false
		mod._cached_live_minigame_type = nil
		mod._debug_event("live_minigame", "inactive")
		return nil
	end

	local current_state = character_state_machine_extension:current_state()
	local method_minigame = nil
	local method_type = nil
	local field_minigame = mod._unwrap_nested_minigame(current_state and current_state._minigame or nil)
	local field_type = _minigame_type_hint(field_minigame)

	if current_state and current_state.minigame then
		method_minigame = mod._unwrap_nested_minigame(current_state:minigame() or nil)
		method_type = _minigame_type_hint(method_minigame)
	end

	if field_minigame and field_type then
		_tag_minigame_type(field_minigame, field_type)
	end

	if method_minigame and method_type then
		_tag_minigame_type(method_minigame, method_type)
	end

	if field_minigame
		and field_type
		and not mod._is_expedition_map_minigame_type(field_type)
		and (method_minigame == nil or (method_type and mod._is_expedition_map_minigame_type(method_type)))
	then
		mod._cached_live_minigame = field_minigame
		mod._cached_live_minigame_type = field_type
		mod._debug_event("live_minigame", string.format("active type=%s source=_minigame preferred_over=%s", tostring(field_type or "unknown"), tostring(method_type or "nil")))
		return mod._cached_live_minigame
	end

	if method_minigame then
		mod._cached_live_minigame = method_minigame or false
		_tag_minigame_type(mod._cached_live_minigame or nil, mod._cached_live_minigame_type)
		mod._debug_event("live_minigame", string.format("active type=%s source=minigame()", tostring(_minigame_type_hint(mod._cached_live_minigame or nil) or mod._cached_live_minigame_type or "unknown")))

		return mod._cached_live_minigame or nil
	end

	mod._cached_live_minigame = field_minigame or false
	_tag_minigame_type(mod._cached_live_minigame or nil, mod._cached_live_minigame_type)
	mod._debug_event("live_minigame", string.format("active type=%s source=_minigame", tostring(_minigame_type_hint(mod._cached_live_minigame or nil) or mod._cached_live_minigame_type or "unknown")))

	return mod._cached_live_minigame or nil
end

local function _active_live_minigame_type()
	local live_minigame = _active_live_minigame()

	return _minigame_type_hint(live_minigame) or mod._cached_live_minigame_type
end

_practice_session_blocks_live_autosolve = function()
	local session = practice_session

	if not session then
		return false
	end

	if session.pending_item_mode then
		return true
	end

	local ui_manager = Managers.ui

	if session.item_mode then
		return session.item_view_opened == true
			or (ui_manager and (
				ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)
				or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME)
			)) or false
	end

	local view_name = session.view_name or PREVIEW_VIEW_NAME

	return (ui_manager and (
		ui_manager:view_active(view_name)
		or ui_manager:is_view_closing(view_name)
	)) or false
end

local function _active_practice_minigame()
	if practice_session and practice_session.minigame and not practice_session.pending_item_mode and _practice_session_blocks_live_autosolve() then
		return practice_session.minigame
	end

	return nil
end

local function _active_practice_minigame_type()
	local practice_minigame = _active_practice_minigame()

	return _minigame_type_hint(practice_minigame) or (_practice_session_blocks_live_autosolve() and practice_session and practice_session.minigame_type) or nil
end

local function _looks_like_decode_style_minigame(minigame)
	return minigame and minigame.current_decode_target and minigame.sweep_duration and minigame.is_on_target
end

local function _looks_like_decode_minigame(minigame)
	local minigame_type = _minigame_type_hint(minigame)

	return (minigame_type == nil or not _is_expedition_minigame_type(minigame_type)) and _looks_like_decode_style_minigame(minigame)
end

local function _looks_like_expedition_grid_minigame(minigame)
	return minigame and minigame.symbols and minigame.cursor_position and minigame.current_stage and minigame.on_axis_set
end

local function _looks_like_expedition_minigame(minigame)
	local minigame_type = _minigame_type_hint(minigame)

	if mod._is_expedition_map_minigame_type(minigame_type)
		or (minigame and minigame.selected_level and minigame.world_pos_to_map_pos)
	then
		return false
	end

	return _looks_like_expedition_grid_minigame(minigame)
		or (_is_expedition_minigame_type(minigame_type) and _looks_like_decode_style_minigame(minigame))
end

local function _resolve_decode_style_minigame(minigame_extension)
	if not minigame_extension then
		return nil
	end

	local minigame_type = minigame_extension.minigame_type and minigame_extension:minigame_type() or nil
	local candidate_types = _is_expedition_minigame_type(minigame_type) and {
		EXPEDITION_MINIGAME_TYPE,
		false,
		MinigameSettings.types.decode_symbols,
	} or {
		MinigameSettings.types.decode_symbols,
		false,
		EXPEDITION_MINIGAME_TYPE,
	}

	for index = 1, #candidate_types do
		local candidate_type = candidate_types[index]
		local minigame = _tag_minigame_type(_try_minigame_extension_minigame(minigame_extension, candidate_type or nil), candidate_type or minigame_type)

		if _looks_like_decode_style_minigame(minigame) then
			return minigame
		end
	end

	return nil
end

local function _decode_style_future_rows(minigame)
	if _looks_like_expedition_minigame(minigame) then
		return 0
	end

	return _should_highlight_decode_targets() and (mod:get("decode_future_rows") or 0) or 0
end

local function _looks_like_frequency_minigame(minigame)
	return minigame and minigame.frequency and minigame.target_frequency and minigame.is_visually_on_target
end

_looks_like_balance_minigame = function(minigame)
	return minigame and minigame.position and minigame.distance and minigame.progression and minigame.uses_joystick and minigame:uses_joystick()
end

_apply_widget_draw_offset_y = function(widgets, delta_y, touched_widgets)
	if not widgets or delta_y == 0 then
		return
	end

	for index = 1, #widgets do
		local widget = widgets[index]
		local offset = widget and widget.offset

		if offset then
			offset[2] = (offset[2] or 0) + delta_y
			touched_widgets[#touched_widgets + 1] = widget
		end
	end
end

_restore_widget_draw_offset_y = function(touched_widgets, delta_y)
	if delta_y == 0 then
		return
	end

	for index = 1, #touched_widgets do
		local widget = touched_widgets[index]
		local offset = widget and widget.offset

		if offset then
			offset[2] = (offset[2] or 0) - delta_y
		end
	end
end

_active_decode_autosolve_minigame = function()
	local practice_minigame = _active_practice_minigame()
	local practice_minigame_type = _active_practice_minigame_type()

	if (practice_minigame_type == MinigameSettings.types.decode_symbols or practice_minigame_type == PREVIEW_DECODE_SYMBOLS_12_TYPE) and _looks_like_decode_minigame(practice_minigame) then
		return practice_minigame
	end

	local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()
	local state_field_type = _minigame_type_hint(state_field_minigame)
	local state_method_type = _minigame_type_hint(state_method_minigame)

	if (state_field_type == nil or state_field_type == MinigameSettings.types.decode_symbols)
		and _looks_like_decode_minigame(state_field_minigame)
	then
		return state_field_minigame
	end

	if (state_method_type == nil or state_method_type == MinigameSettings.types.decode_symbols)
		and _looks_like_decode_minigame(state_method_minigame)
	then
		return state_method_minigame
	end

	local live_minigame = _active_live_minigame()
	local live_minigame_type = _active_live_minigame_type()

	if (live_minigame_type == nil or live_minigame_type == MinigameSettings.types.decode_symbols) and _looks_like_decode_minigame(live_minigame) then
		return live_minigame
	end

	local cached_live_minigame = rawget(mod, "_cached_live_minigame")
	local cached_live_minigame_type = rawget(mod, "_cached_live_minigame_type")

	if (cached_live_minigame_type == nil or cached_live_minigame_type == MinigameSettings.types.decode_symbols)
		and _looks_like_decode_minigame(cached_live_minigame)
	then
		return cached_live_minigame
	end

	return nil
end

_active_expedition_autosolve_minigame = function()
	local function _usable_expedition_autosolve_minigame(minigame)
		local minigame_type = _minigame_type_hint(minigame)

		if mod._is_expedition_map_minigame_type(minigame_type)
			or (minigame and minigame.selected_level and minigame.world_pos_to_map_pos)
		then
			return nil
		end

		if not _looks_like_expedition_minigame(minigame) then
			return nil
		end

		if minigame.is_completed then
			local ok, completed = pcall(minigame.is_completed, minigame)

			if ok and completed then
				return nil
			end
		end

		local stage = minigame.current_stage and minigame:current_stage() or minigame._current_stage
		local stage_amount = minigame._stage_amount or MinigameSettings.decode_search_stage_amount or 3

		if type(stage) == "number" and type(stage_amount) == "number" and stage > stage_amount then
			return nil
		end

		local state_name = minigame.state and minigame:state() or minigame._current_state

		if state_name == MinigameSettings.game_states.complete or state_name == MinigameSettings.game_states.outro then
			return nil
		end

		return minigame
	end

	local practice_minigame = _active_practice_minigame()

	if _is_expedition_minigame_type(_active_practice_minigame_type()) then
		local usable = _usable_expedition_autosolve_minigame(practice_minigame)

		if usable then
			return usable
		end
	end

	local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()

	if not mod._is_expedition_map_minigame_type(_minigame_type_hint(state_field_minigame)) then
		local usable = _usable_expedition_autosolve_minigame(state_field_minigame)

		if usable then
			return usable
		end
	end

	if not mod._is_expedition_map_minigame_type(_minigame_type_hint(state_method_minigame)) then
		local usable = _usable_expedition_autosolve_minigame(state_method_minigame)

		if usable then
			return usable
		end
	end

	local live_minigame = _active_live_minigame()
	local live_minigame_type = _active_live_minigame_type()

	if live_minigame_type == nil or _is_expedition_minigame_type(live_minigame_type) then
		local usable = _usable_expedition_autosolve_minigame(live_minigame)

		if usable then
			return usable
		end
	end

	local cached_expedition_live_minigame = rawget(mod, "_cached_expedition_live_minigame")
	local usable_cached = _usable_expedition_autosolve_minigame(cached_expedition_live_minigame)

	if usable_cached then
		local cached_matches_current = usable_cached == state_field_minigame
			or usable_cached == state_method_minigame
			or usable_cached == live_minigame
		local expedition_open_grace_active = (_gameplay_time() or 0) < (mod._expedition_autosolve_open_grace_until or 0)

		-- Never steer a detached cached expedition minigame offline. That can happen
		-- between interactions and produces bogus move/submit decisions against an old
		-- DecodeSearch object before the real current puzzle is fully bound.
		if not cached_matches_current and not expedition_open_grace_active then
			mod._cached_expedition_live_minigame = nil
			return nil
		end

		if _is_networked_live_session() and not _is_networked_live_minigame(usable_cached) then
			mod._cached_expedition_live_minigame = nil
		else
			return usable_cached
		end
	end

	if cached_expedition_live_minigame ~= nil then
		mod._cached_expedition_live_minigame = nil
	end

	return nil
end

function mod._unwrap_nested_minigame(candidate, preferred_type)
	local current = candidate

	for _ = 1, 4 do
		if type(current) ~= "table" then
			return current
		end

		if (current.selected_level and current.world_pos_to_map_pos)
			or (current.current_decode_target and current.cursor_position and current.on_axis_set)
			or (current.symbols and current.cursor_position and current.current_stage and current.on_axis_set)
		then
			return current
		end

		local nested = rawget(current, "_minigame")
			or rawget(current, "auspex_map")
			or rawget(current, "_map_minigame")
			or rawget(current, "map_minigame")
			or (type(rawget(current, "minigame")) == "table" and rawget(current, "minigame"))

		if nested == nil and type(rawget(current, "minigame")) == "function" then
			local ok, resolved = nil, nil

			if preferred_type ~= nil then
				ok, resolved = pcall(current.minigame, current, preferred_type)
			end

			if not ok or resolved == nil or resolved == current then
				ok, resolved = pcall(current.minigame, current)
			end

			nested = ok and resolved or nil
		end

		if nested == nil or nested == current then
			return current
		end

		current = nested
	end

	return current
end

_active_frequency_autosolve_minigame = function()
	local practice_minigame = _active_practice_minigame()

	if _looks_like_frequency_minigame(practice_minigame) then
		return practice_minigame
	end

	local live_minigame = _active_live_minigame()

	if _looks_like_frequency_minigame(live_minigame) then
		return live_minigame
	end

	return nil
end

_active_drill_autosolve_minigame = function()
	local practice_minigame = _active_practice_minigame()

	if _looks_like_drill_minigame(practice_minigame) then
		return practice_minigame
	end

	local live_minigame = _active_live_minigame()

	if _looks_like_drill_minigame(live_minigame) then
		return live_minigame
	end

	return nil
end

local function _ignore_errors(callback)
	if callback then
		xpcall(callback, function()
			return
		end)
	end
end

local function _force_cancel_local_minigame_state()
	local player_unit = _local_player_unit()

	if not player_unit then
		return
	end

	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local character_state_machine_extension = ScriptUnit.has_extension(player_unit, "character_state_machine_system")

	_ignore_errors(function()
		if character_state_machine_extension and character_state_machine_extension:current_state_name() == "minigame" then
			local current_state = character_state_machine_extension:current_state()

			if current_state and current_state.force_cancel then
				current_state:force_cancel()
			end
		end
	end)

	_ignore_errors(function()
		if not unit_data_extension then
			return
		end

		local minigame_character_state = unit_data_extension:write_component("minigame_character_state")

		if not minigame_character_state then
			return
		end

		minigame_character_state.interface_level_unit_id = NetworkConstants.invalid_level_unit_id
		minigame_character_state.interface_game_object_id = NetworkConstants.invalid_game_object_id
		minigame_character_state.interface_is_level_unit = true
		minigame_character_state.pocketable_device_active = false
	end)
end

local PRACTICE_SOUND_SOURCE_NAME = "_speaker"

local function _with_practice_sound_profile(visual_loadout_extension, callback)
	if not callback then
		return false
	end

	local profile_properties = visual_loadout_extension and visual_loadout_extension.profile_properties and visual_loadout_extension:profile_properties() or nil

	if not profile_properties then
		return callback()
	end

	local previous_weapon_template = profile_properties.wielded_weapon_template

	if previous_weapon_template == PRACTICE_SOUND_WEAPON_TEMPLATE then
		return callback()
	end

	profile_properties.wielded_weapon_template = PRACTICE_SOUND_WEAPON_TEMPLATE

	local ok, result = xpcall(callback, debug.traceback)

	profile_properties.wielded_weapon_template = previous_weapon_template

	if ok then
		return result
	end

	return false
end

local function _trigger_practice_sound_from_source(fx_extension, alias, source_name)
	if not fx_extension or not alias or not source_name then
		return false
	end

	if not fx_extension:sound_source(source_name) then
		return false
	end

	local playing_id = fx_extension:trigger_gear_wwise_event_with_source(alias, nil, source_name, false, true)

	if playing_id then
		return true
	end

	return false
end

local function _trigger_practice_sound_at_position(fx_extension, alias, position)
	if not fx_extension or not alias or not position then
		return false
	end

	if fx_extension.trigger_gear_wwise_event_with_position then
		return not not fx_extension:trigger_gear_wwise_event_with_position(alias, nil, position, false, true)
	end

	return false
end

local function _play_practice_sound_from_slot(visual_loadout_extension, fx_extension, slot_name, alias)
	local fx_sources = slot_name and visual_loadout_extension:source_fx_for_slot(slot_name)

	if type(fx_sources) ~= "table" then
		return false
	end

	local preferred_source_name = fx_sources[PRACTICE_SOUND_SOURCE_NAME]

	if _trigger_practice_sound_from_source(fx_extension, alias, preferred_source_name) then
		return true
	end

	for _, candidate_source_name in pairs(fx_sources) do
		if candidate_source_name ~= preferred_source_name and _trigger_practice_sound_from_source(fx_extension, alias, candidate_source_name) then
			return true
		end
	end

	return false
end

local function _play_practice_sound(alias)
	local player_unit = _local_player_unit()
	local fx_extension = player_unit and ScriptUnit.has_extension(player_unit, "fx_system")
	local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
	local visual_loadout_extension = player_unit and ScriptUnit.has_extension(player_unit, "visual_loadout_system")

	if not alias or not fx_extension or not unit_data_extension or not visual_loadout_extension then
		return false
	end

	local inventory_component = unit_data_extension:read_component("inventory")
	local wielded_slot = inventory_component and inventory_component.wielded_slot
	local played = _with_practice_sound_profile(visual_loadout_extension, function()
		local tried_slots = {}
		local slot_order = {
			PRACTICE_DEVICE_SLOT,
			wielded_slot,
		}

		for index = 1, #slot_order do
			local slot_name = slot_order[index]

			if slot_name and not tried_slots[slot_name] then
				tried_slots[slot_name] = true

				if _play_practice_sound_from_slot(visual_loadout_extension, fx_extension, slot_name, alias) then
					return true
				end
			end
		end

		local player_position = Unit.alive(player_unit) and Unit.world_position(player_unit, 1) or nil

		if _trigger_practice_sound_at_position(fx_extension, alias, player_position) then
			return true
		end

		if fx_extension.trigger_gear_wwise_event then
			return not not fx_extension:trigger_gear_wwise_event(alias, nil)
		end

		return false
	end)

	return not not played
end

function PreviewMinigameBase:play_sound(alias)
	_play_practice_sound(alias)
end

local function _build_preview_context(minigame_type)
	local minigame_extension = PreviewMinigameExtension:new(minigame_type)
	local display_minigame_type = _preview_display_minigame_type(minigame_type)

	if not minigame_extension then
		return nil
	end

	return {
		auspex_unit = nil,
		auspex_helper_is_practice = true,
		device_owner_unit = _local_player_unit(),
		minigame_extension = minigame_extension,
		minigame_type = display_minigame_type,
	}, minigame_extension
end

local function _minigame_display_mode(minigame_type)
	if mod._is_expedition_map_minigame_type(minigame_type) then
		return mod:get("expedition_map_display_mode") or "item"
	end

	return mod:get("live_display_mode") or "item"
end

mod._active_live_display_mode = function()
	return _minigame_display_mode(_active_live_minigame_type() or mod._cached_live_minigame_type)
end

mod._is_expedition_map_minigame_ready = function(minigame)
	if not minigame or not (minigame.selected_level and minigame.world_pos_to_map_pos) then
		return false
	end

	if not _local_player_unit() then
		return false
	end

	local ok_selected, selected_level = pcall(minigame.selected_level, minigame)

	if ok_selected and selected_level ~= nil then
		return true
	end

	-- Do not force-start expedition maps in the background, but still allow the
	-- overlay/minimap views to bind to a live expedition map object and let the
	-- stock map view finish initializing it.
	return true
end

mod._resolve_expedition_map_minigame = function(require_ready)
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or "unknown"
	local game_mode = game_mode_manager and game_mode_manager.game_mode and game_mode_manager:game_mode() or nil
	local game_mode_logic = game_mode and rawget(game_mode, "_game_mode_logic") or nil
	local navigation_handler = game_mode and game_mode.get_navigation_handler and game_mode:get_navigation_handler() or nil
	local minigame = nil
	local resolved_source = "none"
	local function resolve_candidate(owner, value)
		local candidate = value

		if candidate == nil then
			return nil
		end

		if type(candidate) == "function" then
			local ok, resolved = pcall(candidate, owner, EXPEDITION_MAP_MINIGAME_TYPE)

			if not ok or resolved == nil then
				ok, resolved = pcall(candidate, owner)
			end

			candidate = ok and resolved or nil
		end

		return mod._cache_expedition_map_minigame(candidate)
	end

	if game_mode and game_mode.map_minigame then
		minigame = resolve_candidate(game_mode, game_mode.map_minigame)

		if minigame then
			resolved_source = "game_mode.map_minigame"
		end
	end

	if not minigame then
		minigame = resolve_candidate(game_mode_logic, game_mode_logic and rawget(game_mode_logic, "map_minigame"))

		if minigame then
			resolved_source = "game_mode_logic.map_minigame"
		end
	end

	if not minigame then
		minigame = resolve_candidate(game_mode, game_mode and rawget(game_mode, "auspex_map"))

		if minigame then
			resolved_source = "game_mode.auspex_map"
		end
	end

	if not minigame then
		minigame = resolve_candidate(game_mode_logic, game_mode_logic and rawget(game_mode_logic, "auspex_map"))

		if minigame then
			resolved_source = "game_mode_logic.auspex_map"
		end
	end

	if not minigame then
		minigame = resolve_candidate(game_mode, game_mode and rawget(game_mode, "_map_minigame"))

		if minigame then
			resolved_source = "game_mode._map_minigame"
		end
	end

	if not minigame then
		minigame = resolve_candidate(game_mode_logic, game_mode_logic and rawget(game_mode_logic, "_map_minigame"))

		if minigame then
			resolved_source = "game_mode_logic._map_minigame"
		end
	end

	if not minigame then
		minigame = resolve_candidate(navigation_handler, navigation_handler and navigation_handler.minigame)

		if minigame then
			resolved_source = "navigation_handler:minigame()"
		end
	end

	if not minigame then
		minigame = resolve_candidate(navigation_handler, navigation_handler and rawget(navigation_handler, "_minigame"))

		if minigame then
			resolved_source = "navigation_handler._minigame"
		end
	end

	if not minigame then
		local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()

		minigame = mod._cache_expedition_map_minigame(state_method_minigame)
			or mod._cache_expedition_map_minigame(state_field_minigame)

		if minigame then
			resolved_source = "local_state"
		end
	end

	if not minigame then
		minigame = mod._cache_expedition_map_minigame(_active_live_minigame and _active_live_minigame() or nil)

		if minigame then
			resolved_source = "live_minigame"
		end
	end

	if not minigame and game_mode_name == "expedition" then
		minigame = rawget(mod, "_cached_expedition_map_minigame")

		if minigame then
			resolved_source = "cached"
		end
	end

	if not minigame or not (minigame.selected_level and minigame.world_pos_to_map_pos) then
		mod._debug_event("exp_map_resolve", string.format("result=nil require_ready=%s mode=%s cached=%s", tostring(require_ready ~= false), tostring(game_mode_name), tostring(rawget(mod, "_cached_expedition_map_minigame") ~= nil)))
		return nil
	end

	mod._cache_expedition_map_minigame(minigame)

	if require_ready ~= false and not mod._is_expedition_map_minigame_ready(minigame) then
		mod._debug_event("exp_map_resolve", string.format("result=not_ready source=%s require_ready=%s mode=%s", tostring(resolved_source), tostring(require_ready ~= false), tostring(game_mode_name)))
		return nil
	end

	mod._debug_event("exp_map_resolve", string.format("result=ok source=%s require_ready=%s mode=%s", tostring(resolved_source), tostring(require_ready ~= false), tostring(game_mode_name)))

	return _tag_minigame_type(minigame, EXPEDITION_MAP_MINIGAME_TYPE)
end

local function _practice_view_name()
	local session = practice_session

	if session and session.view_name then
		return session.view_name
	end

	return _minigame_display_mode() == "item" and STOCK_SCANNER_VIEW_NAME or PREVIEW_VIEW_NAME
end

mod._persistent_expedition_map_minigame = function()
	if practice_session or mod:get("expedition_map_always_minimap") ~= true or not _is_minigame_enabled(EXPEDITION_MAP_MINIGAME_TYPE) then
		mod._persistent_expedition_minimap_minigame = nil
		return nil
	end

	if mod._expedition_overlay_callout_freeze_active and mod._expedition_overlay_callout_freeze_active() then
		return rawget(mod, "_persistent_expedition_minimap_minigame")
			or rawget(mod, "_cached_expedition_map_minigame")
			or nil
	end

	local minigame = mod._resolve_expedition_map_minigame(false)

	if not minigame then
		local game_mode_manager = Managers.state and Managers.state.game_mode
		local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or "unknown"
		local cached_persistent_minigame = rawget(mod, "_persistent_expedition_minimap_minigame")
		local cached_map_minigame = rawget(mod, "_cached_expedition_map_minigame")
		local fallback_minigame = mod._cache_expedition_map_minigame(cached_persistent_minigame)
			or mod._cache_expedition_map_minigame(cached_map_minigame)

		if game_mode_name == "expedition" and fallback_minigame then
			return fallback_minigame
		end

		if game_mode_name ~= "expedition" then
			mod._cached_expedition_map_minigame = nil
		end

		mod._persistent_expedition_minimap_minigame = nil
		return nil
	end

	local previous_minigame = rawget(mod, "_persistent_expedition_minimap_minigame")

	if previous_minigame ~= nil and previous_minigame ~= minigame then
		local ui_manager = Managers.ui

		if ui_manager and (ui_manager:view_active(EXPEDITION_MINIMAP_VIEW_NAME) or ui_manager:is_view_closing(EXPEDITION_MINIMAP_VIEW_NAME)) then
			mod._debug_event("exp_map_minimap", "refresh minigame_changed=true")
			ui_manager:close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)
		end
	end

	mod._persistent_expedition_minimap_minigame = minigame

	return minigame
end

mod._open_persistent_expedition_minimap = function(minigame)
	if practice_session or not minigame then
		mod._debug_event("exp_map_minimap", string.format("skip practice=%s has_minigame=%s", tostring(practice_session ~= nil), tostring(minigame ~= nil)))
		return
	end

	local ui_manager = Managers.ui
	local ready = mod._is_expedition_map_minigame_ready and mod._is_expedition_map_minigame_ready(minigame) or false
	local active = ui_manager and ui_manager:view_active(EXPEDITION_MINIMAP_VIEW_NAME) or false
	local closing = ui_manager and ui_manager:is_view_closing(EXPEDITION_MINIMAP_VIEW_NAME) or false

	if not ui_manager then
		mod._debug_event("exp_map_minimap", "skip no_ui")
		return
	end

	if active and not ready then
		mod._debug_event("exp_map_minimap", "close stale_not_ready")
		ui_manager:close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)
		return
	end

	if closing or active then
		mod._debug_event("exp_map_minimap", string.format("skip ui=%s active=%s closing=%s ready=%s", tostring(ui_manager ~= nil), tostring(active), tostring(closing), tostring(ready)))
		return
	end

	if not ready then
		mod._debug_event("exp_map_minimap", "wait not_ready")
		return
	end

	local player_unit = _local_player_unit()
	local minigame_extension = {
		minigame = function(_, requested_type)
			if requested_type == nil or requested_type == EXPEDITION_MAP_MINIGAME_TYPE or requested_type == EXPEDITION_MINIMAP_MINIGAME_TYPE then
				return minigame
			end

			return nil
		end,
		minigame_type = function()
			return EXPEDITION_MINIMAP_MINIGAME_TYPE
		end,
	}

	ui_manager:open_view(EXPEDITION_MINIMAP_VIEW_NAME, nil, false, false, nil, {
		auspex_helper_expedition_minimap = true,
		auspex_helper_expedition_minimap_silent = true,
		auspex_helper_is_practice = false,
		auspex_unit = nil,
		-- Keep the persistent minimap detached from the live scanner owner/audio
		-- context while still using the stock expedition map renderer so the
		-- normal widget hooks continue to apply.
		device_owner_unit = nil,
		minigame_extension = minigame_extension,
		minigame_type = EXPEDITION_MINIMAP_MINIGAME_TYPE,
		wwise_world = nil,
	}, {
		use_transition_ui = false,
	})
	mod._debug_event("exp_map_minimap", "open requested")
end

mod._practice_minigame_display_name = function(minigame_type)
	if minigame_type == MinigameSettings.types.decode_symbols then
		return mod:localize("preview_type_decode_symbols")
	elseif minigame_type == PREVIEW_DECODE_SYMBOLS_12_TYPE then
		return mod:localize("preview_type_decode_symbols_12")
	elseif minigame_type == MinigameSettings.types.drill then
		return mod:localize("preview_type_drill")
	elseif minigame_type == MinigameSettings.types.frequency then
		return mod:localize("preview_type_frequency")
	elseif minigame_type == MinigameSettings.types.balance then
		return mod:localize("preview_type_balance")
	elseif _is_expedition_minigame_type(minigame_type) then
		return mod:localize("preview_type_expedition")
	end

	return tostring(minigame_type or "Unknown")
end

mod._notify_practice_completion = function(session)
	if not session or session.practice_completion_notified then
		return
	end

	local minigame = session.minigame

	if not minigame or not session.minigame_started or not minigame.is_completed or not minigame:is_completed() then
		return
	end

	local started_at = session.minigame_started_at or session.opened_at or _gameplay_time()
	local elapsed = math.max(_gameplay_time() - started_at, 0)
	local minigame_name = mod._practice_minigame_display_name(session.minigame_type)

	session.practice_completion_notified = true
	mod:notify(mod:localize("practice_complete_time", minigame_name, elapsed))
end

local _cleanup_preview_session
local _open_preview_view
local _abort_preview_session
local _set_preview_input_simulation

local function _close_view(view_name, force_close)
	local ui_manager = Managers.ui

	if not ui_manager or not view_name then
		return false
	end

	local is_active = ui_manager:view_active(view_name)
	local is_closing = ui_manager:is_view_closing(view_name)

	if not is_active and not is_closing then
		return false
	end

	if view_name == PREVIEW_VIEW_NAME
		or view_name == STOCK_SCANNER_VIEW_NAME
		or view_name == OVERLAY_VIEW_NAME
		or view_name == EXPEDITION_MINIMAP_VIEW_NAME
		or view_name == WORLD_SCAN_VIEW_NAME
		or view_name == WORLD_SCAN_ICONS_VIEW_NAME then
		mod._debug_event("view_close", string.format("name=%s force=%s active=%s closing=%s", tostring(view_name), tostring(force_close == true), tostring(is_active), tostring(is_closing)))
	end

	if force_close then
		_clear_preview_close_request()
	else
		preview_close_requested_at = _gameplay_time()
		preview_close_view_name = view_name
	end

	ui_manager:close_view(view_name, force_close == true)

	if force_close and practice_session and practice_session.view_name == view_name then
		_cleanup_preview_session()
	end

	return true
end

local function _close_preview_view(force_close)
	if practice_session and (practice_session.pending_item_mode or practice_session.item_mode) then
		local should_reopen = preview_reopen_requested and _is_mod_active() and mod:get("enable_preview")

		_abort_preview_session()

		if should_reopen then
			preview_reopen_requested = false
			_open_preview_view()
		end

		return true
	end

	return _close_view(_practice_view_name(), force_close)
end

local function _apply_mod_override_state()
	if not _is_mod_active() then
		_reset_decode_autosolve()
		_reset_expedition_autosolve()
		_reset_drill_autosolve()
		_reset_frequency_autosolve()
		_reset_balance_autosolve()
		mod._world_scan_next_refresh_t = nil
		mod._world_scan_next_visibility_refresh_t = nil

		preview_reopen_requested = false
		_reset_scanner_fade_state()

		_apply_scanner_current_alpha()
		_set_world_scan_highlights(false)
		_close_preview_view(false)
		_close_view(OVERLAY_VIEW_NAME, true)
		_close_view(WORLD_SCAN_VIEW_NAME, true)
		_close_view(WORLD_SCAN_ICONS_VIEW_NAME, true)
		_sync_scanner_hud_visibility()

		return
	end

	if _world_scan_effective_active() then
		_set_world_scan_highlights(true)
	end

	_sync_scanner_hud_visibility()
end

local function _practice_scanner_item()
	if practice_scanner_item and practice_scanner_item_name then
		return practice_scanner_item, practice_scanner_item_name
	end

	local t = _gameplay_time()

	if practice_scanner_item_lookup_complete and t < practice_scanner_item_retry_at then
		return nil, nil
	end

	for index = 1, #PRACTICE_ITEM_IDS do
		local item_name = PRACTICE_ITEM_IDS[index]
		local item = MasterItems.get_item(item_name)

		if item then
			practice_scanner_item = item
			practice_scanner_item_name = item_name
			practice_scanner_item_lookup_complete = true

			return item, item_name
		end
	end

	practice_scanner_item_lookup_complete = true
	practice_scanner_item_retry_at = t + 5

	return nil, nil
end

_practice_auspex_unit = function(player_unit)
	local visual_loadout_extension = player_unit and ScriptUnit.has_extension(player_unit, "visual_loadout_system")
	local item_unit_1p = visual_loadout_extension and visual_loadout_extension:unit_and_attachments_from_slot(PRACTICE_DEVICE_SLOT)

	return item_unit_1p
end

_is_practice_auspex_ready = function(auspex_unit)
	if not auspex_unit or not Unit.alive(auspex_unit) then
		return false
	end

	if not ScriptUnit.has_extension(auspex_unit, "scanner_display_system") then
		return false
	end

	local ok, plane_mesh = pcall(Unit.mesh, auspex_unit, "auspex_scanner_display")

	return ok and plane_mesh ~= nil
end

_practice_interface_unit = function(player_unit)
	local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
	local minigame_character_state = unit_data_extension and unit_data_extension:read_component("minigame_character_state")

	if not minigame_character_state then
		return nil
	end

	local is_level_unit = minigame_character_state.interface_is_level_unit
	local unit_id = is_level_unit and minigame_character_state.interface_level_unit_id or minigame_character_state.interface_game_object_id
	local has_interface = unit_id ~= nil and unit_id ~= NetworkConstants.invalid_level_unit_id and unit_id ~= NetworkConstants.invalid_game_object_id

	if not has_interface then
		return nil
	end

	local unit_spawner = Managers.state and Managers.state.unit_spawner

	return unit_spawner and unit_spawner:unit(unit_id, is_level_unit) or nil
end

_is_practice_interface_ready = function(interface_unit)
	return interface_unit ~= nil and Unit.alive(interface_unit) and ScriptUnit.has_extension(interface_unit, "minigame_system") ~= nil
end

mod._expedition_scanner_slot_snapshot = function(inventory_component)
	if not inventory_component then
		return nil
	end

	local snapshot = {}
	local slot_names = {
		"slot_device",
		"slot_pocketable_small",
	}

	for index = 1, #slot_names do
		local slot_name = slot_names[index]
		local item_name = inventory_component[slot_name]

		if item_name and item_name ~= "not_equipped" then
			snapshot[#snapshot + 1] = {
				slot_name = slot_name,
				item_name = item_name,
			}
		end
	end

	return #snapshot > 0 and snapshot or nil
end

mod._expedition_scanner_slot_snapshot_debug = function(snapshot)
	if type(snapshot) ~= "table" or #snapshot == 0 then
		return "none"
	end

	local parts = {}

	for index = 1, #snapshot do
		local entry = snapshot[index]
		parts[#parts + 1] = string.format("%s=%s", tostring(entry and entry.slot_name or "nil"), tostring(entry and entry.item_name or "nil"))
	end

	return table.concat(parts, ",")
end

_set_practice_item_focus_active = function(session, active)
	if not session or not session.player_unit then
		return false
	end

	local player_unit = session.player_unit
	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local character_state_machine_extension = ScriptUnit.has_extension(player_unit, "character_state_machine_system")
	local animation_extension = ScriptUnit.has_extension(player_unit, "animation_system")

	if not unit_data_extension then
		return false
	end

	local minigame_character_state = unit_data_extension:write_component("minigame_character_state")
	local active_value = active == true

	minigame_character_state.pocketable_device_active = active_value

	if animation_extension and session.item_focus_active ~= active_value then
		animation_extension:anim_event_1p(active_value and "auspex_start_focus" or "auspex_stop_focus")
	end

	session.item_focus_active = active_value

	if active_value then
		session.item_focus_requested_at = _gameplay_time()
	else
		if character_state_machine_extension and character_state_machine_extension:current_state_name() == "minigame" then
			local current_state = character_state_machine_extension:current_state()

			if current_state and current_state.force_cancel then
				current_state:force_cancel()
			end
		end

		session.item_minigame_bound = false
	end

	return true
end

_open_preview_session_view = function(session)
	local ui_manager = Managers.ui

	if not ui_manager or not session or not session.view_name or not session.context then
		return false
	end

	if ui_manager:view_active(session.view_name) or ui_manager:is_view_closing(session.view_name) then
		return false
	end

	ui_manager:open_view(session.view_name, nil, false, false, nil, session.context, {
		use_transition_ui = false,
	})

	session.opened_at = session.opened_at or _gameplay_time()

	if session.view_name == PREVIEW_VIEW_NAME or session.view_name == OVERLAY_VIEW_NAME then
		_refresh_scanner_overlay_state()
	end

	return true
end

_overlay_preview_view_is_active = function(session)
	local ui_manager = Managers.ui

	if not ui_manager or not session or session.item_mode or session.pending_item_mode or not session.view_name then
		return false
	end

	return ui_manager:view_active(session.view_name) and not ui_manager:is_view_closing(session.view_name)
end

_close_world_scan_views = function()
	_suppress_world_scan_views(0.35)
	_close_view(WORLD_SCAN_VIEW_NAME, true)
	_close_view(WORLD_SCAN_ICONS_VIEW_NAME, true)
	_refresh_scanner_overlay_state()
end

_start_preview_minigame = function(session, player)
	local minigame = session and session.minigame

	if not minigame or session.minigame_started then
		return false
	end

	if minigame.setup_game then
		minigame:setup_game()
	end

	if minigame.start then
		minigame:start(player or _local_player())
	end

	session.minigame_started = true
	session.minigame_started_at = _gameplay_time()
	session.practice_completion_notified = false

	return true
end

_open_overlay_preview_session = function(session, show_item_warning)
	if not session or not session.context then
		return false
	end

	session.auspex_unit = nil
	session.item_mode = false
	session.pending_item_mode = false
	session.player_unit = nil
	session.view_name = PREVIEW_VIEW_NAME
	session.context.auspex_unit = nil
	session.context.device_owner_unit = _local_player_unit()
	session.next_view_open_retry_at = 0
	session.overlay_view_ready = false
	session.overlay_missing_since = nil
	session.allow_missing_gameplay_timer = not _has_gameplay_timer()
	mod._preview_allow_missing_gameplay_timer = session.allow_missing_gameplay_timer == true
	practice_session = session
	mod._debug_event("practice_open", string.format("mode=overlay type=%s warning=%s missing_gameplay_timer=%s", tostring(session.minigame_type or "unknown"), tostring(show_item_warning == true), tostring(session.allow_missing_gameplay_timer == true)))
	_close_world_scan_views()
	mod._expedition_map_focus_latched = false
	mod._forced_expedition_map_overlay_active = nil
	_set_scanner_searching_state(false)
	_close_view(STOCK_SCANNER_VIEW_NAME, true)
	_close_view(OVERLAY_VIEW_NAME, true)
	_close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)

	local opened = _open_preview_session_view(session)

	if show_item_warning then
		mod:notify(mod:localize("practice_item_unavailable"))
	end

	return opened
end

_try_open_pending_item_preview = function(session)
	if not session or not session.pending_item_mode or not session.player_unit or not session.context then
		return false
	end

	if session.pending_item_ready_at and _gameplay_time() < session.pending_item_ready_at then
		return false
	end

	local auspex_unit = _practice_auspex_unit(session.player_unit)
	local interface_unit = _practice_interface_unit(session.player_unit)

	if not _is_practice_auspex_ready(auspex_unit) or not _is_practice_interface_ready(interface_unit) then
		return false
	end

	session.auspex_unit = auspex_unit
	session.interface_unit = interface_unit
	session.pending_item_mode = false
	session.context.auspex_unit = auspex_unit
	session.context.device_owner_unit = session.player_unit
	session.context.interface_unit = interface_unit
	mod._debug_event("practice_item", string.format("ready type=%s", tostring(session.minigame_type or "unknown")))

	return _set_practice_item_focus_active(session, true)
end

_equip_practice_scanner = function()
	local player_unit = _local_player_unit()
	local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
	local visual_loadout_extension = player_unit and ScriptUnit.has_extension(player_unit, "visual_loadout_system")

	if not player_unit or not unit_data_extension or not visual_loadout_extension then
		return nil
	end

	local scanner_item, scanner_item_name = _practice_scanner_item()

	if not scanner_item or not scanner_item_name then
		return nil
	end

	local inventory_component = unit_data_extension:read_component("inventory")
	local current_device_item_name = inventory_component[PRACTICE_DEVICE_SLOT]
	local current_wielded_slot = inventory_component.wielded_slot
	local t = _gameplay_time()
	local equipped_practice_device = current_device_item_name ~= scanner_item_name

	if equipped_practice_device then
		if PlayerUnitVisualLoadout.slot_equipped(inventory_component, visual_loadout_extension, PRACTICE_DEVICE_SLOT) then
			PlayerUnitVisualLoadout.unequip_item_from_slot(player_unit, PRACTICE_DEVICE_SLOT, t)
		end

		PlayerUnitVisualLoadout.equip_item_to_slot(player_unit, scanner_item, PRACTICE_DEVICE_SLOT, nil, t)
	end

	if current_wielded_slot ~= PRACTICE_DEVICE_SLOT then
		PlayerUnitVisualLoadout.wield_slot(PRACTICE_DEVICE_SLOT, player_unit, t)
	end

	return {
		equipped_practice_device = equipped_practice_device,
		player_unit = player_unit,
		previous_device_item_name = current_device_item_name,
		previous_wielded_slot = current_wielded_slot,
	}
end

_try_equip_practice_scanner = function()
	local ok, result_or_error = xpcall(_equip_practice_scanner, debug.traceback)

	if ok then
		return result_or_error, nil
	end

	return nil, result_or_error
end

_restore_practice_scanner = function(session)
	if not session or not session.player_unit then
		return
	end

	local player_unit = session.player_unit
	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system")

	if not unit_data_extension or not visual_loadout_extension then
		return
	end

	local inventory_component = unit_data_extension:read_component("inventory")
	local t = _gameplay_time()

	if session.equipped_practice_device then
		local previous_item_name = session.previous_device_item_name

		if previous_item_name and previous_item_name ~= "not_equipped" then
			local previous_item = MasterItems.get_item(previous_item_name)

			if previous_item then
				PlayerUnitVisualLoadout.equip_item_to_slot(player_unit, previous_item, PRACTICE_DEVICE_SLOT, nil, t)
			else
				PlayerUnitVisualLoadout.unequip_item_from_slot(player_unit, PRACTICE_DEVICE_SLOT, t)
			end
		else
			PlayerUnitVisualLoadout.unequip_item_from_slot(player_unit, PRACTICE_DEVICE_SLOT, t)
		end
	end

	local previous_wielded_slot = session.previous_wielded_slot

	if previous_wielded_slot and previous_wielded_slot ~= "none" and inventory_component.wielded_slot ~= previous_wielded_slot and visual_loadout_extension:can_wield(previous_wielded_slot) then
		PlayerUnitVisualLoadout.wield_slot(previous_wielded_slot, player_unit, t)
	end
end

_practice_item_mode_supported_here = function()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or nil

	return game_mode_name ~= nil
		and game_mode_name ~= "hub"
		and game_mode_name ~= "prologue_hub"
		and not _is_networked_live_session()
end

_live_item_mode_supported_here = function()
	-- The old online block was a temporary safety fallback.
	-- Live item mode is now allowed, while truly unsafe character states
	-- are still handled separately by _abort_live_item_scanner_if_unsafe().
	return true
end

_live_item_state_is_unsafe = function(state_name)
	return state_name == "hogtied" or state_name == "netted" or state_name == "pounced" or state_name == "grabbed" or state_name == "warp_grabbed" or state_name == "mutant_charged" or state_name == "knocked_down" or state_name == "dead" or state_name == "consumed" or state_name == "exploding" or state_name == "ledge_hanging" or state_name == "ledge_hanging_falling" or state_name == "ledge_hanging_pull_up" or state_name == "stunned"
end

_notify_live_item_overlay_fallback = function()
	local t = _gameplay_time()
	local next_allowed_t = mod._live_item_overlay_notify_t or 0

	if t < next_allowed_t then
		return
	end

	mod._live_item_overlay_notify_t = t + 5
	mod._debug_event("live_item_fallback", string.format("overlay fallback type=%s display_mode=%s", tostring(_active_live_minigame_type() or mod._cached_live_minigame_type or "unknown"), tostring(mod._active_live_display_mode())))

	mod:notify(mod:localize("live_item_online_unavailable"))
end

_abort_live_item_scanner_if_unsafe = function()
	if practice_session or mod._active_live_display_mode() ~= "item" then
		return false
	end

	local ui_manager = Managers.ui

	if not ui_manager then
		return false
	end

	local stock_view_active = ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME)

	if not stock_view_active and not scanner_equipped_active and not scanner_searching_active then
		return false
	end

	local player_unit = _local_player_unit()
	local character_state_machine_extension = player_unit and ScriptUnit.has_extension(player_unit, "character_state_machine_system")
	local state_name = character_state_machine_extension and character_state_machine_extension:current_state_name() or nil

	if not _live_item_state_is_unsafe(state_name) then
		return false
	end

	mod._debug_event("live_item_abort", string.format("unsafe state=%s", tostring(state_name or "unknown")))

	_ignore_errors(function()
		_close_view(STOCK_SCANNER_VIEW_NAME, true)
	end)
	_ignore_errors(function()
		_force_cancel_local_minigame_state()
	end)
	_set_scanner_searching_state(false)
	_set_scanner_equipped_state(false)

	return true
end

mod._open_live_minigame_overlay = function(live_minigame, minigame_type)
	if practice_session or not live_minigame or not minigame_type then
		mod._debug_event("live_overlay_open", string.format("skip practice=%s has_minigame=%s type=%s", tostring(practice_session ~= nil), tostring(live_minigame ~= nil), tostring(minigame_type or "nil")))
		return
	end

	local ui_manager = Managers.ui

	if not ui_manager or ui_manager:is_view_closing(OVERLAY_VIEW_NAME) then
		mod._debug_event("live_overlay_open", string.format("skip ui=%s closing=%s type=%s", tostring(ui_manager ~= nil), tostring(ui_manager and ui_manager:is_view_closing(OVERLAY_VIEW_NAME) or false), tostring(minigame_type)))
		return
	end

	local player_unit = _local_player_unit()
	local minigame_extension = nil

	if mod._is_expedition_map_minigame_type(minigame_type) then
		minigame_extension = {
			minigame = function(_, requested_type)
				if requested_type == nil or requested_type == minigame_type then
					return live_minigame
				end

				return nil
			end,
			minigame_type = function()
				return minigame_type
			end,
		}
	else
		local interface_unit = player_unit and _practice_interface_unit and _practice_interface_unit(player_unit) or nil
		minigame_extension = interface_unit and ScriptUnit.has_extension(interface_unit, "minigame_system") or nil

		if not minigame_extension then
			minigame_extension = {
				minigame = function(_, requested_type)
					if requested_type == nil or requested_type == minigame_type then
						return live_minigame
					end

					return nil
				end,
				minigame_type = function()
					return minigame_type
				end,
			}
		end
	end

	mod._cached_live_minigame_type = minigame_type

	local keep_stock_scanner_open = _is_expedition_minigame_type(minigame_type)
		and not mod._is_expedition_map_minigame_type(minigame_type)

	if ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) and not keep_stock_scanner_open then
		ui_manager:close_view(STOCK_SCANNER_VIEW_NAME, true)
	end

	if ui_manager:view_active(OVERLAY_VIEW_NAME) then
		mod._debug_event("live_overlay_open", string.format("skip already_active type=%s", tostring(minigame_type)))
		return
	end

	ui_manager:open_view(OVERLAY_VIEW_NAME, nil, false, false, nil, {
		auspex_unit = nil,
		auspex_helper_is_practice = false,
		device_owner_unit = player_unit,
		minigame_extension = minigame_extension,
		minigame_type = minigame_type,
		wwise_world = nil,
	}, {
		use_transition_ui = false,
	})
	mod._forced_expedition_map_overlay_active = true
	if mod._is_expedition_map_minigame_type(minigame_type) then
		mod._hold_expedition_overlay_open(0.75)
	end
	mod._debug_event("live_overlay_open", string.format("open requested type=%s", tostring(minigame_type)))
	_refresh_scanner_overlay_state()
end

_ensure_live_expedition_map_overlay = function(live_minigame)
	if practice_session then
		mod._debug_event("exp_map_overlay", "skip practice")
		return
	end

	if not scanner_searching_active then
		mod._debug_event("exp_map_overlay", "skip not_searching")
		return
	end

	local ui_manager = Managers.ui
	local stock_view_active = ui_manager and (
		ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)
		or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME)
	) or false

	if stock_view_active then
		mod._debug_event("exp_map_overlay", "skip stock_view_active")
		return
	end

	local player_unit = _local_player_unit()
	local character_state_machine_extension = player_unit and ScriptUnit.has_extension(player_unit, "character_state_machine_system")
	local current_state = character_state_machine_extension
		and character_state_machine_extension:current_state_name() == "minigame"
		and character_state_machine_extension:current_state()
		or nil
	local state_method_minigame = current_state and current_state.minigame and current_state:minigame() or nil
	local state_field_minigame = current_state and current_state._minigame or nil
	local state_method_type = _minigame_type_hint(state_method_minigame)
	local state_field_type = _minigame_type_hint(state_field_minigame)

	if state_field_minigame
		and _looks_like_expedition_minigame(state_field_minigame)
		and not mod._is_expedition_map_minigame_type(state_field_type)
	then
		mod._debug_event("exp_map_overlay", string.format("skip state_field=%s", tostring(state_field_type or "expedition")))
		return
	end

	if state_method_minigame
		and _looks_like_expedition_minigame(state_method_minigame)
		and not mod._is_expedition_map_minigame_type(state_method_type)
	then
		mod._debug_event("exp_map_overlay", string.format("skip state_method=%s", tostring(state_method_type or "expedition")))
		return
	end

	local active_live_minigame = _active_live_minigame and _active_live_minigame() or nil
	local resolved_live_minigame = active_live_minigame or live_minigame
	local live_minigame_type = _minigame_type_hint(resolved_live_minigame)
	local overlay_callout_freeze_active = mod._expedition_overlay_callout_freeze_active and mod._expedition_overlay_callout_freeze_active() or false

	if resolved_live_minigame
		and not mod._is_expedition_map_minigame_type(live_minigame_type)
		and (
			_looks_like_expedition_minigame(resolved_live_minigame)
			or _looks_like_decode_minigame(resolved_live_minigame)
			or _looks_like_drill_minigame(resolved_live_minigame)
			or _looks_like_frequency_minigame(resolved_live_minigame)
			or _looks_like_balance_minigame(resolved_live_minigame)
		)
	then
		mod._debug_event("exp_map_overlay", string.format("skip live_minigame=%s", tostring(live_minigame_type or "active_non_map")))
		return
	end

	local map_minigame = mod._resolve_expedition_map_minigame(false)
		or (overlay_callout_freeze_active and rawget(mod, "_cached_expedition_map_minigame") or nil)
		or resolved_live_minigame
	local minigame_type = _minigame_type_hint(map_minigame) or mod._cached_live_minigame_type

	if not mod._is_expedition_map_minigame_type(minigame_type) then
		mod._debug_event("exp_map_overlay", string.format("skip wrong_type=%s", tostring(minigame_type or "nil")))
		return
	end

	if _minigame_display_mode(minigame_type) ~= "overlay" or not _is_minigame_enabled(minigame_type) then
		mod._debug_event("exp_map_overlay", string.format("skip display_mode=%s enabled=%s", tostring(_minigame_display_mode(minigame_type)), tostring(_is_minigame_enabled(minigame_type))))
		return
	end

	mod._debug_event("exp_map_overlay", "open attempt")
	mod._hold_expedition_overlay_open(0.75)
	mod._open_live_minigame_overlay(map_minigame, minigame_type)
end

_ensure_live_item_mode_overlay_fallback = function(live_minigame, t)
	if practice_session or not live_minigame then
		mod._live_item_overlay_fallback_started_t = nil
		mod._live_item_overlay_fallback_minigame = nil
		return
	end

	local minigame_type = _minigame_type_hint(live_minigame) or mod._cached_live_minigame_type

	if not mod._is_expedition_map_minigame_type(minigame_type)
		or _minigame_display_mode(minigame_type) ~= "item"
		or not _is_minigame_enabled(minigame_type) then
		mod._live_item_overlay_fallback_started_t = nil
		mod._live_item_overlay_fallback_minigame = nil
		return
	end

	local ui_manager = Managers.ui
	local stock_view_active = ui_manager and ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)

	if stock_view_active then
		mod._live_item_overlay_fallback_started_t = nil
		mod._live_item_overlay_fallback_minigame = nil
		return
	end

	if mod._live_item_overlay_fallback_minigame ~= live_minigame then
		mod._live_item_overlay_fallback_minigame = live_minigame
		mod._live_item_overlay_fallback_started_t = t
		return
	end

	if t < (mod._live_item_overlay_fallback_started_t or t) + 0.2 then
		return
	end

	mod._live_item_overlay_fallback_started_t = nil
	mod._live_item_overlay_fallback_minigame = nil
	_notify_live_item_overlay_fallback()

	if ui_manager and ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME) then
		ui_manager:close_view(STOCK_SCANNER_VIEW_NAME, true)
	end

	mod._open_live_minigame_overlay(live_minigame, minigame_type)
end

function _cleanup_preview_session()
	if not practice_session then
		mod._preview_allow_missing_gameplay_timer = false
		_set_preview_input_simulation(false)

		return
	end

	local session = practice_session

	mod._preview_allow_missing_gameplay_timer = false
	_set_preview_input_simulation(false)
	mod._notify_practice_completion(session)

	if session.item_mode then
		_ignore_errors(function()
			_set_practice_item_focus_active(session, false)
		end)

		_ignore_errors(function()
			_restore_practice_scanner(session)
		end)
	end

	practice_session = nil
end

function _abort_preview_session()
	local ui_manager = Managers.ui

	_clear_preview_close_request()
	preview_reopen_requested = false

	if practice_session and practice_session.item_mode then
		_ignore_errors(function()
			_set_practice_item_focus_active(practice_session, false)
		end)
	end

	if ui_manager then
		if ui_manager:view_active(PREVIEW_VIEW_NAME) or ui_manager:is_view_closing(PREVIEW_VIEW_NAME) then
			ui_manager:close_view(PREVIEW_VIEW_NAME, true)
		end

		if ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME) then
			ui_manager:close_view(STOCK_SCANNER_VIEW_NAME, true)
		end
	end

	_cleanup_preview_session()
end

function _open_preview_view()
	local ui_manager = Managers.ui

	if not ui_manager then
		return
	end

	local view_name = _practice_view_name()

	if ui_manager:view_active(view_name) or ui_manager:is_view_closing(view_name) then
		return
	end

	local minigame_type = mod:get("preview_type") or MinigameSettings.types.decode_symbols

	if not _is_minigame_enabled(minigame_type) then
		mod:notify(mod:localize("preview_type_disabled"))

		return
	end

	local context, minigame_extension = _build_preview_context(minigame_type)

	if not context or not minigame_extension then
		mod:notify(mod:localize("preview_unavailable"))

		return
	end

	local session = {
		context = context,
		item_mode = false,
		minigame = minigame_extension:minigame(),
		minigame_started = false,
		minigame_extension = minigame_extension,
		minigame_type = minigame_type,
		opened_at = _gameplay_time(),
		previous_action_one_hold = false,
		previous_interact_hold = false,
		previous_jump_held = false,
		previous_primary_input = false,
		primary_hold = false,
		view_name = PREVIEW_VIEW_NAME,
	}

	if _minigame_display_mode() == "item" then
		if not _practice_item_mode_supported_here() then
			mod:notify(mod:localize(_is_networked_live_session() and "live_item_online_unavailable" or "practice_item_hub_unavailable"))
			_open_overlay_preview_session(session)

			return
		end

		local device_session = nil

		device_session = _try_equip_practice_scanner()

		if device_session then
			context.device_owner_unit = device_session.player_unit
			session.equipped_practice_device = device_session.equipped_practice_device
			session.item_mode = true
			session.item_minigame_bound = false
			session.pending_item_mode = true
			session.pending_item_ready_at = _gameplay_time() + 0.1
			session.player_unit = device_session.player_unit
			session.previous_device_item_name = device_session.previous_device_item_name
			session.previous_wielded_slot = device_session.previous_wielded_slot
			session.view_name = STOCK_SCANNER_VIEW_NAME
			practice_session = session
			_try_open_pending_item_preview(session)
			session.opened_at = _gameplay_time()
		else
			_open_overlay_preview_session(session, true)
		end
	else
		_open_overlay_preview_session(session, _minigame_display_mode() == "item")
	end
end

mod:register_view({
	view_name = PREVIEW_VIEW_NAME,
	view_settings = {
		allow_hud = true,
		class = "AuspexOverlayView",
		close_on_hotkey_pressed = false,
		disable_game_world = false,
		init_view_function = function()
			return true
		end,
		load_always = true,
		load_in_hub = true,
		package = "packages/ui/views/scanner_display_view/scanner_display_view",
		path = OVERLAY_VIEW_PATH,
		state_bound = false,
		use_transition_ui = false,
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod:register_view({
	view_name = OVERLAY_VIEW_NAME,
	view_settings = {
		allow_hud = true,
		class = "AuspexOverlayView",
		close_on_hotkey_pressed = false,
		disable_game_world = false,
		init_view_function = function()
			return true
		end,
		load_always = true,
		load_in_hub = false,
		package = "packages/ui/views/scanner_display_view/scanner_display_view",
		path = OVERLAY_VIEW_PATH,
		state_bound = false,
		use_transition_ui = false,
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod:register_view({
	view_name = EXPEDITION_MINIMAP_VIEW_NAME,
	view_settings = {
		allow_hud = true,
		class = "AuspexOverlayView",
		close_on_hotkey_pressed = false,
		disable_game_world = false,
		init_view_function = function()
			return true
		end,
		load_always = true,
		load_in_hub = false,
		package = "packages/ui/views/scanner_display_view/scanner_display_view",
		path = OVERLAY_VIEW_PATH,
		state_bound = false,
		use_transition_ui = false,
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod:register_view({
	view_name = WORLD_SCAN_VIEW_NAME,
	view_settings = {
		allow_hud = true,
		class = "AuspexOverlayView",
		close_on_hotkey_pressed = false,
		disable_game_world = false,
		init_view_function = function()
			return true
		end,
		load_always = true,
		load_in_hub = false,
		package = "packages/ui/views/scanner_display_view/scanner_display_view",
		path = OVERLAY_VIEW_PATH,
		state_bound = false,
		use_transition_ui = false,
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod:register_view({
	view_name = WORLD_SCAN_ICONS_VIEW_NAME,
	view_settings = {
		allow_hud = true,
		class = "AuspexOverlayView",
		close_on_hotkey_pressed = false,
		disable_game_world = false,
		init_view_function = function()
			return true
		end,
		load_always = true,
		load_in_hub = false,
		package = "packages/ui/views/scanner_display_view/scanner_display_view",
		path = OVERLAY_VIEW_PATH,
		state_bound = false,
		use_transition_ui = false,
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod:hook_require("scripts/managers/ui/ui_view_handler", function(UIViewHandler)
	mod:hook(UIViewHandler, "allow_to_pass_input_for_view", function(func, self, view_name)
		if _is_auspex_helper_pass_through_view(view_name) or _is_auspex_helper_overlay_pass_through_view(self, view_name) then
			return true
		end

		return func(self, view_name)
	end)

	mod:hook(UIViewHandler, "allow_close_hotkey_for_view", function(func, self, view_name)
		if _is_auspex_helper_pass_through_view(view_name) or _is_auspex_helper_overlay_pass_through_view(self, view_name) then
			return false
		end

		return func(self, view_name)
	end)
end)

mod:hook_require("scripts/managers/ui/ui_manager", function(UIManager)
	local UIViews = require("scripts/ui/views/views")

	mod:hook(UIManager, "has_active_view", function(func, self)
		local view_handler = self and self._view_handler
		local active_views = view_handler and view_handler:active_views() or nil

		if not active_views or #active_views == 0 then
			return false
		end

		for index = 1, #active_views do
			local view_name = active_views[index]

			if view_name and not _is_auspex_helper_pass_through_view(view_name) and not _is_auspex_helper_overlay_pass_through_view(view_handler, view_name) then
				return true
			end
		end

		return false
	end)

	mod:hook(UIManager, "_update_view_hotkeys", function(func, self)
		if self._ui_constant_elements:using_input() then
			return
		end

		local view_handler = self._view_handler

		if view_handler:transitioning() then
			return
		end

		local views = view_handler:active_views()
		local filtered_views = {}

		for i = 1, #views do
			local view_name = views[i]

			if view_name and not _is_auspex_helper_pass_through_view(view_name) and not _is_auspex_helper_overlay_pass_through_view(view_handler, view_name) then
				filtered_views[#filtered_views + 1] = view_name
			end
		end

		if #filtered_views == #views then
			return func(self)
		end

		local input_service = self:input_service()
		local hotkey_settings = self._update_hotkeys
		local hotkeys = hotkey_settings.hotkeys
		local hotkey_lookup = hotkey_settings.lookup
		local gamepad_active = InputDevice.gamepad_active
		local num_views = #filtered_views

		if num_views > 0 then
			for i = num_views, 1, -1 do
				local active_view_name = filtered_views[i]

				if active_view_name then
					local settings = UIViews[active_view_name]

					if not settings then
						return func(self)
					end

					local hotkey = hotkey_lookup[active_view_name]
					local close_on_hotkey = settings.close_on_hotkey_pressed
					local close_on_gamepad = settings.close_on_hotkey_gamepad
					local can_close_with_hotkey = close_on_hotkey and (not gamepad_active or close_on_gamepad)
					local close_by_hotkey = hotkey and can_close_with_hotkey and input_service:get(hotkey)
					local close_action = self._close_view_input_action
					local close_by_action = view_handler:allow_close_hotkey_for_view(active_view_name) and input_service:get(close_action)
					local should_close_view = close_by_hotkey or close_by_action
					local can_close_view = view_handler:can_close(active_view_name)

					if should_close_view and can_close_view then
						self:close_view(active_view_name)

						return
					end

					local allow_to_pass_input = view_handler:allow_to_pass_input_for_view(active_view_name)

					if not allow_to_pass_input then
						return
					end
				end
			end
		else
			for hotkey, view_name in pairs(hotkeys) do
				if input_service:get(hotkey) then
					self:open_view(view_name)

					return
				end
			end
		end
	end)
end)

mod:add_require_path(OVERLAY_VIEW_PATH)
mod:io_dofile(OVERLAY_VIEW_PATH)

mod:hook_require("scripts/extension_systems/minigame/minigames/minigame_base", function(MinigameBase)
	mod:hook(MinigameBase, "_setup_sound", function(func, self, player, fx_source_name)
		local player_unit = player and player.player_unit

		if not player_unit or not Unit.alive(player_unit) then
			return
		end

		local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
		local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")

		self._fx_extension = ScriptUnit.has_extension(player_unit, "fx_system")
		self._fx_source_name = nil

		if not visual_loadout_extension or not unit_data_extension then
			return
		end

		local inventory_component = unit_data_extension:read_component("inventory")
		local tried_slots = {}
		local slot_order = {
			inventory_component and inventory_component.wielded_slot,
			"slot_device",
			"slot_pocketable_small",
			"slot_primary",
			"slot_secondary",
		}

		for index = 1, #slot_order do
			local slot_name = slot_order[index]

			if slot_name and not tried_slots[slot_name] then
				tried_slots[slot_name] = true

				local fx_sources = visual_loadout_extension:source_fx_for_slot(slot_name)

				if type(fx_sources) == "table" then
					self._fx_source_name = fx_sources[fx_source_name]

					if not self._fx_source_name then
						for _, candidate_source_name in pairs(fx_sources) do
							self._fx_source_name = candidate_source_name

							break
						end
					end

					if self._fx_source_name then
						return
					end
				end
			end
		end
	end)
end)

mod:hook_require("scripts/extension_systems/character_state_machine/character_states/player_character_state_minigame", function(PlayerCharacterStateMinigame)
	if mod._player_character_state_minigame_lifecycle_hook_applied then
		return
	end

	mod._player_character_state_minigame_lifecycle_hook_applied = true

	mod:hook(PlayerCharacterStateMinigame, "on_exit", function(func, self, unit, t, next_state)
		local minigame_character_state = self and self._minigame_character_state_component
		local interface_synced = minigame_character_state and (minigame_character_state.interface_level_unit_id ~= NetworkConstants.invalid_level_unit_id or minigame_character_state.interface_game_object_id ~= NetworkConstants.invalid_game_object_id) or false
		local game_mode_manager = Managers.state and Managers.state.game_mode
		local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or nil
		local unit_data_extension = self and self._unit and ScriptUnit.has_extension(self._unit, "unit_data_system") or nil
		local inventory_component = self and self._inventory_component or (unit_data_extension and unit_data_extension:read_component("inventory")) or nil
		local player_unit = self and self._unit or nil
		local exiting_minigame = mod._unwrap_nested_minigame((self and self._minigame) or (self and self.minigame and self:minigame()) or nil)
		local cached_live_minigame = rawget(mod, "_cached_live_minigame")
		local exiting_is_decode = _looks_like_decode_style_minigame(exiting_minigame)
			or _looks_like_decode_minigame(exiting_minigame)
			or (rawget(mod, "_cached_live_minigame_type") == MinigameSettings.types.decode_symbols and (_looks_like_decode_style_minigame(cached_live_minigame) or _looks_like_decode_minigame(cached_live_minigame)))
		local scanner_snapshot = mod._expedition_scanner_slot_snapshot and mod._expedition_scanner_slot_snapshot(inventory_component) or rawget(self, "_auspex_helper_expedition_scanner_snapshot")
		local snapshot_debug = mod._expedition_scanner_slot_snapshot_debug and mod._expedition_scanner_slot_snapshot_debug(scanner_snapshot) or "none"
		local pre_exit_wielded_slot = inventory_component and inventory_component.wielded_slot or "nil"

		local results = table.pack(func(self, unit, t, next_state))
		local post_exit_snapshot = mod._expedition_scanner_slot_snapshot and mod._expedition_scanner_slot_snapshot(inventory_component) or nil
		local post_exit_wielded_slot = inventory_component and inventory_component.wielded_slot or "nil"

		if game_mode_name == "expedition"
			and player_unit
			and inventory_component
		then
			mod._debug_event("exp_scanner_slots", string.format("exit next=%s wielded_before=%s wielded_after=%s before=%s after=%s", tostring(next_state or "nil"), tostring(pre_exit_wielded_slot), tostring(post_exit_wielded_slot), tostring(snapshot_debug), tostring(mod._expedition_scanner_slot_snapshot_debug(post_exit_snapshot))))

			if exiting_is_decode then
				mod._debug_event("exp_scanner_slots", "skip restore decode_exit")
			elseif scanner_snapshot then
				mod._pending_expedition_scanner_restore = {
					attempts = 0,
					desired_wielded_slot = post_exit_wielded_slot ~= "slot_device" and post_exit_wielded_slot ~= "slot_pocketable_small" and post_exit_wielded_slot or nil,
					player_unit = player_unit,
					requested_at = t or _gameplay_time(),
					stable_attempts = 0,
					slots = scanner_snapshot,
				}
			end
		end

		self._auspex_helper_expedition_scanner_snapshot = nil
		mod._debug_event("minigame_state", string.format("exit pocketable=%s iface=%s unit=%s", tostring(minigame_character_state and minigame_character_state.pocketable_device_active == true or false), tostring(interface_synced), tostring(self and self._unit ~= nil)))

		return (table.unpack or unpack)(results, 1, results.n)
	end)

	mod:hook_safe(PlayerCharacterStateMinigame, "on_enter", function(self)
		local minigame_character_state = self._minigame_character_state_component
		local interface_synced = minigame_character_state and (minigame_character_state.interface_level_unit_id ~= NetworkConstants.invalid_level_unit_id or minigame_character_state.interface_game_object_id ~= NetworkConstants.invalid_game_object_id) or false
		local game_mode_manager = Managers.state and Managers.state.game_mode
		local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or nil
		local minigame = mod._unwrap_nested_minigame((self and self._minigame) or (self and self.minigame and self:minigame()) or nil)
		local minigame_type = _minigame_type_hint(minigame)
		local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()
		local unit_data_extension = self and self._unit and ScriptUnit.has_extension(self._unit, "unit_data_system") or nil
		local inventory_component = self and self._inventory_component or (unit_data_extension and unit_data_extension:read_component("inventory")) or nil

		self._auspex_helper_expedition_scanner_snapshot = nil

		if _looks_like_expedition_minigame(minigame) then
			mod._cached_expedition_live_minigame = minigame
		elseif _looks_like_decode_minigame(minigame) then
			mod._cached_live_minigame = minigame
			mod._cached_live_minigame_type = MinigameSettings.types.decode_symbols
		end

		if _looks_like_expedition_minigame(minigame) or _looks_like_decode_style_minigame(minigame) or _looks_like_decode_minigame(minigame) then
			mod._pending_expedition_scanner_restore = nil
		end

		if game_mode_name == "expedition" and inventory_component then
			self._auspex_helper_expedition_scanner_snapshot = mod._expedition_scanner_slot_snapshot(inventory_component)
			mod._debug_event("exp_scanner_slots", string.format("enter state=%s wielded=%s slots=%s", tostring(minigame_type or "nil"), tostring(inventory_component.wielded_slot or "nil"), tostring(mod._expedition_scanner_slot_snapshot_debug(self._auspex_helper_expedition_scanner_snapshot))))
		end

		if mod._debug_enabled("exp_autosolve") then
			mod._debug_event("exp_autosolve", string.format(
				"state_enter field_type=%s field_exp=%s method_type=%s method_exp=%s direct_type=%s direct_exp=%s",
				tostring(_minigame_type_hint(state_field_minigame) or "nil"),
				tostring(_looks_like_expedition_minigame(state_field_minigame)),
				tostring(_minigame_type_hint(state_method_minigame) or "nil"),
				tostring(_looks_like_expedition_minigame(state_method_minigame)),
				tostring(minigame_type or "nil"),
				tostring(_looks_like_expedition_minigame(minigame))
			))
		end

		mod._debug_event("minigame_state", string.format("enter pocketable=%s iface=%s unit=%s", tostring(minigame_character_state and minigame_character_state.pocketable_device_active == true or false), tostring(interface_synced), tostring(self and self._unit ~= nil)))
	end)
	mod:hook(PlayerCharacterStateMinigame, "_check_initialize_minigame_from_unit", function(func, self)
		local session = practice_session

		if not session or not session.item_mode or not session.minigame or self._unit ~= session.player_unit then
			local minigame_character_state = self._minigame_character_state_component
			local is_unit_synced = minigame_character_state and (minigame_character_state.interface_level_unit_id ~= NetworkConstants.invalid_level_unit_id or minigame_character_state.interface_game_object_id ~= NetworkConstants.invalid_game_object_id)
			local game_mode_manager = Managers.state and Managers.state.game_mode
			local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or nil

			if game_mode_name ~= "expedition" and is_unit_synced and minigame_character_state and not minigame_character_state.pocketable_device_active then
				local inventory_component = self._inventory_component
				local wielded_slot = inventory_component and inventory_component.wielded_slot

				if wielded_slot == "slot_device" or wielded_slot == "slot_pocketable_small" then
					local visual_loadout_extension = self._visual_loadout_extension
					local weapon_template = visual_loadout_extension and visual_loadout_extension:weapon_template_from_slot(wielded_slot)

					if weapon_template and weapon_template.require_minigame and not weapon_template.not_player_wieldable then
						minigame_character_state.pocketable_device_active = true
					end
				end
			end

			return func(self)
		end

		local interface_unit = _practice_interface_unit(session.player_unit)

		if not _is_practice_interface_ready(interface_unit) then
			return false
		end

		session.interface_unit = interface_unit
		self._minigame = session.minigame
		session.item_minigame_bound = true

		_start_preview_minigame(session, self._player)

		return true
	end)
end)

mod:hook_require("scripts/extension_systems/scanner_display/scanner_display_extension", function(ScannerDisplayExtension)
	mod:hook(ScannerDisplayExtension, "_open_view", function(func, self, ui_manager, device_owner_unit, interface_unit)
		local session = practice_session

		if session and session.item_mode and session.context then
			local view_name = self._view_name
			local view_context = session.context

			view_context.auspex_unit = self._unit
			view_context.device_owner_unit = device_owner_unit or session.player_unit
			view_context.interface_unit = interface_unit or session.interface_unit
			session.auspex_unit = self._unit
			session.item_view_opened = true
			session.opened_at = _gameplay_time()

			if not ui_manager:view_active(view_name) and not ui_manager:is_view_closing(view_name) then
				ui_manager:open_view(view_name, nil, nil, nil, nil, view_context)
			end

			return
		end

		local minigame_extension = interface_unit and ScriptUnit.has_extension(interface_unit, "minigame_system") or nil
		local overlay_minigame_extension = minigame_extension
		local explicit_decode_minigame = _tag_minigame_type(
			_try_minigame_extension_minigame(minigame_extension, MinigameSettings.types.decode_symbols),
			MinigameSettings.types.decode_symbols
		)
		local explicit_expedition_minigame = _tag_minigame_type(
			_try_minigame_extension_minigame(minigame_extension, EXPEDITION_MINIGAME_TYPE)
				or _try_minigame_extension_minigame(minigame_extension, LEGACY_EXPEDITION_MINIGAME_TYPE),
			EXPEDITION_MINIGAME_TYPE
		)
		local current_live_minigame = explicit_expedition_minigame or explicit_decode_minigame or _try_minigame_extension_minigame(minigame_extension)
		local explicit_expedition_map_minigame = _try_minigame_extension_minigame(minigame_extension, EXPEDITION_MAP_MINIGAME_TYPE)
		local live_minigame = current_live_minigame or explicit_expedition_map_minigame
		local minigame_type = minigame_extension and minigame_extension:minigame_type() or nil
		local unresolved_minigame_type = minigame_type == nil or minigame_type == MinigameSettings.types.none
		local state_live_minigame = _active_live_minigame and _active_live_minigame() or nil
		local state_live_minigame_type = _minigame_type_hint(state_live_minigame)

		if state_live_minigame and (
			(_is_expedition_minigame_type(state_live_minigame_type) and _looks_like_expedition_minigame(state_live_minigame))
			or ((state_live_minigame_type == nil or state_live_minigame_type == MinigameSettings.types.decode_symbols) and _looks_like_decode_minigame(state_live_minigame))
		) then
			current_live_minigame = state_live_minigame
			live_minigame = state_live_minigame
			minigame_type = state_live_minigame_type or (_looks_like_decode_minigame(state_live_minigame) and MinigameSettings.types.decode_symbols or nil)
			unresolved_minigame_type = false

			if minigame_type then
				_tag_minigame_type(state_live_minigame, minigame_type)
			end
		end

		if live_minigame then
			minigame_type = minigame_type or _minigame_type_hint(live_minigame)
			_tag_minigame_type(live_minigame, minigame_type)

			if mod._is_expedition_map_minigame_type(minigame_type) then
				mod._cache_expedition_map_minigame(live_minigame)
			end
		end

		if current_live_minigame then
			local current_live_minigame_type = _minigame_type_hint(current_live_minigame)
				or minigame_type
				or (_looks_like_decode_minigame(current_live_minigame) and MinigameSettings.types.decode_symbols or nil)

			if current_live_minigame_type then
				_tag_minigame_type(current_live_minigame, current_live_minigame_type)
			end

			if _is_expedition_minigame_type(current_live_minigame_type) or current_live_minigame_type == MinigameSettings.types.decode_symbols then
				live_minigame = current_live_minigame
				minigame_type = current_live_minigame_type
				unresolved_minigame_type = false

				if _is_expedition_minigame_type(current_live_minigame_type) then
					mod._cached_expedition_live_minigame = current_live_minigame
				elseif current_live_minigame_type == MinigameSettings.types.decode_symbols then
					mod._cached_live_minigame = current_live_minigame
					mod._cached_live_minigame_type = current_live_minigame_type
				end
			end
		end

		if explicit_expedition_minigame then
			mod._cached_expedition_live_minigame = explicit_expedition_minigame
		elseif explicit_decode_minigame then
			mod._cached_live_minigame = explicit_decode_minigame
			mod._cached_live_minigame_type = MinigameSettings.types.decode_symbols
		end

		if _is_minigame_enabled(EXPEDITION_MAP_MINIGAME_TYPE) and (not live_minigame or unresolved_minigame_type) then
			local expedition_map_minigame = mod._resolve_expedition_map_minigame(false)

			if expedition_map_minigame then
				live_minigame = expedition_map_minigame
				minigame_type = EXPEDITION_MAP_MINIGAME_TYPE
			else
				mod._resolve_expedition_map_minigame(false)
			end
		end

		if live_minigame and minigame_type and minigame_extension and _try_minigame_extension_minigame(minigame_extension, minigame_type) ~= live_minigame then
			overlay_minigame_extension = {
				minigame = function(_, requested_type)
					if requested_type == nil or requested_type == minigame_type then
						return live_minigame
					end

					return nil
				end,
				minigame_type = function()
					return minigame_type
				end,
			}
		end

		if live_minigame and mod._is_expedition_map_minigame_type(minigame_type) then
			local extension_map_minigame = _try_minigame_extension_minigame(minigame_extension, EXPEDITION_MAP_MINIGAME_TYPE)

			if extension_map_minigame ~= live_minigame then
				overlay_minigame_extension = {
					minigame = function(_, requested_type)
						if requested_type == nil or requested_type == EXPEDITION_MAP_MINIGAME_TYPE then
							return live_minigame
						end

						return nil
					end,
					minigame_type = function()
						return EXPEDITION_MAP_MINIGAME_TYPE
					end,
				}
			end
		end

		local game_mode_manager = Managers.state and Managers.state.game_mode
		local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or nil
		local expedition_overlay_mode = _minigame_display_mode(EXPEDITION_MAP_MINIGAME_TYPE) == "overlay"
			and _is_minigame_enabled(EXPEDITION_MAP_MINIGAME_TYPE)
		local expedition_overlay_active = ui_manager:view_active(OVERLAY_VIEW_NAME)
			and mod._forced_expedition_map_overlay_active == true

		if expedition_overlay_mode
			and game_mode_name == "expedition"
			and (
				mod._is_expedition_map_minigame_type(minigame_type)
				or expedition_overlay_active
			)
		then
			local overlay_map_minigame = mod._resolve_expedition_map_minigame(false)
				or mod._cache_expedition_map_minigame(live_minigame)
				or rawget(mod, "_cached_expedition_map_minigame")

			if overlay_map_minigame then
				live_minigame = overlay_map_minigame
				minigame_type = EXPEDITION_MAP_MINIGAME_TYPE
				overlay_minigame_extension = {
					minigame = function(_, requested_type)
						if requested_type == nil or requested_type == EXPEDITION_MAP_MINIGAME_TYPE then
							return overlay_map_minigame
						end

						return nil
					end,
					minigame_type = function()
						return EXPEDITION_MAP_MINIGAME_TYPE
					end,
				}
			elseif expedition_overlay_active then
				-- While the overlay is already active, do not let a transient unresolved
				-- stock scanner open replace it with a blank expedition map screen.
				return
			end
		end

		local use_overlay = _minigame_display_mode(minigame_type) == "overlay"

		if live_minigame then
			mod._cached_live_minigame_type = minigame_type
		end

		if mod._is_expedition_map_minigame_type(minigame_type) or (Managers.state and Managers.state.game_mode and Managers.state.game_mode:game_mode_name() == "expedition") then
			mod._debug_event("scanner_open_view", string.format("type=%s live=%s overlay=%s search=%s equipped=%s forced=%s", tostring(minigame_type or "nil"), tostring(live_minigame ~= nil), tostring(use_overlay), tostring(scanner_searching_active), tostring(scanner_equipped_active), tostring(mod._forced_expedition_map_overlay_active == true)))
		end

		if not use_overlay and interface_unit and minigame_extension and minigame_type and _is_minigame_enabled(minigame_type) and not _live_item_mode_supported_here() then
			use_overlay = true
			_notify_live_item_overlay_fallback()
		end

		if not use_overlay then
			if live_minigame and mod._is_expedition_map_minigame_type(minigame_type) and _is_minigame_enabled(minigame_type) then
				local stock_minigame_extension = overlay_minigame_extension or {
					minigame = function(_, requested_type)
						if requested_type == nil or requested_type == minigame_type then
							return live_minigame
						end

						return nil
					end,
					minigame_type = function()
						return minigame_type
					end,
				}
				local view_name = self._view_name

				if ui_manager:view_active(view_name) then
					ui_manager:close_view(view_name, true)
				end

				if not ui_manager:is_view_closing(view_name) then
					ui_manager:open_view(view_name, nil, false, false, nil, {
						auspex_unit = self._unit,
						auspex_helper_is_practice = false,
						device_owner_unit = device_owner_unit,
						minigame_extension = stock_minigame_extension,
						minigame_type = minigame_type,
						wwise_world = self._wwise_world,
					}, {
						use_transition_ui = false,
					})
				end

				return
			end

			return func(self, ui_manager, device_owner_unit, interface_unit)
		end

		if _is_expedition_minigame_type(minigame_type)
			and not mod._is_expedition_map_minigame_type(minigame_type)
		then
			local results = table.pack(func(self, ui_manager, device_owner_unit, interface_unit))

			if live_minigame and _is_minigame_enabled(minigame_type) then
				mod._pending_live_expedition_match_overlay = {
					minigame = live_minigame,
					minigame_type = minigame_type,
					requested_at = _gameplay_time(),
				}
				mod._debug_event("live_overlay_open", string.format("defer expedition_match type=%s", tostring(minigame_type)))
			end

			return (table.unpack or unpack)(results, 1, results.n)
		end

		if mod._is_expedition_map_minigame_type(minigame_type) then
			if live_minigame and _is_minigame_enabled(minigame_type) then
				mod._open_live_minigame_overlay(live_minigame, minigame_type)
				return
			end

			return func(self, ui_manager, device_owner_unit, interface_unit)
		end

		if not overlay_minigame_extension and live_minigame and minigame_type then
			overlay_minigame_extension = {
				minigame = function(_, requested_type)
					if requested_type == nil or requested_type == minigame_type then
						return live_minigame
					end

					return nil
				end,
				minigame_type = function()
					return minigame_type
				end,
			}
		end

		if not overlay_minigame_extension or not minigame_type or not _is_minigame_enabled(minigame_type) then
			return func(self, ui_manager, device_owner_unit, interface_unit)
		end

		if ui_manager:is_view_closing(OVERLAY_VIEW_NAME) then
			return
		end

		if ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) then
			ui_manager:close_view(STOCK_SCANNER_VIEW_NAME, true)
		end

		if ui_manager:view_active(WORLD_SCAN_VIEW_NAME) then
			ui_manager:close_view(WORLD_SCAN_VIEW_NAME, true)
		end

		if ui_manager:view_active(WORLD_SCAN_ICONS_VIEW_NAME) then
			ui_manager:close_view(WORLD_SCAN_ICONS_VIEW_NAME, true)
		end

		if mod._is_expedition_map_minigame_type(minigame_type)
			and ui_manager:view_active(OVERLAY_VIEW_NAME)
			and mod._forced_expedition_map_overlay_active == true
		then
			-- Expedition map selection movement can retrigger the stock scanner open path.
			-- Do not tear down and rebuild the overlay in that case; keep the existing
			-- overlay alive and let it continue reading the current expedition map state.
			_refresh_scanner_overlay_state()
			return
		end

		if ui_manager:view_active(OVERLAY_VIEW_NAME) then
			ui_manager:close_view(OVERLAY_VIEW_NAME, true)
		end

		ui_manager:open_view(OVERLAY_VIEW_NAME, nil, false, false, nil, {
			auspex_unit = self._unit,
			auspex_helper_is_practice = false,
			device_owner_unit = device_owner_unit,
			minigame_extension = overlay_minigame_extension,
			minigame_type = minigame_type,
			wwise_world = self._wwise_world,
		}, {
			use_transition_ui = false,
		})
		_refresh_scanner_overlay_state()
	end)

	mod:hook_safe(ScannerDisplayExtension, "deactivate", function()
		local keep_expedition_overlay = false
		local ui_manager = Managers.ui

		if mod._forced_expedition_map_overlay_active
			and _minigame_display_mode(EXPEDITION_MAP_MINIGAME_TYPE) == "overlay"
			and _is_minigame_enabled(EXPEDITION_MAP_MINIGAME_TYPE)
		then
			local expedition_map_minigame = mod._resolve_expedition_map_minigame(false)
				or rawget(mod, "_cached_expedition_map_minigame")

			if expedition_map_minigame then
				keep_expedition_overlay = true
			end
		end

		mod._cached_live_minigame = nil
		mod._cached_live_minigame_type = nil
		mod._live_item_overlay_fallback_started_t = nil
		mod._live_item_overlay_fallback_minigame = nil

		if keep_expedition_overlay then
			_refresh_scanner_overlay_state()
			return
		end

		mod._forced_expedition_map_overlay_active = nil

		if ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) then
			ui_manager:close_view(OVERLAY_VIEW_NAME)
		end
	end)
end)

function mod.toggle_preview()
	if not _is_mod_active() or not mod:get("enable_preview") then
		return
	end

	local ui_manager = Managers.ui

	if not ui_manager then
		return
	end

	if ui_manager.chat_using_input and ui_manager:chat_using_input() then
		return
	end

	if practice_session or preview_close_requested_at then
		_abort_preview_session()

		return
	end

	_open_preview_view()
end

mod:command("auspex_preview", "Toggle the AuspexHelper practice scanner.", function()
	mod.toggle_preview()
end)

mod:command("auspex_practice", "Toggle the AuspexHelper practice scanner.", function()
	mod.toggle_preview()
end)

mod:command("auspex_debug_state", "Dump current AuspexHelper expedition/scanner state.", function()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or "unknown"
	local ui_manager = Managers.ui
	local player_unit = _local_player_unit()
	local character_state_machine_extension = player_unit and ScriptUnit.has_extension(player_unit, "character_state_machine_system")
	local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
	local state_name = character_state_machine_extension and character_state_machine_extension:current_state_name() or "nil"
	local minigame_character_state = unit_data_extension and unit_data_extension:read_component("minigame_character_state") or nil
	local interface_synced = minigame_character_state and (minigame_character_state.interface_level_unit_id ~= NetworkConstants.invalid_level_unit_id or minigame_character_state.interface_game_object_id ~= NetworkConstants.invalid_game_object_id) or false

	mod:echo(string.format(
		"[debug][dump] mode=%s state=%s pocketable=%s iface=%s equipped=%s searching=%s overlay=%s stock=%s minimap=%s world=%s world_icons=%s scanner_overlay=%s practice=%s chat=%s forced=%s",
		tostring(game_mode_name),
		tostring(state_name),
		tostring(minigame_character_state and minigame_character_state.pocketable_device_active == true or false),
		tostring(interface_synced),
		tostring(scanner_equipped_active),
		tostring(scanner_searching_active),
		tostring(ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(EXPEDITION_MINIMAP_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(WORLD_SCAN_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(WORLD_SCAN_ICONS_VIEW_NAME) or false),
		tostring(scanner_overlay_active),
		tostring(practice_session ~= nil),
		tostring(ui_manager and ui_manager.chat_using_input and ui_manager:chat_using_input() or false),
		tostring(mod._forced_expedition_map_overlay_active == true)
	))
end)

mod:command("auspex_force_clear", "Force clear stuck scanner/minigame state.", function()
	mod._expedition_map_focus_latched = false
	mod._forced_expedition_map_overlay_active = nil
	_set_scanner_searching_state(false)
	_set_scanner_equipped_state(false)
	_force_cancel_local_minigame_state()
	_close_view(STOCK_SCANNER_VIEW_NAME, true)
	_close_view(OVERLAY_VIEW_NAME, true)
	_close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)
	_close_view(WORLD_SCAN_VIEW_NAME, true)
	_close_view(WORLD_SCAN_ICONS_VIEW_NAME, true)
	mod:echo("[debug][dump] forced scanner/minigame clear")
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "init", function()
	_refresh_scannable_units()

	if _world_scan_effective_active() then
		_set_world_scan_highlights(true)
	end
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "wield", function()
	scanner_world_helper_active = true

	_request_world_scan_refresh(true)
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "unwield", function()
	scanner_world_helper_active = false
	_set_scanner_searching_state(false)

	_request_world_scan_refresh(true)
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "destroy", function()
	scanner_world_helper_active = false
	_set_scanner_searching_state(false)

	_request_world_scan_refresh(true)
end)

mod:hook_require("scripts/extension_systems/mission_objective_zone/mission_objective_zone_system", function(MissionObjectiveZoneSystem)
	mod:hook_safe(MissionObjectiveZoneSystem, "activate_zone", function(self, unit)
		_request_world_scan_refresh(true)
	end)

	mod:hook_safe(MissionObjectiveZoneSystem, "rpc_event_mission_objective_zone_activate_zone", function(self, channel_id, level_unit_id)
		_request_world_scan_refresh(true)
	end)

	mod:hook_safe(MissionObjectiveZoneSystem, "register_scannable_unit", function(self, scannable_unit)
		_request_world_scan_refresh(false)
	end)
end)

mod:hook_require("scripts/extension_systems/mission_objective_zone_scannable/mission_objective_zone_scannable_extension", function(MissionObjectiveZoneScannableExtension)
	mod:hook_safe(MissionObjectiveZoneScannableExtension, "set_active", function(self, active)
		local unit = self._unit

		if not unit then
			return
		end

		if active then
			_request_world_scan_refresh(true)

			return
		end

		self:set_scanning_outline(false)
		self:set_scanning_highlight(false)

		if mod._world_scan_unit_color_signatures then
			mod._world_scan_unit_color_signatures[unit] = nil
		end

		if mod._world_scan_highlighted_units then
			mod._world_scan_highlighted_units[unit] = nil
		end

		if mod._world_scan_icon_units then
			mod._world_scan_icon_units[unit] = nil
			_refresh_world_scan_icons_view()
		end
	end)

	mod:hook_safe(MissionObjectiveZoneScannableExtension, "set_scanning_outline", function(self, active)
		if active then
			_apply_world_scan_outline_color_to_unit(self._unit)
		end
	end)

	mod:hook_safe(MissionObjectiveZoneScannableExtension, "set_scanning_highlight", function(self, active)
		if active then
			_apply_world_scan_outline_color_to_unit(self._unit)
		end
	end)
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "_run_searching_sfx_loop", function(self)
	if self._is_husk then
		return
	end

	_set_scanner_searching_state(true)
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "_stop_scan_units_effects", function(self)
	if self._is_husk then
		return
	end

	_set_scanner_searching_state(false)
end)

mod:hook_safe(CLASS.AuspexEffects, "wield", function(self)
	if self._is_husk then
		return
	end

	_set_scanner_equipped_state(true)
	_request_world_scan_refresh(true)
end)

mod:hook_safe(CLASS.AuspexEffects, "unwield", function(self)
	if self._is_husk then
		return
	end

	_set_scanner_equipped_state(false)
	_set_scanner_searching_state(false)
	_request_world_scan_refresh(true)
end)

mod:hook_require("scripts/ui/views/scanner_display_view/minigame_decode_symbols_view", function(MinigameDecodeSymbolsView)
	function MinigameDecodeSymbolsView:_create_symbol_widgets()
		local minigame_extension = self._minigame_extension
		local minigame = _resolve_decode_style_minigame(minigame_extension)

		if not minigame then
			return
		end

		local symbols = minigame:symbols()

		if #symbols <= 0 then
			return
		end

		local scenegraph_id = "center_pivot"
		local layout = _decode_layout(minigame)
		local stage_amount = layout.stage_amount
		local symbols_per_stage = MinigameSettings.decode_symbols_items_per_stage
		local widget_size = layout.widget_size
		local starting_offset_x = layout.starting_offset_x
		local starting_offset_y = layout.starting_offset_y
		local spacing = layout.spacing
		local material_path = "content/ui/materials/backgrounds/scanner/"
		local material_prefix = "scanner_decode_"
		local grid_widgets = {}

		for stage = 1, stage_amount do
			for symbol_index = 1, symbols_per_stage do
				local widget_name = "symbol_"
				local symbol_id = symbols[#grid_widgets + 1]

				if symbol_id < 10 then
					widget_name = widget_name .. "0" .. tostring(symbol_id)
				else
					widget_name = widget_name .. tostring(symbol_id)
				end

				local widget_definition = UIWidget.create_definition({
					{
						pass_type = "texture",
						value = material_path .. material_prefix .. widget_name,
						style = {
							hdr = true,
							color = {
								255,
								0,
								255,
								0,
							},
						},
					},
				}, scenegraph_id, nil, widget_size)
				local widget = UIWidget.init(widget_name, widget_definition)

				grid_widgets[#grid_widgets + 1] = widget

				local offset = widget.offset

				offset[1] = starting_offset_x + (widget_size[1] + spacing) * (symbol_index - 1)
				offset[2] = starting_offset_y + (widget_size[2] + spacing) * (stage - 1)
			end
		end

		self._grid_widgets = grid_widgets
	end

	function MinigameDecodeSymbolsView:_draw_cursor(widgets_by_name, decode_start_time, on_target, gameplay_time)
		local minigame_extension = self._minigame_extension
		local minigame = _resolve_decode_style_minigame(minigame_extension)

		if not minigame then
			return
		end

		local current_decode_stage = minigame:current_stage()
		local symbols_per_stage = MinigameSettings.decode_symbols_items_per_stage
		local cursor_position = self:_get_cursor_position_from_time(decode_start_time, gameplay_time)
		local widget_target = widgets_by_name.symbol_frame
		local layout = _decode_layout(minigame)
		local widget_size = layout.widget_size
		local spacing = layout.spacing
		local starting_offset_x = layout.starting_offset_x
		local starting_offset_y = layout.starting_offset_y

		widget_target.style.frame.offset[1] = starting_offset_x + (widget_size[1] + spacing) * ((symbols_per_stage - 1) * cursor_position)
		widget_target.style.frame.offset[2] = starting_offset_y + (widget_size[2] + spacing) * (current_decode_stage - 1)
		widget_target.style.frame.offset[3] = 1

		widget_target.style.frame.color = _ui_highlight_color()
	end

	function MinigameDecodeSymbolsView:_draw_targets(widgets_by_name, decode_start_time, on_target)
		local minigame_extension = self._minigame_extension
		local minigame = _resolve_decode_style_minigame(minigame_extension)

		if not minigame then
			return
		end

		local decode_target = minigame:current_decode_target()
		local current_decode_stage = minigame:current_stage()
		local widget_target = widgets_by_name.symbol_highlight
		local layout = _decode_layout(minigame)
		local widget_size = layout.widget_size
		local spacing = layout.spacing
		local starting_offset_x = layout.starting_offset_x
		local starting_offset_y = layout.starting_offset_y

		widget_target.style.highlight.offset[1] = starting_offset_x + (widget_size[1] + spacing) * (decode_target - 1)
		widget_target.style.highlight.offset[2] = starting_offset_y + (widget_size[2] + spacing) * (current_decode_stage - 1)
		widget_target.style.highlight.color = _ui_highlight_color()
	end
end)

mod:hook_safe(CLASS.MinigameDecodeSymbolsView, "_draw_targets", function(self, widgets_by_name)
	local highlight_widget = widgets_by_name and widgets_by_name.symbol_highlight

	if highlight_widget and highlight_widget.style and highlight_widget.style.highlight then
		highlight_widget.style.highlight.color = _ui_highlight_color()
	end

	local minigame_extension = self._minigame_extension
	local minigame = _resolve_decode_style_minigame(minigame_extension)
	local decode_targets = minigame and minigame._decode_targets or nil
	local current_stage = minigame and minigame:current_stage() or nil
	local reveal_future_rows = _decode_style_future_rows(minigame)

	if not current_stage or not decode_targets then
		self._auspex_helper_decode_visible_count = 0

		return
	end

	local last_stage = math.min(#decode_targets, current_stage + reveal_future_rows)
	local visible_count = last_stage - current_stage + 1
	local layout = _decode_layout(minigame)
	local widget_size = layout.widget_size
	local starting_offset_x = layout.starting_offset_x
	local starting_offset_y = layout.starting_offset_y
	local spacing = layout.spacing
	local widgets = _ensure_decode_overlay_widgets(self, visible_count, widget_size)

	if not widgets then
		self._auspex_helper_decode_visible_count = 0

		return
	end

	for stage = current_stage, last_stage do
		local widget_index = stage - current_stage + 1
		local widget = widgets[widget_index]
		local target = decode_targets[stage] or 1

		widget.style.highlight.color = _ui_highlight_color()
		widget.offset[1] = starting_offset_x + (widget_size[1] + spacing) * (target - 1)
		widget.offset[2] = starting_offset_y + (widget_size[2] + spacing) * (stage - 1)
		widget.offset[3] = 6
	end

	self._auspex_helper_decode_visible_count = visible_count
end)

mod:hook_safe(CLASS.MinigameDecodeSymbolsView, "draw_widgets", function(self, dt, t, input_service, ui_renderer)
	local widgets = self._auspex_helper_decode_widgets
	local visible_count = self._auspex_helper_decode_visible_count or 0

	if not widgets then
		return
	end

	for index = 1, visible_count do
		UIWidget.draw(widgets[index], ui_renderer)
	end
end)

mod:hook_require("scripts/ui/views/scanner_display_view/minigame_decode_search_view", function(MinigameDecodeSearchView)
	mod:hook_safe(MinigameDecodeSearchView, "draw_widgets", function(self, dt, t, input_service, ui_renderer)
		if not _should_highlight_expedition_targets() or not ui_renderer then
			self._auspex_helper_expedition_visible_count = 0
			return
		end

		local minigame_extension = self._minigame_extension
		local minigame = _tag_minigame_type(_try_minigame_extension_minigame(minigame_extension, EXPEDITION_MINIGAME_TYPE), EXPEDITION_MINIGAME_TYPE)
			or _tag_minigame_type(_try_minigame_extension_minigame(minigame_extension), EXPEDITION_MINIGAME_TYPE)

		if not _looks_like_expedition_minigame(minigame) then
			self._auspex_helper_expedition_visible_count = 0
			return
		end

		local target_position = mod._expedition_target_cell(minigame)

		if not target_position then
			self._auspex_helper_expedition_visible_count = 0
			return
		end

		local matches = {}
		local board_width = mod._expedition_board_width()
		local cursor_width = mod._expedition_cursor_width()
		local cursor_height = mod._expedition_cursor_height()

		for y = 0, cursor_height - 1 do
			for x = 0, cursor_width - 1 do
				matches[#matches + 1] = (target_position.y + y - 1) * board_width + (target_position.x + x)
			end
		end

		local widgets = _ensure_expedition_overlay_widgets(self, #matches)

		if not widgets then
			self._auspex_helper_expedition_visible_count = 0
			return
		end

		local widget_size = ScannerDisplayViewDecodeSearchSettings.symbol_widget_size
		local spacing = ScannerDisplayViewDecodeSearchSettings.symbol_spacing or 0
		local starting_offset_x = ScannerDisplayViewDecodeSearchSettings.symbol_starting_offset_x or 0
		local starting_offset_y = ScannerDisplayViewDecodeSearchSettings.symbol_starting_offset_y or 0
		local width = board_width

		for match_index = 1, #matches do
			local symbol_index = matches[match_index]
			local widget = widgets[match_index]
			local x = ((symbol_index - 1) % width) + 1
			local y = math.floor((symbol_index - 1) / width) + 1

			widget.style.highlight.color = _ui_highlight_color()
			widget.offset[1] = starting_offset_x + (widget_size[1] + spacing) * (x - 1)
			widget.offset[2] = starting_offset_y + (widget_size[2] + spacing) * (y - 1)
			widget.offset[3] = 6

			UIWidget.draw(widget, ui_renderer)
		end

		self._auspex_helper_expedition_visible_count = #matches
	end)
end)

mod:hook_require("scripts/ui/views/scanner_display_view/minigame_expedition_map_view", function(MinigameExpeditionMapView)
	if mod._expedition_map_view_hook_applied then
		return
	end

	mod._expedition_map_view_hook_applied = true
	local ScannerDisplayViewExpeditionMapSettings = require("scripts/ui/views/scanner_display_view/scanner_display_view_expedition_map_settings")
	local UISettings = require("scripts/settings/ui/ui_settings")
	local PLAYER_SLOT_COLORS = UISettings and UISettings.player_slot_colors or {}
	local expedition_marker_dot_definition = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "dot",
			value = "content/ui/materials/backgrounds/scanner/scanner_drill_circle_filled",
			style = {
				color = _ui_highlight_color(255),
				hdr = true,
				offset = {
					0,
					0,
					1,
				},
				size = {
					24,
					24,
				},
			},
		},
	}, "center_pivot", nil, {
		24,
		24,
	})
	local expedition_marker_luggable_definition = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "dot",
			value = "content/ui/materials/buttons/arrow_02",
			style = {
				color = _ui_highlight_color(255),
				hdr = true,
				offset = {
					0,
					0,
					1,
				},
				size = {
					22,
					22,
				},
			},
		},
	}, "center_pivot", nil, {
		22,
		22,
	})
	local expedition_marker_reliquary_definition = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "ring",
			value = "content/ui/materials/backgrounds/scanner/scanner_drill_circle_empty",
			style = {
				color = _ui_highlight_color(255),
				hdr = true,
			},
		},
		{
			pass_type = "rotated_texture",
			style_id = "cross_a",
			value = "content/ui/materials/base/ui_default_base",
			style = {
				angle = math.rad(45),
				color = _ui_highlight_color(255),
				hdr = true,
				offset = { 0, 0, 1 },
				size = { 12, 2 },
			},
		},
		{
			pass_type = "rotated_texture",
			style_id = "cross_b",
			value = "content/ui/materials/base/ui_default_base",
			style = {
				angle = math.rad(-45),
				color = _ui_highlight_color(255),
				hdr = true,
				offset = { 0, 0, 1 },
				size = { 12, 2 },
			},
		},
	}, "center_pivot", nil, {
		22,
		22,
	})
	local expedition_marker_config_by_kind = {
		plasteel = {
			color = {
				255,
				96,
				230,
				164,
			},
			style = "dot",
			widget_size = {
				24,
				24,
			},
			widget_definition = expedition_marker_dot_definition,
		},
		diamantine = {
			color = {
				255,
				180,
				112,
				255,
			},
			style = "dot",
			widget_size = {
				24,
				24,
			},
			widget_definition = expedition_marker_dot_definition,
		},
		scrap = {
			color = {
				255,
				90,
				235,
				255,
			},
			style = "dot",
			widget_size = {
				24,
				24,
			},
			widget_definition = expedition_marker_dot_definition,
		},
		tech = {
			color = {
				255,
				255,
				214,
				64,
			},
			style = "dot",
			widget_size = {
				24,
				24,
			},
			widget_definition = expedition_marker_dot_definition,
		},
		crate = {
			color = {
				255,
				255,
				164,
				72,
			},
			style = "dot",
			widget_size = {
				24,
				24,
			},
			widget_definition = expedition_marker_dot_definition,
		},
		luggable = {
			color = {
				255,
				255,
				128,
				128,
			},
			style = "dot",
			widget_size = {
				22,
				22,
			},
			widget_definition = expedition_marker_luggable_definition,
		},
		chest = {
			color = {
				255,
				220,
				150,
				92,
			},
			style = "dot",
			widget_size = {
				24,
				24,
			},
			widget_definition = expedition_marker_dot_definition,
		},
	}
	local expedition_marker_draw_order = {
		"plasteel",
		"diamantine",
		"scrap",
		"tech",
		"crate",
		"luggable",
		"chest",
	}

	local function _expedition_marker_kind(pickup_type, interaction_type, ui_interaction_type, unit_name)
		local normalized_pickup_type = type(pickup_type) == "string" and pickup_type or nil
		local normalized_unit_name = type(unit_name) == "string" and string.lower(unit_name) or nil

		if normalized_pickup_type and string.sub(normalized_pickup_type, -7) == "_pickup" then
			normalized_pickup_type = string.sub(normalized_pickup_type, 1, -8)
		end

		if normalized_pickup_type and (string.find(normalized_pickup_type, "small_metal", 1, true) or string.find(normalized_pickup_type, "large_metal", 1, true)) then
			return "plasteel"
		end

		if normalized_pickup_type and (string.find(normalized_pickup_type, "small_platinum", 1, true) or string.find(normalized_pickup_type, "large_platinum", 1, true)) then
			return "diamantine"
		end

		if normalized_pickup_type and (normalized_pickup_type == "expedition_loot_player_drop" or string.find(normalized_pickup_type, "expedition_loot_small_", 1, true) == 1) then
			return "tech"
		end

		if normalized_pickup_type and string.find(normalized_pickup_type, "expedition_currency_", 1, true) == 1 then
			return "scrap"
		end

		if normalized_pickup_type and string.find(normalized_pickup_type, "expedition_loot_crate_", 1, true) == 1 then
			return "crate"
		end

		if normalized_pickup_type and string.find(normalized_pickup_type, "expedition_loot_heavy_", 1, true) == 1 then
			return "luggable"
		end

		if interaction_type == "expeditions_currency" then
			return "scrap"
		end

		if interaction_type == "expeditions_loot" then
			return "tech"
		end

		if interaction_type == "luggable" then
			return "luggable"
		end

		if normalized_unit_name and string.find(normalized_unit_name, "forge_material_metal", 1, true) then
			return "plasteel"
		end

		if normalized_unit_name and string.find(normalized_unit_name, "forge_material_platinum", 1, true) then
			return "diamantine"
		end

		local pickup_template = PICKUPS_BY_NAME and normalized_pickup_type and PICKUPS_BY_NAME[normalized_pickup_type]

		if not pickup_template then
			if ui_interaction_type == "pickup" and interaction_type == "forge_material" then
				if normalized_pickup_type and string.find(normalized_pickup_type, "metal", 1, true) then
					return "plasteel"
				end

				if normalized_pickup_type and string.find(normalized_pickup_type, "platinum", 1, true) then
					return "diamantine"
				end
			end

			return nil
		end

		local loot_data = pickup_template.loot_data

		if pickup_template.group == "forge_material" then
			if normalized_pickup_type and string.find(normalized_pickup_type, "metal", 1, true) then
				return "plasteel"
			end

			if normalized_pickup_type and string.find(normalized_pickup_type, "platinum", 1, true) then
				return "diamantine"
			end
		end

		if loot_data and loot_data.is_expedition_loot then
			if loot_data.type == "small" then
				return "tech"
			end

			if loot_data.type == "crate" then
				return "crate"
			end

			if loot_data.type == "heavy" then
				return "luggable"
			end
		end

		if pickup_template.group == "luggable" or pickup_template.interaction_type == "luggable" then
			return "luggable"
		end

		return nil
	end

	local function _expedition_marker_color(kind)
		local config = expedition_marker_config_by_kind[kind]
		local color = config and config.color or _ui_highlight_color(255)
		local alpha = mod._expedition_map_marker_alpha()

		return {
			alpha,
			color[2] or 255,
			color[3] or 255,
			color[4] or 255,
		}
	end

	local function _expedition_marker_widget_size()
		local size = mod._expedition_map_marker_size()

		return {
			size,
			size,
		}, size
	end

	local function _clear_expedition_marker_widgets(view)
		view._auspex_helper_expedition_marker_widgets = nil
	end

	local function _finite_number(value)
		return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
	end

	local function _normalized_marker_world_position(position)
		if not position then
			return nil
		end

		local indexed_x, indexed_y, indexed_z = nil, nil, nil

		if Vector3 and Vector3.to_elements then
			local ok, x, y, z = pcall(Vector3.to_elements, position)

			if ok then
				indexed_x = x
				indexed_y = y
				indexed_z = z
			end
		end

		if indexed_x == nil then
			indexed_x = position[1]
			indexed_y = position[2]
			indexed_z = position[3]
		end

		local field_x = position.x
		local field_y = position.y
		local field_z = position.z
		local x = _finite_number(indexed_x) and indexed_x or (_finite_number(field_x) and field_x or nil)
		local y = _finite_number(indexed_y) and indexed_y or (_finite_number(field_y) and field_y or nil)
		local z = _finite_number(indexed_z) and indexed_z or (_finite_number(field_z) and field_z or nil)

		if not (x and y) then
			return nil
		end

		return {
			x = x,
			y = y,
			z = z,
		}
	end

	local function _expedition_marker_world_position(unit)
		if not (unit and ALIVE[unit]) then
			return nil
		end

		local world_position = POSITION_LOOKUP and POSITION_LOOKUP[unit] or nil
		local normalized_position = _normalized_marker_world_position(world_position)

		if normalized_position then
			return normalized_position
		end

		local ok, fallback_position = pcall(Unit.world_position, unit, 1)

		if not ok then
			return nil
		end

		return _normalized_marker_world_position(fallback_position)
	end

	local function _ensure_expedition_marker_widgets(view, kind, widget_count, widget_definition)
		if widget_count <= 0 then
			local widgets_by_kind = view._auspex_helper_expedition_marker_widgets

			if widgets_by_kind then
				widgets_by_kind[kind] = nil
			end

			return nil
		end

		local widgets_by_kind = view._auspex_helper_expedition_marker_widgets

		if not widgets_by_kind then
			widgets_by_kind = {}
			view._auspex_helper_expedition_marker_widgets = widgets_by_kind
		end

		local widgets = widgets_by_kind[kind]

		if widgets and #widgets == widget_count then
			return widgets
		end

		widgets = {}

		for index = 1, widget_count do
			widgets[index] = UIWidget.init("auspex_helper_expedition_" .. kind .. "_marker_" .. tostring(index), widget_definition)
		end

		widgets_by_kind[kind] = widgets

		return widgets
	end

	local _expedition_marker_custom_map_pos = nil

	local function _draw_expedition_marker_widgets(view, ui_renderer, kind, positions, marker_depth, debug_samples)
		local config = expedition_marker_config_by_kind[kind]
		local widgets = config and _ensure_expedition_marker_widgets(view, kind, #positions, config.widget_definition)
		local rendered_count = 0

		if not (config and widgets) then
			return rendered_count
		end

		for index = 1, #positions do
			local widget = widgets[index]
			local world_position = positions[index]
			local position_x = world_position and (world_position.x or world_position[1])
			local position_y = world_position and (world_position.y or world_position[2] or world_position.z or world_position[3])
			local widget_size, marker_size = _expedition_marker_widget_size()

			if position_x ~= nil and position_y ~= nil then
				local x, y = _expedition_marker_custom_map_pos(position_x, position_y, widget_size)

				if x == nil or y == nil then
					local ok = nil

					ok, x, y = pcall(view._world_pos_to_map_pos, view, position_x, position_y, widget_size)

					if not ok then
						x = nil
						y = nil
					end
				end

				if x ~= nil and y ~= nil then
					local color = _expedition_marker_color(kind)

					if config.style == "reliquary" then
						widget.style.ring.size = widget.style.ring.size or {}
						widget.style.ring.size[1] = marker_size
						widget.style.ring.size[2] = marker_size
						widget.style.ring.color = color
						local cross_length = math.max(math.floor(marker_size * 0.55 + 0.5), 6)
						local cross_thickness = math.max(math.floor(marker_size * 0.12 + 0.5), 2)
						widget.style.cross_a.size = widget.style.cross_a.size or {}
						widget.style.cross_a.size[1] = cross_length
						widget.style.cross_a.size[2] = cross_thickness
						widget.style.cross_a.color = color
						widget.style.cross_b.size = widget.style.cross_b.size or {}
						widget.style.cross_b.size[1] = cross_length
						widget.style.cross_b.size[2] = cross_thickness
						widget.style.cross_b.color = color
					else
						widget.style.dot.size = widget.style.dot.size or {}
						widget.style.dot.size[1] = marker_size
						widget.style.dot.size[2] = marker_size
						widget.style.dot.color = color
					end

					widget.offset[1] = x
					widget.offset[2] = y
					widget.offset[3] = marker_depth

					UIWidget.draw(widget, ui_renderer)
					rendered_count = rendered_count + 1

					if debug_samples and #debug_samples < 6 then
						debug_samples[#debug_samples + 1] = string.format("%s@w(%.1f,%.1f)->m(%.1f,%.1f)", tostring(kind), position_x, position_y, x, y)
					end
				elseif debug_samples and #debug_samples < 6 then
					debug_samples[#debug_samples + 1] = string.format("%s@map_fail(%.1f,%.1f)", tostring(kind), position_x, position_y)
				end
			end
		end

		return rendered_count
	end

	local function _expedition_marker_scaled_map_pos(map_x, map_y, widget_size)
		if not (_finite_number(map_x) and _finite_number(map_y)) then
			return nil, nil
		end

		local starting_offset_x = ScannerDisplayViewExpeditionMapSettings.board_starting_offset_x or 0
		local starting_offset_y = ScannerDisplayViewExpeditionMapSettings.board_starting_offset_y or 0
		local board_width = ScannerDisplayViewExpeditionMapSettings.board_width or 0
		local board_height = ScannerDisplayViewExpeditionMapSettings.board_height or 0

		return starting_offset_x + map_x * board_width - widget_size[1] * 0.5, starting_offset_y + map_y * board_height - widget_size[2] * 0.5
	end

	_expedition_marker_custom_map_pos = function(world_x, world_y, widget_size)
		local local_player = _local_player()
		local player_unit = local_player and local_player.player_unit or nil
		local center = _expedition_marker_world_position(player_unit)
		local viewport_name = local_player and local_player.viewport_name or nil
		local camera_manager = Managers.state and Managers.state.camera

		if not (center and viewport_name and camera_manager and camera_manager.camera_rotation) then
			return nil, nil, center
		end

		local ok_rotation, camera_rotation = pcall(camera_manager.camera_rotation, camera_manager, viewport_name)

		if not ok_rotation or camera_rotation == nil then
			return nil, nil, center
		end

		local dx = world_x - center.x
		local dy = world_y - center.y
		local radian = math.atan2(dx, dy) + Quaternion.yaw(camera_rotation) - math.pi * 0.5
		local base_display_distance = ScannerDisplayViewExpeditionMapSettings.display_distance or 1
		local effective_display_distance = base_display_distance / mod._expedition_map_zoom_scale()
		local distance = math.min(math.sqrt(dx * dx + dy * dy) / effective_display_distance, 1)
		local map_x = math.cos(radian) * distance
		local map_y = math.sin(radian) * distance
		local scaled_x, scaled_y = _expedition_marker_scaled_map_pos(map_x, map_y, widget_size)

		return scaled_x, scaled_y, center
	end

	local function _expedition_marker_direct_map_pos(view, world_x, world_y, widget_size)
		local minigame = mod._cache_expedition_map_minigame(view and view._minigame) or mod._resolve_expedition_map_minigame(false)

		if not (minigame and minigame.world_pos_to_map_pos) then
			return nil, nil, minigame
		end

		local ok, map_x, map_y = pcall(minigame.world_pos_to_map_pos, minigame, world_x, world_y)

		if not ok then
			return nil, nil, minigame
		end

		local scaled_x, scaled_y = _expedition_marker_scaled_map_pos(map_x, map_y, widget_size)

		return scaled_x, scaled_y, minigame
	end

	local function _marker_world_distance_sq(a, b)
		if not (a and b) then
			return 0
		end

		local dx = (a.x or 0) - (b.x or 0)
		local dy = (a.y or 0) - (b.y or 0)

		return dx * dx + dy * dy
	end

	local function _first_distinct_marker_pair(positions_by_kind)
		local first_kind = nil
		local first_position = nil

		for index = 1, #expedition_marker_draw_order do
			local kind = expedition_marker_draw_order[index]
			local positions = positions_by_kind[kind]

			for position_index = 1, #(positions or mod._empty_widgets_by_name) do
				local position = positions[position_index]

				if not first_position then
					first_kind = kind
					first_position = position
				elseif _marker_world_distance_sq(first_position, position) > 4 then
					return first_kind, first_position, kind, position
				end
			end
		end

		return first_kind, first_position, nil, nil
	end

	local function _debug_expedition_marker_projection(view, positions_by_kind)
		if not mod._debug_enabled("exp_marker_projection") then
			return
		end

		local now = Managers.time and Managers.time:time("main") or 0
		local next_debug_time = rawget(view, "_auspex_helper_exp_marker_projection_debug_t") or 0

		if now < next_debug_time then
			return
		end

		view._auspex_helper_exp_marker_projection_debug_t = now + 1

		local first_kind, first_position, second_kind, second_position = _first_distinct_marker_pair(positions_by_kind)

		if not (first_kind and first_position and second_kind and second_position) then
			mod._debug_event("exp_marker_projection", "samples=insufficient")
			return
		end

		local first_widget_size = _expedition_marker_widget_size()
		local second_widget_size = _expedition_marker_widget_size()
		local view_ok_a, view_x_a, view_y_a = pcall(view._world_pos_to_map_pos, view, first_position.x, first_position.y, first_widget_size)
		local view_ok_b, view_x_b, view_y_b = pcall(view._world_pos_to_map_pos, view, second_position.x, second_position.y, second_widget_size)
		local direct_x_a, direct_y_a, direct_minigame = _expedition_marker_direct_map_pos(view, first_position.x, first_position.y, first_widget_size)
		local direct_x_b, direct_y_b = _expedition_marker_direct_map_pos(view, second_position.x, second_position.y, second_widget_size)
		local custom_x_a, custom_y_a, custom_center = _expedition_marker_custom_map_pos(first_position.x, first_position.y, first_widget_size)
		local custom_x_b, custom_y_b = _expedition_marker_custom_map_pos(second_position.x, second_position.y, second_widget_size)
		local world_dx = second_position.x - first_position.x
		local world_dy = second_position.y - first_position.y
		local view_dx = view_ok_a and view_ok_b and _finite_number(view_x_a) and _finite_number(view_x_b) and (view_x_b - view_x_a) or nil
		local view_dy = view_ok_a and view_ok_b and _finite_number(view_y_a) and _finite_number(view_y_b) and (view_y_b - view_y_a) or nil
		local direct_dx = direct_x_a and direct_x_b and (direct_x_b - direct_x_a) or nil
		local direct_dy = direct_y_a and direct_y_b and (direct_y_b - direct_y_a) or nil
		local custom_dx = custom_x_a and custom_x_b and (custom_x_b - custom_x_a) or nil
		local custom_dy = custom_y_a and custom_y_b and (custom_y_b - custom_y_a) or nil
		local collapsed_view = _finite_number(view_dx) and _finite_number(view_dy) and (math.abs(view_dx) < 0.5 and math.abs(view_dy) < 0.5) and (math.abs(world_dx) > 2 or math.abs(world_dy) > 2)
		local collapsed_direct = _finite_number(direct_dx) and _finite_number(direct_dy) and (math.abs(direct_dx) < 0.5 and math.abs(direct_dy) < 0.5) and (math.abs(world_dx) > 2 or math.abs(world_dy) > 2)
		local collapsed_custom = _finite_number(custom_dx) and _finite_number(custom_dy) and (math.abs(custom_dx) < 0.5 and math.abs(custom_dy) < 0.5) and (math.abs(world_dx) > 2 or math.abs(world_dy) > 2)

		mod._debug_event("exp_marker_projection", string.format(
			"view_mg=%s direct_mg=%s center=(%s,%s) world_delta=(%.1f,%.1f) view_delta=(%s,%s) direct_delta=(%s,%s) custom_delta=(%s,%s) collapsed_view=%s collapsed_direct=%s collapsed_custom=%s a=%s(%.1f,%.1f) b=%s(%.1f,%.1f)",
			tostring(_minigame_type_hint(view and view._minigame) or "unknown"),
			tostring(_minigame_type_hint(direct_minigame) or "unknown"),
			custom_center and string.format("%.1f", custom_center.x) or "nil",
			custom_center and string.format("%.1f", custom_center.y) or "nil",
			world_dx,
			world_dy,
			_finite_number(view_dx) and string.format("%.1f", view_dx) or "nil",
			_finite_number(view_dy) and string.format("%.1f", view_dy) or "nil",
			_finite_number(direct_dx) and string.format("%.1f", direct_dx) or "nil",
			_finite_number(direct_dy) and string.format("%.1f", direct_dy) or "nil",
			_finite_number(custom_dx) and string.format("%.1f", custom_dx) or "nil",
			_finite_number(custom_dy) and string.format("%.1f", custom_dy) or "nil",
			tostring(collapsed_view == true),
			tostring(collapsed_direct == true),
			tostring(collapsed_custom == true),
			tostring(first_kind),
			first_position.x,
			first_position.y,
			tostring(second_kind),
			second_position.x,
			second_position.y
		))
	end

	local function _draw_expedition_pickup_markers(view, ui_renderer)
		if not view or not view._minigame or not view._world_pos_to_map_pos then
			return
		end

		if mod:get("expedition_map_show_item_markers") ~= true then
			_clear_expedition_marker_widgets(view)
			return
		end

		local extension_manager = Managers.state and Managers.state.extension or nil
		local pickup_system = nil
		local chest_system = nil
		local interactee_system = nil

		if extension_manager and extension_manager.system then
			local ok, result = pcall(extension_manager.system, extension_manager, "pickup_system")

			if ok then
				pickup_system = result
			end

			ok, result = pcall(extension_manager.system, extension_manager, "chest_system")

			if ok then
				chest_system = result
			end

			ok, result = pcall(extension_manager.system, extension_manager, "interactee_system")

			if ok then
				interactee_system = result
			end
		end

		local spawned_pickups = pickup_system and rawget(pickup_system, "_spawned_pickups") or nil
		local dropped_pickups = pickup_system and rawget(pickup_system, "_dropped_pickups") or nil
		local chest_extensions = chest_system and rawget(chest_system, "_unit_to_extension_map") or nil
		local interactee_extensions = interactee_system and rawget(interactee_system, "_unit_to_extension_map") or nil

		if not spawned_pickups and not dropped_pickups and not chest_extensions and not interactee_extensions then
			_clear_expedition_marker_widgets(view)
			return
		end

		local player_unit = _local_player_unit()
		local player_position = _expedition_marker_world_position(player_unit)
		local hide_distant_markers = mod:get("expedition_map_hide_distant_item_markers") ~= false
		local max_marker_distance = 200
		local max_marker_distance_sq = max_marker_distance * max_marker_distance
		local positions_by_kind = {}
		local seen_units = {}
		local unknown_marker_samples = {}

		local function _within_marker_distance(world_position)
			if not hide_distant_markers then
				return true
			end

			if not (player_position and world_position) then
				return true
			end

			return _marker_world_distance_sq(player_position, world_position) <= max_marker_distance_sq
		end

		local function _add_pickup_unit(unit, pickup_type, interaction_type, ui_interaction_type)
			if not (unit and ALIVE[unit]) or seen_units[unit] then
				return
			end

			local unit_name = Unit.has_data(unit, "unit_name") and Unit.get_data(unit, "unit_name") or nil
			local kind = _expedition_marker_kind(pickup_type, interaction_type, ui_interaction_type, unit_name)

			if not kind then
				if mod._debug_enabled("exp_markers") and #unknown_marker_samples < 6 then
					unknown_marker_samples[#unknown_marker_samples + 1] = string.format(
						"%s|%s|%s|%s",
						tostring(pickup_type or "nil"),
						tostring(interaction_type or "nil"),
						tostring(ui_interaction_type or "nil"),
						tostring(unit_name or "nil")
					)
				end

				return
			end

			seen_units[unit] = true
			local world_position = _expedition_marker_world_position(unit)

			if world_position and _within_marker_distance(world_position) then
				positions_by_kind[kind][#positions_by_kind[kind] + 1] = world_position
			end
		end

		for index = 1, #expedition_marker_draw_order do
			positions_by_kind[expedition_marker_draw_order[index]] = {}
		end

		if spawned_pickups and #spawned_pickups > 0 then
			for index = 1, #spawned_pickups do
				local pickup_unit = spawned_pickups[index]

				if ALIVE[pickup_unit] and Unit.has_data(pickup_unit, "pickup_type") then
					_add_pickup_unit(pickup_unit, Unit.get_data(pickup_unit, "pickup_type"))
				end
			end
		end

		if dropped_pickups then
			for pickup_unit, _ in pairs(dropped_pickups) do
				if ALIVE[pickup_unit] and Unit.has_data(pickup_unit, "pickup_type") then
					_add_pickup_unit(pickup_unit, Unit.get_data(pickup_unit, "pickup_type"))
				end
			end
		end

		if interactee_extensions then
			for interactee_unit, interactee_extension in pairs(interactee_extensions) do
				local pickup_type = ALIVE[interactee_unit] and Unit.has_data(interactee_unit, "pickup_type") and Unit.get_data(interactee_unit, "pickup_type") or nil
				local interaction_type = interactee_extension and interactee_extension.interaction_type and interactee_extension:interaction_type() or rawget(interactee_extension, "_active_interaction_type")
				local ui_interaction_type = interactee_extension and interactee_extension.ui_interaction_type and interactee_extension:ui_interaction_type() or rawget(interactee_extension, "_ui_interaction_type")
				local is_active = interactee_extension == nil or rawget(interactee_extension, "_active") ~= false

				if (pickup_type or interaction_type == "forge_material" or interaction_type == "expeditions_currency" or interaction_type == "expeditions_loot" or interaction_type == "luggable") and is_active and ALIVE[interactee_unit] then
					_add_pickup_unit(interactee_unit, pickup_type, interaction_type, ui_interaction_type)
				elseif interaction_type == "chest" and is_active and ALIVE[interactee_unit] and not seen_units[interactee_unit] then
					local world_position = _expedition_marker_world_position(interactee_unit)

					if world_position and _within_marker_distance(world_position) then
						seen_units[interactee_unit] = true
						positions_by_kind.chest[#positions_by_kind.chest + 1] = world_position
					end
				end
			end
		end

		if chest_extensions then
			for chest_unit, chest_extension in pairs(chest_extensions) do
				if seen_units[chest_unit] then
					goto continue_chest_marker
				end

				local is_open = false

				if chest_extension then
					local ok, result = pcall(chest_extension.is_open, chest_extension)

					if ok then
						is_open = result
					else
						is_open = rawget(chest_extension, "_current_state") == "opened"
					end
				end

				if not is_open then
					local world_position = _expedition_marker_world_position(chest_unit)

					if world_position and _within_marker_distance(world_position) then
						seen_units[chest_unit] = true
						positions_by_kind.chest[#positions_by_kind.chest + 1] = world_position
					end
				end

				::continue_chest_marker::
			end
		end

		local rendered_by_kind = mod._debug_enabled("exp_markers") and {} or nil
		local marker_depth = 6

		_debug_expedition_marker_projection(view, positions_by_kind)

		for index = 1, #expedition_marker_draw_order do
			local kind = expedition_marker_draw_order[index]

			local rendered_count = _draw_expedition_marker_widgets(view, ui_renderer, kind, positions_by_kind[kind], marker_depth, nil)

			if rendered_by_kind then
				rendered_by_kind[kind] = rendered_count
			end
		end

		if mod._debug_enabled("exp_markers") then
			local function _count_pairs(source)
				local count = 0

				for _, _ in pairs(source or mod._empty_widgets_by_name) do
					count = count + 1
				end

				return count
			end

			mod._debug_event("exp_markers", string.format(
				"sources spawned=%s dropped=%s interactees=%s chests=%s classified plasteel=%d diamantine=%d scrap=%d tech=%d crate=%d luggable=%d chest=%d rendered plasteel=%d diamantine=%d scrap=%d tech=%d crate=%d luggable=%d chest=%d unknown_count=%d unknown_first=%s",
				tostring(spawned_pickups and #spawned_pickups or 0),
				tostring(_count_pairs(dropped_pickups)),
				tostring(_count_pairs(interactee_extensions)),
				tostring(_count_pairs(chest_extensions)),
				#positions_by_kind.plasteel,
				#positions_by_kind.diamantine,
				#positions_by_kind.scrap,
				#positions_by_kind.tech,
				#positions_by_kind.crate,
				#positions_by_kind.luggable,
				#positions_by_kind.chest,
				rendered_by_kind.plasteel or 0,
				rendered_by_kind.diamantine or 0,
				rendered_by_kind.scrap or 0,
				rendered_by_kind.tech or 0,
				rendered_by_kind.crate or 0,
				rendered_by_kind.luggable or 0,
				rendered_by_kind.chest or 0,
				#unknown_marker_samples,
				unknown_marker_samples[1] or "none"
			))
		end
	end

	local function _destroy_expedition_widget_group(ui_renderer, widgets)
		if not widgets then
			return
		end

		for key, widget in pairs(widgets) do
			if widget then
				UIWidget.destroy(ui_renderer, widget)
			end

			widgets[key] = nil
		end
	end

	local function _clear_expedition_target_widgets(view)
		if not view then
			return
		end

		_destroy_expedition_widget_group(view._ui_renderer, view._exit_widgets)
		_destroy_expedition_widget_group(view._ui_renderer, view._extraction_widgets)
		_destroy_expedition_widget_group(view._ui_renderer, rawget(view, "_opportunity_widgets"))
	end

	local function _ensure_expedition_target_snapshot(view)
		if not view then
			return nil
		end

		local snapshot = rawget(view, "_auspex_helper_target_snapshot")

		if not snapshot then
			snapshot = {}
			view._auspex_helper_target_snapshot = snapshot
		end

		snapshot.exits = snapshot.exits or {}
		snapshot.extractions = snapshot.extractions or {}
		snapshot.opportunities = snapshot.opportunities or {}

		return snapshot
	end

	local function _reset_expedition_target_snapshot(view)
		if not view then
			return
		end

		view._auspex_helper_target_snapshot = nil
		view._auspex_helper_selected_level = nil
		_clear_expedition_target_widgets(view)
	end

	local function _snapshot_expedition_targets(snapshot_targets, registered_targets)
		if not snapshot_targets or not registered_targets then
			return
		end

		local location_index = 0

		for key, location in pairs(registered_targets) do
			location_index = location_index + 1

			if location and location.unbox then
				local position = location:unbox()

				snapshot_targets[key] = {
					x = position.x,
					y = position.y,
					location_index = location_index,
				}
			elseif type(location) == "table" then
				snapshot_targets[key] = {
					x = location.x or location[1],
					y = location.y or location[2],
					location_index = location_index,
				}
			end
		end
	end

	local function _snapshot_expedition_target_widgets(snapshot_targets, widgets)
		if not snapshot_targets or not widgets then
			return
		end

		for key, widget in pairs(widgets) do
			if widget then
				local snapshot = snapshot_targets[key] or {}
				snapshot.widget = widget
				snapshot_targets[key] = snapshot
			end
		end
	end

	local function _registered_expedition_targets(navigation_handler, names)
		if not navigation_handler or not names then
			return nil
		end

		for index = 1, #names do
			local name = names[index]
			local candidate = rawget(navigation_handler, name)

			if type(candidate) == "function" then
				local ok, resolved = pcall(candidate, navigation_handler)

				if ok and type(resolved) == "table" then
					return resolved
				end
			elseif type(candidate) == "table" then
				return candidate
			end
		end

		return nil
	end

	local function _restore_expedition_snapshot_widgets(view, widgets, snapshot_targets, kind)
		if not (view and widgets and snapshot_targets) then
			return
		end

		for key, snapshot in pairs(snapshot_targets) do
			local x = snapshot and snapshot.x or nil
			local y = snapshot and snapshot.y or nil

			if x ~= nil and y ~= nil then
				local widget = widgets[key]

				if not widget then
					if snapshot and snapshot.widget then
						widget = snapshot.widget
					elseif kind == "exit" then
						widget = view:_create_icon_widget(string.format("exit_%s", key), "scanner_map_exit")
					elseif kind == "extraction" then
						widget = view:_create_icon_widget(string.format("extraction_%s", key), "scanner_map_extract")
					elseif kind == "opportunity" then
						local icon_index = (((tonumber(key) or 0) % 24) + 1)

						widget = view:_create_icon_widget(string.format("opportunity_%s", key), string.format("scanner_map_greek_%02d", icon_index))

						if widget.style and widget.style.title then
							widget.style.title.visible = true
						end

						if widget.content then
							widget.content.value_id_2 = "content/ui/materials/backgrounds/scanner/scanner_map_" .. tostring(snapshot and snapshot.location_index or 1)
						end
					end

					widgets[key] = widget
				end

				if widget then
					snapshot.widget = widget

					local offset = widget.offset

					offset[1], offset[2] = view:_world_pos_to_map_pos(x, y, ScannerDisplayViewExpeditionMapSettings.target_widget_size)
					offset[3] = kind == "opportunity" and 4 or 5

					if widget.style and widget.style.highlight and widget.style.highlight.color then
						widget.style.highlight.color[1] = math.max(widget.style.highlight.color[1] or 0, 32)
					end
				end
			end
		end
	end

	local function _force_expedition_widget_alpha(widgets, alpha)
		if not widgets then
			return
		end

		for _, widget in pairs(widgets) do
			local style = widget and widget.style
			local highlight = style and style.highlight
			local title = style and style.title

			if highlight and highlight.color then
				highlight.color[1] = alpha
			end

			if title and title.color then
				title.color[1] = alpha
			end
		end
	end

	local EXPEDITION_OPPORTUNITY_COLORS = {
		{ 255, 96, 255, 170 },
		{ 255, 96, 200, 255 },
		{ 255, 255, 210, 96 },
		{ 255, 255, 128, 224 },
		{ 255, 160, 255, 96 },
		{ 255, 255, 176, 96 },
	}

	local function _expedition_opportunity_color(level_index)
		local palette_index = ((tonumber(level_index) or 1) - 1) % #EXPEDITION_OPPORTUNITY_COLORS + 1

		return EXPEDITION_OPPORTUNITY_COLORS[palette_index]
	end

	local function _should_color_expedition_opportunity_icons()
		return mod:get("expedition_map_color_opportunity_icons") == true
	end

	local function _copy_expedition_widget_color(from, to)
		if not (from and to) then
			return
		end

		local values = nil

		if type(from) == "userdata" and Vector4 and Vector4.to_elements then
			local ok, a, b, c, d = pcall(Vector4.to_elements, from)

			if ok then
				values = { a, b, c, d }
			end
		end

		if not values then
			values = {
				from[1],
				from[2],
				from[3],
				from[4],
			}
		end

		for index = 1, 4 do
			if values[index] ~= nil then
				to[index] = values[index]
			end
		end
	end

	local function _hide_expedition_cursor_widget(cursor_widget)
		local frame = cursor_widget and cursor_widget.style and cursor_widget.style.frame
		local color = frame and frame.color

		if color then
			color[1] = 0
			color[2] = 0
			color[3] = 0
			color[4] = 0
		end
	end

	local function _apply_expedition_target_widget_state(navigation_handler, widgets, cursor_widget, preserve_completed_alpha, opportunity_color_fn)
		if not (navigation_handler and widgets) then
			return false
		end

		local minigame = navigation_handler.minigame and navigation_handler:minigame() or nil
		local selected_level = minigame and minigame.selected_level and minigame:selected_level() or nil
		local selected_found = false

		for level_index, widget in pairs(widgets) do
			local completed = navigation_handler.is_level_completed and navigation_handler:is_level_completed(level_index) or false
			local player_slot_index = navigation_handler.player_slot_by_level_marked and navigation_handler:player_slot_by_level_marked(level_index) or nil
			local player_slot_color = player_slot_index and PLAYER_SLOT_COLORS[player_slot_index] or nil
			local base_color = player_slot_color or ScannerDisplayViewExpeditionMapSettings.target_base_color
			local style = widget and widget.style
			local highlight = style and style.highlight
			local title = style and style.title
			local alpha = completed and (preserve_completed_alpha and 255 or 32) or 255

			if highlight and highlight.color then
				_copy_expedition_widget_color(base_color, highlight.color)
				highlight.color[1] = alpha

				if opportunity_color_fn and not player_slot_color then
					local opportunity_color = opportunity_color_fn(level_index)

					highlight.color[2] = opportunity_color[2]
					highlight.color[3] = opportunity_color[3]
					highlight.color[4] = opportunity_color[4]
				end
			end

			if title and title.color then
				_copy_expedition_widget_color(highlight and highlight.color or base_color, title.color)
				title.color[1] = alpha
			end

			if title then
				title.visible = title.visible ~= false
			end

			if selected_level ~= nil and selected_level == level_index and cursor_widget and widget and widget.offset then
				local cursor_frame = cursor_widget.style and cursor_widget.style.frame
				local cursor_color = cursor_frame and cursor_frame.color
				local offset = cursor_widget.offset
				local target_offset = widget.offset

				if cursor_color then
					_copy_expedition_widget_color(player_slot_color or Color.white(), cursor_color)
				end

				if offset and target_offset then
					offset[1] = target_offset[1]
					offset[2] = target_offset[2]
					offset[3] = (target_offset[3] or 5) + 1
				end

				selected_found = true
			end
		end

		return selected_found
	end

	local function _apply_expedition_opportunity_widget_state(navigation_handler, widgets)
		return _apply_expedition_target_widget_state(
			navigation_handler,
			widgets,
			nil,
			false,
			_should_color_expedition_opportunity_icons() and _expedition_opportunity_color or nil
		)
	end

	local function _expedition_target_widget_seen_cache(view, cache_name)
		if not view then
			return nil
		end

		local cache = rawget(view, cache_name)

		if not cache then
			cache = {}
			view[cache_name] = cache
		end

		return cache
	end

	local function _refresh_expedition_map_navigation_context(view)
		if not view then
			return
		end

		local game_mode_manager = Managers.state and Managers.state.game_mode
		local game_mode = game_mode_manager and game_mode_manager.game_mode and game_mode_manager:game_mode() or nil
		local navigation_handler = game_mode and game_mode.get_navigation_handler and game_mode:get_navigation_handler() or nil
		local minigame = navigation_handler and navigation_handler.minigame and navigation_handler:minigame() or nil
		local navigation_changed = navigation_handler ~= nil and view._navigation_handler ~= navigation_handler
		local minigame_changed = minigame ~= nil and view._minigame ~= minigame

		if navigation_changed or minigame_changed then
			mod._debug_event("exp_map_minimap", string.format("target context changed nav_changed=%s minigame_changed=%s", tostring(navigation_changed), tostring(minigame_changed)))
		end

		if navigation_changed or minigame_changed then
			_reset_expedition_target_snapshot(view)
		end

		if navigation_handler then
			view._navigation_handler = navigation_handler
			view._collectibles_handler = game_mode and game_mode.get_collectibles_handler and game_mode:get_collectibles_handler() or nil
		end

		if minigame then
			view._minigame = minigame
		end
	end

	local function _prune_expedition_target_widgets(view, widgets, active_keys, cache_name)
		return
	end

	local function _active_expedition_target_keys(registered_targets)
		local active_keys = {}

		if registered_targets then
			for key, _ in pairs(registered_targets) do
				active_keys[key] = true
			end
		end

		return active_keys
	end

	local function _cache_from_expedition_map_view(view)
		local minigame = view and rawget(view, "_minigame") or nil

		if type(minigame) == "table" and minigame._minigame and not (minigame.selected_level and minigame.world_pos_to_map_pos) then
			minigame = minigame._minigame
		end

		if not (minigame and minigame.selected_level and minigame.world_pos_to_map_pos) then
			local minigame_extension = view and view._minigame_extension

			minigame = _try_minigame_extension_minigame(minigame_extension, EXPEDITION_MAP_MINIGAME_TYPE)
				or _try_minigame_extension_minigame(minigame_extension)
		end

		if minigame and minigame.selected_level and minigame.world_pos_to_map_pos then
			mod._cache_expedition_map_minigame(minigame)
			mod._cached_live_minigame_type = EXPEDITION_MAP_MINIGAME_TYPE
		end
	end

	local function _refresh_expedition_map_view_from_local_player(view)
		local player_unit = _local_player_unit()

		if not player_unit or not Unit.alive(player_unit) then
			return
		end

		if view._owner_unit ~= player_unit then
			view._owner_unit = player_unit
		end
	end

	mod:hook(MinigameExpeditionMapView, "update", function(func, self, dt, t, widgets_by_name)
		_refresh_expedition_map_navigation_context(self)
		func(self, dt, t, widgets_by_name)
		_refresh_expedition_map_navigation_context(self)
		_cache_from_expedition_map_view(self)
		_refresh_expedition_map_view_from_local_player(self)
	end)

	mod:hook(MinigameExpeditionMapView, "_update_target_widgets", function(func, self, widgets_by_name, navigation_handler)
		local registered_exits = _registered_expedition_targets(navigation_handler, {
			"get_registered_exits",
			"registered_exits",
			"_registered_exits",
		})
		local registered_extractions = _registered_expedition_targets(navigation_handler, {
			"get_registered_extractions",
			"registered_extractions",
			"_registered_extractions",
		})
		local registered_opportunities = _registered_expedition_targets(navigation_handler, {
			"get_registered_opportunities",
			"registered_opportunities",
			"_registered_opportunities",
			"get_opportunities",
			"opportunities",
			"_opportunities",
			"get_registered_opportunity_targets",
			"registered_opportunity_targets",
			"_registered_opportunity_targets",
		})
		local snapshot = _ensure_expedition_target_snapshot(self)
		local opportunity_widgets_before = rawget(self, "_opportunity_widgets")

		_snapshot_expedition_target_widgets(snapshot and snapshot.opportunities, opportunity_widgets_before)

		local result = func(self, widgets_by_name, navigation_handler)
		local opportunity_widgets = rawget(self, "_opportunity_widgets")

		if opportunity_widgets == nil and snapshot and snapshot.opportunities and next(snapshot.opportunities) then
			opportunity_widgets = {}
			self._opportunity_widgets = opportunity_widgets
		end

		_snapshot_expedition_targets(snapshot and snapshot.exits, registered_exits)
		_snapshot_expedition_targets(snapshot and snapshot.extractions, registered_extractions)
		_snapshot_expedition_targets(snapshot and snapshot.opportunities, registered_opportunities)
		_snapshot_expedition_target_widgets(snapshot and snapshot.opportunities, opportunity_widgets)
		_prune_expedition_target_widgets(self, self._exit_widgets, _active_expedition_target_keys(registered_exits), "_auspex_helper_exit_seen_t")
		_prune_expedition_target_widgets(self, self._extraction_widgets, _active_expedition_target_keys(registered_extractions), "_auspex_helper_extraction_seen_t")
		_restore_expedition_snapshot_widgets(self, self._exit_widgets, snapshot and snapshot.exits, "exit")
		_restore_expedition_snapshot_widgets(self, self._extraction_widgets, snapshot and snapshot.extractions, "extraction")
		_restore_expedition_snapshot_widgets(self, opportunity_widgets, snapshot and snapshot.opportunities, "opportunity")
		_force_expedition_widget_alpha(self._exit_widgets, 255)
		_force_expedition_widget_alpha(self._extraction_widgets, 255)
		local cursor_widget = widgets_by_name and widgets_by_name.cursor or nil
		local selected_found = false

		_hide_expedition_cursor_widget(cursor_widget)
		selected_found = _apply_expedition_target_widget_state(navigation_handler, self._exit_widgets, cursor_widget, true, nil) or selected_found
		selected_found = _apply_expedition_target_widget_state(navigation_handler, self._extraction_widgets, cursor_widget, true, nil) or selected_found
		selected_found = _apply_expedition_target_widget_state(
			navigation_handler,
			opportunity_widgets,
			cursor_widget,
			false,
			_should_color_expedition_opportunity_icons() and _expedition_opportunity_color or nil
		) or selected_found

		if not selected_found then
			_hide_expedition_cursor_widget(cursor_widget)
		end

		return result
	end)

	mod:hook_safe(MinigameExpeditionMapView, "_update_player_widgets", function(self)
		if mod:get("expedition_map_hide_teammate_arrows") ~= true then
			return
		end

		local player_manager = Managers.player
		local local_player = player_manager and player_manager.local_player and player_manager:local_player(1) or nil
		local local_unique_id = nil

		if local_player and player_manager and player_manager.players then
			for unique_id, player in pairs(player_manager:players()) do
				if player == local_player then
					local_unique_id = unique_id
					break
				end
			end
		end

		for unique_id, widget in pairs(self._player_widgets or mod._empty_widgets_by_name) do
			if unique_id ~= local_unique_id and widget and widget.style and widget.style.highlight and widget.style.highlight.color then
				widget.style.highlight.color[1] = 0
			end
		end
	end)

	mod:hook(MinigameExpeditionMapView, "draw_widgets", function(func, self, dt, t, input_service, ui_renderer)
		local touched_widgets = {}
		_cache_from_expedition_map_view(self)

		_apply_widget_draw_offset_y(self._background_widgets, mod._expedition_map_draw_offset_y or 0, touched_widgets)

		local ok, result = pcall(func, self, dt, t, input_service, ui_renderer)

		_restore_widget_draw_offset_y(touched_widgets, mod._expedition_map_draw_offset_y or 0)

		if not ok then
			error(result)
		end

		_draw_expedition_pickup_markers(self, ui_renderer)

		return result
	end)
end)

mod:hook_safe(CLASS.MinigameDrillView, "_update_target", function(self, widgets_by_name, minigame)
	local stage = minigame and minigame:current_stage()
	local target_widgets = stage and self._target_widgets and self._target_widgets[stage]
	local correct_targets = minigame and minigame:correct_targets()
	local correct_target = correct_targets and correct_targets[stage]
	local widget = target_widgets and correct_target and target_widgets[correct_target]

	if _should_highlight_drill_targets() and widget and widget.style and widget.style.highlight then
		widget.style.highlight.color = _ui_highlight_color()
	end

	if _should_show_drill_direction_arrows() then
		_set_drill_direction_widgets(self, minigame)
	else
		_set_drill_direction_widgets(self, nil)
	end
end)

mod:hook_safe("MinigameBalanceView", "_update_cursor", function(self)
	if not _is_balance_autosolve_enabled() then
		return
	end

	local minigame_extension = self._minigame_extension
	local minigame = minigame_extension and minigame_extension:minigame(MinigameSettings.types.balance)
	local position = minigame and minigame:position()

	if not position then
		return
	end

	balance_cursor_x = position.x
	balance_cursor_y = position.y
	balance_distance = math.sqrt(balance_cursor_x * balance_cursor_x + balance_cursor_y * balance_cursor_y)
	balance_input_window = 0.05
end)

mod:hook_safe("MinigameBalance", "start", function()
	_reset_balance_autosolve()
end)

mod:hook_safe("MinigameBalance", "stop", function()
	_reset_balance_autosolve()
end)

mod:hook_safe("MinigameFrequency", "start", function()
	_reset_frequency_autosolve()
end)

mod:hook_safe("MinigameFrequency", "stop", function()
	_reset_frequency_autosolve()
end)

mod:hook_safe("MinigameDecodeSymbols", "start", function()
	_reset_decode_autosolve()
end)

mod:hook_safe("MinigameDecodeSymbols", "stop", function()
	_reset_decode_autosolve()
end)

function mod._apply_expedition_minigame_hooks(expedition_minigame_class_name)
	mod._expedition_minigame_hook_applied = mod._expedition_minigame_hook_applied or {}

	if mod._expedition_minigame_hook_applied[expedition_minigame_class_name] then
		return
	end

	mod._expedition_minigame_hook_applied[expedition_minigame_class_name] = true

	mod:hook_safe(expedition_minigame_class_name, "start", function(self)
		_tag_minigame_type(self, EXPEDITION_MINIGAME_TYPE)
		mod._cached_expedition_live_minigame = self
		mod._expedition_autosolve_state_owner_minigame = nil
		mod._expedition_autosolve_state_last_active_at = 0
		mod._pending_expedition_scanner_restore = nil
		mod._expedition_autosolve_open_grace_until = (_gameplay_time() or 0) + 1

		if mod._debug_enabled("exp_autosolve") then
			mod._debug_event("exp_autosolve", string.format("start class=%s", expedition_minigame_class_name))
		end

		_reset_expedition_autosolve()
	end)

	mod:hook_safe(expedition_minigame_class_name, "stop", function(self)
		if rawget(mod, "_cached_expedition_live_minigame") == self then
			mod._cached_expedition_live_minigame = nil
		end

		if rawget(mod, "_pending_live_expedition_match_overlay") and rawget(mod, "_pending_live_expedition_match_overlay").minigame == self then
			mod._pending_live_expedition_match_overlay = nil
		end

		if rawget(mod, "_expedition_autosolve_state_owner_minigame") == self then
			mod._expedition_autosolve_state_owner_minigame = nil
			mod._expedition_autosolve_state_last_active_at = 0
		end

		mod._expedition_autosolve_open_grace_until = 0

		if mod._debug_enabled("exp_autosolve") then
			mod._debug_event("exp_autosolve", string.format("stop class=%s", expedition_minigame_class_name))
		end

		_reset_expedition_autosolve()
	end)
end

mod._apply_expedition_minigame_hooks("MinigameDecodeSearch")
mod._apply_expedition_minigame_hooks("MinigameExpedition")
mod._apply_expedition_minigame_hooks("MinigameScan")

mod:hook_safe("MinigameDrill", "start", function()
	_reset_drill_autosolve()
end)

mod:hook_safe("MinigameDrill", "stop", function()
	_reset_drill_autosolve()
end)

mod:hook_safe("MinigameDecodeSymbols", "is_on_target", function(self, time)
	if not _is_decode_autosolve_enabled() or decode_autosolve_cooldown > 0 or decode_same_targets_count > 0 then
		return
	end

	if _is_decode_on_target(self, time) then
		decode_same_targets_count = _count_decode_same_targets(self)
	end
end)

PREVIEW_BLOCKED_BOOLEAN_ACTIONS = {
	action_one_hold = true,
	action_one_pressed = true,
	action_one_release = true,
	action_two_hold = true,
	action_two_pressed = true,
	action_two_release = true,
	combat_ability_hold = true,
	combat_ability_pressed = true,
	combat_ability_release = true,
	crouch = true,
	crouching = true,
	dodge = true,
	grenade_ability_hold = true,
	grenade_ability_pressed = true,
	grenade_ability_release = true,
	interact_hold = true,
	interact_primary_hold = true,
	interact_primary_pressed = true,
	interact_pressed = true,
	interact_secondary_hold = true,
	interact_secondary_pressed = true,
	jump = true,
	jump_held = true,
	jump_pressed = true,
	quick_wield = true,
	sprint = true,
	sprinting = true,
	weapon_extra_hold = true,
	weapon_extra_pressed = true,
	weapon_extra_release = true,
	weapon_reload_hold = true,
	weapon_reload_pressed = true,
	wield_1 = true,
	wield_2 = true,
	wield_3 = true,
	wield_3_gamepad = true,
	wield_4 = true,
	wield_5 = true,
	wield_scroll_down = true,
	wield_scroll_up = true,
}
PREVIEW_BLOCKED_VECTOR_ACTIONS = {
	look = true,
	look_controller = true,
	look_controller_improved = true,
	look_controller_lunging = true,
	look_controller_ranged = true,
	look_ranged = true,
	look_ranged_alternate_fire = true,
	look_raw = true,
	move = true,
}
PREVIEW_BLOCKED_FLOAT_ACTIONS = {
	move_backward = true,
	move_forward = true,
	move_left = true,
	move_right = true,
}
PREVIEW_ALLOWED_MENU_ACTIONS = {
	back = true,
	cancel = true,
	cycle_chat_channel = true,
	hotkey_menu = true,
	ingame_menu = true,
	pause = true,
	send_chat_message = true,
	show_chat = true,
	toggle_menu = true,
	ui_back = true,
}

_should_block_overlay_practice_input = function()
	local session = practice_session

	return session ~= nil
		and not session.item_mode
		and not session.pending_item_mode
		and not preview_close_requested_at
		and not (Managers.ui and Managers.ui.chat_using_input and Managers.ui:chat_using_input())
		and _overlay_preview_view_is_active(session)
end

_blocked_preview_input_value = function(action_name, result)
	if PREVIEW_ALLOWED_MENU_ACTIONS[action_name] then
		return result
	end

	if PREVIEW_BLOCKED_VECTOR_ACTIONS[action_name] then
		return Vector3.zero()
	elseif PREVIEW_BLOCKED_FLOAT_ACTIONS[action_name] then
		return 0
	elseif PREVIEW_BLOCKED_BOOLEAN_ACTIONS[action_name] then
		return false
	elseif action_name == "move" then
		return Vector3.zero()
	end

	return result
end

_stop_preview_input_simulation_on_service = function(input_service)
	if not input_service or input_service:is_null_service() then
		return
	end

	for action_name, _ in pairs(PREVIEW_BLOCKED_BOOLEAN_ACTIONS) do
		if input_service:has(action_name) then
			input_service:stop_simulate_action(action_name)
		end
	end

	for action_name, _ in pairs(PREVIEW_BLOCKED_VECTOR_ACTIONS) do
		if input_service:has(action_name) then
			input_service:stop_simulate_action(action_name)
		end
	end

	for action_name, _ in pairs(PREVIEW_BLOCKED_FLOAT_ACTIONS) do
		if input_service:has(action_name) then
			input_service:stop_simulate_action(action_name)
		end
	end
end

_set_preview_input_simulation = function(enabled)
	local input_manager = Managers.input
	local input_service = input_manager and input_manager:get_input_service("Ingame")

	if not enabled then
		_stop_preview_input_simulation_on_service(preview_input_simulation_service or input_service)

		preview_input_simulation_active = false
		preview_input_simulation_service = nil

		return
	end

	if not input_service or input_service:is_null_service() then
		return
	end

	if preview_input_simulation_active and preview_input_simulation_service == input_service then
		return
	end

	if preview_input_simulation_service and preview_input_simulation_service ~= input_service then
		_stop_preview_input_simulation_on_service(preview_input_simulation_service)
	end

	for action_name, _ in pairs(PREVIEW_BLOCKED_BOOLEAN_ACTIONS) do
		if input_service:has(action_name) then
			input_service:start_simulate_action(action_name, false)
		end
	end

	for action_name, _ in pairs(PREVIEW_BLOCKED_VECTOR_ACTIONS) do
		if input_service:has(action_name) then
			input_service:start_simulate_action(action_name, Vector3.zero())
		end
	end

	for action_name, _ in pairs(PREVIEW_BLOCKED_FLOAT_ACTIONS) do
		if input_service:has(action_name) then
			input_service:start_simulate_action(action_name, 0)
		end
	end

	preview_input_simulation_active = true
	preview_input_simulation_service = input_service
end

_raw_input_action_value = function(input_service, action_name)
	local actions = input_service and input_service._actions
	local action_rule = actions and actions[action_name]

	if not action_rule or action_rule.filter then
		return nil
	end

	local action_type = action_rule.type
	local action_type_settings = action_type and mod._input_service_class.ACTION_TYPES[action_type]
	local combiner = action_type_settings and action_type_settings.combine_func
	local out = action_rule.default_func and action_rule.default_func() or nil

	if not combiner then
		return out
	end

	for _, callback_func in ipairs(action_rule.callbacks or {}) do
		out = combiner(out, callback_func())
	end

	return out
end

_read_preview_move_input = function(input_service)
	local controller_move = _raw_input_action_value(input_service, "move_controller") or Vector3.zero()
	local keyboard_move = Vector3(
		(_raw_input_action_value(input_service, "keyboard_move_right") or 0) - (_raw_input_action_value(input_service, "keyboard_move_left") or 0),
		(_raw_input_action_value(input_service, "keyboard_move_forward") or 0) - (_raw_input_action_value(input_service, "keyboard_move_backward") or 0),
		0
	)

	if Vector3.length(controller_move) > Vector3.length(keyboard_move) then
		return controller_move
	end

	return keyboard_move
end

_preview_primary_action_pressed = function(input_service)
	return not not (_raw_input_action_value(input_service, "action_one_pressed") or _raw_input_action_value(input_service, "interact_pressed") or _raw_input_action_value(input_service, "interact_primary_pressed") or _raw_input_action_value(input_service, "jump_pressed"))
end

_trigger_preview_primary_action = function(minigame, t)
	if not minigame or not minigame.action then
		return
	end

	if minigame._action_held == nil then
		minigame:action(false, t)
	end

	minigame:action(true, t)
	minigame:action(false, t)
end

_update_preview_autosolve = function(session, minigame, t, move_input)
	if _is_decode_autosolve_enabled() and minigame == (_active_decode_autosolve_minigame and _active_decode_autosolve_minigame() or nil) and decode_autosolve_cooldown <= 0 and _is_decode_on_target(minigame, t) then
		local current_stage = minigame._current_stage
		local targets = minigame._decode_targets or {}
		local same_next_target = current_stage and targets[current_stage] ~= nil and targets[current_stage] == targets[current_stage + 1]

		decode_autosolve_cooldown = same_next_target and 0.05 or _decode_autosolve_cooldown_seconds()
		_trigger_preview_primary_action(minigame, t)
	end

	if _is_expedition_autosolve_enabled() and minigame == (_active_expedition_autosolve_minigame and _active_expedition_autosolve_minigame() or nil) then
		local auto_move = mod._expedition_autosolve_move_vector(minigame)
		local exact_target_match = mod._expedition_exact_target_match(minigame)

		if auto_move then
			local magnitude = math.sqrt((auto_move.x or 0) * (auto_move.x or 0) + (auto_move.y or 0) * (auto_move.y or 0))

			if magnitude <= 0.01 then
				move_input = auto_move
			elseif expedition_autosolve_move_cooldown <= 0 then
				expedition_autosolve_move_cooldown = mod._expedition_move_interaction_seconds()
				move_input = auto_move
			else
				move_input = Vector3.zero()
			end
		end

		if exact_target_match and _is_expedition_on_target(minigame, t) and t >= (mod._expedition_autosolve_submit_retry_at or 0) then
			local stage_before = minigame.current_stage and minigame:current_stage() or minigame._current_stage

			mod._expedition_autosolve_submit_retry_at = t + 0.2
			expedition_autosolve_cooldown = _expedition_autosolve_cooldown_seconds()

			if minigame.on_action_pressed then
				minigame:on_action_pressed(t)
			else
				_trigger_preview_primary_action(minigame, t)
			end

			local stage_after = minigame.current_stage and minigame:current_stage() or minigame._current_stage

			mod._debug_expedition_autosolve(minigame, "submit", {
				note = stage_after ~= stage_before and "preview_retry_advance" or "preview_retry_no_advance",
			})
		end
	end

	if _is_drill_autosolve_enabled() and minigame == (_active_drill_autosolve_minigame and _active_drill_autosolve_minigame() or nil) then
		mod._sync_drill_autosolve_minigame(minigame)
		mod._sync_drill_autosolve_stage(minigame)

		local auto_move = _drill_autosolve_move_vector(minigame)

		if auto_move then
			local magnitude = math.sqrt((auto_move.x or 0) * (auto_move.x or 0) + (auto_move.y or 0) * (auto_move.y or 0))

			if magnitude <= 0.01 then
				move_input = auto_move
			elseif (mod._drill_autosolve_move_cooldown or 0) <= 0 then
				mod._drill_autosolve_move_cooldown = _drill_autosolve_step_delay()
				move_input = auto_move
			else
				move_input = Vector3.zero()
			end
		end

		if (mod._drill_autosolve_submit_cooldown or 0) <= 0 and _should_submit_drill_autosolve(minigame, t) then
			mod._drill_autosolve_submit_cooldown = _drill_autosolve_step_delay()
			_trigger_preview_primary_action(minigame, t)
		end
	end

	if _is_frequency_autosolve_enabled() and minigame == (_active_frequency_autosolve_minigame and _active_frequency_autosolve_minigame() or nil) then
		local auto_move = _frequency_autosolve_move_vector(minigame)

		if auto_move then
			move_input = auto_move
		end

		if frequency_autosolve_submit_cooldown <= 0 and minigame:is_visually_on_target() then
			frequency_autosolve_submit_cooldown = 0.12
			_trigger_preview_primary_action(minigame, t)
		end
	end

	if _is_balance_autosolve_enabled() and _looks_like_balance_minigame(minigame) then
		local auto_move = _balance_autosolve_move_vector(minigame)

		if auto_move then
			move_input = auto_move
		end
	end

	return move_input
end

_update_preview_input = function()
	local session = practice_session
	local minigame = session and session.minigame

	if not session
		or not minigame
		or preview_close_requested_at
		or session.pending_item_mode
		or (session.item_mode and not session.item_view_opened)
		or (Managers.ui and Managers.ui.chat_using_input and Managers.ui:chat_using_input())
		or (not session.item_mode and not _overlay_preview_view_is_active(session))
	then
		return
	end

	local input_manager = Managers.input
	local input_service = input_manager and input_manager:get_input_service("Ingame")

	if (not input_service or input_service:is_null_service()) and session.allow_missing_gameplay_timer then
		input_service = input_manager and input_manager:get_input_service("View")
	end

	if not input_service or input_service:is_null_service() then
		return
	end

	local t = _gameplay_time()

	preview_input_polling = true

	local action_two_pressed = input_service:_get("action_two_pressed")
	local primary_action_pressed = minigame.uses_action and minigame:uses_action() and _preview_primary_action_pressed(input_service)
	local move_input = minigame.uses_joystick and minigame:uses_joystick() and _read_preview_move_input(input_service) or Vector3.zero()

	preview_input_polling = false

	move_input = _update_preview_autosolve(session, minigame, t, move_input)

	if action_two_pressed then
		preview_reopen_requested = false
		_close_preview_view(false)

		return
	end

	if primary_action_pressed then
		_trigger_preview_primary_action(minigame, t)
	end

	if minigame.uses_joystick and minigame:uses_joystick() then
		minigame:on_axis_set(t, move_input.x or 0, move_input.y or 0)
	end
end

_update_live_autosolve_input = function(minigame, t)
	if not minigame or _practice_session_blocks_live_autosolve() then
		if mod._debug_enabled("exp_autosolve") and _is_expedition_autosolve_enabled() then
			mod._debug_event("exp_autosolve", minigame == nil and "live_update minigame=nil" or "live_update blocked_by_practice")
		end

		return
	end

	if mod._debug_enabled("exp_autosolve") and _looks_like_expedition_minigame(minigame) then
		mod._debug_event("exp_autosolve", string.format(
			"live_update active stage=%s type=%s networked=%s",
			tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
			tostring(_minigame_type_hint(minigame) or "unknown"),
			tostring(_is_networked_live_minigame(minigame))
		))
	end

	if minigame.uses_joystick and minigame:uses_joystick() then
		local move_input = nil

		if _is_drill_autosolve_enabled() and _looks_like_drill_minigame(minigame) then
			mod._sync_drill_autosolve_stage(minigame)
			move_input = _drill_autosolve_move_vector(minigame)
		elseif _is_expedition_autosolve_enabled() and _looks_like_expedition_minigame(minigame) then
			local expedition_overlay_direct_live = false

			if _is_networked_live_minigame(minigame) then
				local minigame_type = _minigame_type_hint(minigame) or EXPEDITION_MINIGAME_TYPE
				local ui_manager = Managers.ui
				local overlay_active = ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) or false

				expedition_overlay_direct_live = _minigame_display_mode(minigame_type) == "overlay" and overlay_active
			end

			-- Online expedition matching needs the low-level input shim to inject held
			-- movement; direct on_axis_set calls are reliable offline but not online.
			if expedition_overlay_direct_live then
				move_input = mod._expedition_autosolve_move_vector(minigame)

				if move_input and ((move_input.x or 0) ~= 0 or (move_input.y or 0) ~= 0) then
					expedition_autosolve_move_cooldown = mod._expedition_move_interaction_seconds()
				end
			elseif _is_networked_live_minigame(minigame) then
				move_input = nil
			elseif expedition_autosolve_move_cooldown <= 0 then
				move_input = mod._expedition_autosolve_move_vector(minigame)

				if move_input and ((move_input.x or 0) ~= 0 or (move_input.y or 0) ~= 0) then
					expedition_autosolve_move_cooldown = mod._expedition_move_interaction_seconds()
				end
			end
		elseif _is_frequency_autosolve_enabled() and _looks_like_frequency_minigame(minigame) then
			move_input = _frequency_autosolve_move_vector(minigame)
		elseif _is_balance_autosolve_enabled() and _looks_like_balance_minigame(minigame) then
			move_input = _balance_autosolve_move_vector(minigame)
		end

		if move_input then
			minigame:on_axis_set(t, move_input.x or 0, move_input.y or 0)
		end
	end

	if _is_expedition_autosolve_enabled() and _looks_like_expedition_minigame(minigame) then
		local exact_target_match = mod._expedition_exact_target_match(minigame)

		if exact_target_match and _is_expedition_on_target(minigame, t) and t >= (mod._expedition_autosolve_submit_retry_at or 0) then
			local is_networked_live = _is_networked_live_minigame(minigame)
			local overlay_direct_live = false
			local simulated = false

			if is_networked_live then
				local minigame_type = _minigame_type_hint(minigame) or EXPEDITION_MINIGAME_TYPE
				local ui_manager = Managers.ui
				local overlay_active = ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) or false

				overlay_direct_live = _minigame_display_mode(minigame_type) == "overlay" and overlay_active
			end

			mod._expedition_autosolve_submit_retry_at = t + 0.2
			expedition_autosolve_cooldown = _expedition_autosolve_cooldown_seconds()
			mod._mark_expedition_autosolve_submit(minigame, t)

			if overlay_direct_live then
				if minigame.on_action_pressed then
					minigame:on_action_pressed(t)
				else
					_trigger_preview_primary_action(minigame, t)
				end
			elseif is_networked_live then
				simulated = _start_expedition_submit_input_pulse(t)
			elseif minigame.on_action_pressed then
				minigame:on_action_pressed(t)
			else
				_trigger_preview_primary_action(minigame, t)
			end

			mod._debug_expedition_autosolve(minigame, "submit", {
				note = overlay_direct_live and "overlay_direct_submit" or (is_networked_live and (simulated and "input_service_press" or "input_service_missing") or "live_direct_submit"),
			})
		end
	end

	if _is_decode_autosolve_enabled() and _looks_like_decode_minigame(minigame) and decode_autosolve_cooldown <= 0 and decode_autosolve_press_deadline <= t and _is_decode_on_target(minigame, t) then
		local current_stage = minigame._current_stage
		local targets = minigame._decode_targets or {}
		local same_next_target = current_stage and targets[current_stage] ~= nil and targets[current_stage] == targets[current_stage + 1]
		local press_window = _decode_autosolve_press_window_seconds(minigame)

		decode_autosolve_press_deadline = t + press_window
		decode_autosolve_cooldown = press_window + (same_next_target and 0.05 or _decode_autosolve_cooldown_seconds())
		_trigger_preview_primary_action(minigame, t)
	end

	if _is_drill_autosolve_enabled() and _looks_like_drill_minigame(minigame) and (mod._drill_autosolve_submit_cooldown or 0) <= 0 and _should_submit_drill_autosolve(minigame, t) then
		mod._drill_autosolve_submit_cooldown = _drill_autosolve_step_delay()
		_trigger_preview_primary_action(minigame, t)
	end

	if _is_frequency_autosolve_enabled() and _looks_like_frequency_minigame(minigame) and frequency_autosolve_submit_cooldown <= 0 and minigame.is_visually_on_target and minigame:is_visually_on_target() then
		frequency_autosolve_submit_cooldown = 0.12
		_trigger_preview_primary_action(minigame, t)
	end
end

_handle_preview_input = function(action_name, result)
	if not _should_block_overlay_practice_input() then
		return result
	end

	return _blocked_preview_input_value(action_name, result)
end

_input_get_hook = function(func, self, action_name)
	local result = func(self, action_name)

	if action_name == "show_chat" or action_name == "send_chat_message" or action_name == "cycle_chat_channel" then
		return result
	end

	if preview_input_polling then
		return result
	end

	if self and self.type == "Ingame" and PREVIEW_ALLOWED_MENU_ACTIONS[action_name] then
		local ui_manager = Managers.ui
		local world_scan_ui_active = scanner_searching_active
			or scanner_overlay_active
			or (ui_manager and (
				ui_manager:view_active(WORLD_SCAN_VIEW_NAME)
				or ui_manager:is_view_closing(WORLD_SCAN_VIEW_NAME)
				or ui_manager:view_active(WORLD_SCAN_ICONS_VIEW_NAME)
				or ui_manager:is_view_closing(WORLD_SCAN_ICONS_VIEW_NAME)
			))

		if world_scan_ui_active and result then
			_suppress_world_scan_views(0.35)
			_close_world_scan_views()

			if type(result) == "boolean" then
				return true
			end
		end
	end

	result = _handle_preview_input(action_name, result)

	if self and self.type == "Ingame" then
		result = _handle_expedition_autosolve_input(action_name, result)
		result = _handle_decode_autosolve_input(action_name, result)
		result = _handle_drill_autosolve_input(action_name, result)
		result = _handle_frequency_autosolve_input(action_name, result)
		result = _handle_balance_autosolve_input(action_name, result)
	end

	return result
end

mod:hook("InputService", "_get", _input_get_hook)
mod:hook("InputService", "_get_simulate", _input_get_hook)

mod:hook_require("scripts/extension_systems/input/player_unit_input_extension", function(PlayerUnitInputExtension)
	mod:hook(PlayerUnitInputExtension, "get", function(func, self, action)
		local result = func(self, action)

		if action == "show_chat" or action == "send_chat_message" or action == "cycle_chat_channel" then
			return result
		end

		if not _should_block_overlay_practice_input() then
			result = _handle_expedition_autosolve_input(action, result)
			result = _handle_decode_autosolve_input(action, result)
			result = _handle_drill_autosolve_input(action, result)
			result = _handle_frequency_autosolve_input(action, result)
			result = _handle_balance_autosolve_input(action, result)

			return result
		end

		return _blocked_preview_input_value(action, result)
	end)
end)

mod:hook_require("scripts/extension_systems/input/human_unit_input", function(HumanUnitInput)
	mod:hook(HumanUnitInput, "get", function(func, self, action)
		local result = func(self, action)

		if action == "show_chat" or action == "send_chat_message" or action == "cycle_chat_channel" then
			return result
		end

		if not _should_block_overlay_practice_input() then
			result = _handle_expedition_autosolve_input(action, result)
			result = _handle_decode_autosolve_input(action, result)
			result = _handle_drill_autosolve_input(action, result)
			result = _handle_frequency_autosolve_input(action, result)
			result = _handle_balance_autosolve_input(action, result)

			return result
		end

		return _blocked_preview_input_value(action, result)
	end)
end)

mod:hook_require("scripts/extension_systems/character_state_machine/character_states/player_character_state_minigame", function(PlayerCharacterStateMinigame)
	if mod._player_character_state_minigame_input_hook_applied then
		return
	end

	mod._player_character_state_minigame_input_hook_applied = true

	mod:hook(PlayerCharacterStateMinigame, "_update_input", function(func, self, t, fixed_frame, input_extension)
		local session = practice_session
		local allow_item_mode_practice_autosolve = session
			and session.item_mode
			and session.minigame
			and session.player_unit == self._unit

		if (_practice_session_blocks_live_autosolve() and not allow_item_mode_practice_autosolve)
			or (not _is_decode_autosolve_enabled() and not _is_drill_autosolve_enabled() and not _is_expedition_autosolve_enabled()) then
			return func(self, t, fixed_frame, input_extension)
		end

		local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()
		local minigame = mod._unwrap_nested_minigame((self and self._minigame) or (allow_item_mode_practice_autosolve and session.minigame) or nil)

		if not _looks_like_decode_minigame(minigame)
			and not _looks_like_drill_minigame(minigame)
			and not _looks_like_expedition_minigame(minigame)
		then
			if _looks_like_expedition_minigame(state_field_minigame) then
				minigame = state_field_minigame

				if mod._debug_enabled("exp_autosolve") then
					mod._debug_event("exp_autosolve", "state_update using_state_field_expedition")
				end
			elseif _looks_like_expedition_minigame(state_method_minigame) then
				minigame = state_method_minigame

				if mod._debug_enabled("exp_autosolve") then
					mod._debug_event("exp_autosolve", "state_update using_state_method_expedition")
				end
			elseif _looks_like_decode_minigame(state_field_minigame) then
				minigame = state_field_minigame
			elseif _looks_like_decode_minigame(state_method_minigame) then
				minigame = state_method_minigame
			elseif _looks_like_drill_minigame(state_field_minigame) then
				minigame = state_field_minigame
			elseif _looks_like_drill_minigame(state_method_minigame) then
				minigame = state_method_minigame
			end
		end

		if not _looks_like_decode_minigame(minigame)
			and not _looks_like_drill_minigame(minigame)
			and not _looks_like_expedition_minigame(minigame)
		then
			local cached_expedition_live_minigame = rawget(mod, "_cached_expedition_live_minigame")

			if _looks_like_expedition_minigame(cached_expedition_live_minigame) then
				minigame = cached_expedition_live_minigame

				if mod._debug_enabled("exp_autosolve") then
					mod._debug_event("exp_autosolve", "state_update using_cached_expedition")
				end
			end
		end

		if mod._debug_enabled("exp_autosolve")
			and _is_expedition_autosolve_enabled()
			and rawget(mod, "_cached_expedition_live_minigame") ~= nil
			and not _looks_like_expedition_minigame(minigame)
		then
			mod._debug_event("exp_autosolve", string.format(
				"state_update unresolved field_type=%s field_exp=%s method_type=%s method_exp=%s cached_type=%s cached_exp=%s",
				tostring(_minigame_type_hint(state_field_minigame) or "nil"),
				tostring(_looks_like_expedition_minigame(state_field_minigame)),
				tostring(_minigame_type_hint(state_method_minigame) or "nil"),
				tostring(_looks_like_expedition_minigame(state_method_minigame)),
				tostring(_minigame_type_hint(rawget(mod, "_cached_expedition_live_minigame")) or "nil"),
				tostring(_looks_like_expedition_minigame(rawget(mod, "_cached_expedition_live_minigame")))
			))
		end

		if _looks_like_expedition_minigame(minigame) then
			if mod._debug_enabled("exp_autosolve") then
				mod._debug_event("exp_autosolve", string.format(
					"state_update active type=%s stage=%s networked=%s",
					tostring(_minigame_type_hint(minigame) or "nil"),
					tostring(minigame.current_stage and minigame:current_stage() or minigame._current_stage or "nil"),
					tostring(_is_networked_live_minigame(minigame))
				))
			end

			mod._expedition_autosolve_state_owner_minigame = minigame
			mod._expedition_autosolve_state_last_active_at = t or _gameplay_time() or 0
			mod._cached_expedition_live_minigame = minigame
		elseif _looks_like_decode_minigame(minigame) then
			mod._cached_live_minigame = minigame
			mod._cached_live_minigame_type = MinigameSettings.types.decode_symbols
		end

		if _looks_like_expedition_minigame(minigame) and not allow_item_mode_practice_autosolve then
			if mod._debug_enabled("exp_autosolve") then
				mod._debug_event("exp_autosolve", "state_update pass_through_expedition")
			end

			return func(self, t, fixed_frame, input_extension)
		end

		if not _looks_like_decode_minigame(minigame) and not _looks_like_drill_minigame(minigame) and not _looks_like_expedition_minigame(minigame) then
			mod._sync_drill_autosolve_minigame(nil)
			return func(self, t, fixed_frame, input_extension)
		end

		local action_one_hold = input_extension:get("action_one_hold")
		local interact_hold = input_extension:get("interact_hold")
		local jump_held = input_extension:get("jump_held")

		if action_one_hold ~= self._previous_action_one_hold then
			self._previous_action_one_hold = action_one_hold
			self._previous_input = action_one_hold
		elseif interact_hold ~= self._previous_interact_hold then
			self._previous_interact_hold = interact_hold
			self._previous_input = interact_hold
		elseif jump_held ~= self._previous_jump_held then
			self._previous_jump_held = jump_held
			self._previous_input = jump_held
		end

		local primary_input = self._previous_input
		local action_two_pressed = input_extension:get("action_two_pressed")
		local cancel = action_two_pressed
		local block_weapon_actions = false
		local animation_extension = self._animation_extension
		local auto_move = nil
		local hold_submit = false
		local release_submit = false
		local expedition_submit_edge = false
		local decode_autosolve_minigame = _active_decode_autosolve_minigame and _active_decode_autosolve_minigame() or nil
		local decode_branch = minigame ~= nil and minigame == decode_autosolve_minigame and _is_decode_autosolve_enabled()
		local expedition_branch = minigame ~= nil and _looks_like_expedition_minigame(minigame) and _is_expedition_autosolve_enabled()
		local practice_expedition_branch = allow_item_mode_practice_autosolve and expedition_branch

		if expedition_branch then
			auto_move = mod._expedition_autosolve_move_vector(minigame)
			local exact_target_match = mod._expedition_exact_target_match(minigame)
			local settled_on_target = auto_move
				and math.abs(auto_move.x or 0) <= 0.01
				and math.abs(auto_move.y or 0) <= 0.01
			local state_name = minigame.state and minigame:state() or minigame._current_state or "nil"

			if not settled_on_target and expedition_autosolve_cooldown <= 0 and exact_target_match and _is_expedition_on_target(minigame, t) then
				settled_on_target = true
			end

			if practice_expedition_branch then
				mod._expedition_autosolve_release_deadline = 0
				expedition_autosolve_press_deadline = 0

				if settled_on_target then
					auto_move = Vector3.zero()
				end

				if settled_on_target and exact_target_match and state_name == MinigameSettings.game_states.gameplay and t >= (mod._expedition_autosolve_submit_retry_at or 0) then
					local stage_before = minigame.current_stage and minigame:current_stage() or minigame._current_stage

					mod._expedition_autosolve_submit_retry_at = t + 0.2
					expedition_autosolve_cooldown = _expedition_autosolve_cooldown_seconds()

					if minigame.on_action_pressed then
						minigame:on_action_pressed(t)
					else
						_trigger_preview_primary_action(minigame, t)
					end

					local stage_after = minigame.current_stage and minigame:current_stage() or minigame._current_stage

					mod._debug_expedition_autosolve(minigame, "submit", {
						note = stage_after ~= stage_before and "practice_item_retry_advance" or "practice_item_retry_no_advance",
					})
				end
			elseif expedition_autosolve_cooldown <= 0 and settled_on_target and exact_target_match then
				local press_window = _expedition_autosolve_press_window_seconds(minigame)
				local release_window = math.min(0.05, press_window * 0.5)
				expedition_submit_edge = not _is_networked_live_minigame(minigame)
				mod._mark_expedition_autosolve_submit(minigame, t)
				mod._expedition_autosolve_release_deadline = t + release_window
				expedition_autosolve_press_deadline = t + release_window + press_window
				expedition_autosolve_cooldown = press_window + _expedition_autosolve_cooldown_seconds()
				auto_move = Vector3.zero()
				mod._debug_expedition_autosolve(minigame, "submit_check", {
					chosen = mod._expedition_target_cell(minigame),
					note = string.format(
						"edge state=%s server=%s client=%s held=%s release_until=%.3f press_until=%.3f cooldown=%.3f",
						tostring(state_name),
						tostring(minigame._is_server),
						tostring(minigame._client_side),
						tostring(minigame._action_held),
						mod._expedition_autosolve_release_deadline or 0,
						expedition_autosolve_press_deadline or 0,
						expedition_autosolve_cooldown or 0
					),
				})
			end

			release_submit = (mod._expedition_autosolve_release_deadline or 0) > t
			hold_submit = expedition_autosolve_press_deadline > t and not release_submit

			if not practice_expedition_branch and settled_on_target and exact_target_match and state_name == MinigameSettings.game_states.gameplay and t >= (mod._expedition_autosolve_submit_retry_at or 0) then
				expedition_submit_edge = true
				mod._expedition_autosolve_submit_retry_at = t + 0.2
			end
		elseif decode_branch then
			hold_submit = decode_autosolve_press_deadline > t

			if decode_autosolve_cooldown <= 0 and decode_autosolve_press_deadline <= t and _is_decode_on_target(minigame, t) then
				local current_stage = minigame._current_stage
				local targets = minigame._decode_targets or {}
				local same_next_target = current_stage and targets[current_stage] ~= nil and targets[current_stage] == targets[current_stage + 1]
				local press_window = _decode_autosolve_press_window_seconds(minigame)

				decode_autosolve_press_deadline = t + press_window
				decode_autosolve_cooldown = press_window + (same_next_target and 0.05 or _decode_autosolve_cooldown_seconds())
				hold_submit = true
			end
		else
			mod._sync_drill_autosolve_minigame(minigame)
			mod._sync_drill_autosolve_stage(minigame)
			auto_move = _drill_autosolve_move_vector(minigame)
			local should_submit = (mod._drill_autosolve_submit_cooldown or 0) <= 0 and _should_submit_drill_autosolve(minigame, t)
			hold_submit = (mod._drill_autosolve_press_deadline or 0) > t or (mod._drill_autosolve_second_press_deadline or 0) > t and (mod._drill_autosolve_release_deadline or 0) <= t
			release_submit = (mod._drill_autosolve_release_deadline or 0) > t and (mod._drill_autosolve_press_deadline or 0) <= t

			if should_submit then
				mod._drill_autosolve_submit_cooldown = _drill_autosolve_step_delay()
				mod._drill_autosolve_press_deadline = t + 0.08
				mod._drill_autosolve_release_deadline = t + 0.12
				mod._drill_autosolve_second_press_deadline = t + 0.2
				mod._drill_autosolve_force_release = true
				hold_submit = true
			elseif mod._drill_autosolve_force_release then
				mod._drill_autosolve_force_release = false
			end
		end

		if not self:_is_wielding_minigame_device() then
			return true
		end

		if hold_submit then
			primary_input = true
		elseif release_submit then
			primary_input = false
		elseif not expedition_branch and mod._drill_autosolve_force_release then
			primary_input = false
		end

		if expedition_submit_edge and minigame.on_action_pressed then
			if _is_networked_live_minigame(minigame) then
				local simulated = _start_expedition_submit_input_pulse(t)

				mod._debug_expedition_autosolve(minigame, "submit", {
					note = simulated and "input_service_press_hook" or "input_service_missing_hook",
				})
			else
			local stage_before = minigame.current_stage and minigame:current_stage() or minigame._current_stage
			local state_before = minigame.state and minigame:state() or minigame._current_state or "nil"

			minigame:on_action_pressed(t)

			local stage_after = minigame.current_stage and minigame:current_stage() or minigame._current_stage
			local state_after = minigame.state and minigame:state() or minigame._current_state or "nil"

			if stage_after ~= stage_before then
				minigame._action_held = false
				mod._debug_expedition_autosolve(minigame, "submit", {
					note = "direct_on_action",
				})
			else
				mod._debug_expedition_autosolve(minigame, "submit", {
					note = string.format(
						"direct_no_advance stage_before=%s stage_after=%s state_before=%s state_after=%s server=%s client=%s held=%s",
						tostring(stage_before),
						tostring(stage_after),
						tostring(state_before),
						tostring(state_after),
						tostring(minigame._is_server),
						tostring(minigame._client_side),
						tostring(minigame._action_held)
					),
				})
			end
			end
		end

		local practice_expedition_primary_active = allow_item_mode_practice_autosolve
			and expedition_branch
		local custom_owned_minigame_input = expedition_branch
			or decode_branch
			or _looks_like_drill_minigame(minigame)

		if minigame:uses_action() and minigame:action(primary_input, t) then
			animation_extension:anim_event_1p("button_press")

			if minigame:is_completed() then
				animation_extension:anim_event_1p("scan_end")
			end
		end

		if minigame:uses_joystick() then
			local move_input = auto_move or input_extension:get("move") or Vector3.zero()

			minigame:on_axis_set(t, move_input.x or 0, move_input.y or 0)

			if not Vector3.equal(move_input, Vector3.zero()) then
				if move_input.y > 0 or move_input.x > 0 then
					animation_extension:anim_event_1p("knob_turn_up")
				else
					animation_extension:anim_event_1p("knob_turn_down")
				end
			end
		end

		cancel = minigame:escape_action(action_two_pressed)
		-- The custom autosolve path already drives minigame action/axis input. Letting it
		-- also start stock weapon actions can create invalid `use_auspex` action state.
		block_weapon_actions = custom_owned_minigame_input
			or minigame:blocks_weapon_actions()
			or practice_expedition_primary_active

		if not cancel and not block_weapon_actions then
			local weapon_extension = self._weapon_extension

			weapon_extension:update_weapon_actions(fixed_frame)
		end

		return cancel
	end)
end)

mod:hook_require("scripts/extension_systems/minigame/minigames/minigame_expedition_map", function(MinigameExpeditionMap)
	local ScannerDisplayViewExpeditionMapSettings = require("scripts/ui/views/scanner_display_view/scanner_display_view_expedition_map_settings")

	local function _shared_finite_number(value)
		return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
	end

	local function _shared_normalized_world_position(position)
		if not position then
			return nil
		end

		local indexed_x, indexed_y, indexed_z = nil, nil, nil

		if Vector3 and Vector3.to_elements then
			local ok, x, y, z = pcall(Vector3.to_elements, position)

			if ok then
				indexed_x = x
				indexed_y = y
				indexed_z = z
			end
		end

		if indexed_x == nil then
			indexed_x = position[1]
			indexed_y = position[2]
			indexed_z = position[3]
		end

		local field_x = position.x
		local field_y = position.y
		local field_z = position.z
		local x = _shared_finite_number(indexed_x) and indexed_x or (_shared_finite_number(field_x) and field_x or nil)
		local y = _shared_finite_number(indexed_y) and indexed_y or (_shared_finite_number(field_y) and field_y or nil)
		local z = _shared_finite_number(indexed_z) and indexed_z or (_shared_finite_number(field_z) and field_z or nil)

		if not (x and y) then
			return nil
		end

		return {
			x = x,
			y = y,
			z = z,
		}
	end

	mod:hook(MinigameExpeditionMap, "world_pos_to_map_pos", function(func, self, x, y)
		local local_player = _local_player()
		local player_unit = local_player and local_player.player_unit or nil
		local center = _shared_normalized_world_position((POSITION_LOOKUP and POSITION_LOOKUP[player_unit]) or nil)
		local viewport_name = local_player and local_player.viewport_name or nil
		local camera_manager = Managers.state and Managers.state.camera

		if not center then
			local ok_position, fallback_position = pcall(Unit.world_position, player_unit, 1)

			if ok_position then
				center = _shared_normalized_world_position(fallback_position)
			end
		end

		if not (center and viewport_name and camera_manager and camera_manager.camera_rotation) then
			return func(self, x, y)
		end

		local ok_rotation, camera_rotation = pcall(camera_manager.camera_rotation, camera_manager, viewport_name)

		if not ok_rotation or camera_rotation == nil then
			return func(self, x, y)
		end

		local dx = x - center.x
		local dy = y - center.y
		local base_display_distance = ScannerDisplayViewExpeditionMapSettings.display_distance or 1
		local zoom_scale = mod._expedition_map_zoom_scale()
		local effective_display_distance = base_display_distance / zoom_scale
		local radian = math.atan2(dx, dy) + Quaternion.yaw(camera_rotation) - math.pi * 0.5
		local distance = math.min(math.sqrt(dx * dx + dy * dy) / effective_display_distance, 1)

		return math.cos(radian) * distance, math.sin(radian) * distance
	end)
end)

mod:hook_require("scripts/ui/views/scanner_display_view/scanner_display_view", function(ScannerDisplayView)
	if mod._scanner_display_view_hook_applied then
		return
	end

	mod._scanner_display_view_hook_applied = true
	local decoration_widget_names = {
		"decoration_inquisition",
		"decoration_left_mark",
		"decoration_right_mark",
		"decoration_eagle",
		"decoration_skull",
	}

	mod:hook_safe(ScannerDisplayView, "update", function(self)
		local widgets_by_name = self._widgets_by_name

		if not widgets_by_name then
			return
		end

		local show_decorations = mod:get("overlay_show_decorations") ~= false

		for i = 1, #decoration_widget_names do
			local widget = widgets_by_name[decoration_widget_names[i]]
			local style = widget and widget.style and widget.style.highlight
			local color = style and style.color

			if color then
				style.__auspex_helper_base_alpha = style.__auspex_helper_base_alpha or color[1] or 255
				color[1] = show_decorations and style.__auspex_helper_base_alpha or 0
			end
		end
	end)
end)

mod:hook_require("scripts/ui/views/scanner_display_view/minigame_drill_view", function(MinigameDrillView)
	if mod._drill_view_draw_hook_applied then
		return
	end

	mod._drill_view_draw_hook_applied = true

	mod:hook(MinigameDrillView, "draw_widgets", function(func, self, dt, t, input_service, ui_renderer)
		func(self, dt, t, input_service, ui_renderer)

		local active_minigame_extension = self._minigame_extension
		local active_minigame = active_minigame_extension and active_minigame_extension:minigame(MinigameSettings.types.drill) or nil

		if _should_show_drill_direction_arrows() then
			_set_drill_direction_widgets(self, active_minigame)
		else
			_set_drill_direction_widgets(self, nil)
		end

		local direction_widgets = self._auspex_helper_drill_direction_widgets

		if direction_widgets then
			for index = 1, #DRILL_DIRECTION_WIDGET_ORDER do
				local widget = direction_widgets[DRILL_DIRECTION_WIDGET_ORDER[index]]

				if widget then
					UIWidget.draw(widget, ui_renderer)
				end
			end
		end

		local minigame_extension = self._minigame_extension

		if not minigame_extension or not self._target_widgets then
			return
		end

		local minigame = minigame_extension and minigame_extension:minigame(MinigameSettings.types.drill)

		if not minigame or minigame.unit == nil or minigame:unit() ~= nil then
			return
		end

		if minigame:state() ~= MinigameSettings.game_states.transition then
			return
		end

		self:_update_target(mod._empty_widgets_by_name, minigame, t)

		local current_stage = minigame:current_stage()
		local target_widgets = current_stage and self._target_widgets[current_stage]

		if not target_widgets then
			return
		end

		for index = 1, #target_widgets do
			UIWidget.draw(target_widgets[index], ui_renderer)
		end
	end)
end)

function mod.on_setting_changed(setting_id)
	if setting_id == "enable_mod_override" then
		_apply_mod_override_state()
	elseif setting_id == "enable_world_scans" or setting_id == "world_scan_display_mode" or setting_id == "world_scan_always_show" or setting_id == "world_scan_through_walls" or setting_id == "world_scan_item_overlay" or setting_id == "world_scan_color_red" or setting_id == "world_scan_color_green" or setting_id == "world_scan_color_blue" or setting_id == "world_scan_color_alpha" then
		if setting_id == "world_scan_color_red" or setting_id == "world_scan_color_green" or setting_id == "world_scan_color_blue" or setting_id == "world_scan_color_alpha" then
			mod._world_scan_unit_color_signatures = {}
			mod._world_scan_outline_settings_signature = nil
		elseif setting_id == "world_scan_through_walls" then
			mod._world_scan_outline_settings_signature = nil
		end

		_set_world_scan_highlights(false)

		if setting_id == "world_scan_always_show" or setting_id == "world_scan_through_walls" or setting_id == "world_scan_item_overlay" then
			mod._world_scan_next_refresh_t = nil
			mod._world_scan_next_visibility_refresh_t = nil
		end

		_set_world_scan_highlights(_world_scan_effective_active())
		_refresh_world_scan_overlay_view()
		_refresh_world_scan_icons_view()
	elseif SCANNER_SETTING_IDS[setting_id] then
		if not _is_scanner_visibility_enabled() then
			_reset_scanner_fade_state()
		end

		_sync_scanner_hud_visibility()
	elseif setting_id == "enable_decode_autosolve" or setting_id == "decode_interact_cooldown" or setting_id == "decode_target_precision" then
		if not _is_decode_autosolve_enabled() then
			_reset_decode_autosolve()
		end
	elseif setting_id == "enable_decode_minigame" and not _is_decode_autosolve_enabled() then
		_reset_decode_autosolve()
	elseif setting_id == "enable_expedition_autosolve" or setting_id == "expedition_interact_cooldown" or setting_id == "expedition_move_interaction_ms" then
		if not _is_expedition_autosolve_enabled() then
			_reset_expedition_autosolve()
		end
	elseif setting_id == "enable_expedition_minigame" and not _is_expedition_autosolve_enabled() then
		_reset_expedition_autosolve()
	elseif setting_id == "expedition_map_display_mode"
		or setting_id == "enable_expedition_map_minigame"
		or setting_id == "expedition_map_always_minimap"
		or setting_id == "expedition_map_zoom_scale"
		or setting_id == "expedition_map_color_opportunity_icons"
	then
		mod._cached_live_minigame = nil
		mod._cached_live_minigame_type = nil
		_close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)

		if mod._forced_expedition_map_overlay_active then
			mod._forced_expedition_map_overlay_active = nil
			_close_view(OVERLAY_VIEW_NAME, true)
		end
	elseif setting_id == "enable_drill_autosolve" or setting_id == "drill_autosolve_speed" then
		if not _is_drill_autosolve_enabled() then
			_reset_drill_autosolve()
		end
	elseif setting_id == "enable_drill_minigame" and not _is_drill_autosolve_enabled() then
		_reset_drill_autosolve()
	elseif setting_id == "enable_frequency_autosolve" or setting_id == "frequency_autosolve_strength" then
		if not _is_frequency_autosolve_enabled() then
			_reset_frequency_autosolve()
		end
	elseif setting_id == "enable_frequency_minigame" and not _is_frequency_autosolve_enabled() then
		_reset_frequency_autosolve()
	elseif setting_id == "enable_balance_autosolve" or setting_id == "balance_autosolve_strength" then
		if not _is_balance_autosolve_enabled() then
			_reset_balance_autosolve()
		end
	elseif setting_id == "enable_balance_minigame" and not _is_balance_autosolve_enabled() then
		_reset_balance_autosolve()
	elseif setting_id == "enable_preview" and not mod:get("enable_preview") then
		preview_reopen_requested = false
		_close_preview_view(false)
	elseif MINIGAME_ENABLE_SETTINGS[mod:get("preview_type")] == setting_id and practice_session then
		preview_reopen_requested = false
		_close_preview_view(false)
	elseif practice_session and (setting_id == "preview_type" or setting_id == "live_display_mode") then
		local ui_manager = Managers.ui

		if ui_manager and not ui_manager:is_view_closing(_practice_view_name()) then
			preview_reopen_requested = true
			_close_preview_view(false)
		end
	end
end

function mod.update(dt)
	dt = dt or 0
	local t = _gameplay_time()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name() or nil
	local ui_manager = Managers.ui
	local scanner_view_active = ui_manager and (
		ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)
		or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME)
	) or false

	mod._cached_local_player = nil
	mod._cached_local_player_unit = nil

	if not scanner_view_active then
		mod._cached_live_minigame = nil
	end

	if mod._last_gameplay_time and t + 1 < mod._last_gameplay_time then
		_reset_decode_autosolve()
		_reset_expedition_autosolve()
		_reset_drill_autosolve()
		_reset_frequency_autosolve()
		_reset_balance_autosolve()
		_set_preview_input_simulation(false)
	end

	mod._last_gameplay_time = t

	if not practice_session and (game_mode_name == "hub" or game_mode_name == "prologue_hub") then
		mod._expedition_map_focus_latched = false
		mod._forced_expedition_map_overlay_active = nil
		mod._cached_expedition_map_minigame = nil
		mod._cached_expedition_live_minigame = nil

		if scanner_searching_active then
			_set_scanner_searching_state(false)
		end

		if scanner_equipped_active then
			_set_scanner_equipped_state(false)
		end

		_close_view(OVERLAY_VIEW_NAME, true)
		_close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)
		_force_cancel_local_minigame_state()
	end

	if not practice_session and game_mode_name == "expedition" then
		local input_manager = Managers.input
		local input_service = input_manager and input_manager:get_input_service("Ingame")
		local action_two_hold = input_service and not input_service:is_null_service() and not not input_service:_get("action_two_hold") or false
		local action_two_pressed = input_service and not input_service:is_null_service() and not not input_service:_get("action_two_pressed") or false
		local autosolve_expedition_minigame = _is_expedition_autosolve_enabled() and (_active_expedition_autosolve_minigame and _active_expedition_autosolve_minigame() or nil) or nil
		local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()
		local state_expedition_active = _looks_like_expedition_minigame(state_field_minigame) or _looks_like_expedition_minigame(state_method_minigame)
		local expedition_autosolve_active = autosolve_expedition_minigame ~= nil and (
			autosolve_expedition_minigame == state_field_minigame
			or autosolve_expedition_minigame == state_method_minigame
		)
		local expedition_open_grace_active = (mod._expedition_autosolve_open_grace_until or 0) > t
		local scanner_view_active = ui_manager and (
			ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)
			or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME)
			or ui_manager:view_active(OVERLAY_VIEW_NAME)
			or ui_manager:is_view_closing(OVERLAY_VIEW_NAME)
		) or false

		if not scanner_view_active and not action_two_hold and not action_two_pressed then
			mod._expedition_map_focus_latched = false

			if scanner_searching_active then
				_set_scanner_searching_state(false)
			end

			if not expedition_autosolve_active and not state_expedition_active and not expedition_open_grace_active then
				_force_cancel_local_minigame_state()
			end
		end
	end

	if game_mode_name ~= "expedition" then
		mod._cached_expedition_live_minigame = nil
	end

	if game_mode_name == "expedition" then
		local player_unit = _local_player_unit()
		local character_state_machine_extension = player_unit and ScriptUnit.has_extension(player_unit, "character_state_machine_system")
		local state_name = character_state_machine_extension and character_state_machine_extension:current_state_name() or "nil"
		local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
		local minigame_character_state = unit_data_extension and unit_data_extension:read_component("minigame_character_state") or nil
		local interface_synced = minigame_character_state and (minigame_character_state.interface_level_unit_id ~= NetworkConstants.invalid_level_unit_id or minigame_character_state.interface_game_object_id ~= NetworkConstants.invalid_game_object_id) or false
		local scanner_view_active = ui_manager and (
			ui_manager:view_active(STOCK_SCANNER_VIEW_NAME)
			or ui_manager:is_view_closing(STOCK_SCANNER_VIEW_NAME)
			or ui_manager:view_active(OVERLAY_VIEW_NAME)
			or ui_manager:is_view_closing(OVERLAY_VIEW_NAME)
			or ui_manager:view_active(EXPEDITION_MINIMAP_VIEW_NAME)
			or ui_manager:is_view_closing(EXPEDITION_MINIMAP_VIEW_NAME)
		) or false

		mod._debug_event("expedition_state", string.format(
			"state=%s pocketable=%s iface=%s equipped=%s searching=%s overlay=%s stock=%s minimap=%s world=%s world_icons=%s scanner_overlay=%s chat=%s forced=%s",
			tostring(state_name),
			tostring(minigame_character_state and minigame_character_state.pocketable_device_active == true or false),
			tostring(interface_synced),
			tostring(scanner_equipped_active),
			tostring(scanner_searching_active),
			tostring(ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) or false),
			tostring(ui_manager and ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or false),
			tostring(ui_manager and ui_manager:view_active(EXPEDITION_MINIMAP_VIEW_NAME) or false),
			tostring(ui_manager and ui_manager:view_active(WORLD_SCAN_VIEW_NAME) or false),
			tostring(ui_manager and ui_manager:view_active(WORLD_SCAN_ICONS_VIEW_NAME) or false),
			tostring(scanner_overlay_active),
			tostring(ui_manager and ui_manager.chat_using_input and ui_manager:chat_using_input() or false),
			tostring(mod._forced_expedition_map_overlay_active == true)
		))

		if state_name == "minigame" and not scanner_view_active and not practice_session then
			mod._debug_event("expedition_stuck", string.format(
				"state=%s pocketable=%s iface=%s equipped=%s searching=%s forced=%s",
				tostring(state_name),
				tostring(minigame_character_state and minigame_character_state.pocketable_device_active == true or false),
				tostring(interface_synced),
				tostring(scanner_equipped_active),
				tostring(scanner_searching_active),
				tostring(mod._forced_expedition_map_overlay_active == true)
			))
		else
			mod._debug_event("expedition_stuck", nil)
		end
	end

	if mod._preview_gameplay_timer_missing then
		mod._preview_gameplay_timer_missing = nil
		preview_reopen_requested = false
		_abort_preview_session()

		return
	end

	if _is_scanner_visibility_enabled() or scanner_overlay_active then
		_refresh_scanner_overlay_state()
	end

	if decode_autosolve_cooldown > 0 then
		decode_autosolve_cooldown = math.max(decode_autosolve_cooldown - dt, 0)
	end

	if expedition_autosolve_cooldown > 0 then
		expedition_autosolve_cooldown = math.max(expedition_autosolve_cooldown - dt, 0)
	end

	if expedition_autosolve_move_cooldown > 0 then
		expedition_autosolve_move_cooldown = math.max(expedition_autosolve_move_cooldown - dt, 0)
	end

	_update_expedition_submit_input_pulse(_gameplay_time())

	if frequency_autosolve_submit_cooldown > 0 then
		frequency_autosolve_submit_cooldown = math.max(frequency_autosolve_submit_cooldown - dt, 0)
	end

	if (mod._drill_autosolve_submit_cooldown or 0) > 0 then
		mod._drill_autosolve_submit_cooldown = math.max(mod._drill_autosolve_submit_cooldown - dt, 0)
	end

	if (mod._drill_autosolve_move_cooldown or 0) > 0 then
		mod._drill_autosolve_move_cooldown = math.max(mod._drill_autosolve_move_cooldown - dt, 0)
	end

	if _is_drill_autosolve_enabled() then
		mod._sync_drill_autosolve_minigame(_active_drill_autosolve_minigame and _active_drill_autosolve_minigame() or nil)
	end

	if balance_input_window > 0 then
		balance_input_window = math.max(balance_input_window - dt, 0)
	end

	balance_velocity_x = (balance_cursor_x - balance_previous_x) * dt * 10000
	balance_velocity_y = (balance_cursor_y - balance_previous_y) * dt * 10000
	balance_previous_x = balance_cursor_x
	balance_previous_y = balance_cursor_y

	if practice_session then
		mod._expedition_map_focus_latched = false

		if scanner_searching_active then
			_set_scanner_searching_state(false)
		end

		if mod._forced_expedition_map_overlay_active then
			mod._forced_expedition_map_overlay_active = nil
			_close_view(OVERLAY_VIEW_NAME, true)
		end

		_close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)
	elseif scanner_world_helper_active or scanner_equipped_active or scanner_searching_active then
		local search_input_active = _scanner_search_input_active()

		if search_input_active ~= scanner_searching_active then
			_set_scanner_searching_state(search_input_active)
		end
	end

	_set_preview_input_simulation(not not (practice_session and not practice_session.item_mode and not (Managers.ui and Managers.ui.chat_using_input and Managers.ui:chat_using_input()) and _overlay_preview_view_is_active(practice_session)))
	if practice_session
		and practice_session.minigame
		and practice_session.minigame_started
		and not practice_session.pending_item_mode
		and not preview_close_requested_at
		and (practice_session.item_mode or _overlay_preview_view_is_active(practice_session))
	then
		practice_session.minigame:update(dt, t)

	end

	_update_preview_input()

	local live_minigame = _active_live_minigame and _active_live_minigame() or nil
	local expedition_live_minigame = _active_expedition_autosolve_minigame and _active_expedition_autosolve_minigame() or nil
	local live_autosolve_minigame = expedition_live_minigame or live_minigame

	-- Expedition matching can resolve through its own autosolve selector even when the
	-- generic live minigame resolver returns nil, especially offline. Always prefer the
	-- expedition autosolve minigame when present so both offline and online share the
	-- same steering path.
	if expedition_live_minigame then
		live_autosolve_minigame = expedition_live_minigame
	end

	local persistent_expedition_map_minigame = mod._persistent_expedition_map_minigame and mod._persistent_expedition_map_minigame() or nil
	local view_state = string.format(
		"mode=%s practice=%s equipped=%s searching=%s scanner_overlay=%s preview=%s stock=%s overlay=%s minimap=%s world=%s world_icons=%s",
		tostring(game_mode_name or "unknown"),
		tostring(practice_session ~= nil),
		tostring(scanner_equipped_active),
		tostring(scanner_searching_active),
		tostring(scanner_overlay_active),
		tostring(ui_manager and ui_manager:view_active(PREVIEW_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(EXPEDITION_MINIMAP_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(WORLD_SCAN_VIEW_NAME) or false),
		tostring(ui_manager and ui_manager:view_active(WORLD_SCAN_ICONS_VIEW_NAME) or false)
	)

	if mod._debug_last_view_state ~= view_state then
		mod._debug_last_view_state = view_state
		mod._debug_event("view_state", view_state)
	end

	local pending_expedition_match_overlay = rawget(mod, "_pending_live_expedition_match_overlay")

	if pending_expedition_match_overlay then
		local pending_type = pending_expedition_match_overlay.minigame_type
		local pending_requested_at = pending_expedition_match_overlay.requested_at or t
		local stock_scanner_active = ui_manager and ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or false
		local overlay_active = ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) or false
		local current_expedition_minigame = expedition_live_minigame
			or (_looks_like_expedition_minigame(live_minigame) and live_minigame or nil)
			or (_looks_like_expedition_minigame(pending_expedition_match_overlay.minigame) and pending_expedition_match_overlay.minigame or nil)

		if overlay_active or not _is_expedition_minigame_type(pending_type) then
			mod._pending_live_expedition_match_overlay = nil
		elseif stock_scanner_active and current_expedition_minigame then
			mod._open_live_minigame_overlay(current_expedition_minigame, pending_type)
			mod._pending_live_expedition_match_overlay = nil
		elseif t - pending_requested_at > 1.5 then
			mod._debug_event("live_overlay_open", string.format("defer expired type=%s", tostring(pending_type)))
			mod._pending_live_expedition_match_overlay = nil
		end
	end

	_update_live_autosolve_input(live_autosolve_minigame, t)
	_ensure_live_item_mode_overlay_fallback(live_minigame, t)
	_ensure_live_expedition_map_overlay(live_minigame)

	if persistent_expedition_map_minigame then
		mod._open_persistent_expedition_minimap(persistent_expedition_map_minigame)
	else
		_close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)
	end

	local pending_scanner_restore = mod._pending_expedition_scanner_restore

	if pending_scanner_restore then
		local state_field_minigame, state_method_minigame = mod._current_local_state_minigame()
		local cached_live_minigame = rawget(mod, "_cached_live_minigame")
		local minigame_state_active = _looks_like_expedition_minigame(state_field_minigame)
			or _looks_like_expedition_minigame(state_method_minigame)
			or _looks_like_decode_style_minigame(state_field_minigame)
			or _looks_like_decode_style_minigame(state_method_minigame)
			or _looks_like_decode_minigame(state_field_minigame)
			or _looks_like_decode_minigame(state_method_minigame)
			or (rawget(mod, "_cached_live_minigame_type") == MinigameSettings.types.decode_symbols and (_looks_like_decode_style_minigame(cached_live_minigame) or _looks_like_decode_minigame(cached_live_minigame)))

		if minigame_state_active then
			mod._debug_event("exp_scanner_slots", "restore_cancel minigame_active")
			mod._pending_expedition_scanner_restore = nil
			pending_scanner_restore = nil
		end
	end

	if pending_scanner_restore then
		local player_unit = pending_scanner_restore.player_unit
		local desired_wielded_slot = pending_scanner_restore.desired_wielded_slot
		local slots = pending_scanner_restore.slots
		local unit_data_extension = player_unit and ScriptUnit.has_extension(player_unit, "unit_data_system")
		local visual_loadout_extension = player_unit and ScriptUnit.has_extension(player_unit, "visual_loadout_system")
		local inventory_component = unit_data_extension and unit_data_extension:read_component("inventory") or nil
		local all_present = true

		if player_unit and Unit.alive(player_unit) and inventory_component and visual_loadout_extension and type(slots) == "table" then
			for index = 1, #slots do
				local entry = slots[index]
				local slot_name = entry and entry.slot_name or nil
				local item_name = entry and entry.item_name or nil
				local current_item_name = slot_name and inventory_component[slot_name] or nil

				if slot_name and item_name and item_name ~= "not_equipped" and current_item_name ~= item_name then
					all_present = false

					local item = MasterItems.get_item(item_name)

					if item then
						if current_item_name and current_item_name ~= "not_equipped" and PlayerUnitVisualLoadout.slot_equipped(inventory_component, visual_loadout_extension, slot_name) then
							PlayerUnitVisualLoadout.unequip_item_from_slot(player_unit, slot_name, t)
							mod._debug_event("exp_scanner_slots", string.format("clear slot=%s have=%s attempt=%s", tostring(slot_name), tostring(current_item_name), tostring((pending_scanner_restore.attempts or 0) + 1)))
						end

						PlayerUnitVisualLoadout.equip_item_to_slot(player_unit, item, slot_name, nil, t)
						mod._debug_event("exp_scanner_slots", string.format("restore slot=%s want=%s have=%s attempt=%s", tostring(slot_name), tostring(item_name), tostring(current_item_name or "none"), tostring((pending_scanner_restore.attempts or 0) + 1)))
					end
				end
			end

			if desired_wielded_slot
				and desired_wielded_slot ~= "none"
				and inventory_component.wielded_slot ~= desired_wielded_slot
				and visual_loadout_extension:can_wield(desired_wielded_slot)
			then
				PlayerUnitVisualLoadout.wield_slot(desired_wielded_slot, player_unit, t)
				mod._debug_event("exp_scanner_slots", string.format("rewield slot=%s attempt=%s", tostring(desired_wielded_slot), tostring((pending_scanner_restore.attempts or 0) + 1)))
				all_present = false
			end
		else
			all_present = false
		end

		pending_scanner_restore.attempts = (pending_scanner_restore.attempts or 0) + 1
		pending_scanner_restore.stable_attempts = all_present and ((pending_scanner_restore.stable_attempts or 0) + 1) or 0

		if pending_scanner_restore.stable_attempts >= 6 or pending_scanner_restore.attempts >= 40 or t - (pending_scanner_restore.requested_at or t) > 4 then
			mod._debug_event("exp_scanner_slots", string.format("restore_done attempts=%s stable=%s wielded=%s current=%s", tostring(pending_scanner_restore.attempts), tostring(pending_scanner_restore.stable_attempts or 0), tostring(inventory_component and inventory_component.wielded_slot or "nil"), tostring(mod._expedition_scanner_slot_snapshot_debug(mod._expedition_scanner_slot_snapshot(inventory_component)))))
			mod._pending_expedition_scanner_restore = nil
		end
	end

	if mod._forced_expedition_map_overlay_active then
		local ui_manager = Managers.ui
		local overlay_callout_freeze_active = mod._expedition_overlay_callout_freeze_active and mod._expedition_overlay_callout_freeze_active() or false
		local expedition_map_minigame = mod._resolve_expedition_map_minigame(false)
			or (overlay_callout_freeze_active and rawget(mod, "_cached_expedition_map_minigame") or nil)
		local overlay_mode_enabled = _minigame_display_mode(EXPEDITION_MAP_MINIGAME_TYPE) == "overlay"
		local overlay_active = ui_manager and ui_manager:view_active(OVERLAY_VIEW_NAME) or false
		local overlay_closing = ui_manager and ui_manager:is_view_closing(OVERLAY_VIEW_NAME) or false
		local stock_scanner_active = ui_manager and ui_manager:view_active(STOCK_SCANNER_VIEW_NAME) or false
		local overlay_hold_active = (_gameplay_time() or 0) < (mod._forced_expedition_map_overlay_hold_until or 0)
		local scanner_overlay_should_persist = scanner_searching_active
			or scanner_equipped_active
			or stock_scanner_active
			or overlay_hold_active

		if overlay_callout_freeze_active and overlay_active then
			expedition_map_minigame = expedition_map_minigame or rawget(mod, "_cached_expedition_map_minigame")
		end

		if overlay_mode_enabled and expedition_map_minigame and scanner_overlay_should_persist then
			if stock_scanner_active then
				ui_manager:close_view(STOCK_SCANNER_VIEW_NAME, true)
			end

			if ui_manager and not overlay_active and not overlay_closing then
				mod._open_live_minigame_overlay(expedition_map_minigame, EXPEDITION_MAP_MINIGAME_TYPE)
			end
		else
			mod._forced_expedition_map_overlay_active = nil
			mod._forced_expedition_map_overlay_hold_until = nil

			if ui_manager and overlay_active then
				ui_manager:close_view(OVERLAY_VIEW_NAME, true)
			end
		end
	end

	if _world_scan_effective_active() and t >= (mod._world_scan_next_refresh_t or 0) then
		mod._world_scan_next_refresh_t = t + 0.5
		_set_world_scan_highlights(true)
	end

	if _world_scan_effective_active() and _world_scan_needs_visibility_refresh() and t >= (mod._world_scan_next_visibility_refresh_t or 0) then
		mod._world_scan_next_visibility_refresh_t = t + 0.15
		_set_world_scan_highlights(true, false)
	end

	if scanner_searching_active or scanner_overlay_active then
		_refresh_world_scan_overlay_view()
	end

	local ui_manager = Managers.ui

	if _world_scan_effective_active() or (ui_manager and (ui_manager:view_active(WORLD_SCAN_ICONS_VIEW_NAME) or ui_manager:is_view_closing(WORLD_SCAN_ICONS_VIEW_NAME))) then
		_refresh_world_scan_icons_view()
	end

	local session = practice_session

	if _abort_live_item_scanner_if_unsafe() then
		return
	end

	if session and session.pending_item_mode and not preview_close_requested_at then
		if not _try_open_pending_item_preview(session) and t - (session.opened_at or 0) > mod._practice_item_open_timeout then
			_cleanup_preview_session()
			_open_overlay_preview_session(session, true)
		end
	end

	if session and session.item_mode and session.item_minigame_bound and not preview_close_requested_at then
		local character_state_machine_extension = session.player_unit and ScriptUnit.has_extension(session.player_unit, "character_state_machine_system")

		if character_state_machine_extension and character_state_machine_extension:current_state_name() ~= "minigame" then
			_abort_preview_session()

			return
		end
	end

	if practice_session and practice_session.minigame and practice_session.minigame:should_exit() and not preview_close_requested_at then
		preview_reopen_requested = false
		_abort_preview_session()
	end

	if ui_manager and practice_session and not practice_session.pending_item_mode and not preview_close_requested_at then
		local practice_view_name = practice_session.view_name
		local practice_active = ui_manager:view_active(practice_view_name)
		local practice_closing = ui_manager:is_view_closing(practice_view_name)
		local practice_open_elapsed = t - (practice_session.opened_at or t)

		if not practice_session.item_mode and practice_active and not practice_closing then
			practice_session.overlay_view_ready = true
			practice_session.overlay_missing_since = nil

			if practice_session.minigame and not practice_session.minigame_started then
				_start_preview_minigame(practice_session)
			end
		elseif not practice_session.item_mode and practice_closing then
			_abort_preview_session()

			return
		elseif not practice_session.item_mode and not practice_active and not practice_closing then
			if practice_session.overlay_view_ready then
				_abort_preview_session()

				return
			end

			practice_session.overlay_missing_since = practice_session.overlay_missing_since or t

			if practice_open_elapsed <= PREVIEW_VIEW_OPEN_TIMEOUT and t - practice_session.overlay_missing_since <= PREVIEW_VIEW_OPEN_TIMEOUT then
				if t >= (practice_session.next_view_open_retry_at or 0) then
					practice_session.next_view_open_retry_at = t + mod._preview_view_open_retry_interval
					_open_preview_session_view(practice_session)
				end
			else
				_abort_preview_session()
			end
		end
	end

	if not ui_manager or not preview_close_requested_at or not preview_close_view_name then
		return
	end

	local is_active = ui_manager:view_active(preview_close_view_name)
	local is_closing = ui_manager:is_view_closing(preview_close_view_name)

	if not is_active and not is_closing then
		_clear_preview_close_request()

		_cleanup_preview_session()

		if preview_reopen_requested and _is_mod_active() and mod:get("enable_preview") then
			preview_reopen_requested = false
			_open_preview_view()
		else
			preview_reopen_requested = false
		end

		return
	end

	if is_closing and t - preview_close_requested_at > mod._preview_close_timeout then
		local view_name = preview_close_view_name

		_clear_preview_close_request()
		ui_manager:close_view(view_name, true)
		_cleanup_preview_session()
	end
end

function mod.on_enabled()
	_apply_mod_override_state()
end

function _shutdown_runtime_state_for_unload()
	_reset_decode_autosolve()
	_reset_expedition_autosolve()
	_reset_drill_autosolve()
	_reset_frequency_autosolve()
	_reset_balance_autosolve()
	mod._cached_live_minigame_type = nil
	mod._forced_expedition_map_overlay_active = nil
	mod._live_item_overlay_fallback_started_t = nil
	mod._live_item_overlay_fallback_minigame = nil
	_clear_preview_close_request()
	preview_reopen_requested = false
	_set_preview_input_simulation(false)

	if practice_session then
		_abort_preview_session()
	end

	_force_cancel_local_minigame_state()

	scanner_equipped_active = false
	scanner_overlay_active = false
	scanner_searching_active = false
	_reset_scanner_fade_state()
	_apply_scanner_current_alpha()
	_set_world_scan_highlights(false)
	_close_view(PREVIEW_VIEW_NAME, true)
	_close_view(STOCK_SCANNER_VIEW_NAME, true)
	_close_preview_view(true)
	_close_view(OVERLAY_VIEW_NAME, true)
	_close_view(EXPEDITION_MINIMAP_VIEW_NAME, true)
	_close_view(WORLD_SCAN_VIEW_NAME, true)
	_close_view(WORLD_SCAN_ICONS_VIEW_NAME, true)
	_cleanup_preview_session()
end

function mod.on_disabled()
	_shutdown_runtime_state_for_unload()
end

function mod.on_unload(exit_game)
	_shutdown_runtime_state_for_unload()
end
