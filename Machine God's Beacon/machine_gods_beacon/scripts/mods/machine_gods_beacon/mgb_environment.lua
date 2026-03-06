local mod = get_mod("machine_gods_beacon")
local VERSION = "v2026.01.26.0100"

local mgb_environment = {}
mgb_environment._version = VERSION

local _original_shading_environment_slots = nil
local _original_light_groups = nil
local _original_level_resource_dependency_packages = nil

local _default_slots_cache = {}
local _current_level_name = nil
local _current_theme_tag = nil
local _capturing_defaults = false

local function get_MGB()
	return mod._mgb
end

local function is_special_theme_tag(theme_tag)
	return theme_tag == "darkness" or theme_tag == "ventilation_purge" or theme_tag == "toxic_gas"
end

local function clear_preserved_flags()
	local MGB = get_MGB()
	if not MGB or not MGB.state then
		return
	end
	local state = MGB.state
	state.preserved_is_darkness = false
	state.preserved_is_ventilation = false
	state.preserved_is_toxic_gas = false
end

local function store_extension_state(unit, ext)
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	if state.original_extension_weights[unit] then
		return
	end
	state.original_extension_weights[unit] = {
		base_weight = ext._base_weight,
		current_weight = ext._current_weight,
		enabled = ext._enabled,
		name = ext._shading_environment_resource_name,
	}
	state.original_weights_captured = true
end

local function restore_all_extensions()
	local MGB = get_MGB()
	if not MGB then
		return 0
	end
	local state = MGB.state
	local sys = MGB.get_system("shading_environment_system")
	if not sys or not sys._unit_to_extension_map then
		return 0
	end
	local restored = 0
	for unit, ext in pairs(sys._unit_to_extension_map) do
		local orig = state.original_extension_weights[unit]
		if orig then
			if orig.base_weight then
				ext._base_weight = orig.base_weight
			end
			if orig.current_weight then
				ext._current_weight = orig.current_weight
			end
			if orig.enabled then
				ext._enabled = true
				if ext.enable then
					pcall(function()
						ext:enable()
					end)
				end
			end
			restored = restored + 1
		end
	end
	return restored
end

local function capture_all_extensions()
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	local sys = MGB.get_system("shading_environment_system")
	if not sys or not sys._unit_to_extension_map then
		return
	end
	for unit, ext in pairs(sys._unit_to_extension_map) do
		store_extension_state(unit, ext)
	end
end

local function kill_darkness()
	if not Managers.state or not Managers.state.extension then
		return false
	end
	local ds = Managers.state.extension:system("darkness_system")
	if not ds then
		return false
	end
	if ds._global_darkness ~= nil then
		ds._global_darkness = false
	end
	if ds._in_darkness ~= nil then
		ds._in_darkness = false
	end
	if ds._num_volumes ~= nil then
		ds._num_volumes = 0
	end
	if ds._player_unit_darkness_data then
		for unit, data in pairs(ds._player_unit_darkness_data) do
			if type(data) == "table" then
				for k, v in pairs(data) do
					if type(v) == "boolean" then
						data[k] = false
					elseif type(v) == "number" then
						data[k] = 0
					end
				end
			end
		end
	end
	return true
end

local function should_block_extension_by_slot(ext)
	local MGB = get_MGB()
	if not MGB then
		return false
	end
	local state = MGB.state
	local slot = ext._slot
	if not slot or slot < 0 then
		return false
	end
	if not state.original_slots or not state.original_slots[slot] then
		return false
	end
	local slot_path = state.original_slots[slot]
	return MGB.should_block_shading(slot_path)
end

local function kill_extensions_by_slot()
	local MGB = get_MGB()
	if not MGB then
		return 0
	end
	local sys = MGB.get_system("shading_environment_system")
	if not sys or not sys._unit_to_extension_map then
		return 0
	end
	local killed = 0
	for unit, ext in pairs(sys._unit_to_extension_map) do
		if should_block_extension_by_slot(ext) then
			if ext._base_weight then
				ext._base_weight = 0
			end
			if ext._current_weight then
				ext._current_weight = 0
			end
			if ext._enabled then
				ext._enabled = false
				if ext.disable then
					pcall(function()
						ext:disable()
					end)
				end
			end
			killed = killed + 1
		end
	end
	return killed
