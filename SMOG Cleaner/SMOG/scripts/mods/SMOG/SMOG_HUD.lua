-- SMOG_HUD.lua
local mod = get_mod("SMOG")
local Common = mod._smog_hud_common
local Gui = Gui
local Color = Color
local QuaternionBox = QuaternionBox
local Vector2 = Vector2
local Vector3 = Vector3
local Vector3Box = Vector3Box
local Rotation2D = Rotation2D
local Matrix4x4Box = Matrix4x4Box
local math = math
local math_sin = math.sin
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_pi = math.pi
local math_sqrt = math.sqrt
local math_atan2 = math.atan2 or math.atan
local string_format = string.format
local arc_segments = 96
local circle_segments = 16
local meter_text = "SMOG METER"
local meter_text_width_cache = {}
local base_color_box = QuaternionBox(Color(226,205,201,197))
local phase_sixteen_box = QuaternionBox(Color(226,86,190,40))
local phase_thirtytwo_box = QuaternionBox(Color(226,130,225,65))
local phase_fifty_box = QuaternionBox(Color(226,186,225,58))
local phase_sixtysix_box = QuaternionBox(Color(226,250,207,76))
local phase_eightythree_box = QuaternionBox(Color(226,238,126,52))
local phase_hundred_box = QuaternionBox(Color(226,235,54,38))
local needle_color_box = QuaternionBox(Color(240,47,40,53))
local hub_hole_box = QuaternionBox(Color(245,236,235,236))
local meter_color_box = QuaternionBox(Color(230,205,210,205))
local percent_color_box = QuaternionBox(Color(245,0,0,0))
local Renderer = {}
local function phase_for_percent(percent)
if percent <= 0.2 then
return 0,base_color_box
elseif percent <= 16 then
return 16,phase_sixteen_box
elseif percent <= 32 then
return 32,phase_thirtytwo_box
elseif percent <= 50 then
return 50,phase_fifty_box
elseif percent <= 66 then
return 66,phase_sixtysix_box
elseif percent <= 83 then
return 83,phase_eightythree_box
end
return 100,phase_hundred_box
end
local function build_normalized_arc(start_percent,end_percent)
local span_percent = end_percent - start_percent
local segment_count = math_max(1,math_floor(arc_segments * span_percent / 100 + 0.5))
local start_theta = math_pi - start_percent * 0.01 * math_pi
local end_theta = math_pi - end_percent * 0.01 * math_pi
local points = {}
local point_index = 1
for i = 0,segment_count do
local theta = start_theta + (end_theta - start_theta) * i / segment_count
points[point_index] = math_cos(theta)
points[point_index + 1] = -math_sin(theta)
point_index = point_index + 2
end
return points
end
local normalized_arc_parts = {
[0] = {
remainder = build_normalized_arc(0,100),
},
[16] = {
fill = build_normalized_arc(0,16),
remainder = build_normalized_arc(16,100),
},
[32] = {
fill = build_normalized_arc(0,32),
remainder = build_normalized_arc(32,100),
},
[50] = {
fill = build_normalized_arc(0,50),
remainder = build_normalized_arc(50,100),
},
[66] = {
fill = build_normalized_arc(0,66),
remainder = build_normalized_arc(66,100),
},
[83] = {
fill = build_normalized_arc(0,83),
remainder = build_normalized_arc(83,100),
},
[100] = {
fill = build_normalized_arc(0,100),
},
}
local function draw_line(gui,x1,y1,x2,y2,layer,width,color_box)
if not Gui or not Gui.rect_3d or not Rotation2D or not Vector2 or not Vector3 then
return false
end
local xd = x2 - x1
local yd = y2 - y1
local length = math_sqrt(xd * xd + yd * yd)
if length <= 0 then
return true
end
local angle = -math_atan2(yd,xd)
local transform = Rotation2D(Vector2(x1,y1),angle)
Gui.rect_3d(gui,transform,Vector3.zero(),layer,Vector2(length,width),color_box:unbox())
return true
end
local function sample(owner)
local revision = mod._smog_hud_sample_revision or 0
if owner._smog_analogue_sample_revision == revision then
return
end
owner._smog_analogue_sample_revision = revision
local percent = Common.clamp(mod._smog_hud_sample_percent or 0,0,100)
owner._smog_analogue_percent = percent
owner._smog_analogue_percent_text = string_format("%d%%",math_floor(percent + 0.5))
owner._smog_analogue_fill_percent,owner._smog_analogue_phase_color_box = phase_for_percent(percent)
end
local function update_line_geometry(target,normalized,cx,cy,radius,width)
local next_index = 1
if normalized and Rotation2D and Matrix4x4Box and Vector2 then
local last_x = cx + normalized[1] * radius
local last_y = cy + normalized[2] * radius
for i = 3,#normalized,2 do
local x = cx + normalized[i] * radius
local y = cy + normalized[i + 1] * radius
local xd = x - last_x
local yd = y - last_y
local length = math_sqrt(xd * xd + yd * yd)
if length > 0 then
local transform = Rotation2D(Vector2(last_x,last_y),-math_atan2(yd,xd))
target[next_index] = Matrix4x4Box(transform)
target[next_index + 1] = length
target[next_index + 2] = width
next_index = next_index + 3
end
last_x = x
last_y = y
end
end
for i = next_index,#target do
target[i] = nil
end
end
local function ensure_arc_geometry(owner,cx,cy,radius,width,fill_percent)
if owner._smog_analogue_arc_cx == cx and owner._smog_analogue_arc_cy == cy and owner._smog_analogue_arc_radius == radius and owner._smog_analogue_arc_width == width and owner._smog_analogue_arc_fill_percent == fill_percent then
return
end
owner._smog_analogue_arc_cx = cx
owner._smog_analogue_arc_cy = cy
owner._smog_analogue_arc_radius = radius
owner._smog_analogue_arc_width = width
owner._smog_analogue_arc_fill_percent = fill_percent
local parts = normalized_arc_parts[fill_percent] or normalized_arc_parts[0]
update_line_geometry(owner._smog_analogue_fill_geometry,parts.fill,cx,cy,radius,width)
update_line_geometry(owner._smog_analogue_remainder_geometry,parts.remainder,cx,cy,radius,width)
end
local function draw_arc_geometry(gui,geometry,color_box,layer)
if not geometry or not Gui or not Gui.rect_3d or not Vector2 or not Vector3 then
return
end
local color = color_box:unbox()
local offset = Vector3.zero()
local size = Vector2(0,0)
for i = 1,#geometry,3 do
size.x = geometry[i + 1]
size.y = geometry[i + 2]
Gui.rect_3d(gui,geometry[i]:unbox(),offset,layer,size,color)
end
end
local function update_circle_geometry(target,cx,cy,radius)
local next_index = 1
if Vector3Box and Vector3 then
local centre = target[next_index]
if centre then
centre:store(cx,0,cy)
else
target[next_index] = Vector3Box(cx,0,cy)
end
next_index = next_index + 1
for i = 0,circle_segments do
local theta = i / circle_segments * math_pi * 2
local x = cx + radius * math_cos(theta)
local y = cy + radius * math_sin(theta)
local point = target[next_index]
if point then
point:store(x,0,y)
else
target[next_index] = Vector3Box(x,0,y)
end
next_index = next_index + 1
end
end
for i = next_index,#target do
target[i] = nil
end
end
local function ensure_hub_geometry(owner,cx,cy,scale)
if owner._smog_analogue_hub_cx == cx and owner._smog_analogue_hub_cy == cy and owner._smog_analogue_hub_scale == scale then
return
end
owner._smog_analogue_hub_cx = cx
owner._smog_analogue_hub_cy = cy
owner._smog_analogue_hub_scale = scale
update_circle_geometry(owner._smog_analogue_hub_outer_geometry,cx,cy,14 * scale)
update_circle_geometry(owner._smog_analogue_hub_inner_geometry,cx,cy,5 * scale)
end
local function draw_circle_geometry(gui,geometry,color_box,layer)
if not geometry or #geometry < 3 or not Gui or not Gui.triangle then
return false
end
local centre = geometry[1]:unbox()
local color = color_box:unbox()
for i = 2,#geometry - 1 do
Gui.triangle(gui,centre,geometry[i]:unbox(),geometry[i + 1]:unbox(),layer,color)
end
return true
end
local function draw_hub(owner,gui,cx,cy,scale,hub_color_box,hole_color_box)
ensure_hub_geometry(owner,cx,cy,scale)
if draw_circle_geometry(gui,owner._smog_analogue_hub_outer_geometry,hub_color_box,821) then
draw_circle_geometry(gui,owner._smog_analogue_hub_inner_geometry,hole_color_box,822)
return
end
local outer = math_floor(25 * scale + 0.5)
local inner = math_floor(10 * scale + 0.5)
Gui.rect(gui,Vector3(cx - outer * 0.5,cy - outer * 0.5,821),Vector2(outer,outer),hub_color_box:unbox())
Gui.rect(gui,Vector3(cx - inner * 0.5,cy - inner * 0.5,822),Vector2(inner,inner),hole_color_box:unbox())
end
local function ensure_needle_geometry(owner,cx,cy,scale,outer_radius,percent)
if owner._smog_analogue_needle_cx == cx and owner._smog_analogue_needle_cy == cy and owner._smog_analogue_needle_scale == scale and owner._smog_analogue_needle_percent == percent then
return
end
owner._smog_analogue_needle_cx = cx
owner._smog_analogue_needle_cy = cy
owner._smog_analogue_needle_scale = scale
owner._smog_analogue_needle_percent = percent
local theta = math_pi - percent * 0.01 * math_pi
local dx = math_cos(theta)
local dy = -math_sin(theta)
local px = -dy
local py = dx
local tip_x = cx + dx * (outer_radius - 8 * scale)
local tip_y = cy + dy * (outer_radius - 8 * scale)
local base_x = cx + dx * (15 * scale)
local base_y = cy + dy * (15 * scale)
local needle_half = 5.5 * scale
owner._smog_analogue_needle_tip_x = tip_x
owner._smog_analogue_needle_tip_y = tip_y
if Vector3Box and Vector3 then
local p1 = owner._smog_analogue_needle_p1
local p2 = owner._smog_analogue_needle_p2
local p3 = owner._smog_analogue_needle_p3
if p1 then
p1:store(tip_x,0,tip_y)
p2:store(base_x + px * needle_half,0,base_y + py * needle_half)
p3:store(base_x - px * needle_half,0,base_y - py * needle_half)
else
owner._smog_analogue_needle_p1 = Vector3Box(tip_x,0,tip_y)
owner._smog_analogue_needle_p2 = Vector3Box(base_x + px * needle_half,0,base_y + py * needle_half)
owner._smog_analogue_needle_p3 = Vector3Box(base_x - px * needle_half,0,base_y - py * needle_half)
end
end
end
local function analogue_layout(owner,gui,scale,cx,cy)
local cached = owner._smog_analogue_layout
if cached and cached.scale == scale and cached.cx == cx and cached.cy == cy then
return cached
end
local small_font = owner._smog_analogue_font or Common.font_path("proxima_nova_bold")
if not small_font then
return nil
end
owner._smog_analogue_font = small_font
local outer_radius = 72 * scale
local inner_radius = 53 * scale
local arc_radius = (outer_radius + inner_radius) * 0.5
local meter_font_size = math_max(9,math_floor(11 * scale + 0.5))
local percent_font_size = math_max(10,math_floor(13 * scale + 0.5))
local meter_width = meter_text_width_cache[meter_font_size]
if not meter_width then
meter_width = Common.text_width(gui,meter_text,small_font,meter_font_size)
meter_text_width_cache[meter_font_size] = meter_width
end
cached = cached or {}
cached.scale = scale
cached.cx = cx
cached.cy = cy
cached.font = small_font
cached.outer_radius = outer_radius
cached.arc_radius = arc_radius
cached.arc_width = math_max(outer_radius - inner_radius,8 * scale)
cached.meter_font_size = meter_font_size
cached.percent_font_size = percent_font_size
cached.meter_x = cx - meter_width * 0.5
cached.meter_y = cy + 25 * scale
owner._smog_analogue_layout = cached
return cached
end
function Renderer.init(owner)
owner._smog_analogue_sample_revision = -1
owner._smog_analogue_percent = 0
owner._smog_analogue_percent_text = "0%"
owner._smog_analogue_fill_percent = 0
owner._smog_analogue_phase_color_box = base_color_box
owner._smog_analogue_percent_layout = nil
owner._smog_analogue_layout = nil
owner._smog_analogue_font = nil
owner._smog_analogue_arc_cx = nil
owner._smog_analogue_arc_cy = nil
owner._smog_analogue_arc_radius = nil
owner._smog_analogue_arc_width = nil
owner._smog_analogue_arc_fill_percent = nil
owner._smog_analogue_fill_geometry = {}
owner._smog_analogue_remainder_geometry = {}
owner._smog_analogue_hub_outer_geometry = {}
owner._smog_analogue_hub_inner_geometry = {}
end
function Renderer.draw(owner,dt,gui,scale,screen_width,screen_height)
sample(owner)
local outer_radius = 72 * scale
local cx,cy = Common.position(owner,screen_width,screen_height,scale,outer_radius)
local current_layout = analogue_layout(owner,gui,scale,cx,cy)
if not current_layout then
return
end
local percent = owner._smog_analogue_percent or 0
local percent_text = owner._smog_analogue_percent_text or "0%"
local fill_percent = owner._smog_analogue_fill_percent or 0
local phase_color_box = owner._smog_analogue_phase_color_box or base_color_box
ensure_arc_geometry(owner,cx,cy,current_layout.arc_radius,current_layout.arc_width,fill_percent)
draw_arc_geometry(gui,owner._smog_analogue_remainder_geometry,base_color_box,810)
if fill_percent > 0 then
draw_arc_geometry(gui,owner._smog_analogue_fill_geometry,phase_color_box,811)
end
ensure_needle_geometry(owner,cx,cy,scale,current_layout.outer_radius,percent)
if Gui and Gui.triangle and owner._smog_analogue_needle_p1 then
Gui.triangle(gui,owner._smog_analogue_needle_p1:unbox(),owner._smog_analogue_needle_p2:unbox(),owner._smog_analogue_needle_p3:unbox(),820,needle_color_box:unbox())
else
draw_line(gui,cx,cy,owner._smog_analogue_needle_tip_x,owner._smog_analogue_needle_tip_y,820,8 * scale,needle_color_box)
end
draw_hub(owner,gui,cx,cy,scale,needle_color_box,hub_hole_box)
local percent_layout = owner._smog_analogue_percent_layout
if not percent_layout or percent_layout.text ~= percent_text or percent_layout.font ~= current_layout.font or percent_layout.font_size ~= current_layout.percent_font_size or percent_layout.cx ~= cx or percent_layout.cy ~= cy or percent_layout.scale ~= scale then
local percent_width = Common.text_width(gui,percent_text,current_layout.font,current_layout.percent_font_size)
percent_layout = {
text = percent_text,
font = current_layout.font,
font_size = current_layout.percent_font_size,
cx = cx,
cy = cy,
scale = scale,
x = cx - percent_width * 0.5 + 2 * scale,
y = cy - current_layout.arc_radius - current_layout.percent_font_size * 0.42 + 8 * scale,
}
owner._smog_analogue_percent_layout = percent_layout
end
Common.draw_text(gui,meter_text,current_layout.font,current_layout.meter_font_size,current_layout.meter_x,current_layout.meter_y,825,meter_color_box:unbox())
Common.draw_text(gui,percent_text,current_layout.font,current_layout.percent_font_size,percent_layout.x,percent_layout.y,825,percent_color_box:unbox())
end
function Renderer.destroy(owner)
owner._smog_analogue_fill_geometry = nil
owner._smog_analogue_remainder_geometry = nil
owner._smog_analogue_hub_outer_geometry = nil
owner._smog_analogue_hub_inner_geometry = nil
end
return Renderer