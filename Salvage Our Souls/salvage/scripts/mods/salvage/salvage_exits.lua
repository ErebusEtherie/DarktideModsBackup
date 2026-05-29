-- salvage_exits.lua
local mod = get_mod("salvage")
local exits = {}

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local PlayerUnitVisualLoadout = require("scripts/extension_systems/visual_loadout/utilities/player_unit_visual_loadout")

local MARKER_TYPE = "expedition_exits_marker"
local PENDING_MARKER = "pending"
local TARGET_DISCOVERY_INTERVAL = 0.25
local STATE_REFRESH_INTERVAL = 0.25
local MARKER_RETRY_INTERVAL = 0.75
local SCAN_MISS_LIMIT = 12
local MARKER_MAX_DISTANCE = 500
local THREE_MINUTES = 180
local CLOSE_HIDE_DISTANCE = 15
local TIMER_OBJECTIVE_NAME = "objective_expedition_timer"
local EXIT_ICON = "content/ui/materials/backgrounds/scanner/scanner_map_exit"
local EXTRACTION_ICON = "content/ui/materials/backgrounds/scanner/scanner_map_extract"
local GREEN = { 255, 70, 240, 80 }
local RED = { 255, 234, 47, 40 }
local ORANGE = { 255, 255, 151, 0 }
local SHADOW = { 220, 0, 0, 0 }
local DISTANCE_TEXT = { 255, 230, 230, 220 }
local DISTANCE_SHADOW = { 220, 0, 0, 0 }
local INVISIBLE = { 0, 0, 0, 0 }
local SANCTUARY_ALERT_OBJECTIVES = {
	objective_expedition_clear_exit = true,
	objective_expedition_safe_zone_traversal_power_off = true,
}
local EXTRACTION_ALERT_OBJECTIVES = {
	objective_expedition_clear_extraction = true,
	objective_expedition_enter_valkyrie = true,
}
local EARLY_EVACUATION_WARNING_OBJECTIVES = {
	objective_expedition_clear_extraction = true,
	objective_expedition_enter_valkyrie = true,
}
local EARLY_EVACUATION_WARNING_EVENT = "salvage_show_early_evacuation_warning"
local EARLY_EVACUATION_WARNING_ID = "early_evacuation"
local EARLY_EVACUATION_WARNING_DURATION = 2.5
local EARLY_EVACUATION_WARNING_HUD_CLASS = "HudElementSalvageEarlyEvacuationWarning"
local EARLY_EVACUATION_WARNING_HUD_FILE = "salvage/scripts/mods/salvage/salvage_evac"
local LUGGABLE_PICKUP_TYPES = {
	expedition_loot_heavy_tier_1 = true,
	expedition_loot_heavy_tier_2 = true,
	expedition_loot_heavy_tier_3 = true,
}

mod.in_expedition = false

local current_marker_id = nil
local current_marker_key = nil
local current_marker_kind = nil
local current_marker_pending_frames = nil
local current_marker_target = nil
local current_runtime_key = nil
local cached_target_after_activation = nil
local cached_timer_remaining = nil
local cached_local_reliquary_carried = false
local cached_sanctuary_defend_active = false
local cached_extraction_alert_active = false
local sanctuary_defend_latched = false
local marker_colour_latched = nil
local scan_miss_count = 0
local last_scan_t = -999
local last_state_update_t = -999
local last_marker_retry_t = -999
local force_scan = true
local force_state_update = true
local settings_normalised = false
local early_evacuation_warning_latch_key = nil
local ensure_marker_template

local function safe_call(object, method_name, ...)
	if not object then
		return nil
	end

	local method = object[method_name]

	if type(method) ~= "function" then
		return nil
	end

	local ok, value = pcall(method, object, ...)

	if ok then
		return value
	end

	return nil
end

local function safe_game_mode_manager()
	return Managers and Managers.state and Managers.state.game_mode or nil
end

local function safe_game_mode_name()
	return safe_call(safe_game_mode_manager(), "game_mode_name")
end

local function safe_game_mode()
	return safe_call(safe_game_mode_manager(), "game_mode")
end

local function is_hub_context()
	local name = safe_game_mode_name()

	if type(name) ~= "string" then
		return false
	end

	return name == "hub" or name == "hub_singleplay" or string.find(name, "hub", 1, true) ~= nil
end

local function has_expedition_shape(game_mode)
	if not game_mode then
		return false
	end

	return type(game_mode.get_expedition_template) == "function" or type(game_mode.current_location_index) == "function" or type(game_mode.expedition_loot) == "function" or type(game_mode.expedition_team_loot) == "function" or type(game_mode.in_safe_zone) == "function"
end

local function is_expedition_context()
	if is_hub_context() then
		return false
	end

	local name = safe_game_mode_name()

	if name == "expedition" then
		return true
	end

	return has_expedition_shape(safe_game_mode())
end

local function expedition_game_mode()
	if not is_expedition_context() then
		return nil
	end

	return safe_game_mode()
end

local function in_expedition_safe_zone(game_mode)
	if not game_mode or type(game_mode.in_safe_zone) ~= "function" then
		return false
	end

	local ok, value = pcall(game_mode.in_safe_zone, game_mode)

	return ok and value == true or false
end

local function current_location_index(game_mode)
	local value = safe_call(game_mode, "current_location_index")
	local number = tonumber(value)

	return number and number > 0 and number or nil
end

local function expedition_logic(game_mode)
	if type(game_mode) ~= "table" then
		return nil
	end

	return rawget(game_mode, "_game_mode_logic")
end

local function expedition_layout(game_mode)
	local logic = expedition_logic(game_mode)

	if type(logic) ~= "table" then
		return nil
	end

	local expedition = rawget(logic, "_expedition")

	if type(expedition) == "table" then
		return expedition
	end

	return nil
