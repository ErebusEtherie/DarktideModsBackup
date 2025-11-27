local mod = get_mod("better_downed_indicators")

local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Status = mod:io_dofile("better_downed_indicators/scripts/mods/better_downed_indicators/status_detection")

local packages_to_load = {
    "packages/ui/views/mission_board_view/mission_board_view",
    "packages/ui/hud/team_player_panel/team_player_panel",
    "packages/ui/hud/interaction/interaction",
    "packages/ui/hud/wield_info/wield_info",
    "packages/ui/views/inventory_background_view/inventory_background_view",
}

mod._auspex_active_units = {}
mod._interaction_active_units = {} -- Track active interactions: unit -> {type = "health_station", interactee_unit = unit}
mod._game_state_init_timer = nil

mod:hook_safe(CLASS.AuspexScanningEffects, "_run_searching_sfx_loop", function(self)
    if self and self._owner_unit then
        mod._auspex_active_units[self._owner_unit] = true
    end
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "_stop_scan_units_effects", function(self)
    if self and self._owner_unit then
        mod._auspex_active_units[self._owner_unit] = false
    end
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "unwield", function(self)
    if self and self._owner_unit then
        mod._auspex_active_units[self._owner_unit] = false
    end
end)

mod:hook_safe(CLASS.AuspexEffects, "wield", function(self)
    if self and self._fx_extension and self._fx_extension._unit then
        mod._auspex_active_units[self._fx_extension._unit] = true
    end
end)

mod:hook_safe(CLASS.AuspexEffects, "unwield", function(self)
    if self and self._fx_extension and self._fx_extension._unit then
        mod._auspex_active_units[self._fx_extension._unit] = false
    end
end)

local COLOR_WHITE = { 255, 255, 255, 255 }
local COLOR_YELLOW = { 255, 255, 255, 0 }
local COLOR_RED = { 255, 255, 0, 0 }
local ICON_SIZE_PERSONAL = 65
local ICON_SIZE_TEAM = 55
local ICON_SIZE_OFFSET = 20
-- Using game's shadowing method (desaturation and intensity) instead of custom tint

-- Icons WITH distinct plain versions (different paths between glowly and plain)
local ICONS_WITH_DISTINCT_PLAIN = {
    pounced = true,
    consumed = true,
    grabbed = true,
    knocked_down = true,
    netted = true,
    ledge_hanging = true,
    mutant_charged = true,
    hogtied = true,
}

local function has_distinct_plain_version(detected_status)
    return ICONS_WITH_DISTINCT_PLAIN[detected_status] == true
end

local function get_icon_path(detected_status, use_glowing, customization_mode)
    if customization_mode == "customize_all" then
        -- All icons use plain versions
        return Status.icons[detected_status]
    elseif customization_mode == "customize_plain_only" and use_glowing and not has_distinct_plain_version(detected_status) then
        -- Only icons without distinct plain versions use plain icons
        return Status.icons[detected_status]
    else
        -- Normal behavior: use glowly if available, otherwise plain
        if use_glowing and Status.icons_glowing[detected_status] then
            return Status.icons_glowing[detected_status]
        elseif Status.icons[detected_status] then
            return Status.icons[detected_status]
        end
    end
    return nil
end

local function get_status_color(detected_status, icon_style, customization_mode, use_glowing, player)
    -- Determine if custom colors should be used
    local should_use_custom = (customization_mode == "customize_all") or 
                              (customization_mode == "customize_plain_only" and use_glowing and not has_distinct_plain_version(detected_status))
    
    if should_use_custom then
        return { 255, mod:get(detected_status .. "_r") or 255, mod:get(detected_status .. "_g") or 255, mod:get(detected_status .. "_b") or 255 }
    elseif icon_style == "plain_white" then
        return COLOR_WHITE
    elseif icon_style == "plain_yellow" then
        return COLOR_YELLOW
    elseif icon_style == "plain_red" then
        return COLOR_RED
    elseif icon_style == "plain_slot_color" then
        local player_slot = player and player.slot and player:slot()
        local player_slot_colors = UISettings.player_slot_colors
        if player_slot and player_slot_colors and player_slot_colors[player_slot] then
            return player_slot_colors[player_slot]
        end
    end
    return COLOR_WHITE
end

