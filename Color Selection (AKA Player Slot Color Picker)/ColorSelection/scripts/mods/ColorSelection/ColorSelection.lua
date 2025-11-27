local mod = get_mod("ColorSelection")

local UISettings = require("scripts/settings/ui/ui_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")

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

mod._player_custom_colors = {}
mod._local_player_account_id = nil  -- Store local player's account ID

mod.account_id_color_map = mod:persistent_table("account_id_color_map")

-- Update local player account ID (call this whenever player might be available)
local function update_local_player_id()
	local pm = Managers and Managers.player
	if pm then
		local local_player = pm:local_player_safe(1)
		if local_player then
			local success, account_id = pcall(function() return local_player:account_id() end)
			if success and account_id and account_id ~= "" then
				mod._local_player_account_id = account_id
				return true
			end
		end
	end
	return false
end

local function pcall_safe(func)
	local success, result = pcall(func)
	return success and result or nil
end

-- Forward declaration - defined after ColorAllocator
local get_color_for_account_id

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

    if Managers.ui:view_active(color_customizer_view_name) then
        Managers.ui:close_view(color_customizer_view_name)
        return
    end

    if Managers.ui:has_active_view() or Managers.ui:chat_using_input() then
        return
    end

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

	self.index_taken = { false, false, false, false }
	for slot, idx in pairs(self.slot_to_index) do
		if idx >= 1 and idx <= 4 then
			self.index_taken[idx] = true
		end
	end

	if my_slot and my_slot >= 1 then
		if self.slot_to_index[my_slot] and self.slot_to_index[my_slot] ~= 1 then

			local old_idx = self.slot_to_index[my_slot]
			self.index_taken[old_idx] = false
		end
		self.slot_to_index[my_slot] = 1
		self.index_taken[1] = true
	end

	if all_slots then
		for i = 1, #all_slots do
			local slot = all_slots[i]
			if slot ~= my_slot and slot and slot >= 1 then
				if not self.slot_to_index[slot] then

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

	if not account_id or account_id == "" then
		if mod:get("debug_mode") then
			mod:info(string.format("[ColorSelection] Returning bot color for slot %d (no account_id)", slot or 0))
		end
		return self.bot_color or self.cfg_colors[1]
	end

	-- Ensure local player ID is set (fallback if not initialized yet)
	if not mod._local_player_account_id then
		update_local_player_id()
	end

	-- Check if this is the local player using stored account ID
	-- Also do a live check as backup
	local is_local_player = false
	if mod._local_player_account_id and mod._local_player_account_id == account_id then
		is_local_player = true
	else
		-- Backup live check
		local pm = Managers and Managers.player
		if pm then
			local local_player = pm:local_player_safe(1)
			if local_player then
				local success, lp_account_id = pcall(function() return local_player:account_id() end)
				if success and lp_account_id and lp_account_id == account_id then
					is_local_player = true
					-- Update the cached ID
					mod._local_player_account_id = lp_account_id
				end
			end
		end
	end
	
	if is_local_player then
		-- Local player always gets slot 1 color - FETCH LIVE from settings to avoid stale data after mission
		return {
			mod:get("player_color_a"),
			mod:get("player_color_r"),
			mod:get("player_color_g"),
			mod:get("player_color_b"),
		}
	end

	-- Check if we're in the hub EARLY - before any other color lookups (multiple methods for reliability)
	local in_hub = false
	if Managers.mechanism then
		local success, mechanism_name = pcall(function() return Managers.mechanism:mechanism_name() end)
		if success and mechanism_name == "hub" then
			in_hub = true
		end
	end
	-- Backup check using game mode
	if not in_hub and Managers.state and Managers.state.game_mode then
		local success, game_mode_name = pcall(function() return Managers.state.game_mode:game_mode_name() end)
		if success and game_mode_name == "hub" then
			in_hub = true
		end
	end

	-- Check for custom colors (these apply in hub too)
	if account_id and mod._player_custom_colors and mod._player_custom_colors[account_id] then
		return mod._player_custom_colors[account_id]
	end

	if account_id then
		local saved_colors = mod:get("saved_player_colors")
		if saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
			local color = saved_colors[account_id]
			if color and type(color) == "table" then
				local argb_color = {255, color.r or 255, color.g or 255, color.b or 255}
				if not mod._player_custom_colors then
					mod._player_custom_colors = {}
				end
				mod._player_custom_colors[account_id] = argb_color
				return argb_color
			end
		end
	end

	-- In hub: Only return colors for local player or players with custom colors
	-- Return nil for others to preserve their default appearance
	if in_hub then
		-- No custom color found, return nil to skip color modification
		return nil
	end

	-- Mission only: check account_id_color_map for slot-based colors
	if account_id and mod.account_id_color_map and mod.account_id_color_map[account_id] then
		local color_index = mod.account_id_color_map[account_id]
		if color_index >= 1 and color_index <= 4 then
			return self.cfg_colors[color_index]
		end
	end

	if account_id and self.account_id_to_player_id[account_id] then
		local player_id = self.account_id_to_player_id[account_id]
		
		if self.bot_player_ids[player_id] then
			return self.bot_color or self.cfg_colors[1]
		end
		
		if self.player_to_slot_mapping[player_id] then
			slot = self.player_to_slot_mapping[player_id]
		end
	end

	local idx = self.slot_to_index[slot]
	if idx then
		-- Don't return slot 1 color for non-local players
		if idx == 1 and not is_local_player then
			-- Reassign to a different slot
			for i = 2, 4 do
				if not self.index_taken[i] then
					self.slot_to_index[slot] = i
					self.index_taken[i] = true
					return self.cfg_colors[i]
				end
			end
			-- Fallback to slot 2 if all taken
			return self.cfg_colors[2]
		end
		return self.cfg_colors[idx]
	end

	-- Assign new slot - start from 2 for non-local players (slot 1 reserved for local)
	local start_idx = is_local_player and 1 or 2
	for i = start_idx, 4 do
		if not self.index_taken[i] then
			self.slot_to_index[slot] = i
			self.index_taken[i] = true
			return self.cfg_colors[i]
		end
	end

	-- Fallback - use slot 2-4 for non-local, slot 1 for local
	local fallback = is_local_player and 1 or (((slot - 1) % 3) + 2)
	return self.cfg_colors[fallback]
