local mod = get_mod("strikemap")

-- ---------------------------------------------------------------------------
-- Mission reports: records what happened during a run (player paths, downs,
-- deaths, enemy-death locations, duration, distance) and persists it so it can
-- be reviewed afterwards on the full-map. Fully client-safe:
--   * player positions come from Managers.player unit positions (already used
--     for ally markers);
--   * downs/deaths from unit_data:read_component("character_state").state_name
--     (the same field PlayerUnitStatus.is_knocked_down/is_dead read, and it
--     replicates to every client);
--   * enemy-death points from the broadphase enemy set going alive -> gone
--     (near the local player only, so it is honestly a "combat intensity /
--     enemy deaths near you" layer, not authoritative kill attribution).
--
-- Files are written beside Darktide's user settings under %APPDATA%:
--   strikemap_reports_index.lua   -- small summary list the browser reads
--   strikemap_report_<id>.lua     -- one full run each
-- A one-time, non-destructive migration copies old archives out of the mod
-- folder. Keeping player data outside the install means updating/replacing the
-- mod can no longer wipe mission history.
-- These are player data; the public build script never bundles them.
-- ---------------------------------------------------------------------------

local LEGACY_OUT_DIR = "./../mods/strikemap/"
local LEGACY_INDEX_PATH = LEGACY_OUT_DIR .. "reports_index.lua"
-- The flat %APPDATA% layout used before the archive moved into its own
-- subfolder; still read, so upgrades keep their history.
local ROOT = {
	dir = nil,
	index = "strikemap_reports_index.lua",
	prefix = "strikemap_report_",
}
local OUT_DIR = LEGACY_OUT_DIR
local INDEX_NAME = "reports_index.lua"
local REPORT_PREFIX = "report_"
local INDEX_PATH = OUT_DIR .. INDEX_NAME

local SAMPLE_MOVE = 2.5      -- metres moved before a new path point is stored
local SAMPLE_TIME = 1.5      -- or this many seconds, whichever comes first
local COMBAT_SETTINGS_EVENTS = 120 -- combat events between setting re-reads
local CHECKPOINT_DEFAULT = 60 -- disk-checkpoint seconds when the
                             -- perf_report_autosave setting is unset
local MIN_SAVE_TIME = 25     -- runs shorter than this are not saved
local MAX_PATH_POINTS = 4000 -- per player; hitting it halves stored resolution
                             -- and coarsens future sampling (marathon runs
                             -- degrade gracefully instead of freezing mid-map)
local MAX_KILLS = 15000      -- squad-proximity enemy deaths (KILLZONES heat);
                             -- a 55-minute havoc logged 4140, so 6000 was tight
local MAX_INDEX = 60         -- keep the newest N reports; older files are pruned

-- character_state.state_name -> down type code (1 knocked, 2 grabbed/disabled, 3 dead).
-- Code 4 is synthesized on the transition OUT of any of these states back to a
-- normal one ("back in the fight"): rescues, untangles and prison respawns.
local DOWN_CODE = {
	knocked_down = 1,
	hogtied = 2,
	netted = 2,
	pounced = 2,
	mutant_charged = 2,
	warp_grabbed = 2,
	vortex_grabbed = 2,
	ledge_hanging = 2,
	consumed = 2,
	grabbed = 2,
	dead = 3,
	-- "catapulted" is deliberately NOT here: it is the generic flung-through-
	-- the-air transient (mutant flinging NON-grabbed bystanders, ogryn slams),
	-- lasts under a second and self-recovers on landing. Mapping it to a grab
	-- filled replays with phantom "grabbed by a Mutant" + instant-recovery
	-- pairs. Real mutant grabs enter "mutant_charged" first, which is mapped.
}

-- The disabler each grab state uniquely implies, so an event can read
-- "grabbed by a Trapper" without needing to resolve the attacker unit.
local DISABLER_BY_STATE = {
	netted = "Trapper",
	hogtied = "Trapper",
	pounced = "Hound",
	mutant_charged = "Mutant",
	warp_grabbed = "Daemonhost",
	vortex_grabbed = "Daemonhost",
	consumed = "Beast of Nurgle",
	grabbed = "Chaos Spawn",
	ledge_hanging = "ledge",
}

local DMG_BUCKET = 10        -- seconds per damage-over-time bucket
local TELEPORT_DIST_SQ = 30 * 30 -- a single-frame move past this is a teleport, not walking
local MAX_KILL_EVENTS = 6000 -- per player: replay kill counts come from this
                             -- list, so it cannot be thinned like paths; 1500
                             -- visibly capped a 55-minute havoc marathon
local HIT_ATTRIBUTION_WINDOW = 5  -- seconds from last hit to blame a knockdown on it
local RESCUE_ATTRIBUTION_WINDOW = 8

local _run = nil       -- active run capture, or nil
local _index = nil     -- cached { next_id, runs = {summaries} }
local _sample_timer = 0
local _enemy_timer = 0
local _enemy_gen = 0     -- report_capture_enemies sweep stamp (no per-call tables)
local _checkpoint_timer = 0
local _checkpoint_job = nil -- staged serializer; at most one growing report snapshot
local _prev_enemies = {} -- unit -> {x,y,z} last seen alive
local _unit_records = {} -- player_unit -> player record fast path (per run)
local _last_hit = {}     -- player_unit -> { label, t }: last enemy that hurt them
local _pending_rescue = {} -- player_unit -> { name, t }: who just picked them up
local _view = {          -- browser/render state, read by the element
	open = false,
	sel = 1,             -- 1-based index into runs (newest first)
	layer = "path",      -- path | time | kills
	runs = nil,          -- summaries (newest first), lazily loaded
	report = nil,        -- full report table for the selected run
	report_id = nil,     -- id the loaded report belongs to
	map = nil,           -- parsed floor plan for the selected run's mission
	map_mission = nil,
}

-- Combat receivers fire on EVERY hit by every player, so their two setting
-- reads are refreshed on a timer instead of per event. Per-tick gates keep
-- reading live -- one mod:get a frame is cheap, and staleness there would let a
-- just-disabled recorder keep writing.
local _combat_settings = { n = 0, record = true, combat = true }

local function combat_enabled()
	local n = _combat_settings.n

	if n <= 0 then
		local ok, record = pcall(mod.get, mod, "record_reports")
		_combat_settings.record = not ok or record ~= false

		local combat_ok, combat = pcall(mod.get, mod, "perf_combat_tracking")
		_combat_settings.combat = not combat_ok or combat ~= false

		_combat_settings.n = COMBAT_SETTINGS_EVENTS
	else
		_combat_settings.n = n - 1
	end

	return _combat_settings.record and _combat_settings.combat
end

local function checkpoint_interval()
	local ok, seconds = pcall(mod.get, mod, "perf_report_autosave")
	seconds = ok and tonumber(seconds) or nil

	return seconds or CHECKPOINT_DEFAULT
end

-- Named readers for the per-frame player loop. `pcall(fn, args...)` allocates
-- nothing; `pcall(function() ... end)` builds a fresh closure every call, which
-- at four players a frame is the module's largest source of garbage.
local function read_players(manager)
	return manager:players()
end

local function players_of(manager)
	local ok, players = pcall(read_players, manager)

	return ok and players or nil
end

local function read_alive(unit)
	return Unit.alive(unit)
end

local function unit_is_alive(unit)
	local ok, alive = pcall(read_alive, unit)

	return ok and alive and true or false
end

local function read_position(unit)
	return Unit.world_position(unit, 1)
end

local function unit_position(unit)
	local ok, pos = pcall(read_position, unit)

	return ok and pos or nil
end

local function read_slot(player)
	return player.slot and player:slot()
end

local function player_slot(player)
	local ok, slot = pcall(read_slot, player)

	return ok and slot or 0
end

local function read_is_bot(player)
	return player.is_human_controlled and not player:is_human_controlled()
end

local function player_is_bot(player)
	local ok, is_bot = pcall(read_is_bot, player)

	return ok and is_bot == true
end

local function safe(fn)
	local ok, r = pcall(fn)
	if ok then
		return r
	end
	return nil
end

local function get_io()
	local mods = rawget(_G, "Mods")
	return (mods and mods.lua and mods.lua.io) or rawget(_G, "_io") or rawget(_G, "io")
end

local function get_os()
	local mods = rawget(_G, "Mods")
	return (mods and mods.lua and mods.lua.os) or rawget(_G, "os")
end

-- Returns true when `dir` exists and is writable. Creating it needs a shell
-- call, which the mod sandbox may not expose - hence probe, try, probe again,
-- and let the caller fall back rather than losing anybody's archive.
local function ensure_output_dir(dir)
	local io_lib = get_io()

	if not io_lib or not io_lib.open then
		return false
	end

	local probe_path = dir .. "write_probe.tmp"
	local probe = safe(function()
		return io_lib.open(probe_path, "wb")
	end)

	if not probe then
		local os_lib = get_os()

		if not os_lib or not os_lib.execute then
			return false
		end

		-- 2>nul keeps the "already exists" case quiet; mkdir needs backslashes.
		safe(function()
			return os_lib.execute('mkdir "' .. dir:gsub("/", "\\"):gsub("\\+$", "") .. '" 2>nul')
		end)

		probe = safe(function()
			return io_lib.open(probe_path, "wb")
		end)

		if not probe then
			return false
		end
	end

	safe(function()
		probe:close()
	end)

	if io_lib.remove then
		safe(function()
			return io_lib.remove(probe_path)
		end)
	end

	return true
end

local function configure_default_output_dir()
	local os_lib = get_os()
	local appdata = os_lib and os_lib.getenv and safe(function()
		return os_lib.getenv("APPDATA")
	end)

	if type(appdata) ~= "string" or appdata == "" then
		return
	end

	local base = appdata:gsub("\\", "/"):gsub("/+$", "") .. "/Fatshark/Darktide/"

	-- Previous layout: loose strikemap_*.lua files directly in Darktide's user
	-- folder. Kept as a migration source, and as the fallback when the
	-- subfolder cannot be created.
	ROOT.dir = base
	OUT_DIR = base
	INDEX_NAME = ROOT.index
	REPORT_PREFIX = ROOT.prefix

	-- Preferred layout: our own subfolder, so the archive does not clutter a
	-- directory shared with the game and every other mod.
	local sub = base .. "strikemap/"

	if ensure_output_dir(sub) then
		OUT_DIR = sub
		INDEX_NAME = "reports_index.lua"
		REPORT_PREFIX = "report_"
	end

	INDEX_PATH = OUT_DIR .. INDEX_NAME
end

configure_default_output_dir()

local function report_path(id)
	return OUT_DIR .. REPORT_PREFIX .. tostring(id) .. ".lua"
end

local function legacy_report_path(id)
	return LEGACY_OUT_DIR .. "report_" .. tostring(id) .. ".lua"
end

local function now_stamp()
	local os_lib = get_os()
	return os_lib and os_lib.time and safe(function()
		return os_lib.time()
	end) or nil
end

-- Challenge level 1..5 (Sedition..Damnation); nil when unavailable.
local function mission_difficulty()
	return safe(function()
		local dm = Managers and Managers.state and Managers.state.difficulty

		return dm and dm.get_difficulty and dm:get_difficulty() or nil
	end)
end

-- The mission's real display name ("Silo Cluster 18-66/a" ...), resolved once
-- at capture time so the archive never depends on localization being loaded.
local function mission_display_title(mission)
	local title = safe(function()
		local templates = require("scripts/settings/mission/mission_templates")
		local template = templates and templates[mission]
		local name = template and template.mission_name
		local localize = rawget(_G, "Localize")

		return name and localize and localize(name) or nil
	end)

	if type(title) == "string" and title ~= "" and not title:find("<") then
		return title
	end

	return nil
end

-- Player class ("veteran"/"zealot"/"psyker"/"ogryn"/"adamant"), best effort.
local function player_archetype(player)
	local arch = safe(function()
		return player.archetype_name and player:archetype_name()
	end) or safe(function()
		local profile = player.profile and player:profile()
		local archetype = profile and profile.archetype

		return archetype and (archetype.name or archetype.archetype_name)
	end)

	return type(arch) == "string" and arch or nil
end

local function load_lua(path)
	local io_lib = get_io()
	local load_fn = (rawget(_G, "Mods") and Mods.lua and Mods.lua.loadstring)
		or rawget(_G, "loadstring") or load

	if not io_lib or not load_fn then
		return nil
	end

	local file = io_lib.open(path, "r")

	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	if type(content) ~= "string" or content == "" then
		return nil
	end

	local chunk = load_fn(content, path)

	if not chunk then
		return nil
	end

	local ok, result = pcall(chunk)

	if ok and type(result) == "table" then
		return result
	end

	return nil
end

local function copy_file(source, target)
	local io_lib = get_io()

	if not io_lib then
		return false
	end

	local src = io_lib.open(source, "r")

	if not src then
		return false
	end

	local content = src:read("*all")
	src:close()

	if type(content) ~= "string" or content == "" then
		return false
	end

	local dst = io_lib.open(target, "w")

	if not dst then
		return false
	end

	dst:write(content)
	dst:close()

	return true
end

-- ---------------------------------------------------------------------------
-- Serialization (targeted, not generic: the report shape is fixed)
-- ---------------------------------------------------------------------------
local function esc(s)
	return (tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("[\r\n]", " "))
end

local function num(v, dp)
	local s = string.format("%." .. dp .. "f", v)
	-- Strip trailing zeros only from the fractional part: a dotless integer
	-- like "600" must survive intact (dp=0 callers hit this).
	return (s:gsub("(%..-)0+$", "%1"):gsub("%.$", ""))
end

local SERIALIZE_CHUNK = 256

local function append_joined(chunks, values, separator)
	values = values or {}

	for first = 1, #values, SERIALIZE_CHUNK do
		local last = math.min(first + SERIALIZE_CHUNK - 1, #values)
		local part = {}

		for i = first, last do
			part[#part + 1] = values[i]
		end

		if first > 1 then
			chunks[#chunks + 1] = separator
		end

		chunks[#chunks + 1] = table.concat(part, separator)
		coroutine.yield()
	end
end

-- Runs inside a coroutine. Large packed replay arrays are joined in bounded
-- chunks so a checkpoint cannot monopolise a gameplay frame.
local function serialize_report(run)
	local chunks = {
		"-- strikemap mission report; generated in-game\nreturn {\n",
		"version = 3,\n",
		"id = " .. run.id .. ",\n",
		'mission = "' .. esc(run.mission) .. '",\n',
	}

	if run.title then
		chunks[#chunks + 1] = 'title = "' .. esc(run.title) .. '",\n'
	end

	if run.difficulty then
		chunks[#chunks + 1] = "difficulty = " .. tostring(run.difficulty) .. ",\n"
	end

	chunks[#chunks + 1] = "duration = " .. num(run.time, 1) .. ",\n"

	if run.date then
		chunks[#chunks + 1] = "date = " .. run.date .. ",\n"
	end

	if run.bounds then
		local b = run.bounds
		chunks[#chunks + 1] = string.format("bounds = {%s,%s,%s,%s,%s,%s},\n",
			num(b.x0, 2), num(b.y0, 2), num(b.x1, 2), num(b.y1, 2), num(b.z0, 1), num(b.z1, 1))
	end

	chunks[#chunks + 1] = "kills_stride = 4,\nkillt_stride = 4,\npath_stride = 4,\nkills = \""
	append_joined(chunks, run.kills, ";")
	chunks[#chunks + 1] = '\",\n'

	if run.boss_order and #run.boss_order > 0 then
		chunks[#chunks + 1] = "bosses = {\n"

		for i, rec in ipairs(run.boss_order) do
			chunks[#chunks + 1] = string.format(
				'{label = "%s", t0 = %s, t1 = %s, x = %s, y = %s, z = %s, by = %s},\n',
				esc(rec.label), num(rec.t0 or 0, 1), rec.t1 and num(rec.t1, 1) or "nil",
				num(rec.x or 0, 1), num(rec.y or 0, 1), num(rec.z or 0, 1),
				rec.by and ('"' .. esc(rec.by) .. '"') or "nil")

			if i % 16 == 0 then
				coroutine.yield()
			end
		end

		chunks[#chunks + 1] = "},\n"
	end

	chunks[#chunks + 1] = "players = {\n"

	local buckets = math.max(1, math.ceil(math.max(run.time, 1) / DMG_BUCKET))
	local players = {}

	for _, player in pairs(run.players) do
		players[#players + 1] = player
	end

	for _, p in ipairs(players) do
		local dmgt = {}

		for i = 1, buckets do
			dmgt[i] = tostring(math.floor((p.dmgb and p.dmgb[i] or 0) + 0.5))
		end

		chunks[#chunks + 1] = string.format(
			'{slot = %d, name = "%s", arch = "%s", is_local = %s, is_bot = %s, dist = %s, downtime = %s, '
			.. 'dmg = %d, taken = %d, kills = %d, hits = %d, wk = %d, crit = %d, revs = %d, '
			.. 'ammo = %d, med = %d, plasteel = %d, diamantine = %d, killt = "',
			p.slot or 0, esc(p.name), esc(p.arch or ""), tostring(p.is_local), tostring(p.is_bot or false),
			num(p.dist, 1), num(p.downtime or 0, 1),
			math.floor((p.dmg or 0) + 0.5), math.floor((p.taken or 0) + 0.5), p.kills or 0,
			p.hits or 0, p.wk or 0, p.crit or 0, p.revs or 0,
			p.ammo or 0, p.med or 0,
			math.floor((p.plasteel or 0) + 0.5), math.floor((p.diamantine or 0) + 0.5))

		append_joined(chunks, p.killt, ";")
		chunks[#chunks + 1] = '\", dmgt = "'
		append_joined(chunks, dmgt, ",")
		chunks[#chunks + 1] = '\", path = "'
		append_joined(chunks, p.path, ";")
		chunks[#chunks + 1] = '\", downs = {'

		for i, d in ipairs(p.downs) do
			chunks[#chunks + 1] = string.format('{x=%s,y=%s,z=%s,code=%d,t=%s,cause="%s"},',
				num(d.x, 1), num(d.y, 1), num(d.z, 1), d.code, num(d.t, 1), esc(d.cause or ""))

			if i % 64 == 0 then
				coroutine.yield()
			end
		end

		chunks[#chunks + 1] = "}},\n"
		coroutine.yield()
	end

	chunks[#chunks + 1] = "},\n}\n"

	return table.concat(chunks)
end

local function write_report_body(run, body)
	local io_lib = get_io()
	local file = io_lib and io_lib.open(report_path(run.id), "w")

	if not file then
		return false
	end

	file:write(body)
	file:close()

	return true
end

local function count_downs(run)
	local downs, deaths = 0, 0

	for _, p in pairs(run.players) do
		for i = 1, #p.downs do
			local code = p.downs[i].code

			if code == 3 then
				deaths = deaths + 1
			elseif code ~= 4 then -- recoveries are events, not downs
				downs = downs + 1
			end
		end
	end

	return downs, deaths
end

local function load_index()
	if _index then
		return _index
	end

	local loaded = load_lua(INDEX_PATH)

	-- Older archives: the flat %APPDATA% layout (pre-2.1.1), then the mod folder
	-- (pre-1.9.4). Newest source wins. Copy, never move: a failed or interrupted
	-- upgrade leaves the original archive untouched and retryable.
	if not loaded then
		local sources = {}

		if ROOT.dir then
			sources[#sources + 1] = {
				index = ROOT.dir .. ROOT.index,
				path = function(id)
					return ROOT.dir .. ROOT.prefix .. tostring(id) .. ".lua"
				end,
			}
		end

		sources[#sources + 1] = { index = LEGACY_INDEX_PATH, path = legacy_report_path }

		for s = 1, #sources do
			local source = sources[s]

			if source.index ~= INDEX_PATH then
				local legacy = load_lua(source.index)

				if legacy and type(legacy.runs) == "table" then
					for i = 1, #legacy.runs do
						local r = legacy.runs[i]

						if r and r.id then
							copy_file(source.path(r.id), report_path(r.id))
						end
					end

					copy_file(source.index, INDEX_PATH)
					loaded = legacy
					break
				end
			end
		end
	end

	_index = loaded or { next_id = 1, runs = {} }
	_index.next_id = _index.next_id or 1
	_index.runs = _index.runs or {}

	return _index
end

local function write_index()
	local index = load_index()
	local io_lib = get_io()
	local file = io_lib and io_lib.open(INDEX_PATH, "w")

	if not file then
		return false
	end

	file:write("-- strikemap reports index; generated in-game\nreturn {\n")
	file:write("next_id = " .. index.next_id .. ",\n")
	file:write("runs = {\n")

	for i = 1, #index.runs do
		local r = index.runs[i]
		file:write(string.format(
			'{id = %d, mission = "%s", title = %s, duration = %s, downs = %d, deaths = %d, players = %d, kills = %s, date = %s, difficulty = %s, favorite = %s},\n',
			r.id, esc(r.mission), r.title and ('"' .. esc(r.title) .. '"') or "nil",
			num(r.duration or 0, 0), r.downs or 0, r.deaths or 0, r.players or 0,
			r.kills and tostring(r.kills) or "nil",
			r.date and tostring(r.date) or "nil", r.difficulty and tostring(r.difficulty) or "nil",
			r.favorite == true and "true" or "nil"))
	end

	file:write("},\n}\n")
	file:close()

	return true
end

local function upsert_index(run)
	local index = load_index()
	local downs, deaths = count_downs(run)
	local nplayers = 0
	local total_kills = 0

	for _, p in pairs(run.players) do
		nplayers = nplayers + 1
		total_kills = total_kills + (p.kills or 0)
	end

	local summary = {
		id = run.id,
		mission = run.mission,
		title = run.title,
		duration = run.time,
		downs = downs,
		deaths = deaths,
		players = nplayers,
		kills = total_kills > 0 and total_kills or nil,
		date = run.date,
		difficulty = run.difficulty,
	}

	local found = false

	for i = 1, #index.runs do
		if index.runs[i].id == run.id then
			summary.favorite = index.runs[i].favorite == true or nil
			index.runs[i] = summary
			found = true

			break
		end
	end

	if not found then
		index.runs[#index.runs + 1] = summary

		if run.id >= index.next_id then
			index.next_id = run.id + 1
		end

		-- Favorites are exempt from retention. Keep MAX_INDEX ordinary reports
		-- plus any number the player explicitly protected.
		local ordinary = 0

		for i = 1, #index.runs do
			if index.runs[i].favorite ~= true then
				ordinary = ordinary + 1
			end
		end

		while ordinary > MAX_INDEX do
			local old_index

			for i = 1, #index.runs do
				if index.runs[i].favorite ~= true then
					old_index = i
					break
				end
			end

			if not old_index then
				break
			end

			local old = table.remove(index.runs, old_index)
			ordinary = ordinary - 1
			local os_lib = get_os()

			if os_lib and os_lib.remove and old and old.id then
				safe(function()
					os_lib.remove(report_path(old.id))
				end)
			end
		end
	end

	_view.runs = nil -- force the browser to rebuild its list
end

local function finish_checkpoint_job(job, body)
	local started = mod.perf_begin and mod.perf_begin()
	local written = write_report_body(job.run, body)

	if written then
		upsert_index(job.run)
		write_index()
		job.run.saved = true

		if job.final then
			job.run.final_save_complete = true
		end
	end

	if mod.perf_end and started then
		mod.perf_end("report file commit", started)
	end

	return written
end

local function drive_checkpoint_job(steps)
	steps = steps or 4

	for _ = 1, steps do
		local job = _checkpoint_job

		if not job then
			return true
		end

		local started = mod.perf_begin and mod.perf_begin()
		local ok, result = coroutine.resume(job.co)

		if mod.perf_end and started then
			mod.perf_end("report serialization slice", started)
		end

		if not ok then
			_checkpoint_job = nil
			safe(function()
				mod:warning("Strikemap report serialization failed: " .. tostring(result))
			end)

			return false
		end

		if coroutine.status(job.co) == "dead" then
			_checkpoint_job = nil
			return finish_checkpoint_job(job, result)
		end
	end

	return false
end

local function checkpoint(run, final, synchronous)
	if run.time < MIN_SAVE_TIME then
		return false
	end

	-- A final request supersedes an unfinished mid-run snapshot so the saved
	-- debrief includes everything captured up to freeze. Repeated final calls
	-- reuse/drain the same job instead of formatting and writing twice.
	if not (_checkpoint_job and _checkpoint_job.run == run
		and _checkpoint_job.final and final) then
		_checkpoint_job = {
			run = run,
			final = final == true,
			co = coroutine.create(function()
				return serialize_report(run)
			end),
		}
	end

	-- Direct/test calls and teardown drain synchronously for durability. Normal
	-- gameplay checkpoints and the end screen pass false and advance in slices.
	if synchronous ~= false then
		while _checkpoint_job and _checkpoint_job.run == run do
			drive_checkpoint_job(128)
		end
	end

	return run.saved == true
end

-- ---------------------------------------------------------------------------
-- Capture
-- ---------------------------------------------------------------------------
local function player_state_name(unit)
	return safe(function()
		local ud = ScriptUnit.has_extension(unit, "unit_data_system")
		local comp = ud and ud.read_component and ud:read_component("character_state")

		return comp and comp.state_name
	end)
end

-- What put the player in this state, for the event feed. Grab states map
-- 1:1 to a disabler; knockdown/death have no single attacker.
local function disable_cause(state)
	return DISABLER_BY_STATE[state] or ""
end

local function player_name(player, slot)
	local name = safe(function()
		return player.name and player:name()
	end)

	if type(name) == "string" and name ~= "" then
		return name
	end

	return "Player " .. slot
end

-- Stable per-character key so players who leave/join (or late joins) never merge
-- under a reused lobby slot. character_id() exists on both human and bot players.
local function player_stable_id(player, slot, name)
	local cid = safe(function()
		return player.character_id and player:character_id()
	end)

	if cid ~= nil and cid ~= "" then
		return "c:" .. tostring(cid)
	end

	local uid = safe(function()
		return player.unique_id and player:unique_id()
	end)

	if uid ~= nil then
		return "u:" .. tostring(uid)
	end

	return "n:" .. name
end

local function ensure_player(run, id, player, slot, name, is_local, is_bot)
	local p = run.players[id]

	if not p then
		p = {
			slot = slot,
			name = name,
			arch = nil,
			is_local = is_local,
			is_bot = is_bot,
			dist = 0,
			downtime = 0,
			path = {},
			downs = {},
			-- attributed combat stats (fed by the AttackReportManager hook)
			dmg = 0,       -- damage dealt
			taken = 0,     -- damage taken
			kills = 0,
			hits = 0,      -- attacks landed (for weakspot/crit rates)
			wk = 0,        -- weakspot hits
			crit = 0,      -- critical hits
			revs = 0,      -- teammates revived/rescued
			ammo = 0,      -- ammo pickups
			med = 0,       -- medicae station uses
			plasteel = 0,  -- crafting material amounts picked up
			diamantine = 0,
			killt = {},    -- packed "t,class,x,y" kill events (class 1 horde..4 boss)
			dmgb = {},     -- damage dealt per DMG_BUCKET-second bucket
			px = nil,      -- last frame's position (distance accumulator)
			py = nil,
			last_x = nil,  -- last stored path sample (decimation)
			last_y = nil,
			last_state = nil,
		}
		run.players[id] = p
	end

	-- refresh volatile identity each sample (slot can change, local resolves late)
	p.is_local = is_local
	p.is_bot = is_bot
	p.slot = slot

	return p
end

local function begin_run(mission)
	local index = load_index()

	_run = {
		id = index.next_id,
		mission = mission,
		title = mission_display_title(mission),
		difficulty = mission_difficulty(),
		time = 0,
		date = now_stamp(),
		players = {},
		kills = {},
		bosses = {},     -- victim_key -> {label, t0, t1, x, y, z, by}
		boss_order = {}, -- stable serialization order
		saved = false,
		frozen = false,
	}
	_sample_timer = 0
	_enemy_timer = 0
	_checkpoint_timer = 0
	_unit_records = {}
	_last_hit = {}
	_pending_rescue = {}

	for k in pairs(_prev_enemies) do
		_prev_enemies[k] = nil
	end
end

-- Resolve the player record that owns a player unit (same identity rules as
-- the tick), with a per-run fast path since attack reports arrive per hit.
local function player_record_for_unit(unit)
	if not _run or _run.frozen or not unit then
		return nil
	end

	local cached = _unit_records[unit]

	if cached then
		return cached
	end

	local player_manager = Managers and Managers.player
	local players = player_manager and safe(function()
		return player_manager:players()
	end)

	if type(players) ~= "table" then
		return nil
	end

	local local_player = safe(function()
		return player_manager:local_player(1)
	end)

	for _, player in pairs(players) do
		if player and player.player_unit == unit then
			local slot = safe(function()
				return player.slot and player:slot()
			end) or 0
			local name = player_name(player, slot)
			local id = player_stable_id(player, slot, name)
			local is_bot = safe(function()
				return player.is_human_controlled and not player:is_human_controlled()
			end) == true
			local p = ensure_player(_run, id, player, slot, name, player == local_player, is_bot)

			_unit_records[unit] = p

			return p
		end
	end

	return nil
end

-- ---------------------------------------------------------------------------
-- Attributed combat capture, fed by hooks in strikemap.lua (all client-safe:
-- AttackReportManager fires on every peer; the scoreboard mods run on it).
-- ---------------------------------------------------------------------------

-- A player's attack landed. class_code: 1 horde, 2 elite, 3 special, 4 boss.
function mod.report_damage_dealt(attacker_unit, damage, died, class_code, boss_label, victim_key, x, y, z, weakspot, crit)
	if not _run or _run.frozen or not combat_enabled() then
		return
	end

	local p = player_record_for_unit(attacker_unit)

	if not p then
		return
	end

	p.hits = p.hits + 1

	if weakspot then
		p.wk = p.wk + 1
	end

	if crit then
		p.crit = p.crit + 1
	end

	damage = tonumber(damage) or 0

	if damage > 0 then
		p.dmg = p.dmg + damage

		local bucket = math.floor(_run.time / DMG_BUCKET) + 1

		p.dmgb[bucket] = (p.dmgb[bucket] or 0) + damage
	end

	-- boss records: first blood marks the encounter, the killing blow closes it
	if boss_label and victim_key then
		local rec = _run.bosses[victim_key]

		if not rec then
			rec = { label = boss_label, t0 = _run.time, x = x, y = y, z = z }
			_run.bosses[victim_key] = rec
			_run.boss_order[#_run.boss_order + 1] = rec
		end

		if died and not rec.t1 then
			rec.t1 = _run.time
			rec.by = p.name
			rec.x, rec.y, rec.z = x or rec.x, y or rec.y, z or rec.z
		end
	end

	if died then
		p.kills = p.kills + 1

		if #p.killt < MAX_KILL_EVENTS then
			-- position included so the killzones heatmap can filter per player
			p.killt[#p.killt + 1] = num(_run.time, 1) .. "," .. (class_code or 1)
				.. "," .. num(x or 0, 1) .. "," .. num(y or 0, 1)
		end
	end
end

-- A player took a hit; remember who, so a knockdown right after gets blamed.
function mod.report_player_damaged(victim_unit, attacker_label, damage)
	if not _run or _run.frozen or mod:get("record_reports") == false then
		return
	end

	local p = player_record_for_unit(victim_unit)

	if not p then
		return
	end

	p.taken = p.taken + (tonumber(damage) or 0)

	if attacker_label and attacker_label ~= "" then
		local rec = _last_hit[victim_unit] or {}

		rec.label = attacker_label
		rec.t = _run.time
		_last_hit[victim_unit] = rec
	end
end

-- A player finished reviving/rescuing another; credit them and remember the
-- name so the rescued player's recovery event reads "revived by <name>".
function mod.report_rescue(rescuer_unit, rescued_unit)
	if not _run or _run.frozen or mod:get("record_reports") == false then
		return
	end

	local rescuer = player_record_for_unit(rescuer_unit)

	if rescuer then
		rescuer.revs = rescuer.revs + 1
	end

	if rescued_unit and rescuer then
		_pending_rescue[rescued_unit] = { name = rescuer.name, t = _run.time }
	end
end

-- kind: "ammo" | "med" (counts) or "plasteel" | "diamantine" (amounts)
function mod.report_pickup(unit, kind, count)
	if not _run or _run.frozen or mod:get("record_reports") == false then
		return
	end

	local p = player_record_for_unit(unit)

	if not p then
		return
	end

	if kind == "ammo" then
		p.ammo = p.ammo + 1
	elseif kind == "med" then
		p.med = p.med + 1
	elseif kind == "plasteel" then
		p.plasteel = p.plasteel + (tonumber(count) or 0)
	elseif kind == "diamantine" then
		p.diamantine = p.diamantine + (tonumber(count) or 0)
	end
end

-- The hub firing range is never worth a debrief. Psykhanium/Mortis sessions
-- are opt-in so training never silently fills the mission archive.
local function recording_skipped(mission_name)
	if mission_name == "shooting_range" then
		return true
	end

	return mission_name == "psykhanium" and mod:get("record_psykhanium") ~= true
end

-- Called every frame from mod.update while in a mission.
function mod.report_tick(dt, mission_name, map)
	if mod:get("record_reports") == false or recording_skipped(mission_name) then
		return
	end

	if not _run or _run.mission ~= mission_name then
		if _run then
			mod.report_finalize()
		end

		begin_run(mission_name)
	end

	-- Advance any crash checkpoint in small pieces before mutating this frame's
	-- capture. Four 256-entry chunks normally finishes within a fraction of a
	-- second without a single long serialization frame.
	drive_checkpoint_job(4)

	-- The end screen freezes the run: the mission is decided, so nothing that
	-- happens while people stare at the score should leak into the record.
	if _run.frozen then
		return
	end

	_run.time = _run.time + dt

	-- retry the difficulty/title lookups until they land (both can resolve late)
	if not _run.difficulty then
		_run.difficulty = mission_difficulty()
	end

	if not _run.title then
		_run.title = mission_display_title(mission_name)
	end

	-- adopt the mission's floor-plan bounds once, for standalone rendering
	if not _run.bounds and map and map.tri_count and map.tri_count > 0 then
		_run.bounds = safe(function()
			return mod.map_bounds and mod.map_bounds(map)
		end)
	end

	local player_manager = Managers and Managers.player

	if player_manager then
		local local_player = player_manager:local_player(1)

		_sample_timer = _sample_timer - dt
		local do_sample = _sample_timer <= 0

		for _, player in pairs(players_of(player_manager) or {}) do
			local unit = player.player_unit

			if unit and unit_is_alive(unit) then
				-- Identity (slot, display name, stable id, bot/local flags) costs
				-- several engine calls and a fresh id string. It cannot change
				-- between path samples, so resolve it on the sample tick and read
				-- the per-unit record on every other frame.
				local p = _unit_records[unit]

				if not p or do_sample then
					local slot = player_slot(player)
					local name = player_name(player, slot)
					local id = player_stable_id(player, slot, name)
					local is_local = player == local_player
					local is_bot = player_is_bot(player)

					p = ensure_player(_run, id, player, slot, name, is_local, is_bot)
					_unit_records[unit] = p

					if not p.arch then
						p.arch = player_archetype(player)
					end
				end

				local pos = unit_position(unit)

				if pos then
					-- distance travelled: per-frame delta against the last frame's
					-- position (NOT the last path sample - that double-counts), and
					-- teleports (arena transitions, respawns) are not metres walked
					if p.px then
						local step_x, step_y = pos.x - p.px, pos.y - p.py
						local step_sq = step_x * step_x + step_y * step_y

						if step_sq <= TELEPORT_DIST_SQ then
							p.dist = p.dist + math.sqrt(step_sq)
						end
					end

					p.px, p.py = pos.x, pos.y

					-- path point, decimated by distance or time. Stationary
					-- players add nothing (the replay lerps across the gap),
					-- and time samples respect the per-player rate below.
					local min_move = p.path_min_move or SAMPLE_MOVE
					local moved = p.last_x and ((pos.x - p.last_x) ^ 2 + (pos.y - p.last_y) ^ 2) or math.huge
					local time_due = do_sample and moved > 0.02
						and (_run.time - (p.path_last_t or -1e9)) >= SAMPLE_TIME * (min_move / SAMPLE_MOVE)

					if time_due or moved > min_move * min_move then
						if #p.path >= MAX_PATH_POINTS then
							-- marathon run: halve the stored resolution and
							-- coarsen future sampling instead of freezing the
							-- trail. Spacing stays far below the view's 40m
							-- teleport cutoff, so lines keep connecting.
							local kept = 0

							for pi = 1, #p.path, 2 do
								kept = kept + 1
								p.path[kept] = p.path[pi]
							end

							for pi = kept + 1, #p.path do
								p.path[pi] = nil
							end

							p.path_min_move = min_move * 2
						end

						-- z included so routes hug their floor in the 3D debrief
						p.path[#p.path + 1] = num(pos.x, 1) .. "," .. num(pos.y, 1) .. ","
							.. num(pos.z, 1) .. "," .. num(_run.time, 1)
						p.path_last_t = _run.time
						p.last_x, p.last_y = pos.x, pos.y
					elseif not p.last_x then
						p.last_x, p.last_y = pos.x, pos.y
					end

					-- down / death / recovery transitions
					local state = player_state_name(unit)
					local code = state and DOWN_CODE[state]
					local prev_code = p.last_state and DOWN_CODE[p.last_state]

					if code and code ~= prev_code then
						local cause = ""

						if code == 2 then
							cause = disable_cause(state)
						elseif code == 1 then
							-- blame the knockdown on whoever hit them last
							local hit = _last_hit[unit]

							if hit and (_run.time - hit.t) <= HIT_ATTRIBUTION_WINDOW then
								cause = hit.label
							end
						end

						p.downs[#p.downs + 1] = {
							x = pos.x, y = pos.y, z = pos.z, code = code,
							t = _run.time, cause = cause,
						}
					elseif not code and prev_code and state ~= nil then
						-- rescued / untangled / respawned: back in the fight,
						-- credited to whoever finished the revive interaction
						local rescue = _pending_rescue[unit]
						local cause = ""

						if rescue and (_run.time - rescue.t) <= RESCUE_ATTRIBUTION_WINDOW then
							cause = rescue.name
							_pending_rescue[unit] = nil
						end

						p.downs[#p.downs + 1] = {
							x = pos.x, y = pos.y, z = pos.z, code = 4,
							t = _run.time, cause = cause,
						}
					end

					-- time spent incapacitated (down or disabled, not dead)
					if code == 1 or code == 2 then
						p.downtime = p.downtime + dt
					end

					p.last_state = state
				end
			end
		end

		if do_sample then
			_sample_timer = SAMPLE_TIME
		end
	end

	-- Mid-run checkpoints are crash insurance only; report_freeze always saves
	-- at the end screen, so a setting of 0 ("end of mission only") loses nothing
	-- but the crash safety net. The interval is only read when one comes due.
	_checkpoint_timer = _checkpoint_timer - dt

	if _checkpoint_timer <= 0 then
		local interval = checkpoint_interval()

		_checkpoint_timer = interval > 0 and interval or CHECKPOINT_DEFAULT

		if interval > 0 then
			pcall(checkpoint, _run, false, false)
		end
	end
end

-- Called from collect_enemies with the current alive enemy units + positions,
-- so we can log where enemies disappear (a proxy for kills near the player).
function mod.report_capture_enemies(units, positions, count)
	if not _run or _run.frozen or mod:get("record_reports") == false then
		return
	end

	-- Stamping a generation onto the surviving records replaces the throwaway
	-- `seen` set this used to rebuild several times a second -- during a horde
	-- that table grows to hundreds of entries and is discarded every tick.
	_enemy_gen = _enemy_gen + 1

	for i = 1, count do
		local unit = units[i]
		local pos = positions[i]

		if unit and pos then
			local rec = _prev_enemies[unit]

			if not rec then
				rec = {}
				_prev_enemies[unit] = rec
			end

			rec.x = pos.x
			rec.y = pos.y
			rec.z = pos.z
			rec.gen = _enemy_gen
		end
	end

	-- any previously-alive enemy no longer present = died or left range; log it
	-- (with the run time, so the debrief can plot combat intensity over the run)
	for unit, pos in pairs(_prev_enemies) do
		if pos.gen ~= _enemy_gen then
			if #_run.kills < MAX_KILLS then
				_run.kills[#_run.kills + 1] = num(pos.x, 1) .. "," .. num(pos.y, 1) .. "," .. num(pos.z, 1)
					.. "," .. num(_run.time, 1)
			end

			_prev_enemies[unit] = nil
		end
	end
end

-- Called when the end-of-mission screen appears: checkpoint and stop recording
-- without discarding the run (mission change still finalizes it normally).
function mod.report_freeze()
	if _run and not _run.frozen then
		_run.frozen = true
		safe(function()
			checkpoint(_run, true, false)
		end)
	end
end

-- Called on mission end / leaving to hub.
function mod.report_finalize()
	if _run then
		if not _run.final_save_complete then
			safe(function()
				checkpoint(_run, true, true)
			end)
		end

		_run = nil
		_checkpoint_job = nil
	end
end

-- ---------------------------------------------------------------------------
-- Browser / view state (read by the element)
-- ---------------------------------------------------------------------------
local function build_run_list()
	local index = load_index()
	local runs = {}

	for i = #index.runs, 1, -1 do -- newest first
		runs[#runs + 1] = index.runs[i]
	end

	_view.runs = runs

	if _view.sel > #runs then
		_view.sel = math.max(1, #runs)
	end

	return runs
end

-- Reports saved before downs became structured records store them as a packed
-- "x,y,z,code,t;..." string. Convert to records at load so every consumer sees
-- one shape (and old archives keep working across the format change).
local function normalize_report(report)
	if type(report) ~= "table" or type(report.players) ~= "table" then
		return report
	end

	-- v1 kills were "x,y,z" triplets; v2 appends the run time as a 4th value.
	-- v3.0 killt was "t,class" pairs; v3.1 appends the kill position.
	-- Paths were "x,y,t" triplets; v3.2 stores "x,y,z,t" for the 3D debrief.
	report.kills_stride = report.kills_stride or 3
	report.killt_stride = report.killt_stride or 2
	report.path_stride = report.path_stride or 3

	for _, p in ipairs(report.players) do
		if type(p.downs) == "string" then
			local flat, n = {}, 0

			for v in p.downs:gmatch("[^,;]+") do
				n = n + 1
				flat[n] = tonumber(v) or 0
			end

			local recs = {}

			for i = 0, math.floor(n / 5) - 1 do
				recs[#recs + 1] = {
					x = flat[i * 5 + 1], y = flat[i * 5 + 2], z = flat[i * 5 + 3],
					code = flat[i * 5 + 4], t = flat[i * 5 + 5], cause = "",
				}
			end

			p.downs = recs
		elseif type(p.downs) ~= "table" then
			p.downs = {}
		end
	end

	return report
end

local function load_selected()
	local runs = _view.runs or build_run_list()
	local summary = runs[_view.sel]

	if not summary then
		_view.report = nil
		_view.map = nil

		return
	end

	if _view.report_id ~= summary.id then
		_view.report = normalize_report(load_lua(report_path(summary.id)))
		_view.report_id = summary.id
		_view.map = nil
		_view.map_mission = nil
	end

	local mission = _view.report and _view.report.mission

	if mission and _view.map_mission ~= mission then
		_view.map = safe(function()
			return mod.load_map and mod.load_map(mission)
		end)
		_view.map_mission = mission
	end
end

function mod.report_view()
	if _view.open then
		load_selected()
	end

	return _view
end

function mod.report_browser_toggle()
	mod.report_browser_set_open(not _view.open)
end

-- Explicit open/close, driven by the report UIView's enter/exit.
function mod.report_browser_set_open(open)
	_view.open = open and true or false

	if _view.open then
		_view.sel = 1
		build_run_list()
	end
end

function mod.report_browser_select(index)
	local runs = _view.runs or build_run_list()

	if #runs > 0 then
		_view.sel = math.max(1, math.min(index, #runs))
	end
end

-- Mark/unmark a run as protected. Favorite reports are never removed by the
-- automatic retention cap (manual deletion remains available).
function mod.report_toggle_favorite(id)
	id = tonumber(id)

	if not id then
		return nil
	end

	local index = load_index()
	local favorite

	for i = 1, #index.runs do
		local r = index.runs[i]

		if r and r.id == id then
			if r.favorite == true then
				r.favorite = nil
			else
				r.favorite = true
			end

			favorite = r.favorite == true
			break
		end
	end

	if favorite == nil then
		return nil
	end

	write_index()
	_view.runs = nil

	if _view.open then
		build_run_list()
		load_selected()
	end

	return favorite
end

-- Delete a saved run: its report file and its index entry. Refreshes the
-- browser list so the view updates on the next frame.
function mod.report_delete(id)
	id = tonumber(id)

	if not id then
		return false
	end

	local index = load_index()
	local removed = false

	for i = #index.runs, 1, -1 do
		local r = index.runs[i]

		if r and r.id == id then
			table.remove(index.runs, i)
			removed = true
		end
	end

	if removed then
		write_index()
	end

	local os_lib = get_os()

	if os_lib and os_lib.remove then
		safe(function()
			os_lib.remove(report_path(id))
		end)
	end

	if _view.report_id == id then
		_view.report = nil
		_view.report_id = nil
	end

	if _view.open then
		build_run_list()
		load_selected()
	end

	return removed
end

function mod.report_browser_next()
	if not _view.open then
		return
	end

	local runs = _view.runs or build_run_list()

	if #runs > 0 then
		_view.sel = _view.sel % #runs + 1
	end
end

function mod.report_browser_prev()
	if not _view.open then
		return
	end

	local runs = _view.runs or build_run_list()

	if #runs > 0 then
		_view.sel = (_view.sel - 2) % #runs + 1
	end
end

function mod.report_cycle_layer()
	if not _view.open then
		return
	end

	_view.layer = _view.layer == "path" and "time"
		or _view.layer == "time" and "kills"
		or "path"
end

function mod.report_diag_lines(add)
	add("report: " .. (_run and ("recording " .. _run.mission .. " t=" .. num(_run.time, 0)
		.. " saved=" .. tostring(_run.saved)) or "idle")
		.. "  checkpoint=" .. (_checkpoint_job and (_checkpoint_job.final and "final" or "staged") or "idle")
		.. "  browser=" .. tostring(_view.open) .. " sel=" .. _view.sel)
end

-- Exposed for the offline harness; unused in game.
mod.__test_reports = {
	view = _view,
	run = function()
		return _run
	end,
	set_out_dir = function(dir)
		OUT_DIR = dir
		INDEX_NAME = "reports_index.lua"
		REPORT_PREFIX = "report_"
		INDEX_PATH = dir .. INDEX_NAME
	end,
	-- Points the pre-2.1.1 flat-layout migration source at a temp folder.
	set_root_dir = function(dir)
		ROOT.dir = dir
	end,
	ensure_output_dir = ensure_output_dir,
	begin_run = begin_run,
	checkpoint = checkpoint,
	load_index = load_index,
	num = num,
	reset = function()
		_run = nil
		_checkpoint_job = nil
		_index = nil
		_view.runs = nil
		_view.report = nil
		_view.report_id = nil
		_view.map = nil
		_view.map_mission = nil
	end,
}
