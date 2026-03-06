local mod = get_mod("machine_gods_beacon")
local VERSION = "v2026.01.23.0258"

local DARKNESS_MUTATOR = "mutator_darkness_los"
local VENTILATION_MUTATOR = "mutator_ventilation_purge_los"
local TOXIC_GAS_MUTATOR = "mutator_toxic_gas_volumes"
local DARKNESS_THEME = "darkness"
local VENTILATION_THEME = "ventilation_purge"
local TOXIC_GAS_THEME = "toxic_gas"

local _state = mod:persistent_table("state", {
	is_darkness_mission = false,
	is_ventilation_mission = false,
	is_toxic_gas_mission = false,
	preserved_is_darkness = false,
	preserved_is_ventilation = false,
	preserved_is_toxic_gas = false,
	in_mission = false,
	hooks_called = {},
	original_themes = nil,
	original_slots = nil,
	original_slots_captured = false,
	original_weights_captured = false,
	bypass_hook = false,
	themes_blocked = false,
	light_groups_cache = {},
	original_extension_weights = {},
	intended_light_states = {},
	original_light_states = {},
	original_light_states_captured = false,
})

if not _state.flicker then
	_state.flicker = {}
end
if not _state.flicker.active_flickers then
	_state.flicker.active_flickers = {}
end
if not _state.flicker.cooldowns then
	_state.flicker.cooldowns = {}
end
if not _state.flicker.last_cycle_time then
	_state.flicker.last_cycle_time = 0
end
if not _state.flicker.stutter_state then
	_state.flicker.stutter_state = {}
end
if not _state.flicker.cascade_waves then
	_state.flicker.cascade_waves = {}
end
if not _state.flicker.cascade_next_time then
	_state.flicker.cascade_next_time = 0
end
if not _state.flicker.sorted_lights_cache then
	_state.flicker.sorted_lights_cache = nil
end
if not _state.flicker.last_sort_time then
	_state.flicker.last_sort_time = 0
end
if _state.original_slots == nil then
	_state.original_slots = nil
end
if _state.original_slots_captured == nil then
	_state.original_slots_captured = false
end
if _state.original_weights_captured == nil then
	_state.original_weights_captured = false
end
if _state.bypass_hook == nil then
	_state.bypass_hook = false
end
if _state.themes_blocked == nil then
	_state.themes_blocked = false
end

local _timer = 0
local _game_time = 0

local function log(fmt, ...)
	if mod:get("debug_mode") then
		mod:echo("[MGB] " .. string.format(fmt, ...))
	end
end

local function get_system(name)
	local ext = Managers.state and Managers.state.extension
	return ext and ext:system(name)
end

local function get_circumstance_template()
	local cm = Managers.state and Managers.state.circumstance
	return cm and cm.template and cm:template()
end

local function is_in_mission_or_training()
	if not Managers.state or not Managers.state.game_mode then
		return false
	end
	local gsm = Managers.state.game_mode
	local mode = gsm:game_mode_name()
	return mode == "coop_complete_objective" or mode == "training_grounds" or mode == "shooting_range"
end

local function update_mission_state()
	local template = get_circumstance_template()
	if not template then
		return
	end
	local theme = template.theme_tag
	_state.is_darkness_mission = theme == DARKNESS_THEME
	_state.is_ventilation_mission = theme == VENTILATION_THEME
	_state.is_toxic_gas_mission = theme == TOXIC_GAS_THEME
	_state.current_theme_tag = theme
	if template.mutators then
		for _, mutator in pairs(template.mutators) do
			if mutator == DARKNESS_MUTATOR then
				_state.is_darkness_mission = true
			end
			if mutator == VENTILATION_MUTATOR then
				_state.is_ventilation_mission = true
			end
			if mutator == TOXIC_GAS_MUTATOR then
				_state.is_toxic_gas_mission = true
			end
		end
	end
end

local function is_special_mission()
	return _state.is_darkness_mission or _state.is_ventilation_mission or _state.is_toxic_gas_mission or _state.preserved_is_darkness or _state.preserved_is_ventilation or _state.preserved_is_toxic_gas
end

local function should_block_environment()
	local mode = mod:get("environment_control_mode")
	if mode == "none" then
		return false
	end
	if mode == "all" then
		return true
	end
	if mode == "normal" then
		return not is_special_mission()
	end
	if mode == "modified" then
		return is_special_mission()
	end
	return false
