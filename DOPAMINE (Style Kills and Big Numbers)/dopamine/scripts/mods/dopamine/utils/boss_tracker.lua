

---@type mod
local mod = get_mod("dopamine")

if mod.boss_tracker then
	return mod.boss_tracker
end

local Unit = Unit
local ScriptUnit = ScriptUnit
local Managers = Managers

local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")
local ScoringConstants = mod:core(mod.scoring_constants, "utils/scoring/constants")

---@class BossTrackerEntry
---@field max_health number
---@field damage_local number  local player's cumulative damage to this boss
---@field breed_data FatsharkBreedData|nil
---@field dead boolean

---@type table<Unit, BossTrackerEntry>
local _bosses = {}

---@class BossTracker
local BossTracker = {}

---@return table<Unit, any>|nil
local function boss_unit_map()
	local state = Managers.state
	local extension = state and state.extension
	local system = extension and extension:system("boss_system")
	return system and system:unit_to_extension_map() or nil
end

---@param unit Unit
local function health_of(unit)
	return Unit.alive(unit) and ScriptUnit.has_extension(unit, "health_system") or nil
end

---@param unit Unit
local function register(unit)
	if _bosses[unit] then
		return
	end

	local breed_data = mod.dl.breeds.data_from_unit(unit)
	if not breed_data or not mod.dl.breeds.is_any(breed_data, "category.boss") then
		return
	end

	local health = health_of(unit)
	if not health then
		return
	end

	_bosses[unit] = {
		max_health = health:max_health(),
		damage_local = 0,
		breed_data = breed_data,
		dead = false,
	}
end

---@param unit Unit
---@return boolean
local function is_dead(unit)
	local health = health_of(unit)
	if not health then
		return true
	end
	return not health:is_alive() or health:current_health() <= 0
end

---@param entry BossTrackerEntry
local function on_boss_death(entry)
	local reward = ScoringConstants.BOSS_KILL_MULT
	EventManager.add_timed_mult(reward.add, reward.duration)

	local contribution = entry.max_health > 0 and entry.damage_local / entry.max_health or 0
	if contribution >= ScoringConstants.BOSS_KILL_CONTRIBUTION then
		EventManager.trigger(
			EventEnums.EVENT_ID.boss_kill,
			EventManager.make_context({ breed_data = entry.breed_data })
		)
	end
end

mod.dl.gameplay.while_in_gameplay(function()
	local map = boss_unit_map()
	if map then
		for unit in pairs(map) do
			register(unit)
		end
	end

	for unit, entry in pairs(_bosses) do
		if not entry.dead and is_dead(unit) then
			entry.dead = true
			on_boss_death(entry)
		end
	end
end)

mod.dl.on_hit.execute("controlling player", function(event)
	local unit = event.attacked_unit
	if not unit or not mod.dl.breeds.unit_is_any(unit, "category.boss") then
		return
	end

	register(unit)
	local entry = _bosses[unit]
	if entry then
		entry.damage_local = entry.damage_local + (event.damage or 0)
	end
end)

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if not from_reload then
		BossTracker.reset()
	end
end)

function BossTracker.reset()
	_bosses = {}
end

---@return number
function BossTracker.engaged_max_health()
	local total = 0
	for _, entry in pairs(_bosses) do
		if entry.damage_local > 0 then
			total = total + entry.max_health
		end
	end
	return total
end

mod.boss_tracker = BossTracker

return mod.boss_tracker
