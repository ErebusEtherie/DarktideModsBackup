local mod = get_mod("kill_counter")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local font_size = 24
local size = { 260, font_size + 8 }

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    counter_container = {
        parent = "screen",
        scale = "fit",
        vertical_alignment = "top",
        horizontal_alignment = "right",
        size = size,
        position = { -42, 8, 10 },
    },
}

local style_counter = {
    line_spacing = 1.1,
    font_size = font_size,
    drop_shadow = true,
    font_type = "machine_medium",
    text_color = { 200, 230, 235, 240 },
    size = size,
    text_horizontal_alignment = "right",
    text_vertical_alignment = "center",
}

local widget_definitions = {
    kill_counter = UIWidget.create_definition({
        {
            value_id = "text",
            style_id = "text",
            pass_type = "text",
            value = "",
            style = style_counter,
        },
    }, "counter_container"),
}

local HudElementKillCounter = class("HudElementKillCounter", "HudElementBase")

local function is_in_hub()
    local state = Managers and Managers.state
    local game_mode_manager = state and state.game_mode
    if not game_mode_manager then
        return false
    end

    local game_mode_name = game_mode_manager:game_mode_name()
    return game_mode_name == "hub" or game_mode_name == "prologue_hub"
end

HudElementKillCounter.init = function(self, parent, draw_layer, start_scale)
    HudElementKillCounter.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })
end

HudElementKillCounter.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    HudElementKillCounter.super.update(self, dt, t, ui_renderer, render_settings, input_service)

    local widget = self._widgets_by_name.kill_counter
    if is_in_hub() then
        widget.content.text = ""
        return
    end

    widget.content.text = string.format("Kills  %d", mod.kill_counter or 0)
end

return HudElementKillCounter
