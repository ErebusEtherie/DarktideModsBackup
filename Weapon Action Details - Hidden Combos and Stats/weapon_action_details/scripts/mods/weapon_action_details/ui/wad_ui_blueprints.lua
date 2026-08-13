-- File: weapon_action_details/scripts/mods/weapon_action_details/ui/wad_ui_blueprints.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")

local has_text = mod.has_text
local newline_count = mod.newline_count
local ACTION_ICON_SIZE = mod.ACTION_ICON_SIZE
local ACTION_ICON_PADDING = mod.ACTION_ICON_PADDING
local ACTION_ICON_X = mod.ACTION_ICON_X
local ACTION_ICON_Y = mod.ACTION_ICON_Y
local ACTION_TEXT_ROW_HEIGHT = mod.ACTION_TEXT_ROW_HEIGHT
local ACTION_NAME_ROW_HEIGHT = mod.ACTION_NAME_ROW_HEIGHT
local ACTION_ENTRY_BOTTOM_PADDING = mod.ACTION_ENTRY_BOTTOM_PADDING
local ACTION_ENTRY_MIN_HEIGHT = mod.ACTION_ENTRY_MIN_HEIGHT

local ARMOR_GRID_MAX_ROWS = 7
local ARMOR_GRID_TOP_SPACING = 8
local ARMOR_GRID_KIND_SPACING = 8
local EFFECT_TABLE_HEADER_HEIGHT = 24
local EFFECT_TABLE_ROW_HEIGHT = 20
local EFFECT_TABLE_TOP_SPACING = 8
local EFFECT_TABLE_KIND_SPACING = 8
local TRAINING_TITLE_ROW_HEIGHT = 40
local TRAINING_TEXT_ROW_HEIGHT = 28
local TRAINING_ENTRY_BOTTOM_PADDING = 14
local TRAINING_ENTRY_MIN_HEIGHT = 82

local function action_damage_row_count(damage_text)
    if not has_text(damage_text) then
        return 0
    end

    return 1 + newline_count(damage_text)
end

local function action_entry_pre_grid_body_row_count(element)
    local rows = 0

    if has_text(element.detail_text) then
        rows = rows + 1
    end

    if has_text(element.chain_text) then
        rows = rows + 2
    end

    return rows + action_damage_row_count(element.damage_text)
end