end

-- Helper function to get color for any account_id (works in hub and missions)
-- Returns color table or nil if no color should be applied
get_color_for_account_id = function(account_id)
	if not account_id or account_id == "" then
		return nil
	end
	
	-- Ensure local player ID is set
	if not mod._local_player_account_id then
		update_local_player_id()
	end
	
	-- Check if this is the local player
	local is_local = mod._local_player_account_id and mod._local_player_account_id == account_id
	
	if is_local then
		-- Local player always gets their slot 1 color
		return {
			mod:get("player_color_a"),
			mod:get("player_color_r"),
			mod:get("player_color_g"),
			mod:get("player_color_b"),
		}
	end
	
	-- Check for custom colors (works in hub and missions)
	if mod._player_custom_colors and mod._player_custom_colors[account_id] then
		return mod._player_custom_colors[account_id]
	end
	
	-- Check saved colors
	local saved_colors = mod:get("saved_player_colors")
	if saved_colors and type(saved_colors) == "table" and saved_colors[account_id] then
		local c = saved_colors[account_id]
		if c and type(c) == "table" then
			local color = {255, c.r or 255, c.g or 255, c.b or 255}
			-- Cache it
			if not mod._player_custom_colors then
				mod._player_custom_colors = {}
			end
			mod._player_custom_colors[account_id] = color
			return color
		end
	end
	
	-- Check if we're in the hub (multiple methods for reliability)
	local in_hub = false
	if Managers.mechanism then
		local success, mechanism_name = pcall(function() return Managers.mechanism:mechanism_name() end)
		if success and mechanism_name == "hub" then
			in_hub = true
		end
	end
	-- Backup check using game mode
	if not in_hub and Managers.state and Managers.state.game_mode then
		local success, game_mode_name = pcall(function() return Managers.state.game_mode:game_mode_name() end)
		if success and game_mode_name == "hub" then
			in_hub = true
		end
	end
	
	if in_hub then
		-- In hub, no slot colors for non-custom players
		return nil
	end
	
	-- In missions, use slot-based colors via ColorAllocator
	-- Try to get player's actual slot
	local player = nil
	local pm = Managers and Managers.player
	if pm then
		local human_players = pm:human_players()
		if human_players then
			for _, p in pairs(human_players) do
				local success, pid = pcall(function() return p:account_id() end)
				if success and pid == account_id then
					player = p
					break
				end
			end
		end
	end
	
	local slot = 1
	if player then
		local success, s = pcall(function() return player:slot() end)
		if success and s then
			slot = s
		end
	end
	
	-- Use ColorAllocator for mission slot colors
	return ColorAllocator:color_for(slot, account_id)
