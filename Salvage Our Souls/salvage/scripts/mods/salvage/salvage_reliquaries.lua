-- salvage_reliquaries.lua
return function(mod, shared)
local api = {}
local require_success, UIWidget = pcall(require, "scripts/managers/ui/ui_widget")
if not require_success then
UIWidget = nil
end
local context = shared and shared.context or {}
local clear_table = type(context.clear_table) == "function" and context.clear_table or function(value)
if type(value) == "table" and table and type(table.clear) == "function" then
table.clear(value)
end
end
local should_run = type(context.should_run) == "function" and context.should_run or function()
return false
end
local is_alive_unit = type(context.is_alive_unit) == "function" and context.is_alive_unit or function(unit)
if not unit or not Unit or type(Unit.alive) ~= "function" then
return false
end
local success, alive = pcall(Unit.alive, unit)
return success and alive == true
end
local safe_call = type(context.safe_call) == "function" and context.safe_call or function(object, method_name, ...)
local method = object and object[method_name]
if type(method) ~= "function" then
return nil
end
local success, result = pcall(method, object, ...)
if success then
return result
end
return nil
end
local ROOT_NODE_INDEX = 1
local RELIQUARY_EFFECT_CANDIDATES = {
"content/fx/particles/weapons/grenades/shock_grenade/shock_grenade_explosion",
"content/fx/particles/abilities/cryptic/cryptic_force_field_electric_explosion",
"content/fx/particles/weapons/grenades/shock_mine/shock_mine_self_destruct_01",
"content/fx/particles/player_buffs/buff_electricity_grenade_01",
}
local RELIQUARY_EFFECT_HEIGHT = 0.65
local RELIQUARY_REPEAT_INTERVAL = 1
local RELIQUARY_MARKER_TYPE = "salvage_reliquary_marker"
local RELIQUARY_MARKER_TEMPLATE_VERSION = 2
local RELIQUARY_MARKER_PENDING = "pending"
local RELIQUARY_MARKER_ICON = ""
local RELIQUARY_MARKER_FONT_SIZE = 52
local RELIQUARY_MARKER_DISTANCE_FONT_SIZE = 20
local RELIQUARY_MARKER_WIDGET_SIZE = 160
local RELIQUARY_MARKER_ICON_SIZE = 128
local RELIQUARY_MARKER_MAX_DISTANCE = 100
local RELIQUARY_MARKER_POSITION_OFFSET = { 0, 0, 0.8 }
local RELIQUARY_MARKER_COLOUR = { 255, 55, 150, 255 }
local RELIQUARY_MARKER_SHADOW = { 220, 0, 0, 0 }
local RELIQUARY_MARKER_DISTANCE_COLOUR = { 255, 210, 230, 255 }
local RELIQUARY_MARKER_DISTANCE_SHADOW = { 220, 0, 0, 0 }
local RELIQUARY_MARKER_INVISIBLE = { 0, 0, 0, 0 }
local RELIQUARY_PICKUP_TYPES = {
expedition_loot_heavy_tier_1 = true,
expedition_loot_heavy_tier_2 = true,
expedition_loot_heavy_tier_3 = true,
}
local tracked_reliquaries_by_unit = setmetatable({}, { __mode = "k" })
local tracked_effects_by_unit = setmetatable({}, { __mode = "k" })
local tracked_markers_by_unit = setmetatable({}, { __mode = "k" })
local touched_reliquaries_by_unit = setmetatable({}, { __mode = "k" })
local cached_pickup_types_by_unit = setmetatable({}, { __mode = "k" })
local desired_effect_units_scratch = {}
local desired_marker_units_scratch = {}
local function read_pickup_type_from_unit(unit)
if shared and type(shared.pickup_type_from_unit) == "function" then
local pickup_type = shared.pickup_type_from_unit(unit)
if type(pickup_type) == "string" and pickup_type ~= "" then
return pickup_type
end
end
if not unit or not Unit or not Unit.alive or not Unit.has_data or not Unit.get_data then
return nil
end
local alive_success, alive = pcall(Unit.alive, unit)
if not alive_success or not alive then
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
local function pickup_type_from_unit(unit)
if not unit then
return nil
end
if not is_alive_unit(unit) then
cached_pickup_types_by_unit[unit] = nil
return nil
end
local cached_pickup_type = cached_pickup_types_by_unit[unit]
if cached_pickup_type ~= nil then
return cached_pickup_type
end
local pickup_type = read_pickup_type_from_unit(unit)
if type(pickup_type) == "string" and pickup_type ~= "" then
cached_pickup_types_by_unit[unit] = pickup_type
end
return pickup_type
end
local function is_reliquary_type(pickup_type)
return RELIQUARY_PICKUP_TYPES[pickup_type] == true
end
local function electrify_enabled()
return mod:get("enable_reliquaries") == true
end
local function mark_enabled()
return mod:get("mark_reliquaries_within_100m") ~= false
end
local function luggable_extension(unit)
if not is_alive_unit(unit) or not ScriptUnit or not ScriptUnit.has_extension then
return nil
end
local success, extension = pcall(ScriptUnit.has_extension, unit, "luggable_system")
if success then
return extension
end
return nil
end
local function extension_currently_carried(extension)
if not extension then
return false
end
local carried = safe_call(extension, "is_currently_carried")
if carried ~= nil then
return carried == true
end
local carrier_unit = type(extension) == "table" and rawget(extension, "_carrier_player_unit") or nil
return is_alive_unit(carrier_unit) == true
end
local function is_currently_carried(unit)
return extension_currently_carried(luggable_extension(unit))
end
local function luggable_system_map()
local extension_manager = Managers and Managers.state and Managers.state.extension or nil
if not extension_manager or type(extension_manager.system) ~= "function" then
return nil
end
local success, system = pcall(extension_manager.system, extension_manager, "luggable_system")
if success and system and type(system._unit_to_extension_map) == "table" then
return system._unit_to_extension_map
end
return nil
end
local function world_markers_element()
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
return hud and hud.element and hud:element("HudElementWorldMarkers") or nil
end
local function reliquary_marker_is_live(marker_id)
if not marker_id or marker_id == RELIQUARY_MARKER_PENDING then
return false
end
local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id
return markers_by_id and markers_by_id[marker_id] ~= nil or false
end
local function remove_marker_for_unit(unit)
local record = tracked_markers_by_unit[unit]
local marker_id = record and record.id
if reliquary_marker_is_live(marker_id) and Managers and Managers.event then
Managers.event:trigger("remove_world_marker", marker_id)
end
tracked_markers_by_unit[unit] = nil
end
local function remove_all_markers()
for unit, _ in pairs(tracked_markers_by_unit) do
remove_marker_for_unit(unit)
end
end
local function update_pending_markers()
for unit, record in pairs(tracked_markers_by_unit) do
if not is_alive_unit(unit) then
tracked_markers_by_unit[unit] = nil
elseif record.id == RELIQUARY_MARKER_PENDING then
record.pending_frames = (record.pending_frames or 0) + 1
if record.pending_frames >= 30 then
tracked_markers_by_unit[unit] = nil
end
elseif record.id and not reliquary_marker_is_live(record.id) then
tracked_markers_by_unit[unit] = nil
end
end
end
local function update_marker_widget(widget, marker, marker_template)
local content = widget.content
local style = widget.style
local visible = marker.draw ~= false
local distance = marker.distance or content.distance
widget.visible = true
content.icon = RELIQUARY_MARKER_ICON
content.distance_text = visible and distance and distance > 1 and tostring(math.floor(distance + 0.5)) .. "m" or ""
style.icon_shadow.font_size = RELIQUARY_MARKER_FONT_SIZE
style.icon.font_size = RELIQUARY_MARKER_FONT_SIZE
style.icon_shadow.size[1] = RELIQUARY_MARKER_ICON_SIZE
style.icon_shadow.size[2] = RELIQUARY_MARKER_ICON_SIZE
style.icon.size[1] = RELIQUARY_MARKER_ICON_SIZE
style.icon.size[2] = RELIQUARY_MARKER_ICON_SIZE
style.icon_shadow.text_color = visible and RELIQUARY_MARKER_SHADOW or RELIQUARY_MARKER_INVISIBLE
style.icon.text_color = visible and RELIQUARY_MARKER_COLOUR or RELIQUARY_MARKER_INVISIBLE
if style.distance_shadow then
style.distance_shadow.text_color = visible and RELIQUARY_MARKER_DISTANCE_SHADOW or RELIQUARY_MARKER_INVISIBLE
end
if style.distance_text then
style.distance_text.text_color = visible and RELIQUARY_MARKER_DISTANCE_COLOUR or RELIQUARY_MARKER_INVISIBLE
end
marker.scale = 1
marker.ignore_scale = true
end
local function create_marker_template()
if not UIWidget then
return nil
end
local font_type = "proxima_nova_bold"
local template = {}
template.name = RELIQUARY_MARKER_TYPE
template._salvage_reliquary_template_version = RELIQUARY_MARKER_TEMPLATE_VERSION
template.size = { RELIQUARY_MARKER_WIDGET_SIZE, RELIQUARY_MARKER_WIDGET_SIZE }
template.position_offset = RELIQUARY_MARKER_POSITION_OFFSET
template.max_distance = RELIQUARY_MARKER_MAX_DISTANCE
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
distance_max = RELIQUARY_MARKER_MAX_DISTANCE,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil
template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "icon_shadow",
value = RELIQUARY_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_type,
font_size = RELIQUARY_MARKER_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
size = { RELIQUARY_MARKER_ICON_SIZE, RELIQUARY_MARKER_ICON_SIZE },
text_color = RELIQUARY_MARKER_SHADOW,
},
},
{
pass_type = "text",
style_id = "icon",
value = RELIQUARY_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_type,
font_size = RELIQUARY_MARKER_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
size = { RELIQUARY_MARKER_ICON_SIZE, RELIQUARY_MARKER_ICON_SIZE },
text_color = RELIQUARY_MARKER_COLOUR,
},
},
{
pass_type = "text",
style_id = "distance_shadow",
value = "",
value_id = "distance_text",
style = {
font_type = font_type,
font_size = RELIQUARY_MARKER_DISTANCE_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 70, 2 },
size = { RELIQUARY_MARKER_WIDGET_SIZE, 32 },
text_color = RELIQUARY_MARKER_DISTANCE_SHADOW,
},
},
{
pass_type = "text",
style_id = "distance_text",
value = "",
value_id = "distance_text",
style = {
font_type = font_type,
font_size = RELIQUARY_MARKER_DISTANCE_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 68, 3 },
size = { RELIQUARY_MARKER_WIDGET_SIZE, 32 },
text_color = RELIQUARY_MARKER_DISTANCE_COLOUR,
},
},
}, scenegraph_id)
end
template.on_enter = function(widget, marker, marker_template)
update_marker_widget(widget, marker, marker_template)
end
template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
update_marker_widget(widget, marker, marker_template)
end
return template
end
local function ensure_marker_template()
local world_markers = world_markers_element()
if not world_markers or not world_markers._marker_templates then
return false
end
local marker_template = world_markers._marker_templates[RELIQUARY_MARKER_TYPE]
if not marker_template or marker_template._salvage_reliquary_template_version ~= RELIQUARY_MARKER_TEMPLATE_VERSION then
marker_template = create_marker_template()
if not marker_template then
return false
end
world_markers._marker_templates[RELIQUARY_MARKER_TYPE] = marker_template
end
return true
end
local function request_marker(unit)
if not is_alive_unit(unit) or not ensure_marker_template() or not Managers or not Managers.event then
return
end
local record = tracked_markers_by_unit[unit]
if record and record.id == RELIQUARY_MARKER_PENDING then
return
end
if record and reliquary_marker_is_live(record.id) then
return
end
record = {
id = RELIQUARY_MARKER_PENDING,
pending_frames = 0,
}
tracked_markers_by_unit[unit] = record
local function on_marker_added(marker_id)
local current_record = tracked_markers_by_unit[unit]
if current_record and current_record.id == RELIQUARY_MARKER_PENDING then
current_record.id = marker_id
current_record.pending_frames = nil
end
end
Managers.event:trigger("add_world_marker_unit", RELIQUARY_MARKER_TYPE, unit, on_marker_added, {
unit = unit,
})
end
local function stop_particle(world, effect_id)
if not world or not effect_id or not World then
return
end
local destroyed = false
if World.destroy_particles then
local success = pcall(World.destroy_particles, world, effect_id)
destroyed = success == true
end
if not destroyed and World.stop_spawning_particles then
pcall(World.stop_spawning_particles, world, effect_id)
end
end
local function stop_particle_record(world, particle_record)
if type(particle_record) == "table" then
if particle_record.player_fx then
stop_particle(world, particle_record.particle_id)
return
end
for i = 1, #particle_record do
stop_particle(world, particle_record[i])
end
else
stop_particle(world, particle_record)
end
end
local function stop_effect_for_unit(unit)
local record = tracked_effects_by_unit[unit]
if not record then
return
end
stop_particle_record(record.world, record.particle_record)
tracked_effects_by_unit[unit] = nil
end
local function stop_all_effects()
for unit, _ in pairs(tracked_effects_by_unit) do
stop_effect_for_unit(unit)
end
end
local function unit_world_and_position(unit)
if not is_alive_unit(unit) or not Unit or type(Unit.world) ~= "function" or type(Unit.world_position) ~= "function" then
return nil, nil
end
local world_success, world = pcall(Unit.world, unit)
if not world_success or not world then
return nil, nil
end
local position_success, position = pcall(Unit.world_position, unit, ROOT_NODE_INDEX)
if not position_success or not position then
return nil, nil
end
return world, position
end
local function create_reliquary_particle(world, position)
local particle_group = type(mod._salvage_managed_particle_group) == "function" and mod._salvage_managed_particle_group(world) or nil
for i = 1, #RELIQUARY_EFFECT_CANDIDATES do
local effect_name = RELIQUARY_EFFECT_CANDIDATES[i]
local particle_id = type(mod._salvage_create_particle) == "function" and mod._salvage_create_particle(world, effect_name, position, nil, nil, particle_group) or nil
if particle_id then
return particle_id
end
local player_effect_id = type(mod._salvage_create_player_fx_particle) == "function" and mod._salvage_create_player_fx_particle(effect_name, position, nil, nil) or nil
if player_effect_id then
return {
player_fx = true,
particle_id = player_effect_id,
vfx = effect_name,
}
end
end
return nil
end
local function create_effect_for_unit(unit)
local world, position = unit_world_and_position(unit)
if not world or not position or not Vector3 then
return nil
end
local particle_record = create_reliquary_particle(world, position + Vector3(0, 0, RELIQUARY_EFFECT_HEIGHT))
if particle_record then
return {
world = world,
particle_record = particle_record,
timer = 0,
}
end
return nil
end
local function spawn_effect_for_unit(unit)
if not electrify_enabled() or not is_alive_unit(unit) or is_currently_carried(unit) then
stop_effect_for_unit(unit)
return
end
local old_record = tracked_effects_by_unit[unit]
if old_record then
stop_particle_record(old_record.world, old_record.particle_record)
tracked_effects_by_unit[unit] = nil
end
local record = create_effect_for_unit(unit)
if record then
tracked_effects_by_unit[unit] = record
end
end
local function note_touched(unit)
if not is_alive_unit(unit) then
return
end
touched_reliquaries_by_unit[unit] = true
remove_marker_for_unit(unit)
end
local function consider_reliquary_unit(desired_effect_units, desired_marker_units, unit, extension)
if not is_alive_unit(unit) then
return
end
local pickup_type = pickup_type_from_unit(unit)
if not is_reliquary_type(pickup_type) then
return
end
tracked_reliquaries_by_unit[unit] = pickup_type
local carried = extension and extension_currently_carried(extension) or is_currently_carried(unit)
if carried then
note_touched(unit)
stop_effect_for_unit(unit)
return
end
if electrify_enabled() then
desired_effect_units[unit] = true
end
if mark_enabled() and not touched_reliquaries_by_unit[unit] then
desired_marker_units[unit] = true
end
end
local function add_luggable_reliquaries(desired_effect_units, desired_marker_units)
local map = luggable_system_map()
if type(map) ~= "table" then
return
end
for unit, extension in pairs(map) do
consider_reliquary_unit(desired_effect_units, desired_marker_units, unit, extension)
end
end
local function add_tracked_reliquaries(desired_effect_units, desired_marker_units)
for unit, _ in pairs(tracked_reliquaries_by_unit) do
if is_alive_unit(unit) then
consider_reliquary_unit(desired_effect_units, desired_marker_units, unit, luggable_extension(unit))
else
tracked_reliquaries_by_unit[unit] = nil
touched_reliquaries_by_unit[unit] = nil
cached_pickup_types_by_unit[unit] = nil
end
end
end
local function sync_reliquaries()
if not should_run() then
api.stop_all(true)
return
end
local desired_effect_units = desired_effect_units_scratch
local desired_marker_units = desired_marker_units_scratch
clear_table(desired_effect_units)
clear_table(desired_marker_units)
update_pending_markers()
add_tracked_reliquaries(desired_effect_units, desired_marker_units)
add_luggable_reliquaries(desired_effect_units, desired_marker_units)
for unit, _ in pairs(desired_effect_units) do
if not tracked_effects_by_unit[unit] then
spawn_effect_for_unit(unit)
end
end
for unit, _ in pairs(desired_marker_units) do
request_marker(unit)
end
for unit, _ in pairs(tracked_effects_by_unit) do
if not desired_effect_units[unit] then
stop_effect_for_unit(unit)
end
end
for unit, _ in pairs(tracked_markers_by_unit) do
if not desired_marker_units[unit] then
remove_marker_for_unit(unit)
end
end
end
function api.is_setting(setting_id)
return setting_id == "enable_reliquaries" or setting_id == "mark_reliquaries_within_100m"
end
function api.stop_all(clear_units)
stop_all_effects()
remove_all_markers()
if clear_units then
clear_table(tracked_reliquaries_by_unit)
clear_table(touched_reliquaries_by_unit)
clear_table(cached_pickup_types_by_unit)
end
end
function api.sync()
sync_reliquaries()
end
function api.update(dt)
local update_dt = type(dt) == "number" and dt or 0
for unit, record in pairs(tracked_effects_by_unit) do
if not is_alive_unit(unit) or not electrify_enabled() or is_currently_carried(unit) then
stop_effect_for_unit(unit)
else
record.timer = (record.timer or 0) + update_dt
if record.timer >= RELIQUARY_REPEAT_INTERVAL then
record.timer = record.timer % RELIQUARY_REPEAT_INTERVAL
spawn_effect_for_unit(unit)
end
end
end
end
function api.on_unit_deleted(unit)
if not unit then
return
end
stop_effect_for_unit(unit)
remove_marker_for_unit(unit)
tracked_reliquaries_by_unit[unit] = nil
touched_reliquaries_by_unit[unit] = nil
cached_pickup_types_by_unit[unit] = nil
end
return api
end