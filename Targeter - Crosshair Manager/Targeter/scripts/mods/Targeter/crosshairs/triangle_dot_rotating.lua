-- File: Targeter/scripts/mods/Targeter/crosshairs/triangle_dot_rotating.lua
local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
    name = "triangle_dot_rotating",
}

-- Visual geometry
local DOT_SIZE = { 4, 4 }
local LINE_SIZE = { 2, 14 }
local TRI_RADIUS = 22
local ARM_SPREAD = math.pi / 6

-- Darktide's rotated_texture divider_line_01 renders slightly off-center.
-- This bias corrects the visual mass so it centers perfectly on the dot.
local TRI_Y_BIAS = math.floor(LINE_SIZE[2] * 0.4 + 0.5)

-- Spread response
local SPREAD_DISTANCE = 10
local ROTATION_DEADZONE = 8.0
local ROTATION_PER_SPREAD_UNIT = math.rad(6)
local MAX_CLOCKWISE_ROTATION = math.rad(180)

local SQRT3_OVER_2 = math.sqrt(3) * 0.5

local BASE_TOP_X = 0
local BASE_TOP_Y = -TRI_RADIUS

local BASE_BL_X = -TRI_RADIUS * SQRT3_OVER_2
local BASE_BL_Y = TRI_RADIUS * 0.5

local BASE_BR_X = TRI_RADIUS * SQRT3_OVER_2
local BASE_BR_Y = TRI_RADIUS * 0.5

local BASE_AXIS_TOP = 0
local BASE_AXIS_BL = (2 * math.pi) / 3
local BASE_AXIS_BR = (4 * math.pi) / 3

local function _round(x)
    return math.floor(x + 0.5)
end

local function _rotate_point(x, y, angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)

    return
        x * cos_a - y * sin_a,
        x * sin_a + y * cos_a
end

local function _add_arm(passes, style_id, vx, vy, angle)
    passes[#passes + 1] = {
        value = "content/ui/materials/dividers/divider_line_01",
        pass_type = "rotated_texture",
        style_id = style_id,
        style = {
            vertical_alignment = "center",
            horizontal_alignment = "center",
            offset = { vx, vy, 10 },
            size = LINE_SIZE,
            pivot = { LINE_SIZE[1] * 0.5, 0 },
            angle = angle,
            color = UIHudSettings.color_tint_main_1,
        },
    }
end

local function _add_corner_chevron(passes, prefix, vx, vy, axis_angle)
    _add_arm(passes, prefix .. "_arm_1", vx, vy, axis_angle - ARM_SPREAD)
    _add_arm(passes, prefix .. "_arm_2", vx, vy, axis_angle + ARM_SPREAD)
end

local function _set_arm(style, style_id, vx, vy, angle)
    local arm_style = style[style_id]
    arm_style.offset[1] = _round(vx)
    arm_style.offset[2] = _round(vy)
    arm_style.angle = angle
end

local function _set_corner(style, prefix, vx, vy, axis_angle)
    _set_arm(style, prefix .. "_arm_1", vx, vy, axis_angle - ARM_SPREAD)
    _set_arm(style, prefix .. "_arm_2", vx, vy, axis_angle + ARM_SPREAD)
end

function template.create_widget_defintion(template, scenegraph_id)
    -- Apply the bias so it rests perfectly centered on spawn
    local top_x = _round(BASE_TOP_X)
    local top_y = _round(BASE_TOP_Y + TRI_Y_BIAS)

    local bl_x = _round(BASE_BL_X)
    local bl_y = _round(BASE_BL_Y + TRI_Y_BIAS)

    local br_x = _round(BASE_BR_X)
    local br_y = _round(BASE_BR_Y + TRI_Y_BIAS)

    local passes = {
        {
            pass_type = "texture",
            style_id = "center",
            value = "content/ui/materials/hud/crosshairs/center_dot",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                offset = { 0, 0, 11 },
                size = DOT_SIZE,
                color = UIHudSettings.color_tint_main_1,
            },
        },
        Crosshair.hit_indicator_segment("top_left"),
        Crosshair.hit_indicator_segment("bottom_left"),
        Crosshair.hit_indicator_segment("top_right"),
        Crosshair.hit_indicator_segment("bottom_right"),
        Crosshair.weakspot_hit_indicator_segment("top_left"),
        Crosshair.weakspot_hit_indicator_segment("bottom_left"),
        Crosshair.weakspot_hit_indicator_segment("top_right"),
        Crosshair.weakspot_hit_indicator_segment("bottom_right"),
    }

    _add_corner_chevron(passes, "top", top_x, top_y, BASE_AXIS_TOP)
    _add_corner_chevron(passes, "bottom_left", bl_x, bl_y, BASE_AXIS_BL)
    _add_corner_chevron(passes, "bottom_right", br_x, br_y, BASE_AXIS_BR)

    return UIWidget.create_definition(passes, scenegraph_id)
end

function template.on_enter(widget, template, data)
    return
end

function template.update_function(parent, ui_renderer, widget, template, crosshair_settings, dt, t, draw_hit_indicator)
    local style = widget.style
    local hit_progress, hit_color, hit_weakspot = parent:hit_indicator()
    local yaw, pitch = parent:_spread_yaw_pitch(dt)

    local rotation_angle = 0

    if yaw and pitch then
        local scalar = SPREAD_DISTANCE * (crosshair_settings.spread_scalar or 1)
        local spread_offset_x = math.abs(yaw * scalar)
        local spread_offset_y = math.abs(pitch * scalar)

        -- Use the stronger axis, like the visible edge movement in spread templates.
        local spread_amount = math.max(spread_offset_x, spread_offset_y)

        -- Ignore tiny ADS settling changes, but respond once bloom becomes meaningful.
        local effective_spread = math.max(spread_amount - ROTATION_DEADZONE, 0)

        -- Positive angle orbits clockwise in screen-space
        rotation_angle = math.min(effective_spread * ROTATION_PER_SPREAD_UNIT, MAX_CLOCKWISE_ROTATION)
    end

    local top_x, top_y = _rotate_point(BASE_TOP_X, BASE_TOP_Y, rotation_angle)
    local bl_x, bl_y = _rotate_point(BASE_BL_X, BASE_BL_Y, rotation_angle)
    local br_x, br_y = _rotate_point(BASE_BR_X, BASE_BR_Y, rotation_angle)

    -- Apply the rendering bias AFTER rotation to re-center the visual mass on the dot
    top_y = top_y + TRI_Y_BIAS
    bl_y = bl_y + TRI_Y_BIAS
    br_y = br_y + TRI_Y_BIAS

    -- Subtract rotation_angle because Darktide UI texture rotation is Counter-Clockwise
    _set_corner(style, "top", top_x, top_y, BASE_AXIS_TOP - rotation_angle)
    _set_corner(style, "bottom_left", bl_x, bl_y, BASE_AXIS_BL - rotation_angle)
    _set_corner(style, "bottom_right", br_x, br_y, BASE_AXIS_BR - rotation_angle)

    Crosshair.update_hit_indicator(style, hit_progress, hit_color, hit_weakspot, draw_hit_indicator)
end

return template
