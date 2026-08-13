-- huntsalvage_hud.lua
local mod = get_mod("huntsalvage")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local COUNT_YELLOW = {
255,
255,
230,
0,
}
local COUNT_RED = {
255,
255,
54,
36,
}
local function set_colour(dst, src)
if not dst or not src then
return
end
dst[1] = src[1]
dst[2] = src[2]
dst[3] = src[3]
dst[4] = src[4]
end
local scenegraph_definition = {
screen = UIWorkspaceSettings.screen,
salvage_count = {
parent = "screen",
horizontal_alignment = "left",
vertical_alignment = "center",
size = {
180,
50,
},
position = {
22,
0,
40,
},
},
salvage_completed = {
parent = "screen",
horizontal_alignment = "center",
vertical_alignment = "center",
size = {
1000,
160,
},
position = {
0,
0,
80,
},
},
}
local widget_definitions = {
count = UIWidget.create_definition({
{
pass_type = "text",
style_id = "text",
value = "0/0",
value_id = "text",
style = {
horizontal_alignment = "left",
vertical_alignment = "center",
text_horizontal_alignment = "left",
text_vertical_alignment = "center",
offset = {
0,
0,
1,
},
font_type = "machine_medium",
font_size = 33,
text_color = {
255,
255,
230,
0,
},
size = {
180,
50,
},
},
visibility_function = function ()
return mod:is_count_visible()
end,
},
}, "salvage_count"),
completed = UIWidget.create_definition({
{
pass_type = "text",
style_id = "text",
value = "Last sanctuary",
value_id = "text",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
offset = {
0,
-24,
1,
},
font_type = "machine_medium",
font_size = 58,
text_color = {
255,
255,
174,
0,
},
size = {
1000,
80,
},
},
visibility_function = function ()
return mod:is_completion_flash_visible()
end,
},
{
pass_type = "text",
style_id = "subtitle",
value = "No salvage in next zone",
value_id = "subtitle",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
offset = {
0,
34,
1,
},
font_type = "machine_medium",
font_size = 34,
text_color = {
255,
255,
174,
0,
},
size = {
1000,
60,
},
},
visibility_function = function ()
return mod:is_completion_flash_visible()
end,
},
}, "salvage_completed"),
}
local Definitions = {
scenegraph_definition = scenegraph_definition,
widget_definitions = widget_definitions,
}
local HuntSalvageHudElement = class("HuntSalvageHudElement", "HudElementBase")
HuntSalvageHudElement.init = function (self, parent, draw_layer, start_scale)
HuntSalvageHudElement.super.init(self, parent, draw_layer, start_scale, Definitions)
end
HuntSalvageHudElement.update = function (self, dt, t, ui_renderer, render_settings, input_service)
HuntSalvageHudElement.super.update(self, dt, t, ui_renderer, render_settings, input_service)
local widgets = self._widgets_by_name
local count_widget = widgets and widgets.count
if count_widget then
count_widget.content.text = mod:salvage_counter_text()
count_widget.visible = mod:is_count_visible()
local text_style = count_widget.style and count_widget.style.text
if text_style then
set_colour(text_style.text_color, mod:is_final_zone_counter() and COUNT_RED or COUNT_YELLOW)
end
end
local completed_widget = widgets and widgets.completed
if completed_widget then
completed_widget.visible = mod:is_completion_flash_visible()
end
end
return HuntSalvageHudElement