end

function mgb_environment.kill_by_classification(classification)
	local MGB = get_MGB()
	if not MGB then
		return 0
	end
	local sys = MGB.get_system("shading_environment_system")
	if not sys or not sys._unit_to_extension_map then
		return 0
	end
	local killed = 0
	for unit, ext in pairs(sys._unit_to_extension_map) do
		local name = ext._shading_environment_resource_name
		if name then
			local n = string.lower(name)
			local match = false
			if classification == "vent_purge" then
				match = string.find(n, "vent") or string.find(n, "fog")
			elseif classification == "lights_out" then
				match = string.find(n, "dark")
			elseif classification == "toxic_gas" then
				-- match = string.find(n, "fog") or string.find(n, "toxic") or string.find(n, "gas")
			end
			if match then
				store_extension_state(unit, ext)
				if ext._base_weight then
					ext._base_weight = 0
				end
				if ext._current_weight then
					ext._current_weight = 0
				end
				if ext._enabled then
					ext._enabled = false
				end
				killed = killed + 1
			end
		end
	end
	return killed
end

function mgb_environment.clear_shading_fog()
	local MGB = get_MGB()
	if not MGB then
		return false
	end
	pcall(function()
		local world = Managers.world:world("level_world")
		if not world then
			return
		end
		local viewport_name = "player_1"
		local viewport = ScriptWorld.viewport(world, viewport_name)
		if not viewport then
			return
		end
		local shading_env = Viewport.get_data(viewport, "shading_environment")
		if not shading_env then
			return
		end
		ShadingEnvironment.set_scalar(shading_env, "height_fog_enabled", 0)
		ShadingEnvironment.set_scalar(shading_env, "height_fog_extinction", 0)
		ShadingEnvironment.set_scalar(shading_env, "volumetric_extinction_scale", 0)
		ShadingEnvironment.set_scalar(shading_env, "volumetric_fog_enabled", 0)
		ShadingEnvironment.apply(shading_env)
	end)
	return true
end

function mgb_environment.force_capture_all_slots()
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state
	if state.original_slots_captured then
		return
	end
	local sys = MGB.get_system("shading_environment_system")
	if not sys or not sys._theme_shading_environment_slots then
		return
	end
	local slots = sys._theme_shading_environment_slots
	if table.size(slots) > 0 then
		state.original_slots = {}
		for slot_id, env_name in pairs(slots) do
			state.original_slots[slot_id] = env_name
		end
		state.original_slots_captured = true
		MGB.log("captured %d theme slots", table.size(state.original_slots))
	end
	capture_all_extensions()
end

local function capture_default_slots_for_level(level_name)
	if _default_slots_cache[level_name] then
		return _default_slots_cache[level_name]
	end

	if not _original_level_resource_dependency_packages then
		_default_slots_cache[level_name] = {}
		return {}
	end

	local MGB = get_MGB()
	if MGB then
		MGB.log("capturing default slots for level: %s", level_name)
	end

	_capturing_defaults = true

	local ok, default_packages = pcall(function()
		return _original_level_resource_dependency_packages(level_name, "default")
	end)

	_capturing_defaults = false

	if not ok or not default_packages or #default_packages == 0 then
		if MGB then
			MGB.log("no default packages found for %s", level_name)
		end
		_default_slots_cache[level_name] = {}
		return {}
	end

	local world = nil
	pcall(function()
		world = Managers.world:world("level_world")
	end)

	if not world then
		if MGB then
			MGB.log("no world available for default slot capture")
		end
		_default_slots_cache[level_name] = {}
		return {}
	end

	local default_slots = {}

	for _, pkg_name in ipairs(default_packages) do
		local theme_ok, theme = pcall(function()
			return World.create_theme(world, pkg_name)
		end)

		if theme_ok and theme then
			local slots_ok, slots_info = pcall(function()
				return _original_shading_environment_slots(theme)
			end)

			if slots_ok and slots_info then
				for _, slot_info in ipairs(slots_info) do
					default_slots[slot_info.slot_id] = slot_info.shading_environment_name
					if MGB then
						MGB.log("  default slot[%d] = %s", slot_info.slot_id, slot_info.shading_environment_name)
					end
				end
			end

			pcall(function()
				World.destroy_theme(world, theme)
			end)
		end
	end

	_default_slots_cache[level_name] = default_slots

	if MGB then
		MGB.log("cached %d default slots for %s", table.size(default_slots), level_name)
	end

	return default_slots
