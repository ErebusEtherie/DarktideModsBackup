-- File: weapon_action_details/scripts/mods/weapon_action_details/ui/wad_ui.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local Text = mod:original_require("scripts/utilities/ui/text")
local Localize = Localize

local DAMAGE_TEXT_COLOR = mod.WAD_DAMAGE_TEXT_COLOR
local IMPACT_TEXT_COLOR = mod.WAD_IMPACT_TEXT_COLOR
local CLEAVE_TEXT_COLOR = mod.WAD_CLEAVE_TEXT_COLOR
local CRIT_TEXT_COLOR = mod.WAD_CRIT_TEXT_COLOR
local PERIL_TEXT_COLOR = mod.WAD_PERIL_TEXT_COLOR
local HEAT_TEXT_COLOR = mod.WAD_HEAT_TEXT_COLOR
local DAMAGE_GLYPH = mod.WAD_DAMAGE_GLYPH
local IMPACT_GLYPH = mod.WAD_IMPACT_GLYPH
local CLEAVE_GLYPH = mod.WAD_CLEAVE_GLYPH
local CRIT_GLYPH = mod.WAD_CRIT_GLYPH
local PERIL_GLYPH = mod.WAD_PERIL_GLYPH
local HEAT_GLYPH = mod.WAD_HEAT_GLYPH
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET
local TAB_LEGEND_HEIGHT = 28
local TAB_HEADER_HEIGHT = mod.TAB_HEIGHT + TAB_LEGEND_HEIGHT

local has_text = mod.has_text

local HIT_ZONE_LOCALIZATION_KEYS = {
    [mod.WAD_DAMAGE_HIT_ZONE_BODY] = mod.WAD_LOC.WEAPON_DETAILS_BODY,
    [mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT] = mod.WAD_LOC.WEAPON_DETAILS_WEAKSPOT,
    [mod.WAD_DAMAGE_HIT_ZONE_CRITICAL] = mod.WAD_LOC.WEAPON_DETAILS_CRIT,
    [mod.WAD_DAMAGE_HIT_ZONE_CRITICAL_WEAKSPOT] = mod.WAD_LOC.WEAPON_DETAILS_CRIT_HS,
}

local function text_contains_glyph(text, glyph)
    return type(text) == "string" and string.find(text, glyph, 1, true) ~= nil
end

local function action_entries_resource_flags(entries)
    local include_peril = false
    local include_heat = false

    for i = 1, #entries do
        local entry = entries[i]

        if not include_peril and
            (entry.has_peril == true or has_text(entry.peril_text) or
                text_contains_glyph(entry.damage_text, PERIL_GLYPH)) then
            include_peril = true
        end

        if not include_heat and
            (entry.has_heat == true or has_text(entry.heat_text) or
                text_contains_glyph(entry.damage_text, HEAT_GLYPH)) then
            include_heat = true
        end

        if include_peril and include_heat then
            break
        end
    end

    return include_peril, include_heat
end

function mod.add_tab_spacing_to_layout(layout, self)
    layout[#layout + 1] = {
        widget_type = "dynamic_spacing",
        size = {
            self._default_grid_size[1],
            TAB_HEADER_HEIGHT,
        },
    }
end

function mod.add_current_attack_patterns_layout(layout, self, item)
    layout[#layout + 1] = {
        widget_type = "attack_pattern_header",
        item = item,
    }
    layout[#layout + 1] = {
        widget_type = "pattern_type_breakdown",
        item = item,
    }
    layout[#layout + 1] = {
        widget_type = "dynamic_spacing",
        size = {
            self._default_grid_size[1],
            40,
        },
    }
    layout[#layout + 1] = {
        widget_type = "damage_grid",
        item = item,
    }
end

function mod.action_filter_for_tab(tab_index)
    return tab_index == mod.TAB_SPECIAL_ACTIONS and mod.WAD_ACTION_FILTER_SPECIAL or
        mod.WAD_ACTION_FILTER_NORMAL
end

function mod.wad_actions_legend_text(include_peril, include_heat)
    local parts = {
        string.format("%s%s %s%s", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH,
            Localize(mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT), RICH_TEXT_RESET),
        string.format("%s%s %s%s", IMPACT_TEXT_COLOR, IMPACT_GLYPH,
            Localize(mod.WAD_LOC.STAGGER), RICH_TEXT_RESET),
        string.format("%s%s %s%s", CLEAVE_TEXT_COLOR, CLEAVE_GLYPH,
            Localize(mod.WAD_LOC.STATS_DISPLAY_CLEAVE_TARGETS_STAT), RICH_TEXT_RESET),
        string.format("%s%s %s%s", CRIT_TEXT_COLOR, CRIT_GLYPH,
            Localize(mod.WAD_LOC.WEAPON_DETAILS_CRIT), RICH_TEXT_RESET),
    }

    if include_peril then
        parts[#parts + 1] = string.format("%s%s %s%s", PERIL_TEXT_COLOR, PERIL_GLYPH,
            Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_PERIL_COST), RICH_TEXT_RESET)
    end

    if include_heat then
        parts[#parts + 1] = string.format("%s%s %s%s", HEAT_TEXT_COLOR, HEAT_GLYPH,
            Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_HEAT_GENERATION), RICH_TEXT_RESET)
    end

    return table.concat(parts, " ")
