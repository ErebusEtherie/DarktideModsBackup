local mod = get_mod("machine_gods_beacon")
local VERSION = "v2026.01.23.0258"

local mgb_lights = {}
mgb_lights._version = VERSION

local _perf_batch_size = 10

local function get_MGB()
	return mod._mgb
end

local function get_state()
	local MGB = get_MGB()
	return MGB and MGB.state
end

local function get_stutter_count_for_light()
	local base = mod:get("stutter_count") or 3
	return base + math.random(0, 3)
end

local function get_stutter_interval()
	local MGB = get_MGB()
	if not MGB then
		return 0.125
	end
	return MGB.get_flicker_duration() / 4
end

local function get_cascade_delay()
	return 0.03
end

local function capture_original_light_state(light_group_name, ext)
	local state = get_state()
	if not state then
		return
	end
	if state.original_light_states[light_group_name] ~= nil then
		return
	end
	local is_enabled = ext._enabled
	if is_enabled == nil then
		is_enabled = true
	end
	state.original_light_states[light_group_name] = is_enabled
	local MGB = get_MGB()
	if MGB then
		MGB.log("captured original light state: %s = %s", light_group_name, tostring(is_enabled))
	end
end

local function capture_all_original_light_states()
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	if state.original_light_states_captured then
		return
	end
	local light_sys = MGB.get_system("light_controller_system")
	if not light_sys or not light_sys._light_group_extensions then
		return
	end
	for group_name, extensions in pairs(light_sys._light_group_extensions) do
		if state.original_light_states[group_name] == nil and #extensions > 0 then
			local ext = extensions[1]
			local is_enabled = ext._enabled
			if is_enabled == nil then
				is_enabled = true
			end
			state.original_light_states[group_name] = is_enabled
			MGB.log("captured original light state: %s = %s", group_name, tostring(is_enabled))
		end
	end
	state.original_light_states_captured = true
	MGB.log("captured all original light states: %d groups", table.size(state.original_light_states))
end

local function record_intended_group_state(light_group_name, is_enabled)
	local state = get_state()
	if not state then
		return
	end
	if state.intended_light_states[light_group_name] == nil then
		state.intended_light_states[light_group_name] = is_enabled
		local MGB = get_MGB()
		if MGB then
			MGB.log("recorded intended state: %s = %s", light_group_name, tostring(is_enabled))
		end
	end
end

local function is_light_assigned_on(group_name, index)
	local state = get_state()
	if not state then
		return true
	end
	local cache = state.light_groups_cache[group_name]
	if not cache or not cache.indices then
		return true
	end
	return cache.indices[index] == true
end

function mgb_lights.clear_flicker_caches()
	local state = get_state()
	if not state then
		return
	end
	local flicker = state.flicker
	if not flicker then
		return
	end
	flicker.sorted_lights_cache = nil
	flicker.sorted_on = nil
	flicker.sorted_off = nil
	flicker.last_sort_time = 0
end

function mgb_lights.reset_all_lights(enabled)
	local MGB = get_MGB()
	if not MGB then
		return false
	end
	local light_sys = MGB.get_system("light_controller_system")
	if not light_sys or not light_sys._light_group_extensions then
		return false
	end
	for _, extensions in pairs(light_sys._light_group_extensions) do
		for _, ext in ipairs(extensions) do
			pcall(function()
				ext:set_enabled(enabled, true)
			end)
		end
	end
	return true
end

