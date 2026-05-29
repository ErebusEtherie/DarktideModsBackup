-- valkyrie.lua
local mod = get_mod("valkyrie")
local Missions = require("scripts/settings/mission/mission_templates")
local Danger = require("scripts/utilities/danger")
local MissionIntroViewSettings = require("scripts/ui/views/mission_intro_view/mission_intro_view_settings")
local UIProfileSpawner = require("scripts/managers/ui/ui_profile_spawner")
local MasterItems = require("scripts/backend/master_items")
local ProfileUtils = require("scripts/utilities/profile_utils")
local ScriptWorld = require("scripts/foundation/utilities/script_world")
local view_loader_ok, ViewLoader = pcall(require, "scripts/loading/loaders/view_loader")
if not view_loader_ok then
	ViewLoader = nil
end

local COL_PRIMARY_START = "{#color(116,143,57)}"
local COL_MISSION_START = "{#color(3, 140, 103)}"
local COL_END = "{#reset()}"
local MAX_VALKYRIE_OCCUPANTS = 4
local STEADY_CAMERA_FORWARD_OFFSET = -1.2
local STEADY_CAMERA_VERTICAL_FOV = math.rad(43)
local REPORT_VALKYRIE_START = "valkyrie_start"
local REPORT_MISSION_START = "mission_start"
local REPORT_NONE = "none"
local SHOW_WHO_DEFAULT = "default"
local SHOW_WHO_NO_ONE = "no_one"
local SHOW_WHO_ONLY_ME = "only_me"
local EXPERIMENTAL_NONE = "none"
local EXPERIMENTAL_EXTRA_BOTS = "extra_bots"
local EXPERIMENTAL_NO_UNIFORMS = "no_uniforms"
local EXPERIMENTAL_WEAPON_PRESENTATION = "weapon_presentation"
local report_sent = false
local mission_name = "Unknown"
local difficulty = "Unknown"
local in_lobby = false
local silent_mode = true
local start_is_expedition = false
local in_mission_intro = false
local active_intro_view = nil
local original_ignored_slots = table.clone(MissionIntroViewSettings.ignored_slots)
local ignored_slots_without_weapons = nil
local temp_sorted_players = {}
local temp_seen_players = {}
local current_intro_local_unique_id = nil
local fallback_intro_bots = {}
local empty_uniform_items = {}
local no_uniform_profile_cache = setmetatable({}, { __mode = "k" })
local active_intro_spawners = setmetatable({}, { __mode = "k" })
local steady_camera_locked_unit = nil
local steady_camera_locked_position = nil
local steady_camera_locked_rotation = nil
local steady_camera_locked_fov = nil
local weapon_slots = { slot_primary = true }
local no_uniform_slots = {
	slot_gear_upperbody = "content/items/characters/player/human/gear_upperbody/empty_upperbody",
	slot_gear_lowerbody = "content/items/characters/player/human/gear_lowerbody/empty_lowerbody",
	slot_gear_head = "content/items/characters/player/human/gear_head/empty_headgear",
	slot_gear_extra_cosmetic = "content/items/characters/player/human/backpacks/empty_backpack",
}
local brief_patterns = {
	"mission_.*_brief.*",
	"mission_.*_briefing.*",
	"mission_brief.*",
	"expedition_.*_brief.*",
	"expedition_.*_briefing.*",
	"expedition_brief.*",
}

local function get_option(setting_id, default_value)
	local value = mod:get(setting_id)
	if value == nil then
		return default_value
	end
	return value
end

local function get_mechanism_data()
	local mech = Managers.mechanism and Managers.mechanism._mechanism
	return mech and mech._mechanism_data
end

local function is_expedition_start(data)
	return data and (data.expedition_template_name ~= nil or data.node_id ~= nil) or false
end

local show_who_values = {
	[SHOW_WHO_DEFAULT] = SHOW_WHO_DEFAULT,
	[SHOW_WHO_NO_ONE] = SHOW_WHO_NO_ONE,
	[SHOW_WHO_ONLY_ME] = SHOW_WHO_ONLY_ME,
	["ShowWhoDefault"] = SHOW_WHO_DEFAULT,
	["ShowWhoNoOne"] = SHOW_WHO_NO_ONE,
	["ShowWhoOnlyMe"] = SHOW_WHO_ONLY_ME,
	["Default"] = SHOW_WHO_DEFAULT,
	["No one"] = SHOW_WHO_NO_ONE,
	["Only me"] = SHOW_WHO_ONLY_ME,
	[1] = SHOW_WHO_DEFAULT,
	[2] = SHOW_WHO_NO_ONE,
	[3] = SHOW_WHO_ONLY_ME,
	["1"] = SHOW_WHO_DEFAULT,
	["2"] = SHOW_WHO_NO_ONE,
	["3"] = SHOW_WHO_ONLY_ME,
}

