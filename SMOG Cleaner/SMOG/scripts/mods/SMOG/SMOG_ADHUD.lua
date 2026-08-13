-- SMOG_ADHUD.lua
local mod = get_mod("SMOG")
local Common = mod._smog_hud_common
local Gui = Gui
local Color = Color
local QuaternionBox = QuaternionBox
local Vector3 = Vector3
local Vector2 = Vector2
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local string_format = string.format
local refresh_interval = 0.5
local smog_title = "SMOG"
local lua_column_title = "LUA HEAP"
local process_column_title = "GAME MEMORY"
local lua_full_title = "LUA HEAP FULL"
local lua_total_title = "LUA HEAP TOTAL"
local lua_growth_title = "LUA GROWTH"
local peak_lua_title = "PEAK LUA / SESSION"
local lua_share_title = "LUA SHARE"
local process_total_title = "GAME MEMORY TOTAL"
local process_growth_title = "GAME MEMORY GROWTH"
local peak_process_title = "PEAK GAME MEMORY"
local fps_title = "FPS"
local memory_pressure_title = "MEMORY PRESSURE:"
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
local label_blue_box = QuaternionBox(Color(215,55,190,255))
local title_blue_box = QuaternionBox(Color(225,55,190,255))
local unit_blue_box = QuaternionBox(Color(190,55,190,255))
local divider_blue_box = QuaternionBox(Color(95,55,190,255))
local warning_red_box = QuaternionBox(Color(245,235,54,38))
local fps_green_box = QuaternionBox(Color(195,95,255,115))
local background_box = QuaternionBox(Color(125,7,12,17))
local Renderer = {}
local function digital_text(text)
return tostring(text or ""):gsub("%d",function(character)
return digit_symbols[tonumber(character)] or character
end)
end
local function digital_number(value,min_digits)
local text = tostring(math_max(0,math_floor((value or 0) + 0.5)))
while min_digits and #text < min_digits do
text = "0" .. text
end
return digital_text(text)
end
local function signed_integer(value)
local rounded = math_floor(math_abs(value or 0) + 0.5)
local sign = (value or 0) >= 0 and "+" or "-"
return digital_text(sign .. tostring(rounded))
end
local function decimal_number(value)
return digital_text(string_format("%.1f",math_max(value or 0,0)))
end
local function process_growth_parts(value)
local growth = value or 0
local magnitude = math_abs(growth)
local sign = growth >= 0 and "+" or "-"
if magnitude >= 1024 then
return sign,decimal_number(magnitude / 1024),"GB/min"
end
return sign,digital_number(math_floor(magnitude + 0.5)),"MB/min"
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
local function left_aligned_x(gui,text,font,font_size,x)
local min_x = text_horizontal_bounds(gui,text,font,font_size)
return x - min_x
end
local function sample(owner,dt)
local revision = mod._smog_hud_sample_revision or 0
if owner._smog_advanced_sample_revision ~= revision then
owner._smog_advanced_sample_revision = revision
owner._smog_advanced_percent = Common.clamp(mod._smog_hud_sample_percent or 0,0,100)
local percent_value = math_max(0,math_floor(owner._smog_advanced_percent + 0.5))
local heap_value = math_max(0,math_floor((mod._smog_hud_sample_mb or 0) + 0.5))
if owner._smog_advanced_percent_value ~= percent_value then
owner._smog_advanced_percent_value = percent_value
owner._smog_advanced_percent_text = digital_number(percent_value)
owner._smog_advanced_layout_dirty = true
end
if owner._smog_advanced_heap_value ~= heap_value then
owner._smog_advanced_heap_value = heap_value
owner._smog_advanced_heap_text = digital_number(heap_value)
owner._smog_advanced_layout_dirty = true
end
end
local state = mod._smog_advanced_hud_state
local state_revision = state and state.revision or 0
if owner._smog_advanced_state_revision ~= state_revision then
owner._smog_advanced_state_revision = state_revision
owner._smog_advanced_process_text = decimal_number((state and state.process_mb or 0) / 1024)
owner._smog_advanced_process_growth_sign,owner._smog_advanced_process_growth_magnitude_text,owner._smog_advanced_process_growth_unit = process_growth_parts(state and state.process_growth_mb_per_min or 0)
owner._smog_advanced_process_peak_text = decimal_number((state and state.process_peak_mb or 0) / 1024)
owner._smog_advanced_lua_growth_text = signed_integer(state and state.lua_growth_mb_per_min or 0)
owner._smog_advanced_lua_peak_text = digital_number(state and state.lua_peak_mb or 0)
owner._smog_advanced_lua_share_text = decimal_number(state and state.lua_share_percent or 0)
owner._smog_advanced_pressure_text = state and state.pressure or "NORMAL"
owner._smog_advanced_layout_dirty = true
end
owner._smog_advanced_sample_timer = owner._smog_advanced_sample_timer + (dt or 0)
owner._smog_advanced_fps_elapsed = owner._smog_advanced_fps_elapsed + (dt or 0)
owner._smog_advanced_fps_frames = owner._smog_advanced_fps_frames + 1
if owner._smog_advanced_sample_timer < refresh_interval then
return
end
local fps = 0
if owner._smog_advanced_fps_elapsed > 0 then
fps = math_floor(owner._smog_advanced_fps_frames / owner._smog_advanced_fps_elapsed + 0.5)
end
if fps > 999 then
fps = 999
end
owner._smog_advanced_sample_timer = 0
owner._smog_advanced_fps_elapsed = 0
owner._smog_advanced_fps_frames = 0
if owner._smog_advanced_fps_value ~= fps then
owner._smog_advanced_fps_value = fps
owner._smog_advanced_fps_text = digital_number(fps,3)
owner._smog_advanced_layout_dirty = true
end
end
local function layout(owner,gui,scale,cx,cy,digital_font,mono_font)
local cached = owner._smog_advanced_layout
if not owner._smog_advanced_layout_dirty and cached and cached.scale == scale and cached.cx == cx and cached.cy == cy and cached.digital_font == digital_font and cached.mono_font == mono_font then
return cached
end
cached = cached or {}
local style_a = math_max(10,math_floor(13 * scale + 0.5))
local style_b = math_max(38,math_floor(56 * scale + 0.5))
local style_b_unit = math_max(15,math_floor(20 * scale + 0.5))
local style_c = math_max(18,math_floor(25 * scale + 0.5))
local style_c_label = math_max(9,math_floor(12 * scale + 0.5))
local style_c_unit = math_max(9,math_floor(11 * scale + 0.5))
local lua_share_percent_size = math_max(11,math_floor(style_c_unit * 1.2 + 0.5))
local process_growth_sign_size = math_max(20,math_floor(style_b * 0.6 + 0.5))
local percent_symbol_size = math_max(22,math_floor(31 * scale + 0.5))
local line_height = math_max(1,math_floor(scale + 0.5))
local panel_left = cx - 168 * scale
local divider_x = cx
local panel_right = cx + 156 * scale
local panel_top = cy - 32 * scale
local left_x = panel_left + 13 * scale
local right_x = divider_x + 14 * scale
local smog_y = panel_top + 10 * scale
local column_title_y = panel_top + 35 * scale
local heading_line_y = panel_top + 56 * scale
local content_y = heading_line_y + 14 * scale
local left_label_gap = 17 * scale
local left_block_gap = 65 * scale
local right_block_gap = 86 * scale
local lua_full_label_y = content_y
local lua_full_value_y = lua_full_label_y + left_label_gap
local process_total_label_y = content_y
local process_total_value_y = process_total_label_y + left_label_gap
local process_growth_base_label_y = process_total_label_y + right_block_gap
local process_growth_label_y = process_growth_base_label_y + 5 * scale
local process_growth_value_y = process_growth_base_label_y + left_label_gap
local lua_total_label_y = process_growth_base_label_y
local lua_total_value_y = lua_total_label_y + left_label_gap
local lua_growth_label_y = lua_total_label_y + left_block_gap
local lua_growth_value_y = lua_growth_label_y + left_label_gap
local peak_lua_label_y = lua_growth_label_y + left_block_gap
local peak_lua_value_y = peak_lua_label_y + left_label_gap
local lua_share_label_y = peak_lua_label_y + left_block_gap
local lua_share_value_y = lua_share_label_y + left_label_gap
local peak_process_base_label_y = process_growth_base_label_y + right_block_gap
local peak_process_label_y = peak_process_base_label_y + 5 * scale
local peak_process_value_y = peak_process_base_label_y + left_label_gap
local fps_label_y = lua_share_label_y
local fps_value_y = lua_share_value_y
local fps_line_y = fps_label_y - 11 * scale
local lua_share_bottom = lua_share_value_y + style_c
local fps_bottom = fps_value_y + style_c
local bottom_line_y = math_max(lua_share_bottom,fps_bottom) + 9 * scale
local memory_pressure_y = bottom_line_y + 11 * scale
local panel_bottom = memory_pressure_y + 26 * scale
local background_pad = 8 * scale
local divider_y = column_title_y - 5 * scale
local divider_height = bottom_line_y - divider_y
local percent_text = owner._smog_advanced_percent_text or digit_symbols[0]
local heap_text = owner._smog_advanced_heap_text or digit_symbols[0]
local lua_growth_text = owner._smog_advanced_lua_growth_text or signed_integer(0)
local lua_peak_text = owner._smog_advanced_lua_peak_text or digital_number(0)
local lua_share_text = owner._smog_advanced_lua_share_text or decimal_number(0)
local process_text = owner._smog_advanced_process_text or decimal_number(0)
local process_growth_sign = owner._smog_advanced_process_growth_sign or "+"
local process_growth_magnitude_text = owner._smog_advanced_process_growth_magnitude_text or digital_number(0)
local process_peak_text = owner._smog_advanced_process_peak_text or decimal_number(0)
local fps_text = owner._smog_advanced_fps_text or digital_number(0,3)
local percent_x = left_aligned_x(gui,percent_text,digital_font,style_b,left_x)
local percent_width = select(2,text_horizontal_bounds(gui,percent_text,digital_font,style_b))
local percent_symbol_x = left_x + percent_width + 9 * scale
local heap_x = left_aligned_x(gui,heap_text,digital_font,style_c,left_x)
local heap_width = select(2,text_horizontal_bounds(gui,heap_text,digital_font,style_c))
local lua_growth_x = left_aligned_x(gui,lua_growth_text,digital_font,style_c,left_x)
local lua_peak_x = left_aligned_x(gui,lua_peak_text,digital_font,style_c,left_x)
local lua_share_x = left_aligned_x(gui,lua_share_text,digital_font,style_c,left_x)
local process_x = left_aligned_x(gui,process_text,digital_font,style_b,right_x)
local process_growth_sign_x = left_aligned_x(gui,process_growth_sign,digital_font,process_growth_sign_size,right_x)
local process_growth_sign_width = select(2,text_horizontal_bounds(gui,process_growth_sign,digital_font,process_growth_sign_size))
local process_growth_magnitude_left = right_x + process_growth_sign_width + 5 * scale
local process_growth_magnitude_x = left_aligned_x(gui,process_growth_magnitude_text,digital_font,style_b,process_growth_magnitude_left)
local process_peak_x = left_aligned_x(gui,process_peak_text,digital_font,style_b,right_x)
local fps_x = left_aligned_x(gui,fps_text,digital_font,style_c,right_x)
local process_width = select(2,text_horizontal_bounds(gui,process_text,digital_font,style_b))
local process_growth_magnitude_width = select(2,text_horizontal_bounds(gui,process_growth_magnitude_text,digital_font,style_b))
local process_peak_width = select(2,text_horizontal_bounds(gui,process_peak_text,digital_font,style_b))
local lua_growth_width = select(2,text_horizontal_bounds(gui,lua_growth_text,digital_font,style_c))
local lua_peak_width = select(2,text_horizontal_bounds(gui,lua_peak_text,digital_font,style_c))
local lua_share_width = select(2,text_horizontal_bounds(gui,lua_share_text,digital_font,style_c))
local pressure_label_width = Common.text_width(gui,memory_pressure_title,mono_font,style_a)
cached.scale = scale
cached.cx = cx
cached.cy = cy
cached.digital_font = digital_font
cached.mono_font = mono_font
cached.style_a = style_a
cached.style_b = style_b
cached.style_b_unit = style_b_unit
cached.style_c = style_c
cached.style_c_label = style_c_label
cached.style_c_unit = style_c_unit
cached.lua_share_percent_size = lua_share_percent_size
cached.process_growth_sign_size = process_growth_sign_size
cached.percent_symbol_size = percent_symbol_size
cached.line_height = line_height
cached.panel_left = panel_left
cached.panel_width = panel_right - panel_left
cached.background_x = panel_left - background_pad
cached.background_y = panel_top - background_pad
cached.background_width = panel_right - panel_left + background_pad * 2
cached.background_height = panel_bottom - panel_top + background_pad * 2
cached.divider_x = divider_x
cached.divider_y = divider_y
cached.divider_width = line_height
cached.divider_height = divider_height
cached.smog_x = left_x
cached.smog_y = smog_y
cached.left_x = left_x
cached.right_x = right_x
cached.column_title_y = column_title_y
cached.heading_line_y = heading_line_y
cached.fps_line_y = fps_line_y
cached.fps_line_width = math_max(0,panel_right - divider_x)
cached.bottom_line_y = bottom_line_y
cached.lua_full_label_y = lua_full_label_y
cached.lua_full_value_y = lua_full_value_y
cached.lua_total_label_y = lua_total_label_y
cached.lua_total_value_y = lua_total_value_y
cached.lua_growth_label_y = lua_growth_label_y
cached.lua_growth_value_y = lua_growth_value_y
cached.peak_lua_label_y = peak_lua_label_y
cached.peak_lua_value_y = peak_lua_value_y
cached.lua_share_label_y = lua_share_label_y
cached.lua_share_value_y = lua_share_value_y
cached.process_total_label_y = process_total_label_y
cached.process_total_value_y = process_total_value_y
cached.process_growth_label_y = process_growth_label_y
cached.process_growth_value_y = process_growth_value_y
cached.peak_process_label_y = peak_process_label_y
cached.peak_process_value_y = peak_process_value_y
cached.fps_value_y = fps_value_y
cached.memory_pressure_y = memory_pressure_y
cached.percent_x = percent_x
cached.percent_symbol_x = percent_symbol_x
cached.percent_symbol_y = lua_full_value_y + style_b - percent_symbol_size
cached.heap_x = heap_x
cached.heap_unit_x = left_x + heap_width + 6 * scale
cached.heap_unit_y = lua_total_value_y + style_c - style_c_unit
cached.lua_growth_x = lua_growth_x
cached.lua_growth_unit_x = left_x + lua_growth_width + 6 * scale
cached.lua_peak_x = lua_peak_x
cached.lua_peak_unit_x = left_x + lua_peak_width + 6 * scale
cached.lua_share_x = lua_share_x
cached.lua_share_unit_x = left_x + lua_share_width + 5 * scale
cached.process_x = process_x
cached.process_unit_x = right_x + process_width + 8 * scale
cached.process_growth_sign_x = process_growth_sign_x
cached.process_growth_magnitude_x = process_growth_magnitude_x
cached.process_growth_unit_x = process_growth_magnitude_left + process_growth_magnitude_width + 8 * scale
cached.process_peak_x = process_peak_x
cached.process_peak_unit_x = right_x + process_peak_width + 8 * scale
cached.lua_growth_unit_y = lua_growth_value_y + style_c - style_c_unit
cached.lua_peak_unit_y = peak_lua_value_y + style_c - style_c_unit
cached.lua_share_unit_y = lua_share_value_y + style_c - lua_share_percent_size + 3 * scale
cached.process_unit_y = process_total_value_y + style_b - style_b_unit
cached.process_growth_unit_y = process_growth_value_y + style_b - style_c_unit
cached.process_peak_unit_y = peak_process_value_y + style_b - style_b_unit
cached.fps_x = fps_x
cached.fps_label_x = right_x
cached.fps_label_y = fps_label_y
cached.memory_pressure_value_x = left_x + pressure_label_width + 7 * scale
owner._smog_advanced_layout = cached
owner._smog_advanced_layout_dirty = false
return cached
end
function Renderer.init(owner)
owner._smog_advanced_sample_timer = 0
owner._smog_advanced_fps_elapsed = 0
owner._smog_advanced_fps_frames = 0
owner._smog_advanced_sample_revision = -1
owner._smog_advanced_state_revision = -1
owner._smog_advanced_percent = 0
owner._smog_advanced_percent_value = nil
owner._smog_advanced_heap_value = nil
owner._smog_advanced_fps_value = nil
owner._smog_advanced_percent_text = digit_symbols[0]
owner._smog_advanced_heap_text = digit_symbols[0]
owner._smog_advanced_fps_text = digital_number(0,3)
owner._smog_advanced_process_text = decimal_number(0)
owner._smog_advanced_process_growth_sign,owner._smog_advanced_process_growth_magnitude_text,owner._smog_advanced_process_growth_unit = process_growth_parts(0)
owner._smog_advanced_process_peak_text = decimal_number(0)
owner._smog_advanced_lua_growth_text = signed_integer(0)
owner._smog_advanced_lua_peak_text = digital_number(0)
owner._smog_advanced_lua_share_text = decimal_number(0)
owner._smog_advanced_pressure_text = "NORMAL"
owner._smog_advanced_layout = nil
owner._smog_advanced_layout_dirty = true
owner._smog_advanced_font = nil
owner._smog_advanced_mono_font = nil
end
function Renderer.draw(owner,dt,gui,scale,screen_width,screen_height)
sample(owner,dt)
local cx,cy = Common.position(owner,screen_width,screen_height,scale,72 * scale)
local digital_font = owner._smog_advanced_font or Common.font_path("darktide_custom_regular","mono_tide_regular")
local mono_font = owner._smog_advanced_mono_font or Common.font_path("mono_tide_regular","arial")
if not digital_font or not mono_font then
return
end
owner._smog_advanced_font = digital_font
owner._smog_advanced_mono_font = mono_font
local l = layout(owner,gui,scale,cx,cy,digital_font,mono_font)
local percentage_box = owner._smog_advanced_percent >= 80 and warning_red_box or blue_box
if Gui.rect and Vector2 then
Gui.rect(gui,Vector3(l.background_x,l.background_y,820),Vector2(l.background_width,l.background_height),background_box:unbox())
Gui.rect(gui,Vector3(l.divider_x,l.divider_y,824),Vector2(l.divider_width,l.divider_height),divider_blue_box:unbox())
Gui.rect(gui,Vector3(l.panel_left,l.heading_line_y,824),Vector2(l.panel_width,l.line_height),divider_blue_box:unbox())
Gui.rect(gui,Vector3(l.divider_x,l.fps_line_y,824),Vector2(l.fps_line_width,l.line_height),divider_blue_box:unbox())
Gui.rect(gui,Vector3(l.panel_left,l.bottom_line_y,824),Vector2(l.panel_width,l.line_height),divider_blue_box:unbox())
end
Common.draw_text(gui,smog_title,mono_font,l.style_b_unit,l.smog_x,l.smog_y,825,title_blue_box:unbox())
Common.draw_text(gui,lua_column_title,mono_font,l.style_a,l.left_x,l.column_title_y,825,title_blue_box:unbox())
Common.draw_text(gui,process_column_title,mono_font,l.style_a,l.right_x,l.column_title_y,825,title_blue_box:unbox())
Common.draw_text(gui,lua_full_title,mono_font,l.style_c_label,l.left_x,l.lua_full_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_percent_text or digit_symbols[0],digital_font,l.style_b,l.percent_x,l.lua_full_value_y,825,percentage_box:unbox())
Common.draw_text(gui,"%",mono_font,l.percent_symbol_size,l.percent_symbol_x,l.percent_symbol_y,825,percentage_box:unbox())
Common.draw_text(gui,lua_total_title,mono_font,l.style_c_label,l.left_x,l.lua_total_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_heap_text or digit_symbols[0],digital_font,l.style_c,l.heap_x,l.lua_total_value_y,825,blue_box:unbox())
Common.draw_text(gui,"MB",mono_font,l.style_c_unit,l.heap_unit_x,l.heap_unit_y,825,unit_blue_box:unbox())
Common.draw_text(gui,lua_growth_title,mono_font,l.style_c_label,l.left_x,l.lua_growth_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_lua_growth_text,digital_font,l.style_c,l.lua_growth_x,l.lua_growth_value_y,825,blue_box:unbox())
Common.draw_text(gui,"MB/min",mono_font,l.style_c_unit,l.lua_growth_unit_x,l.lua_growth_unit_y,825,unit_blue_box:unbox())
Common.draw_text(gui,peak_lua_title,mono_font,l.style_c_label,l.left_x,l.peak_lua_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_lua_peak_text,digital_font,l.style_c,l.lua_peak_x,l.peak_lua_value_y,825,blue_box:unbox())
Common.draw_text(gui,"MB",mono_font,l.style_c_unit,l.lua_peak_unit_x,l.lua_peak_unit_y,825,unit_blue_box:unbox())
Common.draw_text(gui,lua_share_title,mono_font,l.style_c_label,l.left_x,l.lua_share_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_lua_share_text,digital_font,l.style_c,l.lua_share_x,l.lua_share_value_y,825,blue_box:unbox())
Common.draw_text(gui,"%",mono_font,l.lua_share_percent_size,l.lua_share_unit_x,l.lua_share_unit_y,825,unit_blue_box:unbox())
Common.draw_text(gui,process_total_title,mono_font,l.style_c_label,l.right_x,l.process_total_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_process_text,digital_font,l.style_b,l.process_x,l.process_total_value_y,825,blue_box:unbox())
Common.draw_text(gui,"GB",mono_font,l.style_b_unit,l.process_unit_x,l.process_unit_y,825,unit_blue_box:unbox())
Common.draw_text(gui,process_growth_title,mono_font,l.style_c_label,l.right_x,l.process_growth_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_process_growth_sign or "+",digital_font,l.process_growth_sign_size,l.process_growth_sign_x,l.process_growth_value_y + l.style_b - l.process_growth_sign_size,825,blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_process_growth_magnitude_text or digital_number(0),digital_font,l.style_b,l.process_growth_magnitude_x,l.process_growth_value_y,825,blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_process_growth_unit or "MB/min",mono_font,l.style_c_unit,l.process_growth_unit_x,l.process_growth_unit_y,825,unit_blue_box:unbox())
Common.draw_text(gui,peak_process_title,mono_font,l.style_c_label,l.right_x,l.peak_process_label_y,825,label_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_process_peak_text,digital_font,l.style_b,l.process_peak_x,l.peak_process_value_y,825,blue_box:unbox())
Common.draw_text(gui,"GB",mono_font,l.style_b_unit,l.process_peak_unit_x,l.process_peak_unit_y,825,unit_blue_box:unbox())
Common.draw_text(gui,fps_title,mono_font,l.style_c_label,l.fps_label_x,l.fps_label_y,825,fps_green_box:unbox())
Common.draw_text(gui,owner._smog_advanced_fps_text or digital_number(0,3),digital_font,l.style_c,l.fps_x,l.fps_value_y,825,fps_green_box:unbox())
Common.draw_text(gui,memory_pressure_title,mono_font,l.style_a,l.left_x,l.memory_pressure_y,825,title_blue_box:unbox())
Common.draw_text(gui,owner._smog_advanced_pressure_text or "NORMAL",mono_font,l.style_a,l.memory_pressure_value_x,l.memory_pressure_y,825,title_blue_box:unbox())
end
function Renderer.destroy()
end
return Renderer