end

local should_block_darkness = should_block_environment
local should_block_fog = should_block_environment
local should_apply_fog_darkness = should_block_environment

local function should_apply_lighting()
	local mode = mod:get("light_control_mode")
	if mode == "none" then
		return false
	end
	if mode == "all" then
		return true
	end
	if mode == "normal" then
		return not is_special_mission()
	end
	if mode == "modified" then
		return is_special_mission()
	end
	return false
end

local function should_block_shading(name)
	if not name then
		return false
	end
	local n = string.lower(name)
	if _state.is_darkness_mission and should_block_environment() then
		if string.find(n, "dark") then
			return true
		end
	end
	if _state.is_ventilation_mission and should_block_environment() then
		if string.find(n, "fog") or string.find(n, "vent") then
			return true
		end
	end
	if _state.is_toxic_gas_mission and should_block_environment() then
		if string.find(n, "fog") or string.find(n, "toxic") or string.find(n, "gas") then
			return true
		end
	end
	return false
end

local function should_block_themes_early()
	local enabled = mod:get("block_themes_early")
	if enabled == nil then
		return true
	end
	return enabled
end

local function get_intended_light_states_count()
	local count = 0
	for _ in pairs(_state.intended_light_states) do
		count = count + 1
	end
	return count
end

local function should_block_in_hook()
	if not mod:is_enabled() then
		return false
	end
	if _state.bypass_hook then
		return false
	end
	if not should_block_environment() then
		return false
	end
	if not is_special_mission() then
		return false
	end
	return true
end

local function get_light_percentage()
	local pct = mod:get("light_percentage") or 33
	return pct / 100
end

local function get_light_state()
	return mod:get("light_state") or "flicker_random"
end

local function get_flicker_default()
	return mod:get("flicker_default") or "on"
end

local function get_flicker_interval()
	return mod:get("flicker_interval") or 5.0
end

local function get_flicker_duration()
	return mod:get("flicker_duration") or 0.5
end

local function get_flicker_cooldown()
	return mod:get("flicker_cooldown") or 3.0
end

local function get_flicker_percentage()
	local pct = mod:get("flicker_percentage") or 33
	return pct / 100
end

local function get_flicker_time()
	return _game_time
end

local function is_flicker_mode()
	local state = get_light_state()
	return state == "flicker" or state == "flicker_cascade" or state == "flicker_random"
end

local MGB = {
	state = _state,
	log = log,
	get_system = get_system,
	get_circumstance_template = get_circumstance_template,
	is_in_mission_or_training = is_in_mission_or_training,
	update_mission_state = update_mission_state,
	should_block_environment = should_block_environment,
	should_block_darkness = should_block_darkness,
	should_block_fog = should_block_fog,
	is_special_mission = is_special_mission,
	should_apply_fog_darkness = should_apply_fog_darkness,
	should_apply_lighting = should_apply_lighting,
	should_block_in_hook = should_block_in_hook,
	should_block_shading = should_block_shading,
	should_block_themes_early = should_block_themes_early,
	get_intended_light_states_count = get_intended_light_states_count,
	get_light_percentage = get_light_percentage,
	get_light_state = get_light_state,
	get_flicker_default = get_flicker_default,
	get_flicker_interval = get_flicker_interval,
	get_flicker_duration = get_flicker_duration,
	get_flicker_cooldown = get_flicker_cooldown,
	get_flicker_percentage = get_flicker_percentage,
	get_flicker_time = get_flicker_time,
	is_flicker_mode = is_flicker_mode,
}

mod._mgb = MGB

local mgb_environment = mod:io_dofile("machine_gods_beacon/scripts/mods/machine_gods_beacon/mgb_environment")
local mgb_lights = mod:io_dofile("machine_gods_beacon/scripts/mods/machine_gods_beacon/mgb_lights")

MGB.env = mgb_environment
MGB.lights = mgb_lights

