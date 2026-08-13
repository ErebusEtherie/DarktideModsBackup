-- SMOG_DHUD.lua
local mod = get_mod("SMOG")
local Common = mod._smog_hud_common
local Gui = Gui
local Color = Color
local QuaternionBox = QuaternionBox
local Vector3 = Vector3
local Vector2 = Vector2
local math_floor = math.floor
local math_max = math.max
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local refresh_interval = 0.5
local title_text = "SMOG"
local fps_label = "FPS"
local digit_symbols = {
[0] = "",
"",
"",
"",
"",
"",
"",
"",
"",
"",
}
local blue_box = QuaternionBox(Color(245,55,190,255))
local label_blue_box = QuaternionBox(Color(190,55,190,255))
local title_blue_box = QuaternionBox(Color(205,55,190,255))
local mb_label_blue_box = QuaternionBox(Color(175,55,190,255))
local divider_blue_box = QuaternionBox(Color(95,55,190,255))
local warning_red_box = QuaternionBox(Color(245,235,54,38))
local Renderer = {}
local function digital_number(value,min_digits)
local text = tostring(math_max(0,math_floor((value or 0) + 0.5)))
while min_digits and #text < min_digits do
text = "0" .. text
end
return text:gsub("%d",function(character)
return digit_symbols[tonumber(character)] or character
end)
end
local function text_horizontal_bounds(gui,text,font,font_size)
if Gui and Gui.slug_text_extents then
local ok,min,max = pcall(Gui.slug_text_extents,gui,text,font,font_size)
if ok and min and max then
local min_x = min[1] or 0
local max_x = max[1] or min_x
return min_x,math_max(max_x - min_x,0)
end
end
return 0,Common.text_width(gui,text,font,font_size)
end
local function sample(owner,dt)
local revision = mod._smog_hud_sample_revision or 0
if owner._smog_digital_sample_revision ~= revision then
owner._smog_digital_sample_revision = revision
owner._smog_digital_percent = Common.clamp(mod._smog_hud_sample_percent or 0,0,100)
local percent_value = math_max(0,math_floor(owner._smog_digital_percent + 0.5))
local heap_value = math_max(0,math_floor((mod._smog_hud_sample_mb or 0) + 0.5))
if owner._smog_digital_percent_value ~= percent_value then
owner._smog_digital_percent_value = percent_value
owner._smog_digital_percent_text = digital_number(percent_value)
owner._smog_digital_layout_dirty = true
end
if owner._smog_digital_heap_value ~= heap_value then
owner._smog_digital_heap_value = heap_value
owner._smog_digital_heap_text = digital_number(heap_value)
owner._smog_digital_layout_dirty = true
end
end
owner._smog_digital_sample_timer = owner._smog_digital_sample_timer + (dt or 0)
owner._smog_digital_fps_elapsed = owner._smog_digital_fps_elapsed + (dt or 0)
owner._smog_digital_fps_frames = owner._smog_digital_fps_frames + 1
if owner._smog_digital_sample_timer < refresh_interval then
return
end
local fps = 0
if owner._smog_digital_fps_elapsed > 0 then
fps = math_floor(owner._smog_digital_fps_frames / owner._smog_digital_fps_elapsed + 0.5)
end
if fps > 999 then
fps = 999
end
owner._smog_digital_sample_timer = 0
owner._smog_digital_fps_elapsed = 0
owner._smog_digital_fps_frames = 0
if owner._smog_digital_fps_value ~= fps then
owner._smog_digital_fps_value = fps
owner._smog_digital_fps_text = digital_number(fps,3)
owner._smog_digital_layout_dirty = true
end
end
local function layout(owner,gui,scale,cx,cy,digital_font,mono_font)
local cached = owner._smog_digital_layout
if not owner._smog_digital_layout_dirty and cached and cached.scale == scale and cached.cx == cx and cached.cy == cy and cached.digital_font == digital_font and cached.mono_font == mono_font then
return cached
end
cached = cached or {}
local title_size = math_max(10,math_floor(13 * scale + 0.5))
local percent_size = math_max(38,math_floor(56 * scale + 0.5))
local percent_symbol_original_size = math_max(30,math_floor(42 * scale + 0.5))
local percent_symbol_size = math_max(22,math_floor(percent_symbol_original_size * 0.72 + 0.5))
local heap_size = math_max(19,math_floor(25 * scale + 0.5))
local fps_size = math_max(13,math_floor(17 * scale + 0.5))
local label_size = math_max(9,math_floor(fps_size * 0.7 + 0.5))
local percent_text = owner._smog_digital_percent_text or digit_symbols[0]
local heap_text = owner._smog_digital_heap_text or digit_symbols[0]
local fps_text = owner._smog_digital_fps_text or digit_symbols[0]
local left_x = cx - 40 * scale
local percent_min_x,percent_width = text_horizontal_bounds(gui,percent_text,digital_font,percent_size)
local percent_reference_text = digit_symbols[2] .. digit_symbols[0]
local _,percent_reference_width = text_horizontal_bounds(gui,percent_reference_text,digital_font,percent_size)
local percent_slot_width = math_max(percent_width,percent_reference_width)
local percent_gap = 13 * scale
local percent_anchor_x = left_x + 2 * scale
local percent_x = percent_anchor_x + percent_slot_width - percent_width - percent_min_x + 5 * scale
local percent_y = cy - 19 * scale
local percent_symbol_x = percent_anchor_x + percent_slot_width + percent_gap - 2 * scale
local percent_symbol_y = percent_y + 18 * scale + percent_symbol_original_size - percent_symbol_size
local percent_symbol_width = Common.text_width(gui,"%",mono_font,percent_symbol_size)
local percent_group_width = percent_slot_width + percent_gap + percent_symbol_width
local column_gap = 14 * scale
local column_two_x = percent_anchor_x + percent_group_width + column_gap
local title_y = cy - 24 * scale
local heap_y = cy - 15 * scale
local fps_y = cy + 18 * scale
local row_offset_y = 4 * scale
local heap_min_x,heap_width = text_horizontal_bounds(gui,heap_text,digital_font,heap_size)
local heap_x = column_two_x - heap_min_x + 2 * scale
local heap_gap = 8 * scale
local fps_anchor_x = column_two_x + 2 * scale
local fps_min_x,fps_text_width = text_horizontal_bounds(gui,fps_text,digital_font,fps_size)
local fps_x = fps_anchor_x - fps_min_x
local divider_x = percent_anchor_x + percent_group_width + column_gap * 0.5
local title_min_x,title_width = text_horizontal_bounds(gui,title_text,mono_font,title_size)
local title_x = divider_x - 6 * scale - title_width - title_min_x
cached.scale = scale
cached.cx = cx
cached.cy = cy
cached.digital_font = digital_font
cached.mono_font = mono_font
cached.title_size = title_size
cached.percent_size = percent_size
cached.percent_symbol_size = percent_symbol_size
cached.heap_size = heap_size
cached.label_size = label_size
cached.fps_size = fps_size
cached.percent_x = percent_x
cached.percent_y = percent_y
cached.percent_symbol_x = percent_symbol_x
cached.percent_symbol_y = percent_symbol_y
cached.title_x = title_x
cached.title_y = title_y
cached.heap_y = heap_y + row_offset_y
cached.heap_x = heap_x
cached.heap_label_x = column_two_x + heap_width + heap_gap - 2 * scale
cached.heap_label_y = heap_y + 14 * scale + row_offset_y
cached.fps_x = fps_x
cached.fps_number_y = fps_y - 3 * scale + row_offset_y
cached.fps_label_x = fps_anchor_x + fps_text_width + 6 * scale
cached.fps_label_y = fps_y + 4 * scale + row_offset_y
cached.divider_x = divider_x
local divider_bottom = fps_y + 20 * scale
local display_height = divider_bottom - (title_y + 2 * scale)
local divider_extension = math_max(1,math_floor(display_height * 0.01 + 0.5))
local divider_y = title_y - divider_extension + 2 * scale
cached.divider_y = divider_y - 2 * scale
cached.divider_width = math_max(1,math_floor(scale + 0.5))
cached.divider_height = math_max(1,divider_bottom - divider_y + 6 * scale)
owner._smog_digital_layout = cached
owner._smog_digital_layout_dirty = false
return cached
end
function Renderer.init(owner)
owner._smog_digital_sample_timer = 0
owner._smog_digital_fps_elapsed = 0
owner._smog_digital_fps_frames = 0
owner._smog_digital_sample_revision = -1
owner._smog_digital_percent = 0
owner._smog_digital_percent_value = nil
owner._smog_digital_heap_value = nil
owner._smog_digital_fps_value = nil
owner._smog_digital_percent_text = digit_symbols[0]
owner._smog_digital_heap_text = digit_symbols[0]
owner._smog_digital_fps_text = digital_number(0,3)
owner._smog_digital_layout = nil
owner._smog_digital_layout_dirty = true
owner._smog_digital_font = nil
owner._smog_digital_mono_font = nil
end
function Renderer.draw(owner,dt,gui,scale,screen_width,screen_height)
sample(owner,dt)
local cx,cy = Common.position(owner,screen_width,screen_height,scale,72 * scale)
local digital_font = owner._smog_digital_font or Common.font_path("darktide_custom_regular","mono_tide_regular")
local mono_font = owner._smog_digital_mono_font or Common.font_path("mono_tide_regular","arial")
if not digital_font or not mono_font then
return
end
owner._smog_digital_font = digital_font
owner._smog_digital_mono_font = mono_font
local current_layout = layout(owner,gui,scale,cx,cy,digital_font,mono_font)
local percent_text = owner._smog_digital_percent_text or digit_symbols[0]
local heap_text = owner._smog_digital_heap_text or digit_symbols[0]
local fps_text = owner._smog_digital_fps_text or digit_symbols[0]
local percentage_box = owner._smog_digital_percent >= 80 and warning_red_box or blue_box
Common.draw_text(gui,percent_text,digital_font,current_layout.percent_size,current_layout.percent_x,current_layout.percent_y,825,percentage_box:unbox())
Common.draw_text(gui,"%",mono_font,current_layout.percent_symbol_size,current_layout.percent_symbol_x,current_layout.percent_symbol_y,825,percentage_box:unbox())
if Gui.rect and Vector2 then
Gui.rect(gui,Vector3(current_layout.divider_x,current_layout.divider_y,824),Vector2(current_layout.divider_width,current_layout.divider_height),divider_blue_box:unbox())
end
Common.draw_text(gui,title_text,mono_font,current_layout.title_size,current_layout.title_x,current_layout.title_y,825,title_blue_box:unbox())
Common.draw_text(gui,heap_text,digital_font,current_layout.heap_size,current_layout.heap_x,current_layout.heap_y,825,blue_box:unbox())
Common.draw_text(gui,"MB",mono_font,current_layout.label_size,current_layout.heap_label_x,current_layout.heap_label_y,825,mb_label_blue_box:unbox())
Common.draw_text(gui,fps_text,digital_font,current_layout.fps_size,current_layout.fps_x,current_layout.fps_number_y,825,blue_box:unbox())
Common.draw_text(gui,fps_label,mono_font,current_layout.label_size,current_layout.fps_label_x,current_layout.fps_label_y,825,label_blue_box:unbox())
end
function Renderer.destroy()
end
return Renderer