end

local function _on_player_removed(player)
	if not player then return end

	local success, account_id = pcall(function() return player:account_id() end)
	if success and account_id and mod._player_custom_colors then

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

				local human_success, is_human = pcall(function() return player:is_human_controlled() end)
				local bot_success, is_bot = pcall(function() return player:is_bot() end)
				local id_success, account_id = pcall(function() return player:account_id() end)

				if not (human_success and is_human) then goto skip_cache end
				if bot_success and is_bot then goto skip_cache end
				if not (id_success and account_id and account_id ~= "") then goto skip_cache end

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

	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end
	
	return _player_cache.by_slot[slot]
end

local function get_player_by_account_id(account_id)
	if not account_id then return nil end

	local current_time = os.clock()
	if current_time - _player_cache.last_update > 0.5 then
		update_player_cache()
	end
	
	return _player_cache.by_account_id[account_id]
end


local function apply_color_to_name_only(text, color)
	if not text or type(text) ~= "string" or not color then
		return text
	end
	
	local c = color
	local target_color_tag = string.format("{#color(%d,%d,%d)}", c[2], c[3], c[4])


	local stripped_text = text:gsub("^{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}$", "")


	return target_color_tag .. stripped_text .. "{#reset()}"
end

local function apply_widget_color(panel)
	if not panel or not panel._widgets_by_name or not mod:get("color_hud_names") then
		return
	end

	local player = panel._player
	if not player and panel._data then
		player = panel._data.player
	end

	local slot = nil
	local account_id = nil
	
	if player then

		local success, result = pcall(function() return player:slot() end)
		if success and result then
			slot = result
		end

		local id_success, id_result = pcall(function() return player:account_id() end)
		if id_success and id_result then
			account_id = id_result
		end

		if slot and not panel._player_slot then
			panel._player_slot = slot
		end
	else

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
		return  -- Skip color modification (hub without custom color)
	end
	
	local widget = panel._widgets_by_name.player_name
	if not widget or not widget.style or not widget.style.text then
		return
	end

	if widget.style.text.text_color then
		widget.style.text.text_color = {color[1], color[2], color[3], color[4]}
	end

	if widget.style.text.default_text_color then
		widget.style.text.default_text_color = {color[1], color[2], color[3], color[4]}
	end

	if widget.content and widget.content.text then
		local current_text = widget.content.text
		local new_text = apply_color_to_name_only(current_text, color)

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

mod:hook_safe("HudElementPlayerPanelBase",     "destroy", function(self) alias_ability_bar_widget(self) end)

mod:hook_safe("HudElementPersonalPlayerPanelHub", "update", function(self)
	if mod:is_enabled() and mod:get("color_hud_names") then
		-- Personal panel in hub is always local player
		local color = {
			mod:get("player_color_a") or 255,
			mod:get("player_color_r") or 226,
			mod:get("player_color_g") or 210,
			mod:get("player_color_b") or 117,
		}
		
		local widget = self._widgets_by_name and self._widgets_by_name.player_name
		if widget and widget.style and widget.style.text then
			if widget.style.text.text_color then
				widget.style.text.text_color = {color[1], color[2], color[3], color[4]}
			end
			if widget.style.text.default_text_color then
				widget.style.text.default_text_color = {color[1], color[2], color[3], color[4]}
			end
			if widget.content and widget.content.text then
				local current_text = widget.content.text
				local new_text = apply_color_to_name_only(current_text, color)
				widget.content.text = new_text
				widget.dirty = true
			end
		end
	end
end)

mod:hook_safe("HudElementPersonalPlayerPanelHub", "_set_player_name", function(self) 
	if mod:is_enabled() and mod:get("color_hud_names") then
		apply_widget_color(self)
	end
end)

