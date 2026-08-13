---@type mod
local mod = get_mod("dopamine")

if mod.enemy_spawn then
	return mod.enemy_spawn
end

local Breeds = mod.dl.breeds

---@class EnemySpawnCategoryTotals
---@field count integer
---@field health number

---@class EnemySpawn
local EnemySpawn = {}

---@return table<UseBreedsBreedCategory, EnemySpawnCategoryTotals>
local function fresh_totals()
	return {
		regular = { count = 0, health = 0 },
		elite = { count = 0, health = 0 },
		special = { count = 0, health = 0 },
		boss = { count = 0, health = 0 },
	}
end

---@type table<UseBreedsBreedCategory, EnemySpawnCategoryTotals>
local _totals = fresh_totals()

local _seen = setmetatable({}, { __mode = "k" })

---@param self any  health extension (HealthExtension | HuskHealthExtension)
---@param unit Unit|nil
local function record_spawn(self, unit)
	if not unit or _seen[unit] then
		return
	end

	local breed_data = Breeds.data_from_unit(unit)
	if not breed_data or breed_data.breed_type ~= "minion" then
		return
	end

	local category = Breeds.breed_category(breed_data)
	local bucket = category and _totals[category]
	if not bucket then
		return
	end

	_seen[unit] = true
	bucket.count = bucket.count + 1
	bucket.health = bucket.health + (self.max_health and self:max_health() or 0)
end

mod.dl.game_hooks.hook_safe("HealthExtension", "init", function(self, _extension_init_context, unit)
	record_spawn(self, unit)
end)

mod.dl.game_hooks.hook_safe("HuskHealthExtension", "init", function(self, _extension_init_context, unit)
	record_spawn(self, unit)
end)

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if not from_reload then
		EnemySpawn.reset()
	end
end)

---@return table<UseBreedsBreedCategory, EnemySpawnCategoryTotals>
function EnemySpawn.totals()
	return _totals
end

function EnemySpawn.reset()
	_totals = fresh_totals()
	_seen = setmetatable({}, { __mode = "k" })
end

mod.enemy_spawn = EnemySpawn

return mod.enemy_spawn