end

local function final_location_index(game_mode)
	local expedition = expedition_layout(game_mode)

	if expedition and #expedition > 0 then
		return #expedition
	end

	local template = safe_call(game_mode, "get_expedition_template")
	local default_amount = template and tonumber(template.default_session_location_amount)

	if default_amount and default_amount > 0 then
		return default_amount
	end

	return nil
end

local function is_final_location(game_mode)
	local current_index = current_location_index(game_mode)
	local final_index = final_location_index(game_mode)

	if current_index and final_index then
		return current_index >= final_index
	end

	return false
end

local function navigation_handler(game_mode)
	return safe_call(game_mode, "get_navigation_handler")
end

local function objective_system()
	local extension_manager = Managers and Managers.state and Managers.state.extension or nil

	return extension_manager and extension_manager.system and extension_manager:system("mission_objective_system") or nil
end

local function expedition_timer_remaining(game_mode)
	local logic = expedition_logic(game_mode)
	local timer_handler = logic and rawget(logic, "_timer_handler") or nil
	local remaining = safe_call(timer_handler, "get_remaining_duration")

	if type(remaining) == "number" then
		return remaining
	end

	local system = objective_system()
	local timer_objective = safe_call(system, "active_objective", TIMER_OBJECTIVE_NAME)
	local objective_remaining = safe_call(timer_objective, "get_time_left")

	if type(objective_remaining) == "number" then
		return objective_remaining
	end

	return nil
end

