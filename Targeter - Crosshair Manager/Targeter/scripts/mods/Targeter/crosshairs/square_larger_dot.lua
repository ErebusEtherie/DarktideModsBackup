local Crosshair = require("scripts/ui/utilities/crosshair")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local template = {
    name = "square_larger_dot",
}

local DOT_SIZE = {
    8,
    8,
}

local CORNER_SIZE = {
    18,
    18,
}

local BASE_OFFSET = 18
local SPREAD_DISTANCE = 10
local MIN_OFFSET = BASE_OFFSET

local CORNER_MATERIALS = {
    top_left = "content/ui/materials/frames/mastery_tree/corner_top_left",
    top_right = "content/ui/materials/frames/mastery_tree/corner_top_right",
    bottom_left = "content/ui/materials/frames/mastery_tree/corner_bottom_left",
    bottom_right = "content/ui/materials/frames/mastery_tree/corner_bottom_right",
}

local function _corner_pass(style_id, material, x, y)
    return {
        pass_type = "texture",
        style_id = style_id,
        value = material,
        style = {
            horizontal_alignment = "center",
            vertical_alignment = "center",
            offset = {
                x,
                y,
                10,
            },
            size = {
                CORNER_SIZE[1],
                CORNER_SIZE[2],
            },
            color = UIHudSettings.color_tint_main_1,
        },
    }
end

template.create_widget_defintion = function(template, scenegraph_id)
    return UIWidget.create_definition({
        {
            pass_type = "texture",
            style_id = "center",
            value = "content/ui/materials/hud/crosshairs/center_dot",
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                offset = {
                    0,
                    0,
                    11,
                },
                size = {
                    DOT_SIZE[1],
                    DOT_SIZE[2],
                },
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

        _corner_pass("top_left", CORNER_MATERIALS.top_left, -BASE_OFFSET, -BASE_OFFSET),
        _corner_pass("top_right", CORNER_MATERIALS.top_right, BASE_OFFSET, -BASE_OFFSET),
        _corner_pass("bottom_left", CORNER_MATERIALS.bottom_left, -BASE_OFFSET, BASE_OFFSET),
        _corner_pass("bottom_right", CORNER_MATERIALS.bottom_right, BASE_OFFSET, BASE_OFFSET),
    }, scenegraph_id)
end

template.on_enter = function(widget, template, data)
    return
end

template.update_function = function(parent, ui_renderer, widget, template, crosshair_settings, dt, t, draw_hit_indicator)
    local style = widget.style
    local hit_progress, hit_color, hit_weakspot = parent:hit_indicator()
    local yaw, pitch = parent:_spread_yaw_pitch(dt)

    if yaw and pitch then
        local scalar = SPREAD_DISTANCE * (crosshair_settings.spread_scalar or 1)
        local spread_offset_y = pitch * scalar
        local spread_offset_x = yaw * scalar

        local top_left_style = style.top_left
        top_left_style.offset[1] = math.min(-BASE_OFFSET - spread_offset_x, -MIN_OFFSET)
        top_left_style.offset[2] = math.min(-BASE_OFFSET - spread_offset_y, -MIN_OFFSET)

        local top_right_style = style.top_right
        top_right_style.offset[1] = math.max(BASE_OFFSET + spread_offset_x, MIN_OFFSET)
        top_right_style.offset[2] = math.min(-BASE_OFFSET - spread_offset_y, -MIN_OFFSET)

        local bottom_left_style = style.bottom_left
        bottom_left_style.offset[1] = math.min(-BASE_OFFSET - spread_offset_x, -MIN_OFFSET)
        bottom_left_style.offset[2] = math.max(BASE_OFFSET + spread_offset_y, MIN_OFFSET)

        local bottom_right_style = style.bottom_right
        bottom_right_style.offset[1] = math.max(BASE_OFFSET + spread_offset_x, MIN_OFFSET)
        bottom_right_style.offset[2] = math.max(BASE_OFFSET + spread_offset_y, MIN_OFFSET)
    end

    Crosshair.update_hit_indicator(style, hit_progress, hit_color, hit_weakspot, draw_hit_indicator)
end

return template
