local mod = get_mod("improve-yourself")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")
local Color = Color
local VisualConstants = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/views/shared/improve_yourself_visual_constants")
local VictoryVisual = VisualConstants.victory

-- Compact Victory Board geometry. All visual layers derive from these values so
-- resizing the host board cannot leave its background, shadows, or frame behind.
local compact_w = VictoryVisual.width
local compact_h = VictoryVisual.height
local compact_background_w = compact_w - 10
local compact_black_w = compact_w - 28
local compact_black_h = compact_h - 36
local compact_shadow_h = compact_h - 3
local compact_inner_w = compact_w - 20
local compact_inner_h = compact_h - 28
local compact_frame_w = compact_w - 14
local compact_visual_z = VictoryVisual.visual_z
local compact_content_z = VictoryVisual.content_z

local function settings(name, table_data)
    table_data.name = name
    return table_data
end

local scenegraph_definition = {
    screen = {
        scale = "fit",
        size = {1920, 1080},
        position = {0, 0, 0},
    },
}

scenegraph_definition.compact_panel = {
    parent = "screen", vertical_alignment = "center", horizontal_alignment = "center",
    size = {compact_w, compact_h}, position = {0, -40, VictoryVisual.root_z},
}
scenegraph_definition.compact_title = {parent = "compact_panel", size = {220, 62}, position = {38, 24, compact_content_z}}
scenegraph_definition.compact_subtitle = {parent = "compact_panel", size = {220, 24}, position = {38, 82, compact_content_z}}
scenegraph_definition.compact_player_1 = {parent = "compact_panel", size = {180, 72}, position = {270, 36, compact_content_z}}
scenegraph_definition.compact_player_2 = {parent = "compact_panel", size = {180, 72}, position = {455, 36, compact_content_z}}
scenegraph_definition.compact_player_3 = {parent = "compact_panel", size = {180, 72}, position = {640, 36, compact_content_z}}
scenegraph_definition.compact_player_4 = {parent = "compact_panel", size = {180, 72}, position = {825, 36, compact_content_z}}
scenegraph_definition.compact_defense = {parent = "compact_panel", size = {970, 96}, position = {40, 118, compact_content_z}}
scenegraph_definition.compact_defense_prototype = {parent = "compact_panel", size = {970, 200}, position = {40, 138, compact_content_z + 1}}
scenegraph_definition.compact_offense = {parent = "compact_panel", size = {970, 96}, position = {40, 220, compact_content_z}}
scenegraph_definition.compact_offense_prototype = {parent = "compact_panel", size = {970, 200}, position = {40, 350, compact_content_z + 1}}
scenegraph_definition.compact_team = {parent = "compact_panel", size = {970, 90}, position = {40, 562, compact_content_z + 1}}

local title_style = table.clone(UIFontSettings.header_1)
title_style.text_horizontal_alignment = "center"
title_style.text_vertical_alignment = "center"
title_style.font_size = 38

-- Hidden summary widgets calculate goal counts and praise for the visible
-- redesigned Defense and Offense widgets. They are populated but not drawn.
local function summary_definition(scenegraph_id)
    local width = 970
    local bar_x = 210
    local bar_w = 580
    local bar_y = 48
    local bar_h = 25
    local passes = {
        {pass_type = "rect", style_id = "background", style = {color = {225, 12, 24, 24}}},
        {pass_type = "rect", style_id = "divider", style = {offset = {0, 94, 2}, size = {width, 2}, color = {210, 115, 135, 118}}},
        {pass_type = "text", value_id = "text", style_id = "text", value = "", style = {
            offset = {8, 1, 4}, size = {195, 25},
            text_horizontal_alignment = "left", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 20, text_color = Color.terminal_text_header(255, true),
        }},
        {pass_type = "text", value_id = "praise", style_id = "praise", value = "", style = (function()
            -- Clone the main title style so the praise uses the same native
            -- Darktide gold gradient/material treatment rather than flat gold.
            local style = table.clone(title_style)
            style.offset = {8, 34, 5}
            style.size = {195, 53}
            style.text_horizontal_alignment = "left"
            style.text_vertical_alignment = "center"
            style.font_size = 34
            return style
        end)()},
        {pass_type = "rect", style_id = "bar_border", style = {offset = {bar_x - 1, bar_y - 1, 4}, size = {bar_w + 2, bar_h + 2}, color = {210, 70, 92, 78}}},
        {pass_type = "rect", style_id = "bar_background", style = {offset = {bar_x, bar_y, 5}, size = {bar_w, bar_h}, color = {235, 8, 18, 18}}},
        {pass_type = "texture", value = "content/ui/materials/patterns/diagonal_lines_pattern_01", style_id = "warning_zone", style = {
            offset = {bar_x, bar_y, 6}, size = {bar_w, bar_h}, color = {115, 90, 112, 92}, material_values = {speed = 0},
        }},
        {pass_type = "rect", style_id = "goal_marker", style = {offset = {bar_x + math.floor(bar_w * 2 / 3), bar_y + bar_h - 1, 11}, size = {2, 5}, color = {230, 105, 125, 108}}},
        {pass_type = "text", value_id = "goal_label", style_id = "goal_label", value = "GOAL", style = {
            offset = {bar_x + math.floor(bar_w * 2 / 3) - 22, bar_y - 14, 12}, size = {44, 12},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 9, text_color = {230, 105, 125, 108},
        }},
        {pass_type = "text", value_id = "score", style_id = "score", value = "", style = {
            offset = {bar_x + bar_w + 14, bar_y, 13}, size = {width - bar_x - bar_w - 18, bar_h},
            text_horizontal_alignment = "left", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 14, text_color = Color.terminal_text_header(255, true),
        }},
        {pass_type = "text", value_id = "status", style_id = "status", value = "", style = {
            offset = {bar_x, 77, 4}, size = {bar_w, 15},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 11, text_color = Color.terminal_text_body(220, true),
        }},
        {pass_type = "text", value_id = "drivers", style_id = "drivers", value = "", style = {
            offset = {0, 0, 4}, size = {0, 0},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 1, text_color = {0, 0, 0, 0},
        }},
    }
    for i = 1, 8 do
        passes[#passes + 1] = {pass_type = "rect", style_id = "segment_" .. i, style = {
            offset = {bar_x, bar_y, 8}, size = {0, bar_h}, color = {0, 0, 0, 0},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "segment_highlight_" .. i, style = {
            offset = {bar_x, bar_y, 9}, size = {0, 2}, color = {0, 0, 0, 0},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "segment_divider_" .. i, style = {
            offset = {bar_x, bar_y + 1, 10}, size = {0, bar_h - 2}, color = {0, 0, 0, 0},
        }}
        passes[#passes + 1] = {pass_type = "texture", value_id = "segment_icon_" .. i, style_id = "segment_icon_" .. i, value = "content/ui/materials/base/ui_default_base", visibility_function = function(content) return content["segment_icon_visible_" .. i] == true end, style = {
            offset = {bar_x, bar_y, 11}, size = {0, 0}, color = {170, 0, 0, 0},
        }}
        passes[#passes + 1] = {pass_type = "text", value_id = "segment_glyph_" .. i, style_id = "segment_glyph_" .. i, value = "", visibility_function = function(content) return content["segment_glyph_visible_" .. i] == true end, style = {
            offset = {bar_x, bar_y, 11}, size = {0, 0}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = "itc_novarese_bold", font_size = 16, text_color = {170, 0, 0, 0},
        }}
    end
    return UIWidget.create_definition(passes, scenegraph_id)
