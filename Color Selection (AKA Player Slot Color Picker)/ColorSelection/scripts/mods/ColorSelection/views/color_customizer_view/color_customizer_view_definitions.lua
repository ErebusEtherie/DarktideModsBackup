local mod = get_mod("ColorSelection")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")

-- Scenegraph definition
local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    background = {
        parent = "screen",
        scale = "fit",
        size = { 1920, 1080 },
        position = { 0, 0, 0 }
    },
    window = {
        parent = "background",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 600, 760 },
        position = { 0, 0, 0 }
    },
    player_info_text = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { 550, 60 },
        position = { 0, 20, 0 }
    },
    slot_buttons_container = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { 550, 50 },
        position = { 0, 90, 0 }
    },
    slot1_button = {
        parent = "slot_buttons_container",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 100, 40 },
        position = { -220, 0, 0 }
    },
    slot2_button = {
        parent = "slot_buttons_container",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 100, 40 },
        position = { -110, 0, 0 }
    },
    slot3_button = {
        parent = "slot_buttons_container",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 100, 40 },
        position = { 0, 0, 0 }
    },
    slot4_button = {
        parent = "slot_buttons_container",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 100, 40 },
        position = { 110, 0, 0 }
    },
    bot_button = {
        parent = "slot_buttons_container",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 100, 40 },
        position = { 220, 0, 0 }
    },
    account_id_input = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { 550, 40 },
        position = { 0, 150, 10 }
    },
    color_preview = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { 150, 150 },
        position = { 0, 210, 0 }
    },
    red_slider = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { 450, 30 },
        position = { 30, 390, 5 }
    },
    red_input = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "right",
        size = { 80, 30 },
        position = { -30, 390, 10 }
    },
    green_slider = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { 450, 30 },
        position = { 30, 440, 5 }
    },
    green_input = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "right",
        size = { 80, 30 },
        position = { -30, 440, 10 }
    },
    blue_slider = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "left",
        size = { 450, 30 },
        position = { 30, 490, 5 }
    },
    blue_input = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "right",
        size = { 80, 30 },
        position = { -30, 490, 10 }
    },
    hex_input = {
        parent = "window",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { 200, 40 },
        position = { 0, 550, 10 }
    },
    apply_button = {
        parent = "window",
        vertical_alignment = "bottom",
        horizontal_alignment = "left",
        size = { 180, 40 },
        position = { 20, -20, 0 }
    },
    save_button = {
        parent = "window",
        vertical_alignment = "bottom",
        horizontal_alignment = "center",
        size = { 180, 40 },
        position = { 0, -20, 0 }
    },
    reset_button = {
        parent = "window",
        vertical_alignment = "bottom",
        horizontal_alignment = "left",
        size = { 180, 40 },
        position = { 20, -70, 0 }
    },
    reset_all_button = {
        parent = "window",
        vertical_alignment = "bottom",
        horizontal_alignment = "right",
        size = { 180, 40 },
        position = { -20, -70, 0 }
    },
    list_players_button = {
        parent = "window",
        vertical_alignment = "bottom",
        horizontal_alignment = "center",
        size = { 180, 40 },
        position = { 0, -70, 0 }
    },
    close_button = {
        parent = "window",
        vertical_alignment = "bottom",
        horizontal_alignment = "right",
        size = { 180, 40 },
        position = { -20, -20, 0 }
    },
    players_panel = {
        parent = "background",
        vertical_alignment = "center",
        horizontal_alignment = "right",
        size = { 400, 600 },
        position = { -20, 0, 10 }
    },
    players_panel_title = {
        parent = "players_panel",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { 380, 40 },
        position = { 0, 20, 0 }
    },
    players_list = {
        parent = "players_panel",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { 380, 520 },
        position = { 0, 70, 0 }
    },
    players_pagination = {
        parent = "players_panel",
        vertical_alignment = "bottom",
        horizontal_alignment = "center",
        size = { 380, 40 },
        position = { 0, -50, 0 }
    },
    prev_page_button = {
        parent = "players_pagination",
        vertical_alignment = "center",
        horizontal_alignment = "left",
        size = { 100, 30 },
        position = { 20, 0, 0 }
    },
    page_info_text = {
        parent = "players_pagination",
        vertical_alignment = "center",
        horizontal_alignment = "center",
        size = { 180, 30 },
        position = { 0, 0, 0 }
    },
    next_page_button = {
        parent = "players_pagination",
        vertical_alignment = "center",
        horizontal_alignment = "right",
        size = { 100, 30 },
        position = { -20, 0, 0 }
    },
    close_panel_button = {
        parent = "players_panel",
        vertical_alignment = "top",
        horizontal_alignment = "right",
        size = { 30, 30 },
        position = { -10, 10, 0 }
    }
}

