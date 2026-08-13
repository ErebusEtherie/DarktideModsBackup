--[[
  Uptime History View Blueprints

  This file defines the UI blueprints for the uptime history view, including
  button styles, text styles, and interaction behaviors.
--]]

local mod = get_mod("uptime"); if not mod then return end

-- ===== Required Dependencies =====
local UISoundEvents = mod:original_require("scripts/settings/ui/ui_sound_events")
local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")
local ButtonPassTemplates = mod:original_require("scripts/ui/pass_templates/button_pass_templates")
local TextUtilities = mod:original_require("scripts/utilities/ui/text")
local UptimeHistoryViewSettings = mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_view_settings")

-- ===== Grid and Size Settings =====
local grid_size = UptimeHistoryViewSettings.grid_size
local grid_width = grid_size[1]
local settings_value_height = 210
local text_horizontal_margin = 10
local text_width = grid_width - text_horizontal_margin * 2

-- ===== Button Style Definitions =====
-- Hotspot style (handles button interactions)
local list_button_hotspot_default_style = {
    anim_hover_speed = 8,
    anim_input_speed = 8,
    anim_select_speed = 8,
    anim_focus_speed = 8,
    on_hover_sound = UISoundEvents.default_mouse_hover,
    on_pressed_sound = UISoundEvents.default_click
}

-- Icon size for buttons
local list_button_icon_size = {
    50,
    50
}

-- Primary text style for buttons
local list_button_with_icon_text_style = table.clone(UIFontSettings.list_button)
list_button_with_icon_text_style.offset = {
    text_horizontal_margin,
    0,
    0
}
list_button_with_icon_text_style.size = {
    text_width,
    settings_value_height
}
list_button_with_icon_text_style.font_size = 20
list_button_with_icon_text_style.vertical_alignment = "top"
list_button_with_icon_text_style.text_vertical_alignment = "top"

-- Icon style for buttons
local list_button_with_icon_icon_style = {
    vertical_alignment = "center",
    color = list_button_with_icon_text_style.text_color,
    default_color = list_button_with_icon_text_style.default_text_color,
    disabled_color = list_button_with_icon_text_style.disabled_color,
    hover_color = list_button_with_icon_text_style.hover_color,
    size = list_button_icon_size,
    offset = { 9, 0, 3 },
}

-- Previous secondary text style, retained as the colour source for subtitle text
local list_button_with_icon_text_style2 = table.clone(UIFontSettings.list_button_second_row)

-- Previous note text style, retained as the colour source for note text
local list_button_with_icon_note_text_style = table.clone(UIFontSettings.list_button_second_row)
list_button_with_icon_note_text_style.font_size = 16

local title_text_color = list_button_with_icon_text_style.text_color
    or list_button_with_icon_text_style.default_text_color
    or Color.terminal_text_header(255, true)

local subtitle_text_color = list_button_with_icon_text_style2.text_color
    or list_button_with_icon_text_style2.default_text_color
    or Color.terminal_text_body(255, true)

local note_text_color = list_button_with_icon_note_text_style.text_color
    or list_button_with_icon_note_text_style.default_text_color
    or Color.terminal_text_body(255, true)

local function clean_text(text)
    if not text then
        return nil
    end

    text = tostring(text)

    if text == "" then
        return nil
    end

    return text
end

local function color_text(text, color)
    return TextUtilities.apply_color_to_text(text, color)
end

local function history_entry_text(entry)
    local lines = {}

    local title = clean_text(entry.title)
    if title then
        lines[#lines + 1] = color_text(title, title_text_color)
    end

    local subtitle = clean_text(entry.subtitle)
    if subtitle then
        lines[#lines + 1] = color_text(subtitle, subtitle_text_color)
    end

    local note = clean_text(entry.note)
    if note then
        lines[#lines + 1] = color_text(note, note_text_color)
    end

    return table.concat(lines, "\n")
end

-- ===== Blueprint Definitions =====
local blueprints = {
    -- Settings button blueprint (used for history entries)
    settings_button = {
        -- Button size
        size = {
            grid_width,
            settings_value_height
        },

        -- Pass template (defines how the button is rendered)
        pass_template = {
            -- Hotspot (clickable area)
            {
                style_id = "hotspot",
                pass_type = "hotspot",
                content_id = "hotspot",
                content = {
                    use_is_focused = true,
                },
                style = list_button_hotspot_default_style
            },

            -- Background when selected
            {
                pass_type = "texture",
                style_id = "background_selected",
                value = "content/ui/materials/buttons/background_selected",
                style = {
                    color = Color.ui_terminal(0, true),
                    offset = { 0, 0, 0 }
                },
                change_function = function(content, style)
                    -- Animate alpha based on selection progress
                    style.color[1] = 255 * content.hotspot.anim_select_progress
                end,
                visibility_function = ButtonPassTemplates.list_button_focused_visibility_function
            },

            -- Highlight frame when hovered/focused
            {
                pass_type = "texture",
                style_id = "highlight",
                value = "content/ui/materials/frames/hover",
                style = {
                    hdr = true,
                    scale_to_material = true,
                    color = Color.ui_terminal(255, true),
                    offset = { 0, 0, 3 },
                    size_addition = { 0, 0 }
                },
                change_function = ButtonPassTemplates.list_button_highlight_change_function,
                visibility_function = ButtonPassTemplates.list_button_focused_visibility_function
            },

            -- Icon (if provided)
            {
                pass_type = "texture",
                value_id = "icon",
                style_id = "icon",
                style = table.clone(list_button_with_icon_icon_style),
                change_function = ButtonPassTemplates.list_button_label_change_function,
                visibility_function = function(content, style)
                    -- Only show if icon is provided
                    return not not content.icon
                end
            },

            -- Combined title, subtitle, and optional note text
            {
                pass_type = "text",
                style_id = "text",
                value_id = "text",
                style = table.clone(list_button_with_icon_text_style),
                change_function = ButtonPassTemplates.list_button_label_change_function
            }
        },

        -- Initialization function for the button
        init = function(parent, widget, entry, callback_name)
            local content = widget.content
            local hotspot = content.hotspot

            -- Set up pressed callback
            hotspot.pressed_callback = function()
                callback(parent, callback_name, widget, entry)()
            end

            -- Set up concatenated text content
            content.text = history_entry_text(entry)

            -- Set up icon and entry reference
            content.icon = entry.icon
            content.entry = entry
        end
    },
}

return settings("UptimeHistoryViewContentBlueprints", blueprints)