end

-- Production Victory/History player block: class icon, name, and role label.
local function compact_player_definition(scenegraph_id)
    return UIWidget.create_definition({
        {pass_type = "text", value_id = "icon", style_id = "icon", value = "", style = {
            offset = {0, -2, 3}, size = {180, 24},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 26,
            text_color = Color.white(255, true),
        }},
        {pass_type = "text", value_id = "name", style_id = "name", value = "", style = {
            offset = {4, 20, 3}, size = {172, 24},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 18,
            text_color = Color.white(255, true),
        }},
        {pass_type = "text", value_id = "detail", style_id = "detail", value = "", style = {
            offset = {4, 52, 3}, size = {172, 18},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 12,
            text_color = Color.terminal_text_body(220, true),
        }},
    }, scenegraph_id)
end

local function defense_prototype_definition(scenegraph_id)
    local width, height = 970, 200
    local label_w = 125
    -- Keep the Defense headings fixed while giving the chart content another
    -- 10 px of breathing room beneath them.
    local chart_x, chart_y, chart_w, chart_h = 154, 62, 320, 82
    local bar_w, bar_gap = 42, 34
    local bars_w = bar_w * 4 + bar_gap * 3
    local first_bar_x = chart_x + (chart_w - bars_w) / 2
    local source_x, source_w = 494, 38
    local source_label_w = 79
    local counter_x, counter_w, counter_gap = 617, 108, 7
    local background_color = {238, 5, 22, 20}
    local passes = {
        {pass_type = "rect", style_id = "background", style = {color = background_color}},
        {pass_type = "rect", style_id = "label_background", style = {offset = {0, 0, 2}, size = {label_w, height}, color = {245, 5, 17, 17}}},
        {pass_type = "rect", style_id = "bottom_divider", style = {offset = {0, height - 2, 3}, size = {width, 2}, color = {210, 82, 112, 92}}},
        {pass_type = "text", value_id = "defense_praise", style_id = "defense_praise", value = "", style = (function()
            local style = table.clone(title_style)
            style.offset = {8, 35, 6}
            style.size = {label_w - 16, 30}
            style.text_horizontal_alignment = "center"
            style.text_vertical_alignment = "center"
            style.font_size = 18
            return style
        end)()},
        {pass_type = "text", value = "DEFENSE", style_id = "section_label", style = {
            offset = {12, 66, 5}, size = {label_w - 24, 32}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 22, text_color = Color.white(255, true),
        }},
        {pass_type = "text", value_id = "defense_score", style_id = "defense_score", value = "", style = {
            offset = {8, 104, 6}, size = {label_w - 16, 24}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 14, text_color = Color.terminal_text_header(255, true),
        }},
        {pass_type = "texture", value_id = "damage_icon", style_id = "damage_icon", value = "content/ui/materials/base/ui_default_base",
            visibility_function = function(content) return content.damage_icon_visible == true end,
            style = {offset = {chart_x, 8, 20}, size = {18, 18}, color = Color.white(255, true)}},
        {pass_type = "text", value_id = "damage_glyph", style_id = "damage_glyph", value = "",
            visibility_function = function(content) return content.damage_glyph_visible == true end,
            style = {offset = {chart_x, 6, 20}, size = {18, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
                font_type = "itc_novarese_bold", font_size = 18, text_color = Color.white(255, true)}},
        {pass_type = "text", value = "Damage Taken", style_id = "damage_title", style = {
            offset = {chart_x + 24, 4, 8}, size = {220, 26}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 17, text_color = Color.white(255, true),
        }},
        {pass_type = "rect", style_id = "grid_50", style = {offset = {chart_x, chart_y, 4}, size = {chart_w, 1}, color = {150, 110, 130, 118}}},
        {pass_type = "rect", style_id = "grid_25", style = {offset = {chart_x, chart_y + chart_h / 2, 4}, size = {chart_w, 1}, color = {150, 110, 130, 118}}},
        {pass_type = "rect", style_id = "grid_0", style = {offset = {chart_x, chart_y + chart_h, 4}, size = {chart_w, 1}, color = {200, 82, 112, 92}}},
        {pass_type = "text", value = "50%", style_id = "grid_50_text", style = {
            offset = {chart_x - 38, chart_y - 8, 5}, size = {34, 16}, text_horizontal_alignment = "right", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 10, text_color = {180, 126, 148, 126},
        }},
        {pass_type = "text", value = "25%", style_id = "grid_25_text", style = {
            offset = {chart_x - 38, chart_y + chart_h / 2 - 8, 5}, size = {34, 16}, text_horizontal_alignment = "right", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 10, text_color = {180, 126, 148, 126},
        }},
        {pass_type = "rect", style_id = "source_connector", style = {offset = {0, 0, 12}, size = {0, 2}, color = Color.white(255, true)}},
        {pass_type = "rect", style_id = "source_bracket_top", style = {offset = {0, 0, 12}, size = {0, 2}, color = Color.white(255, true)}},
        {pass_type = "rect", style_id = "source_bracket_right", style = {offset = {0, 0, 12}, size = {2, 0}, color = Color.white(255, true)}},
        {pass_type = "rect", style_id = "source_bracket_bottom", style = {offset = {0, 0, 12}, size = {0, 2}, color = Color.white(255, true)}},
        {pass_type = "rect", style_id = "source_area", style = {offset = {source_x, chart_y + chart_h, 10}, size = {source_w, 0}, color = {230, 177, 189, 181}}},
        {pass_type = "rect", style_id = "source_melee", style = {offset = {source_x, chart_y + chart_h, 10}, size = {source_w, 0}, color = {230, 151, 166, 158}}},
        {pass_type = "rect", style_id = "source_ranged", style = {offset = {source_x, chart_y + chart_h, 10}, size = {source_w, 0}, color = {230, 123, 140, 134}}},
        {pass_type = "rect", style_id = "source_other", style = {offset = {source_x, chart_y + chart_h, 10}, size = {source_w, 0}, color = {230, 95, 113, 108}}},
        {pass_type = "text", value_id = "source_area_value", style_id = "source_area_value", value = "", style = {
            offset = {source_x, chart_y, 14}, size = {source_w, 14}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 9, text_color = {255, 28, 36, 31},
        }},
        {pass_type = "text", value_id = "source_area_label", style_id = "source_area_label", value = "Area of Effect", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 11}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, font_type = UIFontSettings.body.font_type, font_size = 9, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value_id = "source_area_detail", style_id = "source_area_detail", value = "", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 9}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, line_spacing = 1, font_type = UIFontSettings.body.font_type, font_size = 7, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value_id = "source_melee_value", style_id = "source_melee_value", value = "", style = {
            offset = {source_x, chart_y, 14}, size = {source_w, 14}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 9, text_color = {255, 28, 36, 31},
        }},
        {pass_type = "text", value_id = "source_melee_label", style_id = "source_melee_label", value = "Melee Damage", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 11}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, font_type = UIFontSettings.body.font_type, font_size = 9, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value_id = "source_melee_detail", style_id = "source_melee_detail", value = "", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 9}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, line_spacing = 1, font_type = UIFontSettings.body.font_type, font_size = 7, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value_id = "source_ranged_value", style_id = "source_ranged_value", value = "", style = {
            offset = {source_x, chart_y, 14}, size = {source_w, 14}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 9, text_color = {255, 28, 36, 31},
        }},
        {pass_type = "text", value_id = "source_ranged_label", style_id = "source_ranged_label", value = "Ranged Damage", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 11}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, font_type = UIFontSettings.body.font_type, font_size = 9, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value_id = "source_ranged_detail", style_id = "source_ranged_detail", value = "", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 9}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, line_spacing = 1, font_type = UIFontSettings.body.font_type, font_size = 7, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value_id = "source_other_value", style_id = "source_other_value", value = "", style = {
            offset = {source_x, chart_y, 14}, size = {source_w, 14}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 9, text_color = {255, 28, 36, 31},
        }},
        {pass_type = "text", value_id = "source_other_label", style_id = "source_other_label", value = "Other Damage", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 11}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, font_type = UIFontSettings.body.font_type, font_size = 9, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value_id = "source_other_detail", style_id = "source_other_detail", value = "", style = {
            offset = {source_x + source_w + 4, chart_y, 14}, size = {source_label_w, 18}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            word_wrap = false, line_spacing = 1, font_type = UIFontSettings.body.font_type, font_size = 7, text_color = Color.terminal_text_body(230, true),
        }},
        {pass_type = "text", value = "Attacks Blocked", style_id = "source_summary_title", style = {
            offset = {source_x - 2, chart_y + chart_h + 5, 14}, size = {106, 14}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 9, text_color = Color.terminal_text_body(220, true),
        }},
        {pass_type = "text", value_id = "source_summary", style_id = "source_summary", value = "—", style = {
            offset = {source_x - 2, chart_y + chart_h + 24, 14}, size = {106, 20}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 14, text_color = Color.terminal_text_header(255, true),
        }},
    }
    for i = 1, 4 do
        local bx = first_bar_x + (i - 1) * (bar_w + bar_gap)
        local cx = bx + bar_w / 2
        passes[#passes + 1] = {pass_type = "texture", value = "content/ui/materials/patterns/diagonal_lines_pattern_01", style_id = "goal_stripes_" .. i, style = {offset = {bx, chart_y, 7}, size = {0, 0}, color = {95, 90, 112, 92}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "goal_l_" .. i, style = {offset = {bx, chart_y, 8}, size = {1, 0}, color = {210, 120, 145, 122}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "goal_r_" .. i, style = {offset = {bx + bar_w - 1, chart_y, 8}, size = {1, 0}, color = {210, 120, 145, 122}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "goal_t_" .. i, style = {offset = {bx, chart_y, 8}, size = {bar_w, 1}, color = {210, 120, 145, 122}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "result_" .. i, style = {offset = {bx + 1, chart_y + chart_h, 9}, size = {bar_w - 2, 0}, color = {210, 126, 148, 126}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "result_highlight_" .. i, style = {offset = {bx + 1, chart_y + chart_h, 10}, size = {bar_w - 2, 2}, color = {150, 235, 245, 235}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "overflow_" .. i, style = {offset = {bx + 1, chart_y - 11, 11}, size = {bar_w - 2, 0}, color = {210, 126, 148, 126}}}
        passes[#passes + 1] = {pass_type = "text", value_id = "raw_" .. i, style_id = "raw_" .. i, value = "", style = {
            offset = {cx - 42, chart_y - 27, 12}, size = {84, 19}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 12, text_color = {210, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value_id = "name_" .. i, style_id = "name_" .. i, value = "", style = {
            offset = {cx - 36, chart_y + chart_h + 3, 12}, size = {72, 17}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            word_wrap = false,
            font_type = UIFontSettings.body.font_type, font_size = 10, text_color = {210, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value_id = "pct_" .. i, style_id = "pct_" .. i, value = "", style = {
            offset = {cx - 34, chart_y + chart_h + 24, 12}, size = {68, 20}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 14, text_color = {210, 126, 148, 126},
        }}
    end
    -- Compact best / personal / worst comparison charts for Downed,
    -- Disabled and Deaths. These reuse the proven vertical bar language:
    -- muted comparison bars, a role-goal frame around the local result, and
    -- the local player's uncapped team share underneath.
    local titles = {"Downed", "Disabled", "Deaths"}
    local mini_chart_y, mini_chart_h = 62, 82
    local comparison_bar_w, own_bar_w, mini_gap = 10, 38, 4
    for i = 1, 3 do
        local x = counter_x + (i - 1) * (counter_w + counter_gap)
        local group_w = comparison_bar_w * 2 + own_bar_w + mini_gap * 2
        local group_x = x + (counter_w - group_w) / 2
        local best_x = group_x
        local own_x = best_x + comparison_bar_w + mini_gap
        local worst_x = own_x + own_bar_w + mini_gap
        local own_center_x = own_x + own_bar_w / 2

        -- Center the complete icon + title group over the local player's bar.
        local title_widths = {58, 64, 50}
        local heading_w = 17 + 5 + title_widths[i]
        local heading_x = own_center_x - heading_w / 2
        passes[#passes + 1] = {pass_type = "texture", value_id = "counter_" .. i .. "_icon", style_id = "counter_icon_" .. i,
            value = "content/ui/materials/base/ui_default_base", visibility_function = function(content) return content["counter_" .. i .. "_icon_visible"] == true end,
            style = {offset = {heading_x, 8, 20}, size = {17, 17}, color = Color.white(255, true)}}
        passes[#passes + 1] = {pass_type = "text", value_id = "counter_" .. i .. "_glyph", style_id = "counter_glyph_" .. i, value = "",
            visibility_function = function(content) return content["counter_" .. i .. "_glyph_visible"] == true end,
            style = {offset = {heading_x, 6, 20}, size = {17, 21}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
                font_type = "itc_novarese_bold", font_size = 17, text_color = Color.white(255, true)}}
        passes[#passes + 1] = {pass_type = "text", value_id = "counter_title_" .. i, value = titles[i], style_id = "counter_title_" .. i, style = {
            offset = {heading_x + 22, 4, 12}, size = {title_widths[i], 24}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 14, text_color = Color.white(255, true),
        }}
        passes[#passes + 1] = {pass_type = "text", value = "BEST", style_id = "counter_best_label_" .. i, style = {
            offset = {best_x - 12, mini_chart_y + mini_chart_h + 5, 14}, size = {comparison_bar_w + 24, 14},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 8, text_color = {190, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value = "WORST", style_id = "counter_worst_label_" .. i, style = {
            offset = {worst_x - 14, mini_chart_y + mini_chart_h + 5, 14}, size = {comparison_bar_w + 28, 14},
            text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 8, text_color = {190, 126, 148, 126},
        }}

        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_baseline_" .. i, style = {
            offset = {group_x - 3, mini_chart_y + mini_chart_h, 5}, size = {group_w + 6, 1}, color = {180, 82, 112, 92},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_best_bar_" .. i, style = {
            offset = {best_x, mini_chart_y + mini_chart_h, 7}, size = {comparison_bar_w, 0}, color = {210, 96, 126, 100},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_own_bar_" .. i, style = {
            offset = {own_x + 1, mini_chart_y + mini_chart_h, 9}, size = {own_bar_w - 2, 0}, color = {255, 35, 190, 110},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_own_highlight_" .. i, style = {
            offset = {own_x + 1, mini_chart_y + mini_chart_h, 10}, size = {own_bar_w - 2, 0}, color = {150, 235, 245, 235},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_worst_bar_" .. i, style = {
            offset = {worst_x, mini_chart_y + mini_chart_h, 7}, size = {comparison_bar_w, 0}, color = {210, 96, 126, 100},
        }}
        passes[#passes + 1] = {pass_type = "texture", value = "content/ui/materials/patterns/diagonal_lines_pattern_01", style_id = "counter_goal_stripes_" .. i, style = {
            offset = {own_x, mini_chart_y, 8}, size = {own_bar_w, 0}, color = {95, 90, 112, 92},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_goal_l_" .. i, style = {
            offset = {own_x, mini_chart_y, 11}, size = {1, 0}, color = {220, 120, 145, 122},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_goal_r_" .. i, style = {
            offset = {own_x + own_bar_w - 1, mini_chart_y, 11}, size = {1, 0}, color = {220, 120, 145, 122},
        }}
        passes[#passes + 1] = {pass_type = "rect", style_id = "counter_goal_t_" .. i, style = {
            offset = {own_x, mini_chart_y, 11}, size = {own_bar_w, 1}, color = {220, 120, 145, 122},
        }}
        for _, side in ipairs({{"best", best_x}, {"own", own_x}, {"worst", worst_x}}) do
            passes[#passes + 1] = {pass_type = "text", value_id = "counter_" .. side[1] .. "_raw_" .. i,
                style_id = "counter_" .. side[1] .. "_raw_" .. i, value = "", style = {
                    offset = {side[2] - 6, mini_chart_y - 16, 14}, size = {(side[1] == "own" and own_bar_w or comparison_bar_w) + 12, 15},
                    text_horizontal_alignment = "center", text_vertical_alignment = "center",
                    font_type = UIFontSettings.body.font_type, font_size = 9, text_color = {210, 126, 148, 126},
                }}
        end
        passes[#passes + 1] = {pass_type = "text", value_id = "counter_pct_" .. i, style_id = "counter_pct_" .. i, value = "—", style = {
            offset = {x, mini_chart_y + mini_chart_h + 24, 15}, size = {counter_w, 20}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 14, text_color = {255, 35, 190, 110},
        }}
    end
    return UIWidget.create_definition(passes, scenegraph_id)
