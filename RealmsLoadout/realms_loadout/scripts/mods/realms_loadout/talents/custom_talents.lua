local ProfileMerge = get_mod("realms_loadout"):io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/profile_merge")
local mod = get_mod("realms_loadout")

local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local PlayerTalents = require("scripts/utilities/player_talents/player_talents")
local ProfileUtils = require("scripts/utilities/profile_utils")
local WorkspacePresets = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/workspace_presets")
local PresetStore = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/talent_preset_store")
local Promise = require("scripts/foundation/utilities/promise")
local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local TalentBuilderView = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/workspace_talent_view")
local InventoryBackgroundView = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/workspace_talent_adapter")

local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local TalentRules = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/talent_rules")
local TalentEffects = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/talent_effects")
TalentEffects.install(mod)
local AuraLoadout = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/aura_loadout")
local CharacterSheet = require("scripts/utilities/character_sheet")
local TalentSync = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_talent_sync")
-- Realms keeps one peer-joined/left callback per mod, so both RL protocols
-- subscribe through one shared dispatcher instead of replacing each other.
local PeerEvents = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_peer_events")
local TalentStatus = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/talent_status_ui")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Stimm = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/stimm")
local PROTOCOL_VERSION = TalentSync.VERSION
local BUILD_STORAGE_SETTING = "tamm_custom_talent_builds_v1"
local GUEST_BUILD_STORAGE_SETTING = "tamm_realms_talent_builds_v2"
local MIGRATION_SETTING = "tamm_wote_migration_v1"
local MAX_NETWORK_NODES = 160
local MIN_TALENT_POINTS = 30
local MAX_TALENT_POINTS = 99

local state = mod:persistent_table("tamm_custom_talents")
local talent_views = setmetatable({}, { __mode = "k" })
local inventory_views = setmetatable({}, { __mode = "k" })

state.connection = nil
state.host_reconcile_pending = true
state.host_reconcile_synchronizer = nil
state.host_rules_revision = state.host_rules_revision or 1
state.local_apply_signature = nil
state.local_apply_synchronizer = nil
state.local_official_profile_ref = nil
state.network_registered = false
state.official_bot_profiles = state.official_bot_profiles or {}
state.official_profiles = state.official_profiles or {}
state.official_ui_profiles = {}
state.pending_build_submit = false
state.remote_builds = {}
state.rules_broadcast_pending = false
state.session_rules = nil
state.suspended = false
state.allow_suspended_profile_restore = false
state.editor = nil
state.editor_refresh_pending = false
state.rules_host = nil
state.host_player_rules = {}
state.rules_serial = state.host_rules_revision
mod._realms_profile_writes_suspended = false

local function clone_map(source)
	local result = {}

	if type(source) == "table" then
		for key, value in pairs(source) do
			result[key] = value
		end
	end

	return result
end

local function normalize_peer_id(peer_id)
	return peer_id and string.lower(tostring(peer_id)) or nil
end

local function local_peer_id()
	local player = Managers.player and Managers.player:local_player_safe(1)
	return player and normalize_peer_id(player:peer_id())
end

local function setting_enabled(setting_id)
	return mod:is_enabled() and mod._settings[setting_id] == true
end

local function talent_points_setting(setting_id)
	local value = tonumber(mod._settings[setting_id]) or MIN_TALENT_POINTS
	local minimum = setting_id == "local_talent_points" and 0 or MIN_TALENT_POINTS

	return math.clamp(math.floor(value + 0.5), minimum, MAX_TALENT_POINTS)
end

local function profile_archetype_name(profile)
	local archetype = profile and profile.archetype

	return type(archetype) == "table" and archetype.name or archetype
end

local function profile_layout(profile)
	local archetype = profile and profile.archetype
	local layout_path = type(archetype) == "table" and archetype.talent_layout_file_path

	return layout_path and require(layout_path) or nil
end

local function profile_key(peer_id, local_player_id)
	return string.format("%s|%s", normalize_peer_id(peer_id) or "local", tostring(local_player_id or 1))
end

local function current_connection()
	local connection_manager = Managers.connection

	return connection_manager and (connection_manager._connection_host or connection_manager._connection_client) or nil
end

local function is_realms_host()
	local context = mod.session_context()

	return context.is_realms and context.is_realms_host
end

local function is_realms_client()
	local context = mod.session_context()

	return context.is_realms and context.is_realms_client
end

local function is_custom_talent_host_session()
	local context = mod.session_context()

	return context.is_solo_play or context.is_realms_host
end

local function local_scope_enabled()
	return setting_enabled("enable_custom_talent_points")
		and setting_enabled("enable_local_custom_talents")
end

local function local_official_ui_mode()
	local mode = mod._realms_profile_mode

	return mode == "switching_to_official" or mode == "official" or mode == "closing_official"
end

local function bot_scope_enabled()
	return setting_enabled("enable_custom_talent_points")
		and setting_enabled("enable_bot_custom_talents")
end

local function realms_scope_enabled()
	return setting_enabled("enable_custom_talent_points")
end

local function is_own_player(player)
	local player_manager = Managers.player
	local local_player = player_manager and player_manager:local_player_safe(1)

	return player ~= nil and player == local_player
end

local function received_host_rules()
	if state.network_role ~= "client" then return nil end
	local connection = Managers.connection
	local host = connection and normalize_peer_id(connection:host())
	if current_connection() == state.connection and host == state.rules_host then
		return state.session_rules
	end
	return nil
end

local function custom_talent_ui_enabled(player)
	if not is_own_player(player) then
		return false
	end

	if is_realms_client() then
		local rules = received_host_rules()
		-- Editing stays available during the handshake, using native limits.
		return not rules or rules.enabled == true
	end

	if not local_scope_enabled() then
		return false
	end

	local context = mod.session_context()
	local game_mode_name = context.game_mode_name
	local is_safe_edit_location = game_mode_name == "hub"
		or context.is_main_menu
		or game_mode_name == "prologue_hub"
		or game_mode_name == "shooting_range"
		or context.is_solo_play
		or context.is_realms_host

	return is_safe_edit_location
end

local configured_player_rules

local function custom_talent_ui_cap(player)
	if is_realms_client() then
		local rules = received_host_rules()

		return rules and rules.enabled and rules.realms_player_points or MIN_TALENT_POINTS
	end

	return is_realms_host() and configured_player_rules(local_peer_id()).realms_player_points
		or talent_points_setting("local_talent_points")
end

local function stimm_setting()
  return math.clamp(math.floor(tonumber(mod._settings.stimm_points) or 30), 0, 103)
end

local function local_selection_rules()
	return {
		stimm_points = stimm_setting(),
		unlock_all_auras = setting_enabled("unlock_all_auras"),
		unlock_all_keystones = setting_enabled("unlock_all_keystones"),
	}
end

configured_player_rules = function(peer)
	peer = normalize_peer_id(peer)
	local own = peer ~= nil and peer == local_peer_id()
	local override = is_realms_host() and state.host_player_rules[peer] or nil
	return {
		enabled = not state.network_closed and (own and local_scope_enabled() or not own and realms_scope_enabled()),
		stimm_points = override and override.stimm_points or stimm_setting(),
		realms_player_points = override and override.points or talent_points_setting("local_talent_points"),
		unlock_all_auras = override and override.auras or not override and setting_enabled("unlock_all_auras") or false,
		unlock_all_keystones = override and override.keystones or not override and setting_enabled("unlock_all_keystones") or false,
		revision = math.max(state.host_rules_revision, override and override.revision or 0),
	}
end

local function remote_selection_rules(peer)
	return configured_player_rules(peer)
end

local function selection_rules()
	if is_realms_client() then return received_host_rules() or {} end
	return is_realms_host() and configured_player_rules(local_peer_id()) or local_selection_rules()
end

local function owns_custom_editor(player)
	return not local_official_ui_mode()
		and is_own_player(player) and (is_realms_client() or custom_talent_ui_enabled(player))
end

local host_loadout
local function compatible_effects_context()
	local context = mod.session_context()
	return mod:is_enabled() and (context.is_solo_play or context.is_realms
		or custom_talent_ui_enabled(Managers.player and Managers.player:local_player_safe(1)))
end

mod:hook(CharacterSheet, "class_loadout", function(func, profile, destination, force_base, talents, mute_log)
	local context = mod.session_context()
	if mod:is_enabled() and not force_base and host_loadout then
		profile, talents = host_loadout(profile, talents)
	end
	if not force_base and type(talents) == "table" and profile and compatible_effects_context() then
		profile = TalentEffects.companion_profile(profile, talents, TalentRules)
	end
	-- Player initialization applies talents before GameplayStateRun resumes us.
	-- Suspension guards profile writes, not this read-only loadout conversion:
	-- supplied multi-aura talents must survive native aggregation during loading.
	if mod:is_enabled() and not force_base and type(talents) == "table"
		and profile and profile.archetype and profile.archetype.talent_layout_file_path
		and (profile.tamm_custom_talents or ((context.is_solo_play or context.is_realms
			or custom_talent_ui_enabled(Managers.player and Managers.player:local_player_safe(1)))
			and selection_rules().unlock_all_auras)) then
		return AuraLoadout.build(func, profile, destination, force_base, talents, mute_log)
	end
	return func(profile, destination, force_base, talents, mute_log)
end)

local function layout_node_maps(layout)
	local by_name = {}
	local talent_to_name = {}
	local nodes = layout and layout.nodes or {}

	for i = 1, #nodes do
		local node = nodes[i]

		by_name[node.widget_name] = node

		if node.talent and node.talent ~= "not_selected" then
			talent_to_name[node.talent] = node.widget_name
		end
	end

	return by_name, talent_to_name
end

local function points_spent(nodes_by_name, selected_nodes)
	local total = 0

	for widget_name, tier in pairs(selected_nodes) do
		local node = nodes_by_name[widget_name]

		if node then
			total = total + tier * (node.cost or 1)
		end
	end

	return total
end