local function localise_text(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end

	if string.sub(value, 1, 4) == "loc_" then
		local ok, localised = pcall(Localize, value)

		if ok and type(localised) == "string" and localised ~= "" then
			value = localised
		end
	end

	return value
end

local function normalise_text(value)
	value = localise_text(value)

	if type(value) ~= "string" or value == "" then
		return nil
	end

	return string.lower(value)
end

local function alive_unit(unit)
	return unit ~= nil and ALIVE and ALIVE[unit]
end

local function get_interactee_extension(unit)
	if not alive_unit(unit) then
		return nil
	end

	return ScriptUnit and ScriptUnit.has_extension and ScriptUnit.has_extension(unit, "interactee_system") or nil
end

local function call_interactee_value(unit, method_name)
	local extension = get_interactee_extension(unit)

	if not extension then
		return nil
	end

	local method = extension[method_name]

	if type(method) ~= "function" then
		return nil
	end

	local ok, value = pcall(method, extension)

	if ok then
		return value
	end

	return nil
end

local function unit_data_string(unit, key)
	if not alive_unit(unit) or not Unit.has_data(unit, key) then
		return nil
	end

	local value = Unit.get_data(unit, key)

	return type(value) == "string" and value ~= "" and value or nil
end

local function pickup_type_from_unit(unit)
	if not alive_unit(unit) or not Unit.has_data or not Unit.get_data then
		return nil
	end

	local ok_has, has_data = pcall(Unit.has_data, unit, "pickup_type")

	if not ok_has or not has_data then
		return nil
	end

	local ok_get, pickup_type = pcall(Unit.get_data, unit, "pickup_type")

	if ok_get then
		return pickup_type
	end

	return nil
end

local function button_prompt(unit)
	return {
		description = normalise_text(call_interactee_value(unit, "description") or unit_data_string(unit, "hud_description")),
		action = normalise_text(call_interactee_value(unit, "action_text") or unit_data_string(unit, "sub_description")),
		interaction_type = normalise_text(call_interactee_value(unit, "interaction_type") or unit_data_string(unit, "interaction_type")),
		ui_interaction_type = normalise_text(call_interactee_value(unit, "ui_interaction_type") or unit_data_string(unit, "ui_interaction_type")),
	}
end

local function interactee_is_available(unit)
	local extension = get_interactee_extension(unit)

	if not extension then
		return false
	end

	if extension.used and extension:used() then
		return false
	end

	if extension.active and not extension:active() then
		return false
	end

	return true
end

local function interaction_unit_position(unit)
	if not alive_unit(unit) then
		return nil
	end

	local node = Unit.has_node(unit, "ui_interaction_marker") and Unit.node(unit, "ui_interaction_marker") or 1

	return Unit.world_position(unit, node)
end

local function local_player()
	local player_manager = Managers and Managers.player or nil

	return player_manager and player_manager.local_player and player_manager:local_player(1) or nil
end

local function local_player_unit()
	local player = local_player()
	local unit = player and player.player_unit or nil

	if alive_unit(unit) then
		return unit
	end

	return nil
end

local function local_player_position()
	local unit = local_player_unit()

	if alive_unit(unit) then
		return Unit.world_position(unit, 1)
	end

	return nil
end

local function distance_between(a, b)
	if not a or not b then
		return math.huge
	end

	return Vector3.distance(a, b)
end

local function for_each_active_objective(callback)
	local system = objective_system()

	if not system then
		return
	end

	local objective_groups = rawget(system, "_objective_groups")

	if type(objective_groups) == "table" then
		for group_id, objective_group in pairs(objective_groups) do
			local active_objectives = objective_group and objective_group.active_objectives

			if type(active_objectives) == "table" then
				for objective_name, objective in pairs(active_objectives) do
					callback(objective_name, objective, group_id)
				end
			end
		end
	end

	local active_objectives = safe_call(system, "active_objectives")

	if type(active_objectives) == "table" then
		for objective, _ in pairs(active_objectives) do
			local objective_name = safe_call(objective, "name")

			if objective_name then
				callback(objective_name, objective, nil)
			end
		end
	end
end

local function objective_active(objective_name)
	local found = false

	for_each_active_objective(function(active_objective_name)
		if active_objective_name == objective_name then
			found = true
		end
	end)

	return found
end

local function any_objective_active(objectives)
	for objective_name, _ in pairs(objectives) do
		if objective_active(objective_name) then
			return true
		end
	end

	return false
end

local function active_objective_text_contains(terms)
	local found = false

	for_each_active_objective(function(objective_name, objective)
		if found then
			return
		end

		local values = {
			objective_name,
			safe_call(objective, "header"),
			safe_call(objective, "description"),
			safe_call(objective, "title_text"),
		}

		for i = 1, #values do
			local text = normalise_text(values[i])

			if text then
				for _, term in ipairs(terms) do
					if string.find(text, term, 1, true) then
						found = true
						return
					end
				end
			end
		end
	end)

	return found
end

local function option_use_exit_icon_enabled()
	return mod:get("use_exit_icon") ~= false
end

local function option_three_minutes_enabled()
	return mod:get("three_mins_to_go") == true
end

local function option_field_of_view_enabled()
	return mod:get("field_of_view") == true
end

local function option_hide_close_enabled()
	return mod:get("hide_if_close_to_exit_location") == true
end

local function option_warn_early_evacuation_enabled()
	return mod:get("warn_early_evacuation") == true
end

local function timer_is_in_last_three_minutes()
	return cached_timer_remaining ~= nil and cached_timer_remaining <= THREE_MINUTES
end

local function evaluate_sanctuary_defend_active()
	local game_mode = expedition_game_mode()
	local logic = expedition_logic(game_mode)
	local active_defence_auto_event_id = logic and rawget(logic, "_active_defence_auto_event_id") or nil

	return active_defence_auto_event_id ~= nil or any_objective_active(SANCTUARY_ALERT_OBJECTIVES) or active_objective_text_contains({ "defend the gate", "access deadside sanctuary", "clear exit", "defend" })
end

local function evaluate_extraction_alert_active()
	return any_objective_active(EXTRACTION_ALERT_OBJECTIVES) or active_objective_text_contains({ "enter valkyrie", "clear extraction", "extraction" })
end

local function update_alert_cache()
	local defend_active = evaluate_sanctuary_defend_active()

	if defend_active then
		sanctuary_defend_latched = true
	end

	cached_sanctuary_defend_active = sanctuary_defend_latched or defend_active
	cached_extraction_alert_active = evaluate_extraction_alert_active()
end

local function sanctuary_defend_active()
	return cached_sanctuary_defend_active
end

local function extraction_alert_active()
	return cached_extraction_alert_active
end

local function alert_override_active()
	return cached_sanctuary_defend_active or cached_extraction_alert_active
end

local function early_evacuation_warning_key(game_mode)
	local current_index = current_location_index(game_mode)
	local final_index = final_location_index(game_mode)

	if not current_index or not final_index then
		return nil
	end

	return tostring(current_index) .. ":" .. tostring(final_index)
end

local function should_warn_early_evacuation(game_mode)
	if not option_warn_early_evacuation_enabled() or not game_mode or in_expedition_safe_zone(game_mode) then
		return false
	end

	local current_index = current_location_index(game_mode)
	local final_index = final_location_index(game_mode)

	return current_index ~= nil and final_index ~= nil and current_index < final_index
end

local function show_early_evacuation_warning()
	if Managers and Managers.event then
		Managers.event:trigger(EARLY_EVACUATION_WARNING_EVENT, EARLY_EVACUATION_WARNING_ID, EARLY_EVACUATION_WARNING_DURATION)
	end
end

local function try_warn_early_evacuation(objective_name)
	if not EARLY_EVACUATION_WARNING_OBJECTIVES[objective_name] then
		return
	end

	local game_mode = expedition_game_mode()

	if not should_warn_early_evacuation(game_mode) then
		return
	end

	local warning_key = early_evacuation_warning_key(game_mode)

	if not warning_key or early_evacuation_warning_latch_key == warning_key then
		return
	end

	early_evacuation_warning_latch_key = warning_key
	show_early_evacuation_warning()
end

local function display_allowed_by_timer()
	if not option_three_minutes_enabled() then
		return true
	end

	if cached_local_reliquary_carried or alert_override_active() then
		return true
	end

	return timer_is_in_last_three_minutes()
end

local function raw_marker_colour(kind)
	if kind == "exit" and sanctuary_defend_active() then
		return ORANGE
	end

	if timer_is_in_last_three_minutes() or kind == "extraction" and extraction_alert_active() then
		return RED
	end

	return GREEN
end

local function marker_colour(kind)
	local colour = raw_marker_colour(kind)

	if colour == ORANGE then
		marker_colour_latched = ORANGE
	elseif colour == RED and marker_colour_latched ~= ORANGE then
		marker_colour_latched = RED
	end

	return marker_colour_latched or colour
end

local function marker_distance_colour(kind)
	local colour = marker_colour(kind)

	if colour == GREEN then
		return DISTANCE_TEXT
	end

	return colour
end

local function vector_from_box(value)
	if not value then
		return nil
	end

	if type(value.unbox) == "function" then
		local ok, unboxed = pcall(value.unbox, value)

		if ok then
			value = unboxed
		else
			return nil
		end
	end

	local x = value.x or value[1]
	local y = value.y or value[2]
	local z = value.z or value[3]

	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil
	end

	return Vector3(x, y, z)
end

local function vector_key(position)
	if not position then
		return ""
	end

	return string.format("%.1f:%.1f:%.1f", position.x or position[1] or 0, position.y or position[2] or 0, position.z or position[3] or 0)
end

local function target_key(target)
	if not target then
		return nil
	end

	if target.unit then
		return tostring(target.kind) .. ":unit:" .. tostring(target.unit)
	end

	return tostring(target.kind) .. ":position:" .. tostring(target.level_index or "") .. ":" .. vector_key(target.position)
end

local function registered_points(navigation, method_name)
	if not navigation or type(navigation[method_name]) ~= "function" then
		return nil
	end

	local ok, value = pcall(navigation[method_name], navigation)

	if ok and type(value) == "table" then
		return value
	end

	return nil
end

local function level_completed(navigation, level_index)
	if not navigation or type(navigation.is_level_completed) ~= "function" or level_index == nil then
		return false
	end

	local ok, completed = pcall(navigation.is_level_completed, navigation, level_index)

	return ok and completed == true or false
end

local function choose_registered_point(navigation, points, kind)
	if type(points) ~= "table" then
		return nil
	end

	local player_position = local_player_position()
	local best = nil
	local best_distance = math.huge

	for level_index, boxed_position in pairs(points) do
		local position = vector_from_box(boxed_position)

		if position and not level_completed(navigation, level_index) then
			local distance = distance_between(player_position, position)

			if not best or distance < best_distance then
				best = {
					kind = kind,
					level_index = level_index,
					position = position,
				}
				best_distance = distance
			end
		end
	end

	return best
end

local function interactee_system_map()
	local extension_manager = Managers and Managers.state and Managers.state.extension or nil
	local system = extension_manager and extension_manager.system and extension_manager:system("interactee_system") or nil

	return system and system._unit_to_extension_map or nil
end

local function is_sanctuary_prompt(prompt)
	local description = prompt.description
	local action = prompt.action

	if not description then
		return false
	end

	local has_sanctuary = string.find(description, "deadsider sanctuary", 1, true) or string.find(description, "sanctuary", 1, true)
	local has_open = action == nil or string.find(action, "open", 1, true) or string.find(action, "pull", 1, true)

	return has_sanctuary and has_open
end

local function is_extraction_prompt(prompt)
	local description = prompt.description
	local action = prompt.action

	if not description then
		return false
	end

	local has_extraction = string.find(description, "call for extraction", 1, true) or string.find(description, "extraction", 1, true) or string.find(description, "valkyrie", 1, true)
	local has_action = action == nil or string.find(action, "call", 1, true) or string.find(action, "pull", 1, true) or string.find(action, "open", 1, true)

	return has_extraction and has_action
end

local function candidate_score(unit, prompt, wanted_kind)
	if not alive_unit(unit) or Unit.has_data(unit, "pickup_type") then
		return nil
	end

	if not interactee_is_available(unit) then
		return nil
	end

	local matches = wanted_kind == "extraction" and is_extraction_prompt(prompt) or is_sanctuary_prompt(prompt)

	if not matches then
		return nil
	end

	local score = 1000

	if prompt.interaction_type == "door_control_panel" then
		score = score + 100
	end

	if prompt.ui_interaction_type == "default" or prompt.ui_interaction_type == "mission" then
		score = score + 25
	end

	local position = interaction_unit_position(unit)
	local player_position = local_player_position()
	local distance = distance_between(player_position, position)

	return score - distance * 0.001, position
end

local function choose_interactee_target(wanted_kind)
	local map = interactee_system_map()

	if not map then
		return nil
	end

	local best_target = nil
	local best_score = -math.huge

	for unit, _ in pairs(map) do
		if alive_unit(unit) then
			local prompt = button_prompt(unit)
			local score, position = candidate_score(unit, prompt, wanted_kind)

			if score and position and score > best_score then
				best_score = score
				best_target = {
					kind = wanted_kind,
					unit = unit,
					position = position,
				}
			end
		end
	end

	return best_target
end

local function luggable_system_map()
	local extension_manager = Managers and Managers.state and Managers.state.extension or nil
	local system = extension_manager and extension_manager.system and extension_manager:system("luggable_system") or nil

	return system and system._unit_to_extension_map or nil
end

local function extension_carried_by_local_player(extension, local_unit)
	if not extension or not alive_unit(local_unit) then
		return false
	end

	if rawget(extension, "_carrier_player_unit") == local_unit then
		return true
	end

	return false
end

local function local_player_carrying_reliquary()
	local unit = local_player_unit()

	if not alive_unit(unit) or not ScriptUnit or not ScriptUnit.has_extension then
		return false
	end

	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	local visual_loadout_extension = ScriptUnit.has_extension(unit, "visual_loadout_system")
	local inventory_component = unit_data_extension and safe_call(unit_data_extension, "read_component", "inventory") or nil
	local luggable_component = unit_data_extension and safe_call(unit_data_extension, "read_component", "slot_luggable") or nil
	local luggable_unit = luggable_component and luggable_component.existing_unit_3p or nil

	if inventory_component and visual_loadout_extension and PlayerUnitVisualLoadout and type(PlayerUnitVisualLoadout.slot_equipped) == "function" then
		local ok_equipped, equipped = pcall(PlayerUnitVisualLoadout.slot_equipped, inventory_component, visual_loadout_extension, "slot_luggable")

		if ok_equipped and equipped then
			return true
		end
	end

	if inventory_component and inventory_component.wielded_slot == "slot_luggable" then
		return true
	end

	if alive_unit(luggable_unit) then
		local pickup_type = pickup_type_from_unit(luggable_unit)

		if pickup_type == nil or LUGGABLE_PICKUP_TYPES[pickup_type] then
			return true
		end
	end

	local map = luggable_system_map()

	if map then
		for luggable_unit_key, extension in pairs(map) do
			if alive_unit(luggable_unit_key) and extension_carried_by_local_player(extension, unit) then
				local pickup_type = pickup_type_from_unit(luggable_unit_key)

				if pickup_type == nil or LUGGABLE_PICKUP_TYPES[pickup_type] then
					return true
				end
			end
		end
	end

	return false
end

local function wanted_target_kind(game_mode)
	return is_final_location(game_mode) and "extraction" or "exit"
end

local function cached_target_for_kind(wanted_kind)
	local target = cached_target_after_activation

	if not target or target.kind ~= wanted_kind then
		return nil
	end

	if target.unit and alive_unit(target.unit) then
		target.position = interaction_unit_position(target.unit) or target.position
		return target.position and target or nil
	end

	if target.position then
		return target
	end

	return nil
end

local function discover_expedition_target(game_mode, wanted_kind)
	if not option_use_exit_icon_enabled() or not game_mode or in_expedition_safe_zone(game_mode) then
		return nil
	end

	local cached_target = cached_target_for_kind(wanted_kind)

	if cached_target then
		return cached_target
	end

	local interactee_target = choose_interactee_target(wanted_kind)

	if interactee_target then
		cached_target_after_activation = interactee_target
		return interactee_target
	end

	local navigation = navigation_handler(game_mode)

	if navigation then
		if wanted_kind == "extraction" then
			local extraction = choose_registered_point(navigation, registered_points(navigation, "get_registered_extractions"), "extraction")

			if extraction then
				cached_target_after_activation = extraction
				return extraction
			end
		else
			local exit = choose_registered_point(navigation, registered_points(navigation, "get_registered_exits"), "exit")

			if exit then
				cached_target_after_activation = exit
				return exit
			end
		end
	end

	return nil
end

local function update_cached_runtime_state(game_mode)
	local timer_remaining = expedition_timer_remaining(game_mode)

	if timer_remaining ~= nil then
		cached_timer_remaining = timer_remaining
	end

	cached_local_reliquary_carried = local_player_carrying_reliquary()
	update_alert_cache()
end

local function refresh_runtime_state(t, force)
	local game_mode = expedition_game_mode()

	if not game_mode or in_expedition_safe_zone(game_mode) then
		return false
	end

	local now = t or 0

	if force or force_state_update or now - last_state_update_t >= STATE_REFRESH_INTERVAL then
		last_state_update_t = now
		force_state_update = false
		update_cached_runtime_state(game_mode)
	end

	return true
end

local function current_cached_target()
	local game_mode = expedition_game_mode()

	if not game_mode or in_expedition_safe_zone(game_mode) then
		return nil
	end

	return cached_target_for_kind(wanted_target_kind(game_mode))
end

local function world_markers_element()
	local ui_manager = Managers and Managers.ui or nil
	local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud() or nil

	return hud and hud.element and hud:element("HudElementWorldMarkers") or nil
end

local function marker_is_live(marker_id)
	if not marker_id or marker_id == PENDING_MARKER then
		return false
	end

	local world_markers = world_markers_element()
	local markers_by_id = world_markers and world_markers._markers_by_id or nil

	return markers_by_id and markers_by_id[marker_id] ~= nil or false
end

local function remove_current_marker()
	if marker_is_live(current_marker_id) and Managers and Managers.event then
		Managers.event:trigger("remove_world_marker", current_marker_id)
	end

	current_marker_id = nil
	current_marker_key = nil
	current_marker_kind = nil
	current_marker_pending_frames = nil
	current_marker_target = nil
end

local function update_pending_marker()
	if current_marker_id == PENDING_MARKER then
		current_marker_pending_frames = (current_marker_pending_frames or 0) + 1

		if current_marker_pending_frames >= 30 then
			current_marker_id = nil
			current_marker_pending_frames = nil
		end
	elseif current_marker_id and not marker_is_live(current_marker_id) then
		current_marker_id = nil
		current_marker_pending_frames = nil
	end
end

local function request_marker(target)
	if not target or not target.position or not ensure_marker_template() then
		return
	end

	local key = target_key(target)

	if current_marker_key and current_marker_key ~= key then
		remove_current_marker()
	end

	current_marker_key = key
	current_marker_kind = target.kind
	current_marker_target = target

	if current_marker_id == PENDING_MARKER then
		return
	end

	if marker_is_live(current_marker_id) then
		current_marker_pending_frames = nil
		return
	end

	if not Managers or not Managers.event then
		return
	end

	current_marker_id = PENDING_MARKER
	current_marker_pending_frames = 0

	local marker_data = {
		kind = target.kind,
		level_index = target.level_index,
	}

	local function on_marker_added(new_marker_id)
		if current_marker_id == PENDING_MARKER and current_marker_key == key then
			current_marker_id = new_marker_id
			current_marker_pending_frames = nil
		end
	end

	if target.unit and alive_unit(target.unit) then
		Managers.event:trigger("add_world_marker_unit", MARKER_TYPE, target.unit, on_marker_added, marker_data)
	else
		Managers.event:trigger("add_world_marker_position", MARKER_TYPE, target.position, on_marker_added, marker_data)
	end
end

local function refresh_target(t)
	last_scan_t = t or 0
	force_scan = false

	local game_mode = expedition_game_mode()

	if not game_mode or in_expedition_safe_zone(game_mode) then
		return
	end

	refresh_runtime_state(t, false)

	local wanted_kind = wanted_target_kind(game_mode)
	local target = cached_target_for_kind(wanted_kind) or discover_expedition_target(game_mode, wanted_kind)

	if not target then
		scan_miss_count = scan_miss_count + 1

		if scan_miss_count >= SCAN_MISS_LIMIT then
			remove_current_marker()
			cached_target_after_activation = nil
		end

		return
	end

	scan_miss_count = 0
	request_marker(target)
end

local function update_runtime()
	local expedition = is_expedition_context()

	mod.in_expedition = expedition

	if not expedition then
		if current_runtime_key ~= nil then
			remove_current_marker()
		end

		current_runtime_key = nil
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
		return false
	end

	local game_mode = expedition_game_mode()
	local safe_zone = game_mode and in_expedition_safe_zone(game_mode) or false
	local location_index = game_mode and current_location_index(game_mode) or nil
	local runtime_key = tostring(location_index or "?") .. ":" .. tostring(safe_zone)

	if runtime_key ~= current_runtime_key then
		current_runtime_key = runtime_key
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999

		if safe_zone then
			remove_current_marker()
		end
	end

	return not safe_zone
end

local function normalise_settings_once()
	if settings_normalised then
		return
	end

	settings_normalised = true

	if mod:get("use_exit_icon") == nil then
		mod:set("use_exit_icon", false)
	end

	if mod:get("show_distance") == nil then
		mod:set("show_distance", true)
	end

	if mod:get("three_mins_to_go") == nil then
		mod:set("three_mins_to_go", false)
	end

	if mod:get("field_of_view") == nil then
		mod:set("field_of_view", false)
	end

	if mod:get("hide_if_close_to_exit_location") == nil then
		mod:set("hide_if_close_to_exit_location", true)
	end

	if mod:get("warn_early_evacuation") == nil then
		mod:set("warn_early_evacuation", true)
	end

	if mod.save then
		pcall(mod.save, mod)
	end
end

local function show_distance()
	return mod:get("show_distance") == true
end

local function marker_world_position(marker)
	if not marker then
		return nil
	end

	local world_position = marker.world_position or marker.position

	if world_position then
		return vector_from_box(world_position) or world_position
	end

	if marker.unit and alive_unit(marker.unit) then
		return interaction_unit_position(marker.unit)
	end

	return current_marker_target and current_marker_target.position or nil
end

local function local_camera_context()
	local player = local_player()
	local viewport_name = player and player.viewport_name or nil
	local camera_manager = Managers and Managers.state and Managers.state.camera or nil

	if not viewport_name or not camera_manager then
		return nil
	end

	if type(camera_manager.has_camera) == "function" then
		local ok_has_camera, has_camera = pcall(camera_manager.has_camera, camera_manager, viewport_name)

		if ok_has_camera and not has_camera then
			return nil
		end
	end

	local ok_position, camera_position = pcall(camera_manager.camera_position, camera_manager, viewport_name)
	local ok_rotation, camera_rotation = pcall(camera_manager.camera_rotation, camera_manager, viewport_name)

	if not ok_position or not ok_rotation or not camera_position or not camera_rotation then
		return nil
	end

	local vertical_fov = math.rad(65)

	if type(camera_manager.fov) == "function" then
		local ok_fov, fov = pcall(camera_manager.fov, camera_manager, viewport_name)

		if ok_fov and type(fov) == "number" and fov > 0 then
			vertical_fov = fov
		end
	end

	local width = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width or 1920
	local height = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height or 1080
	local aspect_ratio = width / math.max(height, 1)
	local tan_half_vertical = math.tan(vertical_fov * 0.5)

	return {
		position = camera_position,
		forward = Quaternion.forward(camera_rotation),
		right = Quaternion.right(camera_rotation),
		up = Quaternion.up(camera_rotation),
		tan_half_vertical = tan_half_vertical,
		tan_half_horizontal = tan_half_vertical * aspect_ratio,
	}
end

local function marker_inside_field_of_view(marker)
	if not option_field_of_view_enabled() then
		return true
	end

	local position = marker_world_position(marker)
	local camera = local_camera_context()

	if not position or not camera then
		return true
	end

	local dx = position.x - camera.position.x
	local dy = position.y - camera.position.y
	local dz = position.z - camera.position.z
	local view_x = dx * camera.right.x + dy * camera.right.y + dz * camera.right.z
	local view_y = dx * camera.up.x + dy * camera.up.y + dz * camera.up.z
	local view_z = dx * camera.forward.x + dy * camera.forward.y + dz * camera.forward.z

	if view_z <= 0.05 then
		return false
	end

	local ndc_x = view_x / (view_z * camera.tan_half_horizontal)
	local ndc_y = view_y / (view_z * camera.tan_half_vertical)

	return math.abs(ndc_x) <= 1 and math.abs(ndc_y) <= 1
end

local function marker_close_to_player(marker)
	if not option_hide_close_enabled() then
		return false
	end

	local marker_position = marker_world_position(marker)
	local player_position = local_player_position()

	if not marker_position or not player_position then
		return false
	end

	return distance_between(marker_position, player_position) <= CLOSE_HIDE_DISTANCE
end

local function marker_visible(marker)
	return option_use_exit_icon_enabled() and display_allowed_by_timer() and marker_inside_field_of_view(marker) and not marker_close_to_player(marker)
end

local function update_marker_widget(widget, marker, marker_template)
	local data = marker.data or {}
	local kind = data.kind or current_marker_kind or "exit"
	local icon = kind == "extraction" and EXTRACTION_ICON or EXIT_ICON
	local colour = marker_colour(kind)
	local distance_colour = marker_distance_colour(kind)
	local content = widget.content
	local style = widget.style
	local distance = marker.distance or content.distance

	local visible = marker_visible(marker)

	widget.visible = true
	content.icon = icon
	content.distance_text = visible and show_distance() and distance and distance > 1 and tostring(math.floor(distance + 0.5)) .. "m" or ""
	style.icon_shadow.color = visible and SHADOW or INVISIBLE
	style.icon.color = visible and colour or INVISIBLE
	style.distance_shadow.text_color = visible and DISTANCE_SHADOW or INVISIBLE
	style.distance_text.text_color = visible and distance_colour or INVISIBLE
	marker_template.max_distance = MARKER_MAX_DISTANCE
	marker.scale = 1
	marker.ignore_scale = true
end

local function create_marker_template()
	local font_settings = UIFontSettings.hud_body
	local template = {}

	template.name = MARKER_TYPE
	template.size = { 96, 96 }
	template.unit_node = "ui_interaction_marker"
	template.position_offset = { 0, 0, 1.2 }
	template.max_distance = MARKER_MAX_DISTANCE
	template.screen_clamp = true
	template.screen_margins = {
		down = 0.18,
		left = 0.18,
		right = 0.18,
		up = 0.18,
	}
	template.check_line_of_sight = false
	template.using_smart_tag_system = false
	template.scale_settings = {
		distance_min = 0,
		distance_max = MARKER_MAX_DISTANCE,
		scale_from = 1,
		scale_to = 1,
	}
	template.fade_settings = nil

	template.create_widget_defintion = function(_, scenegraph_id)
		return UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "icon_shadow",
				value = EXIT_ICON,
				value_id = "icon",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					offset = { 2, 2, 0 },
					size = { 58, 58 },
					color = SHADOW,
				},
			},
			{
				pass_type = "texture",
				style_id = "icon",
				value = EXIT_ICON,
				value_id = "icon",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					offset = { 0, 0, 1 },
					size = { 58, 58 },
					color = GREEN,
				},
			},
			{
				pass_type = "text",
				style_id = "distance_shadow",
				value = "",
				value_id = "distance_text",
				style = {
					font_type = font_settings.font_type,
					font_size = 20,
					text_horizontal_alignment = "center",
					text_vertical_alignment = "center",
					horizontal_alignment = "center",
					vertical_alignment = "center",
					offset = { 2, 42, 2 },
					size = { 160, 32 },
					text_color = DISTANCE_SHADOW,
				},
			},
			{
				pass_type = "text",
				style_id = "distance_text",
				value = "",
				value_id = "distance_text",
				style = {
					font_type = font_settings.font_type,
					font_size = 20,
					text_horizontal_alignment = "center",
					text_vertical_alignment = "center",
					horizontal_alignment = "center",
					vertical_alignment = "center",
					offset = { 0, 40, 3 },
					size = { 160, 32 },
					text_color = DISTANCE_TEXT,
				},
			},
		}, scenegraph_id)
	end

	template.on_enter = function(widget, marker, marker_template)
		update_marker_widget(widget, marker, marker_template)
	end

	template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
		update_marker_widget(widget, marker, marker_template)
	end

	return template