function mgb_lights.apply_settings()
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	if not state.in_mission then
		return
	end
	if not MGB.should_apply_lighting() then
		return
	end

	local light_sys = MGB.get_system("light_controller_system")
	if not light_sys or not light_sys._light_group_extensions then
		return
	end

	capture_all_original_light_states()
	mgb_lights.clear_flicker_caches()

	local percentage = MGB.get_light_percentage()
	local selection_mode = mod:get("light_selection")

	if percentage >= 1.0 then
		mgb_lights.reset_all_lights(true)
		for group_name, extensions in pairs(light_sys._light_group_extensions) do
			if not state.light_groups_cache[group_name] then
				state.light_groups_cache[group_name] = {}
			end
			local cache = state.light_groups_cache[group_name]
			cache.indices = {}
			cache.keep_on = #extensions
			cache.mode = selection_mode
			cache.total = #extensions
			for i = 1, #extensions do
				cache.indices[i] = true
			end
		end
		MGB.log("lights: 100pct ON")
		return
	end

	if percentage <= 0 then
		mgb_lights.reset_all_lights(false)
		for group_name, extensions in pairs(light_sys._light_group_extensions) do
			if not state.light_groups_cache[group_name] then
				state.light_groups_cache[group_name] = {}
			end
			local cache = state.light_groups_cache[group_name]
			cache.indices = {}
			cache.keep_on = 0
			cache.mode = selection_mode
			cache.total = #extensions
		end
		MGB.log("lights: 0pct OFF")
		return
	end

	mgb_lights.reset_all_lights(true)

	local total_on, total_lights = 0, 0

	for group_name, extensions in pairs(light_sys._light_group_extensions) do
		local group_total = #extensions
		local keep_on = math.max(0, math.min(group_total, math.floor(group_total * percentage + 0.5)))
		total_lights = total_lights + group_total
		total_on = total_on + keep_on

		if not state.light_groups_cache[group_name] then
			state.light_groups_cache[group_name] = {}
		end

		local cache = state.light_groups_cache[group_name]
		local need_recache = not cache.indices or cache.keep_on ~= keep_on or cache.mode ~= selection_mode or cache.total ~= group_total

		if need_recache then
			cache.indices = {}
			cache.keep_on = keep_on
			cache.mode = selection_mode
			cache.total = group_total

			if selection_mode == "random" then
				local shuffled = {}
				for i = 1, group_total do
					shuffled[i] = i
				end
				for i = group_total, 2, -1 do
					local j = math.random(i)
					shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
				end
				for i = 1, keep_on do
					cache.indices[shuffled[i]] = true
				end
			elseif selection_mode == "alternating" then
				local count = 0
				local idx = 1
				while count < keep_on and idx <= group_total do
					cache.indices[idx] = true
					count = count + 1
					idx = idx + 2
				end
				idx = 2
				while count < keep_on and idx <= group_total do
					cache.indices[idx] = true
					count = count + 1
					idx = idx + 2
				end
			elseif selection_mode == "spread" then
				if keep_on >= group_total then
					for i = 1, group_total do
						cache.indices[i] = true
					end
				elseif keep_on > 0 then
					local step = group_total / keep_on
					for i = 0, keep_on - 1 do
						local idx = math.floor(i * step + step / 2) + 1
						idx = math.max(1, math.min(group_total, idx))
						cache.indices[idx] = true
					end
				end
			else
				for i = 1, keep_on do
					cache.indices[i] = true
				end
			end
		end

		for i, ext in ipairs(extensions) do
			if not cache.indices[i] then
				pcall(function()
					ext:set_enabled(false, true)
				end)
			end
		end
	end

	MGB.log("lights: %d/%d [%s]", total_on, total_lights, selection_mode)
end

local function restore_light_states()
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	local light_sys = MGB.get_system("light_controller_system")
	if not light_sys or not light_sys._light_group_extensions then
		return
	end

	local intended_count = table.size(state.intended_light_states or {})
	MGB.log("restore: intended_states=%d", intended_count)

	if intended_count == 0 then
		MGB.log("restore: no intended states captured, turning all lights ON")
		mgb_lights.reset_all_lights(true)
		return
	end

	local on_count, off_count = 0, 0
	for group_name, extensions in pairs(light_sys._light_group_extensions) do
		local intended_enabled = state.intended_light_states[group_name]
		if intended_enabled ~= nil then
			for _, ext in ipairs(extensions) do
				pcall(function()
					ext:set_enabled(intended_enabled, true)
				end)
				if intended_enabled then
					on_count = on_count + 1
				else
					off_count = off_count + 1
				end
			end
		else
			for _, ext in ipairs(extensions) do
				pcall(function()
					ext:set_enabled(true, true)
				end)
				on_count = on_count + 1
			end
		end
	end
	MGB.log("restore: %d on %d off (from intended states)", on_count, off_count)
