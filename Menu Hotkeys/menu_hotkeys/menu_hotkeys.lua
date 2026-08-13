-- menu_hotkeys.lua
local mod = get_mod("menu_hotkeys")

local Views = require("scripts/ui/views/views")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local SINGLEPLAY_TYPES = MatchmakingConstants.SINGLEPLAY_TYPES
local Missions = require("scripts/settings/mission/mission_templates")
local Promise = require("scripts/foundation/utilities/promise")
local UIWidget = require("scripts/managers/ui/ui_widget")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local MissionTypes = require("scripts/settings/mission/mission_types")
local Zones = require("scripts/settings/zones/zones")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local ColorUtilities = require("scripts/utilities/ui/colors")
local Colors = require("scripts/utilities/ui/colors")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

-- ################## Helper functions #############################

local function get_current_state()
	local ui_manager = Managers.ui
	if not ui_manager then return "unknown" end

	local current_state_name = ui_manager:get_current_state_name()
	if current_state_name and current_state_name == "StateMainMenu" then
		return "main_menu"
	elseif ui_manager:view_active("lobby_view") then
		return "lobby"
	end

	local game_mode_manager = Managers.state and Managers.state.game_mode
	local gamemode_name = game_mode_manager and game_mode_manager:game_mode_name() or "unknown"
	local COOP_MISSIONS = {
		coop_complete_objective = true,
		survival = true,
		expedition = true,
	}
	if COOP_MISSIONS[gamemode_name] then
		gamemode_name = "mission"
	elseif gamemode_name == "training_grounds" then
		gamemode_name = "shooting_range"
	end
	return gamemode_name
end

local function is_soloplay_active()
	local soloplay_mod = get_mod("SoloPlay")
	if soloplay_mod and soloplay_mod.is_soloplay then
		return soloplay_mod:is_soloplay()
	end
	return false
end

local function _get_challenge_level()
	local save_data = Managers.save and Managers.save:account_data()
	local mission_board_data = save_data and save_data.mission_board
	return (mission_board_data and mission_board_data.quickplay_difficulty) or 3
end

-- Fix for Havoc Party Finder button (opens Group Finder without closing Havoc view)
local function _open_group_finder_from_havoc()
	local ui_manager = Managers.ui
	if not ui_manager then return end

	if ui_manager:view_active("havoc_background_view") then
		local context = {
			can_exit = true,
			parent_view = "havoc_background_view",
			allow_close_parent = false,
		}
		Promise.delay(0.5):next(function()
			if ui_manager and ui_manager:view_active("havoc_background_view") then
				ui_manager:open_view("group_finder_view", nil, nil, nil, nil, context)
			end
		end)
	else
		ui_manager:open_view("group_finder_view")
	end
end

-- Hook on HavocPlayView to override the Party Finder callback
mod:hook_safe(CLASS.HavocPlayView, "_cb_on_party_finder_pressed", function(self)
	if self._widgets_by_name.party_finder_button.content.hotspot.disabled then
		return
	end
	Managers.ui:play_2d_sound(UISoundEvents.default_click)
	_open_group_finder_from_havoc()
end)

-- Flags for Meat Grinder
local _meatgrinder_from_main_menu = false

-- ################## Core open/close logic #############################

local function can_activate_view(ui_manager, view)
	if not ui_manager then return false end
	if ui_manager:chat_using_input() then return false end
	if ui_manager:has_active_view(view) then return false end

	if Views and Views[view] and Views[view].validation_function then
		local ok, result = pcall(Views[view].validation_function)
		if not ok or not result then
			return false
		end
	end
	return true
end

-- Unified function to open or close a view.
-- Works everywhere (main menu, psykhanium, hub, solo play).
-- In the main menu, validation is bypassed to allow opening all views.
local function open_or_close_view(view_name, context_override)
	local ui_manager = Managers.ui
	if not ui_manager then return end

	local state = get_current_state()

	-- Запрещаем в обычных миссиях, кроме соло-плея с разрешением
	if state == "mission" then
		if not (is_soloplay_active() and mod:get("enable_in_soloplay")) then
			return
		end
	end

	-- Respect user settings
	if state == "shooting_range" and not mod:get("enable_in_psykhanium") then
		return
	end
	if is_soloplay_active() and not mod:get("enable_in_soloplay") then
		return
	end

	-- Toggle: if view is active and closing is enabled, close it
	if mod:get("close_menu_with_hotkey") and ui_manager:view_active(view_name) then
		ui_manager:close_view(view_name)
		return
	end

	-- For main menu, bypass validation
	if state == "main_menu" then
		local context = context_override or { hub_interaction = true }
		ui_manager:open_view(view_name, nil, nil, nil, nil, context)
		return
	end

	-- Otherwise use normal validation check
	if can_activate_view(ui_manager, view_name) then
		local context = context_override or { hub_interaction = true }
		ui_manager:open_view(view_name, nil, nil, nil, nil, context)
	end
