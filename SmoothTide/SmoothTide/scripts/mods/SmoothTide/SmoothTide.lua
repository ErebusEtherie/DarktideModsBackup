local mod = get_mod("SmoothTide")

local Managers = Managers
local ScriptUnit = ScriptUnit
local Unit = Unit
local math_random = math.random
local math_max = math.max
local math_min = math.min
local pcall = pcall
local type = type
local tostring = tostring

local enabled = false
local in_combat = false
local panic_mode = false
local ultra_panic_mode = false
local cinematic_mode = true
local last_combat_t = 0
local last_mode_echo = nil
local fps_samples = {}
local fps_sample_max = 30
local calm_since_t = 0
local current_resolution_scale = 100

local settings = {
	debug_enabled = false,
	combat_echo = false,
	combat_timeout = 4,
	combat_range = 12,

	suppress_hit_indicators = true,
	suppress_damage_overlay = true,
	particle_thinning = true,
	particle_keep_chance = 60,

	enable_panic_mode = true,
	panic_enemy_count = 14,
	panic_particle_keep_chance = 35,
	panic_hide_hit_indicators = true,
	panic_hide_damage_overlay = true,

	enable_ultra_panic_mode = true,
	ultra_panic_enemy_count = 24,
	ultra_panic_particle_keep_chance = 20,
	ultra_panic_force_performance = true,

	boss_safe_mode = true,
	mode_hotkey_enabled = true,

	default_mode = "cinematic",
	force_cinematic_mode = false,
	force_performance_mode = false,

	enable_smart_mode = true,
	smart_mode_fps_threshold = 72,
	smart_mode_restore_fps = 90,

	auto_cinematic_when_calm = true,
	calm_enemy_threshold = 0,
	calm_restore_delay = 2.5,

	auto_performance_in_hordes = true,
	horde_enemy_threshold = 10,

	enable_dynamic_resolution = true,
	dynamic_resolution_min_scale = 70,
	dynamic_resolution_max_scale = 100,
	dynamic_resolution_fps_floor = 55,
	dynamic_resolution_fps_target = 72,
}

local function refresh_settings()
	settings.debug_enabled = mod:get("debug_enabled")
	settings.combat_echo = mod:get("combat_echo")
	settings.combat_timeout = mod:get("combat_timeout")
	settings.combat_range = mod:get("combat_range")

	settings.suppress_hit_indicators = mod:get("suppress_hit_indicators")
	settings.suppress_damage_overlay = mod:get("suppress_damage_overlay")
	settings.particle_thinning = mod:get("particle_thinning")
	settings.particle_keep_chance = mod:get("particle_keep_chance")

	settings.enable_panic_mode = mod:get("enable_panic_mode")
	settings.panic_enemy_count = mod:get("panic_enemy_count")
	settings.panic_particle_keep_chance = mod:get("panic_particle_keep_chance")
	settings.panic_hide_hit_indicators = mod:get("panic_hide_hit_indicators")
	settings.panic_hide_damage_overlay = mod:get("panic_hide_damage_overlay")

	settings.enable_ultra_panic_mode = mod:get("enable_ultra_panic_mode")
	settings.ultra_panic_enemy_count = mod:get("ultra_panic_enemy_count")
	settings.ultra_panic_particle_keep_chance = mod:get("ultra_panic_particle_keep_chance")
	settings.ultra_panic_force_performance = mod:get("ultra_panic_force_performance")

	settings.boss_safe_mode = mod:get("boss_safe_mode")
	settings.mode_hotkey_enabled = mod:get("mode_hotkey_enabled")

	settings.default_mode = mod:get("default_mode")
	settings.force_cinematic_mode = mod:get("force_cinematic_mode")
	settings.force_performance_mode = mod:get("force_performance_mode")

	settings.enable_smart_mode = mod:get("enable_smart_mode")
	settings.smart_mode_fps_threshold = mod:get("smart_mode_fps_threshold")
	settings.smart_mode_restore_fps = mod:get("smart_mode_restore_fps")

	settings.auto_cinematic_when_calm = mod:get("auto_cinematic_when_calm")
	settings.calm_enemy_threshold = mod:get("calm_enemy_threshold")
	settings.calm_restore_delay = mod:get("calm_restore_delay")

	settings.auto_performance_in_hordes = mod:get("auto_performance_in_hordes")
	settings.horde_enemy_threshold = mod:get("horde_enemy_threshold")

	settings.enable_dynamic_resolution = mod:get("enable_dynamic_resolution")
	settings.dynamic_resolution_min_scale = mod:get("dynamic_resolution_min_scale")
	settings.dynamic_resolution_max_scale = mod:get("dynamic_resolution_max_scale")
	settings.dynamic_resolution_fps_floor = mod:get("dynamic_resolution_fps_floor")
	settings.dynamic_resolution_fps_target = mod:get("dynamic_resolution_fps_target")
