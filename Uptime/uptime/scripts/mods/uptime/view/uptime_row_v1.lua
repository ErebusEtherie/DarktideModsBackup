local mod = get_mod("uptime")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local Definitions = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_view_definitions")
local get_barchart_widget = mod:io_dofile("uptime/scripts/mods/uptime/view/barchart_widget")
local ui_lib = mod:io_dofile("uptime/scripts/mods/uptime/libs/ui")

local ROW_HEIGHT = 40

local is_stackable = function(buff)
    return buff.stackable
end
local default_width = 90
local data_columns = {
    {
        id = "uptime",
        display_name = "loc_uptime_header",
        setting = "show_uptime",
        width = default_width,
        accessor = function(buff)
            return ui_lib.format_seconds(buff.uptime)
        end
    }, {
        id = "uptime_percentage",
        display_name = "loc_uptime_percentage_header",
        setting = "show_uptime_percentage",
        width = default_width,
        accessor = function(buff)
            return string.format("%.1f%%", buff.uptime_percentage)
        end
    }, {
        id = "uptime_combat",
        display_name = "loc_uptime_combat_header",
        setting = "show_uptime_combat",
        width = default_width,
        accessor = function(buff)
            return ui_lib.format_seconds(buff.uptime_combat)
        end
    }, {
        id = "uptime_combat_percentage",
        display_name = "loc_uptime_combat_percentage_header",
        setting = "show_uptime_combat_percentage",
        width = 90,
        accessor = function(buff)
            return string.format("%.1f%%", buff.uptime_combat_percentage)
        end
    }, {
        id = "combat_percentage_per_stack",
        display_name = "loc_combat_percentage_per_stack_header",
        setting = "show_combat_percentage_per_stack",
        width = 400,
        accessor = function(buff, uptime_view)
            return get_barchart_widget(
                    uptime_view,
                    Definitions.row_scene_graph_id,
                    400,
                    ROW_HEIGHT - 8,
                    buff.combat_percentage_per_stack
            )
        end
    }, {
        id = "average_stacks_combat",
        display_name = "loc_avg_stacks_header",
        setting = "show_average_stacks_combat",
        width = default_width,
        condition = is_stackable,
        accessor = function(buff)
            return string.format("%.2f", buff.average_stacks_combat)
        end
    }, {
        id = "combat_time_at_max_stack",
        display_name = "loc_combat_time_at_max_stack_header",
        setting = "show_combat_time_at_max_stack",
        width = default_width,
        condition = is_stackable,
        accessor = function(buff)
            return ui_lib.format_seconds(buff.combat_time_at_max_stack)
        end
    }, {
        id = "combat_percentage_at_max_stack",
        display_name = "loc_percentage_at_max_stacks_header",
        setting = "show_combat_percentage_at_max_stack",
        width = default_width,
        condition = is_stackable,
        accessor = function(buff)
            return string.format("%.1f%%", buff.combat_percentage_at_max_stack)
        end
    },
}

local ICON_PADDING = 2
local ICON_SIZE = ROW_HEIGHT - ICON_PADDING
local row_pass_template = {
    {
        pass_type = "texture",
        style_id = "buff_icon",
        value = "content/ui/materials/icons/buffs/hud/buff_container_with_background",
        style = {
            size = {
                ICON_SIZE,
                ICON_SIZE,
            },
            offset = {
                ICON_PADDING, ICON_PADDING / 2, 0
            },
            material_values = {}
        }
    }, {
        content_id = "hotspot",
        pass_type = "hotspot",
        style = {
            offset = { 0, 0, 100 },
            size = {
                ROW_HEIGHT, ROW_HEIGHT
            }
        }
    }
}