local experimental_values = {
	[EXPERIMENTAL_NONE] = EXPERIMENTAL_NONE,
	[EXPERIMENTAL_EXTRA_BOTS] = EXPERIMENTAL_EXTRA_BOTS,
	[EXPERIMENTAL_NO_UNIFORMS] = EXPERIMENTAL_NO_UNIFORMS,
	[EXPERIMENTAL_WEAPON_PRESENTATION] = EXPERIMENTAL_WEAPON_PRESENTATION,
	["ExperimentalNone"] = EXPERIMENTAL_NONE,
	["ExperimentalExtraBots"] = EXPERIMENTAL_EXTRA_BOTS,
	["ExperimentalNoUniforms"] = EXPERIMENTAL_NO_UNIFORMS,
	["ExperimentalWeaponPresentation"] = EXPERIMENTAL_WEAPON_PRESENTATION,
	["None"] = EXPERIMENTAL_NONE,
	["Extra bots"] = EXPERIMENTAL_EXTRA_BOTS,
	["No uniforms"] = EXPERIMENTAL_NO_UNIFORMS,
	["Weapon presentation"] = EXPERIMENTAL_WEAPON_PRESENTATION,
	[1] = EXPERIMENTAL_NONE,
	[2] = EXPERIMENTAL_EXTRA_BOTS,
	[3] = EXPERIMENTAL_NO_UNIFORMS,
	[4] = EXPERIMENTAL_WEAPON_PRESENTATION,
	["1"] = EXPERIMENTAL_NONE,
	["2"] = EXPERIMENTAL_EXTRA_BOTS,
	["3"] = EXPERIMENTAL_NO_UNIFORMS,
	["4"] = EXPERIMENTAL_WEAPON_PRESENTATION,
}

local function current_show_who()
	return show_who_values[mod:get("show_who")] or SHOW_WHO_DEFAULT
end

local function current_experimental()
	return experimental_values[mod:get("experimental")] or EXPERIMENTAL_NONE
end

local function should_no_uniform()
	if not mod:is_enabled() or current_experimental() ~= EXPERIMENTAL_NO_UNIFORMS then
		return false
	end
	local show_who = current_show_who()
	return show_who == SHOW_WHO_DEFAULT or show_who == SHOW_WHO_ONLY_ME
end

local function should_silence_expedition()
	return start_is_expedition and mod:get("silence_expeditions")
end

local function should_block_briefing()
	return mod:is_enabled() and silent_mode
end

local function is_hub()
	local game_mode_manager = Managers.state and Managers.state.game_mode
	return game_mode_manager and game_mode_manager:game_mode_name() == "hub"
end

local function should_show_no_one()
	return current_show_who() == SHOW_WHO_NO_ONE
end

local function should_show_me_only()
	return current_show_who() == SHOW_WHO_ONLY_ME
end

local function should_show_bots()
	return mod:is_enabled() and current_show_who() == SHOW_WHO_DEFAULT and current_experimental() == EXPERIMENTAL_EXTRA_BOTS
end

local function should_show_weapon()
	if not mod:is_enabled() or current_experimental() ~= EXPERIMENTAL_WEAPON_PRESENTATION then
		return false
	end
	local show_who = current_show_who()
	return show_who == SHOW_WHO_DEFAULT or show_who == SHOW_WHO_ONLY_ME
end

local function should_steady_camera()
	return mod:is_enabled() and get_option("steady_camera", false)
end

local function is_expeditions_intro_level(intro_level)
	local levels = MissionIntroViewSettings.intro_levels_by_zone_id
	local expedition_level = levels and levels.expeditions
	return intro_level and expedition_level and intro_level.level_name == expedition_level.level_name
end

local function default_intro_level_with_package()
	local levels = MissionIntroViewSettings.intro_levels_by_zone_id
	local default_intro_level = levels and levels.default
	if not default_intro_level then
		return nil, nil
	end
	return default_intro_level, {
		is_level_package = true,
		name = default_intro_level.level_name,
	}
end

local function is_expedition_mission_name(mission_name)
	local mission = mission_name and Missions[mission_name]
	return mission and mission.zone_id == "expeditions"
end

local function should_force_default_intro_level(mission_name)
	return should_steady_camera() and (is_expedition_mission_name(mission_name) or is_expedition_start(get_mechanism_data()))
end

local function current_report_timing()
	return mod:get("report_timing") or REPORT_VALKYRIE_START
end

local function clear_steady_camera_state()
	steady_camera_locked_unit = nil
	steady_camera_locked_position = nil
	steady_camera_locked_rotation = nil
	steady_camera_locked_fov = nil
end

local function clear_intro_spawner_flags()
	for profile_spawner, _ in pairs(active_intro_spawners) do
		profile_spawner._valkyrie_intro_spawner = nil
		profile_spawner._valkyrie_weapon_slot = nil
		profile_spawner._request_wield_slot_id = nil
	end
	table.clear(active_intro_spawners)
end