end

-- ################## Data loading utilities #############################

local function safe_promise(p)
	return (p and p.next) and p or Promise.resolved()
end

local _loading_promise = nil
local _pending_callbacks = {}

local function _load_character_data(profile)
	if not profile or not profile.character_id then
		return Promise.resolved()
	end

	local player = Managers.player:local_player(1)
	if not player then
		return Promise.resolved()
	end

	local account_id = player:account_id()
	local character_id = profile.character_id
	local mission_board_service = Managers.data_service.mission_board
	local promises = {}

	-- Narrative
	table.insert(promises, safe_promise(Managers.narrative:load_character_narrative(character_id)))

	-- Mission Board: player journey data
	table.insert(promises, safe_promise(mission_board_service:fetch_player_journey_data(account_id, character_id, false)))

	-- Campaign skip data
	table.insert(promises, safe_promise(mission_board_service:fetch_character_campaign_skip_data(account_id, character_id)))

	-- Havoc data
	local havoc_service = Managers.data_service.havoc
	if havoc_service then
		local havoc_promises = {
			havoc_service:refresh_havoc_status(),
			havoc_service:refresh_havoc_rank(),
			havoc_service:refresh_ever_received_havoc_order(),
			havoc_service:refresh_havoc_unlock_status(),
			havoc_service:refresh_havoc_cadence_status(),
		}
		for _, p in ipairs(havoc_promises) do
			table.insert(promises, safe_promise(p))
		end
	else
		for _ = 1, 5 do
			table.insert(promises, Promise.resolved())
		end
	end

	-- Contracts
	table.insert(promises, safe_promise(Managers.data_service.contracts:get_contract(character_id, false)))

	-- Expedition data
	table.insert(promises, safe_promise(Managers.data_service.expedition:fetch_nodes()))

	return Promise.all(unpack(promises))
end

local function _ensure_data_loaded(profile, callback)
	if not profile or not profile.character_id then
		callback()
		return
	end

	if _loading_promise then
		table.insert(_pending_callbacks, callback)
		return
	end

	_loading_promise = _load_character_data(profile)
		:next(function()
			_loading_promise = nil
			local callbacks = _pending_callbacks
			_pending_callbacks = {}
			for _, cb in ipairs(callbacks) do
				cb()
			end
			callback()
		end)
		:catch(function(err)
			_loading_promise = nil
			local callbacks = _pending_callbacks
			_pending_callbacks = {}
			mod:debug("Failed to load character data: %s", tostring(err))
			for _, cb in ipairs(callbacks) do
				cb()
			end
			callback()
		end)
end

-- ################## Hotkey functions #############################

local view_function_map = {
	barber_vendor_background_view		= "activate_barber_vendor_background_view",
	contracts_background_view			= "activate_contracts_background_view",
	crafting_view						= "activate_crafting_view",
	credits_vendor_background_view		= "activate_credits_vendor_background_view",
	mission_board_view					= "activate_mission_board_view",
	store_view							= "activate_store_view",
	social_menu_view					= "activate_social_view",
	cosmetics_vendor_background_view	= "activate_commissary_view",
	penance_overview_view				= "activate_penance_overview_view",
	havoc_background_view				= "activate_havoc_view",
	expedition_view						= "activate_expedition_view",
	inventory_background_view			= "activate_inventory_view",
}

for view_name, func_name in pairs(view_function_map) do
	mod[func_name] = function(self)
		open_or_close_view(view_name)
	end
end

