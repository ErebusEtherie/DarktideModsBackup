local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
    name = "spiky",
}

local DOT_SIZE = { 4, 4 }
local LINE_SIZE = { 2, 14 }    -- thickness, length of each chevron arm
local TRI_RADIUS = 22          -- distance from center to each triangle vertex
local ARM_SPREAD = math.pi / 6 -- 30° each side => 60° corner (equilateral triangle)

-- divider_line_01 often needs a small Y bias when using pivot-y = 0.
local TRI_Y_BIAS = math.floor(LINE_SIZE[2] * 0.4 + 0.5) -- ~6 when length=14

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
    local sqrt3_over_2 = math.sqrt(3) * 0.5

    -- Inverted equilateral triangle vertices (screen space), then shift by TRI_Y_BIAS
    local bottom_x = 0
    local bottom_y = TRI_RADIUS + TRI_Y_BIAS

    local tl_x = -TRI_RADIUS * sqrt3_over_2
    local tl_y = -(TRI_RADIUS * 0.5) + TRI_Y_BIAS

    local tr_x = TRI_RADIUS * sqrt3_over_2
    local tr_y = -(TRI_RADIUS * 0.5) + TRI_Y_BIAS

    bottom_x, bottom_y = _round(bottom_x), _round(bottom_y)
    tl_x, tl_y = _round(tl_x), _round(tl_y)
    tr_x, tr_y = _round(tr_x), _round(tr_y)

    local axis_bottom = math.pi
    local axis_tl = (5 * math.pi) / 3
    local axis_tr = math.pi / 3

    local passes = {
        -- Center dot (kept on top)
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

    _add_corner_chevron(passes, "tri_bottom", bottom_x, bottom_y, axis_bottom)
    _add_corner_chevron(passes, "tri_tl", tl_x, tl_y, axis_tl)
    _add_corner_chevron(passes, "tri_tr", tr_x, tr_y, axis_tr)

    -- Standard hit / weakspot hit indicators
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
