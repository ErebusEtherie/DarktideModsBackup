local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
    name = "circle_dot",
}

local DOT_SIZE = { 4, 4 }

local SEGMENTS = 16
local RING_RADIUS = 18
local SEG_SIZE = { 2, 8 } -- thickness, segment length

local function _round(x)
    return math.floor(x + 0.5)
end

local function _add_ring_segment(passes, idx, x, y, angle)
    passes[#passes + 1] = {
        value = "content/ui/materials/dividers/divider_line_01",
        pass_type = "rotated_texture",
        style_id = string.format("ring_%02d", idx),
        style = {
            vertical_alignment = "center",
            horizontal_alignment = "center",
            offset = { x, y, 10 },
            size = SEG_SIZE,
            -- Center pivot keeps the ring visually centered around the dot
            pivot = { SEG_SIZE[1] * 0.5, SEG_SIZE[2] * 0.5 },
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

    for i = 0, SEGMENTS - 1 do
        local a = (2 * math.pi) * (i / SEGMENTS)
        local x = _round(math.cos(a) * RING_RADIUS)
        local y = _round(math.sin(a) * RING_RADIUS)

        -- Using angle=a makes each segment tangent to the ring (in Darktide’s UI coordinate conventions).
        _add_ring_segment(passes, i + 1, x, y, a)
    end

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