local function reset_intro_visual_state()
	in_mission_intro = false
	active_intro_view = nil
	current_intro_local_unique_id = nil
	MissionIntroViewSettings.ignored_slots = original_ignored_slots
	clear_intro_spawner_flags()
	clear_steady_camera_state()
end

local function mark_intro_spawner(profile_spawner)
	if not profile_spawner then
		return
	end
	profile_spawner._valkyrie_intro_spawner = true
	active_intro_spawners[profile_spawner] = true
end

local function mark_intro_spawners(view)
	active_intro_view = view or active_intro_view
	local spawn_slots = view and view._spawn_slots
	if not spawn_slots then
		return
	end
	for i = 1, #spawn_slots do
		local slot = spawn_slots[i]
		mark_intro_spawner(slot and slot.profile_spawner)
	end
end

local function is_intro_spawner(profile_spawner)
	return in_mission_intro and profile_spawner and profile_spawner._valkyrie_intro_spawner and active_intro_spawners[profile_spawner] == true
end

local function should_apply_no_uniform_to_spawner(profile_spawner)
	return should_no_uniform() and is_intro_spawner(profile_spawner)
end

local function player_unique_id(player)
	return player and player.unique_id and player:unique_id()
end

local function player_profile(player)
	return player and player.profile and player:profile()
end