end

function mgb_lights.revert_settings()
	local state = get_state()
	if not state then
		return
	end
	if not state.in_mission then
		return
	end
	restore_light_states()
	local MGB = get_MGB()
	if MGB then
		MGB.log("lights: reverted")
	end
end

local function get_lights_by_assignment(want_assigned_on)
	local MGB = get_MGB()
	if not MGB then
		return {}
	end
	local state = MGB.state
	local light_sys = MGB.get_system("light_controller_system")
	if not light_sys or not light_sys._light_group_extensions then
		return {}
	end
	local lights = {}
	for group_name, extensions in pairs(light_sys._light_group_extensions) do
		for i, ext in ipairs(extensions) do
			local assigned_on = is_light_assigned_on(group_name, i)
			if assigned_on == want_assigned_on then
				table.insert(lights, {key = group_name .. ":" .. i, group = group_name, index = i, ext = ext, assigned_on = assigned_on})
			end
		end
	end
	return lights
end

local function get_sorted_lights_by_assignment(want_assigned_on, current_time)
	local state = get_state()
	if not state then
		return {}
	end
	local flicker = state.flicker
	local cache_key = want_assigned_on and "sorted_on" or "sorted_off"

	if flicker[cache_key] and (current_time - flicker.last_sort_time) < 0.5 then
		return flicker[cache_key]
	end

	local lights = get_lights_by_assignment(want_assigned_on)
	table.sort(lights, function(a, b)
		if a.group == b.group then
			return a.index < b.index
		end
		return a.group < b.group
	end)

	flicker[cache_key] = lights
	flicker.last_sort_time = current_time
	return lights
end

local function process_stutter(current_time, light_sys)
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	local flicker = state.flicker
	local stutter_interval = get_stutter_interval()
	local keys_done = {}

	for key, stutter in pairs(flicker.stutter_state or {}) do
		if current_time >= stutter.next_toggle then
			local group_name, idx_str = string.match(key, "(.+):(%d+)")
			local idx = tonumber(idx_str)
			if group_name and idx then
				local extensions = light_sys._light_group_extensions[group_name]
				if extensions and extensions[idx] then
					stutter.is_on = not stutter.is_on
					pcall(function()
						extensions[idx]:set_enabled(stutter.is_on, true)
					end)
					stutter.toggles_remaining = stutter.toggles_remaining - 1
					stutter.next_toggle = current_time + stutter_interval

					if stutter.toggles_remaining <= 0 then
						local restore_state = is_light_assigned_on(group_name, idx)
						pcall(function()
							extensions[idx]:set_enabled(restore_state, true)
						end)
						table.insert(keys_done, key)
						flicker.cooldowns[key] = current_time + MGB.get_flicker_cooldown()
					end
				end
			end
		end
	end

	for _, key in ipairs(keys_done) do
		flicker.stutter_state[key] = nil
	end
end

local function process_active_flickers(current_time, light_sys)
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	local flicker = state.flicker
	local cooldown = MGB.get_flicker_cooldown()
	local keys_to_remove = {}

	for key, flicker_end_time in pairs(flicker.active_flickers or {}) do
		if current_time >= flicker_end_time then
			local group_name, idx_str = string.match(key, "(.+):(%d+)")
			local idx = tonumber(idx_str)
			if group_name and idx then
				local extensions = light_sys._light_group_extensions[group_name]
				if extensions and extensions[idx] then
					local restore_state = is_light_assigned_on(group_name, idx)
					pcall(function()
						extensions[idx]:set_enabled(restore_state, true)
					end)
				end
			end
			table.insert(keys_to_remove, key)
			flicker.cooldowns[key] = current_time + cooldown
		end
	end
	for _, key in ipairs(keys_to_remove) do
		flicker.active_flickers[key] = nil
	end
end