end

local function filter_slots_to_default(slots_info, default_slots, level_name)
	if not slots_info or #slots_info == 0 then
		return slots_info
	end

	if not default_slots or table.size(default_slots) == 0 then
		return {}
	end

	local MGB = get_MGB()
	local filtered = {}

	for _, slot_info in ipairs(slots_info) do
		local slot_id = slot_info.slot_id
		local env_name = slot_info.shading_environment_name
		local default_env = default_slots[slot_id]

		if default_env then
			local modified_slot = {slot_id = slot_id, shading_environment_name = default_env}
			table.insert(filtered, modified_slot)
			if env_name ~= default_env and MGB then
				MGB.log("slot[%d]: replaced %s -> %s", slot_id, env_name, default_env)
			end
		else
			if MGB then
				MGB.log("slot[%d]: blocked %s (not in default)", slot_id, env_name)
			end
		end
	end

	return filtered
end

local function should_block_themes()
	local MGB = get_MGB()
	if not MGB then
		return false
	end
	if not MGB.is_in_mission_or_training then
		return false
	end
	if not MGB.is_in_mission_or_training() then
		return false
	end

	local state = MGB.state
	if not state then
		return false
	end

	local is_special = state.is_darkness_mission or state.is_ventilation_mission or state.is_toxic_gas_mission
	local is_preserved = state.preserved_is_darkness or state.preserved_is_ventilation or state.preserved_is_toxic_gas

	if not is_special and not is_preserved then
		return false
	end

	if not MGB.should_block_themes_early or not MGB.should_block_themes_early() then
		return false
	end

	local block_darkness = (state.is_darkness_mission or state.preserved_is_darkness) and MGB.should_block_darkness and MGB.should_block_darkness()
	local block_fog = (state.is_ventilation_mission or state.is_toxic_gas_mission or state.preserved_is_ventilation or state.preserved_is_toxic_gas) and MGB.should_block_fog and MGB.should_block_fog()

	return block_darkness or block_fog
end

local function is_theme_override(ext, sys)
	if not ext or not sys then
		return false
	end
	local slot = ext._slot
	if not slot or slot < 0 then
		return false
	end
	local theme_env = sys._theme_shading_environment_slots and sys._theme_shading_environment_slots[slot]
	local ext_default = ext._shading_environment_resource_name_default
	if theme_env and ext_default then
		if theme_env ~= ext_default then
			return true, theme_env, ext_default
		end
	end
	return false
end