end



-- Production Offense widget. It deliberately mirrors the Defense band size,
-- label rail, spacing and 0-50% goal language. The left visualization area is
-- reserved for the Damage Total circle; the seven remaining offense metrics
-- are rendered as individual personal goal bars.
local function offense_prototype_definition(scenegraph_id)
    local width, height = 970, 200
    local label_w = 125
    local chart_y, chart_h = 62, 82
    local metrics_x, metrics_w = 330, 385
    -- Keep Combat Quality visually independent from the main Offense panel.
    -- The seven 36 px bars now use 55 px slots (19 px clear gaps, down from
    -- 26.86 px), freeing 55 px for the comparison panel while retaining the
    -- established 10 px gutter.
    local offense_w = 735
    local quality_x, quality_w = 745, 225
    local background_color = {238, 5, 22, 20}
    local passes = {
        {pass_type = "rect", style_id = "background", style = {size = {offense_w, height}, color = background_color}},
        {pass_type = "rect", style_id = "label_background", style = {offset = {0, 0, 2}, size = {label_w, height}, color = {245, 5, 17, 17}}},
        {pass_type = "rect", style_id = "bottom_divider", style = {offset = {0, height - 2, 3}, size = {offense_w, 2}, color = {210, 82, 112, 92}}},
        {pass_type = "rect", style_id = "quality_background", style = {
            offset = {quality_x, 0, 2}, size = {quality_w, height}, color = background_color,
        }},
        {pass_type = "rect", style_id = "quality_header_background", style = {
            offset = {quality_x, 0, 3}, size = {quality_w, 22}, color = {245, 5, 17, 17},
        }},
        {pass_type = "rect", style_id = "quality_critical_background", style = {
            offset = {quality_x, 81, 3}, size = {quality_w, 58}, color = {245, 8, 34, 32},
        }},
        {pass_type = "rect", style_id = "quality_bottom_divider", style = {
            offset = {quality_x, height - 2, 4}, size = {quality_w, 2}, color = {210, 82, 112, 92},
        }},
        {pass_type = "text", value_id = "offense_praise", style_id = "offense_praise", value = "", style = (function()
            local style = table.clone(title_style)
            style.offset = {8, 35, 6}
            style.size = {label_w - 16, 30}
            style.text_horizontal_alignment = "center"
            style.text_vertical_alignment = "center"
            style.font_size = 18
            return style
        end)()},
        {pass_type = "text", value = "OFFENSE", style_id = "section_label", style = {
            offset = {12, 66, 5}, size = {label_w - 24, 32}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 22, text_color = Color.white(255, true),
        }},
        {pass_type = "text", value_id = "offense_score", style_id = "offense_score", value = "", style = {
            offset = {8, 104, 6}, size = {label_w - 16, 24}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 14, text_color = Color.terminal_text_header(255, true),
        }},
        -- Reserved Damage Total circle area. Kept intentionally empty for the
        -- next iteration, with only its heading to lock the final spacing.
        {pass_type = "texture", value_id = "damage_total_icon", style_id = "damage_total_icon", value = "content/ui/materials/base/ui_default_base",
            visibility_function = function(content) return content.damage_total_icon_visible == true end,
            style = {offset = {154, 8, 20}, size = {18, 18}, color = Color.white(255, true)}},
        {pass_type = "text", value_id = "damage_total_glyph", style_id = "damage_total_glyph", value = "",
            visibility_function = function(content) return content.damage_total_glyph_visible == true end,
            style = {offset = {154, 6, 20}, size = {18, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
                font_type = "itc_novarese_bold", font_size = 18, text_color = Color.white(255, true)}},
        {pass_type = "text", value = "Damage Total", style_id = "damage_total_title", style = {
            offset = {178, 4, 8}, size = {135, 26}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 17, text_color = Color.white(255, true),
        }},
        {pass_type = "text", value_id = "damage_total_pct", style_id = "damage_total_pct_shadow_1", value = "—", style = {
            offset = {161, 88, 23}, size = {120, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 20, text_color = {235, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_pct", style_id = "damage_total_pct_shadow_2", value = "—", style = {
            offset = {163, 88, 23}, size = {120, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 20, text_color = {235, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_pct", style_id = "damage_total_pct_shadow_3", value = "—", style = {
            offset = {161, 90, 23}, size = {120, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 20, text_color = {235, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_pct", style_id = "damage_total_pct_shadow_4", value = "—", style = {
            offset = {163, 90, 23}, size = {120, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 20, text_color = {235, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_pct", style_id = "damage_total_pct", value = "—", style = {
            offset = {162, 89, 24}, size = {120, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 20, text_color = {255, 35, 190, 110},
        }},
        {pass_type = "text", value_id = "damage_total_raw", style_id = "damage_total_raw_shadow_1", value = "—", style = {
            offset = {145, 115, 23}, size = {152, 18}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 11, text_color = {220, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_raw", style_id = "damage_total_raw_shadow_2", value = "—", style = {
            offset = {147, 115, 23}, size = {152, 18}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 11, text_color = {220, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_raw", style_id = "damage_total_raw_shadow_3", value = "—", style = {
            offset = {145, 117, 23}, size = {152, 18}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 11, text_color = {220, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_raw", style_id = "damage_total_raw_shadow_4", value = "—", style = {
            offset = {147, 117, 23}, size = {152, 18}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 11, text_color = {220, 0, 0, 0},
        }},
        {pass_type = "text", value_id = "damage_total_raw", style_id = "damage_total_raw", value = "—", style = {
            offset = {146, 116, 24}, size = {152, 18}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 11, text_color = {210, 126, 148, 126},
        }},
        {pass_type = "rect", style_id = "grid_50", style = {offset = {metrics_x, chart_y, 4}, size = {metrics_w, 1}, color = {150, 110, 130, 118}}},
        {pass_type = "rect", style_id = "grid_25", style = {offset = {metrics_x, chart_y + chart_h / 2, 4}, size = {metrics_w, 1}, color = {150, 110, 130, 118}}},
        {pass_type = "rect", style_id = "grid_0", style = {offset = {metrics_x, chart_y + chart_h, 4}, size = {metrics_w, 1}, color = {200, 82, 112, 92}}},
        {pass_type = "text", value = "50%", style_id = "grid_50_text", style = {
            offset = {metrics_x - 36, chart_y - 8, 5}, size = {32, 16}, text_horizontal_alignment = "right", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 10, text_color = {180, 126, 148, 126},
        }},
        {pass_type = "text", value = "25%", style_id = "grid_25_text", style = {
            offset = {metrics_x - 36, chart_y + chart_h / 2 - 8, 5}, size = {32, 16}, text_horizontal_alignment = "right", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 10, text_color = {180, 126, 148, 126},
        }},
        {pass_type = "text", value = "COMBAT QUALITY", style_id = "quality_heading", style = {
            offset = {quality_x + 8, 2, 12}, size = {quality_w - 16, 18}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 12, text_color = Color.white(255, true),
        }},
    }
    -- Render the Damage Total pie directly with Darktide's native triangle
    -- pass. Four player slices each reserve 32
    -- triangles, giving exact dynamic boundaries and a smooth outer edge
    -- without any shader or package dependency.
    local pie_segments_per_player = 32
    local circle_size = 146
    local circle_x, circle_y = 149, 41
    local circle_center = circle_size / 2

    passes[#passes + 1] = {
        pass_type = "circle",
        style_id = "damage_pie_outer_glow",
        style = {
            offset = {circle_x - 3, circle_y - 3, 8},
            size = {circle_size + 6, circle_size + 6},
            color = {0, 0, 0, 0},
        },
    }
    passes[#passes + 1] = {
        pass_type = "circle",
        style_id = "damage_pie_outer_rim",
        style = {
            offset = {circle_x - 1, circle_y - 1, 9},
            size = {circle_size + 2, circle_size + 2},
            color = {125, 70, 95, 89},
        },
    }
    passes[#passes + 1] = {
        pass_type = "circle",
        style_id = "damage_pie_background",
        style = {
            offset = {circle_x, circle_y, 10},
            size = {circle_size, circle_size},
            color = {255, 24, 36, 34},
        },
    }

    for player_index = 1, 4 do
        for segment_index = 1, pie_segments_per_player do
            passes[#passes + 1] = {
                pass_type = "triangle",
                style_id = "damage_pie_" .. player_index .. "_" .. segment_index,
                style = {
                    offset = {circle_x, circle_y, 12 + player_index},
                    size = {circle_size, circle_size},
                    color = {0, 255, 255, 255},
                    triangle_corners = {
                        {circle_center, circle_center},
                        {circle_center, circle_center},
                        {circle_center, circle_center},
                    },
                },
            }
        end
        passes[#passes + 1] = {
            pass_type = "text",
            value_id = "damage_pie_name_" .. player_index,
            style_id = "damage_pie_name_" .. player_index,
            value = "",
            style = {
                offset = {circle_x, circle_y, 28},
                size = {60, 15},
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                font_type = UIFontSettings.body.font_type,
                font_size = 10,
                text_color = {220, 126, 148, 126},
            },
        }
    end

    local metric_titles = {"Weakspot", "Melee", "Ranged", "Swarmers", "Elites", "Specials", "Boss"}
    local slot_w, bar_w = metrics_w / 7, 36
    for i = 1, 7 do
        local cx = metrics_x + slot_w * (i - 0.5)
        local bx = cx - bar_w / 2
        passes[#passes + 1] = {pass_type = "texture", value_id = "metric_icon_" .. i, style_id = "metric_icon_" .. i,
            value = "content/ui/materials/base/ui_default_base", visibility_function = function(content) return content["metric_icon_" .. i .. "_visible"] == true end,
            style = {offset = {cx - 9, 8, 20}, size = {18, 18}, color = Color.white(255, true)}}
        passes[#passes + 1] = {pass_type = "text", value_id = "metric_glyph_" .. i, style_id = "metric_glyph_" .. i, value = "",
            visibility_function = function(content) return content["metric_glyph_" .. i .. "_visible"] == true end,
            style = {offset = {cx - 9, 6, 20}, size = {18, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
                font_type = "itc_novarese_bold", font_size = 17, text_color = Color.white(255, true)}}
        passes[#passes + 1] = {pass_type = "texture", value = "content/ui/materials/patterns/diagonal_lines_pattern_01", style_id = "goal_stripes_" .. i,
            style = {offset = {bx, chart_y, 7}, size = {bar_w, 0}, color = {95, 90, 112, 92}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "goal_l_" .. i, style = {offset = {bx, chart_y, 8}, size = {1, 0}, color = {210, 120, 145, 122}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "goal_r_" .. i, style = {offset = {bx + bar_w - 1, chart_y, 8}, size = {1, 0}, color = {210, 120, 145, 122}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "goal_t_" .. i, style = {offset = {bx, chart_y, 8}, size = {bar_w, 1}, color = {210, 120, 145, 122}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "result_" .. i, style = {offset = {bx + 1, chart_y + chart_h, 9}, size = {bar_w - 2, 0}, color = {255, 35, 190, 110}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "result_highlight_" .. i, style = {offset = {bx + 1, chart_y + chart_h, 10}, size = {bar_w - 2, 0}, color = {150, 235, 245, 235}}}
        passes[#passes + 1] = {pass_type = "rect", style_id = "overflow_" .. i, style = {offset = {bx + 1, chart_y - 11, 11}, size = {bar_w - 2, 0}, color = {255, 35, 190, 110}}}
        passes[#passes + 1] = {pass_type = "text", value_id = "raw_" .. i, style_id = "raw_" .. i, value = "—", style = {
            offset = {cx - 38, chart_y - 27, 12}, size = {76, 19}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 11, text_color = {210, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value_id = "name_" .. i, value = metric_titles[i], style_id = "name_" .. i, style = {
            offset = {cx - slot_w / 2, chart_y + chart_h + 5, 12}, size = {slot_w, 17}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 9, text_color = {210, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value_id = "pct_" .. i, style_id = "pct_" .. i, value = "—", style = {
            offset = {cx - slot_w / 2, chart_y + chart_h + 24, 12}, size = {slot_w, 20}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 13, text_color = {255, 35, 190, 110},
        }}
    end

    -- Neutral personal-rate comparisons. Each row mirrors the Defense
    -- best/local/worst language horizontally and scales to the team-high value.
    local quality_titles = {"Weakspot hit %", "Critical hits %", "Ranged accuracy"}
    -- Center the complete labels + bars + endpoint-values group within the
    -- 225 px Combat Quality panel. The longest group occupies about 170 px,
    -- so a 25 px shift from the former left anchor balances both side margins.
    local quality_group_shift = 25
    local quality_bar_x = quality_x + 42 + quality_group_shift
    local quality_bar_w = 91
    -- Divide the 176 px below the heading and above the bottom divider into
    -- three near-equal sections. Their title baselines produce 10, 9 and 10 px
    -- of clear space beneath the Worst bar respectively.
    local quality_y = {29, 88, 146}
    for i = 1, 3 do
        local y = quality_y[i]
        passes[#passes + 1] = {pass_type = "text", value_id = "quality_title_" .. i, value = quality_titles[i], style_id = "quality_title_" .. i, style = {
            offset = {quality_x + 8, y - 7, 12}, size = {quality_w - 16, 14}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 10, text_color = {220, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value = "BEST", style_id = "quality_best_label_" .. i, style = {
            offset = {quality_x + 5 + quality_group_shift, y + 8, 12}, size = {34, 10}, text_horizontal_alignment = "right", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 8, text_color = {180, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value = "WORST", style_id = "quality_worst_label_" .. i, style = {
            offset = {quality_x + 3 + quality_group_shift, y + 35, 12}, size = {36, 10}, text_horizontal_alignment = "right", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 8, text_color = {180, 126, 148, 126},
        }}
        -- Shared zero line and an even 14 px center-to-center rhythm. Keep one
        -- empty pixel between the 1 px line and the bars so adjacent colors do
        -- not optically merge into a 2 px edge.
        passes[#passes + 1] = {pass_type = "rect", style_id = "quality_zero_line_" .. i, style = {
            offset = {quality_bar_x - 2, y + 8, 7}, size = {1, 36}, color = {180, 82, 112, 92},
        }}
        for _, bar in ipairs({{"best", y + 11, 3}, {"own", y + 21, 11}, {"worst", y + 39, 3}}) do
            local value_y = bar[2] + bar[3] / 2 - 6.5
            passes[#passes + 1] = {pass_type = "rect", style_id = "quality_" .. bar[1] .. "_bar_" .. i, style = {
                offset = {quality_bar_x, bar[2], 8}, size = {0, bar[3]}, color = {190, 96, 126, 100},
            }}
            passes[#passes + 1] = {pass_type = "text", value_id = "quality_" .. bar[1] .. "_value_" .. i,
                style_id = "quality_" .. bar[1] .. "_value_" .. i, value = "--", style = {
                    offset = {quality_bar_x + 5, value_y, 12}, size = {35, 13}, text_horizontal_alignment = "left", text_vertical_alignment = "center",
                    font_type = UIFontSettings.body.font_type, font_size = bar[1] == "own" and 10 or 8,
                    text_color = bar[1] == "own" and {255, 126, 148, 126} or {180, 126, 148, 126},
                }}
            if bar[1] == "own" then
                passes[#passes + 1] = {pass_type = "rect", style_id = "quality_own_highlight_" .. i, style = {
                    offset = {quality_bar_x, bar[2] + 1, 9}, size = {0, bar[3] - 2}, color = {150, 235, 245, 235},
                }}
            end
        end
    end
    return UIWidget.create_definition(passes, scenegraph_id)
end

-- Production Teamplay widget shared by Tactical, Victory, and History.
-- Keep row_icon_N and row_glyph_N IDs synchronized with Tactical updater.
local function teamplay_widget_definition(scenegraph_id)
    local width, height = 970, 90
    local background_color = {238, 5, 22, 20}
    local label_w = 125
    local passes = {
        {pass_type = "rect", style_id = "background", style = {color = background_color}},
        {pass_type = "rect", style_id = "header_background", style = {offset = {0, 0, 2}, size = {label_w, height}, color = {245, 5, 17, 17}}},
        {pass_type = "rect", style_id = "bottom_divider", style = {offset = {0, height - 2, 3}, size = {width, 2}, color = {210, 82, 112, 92}}},
        {pass_type = "text", value_id = "praise", style_id = "praise", value = "", style = (function()
            local style = table.clone(title_style)
            style.offset = {8, 10, 6}
            style.size = {label_w - 16, 22}
            style.text_horizontal_alignment = "center"
            style.text_vertical_alignment = "center"
            style.font_size = 18
            return style
        end)()},
        {pass_type = "text", value = "TEAMPLAY", style_id = "section_label", style = {
            offset = {8, 33, 5}, size = {label_w - 16, 24}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 18, text_color = Color.white(255, true),
        }},
        {pass_type = "text", value_id = "score", style_id = "score", value = "", style = {
            offset = {8, 60, 6}, size = {label_w - 16, 20}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 14, text_color = Color.terminal_text_header(255, true),
        }},
    }
    local labels = {"Coherency", "Saves", "Revives", "Ammo", "Healthstations", "Objectives", "Currency"}
    local content_x = label_w + 10
    local slot_w = (width - content_x - 10) / 7
    for i = 1, 7 do
        local x = content_x + (i - 1) * slot_w
        passes[#passes + 1] = {pass_type = "texture", value_id = "row_icon_" .. i, style_id = "row_icon_" .. i,
            value = "content/ui/materials/base/ui_default_base", visibility_function = function(content) return content["row_icon_" .. i .. "_visible"] == true end,
            style = {offset = {x + slot_w / 2 - 9, 10, 20}, size = {18, 18}, color = Color.white(255, true)}}
        passes[#passes + 1] = {pass_type = "text", value_id = "row_glyph_" .. i, style_id = "row_glyph_" .. i, value = "",
            visibility_function = function(content) return content["row_glyph_" .. i .. "_visible"] == true end,
            style = {offset = {x + slot_w / 2 - 9, 8, 20}, size = {18, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
                font_type = "itc_novarese_bold", font_size = 17, text_color = Color.white(255, true)}}
        passes[#passes + 1] = {pass_type = "text", value_id = "row_name_" .. i, value = labels[i], style_id = "row_name_" .. i, style = {
            offset = {x, 30, 7}, size = {slot_w, 16}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.body.font_type, font_size = 10, text_color = {210, 126, 148, 126},
        }}
        passes[#passes + 1] = {pass_type = "text", value_id = "row_raw_" .. i, style_id = "row_raw_" .. i, value = "—", style = {
            offset = {x, 55, 7}, size = {slot_w, 22}, text_horizontal_alignment = "center", text_vertical_alignment = "center",
            font_type = UIFontSettings.header_1.font_type, font_size = 17, text_color = {255, 35, 190, 110},
        }}
    end
    return UIWidget.create_definition(passes, scenegraph_id)
end

local widget_definitions = {
    compact_panel = UIWidget.create_definition({
        {pass_type = "rect", style = {
            vertical_alignment = "center", horizontal_alignment = "center",
            offset = {0, 0, compact_visual_z - 1}, size = {compact_black_w, compact_black_h}, color = Color.black(255, true),
        }},
        {pass_type = "texture", value = "content/ui/materials/backgrounds/terminal_basic", style = {
            vertical_alignment = "center", horizontal_alignment = "center", scale_to_material = true,
            offset = {0, 0, compact_visual_z}, size = {compact_background_w, compact_h}, color = Color.terminal_grid_background(255, true),
        }},
        {pass_type = "texture", value = "content/ui/materials/frames/dropshadow_heavy", style = {
            vertical_alignment = "center", horizontal_alignment = "center", scale_to_material = true,
            offset = {0, 0, compact_visual_z + 2}, size = {compact_w, compact_shadow_h}, color = Color.black(255, true),
        }},
        {pass_type = "texture", value = "content/ui/materials/frames/inner_shadow_medium", style = {
            vertical_alignment = "center", horizontal_alignment = "center", scale_to_material = true,
            offset = {0, 0, compact_visual_z + 1}, size = {compact_inner_w, compact_inner_h}, color = Color.terminal_grid_background(255, true),
        }},
        {pass_type = "texture", value = "content/ui/materials/dividers/horizontal_frame_big_upper", style = {
            vertical_alignment = "top", horizontal_alignment = "center", scale_to_material = true,
            offset = {0, 0, compact_visual_z + 7}, size = {compact_frame_w, 36}, color = Color.gray(255, true),
        }},
        {pass_type = "texture", value = "content/ui/materials/dividers/horizontal_frame_big_lower", style = {
            vertical_alignment = "bottom", horizontal_alignment = "center", scale_to_material = true,
            offset = {0, 0, compact_visual_z + 7}, size = {compact_frame_w, 36}, color = Color.gray(255, true),
        }},
    }, "compact_panel"),
    compact_title = UIWidget.create_definition({{pass_type = "text", value_id = "text", style_id = "text", value = "IMPROVE YOURSELF!", style = (function()
        local style = table.clone(title_style)
        style.font_size = 54
        style.size = {220, 62}
        style.text_horizontal_alignment = "left"
        style.text_vertical_alignment = "center"
        return style
    end)()}}, "compact_title"),
    compact_subtitle = UIWidget.create_definition({{pass_type = "text", value_id = "text", style_id = "text", value = "", style = {
        offset = {0, 0, 3}, size = {220, 24},
        text_horizontal_alignment = "left", text_vertical_alignment = "center",
        font_type = UIFontSettings.body.font_type, font_size = 14,
        text_color = Color.terminal_text_body(255, true),
    }}}, "compact_subtitle"),
    compact_player_1 = compact_player_definition("compact_player_1"),
    compact_player_2 = compact_player_definition("compact_player_2"),
    compact_player_3 = compact_player_definition("compact_player_3"),
    compact_player_4 = compact_player_definition("compact_player_4"),
    compact_defense = summary_definition("compact_defense"),
    compact_defense_prototype = defense_prototype_definition("compact_defense_prototype"),
    compact_offense = summary_definition("compact_offense"),
    compact_offense_prototype = offense_prototype_definition("compact_offense_prototype"),
    compact_team = teamplay_widget_definition("compact_team"),
}

return settings("ScoreboardMetaViewDefinitions", {
    scenegraph_definition = scenegraph_definition,
    widget_definitions = widget_definitions,
})
