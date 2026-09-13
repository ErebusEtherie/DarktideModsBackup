local mod = get_mod("MortisBuffManager")

local GameModeSurvival = require("scripts/managers/game_mode/game_modes/game_mode_survival")
local HordeMissionBuffsManager = require("scripts/managers/mission_buffs/horde_mission_buffs_manager")
local MissionBuffsAllowedBuffs = require("scripts/managers/mission_buffs/mission_buffs_allowed_buffs")
local HordesBuffsData = require("scripts/settings/buff/hordes_buffs/hordes_buffs_data")
local MissionBuffsSettings = require("scripts/managers/mission_buffs/mission_buffs_settings")
local HordesModeSettings = require("scripts/settings/hordes_mode_settings")
local MissionBuffsParser = require("scripts/ui/constant_elements/elements/mission_buffs/utilities/mission_buffs_parser")
local Catalog = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_catalog")
local Cache = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_cache")
local player_cache = setmetatable({}, { __mode = "k" })
local audits = {}

local Draft = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_draft")
local Coordinator = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_coordinator")
local coordinator
local Policy=mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_host_policy")
local Manifest=mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_diy_manifest")
local policy
local PROTOCOL_VERSION = 9
local SELECTION_STORAGE_SETTING = "tamm_mortis_selections_v1"
local FAMILY_STORAGE_SETTING = "tamm_mortis_families_v1"
local UPDATE_INTERVAL = 0.5
local MORTIS_GAMEPLAY_PACKAGE = "content/levels/horde/missions/mission_psykhanium"

local selectable_buffs, known_buffs, buff_sources = Catalog.all_selectable(MissionBuffsAllowedBuffs, HordesBuffsData)
local family_names = Catalog.family_names(MissionBuffsAllowedBuffs)
local buff_ui_data_cache = {}
local state = mod:persistent_table("tamm_mortis_buffs")

state.applied = {}
state.connection = nil
state.elapsed = 0
state.manager = nil
state.network_registered = false
state.pending_selection_submit = false
state.remote_selections = {}
state.rules_broadcast_pending = false
state.rules_request_elapsed = 0
state.rules_revision = state.rules_revision or 1
state.selection_submit_elapsed = 0
state.session_rules = nil
state.waiting_for_gameplay_assets = false

local function normalize_peer_id(peer_id)
	return peer_id and string.lower(tostring(peer_id)) or nil
end

local function setting_enabled(setting_id)
	return mod:is_enabled() and mod._settings[setting_id] == true
end

local function selection_limit()
	local value = tonumber(mod._settings.mortis_buff_limit) or 10

	return Draft.limit(mod._settings.mortis_mode, value + 0.5)
end

local function is_realms_host()
	local context = mod.session_context()

	return context.is_realms and context.is_realms_host
end

local function is_realms_client()
	local context = mod.session_context()

	return context.is_realms and context.is_realms_client
end

local function editing_selection_limit()
	if is_realms_client() then
		local rules = state.session_rules
		return rules and rules.enabled and Draft.buff_limit(rules.mode, rules.limit) or 0
	end

	return Draft.buff_limit(mod._settings.mortis_mode, selection_limit())
end

local function has_local_authority()
	local context = mod.session_context()

	return context.is_solo_play or context.is_realms_host
end

local function manager_preconfigured_rewards_active(manager)
	return mod:is_enabled() and has_local_authority()
		and manager ~= nil
		and manager._game_mode_name == "survival"
		and manager:_is_server_or_host()
end

local function survival_preconfigured_rewards_active(game_mode)
	return mod:is_enabled() and has_local_authority()
		and game_mode ~= nil
		and game_mode._is_server == true
end

local function client_preconfigured_rewards_active()
	return is_realms_client()
		and state.session_rules ~= nil
		and state.session_rules.preconfigured == true
end

local function local_scope_enabled()
    if is_realms_client() then return mod:is_enabled() and state.session_rules and state.session_rules.native_enabled==true or false end
    return setting_enabled("enable_custom_mortis_buffs")
end
local realms_scope_enabled = local_scope_enabled
local function configured_mode()
    local value = mod._settings.mortis_mode
    return (value == "draft" or value == "competition") and value or "preselect"
end
local function effective_mode()
    if is_realms_client() then return state.session_rules and state.session_rules.mode or "preselect" end
    return configured_mode()
end
local function mission_active()
    local name = mod.session_context().game_mode_name
    return name and name ~= "hub" and name ~= "prologue_hub" and name ~= "shooting_range" and name ~= "prologue"
end
local function can_edit()
    return local_scope_enabled() and effective_mode() == "preselect" and not mission_active()
end

local function player_key(player)
	if not player then
		return nil
	end

	return string.format(
		"%s|%s|%s",
		normalize_peer_id(player:peer_id()) or "unknown",
		tostring(player:local_player_id() or 1),
		tostring(player:character_id() or "unknown")
	)
end

local function local_player()
	local player_manager = Managers.player

	return player_manager and player_manager:local_player_safe(1) or nil
end

local function is_own_player(player)
	return player ~= nil and player == local_player()
end

local function selections_storage()
	local stored = mod:get(SELECTION_STORAGE_SETTING)

	return type(stored) == "table" and stored or {}
end

local function families_storage()
	local stored = mod:get(FAMILY_STORAGE_SETTING)

	return type(stored) == "table" and stored or {}
end

local function character_storage_key(player)
	local profile = player and player:profile()
	local character_id = player and player:character_id() or profile and profile.character_id

	return character_id and tostring(character_id) or nil
end

local function stored_selection_for_player(player)
	local key = character_storage_key(player)
	local stored = key and selections_storage()[key]

	return Catalog.sanitize(stored, known_buffs, Catalog.max_selection)
end

local function stored_family_for_player(player)
	local key = character_storage_key(player)
	local stored = key and families_storage()[key]

	if Catalog.is_valid_family(MissionBuffsAllowedBuffs, stored) then
		return stored
	end

	return Catalog.infer_family(MissionBuffsAllowedBuffs, stored_selection_for_player(player))
end

local function save_selection_for_player(player, selection)
	local key = character_storage_key(player)

	if not key then
		return false, "The current character identity is unavailable"
	end

	local all_selections = selections_storage()
	local updated = {}

	for character_id, character_selection in pairs(all_selections) do
		updated[character_id] = character_selection
	end

	updated[key] = Catalog.sanitize(selection, known_buffs, Catalog.max_selection)
	mod:set(SELECTION_STORAGE_SETTING, updated)
	state.pending_selection_submit = is_realms_client()
	state.selection_submit_elapsed = 1

	return true
