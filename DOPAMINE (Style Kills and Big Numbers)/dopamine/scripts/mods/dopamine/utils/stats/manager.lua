

---@type mod
local mod = get_mod("dopamine")

if mod.stats_manager then
	return mod.stats_manager
end

local Constants = mod:core(mod.stat_chart_constants, "hud/stat_chart/constants").LOGIC

local METRICS = Constants.METRICS
local MAX_ROWS = Constants.MAX_ROWS

---@class StatsManager
local StatsManager = {}

---@class StatAccount
---@field account_id string
---@field player DL_PlayerObject
---@field name string last-known display name, cached from a live player object
---@field damage number
---@field kills number

---@type table<string, StatAccount>
local _accounts = {}

local _metric_index = 1

local PERSIST_SYNC_INTERVAL = 2 
local _persist = mod:persistent_table("stat_chart", {})
local _persist_sync_timer = 0

local _sorted = {}
local _snapshot = { entries = {}, count = 0, metric = METRICS[1] }

---@param player DL_PlayerObject|nil
---@return StatAccount|nil
local function account_for(player)
	if not player then
		return nil
	end
	local ok, account_id = pcall(function()
		return player:account_id()
	end)
	if not ok or account_id == nil then
		return nil
	end

	local account = _accounts[account_id]
	if not account then
		account = { account_id = account_id, player = player, name = "", damage = 0, kills = 0 }
		_accounts[account_id] = account
	else

		account.player = player
	end

	local name = mod.dl.player.name(player)
	if name then
		account.name = name
	end
	return account
end

---@param event DL_HitEvent
local function on_damaged(event)
	if not mod.dl.breeds.is_minion(event.attacked_unit) then
		return
	end

	local account = account_for(event.attacking_player)
	if not account then
		return
	end

	account.damage = account.damage + event.damage
	if event.attack_result == "died" then
		account.kills = account.kills + 1
	end
end

mod.dl.on_hit.execute("human players", on_damaged)

---@return StatChartMetric
function StatsManager.metric()
	return METRICS[_metric_index]
end

---@return StatChartMetric
function StatsManager.cycle_metric()
	_metric_index = _metric_index % #METRICS + 1
	return StatsManager.metric()
end

local _sort_field = "damage"

local function compare_desc(a, b)
	if a[_sort_field] ~= b[_sort_field] then
		return a[_sort_field] > b[_sort_field]
	end
	return a.account_id < b.account_id
end

---@class StatChartSnapshot
---@field entries StatAccount[]
---@field count integer
---@field metric StatChartMetric
---@field max_value number
---@return StatChartSnapshot
function StatsManager.snapshot()
	local metric = StatsManager.metric()
	local field = metric.id

	for i = #_sorted, 1, -1 do
		_sorted[i] = nil
	end
	for _, account in pairs(_accounts) do
		_sorted[#_sorted + 1] = account
	end

	_sort_field = field
	table.sort(_sorted, compare_desc)

	local count = math.min(#_sorted, MAX_ROWS)
	local entries = _snapshot.entries
	for i = #entries, 1, -1 do
		entries[i] = nil
	end
	for i = 1, count do
		entries[i] = _sorted[i]
	end

	_snapshot.count = count
	_snapshot.metric = metric
	_snapshot.max_value = count > 0 and _sorted[1][field] or 0

	return _snapshot
end

---@param dt number
function StatsManager.tick(dt)
  _persist_sync_timer = _persist_sync_timer + dt
  if _persist_sync_timer < PERSIST_SYNC_INTERVAL then
    return
  end
  _persist_sync_timer = _persist_sync_timer - PERSIST_SYNC_INTERVAL

  for account_id, account in pairs(_accounts) do
    local slot = _persist[account_id]
    if not slot then
      slot = {}
      _persist[account_id] = slot
    end
    slot.damage = account.damage
    slot.kills = account.kills
  end
end

function StatsManager.reset()
  for id in pairs(_accounts) do
    _accounts[id] = nil
  end
  for id in pairs(_persist) do
    _persist[id] = nil
  end
  _metric_index = 1
  _persist_sync_timer = 0
end

mod.stats_manager = StatsManager

mod.__cycle_stat_chart = function(self, is_pressed)
	if is_pressed == false then
		return
	end
	StatsManager.cycle_metric()
end

return StatsManager
