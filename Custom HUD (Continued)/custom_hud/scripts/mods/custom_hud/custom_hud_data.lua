local mod = get_mod("custom_hud")

-- Title-case a Color.* palette name for display ("blue_violet" -> "Blue Violet").
local function prettify_color_name(name)
    local out = name:gsub("_", " ")
    out = out:gsub("(%a)([%w]*)", function(head, tail) return head:upper() .. tail end)
    return out
end

-- Build the {text,value} option list for a colour dropdown from the engine's
-- Color palette, sorted alphabetically by name. Each option's DISPLAY text is the
-- colour name drawn IN that colour via {#color(r,g,b)} markup, so the palette is
-- pickable by sight (selected value included). `options.localize = false` tells
-- DMF to skip localising the option text (it would otherwise treat the marked
-- string as a loc key) -- the markup then reaches the text pass raw and the
-- engine's text renderer colours it. Works with OR without Alf's DMF Extensions;
-- no icon material or add-on dependency. The stored `value` stays the raw name so
-- Color[value] still resolves in custom_hud.lua.
local function get_color_options()
    local options = { localize = false }
    for _, color_name in ipairs(Color.list) do
        local c = Color[color_name](255, true)
        local label = prettify_color_name(color_name)
        if c and #c >= 4 then
            -- Draw the name in its own colour, but floor very dark colours (e.g.
            -- black/navy) toward a readable minimum so the label stays legible on
            -- the dark options panel. Hue is preserved by scaling; pure black
            -- becomes a mid grey. Only the DISPLAY is lifted -- `value` is the raw
            -- name, so the actual HUD colour is unaffected.
            local r, g, b = c[2], c[3], c[4]
            local FLOOR = 70
            local maxc = math.max(r, g, b)
            if maxc < FLOOR then
                if maxc == 0 then
                    r, g, b = FLOOR, FLOOR, FLOOR
                else
                    local s = FLOOR / maxc
                    r, g, b = math.floor(r * s + 0.5), math.floor(g * s + 0.5), math.floor(b * s + 0.5)
                end
            end
            label = string.format("{#color(%d,%d,%d)}%s{#reset()}", r, g, b, label)
        end
        options[#options + 1] = { text = label, value = color_name }
    end
    table.sort(options, function(a, b) return a.value < b.value end)
    return options
end

return {
    name = mod:localize("custom_hud"),
    description = mod:localize("custom_hud_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "settings_header",
                type = "group",
                tab = "General",
                sub_widgets = {
                    {
                        setting_id = "toggle_hud_customization_key",
                        type = "keybind",
                        default_value = { "f3" },
                        keybind_trigger = "pressed",
                        keybind_type = "function_call",
                        function_name = "toggle_hud_customization"
                    },
                    {
                        setting_id = "toggle_hud_hidden_key",
                        type = "keybind",
                        default_value = { "f2" },
                        keybind_trigger = "pressed",
                        keybind_type = "function_call",
                        function_name = "toggle_hud_hidden"
                    },
                    {
                        setting_id = "hide_cutscene_bars",
                        type = "checkbox",
                        default_value = false
                    },
                    {
                        setting_id = "opacity",
                        type = "numeric",
                        range = { 0, 1 },
                        default_value = 1,
                        decimals_number = 2,
                        step_size_value = 0.25
                    },
                    {
                        setting_id = "show_info_panel",
                        type = "checkbox",
                        default_value = true
                    },
                    {
                        setting_id = "panel_font",
                        type = "dropdown",
                        default_value = 1,
                        options = {
                            { text = "font_proxima_nova_bold", value = 1 },
                            { text = "font_proxima_nova_light", value = 2 },
                            { text = "font_proxima_nova_medium", value = 3 },
                            { text = "font_machine_medium", value = 4 },
                            { text = "font_itc_novarese", value = 5 },
                            { text = "font_friz_quadrata", value = 6 },
                            { text = "font_rexlia", value = 7 },
                        }
                    },
                    {
                        setting_id = "panel_font_size",
                        type = "numeric",
                        range = { 10, 28 },
                        default_value = 18,
                        decimals_number = 0,
                        step_size_value = 1
                    },
                    {
                        setting_id = "panel_scale",
                        type = "numeric",
                        range = { 0.75, 2.0 },
                        default_value = 1,
                        decimals_number = 2,
                        step_size_value = 0.05
                    },
                    {
                        setting_id = "panel_list_rows",
                        type = "numeric",
                        range = { 8, 30 },
                        default_value = 18,
                        decimals_number = 0,
                        step_size_value = 1
                    },
                    {
                        setting_id = "panel_width",
                        type = "numeric",
                        range = { 220, 700 },
                        default_value = 340,
                        decimals_number = 0,
                        step_size_value = 10
                    },
                    {
                        setting_id = "box_fill_mode",
                        type = "dropdown",
                        default_value = 1,
                        options = {
                            { text = "box_fill_fill", value = 1 },
                            { text = "box_fill_none", value = 2 }
                        }
                    },
                    {
                        setting_id = "fixed_arrow_move",
                        type = "checkbox",
                        default_value = false,
                        sub_widgets = {
                            {
                                setting_id = "arrow_move_step",
                                type = "numeric",
                                range = { 1, 100 },
                                default_value = 5,
                                decimals_number = 0,
                                step_size_value = 1
                            },
                            {
                                setting_id = "resize_step",
                                type = "numeric",
                                range = { 1, 100 },
                                default_value = 5,
                                decimals_number = 0,
                                step_size_value = 1
                            },
                            {
                                setting_id = "z_step",
                                type = "numeric",
                                range = { 1, 100 },
                                default_value = 1,
                                decimals_number = 0,
                                step_size_value = 1
                            }
                        }
                    },
                    {
                        setting_id = "display_grid",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "snap_to_grid",
                                type = "checkbox",
                                default_value = true
                            },
                            {
                                setting_id = "snap_to_elements",
                                type = "checkbox",
                                default_value = true
                            },
                            {
                                setting_id = "grid_cols",
                                type = "numeric",
                                range = { 1, 54 },
                                default_value = 3,
                                decimals_number = 0,
                                step_size_value = 1
                            },
                            {
                                setting_id = "grid_rows",
                                type = "numeric",
                                range = { 1, 27 },
                                default_value = 3,
                                decimals_number = 0,
                                step_size_value = 1
                            }
                        }
                    },
                    {
                        setting_id = "reset_hud",
                        type = "dropdown",
                        default_value = 0,
                        options = {
                            { text = "", value = 0 },
                            { text = "reset_hud", value = 1 }
                        }
                    }
                }
            },
            {
                setting_id = "editor_colors_group",
                type = "group",
                tab = "Colors",
                sub_widgets = {
                    {
                        setting_id = "editor_colors_fill_group",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "editor_color_rect_default",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_rect_default_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_rect_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_rect_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 55,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_rect_hidden",
                                type = "dropdown",
                                default_value = "black",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_rect_hidden_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 0,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_rect_hidden_hovered",
                                type = "dropdown",
                                default_value = "black",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_rect_hidden_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 0,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                        }
                    },
                    {
                        setting_id = "editor_colors_border_top_group",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "editor_color_border_top_default",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_top_default_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_top_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_top_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 55,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_top_hidden",
                                type = "dropdown",
                                default_value = "black",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_top_hidden_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 111,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_top_hidden_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_top_hidden_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                        }
                    },
                    {
                        setting_id = "editor_colors_border_bottom_group",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "editor_color_border_bottom_default",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_bottom_default_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_bottom_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_bottom_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 55,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_bottom_hidden",
                                type = "dropdown",
                                default_value = "black",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_bottom_hidden_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 111,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_bottom_hidden_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_bottom_hidden_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                        }
                    },
                    {
                        setting_id = "editor_colors_border_left_group",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "editor_color_border_left_default",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_left_default_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_left_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_left_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 55,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_left_hidden",
                                type = "dropdown",
                                default_value = "black",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_left_hidden_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 111,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_left_hidden_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_left_hidden_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                        }
                    },
                    {
                        setting_id = "editor_colors_border_right_group",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "editor_color_border_right_default",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_right_default_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_right_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_right_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 55,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_right_hidden",
                                type = "dropdown",
                                default_value = "black",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_right_hidden_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 111,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                            {
                                setting_id = "editor_color_border_right_hidden_hovered",
                                type = "dropdown",
                                default_value = "gray",
                                options = get_color_options()
                            },
                            {
                                setting_id = "editor_color_border_right_hidden_hovered_alpha",
                                type = "numeric",
                                range = { 0, 255 },
                                default_value = 222,
                                decimals_number = 0,
                                step_size_value = 5
                            },
                        }
                    },
                }
            }
        }
    }
}
