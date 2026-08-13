-- salvage_evac.lua
local mod = get_mod("salvage")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local WARNING_ID = "early_evacuation"
local PLAYER_DROP_WARNING_ID = "player_drop_worth"
local LAST_SANCTUARY_WARNING_ID = "last_sanctuary"
local EVENT_SHOW = "salvage_show_early_evacuation_warning"
local EVENT_CLEAR = "salvage_clear_early_evacuation_warning"
local PLAYER_DROP_EVENT_SHOW = "salvage_show_player_drop_worth_warning"
local UI_RED_LIGHT = { 255, 255, 54, 36 }
local UI_DROP_ORANGE = { 255, 255, 84, 0 }
local early_warning_expiry = 0
local last_sanctuary_warning_expiry = 0
local player_drop_worth_expiry = 0
local function current_time()
local time_manager = Managers and Managers.time or nil
if time_manager and type(time_manager.time) == "function" then
local ok, value = pcall(time_manager.time, time_manager, "main")
if ok and type(value) == "number" then
return value
end
end
return 0
end
local function warning_enabled()
return mod and type(mod.get) == "function" and mod:get("warn_early_evacuation") == true
end
local function last_sanctuary_warning_enabled()
return mod and type(mod.get) == "function" and mod:get("last_sanctuary_warning") == true
end
local function warning_visible()
return warning_enabled() and early_warning_expiry > current_time()
end
local function last_sanctuary_warning_visible()
return last_sanctuary_warning_enabled() and last_sanctuary_warning_expiry > current_time()
end
local function player_drop_worth_visible()
return player_drop_worth_expiry > current_time()
end
local scenegraph_definition = {
screen = UIWorkspaceSettings.screen,
early_evacuation_warning = {
horizontal_alignment = "center",
parent = "screen",
vertical_alignment = "center",
size = {
1400,
140,
},
position = {
0,
0,
100,
},
},
last_sanctuary_warning = {
horizontal_alignment = "center",
parent = "screen",
vertical_alignment = "center",
size = {
1200,
160,
},
position = {
0,
0,
101,
},
},
player_drop_worth_warning = {
horizontal_alignment = "center",
parent = "screen",
vertical_alignment = "center",
size = {
1100,
120,
},
position = {
0,
0,
101,
},
},
}
local widget_definitions = {
early_evacuation_warning = UIWidget.create_definition({
{
pass_type = "text",
style_id = "text",
value = "Evacuation triggered early",
value_id = "text",
style = {
font_type = "rexlia",
font_size = 70,
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
text_color = UI_RED_LIGHT,
offset = {
0,
0,
1,
},
},
visibility_function = warning_visible,
},
}, "early_evacuation_warning"),
last_sanctuary_warning = UIWidget.create_definition({
{
pass_type = "text",
style_id = "main_text",
value = "Last sanctuary",
value_id = "main_text",
style = {
font_type = "rexlia",
font_size = 58,
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
text_color = UI_DROP_ORANGE,
offset = {
0,
-18,
1,
},
},
visibility_function = last_sanctuary_warning_visible,
},
{
pass_type = "text",
style_id = "sub_text",
value = "No salvage in next zone",
value_id = "sub_text",
style = {
font_type = "rexlia",
font_size = 34,
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
text_color = UI_DROP_ORANGE,
offset = {
0,
34,
1,
},
},
visibility_function = last_sanctuary_warning_visible,
},
}, "last_sanctuary_warning"),
player_drop_worth_warning = UIWidget.create_definition({
{
pass_type = "text",
style_id = "text",
value = "",
value_id = "text",
style = {
font_type = "rexlia",
font_size = 38,
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
text_color = UI_DROP_ORANGE,
offset = {
0,
0,
1,
},
},
visibility_function = player_drop_worth_visible,
},
}, "player_drop_worth_warning"),
}
local Definitions = {
scenegraph_definition = scenegraph_definition,
widget_definitions = widget_definitions,
}
local HudElementSalvageEarlyEvacuationWarning = class("HudElementSalvageEarlyEvacuationWarning", "HudElementBase")
HudElementSalvageEarlyEvacuationWarning.init = function(self, parent, draw_layer, start_scale)
HudElementSalvageEarlyEvacuationWarning.super.init(self, parent, draw_layer, start_scale, Definitions)
self:_register_event(EVENT_SHOW, "show_warning")
self:_register_event(EVENT_CLEAR, "clear_warning")
self:_register_event(PLAYER_DROP_EVENT_SHOW, "show_player_drop_worth_warning")
end
HudElementSalvageEarlyEvacuationWarning.show_warning = function(self, warning_id, duration_seconds)
local id = type(warning_id) == "string" and warning_id ~= "" and warning_id or WARNING_ID
local duration = tonumber(duration_seconds) or 1.5
if id == WARNING_ID then
early_warning_expiry = current_time() + duration
elseif id == LAST_SANCTUARY_WARNING_ID then
last_sanctuary_warning_expiry = current_time() + duration
end
self:set_dirty()
end
HudElementSalvageEarlyEvacuationWarning.show_player_drop_worth_warning = function(self, amount, duration_seconds)
local numeric_amount = math.abs(tonumber(amount) or 0)
if numeric_amount <= 0 then
return
end
local duration = tonumber(duration_seconds) or 1.5
player_drop_worth_expiry = current_time() + duration
local widget = self._widgets_by_name and self._widgets_by_name.player_drop_worth_warning
if widget then
widget.content.text = "Remnants dropped: " .. tostring(math.floor(numeric_amount + 0.5))
end
self:set_dirty()
end
HudElementSalvageEarlyEvacuationWarning.clear_warning = function(self, warning_id)
local id = type(warning_id) == "string" and warning_id ~= "" and warning_id or WARNING_ID
if id == WARNING_ID then
early_warning_expiry = 0
elseif id == LAST_SANCTUARY_WARNING_ID then
last_sanctuary_warning_expiry = 0
elseif id == PLAYER_DROP_WARNING_ID then
player_drop_worth_expiry = 0
end
self:set_dirty()
end
return HudElementSalvageEarlyEvacuationWarning