function get_active_columns()
    local active_columns = {}
    for _, column in pairs(data_columns) do
        if mod:get(column.setting) then
            active_columns[#active_columns + 1] = column
        end
    end
    return active_columns
end

function get_width()
    local width = ROW_HEIGHT
    for _, col in pairs(get_active_columns()) do
        width = width + col.width
    end
    return width
end

local colors = {
    row = {
        Color.terminal_text_body(0, true),
        Color.terminal_frame(100, true),
    },
    alternate = {
        Color.terminal_frame(150, true),
        Color.terminal_frame(200, true),
    }
}

function add_columns(pass_template, column_definitions, background_colors, row_height)
    local offset = ICON_SIZE
    local alternate = true
    local padding = 12
    local half_padding = padding / 2
    for _, column in pairs(column_definitions) do
        local template = {
            pass_type = "text",
            value_id = column.id,
            style_id = column.id,
            style = {
                line_spacing = 1.2,
                font_size = 22,
                drop_shadow = true,
                font_type = "machine_medium",
                text_vertical_alignment = "center",
                text_horizontal_alignment = "right",
                size = { column.width - padding, row_height - padding },
                offset = { offset + half_padding, half_padding, 0 },
                text_color = Color.terminal_text_header(255, true),
            },
        }
        local color
        if alternate then
            color = background_colors[1]
        else
            color = background_colors[2]
        end
        local background_template = {
            pass_type = "rect",
            style_id = column.id .. "_background",
            style = {
                offset = { offset, 0, -1 },
                size = { column.width, row_height, -1 },
                color = color,
            },
        }
        pass_template[#pass_template + 1] = background_template
        pass_template[#pass_template + 1] = template

        offset = offset + column.width
        alternate = not alternate
    end
    return pass_template
end

function create_header_row_widget_v1(uptime_view)
    local columns = get_active_columns()
    local template = add_columns(table.clone(row_pass_template), columns, colors.row, ROW_HEIGHT * 2)
    local row_widget_def = UIWidget.create_definition(template, Definitions.row_scene_graph_id)
    local widget = uptime_view:_create_widget("header_row", row_widget_def)

    for _, column in pairs(columns) do
        widget.content[column.id] = mod:localize(column.display_name)
    end
    widget.style.buff_icon.visible = false

    return widget
end

function create_row_widget(uptime_view, buff, index)
    local columns = get_active_columns()

    local row_colors
    if index % 2 == 1 then
        row_colors = colors.row
    else
        row_colors = colors.alternate
    end

    local template = add_columns(table.clone(row_pass_template), columns, row_colors, ROW_HEIGHT)
    local row_widget_def = UIWidget.create_definition(template, Definitions.row_scene_graph_id)

    local widget = uptime_view:_create_widget("row" .. index, row_widget_def)
    widget.buff = buff

    local material = widget.style.buff_icon.material_values or {}
    material.talent_icon = buff.icon
    material.gradient_map = buff.gradient_map
    widget.style.buff_icon.material_values = material

    local top_offset = (index * ROW_HEIGHT)

    local additional_widgets = {}
    local total_width = ICON_SIZE
    for _, column in pairs(columns) do
        widget.content[column.id] = ""
        if not column.condition or column.condition(buff) then
            local value = column.accessor(buff, uptime_view)
            if type(value) == "string" then
                widget.content[column.id] = value
            else
                -- value is a widget
                value.offset = { total_width, top_offset + 4 }
                additional_widgets[#additional_widgets + 1] = value
            end
        end
        total_width = total_width + column.width
    end

    widget.offset[2] = top_offset

    return { widget, unpack(additional_widgets) }
end

local weapon_row_template = {
    {
        pass_type = 'text',
        value_id = "text",
        style = {
            size = { get_width(), ROW_HEIGHT },
            text_vertical_alignment = "center",
            line_spacing = 1.2,
            font_size = 26,
            drop_shadow = true,
            font_type = "machine_medium",
            text_color = Color.terminal_text_header(255, true),
        },
    }
}

function get_weapon_row(uptime_view, weapon_name, weapon_entry, index)
    local widget_def = UIWidget.create_definition(weapon_row_template, Definitions.row_scene_graph_id)
    local widget = uptime_view:_create_widget("weapon_row_" .. weapon_name, widget_def)
    local weapon_combat_uptime = mod.ui.format_seconds(weapon_entry.uptime_combat)
    local weapon_combat_uptime_percentage = string.format("%.1f", weapon_entry.uptime_combat_percentage) .. "%"
    widget.content.text = weapon_name .. " - " .. weapon_combat_uptime .. " (" .. weapon_combat_uptime_percentage .. ")"
    local top_offset = ((index) * ROW_HEIGHT)
    widget.offset[2] = top_offset

    return widget
end

return {
    get_width = get_width,
    row_height = ROW_HEIGHT,
    create_header_row = create_header_row_widget_v1,
    create_row = create_row_widget,
    create_weapon_row = get_weapon_row
}