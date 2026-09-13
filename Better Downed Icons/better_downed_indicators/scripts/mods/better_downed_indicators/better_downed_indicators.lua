local mod = get_mod("better_downed_indicators")

local UISettings = require("scripts/settings/ui/ui_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local Status = mod:io_dofile("better_downed_indicators/scripts/mods/better_downed_indicators/helpers/status_detection")
local AggroDetection = mod:io_dofile("better_downed_indicators/scripts/mods/better_downed_indicators/helpers/aggro_detection")

local packages_to_load = {
    "packages/ui/views/mission_board_view/mission_board_view",
    "packages/ui/hud/team_player_panel/team_player_panel",
    "packages/ui/hud/interaction/interaction",
    "packages/ui/hud/wield_info/wield_info",
    "packages/ui/views/inventory_background_view/inventory_background_view",
}

mod._auspex_active_units = {}
mod._interaction_active_units = {}
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

local AGGRO_DEFAULT_COLORS = {
    daemonhost  = { 0, 255, 0 },
    captain     = { 255, 96, 0 },
    monstrosity = { 255, 0, 0 },
    disabler    = { 77, 0, 255 },
    sniper      = { 0, 255, 255 },
    pox_burster = { 255, 255, 0 },
    crusher     = { 0, 0, 255 },
    rager       = { 255, 43, 96 },
    grenadier   = { 34, 100, 34 },
    flamer      = { 86, 10, 40 },
}

local function get_aggro_glow_color(aggro_type)
    local color = mod:get("aggro_" .. aggro_type .. "_color")
    if color then return color end
    
    local defaults = AGGRO_DEFAULT_COLORS[aggro_type]
    if not defaults then return nil end
    return {
        255,
        defaults[1],
        defaults[2],
        defaults[3],
    }
end

local function init_aggro_glow_widget(self, glow_size)
    if self._widgets_by_name.bdi_aggro_glow then return end

    local glow_widget_def = UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "glow1",
            value = "content/ui/materials/frames/frame_glow_01",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                size = { glow_size, glow_size },
                color = { 0, 255, 255, 255 },
                offset = { 0, 0, 10 }
            },
        },
        {
            pass_type = "texture",
            style_id = "glow2",
            value = "content/ui/materials/frames/frame_glow_01",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                size = { glow_size + 4, glow_size + 4 },
                color = { 0, 255, 255, 255 },
                offset = { 0, 0, 11 }
            },
        }
    }, "player_icon")

    local name = "bdi_aggro_glow"
    local widget = UIWidget.init(name, glow_widget_def)

    self._widgets_by_name[name] = widget
    self._widgets[#self._widgets + 1] = widget
end

mod:hook("HudElementPersonalPlayerPanel", "init", function(func, self, parent, draw_layer, start_scale, data)
    func(self, parent, draw_layer, start_scale, data)
    init_aggro_glow_widget(self, 96)
end)

mod:hook("HudElementTeamPlayerPanel", "init", function(func, self, parent, draw_layer, start_scale, data)
    func(self, parent, draw_layer, start_scale, data)
    init_aggro_glow_widget(self, 80)
end)

local function is_personal_panel(panel, player)
    if panel then
        local class_name = panel.__class_name or panel.class_name
        if class_name == "HudElementPersonalPlayerPanel" or class_name == "HudElementPersonalPlayerPanelHub" then
            return true
        end
        if class_name == "HudElementTeamPlayerPanel" or class_name == "HudElementTeamPlayerPanelHub" then
            return false
        end
        local data = panel._data
        if data then
            if data.scenegraph_id == "local_player" or data.using_fixed_scenegraph_id == true then
                return true
            end
            if data.scenegraph_id and string.find(data.scenegraph_id, "player_") then
                return false
            end
        end
    end
    return false
end

local function is_panel_indicators_enabled(panel, player)
    local is_personal = is_personal_panel(panel, player)
    if is_personal then
        local enabled = mod:get("enable_personal_panel_indicators")
        if enabled ~= nil then
            return enabled
        end
        return true
    else
        local enabled = mod:get("enable_team_panel_indicators")
        if enabled ~= nil then
            return enabled
        end
        return true
    end
end

local function get_panel_offsets(panel, player)
    local is_personal = is_personal_panel(panel, player)
    if is_personal then
        local offset_x = mod:get("personal_panel_offset_x") or 0
        local offset_y = mod:get("personal_panel_offset_y") or 0
        return offset_x, offset_y
    else
        local offset_x = mod:get("team_panel_offset_x") or 0
        local offset_y = mod:get("team_panel_offset_y") or 0
        return offset_x, offset_y
    end
end

local function is_aggro_glow_enabled(panel, player)
    local is_personal = is_personal_panel(panel, player)
    if is_personal then
        local enabled = mod:get("aggro_enable_on_self")
        if enabled ~= nil then
            return enabled
        end
        return true
    else
        local enabled = mod:get("aggro_enable_on_teammates")
        if enabled ~= nil then
            return enabled
        end
        return true
    end
end

local function apply_aggro_glow(self, player)
    local widgets_by_name = self._widgets_by_name
    if not widgets_by_name then return end

    local glow_widget = widgets_by_name.bdi_aggro_glow
    if not glow_widget or not glow_widget.style then return end

    local glow1_style = glow_widget.style.glow1
    local glow2_style = glow_widget.style.glow2

    if not is_aggro_glow_enabled(self, player) then
        if glow1_style.color[1] ~= 0 then
            glow1_style.color[1] = 0
            glow2_style.color[1] = 0
            glow_widget.dirty = true
            if self.set_dirty then
                self:set_dirty()
            end
        end
        return
    end

    local unit = player and player.player_unit
    local aggro_type = unit and AggroDetection.get_aggro_for_unit(unit)

    if not aggro_type then
        if glow1_style.color[1] ~= 0 then
            glow1_style.color[1] = 0
            glow2_style.color[1] = 0
            glow_widget.dirty = true
        end
        return
    end

    local color = get_aggro_glow_color(aggro_type)
    if not color then return end

    glow1_style.color[1] = 255
    glow1_style.color[2] = color[2]
    glow1_style.color[3] = color[3]
    glow1_style.color[4] = color[4]

    glow2_style.color[1] = 255
    glow2_style.color[2] = color[2]
    glow2_style.color[3] = color[3]
    glow2_style.color[4] = color[4]

    glow_widget.dirty = true
    if self.set_dirty then
        self:set_dirty()
    end
end

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


local function get_icon_path(detected_status, icon_style)
    if icon_style == "plain" or icon_style == "plain_slot_color" then
        return Status.icons[detected_status]
    else
        return Status.icons_glowing[detected_status] or Status.icons[detected_status]
    end
end

local function get_status_color(detected_status, icon_style, player)
    local is_plain_only = (Status.icons_glowing[detected_status] == Status.icons[detected_status])

    if icon_style == "plain" or (icon_style == "glowing" and is_plain_only) then
        local color = mod:get(detected_status .. "_color")
        return color or { 255, 255, 255, 255 }
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

local function setup_texture_style(texture_style, icon_size, offset_x, offset_y)
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
    texture_style.offset[1] = offset_x or 0
    texture_style.offset[2] = offset_y or 0

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

    local texture_style = player_icon_widget.style.texture
    if texture_style then
        if not enable_background_tint then
            if texture_style.material_values then
                texture_style.material_values.desaturation = 0
                texture_style.material_values.intensity = 1
            end
        else
            apply_shadow_to_pass(texture_style, should_shadow)
        end
    end

    local profile_style = player_icon_widget.style.profile
    if profile_style then
        if not enable_background_tint then
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
            apply_shadow_to_pass(profile_style, should_shadow)

            if should_shadow then
                if not profile_style.color then
                    profile_style.color = { 255, 255, 255, 255 }
                end
                profile_style.color[1] = 255
                profile_style.color[2] = 64
                profile_style.color[3] = 64
                profile_style.color[4] = 64
            else
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

    local player_manager = Managers.player
    if player_manager then
        local unique_id = player:unique_id()
        local all_players = player_manager:players()
        if not all_players or not all_players[unique_id] then
            return nil
        end
    end

    if player.player_unit then
        return nil
    end

    if not (is_dead or show_as_dead) then
        return nil
    end

    local game_mode_manager = Managers.state and Managers.state.game_mode
    if game_mode_manager then
        local can_spawn = game_mode_manager.can_spawn_player and game_mode_manager:can_spawn_player(player)
        if can_spawn then
            return "respawning"
        end

        local time_until_spawn = game_mode_manager.player_time_until_spawn and game_mode_manager:player_time_until_spawn(player)
        if time_until_spawn then
            return "respawning"
        end

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
    
    local icon_path = get_icon_path(detected_status, icon_style)
    
    local status_color = nil
    if icon_path then
        status_color = get_status_color(detected_status, icon_style, player)
    end
    
    if not icon_path then
        icon_style = "plain"
        icon_path = get_icon_path(detected_status, icon_style)
        status_color = get_status_color(detected_status, icon_style, player)
    end

    return status_icon, status_color
end

mod:hook("HudElementPlayerPanelBase", "_set_status_icon", function(func, self, status_icon, status_color, ui_renderer)
    local player = self._player or (self._data and self._data.player)

    if not is_panel_indicators_enabled(self, player) then
        local widgets_by_name = self._widgets_by_name
        local widget = widgets_by_name and widgets_by_name.status_icon
        if widget then
            widget.content.texture = nil
            widget.visible = false
            widget.dirty = true
            if self._set_widget_visible then
                self:_set_widget_visible(widget, false, ui_renderer)
            end
        end
        local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
        if player_icon_widget then
            apply_widget_shadow(player_icon_widget, false)
        end
        return
    end

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

    local icon_path = get_icon_path(detected_status, icon_style)
    if not icon_path then
        icon_style = "plain"
        icon_path = get_icon_path(detected_status, icon_style)
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
        local is_personal = is_personal_panel(self, player)
        local base_size = is_personal and ICON_SIZE_PERSONAL or ICON_SIZE_TEAM
        local needs_size_boost = detected_status == "luggable" or detected_status == "healing" or detected_status == "helping" or detected_status == "interacting"
        if (detected_status == "dead" or detected_status == "respawning" or detected_status == "hogtied") and (icon_style == "plain" or icon_style == "plain_slot_color") then
            needs_size_boost = true
        end
        local icon_size = needs_size_boost and (base_size + ICON_SIZE_OFFSET) or base_size
        if detected_status == "interacting" then
            icon_size = icon_size + 10
        end
        local offset_x, offset_y = get_panel_offsets(self, player)
        setup_texture_style(texture_style, icon_size, offset_x, offset_y)

        local color = get_status_color(detected_status, icon_style, player)
        apply_color_to_texture(texture_style, color)
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

    local widgets_by_name = self._widgets_by_name
    local widget = widgets_by_name and widgets_by_name.status_icon
    if not widget then
        return
    end

    if not is_panel_indicators_enabled(self, player) then
        widget.content.texture = nil
        widget.visible = false
        widget.dirty = true
        if self._set_widget_visible then
            self:_set_widget_visible(widget, false)
        end
        local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
        if player_icon_widget then
            apply_widget_shadow(player_icon_widget, false)
        end
        if self.set_dirty then
            self:set_dirty()
        end
        return
    end

    local unit = player and player.player_unit

    local detected_status = nil
    if unit then
        detected_status = Status.for_unit(unit)
    elseif self._dead or self._show_as_dead then
        detected_status = detect_death_or_respawn_status(player, self._dead, self._show_as_dead)
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

    local icon_path = get_icon_path(detected_status, icon_style)
    if not icon_path then
        icon_style = "plain"
        icon_path = get_icon_path(detected_status, icon_style)
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
        local is_personal = is_personal_panel(self, player)
        local base_size = is_personal and ICON_SIZE_PERSONAL or ICON_SIZE_TEAM
        local needs_size_boost = detected_status == "luggable" or detected_status == "healing" or detected_status == "helping" or detected_status == "interacting"
        if (detected_status == "dead" or detected_status == "respawning" or detected_status == "hogtied") and (icon_style == "plain" or icon_style == "plain_slot_color") then
            needs_size_boost = true
        end
        local icon_size = needs_size_boost and (base_size + ICON_SIZE_OFFSET) or base_size
        if detected_status == "interacting" then
            icon_size = icon_size + 10
        end
        local offset_x, offset_y = get_panel_offsets(self, player)
        setup_texture_style(texture_style, icon_size, offset_x, offset_y)

        local color = get_status_color(detected_status, icon_style, player)
        apply_color_to_texture(texture_style, color)
    end

    widget.visible = true
    widget.dirty = true
    if self._set_widget_visible then
        self:_set_widget_visible(widget, true)
    end

    local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
    if player_icon_widget then
        apply_widget_shadow(player_icon_widget, true)
    end
    if self.set_dirty then
        self:set_dirty()
    end

    if detected_status == "auspex" or detected_status == "luggable" or
       detected_status == "healing" or detected_status == "helping" or detected_status == "interacting" then
        if icon_path then
            local status_color = get_status_color(detected_status, icon_style, player)
            self:_set_status_icon(icon_path, status_color, nil)
        end
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
    _sync_panel_player(self, player)
    func(self, dt, t, player, ui_renderer)

    if self._dead or self._show_as_dead then
        update_status_icon_widget(self, player)
    end
end)

mod:hook("HudElementPersonalPlayerPanel", "_update_player_features", function(func, self, dt, t, player, ui_renderer)
    _sync_panel_player(self, player)
    func(self, dt, t, player, ui_renderer)
    update_status_icon_widget(self, player)
    apply_aggro_glow(self, player)
end)

mod:hook("HudElementTeamPlayerPanel", "_update_player_features", function(func, self, dt, t, player, ui_renderer)
    _sync_panel_player(self, player)
    func(self, dt, t, player, ui_renderer)
    update_status_icon_widget(self, player)
    apply_aggro_glow(self, player)
end)

mod:hook("HudElementPlayerPanelBase", "_set_shadowing_portrait", function(func, self, should_shadow)
    local player = self._player or (self._data and self._data.player)
    if not is_panel_indicators_enabled(self, player) then
        func(self, false)
        local widgets_by_name = self._widgets_by_name
        local player_icon_widget = widgets_by_name and widgets_by_name.player_icon
        if player_icon_widget then
            apply_widget_shadow(player_icon_widget, false)
        end
        return
    end
    func(self, should_shadow)
end)

local function _refresh_panels_in_hud(hud)
    if not hud then return end
    local team_panel_handler = hud:element("HudElementTeamPanelHandler")
    if team_panel_handler and team_panel_handler._player_panels_array then
        for _, panel_data in ipairs(team_panel_handler._player_panels_array) do
            local panel = panel_data.panel
            if panel then
                local player = panel_data.player or panel._player
                update_status_icon_widget(panel, player)
                apply_aggro_glow(panel, player)
                if panel.set_dirty then
                    panel:set_dirty()
                end
            end
        end
        if team_panel_handler.set_dirty then
            team_panel_handler:set_dirty()
        end
    end
end

local function refresh_all_panels()
    local ui_manager = Managers.ui
    if not ui_manager then return end
    _refresh_panels_in_hud(ui_manager._hud)
    _refresh_panels_in_hud(ui_manager._spectator_hud)
end

mod.on_setting_changed = function(setting_id)
    refresh_all_panels()
end

mod.on_settings_changed = mod.on_setting_changed

mod.on_settings_reset = function()
    refresh_all_panels()
end

mod.update = function(dt)
    if mod._game_state_init_timer then
        mod._game_state_init_timer = mod._game_state_init_timer - dt
        if mod._game_state_init_timer <= 0 then
            mod._game_state_init_timer = nil
            refresh_all_panels()
        end
    end

    AggroDetection.scan(dt)
end

local InteractionSettings = require("scripts/settings/interaction/interaction_settings")

mod:hook("InteracteeSystem", "rpc_interaction_started", function(func, self, channel_id, unit_id, is_level_unit, game_object_id)
    func(self, channel_id, unit_id, is_level_unit, game_object_id)

    local interactor_unit = Managers.state.unit_spawner:unit(game_object_id)
    local interactee_unit = Managers.state.unit_spawner:unit(unit_id, is_level_unit)

    if interactor_unit and interactee_unit then
        local extension = self._unit_to_extension_map[interactee_unit]
        if extension then
            local interaction_type = extension._active_interaction_type
            if not interaction_type or interaction_type == "none" then
                interaction_type = extension:interaction_type()
            end

            if interaction_type and interaction_type ~= "none" then
                if not mod._interaction_active_units[interactor_unit] then
                    mod._interaction_active_units[interactor_unit] = {}
                end
                mod._interaction_active_units[interactor_unit].type = interaction_type
                mod._interaction_active_units[interactor_unit].interactee_unit = interactee_unit
            end
        end
    end
end)

mod:hook("InteracteeSystem", "rpc_interaction_stopped", function(func, self, channel_id, unit_id, is_level_unit, interactor_game_object_id, result)
    func(self, channel_id, unit_id, is_level_unit, interactor_game_object_id, result)

    local interactee_unit = Managers.state.unit_spawner:unit(unit_id, is_level_unit)
    if interactee_unit then
        local extension = self._unit_to_extension_map[interactee_unit]

        local interactor_unit = interactor_game_object_id and interactor_game_object_id ~= NetworkConstants.invalid_game_object_id and interactor_game_object_id ~= -1 and Managers.state.unit_spawner:unit(interactor_game_object_id)

        if not interactor_unit and extension then
            interactor_unit = extension._interactor_unit

            if not interactor_unit then
                local uds = ScriptUnit.has_extension(interactee_unit, "unit_data_system") and ScriptUnit.extension(interactee_unit, "unit_data_system")
                if type(uds) == "table" and uds.read_component then
                    local interactee_component = uds:read_component("interactee")
                    if interactee_component then
                        interactor_unit = interactee_component.interactor_unit
                    end
                end
            end

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

mod:hook("InteracteeExtension", "started", function(func, self, interactor_unit)
    func(self, interactor_unit)

    if interactor_unit then
        local interaction_type = self._active_interaction_type
        if not interaction_type or interaction_type == "none" then
            interaction_type = self:interaction_type()
        end

        if interaction_type and interaction_type ~= "none" then
            if not mod._interaction_active_units[interactor_unit] then
                mod._interaction_active_units[interactor_unit] = {}
            end
            mod._interaction_active_units[interactor_unit].type = interaction_type
            mod._interaction_active_units[interactor_unit].interactee_unit = self._unit
        end
    end
end)

mod:hook("InteracteeExtension", "stopped", function(func, self, result, interactor_unit)
    local captured_interactor_unit = interactor_unit or self._interactor_unit

    func(self, result, interactor_unit)

    if captured_interactor_unit and mod._interaction_active_units[captured_interactor_unit] then
        mod._interaction_active_units[captured_interactor_unit] = nil
    end
end)

mod:hook("PlayerInteracteeExtension", "started", function(func, self, interactor_unit)
    func(self, interactor_unit)

    if interactor_unit then
        local interaction_type = self:interaction_type()
        if interaction_type and interaction_type ~= "none" then
            if not mod._interaction_active_units[interactor_unit] then
                mod._interaction_active_units[interactor_unit] = {}
            end
            mod._interaction_active_units[interactor_unit].type = interaction_type
            mod._interaction_active_units[interactor_unit].interactee_unit = self._unit
        end
    end
end)

mod:hook("PlayerInteracteeExtension", "stopped", function(func, self, result, interactor_unit)
    local captured_interactor_unit = interactor_unit or self._interactor_unit

    func(self, result, interactor_unit)

    if captured_interactor_unit and mod._interaction_active_units[captured_interactor_unit] then
        mod._interaction_active_units[captured_interactor_unit] = nil
    end
end)

mod:hook("InteractorExtension", "cancel_interaction", function(func, self, t)
    local interaction_component = self._interaction_component
    local interactor_unit = self._unit
    local target_unit = interaction_component and interaction_component.target_unit

    if interactor_unit and mod._interaction_active_units[interactor_unit] then
        mod._interaction_active_units[interactor_unit] = nil
    end

    func(self, t)
end)

mod:hook("InteractorExtension", "reset_interaction", function(func, self, reset_focus_unit)
    local interaction_component = self._interaction_component
    local interactor_unit = self._unit

    if interactor_unit and mod._interaction_active_units[interactor_unit] then
        mod._interaction_active_units[interactor_unit] = nil
    end

    func(self, reset_focus_unit)
end)

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_player_assistance", function(template)
    local orig_update = template.update_function
    if type(orig_update) == "function" then
        template.update_function = function(parent, ui_renderer, widget, marker, tpl, dt, t)
            local result = orig_update(parent, ui_renderer, widget, marker, tpl, dt, t)
            
            if not widget.bdi_vanilla_cached then
                widget.bdi_vanilla_cached = true
                if widget.content.icon then
                    widget.bdi_vanilla_icon = widget.content.icon
                    widget.bdi_vanilla_icon_color = table.clone(widget.style.icon.color)
                    widget.bdi_vanilla_icon_size = table.clone(widget.style.icon.size)
                    widget.bdi_vanilla_icon_default_size = table.clone(widget.style.icon.default_size)
                elseif widget.content.texture then
                    widget.bdi_vanilla_texture = widget.content.texture
                    widget.bdi_vanilla_texture_color = table.clone(widget.style.texture.color)
                    widget.bdi_vanilla_texture_size = table.clone(widget.style.texture.size)
                    widget.bdi_vanilla_texture_default_size = table.clone(widget.style.texture.default_size)
                end
                widget.bdi_vanilla_pass_alphas = {}
                if widget.style then
                    for pass_id, pass_style in pairs(widget.style) do
                        if pass_id ~= "icon" and pass_id ~= "texture" and pass_id ~= "text" and pass_id ~= "distance" then
                            if pass_style.color then
                                widget.bdi_vanilla_pass_alphas[pass_id] = pass_style.color[1]
                            end
                        end
                    end
                end
            end
            
            if widget.content.icon and widget.bdi_vanilla_icon then
                widget.content.icon = widget.bdi_vanilla_icon
                widget.style.icon.color[1] = widget.bdi_vanilla_icon_color[1]
                widget.style.icon.color[2] = widget.bdi_vanilla_icon_color[2]
                widget.style.icon.color[3] = widget.bdi_vanilla_icon_color[3]
                widget.style.icon.color[4] = widget.bdi_vanilla_icon_color[4]
                widget.style.icon.size[1] = widget.bdi_vanilla_icon_size[1]
                widget.style.icon.size[2] = widget.bdi_vanilla_icon_size[2]
                widget.style.icon.default_size[1] = widget.bdi_vanilla_icon_default_size[1]
                widget.style.icon.default_size[2] = widget.bdi_vanilla_icon_default_size[2]
            elseif widget.content.texture and widget.bdi_vanilla_texture then
                widget.content.texture = widget.bdi_vanilla_texture
                widget.style.texture.color[1] = widget.bdi_vanilla_texture_color[1]
                widget.style.texture.color[2] = widget.bdi_vanilla_texture_color[2]
                widget.style.texture.color[3] = widget.bdi_vanilla_texture_color[3]
                widget.style.texture.color[4] = widget.bdi_vanilla_texture_color[4]
                widget.style.texture.size[1] = widget.bdi_vanilla_texture_size[1]
                widget.style.texture.size[2] = widget.bdi_vanilla_texture_size[2]
                widget.style.texture.default_size[1] = widget.bdi_vanilla_texture_default_size[1]
                widget.style.texture.default_size[2] = widget.bdi_vanilla_texture_default_size[2]
            end
            if widget.style then
                for pass_id, pass_style in pairs(widget.style) do
                    if widget.bdi_vanilla_pass_alphas[pass_id] and pass_style.color then
                        pass_style.color[1] = widget.bdi_vanilla_pass_alphas[pass_id]
                    end
                end
            end
            
            if mod:get("enable_floating_markers") == false then
                return result
            end

            local unit = marker.unit
            if not unit then return result end
            
            local detected_status = Status.for_unit(unit)
            if not detected_status then return result end
            
            local icon_style = mod:get("floating_icon_style") or "glowing"
            local floating_icon_size = mod:get("floating_icon_size") or 65
            
            local icon_path = get_icon_path(detected_status, icon_style)
            
            if icon_path then
                local player = nil
                local player_manager = Managers.player
                if player_manager then
                    player = player_manager:player_by_unit(unit)
                end
                
                local color = get_status_color(detected_status, icon_style, player)
                
                if widget.content.icon then
                    widget.content.icon = icon_path
                    if widget.style.icon then
                        if color then
                            widget.style.icon.color[1] = color[1]
                            widget.style.icon.color[2] = color[2]
                            widget.style.icon.color[3] = color[3]
                            widget.style.icon.color[4] = color[4]
                        end
                        widget.style.icon.size = { floating_icon_size, floating_icon_size }
                        widget.style.icon.default_size = { floating_icon_size, floating_icon_size }
                    end
                elseif widget.content.texture then
                    widget.content.texture = icon_path
                    if widget.style.texture then
                        if color then
                            widget.style.texture.color[1] = color[1]
                            widget.style.texture.color[2] = color[2]
                            widget.style.texture.color[3] = color[3]
                            widget.style.texture.color[4] = color[4]
                        end
                        widget.style.texture.size = { floating_icon_size, floating_icon_size }
                        widget.style.texture.default_size = { floating_icon_size, floating_icon_size }
                    end
                end
                
                if widget.style then
                    for pass_id, pass_style in pairs(widget.style) do
                        if pass_id ~= "icon" and pass_id ~= "texture" and pass_id ~= "text" and pass_id ~= "distance" then
                            if pass_style.color then
                                pass_style.color[1] = 0
                            end
                        end
                    end
                end
            end
            
            return result
        end
    end
end)

mod.on_enabled = function()
    for _, package_path in ipairs(packages_to_load) do
        Managers.package:load(package_path, mod:get_name(), nil, true)
    end
end