-- Shared logic for training grounds (Mortis Trials / Meat Grinder)
local function open_training_grounds_with_button(button_name, direct_launch_from_main_menu)
	local ui_manager = Managers.ui
	if not ui_manager then return end

	-- Toggle: close options and/or background
	if ui_manager:view_active("training_grounds_options_view") then
		ui_manager:close_view("training_grounds_options_view")
		if ui_manager:view_active("training_grounds_view") then
			ui_manager:close_view("training_grounds_view")
		end
		return
	end
	if ui_manager:view_active("training_grounds_view") then
		ui_manager:close_view("training_grounds_view")
		return
	end

	-- Direct launch from main menu (only for Meat Grinder)
	if direct_launch_from_main_menu and get_current_state() == "main_menu" then
		_meatgrinder_from_main_menu = true
		return
	end

	local player = Managers.player:local_player(1)
	local profile = player and player:profile()

	local open_callback = function()
		open_or_close_view("training_grounds_view", { hub_interaction = true })
		Promise.delay(0.5):next(function()
			if not ui_manager or not ui_manager:view_active("training_grounds_view") then
				return
			end
			local view_instance = ui_manager:view_instance("training_grounds_view")
			if not view_instance then return end

			local button_widget = view_instance._widgets_by_name and view_instance._widgets_by_name[button_name]
			if button_widget and button_widget.content and button_widget.content.hotspot then
				local hotspot = button_widget.content.hotspot
				if hotspot.pressed_callback then
					hotspot.pressed_callback()
				end
			end
		end)
	end

	if profile and profile.character_id then
		_ensure_data_loaded(profile, open_callback)
	else
		open_callback()
	end
end

mod.activate_training_grounds_view = function(self)
	open_training_grounds_with_button("option_button_1", false)
end

mod.activate_meatgrinder_view = function(self)
	open_training_grounds_with_button("option_button_4", true)
end

-- Sire Melk's Requisitorium – opens root menu and closes child Contracts view
mod.activate_requisitorium_view = function(self)
	local ui_manager = Managers.ui
	if not ui_manager then return end

	open_or_close_view("contracts_background_view")

	local delay_setting = mod:get("requisitorium_close_delay") or 900 -- fallback 0.9 сек
	local delay = delay_setting / 1000

	Promise.delay(delay):next(function()
		local contracts_view_instance = ui_manager:view_instance("contracts_background_view")
		if contracts_view_instance and contracts_view_instance.cb_on_close_pressed then
			contracts_view_instance:cb_on_close_pressed()
		end
	end)
end

-- Havoc Mode – opens havoc_background_view (available everywhere)
mod.activate_havoc_view = function(self)
	local ui_manager = Managers.ui
	if not ui_manager then return end

	if mod:get("close_menu_with_hotkey") and ui_manager:view_active("havoc_background_view") then
		ui_manager:close_view("havoc_background_view")
		return
	end

	local player = Managers.player:local_player(1)
	local profile = player and player:profile()

	-- Preload Group Finder data in background (no blocking)
	local social_service = Managers.data_service.social
	local region_service = Managers.data_service.region_latency
	if social_service then
		social_service:get_group_finder_tags():catch(function() return {} end)
	end
	if region_service then
		region_service:fetch_regions_latency():catch(function() return {} end)
	end

	local open_callback = function()
		open_or_close_view("havoc_background_view", { hub_interaction = true })
	end

	if profile and profile.character_id then
		_ensure_data_loaded(profile, open_callback)
	else
		open_callback()
	end
end

-- ################## Hooks #############################

-- Launch Meat Grinder directly from main menu
mod:hook(CLASS.StateMainMenu, "update", function(func, self, main_dt, main_t)
	if _meatgrinder_from_main_menu then
		_meatgrinder_from_main_menu = false
		local challenge_level = _get_challenge_level()
		local mechanism_context = {
			mission_name = "tg_shooting_range",
			singleplay_type = SINGLEPLAY_TYPES.training_grounds,
			challenge_level = challenge_level
		}
		mod:debug("Going to Meat Grinder from main menu with difficulty level [%s]", challenge_level)

		local mechanism_manager = Managers.mechanism
		if not mechanism_manager then return end
		local mission_settings = Missions[mechanism_context.mission_name]
		if not mission_settings then return end

		local mechanism_name = mission_settings.mechanism_name
		Managers.multiplayer_session:boot_singleplayer_session()
		mechanism_manager:change_mechanism(mechanism_name, mechanism_context)
		local next_state, state_context = mechanism_manager:wanted_transition()
		return next_state, state_context
	end
	return func(self, main_dt, main_t)
end)

-- Force "hub" presence when in main menu or shooting range – always get current state
mod:hook(CLASS.PresenceEntryMyself, "activity_id", function(func, self)
	local activity_id = func(self)
	local state = get_current_state()
	if state == "shooting_range" or state == "main_menu" then
		activity_id = "hub"
	end
	return activity_id
end)