local function start_light_flicker(light, current_time, use_stutter)
	local state = get_state()
	if not state then
		return
	end
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local flicker = state.flicker
	local duration = MGB.get_flicker_duration()
	local flicker_to_state = not light.assigned_on

	if use_stutter then
		local stutter_cycles = get_stutter_count_for_light()
		flicker.stutter_state[light.key] = {
			is_on = light.assigned_on,
			toggles_remaining = stutter_cycles * 2,
			next_toggle = current_time,
		}
	else
		pcall(function()
			light.ext:set_enabled(flicker_to_state, true)
		end)
		flicker.active_flickers[light.key] = current_time + duration
	end
end

local function is_light_available(light, current_time)
	local state = get_state()
	if not state then
		return false
	end
	local flicker = state.flicker
	local cd = flicker.cooldowns and flicker.cooldowns[light.key]
	local in_active = flicker.active_flickers and flicker.active_flickers[light.key]
	local in_stutter = flicker.stutter_state and flicker.stutter_state[light.key]
	return (not cd or current_time >= cd) and not in_active and not in_stutter
end

local function get_eligible_lights(current_time)
	local MGB = get_MGB()
	if not MGB then
		return {}
	end
	local target_assigned_on = MGB.get_flicker_default() == "on"
	local lights = get_sorted_lights_by_assignment(target_assigned_on, current_time)
	local eligible = {}
	for _, light in ipairs(lights) do
		if is_light_available(light, current_time) then
			table.insert(eligible, light)
		end
	end
	return eligible
end

local function trigger_flicker_all(current_time, use_stutter)
	local eligible = get_eligible_lights(current_time)
	for _, light in ipairs(eligible) do
		start_light_flicker(light, current_time, use_stutter)
	end
end

