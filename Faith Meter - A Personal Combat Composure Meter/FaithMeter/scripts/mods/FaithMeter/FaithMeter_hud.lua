local mod = get_mod("FaithMeter")

local CLASS = CLASS
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

-- This file is a legacy/optional HUD injection into Tactical Overlay.
-- The primary FaithMeter HUD is registered via mod:register_hud_element in FaithMeter.lua.
-- We keep this file stable (no syntax errors) to avoid accidental load-time breakage.

local BASE_Z = 100
local BASE_SIZE = { 240, 44 }
local BAR_MAX_W = 175
local BAR_H = 12

-- ---------------------------------------------------------
-- Tactical Overlay: inject a simple widget definition
-- ---------------------------------------------------------
mod:hook_require("scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay_definitions", function(definitions)
    local sg = definitions.scenegraph_definition
    sg.faith_meter = {
        vertical_alignment = "bottom",
        horizontal_alignment = "left",
        parent = "screen",
        size = { BASE_SIZE[1], BASE_SIZE[2] },
        position = { 100, 200, BASE_Z },
    }

    local widget_def = {
        scenegraph_id = "faith_meter",
        element = {
            passes = {
                -- Background
                {
                    pass_type = "rect",
                    style = {
                        vertical_alignment = "center",
                        horizontal_alignment = "left",
                        offset = { 50, 0, 1 },
                        size = { BAR_MAX_W, BAR_H },
                        color = { 200, 15, 15, 15 },
                    },
                },
                -- Fill
                {
                    pass_type = "rect",
                    style_id = "bar_fill",
                    style = {
                        vertical_alignment = "center",
                        horizontal_alignment = "left",
                        offset = { 50, 0, 2 },
                        size = { 0, BAR_H },
                        color = { 220, 210, 180, 120 },
                    },
                },
                -- Text label
                {
                    pass_type = "text",
                    value_id = "label",
                    value = "",
                    style = {
                        vertical_alignment = "center",
                        horizontal_alignment = "left",
                        offset = { 50, -14, 4 },
                        font_type = "proxima_nova_bold",
                        font_size = 16,
                        text_color = { 255, 220, 205, 170 },
                    },
                },
            },
        },
        content = {
            label = "",
        },
    }

    definitions.widget_definitions.faith_meter = UIWidget.create_definition(widget_def, "faith_meter")
end)

-- ---------------------------------------------------------
-- Tactical Overlay: update widget values
-- ---------------------------------------------------------
mod:hook(CLASS.HudElementTacticalOverlay, "update", function(func, self, dt, t, ui_renderer, render_settings, input_service, ...)
    func(self, dt, t, ui_renderer, render_settings, input_service, ...)

    local widgets = self._widgets_by_name
    local widget = widgets and widgets.faith_meter
    if not widget then
        return
    end

    local enabled = mod:get("hud_enabled") == true
    widget.visible = enabled
    if not enabled then
        return
    end

    -- Optional label
    if mod:get("hud_show_text") == true then
        widget.content.label = mod:localize("hud_faith")
    else
        widget.content.label = ""
    end

    -- Faith is maintained by FaithMeter.lua; prefer get_faith_norm if available.
    local frac = 0
    if mod.get_faith_norm then
        frac = mod:get_faith_norm()
    elseif mod.get_faith then
        frac = math.max(0, math.min(1, (mod:get_faith() or 0) / 100))
    end

    local style = widget.style
    if style and style.bar_fill and style.bar_fill.size then
        style.bar_fill.size[1] = math.floor(BAR_MAX_W * frac + 0.5)
    end

    -- Optional positioning/scaling (best-effort; does not assume scenegraph mutability)
    local ox = mod:get("hud_offset_x")
    local oy = mod:get("hud_offset_y")
    if type(ox) == "number" and type(oy) == "number" then
        widget.offset[1] = ox
        widget.offset[2] = oy
    end
end)
