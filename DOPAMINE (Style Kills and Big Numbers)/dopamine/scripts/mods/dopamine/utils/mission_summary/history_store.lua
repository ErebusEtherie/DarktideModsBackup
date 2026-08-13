

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_history then
	return mod.mission_summary_history
end

local DMF = get_mod("DMF")
local _io = DMF.deepcopy(Mods.lua.io)
local _os = DMF.deepcopy(Mods.lua.os)

local _cache = mod:persistent_table("mission_summary_history", {})

---@class MissionSummaryEntry
---@field mission_id string
---@field mission_display string
---@field difficulty number
---@field difficulty_name string
---@field outcome string
---@field won number
---@field sp number
---@field rank string
---@field kills number
---@field damage number
---@field boss_damage number
---@field boss_max_health number
---@field headshots number
---@field time number
---@field plasteel number
---@field diamantine number
---@field idols_found number
---@field skulls_found number
---@field best_combo number
---@field objectives number
---@field rescues number

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
---@field is_auric number      1/0 -- auric mission (challenge 5 / resistance 5 danger tier)
---@field is_maelstrom number  1/0 -- maelstrom (a "flash mission" circumstance)
---@field is_havoc number      1/0 -- havoc mission
---@field havoc_rank number    havoc rank (0 when not a havoc mission)
---@field circumstance_name string  active circumstance id ("" when none)
---@field archetype string
---@field player_name string
---@field timestamp number
---@field event_counts table<string, integer>  per-style-event fire count, serialized as ec_<id> lines
---@field file string|nil

local NUMERIC_FIELDS = {
	difficulty = true,
	sp = true,
	kills = true,
	damage = true,
	boss_damage = true,
	boss_max_health = true,
	headshots = true,
	time = true,
	plasteel = true,
	diamantine = true,
	idols_found = true,
	skulls_found = true,
	best_combo = true,
	objectives = true,
	rescues = true,
	elite_damage = true,
	special_damage = true,
	regular_damage = true,
	boss_kills = true,
	elite_kills = true,
	special_kills = true,
	regular_kills = true,
	regular_spawned = true,
	elite_spawned = true,
	special_spawned = true,
	boss_spawned = true,
	regular_health = true,
	elite_health = true,
	special_health = true,
	coherency_time = true,
	stims = true,
	rescues_global = true,
	health_lost = true,
	downs = true,
	is_auric = true,
	is_maelstrom = true,
	is_havoc = true,
	havoc_rank = true,
	won = true,
	timestamp = true,
}

local FIELD_ORDER = {
	"mission_id", "mission_display", "difficulty", "difficulty_name", "outcome", "won",
	"sp", "rank", "kills", "damage", "boss_damage", "boss_max_health", "headshots", "time",
	"plasteel", "diamantine", "idols_found", "skulls_found", "best_combo",
	"objectives", "rescues",
	"elite_damage", "special_damage", "regular_damage",
	"boss_kills", "elite_kills", "special_kills", "regular_kills",
	"regular_spawned", "elite_spawned", "special_spawned", "boss_spawned",
	"regular_health", "elite_health", "special_health",
	"coherency_time", "stims", "rescues_global",
	"health_lost", "downs",
	"is_auric", "is_maelstrom", "is_havoc", "havoc_rank", "circumstance_name",
	"archetype", "player_name", "timestamp",
}

---@class MissionSummaryHistory
local History = {}

local function appdata_path()
	local appdata = _os.getenv("APPDATA") or ""
	return appdata .. "/Fatshark/Darktide/dopamine_scores/"
end

local function ensure_directory()
	local path = appdata_path()

	_os.execute('mkdir "' .. path .. '"')
end

---@param value any
---@return string
local function sanitize(value)
	return tostring(value or ""):gsub("[\t\r\n]", " ")
end