end

ensure_marker_template = function()
	local world_markers = world_markers_element()

	if not world_markers or not world_markers._marker_templates then
		return false
	end

	if not world_markers._marker_templates[MARKER_TYPE] then
		world_markers._marker_templates[MARKER_TYPE] = create_marker_template()
	end

	return true
end

local function request_immediate_refresh()
	scan_miss_count = 0
	force_state_update = true
	last_state_update_t = -999

	if not option_use_exit_icon_enabled() then
		remove_current_marker()
		return
	end

	if not update_runtime() or not ensure_marker_template() then
		return
	end

	refresh_runtime_state(0, true)

	local target = current_cached_target() or current_marker_target

	if target then
		request_marker(target)
		return
	end

	force_scan = true
	force_state_update = true
	last_state_update_t = -999
	last_scan_t = -999
	refresh_target(0)
end


local function option_display_name(key)
	local ok, value = pcall(function()
		return mod:localize(key)
	end)

	if ok and type(value) == "string" then
		return value
	end

	return key
end

local function child_options_visible()
	return mod:get("use_exit_icon") == true
end

local function patch_options_templates(options_templates)
	local settings = options_templates and options_templates.settings

	if type(settings) ~= "table" then
		return
	end

	local parent_names = {
		[option_display_name("use_exit_icon")] = true,
		["Use Exit Icon"] = true,
		["Use Exit Icons"] = true,
	}
	local child_names = {
		[option_display_name("show_distance")] = true,
		[option_display_name("three_mins_to_go")] = true,
		[option_display_name("field_of_view")] = true,
		[option_display_name("hide_if_close_to_exit_location")] = true,
	}
	local target_category = nil

	for i = 1, #settings do
		local setting = settings[i]

		if setting and parent_names[setting.display_name] then
			target_category = setting.category
			break
		end
	end

	if not target_category then
		return
	end

	for i = 1, #settings do
		local setting = settings[i]

		if setting and setting.category == target_category and child_names[setting.display_name] then
			setting.validation_function = child_options_visible
			setting.indentation_level = math.max(1, setting.indentation_level or 0)
		end
	end