-- RGB Slider pass template (similar to loadout_config stat sliders)
local function create_rgb_slider_passes(label_text)
    local slider_width = 450
    return {
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "left",
                color = { 180, 3, 3, 3 },
                offset = { 0, 0, 1 }
            }
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_background_gradient(180, true),
                size = { slider_width, 14 },
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_text_header(0, true),
                size = { slider_width, 14 },
                offset = { 0, 0, 1 }
            },
            change_function = function(content, style)
                local hotspot = content.hotspot_bar
                if hotspot and hotspot.is_hover then
                    style.color[1] = 60  -- Bright highlight on hover
                else
                    style.color[1] = 0   -- Invisible when not hovering
                end
            end
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "left",
                size = { 0, 10 },
                color = Color.terminal_background_selected(255, true),
                offset = { 0, 0, 2 }
            },
            change_function = function(content, style)
                style.size[1] = (content.value or 0) * slider_width
            end
        },
        {
            pass_type = "hotspot",
            content_id = "hotspot_bar",
            content = {
                on_hover_sound = UISoundEvents.default_mouse_hover
            },
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                size = { slider_width, 30 },
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "logic",
            value = function(pass, renderer, style, content, position, size)
                local hotspot = content.hotspot_bar
                if not hotspot or not hotspot.is_hover then
                    return
                end
                
                -- Handle mouse wheel scrolling
                local input_service = renderer.input_service
                if input_service then
                    local scroll_axis = input_service:get("scroll_axis")
                    if scroll_axis and scroll_axis ~= 0 then
                        local current_value = content.value or 0
                        local step = 0.02  -- Scroll by 5 units (0.02 * 255 ≈ 5)
                        content.value = math.clamp(current_value + (scroll_axis[2] * step), 0, 1)
                    end
                end
            end
        },
        {
            pass_type = "triangle",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "left",
                triangle_corners = {
                    { -6, 0 },
                    { 0, 6 },
                    { 0, -6 }
                },
                color = Color.white(180, true),
                offset = { 0, 0, 2 }
            },
            change_function = function(content, style)
                if content.hotspot_left.is_hover then
                    style.color = Color.white(255, true)
                else
                    style.color = Color.white(180, true)
                end
            end
        },
        {
            pass_type = "hotspot",
            content_id = "hotspot_left",
            content = {
                on_hover_sound = UISoundEvents.default_mouse_hover
            },
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "left",
                size = { 20, 30 },
                offset = { -5, 0, 0 }
            }
        },
        {
            pass_type = "logic",
            value = function(pass, renderer, style, content, position, size)
                local hotspot = content.hotspot_left
                if not hotspot then
                    return
                end
                
                local on_pressed = hotspot.on_pressed
                local is_held = hotspot.is_held
                
                -- Handle initial press
                if on_pressed then
                    Managers.ui:play_2d_sound(UISoundEvents.default_click)
                    local current_value = content.value or 0
                    content.value = math.clamp(current_value - 0.01, 0, 1)
                    hotspot._last_press_time = 0
                end
                
                -- Handle continuous hold
                if is_held then
                    local dt = renderer.dt
                    local last_press_time = hotspot._last_press_time or 0
                    last_press_time = last_press_time + dt
                    hotspot._last_press_time = last_press_time
                    
                    -- After initial delay, update continuously
                    if last_press_time > 0.5 then
                        local current_value = content.value or 0
                        local step = 0.01 * dt * 8  -- Smooth continuous adjustment
                        content.value = math.clamp(current_value - step, 0, 1)
                    end
                elseif hotspot.on_released then
                    hotspot._last_press_time = nil
                end
            end
        },
        {
            pass_type = "triangle",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "right",
                triangle_corners = {
                    { 6, 0 },
                    { 0, 6 },
                    { 0, -6 }
                },
                color = Color.white(255, true),
                offset = { 450, 0, 2 }
            },
            change_function = function(content, style)
                if content.hotspot_right.is_hover then
                    style.color = Color.white(255, true)
                else
                    style.color = Color.white(180, true)
                end
            end
        },
        {
            pass_type = "hotspot",
            content_id = "hotspot_right",
            content = {
                on_hover_sound = UISoundEvents.default_mouse_hover
            },
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "right",
                size = { 20, 30 },
                offset = { 5, 0, 0 }
            }
        },
        {
            pass_type = "logic",
            value = function(pass, renderer, style, content, position, size)
                local hotspot = content.hotspot_right
                if not hotspot then
                    return
                end
                
                local on_pressed = hotspot.on_pressed
                local is_held = hotspot.is_held
                
                -- Handle initial press
                if on_pressed then
                    Managers.ui:play_2d_sound(UISoundEvents.default_click)
                    local current_value = content.value or 0
                    content.value = math.clamp(current_value + 0.01, 0, 1)
                    hotspot._last_press_time = 0
                end
                
                -- Handle continuous hold
                if is_held then
                    local dt = renderer.dt
                    local last_press_time = hotspot._last_press_time or 0
                    last_press_time = last_press_time + dt
                    hotspot._last_press_time = last_press_time
                    
                    -- After initial delay, update continuously
                    if last_press_time > 0.5 then
                        local current_value = content.value or 0
                        local step = 0.01 * dt * 8  -- Smooth continuous adjustment
                        content.value = math.clamp(current_value + step, 0, 1)
                    end
                elseif hotspot.on_released then
                    hotspot._last_press_time = nil
                end
            end
        },
        {
            pass_type = "text",
            value_id = "label_text",
            value = label_text,
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "left",
                font_type = "machine_medium",
                font_size = 16,
                text_color = UIHudSettings.color_tint_main_1,
                offset = { 0, -20, 2 }
            }
        }
    }
