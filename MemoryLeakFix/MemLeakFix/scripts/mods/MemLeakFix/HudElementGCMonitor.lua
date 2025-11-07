-- @Author: 我是派蒙啊
-- @Date:   2024-10-31 17:54:33
-- @Last Modified by:   我是派蒙啊
-- @Last Modified time: 2024-10-31 19:02:08
local mod = get_mod("MemLeakFix")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local definitions = {
    scenegraph_definition = {
        screen           = UIWorkspaceSettings.screen,
        gcmonitor_layout = {
            parent = "screen",
            size = { 200, 50 },
            vertical_alignment = "top",
            horizontal_alignment = "left",
            position = { 20, 200, 100 },
        }
    },
    widget_definitions = {
        gcmonitor_label = UIWidget.create_definition({
            {
                pass_type = "text",
                value = "",
                value_id = "gcmsg",
                style_id = "gcmsg",
                style = {
                    font_type = "machine_medium",
                    font_size = 23,
                    drop_shadow = true,
                    text_vertical_alignment = "top",
                    text_horizontal_alignment = "left",
                    text_color = { 255, 255, 255, 255 },
                    offset = { 0, 0, 100 },
                }
            }
        }, "gcmonitor_layout")
    }
}

HudElementGCMonitor = class("HudElementGCMonitor", "HudElementBase")

function HudElementGCMonitor:init(parent, draw_layer, start_scale)
    HudElementGCMonitor.super.init(self, parent, draw_layer, start_scale, definitions)
end

local countdown = 1.0 -- mod:get("duration")
-- local last_memory = math.ceil(collectgarbage("count") / 1024) or 0
HudElementGCMonitor.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    HudElementGCMonitor.super.update(self, dt, t, ui_renderer, render_settings, input_service)
    if countdown > 0 then
        countdown = countdown - dt
        return
    end

    countdown = 1.0 -- mod:get("duration")
    local memory = math.ceil(collectgarbage("count") / 1024) or 0
    -- mod:echo("内存(新/旧): " .. last_memory .. "MB/" .. memory .. "MB")
    self._widgets_by_name.gcmonitor_label.content.gcmsg = string.format("%s: %.0fMB", mod:localize("memory"), memory)
    -- last_memory = memory
end

return HudElementGCMonitor
