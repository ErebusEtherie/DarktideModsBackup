-- File: Targeter/scripts/mods/Targeter/crosshairs/charge_up_ads_triangle_dot.lua
local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {}

-- charge_up_ads sizing / behaviour
local length = 24
local thickness = 56
local size = { length, thickness }
local mask_size = { length, thickness - 4 }
local center_size = { 4, 4 }
local spread_distance = 10
local hit_default_distance = 10
local hit_size = { 14, 4 }

-- triangle_dot visual tuning
local LINE_SIZE = { 2, 14 }
local TRI_RADIUS = 22
local ARM_SPREAD = math.pi / 6
local TRI_Y_BIAS = math.floor(LINE_SIZE[2] * 0.4 + 0.5)

template.name = "charge_up_ads_triangle_dot"
template.size = size
template.hit_size = hit_size
template.center_size = center_size
template.spread_distance = spread_distance
template.hit_default_distance = hit_default_distance

local function _round(x)
    return math.floor(x + 0.5)
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

function template.create_widget_defintion(template, scenegraph_id)
    local center_half_width = center_size[1] * 0.5
    local offset_charge = 120
    local offset_charge_right = { offset_charge + center_half_width, 0, 1 }
    local offset_charge_mask_right = { offset_charge + center_half_width, 0, 2 }
    local offset_charge_left = { -(offset_charge + center_half_width), 0, 1 }
    local offset_charge_mask_left = { -(offset_charge + center_half_width), 0, 2 }

    local passes = {
        {
            pass_type = "texture_uv",
            style_id = "charge_left",
            value = "content/ui/materials/hud/crosshairs/charge_up",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                uvs = {
                    { 1, 0 },
                    { 0, 1 },
                },
                offset = offset_charge_left,
                size = size,
                color = UIHudSettings.color_tint_main_1,
            },
        },
        {
            pass_type = "texture",
            style_id = "charge_right",
            value = "content/ui/materials/hud/crosshairs/charge_up",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                offset = offset_charge_right,
                size = size,
                color = UIHudSettings.color_tint_main_1,
            },
        },
        {
            pass_type = "texture_uv",
            style_id = "charge_mask_left",
            value = "content/ui/materials/hud/crosshairs/charge_up_mask",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                uvs = {
                    { 1, 0 },
                    { 0, 1 },
                },
                offset = offset_charge_mask_left,
                size = mask_size,
                color = UIHudSettings.color_tint_main_1,
            },
        },
        {
            pass_type = "texture_uv",
            style_id = "charge_mask_right",
            value = "content/ui/materials/hud/crosshairs/charge_up_mask",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                uvs = {
                    { 0, 1 },
                    { 1, 0 },
                },
                offset = offset_charge_mask_right,
                size = mask_size,
                color = UIHudSettings.color_tint_main_1,
            },
        },
    }

    local sqrt3_over_2 = math.sqrt(3) * 0.5

    local top_x = 0
    local top_y = -TRI_RADIUS + TRI_Y_BIAS

    local bl_x = -TRI_RADIUS * sqrt3_over_2
    local bl_y = (TRI_RADIUS * 0.5) + TRI_Y_BIAS

    local br_x = TRI_RADIUS * sqrt3_over_2
    local br_y = (TRI_RADIUS * 0.5) + TRI_Y_BIAS

    top_x, top_y = _round(top_x), _round(top_y)
    bl_x, bl_y = _round(bl_x), _round(bl_y)
    br_x, br_y = _round(br_x), _round(br_y)

    local axis_top = 0
    local axis_bl = (2 * math.pi) / 3
    local axis_br = (4 * math.pi) / 3

    _add_corner_chevron(passes, "top", top_x, top_y, axis_top)
    _add_corner_chevron(passes, "bottom_left", bl_x, bl_y, axis_bl)
    _add_corner_chevron(passes, "bottom_right", br_x, br_y, axis_br)

    passes[#passes + 1] = Crosshair.hit_indicator_segment("top_left")
    passes[#passes + 1] = Crosshair.hit_indicator_segment("bottom_left")
    passes[#passes + 1] = Crosshair.hit_indicator_segment("top_right")
    passes[#passes + 1] = Crosshair.hit_indicator_segment("bottom_right")

    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("top_left")
    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("bottom_left")
    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("top_right")
    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("bottom_right")

    passes[#passes + 1] = {
        pass_type = "texture",
        style_id = "center",
        value = "content/ui/materials/hud/crosshairs/center_dot",
        style = {
            horizontal_alignment = "center",
            vertical_alignment = "center",
            offset = { 0, 0, 11 },
            size = center_size,
            color = UIHudSettings.color_tint_main_1,
        },
    }

    return UIWidget.create_definition(passes, scenegraph_id)
end

function template.on_enter(widget, template, data)
    return
end

function template.update_function(parent, ui_renderer, widget, template, crosshair_settings, dt, t, draw_hit_indicator)
    local style = widget.style
    local hit_progress, hit_color, hit_weakspot = parent:hit_indicator()
    local charge_level = parent:_get_current_charge_level() or 0

    local mask_height = mask_size[2]
    local mask_height_charged = mask_height * charge_level
    local mask_height_offset_charged = mask_height * (1 - charge_level) * 0.5

    local charge_mask_right_style = style.charge_mask_right
    charge_mask_right_style.uvs[1][2] = charge_level
    charge_mask_right_style.size[2] = mask_height_charged
    charge_mask_right_style.offset[2] = mask_height_offset_charged

    local charge_mask_left_style = style.charge_mask_left
    charge_mask_left_style.uvs[1][2] = 1 - charge_level
    charge_mask_left_style.size[2] = mask_height_charged
    charge_mask_left_style.offset[2] = mask_height_offset_charged

    Crosshair.update_hit_indicator(style, hit_progress, hit_color, hit_weakspot, draw_hit_indicator)
end

return template