local function apply_color_to_texture(texture_style, color)
    if texture_style then
        if not texture_style.color then
            texture_style.color = { 255, 255, 255, 255 }
        end
        texture_style.color[1] = color[1]
        texture_style.color[2] = color[2]
        texture_style.color[3] = color[3]
        texture_style.color[4] = color[4]
    end
end

local function setup_texture_style(texture_style, icon_size)
    if not texture_style then
        return
    end
    
    if not texture_style.size then
        texture_style.size = { icon_size, icon_size }
    else
        texture_style.size[1] = icon_size
        texture_style.size[2] = icon_size
    end
    texture_style.horizontal_alignment = "center"
    texture_style.vertical_alignment = "center"
    texture_style.offset[1] = 0
    texture_style.offset[2] = 0
    
    local profile_pictures_mod = get_mod("ProfilePictures")
    local has_profile_pictures = profile_pictures_mod ~= nil
    if has_profile_pictures then
        texture_style.offset[3] = 4
    end
end

local function apply_shadow_to_pass(pass_style, should_shadow)
    if not pass_style then
        return
    end
    
    if not pass_style.material_values then
        pass_style.material_values = {}
    end
    
    local material_values = pass_style.material_values
    material_values.desaturation = should_shadow and 1 or 0
    material_values.intensity = should_shadow and 0.25 or 1
end

local function apply_widget_shadow(player_icon_widget, should_shadow)
    if not player_icon_widget then
        return
    end
    
    local enable_background_tint = mod:get("enable_background_tint")
    if enable_background_tint == nil then
        enable_background_tint = true
    end
    
    if not player_icon_widget.style then
        player_icon_widget.style = {}
    end
    
    -- Apply shadowing to the base texture pass
    local texture_style = player_icon_widget.style.texture
    if texture_style then
        if not enable_background_tint then
            -- Reset to default (no shadowing)
            if texture_style.material_values then
                texture_style.material_values.desaturation = 0
                texture_style.material_values.intensity = 1
            end
        else
            -- Use the game's shadowing method (same as spectating)
            -- This uses material_values.desaturation and material_values.intensity
            apply_shadow_to_pass(texture_style, should_shadow)
        end
    end
    
    -- Also apply shadowing to profile picture pass if it exists (for ProfilePictures mod compatibility)
    local profile_style = player_icon_widget.style.profile
    if profile_style then
        if not enable_background_tint then
            -- Reset to default (no shadowing)
            if profile_style.material_values then
                profile_style.material_values.desaturation = 0
                profile_style.material_values.intensity = 1
            end
            if profile_style.color then
                profile_style.color[1] = 255
                profile_style.color[2] = 255
                profile_style.color[3] = 255
                profile_style.color[4] = 255
            end
        else
            -- Apply same shadowing to profile picture overlay using BOTH methods
            -- Method 1: material_values (might not work on profile pass, but try anyway)
            apply_shadow_to_pass(profile_style, should_shadow)
            
            -- Method 2: color tinting (25% brightness = 64/255 for RGB, alpha stays 255)
            if should_shadow then
                if not profile_style.color then
                    profile_style.color = { 255, 255, 255, 255 }
                end
                profile_style.color[1] = 255  -- alpha
                profile_style.color[2] = 64   -- red at 25%
                profile_style.color[3] = 64   -- green at 25%
                profile_style.color[4] = 64   -- blue at 25%
            else
                -- Reset to default when should_shadow is false
                if profile_style.color then
                    profile_style.color[1] = 255
                    profile_style.color[2] = 255
                    profile_style.color[3] = 255
                    profile_style.color[4] = 255
                end
            end
        end
    end
    
    player_icon_widget.dirty = true
end