mod:hook_safe("HudElementPersonalPlayerPanel", "update", function(self)
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
		-- In hub, only color local player
		local player = self._player
		if not player and self._data then
			player = self._data.player
		end
		
		if player then
			local account_id = nil
			local id_success, id_result = pcall(function() return player:account_id() end)
			if id_success and id_result then
				account_id = id_result
			end
			
			-- Only color if local player or has custom color
			local color = get_color_for_account_id(account_id)
			if color then
				local widget = self._widgets_by_name and self._widgets_by_name.player_name
				if widget and widget.style and widget.style.text then
					if widget.style.text.text_color then
						widget.style.text.text_color = {color[1], color[2], color[3], color[4]}
					end
					if widget.style.text.default_text_color then
						widget.style.text.default_text_color = {color[1], color[2], color[3], color[4]}
					end
					if widget.content and widget.content.text then
						local current_text = widget.content.text
						local new_text = apply_color_to_name_only(current_text, color)
						widget.content.text = new_text
						widget.dirty = true
					end
				end
			end
		end
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

local function apply_nameplate_color(marker)
	if not marker or not marker.widget then
		return
	end
	
	local player = marker.data
	if not player then
		return
	end

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
	
	-- Use get_color_for_account_id which handles hub logic properly
	-- (returns color for local player and custom colors, nil for others in hub)
	local color = get_color_for_account_id(account_id)
	if not color then
		return  -- Skip color modification (hub without custom color, or non-local player in hub)
	end
	
	local widget = marker.widget
	local content = widget.content
	
	if not content or not content.header_text then
		return
	end
	
	local current_text = content.header_text
	local color_names = mod:get("color_nameplate_names")
	local c = color
	local color_tag = string.format("{#color(%d,%d,%d)}", c[2], c[3], c[4])
	
	local stripped_text = current_text:gsub("^{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}$", ""):gsub("{#reset%(%)}([^\n])", "%1"):gsub("{#reset%(%)}", "")
	
	local new_text
	if color_names then
		new_text = color_tag .. stripped_text .. "{#reset()}"
	else
		local icon, rest = stripped_text:match("^(.-%b[])%s*(.*)$")
		if not icon or icon == "" then
			icon, rest = stripped_text:match("^([^\32-\126]+)%s*(.*)$")
		end
		
		if icon and icon ~= "" then
			if rest and rest ~= "" then
				new_text = color_tag .. icon .. "{#reset()} " .. rest
			else
				new_text = color_tag .. icon .. "{#reset()}"
			end
		else
			new_text = color_tag .. stripped_text .. "{#reset()}"
		end
	end
	
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

mod:hook_safe("HudElementWorldMarkers", "event_add_world_marker_unit", function(self, marker_type, unit, callback, data)
	if not mod:is_enabled() then return end

	if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then

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

mod:hook_safe("HudElementNameplates", "update", function(self, dt, t, ui_renderer)
	if not mod:is_enabled() then return end

	if not Managers or not Managers.ui then return end
	
	local ui_manager = Managers.ui
	local hud = ui_manager._hud
	if not hud then return end

	local success, world_markers = pcall(function() return hud:element("HudElementWorldMarkers") end)
	if not success or not world_markers or not world_markers._markers_by_id then return end
	
	for marker_id, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type
		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			apply_nameplate_color(marker)
		end
	end
end)




mod:hook(CLASS.ConstantElementChat, "_participant_displayname", function(func, self, participant)
	local display_name = func(self, participant)
	
	if not mod:is_enabled() or not mod:get("color_chat_names") then
		return display_name
	end
	
	local account_id = participant and participant.account_id
	if not account_id then
		return display_name
	end

	local slot = 1  -- Default to slot 1
	local player = get_player_by_account_id(account_id)
	if player then
		slot = pcall_safe(function() return player:slot() end) or 1
	end
	
	local color = ColorAllocator:color_for(slot, account_id)
	if not color then
		return display_name  -- Skip color modification (hub without custom color)
	end
	
	if color then
		local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
		local result = color_tag .. display_name .. "{#reset()}"
		
		if mod:get("debug_mode") then
			mod:echo(string.format("[ColorSelection] Chat: %s (ID: %s, Slot: %d) - Color: %d,%d,%d", 
				display_name, account_id:sub(1, 8), slot, color[2], color[3], color[4]))
		end
		
		return result
	end
	
	return display_name
end)

mod:hook_safe(CLASS.LobbyView, "_sync_player", function(self, unique_id, player)
	if not mod:is_enabled() or not mod:get("color_lobby_names") then
		return
	end
	
	local spawn_slots = self._spawn_slots
	if not spawn_slots then
		return
	end
	
	local slot_id = self:_player_slot_id(unique_id)
	local slot = slot_id and spawn_slots[slot_id]
	
	if slot and slot.synced then
		local panel_widget = slot.panel_widget
		local panel_content = panel_widget and panel_widget.content
		
		if not panel_content or not panel_content.character_name then
			return
		end
		
		local account_id = pcall_safe(function() return player:account_id() end)
		local player_slot = pcall_safe(function() return player:slot() end) or 1
		
		if account_id then
			local color = ColorAllocator:color_for(player_slot, account_id)
			if color then
				local current_name = panel_content.character_name
				local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])

				local stripped = current_name:gsub("{#color%([^%)]*%)}", ""):gsub("{#reset%(%)}",  "")
				panel_content.character_name = color_tag .. stripped .. "{#reset()}"
				
				if mod:get("debug_mode") then
					mod:echo(string.format("[ColorSelection] Lobby: %s (ID: %s, Slot: %d) - Color applied", 
						stripped, account_id:sub(1, 8), player_slot))
				end
			end
		end
	end
end)

