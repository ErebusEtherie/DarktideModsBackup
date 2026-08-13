-- salvage_player_drops.lua
return function(mod, shared)
local api = {}
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local context = shared and shared.context or Mods.file.dofile("salvage/scripts/mods/salvage/salvage_expedition_context")
local clear_table = context.clear_table
local should_run = context.should_run
local is_alive_unit = context.is_alive_unit
local safe_call = context.safe_call
local game_mode_manager = context.game_mode_manager
local pickup_type_from_unit = shared and shared.pickup_type_from_unit or function() return nil end
local pickup_type_from_marker_data = shared and shared.pickup_type_from_marker_data or function(marker)
if not marker then
return nil
end
local success, pickup_type = pcall(function()
local data = marker.data
return data and data.type or nil
end)
if success then
return pickup_type
end
return nil
end
local ROOT_NODE_INDEX = 1
local PLAYER_DROP_MARKER_TYPE = "salvage_player_drop_marker"
local PLAYER_DROP_MARKER_PENDING = "pending"
local PLAYER_DROP_MARKER_ICON = ""
local PLAYER_DROP_MARKER_BASE_FONT_SIZE = 66
local PLAYER_DROP_MARKER_DISABLED_FONT_SIZE = PLAYER_DROP_MARKER_BASE_FONT_SIZE
local PLAYER_DROP_MARKER_DEATH_FONT_SIZE = PLAYER_DROP_MARKER_BASE_FONT_SIZE
local PLAYER_DROP_MARKER_WIDGET_SIZE = 528
local PLAYER_DROP_MARKER_MAX_DISTANCE = 1000
local PLAYER_DROP_MARKER_POSITION_OFFSET = { 0, 0, 0.65 }
local PLAYER_DROP_MARKER_DEATH_COLOUR = { 255, 255, 0, 0 }
local PLAYER_DROP_MARKER_DISABLED_COLOUR = { 255, 255, 84, 0 }
local PLAYER_DROP_MARKER_SHADOW = { 220, 0, 0, 0 }
local PLAYER_DROP_MARKER_INVISIBLE = { 0, 0, 0, 0 }
local PLAYER_DROP_PICKUP_TYPE = "expedition_loot_player_drop"
local PLAYER_DROP_REASON_DEATH = "death"
local PLAYER_DROP_REASON_DISABLED = "disabled"
local PLAYER_DROP_RECENT_DURATION = 8
local PLAYER_DROP_RECENT_MATCH_DISTANCE = 12
mod._salvage_player_drop_worth_warning = mod._salvage_player_drop_worth_warning or { last_amount = nil, last_t = -999 }
mod._salvage_recent_player_drop_worth = mod._salvage_recent_player_drop_worth or { amount = nil, time = -999 }
mod._salvage_player_drop_worth_by_unit = mod._salvage_player_drop_worth_by_unit or setmetatable({}, { __mode = "k" })
mod._salvage_pending_player_drop_worth_records = mod._salvage_pending_player_drop_worth_records or {}
mod._salvage_stolen_loot_by_minion_unit = mod._salvage_stolen_loot_by_minion_unit or setmetatable({}, { __mode = "k" })
mod._salvage_player_drop_desired_units_scratch = mod._salvage_player_drop_desired_units_scratch or {}
local tracked_player_drop_markers_by_unit = setmetatable({}, { __mode = "k" })
local tracked_player_drop_pickups_by_unit = setmetatable({}, { __mode = "k" })
local tracked_pickups_by_unit = shared and shared.tracked_pickups_by_unit or mod._salvage_tracked_pickups_by_unit or setmetatable({}, { __mode = "k" })
local recent_player_drop_records = {}
local observed_local_player_drop_states_by_unit = setmetatable({}, { __mode = "k" })
local function world_markers_element()
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
return hud and hud.element and hud:element("HudElementWorldMarkers") or nil
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
if not player then
return nil
end
local unit = player.player_unit
if is_alive_unit(unit) then
return unit
end
if type(player.unit) == "function" then
local success, player_unit = pcall(player.unit, player)
if success and is_alive_unit(player_unit) then
return player_unit
end
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

