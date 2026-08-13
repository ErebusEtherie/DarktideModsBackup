-- huntsalvage.lua
local mod = get_mod("huntsalvage")
local UIWidget = require("scripts/managers/ui/ui_widget")
local MARKER_TYPE = "hunt_salvage_marker"
local SCAN_INTERVAL = 1
local NEAREST_UPDATE_INTERVAL = 1.2
local SALVAGE_YELLOW = {
255,
255,
230,
0,
}
local SALVAGE_BACKGROUND = {
180,
0,
0,
0,
}
local DEFAULT_MARKER_TEXT_COLOUR = {
255,
255,
255,
255,
}
local SALVAGE_PICKUPS = {
expedition_currency_small_tier_1 = true,
expedition_currency_small_tier_2 = true,
}
mod._hs_known_units = {}
mod._hs_live_units = {}
mod._hs_unit_cache = {}
mod._hs_checked_units = {}
mod._hs_skipped_units = {}
mod._hs_counts = {
collected = 0,
total = 0,
visible = false,
}
mod._hs_next_scan_t = 0
mod._hs_next_nearest_t = 0
mod._hs_zone_index = nil
mod._hs_was_active = false
mod._hs_marker_template_hooked = false
mod._hs_world_markers_calculate_hooked = false
mod._hs_markers_aio_hooked = false
mod._hs_completion_flash_until = 0
mod._hs_final_zone = false
mod._hs_was_safe_zone = false
mod._hs_safe_zone_state_known = false
mod._hs_last_play_zone_index = nil
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
mod._hs_nearest_marker_unit = nil
mod._hs_nearest_marker_id = nil
mod._hs_nearest_marker_pending_until = 0
mod._hs_marker_generation = 0
local function clear_table(t)
for key in pairs(t) do
t[key] = nil
end
end
local function copy_colour(dst, src)
if not dst or not src then
return
end
dst[1] = src[1] or 255
dst[2] = src[2] or 255
dst[3] = src[3] or 255
dst[4] = src[4] or 255
end
local function clone_colour(src)
return {
src[1],
src[2],
src[3],
src[4],
}
end
local function unit_alive(unit)
return unit and ALIVE and ALIVE[unit]
end
local function as_vector3(value)
if value == nil or not Vector3 or not Vector3.to_elements then
return nil
end
local success, x, y, z = pcall(Vector3.to_elements, value)
if success and type(x) == "number" and type(y) == "number" and type(z) == "number" then
return value
end
local unbox_success, unboxed = pcall(function ()
return value:unbox()
end)
if unbox_success and unboxed ~= nil then
local vector_success, ux, uy, uz = pcall(Vector3.to_elements, unboxed)
if vector_success and type(ux) == "number" and type(uy) == "number" and type(uz) == "number" then
return unboxed
end
end
local component_success, cx, cy, cz = pcall(function ()
return value.x, value.y, value.z
end)
if component_success and type(cx) == "number" and type(cy) == "number" and type(cz) == "number" then
local create_success, created = pcall(Vector3, cx, cy, cz)
if create_success then
return created
end
end
return nil
end
local function unit_position(unit)
if not unit_alive(unit) then
return nil
end
local position_lookup = POSITION_LOOKUP
local position = as_vector3(position_lookup and position_lookup[unit])
if position then
return position
end
if Unit and Unit.world_position then
local success, result = pcall(Unit.world_position, unit, 1)
if success then
return as_vector3(result)
end
end
return nil
end
local function unit_pickup_type(unit)
if not unit_alive(unit) or not Unit or not Unit.has_data or not Unit.get_data then
return nil
end
local has_data_success, has_data = pcall(Unit.has_data, unit, "pickup_type")
if not has_data_success or not has_data then
return nil
end
local get_data_success, pickup_type = pcall(Unit.get_data, unit, "pickup_type")
if get_data_success then
return pickup_type
end
return nil
end
local function is_salvage_unit(unit)
if not unit_alive(unit) then
return false
end
local cached = mod._hs_unit_cache[unit]
if cached ~= nil then
return cached == true
end
local pickup_type = unit_pickup_type(unit)
if pickup_type then
local is_salvage = SALVAGE_PICKUPS[pickup_type] == true
mod._hs_unit_cache[unit] = is_salvage
return is_salvage
end
return false
end
local function game_mode()
local state_managers = Managers and Managers.state
local game_mode_manager = state_managers and state_managers.game_mode
if not game_mode_manager then
return nil, nil
end
local mode_name
if game_mode_manager.game_mode_name then
local success, result = pcall(function ()
return game_mode_manager:game_mode_name()
end)
if success then
mode_name = result
end
end
if mode_name ~= "expedition" then
return nil, mode_name
end
if not game_mode_manager.game_mode then
return nil, mode_name
end
local success, mode = pcall(function ()
return game_mode_manager:game_mode()
end)
if success then
return mode, mode_name
end
return nil, mode_name
end
local function in_safe_zone(mode)
if not mode or not mode.in_safe_zone then
return false
end
local success, result = pcall(function ()
return mode:in_safe_zone()
end)
return success and result == true
end
local function current_zone(mode)
if not mode or not mode.current_location_index then
return nil
end
local success, result = pcall(function ()
return mode:current_location_index()
end)
if success then
return result
end
return nil
end
local function expedition_total_zones(mode)
local logic = mode and rawget(mode, "_game_mode_logic")
local expedition = logic and rawget(logic, "_expedition")
if type(expedition) == "table" then
return #expedition
end
local levels_spawner = logic and rawget(logic, "_levels_spawner")
if levels_spawner and levels_spawner.expedition then
local success, result = pcall(function ()
return levels_spawner:expedition()
end)
if success and type(result) == "table" then
return #result
end
end
return nil
end
local function is_final_expedition_zone(mode, zone_index)
local total_zones = expedition_total_zones(mode)
return zone_index ~= nil and total_zones ~= nil and (total_zones == 3 or total_zones == 5) and zone_index == total_zones
end
local function update_completion_flash(mode, zone_index, safe_zone, t)
local current_safe_zone = safe_zone == true
if not current_safe_zone and zone_index ~= nil then
mod._hs_last_play_zone_index = zone_index
end
if mod._hs_safe_zone_state_known ~= true then
mod._hs_safe_zone_state_known = true
mod._hs_was_safe_zone = current_safe_zone
return
end
local was_safe_zone = mod._hs_was_safe_zone == true
if current_safe_zone and not was_safe_zone then
local total_zones = expedition_total_zones(mode)
local last_play_zone = mod._hs_last_play_zone_index
if mod:get("last_sanctuary_warning") ~= false and last_play_zone and total_zones and last_play_zone == total_zones - 1 and (total_zones == 3 or total_zones == 5) then
mod._hs_completion_flash_until = t + 1.2
end
end
mod._hs_was_safe_zone = current_safe_zone
end
local function local_player_unit()
local player_manager = Managers and Managers.player
local connection_manager = Managers and Managers.connection
if not player_manager or not connection_manager or not connection_manager.is_initialized then
return nil
end
local connection_success, connection_ready = pcall(function ()
return connection_manager:is_initialized()
end)
if not connection_success or connection_ready ~= true then
return nil
end
if player_manager.num_human_players then
local count_success, num_human_players = pcall(function ()
return player_manager:num_human_players()
end)
if not count_success or not num_human_players or num_human_players < 1 then
return nil
end
elseif rawget(player_manager, "_num_human_players") and rawget(player_manager, "_num_human_players") < 1 then
return nil
end
local player
if player_manager.local_player_safe then
local success, result = pcall(function ()
return player_manager:local_player_safe(1)
end)
if success then
player = result
end
elseif player_manager.local_player then
local success, result = pcall(function ()
return player_manager:local_player(1)
end)
if success then
player = result
end
end
return player and player.player_unit or nil
end
local function pickup_system()
local state_managers = Managers and Managers.state
local extension_manager = state_managers and state_managers.extension
if not extension_manager or not extension_manager.system then
return nil
end
local success, system = pcall(function ()
return extension_manager:system("pickup_system")
end)
if success then
return system
end
return nil
end
local function unit_spawner()
local state_managers = Managers and Managers.state
return state_managers and state_managers.unit_spawner
end
local function try_unit(unit, checked, callback)
if unit and not checked[unit] then
checked[unit] = true
if is_salvage_unit(unit) then
callback(unit)
end
end
end
local function each_pickup_unit(callback)
local checked = mod._hs_checked_units
clear_table(checked)
local spawner = unit_spawner()
local network_units = spawner and rawget(spawner, "_network_units")
if type(network_units) == "table" then
for _, unit in pairs(network_units) do
try_unit(unit, checked, callback)
end
end
local game_object_ids = spawner and rawget(spawner, "_game_object_ids")
if type(game_object_ids) == "table" then
for unit in pairs(game_object_ids) do
try_unit(unit, checked, callback)
end
end
local system = pickup_system()
local spawned_pickups = system and rawget(system, "_spawned_pickups")
if type(spawned_pickups) == "table" then
for i = 1, #spawned_pickups do
try_unit(spawned_pickups[i], checked, callback)
end
end
end
local function world_markers_element()
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
if not hud then
return nil
end
if hud.element then
local success, element = pcall(function ()
return hud:element("HudElementWorldMarkers")
end)
if success and element then
return element
end
end
local elements = rawget(hud, "_elements")
return elements and elements.HudElementWorldMarkers
end
local function markers_aio_mod()
if mod._hs_markers_aio then
return mod._hs_markers_aio
end
if not get_mod then
return nil
end
local success, markers_aio = pcall(get_mod, "markers_aio")
if success and markers_aio then
mod._hs_markers_aio = markers_aio
return markers_aio
end
return nil
end
local function marker_pickup_type(marker)
if not marker then
return nil
end
if marker.pickup_type then
return marker.pickup_type
end
local markers_aio = markers_aio_mod()
if markers_aio and type(markers_aio.get_marker_pickup_type) == "function" then
local success, pickup_type = pcall(markers_aio.get_marker_pickup_type, marker)
if success and pickup_type then
marker.pickup_type = pickup_type
return pickup_type
end
end
local unit = marker.unit
if unit and is_salvage_unit(unit) then
local pickup_type = unit_pickup_type(unit)
marker.pickup_type = pickup_type
return pickup_type
end
return nil
end
local function marker_is_salvage(marker)
if not marker then
return false
end
local pickup_type = marker_pickup_type(marker)
local is_salvage = pickup_type and SALVAGE_PICKUPS[pickup_type] == true or false
local unit = marker.unit
if unit and pickup_type then
mod._hs_unit_cache[unit] = is_salvage
end
return is_salvage == true
end
local function is_custom_marker(marker)
local template = marker and marker.template
return marker and (marker.type == MARKER_TYPE or template and template.name == MARKER_TYPE)
end
local function hide_marker(marker)
if not marker then
return
end
marker.draw = false
local widget = marker.widget
if widget then
widget.visible = false
widget.alpha_multiplier = 0
end
end
local function valid_number(value)
return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function vector3_distance(first, second)
local first_position = as_vector3(first)
local second_position = as_vector3(second)
if not first_position or not second_position or not Vector3 or not Vector3.distance then
return nil
end
local success, distance = pcall(Vector3.distance, first_position, second_position)
if success and valid_number(distance) then
return distance
end
return nil
end
local function distance_text(distance)
return valid_number(distance) and tostring(math.floor(distance + 0.5)) .. "m" or ""
end
local function style_nearest_custom_marker(widget, distance)
if not widget then
return
end
local content = widget.content
local style = widget.style
local highlight_enabled = mod:get("highlight_next_salvage") ~= false
local show_distance = highlight_enabled and mod:get("show_distance_to_next_salvage") ~= false
if content then
content.background = highlight_enabled and "content/ui/materials/hud/interactions/frames/mission_back" or nil
content.ring = highlight_enabled and "content/ui/materials/hud/interactions/frames/mission_top" or nil
content.icon = highlight_enabled and "content/ui/materials/hud/interactions/icons/environment_generic" or nil
content.arrow = highlight_enabled and "content/ui/materials/hud/interactions/frames/direction" or nil
content.tagged = highlight_enabled
content.marker_distance_text = show_distance and distance_text(distance) or ""
content.line_of_sight_progress = 1
end
widget.visible = highlight_enabled
widget.alpha_multiplier = highlight_enabled and 1 or 0
if style then
if style.background then
style.background.size[1] = 104
style.background.size[2] = 104
copy_colour(style.background.color, SALVAGE_BACKGROUND)
end
if style.ring then
style.ring.size[1] = 122
style.ring.size[2] = 122
copy_colour(style.ring.color, SALVAGE_YELLOW)
end
if style.ping then
style.ping.size[1] = 132
style.ping.size[2] = 132
copy_colour(style.ping.color, SALVAGE_YELLOW)
style.ping.color[1] = 155
end
if style.icon then
style.icon.size[1] = 64
style.icon.size[2] = 64
copy_colour(style.icon.color, SALVAGE_YELLOW)
end
if style.arrow then
style.arrow.size[1] = 88
style.arrow.size[2] = 88
copy_colour(style.arrow.color, SALVAGE_YELLOW)
end
if style.marker_distance_text then
style.marker_distance_text.font_size = 20
style.marker_distance_text.offset[1] = 0
style.marker_distance_text.offset[2] = 66
style.marker_distance_text.offset[3] = 8
copy_colour(style.marker_distance_text.text_color, SALVAGE_YELLOW)
end
end
end
local function set_nearest_marker_passthrough(marker)
local template = marker and marker.template
if template then
template.max_distance = nil
template.check_line_of_sight = false
template.screen_clamp = true
end
if marker then
marker.max_distance = nil
marker.aio_check_line_of_sight = false
marker.raycast_result = false
marker.raycast_initialized = false
marker.block_screen_clamp = false
marker.block_max_distance = true
marker.block_fade_settings = true
end
end
local function apply_custom_marker(marker)
if not marker or not is_custom_marker(marker) then
return false
end
local nearest_unit = mod._hs_nearest_unit
if marker.unit ~= nearest_unit or mod:get("enable_mod") == false or mod:get("highlight_next_salvage") == false or mod._hs_counts.visible ~= true then
marker.remove = true
hide_marker(marker)
return false
end
set_nearest_marker_passthrough(marker)
style_nearest_custom_marker(marker.widget, valid_number(marker.distance) and marker.distance or mod._hs_nearest_distance)
marker.markers_aio_type = nil
marker.draw = true
return true
end
local function restore_existing_marker(marker)
if not marker or is_custom_marker(marker) or marker._hs_hidden_by_huntsalvage ~= true then
return false
end
marker._hs_hidden_by_huntsalvage = nil
local widget = marker.widget
if widget then
widget.visible = true
widget.alpha_multiplier = 1
end
return true
end
local function hide_existing_nearest_marker(marker)
if mod:get("highlight_next_salvage") == false or not marker or is_custom_marker(marker) or marker.unit ~= mod._hs_nearest_unit or not marker_is_salvage(marker) then
return false
end
hide_marker(marker)
marker.draw = false
marker._hs_hidden_by_huntsalvage = true
return true
end
local function try_hook_markers_aio()
if mod._hs_markers_aio_hooked then
return
end
local markers_aio = markers_aio_mod()
if not markers_aio or type(markers_aio.update_expedition_markers) ~= "function" then
return
end
local original_update_expedition_markers = markers_aio.update_expedition_markers
markers_aio.update_expedition_markers = function (self, marker)
original_update_expedition_markers(self, marker)
if mod:get("enable_mod") ~= false and mod:get("highlight_next_salvage") ~= false and marker and marker.unit == mod._hs_nearest_unit and marker_is_salvage(marker) then
hide_existing_nearest_marker(marker)
end
end
mod._hs_markers_aio_hooked = true
end
local ensure_nearest_marker
local remove_nearest_marker
local function apply_marker_controls(t)
local world_markers = world_markers_element()
local markers_by_type = world_markers and world_markers._markers_by_type
local nearest_unit = mod._hs_nearest_unit
local highlight_enabled = mod:get("highlight_next_salvage") ~= false
if not markers_by_type then
return
end
local interaction_markers = markers_by_type.interaction
if interaction_markers then
for i = 1, #interaction_markers do
local marker = interaction_markers[i]
if highlight_enabled and nearest_unit and marker and marker.unit == nearest_unit and marker_is_salvage(marker) then
hide_existing_nearest_marker(marker)
else
restore_existing_marker(marker)
end
end
end
if highlight_enabled and nearest_unit then
ensure_nearest_marker(nearest_unit, t or 0)
else
remove_nearest_marker()
end
local custom_markers = markers_by_type[MARKER_TYPE]
if custom_markers then
for i = 1, #custom_markers do
apply_custom_marker(custom_markers[i])
end
end
end
local function remove_marker_id(marker_id)
if marker_id and Managers and Managers.event then
Managers.event:trigger("remove_world_marker", marker_id)
end
end
local function custom_marker_list()
local world_markers = world_markers_element()
local markers_by_type = world_markers and world_markers._markers_by_type
return markers_by_type and markers_by_type[MARKER_TYPE] or nil
end
local function remove_custom_marker(marker)
if not marker then
return
end
hide_marker(marker)
marker.remove = true
remove_marker_id(marker.id)
end
local function remove_all_custom_markers()
local custom_markers = custom_marker_list()
if custom_markers then
for i = #custom_markers, 1, -1 do
remove_custom_marker(custom_markers[i])
end
end
mod._hs_marker_generation = (mod._hs_marker_generation or 0) + 1
mod._hs_nearest_marker_id = nil
mod._hs_nearest_marker_unit = nil
mod._hs_nearest_marker_pending_until = 0
end
remove_nearest_marker = function ()
local marker_id = mod._hs_nearest_marker_id
local marker_unit = mod._hs_nearest_marker_unit
local custom_markers = custom_marker_list()
if custom_markers then
for i = #custom_markers, 1, -1 do
local marker = custom_markers[i]
if marker and (marker.id == marker_id or marker.unit == marker_unit) then
remove_custom_marker(marker)
end
end
end
remove_marker_id(marker_id)
mod._hs_marker_generation = (mod._hs_marker_generation or 0) + 1
mod._hs_nearest_marker_id = nil
mod._hs_nearest_marker_unit = nil
mod._hs_nearest_marker_pending_until = 0
end
local marker_template = {
name = MARKER_TYPE,
max_distance = nil,
check_line_of_sight = false,
screen_clamp = true,
position_offset = {
0,
0,
0.8,
},
screen_margins = {
down = 0.07,
left = 0.07,
right = 0.07,
up = 0.07,
},
fade_settings = nil,
scale_settings = nil,
}
marker_template.create_widget_defintion = function (self, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "texture",
style_id = "background",
value = "content/ui/materials/hud/interactions/frames/mission_back",
value_id = "background",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
size = {
160,
160,
},
offset = {
0,
0,
1,
},
color = clone_colour(SALVAGE_BACKGROUND),
},
visibility_function = function (content)
return content.background ~= nil
end,
},
{
pass_type = "texture",
style_id = "ring",
value = "content/ui/materials/hud/interactions/frames/mission_top",
value_id = "ring",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
size = {
160,
160,
},
offset = {
0,
0,
5,
},
color = clone_colour(SALVAGE_YELLOW),
},
visibility_function = function (content)
return content.ring ~= nil
end,
},
{
pass_type = "rotated_texture",
style_id = "ping",
value = "content/ui/materials/hud/interactions/frames/mission_tag",
value_id = "ping",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
size = {
132,
132,
},
offset = {
0,
0,
6,
},
color = {
155,
255,
230,
0,
},
},
visibility_function = function (content)
return content.tagged == true
end,
},
{
pass_type = "texture",
style_id = "icon",
value = "content/ui/materials/hud/interactions/icons/environment_generic",
value_id = "icon",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
size = {
64,
64,
},
offset = {
0,
0,
4,
},
color = clone_colour(SALVAGE_YELLOW),
},
visibility_function = function (content)
return content.icon ~= nil
end,
},
{
pass_type = "rotated_texture",
style_id = "arrow",
value = "content/ui/materials/hud/interactions/frames/direction",
value_id = "arrow",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
size = {
105,
105,
},
offset = {
0,
0,
3,
},
color = clone_colour(SALVAGE_YELLOW),
},
visibility_function = function (content)
return content.is_clamped == true and content.arrow ~= nil
end,
change_function = function (content, style)
style.angle = content.angle
end,
},
{
pass_type = "text",
style_id = "marker_distance_text",
value = "",
value_id = "marker_distance_text",
style = {
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
font_type = "machine_medium",
font_size = 20,
size = {
160,
36,
},
offset = {
0,
82,
8,
},
text_color = clone_colour(SALVAGE_YELLOW),
},
visibility_function = function (content)
return content.marker_distance_text ~= nil and content.marker_distance_text ~= ""
end,
},
}, scenegraph_id)
end
marker_template.on_enter = function (widget)
if widget then
style_nearest_custom_marker(widget, nil)
end
end
marker_template.update_function = function (parent, ui_renderer, widget, marker, template, dt, t)
apply_custom_marker(marker)
end
local function try_hook_marker_template()
if mod._hs_marker_template_hooked then
return true
end
if not CLASS or not CLASS.HudElementWorldMarkers then
return false
end
mod:hook(CLASS.HudElementWorldMarkers, "_template_by_type", function (func, self, marker_type, clone)
if marker_type == MARKER_TYPE then
return clone and table.clone(marker_template) or marker_template
end
return func(self, marker_type, clone)
end)
mod._hs_marker_template_hooked = true
return true
end
local function try_hook_world_marker_calculate()
if mod._hs_world_markers_calculate_hooked then
return
end
if not CLASS or not CLASS.HudElementWorldMarkers then
return
end
mod:hook_safe(CLASS.HudElementWorldMarkers, "_calculate_markers", function ()
if mod:get("enable_mod") ~= false and mod._hs_counts.visible == true then
local t = Managers and Managers.time and Managers.time:time("main") or 0
apply_marker_controls(t)
end
end)
mod._hs_world_markers_calculate_hooked = true
end
ensure_nearest_marker = function (unit, t)
if not unit or not try_hook_marker_template() then
return
end
local custom_markers = custom_marker_list()
if custom_markers then
for i = #custom_markers, 1, -1 do
local marker = custom_markers[i]
if marker and marker.unit == unit then
mod._hs_nearest_marker_unit = unit
mod._hs_nearest_marker_id = marker.id
mod._hs_nearest_marker_pending_until = 0
return
end
end
end
if mod._hs_nearest_marker_pending_until > t then
return
end
remove_all_custom_markers()
if not Managers or not Managers.event then
return
end
local generation = mod._hs_marker_generation or 0
mod._hs_nearest_marker_unit = unit
mod._hs_nearest_marker_pending_until = t + 2
Managers.event:trigger("add_world_marker_unit", MARKER_TYPE, unit, function (id)
if generation == mod._hs_marker_generation and mod:get("enable_mod") ~= false and mod._hs_nearest_unit == unit and mod._hs_counts.visible == true then
mod._hs_nearest_marker_id = id
mod._hs_nearest_marker_pending_until = 0
else
remove_marker_id(id)
end
end, {})
end
function mod:is_count_visible()
return self._hs_counts.visible == true and self:get("enable_mod") ~= false and self:get("show_counter") ~= false
end
function mod:is_completion_flash_visible()
local t = Managers and Managers.time and Managers.time:time("main") or 0
return self:get("enable_mod") ~= false and self:get("last_sanctuary_warning") ~= false and (self._hs_completion_flash_until or 0) > t
end
function mod:is_final_zone_counter()
return self:is_count_visible() and self._hs_final_zone == true
end
function mod:salvage_counter_text()
if self._hs_final_zone == true then
return ""
end
local counts = self._hs_counts
local collected = counts.collected or 0
local total = counts.total or 0
local remaining = math.max(total - collected, 0)
local text
if self:get("show_total_as_well") == true then
text = tostring(remaining) .. "/" .. tostring(total)
else
text = tostring(remaining)
end
return text .. " "
end
try_hook_marker_template()
try_hook_world_marker_calculate()
try_hook_markers_aio()
mod:register_hud_element({
class_name = "HuntSalvageHudElement",
filename = "huntsalvage/scripts/mods/huntsalvage/huntsalvage_hud",
visibility_groups = {
"alive",
},
use_hud_scale = true,
})
local function reset_zone(zone_index)
clear_table(mod._hs_known_units)
clear_table(mod._hs_live_units)
clear_table(mod._hs_unit_cache)
clear_table(mod._hs_skipped_units)
remove_all_custom_markers()
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
mod._hs_zone_index = zone_index
mod._hs_counts.collected = 0
mod._hs_counts.total = 0
mod._hs_counts.visible = false
mod._hs_final_zone = false
mod._hs_next_nearest_t = 0
if zone_index == nil then
mod._hs_was_safe_zone = false
mod._hs_safe_zone_state_known = false
mod._hs_last_play_zone_index = nil
end
end
local function set_count(collected, total, visible)
mod._hs_counts.collected = collected
mod._hs_counts.total = total
mod._hs_counts.visible = visible == true
end
local function update_nearest_marker(t)
local player_unit = local_player_unit()
local player_position = unit_position(player_unit)
if not player_position then
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
remove_nearest_marker()
return
end
local nearest_unit
local nearest_distance
local function consider_unit(unit, marker_distance)
if not unit or mod._hs_skipped_units[unit] == true then
return
end
local position = unit_position(unit)
local distance = position and vector3_distance(player_position, position) or nil
if not valid_number(distance) then
distance = valid_number(marker_distance) and marker_distance or nil
end
if valid_number(distance) and (not nearest_distance or distance < nearest_distance) then
nearest_unit = unit
nearest_distance = distance
end
end
for unit in pairs(mod._hs_live_units) do
consider_unit(unit)
end
local world_markers = world_markers_element()
local markers_by_type = world_markers and world_markers._markers_by_type
local interaction_markers = markers_by_type and markers_by_type.interaction
if interaction_markers then
for i = 1, #interaction_markers do
local marker = interaction_markers[i]
if marker and marker.unit and marker_is_salvage(marker) then
consider_unit(marker.unit, marker.distance)
end
end
end
mod._hs_nearest_unit = nearest_unit
mod._hs_nearest_distance = nearest_distance
if not nearest_unit then
remove_nearest_marker()
end
apply_marker_controls(t)
end
if mod.command then
mod:command("s", "Skip nearest salvage.", function ()
local unit = mod._hs_nearest_unit
if unit then
mod._hs_skipped_units[unit] = true
end
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
remove_nearest_marker()
update_nearest_marker(Managers and Managers.time and Managers.time:time("main") or 0)
end)
end
local function scan_salvage(t, mode)
mode = mode or game_mode()
if not mode then
reset_zone(nil)
return
end
local zone_index = current_zone(mode)
if zone_index ~= mod._hs_zone_index then
reset_zone(zone_index)
end
if in_safe_zone(mode) then
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
mod._hs_final_zone = false
remove_nearest_marker()
set_count(0, 0, false)
return
end
if is_final_expedition_zone(mode, zone_index) then
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
mod._hs_final_zone = true
clear_table(mod._hs_live_units)
remove_nearest_marker()
set_count(0, 0, true)
return
end
mod._hs_final_zone = false
local player_unit = local_player_unit()
local player_position = unit_position(player_unit)
if not player_position then
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
mod._hs_final_zone = false
remove_nearest_marker()
set_count(0, 0, false)
return
end
local live_units = mod._hs_live_units
local total_count = 0
local collected_count = 0
clear_table(live_units)
each_pickup_unit(function (unit)
mod._hs_known_units[unit] = true
live_units[unit] = true
end)
for unit in pairs(mod._hs_known_units) do
total_count = total_count + 1
if not live_units[unit] then
collected_count = collected_count + 1
end
end
set_count(collected_count, total_count, true)
update_nearest_marker(t)
end
function mod.update(dt)
local t = Managers and Managers.time and Managers.time:time("main") or 0
local enabled = mod:get("enable_mod") ~= false
try_hook_marker_template()
try_hook_world_marker_calculate()
try_hook_markers_aio()
if not enabled then
remove_all_custom_markers()
if mod._hs_was_active then
reset_zone(nil)
end
mod._hs_was_active = false
return
end
local mode = game_mode()
if not mode then
remove_all_custom_markers()
if mod._hs_was_active then
reset_zone(nil)
end
mod._hs_was_active = false
mod._hs_was_safe_zone = false
return
end
mod._hs_was_active = true
local safe_zone = in_safe_zone(mode)
local zone_index = current_zone(mode)
update_completion_flash(mode, zone_index, safe_zone, t)
if safe_zone then
mod._hs_nearest_unit = nil
mod._hs_nearest_distance = nil
mod._hs_final_zone = false
remove_nearest_marker()
set_count(0, 0, false)
return
end
if t >= mod._hs_next_scan_t then
mod._hs_next_scan_t = t + SCAN_INTERVAL
mod._hs_next_nearest_t = t + NEAREST_UPDATE_INTERVAL
scan_salvage(t, mode)
elseif t >= mod._hs_next_nearest_t then
mod._hs_next_nearest_t = t + NEAREST_UPDATE_INTERVAL
update_nearest_marker(t)
end
end