local function add_intro_player(players, seen, player, unique_id)
	if not player or #players >= MAX_VALKYRIE_OCCUPANTS then
		return
	end
	unique_id = unique_id or player_unique_id(player)
	if unique_id and not seen[unique_id] then
		players[#players + 1] = player
		seen[unique_id] = true
	end
end

local function is_human_player(player)
	return player and player.is_human_controlled and player:is_human_controlled()
end

local function local_player_id(player_manager)
	local local_player = player_manager and player_manager.local_player and player_manager:local_player(1)
	return local_player, player_unique_id(local_player)
end

local function is_local_player(player)
	local local_unique_id = current_intro_local_unique_id
	if local_unique_id == nil then
		local _, resolved_local_unique_id = local_player_id(Managers.player)
		local_unique_id = resolved_local_unique_id
	end
	return local_unique_id ~= nil and player_unique_id(player) == local_unique_id
end

local function fallback_bot_player(index)
	local cached = fallback_intro_bots[index]
	if cached then
		return cached
	end
	local profile_name = "bot_" .. tostring(index)
	local ok, profile = pcall(ProfileUtils.get_bot_profile, profile_name)
	if not ok or not profile then
		return nil
	end
	profile.identifier = profile.identifier or profile_name
	local player = {}
	function player:unique_id()
		return "valkyrie_intro_" .. profile_name
	end
	function player:profile()
		return profile
	end
	function player:slot()
		return 1000 + index
	end
	function player:is_human_controlled()
		return false
	end
	function player:breed_name()
		local archetype = profile.archetype
		return archetype and archetype.breed or "human"
	end
	fallback_intro_bots[index] = player
	return player
end

local function should_show_player_in_intro(player)
	if not mod:is_enabled() then
		return true
	end
	if should_show_no_one() then
		return false
	end
	if should_show_me_only() then
		return is_local_player(player)
	end
	if not should_show_bots() and not is_human_player(player) then
		return false
	end
	return true
end

local function collect_local_intro_player(player_manager)
	local local_player, local_unique_id = local_player_id(player_manager)
	if local_player and should_show_player_in_intro(local_player) then
		add_intro_player(temp_sorted_players, temp_seen_players, local_player, local_unique_id)
	end
end

local function collect_human_intro_players(player_manager)
	local all_players = player_manager.players and player_manager:players()
	if all_players then
		for unique_id, player in pairs(all_players) do
			if is_human_player(player) and should_show_player_in_intro(player) then
				add_intro_player(temp_sorted_players, temp_seen_players, player, unique_id)
			end
		end
		return
	end
	local human_players = player_manager.human_players and player_manager:human_players()
	if human_players then
		for unique_id, player in pairs(human_players) do
			if should_show_player_in_intro(player) then
				add_intro_player(temp_sorted_players, temp_seen_players, player, unique_id)
			end
		end
	end
end

local function collect_real_bot_intro_players(player_manager)
	if not should_show_bots() or not player_manager.bot_players then
		return
	end
	local bot_players = player_manager:bot_players()
	for unique_id, player in pairs(bot_players) do
		if #temp_sorted_players >= MAX_VALKYRIE_OCCUPANTS then
			return
		end
		if should_show_player_in_intro(player) then
			add_intro_player(temp_sorted_players, temp_seen_players, player, unique_id)
		end
	end
end

local function fill_intro_with_fallback_bots()
	if not should_show_bots() then
		return
	end
	local index = 1
	while #temp_sorted_players < MAX_VALKYRIE_OCCUPANTS and index <= MAX_VALKYRIE_OCCUPANTS do
		local player = fallback_bot_player(index)
		if player then
			add_intro_player(temp_sorted_players, temp_seen_players, player)
		end
		index = index + 1
	end
end

local function collect_intro_players(player_manager)
	table.clear(temp_sorted_players)
	table.clear(temp_seen_players)
	local _, local_unique_id = local_player_id(player_manager)
	current_intro_local_unique_id = local_unique_id
	if not player_manager then
		return
	end
	if should_show_me_only() then
		collect_local_intro_player(player_manager)
		return
	end
	collect_local_intro_player(player_manager)
	collect_human_intro_players(player_manager)
	collect_real_bot_intro_players(player_manager)
	fill_intro_with_fallback_bots()
end

local function get_ignored_slots_without_weapons()
	if ignored_slots_without_weapons then
		return ignored_slots_without_weapons
	end
	ignored_slots_without_weapons = {}
	for i = 1, #original_ignored_slots do
		local slot_name = original_ignored_slots[i]
		if not weapon_slots[slot_name] then
			ignored_slots_without_weapons[#ignored_slots_without_weapons + 1] = slot_name
		end
	end
	return ignored_slots_without_weapons
end

local function preferred_weapon_slot(player)
	local profile = player_profile(player)
	local loadout = profile and profile.loadout
	if loadout and loadout.slot_primary then
		return "slot_primary"
	end
end

local function unit_alive(unit)
	return unit and Unit and Unit.alive(unit)
end

local function force_unit_visible(unit)
	if not unit_alive(unit) then
		return
	end
	Unit.set_unit_visibility(unit, true, true)
	Unit.flow_event(unit, "lua_visible")
end

local function force_unit_hidden(unit)
	if not unit_alive(unit) then
		return
	end
	Unit.set_unit_visibility(unit, false, true)
	Unit.flow_event(unit, "lua_hidden")
end

local function update_attachment_units(attachments_by_unit_3p, unit_3p, visible)
	local attachments = attachments_by_unit_3p and unit_3p and attachments_by_unit_3p[unit_3p]
	if not attachments then
		return
	end
	for i = 1, #attachments do
		if visible then
			force_unit_visible(attachments[i])
		else
			force_unit_hidden(attachments[i])
		end
	end
end

local function force_slot_visible(slot)
	if not slot then
		return
	end
	slot.wants_hidden_by_gameplay_3p = false
	slot.hidden_3p = false
	force_unit_visible(slot.unit_3p)
	update_attachment_units(slot.attachments_by_unit_3p, slot.unit_3p, true)
end

local function force_slot_hidden(slot)
	if not slot then
		return
	end
	slot.wants_hidden_by_gameplay_3p = true
	slot.hidden_3p = true
	force_unit_hidden(slot.unit_3p)
	update_attachment_units(slot.attachments_by_unit_3p, slot.unit_3p, false)
end

local function unignore_intro_weapons(profile_spawner)
	if not profile_spawner or not profile_spawner._ignored_slots then
		return
	end
	for slot_name, _ in pairs(weapon_slots) do
		profile_spawner._ignored_slots[slot_name] = nil
	end
	if profile_spawner._update_ingore_slots then
		profile_spawner:_update_ingore_slots()
	end
end

local function hide_intro_weapons(profile_spawner)
	local spawn_data = profile_spawner and profile_spawner._character_spawn_data
	local slots = spawn_data and spawn_data.slots
	if not slots then
		return
	end
	profile_spawner._valkyrie_weapon_slot = nil
	profile_spawner._request_wield_slot_id = nil
	for slot_name, _ in pairs(weapon_slots) do
		force_slot_hidden(slots[slot_name])
	end
end

local function apply_intro_weapon_to_spawner(profile_spawner, slot_name)
	if should_no_uniform() then
		hide_intro_weapons(profile_spawner)
		return
	end
	if not should_show_weapon() or not profile_spawner or not slot_name then
		return
	end
	unignore_intro_weapons(profile_spawner)
	profile_spawner._request_wield_slot_id = slot_name
	profile_spawner._valkyrie_weapon_slot = slot_name
	local spawn_data = profile_spawner._character_spawn_data
	local slots = spawn_data and spawn_data.slots
	local weapon_slot = slots and slots[slot_name]
	if not weapon_slot then
		return
	end
	profile_spawner:wield_slot(slot_name)
	if profile_spawner._update_items_visibility then
		profile_spawner:_update_items_visibility()
	end
	spawn_data.wielded_slot = weapon_slot
	force_slot_visible(weapon_slot)
end

local function queue_intro_weapon(player, slot)
	if should_no_uniform() then
		hide_intro_weapons(slot and slot.profile_spawner)
		return nil
	end
	if not should_show_weapon() or not player or not slot then
		return nil
	end
	local slot_name = preferred_weapon_slot(player)
	local profile_spawner = slot.profile_spawner
	if slot_name and profile_spawner then
		unignore_intro_weapons(profile_spawner)
		profile_spawner._request_wield_slot_id = slot_name
		profile_spawner._valkyrie_weapon_slot = slot_name
		slot.weapon_slot_requested = slot_name
		return slot_name
	end
end

local function wield_intro_weapon(player, slot)
	if not player or not slot then
		return
	end
	if should_no_uniform() then
		hide_intro_weapons(slot.profile_spawner)
		return
	end
	local slot_name = slot.weapon_slot_requested or preferred_weapon_slot(player)
	apply_intro_weapon_to_spawner(slot.profile_spawner, slot_name)
end

local function wield_all_intro_weapons(self)
	local spawn_slots = self and self._spawn_slots
	if not spawn_slots then
		return
	end
	for i = 1, #spawn_slots do
		local slot = spawn_slots[i]
		if slot and slot.occupied and slot.profile_spawner then
			if should_no_uniform() then
				hide_intro_weapons(slot.profile_spawner)
			elseif should_show_weapon() and slot.player then
				wield_intro_weapon(slot.player, slot)
			end
		end
	end
end

local function intro_sort_value(player)
	local local_bonus = is_local_player(player) and -10000 or 0
	local bot_bonus = player:is_human_controlled() and 0 or 1000
	local ogryn_bonus = player:breed_name() == "ogryn" and 100 or 0
	return local_bonus + bot_bonus + ogryn_bonus + player:slot()
end

local function sort_intro_players(a, b)
	return intro_sort_value(a) < intro_sort_value(b)
end

local function empty_uniform_item(slot_name)
	if empty_uniform_items[slot_name] ~= nil then
		return empty_uniform_items[slot_name]
	end
	local item_path = no_uniform_slots[slot_name]
	local item = item_path and MasterItems.get_item(item_path)
	empty_uniform_items[slot_name] = item
	return item
end

local function clone_table(source)
	local clone = {}
	if source then
		for key, value in pairs(source) do
			clone[key] = value
		end
	end
	return clone
end

local function no_uniform_profile(profile)
	if not profile then
		return profile
	end
	local cached = no_uniform_profile_cache[profile]
	if cached then
		return cached
	end
	local new_profile = table.clone_instance and table.clone_instance(profile) or clone_table(profile)
	new_profile.loadout = clone_table(profile.loadout)
	new_profile.visual_loadout = clone_table(profile.visual_loadout)
	new_profile.loadout_item_ids = clone_table(profile.loadout_item_ids)
	new_profile.loadout_item_data = clone_table(profile.loadout_item_data)
	for slot_name, _ in pairs(no_uniform_slots) do
		local item = empty_uniform_item(slot_name)
		if item then
			new_profile.loadout[slot_name] = item
			new_profile.visual_loadout[slot_name] = item
			if new_profile.loadout_item_ids then
				new_profile.loadout_item_ids[slot_name] = item.name .. slot_name
			end
			if new_profile.loadout_item_data then
				new_profile.loadout_item_data[slot_name] = { id = item.name }
			end
		end
	end
	no_uniform_profile_cache[profile] = new_profile
	return new_profile
end

local function add_no_uniform_changed_items(changed_items, visual_loadout)
	local changed_clone = clone_table(changed_items)
	local visual_clone = clone_table(visual_loadout)
	for slot_name, _ in pairs(no_uniform_slots) do
		local item = empty_uniform_item(slot_name)
		if item then
			changed_clone[slot_name] = item
			visual_clone[slot_name] = item
		end
	end
	return changed_clone, visual_clone
end

local function refresh_mission_report_values(data)
	data = data or get_mechanism_data()
	if not data then
		return
	end
	local tpl = Missions[data.mission_name]
	mission_name = tpl and Localize(tpl.mission_name) or "Unknown"
	local diff = Danger.danger_by_difficulty(data.challenge, data.resistance) or {}
	difficulty = diff.display_name and Localize(diff.display_name) or "Unknown"
end

local function echo_mission_report()
	mod:echo(COL_PRIMARY_START .. "Mission: " .. COL_MISSION_START .. mission_name .. COL_END .. " " .. COL_PRIMARY_START .. "Difficulty: " .. COL_MISSION_START .. difficulty .. COL_END)
end

local function send_mission_report(timing)
	if report_sent or current_report_timing() ~= timing or timing == REPORT_NONE then
		return
	end
	echo_mission_report()
	report_sent = true
end

local function manual_mission_report()
	if is_hub() then
		mod:echo("This is the Mourningstar.")
		return
	end
	refresh_mission_report_values()
	echo_mission_report()
end

local function is_intro_world_spawner(world_spawner)
	return in_mission_intro and active_intro_view and world_spawner and active_intro_view._world_spawner == world_spawner
end

local function steady_camera_spawner()
	return active_intro_view and active_intro_view._world_spawner
end

local function steady_camera_active_for(world_spawner)
	return should_steady_camera() and is_intro_world_spawner(world_spawner)
end

local function steady_camera_camera(world_spawner)
	if not world_spawner then
		return nil, nil
	end
	local camera = world_spawner.camera and world_spawner:camera() or world_spawner._camera
	local camera_unit = world_spawner.camera_unit and world_spawner:camera_unit() or world_spawner._camera_unit
	return camera, camera_unit
end

local function set_world_spawner_camera(world_spawner, camera_unit, fov)
	if not world_spawner or not unit_alive(camera_unit) then
		return
	end
	local viewport = world_spawner._viewport
	if viewport then
		ScriptWorld.change_camera_unit(viewport, camera_unit, false)
	end
	local camera = Unit.camera(camera_unit, "camera")
	if not camera then
		return
	end
	Camera.set_data(camera, "unit", camera_unit)
	world_spawner._camera = camera
	world_spawner._camera_unit = camera_unit
	world_spawner._camera_animation_data = nil
	if fov then
		Camera.set_vertical_fov(camera, fov)
		world_spawner._start_camera_fov = math.deg(fov)
	end
end

local function steady_camera_pulled_position(position, rotation)
	return position + Quaternion.forward(rotation) * STEADY_CAMERA_FORWARD_OFFSET
end

local function steady_camera_spawn_centroid()
	local spawn_slots = active_intro_view and active_intro_view._spawn_slots
	if not spawn_slots or #spawn_slots == 0 then
		return nil
	end
	local position_sum = Vector3.zero()
	local count = 0
	local max_slots = math.min(MAX_VALKYRIE_OCCUPANTS, #spawn_slots)
	for i = 1, max_slots do
		local slot = spawn_slots[i]
		local spawn_point_unit = slot and slot.spawn_point_unit
		if unit_alive(spawn_point_unit) then
			position_sum = position_sum + Unit.world_position(spawn_point_unit, 1)
			count = count + 1
		end
	end
	if count == 0 then
		return nil
	end
	return position_sum * (1 / count)
end

local function steady_camera_can_lock(camera_unit)
	local centroid = steady_camera_spawn_centroid()
	if not centroid or not unit_alive(camera_unit) then
		return false
	end
	local camera_position = Unit.world_position(camera_unit, 1)
	local distance = Vector3.distance(camera_position, centroid)
	return distance <= 12
end

local function ensure_steady_camera(world_spawner)
	if not steady_camera_active_for(world_spawner) then
		return
	end
	if unit_alive(steady_camera_locked_unit) then
		return
	end
	local camera, camera_unit = steady_camera_camera(world_spawner)
	if not camera or not unit_alive(camera_unit) then
		return
	end
	if not steady_camera_can_lock(camera_unit) then
		return
	end
	local unit_spawner = world_spawner.unit_spawner and world_spawner:unit_spawner() or world_spawner._unit_spawner
	if not unit_spawner or not unit_spawner.spawn_unit then
		return
	end
	local rotation = Unit.world_rotation(camera_unit, 1)
	local position = steady_camera_pulled_position(Unit.world_position(camera_unit, 1), rotation)
	local fov = STEADY_CAMERA_VERTICAL_FOV
	local locked_unit = unit_spawner:spawn_unit("core/units/camera", position, rotation)
	if not unit_alive(locked_unit) then
		return
	end
	steady_camera_locked_unit = locked_unit
	steady_camera_locked_position = Vector3Box(position)
	steady_camera_locked_rotation = QuaternionBox(rotation)
	steady_camera_locked_fov = fov
	set_world_spawner_camera(world_spawner, locked_unit, fov)
end

local function apply_steady_camera()
	local world_spawner = steady_camera_spawner()
	if not steady_camera_active_for(world_spawner) then
		clear_steady_camera_state()
		return
	end
	ensure_steady_camera(world_spawner)
	if not unit_alive(steady_camera_locked_unit) or not steady_camera_locked_position or not steady_camera_locked_rotation then
		clear_steady_camera_state()
		return
	end
	local position = steady_camera_locked_position:unbox()
	local rotation = steady_camera_locked_rotation:unbox()
	Unit.set_local_position(steady_camera_locked_unit, 1, position)
	Unit.set_local_rotation(steady_camera_locked_unit, 1, rotation)
	set_world_spawner_camera(world_spawner, steady_camera_locked_unit, steady_camera_locked_fov)
end

mod:command("valk", "identifies mission via chat", manual_mission_report)

if CLASS.MissionIntroView and CLASS.MissionIntroView.select_target_intro_level then
	mod:hook(CLASS.MissionIntroView, "select_target_intro_level", function(func, mission_name, ...)
		local intro_level, intro_level_packages = func(mission_name, ...)
		if should_force_default_intro_level(mission_name) or is_expeditions_intro_level(intro_level) and should_steady_camera() then
			local default_intro_level, default_intro_level_packages = default_intro_level_with_package()
			if default_intro_level and default_intro_level_packages then
				return default_intro_level, default_intro_level_packages
			end
		end
		return intro_level, intro_level_packages
	end)
end

if ViewLoader and ViewLoader._get_dynamic_package_for_view then
	mod:hook(ViewLoader, "_get_dynamic_package_for_view", function(func, self, view_name, mission_name, ...)
		if view_name == "mission_intro_view" and should_force_default_intro_level(mission_name) then
			local _, default_intro_level_packages = default_intro_level_with_package()
			if default_intro_level_packages then
				return default_intro_level_packages
			end
		end
		return func(self, view_name, mission_name, ...)
	end)
end

if CLASS.MissionIntroView and CLASS.MissionIntroView._initialize_background_world then
	mod:hook(CLASS.MissionIntroView, "_initialize_background_world", function(func, self, ...)
		if should_force_default_intro_level() or is_expeditions_intro_level(self and self._intro_level) and should_steady_camera() then
			local default_intro_level = default_intro_level_with_package()
			if default_intro_level then
				self._intro_level = default_intro_level
				self._intro_level_theme = self._get_intro_level_theme and self._get_intro_level_theme(default_intro_level) or {}
				clear_steady_camera_state()
			end
		end
		return func(self, ...)
	end)
end

mod:hook("LevelTransitionHandler", "on_mission_start", function(func, self, key, params)
	report_sent = false
	silent_mode = true
	in_lobby = false
	start_is_expedition = false
	reset_intro_visual_state()
	return func(self, key, params)
end)

if CLASS.StateMainMenu and CLASS.StateMainMenu.event_continue_cb then
	mod:hook_safe(CLASS.StateMainMenu, "event_continue_cb", function()
		reset_intro_visual_state()
	end)
end

mod:hook_safe(CLASS.LobbyView, "on_enter", function()
	in_lobby = true
end)

if CLASS.LobbyView._setup_loadout_widgets then
	mod:hook_safe(CLASS.LobbyView, "_setup_loadout_widgets", function()
		in_lobby = true
	end)
end

mod:hook_safe(CLASS.LobbyView, "on_exit", function()
	if in_lobby and not mod:get("mute_lobby_mission") then
		silent_mode = false
	end
	in_lobby = false
end)

mod:hook_safe(CLASS.MissionIntroView, "on_enter", function(self)
	report_sent = false
	mission_name = "Unknown"
	difficulty = "Unknown"
	in_mission_intro = true
	active_intro_view = self
	table.clear(no_uniform_profile_cache)
	local data = get_mechanism_data()
	start_is_expedition = is_expedition_start(data)
	refresh_mission_report_values(data)
	if start_is_expedition then
		silent_mode = mod:get("silence_expeditions") and true or false
	end
	if should_silence_expedition() then
		self.mission_briefing_done = true
	end
	send_mission_report(REPORT_VALKYRIE_START)
end)

mod:hook_safe(CLASS.MissionIntroView, "event_register_mission_intro_camera", function(self)
	ensure_steady_camera(self and self._world_spawner)
end)

mod:hook(CLASS.MissionIntroView, "_setup_spawn_slots", function(func, self, ...)
	local old_ignored_slots = MissionIntroViewSettings.ignored_slots
	if should_show_weapon() then
		MissionIntroViewSettings.ignored_slots = get_ignored_slots_without_weapons()
	end
	local result = func(self, ...)
	MissionIntroViewSettings.ignored_slots = old_ignored_slots
	mark_intro_spawners(self)
	return result
end)

mod:hook(CLASS.MissionIntroView, "_assign_player_slots", function(func, self, ...)
	if not mod:is_enabled() then
		return func(self, ...)
	end
	mark_intro_spawners(self)
	if should_show_no_one() then
		return
	end
	local player_manager = Managers.player
	if not player_manager then
		return func(self, ...)
	end
	collect_intro_players(player_manager)
	if #temp_sorted_players > 1 then
		table.sort(temp_sorted_players, sort_intro_players)
	end
	local spawn_slots = self._spawn_slots
	local assigned_count = 0
	for i = 1, #temp_sorted_players do
		if assigned_count >= MAX_VALKYRIE_OCCUPANTS then
			break
		end
		local player = temp_sorted_players[i]
		if should_show_player_in_intro(player) then
			local unique_id = player_unique_id(player)
			local slot_id = unique_id and self:_player_slot_id(unique_id)
			local already_assigned = slot_id ~= nil
			if not slot_id then
				slot_id = player_profile(player) and self:_get_free_slot_id(player)
			end
			local slot = slot_id and spawn_slots[slot_id]
			if slot then
				assigned_count = assigned_count + 1
				mark_intro_spawner(slot.profile_spawner)
				queue_intro_weapon(player, slot)
				if not already_assigned then
					self:_assign_player_to_slot(player, slot)
				end
				wield_intro_weapon(player, slot)
			end
		end
	end
	wield_all_intro_weapons(self)
end)

mod:hook(CLASS.MissionIntroView, "_assign_player_to_slot", function(func, self, player, slot, ...)
	if not should_show_player_in_intro(player) then
		return
	end
	mark_intro_spawner(slot and slot.profile_spawner)
	queue_intro_weapon(player, slot)
	local result = func(self, player, slot, ...)
	wield_intro_weapon(player, slot)
	return result
end)

mod:hook(CLASS.MissionIntroView, "_update_player_slots", function(func, self, ...)
	local result = func(self, ...)
	mark_intro_spawners(self)
	wield_all_intro_weapons(self)
	return result
end)

mod:hook_safe(CLASS.MissionIntroView, "update", function(self)
	if should_silence_expedition() then
		self.mission_briefing_done = true
	end
	mark_intro_spawners(self)
	wield_all_intro_weapons(self)
	apply_steady_camera()
end)

if CLASS.MissionIntroView.destroy then
	mod:hook_safe(CLASS.MissionIntroView, "destroy", function()
		reset_intro_visual_state()
	end)
end

mod:hook_safe(CLASS.MissionIntroView, "on_exit", function()
	send_mission_report(REPORT_MISSION_START)
	silent_mode = true
	start_is_expedition = false
	reset_intro_visual_state()
end)

mod:hook(UIProfileSpawner, "spawn_profile", function(func, self, profile, position, rotation, scale, state_machine_or_nil, animation_event_or_nil, face_state_machine_key_or_nil, face_animation_event_or_nil, force_highest_mip_or_nil, disable_hair_state_machine_or_nil, optional_unit_3p, optional_ignore_state_machine, companion_data)
	if should_apply_no_uniform_to_spawner(self) then
		profile = no_uniform_profile(profile)
		self._valkyrie_weapon_slot = nil
		self._request_wield_slot_id = nil
	elseif is_intro_spawner(self) and should_show_weapon() then
		state_machine_or_nil = nil
		animation_event_or_nil = nil
	end
	return func(self, profile, position, rotation, scale, state_machine_or_nil, animation_event_or_nil, face_state_machine_key_or_nil, face_animation_event_or_nil, force_highest_mip_or_nil, disable_hair_state_machine_or_nil, optional_unit_3p, optional_ignore_state_machine, companion_data)
end)

if UIProfileSpawner._change_slot_items then
	mod:hook(UIProfileSpawner, "_change_slot_items", function(func, self, changed_items, loadout, visual_loadout, equipped_items_or_nil, ...)
		if should_apply_no_uniform_to_spawner(self) then
			changed_items, visual_loadout = add_no_uniform_changed_items(changed_items, visual_loadout)
			self._valkyrie_weapon_slot = nil
			self._request_wield_slot_id = nil
		end
		return func(self, changed_items, loadout, visual_loadout, equipped_items_or_nil, ...)
	end)
end

mod:hook(UIProfileSpawner, "assign_animation_event", function(func, self, animation_event, ...)
	if is_intro_spawner(self) and should_show_weapon() then
		apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
		return
	end
	local result = func(self, animation_event, ...)
	if self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self) then
		apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
	end
	return result
end)

mod:hook(UIProfileSpawner, "set_visibility", function(func, self, visible, ...)
	local result = func(self, visible, ...)
	if visible and (self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self)) then
		apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
	end
	return result
end)

mod:hook(UIProfileSpawner, "cb_on_unit_3p_streaming_complete", function(func, self, unit_3p, timeout, ...)
	local result = func(self, unit_3p, timeout, ...)
	if self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self) then
		apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
	end
	return result
end)