local function detect_death_or_respawn_status(player, is_dead, show_as_dead)
    if not player then
        return nil
    end
    
    -- Check if player has disconnected/left the game
    local player_manager = Managers.player
    if player_manager then
        local unique_id = player:unique_id()
        local all_players = player_manager:players()
        if not all_players or not all_players[unique_id] then
            -- Player is not in the player manager, they've disconnected
            return nil
        end
    end
    
    -- If player has a unit, they're not dead
    if player.player_unit then
        return nil
    end
    
    -- If not marked as dead, return nil
    if not (is_dead or show_as_dead) then
        return nil
    end
    
    -- Check if player is respawning using game mode manager
    local game_mode_manager = Managers.state and Managers.state.game_mode
    if game_mode_manager then
        -- Check if player can spawn (ready to respawn)
        local can_spawn = game_mode_manager.can_spawn_player and game_mode_manager:can_spawn_player(player)
        if can_spawn then
            return "respawning"
        end
        
        -- Check if player has a spawn time set (waiting to respawn)
        local time_until_spawn = game_mode_manager.player_time_until_spawn and game_mode_manager:player_time_until_spawn(player)
        if time_until_spawn then
            -- If time_until_spawn exists (even if 0), player is in respawn system
            return "respawning"
        end
        
        -- Check if player is in respawn queue
        local player_unit_spawn_manager = Managers.state and Managers.state.player_unit_spawn
        if player_unit_spawn_manager then
            local players_to_spawn = player_unit_spawn_manager.players_to_spawn and player_unit_spawn_manager:players_to_spawn()
            if players_to_spawn then
                for _, player_to_spawn in ipairs(players_to_spawn) do
                    if player_to_spawn == player then
                        return "respawning"
                    end
                end
            end
        end
    end
    
    -- If no unit and not respawning, player is dead
    return "dead"
end

local function replace_status_icon(self, status_icon, status_color, ui_renderer, player_override)
    local player = player_override or self._player or (self._data and self._data.player)
    local unit = player and player.player_unit

    if not unit then
        return status_icon, status_color
    end

    local detected_status = Status.for_unit(unit)
    if not detected_status then
        return status_icon, status_color
    end

    local icon_style = mod:get("icon_style") or "glowing"
    local use_glowing = icon_style == "glowing"
    local customization_mode = mod:get("plain_icon_customization_mode") or "off"

    local icon_path = get_icon_path(detected_status, use_glowing, customization_mode)
    if icon_path then
        status_icon = icon_path
        status_color = get_status_color(detected_status, icon_style, customization_mode, use_glowing, player)
    elseif detected_status == "dead" or detected_status == "respawning" or detected_status == "hogtied" or detected_status == "warp_grabbed" then
        icon_path = get_icon_path(detected_status, false, customization_mode)
        if icon_path then
            status_icon = icon_path
            status_color = get_status_color(detected_status, icon_style, customization_mode, false, player)
        end
    end

    return status_icon, status_color
end

mod:hook("HudElementPlayerPanelBase", "_set_status_icon", function(func, self, status_icon, status_color, ui_renderer)
    local player = self._player or (self._data and self._data.player)
    status_icon, status_color = replace_status_icon(self, status_icon, status_color, ui_renderer, player)
    func(self, status_icon, status_color, ui_renderer)
    local unit = player and player.player_unit
    
    local widgets_by_name = self._widgets_by_name
    local detected_status = nil
    if unit then
        detected_status = Status.for_unit(unit)
    elseif self._dead or self._show_as_dead then
        detected_status = detect_death_or_respawn_status(player, self._dead, self._show_as_dead)
    end
    
    if not detected_status then
        local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
        if player_icon_widget then
            apply_widget_shadow(player_icon_widget, false)
        end
        return
    end

    local widget = widgets_by_name and widgets_by_name.status_icon
    if not widget then
        return
    end

    local icon_style = mod:get("icon_style") or "glowing"
    local use_glowing = icon_style == "glowing"
    local customization_mode = mod:get("plain_icon_customization_mode") or "off"

    local icon_path = get_icon_path(detected_status, use_glowing, customization_mode)
    if not icon_path then
        if detected_status == "dead" or detected_status == "respawning" or detected_status == "hogtied" or detected_status == "warp_grabbed" then
            icon_path = get_icon_path(detected_status, false, customization_mode)
        end
        if not icon_path then
            local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
            if player_icon_widget then
                apply_widget_shadow(player_icon_widget, false)
            end
            return
        end
    end

    widget.content.texture = icon_path

    local texture_style = widget.style.texture
    if texture_style then
        local is_personal_panel = self.class_name == "HudElementPersonalPlayerPanel" or (self._data and self._data.is_my_player == true)
        local base_size = is_personal_panel and ICON_SIZE_PERSONAL or ICON_SIZE_TEAM
        local icon_size = (detected_status == "dead" or detected_status == "respawning" or detected_status == "luggable" or 
                          detected_status == "healing" or detected_status == "helping" or detected_status == "interacting") and (base_size + ICON_SIZE_OFFSET) or base_size
        if detected_status == "interacting" then
            icon_size = icon_size + 10
        end
        setup_texture_style(texture_style, icon_size)

        -- Determine if custom colors should be used
        local should_use_custom = (customization_mode == "customize_all") or 
                                  (customization_mode == "customize_plain_only" and use_glowing and not has_distinct_plain_version(detected_status))
        
        if should_use_custom or not use_glowing then
            local color = get_status_color(detected_status, icon_style, customization_mode, use_glowing, player)
            apply_color_to_texture(texture_style, color)
        end
    end

    widget.visible = true
    widget.dirty = true
    
    local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
    if player_icon_widget then
        apply_widget_shadow(player_icon_widget, true)
    end
end)