local function player_drop_markers_enabled()
return mod:get("mark_player_dropped_remnants") == true
end
function mod._salvage_player_drop_warnings_enabled()
return mod:get("player_drop_warning") == true
end
function mod._salvage_player_drop_feature_enabled()
return player_drop_markers_enabled() or mod._salvage_player_drop_warnings_enabled()
end
function mod._salvage_current_main_time()
local time_manager = Managers and Managers.time
if time_manager and type(time_manager.time) == "function" then
local success, value = pcall(time_manager.time, time_manager, "main")
if success and type(value) == "number" then
return value
end
end
return 0
end
function mod._salvage_cache_player_drop_worth(amount)
local numeric_amount = math.abs(tonumber(amount) or 0)
if numeric_amount <= 0 then
return nil
end
local rounded_amount = math.floor(numeric_amount + 0.5)
mod._salvage_recent_player_drop_worth.amount = rounded_amount
mod._salvage_recent_player_drop_worth.time = mod._salvage_current_main_time()
return rounded_amount
end
function mod._salvage_recent_cached_player_drop_worth()
local record = mod._salvage_recent_player_drop_worth
local amount = record and tonumber(record.amount)
local time = record and tonumber(record.time) or -999
if amount and amount > 0 and mod._salvage_current_main_time() - time <= PLAYER_DROP_RECENT_DURATION then
return math.floor(amount + 0.5)
end
return nil
end
function mod._salvage_show_player_drop_worth_flash(amount)
local rounded_amount = mod._salvage_cache_player_drop_worth(amount)
if not rounded_amount or not should_run() or not mod._salvage_player_drop_warnings_enabled() or not Managers or not Managers.event then
return
end
local t = mod._salvage_current_main_time()
if mod._salvage_player_drop_worth_warning.last_amount == rounded_amount and t - mod._salvage_player_drop_worth_warning.last_t < 0.15 then
return
end
mod._salvage_player_drop_worth_warning.last_amount = rounded_amount
mod._salvage_player_drop_worth_warning.last_t = t
Managers.event:trigger("salvage_show_player_drop_worth_warning", rounded_amount, 1.5)
end
function mod._salvage_event_add_notification_message(self, message_type, data)
if type(data) ~= "table" or not mod._salvage_player_drop_feature_enabled() then
return
end
if message_type == "player_loot_drop" then
if type(mod._salvage_record_player_drop_notification) == "function" then
mod._salvage_record_player_drop_notification(data)
end
elseif message_type == "minion_loot_steal" then
mod._salvage_show_player_drop_worth_flash(data.amount)
elseif message_type == "minion_loot_drop" and type(mod._salvage_remember_recent_stolen_minion_drop) == "function" then
mod._salvage_remember_recent_stolen_minion_drop(data.amount)
end
end
function mod._salvage_register_player_drop_notification_event()
if mod._salvage_player_drop_notification_event_registered or not Managers or not Managers.event or type(Managers.event.register) ~= "function" then
return
end
Managers.event:register(mod, "event_add_notification_message", "_salvage_event_add_notification_message")
mod._salvage_player_drop_notification_event_registered = true
end
local function player_drop_marker_reason_from_source(reason)
if reason == PLAYER_DROP_REASON_DEATH or reason == "dead" or reason == "killed" or reason == "hogtied" then
return PLAYER_DROP_REASON_DEATH
end
if reason == PLAYER_DROP_REASON_DISABLED or reason == "knocked_down" or reason == "netted" or reason == "pounced" or reason == "mutant_charged" or reason == "grabbed" or reason == "disabled" or reason == "stolen" or reason == "direct_drop" then
return PLAYER_DROP_REASON_DISABLED
end
return nil
end
local function player_drop_reason_priority(reason)
if reason == PLAYER_DROP_REASON_DEATH then
return 2
end
if reason == PLAYER_DROP_REASON_DISABLED then
return 1
end
return 0
end
local function player_drop_marker_colour(reason)
if reason == PLAYER_DROP_REASON_DEATH then
return PLAYER_DROP_MARKER_DEATH_COLOUR
end
return PLAYER_DROP_MARKER_DISABLED_COLOUR
end
local function player_drop_marker_font_size(reason)
if reason == PLAYER_DROP_REASON_DEATH then
return PLAYER_DROP_MARKER_DEATH_FONT_SIZE
end
return PLAYER_DROP_MARKER_DISABLED_FONT_SIZE
end
function mod._salvage_player_drop_amount_symbol_string(amount)
local numeric_amount = math.floor(math.abs(tonumber(amount) or 0) + 0.5)
if numeric_amount <= 0 then
return ""
end
local text = tostring(numeric_amount)
local result = ""
for i = 1, #text do
local char = string.sub(text, i, i)
if char == "0" then
result = result .. ""
elseif char == "1" then
result = result .. ""
elseif char == "2" then
result = result .. ""
elseif char == "3" then
result = result .. ""
elseif char == "4" then
result = result .. ""
elseif char == "5" then
result = result .. ""
elseif char == "6" then
result = result .. ""
elseif char == "7" then
result = result .. ""
elseif char == "8" then
result = result .. ""
elseif char == "9" then
result = result .. ""
end
end
return result
end
local function player_drop_marker_is_live(marker_id)
if not marker_id or marker_id == PLAYER_DROP_MARKER_PENDING then
return false
end
local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id
return markers_by_id and markers_by_id[marker_id] ~= nil or false
end
local function remove_player_drop_marker_for_unit(unit)
local record = tracked_player_drop_markers_by_unit[unit]
local marker_id = record and record.id
if player_drop_marker_is_live(marker_id) and Managers and Managers.event then
Managers.event:trigger("remove_world_marker", marker_id)
end
tracked_player_drop_markers_by_unit[unit] = nil
end
local function remove_all_player_drop_markers()
for unit, _ in pairs(tracked_player_drop_markers_by_unit) do
remove_player_drop_marker_for_unit(unit)
end
clear_table(tracked_player_drop_pickups_by_unit)
clear_table(mod._salvage_player_drop_worth_by_unit)
clear_table(recent_player_drop_records)
clear_table(mod._salvage_pending_player_drop_worth_records)
clear_table(mod._salvage_stolen_loot_by_minion_unit)
clear_table(observed_local_player_drop_states_by_unit)
end
local function update_pending_player_drop_markers()
for unit, record in pairs(tracked_player_drop_markers_by_unit) do
if not is_alive_unit(unit) then
tracked_player_drop_markers_by_unit[unit] = nil
tracked_player_drop_pickups_by_unit[unit] = nil
mod._salvage_player_drop_worth_by_unit[unit] = nil
elseif record.id == PLAYER_DROP_MARKER_PENDING then
record.pending_frames = (record.pending_frames or 0) + 1
if record.pending_frames >= 30 then
tracked_player_drop_markers_by_unit[unit] = nil
end
elseif record.id and not player_drop_marker_is_live(record.id) then
tracked_player_drop_markers_by_unit[unit] = nil
end
end
end
local function update_player_drop_marker_widget(widget, marker, marker_template)
local content = widget.content
local style = widget.style
local visible = marker.draw ~= false
local unit = marker.unit
local record = unit and tracked_player_drop_markers_by_unit[unit]
local reason = player_drop_marker_reason_from_source(record and record.reason)
local colour = player_drop_marker_colour(reason)
local font_size = player_drop_marker_font_size(reason)
local marker_data = marker and marker.data
local cached_worth = record and record.worth or unit and mod._salvage_player_drop_worth_by_unit[unit] or marker_data and marker_data.worth
if not cached_worth and unit then
local live_worth = mod._salvage_dropped_loot_amount_for_unit(unit)
if type(live_worth) == "number" and live_worth > 0 then
cached_worth = math.floor(live_worth + 0.5)
mod._salvage_player_drop_worth_by_unit[unit] = cached_worth
if record then
record.worth = cached_worth
end
if marker_data then
marker_data.worth = cached_worth
end
end
end
if not cached_worth and unit and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
cached_worth = record and record.worth or mod._salvage_player_drop_worth_by_unit[unit] or marker_data and marker_data.worth
end
if not cached_worth and unit then
local recent_worth = mod._salvage_recent_cached_player_drop_worth()
if type(recent_worth) == "number" and recent_worth > 0 and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
cached_worth = recent_worth
mod._salvage_player_drop_worth_by_unit[unit] = recent_worth
if record then
record.worth = recent_worth
end
end
end
local numeric_worth = tonumber(cached_worth)
local worth_symbols = numeric_worth and numeric_worth > 0 and mod._salvage_player_drop_amount_symbol_string(numeric_worth) or ""
local line_text = worth_symbols ~= "" and PLAYER_DROP_MARKER_ICON .. " " .. worth_symbols or PLAYER_DROP_MARKER_ICON
widget.visible = true
content.icon = line_text
style.icon_shadow.font_size = font_size
style.icon.font_size = font_size
style.icon_shadow.size[1] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon_shadow.size[2] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon.size[1] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon.size[2] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon_shadow.text_color = visible and PLAYER_DROP_MARKER_SHADOW or PLAYER_DROP_MARKER_INVISIBLE
style.icon.text_color = visible and colour or PLAYER_DROP_MARKER_INVISIBLE
marker_template.max_distance = PLAYER_DROP_MARKER_MAX_DISTANCE
marker.scale = 1
marker.ignore_scale = true
widget.dirty = true
end
local function create_player_drop_marker_template()
local font_settings = UIFontSettings.hud_body
local template = {}
template.name = PLAYER_DROP_MARKER_TYPE
template._salvage_version = 35
template.size = { PLAYER_DROP_MARKER_WIDGET_SIZE, PLAYER_DROP_MARKER_WIDGET_SIZE }
template.unit_node = nil
template.position_offset = PLAYER_DROP_MARKER_POSITION_OFFSET
template.max_distance = PLAYER_DROP_MARKER_MAX_DISTANCE
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
distance_max = PLAYER_DROP_MARKER_MAX_DISTANCE,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil
template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "icon_shadow",
value = PLAYER_DROP_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = PLAYER_DROP_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
size = { PLAYER_DROP_MARKER_WIDGET_SIZE, PLAYER_DROP_MARKER_WIDGET_SIZE },
text_color = PLAYER_DROP_MARKER_SHADOW,
},
},
{
pass_type = "text",
style_id = "icon",
value = PLAYER_DROP_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = PLAYER_DROP_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
size = { PLAYER_DROP_MARKER_WIDGET_SIZE, PLAYER_DROP_MARKER_WIDGET_SIZE },
text_color = PLAYER_DROP_MARKER_DISABLED_COLOUR,
},
},
}, scenegraph_id)
end
template.on_enter = function(widget, marker, marker_template)
update_player_drop_marker_widget(widget, marker, marker_template)
end
template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
update_player_drop_marker_widget(widget, marker, marker_template)
end
return template
end
local function ensure_player_drop_marker_template()
local world_markers = world_markers_element()
if not world_markers or not world_markers._marker_templates then
return false
end
local marker_template = world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE]
if not marker_template or marker_template._salvage_version ~= 35 then
world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE] = create_player_drop_marker_template()
end
return true
end
function mod._salvage_install_player_drop_marker_template_patch()
if mod._salvage_player_drop_marker_template_patch_done then
return
end
if not CLASS or not CLASS.HudElementWorldMarkers or type(mod.hook_safe) ~= "function" then
return
end
mod._salvage_player_drop_marker_template_patch_done = true
mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(world_markers)
if world_markers and world_markers._marker_templates then
local marker_template = world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE]
if not marker_template or marker_template._salvage_version ~= 35 then
world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE] = create_player_drop_marker_template()
end
end
end)
end
local function read_unit_components(unit)
if not is_alive_unit(unit) or not ScriptUnit or not ScriptUnit.has_extension then
return nil, nil
end
local success, unit_data_extension = pcall(ScriptUnit.has_extension, unit, "unit_data_system")
if not success or not unit_data_extension or type(unit_data_extension.read_component) ~= "function" then
return nil, nil
end
local character_state_component = nil
local disabled_character_state_component = nil
local character_success, character_component = pcall(unit_data_extension.read_component, unit_data_extension, "character_state")
if character_success then
character_state_component = character_component
end
local disabled_success, disabled_component = pcall(unit_data_extension.read_component, unit_data_extension, "disabled_character_state")
if disabled_success then
disabled_character_state_component = disabled_component
end
return character_state_component, disabled_character_state_component
end
local function player_drop_reason_from_status_components(character_state_component, disabled_character_state_component)
local state_name = character_state_component and character_state_component.state_name
if state_name == "dead" or state_name == "hogtied" then
return PLAYER_DROP_REASON_DEATH
end
if character_state_component and PlayerUnitStatus and type(PlayerUnitStatus.is_disabled) == "function" then
local success, is_disabled = pcall(PlayerUnitStatus.is_disabled, character_state_component)
if success and is_disabled == true then
return PLAYER_DROP_REASON_DISABLED
end
end
if disabled_character_state_component and disabled_character_state_component.is_disabled == true then
return PLAYER_DROP_REASON_DISABLED
end
return nil
end
local function player_status_drop_reason(player)
local unit = player_unit_from_player(player)
if not unit then
return nil
end
local character_state_component, disabled_character_state_component = read_unit_components(unit)
return player_drop_reason_from_status_components(character_state_component, disabled_character_state_component)
end
local function remember_recent_player_drop_at_position(position, reason, worth, flash_warning, short_match)
local position_box = mod._salvage_box_position(position)
local stable_position = mod._salvage_unbox_position(position_box)
if not stable_position and type(worth) ~= "number" then
return
end
local marker_reason = player_drop_marker_reason_from_source(reason)
if not marker_reason then
return
end
local numeric_worth = math.abs(tonumber(worth) or 0)
if numeric_worth > 0 then
mod._salvage_cache_player_drop_worth(numeric_worth)
end
if flash_warning and numeric_worth > 0 then
mod._salvage_show_player_drop_worth_flash(numeric_worth)
end
if numeric_worth > 0 and type(mod._salvage_queue_pending_player_drop_worth) == "function" then
mod._salvage_queue_pending_player_drop_worth(numeric_worth, stable_position, marker_reason, flash_warning == true)
end
local best_unit = nil
local best_distance = PLAYER_DROP_RECENT_MATCH_DISTANCE
if stable_position then
for unit, _ in pairs(tracked_player_drop_pickups_by_unit) do
if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
local drop_position = unit_position(unit)
if drop_position then
local distance = mod._salvage_safe_vector_distance(stable_position, drop_position)
if distance and distance <= best_distance then
best_distance = distance
best_unit = unit
end
end
end
end
end
if best_unit then
tracked_player_drop_pickups_by_unit[best_unit] = marker_reason
if numeric_worth > 0 then
mod._salvage_player_drop_worth_by_unit[best_unit] = math.floor(numeric_worth + 0.5)
end
local marker_record = tracked_player_drop_markers_by_unit[best_unit]
if marker_record then
marker_record.reason = marker_reason
if numeric_worth > 0 then
marker_record.worth = math.floor(numeric_worth + 0.5)
end
end
if numeric_worth > 0 and type(mod._salvage_apply_player_drop_worth_to_unit) == "function" then
mod._salvage_apply_player_drop_worth_to_unit(best_unit, numeric_worth)
end
return
end
recent_player_drop_records[#recent_player_drop_records + 1] = {
position_box = position_box,
reason = marker_reason,
worth = numeric_worth > 0 and numeric_worth or nil,
flash_warning = flash_warning == true,
duration = short_match and 1.5 or PLAYER_DROP_RECENT_DURATION,
time = Managers and Managers.time and Managers.time:time("main") or 0,
}
end
function mod._salvage_record_player_drop_notification(data)
local player = data and data.player
local unit = player_unit_from_player(player)
local reason = player_status_drop_reason(player) or PLAYER_DROP_REASON_DISABLED
remember_recent_player_drop_at_position(unit and unit_position(unit) or nil, reason, data and data.amount, true)
end
local function observe_local_player_drop_source()
if not should_run() or not mod._salvage_player_drop_feature_enabled() then
return
end
local player_manager = Managers and Managers.player
local player = player_manager and player_manager.local_player and player_manager:local_player(1)
local unit = player_unit_from_player(player)
if not unit then
return
end
local character_state_component, disabled_character_state_component = read_unit_components(unit)
local reason = player_drop_reason_from_status_components(character_state_component, disabled_character_state_component)
if not reason then
observed_local_player_drop_states_by_unit[unit] = nil
return
end
local state_name = character_state_component and character_state_component.state_name or "none"
local disabling_type = disabled_character_state_component and disabled_character_state_component.disabling_type or "none"
local state_key = reason .. ":" .. state_name .. ":" .. disabling_type
if observed_local_player_drop_states_by_unit[unit] == state_key then
return
end
observed_local_player_drop_states_by_unit[unit] = state_key
remember_recent_player_drop_at_position(unit_position(unit), reason, nil, false)
end
local function remember_recent_player_drop(peer_id, reason, worth, flash_warning, short_match)
local player_manager = Managers and Managers.player
local player = player_manager and peer_id and player_manager.player and player_manager:player(peer_id, 1)
local unit = player_unit_from_player(player)
local position = unit and unit_position(unit)
remember_recent_player_drop_at_position(position, reason, worth, flash_warning, short_match)
end
local function prune_recent_player_drop_records(t)
for i = #recent_player_drop_records, 1, -1 do
local record = recent_player_drop_records[i]
if not record or t - (record.time or 0) > (record.duration or PLAYER_DROP_RECENT_DURATION) then
table.remove(recent_player_drop_records, i)
end
end
end
local function recent_player_drop_reason_for_unit(unit)
local position = unit_position(unit)
local t = Managers and Managers.time and Managers.time:time("main") or 0
prune_recent_player_drop_records(t)
local best_index = nil
local best_distance = PLAYER_DROP_RECENT_MATCH_DISTANCE
local best_priority = 0
local fallback_index = nil
local fallback_priority = 0
for i = 1, #recent_player_drop_records do
local record = recent_player_drop_records[i]
local record_position = mod._salvage_stored_record_position(record)
local priority = player_drop_reason_priority(record and record.reason)
if record_position and position then
local distance = mod._salvage_safe_vector_distance(position, record_position)
if distance and distance <= PLAYER_DROP_RECENT_MATCH_DISTANCE and (priority > best_priority or priority == best_priority and distance <= best_distance) then
best_distance = distance
best_priority = priority
best_index = i
end
elseif not record_position and type(record and record.worth) == "number" and record.worth > 0 and priority >= fallback_priority then
fallback_index = i
fallback_priority = priority
end
end
if not best_index then
best_index = fallback_index
end
if best_index then
local record = recent_player_drop_records[best_index]
local reason = record and record.reason
local worth = record and record.worth
if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
if record and record.flash_warning == true then
mod._salvage_show_player_drop_worth_flash(worth)
end
end
table.remove(recent_player_drop_records, best_index)
return reason
end
return nil
end
local function current_expedition_loot_handler()
local manager = game_mode_manager()
local game_mode = manager and safe_call(manager, "game_mode")
local candidates = {
game_mode,
game_mode and game_mode._logic,
game_mode and game_mode._game_mode_logic,
manager,
manager and manager._game_mode,
manager and manager._game_mode and manager._game_mode._logic,
}
for i = 1, #candidates do
local candidate = candidates[i]
local loot_handler = candidate and candidate._loot_handler
if loot_handler then
return loot_handler
end
if candidate and type(candidate.get_loot_handler) == "function" then
local success, result = pcall(candidate.get_loot_handler, candidate)
if success and result then
return result
end
end
if candidate and type(candidate.loot_handler) == "function" then
local success, result = pcall(candidate.loot_handler, candidate)
if success and result then
return result
end
end
end
return nil
end
function mod._salvage_current_pickup_system()
local extension_manager = Managers and Managers.state and Managers.state.extension
if not extension_manager or type(extension_manager.system) ~= "function" then
return nil
end
local success, pickup_system = pcall(extension_manager.system, extension_manager, "pickup_system")
if success then
return pickup_system
end
return nil
end
function mod._salvage_dropped_loot_table()
local loot_handler = current_expedition_loot_handler()
if not loot_handler then
return nil
end
if type(loot_handler.dropped_loot_by_pickup_units) == "function" then
local success, result = pcall(loot_handler.dropped_loot_by_pickup_units, loot_handler)
if success and type(result) == "table" then
return result
end
end
local dropped_loot = loot_handler._dropped_loot_by_pickup_unit
if type(dropped_loot) == "table" then
return dropped_loot
end
return nil
end
function mod._salvage_dropped_loot_amount_for_unit(unit)
if not unit then
return nil
end
local dropped_loot = mod._salvage_dropped_loot_table()
local amount = type(dropped_loot) == "table" and dropped_loot[unit] or nil
if type(amount) == "number" and amount > 0 then
return amount
end
return nil
end
function mod._salvage_dropped_reason_for_unit(unit)
local loot_handler = current_expedition_loot_handler()
local reasons = loot_handler and loot_handler._dropped_reason_by_pickup_unit
if type(reasons) ~= "table" then
return nil
end
return reasons[unit]
end
function mod._salvage_loot_handler_raw_drop_reason(unit)
return mod._salvage_dropped_reason_for_unit(unit)
end
function mod._salvage_rounded_player_drop_worth(amount)
local numeric_amount = math.abs(tonumber(amount) or 0)
if numeric_amount <= 0 then
return nil
end
return math.floor(numeric_amount + 0.5)
end
function mod._salvage_apply_player_drop_worth_to_unit(unit, amount)
local rounded_amount = mod._salvage_rounded_player_drop_worth(amount)
if not rounded_amount or not is_alive_unit(unit) or pickup_type_from_unit(unit) ~= PLAYER_DROP_PICKUP_TYPE then
return false
end
mod._salvage_player_drop_worth_by_unit[unit] = rounded_amount
local record = tracked_player_drop_markers_by_unit[unit]
if record then
record.worth = rounded_amount
end
local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id
local marker_id = record and record.id
local marker = marker_id and marker_id ~= PLAYER_DROP_MARKER_PENDING and markers_by_id and markers_by_id[marker_id]
if marker then
marker.data = marker.data or {}
marker.data.worth = rounded_amount
local widget = marker.widget
if widget then
widget.content.icon = PLAYER_DROP_MARKER_ICON .. " " .. mod._salvage_player_drop_amount_symbol_string(rounded_amount)
widget.dirty = true
end
end
if type(mod._salvage_request_player_drop_worth_marker) == "function" then
mod._salvage_request_player_drop_worth_marker(unit, rounded_amount)
end
return true
end
function mod._salvage_player_drop_unit_candidate_allowed(unit)
if not is_alive_unit(unit) or pickup_type_from_unit(unit) ~= PLAYER_DROP_PICKUP_TYPE then
return false
end
return mod._salvage_loot_handler_raw_drop_reason(unit) ~= "reward"
end
function mod._salvage_bind_pending_record_to_best_pickup(record)
if type(record) ~= "table" or not mod._salvage_rounded_player_drop_worth(record.amount) then
return false
end
local record_position = mod._salvage_stored_record_position(record)
local best_unit = nil
local best_distance = math.huge
local seen_units = {}
local function try_unit(unit)
if seen_units[unit] or not mod._salvage_player_drop_unit_candidate_allowed(unit) then
return
end
seen_units[unit] = true
local existing_worth = mod._salvage_player_drop_worth_by_unit[unit]
if type(existing_worth) == "number" and existing_worth > 0 then
return
end
local distance = 0
if record_position then
local position = unit_position(unit)
if not position then
return
end
distance = mod._salvage_safe_vector_distance(position, record_position)
if not distance or distance > PLAYER_DROP_RECENT_MATCH_DISTANCE then
return
end
elseif tracked_player_drop_markers_by_unit[unit] then
distance = 0
else
distance = 1
end
if distance < best_distance then
best_distance = distance
best_unit = unit
end
end
for unit, _ in pairs(tracked_player_drop_markers_by_unit) do
try_unit(unit)
end
for unit, _ in pairs(tracked_player_drop_pickups_by_unit) do
try_unit(unit)
end
if type(tracked_pickups_by_unit) == "table" then
for unit, pickup_type in pairs(tracked_pickups_by_unit) do
if pickup_type == PLAYER_DROP_PICKUP_TYPE then
try_unit(unit)
end
end
end
local pickup_system = mod._salvage_current_pickup_system()
local spawned_pickups = pickup_system and pickup_system._spawned_pickups
if type(spawned_pickups) == "table" then
for _, unit in pairs(spawned_pickups) do
try_unit(unit)
end
end
if best_unit then
local reason = player_drop_marker_reason_from_source(record.reason) or PLAYER_DROP_REASON_DISABLED
tracked_player_drop_pickups_by_unit[best_unit] = reason
mod._salvage_apply_player_drop_worth_to_unit(best_unit, record.amount)
return true
end
return false
end
function mod._salvage_queue_pending_player_drop_worth(amount, position, reason, prefer_existing_marker)
local rounded_amount = mod._salvage_rounded_player_drop_worth(amount)
if not rounded_amount then
return nil
end
local record = {
amount = rounded_amount,
position_box = mod._salvage_box_position(position),
reason = player_drop_marker_reason_from_source(reason) or PLAYER_DROP_REASON_DISABLED,
time = mod._salvage_current_main_time(),
prefer_existing_marker = prefer_existing_marker == true,
}
mod._salvage_pending_player_drop_worth_records[#mod._salvage_pending_player_drop_worth_records + 1] = record
mod._salvage_bind_pending_record_to_best_pickup(record)
return rounded_amount
end
function mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
local t = mod._salvage_current_main_time()
for i = #mod._salvage_pending_player_drop_worth_records, 1, -1 do
local record = mod._salvage_pending_player_drop_worth_records[i]
if not record or t - (record.time or 0) > PLAYER_DROP_RECENT_DURATION then
table.remove(mod._salvage_pending_player_drop_worth_records, i)
elseif mod._salvage_bind_pending_record_to_best_pickup(record) then
table.remove(mod._salvage_pending_player_drop_worth_records, i)
end
end
end
local function loot_handler_drop_reason(unit)
return player_drop_marker_reason_from_source(mod._salvage_loot_handler_raw_drop_reason(unit))
end
local function player_drop_reason_for_unit(unit)
if mod._salvage_loot_handler_raw_drop_reason(unit) == "reward" then
return nil
end
local cached_reason = tracked_player_drop_pickups_by_unit[unit]
if cached_reason then
local worth = mod._salvage_dropped_loot_amount_for_unit(unit)
if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end
return player_drop_marker_reason_from_source(cached_reason)
end
local handler_reason = loot_handler_drop_reason(unit)
if handler_reason then
tracked_player_drop_pickups_by_unit[unit] = handler_reason
local worth = mod._salvage_dropped_loot_amount_for_unit(unit)
if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end
return handler_reason
end
local recent_reason = recent_player_drop_reason_for_unit(unit)
if recent_reason then
tracked_player_drop_pickups_by_unit[unit] = recent_reason
return recent_reason
end
local cached_worth = mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth()
if type(cached_worth) == "number" and cached_worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(cached_worth + 0.5)
return PLAYER_DROP_REASON_DISABLED
end
return nil
end
mod._salvage_request_player_drop_worth_marker = function(unit, worth)
local rounded_worth = mod._salvage_rounded_player_drop_worth(worth or mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth())
if not rounded_worth or not is_alive_unit(unit) or pickup_type_from_unit(unit) ~= PLAYER_DROP_PICKUP_TYPE then
return
end
mod._salvage_player_drop_worth_by_unit[unit] = rounded_worth
local record = tracked_player_drop_markers_by_unit[unit]
if record then
record.worth = rounded_worth
local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id
local marker = record.id and record.id ~= PLAYER_DROP_MARKER_PENDING and markers_by_id and markers_by_id[record.id]
if marker then
marker.data = marker.data or {}
marker.data.worth = rounded_worth
if marker.widget then
marker.widget.content.icon = PLAYER_DROP_MARKER_ICON .. " " .. mod._salvage_player_drop_amount_symbol_string(rounded_worth)
marker.widget.dirty = true
end
end
end
end
local function request_player_drop_marker(unit, reason)
if not is_alive_unit(unit) or not ensure_player_drop_marker_template() or not Managers or not Managers.event then
return
end
local record = tracked_player_drop_markers_by_unit[unit]
local marker_reason = player_drop_marker_reason_from_source(reason)
if not marker_reason then
return
end
local worth = mod._salvage_dropped_loot_amount_for_unit(unit)
if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end
local cached_marker_worth = type(worth) == "number" and worth > 0 and math.floor(worth + 0.5) or mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth()
if type(cached_marker_worth) == "number" and cached_marker_worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(cached_marker_worth + 0.5)
end
if record and record.id == PLAYER_DROP_MARKER_PENDING then
record.reason = marker_reason
record.worth = cached_marker_worth or record.worth
mod._salvage_request_player_drop_worth_marker(unit, record.worth)
return
end
if record and player_drop_marker_is_live(record.id) then
record.reason = marker_reason
record.worth = cached_marker_worth or record.worth
mod._salvage_request_player_drop_worth_marker(unit, record.worth)
return
end
record = {
id = PLAYER_DROP_MARKER_PENDING,
pending_frames = 0,
reason = marker_reason,
worth = cached_marker_worth,
}
tracked_player_drop_markers_by_unit[unit] = record
local function on_marker_added(marker_id)
local current_record = tracked_player_drop_markers_by_unit[unit]
if current_record and current_record.id == PLAYER_DROP_MARKER_PENDING then
current_record.id = marker_id
current_record.pending_frames = nil
end
end
Managers.event:trigger("add_world_marker_unit", PLAYER_DROP_MARKER_TYPE, unit, on_marker_added, {
unit = unit,
worth = cached_marker_worth,
reason = marker_reason,
})
if cached_marker_worth then
mod._salvage_apply_player_drop_worth_to_unit(unit, cached_marker_worth)
end
mod._salvage_request_player_drop_worth_marker(unit, cached_marker_worth)
end
local function register_player_drop_pickup_unit(unit, reason, worth, flash_warning)
if not is_alive_unit(unit) then
return
end
local marker_reason = player_drop_marker_reason_from_source(reason)
if not marker_reason then
return
end
tracked_player_drop_pickups_by_unit[unit] = marker_reason
local cached_worth = worth
if type(cached_worth) ~= "number" then
cached_worth = mod._salvage_dropped_loot_amount_for_unit(unit)
end
if type(cached_worth) ~= "number" then
cached_worth = mod._salvage_recent_cached_player_drop_worth()
end
if type(cached_worth) ~= "number" and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
cached_worth = mod._salvage_player_drop_worth_by_unit[unit]
end
if type(cached_worth) == "number" and cached_worth > 0 then
local rounded_worth = math.floor(cached_worth + 0.5)
mod._salvage_player_drop_worth_by_unit[unit] = rounded_worth
if flash_warning == true then
mod._salvage_show_player_drop_worth_flash(rounded_worth)
end
local marker_record = tracked_player_drop_markers_by_unit[unit]
if marker_record then
marker_record.worth = rounded_worth
end
end
if player_drop_markers_enabled() then
request_player_drop_marker(unit, marker_reason)
end
end
function mod._salvage_maybe_register_player_drop_overlay(unit, pickup_type)
if pickup_type ~= PLAYER_DROP_PICKUP_TYPE or not is_alive_unit(unit) then
return
end
local raw_reason = mod._salvage_loot_handler_raw_drop_reason(unit)
if raw_reason == "reward" and not mod._salvage_player_drop_worth_by_unit[unit] and not mod._salvage_recent_cached_player_drop_worth() then
return
end
local reason = player_drop_reason_for_unit(unit) or PLAYER_DROP_REASON_DISABLED
local worth = mod._salvage_dropped_loot_amount_for_unit(unit) or mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth()
if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end
tracked_player_drop_pickups_by_unit[unit] = player_drop_marker_reason_from_source(reason)
if player_drop_markers_enabled() then
register_player_drop_pickup_unit(unit, reason, worth, false)
end
end
local function add_registered_player_drop_units(desired_units)
for unit, reason in pairs(tracked_player_drop_pickups_by_unit) do
local marker_reason = player_drop_marker_reason_from_source(reason)
if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE and marker_reason then
local live_worth = mod._salvage_dropped_loot_amount_for_unit(unit)
if type(live_worth) == "number" and live_worth > 0 then
mod._salvage_apply_player_drop_worth_to_unit(unit, live_worth)
end
desired_units[unit] = marker_reason
else
tracked_player_drop_pickups_by_unit[unit] = nil
mod._salvage_player_drop_worth_by_unit[unit] = nil
end
end
end
local function add_player_drop_marker_units(desired_units)
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
local world_markers = hud and hud.element and hud:element("HudElementWorldMarkers")
local markers_by_type = world_markers and world_markers._markers_by_type
if not markers_by_type then
return
end
for _, markers in pairs(markers_by_type) do
for i = 1, #markers do
local marker = markers[i]
local unit = marker and marker.unit
local pickup_type = unit and pickup_type_from_unit(unit)
if not pickup_type then
pickup_type = pickup_type_from_marker_data(marker)
end
if type(unit) == "userdata" and pickup_type == PLAYER_DROP_PICKUP_TYPE and is_alive_unit(unit) then
local reason = player_drop_reason_for_unit(unit)
if reason then
desired_units[unit] = reason
tracked_player_drop_pickups_by_unit[unit] = reason
end
end
end
end
end
function mod._salvage_remember_stolen_minion_unit(unit, amount)
local numeric_amount = math.abs(tonumber(amount) or 0)
if not unit or numeric_amount <= 0 then
return
end
local existing_record = mod._salvage_stolen_loot_by_minion_unit[unit]
local existing_amount = math.abs(tonumber(existing_record and existing_record.amount) or 0)
local position = unit_position(unit) or mod._salvage_stored_record_position(existing_record)
mod._salvage_stolen_loot_by_minion_unit[unit] = {
amount = existing_amount + numeric_amount,
position_box = mod._salvage_box_position(position),
time = mod._salvage_current_main_time(),
}
end
function mod._salvage_observe_stolen_minion_sources()
local t = mod._salvage_current_main_time()
for unit, record in pairs(mod._salvage_stolen_loot_by_minion_unit) do
if is_alive_unit(unit) then
local position = unit_position(unit)
if position then
mod._salvage_set_stored_record_position(record, position)
end
record.time = t
elseif record then
remember_recent_player_drop_at_position(mod._salvage_stored_record_position(record), PLAYER_DROP_REASON_DISABLED, record.amount, false)
mod._salvage_stolen_loot_by_minion_unit[unit] = nil
end
end
end
function mod._salvage_remember_recent_stolen_minion_drop(amount)
local numeric_amount = math.abs(tonumber(amount) or 0)
if numeric_amount <= 0 then
return false
end
local rounded_amount = math.floor(numeric_amount + 0.5)
local best_unit = nil
local best_record = nil
local best_age = math.huge
local t = mod._salvage_current_main_time()
for unit, record in pairs(mod._salvage_stolen_loot_by_minion_unit) do
local record_amount = math.floor(math.abs(tonumber(record and record.amount) or 0) + 0.5)
local age = t - (record and record.time or 0)
if record_amount == rounded_amount and age <= 20 and age < best_age then
best_unit = unit
best_record = record
best_age = age
end
end
if best_record then
local position = unit_position(best_unit) or mod._salvage_stored_record_position(best_record)
remember_recent_player_drop_at_position(position, PLAYER_DROP_REASON_DISABLED, best_record.amount, false)
mod._salvage_stolen_loot_by_minion_unit[best_unit] = nil
return true
end
return false
end
local function sync_player_drop_markers()
if not should_run() or not player_drop_markers_enabled() then
remove_all_player_drop_markers()
return
end
if not ensure_player_drop_marker_template() then
return
end
update_pending_player_drop_markers()
if type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
end
local desired_units = mod._salvage_player_drop_desired_units_scratch
clear_table(desired_units)
mod._salvage_add_pickup_system_player_drop_units(desired_units)
mod._salvage_add_tracked_pickup_player_drop_units(desired_units)
add_registered_player_drop_units(desired_units)
add_player_drop_marker_units(desired_units)
for unit, reason in pairs(desired_units) do
request_player_drop_marker(unit, reason)
end
for unit, _ in pairs(tracked_player_drop_markers_by_unit) do
if not desired_units[unit] then
remove_player_drop_marker_for_unit(unit)
end
end
end
local function install_player_drop_reason_hooks()
if mod._salvage_player_drop_reason_hooks_done or type(mod.hook_require) ~= "function" then
return
end
mod._salvage_player_drop_reason_hooks_done = true
mod:hook_require("scripts/utilities/expeditions/expedition_loot_handler", function(instance)
if not instance then
return
end
if type(instance.add_external_player_pickup_unit) == "function" then
mod:hook_safe(instance, "add_external_player_pickup_unit", function(_, pickup_unit, amount, reason)
local flash_warning = reason == PLAYER_DROP_REASON_DISABLED or reason == PLAYER_DROP_REASON_DEATH
register_player_drop_pickup_unit(pickup_unit, reason or PLAYER_DROP_REASON_DISABLED, amount, flash_warning)
end)
end
if type(instance.server_drop_player_loot) == "function" then
mod:hook_safe(instance, "server_drop_player_loot", function(loot_handler)
local reasons = loot_handler and loot_handler._dropped_reason_by_pickup_unit
if type(reasons) ~= "table" then
return
end
for unit, reason in pairs(reasons) do
if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
register_player_drop_pickup_unit(unit, reason, mod._salvage_dropped_loot_amount_for_unit(unit), reason == PLAYER_DROP_REASON_DEATH)
end
end
end)
end
if type(instance.rpc_client_expedition_remove_loot_collected) == "function" then
mod:hook_safe(instance, "rpc_client_expedition_remove_loot_collected", function(_, channel_id, peer_id, loot_type, amount_to_deduct)
if loot_type == "small" and type(amount_to_deduct) == "number" and amount_to_deduct > 0 then
remember_recent_player_drop(peer_id, PLAYER_DROP_REASON_DISABLED, amount_to_deduct, true, true)
end
end)
end
end)
mod:hook_require("scripts/utilities/expeditions/expedition_minion_loot_handler", function(instance)
if not instance then
return
end
if type(instance.rpc_player_loot_stolen) == "function" then
mod:hook_safe(instance, "rpc_player_loot_stolen", function(_, channel_id, peer_id, amount_to_steal, breed_id, game_object_id)
local unit_spawner = Managers and Managers.state and Managers.state.unit_spawner
local unit = unit_spawner and type(unit_spawner.unit) == "function" and unit_spawner:unit(game_object_id, nil, nil) or nil
mod._salvage_show_player_drop_worth_flash(amount_to_steal)
mod._salvage_remember_stolen_minion_unit(unit, amount_to_steal)
end)
end
end)
mod:hook_require("scripts/utilities/player_death", function(instance)
if not instance then
return
end
if type(instance.die) == "function" then
mod:hook_safe(instance, "die", function(unit)
remember_recent_player_drop_at_position(unit_position(unit), PLAYER_DROP_REASON_DEATH, nil, false)
end)
end
if type(instance.knock_down) == "function" then
mod:hook_safe(instance, "knock_down", function(unit)
remember_recent_player_drop_at_position(unit_position(unit), PLAYER_DROP_REASON_DISABLED, nil, false)
end)
end
end)
end
mod._salvage_player_drop_reason_for_unit = player_drop_reason_for_unit
function mod._salvage_note_player_drop_pickup_unit(unit, reason)
local marker_reason = player_drop_marker_reason_from_source(reason)
if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE and marker_reason then
tracked_player_drop_pickups_by_unit[unit] = marker_reason
end
end
mod._salvage_register_player_drop_pickup_unit = register_player_drop_pickup_unit
function api.on_all_mods_loaded()
mod._salvage_install_player_drop_marker_template_patch()
install_player_drop_reason_hooks()
mod._salvage_register_player_drop_notification_event()
end
function api.observe_local()
observe_local_player_drop_source()
end
function api.observe_stolen()
mod._salvage_observe_stolen_minion_sources()
end
function api.sync()
sync_player_drop_markers()
end
function api.remove_all()
remove_all_player_drop_markers()
end
function api.on_unit_deleted(unit)
local stolen_record = mod._salvage_stolen_loot_by_minion_unit[unit]
if stolen_record then
remember_recent_player_drop_at_position(mod._salvage_stored_record_position(stolen_record), PLAYER_DROP_REASON_DISABLED, stolen_record.amount, true)
end
remove_player_drop_marker_for_unit(unit)
tracked_player_drop_pickups_by_unit[unit] = nil
mod._salvage_stolen_loot_by_minion_unit[unit] = nil
mod._salvage_player_drop_worth_by_unit[unit] = nil
observed_local_player_drop_states_by_unit[unit] = nil
end
function api.reset_warning()
mod._salvage_player_drop_worth_warning.last_amount = nil
mod._salvage_player_drop_worth_warning.last_t = -999
end
return api
end
