-- excise-vault-scope.lua
local mod = get_mod("excise-vault-scope")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

local TARGET_MISSION_ID = "lm_scavenge"
local BUTTON_SEARCH_WINDOW = 5
local EXIT_DOOR_SEARCH_WINDOW = 20
local EXTRACTION_OBJECTIVE_NAME = "objective_lm_scavenge_escape"
local EXTRACTION_OBJECTIVE_HEADER = "get to extraction"
local FINAL_DOOR_CANDIDATE_MAX_DISTANCE = 200

local STATE_INACTIVE = 0
local STATE_WAITING_FOR_CASKETS = 1
local STATE_TRACKING_CASKETS = 2
local STATE_SEARCHING_BUTTON = 3
local STATE_BUTTON_LOCKED = 4
local STATE_WAITING_FOR_EXIT_OBJECTIVE = 5
local STATE_SEARCHING_EXIT_DOOR = 6
local STATE_EXIT_DOOR_LOCKED = 7
local STATE_DONE = 8

local CASKET_MARKER_TYPE = "excise_vault_scope_marker"
local BUTTON_MARKER_TYPE = "excise_vault_scope_button_marker"
local MID_EVENT_MARKER_TYPE = "excise_vault_scope_mid_event_marker"

local DEFAULT_CASKET_TEXT = ""
local COUNTDOWN_TEXT_3 = ""
local COUNTDOWN_TEXT_2 = ""
local COUNTDOWN_TEXT_1 = ""
local BUTTON_MARKER_TEXT = ""
local MID_EVENT_INTERROGATOR_TEXT = BUTTON_MARKER_TEXT
local LEVEL_UP_ARROW_TEXT = ""
local LEVEL_DOWN_ARROW_TEXT = ""

local CASKET_MARKER_COLOUR = { 255, 247, 158, 13 }
local BUTTON_MARKER_COLOUR = { 255, 100, 172, 28 }
local MID_EVENT_SETUP_COLOUR = { 255, 161, 174, 155 }
local MID_EVENT_RESTART_COLOUR = { 255, 234, 47, 40 }
local SHADOW_COLOUR = { 200, 0, 0, 0 }
local PENDING_MARKER = "pending"

local DISTANCE_VALUES = {
Near = 20,
Far = 150,
}

local SIZE_FONT_SIZES = {
Small = 65,
Medium = 100,
Large = 150,
}

local FLOOR_Z_SPLIT_MIN_GAP = 6

local settings_normalised = false
local cached_countdown_enabled = false
local cached_final_button_enabled = false
local cached_indicate_level_enabled = false
local cached_include_cypher_ident_mid_event_enabled = false
local cached_marker_font_size = SIZE_FONT_SIZES.Medium
local cached_marker_max_distance = DISTANCE_VALUES.Far

local mission_is_target = false
local mission_detection_complete = false
local state = STATE_INACTIVE
local refresh_requested = false

local tracked_units = {}
local casket_marker_ids = {}
local casket_marker_pending_frames = {}
local tracked_casket_spawn_z = {}
local tracked_casket_floor = {}
local tracked_casket_show_level = {}
local tracked_casket_count = 0
local remaining_caskets = 0
local delivered_caskets = 0

local final_button_unit = nil
local final_button_marker_id = nil
local final_button_marker_pending_frames = nil
local button_search_deadline_t = nil
local exit_door_unit = nil
local exit_door_marker_id = nil
local exit_door_marker_pending_frames = nil
local exit_door_search_deadline_t = nil
local button_prompt_cache = {}

local observed_casket_spawn_z_min = nil
local observed_casket_spawn_z_max = nil
local floor_threshold_z = nil

local mid_event_units = {}
local mid_event_marker_ids = {}
local mid_event_marker_pending_frames = {}
local mid_event_marker_colours = {}
local mid_event_marker_world_positions = {}
local mid_event_door_unit = nil
local mid_event_door_search_active = false
local mid_event_complete = false

local function refresh_cached_settings()
local marker_size = mod:get("marker_size") or "Medium"
local marker_max_distance = mod:get("marker_max_distance") or "Far"

cached_countdown_enabled = mod:get("countdown") == true
cached_final_button_enabled = mod:get("mark_final_button") == true
cached_indicate_level_enabled = mod:get("indicate_level") == true
cached_include_cypher_ident_mid_event_enabled = mod:get("include_cypher_ident_mid_event") == true
cached_marker_font_size = SIZE_FONT_SIZES[marker_size] or SIZE_FONT_SIZES.Medium
cached_marker_max_distance = DISTANCE_VALUES[marker_max_distance] or DISTANCE_VALUES.Far
end

local function normalise_saved_settings_once()
if settings_normalised then
return
end

settings_normalised = true

local changed = false
local size = mod:get("marker_size")

if size == nil or size == "N/A" then
mod:set("marker_size", "Medium")
changed = true
elseif size == "Normal" then
mod:set("marker_size", "Small")
changed = true
elseif size == "Double" then
mod:set("marker_size", "Medium")
changed = true
elseif size == "Triple" then
mod:set("marker_size", "Large")
changed = true
end

local distance = mod:get("marker_max_distance")

if distance == nil or distance == "N/A" then
mod:set("marker_max_distance", "Far")
changed = true
elseif distance == "Middling" then
mod:set("marker_max_distance", "Far")
changed = true
end

if mod:get("countdown") == nil then
mod:set("countdown", false)
changed = true
end

if mod:get("mark_final_button") == nil then
mod:set("mark_final_button", false)
changed = true
end

if mod:get("indicate_level") == nil then
mod:set("indicate_level", false)
changed = true
end

if mod:get("include_cypher_ident_mid_event") == nil then
mod:set("include_cypher_ident_mid_event", false)
changed = true
end

if changed and mod.save then
pcall(mod.save, mod)
end

refresh_cached_settings()
end

local function countdown_enabled()
return cached_countdown_enabled
end

local function final_button_enabled()
return cached_final_button_enabled
end

local function indicate_level_enabled()
return cached_indicate_level_enabled
end

local function include_cypher_ident_mid_event_enabled()
return cached_include_cypher_ident_mid_event_enabled
end

local function marker_font_size()
return cached_marker_font_size
end

local function marker_max_distance()
return cached_marker_max_distance
end

local function button_font_size()
return SIZE_FONT_SIZES.Large
end

local function mid_event_font_size()
return marker_font_size()
end

local function button_max_distance()
return DISTANCE_VALUES.Far
end

local is_valid_unit
local ensure_marker_templates

local function is_finite_number(value)
return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function unit_world_position(unit)
if not is_valid_unit(unit) then
return nil
end

return Unit.world_position(unit, 1)
end

local function unit_world_z(unit)
local position = unit_world_position(unit)

if not position then
return nil
end

local z = position.z or position[3]

return is_finite_number(z) and z or nil
end

local function casket_level_font_size()
return math.max(24, math.floor(marker_font_size() * 0.6))
end

local function casket_level_offset()
return math.max(36, math.floor(marker_font_size() * 0.85))
end

local function get_luggable_extension(unit)
if not is_valid_unit(unit) then
return nil
end

return ScriptUnit.has_extension(unit, "luggable_system")
end

local function is_casket_currently_carried(unit)
local extension = get_luggable_extension(unit)

if not extension or type(extension.is_currently_carried) ~= "function" then
return false
end

local ok, carried = pcall(extension.is_currently_carried, extension)

return ok and carried == true
end

local function clear_casket_level_data(unit)
tracked_casket_spawn_z[unit] = nil
tracked_casket_floor[unit] = nil
tracked_casket_show_level[unit] = nil
end