mod:hook(CLASS.HudElementCombatFeed, "_get_unit_presentation_name", function(func, self, unit)
	if not mod:is_enabled() then
		return func(self, unit)
	end
	
	local player_unit_spawn_manager = Managers.state and Managers.state.player_unit_spawn
	if not player_unit_spawn_manager then
		return func(self, unit)
	end
	
	local player = unit and player_unit_spawn_manager:owner(unit)
	
	if player then
		local account_id = pcall_safe(function() return player:account_id() end)
		local slot = pcall_safe(function() return player:slot() end) or 1
		
		if account_id then
			local color = ColorAllocator:color_for(slot, account_id)
			local name = func(self, unit)
			
			if color and name then
				local TextUtils = require("scripts/utilities/ui/text")
				local colored_name = TextUtils.apply_color_to_text(name, color)
				
				if mod:get("debug_mode") then
					mod:echo(string.format("[ColorSelection] Combat Feed: %s (ID: %s, Slot: %d) - Color applied", 
						name, account_id:sub(1, 8), slot))
				end
				
				return colored_name
			end
		end
	end
	
	return func(self, unit)
end)

local function apply_color_to_player_name(name, player)
	if not name or name == "" or not player then
		return name
	end
	
	local account_id = pcall_safe(function() return player:account_id() end)
	if not account_id or account_id == "" then
		return name
	end

	local color = get_color_for_account_id(account_id)
	
	if color then
		local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
		return color_tag .. name .. "{#reset()}"
	end
	
	return name
end

mod:hook(CLASS.HumanPlayer, "name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end

	if mod:get("color_hud_names") or mod:get("color_chat_names") or 
	   mod:get("color_lobby_names") then
		return apply_color_to_player_name(name, self)
	end
	
	return name
end)

mod:hook(CLASS.RemotePlayer, "name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	if mod:get("color_hud_names") or mod:get("color_chat_names") or 
	   mod:get("color_lobby_names") then
		return apply_color_to_player_name(name, self)
	end
	
	return name
end)

mod:hook(CLASS.PlayerInfo, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	if mod:get("color_hud_names") or mod:get("color_chat_names") or 
	   mod:get("color_lobby_names") then

		local account_id = self._account_id
		if account_id then
			local color = get_color_for_account_id(account_id)
			if color then
				local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
				return color_tag .. name .. "{#reset()}"
			end
		end
	end
	
	return name
end)

mod:hook(CLASS.RemotePlayer, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	if mod:get("color_hud_names") or mod:get("color_chat_names") or 
	   mod:get("color_lobby_names") then
		return apply_color_to_player_name(name, self)
	end
	
	return name
end)