function mgb_environment.apply_settings()
	local MGB = get_MGB()
	if not MGB then
		return
	end
	local state = MGB.state

	MGB.update_mission_state()
	mgb_environment.force_capture_all_slots()

	local block = MGB.should_block_darkness() or MGB.should_block_fog()

	MGB.log("apply_settings: in_mission=%s special=%s dark=%s vent=%s toxic=%s block=%s", tostring(state.in_mission), tostring(MGB.is_special_mission()), tostring(state.is_darkness_mission), tostring(state.is_ventilation_mission),
	        tostring(state.is_toxic_gas_mission), tostring(block))

	if not state.in_mission then
		return
	end
	if not MGB.is_special_mission() then
		return
	end
	if not MGB.should_apply_fog_darkness() then
		MGB.log("apply_settings: should_apply_fog_darkness=false")
		return
	end

	local sys = MGB.get_system("shading_environment_system")

	if not sys then
		MGB.log("apply_settings: no shading system")
		return
	end

	if block then
		local killed_slots = kill_extensions_by_slot()
		MGB.log("apply_settings: killed %d extensions by slot", killed_slots)

		if state.is_darkness_mission then
			local killed_dark = mgb_environment.kill_by_classification("lights_out")
			MGB.log("apply_settings: killed %d darkness extensions", killed_dark)
			kill_darkness()
		end

		if state.is_ventilation_mission then
			local killed_vent = mgb_environment.kill_by_classification("vent_purge")
			MGB.log("apply_settings: killed %d ventilation extensions", killed_vent)
		end

		if state.is_toxic_gas_mission then
			local killed_toxic = mgb_environment.kill_by_classification("toxic_gas")
			MGB.log("apply_settings: killed %d toxic gas extensions", killed_toxic)
		end

		mgb_environment.clear_shading_fog()

		local unit_to_extension_map = sys._unit_to_extension_map
		if unit_to_extension_map then
			local killed = 0
			for unit, ext in pairs(unit_to_extension_map) do
				local is_override, theme_env, ext_default = is_theme_override(ext, sys)
				if is_override then
					store_extension_state(unit, ext)
					ext._base_weight = 0
					ext._current_weight = 0
					ext._enabled = false
					MGB.log("  killed slot[%d]: theme=%s default=%s", ext._slot or -1, theme_env or "nil", ext_default or "nil")
					killed = killed + 1
				end
			end
			MGB.log("apply_settings: killed %d theme override extensions", killed)
		end
	else
		local restored = restore_all_extensions()
		MGB.log("apply_settings: restored %d extensions", restored)
	end
end

function mgb_environment.on_setting_changed(setting_id)
	local MGB = get_MGB()
	if not MGB then
		return
	end

	MGB.log("setting changed: %s", setting_id or "unknown")

	if setting_id == "block_themes_early" then
		return
	end

	mgb_environment.apply_settings()
end

function mgb_environment.restore_all()
	local MGB = get_MGB()
	if not MGB then
		return
	end

	MGB.log("restore_all called")

	local restored = restore_all_extensions()
	MGB.log("restored %d extensions", restored)

	local state = MGB.state
	state.original_extension_weights = {}
	state.original_weights_captured = false
	state.original_slots = nil
	state.original_slots_captured = false
end

function mgb_environment.revert_settings()
	local MGB = get_MGB()
	if not MGB then
		return
	end

	MGB.log("revert_settings called")
	mgb_environment.restore_all()
end

function mgb_environment.get_status()
	local MGB = get_MGB()
	if not MGB then
		return {error = "MGB not initialized"}
	end

	local state = MGB.state
	local sys = MGB.get_system("shading_environment_system")

	local ext_count = 0
	local theme_slot_count = 0
	local override_count = 0

	if sys then
		if sys._unit_to_extension_map then
			ext_count = table.size(sys._unit_to_extension_map)
		end
		if sys._theme_shading_environment_slots then
			theme_slot_count = table.size(sys._theme_shading_environment_slots)
			for unit, ext in pairs(sys._unit_to_extension_map or {}) do
				if is_theme_override(ext, sys) then
					override_count = override_count + 1
				end
			end
		end
	end

	return {
		version = mgb_environment._version,
		in_mission = state.in_mission,
		is_darkness = state.is_darkness_mission,
		is_ventilation = state.is_ventilation_mission,
		is_toxic_gas = state.is_toxic_gas_mission,
		preserved_darkness = state.preserved_is_darkness,
		preserved_ventilation = state.preserved_is_ventilation,
		preserved_toxic_gas = state.preserved_is_toxic_gas,
		current_level = _current_level_name,
		current_theme_tag = _current_theme_tag,
		extension_count = ext_count,
		theme_slot_count = theme_slot_count,
		override_count = override_count,
		original_slots_captured = state.original_slots_captured,
		original_weights_captured = state.original_weights_captured,
		cached_default_levels = table.size(_default_slots_cache),
		shading_intercepted = _original_shading_environment_slots ~= nil,
		lights_intercepted = _original_light_groups ~= nil,
		hooks_called = state.hooks_called,
	}