mod:hook_safe(CLASS.MutatorHandler, "activate_mutator", function(self, mutator_name)
	_state.hooks_called["MutatorHandler.activate_mutator"] = true
	if mutator_name == DARKNESS_MUTATOR then
		_state.is_darkness_mission = true
		log("mutator: darkness detected")
	end
	if mutator_name == VENTILATION_MUTATOR then
		_state.is_ventilation_mission = true
		log("mutator: ventilation detected")
	end
	if mutator_name == TOXIC_GAS_MUTATOR then
		_state.is_toxic_gas_mission = true
		log("mutator: toxic_gas detected")
	end
end)

local function reset_state()
	_state.is_darkness_mission = false
	_state.is_ventilation_mission = false
	_state.is_toxic_gas_mission = false
	_state.in_mission = false
	_state.original_themes = nil
	_state.original_slots = nil
	_state.original_slots_captured = false
	_state.original_weights_captured = false
	_state.bypass_hook = false
	_state.themes_blocked = false
	_state.hooks_called = {}
	_state.original_extension_weights = {}
	_state.intended_light_states = {}
	_state.original_light_states = {}
	_state.original_light_states_captured = false

	_state.flicker.active_flickers = {}
	_state.flicker.cooldowns = {}
	_state.flicker.last_cycle_time = 0
	_state.flicker.stutter_state = {}
	_state.flicker.cascade_waves = {}
	_state.flicker.cascade_next_time = 0
	_state.flicker.sorted_lights_cache = nil
	_state.flicker.last_sort_time = 0
end

mod:hook_safe(CLASS.GameModeManager, "init", function(self)
	_state.hooks_called["GameModeManager.init"] = true
	reset_state()
	_state.in_mission = true
	update_mission_state()
	log("GameModeManager.init dark=%s vent=%s toxic=%s", tostring(_state.is_darkness_mission), tostring(_state.is_ventilation_mission), tostring(_state.is_toxic_gas_mission))

	if not mod:is_enabled() then
		return
	end

	if should_block_environment() then
		log("auto-applying environment settings")
		mgb_environment.apply_settings()
	end
	if should_apply_lighting() then
		log("auto-applying lighting settings")
		mgb_lights.apply_settings()
	end
end)

mod:hook_safe(CLASS.GameModeManager, "destroy", function(self)
	_state.hooks_called["GameModeManager.destroy"] = true
	log("GameModeManager.destroy")
	reset_state()
end)

mod:hook_safe(CLASS.GameModeManager, "complete_game_mode", function(self)
	_state.hooks_called["GameModeManager.complete_game_mode"] = true
	reset_state()
end)

mod:hook_safe(CLASS.GameModeManager, "fail_game_mode", function(self)
	_state.hooks_called["GameModeManager.fail_game_mode"] = true
	reset_state()
end)

mod:hook_safe(CLASS.GameModeManager, "game_mode_ready", function(self)
	_state.hooks_called["GameModeManager.game_mode_ready"] = true
	update_mission_state()
	log("game_mode_ready: dark=%s vent=%s toxic=%s theme=%s", tostring(_state.is_darkness_mission), tostring(_state.is_ventilation_mission), tostring(_state.is_toxic_gas_mission), _state.current_theme_tag or "default")
end)