local function action_armor_grid_row_count(element)
    local armor_grid = element and element.armor_grid

    if type(armor_grid) == "table" and #armor_grid > 0 then
        return math.min(#armor_grid + 1, ARMOR_GRID_MAX_ROWS) -- +1 to fit headers
    end

    return 0
end

local function action_entry_body_row_count(element)
    local rows = action_entry_pre_grid_body_row_count(element) + action_armor_grid_row_count(element)

    if has_text(element.kind_text) then
        rows = rows + 1
    end

    return rows
end

local function action_entry_height(element)
    local armor_grid_row_count = action_armor_grid_row_count(element)
    local height = ACTION_NAME_ROW_HEIGHT + action_entry_body_row_count(element) * ACTION_TEXT_ROW_HEIGHT +
        ACTION_ENTRY_BOTTOM_PADDING

    if armor_grid_row_count > 0 then
        height = height + ARMOR_GRID_TOP_SPACING

        if has_text(element.kind_text) then
            height = height + ARMOR_GRID_KIND_SPACING
        end
    end

    return math.max(ACTION_ENTRY_MIN_HEIGHT, height)
end

local function effect_damage_table_row_count(element)
    local damage_table = element and element.damage_table

    return type(damage_table) == "table" and #damage_table or 0
end

local function effect_armor_grid_row_count(element)
    local armor_grid = element and element.armor_grid

    return type(armor_grid) == "table" and #armor_grid or 0
end

local function effect_table_detail_row_count(element)
    local detail_text = element and element.detail_text

    return has_text(detail_text) and 1 + newline_count(detail_text) or 0
end

local function effect_table_action_entry_height(element)
    local table_rows = math.max(effect_damage_table_row_count(element), effect_armor_grid_row_count(element))
    local detail_rows = effect_table_detail_row_count(element)
    local height = ACTION_NAME_ROW_HEIGHT + detail_rows * ACTION_TEXT_ROW_HEIGHT + EFFECT_TABLE_TOP_SPACING +
        EFFECT_TABLE_HEADER_HEIGHT + table_rows * EFFECT_TABLE_ROW_HEIGHT +
        EFFECT_TABLE_KIND_SPACING + ACTION_TEXT_ROW_HEIGHT + ACTION_ENTRY_BOTTOM_PADDING

    return math.max(ACTION_ENTRY_MIN_HEIGHT, height)
end

local function training_entry_body_row_count(element)
    if not has_text(element.body_text) then
        return 0
    end

    local text_row_count = 1 + newline_count(element.body_text)
    local declared_row_count = type(element.row_count) == "number" and element.row_count or 0

    return math.max(text_row_count, declared_row_count)
end

local function training_entry_height(element)
    local height = TRAINING_TITLE_ROW_HEIGHT +
        training_entry_body_row_count(element) * TRAINING_TEXT_ROW_HEIGHT +
        TRAINING_ENTRY_BOTTOM_PADDING

    return math.max(TRAINING_ENTRY_MIN_HEIGHT, height)
end


function mod.add_weapon_action_details_blueprints(blueprints, grid_size)
    local grid_width = grid_size[1]
    local body_text_style = table.clone(UIFontSettings.body)
    local small_text_style = table.clone(UIFontSettings.body_small)
    local header_text_style = table.clone(UIFontSettings.header_3)
    local action_name_text_style = table.clone(UIFontSettings.body)
    local action_body_text_style = table.clone(UIFontSettings.body_small)
    local action_legend_text_style = table.clone(UIFontSettings.body_small)
    local training_title_text_style = table.clone(UIFontSettings.body)
    local training_body_text_style = table.clone(UIFontSettings.body_small)

    body_text_style.text_horizontal_alignment = "left"
    body_text_style.text_vertical_alignment = "center"
    body_text_style.text_color = Color.terminal_text_body(255, true)
    body_text_style.offset = {
        16,
        0,
        6,
    }
    body_text_style.size = {
        grid_width - 32,
        30,
    }

    small_text_style.text_horizontal_alignment = "left"
    small_text_style.text_vertical_alignment = "center"
    small_text_style.text_color = Color.terminal_text_body_dark(255, true)
    small_text_style.offset = {
        16,
        30,
        6,
    }
    small_text_style.size = {
        grid_width - 32,
        24,
    }

    header_text_style.text_horizontal_alignment = "left"
    header_text_style.text_vertical_alignment = "center"
    header_text_style.text_color = Color.terminal_text_header(255, true)
    header_text_style.offset = {
        16,
        0,
        6,
    }
    header_text_style.size = {
        grid_width - 32,
        40,
    }

    action_name_text_style.text_horizontal_alignment = "left"
    action_name_text_style.text_vertical_alignment = "center"
    action_name_text_style.text_color = Color.terminal_text_body(255, true)
    action_name_text_style.offset = {
        16 + ACTION_ICON_SIZE + ACTION_ICON_PADDING,
        0,
        6,
    }
    action_name_text_style.size = {
        grid_width - 32 - ACTION_ICON_SIZE - ACTION_ICON_PADDING,
        30,
    }

    action_body_text_style.text_horizontal_alignment = "left"
    action_body_text_style.text_vertical_alignment = "top"
    action_body_text_style.text_color = Color.terminal_text_body_dark(255, true)
    action_body_text_style.rich_text = true
    action_body_text_style.offset = {
        16 + ACTION_ICON_SIZE + ACTION_ICON_PADDING,
        ACTION_NAME_ROW_HEIGHT,
        6,
    }
    action_body_text_style.size = {
        grid_width - 32 - ACTION_ICON_SIZE - ACTION_ICON_PADDING,
        ACTION_TEXT_ROW_HEIGHT,
    }

    action_legend_text_style.text_horizontal_alignment = "left"
    action_legend_text_style.text_vertical_alignment = "center"
    action_legend_text_style.text_color = Color.terminal_text_body_dark(255, true)
    action_legend_text_style.rich_text = true
    action_legend_text_style.offset = {
        16,
        0,
        6,
    }
    action_legend_text_style.size = {
        grid_width - 32,
        28,
    }

    training_title_text_style.text_horizontal_alignment = "left"
    training_title_text_style.text_vertical_alignment = "center"
    training_title_text_style.text_color = Color.terminal_text_body(255, true)
    training_title_text_style.offset = {
        16,
        0,
        6,
    }
    training_title_text_style.size = {
        grid_width - 32,
        TRAINING_TITLE_ROW_HEIGHT,
    }

    training_body_text_style.text_horizontal_alignment = "left"
    training_body_text_style.text_vertical_alignment = "top"
    training_body_text_style.text_color = Color.terminal_text_body_dark(255, true)
    training_body_text_style.rich_text = true
    training_body_text_style.offset = {
        16,
        TRAINING_TITLE_ROW_HEIGHT,
        6,
    }
    training_body_text_style.size = {
        grid_width - 32,
        TRAINING_TEXT_ROW_HEIGHT,
    }

    blueprints.wad_actions_header = {
        size = {
            grid_width,
            40,
        },
        pass_template = {
            {
                pass_type = "text",
                style_id = "text",
                value = "",
                value_id = "text",
                style = header_text_style,
            },
        },
        init = function(parent, widget, element)
            widget.content.text = element.text
        end,
    }

    blueprints.wad_actions_legend = {
        size = {
            grid_width,
            28,
        },
        pass_template = {
            {
                pass_type = "text",
                style_id = "text",
                value = "",
                value_id = "text",
                style = action_legend_text_style,
            },
        },
        init = function(parent, widget, element)
            widget.content.text = element.text
        end,
    }

    blueprints.wad_empty_text = {
        size = {
            grid_width,
            60,
        },
        pass_template = {
            {
                pass_type = "text",
                style_id = "text",
                value = "",
                value_id = "text",
                style = body_text_style,
            },
        },
        init = function(parent, widget, element)
            widget.content.text = element.text
        end,
    }

    blueprints.wad_training_entry = {
        size = {
            grid_width,
            TRAINING_ENTRY_MIN_HEIGHT,
        },
        size_function = function(parent, element, ui_renderer)
            return {
                grid_width,
                training_entry_height(element),
            }
        end,
        pass_template = {
            {
                pass_type = "rect",
                style = {
                    color = Color.black(80, true),
                    size_addition = {
                        -8,
                        -4,
                    },
                    offset = {
                        4,
                        2,
                        0,
                    },
                },
            },
            {
                pass_type = "texture",
                style_id = "divider_top",
                value = "content/ui/materials/dividers/divider_line_01",
                style = {
                    vertical_alignment = "top",
                    color = Color.terminal_frame(128, true),
                    size = {
                        grid_width,
                        2,
                    },
                },
                visibility_function = function(content)
                    return content.show_top_divider
                end,
            },
            {
                pass_type = "texture",
                value = "content/ui/materials/dividers/divider_line_01",
                style = {
                    vertical_alignment = "bottom",
                    color = Color.terminal_frame(128, true),
                    size = {
                        grid_width,
                        2,
                    },
                },
            },
            {
                pass_type = "text",
                style_id = "title",
                value = "",
                value_id = "title",
                style = training_title_text_style,
            },
            {
                pass_type = "text",
                style_id = "body",
                value = "",
                value_id = "body",
                style = training_body_text_style,
                visibility_function = function(content)
                    return content.body ~= ""
                end,
            },
        },
        init = function(parent, widget, element)
            local content = widget.content
            local style = widget.style
            local entry_height = training_entry_height(element)

            content.title = element.title or ""
            content.body = element.body_text or ""
            content.show_top_divider = element.show_top_divider
            style.body.size[2] = math.max(
                TRAINING_TEXT_ROW_HEIGHT,
                entry_height - TRAINING_TITLE_ROW_HEIGHT - TRAINING_ENTRY_BOTTOM_PADDING
            )
        end,
    }


    local action_body_x = 16 + ACTION_ICON_SIZE + ACTION_ICON_PADDING
    local action_body_width = grid_width - action_body_x - 16
    local armor_label_column_width = math.floor(action_body_width * 0.20)
    local armor_base_values_column_width = math.floor(action_body_width * 0.20)
    local armor_crit_values_column_width = math.floor(action_body_width * 0.20)
    local armor_details_column_width = action_body_width - armor_label_column_width - armor_base_values_column_width -
        armor_crit_values_column_width

    local armor_label_column_x = action_body_x
    local armor_base_values_column_x = armor_label_column_x + armor_label_column_width
    local armor_crit_values_column_x = armor_base_values_column_x + armor_base_values_column_width
    local armor_details_column_x = armor_crit_values_column_x + armor_crit_values_column_width
    local action_kind_text_style = table.clone(UIFontSettings.body_small)

    action_kind_text_style.text_horizontal_alignment = "left"
    action_kind_text_style.text_vertical_alignment = "center"
    action_kind_text_style.text_color = Color.terminal_text_body_dark(255, true)
    action_kind_text_style.rich_text = true
    action_kind_text_style.offset = {
        action_body_x,
        ACTION_NAME_ROW_HEIGHT,
        6,
    }
    action_kind_text_style.size = {
        action_body_width,
        ACTION_TEXT_ROW_HEIGHT,
    }

    local function armor_grid_row_visibility_function(row_index)
        return function(content)
            return type(content.armor_grid_row_count) == "number" and
                content.armor_grid_row_count >= row_index
        end
    end

    local function armor_grid_text_style(x, width, font_size, text_color, rich_text)
        local style = table.clone(UIFontSettings.body_small)

        style.font_size = font_size
        style.text_horizontal_alignment = "left"
        style.text_vertical_alignment = "center"
        style.text_color = text_color
        style.rich_text = rich_text
        style.offset = {
            x + 6,
            0,
            6,
        }
        style.size = {
            width - 12,
            ACTION_TEXT_ROW_HEIGHT,
        }

        return style
    end

    local function add_armor_grid_cell_passes(pass_template, row_index, column_name, x, width, font_size,
                                              text_color, rich_text)
        local visibility_function = armor_grid_row_visibility_function(row_index)
        local background_style_id = "armor_grid_" .. column_name .. "_background_" .. row_index
        local text_style_id = "armor_grid_" .. column_name .. "_" .. row_index

        pass_template[#pass_template + 1] = {
            pass_type = "rect",
            style_id = background_style_id,
            style = {
                color = Color.black(120, true),
                size = {
                    width - 2,
                    ACTION_TEXT_ROW_HEIGHT - 2,
                },
                offset = {
                    x + 1,
                    1,
                    4,
                },
            },
            visibility_function = visibility_function,
        }
        pass_template[#pass_template + 1] = {
            pass_type = "text",
            style_id = text_style_id,
            value = "",
            value_id = text_style_id,
            style = armor_grid_text_style(x, width, font_size, text_color, rich_text),
            visibility_function = visibility_function,
        }
    end

    local action_entry_pass_template = {
        {
            content_id = "hotspot",
            pass_type = "hotspot",
            style_id = "hotspot",
            style = {
                size = {
                    grid_width,
                    ACTION_ENTRY_MIN_HEIGHT,
                },
                offset = {
                    0,
                    0,
                    10,
                },
            },
        },
        {
            pass_type = "rect",
            style = {
                color = Color.black(80, true),
                size_addition = {
                    -8,
                    -4,
                },
                offset = {
                    4,
                    2,
                    0,
                },
            },
        },
        {
            pass_type = "texture",
            style_id = "divider_top",
            value = "content/ui/materials/dividers/divider_line_01",
            style = {
                vertical_alignment = "top",
                color = Color.terminal_frame(128, true),
                size = {
                    grid_width,
                    2,
                },
            },
            visibility_function = function(content)
                return content.show_top_divider
            end,
        },
        {
            pass_type = "texture",
            style_id = "divider",
            value = "content/ui/materials/dividers/divider_line_01",
            style = {
                vertical_alignment = "bottom",
                color = Color.terminal_frame(128, true),
                size = {
                    grid_width,
                    2,
                },
            },
        },
        {
            content_id = "icon_hotspot",
            pass_type = "hotspot",
            style_id = "icon_hotspot",
            style = {
                vertical_alignment = "top",
                size = {
                    ACTION_ICON_SIZE,
                    ACTION_ICON_SIZE,
                },
                offset = {
                    ACTION_ICON_X,
                    ACTION_ICON_Y,
                    20,
                },
            },
        },
        {
            pass_type = "texture",
            style_id = "icon",
            value = nil,
            value_id = "icon",
            style = {
                vertical_alignment = "top",
                size = {
                    ACTION_ICON_SIZE,
                    ACTION_ICON_SIZE,
                },
                offset = {
                    ACTION_ICON_X,
                    ACTION_ICON_Y,
                    6,
                },
                color = Color.terminal_text_body(255, true),
            },
            visibility_function = function(content)
                return content.icon ~= nil
            end,
        },
        {
            pass_type = "text",
            style_id = "name",
            value = "",
            value_id = "name",
            style = action_name_text_style,
        },
        {
            pass_type = "text",
            style_id = "body",
            value = "",
            value_id = "body",
            style = action_body_text_style,
            visibility_function = function(content)
                return content.body ~= ""
            end,
        },
    }

    for row_index = 1, ARMOR_GRID_MAX_ROWS do
        add_armor_grid_cell_passes(action_entry_pass_template, row_index, "label", armor_label_column_x,
            armor_label_column_width, 14, Color.terminal_text_body(255, true), false)
        add_armor_grid_cell_passes(action_entry_pass_template, row_index, "base_values", armor_base_values_column_x,
            armor_base_values_column_width, 14, Color.terminal_text_body_dark(255, true), true)
        add_armor_grid_cell_passes(action_entry_pass_template, row_index, "crit_values", armor_crit_values_column_x,
            armor_crit_values_column_width, 14, Color.terminal_text_body_dark(255, true), true)
        add_armor_grid_cell_passes(action_entry_pass_template, row_index, "details", armor_details_column_x,
            armor_details_column_width, 14, Color.terminal_text_body_dark(255, true), true)
    end

    action_entry_pass_template[#action_entry_pass_template + 1] = {
        pass_type = "text",
        style_id = "kind",
        value = "",
        value_id = "kind",
        style = action_kind_text_style,
        visibility_function = function(content)
            return content.kind ~= ""
        end,
    }

    blueprints.wad_action_entry = {
        size = {
            grid_width,
            ACTION_ENTRY_MIN_HEIGHT,
        },
        size_function = function(parent, element, ui_renderer)
            return {
                grid_width,
                action_entry_height(element),
            }
        end,
        pass_template = action_entry_pass_template,
        init = function(parent, widget, element)
            local content = widget.content
            local style = widget.style
            local body_lines = {}
            local entry_height = action_entry_height(element)
            local pre_grid_body_row_count = action_entry_pre_grid_body_row_count(element)
            local armor_grid_row_count = action_armor_grid_row_count(element)
            local armor_grid_top_spacing = armor_grid_row_count > 0 and ARMOR_GRID_TOP_SPACING or 0
            local armor_grid_kind_spacing = armor_grid_row_count > 0 and has_text(element.kind_text) and
                ARMOR_GRID_KIND_SPACING or 0
            local armor_grid_y = ACTION_NAME_ROW_HEIGHT + pre_grid_body_row_count * ACTION_TEXT_ROW_HEIGHT +
                armor_grid_top_spacing
            local kind_y = armor_grid_y + armor_grid_row_count * ACTION_TEXT_ROW_HEIGHT +
                armor_grid_kind_spacing
            local armor_grid = type(element.armor_grid) == "table" and element.armor_grid or nil

            content.icon = element.icon
            content.name = element.action_name
            content.tooltip_grid = element.tooltip_grid
            content.armor_grid_row_count = armor_grid_row_count
            content.show_top_divider = element.show_top_divider
            content.kind = has_text(element.kind_text) and
                "{#color(40,40,40)}Kind: " .. element.kind_text .. "{#reset()}" or ""

            style.hotspot.size[2] = entry_height
            style.body.size[2] = math.max(
                ACTION_TEXT_ROW_HEIGHT,
                pre_grid_body_row_count * ACTION_TEXT_ROW_HEIGHT
            )
            style.kind.offset[2] = kind_y

            if content.icon_hotspot then
                content.icon_hotspot.disabled = content.icon == nil or content.tooltip_grid == nil
            end

            if has_text(element.detail_text) then
                body_lines[#body_lines + 1] = element.detail_text
            end

            if has_text(element.chain_text) then
                body_lines[#body_lines + 1] = element.chain_text
            end

            if has_text(element.damage_text) then
                body_lines[#body_lines + 1] = element.damage_text
            end

            content.body = table.concat(body_lines, "\n")

            for row_index = 1, ARMOR_GRID_MAX_ROWS do
                local row_y = armor_grid_y + (row_index - 1) * ACTION_TEXT_ROW_HEIGHT

                -- Clear unused rows (since we reuse widgets over scroll)
                local has_row = row_index <= armor_grid_row_count
                if not has_row then
                    content["armor_grid_label_" .. row_index] = ""
                    content["armor_grid_base_values_" .. row_index] = ""
                    content["armor_grid_crit_values_" .. row_index] = ""
                    content["armor_grid_details_" .. row_index] = ""
                end

                style["armor_grid_label_background_" .. row_index].offset[2] = row_y + 1
                style["armor_grid_base_values_background_" .. row_index].offset[2] = row_y + 1
                style["armor_grid_crit_values_background_" .. row_index].offset[2] = row_y + 1
                style["armor_grid_details_background_" .. row_index].offset[2] = row_y + 1

                style["armor_grid_label_" .. row_index].offset[2] = row_y
                style["armor_grid_base_values_" .. row_index].offset[2] = row_y
                style["armor_grid_crit_values_" .. row_index].offset[2] = row_y
                style["armor_grid_details_" .. row_index].offset[2] = row_y
            end

            -- Populate dynamic headers + cell values
            if armor_grid and #armor_grid > 0 then
                local base_header = (mod.wad_damage_hit_zone == mod.WAD_DAMAGE_HIT_ZONE_BODY) and
                    Localize(mod.WAD_LOC.WEAPON_DETAILS_BODY) or Localize(mod.WAD_LOC.WEAPON_DETAILS_WEAKSPOT)
                local crit_header = (mod.wad_damage_hit_zone == mod.WAD_DAMAGE_HIT_ZONE_BODY) and
                    Localize(mod.WAD_LOC.WEAPON_DETAILS_CRIT) or Localize(mod.WAD_LOC.WEAPON_DETAILS_CRIT_HS)

                content["armor_grid_label_1"] = ""
                content["armor_grid_base_values_1"] = "{#color(180,180,180)}" .. base_header .. "{#reset()}"
                content["armor_grid_crit_values_1"] = "{#color(180,180,180)}" .. crit_header .. "{#reset()}"
                content["armor_grid_details_1"] = ""

                for i = 1, #armor_grid do
                    local row_index = i + 1
                    local row = armor_grid[i]

                    content["armor_grid_label_" .. row_index] = row.label or ""
                    content["armor_grid_base_values_" .. row_index] = row.base_values or ""
                    content["armor_grid_crit_values_" .. row_index] = row.crit_values or ""
                    content["armor_grid_details_" .. row_index] = row.details or ""
                end
            end
        end,
    }

    local effect_table_y = ACTION_NAME_ROW_HEIGHT + ACTION_TEXT_ROW_HEIGHT + EFFECT_TABLE_TOP_SPACING
    local effect_table_gap = 12
    local effect_damage_table_width = math.floor((action_body_width - effect_table_gap) * 0.52)
    local effect_armor_grid_width = action_body_width - effect_damage_table_width - effect_table_gap
    local effect_damage_table_x = action_body_x
    local effect_armor_grid_x = effect_damage_table_x + effect_damage_table_width + effect_table_gap
    local effect_stack_column_width = math.floor(effect_damage_table_width * 0.30)
    local effect_damage_column_width = effect_damage_table_width - effect_stack_column_width
    local effect_armor_label_column_width = math.floor(effect_armor_grid_width * 0.64)
    local effect_armor_value_column_width = effect_armor_grid_width - effect_armor_label_column_width
    local effect_detail_text_style = table.clone(action_body_text_style)

    effect_detail_text_style.size = {
        action_body_width,
        ACTION_TEXT_ROW_HEIGHT,
    }

    local function effect_table_text_style(x, width, y, height, horizontal_alignment, rich_text)
        local style = table.clone(UIFontSettings.body_small)

        style.font_size = 14
        style.line_spacing = 1.4
        style.text_horizontal_alignment = horizontal_alignment
        style.text_vertical_alignment = "top"
        style.text_color = Color.terminal_text_body_dark(255, true)
        style.rich_text = rich_text
        style.offset = {
            x + 6,
            y,
            6,
        }
        style.size = {
            width - 12,
            height,
        }

        return style
    end

    local function add_effect_table_column(pass_template, prefix, x, width, horizontal_alignment, rich_text)
        pass_template[#pass_template + 1] = {
            pass_type = "rect",
            style_id = prefix .. "_header_background",
            style = {
                color = Color.black(150, true),
                size = {
                    width - 2,
                    EFFECT_TABLE_HEADER_HEIGHT - 2,
                },
                offset = {
                    x + 1,
                    effect_table_y + 1,
                    4,
                },
            },
        }
        pass_template[#pass_template + 1] = {
            pass_type = "rect",
            style_id = prefix .. "_body_background",
            style = {
                color = Color.black(120, true),
                size = {
                    width - 2,
                    EFFECT_TABLE_ROW_HEIGHT,
                },
                offset = {
                    x + 1,
                    effect_table_y + EFFECT_TABLE_HEADER_HEIGHT + 1,
                    4,
                },
            },
        }
        pass_template[#pass_template + 1] = {
            pass_type = "text",
            style_id = prefix .. "_header",
            value = "",
            value_id = prefix .. "_header",
            style = effect_table_text_style(x, width, effect_table_y, EFFECT_TABLE_HEADER_HEIGHT,
                horizontal_alignment, false),
        }
        pass_template[#pass_template + 1] = {
            pass_type = "text",
            style_id = prefix .. "_body",
            value = "",
            value_id = prefix .. "_body",
            style = effect_table_text_style(x, width, effect_table_y + EFFECT_TABLE_HEADER_HEIGHT,
                EFFECT_TABLE_ROW_HEIGHT, horizontal_alignment, rich_text),
        }
    end

    local effect_action_entry_pass_template = {
        {
            content_id = "hotspot",
            pass_type = "hotspot",
            style_id = "hotspot",
            style = {
                size = {
                    grid_width,
                    ACTION_ENTRY_MIN_HEIGHT,
                },
                offset = {
                    0,
                    0,
                    10,
                },
            },
        },
        {
            pass_type = "rect",
            style = {
                color = Color.black(80, true),
                size_addition = {
                    -8,
                    -4,
                },
                offset = {
                    4,
                    2,
                    0,
                },
            },
        },
        {
            pass_type = "texture",
            style_id = "divider_top",
            value = "content/ui/materials/dividers/divider_line_01",
            style = {
                vertical_alignment = "top",
                color = Color.terminal_frame(128, true),
                size = {
                    grid_width,
                    2,
                },
            },
            visibility_function = function(content)
                return content.show_top_divider
            end,
        },
        {
            pass_type = "texture",
            style_id = "divider",
            value = "content/ui/materials/dividers/divider_line_01",
            style = {
                vertical_alignment = "bottom",
                color = Color.terminal_frame(128, true),
                size = {
                    grid_width,
                    2,
                },
            },
        },
        {
            pass_type = "texture",
            style_id = "icon",
            value = nil,
            value_id = "icon",
            style = {
                vertical_alignment = "top",
                size = {
                    ACTION_ICON_SIZE,
                    ACTION_ICON_SIZE,
                },
                offset = {
                    ACTION_ICON_X,
                    ACTION_ICON_Y,
                    6,
                },
                color = Color.terminal_text_body(255, true),
            },
            visibility_function = function(content)
                return content.icon ~= nil
            end,
        },
        {
            pass_type = "text",
            style_id = "name",
            value = "",
            value_id = "name",
            style = action_name_text_style,
        },
        {
            pass_type = "text",
            style_id = "detail",
            value = "",
            value_id = "detail",
            style = effect_detail_text_style,
        },
    }

    add_effect_table_column(effect_action_entry_pass_template, "effect_stack",
        effect_damage_table_x, effect_stack_column_width, "center", false)
    add_effect_table_column(effect_action_entry_pass_template, "effect_damage",
        effect_damage_table_x + effect_stack_column_width, effect_damage_column_width, "center", true)
    add_effect_table_column(effect_action_entry_pass_template, "effect_armor_label",
        effect_armor_grid_x, effect_armor_label_column_width, "left", false)
    add_effect_table_column(effect_action_entry_pass_template, "effect_armor_value",
        effect_armor_grid_x + effect_armor_label_column_width, effect_armor_value_column_width, "center", true)

    effect_action_entry_pass_template[#effect_action_entry_pass_template + 1] = {
        pass_type = "text",
        style_id = "kind",
        value = "",
        value_id = "kind",
        style = table.clone(action_kind_text_style),
    }

    blueprints.wad_effect_table_action_entry = {
        size = {
            grid_width,
            ACTION_ENTRY_MIN_HEIGHT,
        },
        size_function = function(parent, element, ui_renderer)
            return {
                grid_width,
                effect_table_action_entry_height(element),
            }
        end,
        pass_template = effect_action_entry_pass_template,
        init = function(parent, widget, element)
            local content = widget.content
            local style = widget.style
            local damage_table = type(element.damage_table) == "table" and element.damage_table or {}
            local armor_grid = type(element.armor_grid) == "table" and element.armor_grid or {}
            local damage_row_count = #damage_table
            local armor_row_count = #armor_grid
            local detail_row_count = effect_table_detail_row_count(element)
            local table_y = ACTION_NAME_ROW_HEIGHT + detail_row_count * ACTION_TEXT_ROW_HEIGHT +
                EFFECT_TABLE_TOP_SPACING
            local damage_body_height = damage_row_count * EFFECT_TABLE_ROW_HEIGHT
            local armor_body_height = armor_row_count * EFFECT_TABLE_ROW_HEIGHT
            local kind_y = table_y + EFFECT_TABLE_HEADER_HEIGHT +
                math.max(damage_body_height, armor_body_height) + EFFECT_TABLE_KIND_SPACING
            local stack_lines = {}
            local damage_lines = {}
            local armor_label_lines = {}
            local armor_value_lines = {}

            for i = 1, damage_row_count do
                local row = damage_table[i]

                stack_lines[i] = type(row) == "table" and row.label or ""
                damage_lines[i] = type(row) == "table" and row.value or ""
            end

            for i = 1, armor_row_count do
                local row = armor_grid[i]

                armor_label_lines[i] = type(row) == "table" and row.label or ""
                armor_value_lines[i] = type(row) == "table" and row.base_values or ""
            end

            content.icon = element.icon
            content.name = element.action_name or ""
            content.detail = element.detail_text or ""
            content.show_top_divider = element.show_top_divider
            content.kind = has_text(element.kind_text) and
                "{#color(40,40,40)}Kind: " .. element.kind_text .. "{#reset()}" or ""
            content.effect_stack_header = element.stack_header or ""
            content.effect_damage_header = element.damage_header or ""
            content.effect_armor_label_header = ""
            content.effect_armor_value_header = element.armor_damage_header or ""
            content.effect_stack_body = table.concat(stack_lines, "\n")
            content.effect_damage_body = table.concat(damage_lines, "\n")
            content.effect_armor_label_body = table.concat(armor_label_lines, "\n")
            content.effect_armor_value_body = table.concat(armor_value_lines, "\n")

            style.hotspot.size[2] = effect_table_action_entry_height(element)
            style.detail.size[2] = math.max(ACTION_TEXT_ROW_HEIGHT, detail_row_count * ACTION_TEXT_ROW_HEIGHT)
            style.kind.offset[2] = kind_y

            local table_column_prefixes = {
                "effect_stack",
                "effect_damage",
                "effect_armor_label",
                "effect_armor_value",
            }

            for i = 1, #table_column_prefixes do
                local prefix = table_column_prefixes[i]

                style[prefix .. "_header_background"].offset[2] = table_y + 1
                style[prefix .. "_body_background"].offset[2] = table_y + EFFECT_TABLE_HEADER_HEIGHT + 1
                style[prefix .. "_header"].offset[2] = table_y
                style[prefix .. "_body"].offset[2] = table_y + EFFECT_TABLE_HEADER_HEIGHT
            end

            style.effect_stack_body_background.size[2] = damage_body_height
            style.effect_damage_body_background.size[2] = damage_body_height
            style.effect_stack_body.size[2] = damage_body_height
            style.effect_damage_body.size[2] = damage_body_height
            style.effect_armor_label_body_background.size[2] = armor_body_height
            style.effect_armor_value_body_background.size[2] = armor_body_height
            style.effect_armor_label_body.size[2] = armor_body_height
            style.effect_armor_value_body.size[2] = armor_body_height
        end,
    }
end
