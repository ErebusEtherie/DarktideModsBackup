-- File: weapon_action_details/scripts/mods/weapon_action_details/ui/wad_ui_tooltips.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")
local UIResolution = mod:original_require("scripts/managers/ui/ui_resolution")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local Localize = Localize

local ACTION_ICON_SIZE = mod.ACTION_ICON_SIZE
local ACTION_ICON_X = mod.ACTION_ICON_X
local ACTION_ICON_Y = mod.ACTION_ICON_Y

local ACTION_TOOLTIP_TARGET_COUNT = mod.WAD_ACTION_TOOLTIP_GRID_TARGET_COUNT or 5
local ACTION_TOOLTIP_ARMOR_ROW_COUNT = 6
local ACTION_TOOLTIP_PADDING = 12
local ACTION_TOOLTIP_GAP = 12
local ACTION_TOOLTIP_WIDTH = 640
local ACTION_TOOLTIP_LEGEND_HEIGHT = 24
local ACTION_TOOLTIP_HEADER_HEIGHT = 26
local ACTION_TOOLTIP_ROW_HEIGHT = 44
local ACTION_TOOLTIP_ARMOR_COLUMN_WIDTH = 150
local ACTION_TOOLTIP_CELL_WIDTH = 92
local ACTION_TOOLTIP_HEIGHT = ACTION_TOOLTIP_PADDING * 2 + ACTION_TOOLTIP_LEGEND_HEIGHT +
    ACTION_TOOLTIP_HEADER_HEIGHT + ACTION_TOOLTIP_ARMOR_ROW_COUNT * ACTION_TOOLTIP_ROW_HEIGHT
local ACTION_TOOLTIP_COLUMN_HEADER_Y = ACTION_TOOLTIP_PADDING + ACTION_TOOLTIP_LEGEND_HEIGHT
local ACTION_TOOLTIP_FIRST_ROW_Y = ACTION_TOOLTIP_COLUMN_HEADER_Y + ACTION_TOOLTIP_HEADER_HEIGHT
local ACTION_TOOLTIP_ARMOR_COLUMN_X = ACTION_TOOLTIP_PADDING
local ACTION_TOOLTIP_FIRST_TARGET_X = ACTION_TOOLTIP_ARMOR_COLUMN_X + ACTION_TOOLTIP_ARMOR_COLUMN_WIDTH

local function action_tooltip_visible(content)
    return content.visible == true
end

local function tooltip_text_style(x, y, width, height, font_size, text_color, rich_text, horizontal_alignment)
    local style = table.clone(UIFontSettings.body_small)

    style.font_size = font_size
    style.text_horizontal_alignment = horizontal_alignment or "center"
    style.text_vertical_alignment = "center"
    style.text_color = text_color
    style.rich_text = rich_text
    style.offset = {
        x,
        y,
        5,
    }
    style.size = {
        width,
        height,
    }

    return style
end

local function tooltip_cell_background_pass(x, y, width, height)
    return {
        pass_type = "rect",
        style = {
            color = Color.black(120, true),
            size = {
                width - 2,
                height - 2,
            },
            offset = {
                x + 1,
                y + 1,
                2,
            },
        },
        visibility_function = action_tooltip_visible,
    }
end

local function tooltip_text_pass(style_id, value_id, style)
    return {
        pass_type = "text",
        style_id = style_id,
        value = "",
        value_id = value_id,
        style = style,
        visibility_function = action_tooltip_visible,
    }
end

local function tooltip_target_column_x(target_index)
    return ACTION_TOOLTIP_FIRST_TARGET_X + (target_index - 1) * ACTION_TOOLTIP_CELL_WIDTH
end

local function tooltip_armor_row_y(row_index)
    return ACTION_TOOLTIP_FIRST_ROW_Y + (row_index - 1) * ACTION_TOOLTIP_ROW_HEIGHT
end

