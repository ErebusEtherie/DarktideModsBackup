-- SMOG.lua
local mod = get_mod("SMOG")
local Managers = Managers
local Application = Application
local collectgarbage = collectgarbage
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_format = string.format
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local type = type
local os_clock = os and os.clock
local dmf = get_mod("DMF")
local check_interval = 1
local heap_sample_interval = 0.5
local context_refresh_interval = 0.2
local transient_frame_spike_multiplier = 1.5
local interval_clean_time = 600
local manual_clear_cooldown = 3
local convenient_collect_cooldown_seconds = 5
local gentle_step_kb = 16
local gentle_max_steps = 8
local gentle_budget_seconds = 0.0005
local over_eighty_pause = 80
local over_eighty_stepmul = 500
local over_eighty_boost_pause = 65
local over_eighty_boost_stepmul = 700
local saved_gc_pause = nil
local saved_gc_stepmul = nil
local staged_step_kb = 32
local staged_max_steps = 16
local staged_budget_seconds = 0.001
local over_eighty_delay_seconds = 5
local over_eighty_boost_delay_seconds = 25
local mourningstar_clean_delay_seconds = 180
local gameplay_exit_clean_delay_seconds = 2
local warning_return_delay_seconds = 2
local growth_window_seconds = 30
local auto_notification_seconds = 5
local manual_notification_seconds = 6
local notification_fade_seconds = 1
local live_memory_warning_percent = 80
local target_frame_seconds = 1 / 60
local minimum_gc_frame_scale = 0.25
local maximum_gc_frame_scale = 1.5
local elapsed_time = 0
local smoothed_frame_time = target_frame_seconds
local incremental_gc_frame_blocked = false
local accumulator = 0
local heap_sample_accumulator = heap_sample_interval
local context_refresh_accumulator = context_refresh_interval
local idle_context_accumulator = 0
local context_refresh_requested = false
local immediate_context_blocked = false
local interval_accumulator = 0
local growth_accumulator = 0
local scheduled_delays = {}
local scheduled_reasons = {}
local due_reasons = {}
local scheduled_count = 0
local next_manual_clear_t = 0
local pressure_state = "normal"
local pressure_wait_started_t = nil
local pressure_boost_elapsed = 0
local gc_tuning_active = false
local gc_tuning_profile = nil
local last_convenient_collect_t = nil
local last_post_collect_mb = nil
local last_collect_low_yield = false
local routine_collect_suppressed = false
local gameplay_exit_clean_pending = false
local gameplay_exit_clean_delay = nil
local gameplay_exit_wait_for_debrief = false
local gameplay_exit_debrief_seen = false
local gameplay_exit_debrief_complete = false
local high_threshold_cycle_active = false
local warning_acknowledged = false
local ninety_collect_done = false
local ninetyfive_collect_done = false
local pending_warning_return_delay = nil
local previous_game_mode_name = nil
local previous_safe_zone_state = nil
local mourningstar_visit_state = "unseen"
local notification_text = nil
local notification_tail = nil
local notification_green_text = false
local notification_good = true
local notification_expiry = 0
local notification_manual = false
local threshold_notification_text = nil
local threshold_notification_red_text = false
local notification_queue = {}
local notification_queue_limit = 3
local first_update_done = false
local last_persisted_heap_state = nil
local context_snapshot = {
hud_allowed = false,
collection_allowed = true,
exit_cinematic_active = false,
debrief_active = false,
}
local refresh_context_snapshot
local collection_context_was_blocked = false
mod.cleaning_permitted = mod:get("cleaning_permitted") ~= false
mod.convenient_moment_cleans = mod:get("auto_clean_on_start")
mod.auto_clean_every_ten_minutes = mod:get("auto_clean_every_ten_minutes")
mod.automatic_notifications = mod:get("notifications") ~= false
mod._smog_hud_visible = mod._smog_hud_visible == true
local advanced = {
process_sample_interval = 2,
growth_sample_interval = 30,
game_growth_threshold_mb_per_min = 256,
}
function advanced.read_hud_format()
local format = mod:get("hud_format")
if format == "digital" or format == "advanced_digital" then
return format
end
return "analogue"
end
mod._smog_hud_format = advanced.read_hud_format()
mod._smog_notification_active = false
mod._smog_hud_x_axis = tonumber(mod:get("hud_x_axis")) or 10
mod._smog_hud_y_axis = tonumber(mod:get("hud_y_axis")) or 30
mod._smog_notification_y_axis = tonumber(mod:get("notification_y_axis")) or 85
local function read_memory_usage_mb()
local used_kb = collectgarbage("count") or 0
return used_kb / 1024
end
local function fmt_mb(value)
return string_format("%.2f",value or 0)
end
local function fmt_delta(value)
local sign = value >= 0 and "-" or "+"
return sign .. fmt_mb(math_abs(value or 0))
end
local function current_time()
return elapsed_time
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
local threshold_thirtyfive_mb = detected_heap_mb * 0.35
local threshold_sixtyeight_mb = detected_heap_mb * 0.68
local threshold_seventy_mb = detected_heap_mb * 0.7
local threshold_seventyeight_mb = detected_heap_mb * 0.78
local threshold_eighty_mb = detected_heap_mb * 0.8
local threshold_eightyfive_mb = detected_heap_mb * 0.85
local threshold_ninety_mb = detected_heap_mb * 0.9
local threshold_ninetyfive_mb = detected_heap_mb * 0.95
local low_collection_yield_mb = math_max(detected_heap_mb * 0.01,8)
local rising_post_collect_mb = math_max(detected_heap_mb * 0.005,4)
local current_heap_mb = read_memory_usage_mb()
local current_heap_percent = detected_heap_mb > 0 and current_heap_mb / detected_heap_mb * 100 or 0
local heap_sample_revision = 1
local growth_sample_mb = current_heap_mb
advanced.process_accumulator = advanced.process_sample_interval
advanced.growth_accumulator = 0
advanced.growth_elapsed = 0
advanced.growth_lua_mb = current_heap_mb
advanced.growth_process_mb = nil
advanced.state = {
revision = 1,
process_mb = 0,
process_peak_mb = 0,
process_growth_mb_per_min = 0,
lua_growth_mb_per_min = 0,
lua_peak_mb = current_heap_mb,
lua_share_percent = 0,
pressure = "NORMAL",
}
mod._smog_advanced_hud_state = advanced.state
function advanced.read_process_memory_mb()
if not Memory or not Memory.usage then
return nil
end
local ok,usage = pcall(Memory.usage,"B")
if not ok or type(usage) ~= "table" then
return nil
end
local used_bytes = tonumber(usage.used_memory)
if not used_bytes or used_bytes < 0 then
return nil
end
return used_bytes / 1048576
end
function advanced.update_pressure()
local state = advanced.state
local lua_pressure = pressure_state ~= "normal" or current_heap_percent >= 70
local lua_positive_growth = math_max(state.lua_growth_mb_per_min or 0,0)
local non_lua_growth = (state.process_growth_mb_per_min or 0) - lua_positive_growth
local game_pressure = non_lua_growth >= advanced.game_growth_threshold_mb_per_min
local pressure = "NORMAL"
if lua_pressure and game_pressure then
pressure = "MIXED"
elseif lua_pressure then
pressure = "LUA"
elseif game_pressure then
pressure = "GAME"
end
if state.pressure ~= pressure then
state.pressure = pressure
state.revision = state.revision + 1
mod:set("_smog_last_pressure",pressure)
if dmf and dmf.save_unsaved_settings_to_file then
pcall(dmf.save_unsaved_settings_to_file)
end
end
end
function advanced.update(dt)
if mod._smog_hud_format ~= "advanced_digital" then
return
end
advanced.process_accumulator = advanced.process_accumulator + (dt or 0)
advanced.growth_accumulator = advanced.growth_accumulator + (dt or 0)
advanced.growth_elapsed = advanced.growth_elapsed + (dt or 0)
local process_sampled = false
if advanced.process_accumulator >= advanced.process_sample_interval then
advanced.process_accumulator = advanced.process_accumulator - advanced.process_sample_interval
local process_mb = advanced.read_process_memory_mb()
if process_mb then
process_sampled = true
local state = advanced.state
state.process_mb = process_mb
if process_mb > state.process_peak_mb then
state.process_peak_mb = process_mb
end
if advanced.growth_process_mb == nil then
advanced.growth_process_mb = process_mb
advanced.growth_lua_mb = current_heap_mb
advanced.growth_elapsed = 0
end
if process_mb > 0 then
state.lua_share_percent = current_heap_mb / process_mb * 100
else
state.lua_share_percent = 0
end
state.revision = state.revision + 1
end
end
if advanced.growth_accumulator >= advanced.growth_sample_interval and advanced.growth_process_mb ~= nil and advanced.growth_elapsed > 0 then
advanced.growth_accumulator = advanced.growth_accumulator - advanced.growth_sample_interval
local state = advanced.state
local elapsed = advanced.growth_elapsed
local process_mb = state.process_mb
state.lua_growth_mb_per_min = (current_heap_mb - advanced.growth_lua_mb) * 60 / elapsed
state.process_growth_mb_per_min = (process_mb - advanced.growth_process_mb) * 60 / elapsed
advanced.growth_lua_mb = current_heap_mb
advanced.growth_process_mb = process_mb
advanced.growth_elapsed = 0
state.revision = state.revision + 1
end
if process_sampled then
advanced.update_pressure()
end
end
function advanced.reset_growth()
advanced.process_accumulator = advanced.process_sample_interval
advanced.growth_accumulator = 0
advanced.growth_elapsed = 0
advanced.growth_process_mb = nil
advanced.growth_lua_mb = current_heap_mb
local state = advanced.state
state.process_growth_mb_per_min = 0
state.lua_growth_mb_per_min = 0
state.pressure = (pressure_state ~= "normal" or current_heap_percent >= 70) and "LUA" or "NORMAL"
state.revision = state.revision + 1
mod:set("_smog_last_pressure",state.pressure)
if dmf and dmf.save_unsaved_settings_to_file then
pcall(dmf.save_unsaved_settings_to_file)
end
end
local function usage_percent(usage_mb)
if detected_heap_mb <= 0 then
return 0
end
return (usage_mb or current_heap_mb) / detected_heap_mb * 100
end
local function set_heap_sample(sample_mb)
current_heap_mb = sample_mb
current_heap_percent = usage_percent(sample_mb)
heap_sample_revision = heap_sample_revision + 1
mod._smog_hud_sample_mb = current_heap_mb
mod._smog_hud_sample_percent = current_heap_percent
mod._smog_hud_sample_revision = heap_sample_revision
local state = advanced.state
if sample_mb > state.lua_peak_mb then
state.lua_peak_mb = sample_mb
state.revision = state.revision + 1
end
if state.process_mb > 0 then
state.lua_share_percent = sample_mb / state.process_mb * 100
end
return current_heap_mb
end
local function refresh_heap_sample()
return set_heap_sample(read_memory_usage_mb())
end
mod._smog_hud_sample_mb = current_heap_mb
mod._smog_hud_sample_percent = current_heap_percent
mod._smog_hud_sample_revision = heap_sample_revision
local function save_settings_now()
if dmf and dmf.save_unsaved_settings_to_file then
pcall(dmf.save_unsaved_settings_to_file)
end
end
local function heap_state(percent)
return (percent or usage_percent()) >= live_memory_warning_percent and live_memory_warning_percent or 0
end
local function persist_heap_state(percent)
local state = heap_state(percent)
if last_persisted_heap_state ~= state then
last_persisted_heap_state = state
mod:set("_smog_last_heap_percent",state)
save_settings_now()
end
if mod._smog_hud_format ~= "advanced_digital" then
local pressure = (pressure_state ~= "normal" or (percent or usage_percent()) >= 70) and "LUA" or "NORMAL"
if mod:get("_smog_last_pressure") ~= pressure then
mod:set("_smog_last_pressure",pressure)
save_settings_now()
end
end
end
local function mark_unclean_start()
local previous_clean = mod:get("_smog_clean_shutdown")
local previous_percent = tonumber(mod:get("_smog_last_heap_percent")) or 0
local previous_pressure = tostring(mod:get("_smog_last_pressure") or "")
if previous_clean == false then
if previous_pressure == "LUA" then
mod:echo(mod:localize("unclean_shutdown_lua"))
elseif previous_pressure == "GAME" then
mod:echo(mod:localize("unclean_shutdown_game"))
elseif previous_pressure == "MIXED" then
mod:echo(mod:localize("unclean_shutdown_mixed"))
elseif previous_pressure == "NORMAL" then
mod:echo(mod:localize("unclean_shutdown"))
elseif previous_percent >= live_memory_warning_percent then
mod:echo(mod:localize("unclean_shutdown_lua"))
else
mod:echo(mod:localize("unclean_shutdown"))
end
end
local state = heap_state(usage_percent(refresh_heap_sample()))
last_persisted_heap_state = state
mod:set("_smog_clean_shutdown",false)
mod:set("_smog_last_heap_percent",state)
mod:set("_smog_last_pressure",current_heap_percent >= 70 and "LUA" or "NORMAL")
save_settings_now()
end
mark_unclean_start()
local function update_notification_active()
mod._smog_notification_active = threshold_notification_text ~= nil or notification_text ~= nil or #notification_queue > 0
end
local function clear_notification()
notification_text = nil
notification_tail = nil
notification_green_text = false
notification_expiry = 0
notification_manual = false
update_notification_active()
end
local function clear_queued_notifications()
for i = #notification_queue,1,-1 do
notification_queue[i] = nil
end
update_notification_active()
end
local function clear_threshold_notification()
threshold_notification_text = nil
threshold_notification_red_text = false
update_notification_active()
end
local function set_threshold_notification(text,red_text)
clear_notification()
clear_queued_notifications()
threshold_notification_text = text
threshold_notification_red_text = red_text == true
update_notification_active()
end
local function clear_all_notifications()
clear_notification()
clear_queued_notifications()
clear_threshold_notification()
end
local function queue_notification(text,good,duration,tail,green_text)
local queue_count = #notification_queue
if queue_count >= notification_queue_limit then
return
end
notification_queue[queue_count + 1] = {
text = text,
tail = tail,
green_text = green_text == true,
good = good ~= false,
duration = duration or auto_notification_seconds,
}
update_notification_active()
end
local function pop_notification(now)
local queue_count = #notification_queue
if queue_count <= 0 then
clear_notification()
return false
end
local queued = notification_queue[1]
for i = 1,queue_count - 1 do
notification_queue[i] = notification_queue[i + 1]
end
notification_queue[queue_count] = nil
local duration = queued.duration or auto_notification_seconds
notification_text = queued.text
notification_tail = queued.tail
notification_green_text = queued.green_text == true
notification_good = queued.good ~= false
notification_expiry = (now or current_time()) + duration
notification_manual = false
update_notification_active()
return true
end
local function show_notification(text,good,is_manual,tail,green_text)
local now = current_time()
if is_manual then
clear_queued_notifications()
notification_text = text
notification_tail = tail
notification_green_text = green_text == true
notification_good = good ~= false
notification_expiry = now + manual_notification_seconds
notification_manual = true
update_notification_active()
return
end
if not mod.automatic_notifications then
return
end
if notification_manual and notification_expiry > now then
return
end
if notification_text and notification_expiry > now then
queue_notification(text,good,auto_notification_seconds,tail,green_text)
return
end
notification_text = text
notification_tail = tail
notification_green_text = green_text == true
notification_good = good ~= false
notification_expiry = now + auto_notification_seconds
notification_manual = false
update_notification_active()
end
local hud_notification_state = {}
mod._smog_get_notification = function()
local now = current_time()
if threshold_notification_text then
hud_notification_state.text = threshold_notification_text
hud_notification_state.tail = nil
hud_notification_state.green_text = false
hud_notification_state.red_text = threshold_notification_red_text == true
hud_notification_state.good = false
hud_notification_state.fade_seconds = notification_fade_seconds
hud_notification_state.remaining = 3600
return hud_notification_state
end
if not notification_text then
if not pop_notification(now) then
return nil
end
elseif notification_expiry <= now then
if not pop_notification(now) then
return nil
end
end
hud_notification_state.text = notification_text
hud_notification_state.tail = notification_tail
hud_notification_state.green_text = notification_green_text == true
hud_notification_state.red_text = false
hud_notification_state.good = notification_good ~= false
hud_notification_state.fade_seconds = notification_fade_seconds
hud_notification_state.remaining = math_max(notification_expiry - now,0)
return hud_notification_state
end
local function cleaning_allowed()
return mod.cleaning_permitted ~= false
end
local function show_cleaning_not_permitted()
show_notification(mod:localize("cleaning_not_permitted"),false,true)
end
local function clear_scheduled_cleans()
for i = 1,scheduled_count do
scheduled_delays[i] = nil
scheduled_reasons[i] = nil
end
scheduled_count = 0
end
local function reset_growth_window(after_mb)
growth_sample_mb = after_mb or current_heap_mb
growth_accumulator = 0
end
local function cleaned_message(before_mb,after_mb,freed_mb)
local before_percent = usage_percent(before_mb)
local after_percent = usage_percent(after_mb)
local cleaned_percent = math_max(before_percent - after_percent,0)
return mod:localize("cleaned_percent",cleaned_percent),string_format(" (%s MB  %s MB) (%s MB)",fmt_mb(before_mb),fmt_mb(after_mb),fmt_delta(freed_mb))
end
local function reset_collection_tracking()
last_post_collect_mb = nil
last_collect_low_yield = false
routine_collect_suppressed = false
end
local function track_collection_result(before_mb,after_mb,freed_mb)
if before_mb < threshold_seventy_mb or after_mb < threshold_seventy_mb then
reset_collection_tracking()
return false
end
local low_yield = freed_mb < low_collection_yield_mb
local rising_baseline = last_post_collect_mb and after_mb >= last_post_collect_mb + rising_post_collect_mb
local retained_pattern = low_yield and last_collect_low_yield and rising_baseline == true
if not low_yield then
routine_collect_suppressed = false
end
last_post_collect_mb = after_mb
last_collect_low_yield = low_yield
if retained_pattern and not routine_collect_suppressed then
routine_collect_suppressed = true
show_notification(mod:localize("post_clean_heap_rising"),false,false)
return true
end
return false
end
local function gameplay_exit_collection_locked()
return gameplay_exit_clean_pending and gameplay_exit_wait_for_debrief and not gameplay_exit_debrief_complete
end
local function perform_collect(notification_mode,context_current)
if not context_current then
refresh_context_snapshot()
end
if not context_snapshot.collection_allowed or gameplay_exit_collection_locked() then
return current_heap_mb,current_heap_mb,0,false
end
if not cleaning_allowed() then
if notification_mode == "manual" then
show_cleaning_not_permitted()
end
return current_heap_mb,current_heap_mb,0,false
end
local before_mb = refresh_heap_sample()
local routine_collect = notification_mode == "auto" or notification_mode == "auto_silent"
if routine_collect and routine_collect_suppressed then
if before_mb < threshold_seventy_mb then
reset_collection_tracking()
else
return before_mb,before_mb,0,false
end
end
collectgarbage("collect")
local after_mb = refresh_heap_sample()
heap_sample_accumulator = 0
local freed_mb = before_mb - after_mb
local retained_pattern = track_collection_result(before_mb,after_mb,freed_mb)
if notification_mode == "manual" then
local message,tail = cleaned_message(before_mb,after_mb,freed_mb)
show_notification(message,freed_mb >= 0,true,tail,true)
elseif notification_mode == "auto" and not retained_pattern then
show_notification(mod:localize("routine_cleaning"),true,false)
end
reset_growth_window(after_mb)
return before_mb,after_mb,freed_mb,true
end
local function perform_convenient_collect(notification_mode)
local now = current_time()
if last_convenient_collect_t and now - last_convenient_collect_t < convenient_collect_cooldown_seconds then
return false
end
local _,_,_,performed = perform_collect(notification_mode or "auto")
if performed then
last_convenient_collect_t = now
end
return performed
end
local function apply_gc_tuning(profile,pause,stepmul)
if gc_tuning_active and gc_tuning_profile == profile then
return
end
if not gc_tuning_active then
local pause_ok,previous_pause = pcall(collectgarbage,"setpause",pause)
local stepmul_ok,previous_stepmul = pcall(collectgarbage,"setstepmul",stepmul)
if pause_ok then
saved_gc_pause = previous_pause or saved_gc_pause
end
if stepmul_ok then
saved_gc_stepmul = previous_stepmul or saved_gc_stepmul
end
else
pcall(collectgarbage,"setpause",pause)
pcall(collectgarbage,"setstepmul",stepmul)
end
pcall(collectgarbage,"restart")
gc_tuning_active = true
gc_tuning_profile = profile
end
local function restore_gc_tuning()
if not gc_tuning_active then
return
end
if saved_gc_pause then
pcall(collectgarbage,"setpause",saved_gc_pause)
end
if saved_gc_stepmul then
pcall(collectgarbage,"setstepmul",saved_gc_stepmul)
end
pcall(collectgarbage,"restart")
gc_tuning_active = false
gc_tuning_profile = nil
saved_gc_pause = nil
saved_gc_stepmul = nil
end
local function reset_high_threshold_cycle()
high_threshold_cycle_active = false
warning_acknowledged = false
ninety_collect_done = false
ninetyfive_collect_done = false
pending_warning_return_delay = nil
clear_threshold_notification()
end
local function apply_pressure_tuning()
if pressure_state == "boosted" then
apply_gc_tuning("boosted",over_eighty_boost_pause,over_eighty_boost_stepmul)
elseif pressure_state == "high" then
apply_gc_tuning("eighty",over_eighty_pause,over_eighty_stepmul)
else
restore_gc_tuning()
end
end
local function lower_pressure_state(usage_mb)
if usage_mb < threshold_sixtyeight_mb then
return "normal"
end
return "gentle"
end
local function set_pressure_state(next_state,show_recovery)
if pressure_state == next_state then
return
end
local previous_state = pressure_state
pressure_state = next_state
if next_state == "waiting" then
pressure_wait_started_t = current_time()
pressure_boost_elapsed = 0
elseif next_state == "high" then
pressure_wait_started_t = nil
pressure_boost_elapsed = 0
elseif next_state == "boosted" then
pressure_wait_started_t = nil
elseif next_state == "normal" or next_state == "gentle" then
pressure_wait_started_t = nil
pressure_boost_elapsed = 0
end
apply_pressure_tuning()
if next_state == "high" then
show_notification(mod:localize("heap_remained_above_eighty"),false,false)
elseif next_state == "boosted" then
show_notification(mod:localize("heap_increasing_incremental_cleaning"),false,false)
elseif previous_state == "waiting" or previous_state == "high" or previous_state == "boosted" then
reset_high_threshold_cycle()
if show_recovery and (previous_state == "high" or previous_state == "boosted") then
show_notification(mod:localize("heap_now_under_eighty"),true,false)
end
end
end
local function reset_pressure_controller()
pressure_state = "normal"
pressure_wait_started_t = nil
pressure_boost_elapsed = 0
restore_gc_tuning()
reset_high_threshold_cycle()
end
local function run_staged_gc_steps(step_kb,max_steps,budget_seconds)
if incremental_gc_frame_blocked then
return false
end
local start_time = os_clock and os_clock() or nil
local steps = 0
local wanted_step_kb = step_kb or staged_step_kb
local frame_scale = target_frame_seconds / math_max(smoothed_frame_time,0.001)
if frame_scale < minimum_gc_frame_scale then
frame_scale = minimum_gc_frame_scale
elseif frame_scale > maximum_gc_frame_scale then
frame_scale = maximum_gc_frame_scale
end
local wanted_max_steps = math_max(1,math_floor((max_steps or staged_max_steps) * frame_scale + 0.5))
local wanted_budget_seconds = (budget_seconds or staged_budget_seconds) * frame_scale
repeat
local finished = collectgarbage("step",wanted_step_kb)
steps = steps + 1
if finished then
break
end
if start_time and os_clock and os_clock() - start_time >= wanted_budget_seconds then
break
end
until steps >= wanted_max_steps
return steps > 0
end
local function update_pressure_state(usage_mb,dt,allow_entry,show_recovery)
local state = pressure_state
if usage_mb < threshold_sixtyeight_mb then
set_pressure_state("normal",show_recovery)
reset_collection_tracking()
return
end
if (state == "waiting" or state == "high" or state == "boosted") and usage_mb < threshold_seventyeight_mb then
set_pressure_state(lower_pressure_state(usage_mb),show_recovery)
return
end
if state == "normal" then
if allow_entry and usage_mb >= threshold_eighty_mb then
set_pressure_state("waiting",false)
elseif allow_entry and usage_mb >= threshold_seventy_mb then
set_pressure_state("gentle",false)
end
elseif state == "gentle" then
if allow_entry and usage_mb >= threshold_eighty_mb then
set_pressure_state("waiting",false)
end
elseif state == "waiting" then
if pressure_wait_started_t and current_time() - pressure_wait_started_t >= over_eighty_delay_seconds then
set_pressure_state("high",false)
end
elseif state == "high" then
pressure_boost_elapsed = pressure_boost_elapsed + (dt or 0)
if pressure_boost_elapsed >= over_eighty_boost_delay_seconds then
set_pressure_state("boosted",false)
end
end
end
local function run_pressure_incremental_action()
if pressure_state == "gentle" or pressure_state == "waiting" then
return run_staged_gc_steps(gentle_step_kb,gentle_max_steps,gentle_budget_seconds)
elseif pressure_state == "high" or pressure_state == "boosted" then
return run_staged_gc_steps(staged_step_kb,staged_max_steps,staged_budget_seconds)
end
return false
end
local function game_mode_manager()
return Managers and Managers.state and Managers.state.game_mode
end
local function hud_blocked_text(value)
if value == nil then
return false
end
local text = type(value) == "string" and value or tostring(value)
return text:find("[Ll]oading") ~= nil or text:find("[Cc]inematic") ~= nil or text:find("[Cc]utscene") ~= nil or text:find("[Vv]alkyrie") ~= nil or text:find("[Bb]riefing") ~= nil
end
local function read_context_values()
local manager = game_mode_manager()
local ui_manager = Managers and Managers.ui
local cinematic = Managers and Managers.state and Managers.state.cinematic
local is_cinematic_active = cinematic and cinematic.cinematic_active and cinematic:cinematic_active() == true or false
local cinematic_view = ui_manager and ui_manager.view_active and ui_manager:view_active("cinematic_view") == true or false
local cutscene_view = ui_manager and ui_manager.view_active and ui_manager:view_active("cutscene_view") == true or false
local loading_view = ui_manager and ui_manager.view_active and ui_manager:view_active("loading_view") == true or false
local mission_intro_view = ui_manager and ui_manager.view_active and ui_manager:view_active("mission_intro_view") == true or false
local mission_outro_view = ui_manager and ui_manager.view_active and ui_manager:view_active("mission_outro_view") == true or false
local lobby_view = ui_manager and ui_manager.view_active and ui_manager:view_active("lobby_view") == true or false
local end_view = ui_manager and ui_manager.view_active and ui_manager:view_active("end_view") == true or false
local end_player_view = ui_manager and ui_manager.view_active and ui_manager:view_active("end_player_view") == true or false
local ui_state = ui_manager and ui_manager.get_current_state_name and ui_manager:get_current_state_name() or nil
local name
local state
if manager then
if manager.game_mode_name then
name = manager:game_mode_name()
elseif manager.game_mode then
local game_mode = manager:game_mode()
if game_mode and game_mode.name then
name = game_mode:name()
end
end
if manager.game_mode_state then
state = manager:game_mode_state()
end
end
return manager ~= nil,is_cinematic_active,cinematic_view,cutscene_view,loading_view,mission_intro_view,mission_outro_view,lobby_view,end_view,end_player_view,ui_state,name,state
end
refresh_context_snapshot = function()
context_refresh_accumulator = 0
context_refresh_requested = false
local ok,manager_present,is_cinematic_active,cinematic_view,cutscene_view,loading_view,mission_intro_view,mission_outro_view,lobby_view,end_view,end_player_view,ui_state,name,state = pcall(read_context_values)
if not ok then
context_snapshot.hud_allowed = false
context_snapshot.collection_allowed = false
context_snapshot.exit_cinematic_active = true
context_snapshot.debrief_active = false
context_snapshot.game_mode_name = nil
return context_snapshot
end
local blocked_view_active = cinematic_view or cutscene_view or loading_view or mission_intro_view or mission_outro_view or lobby_view
local transition_blocked = ui_state == "StateLoading" or ui_state == "GameplayStateInit" or ui_state == "StateExitToMainMenu" or ui_state == "StateMissionServerExit" or hud_blocked_text(ui_state) or hud_blocked_text(name) or state == "leaving_game" or state == "done" or hud_blocked_text(state)
context_snapshot.hud_allowed = manager_present and not is_cinematic_active and not blocked_view_active and not transition_blocked
if is_cinematic_active or blocked_view_active then
context_snapshot.collection_allowed = false
elseif end_view or end_player_view then
context_snapshot.collection_allowed = true
else
context_snapshot.collection_allowed = not transition_blocked
end
context_snapshot.exit_cinematic_active = is_cinematic_active or cinematic_view or cutscene_view or mission_outro_view
context_snapshot.debrief_active = end_view or end_player_view
context_snapshot.game_mode_name = name
return context_snapshot
end
local function read_immediate_context_values()
local cinematic = Managers and Managers.state and Managers.state.cinematic
local is_cinematic_active = cinematic and cinematic.cinematic_active and cinematic:cinematic_active() == true or false
local ui_manager = Managers and Managers.ui
local ui_state = ui_manager and ui_manager.get_current_state_name and ui_manager:get_current_state_name() or nil
local blocked = is_cinematic_active or ui_state == "StateLoading" or ui_state == "GameplayStateInit" or ui_state == "StateExitToMainMenu" or ui_state == "StateMissionServerExit" or hud_blocked_text(ui_state)
local exit_cinematic_active = is_cinematic_active
if gameplay_exit_clean_pending and ui_manager and ui_manager.view_active then
local cinematic_view = ui_manager:view_active("cinematic_view") == true
local cutscene_view = ui_manager:view_active("cutscene_view") == true
local mission_outro_view = ui_manager:view_active("mission_outro_view") == true
blocked = blocked or cinematic_view or cutscene_view or mission_outro_view
exit_cinematic_active = exit_cinematic_active or cinematic_view or cutscene_view or mission_outro_view
end
return blocked,exit_cinematic_active
end
local function update_context_snapshot(dt)
context_refresh_accumulator = math_min(context_refresh_accumulator + (dt or 0),context_refresh_interval)
local ok,blocked,exit_cinematic_active = pcall(read_immediate_context_values)
if not ok then
blocked = true
exit_cinematic_active = true
end
if immediate_context_blocked and not blocked then
context_refresh_requested = true
end
immediate_context_blocked = blocked
if context_refresh_requested or context_refresh_accumulator >= context_refresh_interval then
refresh_context_snapshot()
end
if blocked then
context_snapshot.hud_allowed = false
context_snapshot.collection_allowed = false
if exit_cinematic_active then
context_snapshot.exit_cinematic_active = true
end
end
return context_snapshot
end
refresh_context_snapshot()
mod._smog_context_snapshot = context_snapshot
local hud_element_definition = {
class_name = "HudElementSMOGController",
filename = "SMOG/scripts/mods/SMOG/SMOG_Cont",
use_hud_scale = true,
visibility_groups = {
"dead",
"alive",
"communication_wheel",
"tactical_overlay",
"player_in_danger_zone",
"emote_wheel",
"in_hub_view",
"in_view",
"popup",
},
}
local hud_registered = mod:register_hud_element(hud_element_definition)
if hud_registered ~= true then
mod:error("SMOG HUD element registration failed. See the preceding DMF Custom HUD Elements error for details.")
end
mod.toggle_hud = function()
mod._smog_hud_visible = not mod._smog_hud_visible
if mod._smog_hud_visible then
refresh_context_snapshot()
refresh_heap_sample()
heap_sample_accumulator = 0
else
heap_sample_accumulator = heap_sample_interval
end
end
local function game_mode_object()
local manager = game_mode_manager()
if not manager or not manager.game_mode then
return nil
end
local ok,game_mode = pcall(manager.game_mode,manager)
if ok then
return game_mode
end
return nil
end
local function in_safe_zone()
local game_mode = game_mode_object()
if game_mode and game_mode.in_safe_zone then
local ok,result = pcall(game_mode.in_safe_zone,game_mode)
if ok then
return result == true
end
end
local pacing = Managers and Managers.state and Managers.state.pacing
if pacing and pacing.get_in_safe_zone then
local ok,result = pcall(pacing.get_in_safe_zone,pacing)
if ok then
return result == true
end
end
return nil
end
local function is_hub_mode(name)
return name == "hub" or name == "prologue_hub" or name == "hub_singleplay"
end
local function is_training_mode(name)
return name == "training_grounds" or name == "shooting_range"
end
local function is_mortis_mode(name)
return name == "survival"
end
local function is_expedition_mode(name)
return name == "expedition"
end
local function manual_clear_method()
local binding = mod:get("manual_clear_key")
if type(binding) == "table" and #binding > 0 then
local keys = {}
for i = 1,#binding do
local key = tostring(binding[i])
if key ~= "" then
keys[#keys + 1] = string.upper(key)
end
end
if #keys > 0 then
return "key",table.concat(keys," + ")
end
elseif type(binding) == "string" and binding ~= "" then
return "key",string.upper(binding)
end
return "command"
end
local function localized_manual_warning(key_id,command_id)
local method,key_text = manual_clear_method()
if method == "key" then
return mod:localize(key_id,key_text)
end
return mod:localize(command_id)
end
local function warning_eightyfive_text()
return localized_manual_warning("warning_eightyfive_key","warning_eightyfive_command")
end
local function warning_post_ninety_text()
return localized_manual_warning("warning_post_ninety_key","warning_post_ninety_command")
end
local function warning_ninetyfive_text()
if is_hub_mode(context_snapshot.game_mode_name) then
return localized_manual_warning("warning_ninetyfive_hub_key","warning_ninetyfive_hub_command")
end
return localized_manual_warning("warning_ninetyfive_mission_key","warning_ninetyfive_mission_command")
end
local function trigger_eightyfive_warning()
high_threshold_cycle_active = true
warning_acknowledged = false
ninety_collect_done = false
ninetyfive_collect_done = false
pending_warning_return_delay = nil
set_threshold_notification(warning_eightyfive_text(),false)
mod._smog_hud_visible = true
end
local function trigger_ninety_collect()
if ninety_collect_done or warning_acknowledged or not threshold_notification_text then
return nil,false
end
ninety_collect_done = true
pending_warning_return_delay = nil
set_threshold_notification(mod:localize("heap_reached_ninety"),false)
local _,after_mb,_,performed = perform_collect(false)
if performed and after_mb >= threshold_eighty_mb then
pending_warning_return_delay = warning_return_delay_seconds
end
return after_mb,performed
end
local function trigger_ninetyfive_collect()
if ninetyfive_collect_done then
return nil,false
end
ninetyfive_collect_done = true
ninety_collect_done = true
pending_warning_return_delay = nil
set_threshold_notification(warning_ninetyfive_text(),true)
local _,after_mb,_,performed = perform_collect(false)
return after_mb,performed
end
local function tick_pending_warning_return(dt)
if not pending_warning_return_delay then
return
end
pending_warning_return_delay = pending_warning_return_delay - (dt or 0)
if pending_warning_return_delay > 0 then
return
end
pending_warning_return_delay = nil
if not warning_acknowledged and current_heap_mb >= threshold_eighty_mb then
set_threshold_notification(warning_post_ninety_text(),false)
end
end
local function schedule_convenient_clean(reason,delay)
if not mod.convenient_moment_cleans or not cleaning_allowed() then
return
end
for i = 1,scheduled_count do
if scheduled_reasons[i] == reason then
scheduled_delays[i] = delay
return
end
end
scheduled_count = scheduled_count + 1
scheduled_reasons[scheduled_count] = reason
scheduled_delays[scheduled_count] = delay
end
local function has_scheduled_clean(reason)
for i = 1,scheduled_count do
if scheduled_reasons[i] == reason then
return true
end
end
return false
end
local function remove_scheduled_clean(index)
for i = index,scheduled_count - 1 do
scheduled_delays[i] = scheduled_delays[i + 1]
scheduled_reasons[i] = scheduled_reasons[i + 1]
end
scheduled_delays[scheduled_count] = nil
scheduled_reasons[scheduled_count] = nil
scheduled_count = scheduled_count - 1
end
local function remove_scheduled_reason(reason)
for i = scheduled_count,1,-1 do
if scheduled_reasons[i] == reason then
remove_scheduled_clean(i)
end
end
end
local function schedule_gameplay_exit_clean(wait_for_debrief)
if not mod.convenient_moment_cleans or not cleaning_allowed() then
return
end
local was_pending = gameplay_exit_clean_pending
gameplay_exit_clean_pending = true
gameplay_exit_clean_delay = nil
if wait_for_debrief == true then
gameplay_exit_wait_for_debrief = true
gameplay_exit_debrief_seen = false
gameplay_exit_debrief_complete = false
elseif not was_pending then
gameplay_exit_wait_for_debrief = false
gameplay_exit_debrief_seen = false
gameplay_exit_debrief_complete = true
end
end
local function clear_gameplay_exit_clean()
gameplay_exit_clean_pending = false
gameplay_exit_clean_delay = nil
gameplay_exit_wait_for_debrief = false
gameplay_exit_debrief_seen = false
gameplay_exit_debrief_complete = false
end
local function tick_gameplay_exit_clean(dt)
if not gameplay_exit_clean_pending then
return false
end
if not mod.convenient_moment_cleans or not cleaning_allowed() then
clear_gameplay_exit_clean()
return false
end
if gameplay_exit_collection_locked() or context_snapshot.exit_cinematic_active then
gameplay_exit_clean_delay = nil
return false
end
if gameplay_exit_clean_delay == nil then
gameplay_exit_clean_delay = gameplay_exit_clean_delay_seconds
return false
end
gameplay_exit_clean_delay = gameplay_exit_clean_delay - (dt or 0)
if gameplay_exit_clean_delay <= 0 then
clear_gameplay_exit_clean()
return perform_convenient_collect("auto_silent")
end
return false
end
local function check_convenient_transitions()
local name = context_snapshot.game_mode_name
if name ~= previous_game_mode_name then
if previous_game_mode_name and (is_training_mode(previous_game_mode_name) or is_mortis_mode(previous_game_mode_name) or is_expedition_mode(previous_game_mode_name)) then
schedule_gameplay_exit_clean(false)
end
if is_hub_mode(name) then
if mourningstar_visit_state == "unseen" then
mourningstar_visit_state = "waiting"
schedule_convenient_clean("mourningstar",mourningstar_clean_delay_seconds)
else
remove_scheduled_reason("mourningstar")
end
else
if mourningstar_visit_state == "waiting" then
mourningstar_visit_state = "expired"
end
remove_scheduled_reason("mourningstar")
if is_training_mode(name) or is_mortis_mode(name) or is_expedition_mode(name) then
schedule_convenient_clean("activity_start",1)
end
end
previous_game_mode_name = name
end
local safe_zone = in_safe_zone()
if safe_zone ~= nil and previous_safe_zone_state ~= nil and safe_zone ~= previous_safe_zone_state and safe_zone then
schedule_convenient_clean("sanctuary",1)
end
if safe_zone ~= nil then
previous_safe_zone_state = safe_zone
end
end
local function run_convenient_clean(reason)
if not mod.convenient_moment_cleans or not cleaning_allowed() then
return false
end
local name = context_snapshot.game_mode_name
if reason == "mourningstar" then
if mourningstar_visit_state == "waiting" and is_hub_mode(name) and perform_convenient_collect() then
mourningstar_visit_state = "completed"
return true
end
elseif reason == "gameplay_enter" then
if is_hub_mode(name) then
if mourningstar_visit_state == "waiting" and not has_scheduled_clean("mourningstar") then
schedule_convenient_clean("mourningstar",mourningstar_clean_delay_seconds)
end
else
return perform_convenient_collect()
end
else
return perform_convenient_collect()
end
return false
end
local function tick_scheduled_clean(dt)
if scheduled_count <= 0 then
return false
end
local due_count = 0
for i = scheduled_count,1,-1 do
scheduled_delays[i] = scheduled_delays[i] - (dt or 0)
if scheduled_delays[i] <= 0 then
due_count = due_count + 1
due_reasons[due_count] = scheduled_reasons[i]
remove_scheduled_clean(i)
end
end
local performed = false
for i = 1,due_count do
local reason = due_reasons[i]
due_reasons[i] = nil
if not performed and run_convenient_clean(reason) then
performed = true
end
end
return performed
end
local function growth_collect_due(usage_mb)
growth_accumulator = growth_accumulator + check_interval
if growth_accumulator < growth_window_seconds then
return false
end
local previous_mb = growth_sample_mb or usage_mb
local delta_mb = usage_mb - previous_mb
local delta_percent = delta_mb / detected_heap_mb * 100
growth_sample_mb = usage_mb
growth_accumulator = 0
return cleaning_allowed() and usage_mb > threshold_thirtyfive_mb and delta_percent >= 15
end
local function run_pressure_controller(dt,check_due,gc_action_taken)
local usage_mb = current_heap_mb
update_pressure_state(usage_mb,dt,check_due,true)
if check_due and usage_mb >= threshold_eightyfive_mb and not high_threshold_cycle_active then
trigger_eightyfive_warning()
end
if check_due and not gc_action_taken then
local after_mb = nil
local performed = false
if usage_mb >= threshold_ninetyfive_mb and not ninetyfive_collect_done then
after_mb,performed = trigger_ninetyfive_collect()
elseif usage_mb >= threshold_ninety_mb and high_threshold_cycle_active and not ninety_collect_done and not warning_acknowledged then
after_mb,performed = trigger_ninety_collect()
end
if performed then
update_pressure_state(after_mb,0,true,true)
return true
end
end
if check_due and growth_collect_due(usage_mb) and not gc_action_taken then
show_notification(mod:localize("heap_growth_spike"),false,false)
local _,after_mb,_,performed = perform_collect(false)
if performed then
update_pressure_state(after_mb,0,true,true)
return true
end
end
if gc_action_taken then
update_pressure_state(current_heap_mb,0,true,true)
return true
end
return run_pressure_incremental_action()
end
mod.manual_clear = function()
local t = current_time()
refresh_context_snapshot()
if not context_snapshot.collection_allowed then
return
end
if not cleaning_allowed() then
show_cleaning_not_permitted()
return
end
if t < next_manual_clear_t then
return
end
next_manual_clear_t = t + manual_clear_cooldown
if high_threshold_cycle_active then
warning_acknowledged = true
ninety_collect_done = true
pending_warning_return_delay = nil
clear_threshold_notification()
end
local _,after_mb = perform_collect("manual",true)
update_pressure_state(after_mb,0,true,false)
end
mod:command("smog",mod:localize("command_clear_desc"),function()
mod.manual_clear()
end)
mod.on_setting_changed = function(changed_setting)
if changed_setting == "cleaning_permitted" then
mod.cleaning_permitted = mod:get("cleaning_permitted") ~= false
if cleaning_allowed() then
context_refresh_requested = true
else
reset_pressure_controller()
clear_scheduled_cleans()
clear_gameplay_exit_clean()
last_convenient_collect_t = nil
reset_collection_tracking()
interval_accumulator = 0
end
elseif changed_setting == "auto_clean_on_start" then
mod.convenient_moment_cleans = mod:get("auto_clean_on_start")
if mod.convenient_moment_cleans then
if mourningstar_visit_state == "waiting" and is_hub_mode(context_snapshot.game_mode_name) then
schedule_convenient_clean("mourningstar",mourningstar_clean_delay_seconds)
end
else
clear_scheduled_cleans()
clear_gameplay_exit_clean()
last_convenient_collect_t = nil
end
elseif changed_setting == "auto_clean_every_ten_minutes" then
mod.auto_clean_every_ten_minutes = mod:get("auto_clean_every_ten_minutes")
interval_accumulator = 0
elseif changed_setting == "notifications" then
mod.automatic_notifications = mod:get("notifications") ~= false
if not mod.automatic_notifications then
clear_queued_notifications()
if not notification_manual then
clear_notification()
end
end
elseif changed_setting == "hud_format" then
local previous_format = mod._smog_hud_format
mod._smog_hud_format = advanced.read_hud_format()
if mod._smog_hud_format == "advanced_digital" and previous_format ~= "advanced_digital" then
advanced.reset_growth()
end
elseif changed_setting == "hud_x_axis" then
mod._smog_hud_x_axis = tonumber(mod:get("hud_x_axis")) or 10
elseif changed_setting == "hud_y_axis" then
mod._smog_hud_y_axis = tonumber(mod:get("hud_y_axis")) or 30
elseif changed_setting == "notification_y_axis" then
mod._smog_notification_y_axis = tonumber(mod:get("notification_y_axis")) or 85
end
end
mod.on_game_state_changed = function(status,state_name)
refresh_context_snapshot()
if status == "enter" then
if state_name == "StateGameplay" then
if gameplay_exit_collection_locked() then
gameplay_exit_debrief_complete = true
end
schedule_convenient_clean("gameplay_enter",1)
end
elseif status == "exit" and state_name == "StateGameplay" then
schedule_gameplay_exit_clean(true)
end
end
mod.update = function(dt)
if mod.is_enabled and not mod:is_enabled() then
return
end
if type(dt) ~= "number" or dt <= 0 then
return
end
elapsed_time = elapsed_time + dt
advanced.update(dt)
heap_sample_accumulator = math_min(heap_sample_accumulator + dt,check_interval)
local frame_dt = math_min(dt,0.1)
incremental_gc_frame_blocked = frame_dt > math_max(smoothed_frame_time,0.001) * transient_frame_spike_multiplier
smoothed_frame_time = smoothed_frame_time * 0.9 + frame_dt * 0.1
if not cleaning_allowed() and mod._smog_hud_visible ~= true and mod._smog_notification_active ~= true then
idle_context_accumulator = 0
context_refresh_accumulator = math_min(context_refresh_accumulator + dt,context_refresh_interval)
if heap_sample_accumulator >= check_interval then
refresh_heap_sample()
heap_sample_accumulator = 0
end
accumulator = accumulator + dt
if accumulator >= check_interval then
accumulator = accumulator - check_interval
persist_heap_state(current_heap_percent)
end
return
end
if not first_update_done then
refresh_context_snapshot()
first_update_done = true
previous_game_mode_name = context_snapshot.game_mode_name
previous_safe_zone_state = in_safe_zone()
if is_hub_mode(previous_game_mode_name) then
mourningstar_visit_state = "waiting"
schedule_convenient_clean("mourningstar",mourningstar_clean_delay_seconds)
end
end
local idle_normal = pressure_state == "normal" and mod._smog_hud_visible ~= true and mod._smog_notification_active ~= true and scheduled_count <= 0 and not gameplay_exit_clean_pending and not mod.auto_clean_every_ten_minutes and not context_refresh_requested
if idle_normal then
accumulator = 0
idle_context_accumulator = idle_context_accumulator + dt
if idle_context_accumulator < check_interval then
return
end
idle_context_accumulator = idle_context_accumulator - check_interval
refresh_context_snapshot()
local collection_blocked = not context_snapshot.collection_allowed
if collection_blocked then
collection_context_was_blocked = true
return
end
collection_context_was_blocked = false
refresh_heap_sample()
heap_sample_accumulator = 0
persist_heap_state(current_heap_percent)
check_convenient_transitions()
run_pressure_controller(dt,true,false)
return
end
idle_context_accumulator = 0
update_context_snapshot(dt)
if gameplay_exit_clean_pending and gameplay_exit_wait_for_debrief and not gameplay_exit_debrief_complete then
if context_snapshot.debrief_active then
gameplay_exit_debrief_seen = true
elseif gameplay_exit_debrief_seen then
gameplay_exit_debrief_complete = true
end
end
local collection_blocked = not context_snapshot.collection_allowed or gameplay_exit_collection_locked()
if collection_blocked then
if not collection_context_was_blocked then
collection_context_was_blocked = true
restore_gc_tuning()
if pressure_state == "waiting" then
pressure_wait_started_t = nil
end
if gameplay_exit_clean_pending then
gameplay_exit_clean_delay = nil
end
end
return
elseif collection_context_was_blocked then
collection_context_was_blocked = false
if pressure_state == "waiting" then
pressure_wait_started_t = current_time()
elseif pressure_state == "high" or pressure_state == "boosted" then
apply_pressure_tuning()
end
end
local wanted_heap_sample_interval = (mod._smog_hud_visible or pressure_state ~= "normal") and heap_sample_interval or check_interval
if heap_sample_accumulator >= wanted_heap_sample_interval then
refresh_heap_sample()
heap_sample_accumulator = 0
end
accumulator = accumulator + dt
local check_due = false
if accumulator >= check_interval then
accumulator = accumulator - check_interval
persist_heap_state(current_heap_percent)
check_due = true
end
if not cleaning_allowed() then
return
end
local gc_action_taken = tick_scheduled_clean(dt)
if not gc_action_taken then
gc_action_taken = tick_gameplay_exit_clean(dt)
end
if mod.auto_clean_every_ten_minutes then
interval_accumulator = interval_accumulator + dt
if interval_accumulator >= interval_clean_time then
interval_accumulator = 0
if not gc_action_taken then
local _,_,_,performed = perform_collect("auto")
gc_action_taken = performed
end
end
else
interval_accumulator = 0
end
tick_pending_warning_return(dt)
if check_due then
check_convenient_transitions()
end
if pressure_state ~= "normal" or check_due or gc_action_taken then
run_pressure_controller(dt,check_due,gc_action_taken)
end
end
local function clean_shutdown()
local state = heap_state(usage_percent(refresh_heap_sample()))
last_persisted_heap_state = state
mod:set("_smog_clean_shutdown",true)
mod:set("_smog_last_heap_percent",state)
if mod._smog_hud_format == "advanced_digital" then
mod:set("_smog_last_pressure",advanced.state.pressure)
else
mod:set("_smog_last_pressure",(pressure_state ~= "normal" or current_heap_percent >= 70) and "LUA" or "NORMAL")
end
save_settings_now()
end
local function cleanup_mod()
collection_context_was_blocked = false
reset_pressure_controller()
clear_scheduled_cleans()
clear_gameplay_exit_clean()
clear_all_notifications()
mod._smog_hud_visible = false
clean_shutdown()
end
mod.on_unload = cleanup_mod
mod.on_disabled = cleanup_mod