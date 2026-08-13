-- SMOG_Cont.lua
local mod = get_mod("SMOG")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local file_dofile = Mods.file.dofile
local Common
do
local Managers = Managers
local Gui = Gui
local Vector3 = Vector3
local pcall = pcall
local type = type
local math_max = math.max
local utf8_string_length = Utf8 and Utf8.string_length
local font_path_cache = {}
Common = {}
function Common.clamp(value,low,high)
if value < low then
return low
elseif value > high then
return high
end
return value
end
function Common.font_path(font_type,fallback_type)
local cached = font_path_cache[font_type]
if cached then
return cached
end
local font_manager = Managers and Managers.font
if not font_manager or not font_manager.data_by_type then
return nil
end
local ok,font_data = pcall(font_manager.data_by_type,font_manager,font_type)
if ok and font_data and font_data.path then
font_path_cache[font_type] = font_data.path
return font_data.path
end
local fallback = fallback_type or "arial"
ok,font_data = pcall(font_manager.data_by_type,font_manager,fallback)
if ok and font_data and font_data.path then
font_path_cache[font_type] = font_data.path
return font_data.path
end
return nil
end
function Common.text_width(gui,text,font,font_size)
if Gui and Gui.slug_text_extents then
local ok,min,max = pcall(Gui.slug_text_extents,gui,text,font,font_size)
if ok and min and max then
return max[1] - min[1]
end
end
local fallback_text = text or ""
if utf8_string_length then
local ok,length = pcall(utf8_string_length,fallback_text)
if ok and length then
return length * font_size * 0.55
end
end
return #fallback_text * font_size * 0.55
end
function Common.position(owner,screen_width,screen_height,scale,outer_radius)
local radius = outer_radius or 72 * scale
local x_axis = Common.clamp(mod._smog_hud_x_axis or 10,0,100)
local y_axis = Common.clamp(mod._smog_hud_y_axis or 30,0,100)
local cached = owner._smog_position_cache
if cached and cached.screen_width == screen_width and cached.screen_height == screen_height and cached.scale == scale and cached.radius == radius and cached.x_axis == x_axis and cached.y_axis == y_axis then
return cached.cx,cached.cy
end
local horizontal_margin = radius + 18 * scale
local top_margin = radius + 30 * scale
local bottom_margin = 48 * scale
local available_x = math_max(screen_width - horizontal_margin * 2,0)
local available_y = math_max(screen_height - top_margin - bottom_margin,0)
local cx = horizontal_margin + available_x * x_axis * 0.01
local cy = top_margin + available_y * y_axis * 0.01
owner._smog_position_cache = {
screen_width = screen_width,
screen_height = screen_height,
scale = scale,
radius = radius,
x_axis = x_axis,
y_axis = y_axis,
cx = cx,
cy = cy,
}
return cx,cy
end
function Common.context_allowed()
if mod and mod.is_enabled and not mod:is_enabled() then
return false
end
local snapshot = mod and mod._smog_context_snapshot
return type(snapshot) == "table" and snapshot.hud_allowed == true
end
function Common.draw_text(gui,text,font,font_size,x,y,layer,color)
Gui.slug_text(gui,text,font,font_size,Vector3(x,y,layer),nil,color)
end
end
mod._smog_hud_common = Common
local AnalogueRenderer = file_dofile("SMOG/scripts/mods/SMOG/SMOG_HUD")
fassert(type(AnalogueRenderer) == "table", "`SMOG` failed to load SMOG_HUD.lua.")
local DigitalRenderer = file_dofile("SMOG/scripts/mods/SMOG/SMOG_DHUD")
fassert(type(DigitalRenderer) == "table", "`SMOG` failed to load SMOG_DHUD.lua.")
local AdvancedDigitalRenderer = file_dofile("SMOG/scripts/mods/SMOG/SMOG_ADHUD")
fassert(type(AdvancedDigitalRenderer) == "table", "`SMOG` failed to load SMOG_ADHUD.lua.")
local Gui = Gui
local Color = Color
local Vector2 = Vector2
local Vector3 = Vector3
local RESOLUTION_LOOKUP = RESOLUTION_LOOKUP
local pcall = pcall
local type = type
local math_floor = math.floor
local math_max = math.max
local label_text = "SMOG"
local definitions = {
scenegraph_definition = {
screen = UIWorkspaceSettings.screen,
},
widget_definitions = {},
}
local function notice_layout(owner,gui,scale,screen_width,screen_height,font,text,tail)
local notification_y_axis = Common.clamp(mod._smog_notification_y_axis or 85,0,100)
local cached = owner._smog_notice_layout
if cached and cached.scale == scale and cached.screen_width == screen_width and cached.screen_height == screen_height and cached.notification_y_axis == notification_y_axis and cached.font == font and cached.text == text and cached.tail == tail then
return cached
end
local font_size = math_floor(22 * scale + 0.5)
if font_size < 16 then
font_size = 16
end
local square_size = math_floor(12 * scale + 0.5)
if square_size < 9 then
square_size = 9
end
local gap = math_floor(8 * scale + 0.5)
local label_width = Common.text_width(gui,label_text,font,font_size)
local message_width = Common.text_width(gui,text,font,font_size)
local tail_width = tail and Common.text_width(gui,tail,font,font_size) or 0
local total_width = label_width + gap + square_size + gap + message_width + tail_width
local x = (screen_width - total_width) * 0.5
local y = Common.clamp(screen_height * notification_y_axis * 0.01 - font_size * 0.5,0,math_max(screen_height - font_size,0))
local square_x = x + label_width + gap
local message_x = square_x + square_size + gap
cached = {
scale = scale,
screen_width = screen_width,
screen_height = screen_height,
notification_y_axis = notification_y_axis,
font = font,
text = text,
tail = tail,
font_size = font_size,
square_size = square_size,
label_x = x,
square_x = square_x,
square_y = y + font_size * 0.25,
message_x = message_x,
tail_x = message_x + message_width,
y = y,
}
owner._smog_notice_layout = cached
return cached
end
local function draw_notice(owner,gui,scale,screen_width,screen_height)
local getter = mod and mod._smog_get_notification
if type(getter) ~= "function" then
return
end
local state = getter()
if not state or not state.text then
return
end
local remaining = math_max(state.remaining or 0,0)
if remaining <= 0 then
return
end
local fade_seconds = state.fade_seconds or 1
local fade = remaining >= fade_seconds and 1 or math_max(remaining / fade_seconds,0)
local alpha = math_floor(235 * fade + 0.5)
if alpha <= 0 then
return
end
local font = Common.font_path("proxima_nova_bold")
if not font then
return
end
local text = state.text or ""
local tail = state.tail
local layout = notice_layout(owner,gui,scale,screen_width,screen_height,font,text,tail)
local square_colour = state.good ~= false and Color(alpha,90,200,90) or Color(alpha,220,40,40)
local text_colour = Color(alpha,205,210,205)
local green_text_colour = Color(alpha,90,200,90)
local red_text_colour = Color(alpha,220,40,40)
local full_red = state.red_text == true
local label_colour = full_red and red_text_colour or text_colour
local message_colour = full_red and red_text_colour or state.green_text == true and green_text_colour or text_colour
local tail_colour = full_red and red_text_colour or text_colour
Common.draw_text(gui,label_text,font,layout.font_size,layout.label_x,layout.y,991,label_colour)
Gui.rect(gui,Vector3(layout.square_x,layout.square_y,990),Vector2(layout.square_size,layout.square_size),square_colour)
Common.draw_text(gui,text,font,layout.font_size,layout.message_x,layout.y,991,message_colour)
if tail then
Common.draw_text(gui,tail,font,layout.font_size,layout.tail_x,layout.y,991,tail_colour)
end
end
local class_name = "HudElementSMOGController"
local HudElementSMOGController = rawget(_G,class_name)
if not HudElementSMOGController then
HudElementSMOGController = class(class_name,"HudElementBase")
_G[class_name] = HudElementSMOGController
end
local renderer_by_format = {
analogue = AnalogueRenderer,
digital = DigitalRenderer,
advanced_digital = AdvancedDigitalRenderer,
}
local function renderer_format()
local format = mod._smog_hud_format
if renderer_by_format[format] then
return format
end
return "analogue"
end
local function switch_renderer(previous_renderer,renderer,owner)
previous_renderer.destroy(owner)
renderer.init(owner)
end
function HudElementSMOGController:init(parent,draw_layer,start_scale)
HudElementSMOGController.super.init(self,parent,draw_layer,start_scale,definitions)
self._smog_renderer_format = renderer_format()
self._smog_renderer_draw_failed = false
self._smog_notice_draw_failed = false
self._smog_notice_layout = nil
renderer_by_format[self._smog_renderer_format].init(self)
end
function HudElementSMOGController:_sync_renderer_format()
local format = renderer_format()
local renderer = renderer_by_format[format]
if self._smog_renderer_format == format then
return format,renderer
end
local previous_renderer = renderer_by_format[self._smog_renderer_format]
self._smog_renderer_format = format
self._smog_renderer_draw_failed = false
local ok,error_message = pcall(switch_renderer,previous_renderer,renderer,self)
if not ok then
self._smog_renderer_draw_failed = true
mod:error("SMOG %s HUD renderer failed to initialise after a format change and was disabled: %s",format,tostring(error_message))
end
return format,renderer
end
function HudElementSMOGController:_draw_widgets(dt,t,input_service,ui_renderer,render_settings)
if mod._smog_hud_visible ~= true and mod._smog_notification_active ~= true then
return
end
if not Common.context_allowed() then
return
end
local gui = ui_renderer and ui_renderer.gui
if not gui or not Gui or not Vector2 or not Vector3 or not Color then
return
end
local resolution = RESOLUTION_LOOKUP or {}
local scale = resolution.scale or 1
local screen_width = resolution.width or 1920
local screen_height = resolution.height or 1080
if mod._smog_notification_active == true and not self._smog_notice_draw_failed then
local ok,error_message = pcall(draw_notice,self,gui,scale,screen_width,screen_height)
if not ok then
self._smog_notice_draw_failed = true
mod:error("SMOG notification renderer was disabled after a draw failure: %s",tostring(error_message))
end
end
if mod._smog_hud_visible ~= true then
return
end
local format,renderer = self:_sync_renderer_format()
if self._smog_renderer_draw_failed then
return
end
local ok,error_message = pcall(renderer.draw,self,dt,gui,scale,screen_width,screen_height)
if not ok then
self._smog_renderer_draw_failed = true
mod:error("SMOG %s HUD renderer was disabled after a draw failure: %s",format,tostring(error_message))
end
end
function HudElementSMOGController:destroy(ui_renderer)
renderer_by_format[self._smog_renderer_format].destroy(self)
HudElementSMOGController.super.destroy(self,ui_renderer)
end
return HudElementSMOGController