local function add_action_tooltip_passes(pass_template)
    pass_template[#pass_template + 1] = {
        pass_type = "rect",
        style = {
            color = Color.terminal_grid_background(245, true),
            size = {
                ACTION_TOOLTIP_WIDTH,
                ACTION_TOOLTIP_HEIGHT,
            },
            offset = {
                0,
                0,
                0,
            },
        },
        visibility_function = action_tooltip_visible,
    }

    pass_template[#pass_template + 1] = {
        pass_type = "texture",
        value = "content/ui/materials/frames/frame_tile_2px",
        style = {
            scale_to_material = true,
            color = Color.terminal_frame(255, true),
            size = {
                ACTION_TOOLTIP_WIDTH,
                ACTION_TOOLTIP_HEIGHT,
            },
            offset = {
                0,
                0,
                4,
            },
        },
        visibility_function = action_tooltip_visible,
    }

    pass_template[#pass_template + 1] = tooltip_text_pass("tooltip_legend", "tooltip_legend",
        tooltip_text_style(ACTION_TOOLTIP_PADDING, ACTION_TOOLTIP_PADDING,
            ACTION_TOOLTIP_WIDTH - ACTION_TOOLTIP_PADDING * 2, ACTION_TOOLTIP_LEGEND_HEIGHT, 16,
            Color.terminal_text_body(255, true), true, "left"))

    pass_template[#pass_template + 1] = tooltip_cell_background_pass(ACTION_TOOLTIP_ARMOR_COLUMN_X,
        ACTION_TOOLTIP_COLUMN_HEADER_Y, ACTION_TOOLTIP_ARMOR_COLUMN_WIDTH, ACTION_TOOLTIP_HEADER_HEIGHT)

    pass_template[#pass_template + 1] = tooltip_text_pass("tooltip_armor_header", "tooltip_armor_header",
        tooltip_text_style(ACTION_TOOLTIP_ARMOR_COLUMN_X + 6, ACTION_TOOLTIP_COLUMN_HEADER_Y,
            ACTION_TOOLTIP_ARMOR_COLUMN_WIDTH - 12, ACTION_TOOLTIP_HEADER_HEIGHT, 15,
            Color.terminal_text_header(255, true), false, "left"))

    for target_index = 1, ACTION_TOOLTIP_TARGET_COUNT do
        local x = tooltip_target_column_x(target_index)
        local value_id = "tooltip_column_" .. target_index

        pass_template[#pass_template + 1] = tooltip_cell_background_pass(x, ACTION_TOOLTIP_COLUMN_HEADER_Y,
            ACTION_TOOLTIP_CELL_WIDTH, ACTION_TOOLTIP_HEADER_HEIGHT)
        pass_template[#pass_template + 1] = tooltip_text_pass(value_id, value_id,
            tooltip_text_style(x, ACTION_TOOLTIP_COLUMN_HEADER_Y, ACTION_TOOLTIP_CELL_WIDTH,
                ACTION_TOOLTIP_HEADER_HEIGHT, 15, Color.terminal_text_header(255, true), false))
    end

    for row_index = 1, ACTION_TOOLTIP_ARMOR_ROW_COUNT do
        local y = tooltip_armor_row_y(row_index)
        local armor_value_id = "tooltip_armor_" .. row_index

        pass_template[#pass_template + 1] = tooltip_cell_background_pass(ACTION_TOOLTIP_ARMOR_COLUMN_X, y,
            ACTION_TOOLTIP_ARMOR_COLUMN_WIDTH, ACTION_TOOLTIP_ROW_HEIGHT)
        pass_template[#pass_template + 1] = tooltip_text_pass(armor_value_id, armor_value_id,
            tooltip_text_style(ACTION_TOOLTIP_ARMOR_COLUMN_X + 6, y, ACTION_TOOLTIP_ARMOR_COLUMN_WIDTH - 12,
                ACTION_TOOLTIP_ROW_HEIGHT, 14, Color.terminal_text_body(255, true), false, "left"))

        for target_index = 1, ACTION_TOOLTIP_TARGET_COUNT do
            local x = tooltip_target_column_x(target_index)
            local cell_value_id = "tooltip_cell_" .. row_index .. "_" .. target_index

            pass_template[#pass_template + 1] = tooltip_cell_background_pass(x, y, ACTION_TOOLTIP_CELL_WIDTH,
                ACTION_TOOLTIP_ROW_HEIGHT)
            pass_template[#pass_template + 1] = tooltip_text_pass(cell_value_id, cell_value_id,
                tooltip_text_style(x, y, ACTION_TOOLTIP_CELL_WIDTH, ACTION_TOOLTIP_ROW_HEIGHT, 12,
                    Color.terminal_text_body(255, true), true))
        end
    end
end

local function set_action_tooltip_content(content, tooltip_grid)
    content.tooltip_grid = tooltip_grid
    content.tooltip_legend = tooltip_grid and tooltip_grid.legend_text or ""
    content.tooltip_armor_header = tooltip_grid and tooltip_grid.target_header_text or
        Localize(mod.WAD_LOC.STATS_DISPLAY_CLEAVE_TARGETS_STAT)

    local column_headers = tooltip_grid and tooltip_grid.column_headers

    for target_index = 1, ACTION_TOOLTIP_TARGET_COUNT do
        local column_header = column_headers and column_headers[target_index]

        content["tooltip_column_" .. target_index] = column_header and column_header.text or tostring(target_index)
    end

    local armor_rows = tooltip_grid and tooltip_grid.armor_rows

    for row_index = 1, ACTION_TOOLTIP_ARMOR_ROW_COUNT do
        local row = armor_rows and armor_rows[row_index]

        content["tooltip_armor_" .. row_index] = row and row.display_name or ""

        for target_index = 1, ACTION_TOOLTIP_TARGET_COUNT do
            local cell = row and row.cells and row.cells[target_index]

            content["tooltip_cell_" .. row_index .. "_" .. target_index] = cell and cell.text or ""
        end
    end