end

function mgb_environment.clear_cache()
	table.clear(_default_slots_cache)
	clear_preserved_flags()
	local MGB = get_MGB()
	if MGB then
		MGB.log("default slots cache cleared")
	end
end

mod:hook_safe(CLASS.ShadingEnvironmentSystem, "on_theme_changed", function(self, themes, force_reset)
	local MGB = get_MGB()
	local state = MGB and MGB.state

	if state then
		state.hooks_called["ShadingEnvironmentSystem.on_theme_changed"] = true
	end

	if not MGB or not MGB.is_in_mission_or_training() then
		return
	end

	if not MGB.is_special_mission() then
		return
	end

	if MGB.should_block_themes_early and MGB.should_block_themes_early() then
		MGB.log("on_theme_changed: early blocking active, slots already filtered")
	end
end)

mod:hook(CLASS.ShadingEnvironmentSystem, "_fetch_theme_shading_environments", function(func, self, themes, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state

	if state then
		state.hooks_called["ShadingEnvironmentSystem._fetch_theme_shading_environments"] = true
	end

	if not MGB or not MGB.is_in_mission_or_training() then
		return func(self, themes, ...)
	end

	if not MGB.is_special_mission() then
		return func(self, themes, ...)
	end

	if MGB.should_block_themes_early and MGB.should_block_themes_early() then
		MGB.log("_fetch_theme_shading_environments: early blocking, Theme API already filtered")
	end

	return func(self, themes, ...)
end)

mod:hook(CLASS.ShadingEnvironmentSystem, "theme_environment_from_slot", function(func, self, slot_id, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state

	if state then
		state.hooks_called["ShadingEnvironmentSystem.theme_environment_from_slot"] = true
	end

	if not MGB or not MGB.is_in_mission_or_training() then
		return func(self, slot_id, ...)
	end

	if not MGB.is_special_mission() then
		return func(self, slot_id, ...)
	end

	if not MGB.should_block_in_hook or not MGB.should_block_in_hook() then
		return func(self, slot_id, ...)
	end

	local env_name = self._theme_shading_environment_slots and self._theme_shading_environment_slots[slot_id]
	if env_name and MGB.should_block_shading(env_name) then
		MGB.log("theme_environment_from_slot: blocked slot %d (%s)", slot_id, env_name)
		return nil
	end

	return func(self, slot_id, ...)
end)

mod:hook(CLASS.ShadingEnvironmentExtension, "setup_theme", function(func, self, shading_env_system, force_reset, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state

	if state then
		state.hooks_called["ShadingEnvironmentExtension.setup_theme"] = true
	end

	if state and state.bypass_hook then
		return func(self, shading_env_system, force_reset, ...)
	end
	if not MGB or not MGB.is_in_mission_or_training() then
		return func(self, shading_env_system, force_reset, ...)
	end
	if not MGB.should_block_in_hook() then
		return func(self, shading_env_system, force_reset, ...)
	end

	if should_block_extension_by_slot(self) then
		MGB.log("hook: setup_theme blocked slot %d", self._slot or -1)
		return
	end
	return func(self, shading_env_system, force_reset, ...)
end)

mod:hook(CLASS.ShadingEnvironmentExtension, "enable", function(func, self, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["ShadingEnvironmentExtension.enable"] = true
	end

	if state and state.bypass_hook then
		return func(self, ...)
	end

	if not MGB or not MGB.is_in_mission_or_training() then
		return func(self, ...)
	end
	if not MGB.should_block_in_hook() then
		return func(self, ...)
	end

	local name = self._shading_environment_resource_name
	if name and MGB.should_block_shading(name) then
		MGB.log("hook: enable blocked (name): %s", name)
		return
	end

	if should_block_extension_by_slot(self) then
		MGB.log("hook: enable blocked (slot): %d", self._slot or -1)
		return
	end

	return func(self, ...)
end)

mod:hook_safe(CLASS.DarknessSystem, "init", function(self, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["DarknessSystem.init"] = true
	end
end)

mod:hook(CLASS.DarknessSystem, "update", function(func, self, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["DarknessSystem.update"] = true
	end
	if MGB and MGB.is_in_mission_or_training() and MGB.is_special_mission() and MGB.should_block_in_hook() then
		if MGB.should_block_darkness() or MGB.should_block_fog() then
			return
		end
	end
	return func(self, ...)
end)

mod:hook(CLASS.DarknessSystem, "is_in_darkness_volume", function(func, self, position, ...)
	local MGB = get_MGB()
	if MGB and MGB.is_in_mission_or_training() and MGB.is_special_mission() and MGB.should_block_in_hook() then
		if MGB.should_block_darkness() or MGB.should_block_fog() then
			return false
		end
	end
	return func(self, position, ...)
end)

mod:hook(CLASS.DarknessSystem, "set_global_darkness", function(func, self, set, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state
	if state then
		state.hooks_called["DarknessSystem.set_global_darkness"] = true
	end
	if MGB and MGB.is_in_mission_or_training() and MGB.is_special_mission() and MGB.should_block_in_hook() and set then
		if MGB.should_block_darkness() or MGB.should_block_fog() then
			return func(self, false, ...)
		end
	end
	return func(self, set, ...)
end)

mod:hook(CLASS.LevelLoader, "start_loading", function(func, self, context, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state

	if state then
		state.hooks_called["LevelLoader.start_loading"] = true
	end

	clear_preserved_flags()

	if not mod:is_enabled() then
		return func(self, context, ...)
	end

	local circumstance_name = context and context.circumstance_name
	local level_name = context and context.level_name

	_current_level_name = level_name

	if circumstance_name then
		local c = string.lower(circumstance_name)
		if string.find(c, "darkness") then
			if state then
				state.is_darkness_mission = true
				state.preserved_is_darkness = true
			end
			_current_theme_tag = "darkness"
			if MGB then
				MGB.log("LevelLoader: detected darkness from circumstance %s", circumstance_name)
			end
		end
		if string.find(c, "ventilation") or string.find(c, "purge") then
			if state then
				state.is_ventilation_mission = true
				state.preserved_is_ventilation = true
			end
			_current_theme_tag = "ventilation_purge"
			if MGB then
				MGB.log("LevelLoader: detected ventilation from circumstance %s", circumstance_name)
			end
		end
		if string.find(c, "toxic") or string.find(c, "gas") then
			if state then
				state.is_toxic_gas_mission = true
				state.preserved_is_toxic_gas = true
			end
			_current_theme_tag = "toxic_gas"
			if MGB then
				MGB.log("LevelLoader: detected toxic_gas from circumstance %s", circumstance_name)
			end
		end
	end

	return func(self, context, ...)
end)

mod:hook(CLASS.LocalThemeState, "init", function(func, self, state_machine, shared_state, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state

	if state then
		state.hooks_called["LocalThemeState.init"] = true
	end

	if not mod:is_enabled() then
		return func(self, state_machine, shared_state, ...)
	end

	local circumstance_name = shared_state and shared_state.circumstance_name
	local level_name = shared_state and shared_state.level_name

	_current_level_name = level_name

	if circumstance_name and MGB then
		local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
		local template = CircumstanceTemplates[circumstance_name]
		if template then
			local theme_tag = template.theme_tag
			_current_theme_tag = theme_tag
			if theme_tag == "darkness" then
				state.is_darkness_mission = true
				state.preserved_is_darkness = true
				MGB.log("LocalThemeState: darkness theme detected")
			elseif theme_tag == "ventilation_purge" then
				state.is_ventilation_mission = true
				state.preserved_is_ventilation = true
				MGB.log("LocalThemeState: ventilation theme detected")
			elseif theme_tag == "toxic_gas" then
				state.is_toxic_gas_mission = true
				state.preserved_is_toxic_gas = true
				MGB.log("LocalThemeState: toxic_gas theme detected")
			end
		end
	end

	return func(self, state_machine, shared_state, ...)
end)

mod:hook(CLASS.HostThemeState, "init", function(func, self, state_machine, shared_state, ...)
	local MGB = get_MGB()
	local state = MGB and MGB.state

	if state then
		state.hooks_called["HostThemeState.init"] = true
	end

	if not mod:is_enabled() then
		return func(self, state_machine, shared_state, ...)
	end

	local circumstance_name = shared_state and shared_state.circumstance_name
	local level_name = shared_state and shared_state.level_name

	_current_level_name = level_name

	if circumstance_name and MGB then
		local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
		local template = CircumstanceTemplates[circumstance_name]
		if template then
			local theme_tag = template.theme_tag
			_current_theme_tag = theme_tag
			if theme_tag == "darkness" then
				state.is_darkness_mission = true
				state.preserved_is_darkness = true
				MGB.log("HostThemeState: darkness theme detected")
			elseif theme_tag == "ventilation_purge" then
				state.is_ventilation_mission = true
				state.preserved_is_ventilation = true
				MGB.log("HostThemeState: ventilation theme detected")
			elseif theme_tag == "toxic_gas" then
				state.is_toxic_gas_mission = true
				state.preserved_is_toxic_gas = true
				MGB.log("HostThemeState: toxic_gas theme detected")
			end
		end
	end

	return func(self, state_machine, shared_state, ...)
end)

if rawget(_G, "Theme") and Theme.shading_environment_slots then
	_original_shading_environment_slots = Theme.shading_environment_slots

	Theme.shading_environment_slots = function(theme, ...)
		local MGB = get_MGB()
		local state = MGB and MGB.state

		if state then
			state.hooks_called["Theme.shading_environment_slots"] = true
		end

		local result = _original_shading_environment_slots(theme, ...)

		if not mod:is_enabled() then
			return result
		end

		if _capturing_defaults then
			return result
		end

		if not should_block_themes() then
			return result
		end

		if MGB then
			MGB.log("Theme.shading_environment_slots: blocking - returning empty (vent=%s dark=%s preserved_vent=%s)", tostring(state and state.is_ventilation_mission), tostring(state and state.is_darkness_mission),
			        tostring(state and state.preserved_is_ventilation))
		end

		return {}
	end
end

if rawget(_G, "Theme") and Theme.light_groups then
	_original_light_groups = Theme.light_groups

	Theme.light_groups = function(theme, ...)
		local MGB = get_MGB()
		local state = MGB and MGB.state

		if state then
			state.hooks_called["Theme.light_groups"] = true
		end

		return _original_light_groups(theme, ...)
	end
end

local ThemePackage = require("scripts/foundation/managers/package/utilities/theme_package")

if ThemePackage and ThemePackage.level_resource_dependency_packages then
	_original_level_resource_dependency_packages = ThemePackage.level_resource_dependency_packages

	ThemePackage.level_resource_dependency_packages = function(level_name, theme_tag, ...)
		local MGB = get_MGB()
		local state = MGB and MGB.state

		if state then
			state.hooks_called["ThemePackage.level_resfource_dependency_packages"] = true
		end

		if not mod:is_enabled() then
			return _original_level_resource_dependency_packages(level_name, theme_tag, ...)
		end

		if theme_tag == "darkness" then
			if state then
				state.is_darkness_mission = true
				state.preserved_is_darkness = true
			end
			_current_theme_tag = "darkness"
			if MGB then
				MGB.log("ThemePackage: darkness mission detected for %s", level_name)
			end
		elseif theme_tag == "ventilation_purge" then
			if state then
				state.is_ventilation_mission = true
				state.preserved_is_ventilation = true
			end
			_current_theme_tag = "ventilation_purge"
			if MGB then
				MGB.log("ThemePackage: ventilation mission detected for %s", level_name)
			end
		elseif theme_tag == "toxic_gas" then
			if state then
				state.is_toxic_gas_mission = true
				state.preserved_is_toxic_gas = true
			end
			_current_theme_tag = "toxic_gas"
			if MGB then
				MGB.log("ThemePackage: toxic_gas mission detected for %s", level_name)
			end
		end

		_current_level_name = level_name

		return _original_level_resource_dependency_packages(level_name, theme_tag, ...)
	end
end

return mgb_environment