---@param entry MissionSummaryEntry
function History.save(entry)
	ensure_directory()

	local timestamp = entry.timestamp or _os.time()
	entry.timestamp = timestamp
	local file_name = tostring(timestamp) .. ".txt"
	local path = appdata_path() .. file_name

	local file = _io.open(path, "w+")
	if not file then
		return
	end

	for i = 1, #FIELD_ORDER do
		local key = FIELD_ORDER[i]
		file:write(key .. "\t" .. sanitize(entry[key]) .. "\n")
	end

	if entry.event_counts then
		for event_id, count in pairs(entry.event_counts) do
			file:write("ec_" .. sanitize(event_id) .. "\t" .. tostring(math.floor(count or 0)) .. "\n")
		end
	end
	file:close()

	entry.file = file_name
	if _cache.entries then
		_cache.entries[#_cache.entries + 1] = entry
	end
end

---@param path string
---@param file_name string
---@return MissionSummaryEntry|nil
local function load_entry(path, file_name)
	local file = _io.open(path, "r")
	if not file then
		return nil
	end

	---@type MissionSummaryEntry
	local entry = { event_counts = {} }
	for line in file:lines() do
		local key, value = line:match("^([^\t]+)\t(.*)$")
		if key then

			value = value:gsub("\r$", "")
			local event_id = key:match("^ec_(.+)$")
			if event_id then
				entry.event_counts[event_id] = tonumber(value) or 0
			elseif NUMERIC_FIELDS[key] then
				entry[key] = tonumber(value) or 0
			else
				entry[key] = value
			end
		end
	end
	file:close()

	if not entry.mission_id then
		return nil
	end

	entry.file = file_name
	return entry
end

---@return string[]
local function scandir()
	local names = {}
	local pipe = _io.popen('dir "' .. appdata_path() .. '" /b 2>nul')
	if not pipe then
		return names
	end
	for name in pipe:lines() do
		if name:match("%.txt$") then
			names[#names + 1] = name
		end
	end
	pipe:close()
	return names
end

---@param rescan boolean|nil
---@return MissionSummaryEntry[]
function History.all_entries(rescan)
	if _cache.entries and not rescan then
		return _cache.entries
	end

	local entries = {}
	local dir = appdata_path()
	local files = scandir()
	for i = 1, #files do
		local entry = load_entry(dir .. files[i], files[i])
		if entry then
			entries[#entries + 1] = entry
		end
	end

	_cache.entries = entries
	return entries
end

---@return MissionSummaryEntry|nil
function History.most_recent()
	local all = History.all_entries()
	local best = nil
	for i = 1, #all do
		if not best or (all[i].timestamp or 0) > (best.timestamp or 0) then
			best = all[i]
		end
	end
	return best
end

---@param mission_id string|nil
---@param difficulty number|nil
---@return MissionSummaryEntry[]
function History.entries_for(mission_id, difficulty)
	local all = History.all_entries()
	local out = {}
	for i = 1, #all do
		local entry = all[i]
		if (not mission_id or entry.mission_id == mission_id)
			and (not difficulty or entry.difficulty == difficulty)
		then
			out[#out + 1] = entry
		end
	end

	table.sort(out, function(a, b)
		return (a.sp or 0) > (b.sp or 0)
	end)

	return out
end

---@param entry MissionSummaryEntry
---@return boolean
function History.delete(entry)
	if not entry then
		return false
	end

	local file_name = entry.file or (entry.timestamp and (tostring(entry.timestamp) .. ".txt")) or nil
	local removed = false
	if file_name then
		removed = _os.remove(appdata_path() .. file_name) and true or false
	end

	if _cache.entries then
		for i = #_cache.entries, 1, -1 do
			local cached = _cache.entries[i]
			if cached == entry or (entry.timestamp and cached.timestamp == entry.timestamp) then
				table.remove(_cache.entries, i)
			end
		end
	end

	return removed
end

---@return integer
function History.clear_all()
	local dir = appdata_path()
	local files = scandir()
	local removed = 0
	for i = 1, #files do
		if _os.remove(dir .. files[i]) then
			removed = removed + 1
		end
	end

	_cache.entries = {}
	return removed
end

mod.mission_summary_history = History

return mod.mission_summary_history