mod:hook(CLASS.PresenceEntryMyself, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	if mod:get("color_hud_names") or mod:get("color_chat_names") or 
	   mod:get("color_lobby_names") then
		-- PresenceEntryMyself is always the local player
		local color = {
			mod:get("player_color_a"),
			mod:get("player_color_r"),
			mod:get("player_color_g"),
			mod:get("player_color_b"),
		}
		local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
		return color_tag .. name .. "{#reset()}"
	end
	
	return name
end)

mod:hook(CLASS.PresenceEntryImmaterium, "character_name", function(func, self)
	local name = func(self)
	
	if not mod:is_enabled() then
		return name
	end
	
	if mod:get("color_hud_names") or mod:get("color_chat_names") or 
	   mod:get("color_lobby_names") then

		local account_id = self._immaterium_entry and self._immaterium_entry.account_id
		if account_id then
			local color = get_color_for_account_id(account_id)
			if color then
				local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
				return color_tag .. name .. "{#reset()}"
			end
		end
	end
	
	return name
end)

mod:hook_require("scripts/utilities/profile_utils", function(instance)
	mod:hook(instance, "character_name", function(func, profile)
		local name = func(profile)
		
		if not mod:is_enabled() then
			return name
		end
		
		if mod:get("color_hud_names") or mod:get("color_chat_names") or 
		   mod:get("color_lobby_names") then
			local account_id = profile and profile.account_id
			if account_id then
				local color = get_color_for_account_id(account_id)
				if color then
					local color_tag = string.format("{#color(%d,%d,%d)}", color[2], color[3], color[4])
					return color_tag .. name .. "{#reset()}"
				end
			end
		end
		
		return name
	end)
end)

local function install_player_panel_hooks(base)
	if not base or base.__cs_hooks then return end
	base.__cs_hooks = true

	mod:hook_safe(base, "update", function(self, dt, t, ui_renderer)

		if mod:is_enabled() and mod:get("color_hud_names") and self._widgets_by_name and self._widgets_by_name.player_name then
			apply_widget_color(self)
		end
	end)
	
	mod:hook_safe(base, "_update_player_name_prefix", function(self)
		if not mod:is_enabled() then return end
		if self._colors_revision ~= mod._colors_revision then
			self._colors_revision = mod._colors_revision
			self._player_slot = nil

			apply_widget_color(self)
		end
	end)
	
	mod:hook_safe(base, "_set_player_name", function(self)
		if not mod:is_enabled() then return end
		apply_widget_color(self) 
	end)
	
	mod:hook_safe(base, "_update_player_features", function(self, dt, t, player, ui_renderer)

		if player then
			self._player = player

			local success, slot = pcall(function() return player:slot() end)
			if success and slot then
				self._player_slot = slot
			end
		end
		apply_widget_color(self) 
	end)

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

local function update_world_markers()
	local ui_manager = Managers and Managers.ui
	if not ui_manager then return false end
	
	local hud = ui_manager:get_hud()
	if not hud then return false end
	
	local world_markers = hud:element("HudElementWorldMarkers")
	if not world_markers or not world_markers._markers_by_id then return false end
	
	for marker_id, marker in pairs(world_markers._markers_by_id) do
		local marker_type = marker.type

		if marker_type and (marker_type:match("nameplate") or marker_type:match("companion")) then
			-- Reset mod compatibility flags so who_are_you and true_level re-apply
			marker.wru_modified = false
			marker.tl_modified = false
			apply_nameplate_color(marker)
		end
	end
	
	return true
end

local function update_mod_compatibility_flags()
	local ui_manager = Managers and Managers.ui
	if not ui_manager then return end

	-- LobbyView
	local lobby_view = ui_manager:view_instance("lobby_view")
	if lobby_view and lobby_view._spawn_slots then
		for _, slot in pairs(lobby_view._spawn_slots) do
			slot.wru_modified = false
			slot.tl_modified = false
		end
	end

	-- GroupFinderView
	local group_finder_view = ui_manager:view_instance("group_finder_view")
	if group_finder_view then
		-- Reset request grid widgets
		if group_finder_view._player_request_grid then
			local widgets = group_finder_view._player_request_grid:widgets()
			if widgets then
				for _, widget in ipairs(widgets) do
					widget.wru_modified = false
					widget.tl_modified = false
				end
			end
		end
		-- Reset preview grid widgets
		if group_finder_view._preview_grid then
			local widgets = group_finder_view._preview_grid:widgets()
			if widgets then
				for _, widget in ipairs(widgets) do
					widget.wru_modified = false
					widget.tl_modified = false
				end
			end
		end
	end