local function update_status_icon_widget(self, player)
    local supported_features = self._supported_features
    if not supported_features or not supported_features.status_icon then
        return
    end

    local unit = player and player.player_unit
    local widgets_by_name = self._widgets_by_name
    
    local detected_status = nil
    if unit then
        detected_status = Status.for_unit(unit)
    elseif self._dead or self._show_as_dead then
        detected_status = detect_death_or_respawn_status(player, self._dead, self._show_as_dead)
    end
    
    local widget = widgets_by_name and widgets_by_name.status_icon
    if not widget then
        return
    end
    
    if not detected_status then
        local current_texture = widget.content.texture
        local auspex_icon_glowing = Status.icons_glowing.auspex
        local auspex_icon_plain = Status.icons.auspex
        local luggable_icon_glowing = Status.icons_glowing.luggable
        local luggable_icon_plain = Status.icons.luggable
        local healing_icon_glowing = Status.icons_glowing.healing
        local healing_icon_plain = Status.icons.healing
        local helping_icon_glowing = Status.icons_glowing.helping
        local helping_icon_plain = Status.icons.helping
        local interacting_icon_glowing = Status.icons_glowing.interacting
        local interacting_icon_plain = Status.icons.interacting
        
        if current_texture == auspex_icon_glowing or current_texture == auspex_icon_plain or
           current_texture == luggable_icon_glowing or current_texture == luggable_icon_plain or
           current_texture == healing_icon_glowing or current_texture == healing_icon_plain or
           current_texture == helping_icon_glowing or current_texture == helping_icon_plain or
           current_texture == interacting_icon_glowing or current_texture == interacting_icon_plain then
            widget.visible = false
            widget.dirty = true
        end
        
        local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
        if player_icon_widget then
            apply_widget_shadow(player_icon_widget, false)
        end
        return
    end

    local icon_style = mod:get("icon_style") or "glowing"
    local use_glowing = icon_style == "glowing"
    local customization_mode = mod:get("plain_icon_customization_mode") or "off"

    local icon_path = get_icon_path(detected_status, use_glowing, customization_mode)
    if not icon_path then
        local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
        if player_icon_widget then
            apply_widget_shadow(player_icon_widget, false)
        end
        return
    end

    widget.content.texture = icon_path

    local texture_style = widget.style.texture
    if texture_style then
        local is_personal_panel = self.class_name == "HudElementPersonalPlayerPanel" or (self._data and self._data.is_my_player == true)
        local base_size = is_personal_panel and ICON_SIZE_PERSONAL or ICON_SIZE_TEAM
        local icon_size = (detected_status == "dead" or detected_status == "respawning" or detected_status == "luggable" or 
                          detected_status == "healing" or detected_status == "helping" or detected_status == "interacting") and (base_size + ICON_SIZE_OFFSET) or base_size
        if detected_status == "interacting" then
            icon_size = icon_size + 10
        end
        setup_texture_style(texture_style, icon_size)

        -- Determine if custom colors should be used
        local should_use_custom = (customization_mode == "customize_all") or 
                                  (customization_mode == "customize_plain_only" and use_glowing and not has_distinct_plain_version(detected_status))
        
        if should_use_custom or not use_glowing then
            local color = get_status_color(detected_status, icon_style, customization_mode, use_glowing, player)
            apply_color_to_texture(texture_style, color)
        end
    end

    widget.visible = true
    widget.dirty = true
    
    local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
    if player_icon_widget then
        apply_widget_shadow(player_icon_widget, true)
    end
    
    if detected_status == "auspex" or detected_status == "luggable" or 
       detected_status == "healing" or detected_status == "helping" or detected_status == "interacting" then
        local status_color = get_status_color(detected_status, icon_style, customization_mode, use_glowing, player)
        self:_set_status_icon(icon_path, status_color, nil)
    end