end

local function register_early_evacuation_warning_hud()
	if mod._salvage_early_evacuation_warning_hud_registered or type(mod.register_hud_element) ~= "function" then
		return
	end

	mod._salvage_early_evacuation_warning_hud_registered = true
	mod:register_hud_element({
		class_name = EARLY_EVACUATION_WARNING_HUD_CLASS,
		filename = EARLY_EVACUATION_WARNING_HUD_FILE,
		visibility_groups = {
			"alive",
		},
		use_hud_scale = true,
	})
end

local function hook_dmf_option_generation()
	if mod._salvage_exits_options_hooked then
		return
	end

	local dmf = get_mod("DMF")

	if not dmf or type(dmf.create_mod_options_settings) ~= "function" then
		return
	end

	mod._salvage_exits_options_hooked = true

	mod:hook(dmf, "create_mod_options_settings", function(func, self, options_templates)
		local result = func(self, options_templates)

		patch_options_templates(result or options_templates)

		return result
	end)
end

function exits.on_all_mods_loaded()
	normalise_settings_once()
	register_early_evacuation_warning_hud()
	hook_dmf_option_generation()
end

function exits.on_setting_changed(setting_id)
	if setting_id == "use_exit_icon" then
		request_immediate_refresh()
	elseif setting_id == "show_distance" or setting_id == "three_mins_to_go" or setting_id == "field_of_view" or setting_id == "hide_if_close_to_exit_location" then
		if option_use_exit_icon_enabled() then
			request_immediate_refresh()
		end
	elseif setting_id == "warn_early_evacuation" and mod:get("warn_early_evacuation") ~= true and Managers and Managers.event then
		Managers.event:trigger("salvage_clear_early_evacuation_warning", EARLY_EVACUATION_WARNING_ID)
	end