end

local function debug_echo(...)
	if not settings.debug_enabled then
		return
	end

	local count = select("#", ...)
	if count == 0 then
		return
	end

	local text = tostring(select(1, ...))

	for i = 2, count do
		text = text .. " " .. tostring(select(i, ...))
	end

	mod:echo(text)
end

local function get_main_time()
	local time_manager = Managers and Managers.time
	if time_manager and time_manager.time then
		local ok, t = pcall(time_manager.time, time_manager, "main")
		if ok and type(t) == "number" then
			return t
		end
	end

	return os.clock()
end

local function mark_combat()
	last_combat_t = get_main_time()
end

local function get_local_player()
	local player_manager = Managers and Managers.player
	if not player_manager or not player_manager.local_player_safe then
		return nil
	end

	local ok, player = pcall(player_manager.local_player_safe, player_manager, 1)
	if ok then
		return player
	end

	return nil
end

local function get_player_unit()
	local player = get_local_player()
	if not player then
		return nil
	end

	local player_unit = player.player_unit

	if type(player_unit) == "function" then
		local ok, unit = pcall(player.player_unit, player)
		if ok then
			return unit
		end

		return nil
	end

	return player_unit
end

local function is_unit_alive(unit)
	if not unit then
		return false
	end

	if Unit and Unit.alive then
		local ok, alive = pcall(Unit.alive, unit)
		if ok then
			return alive
		end
	end

	return true
end

local function get_side_system()
	local extension_manager = Managers and Managers.state and Managers.state.extension
	if not extension_manager or not extension_manager.system then
		return nil
	end

	local ok, side_system = pcall(extension_manager.system, extension_manager, "side_system")
	if ok then
		return side_system
	end

	return nil
end

local function enemy_snapshot()
	local player_unit = get_player_unit()
	if not player_unit or not is_unit_alive(player_unit) then
		return 0, false
	end

	if not Unit or not Unit.world_position then
		return 0, false
	end

	local side_system = get_side_system()
	if not side_system or not side_system.get_enemy_units then
		return 0, false
	end

	local ok_player_pos, player_pos = pcall(Unit.world_position, player_unit, 1)
	if not ok_player_pos or not player_pos then
		return 0, false
	end

	local ok_enemy_units, enemy_units = pcall(side_system.get_enemy_units, side_system)
	if not ok_enemy_units or not enemy_units then
		return 0, false
	end

	local range_sq = settings.combat_range * settings.combat_range
	local count = 0
	local boss_present = false

	for i = 1, #enemy_units do
		local enemy_unit = enemy_units[i]

		if enemy_unit and is_unit_alive(enemy_unit) then
			local ok_enemy_pos, enemy_pos = pcall(Unit.world_position, enemy_unit, 1)

			if ok_enemy_pos and enemy_pos then
				local dx = enemy_pos.x - player_pos.x
				local dy = enemy_pos.y - player_pos.y
				local dz = enemy_pos.z - player_pos.z
				local dist_sq = dx * dx + dy * dy + dz * dz

				if dist_sq <= range_sq then
					count = count + 1

					if settings.boss_safe_mode and ScriptUnit and ScriptUnit.has_extension then
						local ok_health_has = pcall(ScriptUnit.has_extension, enemy_unit, "health_system")
						if ok_health_has then
							local ok_health_ext, health_ext = pcall(ScriptUnit.extension, enemy_unit, "health_system")
							if ok_health_ext and health_ext then
								local breed = rawget(health_ext, "_breed")
									or rawget(health_ext, "breed")
									or rawget(enemy_unit, "breed")

								if type(breed) == "table" then
									local tags = rawget(breed, "tags")
									if tags and (tags.monster or tags.captain or tags.chaos_ogryn or tags.daemonhost) then
										boss_present = true
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return count, boss_present
end

