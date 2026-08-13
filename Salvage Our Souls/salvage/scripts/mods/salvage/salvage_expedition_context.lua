-- salvage_expedition_context.lua
local mod = get_mod("salvage")
local context = {}
local function clear_table(target)
if type(target) ~= "table" then
return
end
if table.clear then
table.clear(target)
return
end
for key, _ in pairs(target) do
target[key] = nil
end
end
local function safe_call(object, method_name)
local method = object and object[method_name]
if type(method) ~= "function" then
return nil
end
local success, result = pcall(method, object)
if success then
return result
end
return nil
end
local function game_mode_manager()
return Managers and Managers.state and Managers.state.game_mode
end
local function mechanism_data()
local mechanism = Managers and Managers.mechanism and Managers.mechanism._mechanism
return mechanism and mechanism._mechanism_data or nil
end
local function mechanism_is_expedition()
local data = mechanism_data()
return data and (data.expedition_template_name ~= nil or data.node_id ~= nil) or false
end
local function is_expedition()
local manager = game_mode_manager()
if manager then
local name = safe_call(manager, "game_mode_name")
if name == "expedition" then
return true
end
if name ~= nil then
return false
end
local game_mode = safe_call(manager, "game_mode")
local game_mode_name = safe_call(game_mode, "name")
if game_mode_name == "expedition" then
return true
end
if game_mode_name ~= nil then
return false
end
end
return mechanism_is_expedition()
end
local function in_safe_zone()
local manager = game_mode_manager()
local game_mode = manager and safe_call(manager, "game_mode")
local game_mode_safe_zone = safe_call(game_mode, "in_safe_zone")
if game_mode_safe_zone ~= nil then
return game_mode_safe_zone == true
end
local pacing = Managers and Managers.state and Managers.state.pacing
local pacing_safe_zone = safe_call(pacing, "get_in_safe_zone")
return pacing_safe_zone == true
end
local function should_run()
if mod.is_enabled and not mod:is_enabled() then
return false
end
return is_expedition() and not in_safe_zone()
end
local function is_alive_unit(unit)
return type(unit) == "userdata" and Unit and Unit.alive and Unit.alive(unit)
end
local function is_valid_unit(unit)
if type(unit) ~= "userdata" or not Unit then
return false
end
if Unit.is_valid then
local success, valid = pcall(Unit.is_valid, unit)
if success then
return valid == true
end
end
return Unit.alive and Unit.alive(unit) or false
end
return { clear_table = clear_table, safe_call = safe_call, game_mode_manager = game_mode_manager, mechanism_data = mechanism_data, mechanism_is_expedition = mechanism_is_expedition, is_expedition = is_expedition, in_safe_zone = in_safe_zone, should_run = should_run, is_alive_unit = is_alive_unit, is_valid_unit = is_valid_unit }