mod:hook_safe(CLASS.ShadingEnvironmentSystem, "on_gameplay_post_init", function(self, level, themes)
	_state.hooks_called["ShadingEnvironmentSystem.on_gameplay_post_init"] = true
	if themes and #themes > 0 and not _state.original_themes then
		_state.original_themes = themes
		log("captured original_themes count=%d", #themes)
	end
end)

local function get_status_info()
	return {
		version = VERSION,
		mission = _state.in_mission,
		dark = _state.is_darkness_mission,
		vent = _state.is_ventilation_mission,
		toxic = _state.is_toxic_gas_mission,
		theme_tag = _state.current_theme_tag,
		env_mode = mod:get("environment_control_mode"),
		light_mode = mod:get("light_control_mode"),
		should_block = should_block_environment(),
		should_light = should_apply_lighting(),
		light_pct = mod:get("light_percentage"),
		light_selection = mod:get("light_selection"),
		light_state = mod:get("light_state"),
		lights_count = table.size(_state.intended_light_states or {}),
		env_blocked = _state.environment_blocked,
		themes_blocked = _state.themes_blocked,
		has_themes = _state.original_themes ~= nil and #(_state.original_themes or {}) > 0,
		themes_count = _state.original_themes and #_state.original_themes or 0,
	}
end

local function get_hooks_list()
	local hooks = {}
	for name, _ in pairs(_state.hooks_called) do
		table.insert(hooks, name)
	end
	table.sort(hooks)
	return hooks
end

-- mod:command("mgb_core", "MGB core diagnostics", function(cmd, ...)
-- 	log("[i] mgb_core %s", cmd or "status")
-- 	if cmd == "status" or not cmd then
-- 		local info = get_status_info()
-- 		mod:echo("[MGB] === Core Status ===")
-- 		mod:echo("version: %s", info.version)
-- 		mod:echo("mission: %s | dark: %s | vent: %s | toxic: %s", tostring(info.mission), tostring(info.dark), tostring(info.vent), tostring(info.toxic))
-- 		mod:echo("theme_tag: %s", info.theme_tag or "default")
-- 		mod:echo("env_mode: %s | light_mode: %s", info.env_mode, info.light_mode)
-- 		mod:echo("should_block: %s | should_light: %s", tostring(info.should_block), tostring(info.should_light))
-- 		mod:echo("light: pct=%d sel=%s state=%s", info.light_pct, info.light_selection, info.light_state)
-- 		mod:echo("data: lights=%d themes=%d themes_blocked=%s", info.lights_count, info.themes_count, tostring(info.themes_blocked))
-- 	elseif cmd == "hooks" then
-- 		local hooks = get_hooks_list()
-- 		mod:echo("[MGB] === Hooks Called (%d) ===", #hooks)
-- 		for _, name in ipairs(hooks) do
-- 			mod:echo("  %s", name)
-- 		end
-- 	elseif cmd == "reset" then
-- 		reset_state()
-- 		_state.in_mission = is_in_mission_or_training()
-- 		update_mission_state()
-- 		mod:echo("[MGB] state reset")
-- 	elseif cmd == "apply" then
-- 		update_mission_state()
-- 		mgb_environment.apply_settings()
-- 		mgb_lights.apply_settings()
-- 		mod:echo("[MGB] settings applied")
-- 	elseif cmd == "revert" then
-- 		mgb_environment.revert_settings()
-- 		mgb_lights.revert_settings()
-- 		mod:echo("[MGB] settings reverted")
-- 	elseif cmd == "help" then
-- 		mod:echo("[MGB] mgb_core commands: status, hooks, reset, apply, revert, help")
-- 	else
-- 		mod:echo("[MGB] unknown command: %s (try 'help')", cmd)
-- 	end
-- end)

local function on_setting_changed(id)
	if not mod:is_enabled() then
		return
	end
	if not _state.in_mission then
		return
	end

	log("setting changed: %s", id)

	if id == "environment_control_mode" then
		if should_block_environment() then
			mgb_environment.apply_settings()
		else
			mgb_environment.revert_settings()
		end
	end

	if id == "light_control_mode" then
		if should_apply_lighting() then
			mgb_lights.apply_settings()
		else
			mgb_lights.revert_settings()
		end
	end

	if id == "light_percentage" or id == "light_selection" or id == "light_state" then
		if should_apply_lighting() then
			mgb_lights.apply_settings()
		end
	end
end

mod.on_setting_changed = on_setting_changed

local function update(dt)
	if not mod:is_enabled() then
		return
	end
	if not _state.in_mission then
		return
	end

	_timer = _timer + dt
	_game_time = _game_time + dt

	if _timer > 2 then
		_timer = 0
		if not is_special_mission() then
			update_mission_state()
		end

		if _state.themes_blocked then
			mgb_environment.clear_shading_fog()
		end
	end

	if should_apply_lighting() and is_special_mission() and should_apply_fog_darkness() then
		if is_flicker_mode() then
			mgb_lights.update_flicker(_game_time)
		end
	end
end

mod.update = update

mod.on_disabled = function(initial_call)
	if initial_call then
		return
	end
	log("mod disabled, reverting settings")
	if _state.in_mission then
		mgb_environment.revert_settings()
		mgb_lights.revert_settings()
	end
end

mod.on_enabled = function(initial_call)
	if initial_call then
		return
	end
	log("mod enabled")
	if _state.in_mission then
		if should_block_environment() then
			mgb_environment.apply_settings()
		end
		if should_apply_lighting() then
			mgb_lights.apply_settings()
		end
	end
end