end

local function save_family_for_player(player, family_name)
	local key = character_storage_key(player)

	if not key or not Catalog.is_valid_family(MissionBuffsAllowedBuffs, family_name) then
		return false, "The current character identity or Mortis family is unavailable"
	end

	local all_families = families_storage()
	local updated = {}

	for character_id, character_family in pairs(all_families) do
		updated[character_id] = character_family
	end

	updated[key] = family_name
	mod:set(FAMILY_STORAGE_SETTING, updated)
	state.pending_selection_submit = is_realms_client()
	state.selection_submit_elapsed = 1

	return true
end

local function player_setup(player)
	if not player then
		return nil
	end

	local profile = player:profile()
	local player_unit = player.player_unit
	local build=mod.mortis_build_setup and mod.mortis_build_setup(player)
	local ability_extension = not build and player_unit and ALIVE[player_unit]
		and ScriptUnit.has_extension(player_unit, "ability_system")
	local grenade_ability
	local combat_ability

	if ability_extension then
		local equipped_abilities = ability_extension:equipped_abilities() or {}

		if ability_extension:has_ability_type("grenade_ability") and equipped_abilities.grenade_ability then
			grenade_ability = equipped_abilities.grenade_ability.name
		end
		if ability_extension:has_ability_type("combat_ability") and equipped_abilities.combat_ability then
			combat_ability = equipped_abilities.combat_ability.ability_group
		end
	end

	-- The hub has no spawned unit in some states, so the live ability extension
	-- can be absent while the talent tree is open. Profile talent definitions
	-- carry the same PlayerAbilities records and provide the native-equivalent
	-- fallback needed to build this character's exclusive reward pool.
	if not build and (not grenade_ability or not combat_ability) then
		local profile_grenade_ability, profile_combat_ability = Catalog.resolve_profile_abilities(profile)
		grenade_ability = grenade_ability or profile_grenade_ability
		combat_ability = combat_ability or profile_combat_ability
	end
	local archetype, talents = player:archetype_name(), profile and profile.talents or {}
    if build then
        grenade_ability=build.grenade_ability
        combat_ability=build.combat_ability
    end
	local cached = player_cache[player]
	local previous = cached and cached.setup
	if previous and cached.unit == player_unit and previous.archetype == archetype
		and previous.grenade_ability == grenade_ability and previous.combat_ability == combat_ability
		and Cache.equal(previous.talents, talents) and Cache.equal(previous.resources,build and build.resources)
        and Cache.equal(previous.weapon_slots,build and build.weapon_slots) and previous.build_complete==(build and build.complete) then
		return previous, grenade_ability ~= nil and combat_ability ~= nil and (not build or build.complete)
	end
	local setup = {
		archetype = archetype,
		combat_ability = combat_ability,
		grenade_ability = grenade_ability,
		talents = Cache.copy(talents),
        resources=build and Cache.copy(build.resources),weapon_slots=build and Cache.copy(build.weapon_slots),build_complete=build and build.complete,
	}
	player_cache[player] = { setup = setup, unit = player_unit, valid = {} }
	return setup, grenade_ability ~= nil and combat_ability ~= nil and (not build or build.complete)
end

local function valid_buffs_for_player(player, family_name)
	local setup, abilities_ready = player_setup(player)

	family_name = family_name or stored_family_for_player(player)
	local cached = player_cache[player]
	local key = family_name or false
	local valid = cached and cached.valid[key]
	if valid then return valid.lookup, abilities_ready, valid.names, valid.sources, setup, family_name end
	local buff_names, valid_buffs, sources = Catalog.valid_for_setup(
		MissionBuffsAllowedBuffs,
		known_buffs,
		setup,
		family_name
	)
	if cached then cached.valid[key] = { lookup = valid_buffs, names = buff_names, sources = sources } end

	return valid_buffs, abilities_ready, buff_names, sources, setup, family_name
end

local function allowed_buffs_for_player(player,family)
    local valid,ready=valid_buffs_for_player(player,family)
    local rules=policy and policy.current()
    local cached=player_cache[player]
    if cached.allowed and cached.allowed.source==valid and cached.allowed.rules==rules then return cached.allowed.lookup,ready end
    local allowed={};for name in pairs(valid)do if rules and not rules.native[name] then allowed[name]=true end end
    cached.allowed={source=valid,rules=rules,lookup=allowed}
    return allowed,ready
end

local function draft_pool_for_player(player)
    local setup, ready = player_setup(player)
    if not ready then return nil end
    local manager = coordinator and coordinator.mission or state.manager
    local weighted = manager and manager.get_weighted_randomization_data and manager:get_weighted_randomization_data()
    local excluded = manager and manager.get_buffs_to_exclude and manager:get_buffs_to_exclude()
    local weights = weighted and weighted.buff_family_weights
    local bans=policy and policy.current()
    local combined=Cache.copy(excluded or {})
    for name in pairs(bans and bans.native or {})do combined[name]=true end
    excluded=combined
    local cached = player_cache[player]
    local native_enabled=local_scope_enabled()
    local diy=mod.diy_mortis
    local record=coordinator and coordinator.run and coordinator.run.players[player_key(player)]
    local acquired=record and record.selected or coordinator and coordinator.role=="client" and coordinator.remote and coordinator.remote.selected or {}
    local diy_key=diy and diy.pool_key(player,acquired)
    if cached.pool and cached.manager == manager and cached.native_enabled==native_enabled and cached.diy_key==diy_key
        and Cache.equal(cached.weights, weights) and Cache.equal(cached.excluded, excluded) then return cached.pool end
    cached.manager, cached.weights, cached.excluded = manager, Cache.copy(weights), Cache.copy(excluded)
    cached.native_enabled,cached.diy_key=native_enabled,diy_key
    cached.pool = Catalog.draft_for_setup(MissionBuffsAllowedBuffs, known_buffs, setup, HordesBuffsData,
        MissionBuffsSettings, HordesModeSettings, weights, excluded)
    if not native_enabled then cached.pool.families={};cached.pool.routes={};cached.pool.legendary={};cached.pool.categories={} end
    if diy then diy.add_to_pool(cached.pool,player,acquired) end
    cached.pool.skip_family=not native_enabled
    return cached.pool
end

local function localized_buff_name(buff_name)
	local buff_data = HordesBuffsData[buff_name]
	local title_key = buff_data and buff_data.title

	if type(title_key) == "string" and title_key ~= "" and rawget(_G, "Localize") then
		local success, localized = pcall(Localize, title_key)

		if success
			and type(localized) == "string"
			and localized ~= ""
			and localized ~= title_key
			and localized ~= "<" .. title_key .. ">"
		then
			return localized
		end
	end

	local localization_key = "mortis_option_" .. tostring(buff_name)
	local localized = mod:localize(localization_key)

	return localized ~= localization_key and localized or tostring(buff_name)