local function update_floor_threshold_from_spawn_z(spawn_z)
if not is_finite_number(spawn_z) then
return false
end

observed_casket_spawn_z_min = observed_casket_spawn_z_min and math.min(observed_casket_spawn_z_min, spawn_z) or spawn_z
observed_casket_spawn_z_max = observed_casket_spawn_z_max and math.max(observed_casket_spawn_z_max, spawn_z) or spawn_z

local old_threshold_z = floor_threshold_z

if observed_casket_spawn_z_min and observed_casket_spawn_z_max and (observed_casket_spawn_z_max - observed_casket_spawn_z_min) >= FLOOR_Z_SPLIT_MIN_GAP then
floor_threshold_z = (observed_casket_spawn_z_min + observed_casket_spawn_z_max) * 0.5
end

return floor_threshold_z ~= old_threshold_z
end

local function classify_tracked_casket_floor(unit)
if not tracked_units[unit] or not floor_threshold_z then
return
end

local spawn_z = tracked_casket_spawn_z[unit]

if is_finite_number(spawn_z) then
tracked_casket_floor[unit] = spawn_z > floor_threshold_z and "upper" or "lower"
end
end

local function classify_all_tracked_casket_floors()
if not floor_threshold_z then
return
end

for unit, _ in pairs(tracked_units) do
classify_tracked_casket_floor(unit)
end
end

local function current_casket_level_text(unit)
if not indicate_level_enabled() or not tracked_units[unit] or tracked_casket_show_level[unit] == false then
return "", ""
end

if is_casket_currently_carried(unit) then
tracked_casket_show_level[unit] = false

return "", ""
end

local floor = tracked_casket_floor[unit]

if floor == "upper" then
return LEVEL_UP_ARROW_TEXT, ""
elseif floor == "lower" then
return "", LEVEL_DOWN_ARROW_TEXT
end

return "", ""
end

local function gameplay_time()
local time_manager = Managers.time

if time_manager and time_manager.has_timer and time_manager:has_timer("gameplay") then
return time_manager:time("gameplay")
end

return nil
end

local function get_world_markers_element()
local ui_manager = Managers.ui
local hud = ui_manager and ui_manager:get_hud()

return hud and hud:element("HudElementWorldMarkers")
end

local function marker_id_is_live(marker_id)
if not marker_id or marker_id == PENDING_MARKER then
return false
end

local world_markers = get_world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id

return markers_by_id and markers_by_id[marker_id] ~= nil
end

function is_valid_unit(unit)
return unit ~= nil and ALIVE and ALIVE[unit]
end

local function get_decoder_device_extension(unit)
if not is_valid_unit(unit) then
return nil
end

return ScriptUnit.has_extension(unit, "decoder_device_system")
end

local function get_door_control_panel_extension(unit)
if not is_valid_unit(unit) then
return nil
end

return ScriptUnit.has_extension(unit, "door_control_panel_system")
end

local function call_extension_boolean(extension, method_name)
if not extension then
return false
end

local method = extension[method_name]

if type(method) ~= "function" then
return false
end

local ok, value = pcall(method, extension)

return ok and value == true
end

local function has_mid_event_units()
return next(mid_event_units) ~= nil
end

local function should_update_end_event_markers()
return state == STATE_TRACKING_CASKETS or state == STATE_SEARCHING_BUTTON or state == STATE_BUTTON_LOCKED or state == STATE_WAITING_FOR_EXIT_OBJECTIVE or state == STATE_SEARCHING_EXIT_DOOR or state == STATE_EXIT_DOOR_LOCKED
end

local function should_update_mid_event_markers()
return include_cypher_ident_mid_event_enabled() and not mid_event_complete and (has_mid_event_units() or mid_event_door_unit ~= nil or mid_event_door_search_active)
end

local function should_update_markers()
return should_update_end_event_markers() or should_update_mid_event_markers()
end

local function track_mid_event_unit(unit)
if not mission_is_target or not include_cypher_ident_mid_event_enabled() or mid_event_complete or not is_valid_unit(unit) or mid_event_units[unit] then
return
end

mid_event_units[unit] = true
refresh_requested = true
end

local function remove_mid_event_marker(unit)
local marker_id = mid_event_marker_ids[unit]

if marker_id_is_live(marker_id) then
Managers.event:trigger("remove_world_marker", marker_id)
end

mid_event_marker_ids[unit] = nil
mid_event_marker_pending_frames[unit] = nil
mid_event_marker_colours[unit] = nil
mid_event_marker_world_positions[unit] = nil
end

local function untrack_mid_event_unit(unit)
if mid_event_units[unit] then
mid_event_units[unit] = nil
end

remove_mid_event_marker(unit)

if mid_event_door_unit == unit then
mid_event_door_unit = nil
mid_event_door_search_active = has_mid_event_units()
end
end

local function clear_mid_event_state()
local units_to_clear = {}

