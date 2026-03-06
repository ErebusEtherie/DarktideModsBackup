local mod = get_mod("FaithMeter")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

-- FaithMeter HUD (visual-only v1)
-- Uses only built-in UI materials for maximum compatibility.

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    faith_meter_root = {
        parent = "screen",
        scale = "hud_scale",
        vertical_alignment = "bottom",
        horizontal_alignment = "left",
        size = { 260, 56 },
        -- Tuned to sit near the default lower-left player HUD cluster.
        position = { 210, -92, 60 },
    },

    -- Dual-bar layout (Pressure left, Faith right). Kept separate from the classic widget so the
    -- classic layout remains untouched unless explicitly selected in options.
    faith_meter_dual_root = {
        parent = "screen",
        scale = "hud_scale",
        vertical_alignment = "bottom",
        horizontal_alignment = "left",
        size = { 220, 170 },
        position = { 210, -92, 60 },
    },
}

local function is_enabled()
    return mod:get("hud_enabled")
end

local function show_label()
    return is_enabled() and mod:get("hud_show_text")
end

local function show_label_classic()
    return show_label() and is_classic_layout()
end

local function show_label_dual()
    return show_label() and is_dual_layout()
end

local function is_dual_layout()
    return is_enabled() and (mod:get("hud_layout") == 2)
end

local function is_classic_layout()
    return is_enabled() and (mod:get("hud_layout") ~= 2)
end

local function show_debug()
    return mod:get("debug_special_pressure")
end

local function show_debug_classic()
    return show_debug() and is_classic_layout()
end

local function show_debug_dual()
    return show_debug() and is_dual_layout()
end

local function show_debug_classic()
    return show_debug() and is_classic_layout()
end

local function show_debug_dual()
    return show_debug() and is_dual_layout()
end

local widget_definitions = {
    faith_meter = UIWidget.create_definition({
        -- Soft outer glow (alpha/intensity set in update)
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style_id = "glow",
            style = {
                color = { 0, 255, 255, 255 }, -- updated per-frame
                size = { 240, 48 },
                offset = { 0, 4, 0 },
            },
            visibility_function = is_classic_layout,
        },
        -- Plate background
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/terminal_basic",
            style_id = "plate_bg",
            style = {
                color = { 170, 10, 10, 10 },
                size = { 240, 48 },
                offset = { 0, 4, 1 },
            },
            visibility_function = is_classic_layout,
        },
        -- Icon (built-in aquila)
        {
            pass_type = "texture",
            value = "content/ui/materials/icons/generic/aquila",
            style_id = "icon",
            style = {
                color = { 255, 235, 220, 170 }, -- updated per-frame
                size = { 34, 34 },
                offset = { 10, 11, 3 },
            },
            visibility_function = is_classic_layout,
        },
        -- Bar background
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style_id = "bar_bg",
            style = {
                color = { 200, 0, 0, 0 },
                size = { 170, 10 },
                offset = { 54, 25, 2 },
            },
            visibility_function = is_classic_layout,
        },
        -- Bar fill (size and color updated per-frame)
        {
            pass_type = "rect",
            style_id = "bar_fill",
            style = {
                color = { 220, 235, 220, 170 },
                size = { 170, 10 },
                offset = { 54, 25, 3 },
            },
            visibility_function = is_classic_layout,
        },
        -- Label
        {
            pass_type = "text",
            value_id = "label_text",
            style_id = "label",
            style = {
                font_type = "machine_medium",
                font_size = 16,
                text_color = { 220, 235, 220, 170 }, -- updated per-frame
                offset = { 54, 6, 3 },
                size = { 170, 18 },
                text_horizontal_alignment = "left",
                text_vertical_alignment = "top",
                drop_shadow = true,
            },
            visibility_function = function()
                return is_classic_layout() and show_label()
            end,
        },
