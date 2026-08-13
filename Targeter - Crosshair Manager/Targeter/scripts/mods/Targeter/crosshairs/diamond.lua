local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
    name = "diamond",
}

local DOT_SIZE = { 4, 4 }

-- Diamond tuning (vertices at top/right/bottom/left)
local VERTEX_RADIUS = 20
local SIDE_LENGTH = math.floor(VERTEX_RADIUS * math.sqrt(2) + 0.5)
local LINE_SIZE = { 2, SIDE_LENGTH } -- thickness, side length

local function _round(x)
    return math.floor(x + 0.5)
end

local function _add_side(passes, style_id, x, y, angle)
    passes[#passes + 1] = {
        value = "content/ui/materials/dividers/divider_line_01",
        pass_type = "rotated_texture",
        style_id = style_id,
        style = {
            vertical_alignment = "center",
            horizontal_alignment = "center",
            offset = { x, y, 10 },
            size = LINE_SIZE,
            pivot = { LINE_SIZE[1] * 0.5, LINE_SIZE[2] * 0.5 },
            angle = angle,
            color = UIHudSettings.color_tint_main_1,
        },
    }
end

function template.create_widget_defintion(template, scenegraph_id)
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

    -- Midpoints of the four sides for a diamond with vertices (0,-r), (r,0), (0,r), (-r,0)
    local m = VERTEX_RADIUS * 0.5

    _add_side(passes, "side_tr", _round(m), _round(-m), math.pi / 4)        -- top -> right
    _add_side(passes, "side_br", _round(m), _round(m), (3 * math.pi) / 4)   -- right -> bottom
    _add_side(passes, "side_bl", _round(-m), _round(m), (5 * math.pi) / 4)  -- bottom -> left
    _add_side(passes, "side_tl", _round(-m), _round(-m), (7 * math.pi) / 4) -- left -> top

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
