-- scaling_hook.lua
--
-- Applies the per-tier enemy attack-speed buffs on minion spawn.
--
-- ===========================================================================
-- WHY THIS EXISTS
-- ===========================================================================
--
-- Enemy HP scaling above Damnation rides the coop game mode's own path:
-- circumstance_template.minion_health_modifier is read for every minion
-- spawn (minion_spawn_manager.lua:126) and multiplies HP. That covers HP.
--
-- Enemy ATTACK SPEED scaling has no comparable "circumstance field the
-- coop mode reads" path. The way Havoc does it: on every minion_unit_spawned
-- event, if the minion is melee-tagged, add the shipped buff template
-- `havoc_melee_attack_speed_0X` to it. Same for ranged with
-- `havoc_ranged_attack_speed_0X`. These buff templates are shipped and
-- valid (havoc_settings.lua:238-250 references them by name; the buff
-- templates themselves live in the game's buff_templates table).
--
-- Since our coop mission has no havoc_extension calling this, we do the
-- equivalent ourselves via the `minion_unit_spawned` event that
-- MutatorManager already listens to (mutator_manager.lua:22). Managers.event
-- is the same event bus, so registering a listener there gives us the same
-- callback shape.
--
-- ===========================================================================
-- WHEN THIS ACTS
-- ===========================================================================
--
--   * solo host only (Shared.is_solo_host).
--   * an active pilgrimage run.
--   * the current leg's scale_tier >= 1 (difficulty.for_leg).
--
-- Anything else and the listener no-ops; matchmade missions and non-run
-- Psykhanium spawns get no buffs added.

local M = {}

local _mod
local _shared
local _run_state
local _difficulty
local _event_log
local _debug_log

-- Session counters, for /pil_mutators reporting.
local _stats = {
	melee_buffed  = 0,
	ranged_buffed = 0,
	skipped_no_ext = 0,
	last_scale = 0,
}

local _listener_registered = false
local _listener_context = nil  -- the "self" table we register with Managers.event

local function _should_act()
	if not (_shared and _shared.is_solo_host()) then return false end
	if not (_run_state and _run_state.is_active()) then return false end
	local state = _run_state.get()
	if not state or not state.active then return false end
	local diff = _difficulty and _difficulty.for_leg
		and _difficulty.for_leg(state.index, state.starting_difficulty)
	if not diff or (diff.scale_tier or 0) < 1 then return false end
	return diff.scale_tier
end

local function _on_minion_unit_spawned(unit)
	local scale_tier = _should_act()
	if not scale_tier then return end

	_stats.last_scale = scale_tier

	local ok, extension_manager = pcall(function()
		return Managers and Managers.state and Managers.state.extension
	end)
	if not ok or not extension_manager then return end

	-- Read the breed's tags to decide which buffs apply. Same shape the
	-- havoc extension uses.
	local unit_data = ScriptUnit and ScriptUnit.has_extension
		and ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data then _stats.skipped_no_ext = _stats.skipped_no_ext + 1 return end

	local ok_breed, breed = pcall(unit_data.breed, unit_data)
	if not ok_breed or type(breed) ~= "table" then return end

	local tags = breed.tags or {}
	local melee = tags.melee
	local ranged = tags.far or tags.close

	if not melee and not ranged then return end

	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
	if not buff_extension then _stats.skipped_no_ext = _stats.skipped_no_ext + 1 return end

	local melee_buff, ranged_buff = _difficulty.spawn_buffs_for(scale_tier)

	local ok_time, t = pcall(function()
		return Managers.time and Managers.time:time("gameplay")
	end)
	if not ok_time or not t then return end

	if melee and melee_buff then
		pcall(buff_extension.add_internally_controlled_buff, buff_extension, melee_buff, t)
		_stats.melee_buffed = _stats.melee_buffed + 1
	end
	if ranged and ranged_buff then
		pcall(buff_extension.add_internally_controlled_buff, buff_extension, ranged_buff, t)
		_stats.ranged_buffed = _stats.ranged_buffed + 1
	end
end

-- ---------------------------------------------------------------------------
-- Listener installation
-- ---------------------------------------------------------------------------

-- Registers on Managers.event once the manager exists. Called from tick
-- during gameplay init (register too early and the manager isn't there yet).
-- Idempotent.
function M.ensure()
	if _listener_registered then return end

	local ok_mgr, event_manager = pcall(function()
		return Managers and Managers.event
	end)
	if not ok_mgr or not event_manager then return end
	if type(event_manager.register) ~= "function" then return end

	-- Use a stable table as the "self" ref so unregister works if we ever
	-- want to reset it. The register API needs (self, event_name, method_name)
	-- and calls self:method_name(...). We give it a table with the method.
	_listener_context = _listener_context or {
		_on_minion_unit_spawned = function(_, unit) _on_minion_unit_spawned(unit) end,
	}

	local ok = pcall(event_manager.register, event_manager, _listener_context,
		"minion_unit_spawned", "_on_minion_unit_spawned")
	if ok then
		_listener_registered = true
		_debug_log("scaling_hook", 0, "minion_unit_spawned listener registered", 0, "info")
	end
end

-- Called on GameplayStateRun EXIT so a fresh listener registers next
-- gameplay init. Event managers get destroyed with the mission's Lua VM,
-- so a stale registration flag would prevent re-register.
function M.reset()
	_listener_registered = false
	_listener_context = nil
	_stats.melee_buffed = 0
	_stats.ranged_buffed = 0
	_stats.skipped_no_ext = 0
	_stats.last_scale = 0
end

function M.stats()
	return {
		melee_buffed  = _stats.melee_buffed,
		ranged_buffed = _stats.ranged_buffed,
		skipped_no_ext = _stats.skipped_no_ext,
		last_scale = _stats.last_scale,
		registered = _listener_registered,
	}
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_run_state = deps.run_state
	_difficulty = deps.difficulty
	_event_log = deps.event_log
	_debug_log = deps.debug_log or function() end
end

return M