end

if CLASS and CLASS.GameModeExpedition then
	mod:hook_safe(CLASS.GameModeExpedition, "on_gameplay_post_init", function()
		mod.in_expedition = true
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
	end)

	mod:hook_safe(CLASS.GameModeExpedition, "mission_cleanup", function()
		remove_current_marker()
		mod.in_expedition = false
		current_runtime_key = nil
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
	end)

	mod:hook_safe(CLASS.GameModeExpedition, "destroy", function()
		remove_current_marker()
		mod.in_expedition = false
		current_runtime_key = nil
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
	end)

	mod:hook_safe(CLASS.GameModeExpedition, "complete", function()
		remove_current_marker()
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
	end)

	mod:hook_safe(CLASS.GameModeExpedition, "fail", function()
		remove_current_marker()
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
	end)
end

if CLASS and CLASS.StateGameplay then
	mod:hook_safe(CLASS.StateGameplay, "on_enter", function()
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
		last_scan_t = -999
	end)

	mod:hook_safe(CLASS.StateGameplay, "on_exit", function()
		remove_current_marker()
		mod.in_expedition = false
		current_runtime_key = nil
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
	end)
end

if CLASS and CLASS.Interactable then
	mod:hook_safe(CLASS.Interactable, "interactable_set_used", function()
		if mod.in_expedition and option_use_exit_icon_enabled() then
			force_scan = true
			force_state_update = true
			last_state_update_t = -999
		end
	end)

	mod:hook_safe(CLASS.Interactable, "interactable_disable", function()
		if mod.in_expedition and option_use_exit_icon_enabled() then
			force_scan = true
			force_state_update = true
			last_state_update_t = -999
		end
	end)

	mod:hook_safe(CLASS.Interactable, "interactable_disable_local", function()
		if mod.in_expedition and option_use_exit_icon_enabled() then
			force_scan = true
			force_state_update = true
			last_state_update_t = -999
		end
	end)
