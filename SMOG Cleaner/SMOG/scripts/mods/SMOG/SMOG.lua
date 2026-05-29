-- SMOG.lua
local mod = get_mod("SMOG")
local check_interval = 1
local interval_clean_time = 600
local accumulator = 0
local interval_accumulator = 0
local current_warn_level = 0
local pending_start_clean = false
local pending_start_clean_delay = 0

mod.auto_clean_on_start = mod:get("auto_clean_on_start")
mod.auto_clean_every_ten_minutes = mod:get("auto_clean_every_ten_minutes")
mod.silent_running = mod:get("silent_running")

local function memory_usage_mb()
local used_kb = collectgarbage("count") or 0
return used_kb / 1024
end

local function fmt_mb(value)
return string.format("%.2f",value)
end

local function fmt_delta(value)
local sign = value >= 0 and "-" or "+"
return sign .. fmt_mb(math.abs(value))
end

local function heap_size_mb()
local size = 1024
if Application and Application.argv then
local ok,args = pcall(function()
return {Application.argv()}
end)
if ok and args then
for i = 1,#args do
local arg = tostring(args[i])
local inline_size = arg:match("^%-%-lua%-heap%-mb%-size=(%d+)$")
if inline_size then
size = tonumber(inline_size) or size
elseif arg == "--lua-heap-mb-size" and tonumber(args[i + 1]) then
size = tonumber(args[i + 1])
end
end
end
end
return size
end

local detected_heap_mb = heap_size_mb()
local function round_mb(value)
return math.floor(value + 0.5)
end

local warn_levels = {round_mb(detected_heap_mb * 0.7),round_mb(detected_heap_mb * 0.8),round_mb(detected_heap_mb * 0.9)}
local warn_percentages = {70,80,90}

local function colour_text(text,colour)
return "{#color(" .. colour .. ")}" .. text .. "{#reset()}"
end

local function green_text(text)
return "{#color(110,255,110)}" .. text .. "{#reset()}"
end

local function safe_echo(text)
mod:echo("%s",text)
end

local function echo_warning(message,colour,detail)
safe_echo(colour_text(message,colour))
if detail then
safe_echo(detail)
end
end

local function echo_heap_size()
safe_echo("Lua heap size: " .. string.format("%.0f",detected_heap_mb) .. " MB")
end

local function echo_cleaned(before_mb,after_mb,freed_mb)
local message = "Cleared " .. fmt_mb(before_mb) .. " MB > " .. fmt_mb(after_mb) .. " MB (" .. green_text(fmt_delta(freed_mb)) .. " MB)"
safe_echo(message)
end

local function perform_collect(output,include_heap_size)
local before_mb = memory_usage_mb()
collectgarbage("collect")
local after_mb = memory_usage_mb()
local freed_mb = before_mb - after_mb
if output then
if include_heap_size then
echo_heap_size()
end
echo_cleaned(before_mb,after_mb,freed_mb)
end
return before_mb,after_mb,freed_mb
end

local function in_hub()
local connection = Managers and Managers.connection
if connection and connection.host_type then
local ok,host_type = pcall(function()
return connection:host_type()
end)
if ok and host_type == "hub_server" then
return true
end
end
local game_mode_manager = Managers and Managers.state and Managers.state.game_mode
if not game_mode_manager then
return nil
end
if game_mode_manager.is_social_hub then
local ok,is_social_hub = pcall(function()
return game_mode_manager:is_social_hub()
end)
if ok and is_social_hub then
return true
end
end
if game_mode_manager.is_prologue_hub then
local ok,is_prologue_hub = pcall(function()
return game_mode_manager:is_prologue_hub()
end)
if ok and is_prologue_hub then
return true
end
end
if game_mode_manager.game_mode_name then
local ok,game_mode_name = pcall(function()
return game_mode_manager:game_mode_name()
end)
if ok and (game_mode_name == "hub" or game_mode_name == "prologue_hub") then
return true
end
if ok and game_mode_name then
return false
end
end
return nil
end

mod:command("clear",mod:localize("command_clear_desc"),function()
perform_collect(true,true)
end)

mod:command("smog",mod:localize("command_clear_desc"),function()
perform_collect(true,true)
end)

mod:command("clean",mod:localize("command_clear_desc"),function()
perform_collect(true,true)
end)

mod.on_setting_changed = function(changed_setting)
if changed_setting == "auto_clean_on_start" then
mod.auto_clean_on_start = mod:get("auto_clean_on_start")
elseif changed_setting == "auto_clean_every_ten_minutes" then
mod.auto_clean_every_ten_minutes = mod:get("auto_clean_every_ten_minutes")
interval_accumulator = 0
elseif changed_setting == "silent_running" then
mod.silent_running = mod:get("silent_running")
end
end

mod.on_game_state_changed = function(status,state_name)
if mod.auto_clean_on_start and status == "enter" and state_name == "StateGameplay" then
pending_start_clean = true
pending_start_clean_delay = 1
end
end

mod.update = function(dt)
if pending_start_clean then
pending_start_clean_delay = pending_start_clean_delay - dt
if pending_start_clean_delay <= 0 then
local is_hub = in_hub()
if is_hub == nil then
pending_start_clean_delay = 1
elseif is_hub then
pending_start_clean = false
else
pending_start_clean = false
perform_collect(not mod.silent_running,false)
end
end
end
if mod.auto_clean_every_ten_minutes then
interval_accumulator = interval_accumulator + dt
if interval_accumulator >= interval_clean_time then
interval_accumulator = 0
perform_collect(not mod.silent_running,false)
end
else
interval_accumulator = 0
end
accumulator = accumulator + dt
if accumulator < check_interval then
return
end
accumulator = 0
local usage = memory_usage_mb()
local new_level = 0
for level_index,threshold in ipairs(warn_levels) do
if usage >= threshold then
new_level = level_index
end
end
if new_level > current_warn_level then
current_warn_level = new_level
if not mod.silent_running then
if new_level == 1 then
echo_warning("Lua warning: " .. tostring(warn_percentages[new_level]) .. "%","255,220,0",colour_text("Type ","255,220,0") .. green_text("/clear") .. colour_text(" to clear Lua heap now","255,220,0"))
elseif new_level == 2 then
echo_warning("Lua high: " .. tostring(warn_percentages[new_level]) .. "%","255,150,0",colour_text("Type ","255,150,0") .. green_text("/clear") .. colour_text(" to clear Lua heap now","255,150,0"))
elseif new_level == 3 then
echo_warning("Lua critical: " .. tostring(warn_percentages[new_level]) .. "%","255,0,0",colour_text("Executing ","255,0,0") .. green_text("/clear") .. colour_text(" now...","255,0,0"))
end
end
if new_level == #warn_levels then
perform_collect(not mod.silent_running,true)
end
elseif new_level < current_warn_level then
current_warn_level = new_level
end
end

mod.perform_collect = perform_collect