end

function mod.add_actions_layout(layout, item, action_filter)
    local entries = mod.sorted_action_entries(item, action_filter)
    local is_special_actions = action_filter == mod.WAD_ACTION_FILTER_SPECIAL
    local header_text = is_special_actions and
        Text.localize_to_upper(mod.WAD_LOC.WEAPON_ACTION_TITLE_SPECIAL) or
        Text.localize_to_upper(mod.WAD_LOC.ITEM_INFORMATION_ACTIONS)
    local hit_zone_localization_key =
        HIT_ZONE_LOCALIZATION_KEYS[mod.wad_damage_hit_zone] or
        mod.WAD_LOC.WEAPON_DETAILS_BODY

    local hit_zone_text = Text.localize_to_upper(hit_zone_localization_key)

    layout[#layout + 1] = {
        widget_type = "wad_actions_header",
        text = string.format("%s - %s (%d)", header_text, hit_zone_text, #entries),
    }

    local legend_text

    if #entries > 0 then
        local include_peril, include_heat = action_entries_resource_flags(entries)

        legend_text = mod.wad_actions_legend_text(include_peril, include_heat)
    end

    for i = 1, #entries do
        local entry = entries[i]

        layout[#layout + 1] = {
            widget_type = entry.is_effect_table and "wad_effect_table_action_entry" or "wad_action_entry",
            action_name = entry.display_name,
            detail_text = entry.detail_text,
            chain_text = entry.chain_text,
            stamina_text = entry.stamina_text,
            damage_text = entry.damage_text,
            damage_table = entry.damage_table,
            stack_header = entry.stack_header,
            damage_header = entry.damage_header,
            armor_damage_header = entry.armor_damage_header,
            armor_grid = entry.armor_grid,
            kind_text = entry.kind,
            icon = entry.icon,
            tooltip_grid = entry.tooltip_grid,
            show_top_divider = i == 1,
        }
    end

    if #entries == 0 then
        layout[#layout + 1] = {
            widget_type = "wad_empty_text",
            text = is_special_actions and
                "No displayable special actions found." or
                "No displayable actions found.",
        }
    end

    return legend_text, entries.range_affects_performance == true
end

function mod.add_training_layout(layout, item)
    local entries = type(mod.training_entries) == "function" and
        mod.training_entries(item) or {}

    layout[#layout + 1] = {
        widget_type = "wad_actions_header",
        text = Text.localize_to_upper(mod.WAD_LOC.BASIC_TRAINING_TITLE),
    }

    for i = 1, #entries do
        local entry = entries[i]

        layout[#layout + 1] = {
            widget_type = "wad_training_entry",
            title = entry.title,
            body_text = entry.body_text,
            row_count = entry.row_count,
            show_top_divider = i == 1,
        }
    end

    if #entries == 0 then
        layout[#layout + 1] = {
            widget_type = "wad_empty_text",
            text = "No training combinations found.",
        }
    end
end

function mod.tab_background_color(is_selected, is_hover)
    if is_selected then
        return Color.terminal_background_selected(180, true)
    elseif is_hover then
        return Color.terminal_background_gradient(120, true)
    end

    return Color.terminal_grid_background(120, true)
end

function mod.tab_text_color(is_selected, is_hover)
    if is_selected then
        return Color.terminal_text_header_selected(255, true)
    elseif is_hover then
        return Color.terminal_text_header(255, true)
    end

    return Color.terminal_text_body(255, true)
end

function mod.create_tab_background_definition(width)
    return UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "background",
            style = {
                size = {
                    width,
                    TAB_LEGEND_HEIGHT,
                },
                color = Color.black(255, true),
                offset = {
                    0,
                    mod.TAB_HEIGHT,
                    0,
                },
            },
        },
        {
            pass_type = "text",
            style_id = "legend",
            value = "",
            value_id = "legend_text",
            style = {
                font_size = 16,
                font_type = "proxima_nova_bold",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = Color.terminal_text_body(255, true),
                rich_text = true,
                size = {
                    width - 32,
                    TAB_LEGEND_HEIGHT,
                },
                offset = {
                    16,
                    mod.TAB_HEIGHT,
                    1,
                },
            },
        },
    }, "pivot", nil, {
        width,
        TAB_HEADER_HEIGHT,
    })
end