end

local function localized_buff_description(buff_name)
	local buff_data = HordesBuffsData[buff_name]

	if not buff_data or type(buff_data.description) ~= "string" or buff_data.description == "" then
		return mod:localize("mortis_talent_ui_no_description")
	end

	-- This is the same formatter used by the native Mortis reward cards. In
	-- addition to localizing the sentence, it expands the Buff's live numeric
	-- stats so the talent-tree picker does not show raw placeholders.
	local value_color = Color and Color.ui_terminal and Color.ui_terminal(255, true)
	local success, description = pcall(MissionBuffsParser.get_formated_buff_description, buff_data, value_color)
	local localization_key = buff_data.description

	if success
		and type(description) == "string"
		and description ~= ""
		and description ~= localization_key
		and description ~= "<" .. localization_key .. ">"
	then
		return description
	end

	return mod:localize("mortis_talent_ui_no_description")
end

local function buff_ui_data(buff_name, include_description)
    if mod.diy_mortis and mod.diy_mortis.reward_known(buff_name) then return mod.diy_mortis.reward_ui_data(buff_name) end
	local cached = buff_ui_data_cache[buff_name]

	if not cached then
		local buff_data = HordesBuffsData[buff_name] or {}

		cached = {
			display_name = localized_buff_name(buff_name),
			gradient = buff_data.gradient,
			icon = buff_data.icon,
			subtitle = Localize(buff_data.is_family_buff and "loc_tactical_overlay_build_lesser" or "loc_tactical_overlay_build_major"),
		}
		buff_ui_data_cache[buff_name] = cached
	end
	-- List rows need titles and icons only. Format the native numeric tooltip
	-- when its detail is shown; draft/reward cards still request full text.
	if include_description ~= false and not cached.description then
		cached.description = localized_buff_description(buff_name)
	end

	return cached
end

local function notify_status(status, buff_name, limit)
	local message_key = "mortis_selection_" .. tostring(status)

	if status == "added" or status == "removed" or status == "duplicate" or status == "missing" or status == "incompatible" then
		mod:notify(mod:localize(message_key, localized_buff_name(buff_name)))
	elseif status == "full" then
		mod:notify(mod:localize(message_key, limit))
	else
		mod:notify(mod:localize("mortis_selection_unknown"))
	end
end

local function ui_selection_context()
	local player = local_player()

	if not player then
		mod:notify(mod:localize("mortis_character_unavailable"))

		return nil
	end

	local valid_buffs = valid_buffs_for_player(player)

	return player, valid_buffs
end

mod.add_selected_mortis_buff = function()
	local player, valid_buffs = ui_selection_context()

	if not player then
		return
	end

	local buff_name = mod:get("mortis_buff_to_add")
	local current = stored_selection_for_player(player)
	local limit = editing_selection_limit()
	local updated, status = Catalog.add(current, buff_name, known_buffs, valid_buffs, Catalog.max_selection)

	if status == "added" then
		save_selection_for_player(player, updated)
	end

	notify_status(status, buff_name, limit)
end

mod.remove_selected_mortis_buff = function()
	local player = local_player()

	if not player then
		mod:notify(mod:localize("mortis_character_unavailable"))

		return
	end

	local buff_name = mod:get("mortis_buff_to_remove")
	local current = stored_selection_for_player(player)
	local updated, status = Catalog.remove(current, buff_name, known_buffs)

	if status == "removed" then
		save_selection_for_player(player, updated)
	end

	notify_status(status, buff_name, selection_limit())
end

mod.clear_selected_mortis_buffs = function()
	local player = local_player()

	if not player then
		mod:notify(mod:localize("mortis_character_unavailable"))

		return
	end

	save_selection_for_player(player, {})
	mod:notify(mod:localize("mortis_selection_cleared"))
end