local function get_average_fps(dt)
	if not dt or dt <= 0 then
		return nil
	end

	local fps = 1 / dt
	fps_samples[#fps_samples + 1] = fps

	if #fps_samples > fps_sample_max then
		table.remove(fps_samples, 1)
	end

	local total = 0
	for i = 1, #fps_samples do
		total = total + fps_samples[i]
	end

	if #fps_samples == 0 then
		return nil
	end

	return total / #fps_samples
end

local function apply_mode_rules()
	if settings.force_performance_mode then
		cinematic_mode = false
		return
	end

	if settings.force_cinematic_mode then
		cinematic_mode = true
		return
	end

	if settings.default_mode == "performance" then
		cinematic_mode = false
	else
		cinematic_mode = true
	end
end

local function set_mode_echo()
	if not settings.combat_echo then
		return
	end

	local mode_text

	if ultra_panic_mode then
		mode_text = "SmoothTide Pro: Ultra Panic Mode"
	elseif not cinematic_mode then
		mode_text = "SmoothTide Pro: Performance Mode"
	elseif panic_mode then
		mode_text = "SmoothTide Pro: Panic Mode"
	elseif in_combat then
		mode_text = "SmoothTide Pro: Combat Mode"
	else
		mode_text = "SmoothTide Pro: Cinematic Mode"
	end

	if mode_text ~= last_mode_echo then
		last_mode_echo = mode_text
		mod:echo(mode_text)
	end
end

local function apply_dynamic_resolution(avg_fps)
	if not settings.enable_dynamic_resolution or not avg_fps then
		return
	end

	local render_settings = Application.user_setting and Application.user_setting("render_settings")
	if not render_settings then
		return
	end

	local min_scale = math_max(50, settings.dynamic_resolution_min_scale or 70)
	local max_scale = math_min(100, settings.dynamic_resolution_max_scale or 100)

	if min_scale > max_scale then
		min_scale = max_scale
	end

	local new_scale = current_resolution_scale

	if avg_fps < settings.dynamic_resolution_fps_floor then
		new_scale = math_max(min_scale, current_resolution_scale - 5)
	elseif avg_fps >= settings.dynamic_resolution_fps_target and not ultra_panic_mode and not panic_mode then
		new_scale = math_min(max_scale, current_resolution_scale + 5)
	end

	if new_scale ~= current_resolution_scale then
		current_resolution_scale = new_scale

		render_settings.render_scale = current_resolution_scale / 100
		render_settings.resolution_scale = current_resolution_scale / 100
		render_settings.dynamic_resolution = true

		if Application.apply_user_settings then
			pcall(Application.apply_user_settings)
		end

		debug_echo("SmoothTide dynamic resolution:", current_resolution_scale .. "%")
	end
end

local function update_state(dt)
	local t = get_main_time()
	local recent_combat = (t - last_combat_t) <= settings.combat_timeout
	local nearby_enemy_count, boss_present = enemy_snapshot()
	local avg_fps = get_average_fps(dt)

	in_combat = recent_combat or nearby_enemy_count > 0

	if settings.enable_ultra_panic_mode and not boss_present and nearby_enemy_count >= settings.ultra_panic_enemy_count then
		ultra_panic_mode = true
	else
		ultra_panic_mode = false
	end

	if settings.enable_panic_mode and not boss_present and nearby_enemy_count >= settings.panic_enemy_count then
		panic_mode = true
	else
		panic_mode = false
	end

	local horde_forces_performance = false
	if settings.auto_performance_in_hordes and not settings.force_cinematic_mode then
		horde_forces_performance = nearby_enemy_count >= settings.horde_enemy_threshold
	end

	local calm_now = nearby_enemy_count <= settings.calm_enemy_threshold and not recent_combat and not panic_mode and not ultra_panic_mode
	if calm_now then
		if calm_since_t == 0 then
			calm_since_t = t
		end
	else
		calm_since_t = 0
	end

	local calm_ready = calm_since_t > 0 and (t - calm_since_t) >= settings.calm_restore_delay

	if not settings.force_cinematic_mode and not settings.force_performance_mode and settings.enable_smart_mode and avg_fps then
		if avg_fps < settings.smart_mode_fps_threshold then
			cinematic_mode = false
		elseif avg_fps > settings.smart_mode_restore_fps and not ultra_panic_mode then
			if settings.default_mode == "performance" then
				cinematic_mode = false
			else
				cinematic_mode = true
			end
		end
	end

	if not settings.force_cinematic_mode and not settings.force_performance_mode then
		if horde_forces_performance then
			cinematic_mode = false
		elseif settings.auto_cinematic_when_calm and calm_ready then
			cinematic_mode = true
		end
	end

	if ultra_panic_mode and settings.ultra_panic_force_performance and not settings.force_cinematic_mode then
		cinematic_mode = false
	end

	if ultra_panic_mode then
		current_resolution_scale = math_max(settings.dynamic_resolution_min_scale or 70, current_resolution_scale - 10)
		apply_dynamic_resolution(avg_fps)
	else
		apply_dynamic_resolution(avg_fps)
	end

	set_mode_echo()
end

local function current_particle_keep_chance()
	if ultra_panic_mode then
		return settings.ultra_panic_particle_keep_chance
	end

	if not cinematic_mode then
		return math_min(settings.particle_keep_chance, settings.panic_particle_keep_chance)
	end

	if panic_mode then
		return settings.panic_particle_keep_chance
	end

	return settings.particle_keep_chance
end

local function should_hide_hit_indicators()
	if not enabled then
		return false
	end

	if ultra_panic_mode then
		return true
	end

	if not cinematic_mode then
		return true
	end

	if panic_mode and settings.panic_hide_hit_indicators then
		return true
	end

	return in_combat and settings.suppress_hit_indicators
end

local function should_hide_damage_overlay()
	if not enabled then
		return false
	end

	if ultra_panic_mode then
		return true
	end

	if not cinematic_mode then
		return true
	end

	if panic_mode and settings.panic_hide_damage_overlay then
		return true
	end

	return in_combat and settings.suppress_damage_overlay
end

function mod.toggle_smoothtide_mode_hotkey()
	if not settings.mode_hotkey_enabled then
		return
	end

	if settings.force_cinematic_mode or settings.force_performance_mode then
		mod:echo("SmoothTide: Mode locked in settings")
		return
	end

	cinematic_mode = not cinematic_mode
	panic_mode = false
	ultra_panic_mode = false
	last_mode_echo = nil
	set_mode_echo()
end

function mod.toggle_performance_mode_hotkey()
	if not settings.mode_hotkey_enabled then
		return
	end

	local current = mod:get("force_performance_mode")
	mod:set("force_performance_mode", not current, true)

	if not current then
		mod:set("force_cinematic_mode", false, true)
		mod:echo("SmoothTide: Performance Mode FORCED")
	else
		mod:echo("SmoothTide: Performance Mode OFF")
	end

	refresh_settings()
	apply_mode_rules()
	last_mode_echo = nil
	set_mode_echo()
end

function mod.toggle_cinematic_mode_hotkey()
	if not settings.mode_hotkey_enabled then
		return
	end

	local current = mod:get("force_cinematic_mode")
	mod:set("force_cinematic_mode", not current, true)

	if not current then
		mod:set("force_performance_mode", false, true)
		mod:echo("SmoothTide: Cinematic Mode FORCED")
	else
		mod:echo("SmoothTide: Cinematic Mode OFF")
	end

	refresh_settings()
	apply_mode_rules()
	last_mode_echo = nil
	set_mode_echo()
end

mod.on_enabled = function()
	enabled = true
	refresh_settings()
	apply_mode_rules()
	current_resolution_scale = settings.dynamic_resolution_max_scale or 100
end

mod.on_disabled = function()
	enabled = false
	in_combat = false
	panic_mode = false
	ultra_panic_mode = false
	fps_samples = {}
	calm_since_t = 0
	current_resolution_scale = 100
end

mod.on_all_mods_loaded = function()
	refresh_settings()
	apply_mode_rules()
end

mod.on_setting_changed = function(setting_id)
	refresh_settings()

	if setting_id == "force_cinematic_mode" and settings.force_cinematic_mode then
		mod:set("force_performance_mode", false, true)
		refresh_settings()
	elseif setting_id == "force_performance_mode" and settings.force_performance_mode then
		mod:set("force_cinematic_mode", false, true)
		refresh_settings()
	end

	if setting_id == "dynamic_resolution_min_scale" or setting_id == "dynamic_resolution_max_scale" then
		local min_scale = settings.dynamic_resolution_min_scale or 70
		local max_scale = settings.dynamic_resolution_max_scale or 100
		if current_resolution_scale < min_scale then
			current_resolution_scale = min_scale
		elseif current_resolution_scale > max_scale then
			current_resolution_scale = max_scale
		end
	end

	apply_mode_rules()
	debug_echo("SmoothTide setting changed:", setting_id, "=", mod:get(setting_id))
end

mod.update = function(dt)
	if not enabled then
		return
	end

	update_state(dt)
end

mod:hook_safe("AttackReportManager", "add_attack_result", function(...)
	if enabled then
		mark_combat()
	end
end)

mod:hook("HudElementHitIndicator", "_draw", function(func, self, dt, t, ui_renderer, render_settings, input_service)
	if should_hide_hit_indicators() then
		return
	end

	return func(self, dt, t, ui_renderer, render_settings, input_service)
end)

mod:hook("HudElementPlayerDamage", "_draw", function(func, self, dt, t, ui_renderer, render_settings, input_service)
	if should_hide_damage_overlay() then
		return
	end

	return func(self, dt, t, ui_renderer, render_settings, input_service)
end)

mod:hook("PlayerUnitFxExtension", "spawn_exclusive_particle", function(func, self, ...)
	if enabled and settings.particle_thinning and (in_combat or not cinematic_mode or panic_mode or ultra_panic_mode) then
		local keep_chance = current_particle_keep_chance()
		local keep_roll = math_random(1, 100)

		if keep_roll > math_max(1, keep_chance) then
			return
		end
	end

	return func(self, ...)
end)