for unit, _ in pairs(mid_event_marker_ids) do
units_to_clear[#units_to_clear + 1] = unit
end

for i = 1, #units_to_clear do
remove_mid_event_marker(units_to_clear[i])
end

table.clear(mid_event_units)
table.clear(mid_event_marker_ids)
table.clear(mid_event_marker_pending_frames)
table.clear(mid_event_marker_colours)
table.clear(mid_event_marker_world_positions)
mid_event_door_unit = nil
mid_event_door_search_active = false
table.clear(button_prompt_cache)
end

local function finish_mid_event_state()
mid_event_complete = true
clear_mid_event_state()
end

local function decoder_wait_for_setup(unit)
return call_extension_boolean(get_decoder_device_extension(unit), "wait_for_setup")
end

local function decoder_wait_for_restart(unit)
return call_extension_boolean(get_decoder_device_extension(unit), "wait_for_restart")
end

local function decoder_is_finished(unit)
return call_extension_boolean(get_decoder_device_extension(unit), "is_finished")
end

local function decoder_is_enabled(unit)
return call_extension_boolean(get_decoder_device_extension(unit), "unit_is_enabled")
end

local function door_panel_is_active(unit)
return call_extension_boolean(get_door_control_panel_extension(unit), "is_active")
end

local function door_panel_is_on_hold(unit)
return call_extension_boolean(get_door_control_panel_extension(unit), "is_on_hold")
end

local function current_mid_event_marker_state(unit)
if not include_cypher_ident_mid_event_enabled() or not mid_event_units[unit] or not decoder_is_enabled(unit) or decoder_is_finished(unit) then
return nil
end

if decoder_wait_for_setup(unit) then
return "setup"
elseif decoder_wait_for_restart(unit) then
return "restart"
end

return nil
end

local function current_mid_event_marker_colour(unit)
return unit and (mid_event_marker_colours[unit] or BUTTON_MARKER_COLOUR) or BUTTON_MARKER_COLOUR
end

local function current_mid_event_marker_text(unit)
if unit and unit == mid_event_door_unit then
return BUTTON_MARKER_TEXT
end

return MID_EVENT_INTERROGATOR_TEXT
end

local function request_mid_event_marker(unit, colour, world_position)
if not is_valid_unit(unit) or not ensure_marker_templates() then
return
end

mid_event_marker_colours[unit] = colour
mid_event_marker_world_positions[unit] = world_position or nil

local marker_id = mid_event_marker_ids[unit]

if marker_id == PENDING_MARKER then
return
end

if marker_id_is_live(marker_id) then
mid_event_marker_pending_frames[unit] = nil
return
end

mid_event_marker_ids[unit] = PENDING_MARKER
mid_event_marker_pending_frames[unit] = 0

local function on_marker_added(new_marker_id)
if mid_event_marker_ids[unit] == PENDING_MARKER then
mid_event_marker_ids[unit] = new_marker_id
mid_event_marker_pending_frames[unit] = nil
end
end

if world_position then
Managers.event:trigger("add_world_marker_position", MID_EVENT_MARKER_TYPE, world_position, on_marker_added)
else
Managers.event:trigger("add_world_marker_unit", MID_EVENT_MARKER_TYPE, unit, on_marker_added)
end
end

local function update_pending_mid_event_marker(unit)
local marker_id = mid_event_marker_ids[unit]

if marker_id == PENDING_MARKER then
local pending_frames = (mid_event_marker_pending_frames[unit] or 0) + 1

mid_event_marker_pending_frames[unit] = pending_frames

if pending_frames >= 30 then
mid_event_marker_ids[unit] = nil
mid_event_marker_pending_frames[unit] = nil
end
elseif marker_id and not marker_id_is_live(marker_id) then
mid_event_marker_ids[unit] = nil
end
end

local security_door_candidate_score

local function interaction_marker_world_position(marker)
if not marker then
return nil
end

local world_position = marker.world_position

if world_position then
if type(world_position.unbox) == "function" then
return world_position:unbox()
end

return world_position
end

local position = marker.position

if position then
if type(position.unbox) == "function" then
return position:unbox()
end

return position
end

return nil
end

local function scan_enabled_decoder_units()
if not mission_is_target or not include_cypher_ident_mid_event_enabled() then
return
end

local extension_manager = Managers.state and Managers.state.extension
local decoder_device_system = extension_manager and extension_manager:system("decoder_device_system")
local unit_to_extension_map = decoder_device_system and decoder_device_system._unit_to_extension_map

if not unit_to_extension_map then
return
end

for unit, extension in pairs(unit_to_extension_map) do
if is_valid_unit(unit) and call_extension_boolean(extension, "unit_is_enabled") then
track_mid_event_unit(unit)
end
end
end

local function clear_button_prompt_cache()
table.clear(button_prompt_cache)
end

local function mission_objective_system()
local extension_manager = Managers.state and Managers.state.extension

return extension_manager and extension_manager:system("mission_objective_system")
end

local function active_extraction_objective()
local system = mission_objective_system()

return system and system:active_objective(EXTRACTION_OBJECTIVE_NAME) or nil
end

local function extraction_objective_active()
local objective = active_extraction_objective()

if not objective then
return false
end

local header = normalise_text(objective:header())

return header == EXTRACTION_OBJECTIVE_HEADER or (header and string.find(header, "extraction", 1, true) ~= nil)
end

local function current_casket_marker_text()
if not countdown_enabled() then
return DEFAULT_CASKET_TEXT
end

if remaining_caskets >= 3 then
return COUNTDOWN_TEXT_3
elseif remaining_caskets == 2 then
return COUNTDOWN_TEXT_2
elseif remaining_caskets == 1 then
return COUNTDOWN_TEXT_1
end

return DEFAULT_CASKET_TEXT
end

local function create_casket_marker_template()
local font_settings = UIFontSettings.hud_body
local template = {}

template.name = CASKET_MARKER_TYPE
template.size = { 64, 64 }
template.unit_node = "ui_interaction_marker"
template.position_offset = { 0, 0, 0 }
template.max_distance = marker_max_distance()
template.screen_clamp = true
template.screen_margins = {
down = 0.23148148148148148,
left = 0.234375,
right = 0.234375,
up = 0.23148148148148148,
}
template.check_line_of_sight = false
template.using_smart_tag_system = false
template.scale_settings = {
distance_min = 0,
distance_max = DISTANCE_VALUES.Far,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil

template.create_widget_defintion = function(_, scenegraph_id)
local arrow_font_size = casket_level_font_size()
local arrow_offset = casket_level_offset()

return UIWidget.create_definition({
{
pass_type = "text",
style_id = "marker_shadow",
value = DEFAULT_CASKET_TEXT,
value_id = "marker_text",
style = {
font_type = font_settings.font_type,
font_size = marker_font_size(),
default_font_size = marker_font_size(),
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
default_offset = { 2, 2, 0 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = SHADOW_COLOUR,
},
},
{
pass_type = "text",
style_id = "marker_text",
value = DEFAULT_CASKET_TEXT,
value_id = "marker_text",
style = {
font_type = font_settings.font_type,
font_size = marker_font_size(),
default_font_size = marker_font_size(),
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
default_offset = { 0, 0, 1 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = CASKET_MARKER_COLOUR,
},
},
{
pass_type = "text",
style_id = "upper_arrow_shadow",
value = "",
value_id = "upper_arrow_text",
style = {
font_type = font_settings.font_type,
font_size = arrow_font_size,
default_font_size = arrow_font_size,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, -arrow_offset + 2, 0 },
default_offset = { 2, -arrow_offset + 2, 0 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = SHADOW_COLOUR,
},
},
{
pass_type = "text",
style_id = "upper_arrow_text",
value = "",
value_id = "upper_arrow_text",
style = {
font_type = font_settings.font_type,
font_size = arrow_font_size,
default_font_size = arrow_font_size,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, -arrow_offset, 1 },
default_offset = { 0, -arrow_offset, 1 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = CASKET_MARKER_COLOUR,
},
},
{
pass_type = "text",
style_id = "lower_arrow_shadow",
value = "",
value_id = "lower_arrow_text",
style = {
font_type = font_settings.font_type,
font_size = arrow_font_size,
default_font_size = arrow_font_size,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, arrow_offset + 2, 0 },
default_offset = { 2, arrow_offset + 2, 0 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = SHADOW_COLOUR,
},
},
{
pass_type = "text",
style_id = "lower_arrow_text",
value = "",
value_id = "lower_arrow_text",
style = {
font_type = font_settings.font_type,
font_size = arrow_font_size,
default_font_size = arrow_font_size,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, arrow_offset, 1 },
default_offset = { 0, arrow_offset, 1 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = CASKET_MARKER_COLOUR,
},
},
}, scenegraph_id)
end

template.on_enter = function(widget, marker)
local font_size = marker_font_size()
local arrow_font_size = casket_level_font_size()
local arrow_offset = casket_level_offset()
local upper_arrow_text, lower_arrow_text = current_casket_level_text(marker.unit)

widget.content.marker_text = current_casket_marker_text()
widget.content.upper_arrow_text = upper_arrow_text
widget.content.lower_arrow_text = lower_arrow_text

widget.style.marker_shadow.font_size = font_size
widget.style.marker_shadow.default_font_size = font_size
widget.style.marker_text.font_size = font_size
widget.style.marker_text.default_font_size = font_size

widget.style.upper_arrow_shadow.font_size = arrow_font_size
widget.style.upper_arrow_shadow.default_font_size = arrow_font_size
widget.style.upper_arrow_shadow.offset[2] = -arrow_offset + 2
widget.style.upper_arrow_shadow.default_offset[2] = -arrow_offset + 2
widget.style.upper_arrow_text.font_size = arrow_font_size
widget.style.upper_arrow_text.default_font_size = arrow_font_size
widget.style.upper_arrow_text.offset[2] = -arrow_offset
widget.style.upper_arrow_text.default_offset[2] = -arrow_offset

widget.style.lower_arrow_shadow.font_size = arrow_font_size
widget.style.lower_arrow_shadow.default_font_size = arrow_font_size
widget.style.lower_arrow_shadow.offset[2] = arrow_offset + 2
widget.style.lower_arrow_shadow.default_offset[2] = arrow_offset + 2
widget.style.lower_arrow_text.font_size = arrow_font_size
widget.style.lower_arrow_text.default_font_size = arrow_font_size
widget.style.lower_arrow_text.offset[2] = arrow_offset
widget.style.lower_arrow_text.default_offset[2] = arrow_offset

marker.template.max_distance = marker_max_distance()
marker.scale = 1
marker.ignore_scale = true
end

template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
local font_size = marker_font_size()
local arrow_font_size = casket_level_font_size()
local arrow_offset = casket_level_offset()
local upper_arrow_text, lower_arrow_text = current_casket_level_text(marker.unit)

marker_template.max_distance = marker_max_distance()
widget.content.marker_text = current_casket_marker_text()
widget.content.upper_arrow_text = upper_arrow_text
widget.content.lower_arrow_text = lower_arrow_text

widget.style.marker_shadow.font_size = font_size
widget.style.marker_shadow.default_font_size = font_size
widget.style.marker_text.font_size = font_size
widget.style.marker_text.default_font_size = font_size
widget.style.marker_shadow.text_color = SHADOW_COLOUR
widget.style.marker_text.text_color = CASKET_MARKER_COLOUR

widget.style.upper_arrow_shadow.font_size = arrow_font_size
widget.style.upper_arrow_shadow.default_font_size = arrow_font_size
widget.style.upper_arrow_shadow.offset[2] = -arrow_offset + 2
widget.style.upper_arrow_shadow.default_offset[2] = -arrow_offset + 2
widget.style.upper_arrow_shadow.text_color = SHADOW_COLOUR
widget.style.upper_arrow_text.font_size = arrow_font_size
widget.style.upper_arrow_text.default_font_size = arrow_font_size
widget.style.upper_arrow_text.offset[2] = -arrow_offset
widget.style.upper_arrow_text.default_offset[2] = -arrow_offset
widget.style.upper_arrow_text.text_color = CASKET_MARKER_COLOUR

widget.style.lower_arrow_shadow.font_size = arrow_font_size
widget.style.lower_arrow_shadow.default_font_size = arrow_font_size
widget.style.lower_arrow_shadow.offset[2] = arrow_offset + 2
widget.style.lower_arrow_shadow.default_offset[2] = arrow_offset + 2
widget.style.lower_arrow_shadow.text_color = SHADOW_COLOUR
widget.style.lower_arrow_text.font_size = arrow_font_size
widget.style.lower_arrow_text.default_font_size = arrow_font_size
widget.style.lower_arrow_text.offset[2] = arrow_offset
widget.style.lower_arrow_text.default_offset[2] = arrow_offset
widget.style.lower_arrow_text.text_color = CASKET_MARKER_COLOUR

marker.scale = 1
marker.ignore_scale = true
end

return template
end

local function create_mid_event_marker_template()
local font_settings = UIFontSettings.hud_body
local template = {}

template.name = MID_EVENT_MARKER_TYPE
template.size = { 64, 64 }
template.unit_node = "ui_interaction_marker"
template.position_offset = { 0, 0, 0 }
template.max_distance = button_max_distance()
template.screen_clamp = true
template.screen_margins = {
down = 0.23148148148148148,
left = 0.234375,
right = 0.234375,
up = 0.23148148148148148,
}
template.check_line_of_sight = false
template.using_smart_tag_system = false
template.scale_settings = {
distance_min = 0,
distance_max = DISTANCE_VALUES.Far,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil

template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "marker_shadow",
value = BUTTON_MARKER_TEXT,
value_id = "marker_text",
style = {
font_type = font_settings.font_type,
font_size = mid_event_font_size(),
default_font_size = mid_event_font_size(),
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
default_offset = { 2, 2, 0 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = SHADOW_COLOUR,
},
},
{
pass_type = "text",
style_id = "marker_text",
value = BUTTON_MARKER_TEXT,
value_id = "marker_text",
style = {
font_type = font_settings.font_type,
font_size = mid_event_font_size(),
default_font_size = mid_event_font_size(),
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
default_offset = { 0, 0, 1 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = BUTTON_MARKER_COLOUR,
},
},
}, scenegraph_id)
end

template.on_enter = function(widget, marker)
local font_size = mid_event_font_size()
local unit = marker.unit or (marker.data and marker.data.owner_unit) or nil
local marker_colour = current_mid_event_marker_colour(unit)

widget.content.marker_text = current_mid_event_marker_text(unit)
widget.style.marker_shadow.font_size = font_size
widget.style.marker_shadow.default_font_size = font_size
widget.style.marker_text.font_size = font_size
widget.style.marker_text.default_font_size = font_size
widget.style.marker_text.text_color = marker_colour
marker.template.max_distance = button_max_distance()
marker.scale = 1
marker.ignore_scale = true
end

template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
local font_size = mid_event_font_size()
local unit = marker.unit or (marker.data and marker.data.owner_unit) or nil
local marker_colour = current_mid_event_marker_colour(unit)

marker_template.max_distance = button_max_distance()
widget.content.marker_text = current_mid_event_marker_text(unit)
widget.style.marker_shadow.font_size = font_size
widget.style.marker_shadow.default_font_size = font_size
widget.style.marker_text.font_size = font_size
widget.style.marker_text.default_font_size = font_size
widget.style.marker_shadow.text_color = SHADOW_COLOUR
widget.style.marker_text.text_color = marker_colour
marker.scale = 1
marker.ignore_scale = true
end

return template
end

local function create_button_marker_template()
local font_settings = UIFontSettings.hud_body
local template = {}

template.name = BUTTON_MARKER_TYPE
template.size = { 64, 64 }
template.unit_node = "ui_interaction_marker"
template.position_offset = { 0, 0, 0 }
template.max_distance = button_max_distance()
template.screen_clamp = true
template.screen_margins = {
down = 0.23148148148148148,
left = 0.234375,
right = 0.234375,
up = 0.23148148148148148,
}
template.check_line_of_sight = false
template.using_smart_tag_system = false
template.scale_settings = {
distance_min = 0,
distance_max = DISTANCE_VALUES.Far,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil

template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "marker_shadow",
value = BUTTON_MARKER_TEXT,
value_id = "marker_text",
style = {
font_type = font_settings.font_type,
font_size = button_font_size(),
default_font_size = button_font_size(),
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
default_offset = { 2, 2, 0 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = SHADOW_COLOUR,
},
},
{
pass_type = "text",
style_id = "marker_text",
value = BUTTON_MARKER_TEXT,
value_id = "marker_text",
style = {
font_type = font_settings.font_type,
font_size = button_font_size(),
default_font_size = button_font_size(),
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
default_offset = { 0, 0, 1 },
size = { 320, 320 },
default_size = { 320, 320 },
text_color = BUTTON_MARKER_COLOUR,
},
},
}, scenegraph_id)
end

template.on_enter = function(widget, marker)
local font_size = button_font_size()

widget.content.marker_text = BUTTON_MARKER_TEXT
widget.style.marker_shadow.font_size = font_size
widget.style.marker_shadow.default_font_size = font_size
widget.style.marker_text.font_size = font_size
widget.style.marker_text.default_font_size = font_size
marker.template.max_distance = button_max_distance()
marker.scale = 1
marker.ignore_scale = true
end

template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
local font_size = button_font_size()

marker_template.max_distance = button_max_distance()
widget.content.marker_text = BUTTON_MARKER_TEXT
widget.style.marker_shadow.font_size = font_size
widget.style.marker_shadow.default_font_size = font_size
widget.style.marker_text.font_size = font_size
widget.style.marker_text.default_font_size = font_size
widget.style.marker_shadow.text_color = SHADOW_COLOUR
widget.style.marker_text.text_color = BUTTON_MARKER_COLOUR
marker.scale = 1
marker.ignore_scale = true
end

return template
end

ensure_marker_templates = function()
if not mission_is_target then
return false
end

local world_markers = get_world_markers_element()

if not world_markers or not world_markers._marker_templates then
return false
end

if not world_markers._marker_templates[CASKET_MARKER_TYPE] then
world_markers._marker_templates[CASKET_MARKER_TYPE] = create_casket_marker_template()
end

if not world_markers._marker_templates[BUTTON_MARKER_TYPE] then
world_markers._marker_templates[BUTTON_MARKER_TYPE] = create_button_marker_template()
end

if not world_markers._marker_templates[MID_EVENT_MARKER_TYPE] then
world_markers._marker_templates[MID_EVENT_MARKER_TYPE] = create_mid_event_marker_template()
end

return true
end

local function remove_button_marker()
if marker_id_is_live(final_button_marker_id) then
Managers.event:trigger("remove_world_marker", final_button_marker_id)
end

final_button_marker_id = nil
final_button_marker_pending_frames = nil
end

local function remove_exit_door_marker()
if marker_id_is_live(exit_door_marker_id) then
Managers.event:trigger("remove_world_marker", exit_door_marker_id)
end

exit_door_marker_id = nil
exit_door_marker_pending_frames = nil
end

local function clear_button_state()
remove_button_marker()

final_button_unit = nil
button_search_deadline_t = nil
clear_button_prompt_cache()
end

local function clear_exit_door_state()
remove_exit_door_marker()

exit_door_unit = nil
exit_door_search_deadline_t = nil
clear_button_prompt_cache()
end

local function remove_casket_marker(unit)
local marker_id = casket_marker_ids[unit]

if marker_id_is_live(marker_id) then
Managers.event:trigger("remove_world_marker", marker_id)
end

casket_marker_ids[unit] = nil
casket_marker_pending_frames[unit] = nil
end

local function clear_tracking_data()
mid_event_complete = false

for unit, _ in pairs(tracked_units) do
remove_casket_marker(unit)
end

table.clear(tracked_units)
table.clear(casket_marker_ids)
table.clear(casket_marker_pending_frames)
table.clear(tracked_casket_spawn_z)
table.clear(tracked_casket_floor)
table.clear(tracked_casket_show_level)
observed_casket_spawn_z_min = nil
observed_casket_spawn_z_max = nil
floor_threshold_z = nil

tracked_casket_count = 0
remaining_caskets = 0
delivered_caskets = 0

clear_button_state()
clear_exit_door_state()
clear_mid_event_state()

refresh_requested = false
end

local function finish_tracking()
clear_tracking_data()
state = mission_is_target and STATE_DONE or STATE_INACTIVE
end

local function set_state_for_current_counts()
if exit_door_unit then
state = STATE_EXIT_DOOR_LOCKED
elseif state == STATE_WAITING_FOR_EXIT_OBJECTIVE or state == STATE_SEARCHING_EXIT_DOOR then
state = state
elseif delivered_caskets >= 3 and final_button_enabled() then
state = final_button_unit and STATE_BUTTON_LOCKED or STATE_SEARCHING_BUTTON
elseif tracked_casket_count > 0 then
state = STATE_TRACKING_CASKETS
elseif mission_is_target then
state = STATE_WAITING_FOR_CASKETS
else
state = STATE_INACTIVE
end
end

local function clear_all_state()
mission_is_target = false
mission_detection_complete = false
state = STATE_INACTIVE
clear_tracking_data()
end

local function current_mission_name()
local mechanism_manager = Managers.mechanism
local mechanism_data = mechanism_manager and mechanism_manager:mechanism_data()

return mechanism_data and mechanism_data.mission_name or nil
end

local function detect_current_mission_once()
if mission_detection_complete then
return
end

mission_detection_complete = true
mission_is_target = current_mission_name() == TARGET_MISSION_ID
state = mission_is_target and STATE_WAITING_FOR_CASKETS or STATE_INACTIVE

if mission_is_target then
end
end

local function arm_button_search()
if not final_button_enabled() then
finish_tracking()
return
end

if not mid_event_complete then
finish_mid_event_state()
end

clear_button_state()
clear_exit_door_state()

state = STATE_SEARCHING_BUTTON
button_search_deadline_t = (gameplay_time() or 0) + BUTTON_SEARCH_WINDOW
refresh_requested = true
end

local function arm_exit_door_search()
if not final_button_enabled() then
finish_tracking()
return
end

if not mid_event_complete then
finish_mid_event_state()
end

clear_exit_door_state()

state = STATE_SEARCHING_EXIT_DOOR
exit_door_search_deadline_t = (gameplay_time() or 0) + EXIT_DOOR_SEARCH_WINDOW
refresh_requested = true
end

local function arm_wait_for_exit_objective()
if not final_button_enabled() then
finish_tracking()
return
end

clear_button_state()
clear_exit_door_state()

if extraction_objective_active() then
arm_exit_door_search()
else
state = STATE_WAITING_FOR_EXIT_OBJECTIVE
refresh_requested = true
end
end

local function is_container_casket(unit)
if not is_valid_unit(unit) then
return false
end

if not Unit.has_data(unit, "pickup_type") then
return false
end

return Unit.get_data(unit, "pickup_type") == "container_01_luggable"
end

local function track_casket(unit)
if tracked_units[unit] or not is_container_casket(unit) then
return
end

tracked_units[unit] = true
tracked_casket_spawn_z[unit] = unit_world_z(unit)
tracked_casket_show_level[unit] = true
tracked_casket_count = tracked_casket_count + 1
remaining_caskets = remaining_caskets + 1

local threshold_changed = update_floor_threshold_from_spawn_z(tracked_casket_spawn_z[unit])

classify_tracked_casket_floor(unit)

if threshold_changed then
classify_all_tracked_casket_floors()
end

state = STATE_TRACKING_CASKETS
refresh_requested = true
end

local function untrack_casket(unit)
if not tracked_units[unit] then
return
end

remove_casket_marker(unit)

tracked_units[unit] = nil
clear_casket_level_data(unit)
tracked_casket_count = math.max(0, tracked_casket_count - 1)
remaining_caskets = math.max(0, remaining_caskets - 1)

set_state_for_current_counts()
end

local function mark_casket_delivered(unit)
if not tracked_units[unit] then
return
end

remove_casket_marker(unit)

tracked_units[unit] = nil
clear_casket_level_data(unit)
tracked_casket_count = math.max(0, tracked_casket_count - 1)
remaining_caskets = math.max(0, remaining_caskets - 1)
delivered_caskets = delivered_caskets + 1

if delivered_caskets >= 3 then
arm_button_search()
else
set_state_for_current_counts()
end
end

local function request_casket_marker(unit)
if not tracked_units[unit] or not ensure_marker_templates() then
return
end

local marker_id = casket_marker_ids[unit]

if marker_id == PENDING_MARKER then
return
end

if marker_id_is_live(marker_id) then
casket_marker_pending_frames[unit] = nil
return
end

casket_marker_ids[unit] = PENDING_MARKER
casket_marker_pending_frames[unit] = 0

Managers.event:trigger("add_world_marker_unit", CASKET_MARKER_TYPE, unit, function(new_marker_id)
if casket_marker_ids[unit] == PENDING_MARKER then
casket_marker_ids[unit] = new_marker_id
casket_marker_pending_frames[unit] = nil
end
end)
end

local function request_button_marker()
if not final_button_unit or not is_valid_unit(final_button_unit) or not ensure_marker_templates() then
return
end

if final_button_marker_id == PENDING_MARKER then
return
end

if marker_id_is_live(final_button_marker_id) then
final_button_marker_pending_frames = nil
return
end

final_button_marker_id = PENDING_MARKER
final_button_marker_pending_frames = 0

Managers.event:trigger("add_world_marker_unit", BUTTON_MARKER_TYPE, final_button_unit, function(new_marker_id)
if final_button_marker_id == PENDING_MARKER then
final_button_marker_id = new_marker_id
final_button_marker_pending_frames = nil
end
end)
end

local function request_exit_door_marker()
if not exit_door_unit or not is_valid_unit(exit_door_unit) or not ensure_marker_templates() then
return
end

if exit_door_marker_id == PENDING_MARKER then
return
end

if marker_id_is_live(exit_door_marker_id) then
exit_door_marker_pending_frames = nil
return
end

exit_door_marker_id = PENDING_MARKER
exit_door_marker_pending_frames = 0

Managers.event:trigger("add_world_marker_unit", BUTTON_MARKER_TYPE, exit_door_unit, function(new_marker_id)
if exit_door_marker_id == PENDING_MARKER then
exit_door_marker_id = new_marker_id
exit_door_marker_pending_frames = nil
end
end)
end

local function update_pending_casket_marker(unit)
local marker_id = casket_marker_ids[unit]

if marker_id == PENDING_MARKER then
local pending_frames = (casket_marker_pending_frames[unit] or 0) + 1

casket_marker_pending_frames[unit] = pending_frames

if pending_frames >= 30 then
casket_marker_ids[unit] = nil
casket_marker_pending_frames[unit] = nil
end
elseif marker_id and not marker_id_is_live(marker_id) then
casket_marker_ids[unit] = nil
end
end

local function update_pending_button_marker()
if final_button_marker_id == PENDING_MARKER then
final_button_marker_pending_frames = (final_button_marker_pending_frames or 0) + 1

if final_button_marker_pending_frames >= 30 then
final_button_marker_id = nil
final_button_marker_pending_frames = nil
end
elseif final_button_marker_id and not marker_id_is_live(final_button_marker_id) then
final_button_marker_id = nil
end
end

local function update_pending_exit_door_marker()
if exit_door_marker_id == PENDING_MARKER then
exit_door_marker_pending_frames = (exit_door_marker_pending_frames or 0) + 1

if exit_door_marker_pending_frames >= 30 then
exit_door_marker_id = nil
exit_door_marker_pending_frames = nil
end
elseif exit_door_marker_id and not marker_id_is_live(exit_door_marker_id) then
exit_door_marker_id = nil
end
end

local function refresh_active_markers()
for unit, _ in pairs(tracked_units) do
remove_casket_marker(unit)
end

for unit, _ in pairs(mid_event_marker_ids) do
remove_mid_event_marker(unit)
end

remove_button_marker()
remove_exit_door_marker()

for unit, _ in pairs(mid_event_units) do
remove_mid_event_marker(unit)
end

if mid_event_door_unit then
remove_mid_event_marker(mid_event_door_unit)
end

for unit, _ in pairs(tracked_units) do
if is_container_casket(unit) then
request_casket_marker(unit)
else
untrack_casket(unit)
end
end

if state == STATE_BUTTON_LOCKED and final_button_unit and is_valid_unit(final_button_unit) then
request_button_marker()
end

if state == STATE_EXIT_DOOR_LOCKED and exit_door_unit and is_valid_unit(exit_door_unit) then
request_exit_door_marker()
end

for unit, _ in pairs(mid_event_units) do
if is_valid_unit(unit) then
local marker_state = current_mid_event_marker_state(unit)

if marker_state == "setup" then
request_mid_event_marker(unit, MID_EVENT_SETUP_COLOUR)
elseif marker_state == "restart" then
request_mid_event_marker(unit, MID_EVENT_RESTART_COLOUR)
end
else
untrack_mid_event_unit(unit)
end
end

if mid_event_door_unit and is_valid_unit(mid_event_door_unit) then
request_mid_event_marker(mid_event_door_unit, BUTTON_MARKER_COLOUR, mid_event_marker_world_positions[mid_event_door_unit])
end
end

local function get_interactee_extension(unit)
if not is_valid_unit(unit) then
return nil
end

return ScriptUnit.has_extension(unit, "interactee_system")
end

local function call_interactee_value(unit, method_name)
local extension = get_interactee_extension(unit)

if not extension then
return nil
end

local method = extension[method_name]

if type(method) ~= "function" then
return nil
end

local ok, value = pcall(method, extension)

if ok then
return value
end

return nil
end

local function localise_text(value)
if type(value) ~= "string" or value == "" then
return nil
end

if string.sub(value, 1, 4) == "loc_" then
local ok, localised = pcall(Localize, value)

if ok and type(localised) == "string" and localised ~= "" then
value = localised
end
end

return value
end

local function normalise_text(value)
value = localise_text(value)

if type(value) ~= "string" or value == "" then
return nil
end

return string.lower(value)
end

local function unit_data_string(unit, key)
if not is_valid_unit(unit) or not Unit.has_data(unit, key) then
return nil
end

local value = Unit.get_data(unit, key)

return type(value) == "string" and value ~= "" and value or nil
end

local function cached_button_prompt(unit)
local cached = button_prompt_cache[unit]

if cached ~= nil then
return cached
end

local prompt = {
description = normalise_text(call_interactee_value(unit, "description") or unit_data_string(unit, "hud_description")),
action = normalise_text(call_interactee_value(unit, "action_text") or unit_data_string(unit, "sub_description")),
interaction_type = normalise_text(call_interactee_value(unit, "interaction_type") or unit_data_string(unit, "interaction_type")),
ui_interaction_type = normalise_text(call_interactee_value(unit, "ui_interaction_type") or unit_data_string(unit, "ui_interaction_type")),
}

button_prompt_cache[unit] = prompt

return prompt
end

local function is_active_interactable(unit)
local extension = get_interactee_extension(unit)

if not extension then
return false
end

if extension.used and extension:used() then
return false
end

if extension.active and not extension:active() then
return false
end

return true
end

security_door_candidate_score = function(unit)
if not is_valid_unit(unit) or mid_event_units[unit] or tracked_units[unit] or Unit.has_data(unit, "pickup_type") then
return nil
end

if not is_active_interactable(unit) then
return nil
end

local prompt = cached_button_prompt(unit)
local description = prompt.description
local action = prompt.action
local interaction_type = prompt.interaction_type
local ui_interaction_type = prompt.ui_interaction_type

if description ~= "security door" then
return nil
end

if action ~= "open" and not (action and string.find(action, "open", 1, true)) then
return nil
end

local score = 1000

if get_door_control_panel_extension(unit) then
score = score + 100
end

if interaction_type == "door_control_panel" then
score = score + 100
end

if ui_interaction_type == "default" or ui_interaction_type == "mission" then
score = score + 25
end

return score
end

local function custom_marker_is_live_for_unit(unit)
return unit ~= nil and ((tracked_units[unit] and marker_id_is_live(casket_marker_ids[unit])) or (final_button_unit == unit and marker_id_is_live(final_button_marker_id)) or (exit_door_unit == unit and marker_id_is_live(exit_door_marker_id)) or marker_id_is_live(mid_event_marker_ids[unit]))
end

local function hide_default_markers_for_custom_units(markers_by_type)
if not markers_by_type then
return
end

for marker_type, markers in pairs(markers_by_type) do
if marker_type ~= CASKET_MARKER_TYPE and marker_type ~= BUTTON_MARKER_TYPE and marker_type ~= MID_EVENT_MARKER_TYPE and type(markers) == "table" then
for i = 1, #markers do
local marker = markers[i]
local unit = marker.unit

if unit and custom_marker_is_live_for_unit(unit) then
marker.draw = false

if marker.widget then
marker.widget.alpha_multiplier = 0
end
end
end
end
end
end

local function update_mid_event_markers(interaction_markers)
if not should_update_mid_event_markers() then
return
end

local all_finished = has_mid_event_units()
local best_door_candidate = nil
local best_door_score = -1
local best_door_world_position = nil

for unit, _ in pairs(mid_event_units) do
if not is_valid_unit(unit) then
untrack_mid_event_unit(unit)
else
update_pending_mid_event_marker(unit)

local marker_state = current_mid_event_marker_state(unit)

if marker_state == "setup" then
request_mid_event_marker(unit, MID_EVENT_SETUP_COLOUR)
elseif marker_state == "restart" then
request_mid_event_marker(unit, MID_EVENT_RESTART_COLOUR)
else
remove_mid_event_marker(unit)
end

if not decoder_is_finished(unit) then
all_finished = false
end
end
end

if all_finished and has_mid_event_units() then
if mid_event_door_unit and is_valid_unit(mid_event_door_unit) and is_active_interactable(mid_event_door_unit) then
mid_event_door_search_active = false
update_pending_mid_event_marker(mid_event_door_unit)
request_mid_event_marker(mid_event_door_unit, BUTTON_MARKER_COLOUR, mid_event_marker_world_positions[mid_event_door_unit])
else
if mid_event_door_unit then
remove_mid_event_marker(mid_event_door_unit)
mid_event_door_unit = nil
end

if not mid_event_door_search_active then
end
mid_event_door_search_active = true

if interaction_markers then
for i = 1, #interaction_markers do
local marker = interaction_markers[i]
local unit = marker.unit

if unit then
local prompt = cached_button_prompt(unit)

if prompt.interaction_type == "door_control_panel" or prompt.description == "security door" then
end

local candidate_score = security_door_candidate_score(unit)

if candidate_score and candidate_score > best_door_score then
best_door_candidate = unit
best_door_score = candidate_score
best_door_world_position = interaction_marker_world_position(marker)
end
end
end
end

if best_door_candidate then
mid_event_door_unit = best_door_candidate
mid_event_door_search_active = false
update_pending_mid_event_marker(mid_event_door_unit)
request_mid_event_marker(mid_event_door_unit, BUTTON_MARKER_COLOUR, best_door_world_position)
end
end
else
mid_event_door_search_active = false

if mid_event_door_unit then
remove_mid_event_marker(mid_event_door_unit)
mid_event_door_unit = nil
end
end
end

local function button_candidate_score(unit)
if not is_valid_unit(unit) or tracked_units[unit] or Unit.has_data(unit, "pickup_type") then
return nil
end

if not is_active_interactable(unit) then
return nil
end

local prompt = cached_button_prompt(unit)
local description = prompt.description
local action = prompt.action
local interaction_type = prompt.interaction_type
local ui_interaction_type = prompt.ui_interaction_type
local score = 0

if description then
if description == "pneumatic conveyor" then
score = score + 1000
end

if string.find(description, "pneumatic", 1, true) then
score = score + 500
end

if string.find(description, "conveyor", 1, true) then
score = score + 500
end
end

if action then
if action == "send" then
score = score + 400
elseif string.find(action, "send", 1, true) then
score = score + 250
end
end

if score > 0 and interaction_type == "door_control_panel" then
score = score + 50
end

if score > 0 and (ui_interaction_type == "default" or ui_interaction_type == "mission") then
score = score + 25
end

return score > 0 and score or nil
end

local function exit_door_candidate_score(unit, marker)
if unit == mid_event_door_unit or unit == final_button_unit or not is_valid_unit(unit) then
return nil
end

if marker and marker.distance and marker.distance > FINAL_DOOR_CANDIDATE_MAX_DISTANCE then
return nil
end

if get_door_control_panel_extension(unit) and (not door_panel_is_active(unit) or door_panel_is_on_hold(unit)) then
return nil
end

return security_door_candidate_score(unit)
end

mod.on_all_mods_loaded = function()
normalise_saved_settings_once()
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function()
if mission_is_target and state == STATE_WAITING_FOR_EXIT_OBJECTIVE and extraction_objective_active() then
arm_exit_door_search()
end

if mission_is_target and should_update_markers() then
refresh_requested = true
end
end)

mod:hook_safe(CLASS.StateGameplay, "on_enter", function()
detect_current_mission_once()

if not mission_is_target then
clear_tracking_data()
elseif include_cypher_ident_mid_event_enabled() then
scan_enabled_decoder_units()
end
end)

mod:hook_safe(CLASS.StateGameplay, "on_exit", function()
clear_all_state()
end)

mod:hook_safe(CLASS.HudElementWorldMarkers, "_calculate_markers", function(self)
if not mission_is_target or not should_update_markers() then
return
end

if not ensure_marker_templates() then
return
end

if refresh_requested then
refresh_requested = false
refresh_active_markers()
end

for unit, _ in pairs(tracked_units) do
if is_container_casket(unit) then
update_pending_casket_marker(unit)
request_casket_marker(unit)
else
untrack_casket(unit)
end
end

if state == STATE_SEARCHING_BUTTON then
local now = gameplay_time()

if button_search_deadline_t and now and now > button_search_deadline_t then
finish_tracking()
return
end
elseif state == STATE_BUTTON_LOCKED then
if not final_button_unit or not is_active_interactable(final_button_unit) then
arm_exit_door_search()
else
update_pending_button_marker()
request_button_marker()
end
elseif state == STATE_WAITING_FOR_EXIT_OBJECTIVE then
if extraction_objective_active() then
arm_exit_door_search()
end
elseif state == STATE_SEARCHING_EXIT_DOOR then
local now = gameplay_time()

if exit_door_search_deadline_t and now and now > exit_door_search_deadline_t then
finish_tracking()
return
end
elseif state == STATE_EXIT_DOOR_LOCKED then
if not exit_door_unit or not is_active_interactable(exit_door_unit) or (get_door_control_panel_extension(exit_door_unit) and (not door_panel_is_active(exit_door_unit) or door_panel_is_on_hold(exit_door_unit))) then
finish_tracking()
return
end

update_pending_exit_door_marker()
request_exit_door_marker()
end

local markers_by_type = self._markers_by_type
local interaction_markers = markers_by_type and markers_by_type.interaction or nil
local casket_markers = markers_by_type and markers_by_type[CASKET_MARKER_TYPE] or nil
local button_markers = markers_by_type and markers_by_type[BUTTON_MARKER_TYPE] or nil
local mid_event_markers = markers_by_type and markers_by_type[MID_EVENT_MARKER_TYPE] or nil
local casket_distance = marker_max_distance()
local final_button_distance = button_max_distance()
local best_button_candidate = nil
local best_button_score = -1
local best_exit_door_candidate = nil
local best_exit_door_score = -1

if interaction_markers then
for i = 1, #interaction_markers do
local marker = interaction_markers[i]
local unit = marker.unit

if state == STATE_SEARCHING_BUTTON and not final_button_unit and unit then
local prompt = cached_button_prompt(unit)

if prompt.interaction_type == "door_control_panel" or prompt.description == "pneumatic conveyor" then
end

local candidate_score = button_candidate_score(unit)

if candidate_score and candidate_score > best_button_score then
best_button_candidate = unit
best_button_score = candidate_score
end
elseif state == STATE_SEARCHING_EXIT_DOOR and not exit_door_unit and unit then
local prompt = cached_button_prompt(unit)

if prompt.interaction_type == "door_control_panel" or prompt.description == "security door" then
end

local candidate_score = exit_door_candidate_score(unit, marker)

if candidate_score and candidate_score > best_exit_door_score then
best_exit_door_candidate = unit
best_exit_door_score = candidate_score
end
end
end
end

update_mid_event_markers(interaction_markers)
hide_default_markers_for_custom_units(markers_by_type)

if casket_markers then
for i = 1, #casket_markers do
local marker = casket_markers[i]

marker.template.max_distance = casket_distance
marker.scale = 1
marker.ignore_scale = true

if marker.distance and marker.distance > casket_distance then
marker.draw = false
else
marker.draw = true
end
end
end

if button_markers then
for i = 1, #button_markers do
local marker = button_markers[i]

marker.template.max_distance = final_button_distance
marker.scale = 1
marker.ignore_scale = true

if marker.distance and marker.distance > final_button_distance then
marker.draw = false
else
marker.draw = true
end
end
end

if mid_event_markers then
for i = 1, #mid_event_markers do
local marker = mid_event_markers[i]

marker.template.max_distance = final_button_distance
marker.scale = 1
marker.ignore_scale = true

if marker.distance and marker.distance > final_button_distance then
marker.draw = false
else
marker.draw = true
end
end
end

if best_button_candidate then
final_button_unit = best_button_candidate
state = STATE_BUTTON_LOCKED
button_search_deadline_t = nil
clear_button_prompt_cache()
request_button_marker()
elseif best_exit_door_candidate then
exit_door_unit = best_exit_door_candidate
state = STATE_EXIT_DOOR_LOCKED
exit_door_search_deadline_t = nil
clear_button_prompt_cache()
request_exit_door_marker()
end
end)

mod:hook_safe(CLASS.LuggableExtension, "init", function(self, extension_init_context, unit)
if not mission_is_target or state == STATE_DONE then
return
end

if is_container_casket(unit) then
track_casket(unit)
end
end)

mod:hook_safe(CLASS.LuggableExtension, "destroy", function(self)
if not mission_is_target or not should_update_end_event_markers() then
return
end

local unit = self._unit

if tracked_units[unit] then
untrack_casket(unit)
end
end)

mod:hook_safe(CLASS.LuggableSocketExtension, "socket_luggable", function(self, luggable_unit)
if not mission_is_target or not should_update_end_event_markers() then
return
end

if tracked_units[luggable_unit] then
mark_casket_delivered(luggable_unit)
end
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "enable_unit", function(self)
if mission_is_target and include_cypher_ident_mid_event_enabled() then
track_mid_event_unit(self._unit)
end
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "hot_join_sync", function(self, unit_is_enabled)
if mission_is_target and include_cypher_ident_mid_event_enabled() and unit_is_enabled then
track_mid_event_unit(self._unit)
end
end)

mod:hook_safe(CLASS.DecoderDeviceExtension, "finished", function(self)
if mission_is_target and include_cypher_ident_mid_event_enabled() then
refresh_requested = true
end
end)

mod:hook_safe(CLASS.DoorControlPanelExtension, "toggle_door_state", function(self)
if mission_is_target and state == STATE_BUTTON_LOCKED and final_button_unit == self._unit then
arm_exit_door_search()
elseif mission_is_target and include_cypher_ident_mid_event_enabled() and mid_event_door_unit == self._unit then
finish_mid_event_state()
elseif mission_is_target and state == STATE_EXIT_DOOR_LOCKED and exit_door_unit == self._unit then
finish_tracking()
end
end)

mod:hook_safe(CLASS.Interactable, "interactable_set_used", function(self, unit)
if mission_is_target and state == STATE_BUTTON_LOCKED and final_button_unit == unit then
arm_exit_door_search()
elseif mission_is_target and state == STATE_EXIT_DOOR_LOCKED and exit_door_unit == unit then
finish_tracking()
elseif mission_is_target and mid_event_door_unit == unit then
finish_mid_event_state()
end
end)

mod:hook_safe(CLASS.Interactable, "interactable_disable", function(self, unit)
if mission_is_target and state == STATE_BUTTON_LOCKED and final_button_unit == unit then
arm_wait_for_exit_objective()
elseif mission_is_target and state == STATE_EXIT_DOOR_LOCKED and exit_door_unit == unit then
finish_tracking()
elseif mission_is_target and mid_event_door_unit == unit then
finish_mid_event_state()
end
end)

mod:hook_safe(CLASS.Interactable, "interactable_disable_local", function(self, unit)
if mission_is_target and state == STATE_BUTTON_LOCKED and final_button_unit == unit then
arm_wait_for_exit_objective()
elseif mission_is_target and state == STATE_EXIT_DOOR_LOCKED and exit_door_unit == unit then
finish_tracking()
elseif mission_is_target and mid_event_door_unit == unit then
finish_mid_event_state()
end
end)

mod:hook_safe(CLASS.MissionObjectiveSystem, "hot_join_sync", function()
if mission_is_target and include_cypher_ident_mid_event_enabled() then
scan_enabled_decoder_units()
end

if mission_is_target and should_update_markers() then
refresh_requested = true
end
end)

mod:hook_safe(CLASS.MissionObjectiveSystem, "start_mission_objective", function(self, objective_name)
if not mission_is_target or state ~= STATE_WAITING_FOR_EXIT_OBJECTIVE then
return
end

if objective_name == EXTRACTION_OBJECTIVE_NAME or extraction_objective_active() then
arm_exit_door_search()
end
end)

mod:hook_safe(CLASS.HudElementMissionObjectivePopup, "event_mission_objective_start", function(self, mission_name)
if not mission_is_target or state ~= STATE_WAITING_FOR_EXIT_OBJECTIVE then
return
end

if mission_name == EXTRACTION_OBJECTIVE_NAME then
arm_exit_door_search()
return
end

local mission_objective = self and self._mission_objective_system and self._mission_objective_system:active_objective(mission_name)
local header = mission_objective and normalise_text(mission_objective:header()) or nil

if header == EXTRACTION_OBJECTIVE_HEADER or (header and string.find(header, "extraction", 1, true) ~= nil) then
arm_exit_door_search()
end
end)

mod.on_setting_changed = function(setting_id)
refresh_cached_settings()

if setting_id == "include_cypher_ident_mid_event" then
if include_cypher_ident_mid_event_enabled() then
if mission_is_target then
scan_enabled_decoder_units()
refresh_requested = true
end
else
clear_mid_event_state()
end
end

if not mission_is_target or not should_update_markers() then
return
end

if setting_id == "marker_size" or setting_id == "marker_max_distance" or setting_id == "countdown" or setting_id == "indicate_level" or setting_id == "include_cypher_ident_mid_event" then
refresh_requested = true
elseif setting_id == "mark_final_button" then
if not final_button_enabled() then
clear_button_state()
clear_exit_door_state()

if delivered_caskets >= 3 then
finish_tracking()
return
end

set_state_for_current_counts()
elseif delivered_caskets >= 3 and state ~= STATE_BUTTON_LOCKED and state ~= STATE_WAITING_FOR_EXIT_OBJECTIVE and state ~= STATE_SEARCHING_EXIT_DOOR and state ~= STATE_EXIT_DOOR_LOCKED then
arm_button_search()
end

refresh_requested = true
end
end

mod.on_disabled = function()
clear_all_state()
end