mod.show_selected_mortis_buffs = function()
	local player = local_player()

	if not player then
		mod:notify(mod:localize("mortis_character_unavailable"))

		return
	end

	local selection = stored_selection_for_player(player)

	if #selection == 0 then
		mod:notify(mod:localize("mortis_selection_empty"))

		return
	end

	local names = {}
	local display_count = math.min(#selection, 12)

	for i = 1, display_count do
		names[i] = localized_buff_name(selection[i])
	end

	local suffix = #selection > display_count and string.format(" ... (+%d)", #selection - display_count) or ""

	mod:notify(mod:localize("mortis_selection_summary", #selection, table.concat(names, ", ") .. suffix))
end

local function current_connection()
    local manager = Managers.connection
    return manager and (manager._connection_host or manager._connection_client) or nil
end
local function realms_mod()
    local ok, realms = pcall(get_mod, "Realms")
    return ok and realms and realms:is_enabled() and realms or nil
end
policy=Policy.new(mod,{
    client=is_realms_client,remote=function() return state.session_rules end,
    revision=function() return state.rules_revision end,
    availability=function() local rules=coordinator and coordinator:rules();return rules and rules.diy_availability end,
    missing=function(id) local rules=coordinator and coordinator:rules();return Manifest.missing(rules and rules.diy_availability,id) end,
    mission=function() return mission_active(),Managers.state and Managers.state.game_session end,
    identity=function() local p=local_player();return current_connection(),p and p:character_id() end,
    known=function(kind,id)
        if kind=="native" then return known_buffs[id]==true end
        if kind~="diy" or not mod.diy_library then return false end
        local doc=mod.diy_library.document
        for _,entry in ipairs(doc.entries)do if id==doc.id.."/"..entry.id then return true end end
        return false
    end,
    changed=function()
        state.rules_revision=state.rules_revision+1;player_cache=setmetatable({},{__mode="k"});audits={}
        if coordinator then coordinator:changed() end
        state.elapsed=UPDATE_INTERVAL
    end,
})
mod.mortis_host_policy=policy
local cached_rules
local function host_rules()
    local native_enabled, limit, mode = setting_enabled("enable_custom_mortis_buffs"), selection_limit(), configured_mode()
    local bans=policy.host_rules()
    local availability=coordinator and coordinator:compatibility()
    local diy_enabled=mod.diy_mortis and mod.diy_mortis.enabled() or false
    local enabled=native_enabled or diy_enabled
    local locked=mission_active()==true
    if cached_rules and (cached_rules.diy_availability~=availability or cached_rules.diy_enabled~=diy_enabled or cached_rules.locked~=locked) then state.rules_revision=state.rules_revision+1 end
    if not cached_rules or cached_rules.revision ~= state.rules_revision or cached_rules.enabled ~= enabled
        or cached_rules.limit ~= limit or cached_rules.mode ~= mode or cached_rules.bans ~= bans or cached_rules.native_enabled~=native_enabled then
        cached_rules = { enabled = enabled, limit = limit, mode = mode, preconfigured = true, diy_enabled=diy_enabled,
            native_enabled=native_enabled,locked=locked,revision = state.rules_revision, protocol = PROTOCOL_VERSION, bans = bans, diy_availability=availability,
            diy_limits=mod.diy_library and {max_total=mod.diy_library.options.max_total} or {max_total=6} }
    end
    return cached_rules
end
local function register_realms_network() if coordinator then coordinator:context(); coordinator:register() end end
local function update_realms_network(dt) if coordinator then coordinator:update(dt) end end

local function active_mission_buffs_manager()
	local game_mode_manager = Managers.state and Managers.state.game_mode

	if not game_mode_manager then
		return nil
	end

	local game_mode = game_mode_manager:game_mode()
	local manager = game_mode and game_mode._mission_buffs_manager

	if not manager or not manager._mission_buffs_handler or not manager:_is_server_or_host() then
		return nil
	end

	return manager
end

local function mortis_gameplay_assets_ready()
	local package_manager = Managers.package

	return package_manager ~= nil and package_manager:has_loaded(MORTIS_GAMEPLAY_PACKAGE)
end

local function player_is_ready(player)
	local unit = player and player.player_unit

	return player and player:is_human_controlled()
		and unit ~= nil
		and ALIVE[unit]
		and ScriptUnit.has_extension(unit, "buff_system") ~= nil
end

local function desired_selection_for_player(player)
    if not is_own_player(player) and coordinator and not coordinator:eligible(player) then return {}, nil end
    if effective_mode() ~= "preselect" then
        local run = coordinator and coordinator.run
        local record = run and run.players[player_key(player)]
        return local_scope_enabled() and record and Draft.selection(record, selection_limit()) or {}, record and record.family
    end
	if is_own_player(player) then
		if local_scope_enabled() then
			return policy.filter("native",stored_selection_for_player(player)), stored_family_for_player(player)
		end

		return {}, stored_family_for_player(player)
	end

	if is_realms_host() and realms_scope_enabled() then
		local peer_id = normalize_peer_id(player:peer_id())
		local peer_selections = state.remote_selections[peer_id]
		local remote = peer_selections and peer_selections[player:local_player_id()]

		if remote and remote.character_id == player:character_id() then
			return policy.filter("native",remote.selection), remote.family
		end
	end

	return {}, nil
end

local function remove_owned_buff(manager, player, buff_name)
	if not player_is_ready(player) then
		return false
	end

	local success, removal_error = pcall(
		manager._remove_externally_controlled_buff_from_player,
		manager,
		player,
		buff_name
	)

	if not success then
		mod:error("Could not remove managed Mortis Buff %s: %s", buff_name, tostring(removal_error))
	end

	return success
end

local function add_owned_buff(manager, player, buff_name)
	if not player_is_ready(player) then
		return false
	end

	local handler = manager._mission_buffs_handler

	if handler:does_player_have_buff_saved(player, buff_name) then
		return false
	end

	local success, apply_error = pcall(
		manager._add_externally_controlled_buff_to_player,
		manager,
		player,
		buff_name
	)

	if not success then
		mod:error("Could not apply managed Mortis Buff %s: %s", buff_name, tostring(apply_error))

		return false
	end

	return handler:does_player_have_buff_saved(player, buff_name)
end

local function remove_buff_from_pool(pool, buff_name)
	if type(pool) ~= "table" then
		return
	end

	for i = #pool, 1, -1 do
		if pool[i] == buff_name then
			table.remove(pool, i)
		end
	end
end

local function exclude_selected_buff_from_native_choices(handler, player, buff_name)
	local legendary_pools = handler:get_legendary_buffs_available_for_player(player)

	for _, pool in pairs(legendary_pools or {}) do
		remove_buff_from_pool(pool, buff_name)
	end

	local persistent_data = handler._persistent_data

	if persistent_data and handler:does_player_have_family_selected(player) then
		local priority_pool = persistent_data:get_player_priority_family_buffs_available(player)
		local family_pool = persistent_data:get_player_family_buffs_available(player)

		remove_buff_from_pool(priority_pool, buff_name)
		remove_buff_from_pool(family_pool, buff_name)
	end
end

local function reconcile_player(manager, player)
	local key = player_key(player)

	if not key or not player_is_ready(player) then
		return
	end

	local handler = manager._mission_buffs_handler

	if not handler then
		return
	end

	local is_survival = manager._game_mode_name == "survival"

	-- Survival initializes its legendary/family pools asynchronously from the
	-- backend. Wait for that native initialization to avoid a later duplicate
	-- restore. Ordinary adventure/Havoc missions use MissionBuffsManager too,
	-- but it intentionally has no backend pool; give_buff_to_player creates the
	-- small persistent record on first use in those modes.
	if is_survival and not handler:does_player_have_existing_data(player) then
		return
	end

	local desired, family_name = desired_selection_for_player(player)
    if not local_scope_enabled() then desired = {} end
	local valid_buffs = allowed_buffs_for_player(player, family_name)
	local limit = Draft.buff_limit(configured_mode(), selection_limit())
	local now = coordinator and coordinator.now or 0
	local audit = audits[key]
	-- Rewards/settings/build/unit changes still reconcile on the next 0.5s tick.
	-- A five-second recovery audit catches changes made outside this manager.
	-- Survival retains its native asynchronous pool exclusion cadence.
	if not is_survival and audit and audit.unit == player.player_unit and audit.handler == handler
		and audit.valid == valid_buffs and audit.limit == limit and Cache.equal(audit.desired, desired)
		and now < audit.next then return end
	local desired_lookup = {}
	local applied_count = 0
	local removed_count = 0

	for i = 1, math.min(#desired, limit) do
		local buff_name = desired[i]

		if known_buffs[buff_name] and valid_buffs[buff_name] then
			desired_lookup[buff_name] = true
		end
	end

	local owned = state.applied[key] or {}
    -- Native MissionBuffsSelector supplies this hidden adapter for the basic
    -- Ogryn box. Our custom reward flow also runs outside native Mortis setup.
    local setup=player_setup(player)
    local helper="hordes_buff_ogryn_basic_box_spawns_cluster"
    if local_scope_enabled() and setup and setup.archetype=="ogryn" and setup.grenade_ability=="ogryn_grenade_box"
        and (owned[helper] or not handler:does_player_have_buff_saved(player,helper)) then
        desired_lookup[helper]=true
        if not owned[helper] and add_owned_buff(manager,player,helper) then owned[helper]=true;applied_count=applied_count+1 end
    end

	for buff_name in pairs(owned) do
		if not desired_lookup[buff_name] then
			if remove_owned_buff(manager, player, buff_name) then
				owned[buff_name] = nil
				removed_count = removed_count + 1
			end
		elseif not handler:does_player_have_buff_saved(player, buff_name) then
			owned[buff_name] = nil
		end
	end

	-- Apply in reward order so route foundations precede their upgrades.
	for i = 1, math.min(#desired, limit) do
		local buff_name = desired[i]
		if desired_lookup[buff_name] and not owned[buff_name] and add_owned_buff(manager, player, buff_name) then
			owned[buff_name] = true
			applied_count = applied_count + 1
		end

		if is_survival and desired_lookup[buff_name] then
			-- A player's legendary pool is initialized before externally selected
			-- Buffs are applied, and the native family pool may be initialized later.
			-- Remove selected entries from both live pools so a native Mortis reward
			-- cannot offer and stack the same Buff a second time.
			exclude_selected_buff_from_native_choices(handler, player, buff_name)
		end
	end

	state.applied[key] = owned
	audits[key] = { unit = player.player_unit, handler = handler, valid = valid_buffs,
		limit = limit, desired = Cache.copy(desired), next = now + 5 }
	for name in pairs(desired_lookup) do
		if not owned[name] then audits[key].next = now; break end
	end

	if applied_count > 0 or removed_count > 0 then
		mod:info(
			"Reconciled preselected Mortis Buffs for %s in %s: applied=%d removed=%d active=%d",
			key,
			tostring(manager._game_mode_name),
			applied_count,
			removed_count,
			table.size(owned)
		)
	end
end

local function reconcile_mortis_buffs()
	local manager = has_local_authority() and active_mission_buffs_manager() or nil

	if manager ~= state.manager then
		state.manager = manager
		state.applied = {}
		audits = {}
		player_cache = setmetatable({}, { __mode = "k" })

		if manager then
			mod:info(
				"Preselected Mortis Buff runtime attached to local %s mission",
				tostring(manager._game_mode_name)
			)
		end
	end
	if not manager then
		return
	end

	-- The Mod manifest loads and retains the native Mortis level package on
	-- every peer. Ordinary adventure/Havoc missions do not load those gameplay
	-- resources themselves, so applying a Buff before the asynchronous package
	-- load completes can crash as soon as a periodic/networked particle fires.
	if not mortis_gameplay_assets_ready() then
		if not state.waiting_for_gameplay_assets then
			state.waiting_for_gameplay_assets = true
			mod:info("Waiting for native Mortis gameplay assets before applying preselected Buffs")
		end

		return
	elseif state.waiting_for_gameplay_assets then
		state.waiting_for_gameplay_assets = false
		mod:info("Native Mortis gameplay assets are ready; applying preselected Buffs")
	end

	local player_manager = Managers.player
	local players = player_manager and player_manager:human_players()

	if not players then
		return
	end

	for _, player in pairs(players) do
		reconcile_player(manager, player)
	end
end

local function cleanup_owned_buffs()
	local manager = state.manager
	local player_manager = Managers.player
	local players = manager
		and manager._mission_buffs_handler
		and player_manager
		and player_manager:human_players()

	if manager and players then
		for _, player in pairs(players) do
			local owned = state.applied[player_key(player)] or {}

			for buff_name in pairs(owned) do
				remove_owned_buff(manager, player, buff_name)
			end
		end
	end

	state.applied = {}
	state.manager = nil
end

mod.mortis_buffs_on_all_mods_loaded = function()
	register_realms_network()
    mod.mortis_buffs_on_setting_changed("mortis_mode")
end

mod.mortis_buffs_on_setting_changed = function(changed_setting)
    if (changed_setting == "mortis_mode" or changed_setting == "mortis_buff_limit") and configured_mode() ~= "draft" then
        local limit = selection_limit()
        if mod._settings.mortis_buff_limit ~= limit then
            mod._settings.mortis_buff_limit = limit; mod:set("mortis_buff_limit", limit)
        end
    end
    if changed_setting == "enable_custom_mortis_buffs" or changed_setting == "mortis_buff_limit"
        or changed_setting == "mortis_mode" or changed_setting:match("^mortis_kill_") then
        state.rules_revision = state.rules_revision + 1
        if coordinator then coordinator:changed() end
        state.elapsed = UPDATE_INTERVAL
    end
end

mod.update_mortis_buffs = function(dt)
	update_realms_network(dt)
	-- Native permissions are whole-pool only. There are no individual native
	-- exclusions to scan or notify about in any reward mode.

	state.elapsed = state.elapsed + dt

	if state.elapsed >= UPDATE_INTERVAL then
		state.elapsed = state.elapsed - UPDATE_INTERVAL
		reconcile_mortis_buffs()
	end
end

mod.cleanup_mortis_buffs = function()
    policy.reset()
    if coordinator then coordinator:cleanup() end
	cleanup_owned_buffs()
	audits = {}
	player_cache = setmetatable({}, { __mode = "k" })
	state.connection = nil
	state.elapsed = 0
	state.pending_selection_submit = false
	state.remote_selections = {}
	state.rules_broadcast_pending = false
	state.rules_request_elapsed = 0
	state.selection_submit_elapsed = 0
	state.session_rules = nil
	state.waiting_for_gameplay_assets = false
end

-- Preconfigured mode replaces the whole native reward-draft pipeline. Merely
-- hiding the card UI is insufficient: the family choice gates wave one, and
-- queued legendary choices are counted by join-in-progress catch-up. These
-- hooks stop the choices at their server-side sources while preserving normal
-- wave-completion presentation and every non-selection part of survival mode.
mod:hook(HordeMissionBuffsManager, "_request_buff_family_choice", function(func, self, ...)
	if manager_preconfigured_rewards_active(self) then
		-- Do not call buff_family_choice_initiated(): leaving the persistent
		-- requirement false makes every player ready without fabricating a
		-- family or silently granting an unselected family Buff.
		self._mission_buffs_handler:check_if_all_players_chosen_family()

		return
	end

	return func(self, ...)
end)

mod:hook(HordeMissionBuffsManager, "_request_legendary_buff_choice", function(func, self, ...)
	if manager_preconfigured_rewards_active(self) then
		return
	end

	return func(self, ...)
end)

mod:hook(HordeMissionBuffsManager, "_request_family_buff_for_all", function(func, self, ...)
	if manager_preconfigured_rewards_active(self) then
		return
	end

	return func(self, ...)
end)

mod:hook(HordeMissionBuffsManager, "check_catchup_for_new_player", function(func, self, ...)
	if manager_preconfigured_rewards_active(self) then
		return
	end

	return func(self, ...)
end)

mod:hook(HordeMissionBuffsManager, "rpc_client_mission_buffs_buff_choices_received", function(func, self, ...)
	if client_preconfigured_rewards_active() then
		return
	end

	return func(self, ...)
end)

mod:hook(GameModeSurvival, "_handle_giving_buffs_for_wave", function(func, self, ...)
	if survival_preconfigured_rewards_active(self) then
        if coordinator and configured_mode() == "draft" then coordinator:event("wave:" .. tostring(select(1, ...))) end
		-- Returning false tells survival progression that no Buff notification
		-- was queued, so it still shows the ordinary wave-complete notification.
		return false
	end

	return func(self, ...)
end)

mod.mortis_selectable_buffs = selectable_buffs
mod.mortis_native_sources = buff_sources
mod.mortis_known_buffs = known_buffs
mod.mortis_family_names = family_names

-- The talent-tree UI intentionally receives a small, read-only snapshot rather
-- than direct access to the network/session state. Selection changes still go
-- through the same persistence and validation path used by the host.
mod.mortis_talent_ui_available = function(player)
	return mod:is_enabled()
			and player ~= nil
		and is_own_player(player)
		and player:is_human_controlled()
end

-- Navigation needs permission only; do not build/sort the entire Buff catalog
-- on every equipment-window frame.
mod.mortis_talent_ui_editable = function(player)
	return mod.mortis_talent_ui_available(player) and can_edit()
end

mod.mortis_talent_ui_description = function(buff_name)
	return buff_ui_data(buff_name).description
end

mod.mortis_talent_ui_snapshot = function(player)
	if not mod.mortis_talent_ui_available(player) then
		return nil
	end

	local selection = stored_selection_for_player(player)
	local valid_lookup, abilities_ready, valid_names, sources, setup, family_name = valid_buffs_for_player(player)
	-- Eligibility tables are cached by character, abilities and route. Rebuild
	-- the sorted editor rows only when eligibility or saved selection changes.
	local cached = player_cache[player]
	local ui = cached and cached.ui_entries
    local policy_rules=policy.current()
	local entries = ui and ui.names == valid_names and ui.policy==policy_rules and Cache.equal(ui.selection, selection) and ui.entries
	if not entries then
		local selected_lookup = {}

		for i = 1, #selection do
			selected_lookup[selection[i]] = true
		end

		entries = {}

		local function append_entry(buff_name, valid, selected)
			local ui_data = buff_ui_data(buff_name, false)
			local source = sources[buff_name] or {}

			entries[#entries + 1] = {
				buff_name = buff_name,
				description = ui_data.description,
				display_name = ui_data.display_name,
				gradient = ui_data.gradient,
				icon = ui_data.icon,
				selected = selected,
				source_family = source.families and source.families[1],
				source_kind = source.kind or "stale",
				source_requirement = source.requirement,
				valid = valid and policy.allowed("native",buff_name),
                host_banned = policy_rules and policy_rules.native[buff_name] or false,
			}
		end

		-- Iterate the native pool produced for this exact archetype and equipped
		-- grenade/combat ability. This makes the UI filter explicit rather than
		-- walking the union of every class and hiding entries afterward.
		for i = 1, #valid_names do
			local buff_name = valid_names[i]
			local selected = selected_lookup[buff_name] == true

			append_entry(buff_name, true, selected)
		end

		-- Keep stale selections visible only so a character that changed class or
		-- equipped abilities can remove them. They remain disabled for addition.
		for i = 1, #selection do
			local buff_name = selection[i]

			if not valid_lookup[buff_name] then
				append_entry(buff_name, false, true)
			end
		end

		local source_order = {
			class = 1,
			generic = 2,
			family = 3,
			stale = 4,
		}

		table.sort(entries, function(left, right)
			local left_rank = source_order[left.source_kind] or 5
			local right_rank = source_order[right.source_kind] or 5

			if left_rank ~= right_rank then
				return left_rank < right_rank
			end

			if left.source_family ~= right.source_family then
				return tostring(left.source_family or "") < tostring(right.source_family or "")
			end

			local left_name = string.lower(left.display_name)
			local right_name = string.lower(right.display_name)

			if left_name == right_name then
				return left.buff_name < right.buff_name
			end

			return left_name < right_name
		end)
		if cached then cached.ui_entries = { names = valid_names, selection = Cache.copy(selection), entries = entries, policy = policy_rules } end
	end

	local client = is_realms_client()
	local rules_received = not client or state.session_rules ~= nil
	local host_enabled = not client or state.session_rules and state.session_rules.enabled or false

	return {
        mode = effective_mode(), editable = can_edit(), draft = coordinator and coordinator:snapshot(),
		abilities_ready = abilities_ready,
		apply_to_self = local_scope_enabled(),
		archetype = setup and setup.archetype,
		entries = entries,
		family = family_name,
		family_names = family_names,
		host_enabled = host_enabled,
		is_realms_client = client,
		limit = editing_selection_limit(),
		rules_received = rules_received,
		selected_count = #policy.filter("native",selection),
	}
end

mod.set_mortis_family_from_talent_ui = function(player, family_name)
	if not can_edit() or not mod.mortis_talent_ui_available(player)
		or not Catalog.is_valid_family(MissionBuffsAllowedBuffs, family_name)
	then
		return false, "unknown"
	end

	local current_family = stored_family_for_player(player)

	if family_name == current_family then
		return false, "unchanged"
	end

	local valid_buffs = valid_buffs_for_player(player, family_name)
	local current = stored_selection_for_player(player)
	local filtered = Catalog.filter_valid(current, known_buffs, valid_buffs, Catalog.max_selection)
	local saved_family, family_error = save_family_for_player(player, family_name)

	if not saved_family then
		return false, "storage", family_error
	end

	if #filtered ~= #current then
		local saved_selection, selection_error = save_selection_for_player(player, filtered)

		if not saved_selection then
			return false, "storage", selection_error
		end
	end

	return true, "changed", #current - #filtered
end

mod.toggle_mortis_buff_from_talent_ui = function(player, buff_name)
	if not can_edit() or not mod.mortis_talent_ui_available(player) or type(buff_name) ~= "string" then
		return false, "unknown", editing_selection_limit()
	end

	local current = stored_selection_for_player(player)

	for i = 1, #current do
		if current[i] == buff_name then
			local updated, status = Catalog.remove(current, buff_name, known_buffs)

			if status == "removed" then
				local saved, save_error = save_selection_for_player(player, updated)

				if not saved then
					return false, "storage", editing_selection_limit(), save_error
				end
			end

			return status == "removed", status, editing_selection_limit()
		end
	end

	local valid_buffs = allowed_buffs_for_player(player)
    if not policy.allowed("native",buff_name) then return false,"incompatible",editing_selection_limit() end
    if #policy.filter("native",current)>=editing_selection_limit() then return false,"full",editing_selection_limit() end
	local limit = editing_selection_limit()
	local updated, status = Catalog.add(current, buff_name, known_buffs, valid_buffs, Catalog.max_selection)

	if status == "added" then
		local saved, save_error = save_selection_for_player(player, updated)

		if not saved then
			return false, "storage", limit, save_error
		end
	end

	return status == "added", status, limit
end

mod.clear_mortis_buffs_from_talent_ui = function(player)
	if not can_edit() or not mod.mortis_talent_ui_available(player) then
		return false
	end

	return save_selection_for_player(player, {})
end

coordinator = Coordinator.new(mod, Draft, {
    version = "4.6.1",
    valid_bans = Policy.valid,
    valid_manifest=Manifest.valid,valid_availability=Manifest.valid_availability,valid_limits=Manifest.valid_limits,
    diy_manifest=function()
        if mod.diy_mortis then return mod.diy_mortis.manifest() end
        return {enabled=true,entries={}},"empty"
    end,
    diy_availability=Manifest.build,same_availability=Cache.equal,
    warn_peer = function(player, status)
        local profile = player:profile()
        mod:notify(mod:localize("mortis_peer_warning", profile and profile.name or tostring(player:peer_id()), mod:localize("mortis_deploy_" .. status)))
    end,
    context = function()
        local realms, connection = realms_mod(), current_connection()
        local session = realms and realms._session
        if connection and session then
            if session.is_active_host() and is_realms_host() then return connection, "host" end
            if session.is_active_client() and is_realms_client() then return connection, "client", Managers.connection:host() end
        end
        return nil, "local"
    end,
    realms = realms_mod, rules = host_rules, key = player_key, local_player = local_player,
    players = function() return Managers.player and Managers.player:human_players() end,
    mission = function() return has_local_authority() and mission_active() and active_mission_buffs_manager() or nil end,
    ready = function(player)
        if mod.mortis_request_assets then mod.mortis_request_assets()end
        return player_is_ready(player) and mortis_gameplay_assets_ready()
    end,
    assets_ready = function()
        if mod.mortis_request_assets then mod.mortis_request_assets()end
        return mortis_gameplay_assets_ready() and Managers.package:has_loaded("packages/ui/constant_elements/mission_buffs/mission_buffs")
    end,
    progress = function()
        local path = Managers.state and Managers.state.main_path
        if path and path:is_main_path_ready() and path:is_main_path_available() and path:path_type() == "linear" then
            return path:furthest_travel_percentage(1)
        end
    end,
    pool = draft_pool_for_player,
    setup = player_setup,
    known = function(name) return type(name) == "string" and (known_buffs[name] == true or mod.diy_mortis and mod.diy_mortis.reward_known(name)) end,
    known_family = function(name) return Catalog.is_valid_family(MissionBuffsAllowedBuffs, name) end,
    payload = function()
        local player = local_player()
        if not player then return end
        return { character_id = player:character_id(), archetype = player:archetype_name(), local_player_id = 1,
            family = stored_family_for_player(player), selection = local_scope_enabled() and policy.filter("native",stored_selection_for_player(player)) or {} }
    end,
    accept = function(player, payload)
        if not local_scope_enabled() and type(payload.selection)=="table" and next(payload.selection) then return false end
        if not Catalog.is_valid_family(MissionBuffsAllowedBuffs, payload.family) then return false end
        local valid, ready = allowed_buffs_for_player(player, payload.family)
        if not ready then return false end
        local selection = Catalog.validate(payload.selection, known_buffs, valid, Catalog.max_selection)
        if not selection then return false end
        local peer = normalize_peer_id(player:peer_id())
        state.remote_selections[peer] = state.remote_selections[peer] or {}
        local previous = state.remote_selections[peer][1]
        if mission_active() and previous and previous.character_id == payload.character_id then return true end
        state.remote_selections[peer][1] = { character_id = payload.character_id, family = payload.family, selection = selection }
        return true
    end,
}, state)
mod.mortis_rules = function() return coordinator:rules() end
mod.mortis_diy_configuration_changed=function()
    state.rules_revision=state.rules_revision+1;coordinator:changed();state.elapsed=UPDATE_INTERVAL
end
mod.mortis_diy_reward_ids=function(player)
    local record=coordinator.run and coordinator.run.players[player_key(player)]
    local result={}
    local selected=record and Draft.selection(record,selection_limit()) or coordinator.role=="client" and coordinator.remote and coordinator.remote.selected or {}
    for _,id in ipairs(selected)do
        if type(id)=="string" and id:sub(1,5)=="diy::" then result[#result+1]=id:sub(6) end
    end
    return result
end
mod.mortis_reward_mode=effective_mode
mod.mortis_inspect_native=function(player)
    local selected=stored_selection_for_player(player)
    local setup=player_setup(player);local cache=player_cache[player]
    local mode=effective_mode();local family=stored_family_for_player(player)
    local record=cache.inspection
    if not record or record.mode~=mode or record.family~=family then
        local lookup={}
        local families=mode=="preselect" and {family} or family_names
        for _,name in ipairs(families)do
            local _,valid=Catalog.valid_for_setup(MissionBuffsAllowedBuffs,known_buffs,setup,name)
            for id in pairs(valid)do lookup[id]=true end
        end
        record={lookup=lookup,mode=mode,family=family};cache.inspection=record
    end
    return record.lookup,selected,family,editing_selection_limit()
end
mod.mortis_inspection_pool=draft_pool_for_player
mod.mortis_workspace_set_rules=function(mode,limit,native,diy)
    if not policy.editable() or (mode~="preselect" and mode~="draft" and mode~="competition")
        or type(limit)~="number" or limit~=limit or limit%1~=0 or limit<0 or limit>99
        or type(native)~="boolean" or type(diy)~="boolean" then return false end
    if mod.diy_library and not mod.diy_library.set_options({enabled=diy,mode="manual"}) then return false end
    mod._settings.mortis_mode=mode;mod:set("mortis_mode",mode)
    mod._settings.enable_custom_mortis_buffs=native;mod:set("enable_custom_mortis_buffs",native)
    if mode~="draft" then mod._settings.mortis_buff_limit=limit;mod:set("mortis_buff_limit",limit) end
    state.rules_revision=state.rules_revision+1;coordinator:changed();state.elapsed=UPDATE_INTERVAL
    return true
end
mod.mortis_workspace_set_diy_rules=function(limit,enabled)
    if not policy.editable() or not mod.diy_library
        or type(limit)~="number" or limit~=limit or limit%1~=0 or limit<0 or limit>99
        or type(enabled)~="boolean" then return false end
    return mod.diy_library.set_options({max_total=limit,enabled=enabled,mode="manual"})
end
mod.mortis_diy_family=function(player)
    if not local_scope_enabled() then return nil end
    if is_realms_client() and is_own_player(player) and effective_mode()~="preselect" then return coordinator.remote and coordinator.remote.family end
    local _,family=desired_selection_for_player(player);return family
end
mod.mortis_draft_snapshot = function() return coordinator:snapshot() end
mod.mortis_peer_deployment = function(peer) return coordinator:deployment(peer) end
mod.mortis_buff_ui_data = buff_ui_data
mod.mortis_choice_ui_data = function(name, kind)
    if kind ~= "family" then return buff_ui_data(name) end
    local family = MissionBuffsAllowedBuffs.buff_families[name]
    if not family then return nil end
    local seed = (family.priority_buffs or {})[1] or (family.buffs or {})[1]
    local first = seed and buff_ui_data(seed) or {}
    local native = HordesBuffsData["hordes_family_" .. name] or {}
    local native_ui = buff_ui_data("hordes_family_" .. name)
    return { display_name = native.title and native_ui.display_name or mod:localize("mortis_talent_ui_family_" .. name),
        description = native.description and native_ui.description or first.description or "",
        subtitle = Localize("loc_horde_buff_family_pick"), family = true,
        icon = native.icon or first.icon, gradient = native.gradient or first.gradient }
end
mod.choose_mortis_draft = function(index)
    local snapshot = coordinator:snapshot()
    local player = local_player()
    if player and snapshot and snapshot.active then return coordinator:choose(player, snapshot.active.id, index) end
    return false
end
mod.mortis_realms_controls_active = function()
    local realms = realms_mod()
    return mod:is_enabled() and realms and realms._session and realms._session.is_active_host()
        and is_realms_host() and current_connection() ~= nil or false
end
mod.set_mortis_global_rules = function(mode, limit, enabled, connection)
    if not policy.editable() or not mod.mortis_realms_controls_active() or current_connection() ~= connection
        or (mode ~= "preselect" and mode ~= "draft" and mode ~= "competition")
        or type(limit) ~= "number" or limit ~= limit or limit % 1 ~= 0 or limit < 0 or limit > Catalog.max_selection
        or type(enabled) ~= "boolean" then return false end
    limit = Draft.limit(mode, limit)
    local values = { mortis_mode = mode, enable_custom_mortis_buffs = enabled }
    -- The fixed progress quota must not overwrite the editable setting.
    if mode ~= "draft" then values.mortis_buff_limit = limit end
    for key, value in pairs(values) do
        mod._settings[key] = value; mod:set(key, value)
    end
    state.rules_revision = state.rules_revision + 1; coordinator:changed(); state.elapsed = UPDATE_INTERVAL
    return true
end
mod.mortis_global_rules_snapshot = function()
    if not mod.mortis_realms_controls_active() then return nil end
    return host_rules(), current_connection()
end
mod.set_mortis_diy_rules=function(limit,enabled,connection)
    if not mod.mortis_realms_controls_active() or current_connection()~=connection then return false end
    return mod.mortis_workspace_set_diy_rules(limit,enabled)
end
local MissionObjectiveSystem = require("scripts/extension_systems/mission_objective/mission_objective_system")
mod:hook(MissionObjectiveSystem, "start_mission_objective", function(func, self, name, group, ...)
    local result = func(self, name, group, ...)
    local key
    if self._is_server and local_scope_enabled() and configured_mode() == "draft"
        and mod.session_context().game_mode_name ~= "survival" then
        local objective = self:active_objective(name, group)
        if objective and not objective:is_side_mission() then key = "objective:" .. tostring(group or 1) .. ":" .. tostring(name) end
    end
    if key then coordinator:event(key) end
    return result
end)
local AttackReportManager = require("scripts/managers/attack_report/attack_report_manager")
local Breed = require("scripts/utilities/breed")
local kill_defaults = { horde = 0.25, special = 5, elite = 2.5, boss = 40, weakened_boss = 20, captain = 50 }
local breed_kinds=setmetatable({},{__mode="k"})
mod:hook_safe(AttackReportManager, "add_attack_result", function(self, profile, victim, attacker, direction, position, weakspot, damage, result, attack_type, efficiency, critical)
    if self._is_server and result=="died" and mod.diy_mortis then mod.diy_mortis.enemy_died(victim,attacker,damage,attack_type,critical) end
    if not self._is_server or result ~= "died" or configured_mode() ~= "competition" or not setting_enabled("enable_custom_mortis_buffs")
        or not coordinator.run or not victim or not attacker then return end
    local spawn = Managers.state and Managers.state.player_unit_spawn
    local player = spawn and spawn:owner(attacker)
    if not player or not player:is_human_controlled() or not coordinator:counting(player,victim) then return end
    local breed = Breed.unit_breed_or_nil(victim)
    if not breed or not Breed.is_minion(breed) then return end
    local kind = breed_kinds[breed]
    if not kind then kind=Breed.enemy_type(breed);breed_kinds[breed]=kind end
    -- The breed classification is immutable. Only monsters need the native
    -- per-instance weakened-boss flag; ordinary deaths need no boss lookup.
    local boss = kind=="monster" and ScriptUnit.has_extension(victim, "boss_system")
    local category = kind == "captain" and "captain"
        or kind == "monster" and (boss and boss.is_weakened and boss:is_weakened() and "weakened_boss" or "boss")
        or kind == "elite" and "elite" or kind == "special" and "special" or "horde"
    coordinator:kill(player, victim, tonumber(mod._settings["mortis_kill_" .. category])
        or kill_defaults[category])
end)
