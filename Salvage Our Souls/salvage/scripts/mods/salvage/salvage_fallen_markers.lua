-- salvage_fallen_markers.lua
local mod = get_mod("salvage")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local context = Mods.file.dofile("salvage/scripts/mods/salvage/salvage_expedition_context")
local clear_table = context.clear_table
local should_run = context.should_run
local is_alive_unit = context.is_alive_unit
local is_valid_unit = context.is_valid_unit
local FALLEN_MARKER_TYPE = "salvage_fallen_comrade_marker"
local FALLEN_MARKER_PENDING = "pending"
local FALLEN_MARKER_ICON = ""
local FALLEN_MARKER_REASON_DEATH = "death"
local FALLEN_MARKER_REASON_DISABLED = "disabled"
local FALLEN_MARKER_BASE_FONT_SIZE = 56
local FALLEN_MARKER_DEATH_FONT_SIZE = math.floor(FALLEN_MARKER_BASE_FONT_SIZE * 1.3 + 0.5)
local FALLEN_MARKER_DISABLED_FONT_SIZE = 45
local FALLEN_MARKER_WIDGET_SIZE = 128
local FALLEN_MARKER_MAX_DISTANCE = 1000
local FALLEN_MARKER_CLOSE_DISTANCE = 3
local FALLEN_MARKER_POSITION_OFFSET = { 0, 0, 1.25 }
local FALLEN_MARKER_DEATH_COLOUR = { 255, 255, 0, 0 }
local FALLEN_MARKER_DISABLED_COLOUR = { 255, 255, 84, 0 }
local FALLEN_MARKER_SHADOW = { 220, 0, 0, 0 }
local FALLEN_MARKER_INVISIBLE = { 0, 0, 0, 0 }
local tracked_fallen_markers_by_unit = setmetatable({}, { __mode = "k" })
local found_fallen_comrades_by_unit = setmetatable({}, { __mode = "k" })
mod._salvage_fallen_marker_teammates_scratch = mod._salvage_fallen_marker_teammates_scratch or {}
mod._salvage_fallen_marker_desired_units_scratch = mod._salvage_fallen_marker_desired_units_scratch or {}
local function fallen_comrade_markers_enabled()
local setting = mod:get("mark_fallen_comrades")
return setting == "dead_only" or setting == "downed_only" or setting == "disabled_only" or setting == "dead_or_downed" or setting == "all"
end
local function world_markers_element()
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
return hud and hud.element and hud:element("HudElementWorldMarkers") or nil
end
local function fallen_marker_reason_from_source(reason)
if reason == FALLEN_MARKER_REASON_DEATH then
return FALLEN_MARKER_REASON_DEATH
end
return FALLEN_MARKER_REASON_DISABLED
end
local function fallen_marker_colour(reason)
if reason == FALLEN_MARKER_REASON_DEATH then
return FALLEN_MARKER_DEATH_COLOUR
end
return FALLEN_MARKER_DISABLED_COLOUR
end
local function fallen_marker_font_size(reason)
if reason == FALLEN_MARKER_REASON_DEATH then
return FALLEN_MARKER_DEATH_FONT_SIZE
end
return FALLEN_MARKER_DISABLED_FONT_SIZE
end
local function fallen_marker_is_live(marker_id)
if not marker_id or marker_id == FALLEN_MARKER_PENDING then
return false
end
local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id
return markers_by_id and markers_by_id[marker_id] ~= nil or false
end
local function remove_fallen_marker_for_unit(unit)
local record = tracked_fallen_markers_by_unit[unit]
local marker_id = record and record.id
if fallen_marker_is_live(marker_id) and Managers and Managers.event then
Managers.event:trigger("remove_world_marker", marker_id)
end
tracked_fallen_markers_by_unit[unit] = nil
end
local function remove_all_fallen_markers()
for unit, _ in pairs(tracked_fallen_markers_by_unit) do
remove_fallen_marker_for_unit(unit)
end
clear_table(found_fallen_comrades_by_unit)
end
local function update_pending_fallen_markers()
for unit, record in pairs(tracked_fallen_markers_by_unit) do
if not is_alive_unit(unit) then
tracked_fallen_markers_by_unit[unit] = nil
elseif record.id == FALLEN_MARKER_PENDING then
record.pending_frames = (record.pending_frames or 0) + 1
if record.pending_frames >= 30 then
tracked_fallen_markers_by_unit[unit] = nil
end
elseif record.id and not fallen_marker_is_live(record.id) then
tracked_fallen_markers_by_unit[unit] = nil
end
end
end
local function update_fallen_marker_widget(widget, marker, marker_template)
local content = widget.content
local style = widget.style
local visible = marker.draw ~= false
local unit = marker.unit
local record = unit and tracked_fallen_markers_by_unit[unit]
local reason = fallen_marker_reason_from_source(record and record.reason)
local colour = fallen_marker_colour(reason)
local font_size = fallen_marker_font_size(reason)
widget.visible = true
content.icon = FALLEN_MARKER_ICON
style.icon_shadow.font_size = font_size
style.icon.font_size = font_size
style.icon_shadow.size[1] = FALLEN_MARKER_WIDGET_SIZE
style.icon_shadow.size[2] = FALLEN_MARKER_WIDGET_SIZE
style.icon.size[1] = FALLEN_MARKER_WIDGET_SIZE
style.icon.size[2] = FALLEN_MARKER_WIDGET_SIZE
style.icon_shadow.text_color = visible and FALLEN_MARKER_SHADOW or FALLEN_MARKER_INVISIBLE
style.icon.text_color = visible and colour or FALLEN_MARKER_INVISIBLE
marker_template.max_distance = FALLEN_MARKER_MAX_DISTANCE
marker.scale = 1
marker.ignore_scale = true
end
local function create_fallen_marker_template()
local font_settings = UIFontSettings.hud_body
local template = {}
template.name = FALLEN_MARKER_TYPE
template.size = { FALLEN_MARKER_WIDGET_SIZE, FALLEN_MARKER_WIDGET_SIZE }
template.unit_node = "j_hips"
template.position_offset = FALLEN_MARKER_POSITION_OFFSET
template.max_distance = FALLEN_MARKER_MAX_DISTANCE
template.screen_clamp = true
template.screen_margins = {
down = 0.18,
left = 0.18,
right = 0.18,
up = 0.18,
}
template.check_line_of_sight = false
template.using_smart_tag_system = false
template.scale_settings = {
distance_min = 0,
distance_max = FALLEN_MARKER_MAX_DISTANCE,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil
template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "icon_shadow",
value = FALLEN_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = FALLEN_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
size = { FALLEN_MARKER_WIDGET_SIZE, FALLEN_MARKER_WIDGET_SIZE },
text_color = FALLEN_MARKER_SHADOW,
},
},
{
pass_type = "text",
style_id = "icon",
value = FALLEN_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = FALLEN_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
size = { FALLEN_MARKER_WIDGET_SIZE, FALLEN_MARKER_WIDGET_SIZE },
text_color = FALLEN_MARKER_DEATH_COLOUR,
},
},
}, scenegraph_id)
end
template.on_enter = function(widget, marker, marker_template)
update_fallen_marker_widget(widget, marker, marker_template)
end
template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
update_fallen_marker_widget(widget, marker, marker_template)
end
return template
end
local function ensure_fallen_marker_template()
local world_markers = world_markers_element()
if not world_markers or not world_markers._marker_templates then
return false
end
if not world_markers._marker_templates[FALLEN_MARKER_TYPE] then
world_markers._marker_templates[FALLEN_MARKER_TYPE] = create_fallen_marker_template()
end
return true
end
local function local_player_unit_for_fallen_markers()
local player_manager = Managers and Managers.player
local player = player_manager and player_manager.local_player and player_manager:local_player(1)
local unit = player and player.player_unit
if is_alive_unit(unit) then
return unit
end
return nil
end
function mod._salvage_box_position(position)
if not position or not Vector3Box then
return nil
end
local source_position = position
if type(Vector3Box.unbox) == "function" then
local unbox_success, unboxed_position = pcall(Vector3Box.unbox, position)
if unbox_success and unboxed_position then
source_position = unboxed_position
end
end
local box_success, position_box = pcall(Vector3Box, source_position)
if box_success then
return position_box
end
return nil
end
function mod._salvage_unbox_position(position_box)
if not position_box or not Vector3Box or type(Vector3Box.unbox) ~= "function" then
return nil
end
local success, position = pcall(Vector3Box.unbox, position_box)
if success then
return position
end
return nil
end
function mod._salvage_stored_record_position(record)
if type(record) ~= "table" then
return nil
end
local position = mod._salvage_unbox_position(record.position_box)
if position then
return position
end
record.position_box = nil
return nil
end
function mod._salvage_set_stored_record_position(record, position)
if type(record) ~= "table" then
return false
end
record.position_box = mod._salvage_box_position(position)
return record.position_box ~= nil
end
function mod._salvage_safe_vector_distance(first_position, second_position)
if not first_position or not second_position or not Vector3 or type(Vector3.distance) ~= "function" then
return nil
end
local success, distance = pcall(Vector3.distance, first_position, second_position)
if success and type(distance) == "number" then
return distance
end
return nil
end
local function unit_position(unit)
if is_alive_unit(unit) then
if POSITION_LOOKUP and POSITION_LOOKUP[unit] then
return POSITION_LOOKUP[unit]
end
if Unit and Unit.world_position then
local success, position = pcall(Unit.world_position, unit, ROOT_NODE_INDEX)
if success then
return position
end
end
end
return nil
end
local function player_unit_from_player(player)
local unit = player and player.player_unit
if is_alive_unit(unit) then
return unit
end
return nil
end
local function fallen_marker_reason_for_player_unit(unit)
if not is_alive_unit(unit) or not ScriptUnit or not ScriptUnit.has_extension then
return nil
end
local success, unit_data_extension = pcall(ScriptUnit.has_extension, unit, "unit_data_system")
if not success or not unit_data_extension or type(unit_data_extension.read_component) ~= "function" then
return nil
end
local read_success, character_state_component = pcall(unit_data_extension.read_component, unit_data_extension, "character_state")
if not read_success or not character_state_component then
return nil
end
local state_name = character_state_component.state_name
if state_name == "dead" or state_name == "hogtied" then
return FALLEN_MARKER_REASON_DEATH
end
if PlayerUnitStatus and type(PlayerUnitStatus.is_hogtied) == "function" then
local hogtied_success, is_hogtied = pcall(PlayerUnitStatus.is_hogtied, character_state_component)
if hogtied_success and is_hogtied == true then
return FALLEN_MARKER_REASON_DEATH
end
end
if state_name == "knocked_down" then
return "knocked_down"
end
if PlayerUnitStatus and type(PlayerUnitStatus.is_knocked_down) == "function" then
local knocked_down_success, is_knocked_down = pcall(PlayerUnitStatus.is_knocked_down, character_state_component)
if knocked_down_success and is_knocked_down == true then
return "knocked_down"
end
end
if PlayerUnitStatus and type(PlayerUnitStatus.is_disabled) == "function" then
local disabled_success, is_disabled = pcall(PlayerUnitStatus.is_disabled, character_state_component)
if disabled_success and is_disabled == true then
return FALLEN_MARKER_REASON_DISABLED
end
end
local disabled_success, disabled_character_state_component = pcall(unit_data_extension.read_component, unit_data_extension, "disabled_character_state")
if disabled_success and disabled_character_state_component and disabled_character_state_component.is_disabled == true then
return FALLEN_MARKER_REASON_DISABLED
end
return nil
end
local function request_fallen_marker(unit, reason)
if not is_alive_unit(unit) or not ensure_fallen_marker_template() or not Managers or not Managers.event then
return
end
local record = tracked_fallen_markers_by_unit[unit]
local marker_reason = fallen_marker_reason_from_source(reason)
if record and record.id == FALLEN_MARKER_PENDING then
record.reason = marker_reason
return
end
if record and fallen_marker_is_live(record.id) then
record.reason = marker_reason
return
end
record = {
id = FALLEN_MARKER_PENDING,
pending_frames = 0,
reason = marker_reason,
}
tracked_fallen_markers_by_unit[unit] = record
local function on_marker_added(marker_id)
local current_record = tracked_fallen_markers_by_unit[unit]
if current_record and current_record.id == FALLEN_MARKER_PENDING then
current_record.id = marker_id
current_record.pending_frames = nil
end
end
Managers.event:trigger("add_world_marker_unit", FALLEN_MARKER_TYPE, unit, on_marker_added, {
unit = unit,
})
end
local function collect_fallen_marker_teammates(local_unit)
local units = mod._salvage_fallen_marker_teammates_scratch
clear_table(units)
local player_manager = Managers and Managers.player
if not player_manager or type(player_manager.players) ~= "function" then
return units
end
local success, players = pcall(player_manager.players, player_manager)
if not success or type(players) ~= "table" then
return units
end
local setting = mod:get("mark_fallen_comrades")
for _, player in pairs(players) do
local unit = player_unit_from_player(player)
local reason = unit and unit ~= local_unit and fallen_marker_reason_for_player_unit(unit) or nil
local is_dead = reason == FALLEN_MARKER_REASON_DEATH
local is_downed = reason == "knocked_down"
local is_disabled = reason == FALLEN_MARKER_REASON_DISABLED
local allowed = setting == "all" and (is_dead or is_downed or is_disabled) or setting == "dead_only" and is_dead or setting == "downed_only" and is_downed or setting == "disabled_only" and is_disabled or setting == "dead_or_downed" and (is_dead or is_downed)
if unit and reason and allowed then
units[unit] = reason
end
end
return units
end
local function sync_fallen_comrade_markers()
if not should_run() or not fallen_comrade_markers_enabled() then
remove_all_fallen_markers()
return
end
local local_unit = local_player_unit_for_fallen_markers()
if not local_unit then
remove_all_fallen_markers()
return
end
if not ensure_fallen_marker_template() then
return
end
update_pending_fallen_markers()
local local_position = unit_position(local_unit)
local desired_units = mod._salvage_fallen_marker_desired_units_scratch
clear_table(desired_units)
local fallen_units = collect_fallen_marker_teammates(local_unit)
for unit, reason in pairs(fallen_units) do
local position = unit_position(unit)
local is_death_marker = reason == FALLEN_MARKER_REASON_DEATH
local distance = is_death_marker and mod._salvage_safe_vector_distance(local_position, position) or nil
if is_death_marker and distance and distance <= FALLEN_MARKER_CLOSE_DISTANCE then
found_fallen_comrades_by_unit[unit] = true
remove_fallen_marker_for_unit(unit)
elseif not is_death_marker or not found_fallen_comrades_by_unit[unit] then
desired_units[unit] = true
request_fallen_marker(unit, reason)
end
end
for unit, _ in pairs(tracked_fallen_markers_by_unit) do
if not desired_units[unit] then
remove_fallen_marker_for_unit(unit)
end
end
for unit, _ in pairs(found_fallen_comrades_by_unit) do
if fallen_marker_reason_for_player_unit(unit) ~= FALLEN_MARKER_REASON_DEATH then
found_fallen_comrades_by_unit[unit] = nil
end
end
end
local fallen = {}
function fallen.sync()
sync_fallen_comrade_markers()
end
function fallen.remove_all()
remove_all_fallen_markers()
end
function fallen.remove_for_unit(unit)
remove_fallen_marker_for_unit(unit)
end
function fallen.clear_found(unit)
found_fallen_comrades_by_unit[unit] = nil
end
return fallen
