-- swagger_hud.lua
local mod = get_mod("swagger")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
require("scripts/ui/hud/elements/hud_element_base")
local get_hud_color = UIHudSettings.get_hud_color
local PANEL_WIDTH = 300
local PANEL_HEIGHT = 88
local TOP_HEIGHT = 34
local scenegraph_definition = {
screen = UIWorkspaceSettings.screen,
prompt = {
horizontal_alignment = "left",
parent = "screen",
vertical_alignment = "top",
size = {
PANEL_WIDTH,
PANEL_HEIGHT,
},
position = {
0,
0,
100,
},
},
notice = {
horizontal_alignment = "center",
parent = "screen",
vertical_alignment = "center",
size = {
600,
80,
},
position = {
0,
110,
100,
},
},
}
local top_text_style = table.clone(UIFontSettings.hud_body)
top_text_style.font_size = 20
top_text_style.horizontal_alignment = "left"
top_text_style.vertical_alignment = "top"
top_text_style.text_horizontal_alignment = "left"
top_text_style.text_vertical_alignment = "center"
top_text_style.text_color = get_hud_color("color_tint_main_1", 255)
top_text_style.size = {
PANEL_WIDTH - 20,
TOP_HEIGHT,
}
top_text_style.offset = {
10,
0,
6,
}
local bottom_text_style = table.clone(UIFontSettings.hud_body)
bottom_text_style.font_size = 22
bottom_text_style.horizontal_alignment = "left"
bottom_text_style.vertical_alignment = "bottom"
bottom_text_style.text_horizontal_alignment = "left"
bottom_text_style.text_vertical_alignment = "center"
bottom_text_style.text_color = get_hud_color("color_tint_main_1", 255)
bottom_text_style.size = {
PANEL_WIDTH - 20,
PANEL_HEIGHT - TOP_HEIGHT,
}
bottom_text_style.offset = {
10,
0,
6,
}
local notice_text_style = table.clone(UIFontSettings.hud_body)
notice_text_style.font_size = 36
notice_text_style.horizontal_alignment = "center"
notice_text_style.vertical_alignment = "center"
notice_text_style.text_horizontal_alignment = "center"
notice_text_style.text_vertical_alignment = "center"
notice_text_style.text_color = get_hud_color("color_tint_main_1", 255)
notice_text_style.offset = {
0,
0,
6,
}
local widget_definitions = {
prompt = UIWidget.create_definition({
{
pass_type = "texture",
style_id = "background",
value = "content/ui/materials/hud/backgrounds/interaction_background",
style = {
horizontal_alignment = "center",
scale_to_material = true,
vertical_alignment = "center",
color = get_hud_color("color_tint_main_4", 230),
offset = {
0,
0,
0,
},
},
},
{
pass_type = "rect",
style_id = "top_strip",
style = {
horizontal_alignment = "center",
vertical_alignment = "top",
size = {
PANEL_WIDTH,
TOP_HEIGHT,
},
color = {
180,
121,
136,
109,
},
offset = {
0,
0,
1,
},
},
},
{
pass_type = "texture",
style_id = "frame",
value = "content/ui/materials/frames/dropshadow_medium",
style = {
horizontal_alignment = "center",
scale_to_material = true,
vertical_alignment = "center",
color = {
255,
0,
0,
0,
},
size_addition = {
20,
20,
},
offset = {
0,
0,
3,
},
},
},
{
pass_type = "text",
style_id = "top_text",
value = "",
value_id = "top_text",
style = top_text_style,
},
{
pass_type = "text",
style_id = "bottom_text",
value = "",
value_id = "bottom_text",
style = bottom_text_style,
},
}, "prompt"),
notice = UIWidget.create_definition({
{
pass_type = "text",
style_id = "text",
value = "",
value_id = "text",
style = notice_text_style,
},
}, "notice"),
}
local Definitions = {
scenegraph_definition = scenegraph_definition,
widget_definitions = widget_definitions,
}
local SwaggerBackupHud = class("SwaggerBackupHud", "HudElementBase")
SwaggerBackupHud.init = function(self, parent, draw_layer, start_scale)
SwaggerBackupHud.super.init(self, parent, draw_layer, start_scale, Definitions)
self._player = parent:player()
self._widgets_by_name.prompt.visible = false
self._widgets_by_name.notice.visible = false
end
SwaggerBackupHud.update = function(self, dt, t, ui_renderer, render_settings, input_service)
SwaggerBackupHud.super.update(self, dt, t, ui_renderer, render_settings, input_service)
local prompt_widget = self._widgets_by_name.prompt
local prompt_data = mod.swagger_prompt_data and mod.swagger_prompt_data() or nil
local visible = false
if prompt_data and prompt_data.world_position then
local ok_camera, camera = pcall(function()
return self._parent and self._parent:player_camera()
end)
if ok_camera and camera then
local ok_screen, screen_position, distance = pcall(Camera.world_to_screen, camera, prompt_data.world_position)
local ok_frustum, inside_frustum = pcall(Camera.inside_frustum, camera, prompt_data.world_position)
if ok_screen and screen_position and type(distance) == "number" and distance > 0 and ok_frustum and type(inside_frustum) == "number" and inside_frustum > 0 then
local x = screen_position.x
local y = screen_position.y
if type(x) == "number" and type(y) == "number" and x == x and y == y and x < math.huge and x > -math.huge and y < math.huge and y > -math.huge then
local inverse_scale = ui_renderer and ui_renderer.inverse_scale or 1
prompt_widget.offset[1] = x * inverse_scale - PANEL_WIDTH * 0.5
prompt_widget.offset[2] = y * inverse_scale - PANEL_HEIGHT - 18
prompt_widget.content.top_text = prompt_data.top_text or ""
prompt_widget.content.bottom_text = prompt_data.bottom_text or ""
prompt_widget.dirty = true
visible = true
end
end
end
end
if prompt_widget.visible ~= visible then
prompt_widget.visible = visible
prompt_widget.dirty = true
end
local notice_widget = self._widgets_by_name.notice
local notice_text = mod.swagger_backup_notice and mod.swagger_backup_notice() or nil
local notice_visible = notice_text ~= nil
if notice_widget.visible ~= notice_visible then
notice_widget.visible = notice_visible
notice_widget.dirty = true
end
if notice_text and notice_widget.content.text ~= notice_text then
notice_widget.content.text = notice_text
notice_widget.dirty = true
end
end
return SwaggerBackupHud