end


if CLASS and CLASS.LuggableExtension then
	mod:hook_safe(CLASS.LuggableExtension, "set_carried_by", function(self)
		if mod.in_expedition and option_use_exit_icon_enabled() then
			cached_local_reliquary_carried = local_player_carrying_reliquary()
			request_immediate_refresh()
		end
	end)
end

if CLASS and CLASS.MissionObjectiveSystem then
	mod:hook_safe(CLASS.MissionObjectiveSystem, "start_mission_objective", function(_, objective_name)
		try_warn_early_evacuation(objective_name)

		if mod.in_expedition and option_use_exit_icon_enabled() then
			request_immediate_refresh()
		end
	end)

	mod:hook_safe(CLASS.MissionObjectiveSystem, "end_mission_objective", function()
		if mod.in_expedition and option_use_exit_icon_enabled() then
			request_immediate_refresh()
		end
	end)
end

if CLASS and CLASS.HudElementWorldMarkers then
	mod:hook_safe(CLASS.HudElementWorldMarkers, "_calculate_markers", function(self, dt, t)
		normalise_settings_once()

		if not option_use_exit_icon_enabled() then
			remove_current_marker()
			return
		end

		if not update_runtime() then
			return
		end

		if not ensure_marker_template() then
			return
		end

		update_pending_marker()

		local now = t or 0

		refresh_runtime_state(now, false)

		local target = current_cached_target()

		if target then
			scan_miss_count = 0
			force_scan = false
			current_marker_target = target
			current_marker_kind = target.kind
			current_marker_key = target_key(target)

			if current_marker_id == nil or current_marker_id == PENDING_MARKER or not marker_is_live(current_marker_id) then
				if now - last_marker_retry_t >= MARKER_RETRY_INTERVAL then
					last_marker_retry_t = now
					request_marker(target)
				end
			end
		elseif force_scan or now - last_scan_t >= TARGET_DISCOVERY_INTERVAL then
			refresh_target(now)
		end
	end)
end
function exits.on_game_state_changed(status)
	if status == "exit" then
		remove_current_marker()
		mod.in_expedition = false
		current_runtime_key = nil
		cached_target_after_activation = nil
		cached_timer_remaining = nil
		cached_local_reliquary_carried = false
		cached_sanctuary_defend_active = false
		cached_extraction_alert_active = false
		sanctuary_defend_latched = false
		marker_colour_latched = nil
		early_evacuation_warning_latch_key = nil
		scan_miss_count = 0
		force_scan = true
		force_state_update = true
		last_state_update_t = -999
	end
end

function exits.on_unload()
	remove_current_marker()
	mod.in_expedition = false
	current_runtime_key = nil
	cached_target_after_activation = nil
	cached_timer_remaining = nil
	cached_local_reliquary_carried = false
	cached_sanctuary_defend_active = false
	cached_extraction_alert_active = false
	sanctuary_defend_latched = false
	marker_colour_latched = nil
	early_evacuation_warning_latch_key = nil
	scan_miss_count = 0
	force_scan = true
	force_state_update = true
	last_state_update_t = -999
end

function exits.on_disabled()
	exits.on_unload()
end

return exits
