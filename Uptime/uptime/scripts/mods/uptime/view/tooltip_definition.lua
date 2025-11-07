local mod = get_mod("uptime")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local ui_lib = mod:io_dofile("uptime/scripts/mods/uptime/libs/ui")

local tooltip_scene = {
    horizontal_alignment = "left",
    parent = "container",
    vertical_alignment = "top",
    size = {
        400,
        400,
    },
    position = {
        75,
        75,
        330,
    },
}
local tooltip_widget = UIWidget.create_definition({
    {
        pass_type = "rect",
        style = {
            color = {
                220,
                0,
                0,
                0,
            },
        },
    },
    {
        pass_type = "texture",
        style_id = "background",
        value = "content/ui/materials/backgrounds/default_square",
        style = {
            color = Color.terminal_background(nil, true),
        },
    },
    {
        pass_type = "texture",
        style_id = "background_gradient",
        value = "content/ui/materials/gradients/gradient_vertical",
        style = {
            horizontal_alignment = "center",
            vertical_alignment = "center",
            color = Color.terminal_background_gradient(180, true),
            offset = {
                0,
                0,
                1,
            },
        },
    },
    {
        pass_type = "texture",
        style_id = "outer_shadow",
        value = "content/ui/materials/frames/dropshadow_medium",
        style = {
            horizontal_alignment = "center",
            scale_to_material = true,
            vertical_alignment = "center",
            color = Color.black(200, true),
            size_addition = {
                20,
                20,
            },
            offset = {
                0,
                0,
                3,
            },
        },
    },
    {
        pass_type = "texture",
        style_id = "frame",
        value = "content/ui/materials/frames/frame_tile_2px",
        style = {
            horizontal_alignment = "center",
            vertical_alignment = "center",
            color = Color.terminal_frame(nil, true),
            offset = {
                0,
                0,
                2,
            },
        },
    },
    {
        pass_type = "texture",
        style_id = "corner",
        value = "content/ui/materials/frames/frame_corner_2px",
        style = {
            horizontal_alignment = "center",
            vertical_alignment = "center",
            color = Color.terminal_corner(nil, true),
            offset = {
                0,
                0,
                3,
            },
        },
    },
    {
        pass_type = "text",
        style_id = "title",
        value = "n/a",
        value_id = "title",
        style = {
            font_size = 24,
            font_type = "proxima_nova_bold",
            horizontal_alignment = "center",
            text_horizontal_alignment = "left",
            text_vertical_alignment = "center",
            vertical_alignment = "top",
            text_color = Color.terminal_text_header(255, true),
            color = {
                100,
                255,
                200,
                50,
            },
            size = {
                nil,
                0,
            },
            offset = {
                0,
                0,
                5,
            },
            size_addition = {
                -40,
                0,
            },
        },
    },
    {
        pass_type = "text",
        style_id = "description",
        value = "n/a",
        value_id = "description",
        style = {
            font_size = 20,
            font_type = "proxima_nova_bold",
            horizontal_alignment = "center",
            text_horizontal_alignment = "left",
            text_vertical_alignment = "center",
            vertical_alignment = "top",
            text_color = Color.terminal_text_body(255, true),
            size = {
                nil,
                0,
            },
            offset = {
                0,
                0,
                5,
            },
            color = {
                100,
                100,
                255,
                0,
            },
            size_addition = {
                -40,
                0,
            },
        },
    },
    {
        pass_type = "rect",
        style_id = "requirement_background",
        style = {
            vertical_alignment = "top",
            size = {
                nil,
                0,
            },
            offset = {
                0,
                0,
                1,
            },
            color = {
                150,
                35,
                0,
                0,
            },
        },
    },
    {
        pass_type = "rect",
        style_id = "input_background",
        style = {
            vertical_alignment = "top",
            size = {
                nil,
                0,
            },
            offset = {
                0,
                0,
                1,
            },
            color = {
                100,
                0,
                0,
                0,
            },
        },
    },
}, "tooltip")

local dummy_tooltip_text_size = {
    400,
    20,
}
function resize_tooltip(self, widget, ui_renderer)
    local content = widget.content
    local style = widget.style
    local text_vertical_offset = 14

    local widget_width, _ = self:_scenegraph_size(widget.scenegraph_id, nil)
    local text_size_addition = style.title.size_addition

    dummy_tooltip_text_size[1] = widget_width + text_size_addition[1]

    local title_height = ui_lib.get_text_height(ui_renderer, content.title, style.title, dummy_tooltip_text_size)

    style.title.offset[2] = text_vertical_offset
    style.title.size[2] = title_height
    text_vertical_offset = text_vertical_offset + title_height + 10

    local description_height = get_text_height(ui_renderer, content.description, style.description, dummy_tooltip_text_size)

    style.description.offset[2] = text_vertical_offset
    style.description.size[2] = description_height
    text_vertical_offset = text_vertical_offset + description_height

    text_vertical_offset = text_vertical_offset + 14

    self:_set_scenegraph_size(widget.scenegraph_id, nil, text_vertical_offset, self._ui_overlay_scenegraph)

end

return {
    scene = tooltip_scene,
    widget_definition = tooltip_widget,
    resize_tooltip = resize_tooltip
}