end

local function _sync_panel_player(self, player)
    if player and player ~= self._player then
        self._player = player
    end
    if self._data and player and self._data.player ~= player then
        self._data.player = player
    end
end

mod:hook("HudElementPlayerPanelBase", "_set_dead", function(func, self, is_dead, show_as_dead, ui_renderer)
    func(self, is_dead, show_as_dead, ui_renderer)
    
    if is_dead or show_as_dead then
        local player = self._player or (self._data and self._data.player)
        update_status_icon_widget(self, player)
    end
end)

mod:hook("HudElementPlayerPanelBase", "_set_player_respawn_timer", function(func, self, t, timer, is_dead)
    func(self, t, timer, is_dead)
    
    if is_dead or self._dead or self._show_as_dead then
        local player = self._player or (self._data and self._data.player)
        update_status_icon_widget(self, player)
    end
end)

mod:hook("HudElementPlayerPanelBase", "_update_player_features", function(func, self, dt, t, player, ui_renderer)
    _sync_panel_player(self, player) -- keep cache current
    func(self, dt, t, player, ui_renderer)
    
    if self._dead or self._show_as_dead then
        update_status_icon_widget(self, player)
    end
end)

mod:hook("HudElementPersonalPlayerPanel", "_update_player_features", function(func, self, dt, t, player, ui_renderer)
    _sync_panel_player(self, player) -- keep cache current
    func(self, dt, t, player, ui_renderer)
    update_status_icon_widget(self, player)
end)

mod:hook("HudElementTeamPlayerPanel", "_update_player_features", function(func, self, dt, t, player, ui_renderer)
    _sync_panel_player(self, player) -- keep cache current
    func(self, dt, t, player, ui_renderer)
    update_status_icon_widget(self, player)
end)


mod.update = function(dt)
    if mod._game_state_init_timer then
        mod._game_state_init_timer = mod._game_state_init_timer - dt
        if mod._game_state_init_timer <= 0 then
            mod._game_state_init_timer = nil
            
            local ui_manager = Managers.ui
            if ui_manager then
                local hud = ui_manager._hud
                if hud then
                    local team_panel_handler = hud:element("HudElementTeamPanelHandler")
                    if team_panel_handler and team_panel_handler._player_panels_array then
                        for _, panel_data in ipairs(team_panel_handler._player_panels_array) do
                            if panel_data and panel_data.panel and panel_data.player then
                                update_status_icon_widget(panel_data.panel, panel_data.player)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Track interactions for all players using RPC hooks (network-synced)
local InteractionSettings = require("scripts/settings/interaction/interaction_settings")

-- Hook RPCs to track interactions for all players
mod:hook("InteracteeSystem", "rpc_interaction_started", function(func, self, channel_id, unit_id, is_level_unit, game_object_id, interaction_input_type)
    func(self, channel_id, unit_id, is_level_unit, game_object_id, interaction_input_type)
    
    local interactor_unit = Managers.state.unit_spawner:unit(game_object_id)
    local interactee_unit = Managers.state.unit_spawner:unit(unit_id, is_level_unit)
    
    if interactor_unit and interactee_unit then
        local extension = self._unit_to_extension_map[interactee_unit]
        if extension then
            -- Try to get interaction type - use _active_interaction_type directly if available
            local interaction_type = extension._active_interaction_type
            if not interaction_type or interaction_type == "none" then
                interaction_type = extension:interaction_type()
            end
            
            if interaction_type and interaction_type ~= "none" then
                if not mod._interaction_active_units[interactor_unit] then
                    mod._interaction_active_units[interactor_unit] = {}
                end
                mod._interaction_active_units[interactor_unit].type = interaction_type
                mod._interaction_active_units[interactor_unit].interactee_unit = interactee_unit -- Store for cleanup
            end
        end
    end
end)