-- Minimal patch for HavocPlayView._setup_current_havoc_mission_data:
-- The original method may crash if player_unit is nil (e.g., in main menu).
-- We call the original and then fix the _user_stat_id if it wasn't set properly.
-- However, the original will crash if _player() returns nil or player_unit is nil.
-- To be safe, we override the method entirely with a safe version.
-- This is a copy of the original with a safety check for stat_id.
local function safe_setup_current_havoc_mission_data(self)
	-- We need to replicate the original logic to avoid crashes.
	-- This is the same as before, kept for stability.
	local current_havoc_order = self._parent.havoc_order
	local widgets_by_name = self._widgets_by_name
	local definitions = self._definitions
	local rank_badge_definitions = definitions.badge_definitions
	local rank_badge_size = rank_badge_definitions.size
	local rank_badge_passes = rank_badge_definitions.pass_template_function(self, {
		rank = current_havoc_order.data.rank,
	})
	local rank_badge_widget_definition = UIWidget.create_definition(rank_badge_passes, "current_rank", nil, rank_badge_size)
	local widget = UIWidget.init("rank_badge", rank_badge_widget_definition)

	self._widgets_by_name.rank_badge = widget
	self._widgets[1 + #self._widgets] = widget

	local charges_widget = widgets_by_name.current_order_charges_remaining_description
	charges_widget.content.visible = current_havoc_order.data.rank > 1

	local num_charges = current_havoc_order.charges
	for i = 1, 3 do
		local destination_color = charges_widget.style["havoc_charge_" .. i].color
		if i <= num_charges then
			ColorUtilities.color_copy(Color.terminal_text_header(255, true), destination_color)
		else
			ColorUtilities.color_copy({ 255, 74, 21, 21 }, destination_color)
		end
	end

	-- SAFETY: compute stat_id with fallback
	local _player = self:_player()
	local player_unit = _player and _player.player_unit
	local stat_id
	if player_unit then
		local player_owner = Managers.state.player_unit_spawn:owner(player_unit)
		stat_id = player_owner.remote and player_owner.stat_id or player_owner:local_player_id()
	else
		stat_id = 1 -- fallback for main menu
	end
	self._user_stat_id = stat_id

	local highest_reached = self._parent._havoc_week_data and self._parent._havoc_week_data.all_time or 0
	if highest_reached == 0 then
		highest_reached = Localize("loc_generic_interaction")
	end

	self._reward_end_time = self._parent._havoc_week_end_time

	local mission = current_havoc_order.blueprint.template
	self._mission = mission

	if not self._initialized then
		self._initialized = true
		if self._play_fast_enter_animation then
			self._enter_animation_id = self:_start_animation("on_enter_fast", widgets_by_name, self)
		else
			self._enter_animation_id = self:_start_animation("on_enter", widgets_by_name, self)
		end
	end

	local map = mission.id
	local mission_template = MissionTemplates[map]
	local widget = widgets_by_name.detail
	widget.visible = true

	local content = widget.content
	local mission_type = MissionTypes[mission_template.mission_type or "undefined"]
	content.header_icon = mission_type.icon
	content.header_subtitle = Localize(Zones[mission_template.zone_id].name)
	content.header_title = Localize(mission_template.mission_name)

	local location_image_material_values = widget.style.location_image.material_values
	location_image_material_values.texture_map = mission_template.texture_big
	location_image_material_values.show_static = 0

	local objective_widget = widgets_by_name.objective
	objective_widget.content.header_icon = mission_type.icon
	objective_widget.content.header_title = Localize("loc_misison_board_main_objective_title")
	objective_widget.content.header_subtitle = Localize(mission_type.name)
	objective_widget.content.body_text = Localize(mission_template.mission_description)

	local havoc_mission_flag_data = self:_extract_havoc_flags_data()
	local circumstances = havoc_mission_flag_data.circumstances
	if circumstances then
		local mission_circumstances_presentation_data = {}
		for key, _ in pairs(circumstances) do
			local circumstance_presentation_data = CircumstanceTemplates[key]
			mission_circumstances_presentation_data[#mission_circumstances_presentation_data + 1] = circumstance_presentation_data.ui
		end
		self:_setup_mission_detail_grid(mission_circumstances_presentation_data)
	end

	local participants = current_havoc_order.participants
	self:_update_mission_participants(participants)
	self.can_start_mission = true
end

mod:hook(CLASS.HavocPlayView, "_setup_current_havoc_mission_data", function(func, self, ...)
	safe_setup_current_havoc_mission_data(self)
end)

-- Preload character data when a profile is selected (so that Mortis, Meat Grinder, Havoc work from main menu/psykhanium)
mod.on_all_mods_loaded = function()
	-- Register event for character selection
	Managers.event:register("event_main_menu_selected_profile_changed", function(profile)
		if not profile or not profile.character_id then
			return
		end
		_load_character_data(profile):next(function()
			mod:debug("Character data preloaded for character %s", profile.character_id)
		end):catch(function(err)
			mod:debug("Failed to preload character data: %s", tostring(err))
		end)
	end)
end