-- Flavor line (brief message on state change)
{
    pass_type = "text",
    value_id = "flavor_text",
    style_id = "flavor",
    style = {
        font_type = "machine_medium",
        font_size = 14,
        text_color = { 200, 235, 220, 170 }, -- updated per-frame
        offset = { 54, 40, 3 },
        size = { 190, 18 },
        text_horizontal_alignment = "left",
        text_vertical_alignment = "top",
        drop_shadow = true,
    },
    visibility_function = function()
        return is_classic_layout() and show_label()
    end,
},

        -- Debug line (special pressure, optional)
        {
            pass_type = "text",
            value_id = "debug_text",
            style_id = "debug",
            style = {
                font_type = "machine_medium",
                font_size = 12,
                text_color = { 180, 200, 200, 200 },
                offset = { 54, -12, 4 },
                size = { 250, 16 },
                text_horizontal_alignment = "left",
                text_vertical_alignment = "top",
                drop_shadow = true,
            },
            visibility_function = function()
                return is_classic_layout() and show_debug()
            end,
        },
    }, "faith_meter_root", { label_text = "FAITH", flavor_text = "" }),

    -- -----------------------------------------------------
    -- Dual-bars widget (Pressure left, Faith right)
    -- -----------------------------------------------------
    faith_meter_dual = UIWidget.create_definition({
        -- Plate background (optional; off by default for the dual-bar layout)
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/terminal_basic",
            style_id = "dual_plate_bg",
            style = {
                color = { 170, 10, 10, 10 },
                size = { 220, 170 },
                offset = { 0, 0, 1 },
            },
            visibility_function = function()
                return is_dual_layout() and (mod:get("dual_bar_background") == true)
            end,
        },
        -- Center emblem (subtle)
        {
            pass_type = "texture",
            value = "content/ui/materials/icons/generic/aquila",
            style_id = "dual_icon",
            style = {
                color = { 140, 235, 220, 170 },
                size = { 40, 40 },
                offset = { 90, 112, 3 },
            },
            visibility_function = is_dual_layout,
        },
        -- Pressure bar background (left)
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style_id = "pressure_bg",
            style = {
                color = { 200, 0, 0, 0 },
                size = { 22, 120 },
                offset = { 52, 28, 2 },
            },
            visibility_function = is_dual_layout,
        },
        -- Faith bar background (right)
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style_id = "faith_bg_v",
            style = {
                color = { 200, 0, 0, 0 },
                size = { 22, 120 },
                offset = { 146, 28, 2 },
            },
            visibility_function = is_dual_layout,
        },
        -- Pressure fill (size/color updated per-frame)
        {
            pass_type = "rect",
            style_id = "pressure_fill",
            style = {
                color = { 210, 140, 60, 40 },
                size = { 22, 0 },
                offset = { 52, 28, 3 },
            },
            visibility_function = is_dual_layout,
        },
        -- Faith fill (size/color updated per-frame)
        {
            pass_type = "rect",
            style_id = "faith_fill_v",
            style = {
                color = { 220, 235, 220, 170 },
                size = { 22, 0 },
                offset = { 146, 28, 3 },
            },
            visibility_function = is_dual_layout,
        },
        -- Label / state text (reuses existing content fields)
        {
            pass_type = "text",
            value_id = "label_text",
            style_id = "dual_label",
            style = {
                font_type = "machine_medium",
                font_size = 16,
                text_color = { 220, 235, 220, 170 },
                -- Centered above both bars
                offset = { 0, 5, 4 },
                size = { 220, 18 },
                text_horizontal_alignment = "center",
                text_vertical_alignment = "top",
                drop_shadow = true,
            },
            visibility_function = function()
                return is_dual_layout() and show_label()
            end,
        },
        -- Flavor line
        {
            pass_type = "text",
            value_id = "flavor_text",
            style_id = "dual_flavor",
            style = {
                font_type = "machine_medium",
                font_size = 14,
                text_color = { 200, 235, 220, 170 },
                -- Slight right shift for better balance under the bars
                offset = { 24, 152, 4 },
                size = { 200, 18 },
                text_horizontal_alignment = "left",
                text_vertical_alignment = "top",
                drop_shadow = true,
            },
            visibility_function = function()
                return is_dual_layout() and show_label()
            end,
        },
        -- Debug (same content id)
        {
            pass_type = "text",
            value_id = "debug_text",
            style_id = "dual_debug",
            style = {
                font_type = "machine_medium",
                font_size = 12,
                text_color = { 180, 200, 200, 200 },
                offset = { 18, -12, 4 },
                size = { 240, 28 },
                text_horizontal_alignment = "left",
                text_vertical_alignment = "top",
                drop_shadow = true,
            },
            visibility_function = function()
                return is_dual_layout() and show_debug()
            end,
        },
    }, "faith_meter_dual_root", { label_text = "FAITH", flavor_text = "" }),
}

return {
    scenegraph_definition = scenegraph_definition,
    widget_definitions = widget_definitions,
}
