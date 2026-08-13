

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_stats then
	return mod.mission_summary_stats
end

local EventManager = mod:core(mod.event_manager, "utils/event/manager")

local ObjectiveTime = mod:core(mod.objective_time, "hooks/objective_time")
local TeammateRescue = mod:core(mod.teammate_rescue, "hooks/teammate_rescue")

local BossTracker = mod:core(mod.boss_tracker, "utils/boss_tracker")

local EnemySpawn = mod:core(mod.enemy_spawn, "hooks/enemy_spawn")
local Coherency = mod:core(mod.coherency, "hooks/coherency")
local StimTracker = mod:core(mod.stim_tracker, "hooks/stim_tracker")
local Finesse = mod:core(mod.finesse, "hooks/finesse")

---@class MissionSummaryStats
local Stats = {}

local _kills = 0
local _damage = 0
local _boss_damage = 0

local _elite_damage = 0
local _special_damage = 0
local _regular_damage = 0

local _boss_kills = 0
local _elite_kills = 0
local _special_kills = 0
local _regular_kills = 0
local _headshots = 0
local _time = 0
local _plasteel = 0
local _diamantine = 0
local _idols = 0
local _skulls = 0

local function local_player()
	return mod.dl.player.local_player()
end

---@param event DL_HitEvent
local function on_damaged(event)
	local attacker = event.attacking_player
	if not attacker or attacker ~= local_player() then
		return
	end

	local data = mod.dl.breeds.data_from_unit(event.attacked_unit)
	if not data or data.breed_type ~= "minion" then
		return
	end

	local damage = event.damage or 0

	local category = mod.dl.breeds.breed_category(data)

	_damage = _damage + damage
	if category == "boss" then
		_boss_damage = _boss_damage + damage
	elseif category == "elite" then
		_elite_damage = _elite_damage + damage
	elseif category == "special" then
		_special_damage = _special_damage + damage
	elseif category == "regular" then
		_regular_damage = _regular_damage + damage
	end

	if event.hit_weakspot then
		_headshots = _headshots + 1
	end

	if event.attack_result == "died" then
		_kills = _kills + 1
		if category == "boss" then
			_boss_kills = _boss_kills + 1
		elseif category == "elite" then
			_elite_kills = _elite_kills + 1
		elseif category == "special" then
			_special_kills = _special_kills + 1
		elseif category == "regular" then
			_regular_kills = _regular_kills + 1
		end
	end
end

mod.dl.on_hit.execute("human players", on_damaged)

---@type table<string, { material: "plasteel"|"diamantine", amount: number }>
local FORGE_MATERIALS = {
	loc_pickup_small_metal = { material = "plasteel", amount = 10 },
	loc_pickup_large_metal = { material = "plasteel", amount = 25 },
	loc_pickup_small_platinum = { material = "diamantine", amount = 10 },
	loc_pickup_large_platinum = { material = "diamantine", amount = 25 },
}

mod.dl.game_hooks.hook(
	"InteracteeExtension",
	"stopped",
	function(next_fn, _self, result, interactor_unit)
		next_fn(_self, result, interactor_unit)

		if result ~= "success" or interactor_unit ~= mod.dl.player.local_player_unit() then
			return
		end
		if _self:interaction_type() ~= "forge_material" then
			return
		end
		local context = _self._override_contexts and _self._override_contexts.forge_material
		local entry = context and FORGE_MATERIALS[context.description]
		if not entry then
			return
		end
		if entry.material == "plasteel" then
			_plasteel = _plasteel + entry.amount
		else
			_diamantine = _diamantine + entry.amount
		end
	end
)

mod.dl.game_hooks.hook_safe(
	"PocketableInteraction",
	"stop",
	function(_self, _world, interactor_unit, interaction_context, _t, result)
		if result ~= "success" or interactor_unit ~= mod.dl.player.local_player_unit() then
			return
		end
		local interactee_unit = interaction_context and interaction_context.target_unit
		if not interactee_unit or not Unit.has_data(interactee_unit, "pickup_type") then
			return
		end
		local pickup_name = Unit.get_data(interactee_unit, "pickup_type")
		if pickup_name == "grimoire" then
			_idols = _idols + 1
		elseif pickup_name == "tome" then
			_skulls = _skulls + 1
		end
	end
)

mod.dl.gameplay.while_in_gameplay(function(dt)
	_time = _time + dt
end)

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if not from_reload then
		Stats.reset()
	end
end)

function Stats.reset()
	_kills = 0
	_damage = 0
	_boss_damage = 0
	_elite_damage = 0
	_special_damage = 0
	_regular_damage = 0
	_boss_kills = 0
	_elite_kills = 0
	_special_kills = 0
	_regular_kills = 0
	_headshots = 0
	_time = 0
	_plasteel = 0
	_diamantine = 0
	_idols = 0
	_skulls = 0
end

---@class MissionSummaryStatValues
---@field time number
---@field kills number
---@field damage number
---@field boss_damage number
---@field boss_max_health number  summed max health of the bosses the player engaged
---@field headshots number
---@field style_points number
---@field plasteel number
---@field diamantine number
---@field idols_found number
---@field skulls_found number
---@field best_combo number  largest combo kill-streak this run
---@field objectives number  objectives the local player personally completed this run
---@field rescues number  teammates the local player rescued this run (revives + unties + net cuts)
---@field event_counts table<EventID, integer>  live per-mission fire count per style event

---@field elite_damage number
---@field special_damage number
---@field regular_damage number

---@field boss_kills number
---@field elite_kills number
---@field special_kills number
---@field regular_kills number

---@field regular_spawned number
---@field elite_spawned number
---@field special_spawned number
---@field boss_spawned number
---@field regular_health number
---@field elite_health number
---@field special_health number

---@field coherency_time number
---@field stims number
---@field rescues_global number

---@field health_lost number
---@field downs number
---@return MissionSummaryStatValues
function Stats.current()
	local spawn = EnemySpawn.totals()
	return {
		time = _time,
		kills = _kills,
		damage = _damage,
		boss_damage = _boss_damage,
		boss_max_health = BossTracker.engaged_max_health(),
		headshots = _headshots,
		style_points = EventManager.total_sp(),
		plasteel = _plasteel,
		diamantine = _diamantine,
		idols_found = _idols,
		skulls_found = _skulls,
		best_combo = EventManager.best_combo(),
		objectives = ObjectiveTime.objectives(),
		rescues = TeammateRescue.rescue_count(),
		event_counts = EventManager.event_counts(),

		elite_damage = _elite_damage,
		special_damage = _special_damage,
		regular_damage = _regular_damage,
		boss_kills = _boss_kills,
		elite_kills = _elite_kills,
		special_kills = _special_kills,
		regular_kills = _regular_kills,
		regular_spawned = spawn.regular.count,
		elite_spawned = spawn.elite.count,
		special_spawned = spawn.special.count,
		boss_spawned = spawn.boss.count,
		regular_health = spawn.regular.health,
		elite_health = spawn.elite.health,
		special_health = spawn.special.health,

		coherency_time = Coherency.time(),
		stims = StimTracker.ally_stims(),
		rescues_global = TeammateRescue.global_rescue_count(),

		health_lost = Finesse.health_lost(),
		downs = Finesse.downs(),
	}
end

mod.mission_summary_stats = Stats

return mod.mission_summary_stats