end

local function update_player_panel_colors()
	update_mod_compatibility_flags()

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
				-- Reset mod compatibility flags so who_are_you and true_level re-apply
				element.wru_modified = false
				element.tl_modified = false
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPlayerPanel" or class_name == "HudElementTeamPlayerPanelHub" then
				-- Reset mod compatibility flags so who_are_you and true_level re-apply
				element.wru_modified = false
				element.tl_modified = false
				apply_widget_color(element)
			elseif class_name == "HudElementTeamPanelHandler" then
				-- Reset flags on all panels in handler
				if element._player_panels_array then
					for _, data in ipairs(element._player_panels_array) do
						if data.panel then
							data.panel.wru_modified = false
							data.panel.tl_modified = false
						end
					end
				end
				colourise_team_panels(element)
			end
		end
	end

	update_world_markers()
	
	return true
end

local last_debug_state = ""  -- Track last debug output to prevent spam
local logged_reassignments = {}  -- Track which players we've logged reassignments for

local apply_slot_colors_internal

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

	local operation_count = 0
	while #color_assignment_queue > 0 do
		local operation = table.remove(color_assignment_queue, 1)
		operation_count = operation_count + 1
		
		if debug_mode then
			local msg = string.format("[ColorSelection] Executing queued operation %d/%d", operation_count, queue_size)
			mod:info(msg)
			mod:echo(msg)
		end

		operation()
	end

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

