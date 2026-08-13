-- swagger.lua
local mod = get_mod("swagger")
local unpack_values = table.unpack or unpack
local HUB_NAMES = {
hub = true,
hub_singleplay = true,
prologue_hub = true,
}
local SWAGGER_POSITION = {
x = -24.0024,
y = -122.0962,
z = 100.1014,
}
local SWAGGER_MATCH_RADIUS = 0.5
local SWAGGER_MATCH_RADIUS_SQ = SWAGGER_MATCH_RADIUS * SWAGGER_MATCH_RADIUS
local SWAGGER_NUM_ACTORS = 40
local SWAGGER_NUM_MESHES = 21
local SWAGGER_INTERACTION_DISTANCE = 4
local SWAGGER_INTERACTION_DISTANCE_SQ = SWAGGER_INTERACTION_DISTANCE * SWAGGER_INTERACTION_DISTANCE
local SWAGGER_BECKON_DISTANCE = 9
local SWAGGER_BECKON_DISTANCE_SQ = SWAGGER_BECKON_DISTANCE * SWAGGER_BECKON_DISTANCE
local SWAGGER_RESET_DISTANCE = 7
local SWAGGER_RESET_DISTANCE_SQ = SWAGGER_RESET_DISTANCE * SWAGGER_RESET_DISTANCE
local BACKUP_SAVE_DELAY = 3.5
local BACKUP_NOTICE_DURATION = 3
local SWAGGER_PLAYER_EMOTE_STATE_MACHINE = "content/characters/player/human/third_person/animations/unarmed_hub"
local SWAGGER_ARCHETYPE_VARIABLES = {
"adamant_active",
"broker_active",
"cryptic_active",
"psyker_active",
"veteran_active",
"zealot_active",
}
local REQUIRED_NODES = {
"j_head",
"j_hips",
"j_leftshoulder",
"j_rightshoulder",
}
local SWAGGER_WORK_LINE_WORDS = {
"fascinating",
"watch",
"work",
}
local SWAGGER_EMOTE_EVENTS = {
beckon = {
event = "emote_greeting_004",
label = "Beckon",
},
hunker = {
event = "emote_personality_006",
label = "Hunker Down",
},
nod = {
event = "emote_affirmative_004",
label = "Nod",
},
}
local function safe_call(fn, ...)
if type(fn) ~= "function" then
return false, nil
end
local values = {
pcall(fn, ...),
}
local ok = values[1]
table.remove(values, 1)
return ok, unpack_values(values)
end
local function safe_method(object, method_name, ...)
if object == nil then
return false, nil
end
local ok, method = pcall(function()
return object[method_name]
end)
if not ok or type(method) ~= "function" then
return false, nil
end
return safe_call(method, object, ...)
end
local function finite_number(value)
return type(value) == "number" and value == value and value < math.huge and value > -math.huge
end
local function vector_values(vector)
if vector == nil then
return nil
end
local ok, x, y, z = pcall(function()
return vector.x, vector.y, vector.z
end)
if not ok or not finite_number(x) or not finite_number(y) or not finite_number(z) then
return nil
end
return x, y, z
end
local function current_game_mode_name()
local managers = rawget(_G, "Managers")
local manager = managers and managers.state and managers.state.game_mode
local ok, value = safe_method(manager, "game_mode_name")
return ok and value or nil
end
local function local_player_unit()
local managers = rawget(_G, "Managers")
local player_manager = managers and managers.player
local ok, player = safe_method(player_manager, "local_player", 1)
if not ok or not player then
return nil
end
local success, unit = pcall(function()
return player.player_unit
end)
return success and unit or nil
end
local function component_position(unit, component_name)
local script_unit = rawget(_G, "ScriptUnit")
if not unit or not script_unit or type(script_unit.has_extension) ~= "function" then
return nil
end
local ok_extension, extension = safe_call(script_unit.has_extension, unit, "unit_data_system")
if not ok_extension or not extension then
return nil
end
local ok_component, component = safe_method(extension, "read_component", component_name)
if not ok_component or not component then
return nil
end
local ok_position, position = pcall(function()
return component.position
end)
if ok_position and vector_values(position) then
return position
end
return nil
end
local function player_position(unit)
local position = component_position(unit, "locomotion")
if position then
return position
end
position = component_position(unit, "first_person")
if position then
return position
end
local unit_api = rawget(_G, "Unit")
local ok, fallback = safe_call(unit_api and unit_api.world_position, unit, 1)
if ok and vector_values(fallback) then
return fallback
end
return nil
end
local function unit_alive(unit)
local unit_api = rawget(_G, "Unit")
local ok, alive = safe_call(unit_api and unit_api.alive, unit)
return ok and alive == true
end
local function unit_position(unit)
if not unit or not unit_alive(unit) then
return nil
end
local unit_api = rawget(_G, "Unit")
local ok, position = safe_call(unit_api and unit_api.world_position, unit, 1)
if ok and vector_values(position) then
return position
end
return nil
end
local function distance_squared(a, b)
local ax, ay, az = vector_values(a)
local bx, by, bz = vector_values(b)
if not ax or not bx then
return nil
end
local dx = ax - bx
local dy = ay - by
local dz = az - bz
local value = dx * dx + dy * dy + dz * dz
return finite_number(value) and value or nil
end
local function has_node(unit, node_name)
local unit_api = rawget(_G, "Unit")
local ok, result = safe_call(unit_api and unit_api.has_node, unit, node_name)
return ok and result == true
end
local function node_position(unit, node_name)
if not has_node(unit, node_name) then
return nil
end
local unit_api = rawget(_G, "Unit")
local ok_index, index = safe_call(unit_api and unit_api.node, unit, node_name)
if not ok_index or index == nil then
return nil
end
local ok_position, position = safe_call(unit_api and unit_api.world_position, unit, index)
if not ok_position or not vector_values(position) then
return nil
end
return position
end
local function local_player_camera()
local managers = rawget(_G, "Managers")
local player_manager = managers and managers.player
local camera_manager = managers and managers.state and managers.state.camera
local ok_player, player = safe_method(player_manager, "local_player", 1)
if not ok_player or not player or not camera_manager then
return nil
end
local ok_viewport, viewport_name = pcall(function()
return player.viewport_name
end)
if not ok_viewport or type(viewport_name) ~= "string" or viewport_name == "" then
return nil
end
local ok_camera, camera = safe_method(camera_manager, "camera", viewport_name)
return ok_camera and camera or nil
end
local function swagger_view_target(unit)
local head_position = node_position(unit, "j_head")
if head_position then
return head_position
end
local position = unit_position(unit)
local x, y, z = vector_values(position)
if not x then
return nil
end
local vector3 = rawget(_G, "Vector3")
if vector3 then
local ok, target = pcall(vector3, x, y, z + 1.5)
if ok and target then
return target
end
end
return position
end
local function player_is_looking_at_swagger(unit)
local camera = local_player_camera()
local target = unit and swagger_view_target(unit)
local camera_api = rawget(_G, "Camera")
if not camera or not target or not camera_api then
return false
end
local ok_screen, _, depth = safe_call(camera_api.world_to_screen, camera, target)
local ok_frustum, inside_frustum = safe_call(camera_api.inside_frustum, camera, target)
return ok_screen and finite_number(depth) and depth > 0 and ok_frustum and type(inside_frustum) == "number" and inside_frustum > 0
end
local function level_world()
local managers = rawget(_G, "Managers")
local world_manager = managers and managers.world
local ok, world = safe_method(world_manager, "world", "level_world")
return ok and world or nil
end
local function unit_count(unit, count_function)
local ok, value = safe_call(count_function, unit)
if ok and type(value) == "number" then
return value
end
return nil
end
local function swagger_signature_matches(unit)
if not unit or not unit_alive(unit) then
return false
end
for _, node_name in ipairs(REQUIRED_NODES) do
if not has_node(unit, node_name) then
return false
end
end
local unit_api = rawget(_G, "Unit")
local num_actors = unit_count(unit, unit_api and unit_api.num_actors)
local num_meshes = unit_count(unit, unit_api and unit_api.num_meshes)
return num_actors == SWAGGER_NUM_ACTORS and num_meshes == SWAGGER_NUM_MESHES
end
local function find_physical_swagger(world)
local world_api = rawget(_G, "World")
local level_api = rawget(_G, "Level")
local ok_levels, levels = safe_call(world_api and world_api.levels, world)
if not ok_levels or type(levels) ~= "table" then
return nil
end
local best_unit
local best_distance_sq
for level_order = 1, #levels do
local level = levels[level_order]
local ok_name, level_name = safe_call(level_api and level_api.name, level)
local is_hub_level = ok_name and type(level_name) == "string" and string.find(level_name, "hub_ship", 1, true) ~= nil
if is_hub_level then
local ok_units, units = safe_call(level_api and level_api.units, level, true)
if ok_units and type(units) == "table" then
for array_index = 1, #units do
local unit = units[array_index]
local position = unit_position(unit)
local distance_sq = distance_squared(SWAGGER_POSITION, position)
if distance_sq and distance_sq <= SWAGGER_MATCH_RADIUS_SQ and swagger_signature_matches(unit) then
if not best_distance_sq or distance_sq < best_distance_sq then
best_unit = unit
best_distance_sq = distance_sq
end
end
end
end
end
end
return best_unit
end
local function physical_swagger_unit()
local unit = mod.swagger_cached_unit
if unit and swagger_signature_matches(unit) then
return unit
end
local world = level_world()
if not world then
return nil
end
unit = find_physical_swagger(world)
if unit then
mod.swagger_cached_unit = unit
end
return unit
end
local function normalise_search_text(value)
value = string.lower(tostring(value or ""))
value = string.gsub(value, "{#.-}", " ")
value = string.gsub(value, "[^%w]+", " ")
value = string.gsub(value, "^%s+", "")
value = string.gsub(value, "%s+$", "")
return value
end
local function safe_field(item, field_name)
if item == nil then
return nil
end
local ok, value = pcall(function()
return item[field_name]
end)
return ok and value or nil
end
local function swagger_dialogue_extension(unit)
local script_unit = rawget(_G, "ScriptUnit")
if not unit or not script_unit or type(script_unit.has_extension) ~= "function" then
return nil
end
local ok, extension = safe_call(script_unit.has_extension, unit, "dialogue_system")
return ok and extension or nil
end
local function localised_dialogue_line(localisation_key)
if type(localisation_key) ~= "string" or localisation_key == "" then
return nil
end
local managers = rawget(_G, "Managers")
local localisation_manager = managers and managers.localization
local ok_exists, exists = safe_method(localisation_manager, "exists", localisation_key)
if ok_exists and exists == true then
local ok_text, text = safe_method(localisation_manager, "localize", localisation_key)
if ok_text and type(text) == "string" and text ~= "" then
return text
end
end
local global_localize = rawget(_G, "Localize")
local ok_text, text = safe_call(global_localize, localisation_key)
if ok_text and type(text) == "string" and text ~= "" and text ~= localisation_key then
return text
end
return nil
end
local function is_swagger_work_line(text)
local normalized = normalise_search_text(text)
for _, word in ipairs(SWAGGER_WORK_LINE_WORDS) do
if not string.find(normalized, word, 1, true) then
return false
end
end
return true
end
local function find_swagger_work_line(extension)
local cached = mod.swagger_work_line
if cached and cached.extension == extension then
return cached
end
local ok_choice, vo_choice = pcall(function()
return extension._vo_choice
end)
if not ok_choice or type(vo_choice) ~= "table" then
return nil
end
for rule_name, rule in pairs(vo_choice) do
local sound_events = safe_field(rule, "sound_events")
if type(rule_name) == "string" and type(sound_events) == "table" then
for line_index, sound_event in ipairs(sound_events) do
local text = localised_dialogue_line(sound_event)
if text and is_swagger_work_line(text) then
local match = {
extension = extension,
rule_name = rule_name,
line_index = line_index,
sound_event = sound_event,
text = text,
}
mod.swagger_work_line = match
mod:info("Matched Swagger backup line %s[%d]: %s", tostring(rule_name), line_index, tostring(text))
return match
end
end
end
end
return nil
end
local function play_swagger_work_line()
local unit = physical_swagger_unit()
local extension = unit and swagger_dialogue_extension(unit)
if not extension then
return false
end
local line = find_swagger_work_line(extension)
if not line then
if not mod.swagger_work_line_missing_logged then
mod.swagger_work_line_missing_logged = true
mod:warning("Swagger's loaded dialogue did not contain a localised line matching fascinating, watch and work.")
end
return false
end
local ok_current, current = safe_method(extension, "get_currently_playing_dialogue")
if ok_current and current then
safe_method(extension, "stop_currently_playing_vo")
end
local route_key = 1
local ok_choice, vo_choice = pcall(function()
return extension._vo_choice
end)
local rule = ok_choice and type(vo_choice) == "table" and vo_choice[line.rule_name] or nil
local configured_route = safe_field(rule, "wwise_route")
if type(configured_route) == "number" then
route_key = configured_route
end
local ok_play = safe_method(extension, "play_local_vo_event", line.rule_name, route_key, nil, nil, false, nil, nil, line.line_index)
if ok_play then
mod:info("Played Swagger backup line %s[%d] using %s.", tostring(line.rule_name), line.line_index, tostring(line.sound_event))
return true
end
mod:warning("Swagger's matched backup line could not be played safely.")
return false
end
local function component_system()
local managers = rawget(_G, "Managers")
local extension_manager = managers and managers.state and managers.state.extension
local ok_system, system = safe_method(extension_manager, "system", "component_system")
return ok_system and system or nil
end
local function swagger_animation_component(unit)
local system = component_system()
if not system then
return nil, nil
end
for _, component_name in ipairs({
"NpcAnimation",
"PropAnimation",
}) do
local ok_components, components = safe_method(system, "get_components", unit, component_name)
if ok_components and type(components) == "table" and components[1] then
return components[1], component_name
end
end
return nil, nil
end
local function capture_swagger_animation_restore(unit)
local current = mod.swagger_animation_restore
if current and current.unit == unit and unit_alive(unit) then
return current
end
local component, component_name = swagger_animation_component(unit)
local state_machine_override
local state_machine_init_event
if component then
local ok_state_machine, value = safe_method(component, "get_data", unit, "state_machine_override")
if ok_state_machine and type(value) == "string" and value ~= "" then
state_machine_override = value
end
local ok_init_event, init_value = safe_method(component, "get_data", unit, "state_machine_init_event")
if ok_init_event and type(init_value) == "string" and init_value ~= "" then
state_machine_init_event = init_value
end
end
local restore = {
unit = unit,
component = component,
component_name = component_name,
state_machine_override = state_machine_override,
state_machine_init_event = state_machine_init_event,
}
mod.swagger_animation_restore = restore
return restore
end
local function restore_swagger_animation()
local restore = mod.swagger_animation_restore
local unit = restore and restore.unit or physical_swagger_unit()
if not unit or not unit_alive(unit) then
mod.swagger_animation_restore = nil
return false
end
local restored = false
local component = restore and restore.component
local component_name = restore and restore.component_name
if component and component_name == "NpcAnimation" then
local ok_override = safe_method(component, "_override_animation", unit)
restored = ok_override == true
end
if not restored and restore and restore.state_machine_override then
local unit_api = rawget(_G, "Unit")
local ok_set = safe_call(unit_api and unit_api.set_animation_state_machine, unit, restore.state_machine_override)
if ok_set then
safe_call(unit_api and unit_api.enable_animation_state_machine, unit)
local event_name = restore.state_machine_init_event
if event_name then
local ok_event, has_event = safe_call(unit_api and unit_api.has_animation_event, unit, event_name)
if ok_event and has_event == true then
safe_call(unit_api and unit_api.animation_event, unit, event_name)
end
end
restored = true
end
end
if restored then
mod.swagger_last_animation_event = nil
mod.swagger_animation_restore = nil
return true
end
return false
end
local function initialise_swagger_emote_state_machine(unit)
capture_swagger_animation_restore(unit)
local unit_api = rawget(_G, "Unit")
local ok_set = safe_call(unit_api and unit_api.set_animation_state_machine, unit, SWAGGER_PLAYER_EMOTE_STATE_MACHINE)
if not ok_set then
return false
end
local ok_enable = safe_call(unit_api and unit_api.enable_animation_state_machine, unit)
if not ok_enable then
return false
end
for _, variable_name in ipairs(SWAGGER_ARCHETYPE_VARIABLES) do
local ok_variable, variable_id = safe_call(unit_api and unit_api.animation_find_variable, unit, variable_name)
if ok_variable and variable_id ~= nil then
local value = variable_name == "zealot_active" and 1 or 0
safe_call(unit_api and unit_api.animation_set_variable, unit, variable_id, value)
end
end
for _, event_name in ipairs({
"to_idle",
"idle",
}) do
local ok_event, has_event = safe_call(unit_api and unit_api.has_animation_event, unit, event_name)
if ok_event and has_event == true then
safe_call(unit_api and unit_api.animation_event, unit, event_name)
break
end
end
return true
end
local function play_swagger_animation(action_name)
if not HUB_NAMES[current_game_mode_name()] then
return false
end
local definition = SWAGGER_EMOTE_EVENTS[action_name]
if not definition then
return false
end
local unit = physical_swagger_unit()
if not unit or not initialise_swagger_emote_state_machine(unit) then
return false
end
local unit_api = rawget(_G, "Unit")
local ok_has_event, has_event = safe_call(unit_api and unit_api.has_animation_event, unit, definition.event)
if not ok_has_event or has_event ~= true then
mod:warning("Swagger's replacement state machine rejected %s with animation event %s.", definition.label, definition.event)
return false
end
local triggered = false
local script_unit = rawget(_G, "ScriptUnit")
if script_unit and type(script_unit.has_extension) == "function" then
local ok_extension, animation_extension = safe_call(script_unit.has_extension, unit, "animation_system")
if ok_extension and animation_extension then
local ok_trigger = safe_method(animation_extension, "anim_event", definition.event)
triggered = ok_trigger == true
end
end
if not triggered then
local ok_trigger = safe_call(unit_api and unit_api.animation_event, unit, definition.event)
triggered = ok_trigger == true
end
if triggered then
mod.swagger_last_animation_event = definition.event
return true
end
return false
end
local function main_time()
local managers = rawget(_G, "Managers")
local time_manager = managers and managers.time
local ok, value = safe_method(time_manager, "time", "main")
return ok and finite_number(value) and value or 0
end
local function interaction_pressed()
local managers = rawget(_G, "Managers")
local input_manager = managers and managers.input
if not input_manager then
return false
end
for _, service_name in ipairs({
"Ingame",
"Player",
}) do
local ok_service, service = safe_method(input_manager, "get_input_service", service_name)
if ok_service and service then
for _, action_name in ipairs({
"interact_pressed",
"interact_inspect_pressed",
}) do
local ok_pressed, pressed = safe_method(service, "get", action_name)
if ok_pressed and pressed == true then
return true
end
end
end
end
return false
end
local function appdata_path()
local mods = rawget(_G, "Mods")
local os_library = mods and mods.lua and mods.lua.os
local getenv = os_library and os_library.getenv
if type(getenv) ~= "function" then
local global_os = rawget(_G, "os")
getenv = global_os and global_os.getenv
end
if type(getenv) ~= "function" then
return nil
end
local ok, value = pcall(getenv, "APPDATA")
if not ok or type(value) ~= "string" or value == "" then
return nil
end
return value
end
local function copy_config_backup()
local mods = rawget(_G, "Mods")
local io_library = mods and mods.lua and mods.lua.io
local os_library = mods and mods.lua and mods.lua.os
local global_os = rawget(_G, "os")
local date_function = os_library and os_library.date or global_os and global_os.date
local remove_function = os_library and os_library.remove or global_os and global_os.remove
if not io_library or type(io_library.open) ~= "function" then
return false, "file access is unavailable"
end
if type(date_function) ~= "function" then
return false, "the current date and time could not be determined"
end
local appdata = appdata_path()
if not appdata then
return false, "APPDATA could not be found"
end
local directory = appdata .. "\\Fatshark\\Darktide\\"
local source_path = directory .. "user_settings.config"
local rotation_path = directory .. "swagger-backup-rotation.dat"
local legacy_son_path = directory .. "swagger-backup-son.config"
local legacy_father_path = directory .. "swagger-backup-father.config"
local legacy_grandfather_path = directory .. "swagger-backup-grandfather.config"
local open_files = {}
local function close_file(file)
if not file then
return
end
pcall(function()
file:close()
end)
open_files[file] = nil
end
local function read_file(path, required)
local file = io_library.open(path, "rb")
if not file then
if required then
return nil, path .. " could not be opened"
end
return nil, nil
end
open_files[file] = true
local content = file:read("*a")
close_file(file)
if type(content) ~= "string" then
return nil, path .. " could not be read"
end
return content, nil
end
local function write_file(path, content)
local file = io_library.open(path, "wb")
if not file then
return false, path .. " could not be opened"
end
open_files[file] = true
local write_result = file:write(content)
file:flush()
close_file(file)
if write_result == nil then
return false, path .. " could not be written"
end
return true, nil
end
local function remove_file(path)
if type(remove_function) ~= "function" or type(path) ~= "string" or path == "" then
return
end
pcall(remove_function, path)
end
local function valid_date(value)
return type(value) == "string" and string.match(value, "^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end
local function valid_timestamp(value)
return type(value) == "string" and string.match(value, "^%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d$") ~= nil
end
local function normalise_timestamp(value)
if valid_timestamp(value) then
return value
end
if valid_date(value) then
return value .. "-00-00"
end
return nil
end
local function backup_path(timestamp, generation)
if not valid_timestamp(timestamp) and not valid_date(timestamp) then
return nil
end
return directory .. timestamp .. "-Swagger-Backup-" .. generation .. ".config"
end
local function read_rotation()
local content = read_file(rotation_path, false)
if type(content) ~= "string" then
return nil, nil, nil
end
local son_timestamp = string.match(content, "son=([^\r\n]+)")
local father_timestamp = string.match(content, "father=([^\r\n]+)")
local grandfather_timestamp = string.match(content, "grandfather=([^\r\n]+)")
return valid_timestamp(son_timestamp) and son_timestamp or valid_date(son_timestamp) and son_timestamp or nil,
valid_timestamp(father_timestamp) and father_timestamp or valid_date(father_timestamp) and father_timestamp or nil,
valid_timestamp(grandfather_timestamp) and grandfather_timestamp or valid_date(grandfather_timestamp) and grandfather_timestamp or nil
end
local ok, result, detail = pcall(function()
local source_content, source_error = read_file(source_path, true)
if not source_content then
return false, source_error
end
local ok_timestamp, current_timestamp = pcall(date_function, "%Y-%m-%d-%H-%M")
if not ok_timestamp or not valid_timestamp(current_timestamp) then
return false, "the current date and time could not be determined"
end
local son_timestamp, father_timestamp, grandfather_timestamp = read_rotation()
local old_son_path = backup_path(son_timestamp, "son")
local old_father_path = backup_path(father_timestamp, "father")
local old_grandfather_path = backup_path(grandfather_timestamp, "grandfather")
local son_content, son_error = read_file(old_son_path or legacy_son_path, false)
if son_error then
return false, son_error
end
local father_content, father_error = read_file(old_father_path or legacy_father_path, false)
if father_error then
return false, father_error
end
if not son_timestamp and son_content then
son_timestamp = current_timestamp
elseif son_timestamp then
son_timestamp = normalise_timestamp(son_timestamp)
end
if not father_timestamp and father_content then
father_timestamp = current_timestamp
elseif father_timestamp then
father_timestamp = normalise_timestamp(father_timestamp)
end
local new_son_path = backup_path(current_timestamp, "son")
local new_father_path = son_content and backup_path(son_timestamp, "father") or nil
local new_grandfather_path = father_content and backup_path(father_timestamp, "grandfather") or nil
if new_grandfather_path then
local wrote_grandfather, grandfather_write_error = write_file(new_grandfather_path, father_content)
if not wrote_grandfather then
return false, grandfather_write_error
end
end
if new_father_path then
local wrote_father, father_write_error = write_file(new_father_path, son_content)
if not wrote_father then
return false, father_write_error
end
end
local wrote_son, son_write_error = write_file(new_son_path, source_content)
if not wrote_son then
return false, son_write_error
end
local rotation_content = table.concat({
"son=" .. current_timestamp,
"father=" .. tostring(son_content and son_timestamp or ""),
"grandfather=" .. tostring(father_content and father_timestamp or ""),
}, "\n") .. "\n"
local wrote_rotation, rotation_error = write_file(rotation_path, rotation_content)
if not wrote_rotation then
return false, rotation_error
end
local retained_paths = {
[new_son_path] = true,
}
if new_father_path then
retained_paths[new_father_path] = true
end
if new_grandfather_path then
retained_paths[new_grandfather_path] = true
end
for _, obsolete_path in ipairs({
old_son_path,
old_father_path,
old_grandfather_path,
legacy_son_path,
legacy_father_path,
legacy_grandfather_path,
}) do
if obsolete_path and not retained_paths[obsolete_path] then
remove_file(obsolete_path)
end
end
return true, new_son_path
end)
while next(open_files) do
local file = next(open_files)
close_file(file)
end
if not ok then
return false, tostring(result)
end
return result == true, detail
end
local function swagger_player_distance_squared(unit)
local player_unit = local_player_unit()
local origin = player_unit and player_position(player_unit)
local target = unit and unit_position(unit)
return distance_squared(origin, target)
end
local function swagger_interaction_ready()
if mod.swagger_backup_available ~= true or mod.swagger_backup_stage then
return false
end
if not HUB_NAMES[current_game_mode_name()] then
return false
end
local unit = physical_swagger_unit()
local distance_sq = unit and swagger_player_distance_squared(unit)
return unit ~= nil and distance_sq ~= nil and distance_sq <= SWAGGER_INTERACTION_DISTANCE_SQ
end
mod.swagger_prompt_data = function()
if not swagger_interaction_ready() then
return nil
end
local unit = physical_swagger_unit()
local position = unit and unit_position(unit)
local x, y, z = vector_values(position)
if not x then
return nil
end
local world_position = position
local vector3 = rawget(_G, "Vector3")
if vector3 then
local ok, offset_position = pcall(vector3, x, y, z + 2.05)
if ok and offset_position then
world_position = offset_position
end
end
return {
world_position = world_position,
top_text = mod:localize("swagger_talk"),
bottom_text = mod:localize("swagger_backup_label"),
}
end
mod.swagger_backup_notice = function()
local expiry = mod.swagger_backup_notice_expiry or 0
if expiry > main_time() then
return mod:localize("swagger_backup_done")
end
return nil
end
local function clear_swagger_beckon_state(restore_animation)
if restore_animation and mod.swagger_beckon_active and mod.swagger_animation_restore then
restore_swagger_animation()
end
mod.swagger_beckon_active = nil
end
local function begin_config_backup()
if not swagger_interaction_ready() then
return
end
clear_swagger_beckon_state(false)
mod.swagger_beckon_approach_handled = true
mod.swagger_post_backup_active = nil
mod.swagger_backup_available = false
mod.swagger_backup_stage = "saving"
mod.swagger_backup_execute_at = main_time() + BACKUP_SAVE_DELAY
play_swagger_animation("hunker")
play_swagger_work_line()
local application = rawget(_G, "Application")
if application and type(application.save_user_settings) == "function" then
safe_call(application.save_user_settings)
end
end
local function complete_config_backup(t)
local success, detail = copy_config_backup()
mod.swagger_backup_stage = nil
mod.swagger_backup_execute_at = nil
if success then
local nodded = play_swagger_animation("nod")
if nodded then
mod.swagger_post_backup_active = true
else
restore_swagger_animation()
mod.swagger_post_backup_active = nil
end
mod.swagger_backup_notice_expiry = t + BACKUP_NOTICE_DURATION
mod:info("Created Swagger backup at %s.", tostring(detail))
else
restore_swagger_animation()
mod.swagger_post_backup_active = nil
mod:error("Swagger could not back up user_settings.config: %s", tostring(detail))
end
end
local function update_swagger_beckon()
if mod.swagger_backup_available ~= true or mod.swagger_backup_stage or mod.swagger_post_backup_active then
clear_swagger_beckon_state(false)
return
end
local unit = physical_swagger_unit()
local distance_sq = unit and swagger_player_distance_squared(unit)
if not unit or not distance_sq then
return
end
local looking = player_is_looking_at_swagger(unit)
if mod.swagger_beckon_active and distance_sq > SWAGGER_RESET_DISTANCE_SQ and not looking then
clear_swagger_beckon_state(true)
mod.swagger_beckon_approach_handled = false
return
end
if distance_sq <= SWAGGER_BECKON_DISTANCE_SQ and not mod.swagger_beckon_approach_handled then
local beckoned = play_swagger_animation("beckon")
mod.swagger_beckon_approach_handled = true
if beckoned then
mod.swagger_beckon_active = true
end
end
end
local function update_swagger_post_backup()
if not mod.swagger_post_backup_active then
return
end
local unit = physical_swagger_unit()
local distance_sq = unit and swagger_player_distance_squared(unit)
if not unit or not distance_sq then
return
end
if distance_sq > SWAGGER_RESET_DISTANCE_SQ and not player_is_looking_at_swagger(unit) then
restore_swagger_animation()
mod.swagger_post_backup_active = nil
end
end
mod.update = function(dt, t)
local in_hub = HUB_NAMES[current_game_mode_name()] == true
if in_hub and not mod.swagger_was_in_hub then
mod.swagger_backup_available = true
mod.swagger_backup_stage = nil
mod.swagger_backup_execute_at = nil
mod.swagger_backup_notice_expiry = nil
mod.swagger_beckon_active = nil
mod.swagger_beckon_approach_handled = false
mod.swagger_post_backup_active = nil
elseif not in_hub and mod.swagger_was_in_hub then
if mod.swagger_animation_restore then
restore_swagger_animation()
end
mod.swagger_backup_available = false
mod.swagger_backup_stage = nil
mod.swagger_backup_execute_at = nil
mod.swagger_backup_notice_expiry = nil
mod.swagger_beckon_active = nil
mod.swagger_beckon_approach_handled = false
mod.swagger_post_backup_active = nil
mod.swagger_cached_unit = nil
mod.swagger_work_line = nil
mod.swagger_work_line_missing_logged = nil
end
mod.swagger_was_in_hub = in_hub
if not in_hub then
return
end
local now = finite_number(t) and t or main_time()
if mod.swagger_backup_stage == "saving" and now >= (mod.swagger_backup_execute_at or math.huge) then
complete_config_backup(now)
end
update_swagger_post_backup()
update_swagger_beckon()
if swagger_interaction_ready() and interaction_pressed() then
begin_config_backup()
end
end
mod.on_disabled = function()
if mod.swagger_animation_restore then
restore_swagger_animation()
end
mod.swagger_cached_unit = nil
mod.swagger_work_line = nil
mod.swagger_work_line_missing_logged = nil
mod.swagger_backup_available = false
mod.swagger_backup_stage = nil
mod.swagger_backup_execute_at = nil
mod.swagger_backup_notice_expiry = nil
mod.swagger_beckon_active = nil
mod.swagger_beckon_approach_handled = false
mod.swagger_post_backup_active = nil
end
mod:register_hud_element({
class_name = "SwaggerBackupHud",
filename = "swagger/scripts/mods/swagger/swagger_hud",
visibility_groups = {
"alive",
},
use_hud_scale = true,
})