end

-- Widget definitions
local widget_definitions = {
    background = UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_background(180, true),
                offset = { 0, 0, 0 }
            }
        }
    }, "background"),
    
    window = UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_background(255, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "texture",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_frame(255, true),
                offset = { 0, 0, 2 }
            }
        },
        {
            pass_type = "text",
            value = mod:localize("color_customizer_title"),
            style = {
                text_vertical_alignment = "top",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 24,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 10, 1 }
            }
        }
    }, "window"),
    
    player_info_text = UIWidget.create_definition({
        {
            pass_type = "text",
            value_id = "text",
            value = "",
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 1 }
            }
        }
    }, "player_info_text"),
    
    slot1_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            content = {
                on_pressed_sound = UISoundEvents.default_click
            }
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_background(255, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "rect",
            style_id = "color_swatch",
            style = {
                vertical_alignment = "top",
                horizontal_alignment = "left",
                color = { 255, 255, 255, 255 },
                size = { 100, 8 },
                offset = { 0, 0, 1 }
            }
        },
        {
            pass_type = "text",
            value = mod:localize("button_slot1"),
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 2 }
            }
        }
    }, "slot1_button"),
    
    slot2_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            content = {
                on_pressed_sound = UISoundEvents.default_click
            }
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_background(255, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "rect",
            style_id = "color_swatch",
            style = {
                vertical_alignment = "top",
                horizontal_alignment = "left",
                color = { 255, 255, 255, 255 },
                size = { 100, 8 },
                offset = { 0, 0, 1 }
            }
        },
        {
            pass_type = "text",
            value = mod:localize("button_slot2"),
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 2 }
            }
        }
    }, "slot2_button"),
    
    slot3_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            content = {
                on_pressed_sound = UISoundEvents.default_click
            }
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_background(255, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "rect",
            style_id = "color_swatch",
            style = {
                vertical_alignment = "top",
                horizontal_alignment = "left",
                color = { 255, 255, 255, 255 },
                size = { 100, 8 },
                offset = { 0, 0, 1 }
            }
        },
        {
            pass_type = "text",
            value = mod:localize("button_slot3"),
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 2 }
            }
        }
    }, "slot3_button"),
    
    slot4_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            content = {
                on_pressed_sound = UISoundEvents.default_click
            }
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_background(255, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "rect",
            style_id = "color_swatch",
            style = {
                vertical_alignment = "top",
                horizontal_alignment = "left",
                color = { 255, 255, 255, 255 },
                size = { 100, 8 },
                offset = { 0, 0, 1 }
            }
        },
        {
            pass_type = "text",
            value = mod:localize("button_slot4"),
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 2 }
            }
        }
    }, "slot4_button"),
    
    bot_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            content = {
                on_pressed_sound = UISoundEvents.default_click
            }
        },
        {
            pass_type = "rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_background(255, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "rect",
            style_id = "color_swatch",
            style = {
                vertical_alignment = "top",
                horizontal_alignment = "left",
                color = { 255, 255, 255, 255 },
                size = { 100, 8 },
                offset = { 0, 0, 1 }
            }
        },
        {
            pass_type = "text",
            value = mod:localize("button_bot"),
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 2 }
            }
        }
    }, "bot_button"),
    
    account_id_input = UIWidget.create_definition(
        TextInputPassTemplates.terminal_input_field,
        "account_id_input",
        {
            input_text = "",
            placeholder_text = mod:localize("account_id_placeholder"),
            max_length = 36  -- UUID max length (with hyphens: 36 chars, without: 32 chars)
        }
    ),
    
    color_preview = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "color_rect",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = { 255, 255, 255, 255 },
                size = { 150, 150 },
                offset = { 0, 0, 2 }  -- Higher z-order so it's above the frame
            }
        },
        {
            pass_type = "texture",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_frame(255, true),
                offset = { 0, 0, 1 }  -- Frame behind the color rect
            }
        }
    }, "color_preview"),
    
    red_slider = UIWidget.create_definition(
        create_rgb_slider_passes(mod:localize("label_red")),
        "red_slider",
        { value = 1.0 }
    ),
    
    green_slider = UIWidget.create_definition(
        create_rgb_slider_passes(mod:localize("label_green")),
        "green_slider",
        { value = 1.0 }
    ),
    
    blue_slider = UIWidget.create_definition(
        create_rgb_slider_passes(mod:localize("label_blue")),
        "blue_slider",
        { value = 1.0 }
    ),
    
    red_input = UIWidget.create_definition(
        TextInputPassTemplates.terminal_input_field,
        "red_input",
        {
            input_text = "255",
            placeholder_text = "0-255",
            max_length = 3
        }
    ),
    
    green_input = UIWidget.create_definition(
        TextInputPassTemplates.terminal_input_field,
        "green_input",
        {
            input_text = "255",
            placeholder_text = "0-255",
            max_length = 3
        }
    ),
    
    blue_input = UIWidget.create_definition(
        TextInputPassTemplates.terminal_input_field,
        "blue_input",
        {
            input_text = "255",
            placeholder_text = "0-255",
            max_length = 3
        }
    ),
    
    hex_input = UIWidget.create_definition(
        TextInputPassTemplates.terminal_input_field,
        "hex_input",
        {
            input_text = "FFFFFF",
            placeholder_text = "FFFFFF",
            max_length = 7  -- Allow 7 chars to accommodate #FFFFFF, then strip the #
        }
    ),
    
    apply_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "apply_button",
        {
            text = mod:localize("button_apply"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            }
        }
    ),
    
    save_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "save_button",
        {
            text = mod:localize("button_save"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            }
        }
    ),
    
    reset_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "reset_button",
        {
            text = mod:localize("button_reset"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            }
        }
    ),
    
    reset_all_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "reset_all_button",
        {
            text = mod:localize("button_reset_all"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            }
        }
    ),
    
    list_players_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "list_players_button",
        {
            text = mod:localize("button_list_players"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            }
        }
    ),
    
    close_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "close_button",
        {
            text = mod:localize("button_close"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            }
        }
    ),
    
    players_panel = UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_background(255, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "texture",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = {
                vertical_alignment = "center",
                horizontal_alignment = "center",
                color = Color.terminal_frame(255, true),
                offset = { 0, 0, 2 }
            }
        }
    }, "players_panel", {
        visible = false  -- Start hidden
    }),
    
    players_panel_title = UIWidget.create_definition({
        {
            pass_type = "text",
            value = mod:localize("players_list_title"),
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 20,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 1 }
            }
        }
    }, "players_panel_title", {
        visible = false  -- Start hidden
    }),
    
    players_list = UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_background_gradient(180, true),
                offset = { 0, 0, 0 }
            }
        },
        {
            pass_type = "text",
            value_id = "list_text",
            value = "",
            style = {
                text_vertical_alignment = "top",
                text_horizontal_alignment = "left",
                font_type = "machine_medium",
                font_size = 14,
                text_color = Color.terminal_text_body(255, true),
                offset = { 50, 10, 1 }  -- Offset to make room for color swatches
            }
        },
        -- Color swatches for up to 15 players
        {
            pass_type = "rect",
            value_id = "color_swatch_1",
            style_id = "color_swatch_1",
            style = {
                color = Color.white(255, true),
                offset = { 10, 10, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_2",
            style_id = "color_swatch_2",
            style = {
                color = Color.white(255, true),
                offset = { 10, 40, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_3",
            style_id = "color_swatch_3",
            style = {
                color = Color.white(255, true),
                offset = { 10, 70, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_4",
            style_id = "color_swatch_4",
            style = {
                color = Color.white(255, true),
                offset = { 10, 100, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_5",
            style_id = "color_swatch_5",
            style = {
                color = Color.white(255, true),
                offset = { 10, 130, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_6",
            style_id = "color_swatch_6",
            style = {
                color = Color.white(255, true),
                offset = { 10, 160, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_7",
            style_id = "color_swatch_7",
            style = {
                color = Color.white(255, true),
                offset = { 10, 190, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_8",
            style_id = "color_swatch_8",
            style = {
                color = Color.white(255, true),
                offset = { 10, 220, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_9",
            style_id = "color_swatch_9",
            style = {
                color = Color.white(255, true),
                offset = { 10, 250, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_10",
            style_id = "color_swatch_10",
            style = {
                color = Color.white(255, true),
                offset = { 10, 280, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_11",
            style_id = "color_swatch_11",
            style = {
                color = Color.white(255, true),
                offset = { 10, 310, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_12",
            style_id = "color_swatch_12",
            style = {
                color = Color.white(255, true),
                offset = { 10, 340, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_13",
            style_id = "color_swatch_13",
            style = {
                color = Color.white(255, true),
                offset = { 10, 370, 2 },
                size = { 30, 20 }
            }
        },
        {
            pass_type = "rect",
            value_id = "color_swatch_14",
            style_id = "color_swatch_14",
            style = {
                color = Color.white(255, true),
                offset = { 10, 400, 2 },
                size = { 30, 20 }
            }
        },
        -- Hotspots for clicking player entries (one per line, covers the text area)
        {
            pass_type = "hotspot",
            content_id = "player_entry_1",
            style = {
                offset = { 50, 10, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_2",
            style = {
                offset = { 50, 40, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_3",
            style = {
                offset = { 50, 70, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_4",
            style = {
                offset = { 50, 100, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_5",
            style = {
                offset = { 50, 130, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_6",
            style = {
                offset = { 50, 160, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_7",
            style = {
                offset = { 50, 190, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_8",
            style = {
                offset = { 50, 220, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_9",
            style = {
                offset = { 50, 250, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_10",
            style = {
                offset = { 50, 280, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_11",
            style = {
                offset = { 50, 310, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_12",
            style = {
                offset = { 50, 340, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_13",
            style = {
                offset = { 50, 370, 10 },
                size = { 400, 20 }
            }
        },
        {
            pass_type = "hotspot",
            content_id = "player_entry_14",
            style = {
                offset = { 50, 400, 10 },
                size = { 400, 20 }
            }
        }
    }, "players_list", {
        visible = false  -- Start hidden
    }),
    
    page_info_text = UIWidget.create_definition({
        {
            pass_type = "text",
            value_id = "text",
            value = "",
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "center",
                font_type = "machine_medium",
                font_size = 14,
                text_color = Color.terminal_text_body(255, true),
                offset = { 0, 0, 1 }
            }
        }
    }, "page_info_text", {
        visible = false  -- Start hidden
    }),
    
    prev_page_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "prev_page_button",
        {
            text = mod:localize("button_prev_page"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            },
            visible = false  -- Start hidden
        }
    ),
    
    next_page_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "next_page_button",
        {
            text = mod:localize("button_next_page"),
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            },
            visible = false  -- Start hidden
        }
    ),
    
    close_panel_button = UIWidget.create_definition(
        ButtonPassTemplates.terminal_button_small,
        "close_panel_button",
        {
            text = "X",
            hotspot = {
                on_pressed_sound = UISoundEvents.default_click
            },
            visible = false  -- Start hidden
        }
    )
}

-- Legend inputs
local legend_inputs = {
    {
        input_action = "back",
        on_pressed_callback = "_on_back_pressed",
        display_name = "loc_class_selection_button_back",
        alignment = "left_alignment"
    }
}

return {
    scenegraph_definition = scenegraph_definition,
    widget_definitions = widget_definitions,
    legend_inputs = legend_inputs,
}

