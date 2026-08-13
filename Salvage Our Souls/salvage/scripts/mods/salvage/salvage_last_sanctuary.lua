-- salvage_last_sanctuary.lua
local mod = get_mod("salvage")
local last_sanctuary = {}
local WARNING_EVENT = "salvage_show_early_evacuation_warning"
local CLEAR_EVENT = "salvage_clear_early_evacuation_warning"
local WARNING_ID = "last_sanctuary"
local WARNING_DURATION = 2.4
local WARNING_DELAY = 10
local POLL_INTERVAL = 0.2
local last_poll_t = -999
local runtime_key = nil
local latch_key = nil
local pending_warning_key = nil
local pending_warning_at = nil
local hooks_registered = false
last_sanctuary.warning_id = WARNING_ID
local function safe_call(object, method_name, ...)
if not object then
return nil
end
local method = object[method_name]
if type(method) ~= "function" then
return nil
end
local ok, value = pcall(method, object, ...)
if ok then
return value
end
return nil
end
local function safe_game_mode_manager()
return Managers and Managers.state and Managers.state.game_mode or nil
end
local function safe_game_mode_name()
return safe_call(safe_game_mode_manager(), "game_mode_name")
end
local function safe_game_mode()
return safe_call(safe_game_mode_manager(), "game_mode")
end
local function is_hub_context()
local name = safe_game_mode_name()
if type(name) ~= "string" then
return false
end
return name == "hub" or name == "hub_singleplay" or name == "prologue_hub" or string.find(name, "hub", 1, true) ~= nil
end
local function has_expedition_shape(game_mode)
if not game_mode then
return false
end
return type(game_mode.current_location_index) == "function" or type(game_mode.in_safe_zone) == "function" or type(game_mode.get_expedition_template) == "function" or type(game_mode.expedition_loot) == "function" or type(game_mode.expedition_team_loot) == "function"
end
local function is_expedition_context()
if is_hub_context() then
return false
end
local name = safe_game_mode_name()
if name == "expedition" then
return true
end
return has_expedition_shape(safe_game_mode())
end
local function expedition_game_mode()
if not is_expedition_context() then
return nil
end
return safe_game_mode()
end
local function expedition_logic(game_mode)
if type(game_mode) ~= "table" then
return nil
end
return rawget(game_mode, "_game_mode_logic")
end
local function expedition_layout(game_mode)
local logic = expedition_logic(game_mode)
if type(logic) ~= "table" then
return nil
end
local expedition = rawget(logic, "_expedition")
if type(expedition) == "table" then
return expedition
end
return nil
end
local function current_location_index(game_mode)
local value = safe_call(game_mode, "current_location_index")
local number = tonumber(value)
if number and number > 0 then
return number
end
local logic = expedition_logic(game_mode)
number = tonumber(logic and rawget(logic, "_current_section_index") or nil)
if number and number > 0 then
return number
end
return nil
end
local function current_safe_zone_index(game_mode)
local logic = expedition_logic(game_mode)
local number = tonumber(logic and rawget(logic, "_current_safe_zone_section_index") or nil)
if number and number > 0 then
return number
end
return current_location_index(game_mode)
end
local function final_location_index(game_mode)
local expedition = expedition_layout(game_mode)
if expedition and #expedition > 0 then
return #expedition
end
local template = safe_call(game_mode, "get_expedition_template")
local default_amount = template and tonumber(template.default_session_location_amount)
if default_amount and default_amount > 0 then
return default_amount
end
return nil
end
local function in_safe_zone(game_mode)
local value = safe_call(game_mode, "in_safe_zone")
return value == true
end
local function main_time()
local time_manager = Managers and Managers.time or nil
if time_manager and type(time_manager.time) == "function" then
local ok, value = pcall(time_manager.time, time_manager, "main")
if ok and type(value) == "number" then
return value
end
end
return 0
end
local function option_enabled()
return mod:get("last_sanctuary_warning") == true
end
local function clear_pending_warning()
pending_warning_key = nil
pending_warning_at = nil
end
local function clear_warning()
clear_pending_warning()
if Managers and Managers.event then
Managers.event:trigger(CLEAR_EVENT, WARNING_ID)
end
end
local function show_warning()
if Managers and Managers.event then
Managers.event:trigger(WARNING_EVENT, WARNING_ID, WARNING_DURATION)
end
end
local function target_sanctuary_index(final_index)
if type(final_index) ~= "number" or final_index < 3 then
return nil
end
return final_index - 1
end
local function state_key(game_mode)
local safe = in_safe_zone(game_mode)
local current = safe and current_safe_zone_index(game_mode) or current_location_index(game_mode)
local final = final_location_index(game_mode)
return tostring(current or "?") .. ":" .. tostring(final or "?") .. ":" .. tostring(safe), current, final, safe
end
local function reset_latch_if_runtime_changed(new_key)
if new_key ~= runtime_key then
runtime_key = new_key
if not new_key or string.find(new_key, "true", 1, true) == nil then
return
end
end
end
local function should_warn(game_mode)
local key, current, final, safe = state_key(game_mode)
reset_latch_if_runtime_changed(key)
if safe ~= true then
return false, key, current, final, safe
end
local target = target_sanctuary_index(final)
if not target or not current then
return false, key, current, final, safe
end
return current == target, key, current, final, safe
end
function last_sanctuary.reset(in_expedition, clear_runtime)
if in_expedition == false then
latch_key = nil
end
if clear_runtime ~= false then
runtime_key = nil
clear_pending_warning()
end
last_poll_t = -999
end
function last_sanctuary.update(t, force)
local now = type(t) == "number" and t or main_time()
if not force and now - last_poll_t < POLL_INTERVAL then
return false
end
last_poll_t = now
if not option_enabled() then
clear_warning()
return false
end
local game_mode = expedition_game_mode()
if not game_mode then
last_sanctuary.reset(false, true)
return false
end
local should, key, current, final = should_warn(game_mode)
if not should then
clear_pending_warning()
return false
end
local warning_key = tostring(current) .. ":" .. tostring(final)
if latch_key == warning_key then
return false
end
if pending_warning_key ~= warning_key then
pending_warning_key = warning_key
pending_warning_at = now + WARNING_DELAY
return false
end
if type(pending_warning_at) == "number" and now >= pending_warning_at then
latch_key = warning_key
clear_pending_warning()
show_warning()
return true
end
return false
end
function last_sanctuary.on_setting_changed(setting_id)
if setting_id == "last_sanctuary_warning" then
if mod:get("last_sanctuary_warning") ~= true then
clear_warning()
else
last_sanctuary.update(main_time(), true)
end
end
end
function last_sanctuary.on_game_state_changed(status)
if status == "exit" then
clear_warning()
last_sanctuary.reset(false, true)
end
end
function last_sanctuary.on_unload()
clear_warning()
last_sanctuary.reset(false, true)
end
function last_sanctuary.on_disabled()
last_sanctuary.on_unload()
end
local function safe_hook(class_table, method_name, callback)
if not class_table or type(class_table[method_name]) ~= "function" or type(mod.hook_safe) ~= "function" then
return
end
pcall(function()
mod:hook_safe(class_table, method_name, callback)
end)
end
function last_sanctuary.register_hooks()
if hooks_registered or not CLASS then
return
end
local any_hook_target = false
if CLASS.GameModeExpedition then
any_hook_target = true
safe_hook(CLASS.GameModeExpedition, "on_gameplay_post_init", function()
last_sanctuary.reset(nil, true)
last_sanctuary.update(main_time(), true)
end)
safe_hook(CLASS.GameModeExpedition, "client_update", function(_, dt, t)
last_sanctuary.update(t, false)
end)
safe_hook(CLASS.GameModeExpedition, "server_update", function(_, dt, t)
last_sanctuary.update(t, false)
end)
safe_hook(CLASS.GameModeExpedition, "mission_cleanup", function()
last_sanctuary.reset(false, true)
end)
safe_hook(CLASS.GameModeExpedition, "destroy", function()
last_sanctuary.reset(false, true)
end)
safe_hook(CLASS.GameModeExpedition, "complete", function()
last_sanctuary.reset(nil, false)
end)
safe_hook(CLASS.GameModeExpedition, "fail", function()
last_sanctuary.reset(nil, false)
end)
end
local function hook_expedition_logic(class_table)
if not class_table then
return false
end
safe_hook(class_table, "rpc_expedition_on_gameplay_pause", function()
last_sanctuary.update(main_time(), true)
end)
safe_hook(class_table, "_on_gameplay_paused", function()
last_sanctuary.update(main_time(), true)
end)
safe_hook(class_table, "rpc_expedition_on_gameplay_resume", function()
last_sanctuary.update(main_time(), true)
end)
safe_hook(class_table, "_on_gameplay_resume", function()
last_sanctuary.update(main_time(), true)
end)
return true
end
if hook_expedition_logic(CLASS.ExpeditionLogicBase) then
any_hook_target = true
end
if hook_expedition_logic(CLASS.ExpeditionLogicServer) then
any_hook_target = true
end
if hook_expedition_logic(CLASS.ExpeditionLogicClient) then
any_hook_target = true
end
if CLASS.StateGameplay then
any_hook_target = true
safe_hook(CLASS.StateGameplay, "on_enter", function()
last_sanctuary.reset(nil, true)
end)
safe_hook(CLASS.StateGameplay, "on_exit", function()
last_sanctuary.on_unload()
end)
end
if any_hook_target then
hooks_registered = true
end
end
function last_sanctuary.on_all_mods_loaded()
last_sanctuary.register_hooks()
last_sanctuary.update(main_time(), true)
end
last_sanctuary.register_hooks()
return last_sanctuary
