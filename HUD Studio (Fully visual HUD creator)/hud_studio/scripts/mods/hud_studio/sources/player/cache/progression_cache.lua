---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_progression_cache then
	return mod.hud_studio_progression_cache
end

local FAILED_FETCH_RETRY_SECONDS = 3

local Cache = {}

local state = mod:persistent_table("hud_studio_progression")
state.records = state.records or {} 
state.pending = state.pending or {} 
state.retry_after = state.retry_after or {}

---@param key string  a character_id, or "xp" for the shared xp table
---@return boolean     whether a fetch for `key` may start now
local function may_fetch(key)
	if state.pending[key] then
		return false
	end
	local retry_after = state.retry_after[key]
	return not retry_after or os.clock() >= retry_after
end

---@param key string
local function fetch_failed(key)
	state.pending[key] = nil
	state.retry_after[key] = os.clock() + FAILED_FETCH_RETRY_SECONDS
end

---@return table | nil  the progression backend interface, once the backend is up
local function progression_interface()
	local backend = Managers.backend
	local interfaces = backend and backend.interfaces
	return interfaces and interfaces.progression or nil
end

local function fetch_xp_table()
	if state.xp or not may_fetch("xp") then
		return
	end

	local progression = progression_interface()
	if not progression then
		return
	end

	state.pending.xp = true
	progression
		:get_xp_table("character")
		:next(function(level_array)
			state.pending.xp = nil
			local max_level = level_array and #level_array or 0
			if max_level < 2 then
				fetch_failed("xp")
				return
			end
			state.xp = {
				level_array = level_array,
				total_xp = level_array[max_level],
				max_level = max_level,
			}
		end)
		:catch(function()
			fetch_failed("xp")
		end)
end

---@param character_progression table  backend body: currentLevel + currentXp
---@return table  { level, total_level, extra_levels, prestige }
local function build_record(character_progression)
	local xp = state.xp
	local level = character_progression.currentLevel or 0
	local current_xp = character_progression.currentXp or 0
	local record = {
		level = level,
		total_level = level,
		extra_levels = 0,
		prestige = 0,
	}

	if level >= xp.max_level then
		local xp_per_level = xp.level_array[xp.max_level] - xp.level_array[xp.max_level - 1]
		local xp_past_cap = current_xp - xp.total_xp
		local extra_levels = math.max(math.floor(xp_past_cap / xp_per_level), 0)

		record.extra_levels = extra_levels
		record.total_level = level + extra_levels
		record.prestige = math.floor(current_xp / xp.total_xp)
	end

	return record
end

---@param character_id string
---@param account_id string | nil
local function fetch_havoc_rank(character_id, account_id)
	local data_service = Managers.data_service
	local havoc = data_service and data_service.havoc
	if not havoc or not account_id then
		return
	end

	havoc:havoc_rank_cadence_high(account_id):next(function(rank)
		local record = state.records[character_id]
		if record then
			record.havoc_rank = rank
		end
	end)
end

local PROFILE_UTILS_PATH = "scripts/utilities/profile_utils"

---@type table | nil
local profile_utils = nil

---@param account_id string | nil
---@return table | nil  presence entry
local function presence_entry(account_id)
	local presence_manager = Managers.presence
	if not presence_manager or not account_id or account_id == "" then
		return nil
	end
	local ok, entry = pcall(presence_manager.get_presence, presence_manager, account_id)
	return ok and entry or nil
end

---@param account_id string | nil
---@return table | nil
local function presence_record(account_id)
	local entry = presence_entry(account_id)
	if not entry then
		return nil
	end

	local immaterium = entry._immaterium_entry
	local key_values = type(immaterium) == "table" and immaterium.key_values or nil
	local blob = type(key_values) == "table" and key_values.character_profile or nil
	if type(blob) ~= "table" or blob.value == nil or blob.value == "" then
		return nil
	end

	if not profile_utils then
		local ok_utils, utils = pcall(mod.original_require, mod, PROFILE_UTILS_PATH)
		if not ok_utils or type(utils) ~= "table" then
			return nil
		end
		profile_utils = utils
	end

	local json = _G.cjson
	if not json then
		return nil
	end
	local ok_json, decoded = pcall(json.decode, blob.value)
	if not ok_json then
		return nil
	end
	local ok_body, body = pcall(profile_utils.process_backend_body, decoded)
	local progression = ok_body and type(body) == "table" and body.progression or nil
	if type(progression) ~= "table" then
		return nil
	end

	local record = build_record(progression)

	local ok_havoc, havoc_rank = pcall(entry.havoc_rank_cadence_high, entry)
	record.havoc_rank = ok_havoc and havoc_rank or nil
	return record
end

---@param character_id string
---@param account_id string | nil
local function fetch_character(character_id, account_id)
	if not may_fetch(character_id) then
		return
	end

	local progression = progression_interface()
	if not progression then
		return
	end

	state.pending[character_id] = true
	progression
		:get_progression("character", character_id)
		:next(function(character_progression)
			state.pending[character_id] = nil
			if not state.xp or not character_progression then

				fetch_failed(character_id)
				return
			end
			state.records[character_id] = build_record(character_progression)
			fetch_havoc_rank(character_id, account_id)
		end)
		:catch(function()
			fetch_failed(character_id)
		end)
end

---@param character_id string | nil
---@param account_id string | nil
---@param live_level integer | nil
---@return table | nil  { level, total_level, extra_levels, prestige, havoc_rank? }
function Cache.record(character_id, account_id, live_level)
	if not character_id then
		return nil
	end

	if not state.xp then
		fetch_xp_table()
		return nil
	end

	local record = state.records[character_id]
	if record and live_level and live_level > record.level then
		record = nil
		state.records[character_id] = nil
	end

	if not record then

		record = presence_record(account_id)
		if record then
			state.records[character_id] = record
			if not record.havoc_rank then
				fetch_havoc_rank(character_id, account_id)
			end
		else
			fetch_character(character_id, account_id)
			return nil
		end
	end

	return record
end

mod.hud_studio_progression_cache = Cache
return Cache
