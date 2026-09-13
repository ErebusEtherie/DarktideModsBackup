local mod = get_mod("aggro_indicator")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ScriptCamera = require("scripts/foundation/utilities/script_camera")
local AggroDetection = mod:io_dofile("aggro_indicator/scripts/mods/aggro_indicator/aggro_detection")

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    aggro_indicator_anchor = {
        parent = "screen",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 0, 0 },
        position = { 0, 0, 100 },
    },
}

local widget_definitions = {
    indicator = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/icons/system/escape/settings",
            style_id = "circle_indicator",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                offset = { 0, 0, 0 },
                size = { 10, 10 },
                color = { 0, 255, 255, 255 },
            }
        },
        {
            style_id = "facing_arrow",
            pass_type = "rotated_texture",
            value = "content/ui/materials/buttons/arrow_01",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = { 0, 255, 255, 255 },
                offset = { 0, 0, 4 },
                size = { 18, 18 },
                pivot = { 9, 9 },
                angle = 0
            },
        },
    }, "aggro_indicator_anchor"),
}

local HudElementAggroIndicator = class("HudElementAggroIndicator", "HudElementBase")

HudElementAggroIndicator.init = function(self, parent, draw_layer, start_scale)
    HudElementAggroIndicator.super.init(self, parent, draw_layer, start_scale, {
        widget_definitions = widget_definitions,
        scenegraph_definition = scenegraph_definition
    })
    self._indicator_widget = self._widgets_by_name.indicator
    
    local offset_x = mod:get("indicator_offset_x") or -30
    local offset_y = mod:get("indicator_offset_y") or 0
    local horiz_align = mod:get("indicator_horizontal_alignment") or "center"
    local vert_align = mod:get("indicator_vertical_alignment") or "center"
    
    self:set_scenegraph_position("aggro_indicator_anchor", offset_x, offset_y, 100, horiz_align, vert_align)
end

HudElementAggroIndicator.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    HudElementAggroIndicator.super.update(self, dt, t, ui_renderer, render_settings, input_service)
    
    local is_enabled = mod:get("is_enabled")
    if is_enabled == false then
        self._indicator_widget.style.circle_indicator.color[1] = 0
        self._indicator_widget.style.facing_arrow.color[1] = 0
        return
    end

    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then
        self._indicator_widget.style.circle_indicator.color[1] = 0
        self._indicator_widget.style.facing_arrow.color[1] = 0
        return
    end

    AggroDetection.scan(dt)
    
    local local_player = Managers.player and Managers.player:local_player(1)
    if not local_player or not local_player.player_unit then
        self._indicator_widget.style.circle_indicator.color[1] = 0
        self._indicator_widget.style.facing_arrow.color[1] = 0
        return
    end

    local aggro_type, enemy_unit = AggroDetection.get_aggro_for_unit(local_player.player_unit)
    
    local size = mod:get("indicator_size") or 25
    self._indicator_widget.style.circle_indicator.size[1] = size
    self._indicator_widget.style.circle_indicator.size[2] = size
    
    if aggro_type then
        local color = mod:get("aggro_" .. aggro_type .. "_color") or { 255, 255, 0, 0 }
        local r = color[2] or 255
        local g = color[3] or 0
        local b = color[4] or 0
        
        self._indicator_widget.style.circle_indicator.color[1] = 255
        self._indicator_widget.style.circle_indicator.color[2] = r
        self._indicator_widget.style.circle_indicator.color[3] = g
        self._indicator_widget.style.circle_indicator.color[4] = b
        
        if enemy_unit and Unit.alive(enemy_unit) then
            local camera_manager = Managers.state.camera
            local camera = camera_manager and camera_manager:camera(local_player.viewport_name)
            
            local player_pos = POSITION_LOOKUP[local_player.player_unit] or Unit.local_position(local_player.player_unit, 1)
            local enemy_pos = POSITION_LOOKUP[enemy_unit] or Unit.local_position(enemy_unit, 1)
            
            if camera and player_pos and enemy_pos then
                local diff = enemy_pos - player_pos
                local dir_yaw = math.atan2(Vector3.y(diff), Vector3.x(diff))
                
                local cam_rot = ScriptCamera.rotation(camera)
                local cam_fwd = Quaternion.forward(cam_rot)
                local camera_yaw = math.atan2(Vector3.y(cam_fwd), Vector3.x(cam_fwd))
                
                local angle = -(dir_yaw - camera_yaw)
                
                self._indicator_widget.style.facing_arrow.angle = (math.pi / 2) - angle
                local arrow_size = mod:get("arrow_size") or 18
                self._indicator_widget.style.facing_arrow.size[1] = arrow_size
                self._indicator_widget.style.facing_arrow.size[2] = arrow_size
                self._indicator_widget.style.facing_arrow.pivot[1] = arrow_size / 2
                self._indicator_widget.style.facing_arrow.pivot[2] = arrow_size / 2
                
                local arrow_orbit_dist = mod:get("arrow_orbit_distance") or 5
                local orbit_radius = (size * 0.5) + arrow_orbit_dist
                self._indicator_widget.style.facing_arrow.offset[1] = orbit_radius * math.sin(angle)
                self._indicator_widget.style.facing_arrow.offset[2] = -orbit_radius * math.cos(angle)
                
                local show_arrow = mod:get("show_facing_arrow")
                if show_arrow == nil then show_arrow = true end
                
                if show_arrow then
                    self._indicator_widget.style.facing_arrow.color[1] = 255
                    self._indicator_widget.style.facing_arrow.color[2] = r
                    self._indicator_widget.style.facing_arrow.color[3] = g
                    self._indicator_widget.style.facing_arrow.color[4] = b
                else
                    self._indicator_widget.style.facing_arrow.color[1] = 0
                end
            else
                self._indicator_widget.style.facing_arrow.color[1] = 0
            end
        else
            self._indicator_widget.style.facing_arrow.color[1] = 0
        end
    else
        self._indicator_widget.style.facing_arrow.color[1] = 0
        if mod:get("always_on") then
            self._indicator_widget.style.circle_indicator.color[1] = 128
            self._indicator_widget.style.circle_indicator.color[2] = 128
            self._indicator_widget.style.circle_indicator.color[3] = 128
            self._indicator_widget.style.circle_indicator.color[4] = 128
        else
            self._indicator_widget.style.circle_indicator.color[1] = 0
        end
    end
    
end

return HudElementAggroIndicator
