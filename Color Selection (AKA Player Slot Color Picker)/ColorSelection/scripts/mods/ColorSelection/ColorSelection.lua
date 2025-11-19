local mod = get_mod("ColorSelection")

local UISettings = require("scripts/settings/ui/ui_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

-- Constants
local CONSTANTS = {
	MAX_PLAYERS_PER_PAGE = 14,
	MAX_COLOR_VALUE = 255,
	UUID_LENGTH_WITH_HYPHENS = 36,
	UUID_LENGTH_WITHOUT_HYPHENS = 32,
	SLIDER_HOLD_DELAY = 0.5,
	PLAYER_CHECK_INTERVAL = 1.0,
	SWATCH_SIZE = {30, 20},
	LINE_HEIGHT = 30
}

-- Color utility functions
local ColorUtils = {}

function ColorUtils.normalize_to_rgb(color)
	if not color or type(color) ~= "table" then
		return {r = CONSTANTS.MAX_COLOR_VALUE, g = CONSTANTS.MAX_COLOR_VALUE, b = CONSTANTS.MAX_COLOR_VALUE}
	end
	
	if color.r and color.g and color.b then
		return {
			r = math.clamp(color.r or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			g = math.clamp(color.g or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			b = math.clamp(color.b or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE)
		}
	elseif color[1] and color[2] and color[3] then
		-- ARGB format: {alpha, red, green, blue}
		return {
			r = math.clamp(color[2] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			g = math.clamp(color[3] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE),
			b = math.clamp(color[4] or CONSTANTS.MAX_COLOR_VALUE, 0, CONSTANTS.MAX_COLOR_VALUE)
		}
	end
	
	return {r = CONSTANTS.MAX_COLOR_VALUE, g = CONSTANTS.MAX_COLOR_VALUE, b = CONSTANTS.MAX_COLOR_VALUE}
end

function ColorUtils.rgb_to_argb(rgb)
	return {CONSTANTS.MAX_COLOR_VALUE, rgb.r, rgb.g, rgb.b}
end

function ColorUtils.argb_to_rgb(argb)
	return {
		r = argb[2] or CONSTANTS.MAX_COLOR_VALUE,
		g = argb[3] or CONSTANTS.MAX_COLOR_VALUE,
		b = argb[4] or CONSTANTS.MAX_COLOR_VALUE
	}
end

-- Initialize custom colors storage
mod._player_custom_colors = {}

-- Register color customizer view
local color_customizer_view_name = "color_customizer"
local color_customizer_view_path = "ColorSelection/scripts/mods/ColorSelection/views/color_customizer_view/color_customizer_view"

mod:add_require_path(color_customizer_view_path)

local registered_view = mod:register_view({
    view_name = color_customizer_view_name,
    view_settings = {
        init_view_function = function(ingame_ui_context)
            return true
        end,
        state_bound = true,
        display_name = "loc_eye_color_sienna_desc",
        path = color_customizer_view_path,
        package = "packages/ui/views/credits_goods_vendor_view/credits_goods_vendor_view",
        class = "ColorCustomizerView",
        load_in_hub = false,
        game_world_blur = 1,
        enter_sound_events = {
            "wwise/events/ui/play_ui_enter_short"
        },
        exit_sound_events = {
            "wwise/events/ui/play_ui_back_short"
        },
        wwise_states = {},
    },
    view_transitions = {},
    view_options = {
        close_all = false,
        close_previous = false,
        close_transition_time = nil,
        transition_time = nil
    }
})

function mod.open_color_customizer()
    -- Check if our view is already open - if so, just close it
    if Managers.ui:view_active(color_customizer_view_name) then
        Managers.ui:close_view(color_customizer_view_name)
        return
    end
    
    -- Don't open if there's already an active view or chat is using input
    if Managers.ui:has_active_view() or Managers.ui:chat_using_input() then
        return
    end
    
    -- Open the view
    Managers.ui:open_view(color_customizer_view_name)
end


local function color_for_slot(slot)
	if not slot or slot < 1 then
		return 1
	end
	return slot
end

local function get_color(prefix)
	return {
		mod:get(prefix .. "_a") or CONSTANTS.MAX_COLOR_VALUE,
		mod:get(prefix .. "_r") or CONSTANTS.MAX_COLOR_VALUE,
		mod:get(prefix .. "_g") or CONSTANTS.MAX_COLOR_VALUE,
		mod:get(prefix .. "_b") or CONSTANTS.MAX_COLOR_VALUE,
	}
end

local ColorAllocator = {
	cfg_colors = {},
	bot_color = nil,
	slot_to_index = {},
	index_taken = {},
	player_to_slot_mapping = {},  -- Maps player unique_id to remapped slot (1-4)
	account_id_to_player_id = {},  -- Maps account_id to unique_id for lookups
	bot_player_ids = {},  -- Set of unique_ids that are bots
}

function ColorAllocator:reset()
	self.slot_to_index = {}
	self.index_taken = { false, false, false, false }
	self.player_to_slot_mapping = {}
	self.account_id_to_player_id = {}
	self.bot_player_ids = {}
end

function ColorAllocator:setup(my_slot, all_slots)
	self.cfg_colors = {
		get_color("player_color"),
		get_color("player2_color"),
		get_color("player3_color"),
		get_color("player4_color"),
	}
	self.bot_color = get_color("bot_color")
	
	-- Build a set of currently active slots
	local active_slots = {}
	if my_slot and my_slot >= 1 then
		active_slots[my_slot] = true
	end
	if all_slots then
		for i = 1, #all_slots do
			local slot = all_slots[i]
			if slot and slot >= 1 then
				active_slots[slot] = true
			end
		end
	end
	
	-- Remove assignments for slots that are no longer active
	local slots_to_remove = {}
	for slot, idx in pairs(self.slot_to_index) do
		if not active_slots[slot] then
			slots_to_remove[#slots_to_remove + 1] = slot
		end
	end
	for i = 1, #slots_to_remove do
		local slot = slots_to_remove[i]
		local idx = self.slot_to_index[slot]
		self.slot_to_index[slot] = nil
		if idx then
			self.index_taken[idx] = false
		end
	end
	
	-- Rebuild index_taken based on current assignments
	self.index_taken = { false, false, false, false }
	for slot, idx in pairs(self.slot_to_index) do
		if idx >= 1 and idx <= 4 then
			self.index_taken[idx] = true
		end
	end
	
	-- Local player always gets index 1
	if my_slot and my_slot >= 1 then
		if self.slot_to_index[my_slot] and self.slot_to_index[my_slot] ~= 1 then
			-- Local player had a different index, need to swap or reassign
			local old_idx = self.slot_to_index[my_slot]
			self.index_taken[old_idx] = false
		end
		self.slot_to_index[my_slot] = 1
		self.index_taken[1] = true
	end
	
	-- Pre-assign colors to new players to prevent race conditions
	if all_slots then
		for i = 1, #all_slots do
			local slot = all_slots[i]
			if slot ~= my_slot and slot and slot >= 1 then
				if not self.slot_to_index[slot] then
					-- Find next available index
					for idx = 1, 4 do
						if not self.index_taken[idx] then
							self.slot_to_index[slot] = idx
							self.index_taken[idx] = true
							break
						end
					end
				end
			end
		end
	end
end

function ColorAllocator:color_for(slot, account_id)
	slot = color_for_slot(slot)
	
	-- Check if this is a bot (no account_id) - return bot color
	if not account_id or account_id == "" then
		if mod:get("debug_mode") then
			mod:info(string.format("[ColorSelection] Returning bot color for slot %d (no account_id)", slot or 0))
		end
		return self.bot_color or self.cfg_colors[1]  -- Fallback to player1 color if bot_color not set
	end
	
	-- Apply player-based slot remapping if we have account_id
	if account_id and self.account_id_to_player_id[account_id] then
		local player_id = self.account_id_to_player_id[account_id]
		
		-- Check if this player is marked as a bot
		if self.bot_player_ids[player_id] then
			return self.bot_color or self.cfg_colors[1]
		end
		
		if self.player_to_slot_mapping[player_id] then
			slot = self.player_to_slot_mapping[player_id]
		end
	end
	
	-- Check for custom color by account ID first
	if account_id and mod._player_custom_colors and mod._player_custom_colors[account_id] then
		return mod._player_custom_colors[account_id]
	end
	
	-- Check for saved color by account ID (stored as table directly, no JSON needed)
	if account_id then
		local saved_colors = mod:get("saved_player_colors")
		if saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
			local color = saved_colors[account_id]
			if color and type(color) == "table" then
				-- Convert to ARGB format and cache it
				local argb_color = {255, color.r or 255, color.g or 255, color.b or 255}
				if not mod._player_custom_colors then
					mod._player_custom_colors = {}
				end
				mod._player_custom_colors[account_id] = argb_color
				return argb_color
			end
		end
	end

	local idx = self.slot_to_index[slot]
	if idx then
		return self.cfg_colors[idx]
	end

	-- Fallback for players joining after setup
	for i = 1, 4 do
		if not self.index_taken[i] then
			self.slot_to_index[slot] = i
			self.index_taken[i] = true
			return self.cfg_colors[i]
		end
	end

	-- All indices taken (shouldn't happen with max 4 players)
	local fallback = ((slot - 1) % 4) + 1
	return self.cfg_colors[fallback]
end

local function _on_player_removed(player)
	if not player then return end
	
	-- Clean up runtime color cache for this player (with safety checks)
	local success, account_id = pcall(function() return player:account_id() end)
	if success and account_id and mod._player_custom_colors then
		-- Don't remove from saved colors, just runtime cache
		mod._player_custom_colors[account_id] = nil
	end
	
	local slot_success, slot = pcall(function() return player:slot() end)
	if not slot_success or not slot then
		return
	end
	local idx = ColorAllocator.slot_to_index[slot]
	if idx then
		ColorAllocator.slot_to_index[slot] = nil
		ColorAllocator.index_taken[idx] = false
	end
end

-- Player lookup cache for performance
local _player_cache = {
	by_slot = {},
	by_account_id = {},
	last_update = 0
}

local function update_player_cache()
	local pm = Managers and Managers.player
	if not pm then
		return
	end
	
	table.clear(_player_cache.by_slot)
	table.clear(_player_cache.by_account_id)
	
	local human_players = pm:human_players()
	if human_players then
		for unique_id, player in pairs(human_players) do
			if player then
				-- Filter out bots using the same checks as apply_slot_colors
				local human_success, is_human = pcall(function() return player:is_human_controlled() end)
				local bot_success, is_bot = pcall(function() return player:is_bot() end)
				local id_success, account_id = pcall(function() return player:account_id() end)
				
				-- Only cache real human players (skip bots)
				if not (human_success and is_human) then goto skip_cache end
				if bot_success and is_bot then goto skip_cache end
				if not (id_success and account_id and account_id ~= "") then goto skip_cache end
				
				-- Use pcall to safely access player methods
				local slot_success, slot = pcall(function() return player:slot() end)
				if slot_success and slot then _player_cache.by_slot[slot] = player end
				if id_success and account_id then _player_cache.by_account_id[account_id] = player end
				
				::skip_cache::
			end
		end
	end
	
	_player_cache.last_update = os.clock()
end

local function get_player_by_slot(slot)
	if not slot then return nil end
	
	-- Update cache if needed (every 0.5 seconds or on first call)
	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end
	
	return _player_cache.by_slot[slot]
end

local function get_player_by_account_id(account_id)
	if not account_id then return nil end
	
	-- Update cache if needed
	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end
	
	return _player_cache.by_account_id[account_id]
end

-- Helper function to apply color to text
-- Simple approach: wrap entire text in color tag, let true_level's inline tags override
local function apply_color_to_name_only(text, color)
	if not text or type(text) ~= "string" or not color then
		return text
	end
	
	local c = color
	local target_color_tag = string.format("{#color(%d,%d,%d)}", c[2], c[3], c[4])
	
	-- Strip any leading ColorSelection color tag (from previous application)
	-- But preserve true_level's inline color tags within the text
	local stripped_text = text:gsub("^{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}$", "")
	
	-- Simply wrap the entire text with our color
	-- true_level's inline color tags will override our color where they're placed
	return target_color_tag .. stripped_text .. "{#reset()}"
end

local function apply_widget_color(panel)
	if not panel or not panel._widgets_by_name or not mod:get("color_hud_names") then
		return
	end
	
	-- Try to get player from panel directly (more reliable than slot lookup)
	local player = panel._player
	if not player and panel._data then
		player = panel._data.player
	end
	
	-- Get slot and account ID
	local slot = nil
	local account_id = nil
	
	if player then
		-- Get slot from player (with safety check for destroyed objects)
		local success, result = pcall(function() return player:slot() end)
		if success and result then
			slot = result
		end
		
		-- Get account ID from player (with safety check for destroyed objects)
		local id_success, id_result = pcall(function() return player:account_id() end)
		if id_success and id_result then
			account_id = id_result
		end
		-- Update panel's player slot if not set
		if slot and not panel._player_slot then
			panel._player_slot = slot
		end
	else
		-- Fallback to slot-based lookup if player not available
		slot = panel._player_slot
		if slot then
			player = get_player_by_slot(slot)
			if player then
				local success, result = pcall(function() return player:account_id() end)
				if success then
					account_id = result
				end
			end
		end
	end
	
	if not slot then
		return
	end
	
	local color = ColorAllocator:color_for(slot, account_id)
	if not color then
		return
	end
	
	local widget = panel._widgets_by_name.player_name
	if not widget or not widget.style or not widget.style.text then
		return
	end
	
	-- Set the base text color to our custom color (this colors the whole widget)
	if widget.style.text.text_color then
		widget.style.text.text_color = {color[1], color[2], color[3], color[4]}
	end
	
	-- Also set the default_text_color if it exists
	if widget.style.text.default_text_color then
		widget.style.text.default_text_color = {color[1], color[2], color[3], color[4]}
	end
	
	-- Also apply inline tags as backup
	if widget.content and widget.content.text then
		local current_text = widget.content.text
		local new_text = apply_color_to_name_only(current_text, color)
		-- Always update to ensure color is applied (game may reset text)
		widget.content.text = new_text
		widget.dirty = true
	end
end

local function alias_ability_bar_widget(panel)
	local w = panel and panel._widgets_by_name
	if not w then
		return
	end
	if w.ability_bar then
		w.ability_bar_widget = w.ability_bar
	elseif not w.ability_bar_widget then
		w.ability_bar_widget = { visible = false, dirty = false, style = { texture = { color = { 255, 255, 255, 255 }, size = { 0, 0 } } } }
	end
end

mod:hook_safe("HudElementPersonalPlayerPanel", "init", function(self) alias_ability_bar_widget(self) end)
mod:hook_safe("HudElementTeamPlayerPanel",     "init", function(self) alias_ability_bar_widget(self) end)
mod:hook_safe("HudElementPersonalPlayerPanelHub", "init", function(self) alias_ability_bar_widget(self) end)
mod:hook_safe("HudElementTeamPlayerPanelHub",     "init", function(self) alias_ability_bar_widget(self) end)
mod:hook_safe("HudElementPlayerPanelBase",     "destroy", function(self) alias_ability_bar_widget(self) end)

-- Continuously update player panel colors during gameplay
mod:hook_safe("HudElementPersonalPlayerPanel", "update", function(self) 
	if mod:is_enabled() and mod:get("color_hud_names") then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementPersonalPlayerPanelHub", "update", function(self)
	if mod:is_enabled() and mod:get("color_hud_names") then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementTeamPlayerPanel", "update", function(self)
	if mod:is_enabled() and mod:get("color_hud_names") then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementTeamPlayerPanelHub", "update", function(self)
	if mod:is_enabled() and mod:get("color_hud_names") then
		apply_widget_color(self)
	end
end)

local function colourise_team_panels(handler)
	if not mod:is_enabled() then return end
	local panels = handler and handler._player_panels_array
	if not panels then return end
	for i = 1, #panels do
		local p = panels[i] and panels[i].panel
		if p then apply_widget_color(p) end
	end
end

-- Helper function to apply color to world marker nameplates
local function apply_nameplate_color(marker)
	if not marker or not marker.widget then
		return
	end
	
	local player = marker.data
	if not player then
		return
	end
	
	-- Get player info
	local slot = nil
	local account_id = nil
	
	local slot_success, slot_result = pcall(function() return player:slot() end)
	if slot_success and slot_result then
		slot = slot_result
	end
	
	local id_success, id_result = pcall(function() return player:account_id() end)
	if id_success and id_result then
		account_id = id_result
	end
	
	if not slot then
		return
	end
	
	local color = ColorAllocator:color_for(slot, account_id)
	if not color then
		return
	end
	
	local widget = marker.widget
	local content = widget.content
	
	if not content or not content.header_text then
		return
	end
	
	local current_text = content.header_text
	
	-- Check if we should color the player name portion
	local color_names = mod:get("color_nameplate_names")
	
	local c = color
	local color_tag = string.format("{#color(%d,%d,%d)}", c[2], c[3], c[4])
	
	-- Strip only leading/trailing ColorSelection color tags, preserve true_level's inline tags
	local stripped_text = current_text:gsub("^{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}$", "")
	
	local new_text
	if color_names then
		-- Color everything, let true_level's inline tags override
		new_text = color_tag .. stripped_text .. "{#reset()}"
	else
		-- Only color the icon at the start
		local icon, rest = stripped_text:match("^([^\32-\126%s]+)%s+(.+)$")  -- Non-ASCII chars followed by space
		if icon and rest then
			new_text = color_tag .. icon .. "{#reset()} " .. rest
		else
			-- No icon found, don't color
			new_text = stripped_text
		end
	end
	
	-- Always update to ensure color changes apply
	if new_text ~= current_text then
		content.header_text = new_text
	end
end

mod:hook_require("scripts/ui/hud/elements/team_panel_handler/hud_element_team_panel_handler", function(H)
	if not H.__cs_hooked then
		H.__cs_hooked = true
		mod:hook_safe(H, "update", function(self) colourise_team_panels(self) end)
	end
end)

-- Hook world markers to apply colors to nameplates and companion nameplates
mod:hook_safe("HudElementWorldMarkers", "event_add_world_marker_unit", function(self, marker_type, unit, callback, data)
	if not mod:is_enabled() then return end
	-- Apply colors to newly added nameplates (icon always colored, name optional)
	if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
		-- Find and color the newly added marker
		if self._markers_by_id then
			for marker_id, marker in pairs(self._markers_by_id) do
				if marker.unit == unit then
					apply_nameplate_color(marker)
					break
				end
			end
		end
	end
end)

-- Hook nameplate updates to continuously apply colors
mod:hook_safe("HudElementNameplates", "update", function(self, dt, t, ui_renderer)
	if not mod:is_enabled() then return end
	-- Update all visible nameplates (icon always colored, name optional)
	if not Managers or not Managers.ui then return end
	
	local ui_manager = Managers.ui
	local hud = ui_manager._hud
	if not hud then return end
	
	-- Try to get world markers element safely
	local success, world_markers = pcall(function() return hud:element("HudElementWorldMarkers") end)
	if not success or not world_markers or not world_markers._markers_by_id then return end
	
	for marker_id, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type
		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			apply_nameplate_color(marker)
		end
	end
end)

local function install_player_panel_hooks(base)
	if not base or base.__cs_hooks then return end
	base.__cs_hooks = true
	
	-- Hook update to continuously apply colors (catches cases where name is set outside our hooks)
	mod:hook_safe(base, "update", function(self, dt, t, ui_renderer)
		-- Only apply if mod enabled, colors enabled, and panel has widgets
		if mod:is_enabled() and mod:get("color_hud_names") and self._widgets_by_name and self._widgets_by_name.player_name then
			apply_widget_color(self)
		end
	end)
	
	mod:hook_safe(base, "_update_player_name_prefix", function(self)
		if not mod:is_enabled() then return end
		if self._colors_revision ~= mod._colors_revision then
			self._colors_revision = mod._colors_revision
			self._player_slot = nil
			-- Force reapplication of color when revision changes
			apply_widget_color(self)
		end
	end)
	
	mod:hook_safe(base, "_set_player_name", function(self)
		if not mod:is_enabled() then return end
		apply_widget_color(self) 
	end)
	
	mod:hook_safe(base, "_update_player_features", function(self, dt, t, player, ui_renderer)
		-- Store player reference if available
		if player then
			self._player = player
			-- Update slot from player (with safety check for destroyed objects)
			local success, slot = pcall(function() return player:slot() end)
			if success and slot then
				self._player_slot = slot
			end
		end
		apply_widget_color(self) 
	end)
	
	-- Also hook init to ensure player slot is set for hub panels
	mod:hook_safe(base, "init", function(self, parent, draw_layer, scale, data)
		if data and data.player then
			local player = data.player
			if player then
				local success, slot = pcall(function() return player:slot() end)
				if success and slot then
					self._player_slot = slot
				end
			end
		end
		-- Apply color immediately after init
		apply_widget_color(self)
	end)
end

mod:hook_require("scripts/ui/hud/elements/player_panel_base/hud_element_player_panel_base", function(B) install_player_panel_hooks(B) end)

mod._colors_revision = 0
local previous_slot_colors

local function deep_clone(tbl)
	if not tbl then return nil end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = type(v) == "table" and deep_clone(v) or v
	end
	return copy
end

local function restore_previous()
	if previous_slot_colors then
		UISettings.player_slot_colors = previous_slot_colors
		previous_slot_colors = nil
		mod._colors_revision = mod._colors_revision + 1
	end
end

mod.on_unload = restore_previous

-- Helper function to update all world markers (nameplates and companions)
local function update_world_markers()
	local ui_manager = Managers and Managers.ui
	if not ui_manager then return false end
	
	local hud = ui_manager:get_hud()
	if not hud then return false end
	
	local world_markers = hud:element("HudElementWorldMarkers")
	if not world_markers or not world_markers._markers_by_id then return false end
	
	for marker_id, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type
		-- Handle both regular nameplates and companion nameplates
		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			apply_nameplate_color(marker)
		end
	end
	
	return true
end

-- Updates only player panel HUD elements to avoid recreating entire HUD
local function update_player_panel_colors()
	local ui_manager = Managers and Managers.ui
	if not ui_manager or not ui_manager._hud then return false end
	
	local hud = ui_manager._hud
	local elements_array = hud._elements_array
	if not elements_array then return false end
	
	for i = 1, #elements_array do
		local element = elements_array[i]
		if element then
			local class_name = element.__class_name
			if class_name == "HudElementPersonalPlayerPanel" or class_name == "HudElementPersonalPlayerPanelHub" then
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPlayerPanel" or class_name == "HudElementTeamPlayerPanelHub" then
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPanelHandler" then
				colourise_team_panels(element)
			end
		end
	end
	
	-- Also update world markers (nameplates and companions)
	update_world_markers()
	
	return true
end

local last_debug_state = ""  -- Track last debug output to prevent spam
local logged_reassignments = {}  -- Track which players we've logged reassignments for

-- Forward declare the internal function so queue can reference it
local apply_slot_colors_internal

-- Queue system to prevent race conditions when multiple players join simultaneously
local color_assignment_queue = {}
local is_processing_queue = false

local function process_next_in_queue()
	if is_processing_queue or #color_assignment_queue == 0 then
		return
	end
	
	is_processing_queue = true
	local queue_size = #color_assignment_queue
	local debug_mode = mod:get("debug_mode")
	
	if queue_size > 1 then
		local msg = string.format("[ColorSelection] Processing queue with %d operations (RACE CONDITION PREVENTED!)", queue_size)
		mod:info(msg)  -- Always log to file
		if debug_mode then
			mod:echo(msg)  -- Also show in chat if debug mode
		end
	end
	
	-- Process all queued operations sequentially
	local operation_count = 0
	while #color_assignment_queue > 0 do
		local operation = table.remove(color_assignment_queue, 1)
		operation_count = operation_count + 1
		
		if debug_mode then
			local msg = string.format("[ColorSelection] Executing queued operation %d/%d", operation_count, queue_size)
			mod:info(msg)
			mod:echo(msg)
		end
		
		-- Execute the color assignment
		operation()
	end
	
	-- Mark as complete
	is_processing_queue = false
end

local function queue_color_assignment()
	local queue_position = #color_assignment_queue + 1
	local debug_mode = mod:get("debug_mode")
	
	if debug_mode then
		local msg = string.format("[ColorSelection] Queueing color assignment (position %d)", queue_position)
		mod:info(msg)
		mod:echo(msg)
	end
	
	table.insert(color_assignment_queue, function() apply_slot_colors_internal() end)
	process_next_in_queue()
end

-- Define the actual implementation
apply_slot_colors_internal = function()
	if not UISettings then
		return
	end
	
	-- Initialize player_slot_colors if it doesn't exist
	if not UISettings.player_slot_colors then
		UISettings.player_slot_colors = {}
	end
	
	if not previous_slot_colors then
		previous_slot_colors = deep_clone(UISettings.player_slot_colors)
	end

	local my_slot
	local all_slots = {}
	local pm = Managers and Managers.player
	if not pm then
		return
	end
	
	-- Build player-to-slot mapping (game bug workaround)
	-- Use existing mapping if available to keep assignments stable
	local player_to_slot = ColorAllocator.player_to_slot_mapping or {}
	local used_slots = {false, false, false, false}  -- Track which 1-4 slots are used
	
	-- First pass: Identify local player and collect all players
	local player_slots = {}  -- Store {unique_id, original_slot, player}
	local current_players = {}  -- Track which players are currently in game
	local local_player_id = nil
	local human_players = pm:human_players()
	local lp = pm:local_player_safe(1)
	
	if human_players then
		for unique_id, player in pairs(human_players) do
			if player then
				-- Multiple checks to ensure we only process real human players
				local human_success, is_human = pcall(function() return player:is_human_controlled() end)
				local bot_success, is_bot = pcall(function() return player:is_bot() end)
				local account_success, account_id_check = pcall(function() return player:account_id() end)
				
				-- Skip if:
				-- 1. Not human controlled
				-- 2. Explicitly marked as bot
				-- 3. No valid account ID (bots don't have account IDs)
				if not (human_success and is_human) then
					if mod:get("debug_mode") then
						mod:echo(string.format("[ColorSelection] Skipping player %s - not human controlled", unique_id:sub(1, 8)))
					end
					goto skip_player
				end
				if bot_success and is_bot then
					if mod:get("debug_mode") then
						mod:echo(string.format("[ColorSelection] Skipping player %s - is_bot returned true", unique_id:sub(1, 8)))
					end
					goto skip_player
				end
				if not (account_success and account_id_check and account_id_check ~= "") then
					if mod:get("debug_mode") then
						mod:echo(string.format("[ColorSelection] Skipping player %s - no valid account_id (BOT)", unique_id:sub(1, 8)))
					end
					goto skip_player
				end
				
				local success, slot = pcall(function() return player:slot() end)
				if success and slot and slot >= 1 then
					table.insert(player_slots, {unique_id = unique_id, slot = slot, player = player})
					current_players[unique_id] = true
					
					-- Check if this is the local player
					if lp and player == lp then
						local_player_id = unique_id
					end
				end
				
				::skip_player::
			end
		end
	end
	
	-- Remove mappings for players who left
	for player_id in pairs(player_to_slot) do
		if not current_players[player_id] then
			local old_slot = player_to_slot[player_id]
			player_to_slot[player_id] = nil
			-- Free up the slot they were using
			if old_slot >= 1 and old_slot <= 4 then
				used_slots[old_slot] = false
			end
			-- Clear logged reassignments for this player
			for key in pairs(logged_reassignments) do
				if key:sub(1, 8) == player_id:sub(1, 8) then
					logged_reassignments[key] = nil
				end
			end
		end
	end
	
	-- Mark slots that are already assigned to existing players (except slot 1, reserved for local player)
	for player_id, slot in pairs(player_to_slot) do
		if player_id ~= local_player_id and slot >= 1 and slot <= 4 then
			used_slots[slot] = true
		end
	end
	
	-- ALWAYS assign local player to slot 1
	if local_player_id then
		player_to_slot[local_player_id] = 1
		used_slots[1] = true  -- Reserve slot 1 for local player
	end
	
	-- Second pass: Assign other players to slots 2-4 only
	-- Also build account_id mapping
	local account_id_to_player_id = {}
	for _, data in ipairs(player_slots) do
		local slot = data.slot
		local unique_id = data.unique_id
		local player = data.player
		
		-- Get account_id for this player
		local acct_success, account_id = pcall(function() return player:account_id() end)
		if acct_success and account_id then
			account_id_to_player_id[account_id] = unique_id
		end
		
		-- Skip local player (already assigned to slot 1)
		if unique_id == local_player_id then
			goto continue
		end
		
		-- Only assign if player doesn't have a mapping yet
		if not player_to_slot[unique_id] then
			-- For other players, only use slots 2-4
			local assigned = false
			for i = 2, 4 do  -- Start from 2, not 1
				if not used_slots[i] then
					player_to_slot[unique_id] = i
					used_slots[i] = true
					if slot ~= i then
						-- Only log once per unique reassignment
						local reassignment_key = string.format("%s:%d:%d", unique_id, slot, i)
						if not logged_reassignments[reassignment_key] then
							logged_reassignments[reassignment_key] = true
							local msg = string.format("[ColorSelection] Player %s: slot %d → slot %d (reassigned)", 
								unique_id:sub(1, 8), slot, i)
							if mod:get("debug_mode") then
								mod:echo(msg)
							else
								mod:info(msg)
							end
						end
					end
					assigned = true
					break
				end
			end
			-- If slots 2-4 all taken (hub scenario with many players)
			-- Use account_id to deterministically assign a slot so each player gets a consistent color
			if not assigned then
				-- Get account_id for this player
				local hash_source = account_id or unique_id
				
				-- Create a simple hash from the ID string
				local hash = 0
				for i = 1, #hash_source do
					hash = hash + string.byte(hash_source, i)
				end
				
				-- Map to slots 2-4 based on hash
				local reassigned_slot = (hash % 3) + 2  -- Maps to 2, 3, or 4
				player_to_slot[unique_id] = reassigned_slot
			end
		end
		
		::continue::
	end
	
	-- Store mappings in ColorAllocator for color lookups
	ColorAllocator.player_to_slot_mapping = player_to_slot
	ColorAllocator.account_id_to_player_id = account_id_to_player_id
	
	-- Debug: Log all final assignments only if they changed
	-- Build a hash of current state
	local current_state = {}
	for player_id, slot in pairs(player_to_slot) do
		table.insert(current_state, player_id:sub(1, 8) .. "=" .. slot)
	end
	table.sort(current_state)
	local state_hash = table.concat(current_state, ",")
	
	-- Only log if state changed
	if state_hash ~= last_debug_state then
		last_debug_state = state_hash
		local debug_enabled = mod:get("debug_mode")
		local log_func = debug_enabled and mod.echo or mod.info
		
		log_func(mod, "[ColorSelection] === Final slot assignments ===")
		for player_id, slot in pairs(player_to_slot) do
			log_func(mod, string.format("[ColorSelection]   Player %s → slot %d", player_id:sub(1, 8), slot))
		end
	end
	
	-- Get local player slot (already assigned to slot 1)
	if local_player_id and player_to_slot[local_player_id] then
		my_slot = player_to_slot[local_player_id]  -- Should always be 1
	end
	
	-- Build all_slots list with remapped slots
	for _, data in ipairs(player_slots) do
		local unique_id = data.unique_id
		local remapped_slot = player_to_slot[unique_id]
		
		if remapped_slot then
			local found = false
			for i = 1, #all_slots do
				if all_slots[i] == remapped_slot then
					found = true
					break
				end
			end
			if not found and remapped_slot ~= my_slot then
				all_slots[#all_slots + 1] = remapped_slot
			end
		end
	end

	ColorAllocator:setup(my_slot, all_slots)

	-- Create our custom metatable for color lookups
	local color_metatable = {
		__index = function(_, k)
			if type(k) ~= "number" or k < 1 then return nil end
			-- Try to get account ID for this slot using cache
			local account_id = nil
			local player = get_player_by_slot(k)
			if player then
				local success, result = pcall(function() return player:account_id() end)
				if success then
					account_id = result
				end
			end
			return ColorAllocator:color_for(k, account_id)
		end,
	}

	-- Directly set our metatable, don't restore previous (causes conflicts)
	UISettings.player_slot_colors = setmetatable({}, color_metatable)

	mod._colors_revision = mod._colors_revision + 1
	update_player_panel_colors()
	
	-- Log successful application
	local debug_enabled = mod:get("debug_mode")
	if debug_enabled then
		mod:echo("[ColorSelection] Slot colors applied successfully")
	else
		mod:info("[ColorSelection] Slot colors applied successfully")
	end
end

-- Public wrapper that queues color assignment to prevent race conditions
local function apply_slot_colors()
	queue_color_assignment()
end

-- Expose apply_slot_colors and update_player_panel_colors so they can be called from the color customizer view
mod.apply_slot_colors = apply_slot_colors
mod.update_player_panel_colors = update_player_panel_colors
mod.ColorAllocator = ColorAllocator
mod.ColorUtils = ColorUtils
mod.CONSTANTS = CONSTANTS
mod.get_player_by_account_id = get_player_by_account_id
mod.get_player_by_slot = get_player_by_slot

local in_gameplay_state = false

-- No dynamic updates during gameplay
-- Colors are set once when entering mission and stay until you leave
-- To see new color settings, exit and rejoin the mission

-- Hook into social menu to add "Copy Account ID" button
mod:hook_require("scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup_content_list", function(module)
	if module.from_player_info then
		local original_from_player_info = module.from_player_info
		
		module.from_player_info = function(parent, player_info)
			local popup_menu_items, num_menu_items = original_from_player_info(parent, player_info)
			
			-- Only add button if it's not the own player and account ID exists
			if not player_info:is_own_player() and player_info:account_id() then
				local account_id = player_info:account_id()
				
				-- Add divider before our button
				local _add_divider = function(at_index)
					local _get_next_list_item = function(at_index)
						local last_item_index = num_menu_items + 1
						local new_item = popup_menu_items[last_item_index]
						
						if new_item then
							table.clear(new_item)
						else
							new_item = {}
							popup_menu_items[last_item_index] = new_item
						end
						
						if at_index then
							popup_menu_items[last_item_index] = nil
							table.insert(popup_menu_items, at_index, new_item)
						end
						
						num_menu_items = last_item_index
						return new_item, last_item_index
					end
					
					local item, num_items = _get_next_list_item(at_index)
					item.blueprint = "group_divider"
					item.label = "divider_" .. num_items
				end
				
				local _get_next_list_item = function(at_index)
					local last_item_index = num_menu_items + 1
					local new_item = popup_menu_items[last_item_index]
					
					if new_item then
						table.clear(new_item)
					else
						new_item = {}
						popup_menu_items[last_item_index] = new_item
					end
					
					if at_index then
						popup_menu_items[last_item_index] = nil
						table.insert(popup_menu_items, at_index, new_item)
					end
					
					num_menu_items = last_item_index
					return new_item, last_item_index
				end
				
				-- Add divider
				_add_divider()
				
				-- Add "Copy Account ID" button
				local copy_button = _get_next_list_item()
				copy_button.blueprint = "button"
				copy_button.label = mod:localize("copy_account_id_button")
				copy_button.callback = function()
					if account_id then
						Clipboard.put(account_id)
						mod:notify(mod:localize("account_id_copied"))
					end
				end
				copy_button.on_pressed_sound = UISoundEvents.social_menu_see_player_profile
			end
			
			return popup_menu_items, num_menu_items
		end
	end
end)

-- Hook into social menu roster view to apply custom colors to player names
mod:hook_require("scripts/ui/views/social_menu_roster_view/social_menu_roster_view_blueprints", function(module)
	-- Function to get custom color for an account ID (same logic as ColorAllocator:color_for)
	local function get_custom_color(account_id)
		if not account_id then
			return nil
		end
		
		-- Check runtime custom colors first
		if mod._player_custom_colors and mod._player_custom_colors[account_id] then
			return mod._player_custom_colors[account_id]
		end
		
		-- Check saved colors
		local saved_colors = mod:get("saved_player_colors")
		if saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
			local saved_color = saved_colors[account_id]
			if saved_color and type(saved_color) == "table" then
				-- Convert to ARGB format
				local rgb = ColorUtils.normalize_to_rgb(saved_color)
				local color = ColorUtils.rgb_to_argb(rgb)
				-- Cache it
				if not mod._player_custom_colors then
					mod._player_custom_colors = {}
				end
				mod._player_custom_colors[account_id] = color
				return color
			end
		end
		
		return nil
	end
	
	-- Helper function to apply custom color to a style
	local function apply_color_to_style(style, color)
		if not style or not color then
			return
		end
		
		-- Apply to text_color array (ARGB format)
		if style.text_color then
			style.text_color[1] = color[1] or CONSTANTS.MAX_COLOR_VALUE  -- Alpha
			style.text_color[2] = color[2] or CONSTANTS.MAX_COLOR_VALUE  -- Red
			style.text_color[3] = color[3] or CONSTANTS.MAX_COLOR_VALUE  -- Green
			style.text_color[4] = color[4] or CONSTANTS.MAX_COLOR_VALUE  -- Blue
		end
		
		-- Also update default_color if it exists (overrides party status colors)
		if style.default_color then
			style.default_color[1] = color[1] or CONSTANTS.MAX_COLOR_VALUE
			style.default_color[2] = color[2] or CONSTANTS.MAX_COLOR_VALUE
			style.default_color[3] = color[3] or CONSTANTS.MAX_COLOR_VALUE
			style.default_color[4] = color[4] or CONSTANTS.MAX_COLOR_VALUE
		end
	end
	
	-- Wrap the player_plaque blueprint
	if module.player_plaque and module.player_plaque.pass_template then
		local pass_template = module.player_plaque.pass_template
		
		-- Find and wrap both name_or_activity and account_name passes
		for i = 1, #pass_template do
			local pass = pass_template[i]
			if pass and pass.change_function then
				-- Handle name_or_activity pass (character name)
				if pass.style_id == "name_or_activity" then
					local original_change_function = pass.change_function
					
					pass.change_function = function(content, style)
						-- Call original function first
						original_change_function(content, style)
						
						-- Apply custom color if available
						local player_info = content.player_info
						if player_info then
							local account_id = player_info:account_id()
							if account_id then
								local color = get_custom_color(account_id)
								if color then
									apply_color_to_style(style, color)
								end
							end
						end
					end
				-- Handle account_name pass (account name shown in hub panel)
				elseif pass.style_id == "account_name" then
					local original_change_function = pass.change_function
					
					pass.change_function = function(content, style)
						-- Call original function first
						original_change_function(content, style)
						
						-- Apply custom color if available
						local player_info = content.player_info
						if player_info then
							local account_id = player_info:account_id()
							if account_id then
								local color = get_custom_color(account_id)
								if color then
									apply_color_to_style(style, color)
								end
							end
						end
					end
				end
			end
		end
	end
end)

-- Social popup color application removed - keeping only Copy Account ID button functionality

mod.on_all_mods_loaded = function()
	-- Reset color allocator on mod load
	ColorAllocator:reset()
	
	-- Don't apply colors here - wait until entering StateGameplay
	-- Colors will be applied when entering a mission
	
	if mod.command then
		mod:command("cs_menu", "open color customizer menu", function() mod.open_color_customizer() end)
		mod:command("cs_sync", "sync/apply color settings", function()
			if UISettings and in_gameplay_state then
				apply_slot_colors()
				mod:notify("Colors synced")
			else
				mod:notify("Cannot sync colors outside of gameplay")
			end
		end)
	end
	
	-- Hook into DMF keybind system to block mod hotkeys when our view is open
	local dmf = get_mod("DMF")
	if dmf then
		-- Use mod:hook to intercept check_keybinds before it runs
		mod:hook(dmf, "check_keybinds", function(func)
			-- Block all mod hotkeys when our color customizer view is open
			if Managers.ui and Managers.ui:view_active(color_customizer_view_name) then
				-- Don't call the original function, effectively blocking all keybinds
				return
			end
			
			-- Otherwise, call the original function
			return func()
		end)
	end
end

mod.on_game_state_changed = function(status, state_name)
	-- Track when we're in actual gameplay (mission with players)
	if status == "enter" and state_name == "StateGameplay" then
		in_gameplay_state = true
		-- Apply colors once when entering gameplay
		apply_slot_colors()
	elseif status == "exit" and state_name == "StateGameplay" then
		in_gameplay_state = false
		restore_previous()
	end
end

mod.on_enabled = function()
	-- Only apply if we're already in gameplay state
	if UISettings and in_gameplay_state then
		apply_slot_colors()
	end
end

mod.on_disabled = function()
	if previous_slot_colors and UISettings and UISettings.player_slot_colors then
		restore_previous()
		-- Force update HUD to clear custom colors
		if in_gameplay_state then
			update_player_panel_colors()
		end
	end
end