function mod.create_tab_definition(width)
    return UIWidget.create_definition({
        {
            content_id = "hotspot",
            pass_type = "hotspot",
            style_id = "hotspot",
            style = {
                size = {
                    width,
                    mod.TAB_HEIGHT,
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
            style_id = "background",
            style = {
                size = {
                    width,
                    mod.TAB_HEIGHT,
                },
                color = Color.terminal_grid_background(120, true),
            },
        },
        {
            pass_type = "texture",
            style_id = "frame",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = {
                scale_to_material = true,
                size = {
                    width,
                    mod.TAB_HEIGHT,
                },
                color = Color.terminal_frame(255, true),
                offset = {
                    0,
                    0,
                    2,
                },
            },
        },
        {
            pass_type = "text",
            style_id = "text",
            value = "",
            value_id = "text",
            style = {
                font_size = 20,
                font_type = "proxima_nova_bold",
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = Color.terminal_text_body(255, true),
                size = {
                    width,
                    mod.TAB_HEIGHT,
                },
                offset = {
                    0,
                    0,
                    3,
                },
            },
        },
    }, "pivot", nil, {
        width,
        mod.TAB_HEIGHT,
    })
end

local function add_tab_widget(tab_widgets, self, widget_name, tab_width, tab_index, text)
    local widget = UIWidget.init(widget_name, mod.create_tab_definition(tab_width))
    local tab_position = #tab_widgets

    widget.content.text = text
    widget.content.wad_tab_index = tab_index
    widget.content.hotspot.pressed_callback = callback(self, "wad_switch_tab", tab_index)
    widget.offset[1] = (tab_width + mod.TAB_GAP) * tab_position
    widget.offset[2] = 0
    widget.offset[3] = 1

    tab_widgets[#tab_widgets + 1] = widget
end

function mod.ensure_tab_widgets(self)
    local grid_width = self._default_grid_size and self._default_grid_size[1]

    if not grid_width then
        return
    end

    local has_special_actions = self._wad_has_special_actions == true
    local has_training = self._wad_has_training == true

    if self._wad_tab_background_widget and self._wad_tab_widgets and
        self._wad_tab_grid_width == grid_width and
        self._wad_tab_has_special_actions == has_special_actions and
        self._wad_tab_has_training == has_training then
        return
    end

    local tab_count = 2

    if has_special_actions then
        tab_count = tab_count + 1
    end

    if has_training then
        tab_count = tab_count + 1
    end

    local tab_width = math.floor(
        (grid_width - mod.TAB_GAP * (tab_count - 1)) / tab_count
    )
    local tab_background_widget = UIWidget.init(
        "wad_tab_background",
        mod.create_tab_background_definition(grid_width)
    )
    local tab_widgets = {}

    tab_background_widget.offset[3] = 0

    add_tab_widget(
        tab_widgets,
        self,
        "wad_attack_patterns_tab",
        tab_width,
        mod.TAB_ATTACK_PATTERNS,
        Localize(mod.WAD_LOC.WEAPON_STATS_ATTACK_PATTERN)
    )
    add_tab_widget(
        tab_widgets,
        self,
        "wad_actions_tab",
        tab_width,
        mod.TAB_ACTIONS,
        Localize(mod.WAD_LOC.ITEM_INFORMATION_ACTIONS)
    )

    if has_special_actions then
        add_tab_widget(
            tab_widgets,
            self,
            "wad_special_actions_tab",
            tab_width,
            mod.TAB_SPECIAL_ACTIONS,
            Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_SPECIAL)
        )
    end

    if has_training then
        add_tab_widget(
            tab_widgets,
            self,
            "wad_training_tab",
            tab_width,
            mod.TAB_TRAINING,
            Localize(mod.WAD_LOC.BASIC_TRAINING_TITLE)
        )
    end

    self._wad_tab_background_widget = tab_background_widget
    self._wad_tab_widgets = tab_widgets
    self._wad_tab_grid_width = grid_width
    self._wad_tab_has_special_actions = has_special_actions
    self._wad_tab_has_training = has_training
end

function mod.update_tab_widgets(self)
    mod.ensure_tab_widgets(self)

    local tab_background_widget = self._wad_tab_background_widget
    local tab_widgets = self._wad_tab_widgets

    if not tab_background_widget or not tab_widgets then
        return
    end

    local selected_tab = self._wad_selected_tab
    local show_legend = selected_tab == mod.TAB_ACTIONS or selected_tab == mod.TAB_SPECIAL_ACTIONS

    tab_background_widget.content.visible = true
    tab_background_widget.content.legend_text = show_legend and self._wad_tab_legend_text or ""

    for i = 1, #tab_widgets do
        local widget = tab_widgets[i]
        local content = widget.content
        local style = widget.style
        local tab_index = content.wad_tab_index
        local visible = tab_index == mod.TAB_ATTACK_PATTERNS or
            tab_index == mod.TAB_ACTIONS and self._wad_has_actions or
            tab_index == mod.TAB_SPECIAL_ACTIONS and
            self._wad_has_actions and
            self._wad_has_special_actions or
            tab_index == mod.TAB_TRAINING and
            self._wad_has_actions and
            self._wad_has_training
        local hotspot = content.hotspot
        local is_selected = self._wad_selected_tab == tab_index
        local is_hover = hotspot and hotspot.is_hover

        content.visible = visible
        hotspot.disabled = not visible
        hotspot.is_selected = is_selected
        style.background.color = mod.tab_background_color(is_selected, is_hover)
        style.text.text_color = mod.tab_text_color(is_selected, is_hover)
        style.frame.color = is_selected and
            Color.terminal_frame_selected(255, true) or
            Color.terminal_frame(255, true)
    end
end
