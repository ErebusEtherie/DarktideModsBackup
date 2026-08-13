-- valkyrie.lua
local mod = get_mod("valkyrie")
local Missions = require("scripts/settings/mission/mission_templates")
local MissionIntroViewSettings = require("scripts/ui/views/mission_intro_view/mission_intro_view_settings")
local UIProfileSpawner = require("scripts/managers/ui/ui_profile_spawner")
local ui_renderer_ok, UIRenderer = pcall(require, "scripts/managers/ui/ui_renderer")
if not ui_renderer_ok then
UIRenderer = nil
end
local MasterItems = require("scripts/backend/master_items")
local ProfileUtils = require("scripts/utilities/profile_utils")
local ScriptWorld = require("scripts/foundation/utilities/script_world")
local ui_settings_ok, UISettings = pcall(require, "scripts/settings/ui/ui_settings")
if not ui_settings_ok then
UISettings = nil
end
local archetype_talents_ok, ArchetypeTalents = pcall(require, "scripts/settings/ability/archetype_talents/archetype_talents")
if not archetype_talents_ok then
ArchetypeTalents = nil
end
local view_loader_ok, ViewLoader = pcall(require, "scripts/loading/loaders/view_loader")
if not view_loader_ok then
ViewLoader = nil
end
local SteadyCameraModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_steady_camera")
local BusinessCardsModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_business_cards")
local WeaponPresentationModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_weapon_presentation")
local BabooshkaModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_babooshka")
local NoUniformsModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_no_uniforms")
local ExtraBotsModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_extra_bots")
local ValkCommandModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_command")
local SuppressionModule = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_suppression")
local MAX_VALKYRIE_OCCUPANTS = 4
local SHOW_WHO_DEFAULT = "default"
local SHOW_WHO_NO_ONE = "no_one"
local SHOW_WHO_ONLY_ME = "only_me"
local EXPERIMENTAL_NONE = "none"
local EXPERIMENTAL_EXTRA_BOTS = "extra_bots"
local EXPERIMENTAL_NO_UNIFORMS = "no_uniforms"
local EXPERIMENTAL_WEAPON_PRESENTATION = "weapon_presentation"
local EXPERIMENTAL_BABOOSHKA = "babooshka"
local in_lobby = false
local lobby_start_detected = false
local suppress_next_lobby_exit_start = false
local silent_mode = true
local in_mission_intro = false
local active_intro_view = nil
local original_ignored_slots = table.clone(MissionIntroViewSettings.ignored_slots)
local temp_sorted_players = {}
local temp_seen_players = {}
local current_intro_local_unique_id = nil
local active_intro_spawners = setmetatable({}, { __mode = "k" })
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
local function mission_template_is_expedition(mission_name)
local mission_template = mission_name and Missions[mission_name]
return mission_template and mission_template.expedition_template ~= nil or false
end
local function mission_template_is_mortis_trials(mission_name)
local mission_template = mission_name and Missions[mission_name]
return mission_template and (mission_template.game_mode_name == "survival" or mission_template.mission_type == "horde" or mission_template.zone_id == "horde") or false
end
local function is_expedition_start(data)
return data and (data.expedition_template_name ~= nil or data.node_id ~= nil or mission_template_is_expedition(data.mission_name)) or false
end
local function is_mortis_trials_start(data)
return data and mission_template_is_mortis_trials(data.mission_name) or false
end
local function transition_data(key, params)
if type(params) == "table" then
if type(params.mechanism_data) == "table" then
return params.mechanism_data
end
if type(params.next_state_params) == "table" and type(params.next_state_params.mechanism_data) == "table" then
return params.next_state_params.mechanism_data
end
if params.mission_name then
return params
end
end
if type(key) == "table" then
if type(key.mechanism_data) == "table" then
return key.mechanism_data
end
if key.mission_name then
return key
end
end
return nil
end
local current_game_mode_name
local function current_show_who()
local value = mod:get("show_who")
if value == SHOW_WHO_NO_ONE or value == SHOW_WHO_ONLY_ME then
return value
end
return SHOW_WHO_DEFAULT
end
local function current_experimental()
local value = mod:get("experimental")
if value == EXPERIMENTAL_EXTRA_BOTS or value == EXPERIMENTAL_NO_UNIFORMS or value == EXPERIMENTAL_WEAPON_PRESENTATION or value == EXPERIMENTAL_BABOOSHKA then
return value
end
return EXPERIMENTAL_NONE
end
local function should_no_uniform()
if not mod:is_enabled() or current_experimental() ~= EXPERIMENTAL_NO_UNIFORMS then
return false
end
local show_who = current_show_who()
return show_who == SHOW_WHO_DEFAULT or show_who == SHOW_WHO_ONLY_ME
end
local function is_lobby_view_active()
local ui_manager = Managers.ui
if not ui_manager or not ui_manager.view_active then
return false
end
local ok, active = pcall(function()
return ui_manager:view_active("lobby_view")
end)
return ok and active or false
end
current_game_mode_name = function()
local game_mode_manager = Managers.state and Managers.state.game_mode
if not game_mode_manager or not game_mode_manager.game_mode_name then
return nil
end
local ok, game_mode_name = pcall(function()
return game_mode_manager:game_mode_name()
end)
return ok and game_mode_name or nil
end
local function is_hub()
return current_game_mode_name() == "hub"
end
local function should_silence_from_lobby()
return get_option("mute_lobby_mission", false) and true or false
end
local function mark_lobby_start()
suppress_next_lobby_exit_start = false
lobby_start_detected = true
silent_mode = should_silence_from_lobby()
end
local function mark_in_progress_start()
lobby_start_detected = false
silent_mode = true
end
local function cancel_lobby_start()
mark_in_progress_start()
suppress_next_lobby_exit_start = true
end
local function voting_is_mission_lobby_ready(voting)
local template = voting and voting._template
return template and template.name == "mission_lobby_ready" or false
end
local function is_mortis_trials()
return current_game_mode_name() == "survival" or is_mortis_trials_start(get_mechanism_data())
end
local function should_block_briefing()
if not mod:is_enabled() or is_lobby_view_active() then
return false
end
if lobby_start_detected then
return should_silence_from_lobby()
end
return silent_mode
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
local function should_show_babooshka()
if not mod:is_enabled() or current_experimental() ~= EXPERIMENTAL_BABOOSHKA then
return false
end
local show_who = current_show_who()
return show_who == SHOW_WHO_DEFAULT or show_who == SHOW_WHO_ONLY_ME
end
local function should_use_standing_presentation()
return should_show_weapon() or should_show_babooshka()
end
local function should_steady_camera()
return mod:is_enabled() and get_option("steady_camera", false)
end
local function player_is_destroyed(player)
return type(player) == "table" and rawget(player, "__deleted") == true
end
local function player_unique_id(player)
if not player or player_is_destroyed(player) then
return nil
end
local ok, unique_id = pcall(function()
local unique_id_func = player.unique_id
return unique_id_func and unique_id_func(player)
end)
return ok and unique_id or nil
end
local function player_profile(player)
if not player or player_is_destroyed(player) then
return nil
end
local ok, profile = pcall(function()
local profile_func = player.profile
return profile_func and profile_func(player)
end)
return ok and profile or nil
end
local function profile_breed_name(profile)
local archetype = profile and profile.archetype
return archetype and archetype.breed
end
local function player_breed_name(player)
if player and not player_is_destroyed(player) then
local ok, breed_name = pcall(function()
local breed_name_func = player.breed_name
return breed_name_func and breed_name_func(player)
end)
if ok and breed_name then
return breed_name
end
end
return profile_breed_name(player_profile(player))
end
local function player_slot(player)
if player and not player_is_destroyed(player) then
local ok, slot = pcall(function()
local slot_func = player.slot
return slot_func and slot_func(player)
end)
if ok and type(slot) == "number" then
return slot
end
end
return MAX_VALKYRIE_OCCUPANTS + 1
end
local function is_ogryn_breed_name(breed_name)
if type(breed_name) ~= "string" then
return false
end
return string.find(string.lower(breed_name), "ogryn", 1, true) ~= nil
end
local function is_ogryn_player(player, profile)
return is_ogryn_breed_name(player_breed_name(player)) or is_ogryn_breed_name(profile_breed_name(profile))
end
local function add_intro_player(players, seen, player, unique_id)
if not player or player_is_destroyed(player) or #players >= MAX_VALKYRIE_OCCUPANTS then
return
end
unique_id = unique_id or player_unique_id(player)
if unique_id and not seen[unique_id] then
players[#players + 1] = player
seen[unique_id] = true
end
end
local function is_human_player(player)
if not player or player_is_destroyed(player) then
return false
end
local ok, is_human = pcall(function()
local is_human_func = player.is_human_controlled
return is_human_func and is_human_func(player)
end)
return ok and is_human == true
end
local function local_player_id(player_manager)
local ok, local_player = pcall(function()
local local_player_func = player_manager and player_manager.local_player
return local_player_func and local_player_func(player_manager, 1)
end)
local_player = ok and local_player or nil
return local_player, player_unique_id(local_player)
end
local function is_local_player(player)
if not player or player_is_destroyed(player) then
return false
end
local local_unique_id = current_intro_local_unique_id
if local_unique_id == nil then
local _, resolved_local_unique_id = local_player_id(Managers.player)
local_unique_id = resolved_local_unique_id
end
return local_unique_id ~= nil and player_unique_id(player) == local_unique_id
end
local function unit_alive(unit)
return unit and Unit and Unit.alive(unit)
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
local SteadyCamera = SteadyCameraModule.init({
ScriptWorld = ScriptWorld,
MissionIntroViewSettings = MissionIntroViewSettings,
Missions = Missions,
max_occupants = MAX_VALKYRIE_OCCUPANTS,
get_mechanism_data = get_mechanism_data,
is_expedition_start = is_expedition_start,
should_steady_camera = should_steady_camera,
unit_alive = unit_alive,
in_mission_intro = function()
return in_mission_intro
end,
active_intro_view = function()
return active_intro_view
end,
})
local BusinessCards = BusinessCardsModule.init({
UIRenderer = UIRenderer,
UISettings = UISettings,
ArchetypeTalents = ArchetypeTalents,
ProfileUtils = ProfileUtils,
max_occupants = MAX_VALKYRIE_OCCUPANTS,
get_option = get_option,
in_mission_intro = function()
return in_mission_intro
end,
player_profile = player_profile,
player_unique_id = player_unique_id,
player_is_destroyed = player_is_destroyed,
is_local_player = is_local_player,
steady_camera_camera = SteadyCamera.camera,
unit_alive = unit_alive,
is_mortis_trials = is_mortis_trials,
})
local WeaponPresentation = WeaponPresentationModule.init({
max_occupants = MAX_VALKYRIE_OCCUPANTS,
original_ignored_slots = original_ignored_slots,
should_show_weapon = should_show_weapon,
should_no_uniform = should_no_uniform,
should_use_standing_presentation = should_use_standing_presentation,
player_profile = player_profile,
active_intro_view = function()
return active_intro_view
end,
steady_camera_camera = SteadyCamera.camera,
unit_alive = unit_alive,
})
local Babooshka = BabooshkaModule.init({
max_occupants = MAX_VALKYRIE_OCCUPANTS,
should_show_babooshka = should_show_babooshka,
steady_camera_camera = SteadyCamera.camera,
active_intro_view = function()
return active_intro_view
end,
unit_alive = unit_alive,
is_ogryn_player = is_ogryn_player,
player_profile = player_profile,
})
local NoUniforms = NoUniformsModule.init({
MasterItems = MasterItems,
})
local ExtraBots = ExtraBotsModule.init({
ProfileUtils = ProfileUtils,
max_occupants = MAX_VALKYRIE_OCCUPANTS,
temp_sorted_players = temp_sorted_players,
temp_seen_players = temp_seen_players,
should_show_bots = should_show_bots,
should_show_player_in_intro = should_show_player_in_intro,
add_intro_player = add_intro_player,
})
local ValkCommand = ValkCommandModule.init({
mod = mod,
Missions = Missions,
get_mechanism_data = get_mechanism_data,
is_hub = is_hub,
})
local Suppression = SuppressionModule.init({
mod = mod,
is_lobby_view_active = is_lobby_view_active,
is_mortis_trials = is_mortis_trials,
should_block_briefing = should_block_briefing,
})
local function clear_intro_spawner_flags()
for profile_spawner, _ in pairs(active_intro_spawners) do
profile_spawner._valkyrie_intro_spawner = nil
WeaponPresentation.clear_spawner_flags(profile_spawner)
Babooshka.clear_spawner_flags(profile_spawner)
end
table.clear(active_intro_spawners)
WeaponPresentation.clear_state()
end
local function reset_intro_visual_state()
BusinessCards.clear_state(active_intro_view)
in_mission_intro = false
active_intro_view = nil
current_intro_local_unique_id = nil
MissionIntroViewSettings.ignored_slots = original_ignored_slots
clear_intro_spawner_flags()
SteadyCamera.clear_state()
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
ExtraBots.collect_real_bot_intro_players(player_manager)
ExtraBots.fill_intro_with_fallback_bots()
end
local function intro_sort_value(player)
local local_bonus = is_local_player(player) and -10000 or 0
local bot_bonus = is_human_player(player) and 0 or 1000
local ogryn_bonus = is_ogryn_player(player, player_profile(player)) and 100 or 0
return local_bonus + bot_bonus + ogryn_bonus + player_slot(player)
end
local function sort_intro_players(a, b)
return intro_sort_value(a) < intro_sort_value(b)
end
function mod.on_game_state_changed(status)
if status == "exit" then
reset_intro_visual_state()
end
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView.select_target_intro_level then
mod:hook(CLASS.MissionIntroView, "select_target_intro_level", function(func, mission_name, ...)
local intro_level, intro_level_packages = func(mission_name, ...)
if SteadyCamera.should_force_default_intro_level(mission_name) or SteadyCamera.is_expeditions_intro_level(intro_level) and should_steady_camera() then
local default_intro_level, default_intro_level_packages = SteadyCamera.default_intro_level_with_package()
if default_intro_level and default_intro_level_packages then
return default_intro_level, default_intro_level_packages
end
end
return intro_level, intro_level_packages
end)
end
if ViewLoader and ViewLoader._get_dynamic_package_for_view then
mod:hook(ViewLoader, "_get_dynamic_package_for_view", function(func, self, view_name, mission_name, ...)
if view_name == "mission_intro_view" and SteadyCamera.should_force_default_intro_level(mission_name) then
local _, default_intro_level_packages = SteadyCamera.default_intro_level_with_package()
if default_intro_level_packages then
return default_intro_level_packages
end
end
return func(self, view_name, mission_name, ...)
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView._initialize_background_world then
mod:hook(CLASS.MissionIntroView, "_initialize_background_world", function(func, self, ...)
if SteadyCamera.should_force_default_intro_level() or SteadyCamera.is_expeditions_intro_level(self and self._intro_level) and should_steady_camera() then
local default_intro_level = SteadyCamera.default_intro_level_with_package()
if default_intro_level then
self._intro_level = default_intro_level
self._intro_level_theme = self._get_intro_level_theme and self._get_intro_level_theme(default_intro_level) or {}
SteadyCamera.clear_state()
end
end
return func(self, ...)
end)
end
mod:hook("VotingByNetworkImpl", "_on_started", function(func, self, voting_id, template, params, initiator_peer)
if template and template.name == "mission_lobby_ready" then
mark_lobby_start()
end
return func(self, voting_id, template, params, initiator_peer)
end)
mod:hook("VotingClient", "on_voting_aborted", function(func, self, reason, ...)
if voting_is_mission_lobby_ready(self) then
cancel_lobby_start()
end
return func(self, reason, ...)
end)
mod:hook("VotingHost", "on_voting_aborted", function(func, self, reason, ...)
if voting_is_mission_lobby_ready(self) then
cancel_lobby_start()
end
return func(self, reason, ...)
end)
mod:hook("LevelTransitionHandler", "on_mission_start", function(func, self, key, params)
ValkCommand.reset_report()
local from_lobby = lobby_start_detected or in_lobby or is_lobby_view_active()
if from_lobby then
mark_lobby_start()
else
mark_in_progress_start()
end
reset_intro_visual_state()
return func(self, key, params)
end)
if CLASS and CLASS.StateMainMenu and CLASS.StateMainMenu.event_continue_cb then
mod:hook_safe(CLASS.StateMainMenu, "event_continue_cb", function()
reset_intro_visual_state()
end)
end
if CLASS and CLASS.LobbyView and CLASS.LobbyView.on_enter then
mod:hook_safe(CLASS.LobbyView, "on_enter", function()
in_lobby = true
end)
end
if CLASS and CLASS.LobbyView and CLASS.LobbyView._setup_loadout_widgets then
mod:hook_safe(CLASS.LobbyView, "_setup_loadout_widgets", function()
in_lobby = true
end)
end
if CLASS and CLASS.LobbyView and CLASS.LobbyView.trigger_on_exit_animation then
mod:hook_safe(CLASS.LobbyView, "trigger_on_exit_animation", function(self)
if self and self._is_animating_on_exit and not suppress_next_lobby_exit_start then
mark_lobby_start()
end
end)
end
if CLASS and CLASS.LobbyView and CLASS.LobbyView.on_exit then
mod:hook_safe(CLASS.LobbyView, "on_exit", function()
if in_lobby then
if suppress_next_lobby_exit_start then
suppress_next_lobby_exit_start = false
mark_in_progress_start()
else
mark_lobby_start()
end
end
in_lobby = false
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView.on_enter then
mod:hook_safe(CLASS.MissionIntroView, "on_enter", function(self)
ValkCommand.reset_report()
in_mission_intro = true
active_intro_view = self
NoUniforms.clear_cache()
BusinessCards.clear_state(self)
local data = get_mechanism_data()
ValkCommand.refresh_values(data)
if lobby_start_detected or in_lobby or is_lobby_view_active() then
mark_lobby_start()
end
Suppression.set_briefing_done_if_silent(self)
ValkCommand.send(ValkCommand.REPORT_VALKYRIE_START)
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView.event_register_mission_intro_camera then
mod:hook_safe(CLASS.MissionIntroView, "event_register_mission_intro_camera", function(self)
SteadyCamera.ensure(self and self._world_spawner)
Babooshka.update_slot_scales(self)
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView._setup_spawn_slots then
mod:hook(CLASS.MissionIntroView, "_setup_spawn_slots", function(func, self, ...)
local old_ignored_slots = MissionIntroViewSettings.ignored_slots
if should_show_weapon() then
MissionIntroViewSettings.ignored_slots = WeaponPresentation.get_ignored_slots_without_weapons()
end
local result = func(self, ...)
MissionIntroViewSettings.ignored_slots = old_ignored_slots
mark_intro_spawners(self)
Babooshka.update_slot_scales(self)
return result
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView._assign_player_slots then
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
local spawn_slots = self and self._spawn_slots
if not spawn_slots then
return func(self, ...)
end
local assigned_count = 0
for i = 1, #temp_sorted_players do
if assigned_count >= MAX_VALKYRIE_OCCUPANTS then
break
end
local player = temp_sorted_players[i]
if should_show_player_in_intro(player) then
local unique_id = player_unique_id(player)
local slot_id = unique_id and self._player_slot_id and self:_player_slot_id(unique_id)
local already_assigned = slot_id ~= nil
if not slot_id and self._get_free_slot_id then
slot_id = player_profile(player) and self:_get_free_slot_id(player)
end
local slot = slot_id and spawn_slots[slot_id]
if slot then
assigned_count = assigned_count + 1
mark_intro_spawner(slot.profile_spawner)
Babooshka.apply_player_to_slot(player, slot)
WeaponPresentation.queue_intro_weapon(player, slot)
if not already_assigned and self._assign_player_to_slot then
self:_assign_player_to_slot(player, slot)
end
BusinessCards.cache_for_slot(player, slot)
WeaponPresentation.wield_intro_weapon(player, slot)
end
end
end
WeaponPresentation.wield_all_intro_weapons(self)
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView._assign_player_to_slot then
mod:hook(CLASS.MissionIntroView, "_assign_player_to_slot", function(func, self, player, slot, ...)
if not should_show_player_in_intro(player) then
return
end
mark_intro_spawner(slot and slot.profile_spawner)
Babooshka.apply_player_to_slot(player, slot)
WeaponPresentation.queue_intro_weapon(player, slot)
local result = func(self, player, slot, ...)
BusinessCards.cache_for_slot(player, slot)
WeaponPresentation.wield_intro_weapon(player, slot)
return result
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView._update_player_slots then
mod:hook(CLASS.MissionIntroView, "_update_player_slots", function(func, self, ...)
local result = func(self, ...)
mark_intro_spawners(self)
WeaponPresentation.wield_all_intro_weapons(self)
return result
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView.update then
mod:hook_safe(CLASS.MissionIntroView, "update", function(self)
Suppression.set_briefing_done_if_silent(self)
mark_intro_spawners(self)
WeaponPresentation.wield_all_intro_weapons(self)
SteadyCamera.apply()
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView.draw then
mod:hook(CLASS.MissionIntroView, "draw", function(func, self, dt, t, input_service, layer, ...)
local result = func(self, dt, t, input_service, layer, ...)
BusinessCards.draw_cards(self, dt, input_service, layer)
return result
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView.destroy then
mod:hook_safe(CLASS.MissionIntroView, "destroy", function()
reset_intro_visual_state()
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView.on_exit then
mod:hook_safe(CLASS.MissionIntroView, "on_exit", function()
ValkCommand.send(ValkCommand.REPORT_MISSION_START)
silent_mode = true
lobby_start_detected = false
in_lobby = false
reset_intro_visual_state()
end)
end
if UIProfileSpawner and UIProfileSpawner.spawn_profile then
mod:hook(UIProfileSpawner, "spawn_profile", function(func, self, profile, position, rotation, scale, state_machine_or_nil, animation_event_or_nil, face_state_machine_key_or_nil, face_animation_event_or_nil, force_highest_mip_or_nil, disable_hair_state_machine_or_nil, optional_unit_3p, optional_ignore_state_machine, companion_data)
if should_apply_no_uniform_to_spawner(self) then
profile = NoUniforms.profile(profile)
WeaponPresentation.clear_spawner_flags(self)
elseif is_intro_spawner(self) and should_use_standing_presentation() then
position = WeaponPresentation.inward_position(position)
state_machine_or_nil = nil
animation_event_or_nil = nil
if should_show_babooshka() then
scale = Babooshka.spawn_scale(self, profile, scale)
end
end
return func(self, profile, position, rotation, scale, state_machine_or_nil, animation_event_or_nil, face_state_machine_key_or_nil, face_animation_event_or_nil, force_highest_mip_or_nil, disable_hair_state_machine_or_nil, optional_unit_3p, optional_ignore_state_machine, companion_data)
end)
end
if UIProfileSpawner and UIProfileSpawner._change_slot_items then
mod:hook(UIProfileSpawner, "_change_slot_items", function(func, self, changed_items, loadout, visual_loadout, equipped_items_or_nil, ...)
if should_apply_no_uniform_to_spawner(self) then
changed_items, visual_loadout = NoUniforms.add_changed_items(changed_items, visual_loadout)
WeaponPresentation.clear_spawner_flags(self)
end
return func(self, changed_items, loadout, visual_loadout, equipped_items_or_nil, ...)
end)
end
if UIProfileSpawner and UIProfileSpawner.assign_animation_event then
mod:hook(UIProfileSpawner, "assign_animation_event", function(func, self, animation_event, ...)
if is_intro_spawner(self) and should_show_weapon() then
WeaponPresentation.apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
return
end
if is_intro_spawner(self) and should_show_babooshka() then
return
end
local unit_3p = WeaponPresentation.streamed_unit_3p(self)
if unit_3p and animation_event then
animation_event = WeaponPresentation.safe_animation_event_for_unit(unit_3p, animation_event)
if not animation_event then
self._pending_animation_event = nil
if self._loading_profile_data then
self._loading_profile_data.animation_event = nil
end
if self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self) then
WeaponPresentation.apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
end
return
end
end
local result = func(self, animation_event, ...)
if self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self) then
WeaponPresentation.apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
end
return result
end)
end
if UIProfileSpawner and UIProfileSpawner.set_visibility then
mod:hook(UIProfileSpawner, "set_visibility", function(func, self, visible, ...)
local result = func(self, visible, ...)
if visible and (self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self)) then
WeaponPresentation.apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
end
return result
end)
end
if UIProfileSpawner and UIProfileSpawner.cb_on_unit_3p_streaming_complete then
mod:hook(UIProfileSpawner, "cb_on_unit_3p_streaming_complete", function(func, self, unit_3p, timeout, ...)
local result = func(self, unit_3p, timeout, ...)
if self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self) then
WeaponPresentation.apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
end
return result
end)
end
if UIProfileSpawner and UIProfileSpawner.cb_on_unit_3p_streaming_complete_equip_item then
mod:hook_safe(UIProfileSpawner, "cb_on_unit_3p_streaming_complete_equip_item", function(self)
if self._valkyrie_weapon_slot or should_apply_no_uniform_to_spawner(self) then
WeaponPresentation.apply_intro_weapon_to_spawner(self, self._valkyrie_weapon_slot)
end
end)
end
Suppression.register_hooks()