mod:hook("InteracteeSystem", "rpc_interaction_stopped", function(func, self, channel_id, unit_id, is_level_unit, result)
    func(self, channel_id, unit_id, is_level_unit, result)
    
    -- Find which player was interacting with this unit
    local interactee_unit = Managers.state.unit_spawner:unit(unit_id, is_level_unit)
    if interactee_unit then
        local extension = self._unit_to_extension_map[interactee_unit]
        
        -- Try multiple methods to find the interactor
        local interactor_unit = nil
        if extension then
            -- Method 1: From extension's _interactor_unit (might be cleared)
            interactor_unit = extension._interactor_unit
            
            -- Method 2: From interactee component
            if not interactor_unit then
                local uds = ScriptUnit.has_extension(interactee_unit, "unit_data_system") and ScriptUnit.extension(interactee_unit, "unit_data_system")
                if uds then
                    local interactee_component = uds:read_component("interactee")
                    if interactee_component then
                        interactor_unit = interactee_component.interactor_unit
                    end
                end
            end
            
            -- Method 3: Search our tracking table by interactee_unit
            if not interactor_unit then
                for tracked_unit, data in pairs(mod._interaction_active_units) do
                    if data.interactee_unit == interactee_unit then
                        interactor_unit = tracked_unit
                        break
                    end
                end
            end
        end
        
        if interactor_unit and mod._interaction_active_units[interactor_unit] then
            mod._interaction_active_units[interactor_unit] = nil
        end
    end
end)

-- Also hook local extension methods for immediate tracking (before RPC)
mod:hook("InteracteeExtension", "started", function(func, self, interactor_unit, interaction_input_type)
    func(self, interactor_unit, interaction_input_type)
    
    if interactor_unit then
        -- Use _active_interaction_type directly if available, fallback to interaction_type()
        local interaction_type = self._active_interaction_type
        if not interaction_type or interaction_type == "none" then
            interaction_type = self:interaction_type()
        end
        
        if interaction_type and interaction_type ~= "none" then
            if not mod._interaction_active_units[interactor_unit] then
                mod._interaction_active_units[interactor_unit] = {}
            end
            mod._interaction_active_units[interactor_unit].type = interaction_type
            mod._interaction_active_units[interactor_unit].interactee_unit = self._unit -- Store for cleanup
        end
    end
end)

mod:hook("InteracteeExtension", "stopped", function(func, self, result)
    -- Capture interactor_unit BEFORE calling the original function
    -- because the original function may clear _interactor_unit (especially on server rejection)
    local interactor_unit = self._interactor_unit
    
    func(self, result)
    
    if interactor_unit and mod._interaction_active_units[interactor_unit] then
        mod._interaction_active_units[interactor_unit] = nil
    end
end)

-- Also hook PlayerInteracteeExtension for player-to-player interactions
mod:hook("PlayerInteracteeExtension", "started", function(func, self, interactor_unit, interaction_input_type)
    func(self, interactor_unit, interaction_input_type)
    
    if interactor_unit then
        local interaction_type = self:interaction_type()
        if interaction_type and interaction_type ~= "none" then
            if not mod._interaction_active_units[interactor_unit] then
                mod._interaction_active_units[interactor_unit] = {}
            end
            mod._interaction_active_units[interactor_unit].type = interaction_type
            mod._interaction_active_units[interactor_unit].interactee_unit = self._unit -- Store for cleanup
        end
    end
end)

mod:hook("PlayerInteracteeExtension", "stopped", function(func, self, result)
    -- Capture interactor_unit BEFORE calling the original function
    -- because the original function may clear _interactor_unit (especially on server rejection)
    local interactor_unit = self._interactor_unit
    
    func(self, result)
    
    if interactor_unit and mod._interaction_active_units[interactor_unit] then
        mod._interaction_active_units[interactor_unit] = nil
    end
end)

-- Hook into InteractorExtension to catch cancellations and resets
mod:hook("InteractorExtension", "cancel_interaction", function(func, self, t)
    local interaction_component = self._interaction_component
    local interactor_unit = self._unit
    local target_unit = interaction_component and interaction_component.target_unit
    
    -- Clear interaction status before cancellation
    if interactor_unit and mod._interaction_active_units[interactor_unit] then
        mod._interaction_active_units[interactor_unit] = nil
    end
    
    func(self, t)
end)

mod:hook("InteractorExtension", "reset_interaction", function(func, self, reset_focus_unit)
    local interaction_component = self._interaction_component
    local interactor_unit = self._unit
    
    -- Clear interaction status when interaction is reset
    if interactor_unit and mod._interaction_active_units[interactor_unit] then
        mod._interaction_active_units[interactor_unit] = nil
    end
    
    func(self, reset_focus_unit)
end)

mod.on_enabled = function()
    for _, package_path in ipairs(packages_to_load) do
        Managers.package:load(package_path, mod:get_name(), nil, true)
    end
end