mod:hook_safe(UIProfileSpawner, "cb_on_unit_3p_streaming_complete_equip_item", function(self)
	if self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self) then
		apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
	end
end)

mod:hook(CLASS.MissionIntroView, "_play_mission_brief_vo", function(func, self, ...)
	if should_silence_expedition() then
		self.mission_briefing_done = true
		return
	end
	return func(self, ...)
end)

mod:hook("LocalWaitForMissionBriefingDoneState", "update", function(func, self, dt)
	if should_block_briefing() then
		return "mission_briefing_done"
	end
	return func(self, dt)
end)

mod:hook("DialogueExtension", "play_event", function(func, self, event)
	if should_block_briefing() and event.sound_event then
		for _, pat in ipairs(brief_patterns) do
			if event.sound_event:match(pat) then
				return
			end
		end
	end
	return func(self, event)
end)

mod:hook("DialogueSystemSubtitle", "add_playing_localized_dialogue", function(func, self, speaker, dialogue)
	if should_block_briefing() and dialogue.currently_playing_subtitle then
		for _, pat in ipairs(brief_patterns) do
			if dialogue.currently_playing_subtitle:match(pat) then
				return
			end
		end
	end
	return func(self, speaker, dialogue)
end)

mod:hook_safe(CLASS.MissionIntroView, "_set_hologram_briefing_material", function(self)
	if mod:is_enabled() and mod:get("hide_mission_screen") then
		local world = self._world_spawner and self._world_spawner._world
		if not world then
			return
		end
		local holo = World.unit_by_name(world, "valkyrie_hologram_prototype_01")
		if holo and Unit.alive(holo) then
			Unit.set_unit_visibility(holo, false)
		end
	end
end)