local function trigger_flicker_random(current_time, use_stutter)
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local eligible = get_eligible_lights(current_time)
	if #eligible == 0 then
		return
	end

	local flicker_count = math.max(1, math.floor(#eligible * MGB.get_flicker_percentage() + 0.5))

	for i = #eligible, 2, -1 do
		local j = math.random(i)
		eligible[i], eligible[j] = eligible[j], eligible[i]
	end

	for i = 1, math.min(flicker_count, #eligible) do
		start_light_flicker(eligible[i], current_time, use_stutter)
	end
end

local function spawn_cascade_wave(start_index, total_lights)
	local state = get_state()
	if not state then
		return
	end
	local flicker = state.flicker
	local half = math.floor(total_lights / 2)
	table.insert(flicker.cascade_waves, {
		index = start_index,
		end_index = total_lights,
		spawn_at = start_index + half,
		spawned = false,
	})
end

local function update_cascade(current_time, use_stutter)
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	local flicker = state.flicker
	local target_assigned_on = MGB.get_flicker_default() == "on"
	local sorted = get_sorted_lights_by_assignment(target_assigned_on, current_time)
	local total = #sorted

	if total == 0 then
		return
	end
	if current_time < flicker.cascade_next_time then
		return
	end

	if #flicker.cascade_waves == 0 then
		spawn_cascade_wave(1, total)
		flicker.cascade_next_time = current_time
	end

	local waves_to_add = {}
	local waves_to_remove = {}
	local triggered_count = 0
	local max_per_tick = _perf_batch_size

	for i, wave in ipairs(flicker.cascade_waves) do
		if triggered_count >= max_per_tick then
			break
		end

		local light = sorted[wave.index]
		if light and is_light_available(light, current_time) then
			start_light_flicker(light, current_time, use_stutter)
			triggered_count = triggered_count + 1
		end

		if not wave.spawned and wave.index >= wave.spawn_at then
			wave.spawned = true
			table.insert(waves_to_add, {start = 1, total = total})
		end

		wave.index = wave.index + 1
		if wave.index > wave.end_index then
			table.insert(waves_to_remove, i)
		end
	end

	for i = #waves_to_remove, 1, -1 do
		table.remove(flicker.cascade_waves, waves_to_remove[i])
	end

	for _, new_wave in ipairs(waves_to_add) do
		spawn_cascade_wave(new_wave.start, new_wave.total)
	end

	if triggered_count > 0 or #flicker.cascade_waves > 0 then
		flicker.cascade_next_time = current_time + get_cascade_delay()
	end
end

local function trigger_new_flickers(current_time)
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	local flicker = state.flicker
	local interval = MGB.get_flicker_interval()
	local light_state = MGB.get_light_state()
	local use_stutter = mod:get("enable_stutter")

	if light_state == "flicker_cascade" then
		update_cascade(current_time, use_stutter)
		return
	end

	if current_time - (flicker.last_cycle_time or 0) < interval then
		return
	end
	flicker.last_cycle_time = current_time

	if light_state == "flicker" then
		trigger_flicker_all(current_time, use_stutter)
	elseif light_state == "flicker_random" then
		trigger_flicker_random(current_time, use_stutter)
	end
end

function mgb_lights.update_flicker(current_time)
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	if not state.in_mission then
		return
	end
	if not MGB.should_apply_lighting() then
		return
	end
	if not MGB.is_flicker_mode() then
		return
	end

	local light_sys = MGB.get_system("light_controller_system")
	if not light_sys or not light_sys._light_group_extensions then
		return
	end

	local flicker = state.flicker
	if not flicker then
		return
	end

	process_stutter(current_time, light_sys)
	process_active_flickers(current_time, light_sys)
	trigger_new_flickers(current_time)
end

function mgb_lights.stop_all_flickers()
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	local light_sys = MGB.get_system("light_controller_system")
	local flicker = state.flicker
	if not flicker then
		return
	end

	if light_sys and light_sys._light_group_extensions then
		for key, _ in pairs(flicker.active_flickers or {}) do
			local group_name, idx_str = string.match(key, "(.+):(%d+)")
			local idx = tonumber(idx_str)
			if group_name and idx then
				local extensions = light_sys._light_group_extensions[group_name]
				if extensions and extensions[idx] then
					local restore_state = is_light_assigned_on(group_name, idx)
					pcall(function()
						extensions[idx]:set_enabled(restore_state, true)
					end)
				end
			end
		end
		for key, _ in pairs(flicker.stutter_state or {}) do
			local group_name, idx_str = string.match(key, "(.+):(%d+)")
			local idx = tonumber(idx_str)
			if group_name and idx then
				local extensions = light_sys._light_group_extensions[group_name]
				if extensions and extensions[idx] then
					local restore_state = is_light_assigned_on(group_name, idx)
					pcall(function()
						extensions[idx]:set_enabled(restore_state, true)
					end)
				end
			end
		end
	end

	flicker.active_flickers = {}
	flicker.cooldowns = {}
	flicker.last_cycle_time = 0
	flicker.stutter_state = {}
	flicker.cascade_waves = {}
	flicker.cascade_next_time = 0
	flicker.sorted_lights_cache = nil
	flicker.sorted_on = nil
	flicker.sorted_off = nil
	flicker.last_sort_time = 0
end

local function should_control_lights_in_hook()
	if not mod:is_enabled() then
		return false
	end
	local MGB = get_MGB()
	if not MGB then
		return false
	end
	if not MGB.is_in_mission_or_training() then
		return false
	end
	MGB.update_mission_state()
	return MGB.should_apply_lighting()
end

mod:hook(CLASS.LightControllerSystem, "init", function(func, self, extension_init_context, system_init_data, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["LightControllerSystem.init"] = true
	end
	if not mod:is_enabled() then
		return func(self, extension_init_context, system_init_data, ...)
	end
	local themes = system_init_data and system_init_data.themes
	if themes and state then
		for _, theme in ipairs(themes) do
			local t = string.lower(tostring(theme))
			if string.find(t, "darkness") then
				state.is_darkness_mission = true
			elseif string.find(t, "ventilation") or string.find(t, "fog") then
				state.is_ventilation_mission = true
			end
		end
	end
	return func(self, extension_init_context, system_init_data, ...)
end)

mod:hook(CLASS.LightControllerSystem, "on_theme_changed", function(func, self, themes, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["LightControllerSystem.on_theme_changed"] = true
	end
	return func(self, themes, ...)
end)

mod:hook(CLASS.LightControllerSystem, "setup_light_groups", function(func, self, themes, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["LightControllerSystem.setup_light_groups"] = true
	end
	return func(self, themes, ...)
end)

mod:hook(CLASS.LightControllerSystem, "_set_light_group_enabled", function(func, self, light_group_name, is_enabled, is_deterministic, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["LightControllerSystem._set_light_group_enabled"] = true
	end
	if state and state.original_light_states[light_group_name] == nil then
		local extensions = self._light_group_extensions and self._light_group_extensions[light_group_name]
		if extensions and #extensions > 0 then
			local ext = extensions[1]
			local current_enabled = ext._enabled
			if current_enabled == nil then
				current_enabled = true
			end
			state.original_light_states[light_group_name] = current_enabled
			if MGB then
				MGB.log("captured original light state (hook): %s = %s", light_group_name, tostring(current_enabled))
			end
		end
	end
	record_intended_group_state(light_group_name, is_enabled)
	if should_control_lights_in_hook() and not is_enabled then
		return
	end
	return func(self, light_group_name, is_enabled, is_deterministic, ...)
end)

mod:hook(CLASS.LightControllerSystem, "on_gameplay_post_init", function(func, self, level, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["LightControllerSystem.on_gameplay_post_init"] = true
	end
	local result = func(self, level, ...)
	if MGB then
		MGB.log("post_init: intended_states=%d", MGB.get_intended_light_states_count())
	end
	if should_control_lights_in_hook() then
		Promise.delay(0.5):next(function()
			mgb_lights.apply_settings()
		end)
	end
	return result
end)

-- local function get_light_groups_info()
-- 	local MGB = get_MGB()
-- 	if not MGB then
-- 		return nil, 0
-- 	end
-- 	local sys = MGB.get_system("light_controller_system")
-- 	if not sys or not sys._light_group_extensions then
-- 		return nil, 0
-- 	end
-- 	local groups = {}
-- 	local total = 0
-- 	for name, exts in pairs(sys._light_group_extensions) do
-- 		table.insert(groups, {name = name, count = #exts})
-- 		total = total + #exts
-- 	end
-- 	return groups, total
-- end

-- local function get_assignment_info()
-- 	local state = get_state()
-- 	if not state then
-- 		return 0, 0
-- 	end
-- 	local assigned_on, assigned_off = 0, 0
-- 	for group_name, cache in pairs(state.light_groups_cache) do
-- 		if cache.indices then
-- 			for i = 1, (cache.total or 0) do
-- 				if cache.indices[i] then
-- 					assigned_on = assigned_on + 1
-- 				else
-- 					assigned_off = assigned_off + 1
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return assigned_on, assigned_off
-- end

-- local function get_flicker_info()
-- 	local MGB = get_MGB()
-- 	if not MGB then
-- 		return nil
-- 	end
-- 	local state = MGB.state
-- 	local flicker = state.flicker
-- 	if not flicker then
-- 		return nil
-- 	end
-- 	local active = 0
-- 	for _ in pairs(flicker.active_flickers or {}) do
-- 		active = active + 1
-- 	end
-- 	local cds = 0
-- 	for _ in pairs(flicker.cooldowns or {}) do
-- 		cds = cds + 1
-- 	end
-- 	local stuttering = 0
-- 	for _ in pairs(flicker.stutter_state or {}) do
-- 		stuttering = stuttering + 1
-- 	end
-- 	local waves = #(flicker.cascade_waves or {})
-- 	local assigned_on, assigned_off = get_assignment_info()
-- 	return {
-- 		state = MGB.get_light_state(),
-- 		default = MGB.get_flicker_default(),
-- 		interval = MGB.get_flicker_interval(),
-- 		duration = MGB.get_flicker_duration(),
-- 		cooldown = MGB.get_flicker_cooldown(),
-- 		pct = MGB.get_flicker_percentage(),
-- 		stutter = mod:get("enable_stutter"),
-- 		stutter_count = mod:get("stutter_count"),
-- 		active = active,
-- 		cooldowns = cds,
-- 		stuttering = stuttering,
-- 		waves = waves,
-- 		last_cycle = MGB.get_flicker_time() - (flicker.last_cycle_time or 0),
-- 		assigned_on = assigned_on,
-- 		assigned_off = assigned_off,
-- 	}
-- end

-- mod:command("mgb_light", "lights: status|groups|state|flicker|apply|revert|set [on|off|stop]", function(arg, param)
-- 	local MGB = get_MGB()
-- 	if not MGB then
-- 		mod:echo("[MGB] not initialized")
-- 		return
-- 	end
-- 	arg = arg and string.lower(arg) or "status"
-- 	local state = MGB.state

-- 	if arg == "status" then
-- 		local groups, total = get_light_groups_info()
-- 		local on, off = get_assignment_info()
-- 		local f = get_flicker_info()
-- 		MGB.log("groups=%d total=%d on=%d off=%d", groups and #groups or 0, total, on, off)
-- 		if f then
-- 			MGB.log("flicker: %s default=%s active=%d cds=%d", f.state, f.default, f.active, f.cooldowns)
-- 		end

-- 	elseif arg == "groups" then
-- 		local groups, total = get_light_groups_info()
-- 		if not groups then
-- 			MGB.log("unavailable")
-- 			return
-- 		end
-- 		for _, g in ipairs(groups) do
-- 			MGB.log("  %s: %d", g.name, g.count)
-- 		end
-- 		MGB.log("total: %d", total)

-- 	elseif arg == "state" then
-- 		local on, off = get_assignment_info()
-- 		MGB.log("assigned on=%d off=%d", on, off)
-- 		local intended = {}
-- 		for group, enabled in pairs(state.intended_light_states) do
-- 			table.insert(intended, {name = group, enabled = enabled})
-- 		end
-- 		table.sort(intended, function(a, b)
-- 			return a.name < b.name
-- 		end)
-- 		for _, s in ipairs(intended) do
-- 			local cache = state.light_groups_cache[s.name]
-- 			local actual = 0
-- 			if cache and cache.indices then
-- 				for i = 1, (cache.total or 0) do
-- 					if cache.indices[i] then
-- 						actual = actual + 1
-- 					end
-- 				end
-- 			end
-- 			MGB.log("  %s: int=%s act=%d/%d", s.name, s.enabled and "ON" or "OFF", actual, cache and cache.total or 0)
-- 		end

-- 	elseif arg == "flicker" then
-- 		local f = get_flicker_info()
-- 		if not f then
-- 			MGB.log("unavailable")
-- 			return
-- 		end
-- 		MGB.log("%s def=%s int=%.2f dur=%.3f cd=%.2f pct=%d%%", f.state, f.default, f.interval, f.duration, f.cooldown, math.floor(f.pct * 100))
-- 		MGB.log("active=%d cds=%d waves=%d stutter=%s(%d)", f.active, f.cooldowns, f.waves, tostring(f.stutter), f.stuttering)

-- 	elseif arg == "apply" then
-- 		mgb_lights.apply_settings()
-- 		MGB.log("applied")

-- 	elseif arg == "revert" then
-- 		mgb_lights.revert_settings()
-- 		MGB.log("reverted")

-- 	elseif arg == "set" then
-- 		param = param and string.lower(param)
-- 		if param == "on" then
-- 			if mgb_lights.reset_all_lights(true) then
-- 				MGB.log("ON")
-- 			else
-- 				MGB.log("failed")
-- 			end
-- 		elseif param == "off" then
-- 			if mgb_lights.reset_all_lights(false) then
-- 				MGB.log("OFF")
-- 			else
-- 				MGB.log("failed")
-- 			end
-- 		elseif param == "stop" then
-- 			mgb_lights.stop_all_flickers()
-- 			MGB.log("stopped")
-- 		else
-- 			MGB.log("usage: mgb_light set [on|off|stop]")
-- 		end

-- 	else
-- 		MGB.log("usage: mgb_light [status|groups|state|flicker|apply|revert|set]")
-- 	end
-- end)

return mgb_lights
