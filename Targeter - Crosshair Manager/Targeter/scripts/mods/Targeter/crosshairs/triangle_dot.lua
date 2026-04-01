-- File: Targeter/scripts/mods/Targeter/crosshairs/triangle_dot.lua
local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
    name = "triangle_dot",
}

-- Visual tuning
local DOT_SIZE = { 4, 4 }
local LINE_SIZE = { 2, 14 }    -- thickness, length of each chevron arm
local TRI_RADIUS = 22          -- distance from center to each triangle vertex
local ARM_SPREAD = math.pi / 6 -- 30° each side => 60° corner (equilateral triangle)

-- divider_line_01 + rotated_texture tends to need a small Y bias (see chevron.lua offsets like y=5/y=8) :contentReference[oaicite:1]{index=1}
local TRI_Y_BIAS = math.floor(LINE_SIZE[2] * 0.4 + 0.5) -- ~6 when LINE_SIZE[2]=14

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
            pivot = { LINE_SIZE[1] * 0.5, 0 }, -- keep "arm starts at pivot" look
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
    -- Equilateral triangle vertex offsets (screen space, centered)
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

    -- (Same angles as before)
    local axis_top = 0
    local axis_bl = (2 * math.pi) / 3
    local axis_br = (4 * math.pi) / 3

    local passes = {
        -- Center dot (known-good centered: offset {0,0}) :contentReference[oaicite:2]{index=2}
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
    }

    _add_corner_chevron(passes, "tri_top", top_x, top_y, axis_top)
    _add_corner_chevron(passes, "tri_bl", bl_x, bl_y, axis_bl)
    _add_corner_chevron(passes, "tri_br", br_x, br_y, axis_br)

    -- Standard hit/weakspot hit indicator segments
    passes[#passes + 1] = Crosshair.hit_indicator_segment("top_left")
    passes[#passes + 1] = Crosshair.hit_indicator_segment("bottom_left")
    passes[#passes + 1] = Crosshair.hit_indicator_segment("top_right")
    passes[#passes + 1] = Crosshair.hit_indicator_segment("bottom_right")

    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("top_left")
    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("bottom_left")
    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("top_right")
    passes[#passes + 1] = Crosshair.weakspot_hit_indicator_segment("bottom_right")

    return UIWidget.create_definition(passes, scenegraph_id)
end

function template.on_enter(widget, template, data)
    return
end

function template.update_function(parent, ui_renderer, widget, template, crosshair_settings, dt, t, draw_hit_indicator)
    local style = widget.style
    local hit_progress, hit_color, hit_weakspot = parent:hit_indicator()

    Crosshair.update_hit_indicator(style, hit_progress, hit_color, hit_weakspot, draw_hit_indicator)
end

return template