end

local function create_action_tooltip_definition()
    local pass_template = {}

    add_action_tooltip_passes(pass_template)

    return UIWidget.create_definition(pass_template, "grid_content_pivot", nil, {
        ACTION_TOOLTIP_WIDTH,
        ACTION_TOOLTIP_HEIGHT,
    })
end

local function widget_has_action_tooltip(widget)
    local content = widget and widget.content

    return content and content.tooltip_grid ~= nil
end

local function hovered_action_tooltip_entry_widget(self)
    if self and self.hovered_widget then
        local hovered_widget = self:hovered_widget()

        if widget_has_action_tooltip(hovered_widget) then
            return hovered_widget
        end
    end

    local widgets = self and self._grid_widgets

    if not widgets then
        return nil
    end

    for i = 1, #widgets do
        local widget = widgets[i]
        local content = widget and widget.content
        local hotspot = content and content.icon_hotspot

        if widget_has_action_tooltip(widget) and hotspot and hotspot.is_hover == true then
            return widget
        end
    end

    return nil
end

local function cursor_position(input_service)
    local cursor = input_service and input_service:get("cursor")

    if not cursor then
        return nil
    end

    local inverse_scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale

    return inverse_scale and UIResolution.inverse_scale_vector(cursor, inverse_scale) or cursor
end

local function grid_content_pivot_world_position(self)
    local ui_scenegraph = self and self._ui_scenegraph
    local grid_content_pivot = ui_scenegraph and ui_scenegraph.grid_content_pivot

    return grid_content_pivot and grid_content_pivot.world_position
end

local function cursor_is_over_action_icon(self, widget, input_service)
    if not input_service then
        return true
    end

    local cursor = cursor_position(input_service)
    local grid_content_pivot_position = grid_content_pivot_world_position(self)
    local widget_offset = widget and widget.offset

    if not cursor or not grid_content_pivot_position or not widget_offset then
        return false
    end

    local icon_position = {
        grid_content_pivot_position[1] + (widget_offset[1] or 0) + ACTION_ICON_X,
        grid_content_pivot_position[2] + (widget_offset[2] or 0) + ACTION_ICON_Y,
    }

    return math.point_is_inside_2d_box(cursor, icon_position, {
        ACTION_ICON_SIZE,
        ACTION_ICON_SIZE,
    })
end

function mod.ensure_action_tooltip_widget(self)
    if self._wad_action_tooltip_widget then
        return self._wad_action_tooltip_widget
    end

    local widget = UIWidget.init("wad_action_tooltip", create_action_tooltip_definition())

    widget.content.visible = false
    widget.offset[3] = 200

    self._wad_action_tooltip_widget = widget

    return widget
end

function mod.update_action_tooltip_widget(self, input_service)
    local tooltip_widget = mod.ensure_action_tooltip_widget(self)
    local hovered_widget = hovered_action_tooltip_entry_widget(self)
    local tooltip_content = tooltip_widget.content

    if not hovered_widget or not cursor_is_over_action_icon(self, hovered_widget, input_service) then
        tooltip_content.visible = false
        return tooltip_widget
    end

    local hovered_content = hovered_widget.content
    local hovered_offset = hovered_widget.offset

    set_action_tooltip_content(tooltip_content, hovered_content.tooltip_grid)

    tooltip_content.visible = tooltip_content.tooltip_grid ~= nil
    tooltip_widget.offset[1] = (hovered_offset and hovered_offset[1] or 0) + ACTION_ICON_X -
        ACTION_TOOLTIP_WIDTH - ACTION_TOOLTIP_GAP
    tooltip_widget.offset[2] = (hovered_offset and hovered_offset[2] or 0) + ACTION_ICON_Y
    tooltip_widget.offset[3] = 200

    return tooltip_widget
end

function mod.draw_action_tooltip_widget(self, ui_renderer)
    local widget = self and self._wad_action_tooltip_widget

    if widget and widget.content.visible then
        UIWidget.draw(widget, ui_renderer)
    end
end