local function points_spent_in_group(nodes_by_name, selected_nodes, group_name, excluded_widget_name)
	local total = 0

	for widget_name, tier in pairs(selected_nodes) do
		local node = nodes_by_name[widget_name]

		if node and node.group_name == group_name and widget_name ~= excluded_widget_name then
			total = total + tier * (node.cost or 1)
		end
	end

	return total
end

local function parent_unlocks_child(parent, selected_nodes)
	if not parent then
		return false
	end
	if parent.type == "start" then
		return true
	end

	local tier = selected_nodes[parent.widget_name]

	if not tier then
		return false
	end

	local requirements = parent.requirements or {}
	local unlock_points = requirements.children_unlock_points or 0

	return tier * (parent.cost or 1) >= unlock_points
end

local function reachable_nodes_from_start(selected_nodes, nodes_by_name)
	local reachable = {}
	local children_by_parent = {}
	local remaining_required_parents = {}
	local queue = {}

	for widget_name, node in pairs(nodes_by_name) do
		local parents = node.parents or {}

		remaining_required_parents[widget_name] = #parents

		for i = 1, #parents do
			local parent_name = parents[i]
			local children = children_by_parent[parent_name]

			if not children then
				children = {}
				children_by_parent[parent_name] = children
			end

			children[#children + 1] = widget_name
		end

		if node.type == "start" or #parents == 0 then
			reachable[widget_name] = true
			queue[#queue + 1] = widget_name
		end
	end

	-- Traverse every node and edge at most once. Talent layouts contain many
	-- converging paths, so recursively enumerating paths becomes exponential
	-- for large Bot autofill builds even when the graph itself is acyclic.
	local queue_index = 1

	while queue_index <= #queue do
		local parent_name = queue[queue_index]
		local parent = nodes_by_name[parent_name]

		queue_index = queue_index + 1

		if parent_unlocks_child(parent, selected_nodes) then
			local children = children_by_parent[parent_name] or {}

			for i = 1, #children do
				local child_name = children[i]

				if not reachable[child_name] then
					local child = nodes_by_name[child_name]
					local requirements = child and child.requirements or {}

					if requirements.all_parents_chosen == true then
						remaining_required_parents[child_name] = remaining_required_parents[child_name] - 1

						if remaining_required_parents[child_name] == 0 then
							reachable[child_name] = true
							queue[#queue + 1] = child_name
						end
					else
						reachable[child_name] = true
						queue[#queue + 1] = child_name
					end
				end
			end
		end
	end

	return reachable
end

local function validate_selected_nodes(profile, selected_nodes, cap, rules)
	local layout = profile_layout(profile)
	rules = rules or selection_rules()

	if not layout then
		return nil, "The current archetype has no talent layout"
	end
	if type(selected_nodes) ~= "table" then
		return nil, "Selected talent nodes are not a table"
	end

	local nodes_by_name, talent_to_name = layout_node_maps(layout)
	local sanitized = {}
	local selected_count = 0

	for widget_name, tier in pairs(selected_nodes) do
		selected_count = selected_count + 1

		if selected_count > MAX_NETWORK_NODES then
			return nil, "Selected talent node count exceeds the safety limit"
		end
		if type(widget_name) ~= "string" or type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 then
			return nil, "Selected talent node data is malformed"
		end

		local node = nodes_by_name[widget_name]

		if not node then
			return nil, "Selected talent node is not present in the current layout"
		end
		if node.type == "start" then
			return nil, "Starting nodes cannot be selected"
		end

		local cost = node.cost or 1
		local max_points = node.max_points or 0
		local node_points = cost == 0 and tier or tier * cost

		if node_points > max_points then
			return nil, "Selected talent node exceeds its point limit"
		end

		sanitized[widget_name] = tier
	end

	cap = math.clamp(math.floor(tonumber(cap) or MIN_TALENT_POINTS), 0, profile.rl_specialization and 103 or MAX_TALENT_POINTS)

	local total_points = points_spent(nodes_by_name, sanitized)

	if total_points > cap then
		return nil, string.format("Talent build spends %d points but the host allows %d", total_points, cap)
	end

	local exclusive_groups = {}
	local reachable_nodes = reachable_nodes_from_start(sanitized, nodes_by_name)

	for widget_name in pairs(sanitized) do
		local node = nodes_by_name[widget_name]
		local requirements = node.requirements or {}
		local exclusive_group = TalentRules.exclusive_group(node, rules)

		if exclusive_group and exclusive_group ~= "" then
			if exclusive_groups[exclusive_group] then
				return nil, "Talent build selects more than one node in an exclusive group"
			end

			exclusive_groups[exclusive_group] = widget_name
		end

		local incompatible_talent = TalentRules.incompatible_talent(node, rules)

		if incompatible_talent and incompatible_talent ~= "" then
			local incompatible_widget = talent_to_name[incompatible_talent]

			if incompatible_widget and sanitized[incompatible_widget] then
				return nil, "Talent build contains incompatible talents"
			end
		end

		local min_points_spent = requirements.min_points_spent or 0
		local min_points_spent_in_group = requirements.min_points_spent_in_group

		if min_points_spent > 0 then
			local available_requirement_points

			if min_points_spent_in_group and min_points_spent_in_group ~= "" then
				available_requirement_points = points_spent_in_group(
					nodes_by_name,
					sanitized,
					min_points_spent_in_group,
					widget_name
				)
			else
				available_requirement_points = total_points - sanitized[widget_name] * (node.cost or 1)
			end

			if available_requirement_points < min_points_spent then
				return nil, "Talent build does not meet a minimum-points requirement"
			end
		end

		if not reachable_nodes[widget_name] then
			return nil, "Talent build contains a node that is not connected to a starting node"
		end
	end

	return sanitized, nil, total_points, layout
end

local function filtered_profile_nodes(profile)
	local layout = profile_layout(profile)
	local selected_nodes = profile and profile.selected_nodes or {}
	local result = {}

	if not layout then
		return result
	end

	for i = 1, #layout.nodes do
		local widget_name = layout.nodes[i].widget_name
		local tier = selected_nodes[widget_name]

		if tier then
			result[widget_name] = tier
		end
	end

	return result
end

local function sorted_layout_nodes(layout, salt)
	-- Sorting changes the array order, never the native node definitions.
	local result = clone_map(layout.nodes)

	local function salted_score(widget_name)
		local value = tostring(salt or "") .. tostring(widget_name or "")
		local score = 0

		for i = 1, #value do
			score = (score * 33 + string.byte(value, i)) % 2147483647
		end

		return score
	end

	table.sort(result, function(left, right)
		local left_y = left.y or 0
		local right_y = right.y or 0

		if left_y ~= right_y then
			return left_y < right_y
		end

		local left_score = salted_score(left.widget_name)
		local right_score = salted_score(right.widget_name)

		if left_score ~= right_score then
			return left_score < right_score
		end

		return tostring(left.widget_name) < tostring(right.widget_name)
	end)

	return result
end

local function project_nodes_to_cap(profile, desired_nodes, cap, salt, rules)
	local layout = profile_layout(profile)

	if not layout then
		return {}
	end

	local candidates = sorted_layout_nodes(layout, salt)
	local projected = {}
	local progress = true

	while progress do
		progress = false

		for i = 1, #candidates do
			local node = candidates[i]
			local widget_name = node.widget_name
			local desired_tier = desired_nodes[widget_name] or 0
			local current_tier = projected[widget_name] or 0

			if current_tier < desired_tier then
				local trial = clone_map(projected)

				trial[widget_name] = current_tier + 1

				if validate_selected_nodes(profile, trial, cap, rules) then
					projected = trial
					progress = true
				end
			end
		end
	end

	return projected
end

Stimm.install(validate_selected_nodes, project_nodes_to_cap)

local function autofill_nodes(profile, starting_nodes, cap, salt)
	local layout = profile_layout(profile)

	if not layout then
		return starting_nodes
	end

	local selected = project_nodes_to_cap(profile, starting_nodes, cap, salt)
	local candidates = sorted_layout_nodes(layout, salt)
	local progress = true

	while progress do
		progress = false

		for i = 1, #candidates do
			local node = candidates[i]
			local widget_name = node.widget_name
			local cost = node.cost or 1
			local current_tier = selected[widget_name] or 0
			local max_tier = cost == 0 and (node.max_points or 0) or math.floor((node.max_points or 0) / cost)

			if current_tier < max_tier then
				local trial = clone_map(selected)

				trial[widget_name] = current_tier + 1

				if validate_selected_nodes(profile, trial, cap) then
					selected = trial
					progress = true
				end
			end
		end
	end

	return selected
end

local function builds_storage(storage_key)
	local builds = mod:get(storage_key or BUILD_STORAGE_SETTING)

	return type(builds) == "table" and builds or {}
end

local function migrate_wote_settings_once()
	if mod:get(MIGRATION_SETTING) == true then
		return
	end

	local success, old_mod = pcall(get_mod, "WillOfTheEmperor")

	if success and old_mod then
		local old_builds = old_mod:get("custom_talent_builds_v1")

		if type(old_builds) == "table" and next(builds_storage()) == nil then
			mod:set(BUILD_STORAGE_SETTING, table.clone_instance(old_builds))
		end

		local setting_migrations = {
			bot_talent_autofill = "bot_talent_autofill",
			bot_talent_points = "bot_talent_points",
			enable_bot_bestowments = "enable_bot_custom_talents",
			enable_custom_talent_points = "enable_custom_talent_points",
			enable_local_player_bestowments = "enable_local_custom_talents",
			enable_realms_player_bestowments = "enable_realms_custom_talents",
			local_talent_points = "local_talent_points",
			realms_talent_points = "realms_talent_points",
		}

		for old_setting, new_setting in pairs(setting_migrations) do
			local value = old_mod:get(old_setting)

			if value ~= nil then
				mod:set(new_setting, value)
				mod._settings[new_setting] = value
			end
		end
	end

	mod:set(MIGRATION_SETTING, true)
end

local function preset_record(profile, guest)
	local character = tostring(profile.character_id)
	local setting = guest and GUEST_BUILD_STORAGE_SETTING or BUILD_STORAGE_SETTING
	local snapshot = WorkspacePresets.snapshot(profile)
	local function fallback(entry)
		local layout = profile_layout(profile)
		return layout and { archetype = profile_archetype_name(profile), layout_version = layout.version,
			selected_nodes = filtered_profile_nodes(entry and entry.seed_nodes and { archetype = profile.archetype, selected_nodes = entry.seed_nodes } or profile),
      specialization_nodes = Stimm.filter(profile, entry and entry.seed_nodes), points_spent = 0, revision = 0 }
	end
	local inherited = guest and preset_record(profile, false) or nil
	local legacy = builds_storage(setting)[character]
	return PresetStore.resolve(mod, setting, character, snapshot, legacy, fallback, inherited)
end

local function stored_build(profile)
	local character_id = profile and profile.character_id

	if not character_id then
		return nil
	end

	local build = PresetStore.read(preset_record(profile, is_realms_client()))
	local layout = profile_layout(profile)

	if type(build) ~= "table"
		or type(build.selected_nodes) ~= "table"
		or build.archetype ~= profile_archetype_name(profile)
		or not layout
		or build.layout_version ~= layout.version
	then
		return nil
	end

	return build
end

local function save_build(profile, selected_nodes, cap, preset_key)
	local sanitized, validation_error, total_points, layout = validate_selected_nodes(profile, selected_nodes, cap)

	if not sanitized then
		return nil, validation_error
	end

	local character_id = profile.character_id

	if not character_id then
		return nil, "The local character identity is unavailable"
	end

	local setting_key = is_realms_client() and GUEST_BUILD_STORAGE_SETTING or BUILD_STORAGE_SETTING
	local builds = builds_storage(setting_key)
	local storage_key = tostring(character_id)
	local record, preset_data, preset_setting = preset_record(profile, is_realms_client())

	builds[storage_key] = {
		archetype = profile_archetype_name(profile),
		layout_version = layout.version,
		points_spent = total_points,
		revision = record.revision,
		selected_nodes = sanitized,
        specialization_nodes = clone_map((record.slots[preset_key or record.active_key] or {}).specialization_nodes or Stimm.filter(profile)),
	}
	if not PresetStore.write(mod, preset_data, preset_setting, record, builds[storage_key], preset_key) then
        return nil, "The edited preset was deleted"
    end

	mod:set(setting_key, builds)

	return builds[storage_key]
end

local function build_for_profile(profile, cap)
	local layout = profile_layout(profile)

	if not layout then
		return nil, "The current archetype has no talent layout"
	end

	local build = stored_build(profile)
	local desired_nodes = build and build.selected_nodes or filtered_profile_nodes(profile)
	local salt = profile.character_id or profile_archetype_name(profile)
	local selected_nodes = project_nodes_to_cap(profile, desired_nodes, cap, salt)

	return {
		archetype = profile_archetype_name(profile),
		layout_version = layout.version,
		points_spent = select(3, validate_selected_nodes(profile, selected_nodes, cap)) or 0,
		revision = build and build.revision or 0,
		selected_nodes = selected_nodes,
	}
end

local function remember_official_profile(peer_id, local_player_id, profile)
	if not profile or profile.tamm_custom_talents then
		return
	end

	state.official_profiles[profile_key(peer_id, local_player_id)] = table.clone_instance(profile)
end

local function latest_player_profile(player)
	local current = player and player:profile()
	local manager = Managers.profile_synchronization
	local sync = manager and manager:synchronizer_host()
	local updates = sync and sync._profile_updates
	local peer = player and player:peer_id()
	local pending = updates and (updates[peer] or updates[normalize_peer_id(peer)])
	pending = pending and pending[player:local_player_id()]
	-- A new equipment profile can be queued while the player still exposes the
	-- previous one. Merge talent edits into the native queue's newest profile.
	if current and pending and current.character_id == pending.character_id then return pending end
	return current
end

local function official_profile(peer_id, local_player_id, current)
	local profile = state.official_profiles[profile_key(peer_id, local_player_id)]

	if not profile then return nil end
	local manager = Managers.player
	local player = manager and manager:player(peer_id, local_player_id)
	current = current or latest_player_profile(player)
	if current then return ProfileMerge.restore_main(current, profile) end
	return table.clone_instance(profile)
end

mod.realms_loadout_official_profile = function(player)
	if not player then
		return nil
	end

	local restored = official_profile(player:peer_id(), player:local_player_id())

	if restored then
		restored = table.clone_instance(restored)
		restored.tamm_custom_talents = nil
	end

	return restored
end

local function bot_profile_key(profile, identifier)
	local marker = profile and profile.tamm_custom_talents

	return tostring(marker and marker.bot_profile_key or profile and profile.character_id or identifier or "unknown")
end

local function suppress_talent_transform()
	local context = mod._realms_profile_apply_context

	return context and context.suppress_talent_transform == true
end

local function remember_official_bot_profile(profile, identifier)
	if not profile or profile.tamm_custom_talents then
		return
	end

	state.official_bot_profiles[bot_profile_key(profile, identifier)] = table.clone_instance(profile)
end

local function official_bot_profile(profile)
	local saved = state.official_bot_profiles[bot_profile_key(profile)]

	return saved and table.clone_instance(saved) or nil
end

local function apply_nodes_to_profile(profile, selected_nodes, cap, source, revision, explicit_rules, specialization_nodes)
	local rules = explicit_rules or (source == "realms" and remote_selection_rules() or selection_rules())
	local sanitized, validation_error, total_points, layout = validate_selected_nodes(profile, selected_nodes, cap, rules)

	if not sanitized then
		return nil, validation_error
	end

	local new_profile = table.clone_instance(profile)
	local new_selected_nodes = clone_map(new_profile.selected_nodes)
	local new_talents = clone_map(new_profile.talents)
	local main_talents = {}

	for i = 1, #layout.nodes do
		local node = layout.nodes[i]

		new_selected_nodes[node.widget_name] = nil

		if node.talent and node.talent ~= "not_selected" then
			new_talents[node.talent] = nil
		end
	end

	for widget_name, tier in pairs(sanitized) do
		new_selected_nodes[widget_name] = tier
	end

	TalentLayoutParser.selected_talents_from_selected_nodes(layout, sanitized, main_talents)

	for talent_name, tier in pairs(main_talents) do
		new_talents[talent_name] = tier
	end

	PlayerTalents.add_archetype_base_talents(new_profile.archetype, new_talents)

	new_profile.selected_nodes = new_selected_nodes
	new_profile.talents = new_talents
	new_profile.talent_points = cap
	new_profile.tamm_custom_talents = {
		cap = cap,
		enabled = true,
		points_spent = total_points,
		protocol = PROTOCOL_VERSION,
		revision = revision or 0,
		source = source,
	}

  if source ~= "bot" and Stimm.layout(new_profile) then
    if not specialization_nodes and source == "local" then
      local saved = stored_build(profile)
      specialization_nodes = saved and saved.specialization_nodes
    end
    Stimm.apply(new_profile, specialization_nodes, Stimm.cap(new_profile, rules.stimm_points))
  end
	return new_profile
end

local function player_for_peer(peer_id, local_player_id)
	local player_manager = Managers.player

	if not player_manager then
		return nil
	end

	return player_manager:player(peer_id, local_player_id)
		or player_manager:player(normalize_peer_id(peer_id), local_player_id)
end

local function transformed_host_profile(peer_id, local_player_id, profile)
	if not profile then
		return profile
	end

	local normalized_peer_id = normalize_peer_id(peer_id)
	local own_peer = normalized_peer_id == local_peer_id()
	local key = profile_key(peer_id, local_player_id)
	local marker = profile.tamm_custom_talents
	local marker_source = marker and marker.source

	-- A Realms client has no host synchronizer of its own. These one-shot
	-- markers tell the host to keep that peer on its official profile while the
	-- native inventory is open, then resume the normal Realms transform when it
	-- closes. The marker itself is never applied to the player profile.
	if marker_source == "realms_loadout_official_ui" then
		state.official_ui_profiles[key] = true
		local restored = table.clone_instance(profile)
		restored.tamm_custom_talents = nil
		remember_official_profile(peer_id, local_player_id, restored)

		return restored
	elseif marker_source == "realms_loadout_resume" then
		state.official_ui_profiles[key] = nil
		profile = table.clone_instance(profile)
		profile.tamm_custom_talents = nil
	elseif state.official_ui_profiles[key] then
		remember_official_profile(peer_id, local_player_id, profile)

		return profile
	end

	if suppress_talent_transform() then
		return profile
	end

	if state.suspended or not is_custom_talent_host_session() then
		return profile
	end
	if own_peer and local_official_ui_mode() then
		remember_official_profile(peer_id, local_player_id, profile)

		return profile
	end

	local player = player_for_peer(peer_id, local_player_id)
	local human_controlled = not player or player:is_human_controlled()

	if not human_controlled then
		return profile
	end

	if own_peer and local_scope_enabled() then
		remember_official_profile(peer_id, local_player_id, profile)

		local cap = custom_talent_ui_cap(player)
		local build, build_error = build_for_profile(profile, cap)

		if not build then
			mod:error("Could not prepare the local custom talent profile: %s", tostring(build_error))

			return profile
		end

		local transformed = apply_nodes_to_profile(profile, build.selected_nodes, cap, "local", build.revision)

		return transformed or profile
	end

	if not own_peer and is_realms_host() and realms_scope_enabled() then
		local peer_builds = state.remote_builds[normalized_peer_id]
		local build = peer_builds and peer_builds[local_player_id]

		local assigned = state.host_player_rules[normalized_peer_id]
		if (build and build.character_id == profile.character_id) or assigned then
			remember_official_profile(peer_id, local_player_id, profile)

			local rules = remote_selection_rules(normalized_peer_id)
			local cap = rules.realms_player_points
			local matching = build and build.character_id == profile.character_id
			local desired = matching and build.selected_nodes or filtered_profile_nodes(profile)
			local selected = project_nodes_to_cap(profile, desired, cap, normalized_peer_id, rules)
			local transformed = apply_nodes_to_profile(profile, selected, cap, "realms", matching and build.revision or 0, rules, matching and build.specialization_nodes)

			return transformed or profile
		end
	end

	if profile.tamm_custom_talents then
		return official_profile(peer_id, local_player_id, profile) or profile
	end

	return profile
end

local ProfileHooks = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_profile_hooks")

-- Weapons rebuild first (priority 10); this transform runs after them so the
-- talent build is cloned on top of the rebuilt profile.
ProfileHooks.set_transform("talents", function (peer_id, local_player_id, profile)
	return transformed_host_profile(peer_id, local_player_id, profile)
end, 20)

mod:hook(ProfileUtils, "get_bot_profile", function(func, identifier)
	local profile = func(identifier)

	remember_official_bot_profile(profile, identifier)

	if state.suspended or not is_custom_talent_host_session() or not bot_scope_enabled() then
		return profile
	end

	local cap = talent_points_setting("bot_talent_points")
	local selected_nodes = filtered_profile_nodes(profile)

	if setting_enabled("bot_talent_autofill") then
		selected_nodes = autofill_nodes(profile, selected_nodes, cap, identifier)
	end

	local transformed = apply_nodes_to_profile(profile, selected_nodes, cap, "bot", 0)

	if transformed then
		transformed.tamm_custom_talents.bot_profile_key = bot_profile_key(profile, identifier)
	end

	return transformed or profile
end)

local function active_profile_synchronizer_host()
	local manager = Managers.profile_synchronization

	return manager and manager:synchronizer_host() or nil
end

local function override_owned_profile(synchronizer, player, local_player_id, profile, source)
	local allow_while_suspended = state.allow_suspended_profile_restore == true

	if state.suspended and not allow_while_suspended then
		return false, "profile writes suspended"
	end

	if not synchronizer or not player or player.__deleted or type(profile) ~= "table" then
		return false, "profile update target unavailable"
	end

	local peer_id = player:peer_id()
	local player_manager = Managers.player
	local registered_player = player_manager and player_manager:player(peer_id, local_player_id)

	if registered_player ~= player then
		return false, "profile player is no longer registered"
	end

	local current = latest_player_profile(player)

	if not current or current.character_id ~= profile.character_id then
		return false, "profile character changed"
	end

	local previous_context = mod._realms_profile_apply_context
	mod._realms_profile_apply_context = {
		allow_while_suspended = allow_while_suspended,
		owner = "realms_loadout",
		source = source,
	}

	local ok, err = pcall(function ()
		synchronizer:override_singleplay_profile(peer_id, local_player_id, profile)
	end)

	mod._realms_profile_apply_context = previous_context

	if not ok then
		return false, tostring(err)
	end

	return true
end

-- Submit legal profiles immediately, but let the native profile/package
-- synchronizers own gameplay removal, resource loading and talent application.
-- A live talent extension only proves its OLD loadout is ready. Calling
-- select_new_talents here can equip an unloaded ability, send the same unsafe
-- update to its client, or re-equip a slot already removed for a pending sync.

local function apply_local_profile_if_needed()
	if state.suspended or local_official_ui_mode()
		or not is_custom_talent_host_session() or not local_scope_enabled() then
		return
	end

	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player_safe(1)
	local synchronizer = active_profile_synchronizer_host()

	if not player or not synchronizer then
		return
	end

	if synchronizer ~= state.local_apply_synchronizer then
		state.local_apply_synchronizer = synchronizer
		state.local_apply_signature = nil
	end

	local profile = latest_player_profile(player)
	local cap = custom_talent_ui_cap(player)
	local stored = stored_build(profile)
	local desired_revision = stored and stored.revision or 0
	local signature = string.format("%s:%s:%s", tostring(profile.character_id), tostring(desired_revision), tostring(cap))

	if state.local_apply_signature == signature then
		return
	end

	local build, build_error = build_for_profile(profile, cap)

	if not build then
		mod:error("Could not prepare the local custom talent profile: %s", tostring(build_error))

		return
	end

	remember_official_profile(player:peer_id(), player:local_player_id(), profile)

	local transformed, transform_error = apply_nodes_to_profile(profile, build.selected_nodes, cap, "local", build.revision)

	if not transformed then
		mod:error("Could not apply the local custom talent profile: %s", tostring(transform_error))

		return
	end

	local applied, apply_error = override_owned_profile(
		synchronizer,
		player,
		player:local_player_id(),
		transformed,
		"local_talent_apply"
	)

	if not applied then
		mod:warning("Could not queue the local custom talent profile: %s", tostring(apply_error))

		return
	end

	state.local_apply_signature = signature
end

local function set_profile_direct(player, profile)
	-- Only a detached local profile may be restored directly. Never fabricate
	-- updated_player_profile_synced: that event belongs to the native protocol.
	player:set_profile(profile)

	if Managers.event then
		Managers.event:trigger("event_player_profile_updated", player:peer_id(), player:local_player_id(), profile)
	end
end

local function restore_profile(player, restored, synchronizer)
	local current = latest_player_profile(player)
	if not current or not restored or current.character_id ~= restored.character_id or is_realms_client() then
		return false
	end

	restored = ProfileMerge.restore_main(current, restored)
	if not restored then return false end
	if synchronizer and is_custom_talent_host_session() then
		local applied = override_owned_profile(
			synchronizer,
			player,
			player:local_player_id(),
			restored,
			"official_profile_restore"
		)

		if not applied then
			return false
		end
	else
		-- A synchronizer can disappear before the player object during teardown.
		-- Leave live/connected units to their owning native session.
		local unit = player.player_unit
		if current_connection() or (unit and ALIVE and ALIVE[unit]) then return false end
		set_profile_direct(player, restored)
	end

	return true
end

local function reconcile_remote_player(player, profile, synchronizer, force_restore)
	profile = latest_player_profile(player) or profile
	local peer_id = normalize_peer_id(player:peer_id())
	local local_player_id = player:local_player_id()
	local key = profile_key(peer_id, local_player_id)

	if not force_restore and state.official_ui_profiles[key] then
		remember_official_profile(peer_id, local_player_id, profile)

		return
	end

	local peer_builds = state.remote_builds[peer_id]
	local build = peer_builds and peer_builds[local_player_id]

	local matching = build and build.character_id == profile.character_id
	if not force_restore and realms_scope_enabled() and (matching or state.host_player_rules[peer_id]) then
		local base_profile = profile
		if base_profile.character_id ~= profile.character_id then base_profile = profile end

		remember_official_profile(peer_id, local_player_id, base_profile)

		local rules = remote_selection_rules(peer_id)
		local cap = rules.realms_player_points
		local desired = matching and build.selected_nodes or filtered_profile_nodes(base_profile)
		local selected_nodes = project_nodes_to_cap(base_profile, desired, cap, peer_id, rules)
		local transformed, transform_error = apply_nodes_to_profile(
			base_profile,
			selected_nodes,
			cap,
			"realms",
			matching and build.revision or 0,
			rules, matching and build.specialization_nodes
		)

		if transformed then
			local applied, apply_error = override_owned_profile(
				synchronizer,
				player,
				local_player_id,
				transformed,
				"host_reconcile"
			)

			if not applied then
				mod:warning("Could not queue the Realms custom talent profile for %s: %s", peer_id, tostring(apply_error))
			end
		else
			mod:error("Could not reapply the Realms custom talent profile for %s: %s", peer_id, tostring(transform_error))
		end
	elseif profile.tamm_custom_talents and profile.tamm_custom_talents.source == "realms" then
		restore_profile(player, official_profile(peer_id, local_player_id), synchronizer)
	end
end

local function reconcile_bot_player(player, profile, synchronizer, force_restore)
	local original = official_bot_profile(profile)

	if not force_restore and bot_scope_enabled() and original then
		local cap = talent_points_setting("bot_talent_points")
		local selected_nodes = filtered_profile_nodes(original)

		if setting_enabled("bot_talent_autofill") then
			selected_nodes = autofill_nodes(original, selected_nodes, cap, bot_profile_key(profile))
		end

		local transformed, transform_error = apply_nodes_to_profile(
			original,
			selected_nodes,
			cap,
			"bot",
			state.host_rules_revision
		)

		if transformed then
			transformed.tamm_custom_talents.bot_profile_key = bot_profile_key(profile)
			local applied, apply_error = override_owned_profile(
				synchronizer,
				player,
				player:local_player_id(),
				transformed,
				"bot_reconcile"
			)

			if not applied then
				mod:warning("Could not queue a Bot custom talent profile: %s", tostring(apply_error))
			end
		else
			mod:error("Could not reapply a Bot custom talent profile: %s", tostring(transform_error))
		end
	elseif profile.tamm_custom_talents and profile.tamm_custom_talents.source == "bot" then
		restore_profile(player, original, synchronizer)
	end
end

local function reconcile_host_profiles(force_restore)
	if not is_custom_talent_host_session() then
		return
	end

	local synchronizer = active_profile_synchronizer_host()

	if synchronizer ~= state.host_reconcile_synchronizer then
		state.host_reconcile_synchronizer = synchronizer
		state.host_reconcile_pending = true
	end
	if (not force_restore and not state.host_reconcile_pending) or not synchronizer then
		return
	end

	local player_manager = Managers.player
	local players = player_manager and player_manager:players()

	if not players then
		return
	end

	for _, player in pairs(players) do
		local profile = player and player:profile()

		if profile then
			if is_own_player(player) then
				if (force_restore or not local_scope_enabled())
					and profile.tamm_custom_talents
					and profile.tamm_custom_talents.source == "local"
				then
					restore_profile(
						player,
						official_profile(player:peer_id(), player:local_player_id()),
						synchronizer
					)
				end
			elseif player:is_human_controlled() then
				reconcile_remote_player(player, profile, synchronizer, force_restore)
			else
				reconcile_bot_player(player, profile, synchronizer, force_restore)
			end
		end
	end

	state.host_reconcile_pending = false
end

local function remember_local_official_profile()
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player_safe(1)
	local profile = player and player:profile()

	if profile and not profile.tamm_custom_talents and profile ~= state.local_official_profile_ref then
		remember_official_profile(player:peer_id(), player:local_player_id(), profile)
		state.local_official_profile_ref = profile
	end
end

local function restore_local_official_profile_if_needed(force_restore)
	if not force_restore and (is_custom_talent_host_session() or is_realms_client()) then
		return
	end

	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player_safe(1)
	local profile = player and player:profile()

	if not profile or not profile.tamm_custom_talents then
		return
	end

	local restored = official_profile(player:peer_id(), player:local_player_id())

	if restored then
		restore_profile(player, restored, active_profile_synchronizer_host())
	end
end

local function realms_mod()
	local success, realms = pcall(get_mod, "Realms")

	if not success or not realms or not realms:is_enabled() then
		return nil
	end

	return realms
end

local function host_rules(peer)
	return configured_player_rules(peer)
end

local function clear_remote_peer(peer, restore_connected)
	state.remote_builds[peer] = nil
	-- Actual departure and room replacement must only discard mod state. Native
	-- removal owns the player's pending profiles, package requests and unit.
	local players = restore_connected ~= false and not state.suspended
		and Managers.player and Managers.player:players() or {}
	local synchronizer = active_profile_synchronizer_host()
	for _, player in pairs(players) do
		if normalize_peer_id(player:peer_id()) == peer then
			local profile = player:profile()
			if profile and profile.tamm_custom_talents and profile.tamm_custom_talents.source == "realms" then
				restore_profile(player, official_profile(peer, player:local_player_id()), synchronizer)
			end
		end
	end
	local prefix = peer .. "|"
	for key in pairs(state.official_profiles) do
		if string.sub(key, 1, #prefix) == prefix then state.official_profiles[key] = nil end
	end
	for key in pairs(state.official_ui_profiles) do
		if string.sub(key, 1, #prefix) == prefix then state.official_ui_profiles[key] = nil end
	end
end

local function apply_remote_build(peer, payload)
	if type(payload) ~= "table" or type(payload.local_player_id) ~= "number"
		or payload.local_player_id % 1 ~= 0 or payload.local_player_id < 1 or payload.local_player_id > 4
		or type(payload.character_id) ~= "string" or type(payload.archetype) ~= "string"
		or type(payload.layout_version) ~= "number" or type(payload.selected_nodes) ~= "table"
		or type(payload.revision) ~= "number" or payload.revision % 1 ~= 0 or payload.revision < 0 then
		return { accepted = false, reason = "malformed" }
	end
	local player = player_for_peer(peer, payload.local_player_id)
	local profile = latest_player_profile(player)
	local layout = profile and profile_layout(profile)
	if state.suspended or not player or not profile then
		return { accepted = false, retry = true, reason = "loading" }
	end
	if not player:is_human_controlled() or player:character_id() ~= payload.character_id
		or profile_archetype_name(profile) ~= payload.archetype or not layout or layout.version ~= payload.layout_version then
		return { accepted = false, reason = "identity" }
	end
	local rules = remote_selection_rules(peer)
	local cap = rules.realms_player_points
	local selected, validation_error, total = validate_selected_nodes(profile, payload.selected_nodes, cap, rules)
	if not selected then return { accepted = false, reason = "invalid_build" } end
	local synchronizer = active_profile_synchronizer_host()
	if not synchronizer then return { accepted = false, retry = true, reason = "loading" } end
	local specialization = payload.specialization_nodes or {}
  if not Stimm.validate(profile, specialization, Stimm.cap(profile, rules.stimm_points)) then
    return { accepted = false, reason = "invalid_stimm_build" }
  end
  local base = profile
	local transformed = apply_nodes_to_profile(base, selected, cap, "realms", payload.revision, rules, specialization)
	if not transformed then return { accepted = false, reason = "invalid_build" } end
	remember_official_profile(peer, payload.local_player_id, base)
	state.remote_builds[peer] = state.remote_builds[peer] or {}
	state.remote_builds[peer][payload.local_player_id] = {
		character_id = payload.character_id, archetype = payload.archetype, layout_version = payload.layout_version,
		points_spent = total, revision = payload.revision, selected_nodes = selected, specialization_nodes = clone_map(specialization),
	}

	if not state.official_ui_profiles[profile_key(peer, payload.local_player_id)] then
		local applied = override_owned_profile(
			synchronizer,
			player,
			payload.local_player_id,
			transformed,
			"remote_build_accept"
		)

		if not applied then
			return { accepted = false, retry = true, reason = "loading" }
		end
	end

	return { accepted = true }
end

local function current_local_build_payload()
	local player = Managers.player and Managers.player:local_player_safe(1)
	local rules = received_host_rules()
	if state.suspended or not player or not rules or not rules.enabled then return nil end
	local profile = player:profile()
	if not profile or not profile.character_id or not profile_layout(profile) then return nil end
	local saved = stored_build(profile)
	-- Projection/validation runs only after a saved build, profile or rule change.
	local key = table.concat({ tostring(profile), tostring(profile.character_id), tostring(saved and saved.revision or 0),
		tostring(rules.revision), tostring(state.sync.remote_host_token) }, "|")
	if state.payload_cache_key ~= key then
		local build = build_for_profile(profile, rules.realms_player_points)
		if not build then return nil end
		state.payload_cache_key = key
		state.payload_cache = { archetype = profile_archetype_name(profile), character_id = player:character_id(),
			layout_version = build.layout_version, local_player_id = player:local_player_id(),
			revision = build.revision, selected_nodes = build.selected_nodes,
            specialization_nodes = Stimm.project(profile, saved and saved.specialization_nodes or Stimm.filter(profile), Stimm.cap(profile, rules.stimm_points)) }
		local parts = { tostring(profile.character_id), tostring(build.layout_version), tostring(build.revision), tostring(rules.revision) }
		local names = table.keys(build.selected_nodes)
		table.sort(names)
		for _, name in ipairs(names) do parts[#parts + 1] = name .. "=" .. build.selected_nodes[name] end
		state.payload_signature = table.concat(parts, "|")
	end
	return state.payload_cache, state.payload_signature
end

state.sync_generation = (state.sync_generation or 0) + 1
state.network_closed = false
state.sync = TalentSync.new({
	generation = state.sync_generation,
	local_ready = function()
		local player = Managers.player and Managers.player:local_player_safe(1)
		local profile = player and player:profile()
		return not state.suspended and profile ~= nil and profile.character_id ~= nil and profile_layout(profile) ~= nil
	end,
	warn_peer = function(peer, status)
		local player = player_for_peer(peer, 1)
		local profile = player and player:profile()
		mod:notify(mod:localize("tpm_peer_warning", profile and profile.name or peer, mod:localize("tpm_deploy_" .. status)))
	end,
	host_rules = host_rules, local_build = current_local_build_payload, apply_build = apply_remote_build,
	peer_left = clear_remote_peer,
	member_left = function(peer) state.host_player_rules[peer] = nil end,
	reset = function(old_peers, role)
		for peer in pairs(old_peers) do clear_remote_peer(peer, false) end
		state.remote_builds = {}
		state.official_ui_profiles = {}
		state.host_player_rules = {}
		state.host_reconcile_pending = true
		state.payload_cache_key = nil
		state.editor_reload_pending = not (state.editor and state.editor._tamm_user_edited)
	end,
	rules_changed = function(rules, initial)
		state.session_rules = rules
		state.payload_cache_key = nil
		state.editor_refresh_pending = true
		-- A new valid snapshot may load the saved build only if there is no unsaved draft.
		if initial and rules and not (state.editor and state.editor._tamm_user_edited) then
			state.editor_reload_pending = true
		end
	end,
	send = function(peer, message)
		local realms = realms_mod()
		if not realms or not state.sync.ready then return false end
		return realms.network_send(mod, TalentSync.RPC, peer, message)
	end,
})

local function sync_network_context()
	local realms = realms_mod()
	local session = realms and realms._session
	local connection = current_connection()
	local role = "local"
	if connection and session and not state.network_closed then
		if session.is_active_host() then role = "host"
		elseif session.is_active_client() then role = "client" end
	end
	local host = role == "client" and normalize_peer_id(Managers.connection:host()) or nil
	-- Realms.send reads a native peer ID. Never call it (or transport availability)
	-- until Realms has a real connection. An empty hosted room is a valid session.
	local ready = role ~= "local" and type(realms.network_is_available) == "function"
		and realms.network_is_available() == true
	state.connection, state.rules_host, state.network_role = connection, host, role
	return state.sync:context({ connection = connection, role = role, host = host, ready = ready })
end

local function register_realms_network(replay)
	local realms = realms_mod()
	if not realms or type(realms.network_register) ~= "function"
		or type(realms.network_on_peer_joined) ~= "function" or type(realms.network_on_peer_left) ~= "function" then return end
	-- Realms keeps one peer callback per mod, so all RL protocols share one
	-- dispatcher (realms_peer_events) instead of overwriting each other.
	PeerEvents.install(realms)
	if state.network_registered ~= realms then
		local registered = realms.network_register(mod, TalentSync.RPC, function(peer, message)
			sync_network_context()
			state.sync:receive(normalize_peer_id(peer), message)
		end)
		if not registered then return end
		state.network_registered = realms
		replay = true
	end
	if replay then
		PeerEvents.set_left("talent_sync", function(peer)
			sync_network_context()
			state.sync:left(normalize_peer_id(peer))
		end)
		-- Subscribing replays currently known members when enabling mid-session.
		PeerEvents.set_joined("talent_sync", function(peer)
			sync_network_context()
			state.sync:joined(normalize_peer_id(peer))
		end)
	end
end

local function update_realms_network(dt)
	local changed = sync_network_context()
	register_realms_network(changed)
	if state.rules_broadcast_pending then
		state.rules_broadcast_pending = false
		state.sync:rules_updated()
	end
	if state.pending_build_submit then
		state.pending_build_submit = false
		state.payload_cache_key = nil
		state.sync:queue_build()
	end
	state.sync:update(dt)
end

mod.realms_talent_controls_active = function()
	local realms = realms_mod()
	return mod:is_enabled() and realms and realms._session and realms._session.is_active_host()
		and is_realms_host() and current_connection() ~= nil and not state.network_closed or false
end

mod.realms_talent_player_rules = function(peer)
	if not mod.realms_talent_controls_active() then return nil end
	peer = normalize_peer_id(peer)
	if peer ~= local_peer_id() and not state.sync.peers[peer] then return nil end
	local rules = configured_player_rules(peer)
  local player = player_for_peer(peer, 1)
  local profile = player and player:profile()
  rules.is_scum = Stimm.layout(profile) ~= nil
  rules.stimm_effective_points = rules.is_scum and Stimm.cap(profile, rules.stimm_points) or nil
  return rules, current_connection()
end

mod.realms_talent_deployment = function(peer)
	if not mod.realms_talent_controls_active() then return nil end
	peer = normalize_peer_id(peer)
	if peer == local_peer_id() then
		return { status = local_scope_enabled() and "accepted" or "disabled", version = TalentSync.DEPLOYMENT_VERSION }
	end
	return state.sync:deployment(peer)
end

mod.set_realms_talent_player_rules = function(peer, values, connection)
	if not mod.realms_talent_controls_active() or connection ~= current_connection()
		or type(values) ~= "table" then return false end
	peer = normalize_peer_id(peer)
	if peer ~= local_peer_id() and not state.sync.peers[peer] then return false end
	if type(values.points) ~= "number" or values.points % 1 ~= 0 or values.points < 0 or values.points > 99
		or type(values.auras) ~= "boolean" or type(values.keystones) ~= "boolean" then return false end
	local previous = configured_player_rules(peer)
	if not previous.enabled then return false end
	local stimm_points = values.stimm_points
  if stimm_points == nil then stimm_points = previous.stimm_points end
  if type(stimm_points) ~= "number" or stimm_points % 1 ~= 0 or stimm_points < -1 or stimm_points > 103 then return false end
  local target_player = player_for_peer(peer, 1)
  if values.stimm_points ~= nil and not Stimm.layout(target_player and target_player:profile()) then return false end
  if previous.stimm_points == stimm_points and previous.realms_player_points == values.points and previous.unlock_all_auras == values.auras
		and previous.unlock_all_keystones == values.keystones then return true end
	state.rules_serial = math.max(state.rules_serial, state.host_rules_revision) + 1
	state.host_player_rules[peer] = { points = values.points, auras = values.auras,
		keystones = values.keystones, stimm_points = stimm_points, revision = state.rules_serial }
	local player = player_for_peer(peer, 1)
	local synchronizer = active_profile_synchronizer_host()
	if peer == local_peer_id() then
		state.local_apply_signature = nil
		state.editor_refresh_pending = true
		if not state.suspended then apply_local_profile_if_needed() end
	else
		-- Recompute from the retained desired build before the guest replies.
		if not state.suspended and player and player:profile() and synchronizer then
			reconcile_remote_player(player, player:profile(), synchronizer, false)
		else state.host_reconcile_pending = true end
		state.sync:rules_updated(peer)
	end
	return true
end

local function refresh_talent_editor()
	local view = state.editor
	state.editor_refresh_pending = false
	if not view or not view._tamm_custom_talent_mode or not view._active_layout then
		return
	end
	local profile = view._preview_player:profile()
	local enabled = custom_talent_ui_enabled(view._preview_player)
	local cap = enabled and custom_talent_ui_cap(view._preview_player) or MIN_TALENT_POINTS
	local rules = enabled and selection_rules() or {}
	TalentRules.configure_layout(view._active_layout, profile_layout(profile), rules)
	table.clear(view._incompatible_talents)
	for _, node in ipairs(view._active_layout.nodes) do
		local incompatible = node.requirements and node.requirements.incompatible_talent
		if incompatible then view._incompatible_talents[incompatible] = true end
	end
	local desired = view._node_widget_tiers or {}
	if state.editor_reload_pending then
		local stored = build_for_profile(profile, cap)
		desired = stored and stored.selected_nodes or desired
		state.editor_reload_pending = false
	end
	view._is_readonly = view._tamm_base_readonly or not enabled
	local projected = project_nodes_to_cap(profile, desired, cap, profile.character_id, rules)
	local removed = false
	for name, tier in pairs(desired) do
		if projected[name] ~= tier then removed = true; break end
	end
	view._node_widget_tiers = projected
	view._draw_instant_lines = true
	for _, widget in ipairs(view._node_widgets or {}) do
		local selected = projected[widget.name] ~= nil
		widget.content.has_points_spent = selected
		widget.content.highlighted = selected
		widget.content.alpha_anim_progress = selected and 1 or 0
	end
	view:_update_base_talent_loadout_presentation()
	Managers.event:trigger("tpm_workspace_nodes_updated", projected)
	if removed then
		mod:notify(mod:localize("custom_talent_rules_pruned"))
	end
end

-- Player initialization can precede Run's resume callback. Enforce assigned
-- host limits here too, without writing profiles or touching saved builds.
host_loadout = function(profile, talents)
	if not is_realms_host() or not realms_scope_enabled() or type(talents) ~= "table"
		or not profile or not profile.character_id then return profile, talents end
	local players = Managers.player and Managers.player:players() or {}
	for _, player in pairs(players) do
		local current = player:profile()
		local peer = normalize_peer_id(player:peer_id())
		if current and current.character_id == profile.character_id and player:is_human_controlled()
			and (state.host_player_rules[peer] or profile.tamm_custom_talents) then
			local rules = configured_player_rules(peer)
			local layout = profile_layout(profile)
			if not rules.enabled or not layout then return profile, talents end
			local nodes = {}
			for _, node in ipairs(layout.nodes) do
				if node.type ~= "start" and talents[node.talent] then nodes[node.widget_name] = talents[node.talent] end
			end
			if validate_selected_nodes(profile, nodes, rules.realms_player_points, rules) then return profile, talents end
			local selected = project_nodes_to_cap(profile, nodes, rules.realms_player_points, peer, rules)
			local adjusted, adjusted_talents = clone_map(profile), clone_map(talents)
			adjusted.selected_nodes = clone_map(profile.selected_nodes)
			for _, node in ipairs(layout.nodes) do
				adjusted.selected_nodes[node.widget_name] = nil
				if node.talent then adjusted_talents[node.talent] = nil end
			end
			for name, tier in pairs(selected) do adjusted.selected_nodes[name] = tier end
			TalentLayoutParser.selected_talents_from_selected_nodes(layout, selected, adjusted_talents)
			PlayerTalents.add_archetype_base_talents(profile.archetype, adjusted_talents)
			adjusted.talents = adjusted_talents
			return adjusted, adjusted_talents
		end
	end
	return profile, talents
end

mod:hook_require("scripts/extension_systems/talent/player_unit_talent_extension", function(Extension)
	local function allowed(self, talents)
		local profile = self._player and self._player:profile()
		local _, filtered = host_loadout(profile, talents)
		if self._talents == talents then self._talents = filtered end
		return filtered
	end
	mod:hook(Extension, "_apply_talents", function(func, self, archetype, talents, ...)
		self._tpm_combined_upgrades = compatible_effects_context() == true
		local result = func(self, archetype, allowed(self, talents), ...)
		if mod.talent_debug_applied then mod.talent_debug_applied(self) end
		return result
	end)
	mod:hook(Extension, "_send_rpc_update_to_client", function(func, self, player, talents, ...)
		return func(self, player, allowed(self, talents), ...)
	end)
end)

local function update_talent_status(view, dt)
	talent_views[view] = true
	local widget = view._tpm_status_widget
	local in_realms = realms_mod() and (is_realms_host() or is_realms_client()) and not state.network_closed
	if not widget and in_realms and is_own_player(view._preview_player) and view._widgets and view._ui_overlay_scenegraph then
		widget = view:_create_widget("tpm_session_status", TalentStatus.definition(UIWidget))
		view._tpm_status_widget = widget
		view._widgets[#view._widgets + 1] = widget
	end
	if not widget then return end
	local own = not local_official_ui_mode() and is_own_player(view._preview_player)
		and (is_realms_host() or owns_custom_editor(view._preview_player))
	widget.content.visible = mod:is_enabled() and own and in_realms == true
		and not (view._is_handling_popup_window and view:_is_handling_popup_window())
	if not widget.content.visible then return end
	view._tpm_status_elapsed = (view._tpm_status_elapsed or 0.2) + dt
	if view._tpm_status_elapsed < 0.2 then return end
	view._tpm_status_elapsed = 0
	local sync = state.sync
	local confirmed, total, incompatible = 0, 0, 0
	for peer_id, peer in pairs(sync.peers) do
		total = total + 1
		if peer.ack_revision == host_rules(peer_id).revision then confirmed = confirmed + 1 end
		if peer.status == "incompatible" then incompatible = incompatible + 1 end
	end
	local rules = selection_rules()
	local enabled = custom_talent_ui_enabled(view._preview_player)
	local model = { role = sync.role, status = sync.status, cap = enabled and custom_talent_ui_cap(view._preview_player) or 30,
		spent = view:_node_points_spent(), auras = enabled and rules.unlock_all_auras,
		keystones = enabled and rules.unlock_all_keystones, confirmed = confirmed, total = total,
		incompatible = incompatible, guest_cap = realms_scope_enabled() and talent_points_setting("local_talent_points") or 30,
		has_rules = received_host_rules() ~= nil,
		draft = view._tamm_user_edited, enabled = enabled }
	local lines = TalentStatus.lines(model, function(key, ...) return mod:localize(key, ...) end)
	for i, line in ipairs(lines) do widget.content["line" .. i] = line end
end

local function install_ui_hooks()
	mod:hook(TalentBuilderView, "update", function(func, self, dt, ...)
		-- DMF can be enabled while an already-created native editor is open.
		if not self._tamm_custom_talent_mode and not state.network_closed and not state.suspended
			and self._active_layout and owns_custom_editor(self._preview_player) then
			self._tamm_base_readonly = self._is_readonly
			self._tamm_custom_talent_mode = true
			mod._custom_talent_view_active = true
			state.editor = self
			state.editor_reload_pending = true
			local parent = self._context and self._context.parent
			if parent then inventory_views[parent] = true; parent._tamm_custom_talent_mode = true end
			refresh_talent_editor()
		end
		local pass_input, pass_draw = func(self, dt, ...)
		if self._tamm_custom_talent_mode and not state.editor and owns_custom_editor(self._preview_player)
			and (not state.suspended or (realms_mod() and (is_realms_host() or is_realms_client()) and not state.network_closed)) then
			state.editor = self
			state.editor_refresh_pending = true
		end
		update_talent_status(self, dt)
		return pass_input, pass_draw
	end)
	mod:hook(TalentBuilderView, "_get_player_mode_layout", function(func, self, ...)
		if not owns_custom_editor(self._preview_player) then
			return func(self, ...)
		end
		local original = profile_layout(self._preview_player:profile())
		if not original then return func(self, ...) end
		local layout = TalentRules.copy_layout(original, selection_rules())
		for _, node in ipairs(layout.nodes) do self:_init_node(node) end
		return layout
	end)

	mod:hook(TalentLayoutParser, "is_talent_selection_valid", function(func, profile, layout_key, nodes, ...)
		local player = Managers.player and Managers.player:local_player_safe(1)
		if layout_key == "talent_layout_file_path" and player and profile == player:profile()
			and mod._custom_talent_view_active and custom_talent_ui_enabled(player) then
			return validate_selected_nodes(profile, nodes, custom_talent_ui_cap(player)) ~= nil
		end
		return func(profile, layout_key, nodes, ...)
	end)

	mod:hook(TalentBuilderView, "_max_node_points", function(func, self, ...)
		if owns_custom_editor(self._preview_player) then
			return custom_talent_ui_cap(self._preview_player)
		end

		return func(self, ...)
	end)

	mod:hook(TalentBuilderView, "on_enter", function(func, self, ...)
		local result
		update_realms_network(0)

		if owns_custom_editor(self._preview_player) then
			self._tamm_base_readonly = self._is_readonly
			mod._custom_talent_view_initializing = true

			local success

			success, result = pcall(func, self, ...)
			mod._custom_talent_view_initializing = false

			if not success then
				error(result)
			end

			self._tamm_custom_talent_mode = true
			mod._custom_talent_view_active = true
			state.editor = self
			state.editor_reload_pending = true
			refresh_talent_editor()
		else
			result = func(self, ...)
		end


		update_talent_status(self, 0.2)
		return result
	end)

	mod:hook(TalentBuilderView, "on_exit", function(func, self, ...)
		talent_views[self] = nil
		if state.editor == self then state.editor = nil end
		if self._tamm_custom_talent_mode then
			mod._custom_talent_view_active = false
		end

		return func(self, ...)
	end)

	mod:hook(TalentBuilderView, "event_on_profile_preset_changed", function(func, self, ...)
		if self._tamm_custom_talent_mode then
			return
		end

		return func(self, ...)
	end)

	for _, name in ipairs({ "_add_node_point_on_widget", "_remove_node_point_on_widget", "clear_node_points" }) do
		mod:hook(TalentBuilderView, name, function(func, self, ...)
			if self._tamm_custom_talent_mode and not custom_talent_ui_enabled(self._preview_player) then
				return false
			end
			local result = func(self, ...)
			if self._tamm_custom_talent_mode and result ~= false then
				self._tamm_user_edited = true
				local parent = self._context and self._context.parent
				if parent then
					parent._tamm_user_edited = true
					mod.workspace_nodes_updated(parent, self._node_widget_tiers)
				end
			end
			return result
		end)
	end

	mod:hook(InventoryBackgroundView, "_switch_active_view", function(func, self, view_name, ...)
		if view_name == "talent_builder_view" and owns_custom_editor(self._preview_player) then
			update_realms_network(0)
			local profile = self._preview_player:profile()
			local cap = custom_talent_ui_cap(self._preview_player)
			self._tamm_preset_key = WorkspacePresets.snapshot(profile).key
			local build, build_error = build_for_profile(profile, cap)

			if build then
				inventory_views[self] = true
				self._current_profile_equipped_talents = clone_map(build.selected_nodes)
				self._valid_profile_equipped_talents = clone_map(build.selected_nodes)
				self._tamm_custom_talent_mode = true

				if not self._tamm_custom_talent_notice_shown then
					self._tamm_custom_talent_notice_shown = true
					mod:notify(mod:localize("custom_talent_edit_notice", cap))
				end
			else
				mod:error("Could not prepare the custom talent editor: %s", tostring(build_error))
			end
		end

		return func(self, view_name, ...)
	end)
	mod:hook_safe(InventoryBackgroundView, "on_exit", function(self) inventory_views[self] = nil end)

	mod:hook(InventoryBackgroundView, "_save_current_talents_to_profile_preset", function(func, self, ...)
		if self._tamm_custom_talent_mode
			or (not local_official_ui_mode() and is_realms_client() and is_own_player(self._preview_player)) then
			return
		end

		return func(self, ...)
	end)

	mod:hook(InventoryBackgroundView, "_apply_current_talents_to_profile", function(func, self, ...)
		if not local_official_ui_mode() and is_realms_client() and is_own_player(self._preview_player) then
			self._tamm_custom_talent_mode = true
		end
		if not self._tamm_custom_talent_mode then
			return func(self, ...)
		end
		if not custom_talent_ui_enabled(self._preview_player) then
			mod:notify(mod:localize("custom_talent_session_disabled"))

			return Promise.resolved(false)
		end

		local player = self._preview_player
		if self._is_readonly or not is_own_player(player) then return Promise.resolved(false) end
		if is_realms_client() and not self._tamm_user_edited then return Promise.resolved(true) end
		local profile = player:profile()
		local cap = custom_talent_ui_cap(player)
		local selected_nodes = self._valid_profile_equipped_talents
		local build, save_error = save_build(profile, selected_nodes, cap, self._tamm_preset_key)

		if not build then
			mod:notify(string.format("%s: %s", mod:localize("custom_talent_build_rejected"), tostring(save_error)))
		else
			mod:notify(mod:localize("custom_talent_build_saved", build.points_spent, cap))
			state.local_apply_signature = nil
			self._tamm_user_edited = false
			if state.editor then state.editor._tamm_user_edited = false end

			if is_realms_client() then
				state.pending_build_submit = true
			else
				apply_local_profile_if_needed()
			end
		end

		if self._active_specialization_talent_loadout and self._current_profile_equipped_specialization_talents then
			Managers.data_service.talents:set_talents_v2(player, nil, {
				layout = self._active_specialization_talent_loadout,
				node_tiers = self._current_profile_equipped_specialization_talents,
			})
		end

		return Promise.resolved(build ~= nil)
	end)

	local onboarding_templates = require("scripts/ui/constant_elements/elements/onboarding_handler/onboarding_templates")

	for i = 1, #onboarding_templates do
		local template = onboarding_templates[i]

		if template.name == "Unspent Talent points available" and type(template.validation_func) == "function" then
			mod:hook(template, "validation_func", function(func, self, ...)
				local player_manager = Managers.player
				local player = player_manager and player_manager:local_player_safe(1)
				local profile = player and player:profile()

				if profile and profile.tamm_custom_talents then
					return false
				end

				return func(self, ...)
			end)

			break
		end
	end
end

install_ui_hooks()
mod.workspace_stimm_cap = function(profile)
  return Stimm.cap(profile, selection_rules().stimm_points)
end
mod.workspace_stimm_nodes = function(profile)
  local saved = stored_build(profile)
  return Stimm.project(profile, saved and saved.specialization_nodes or Stimm.filter(profile), mod.workspace_stimm_cap(profile))
end
mod.workspace_stimm_save = function(player, nodes, preset_key)
  if not owns_custom_editor(player) then return false end
  local profile = player:profile()
  local selected = Stimm.validate(profile, nodes, mod.workspace_stimm_cap(profile))
  if not selected then return false end
  local record, data, key = preset_record(profile, is_realms_client())
  if preset_key and not record.slots[preset_key] then return false end
  local build = table.clone_instance(record.slots[preset_key or record.active_key] or {})
  build.specialization_nodes = selected
  PresetStore.write(mod, data, key, record, build, preset_key)
  state.local_apply_signature = nil
  state.pending_build_submit = true
  return true
end

mod.workspace_nodes_updated = function(parent, nodes)
	if not mod:is_enabled() or not parent or not is_own_player(parent._preview_player) then return end
	parent._current_profile_equipped_talents = clone_map(nodes)
	if validate_selected_nodes(parent._preview_player:profile(), nodes, custom_talent_ui_cap(parent._preview_player)) then
		parent._valid_profile_equipped_talents = clone_map(nodes)
	end
end
mod.workspace_prepare = function(parent)
	WorkspacePresets.snapshot(parent._preview_player:profile(), true)
	parent._tamm_user_edited = false
	return InventoryBackgroundView._switch_active_view(parent, "talent_builder_view")
end
mod.workspace_commit = function(parent)
	if not mod:is_enabled() or not parent or parent.__deleted or not parent._tamm_user_edited then return end
	local player = Managers.player and Managers.player:local_player_safe(1)
	local connection = Managers.connection and (Managers.connection._connection_host or Managers.connection._connection_client)
	if parent._workspace_invalid or not player or player.__deleted or parent._preview_player ~= player then return end
	if parent._context and parent._context.parent and parent._context.parent._workspace_invalid then return end
	if parent._workspace_session_owned and (connection ~= parent._connection or player:character_id() ~= parent._character) then return end
	return InventoryBackgroundView._apply_current_talents_to_profile(parent)
end
mod.talent_workspace_page = { view_name = "realms_loadout_talent_view",
	prepare = mod.workspace_prepare, commit = mod.workspace_commit, available = owns_custom_editor }
mod.talent_workspace_page.nodes_event = "tpm_workspace_nodes_updated"
mod.talent_workspace_page.nodes_updated = mod.workspace_nodes_updated
mod.talent_workspace_pages = { { id = "talents", order = 40,
    label = function() return mod:localize("workspace_talents") end,
    page = mod.talent_workspace_page, applies = owns_custom_editor } }
mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/workspace_inventory_talents").install()
mod.workspace_native_nodes = function(player)
    if not player then return nil end
    local profile = official_profile(player:peer_id(), player:local_player_id())
    return profile and profile.selected_nodes
end
mod:add_require_path("realms_loadout/scripts/mods/realms_loadout/talents/workspace_talent_view")
mod:register_view({ view_name = mod.talent_workspace_page.view_name,
	view_settings = { class = "RealmsLoadoutTalentView", path = "realms_loadout/scripts/mods/realms_loadout/talents/workspace_talent_view",
		package = "packages/ui/views/talent_builder_view/talent_builder_view", state_bound = true,
		init_view_function = function() return true end }, view_transitions = {} })
local RealmsControls = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_player_controls")
RealmsControls.install()

local function restore_native_talent_ui()
	local function original_nodes(player)
		if not player or player.__deleted then
			return {}, nil
		end

		local profile = official_profile(player:peer_id(), player:local_player_id()) or player:profile()
		local layout = profile_layout(profile)
		local selected, nodes = profile.selected_nodes or {}, {}
		for _, node in ipairs(layout and layout.nodes or {}) do
			if selected[node.widget_name] then nodes[node.widget_name] = selected[node.widget_name] end
		end
		return nodes, layout
	end
	-- Restore parent buffers too: the native inventory saves these on exit,
	-- even if the player switched away from the talent tab before disabling.
	if state.editor then talent_views[state.editor] = true end
	for view in pairs(talent_views) do
		local preview_player = view and view._preview_player

		if not preview_player or preview_player.__deleted then
			talent_views[view] = nil
		else
			if view._tpm_status_widget then view._tpm_status_widget.content.visible = false end
			if view._tamm_custom_talent_mode then
				local parent = view._context and view._context.parent
				if parent then inventory_views[parent] = true end
				local nodes, layout = original_nodes(preview_player)
				view._tamm_custom_talent_mode = nil
				view._tamm_user_edited = nil
				view._is_readonly = view._tamm_base_readonly
				view._tamm_base_readonly = nil
				view._node_widget_tiers = nodes
				if view._context then view._context.current_profile_equipped_talents = nodes end
				view._active_profile_preset_id = ProfileUtils.get_active_profile_preset_id and ProfileUtils.get_active_profile_preset_id() or nil
				view._save_talent_changes = false
				view._draw_instant_lines = true
				if view._active_layout and layout then TalentRules.configure_layout(view._active_layout, layout, {}) end
				table.clear(view._incompatible_talents)
				for _, node in ipairs(layout and layout.nodes or {}) do
					local incompatible = node.requirements and node.requirements.incompatible_talent
					if incompatible then view._incompatible_talents[incompatible] = true end
				end
				for _, widget in ipairs(view._node_widgets or {}) do
					local selected = nodes[widget.name] ~= nil
					widget.content.has_points_spent = selected
					widget.content.highlighted = selected
					widget.content.alpha_anim_progress = selected and 1 or 0
				end
				view:_update_base_talent_loadout_presentation()
			end
		end
	end
	for parent in pairs(inventory_views) do
		local preview_player = parent and parent._preview_player

		if not preview_player or preview_player.__deleted then
			inventory_views[parent] = nil
		else
			local nodes = original_nodes(preview_player)
			parent._current_profile_equipped_talents = clone_map(nodes)
			parent._valid_profile_equipped_talents = clone_map(nodes)
			if parent._active_view_context then parent._active_view_context.current_profile_equipped_talents = parent._current_profile_equipped_talents end
			parent._tamm_custom_talent_mode = nil
			parent._tamm_user_edited = nil
			parent._modified_talents = false
			parent._invalid_talents = false
		end
	end
	talent_views = setmetatable({}, { __mode = "k" })
	inventory_views = setmetatable({}, { __mode = "k" })
end

mod.custom_talents_on_all_mods_loaded = function()
	migrate_wote_settings_once()
	update_realms_network(0)
end

mod.custom_talents_on_setting_changed = function(changed_setting)
	if changed_setting == "stimm_points"
        or changed_setting == "enable_custom_talent_points"
		or changed_setting == "local_talent_points"
		or changed_setting == "bot_talent_points"
		or changed_setting == "bot_talent_autofill"
		or changed_setting == "realms_talent_points"
		or changed_setting == "enable_local_custom_talents"
		or changed_setting == "enable_bot_custom_talents"
		or changed_setting == "enable_realms_custom_talents"
		or changed_setting == "unlock_all_auras"
		or changed_setting == "unlock_all_keystones"
	then
		state.editor_refresh_pending = true
		state.rules_serial = math.max(state.rules_serial, state.host_rules_revision) + 1
		state.host_rules_revision = state.rules_serial
		state.host_reconcile_pending = true
		state.local_apply_signature = nil
		state.pending_build_submit = is_realms_client() and state.session_rules ~= nil

		if changed_setting == "enable_custom_talent_points"
			or changed_setting == "local_talent_points"
			or changed_setting == "realms_talent_points"
			or changed_setting == "enable_realms_custom_talents"
			or changed_setting == "unlock_all_auras"
			or changed_setting == "unlock_all_keystones"
		then
			state.rules_broadcast_pending = is_realms_host()
		end
	end
end

mod.update_custom_talents = function(dt)
	local preset_player = Managers.player and Managers.player:local_player_safe(1)
	local preset_profile = preset_player and not preset_player.__deleted and preset_player:profile()
	if mod:is_enabled() and preset_profile and preset_profile.character_id and preset_profile.archetype then
		local selected = stored_build(preset_profile)
		local signature = tostring(preset_player:character_id()) .. ":" .. tostring(selected and selected.revision)
		if state.preset_signature ~= signature then
			state.preset_signature = signature
			state.local_apply_signature = nil
			state.pending_build_submit = is_realms_client() or state.pending_build_submit
		end
	end
	update_realms_network(dt)
	-- The preparation screen can open the talent editor between Run states.
	-- Keep its rule display/projection responsive while profile writes pause.
	if state.editor_refresh_pending then refresh_talent_editor() end
	if state.suspended then return end
	remember_local_official_profile()
	-- Normal updates must stay idempotent. Reconciliation is gated by
	-- host_reconcile_pending, while local application is gated by its signature.
	reconcile_host_profiles()
	apply_local_profile_if_needed()
	restore_local_official_profile_if_needed()
end

mod.cleanup_custom_talents = function(full_exit, reason)
	if full_exit then
		state.network_closed = true
		mod._custom_talent_view_initializing = false
		mod._custom_talent_view_active = false
		restore_native_talent_ui()
		RealmsControls.cleanup()
		state.rules_serial = math.max(state.rules_serial, state.host_rules_revision) + 1
		state.host_rules_revision = state.rules_serial
		state.sync:close()
	end
	state.suspended = true
	state.allow_suspended_profile_restore = full_exit == true
	mod._realms_profile_writes_suspended = true

	local profile_hooks = mod._realms_profile_hooks

	if profile_hooks and type(profile_hooks.cancel_owned_updates) == "function" then
		profile_hooks.cancel_owned_updates(active_profile_synchronizer_host(), reason or (full_exit and "full_exit" or "gameplay_exit"))
	end

	state.host_reconcile_pending = true
	-- Mission teardown destroys these player objects, so synchronizing an
	-- official profile here can leave an update queued after its player is gone.
	-- Only an explicit mod disable restores profiles that remain live.
	if full_exit then
		reconcile_host_profiles(true)
	end

	mod._custom_talent_view_initializing = false
	mod._custom_talent_view_active = false
	state.host_reconcile_pending = false
	state.host_reconcile_synchronizer = nil
	state.local_apply_signature = nil
	state.local_apply_synchronizer = nil
	state.local_official_profile_ref = nil
	state.official_ui_profiles = {}
	state.pending_build_submit = false
	state.rules_broadcast_pending = false
	if state.editor and state.editor._tpm_status_widget then state.editor._tpm_status_widget.content.visible = false end
	state.editor = nil
	if full_exit then
		state.sync:context({ role = "local", ready = false })
		state.network_registered = false
		state.session_rules = nil
	end

	-- Guests retain the host's synchronized profile. A detached local profile
	-- is restored only for an explicit disable, never during mission teardown.
	if full_exit and (not is_custom_talent_host_session() or not active_profile_synchronizer_host()) then
		restore_local_official_profile_if_needed(true)
	end

	state.allow_suspended_profile_restore = false
end

-- Preparation hands its final profile to the mission's resource synchronizer.
-- Pause new submissions during loading without replacing that profile with
-- the official build (profile restoration is reserved for explicit disable).
mod.pause_custom_talents = function()
	state.suspended = true
	mod._realms_profile_writes_suspended = true
end

mod.resume_custom_talents = function()
	RealmsControls.refresh_hooks()
	state.network_closed = false
	state.suspended = false
	state.allow_suspended_profile_restore = false
	mod._realms_profile_writes_suspended = false
	-- Native/other equipment updates can replace a profile between states even
	-- when the saved build revision and cap have not changed.
	state.local_apply_signature = nil
	state.payload_cache_key = nil
	state.pending_build_submit = is_realms_client()
	state.host_reconcile_pending = true
	state.rules_broadcast_pending = true
	update_realms_network(0)
end