apply_slot_colors_internal = function()
	if not UISettings then
		return
	end
	
	if Managers.mechanism and Managers.mechanism:mechanism_name() == "hub" then
		return
	end
	
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


	local player_to_slot = ColorAllocator.player_to_slot_mapping or {}
	local used_slots = {false, false, false, false}  -- Track which 1-4 slots are used

	local player_slots = {}  -- Store {unique_id, original_slot, player}
	local current_players = {}  -- Track which players are currently in game
	local local_player_id = nil
	local human_players = pm:human_players()
	local lp = pm:local_player_safe(1)
	
	if human_players then
		for unique_id, player in pairs(human_players) do
			if player then

				local human_success, is_human = pcall(function() return player:is_human_controlled() end)
				local bot_success, is_bot = pcall(function() return player:is_bot() end)
				local account_success, account_id_check = pcall(function() return player:account_id() end)




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

					if lp and player == lp then
						local_player_id = unique_id
					end
				end
				
				::skip_player::
			end
		end
	end

	for player_id in pairs(player_to_slot) do
		if not current_players[player_id] then
			local old_slot = player_to_slot[player_id]
			player_to_slot[player_id] = nil

			if old_slot >= 1 and old_slot <= 4 then
				used_slots[old_slot] = false
			end

			for key in pairs(logged_reassignments) do
				if key:sub(1, 8) == player_id:sub(1, 8) then
					logged_reassignments[key] = nil
				end
			end
		end
	end

	for player_id, slot in pairs(player_to_slot) do
		if player_id ~= local_player_id and slot >= 1 and slot <= 4 then
			used_slots[slot] = true
		end
	end

	if local_player_id then
		player_to_slot[local_player_id] = 1
		used_slots[1] = true  -- Reserve slot 1 for local player
	end


	local account_id_to_player_id = {}
	for _, data in ipairs(player_slots) do
		local slot = data.slot
		local unique_id = data.unique_id
		local player = data.player

		local acct_success, account_id = pcall(function() return player:account_id() end)
		if acct_success and account_id then
			account_id_to_player_id[account_id] = unique_id
		end

		if unique_id == local_player_id then
			goto continue
		end

		if not player_to_slot[unique_id] then

			local assigned = false
			for i = 2, 4 do  -- Start from 2, not 1
				if not used_slots[i] then
					player_to_slot[unique_id] = i
					used_slots[i] = true
					if slot ~= i then

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

			if not assigned then

				local hash_source = account_id or unique_id

				local hash = 0
				for i = 1, #hash_source do
					hash = hash + string.byte(hash_source, i)
				end

				local reassigned_slot = (hash % 3) + 2  -- Maps to 2, 3, or 4
				player_to_slot[unique_id] = reassigned_slot
			end
		end
		
		::continue::
	end

	ColorAllocator.player_to_slot_mapping = player_to_slot
	ColorAllocator.account_id_to_player_id = account_id_to_player_id

	local current_state = {}
	for player_id, slot in pairs(player_to_slot) do
		table.insert(current_state, player_id:sub(1, 8) .. "=" .. slot)
	end
	table.sort(current_state)
	local state_hash = table.concat(current_state, ",")

	if state_hash ~= last_debug_state then
		last_debug_state = state_hash
		local debug_enabled = mod:get("debug_mode")
		local log_func = debug_enabled and mod.echo or mod.info
		
		log_func(mod, "[ColorSelection] === Final slot assignments ===")
		for player_id, slot in pairs(player_to_slot) do
			log_func(mod, string.format("[ColorSelection]   Player %s → slot %d", player_id:sub(1, 8), slot))
		end
	end

	if local_player_id and player_to_slot[local_player_id] then
		my_slot = player_to_slot[local_player_id]  -- Should always be 1
	end

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

	local color_metatable = {
		__index = function(_, k)
			if type(k) ~= "number" or k < 1 then return nil end

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

	UISettings.player_slot_colors = setmetatable({}, color_metatable)

	mod._colors_revision = mod._colors_revision + 1
	update_player_panel_colors()

	local debug_enabled = mod:get("debug_mode")
	if debug_enabled then
		mod:echo("[ColorSelection] Slot colors applied successfully")
	else
		mod:info("[ColorSelection] Slot colors applied successfully")
	end
end

local function apply_slot_colors()
	queue_color_assignment()
end

mod.apply_slot_colors = apply_slot_colors
mod.update_player_panel_colors = update_player_panel_colors
mod.ColorAllocator = ColorAllocator
mod.ColorUtils = ColorUtils
mod.CONSTANTS = CONSTANTS
mod.get_player_by_account_id = get_player_by_account_id
mod.get_player_by_slot = get_player_by_slot
mod.get_color_for_account_id = get_color_for_account_id

local in_gameplay_state = false

mod:hook_require("scripts/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup_content_list", function(module)
	if module.from_player_info then
		local original_from_player_info = module.from_player_info
		
		module.from_player_info = function(parent, player_info)
			local popup_menu_items, num_menu_items = original_from_player_info(parent, player_info)

			if not player_info:is_own_player() and player_info:account_id() then
				local account_id = player_info:account_id()

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

				_add_divider()

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

mod.on_all_mods_loaded = function()
	update_local_player_id()  -- Try to get local player ID early
	ColorAllocator:reset()
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

	local dmf = get_mod("DMF")
	if dmf then

		mod:hook(dmf, "check_keybinds", function(func)

			if Managers.ui and Managers.ui:view_active(color_customizer_view_name) then

				return
			end

			return func()
		end)
	end
end

mod.on_game_state_changed = function(status, state_name)
	update_local_player_id()  -- Update local player ID on state change
	
	if status == "enter" and state_name == "StateGameplay" then
		in_gameplay_state = true
		apply_slot_colors()
	elseif status == "exit" and state_name == "StateGameplay" then
		in_gameplay_state = false
		restore_previous()
	end
end

mod.on_enabled = function()
	update_local_player_id()  -- Update local player ID when mod enabled
	if UISettings and in_gameplay_state then
		apply_slot_colors()
	end
end

mod.on_disabled = function()
	if previous_slot_colors and UISettings and UISettings.player_slot_colors then
		restore_previous()

		if in_gameplay_state then
			update_player_panel_colors()
		end
	end
end

mod.on_setting_changed = function(setting_id)
	if string.find(setting_id, "_color_") then
		ColorAllocator:reset()
		if UISettings and in_gameplay_state then
			apply_slot_colors()
		end
		update_player_panel_colors()
	elseif setting_id == "color_hud_names" or setting_id == "color_nameplate_names" then
		update_player_panel_colors()
	end
end
