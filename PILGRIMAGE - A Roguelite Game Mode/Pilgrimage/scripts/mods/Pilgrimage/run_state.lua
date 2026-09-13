-- run_state.lua
--
-- The save file for an in-progress pilgrimage.
--
-- THE HARD CONSTRAINT: between missions, the mod's Lua state is gone. Locals,
-- module tables, mechanism_data, all wiped by the level change. The only channel
-- that survives a level load AND a game restart is DMF settings (mod:get / mod:set),
-- which is exactly how SoloPlay keeps its mission choice alive across the same gap.
--
-- So the run lives in settings, and this module is the only thing allowed to touch
-- those keys.
--
-- ENCODING CHOICE: everything is stored as a flat string, number or boolean. No
-- nested tables. Two reasons:
--
--   * DMF's settings save has known failure modes with awkward table shapes (table
--     keys in particular), and a hard engine fault underneath a pcall is not
--     something we want in the run-save path. Flat scalars cannot trip it.
--
--   * Lists as delimited strings is what the game itself does. Havoc orders are a
--     semicolon and colon joined string. We are following an existing convention,
--     not inventing one.
--
-- Setting keys are underscore-prefixed. They are never declared in Pilgrimage_data.lua,
-- so they persist correctly but never appear as a widget in the options menu.

local M = {}

local _mod
local _event_log
local _shared
local _character_runs

-- ---------------------------------------------------------------------------
-- Keys
-- ---------------------------------------------------------------------------

local KEY = {
	active     = "_run_active",     -- boolean
	seed       = "_run_seed",       -- number
	queue      = "_run_queue",      -- "mission_a,mission_b,mission_c"
	index      = "_run_index",      -- number, 1-based, which leg we are on
	boons      = "_run_boons",      -- "buff_name:3,other_buff:1"
	curses     = "_run_curses",     -- "modifier_name.2,other_modifier.1"
	legs_done  = "_run_legs_done",  -- "mission_a:complete,mission_b:failed"
	curse_queue = "_run_curse_queue", -- "darkness_01,default,toxic_gas_01", aligned with queue
	started_at = "_run_started_at", -- number, wall clock
	draft      = "_run_draft",      -- number, the leg a boon draft is owed for, 0 = none
	-- v0.28.7: Legendary-offer pity state. `legendary_misses` is the
	-- consecutive number of drafts without a Legendary. The evaluated draft
	-- and chance make reopening one offer idempotent instead of rerolling it
	-- after the miss counter changes.
	legendary_misses      = "_run_legendary_misses",
	legendary_eval_draft  = "_run_legendary_eval_draft",
	legendary_eval_chance = "_run_legendary_eval_chance",
	second_reading_leg    = "_run_second_reading_leg",
	wager_escrow          = "_run_wager_escrow",
	wager_remainder       = "_run_wager_remainder",

	-- What the launcher last launched. Written immediately before the session
	-- teardown, read by mutator_guard in the MISSION's fresh Lua VM, which is
	-- why this must be settings and not memory: the level load wipes memory.
	launch_mission      = "_launch_mission",      -- string, internal mission id
	launch_circumstance = "_launch_circumstance", -- string, circumstance name

	-- v0.18.0: the danger index the RUN started at. Each leg's actual danger
	-- is computed from this by difficulty.for_leg(state.index, starting_...).
	-- Stored per-run so an in-progress run's ramp is stable across restarts
	-- even if the mod option changes mid-run.
	starting_difficulty = "_run_starting_difficulty",

	-- v0.19.0: the War Plan this run belongs to. Read by penances.observe
	-- on run_complete to decide which penance to award. Empty means the
	-- default plan (novitiate) or a run from before v0.19.
	plan_id = "_run_plan_id",

	-- v0.20.0: whether this specific run is under Blitz. Captured at
	-- run start from the mod setting, then never re-read for the run's
	-- lifetime. Toggling the mod option mid-run does not change the mode
	-- of the run in progress, which is Kaizen's design: Blitz is a
	-- commitment, not a UI convenience.
	blitz = "_run_blitz",

	-- v0.22.49 (Session B): per-run stat trackers. All reset by
	-- M.start(); persist across mission loads (same channel as everything
	-- else here). Reader is the run_complete penance observer; writers are
	-- scattered hooks (see the section header below the state schema).
	stat_archetype           = "_run_stat_archetype",        -- string, "veteran" | "zealot" | ...
	stat_ever_downed         = "_run_stat_ever_downed",      -- boolean
	stat_downs               = "_run_stat_downs",            -- number, total downs this run
	stat_boons_taken         = "_run_stat_boons_taken",      -- number, boons picked in the run's drafts
	stat_hp_damage_taken     = "_run_stat_hp_damage",        -- number, HP damage across the whole run
	stat_ranged_hp_damage    = "_run_stat_ranged_hp_damage", -- number, HP damage from ranged attacks only
	stat_shop_purchases      = "_run_stat_shop_purchases",   -- number, shop items bought this run
	stat_bots_slotted        = "_run_stat_bots_slotted",     -- number, count of bots on the roster this run

	-- v0.22.77 (Session B phase 2): damage-dealt split + companion kills
	-- + Martyrdom uptime. Writers: the StatsManager record_private hook in
	-- Pilgrimage.lua (damage/kills) and the penance_time Tick task in
	-- bootstrap.lua (time counters). Damage/kill increments update the
	-- in-memory state WITHOUT saving per hit (a swing can land a dozen
	-- events a second); the 1s penance_time task performs the periodic
	-- save that folds them to DMF settings, and run/mission-complete
	-- readers see the exact in-memory values.
	stat_total_damage        = "_run_stat_total_damage",     -- number, damage dealt by the human player this run
	stat_electric_damage     = "_run_stat_electric_damage",  -- number, subset with an electricity damage_type
	stat_companion_kills     = "_run_stat_companion_kills",  -- number, kills credited to the player's dog
	stat_martyrdom_time      = "_run_stat_martyrdom_time",   -- seconds at 3+ Martyrdom stacks (Zealot)
	stat_active_time         = "_run_stat_active_time",      -- seconds of in-mission play observed by the poll

	-- v0.22.49: per-MISSION stat trackers. Reset by M.mission_start_stats(),
	-- called from the mission-start emitter. Reader is any per-mission
	-- penance check (e.g. Abelard: no HP damage in a single Fanatic mission).
	mission_stat_hp_damage = "_mission_stat_hp_damage",       -- number, HP damage this mission
	mission_stat_mission   = "_mission_stat_mission",         -- string, which mission this counter covers
	-- v0.22.80: elite/specialist kills by Peril overload detonation
	-- this mission (Idira's unlock penance, Unsanctioned Fury).
	mission_stat_overload_kills = "_mission_stat_overload_kills",
	mission_stat_ever_downed = "_mission_stat_ever_downed",
}

-- v0.22.49: persistent cross-run counters. NOT reset by M.start();
-- accumulate forever. Used by penances that count across runs
-- (Data-Hymn: 20 interrogators, Machine Spirit Banishment: 200
-- Voltaic Emitter weapon-disables, The Devoted: 10 missions completed).
-- Namespaced separately so a run reset never clobbers them.
local PERSIST_KEY = {
	total_runs_completed        = "_stat_total_runs_completed",
	total_missions_completed    = "_stat_total_missions_completed",
	total_interrogators_hacked  = "_stat_total_interrogators_hacked",  -- via Skitarii bot skull
	total_voltaic_disables      = "_stat_total_voltaic_disables",       -- via Voltaic Emitter blitz
}
M.PERSIST_KEY = PERSIST_KEY

M.KEY = KEY

-- ---------------------------------------------------------------------------
-- Encoding helpers
--
-- Deliberately strict: anything containing a separator character is rejected at
-- write time rather than silently corrupting the whole string on the next read.
-- ---------------------------------------------------------------------------

local LIST_SEP = ","
local PAIR_SEP = ":"
local TIER_SEP = "."

local function _clean(value)
	value = tostring(value or "")
	if value:find("[,:]") then return nil end
	return value
end

-- { "a", "b" }  ->  "a,b"
local function _encode_list(list)
	if type(list) ~= "table" then return "" end
	local out = {}
	for i = 1, #list do
		local item = _clean(list[i])
		if item and item ~= "" then out[#out + 1] = item end
	end
	return table.concat(out, LIST_SEP)
end

-- "a,b"  ->  { "a", "b" }
local function _decode_list(text)
	local out = {}
	if type(text) ~= "string" or text == "" then return out end
	for item in string.gmatch(text, "([^" .. LIST_SEP .. "]+)") do
		out[#out + 1] = item
	end
	return out
end

-- { name = 3 }  ->  "name:3"
local function _encode_counts(map, separator)
	if type(map) ~= "table" then return "" end
	separator = separator or PAIR_SEP

	-- Sorted so the same state always produces the same string. Makes the setting
	-- diffable and stops needless writes when nothing actually changed.
	local names = {}
	for name in pairs(map) do names[#names + 1] = name end
	table.sort(names)

	local out = {}
	for i = 1, #names do
		local name = _clean(names[i])
		local count = tonumber(map[names[i]])
		if name and name ~= "" and count and count > 0 then
			out[#out + 1] = name .. separator .. tostring(math.floor(count))
		end
	end
	return table.concat(out, LIST_SEP)
end

-- "name:3"  ->  { name = 3 }
local function _decode_counts(text, separator)
	local out = {}
	if type(text) ~= "string" or text == "" then return out end
	separator = separator or PAIR_SEP

	-- Escaped for the pattern, because "." is a wildcard in Lua patterns.
	local escaped = separator == TIER_SEP and "%." or separator

	for entry in string.gmatch(text, "([^" .. LIST_SEP .. "]+)") do
		local name, count = string.match(entry, "^(.-)" .. escaped .. "(%d+)$")
		if name and count then
			out[name] = tonumber(count)
		end
	end
	return out
end

M.encode_list = _encode_list
M.decode_list = _decode_list
M.encode_counts = _encode_counts
M.decode_counts = _decode_counts

-- ---------------------------------------------------------------------------
-- Load and save
-- ---------------------------------------------------------------------------

-- The in-memory view of the run. Rebuilt from settings on every load, so it is safe
-- for it to be wiped by a level change.
local _state = nil

local function _blank()
	return {
		active     = false,
		seed       = 0,
		queue      = {},
		curse_queue = {},
		index      = 0,
		boons      = {},
		curses     = {},
		legs_done  = {},
		started_at = 0,
		draft      = 0,
		legendary_misses = 0,
		legendary_eval_draft = 0,
		legendary_eval_chance = 0,
		second_reading_leg = 0,
		wager_escrow = 0,
		wager_remainder = 0,
		starting_difficulty = 0, -- 0 = fall back to the mod option at read time
		plan_id = "",
		blitz   = false,
		-- v0.22.49: per-run stats (see KEY.stat_* above)
		stat_archetype        = "",
		stat_ever_downed      = false,
		stat_downs            = 0,
		stat_boons_taken      = 0,
		stat_hp_damage_taken  = 0,
		stat_ranged_hp_damage = 0,
		stat_shop_purchases   = 0,
		stat_bots_slotted     = 0,
		-- v0.22.77: damage-dealt / companion / time stats
		stat_total_damage     = 0,
		stat_electric_damage  = 0,
		stat_companion_kills  = 0,
		stat_martyrdom_time   = 0,
		stat_active_time      = 0,
		-- v0.22.49: per-mission stats
		mission_stat_hp_damage = 0,
		mission_stat_mission   = "",
		mission_stat_overload_kills = 0,  -- v0.22.80
		mission_stat_ever_downed = false,
	}
end

function M.load()
	if not _mod then return _blank() end

	_state = {
		active     = _mod:get(KEY.active) == true,
		seed       = tonumber(_mod:get(KEY.seed)) or 0,
		queue      = _decode_list(_mod:get(KEY.queue)),
		curse_queue = _decode_list(_mod:get(KEY.curse_queue)),
		index      = tonumber(_mod:get(KEY.index)) or 0,
		boons      = _decode_counts(_mod:get(KEY.boons), PAIR_SEP),
		curses     = _decode_counts(_mod:get(KEY.curses), TIER_SEP),
		legs_done  = _decode_list(_mod:get(KEY.legs_done)),
		started_at = tonumber(_mod:get(KEY.started_at)) or 0,
		draft      = tonumber(_mod:get(KEY.draft)) or 0,
		legendary_misses = tonumber(_mod:get(KEY.legendary_misses)) or 0,
		legendary_eval_draft = tonumber(_mod:get(KEY.legendary_eval_draft)) or 0,
		legendary_eval_chance = tonumber(_mod:get(KEY.legendary_eval_chance)) or 0,
		second_reading_leg = tonumber(_mod:get(KEY.second_reading_leg)) or 0,
		wager_escrow = tonumber(_mod:get(KEY.wager_escrow)) or 0,
		wager_remainder = tonumber(_mod:get(KEY.wager_remainder)) or 0,
		starting_difficulty = tonumber(_mod:get(KEY.starting_difficulty)) or 0,
		plan_id    = _mod:get(KEY.plan_id) or "",
		blitz      = _mod:get(KEY.blitz) == true,
		-- v0.22.49: per-run stats
		stat_archetype        = _mod:get(KEY.stat_archetype) or "",
		stat_ever_downed      = _mod:get(KEY.stat_ever_downed) == true,
		stat_downs            = tonumber(_mod:get(KEY.stat_downs)) or 0,
		stat_boons_taken      = tonumber(_mod:get(KEY.stat_boons_taken)) or 0,
		stat_hp_damage_taken  = tonumber(_mod:get(KEY.stat_hp_damage_taken)) or 0,
		stat_ranged_hp_damage = tonumber(_mod:get(KEY.stat_ranged_hp_damage)) or 0,
		stat_shop_purchases   = tonumber(_mod:get(KEY.stat_shop_purchases)) or 0,
		stat_bots_slotted     = tonumber(_mod:get(KEY.stat_bots_slotted)) or 0,
		-- v0.22.77
		stat_total_damage     = tonumber(_mod:get(KEY.stat_total_damage)) or 0,
		stat_electric_damage  = tonumber(_mod:get(KEY.stat_electric_damage)) or 0,
		stat_companion_kills  = tonumber(_mod:get(KEY.stat_companion_kills)) or 0,
		stat_martyrdom_time   = tonumber(_mod:get(KEY.stat_martyrdom_time)) or 0,
		stat_active_time      = tonumber(_mod:get(KEY.stat_active_time)) or 0,
		mission_stat_hp_damage = tonumber(_mod:get(KEY.mission_stat_hp_damage)) or 0,
		mission_stat_mission   = _mod:get(KEY.mission_stat_mission) or "",
		mission_stat_overload_kills = tonumber(_mod:get(KEY.mission_stat_overload_kills)) or 0,
		mission_stat_ever_downed = _mod:get(KEY.mission_stat_ever_downed) == true,
	}

	-- Repair an index that has drifted outside the queue. Better to clamp than to
	-- hand gameplay code a nil mission name.
	local queue_length = #_state.queue
	if _state.active and (_state.index < 1 or _state.index > queue_length) then
		_state.index = math.max(1, math.min(_state.index, queue_length))
	end

	return _state
end

-- ---------------------------------------------------------------------------
-- Flushing to disk
--
-- WHY THIS EXISTS AT ALL
--
-- mod:set only updates DMF's in-memory settings table and raises a dirty flag. The
-- actual write to user_settings.config happens in exactly two places, both in
-- dmf_loader.lua:
--
--     dmf_mod_object:on_game_state_changed(...)  -> save_unsaved_settings_to_file()
--     dmf_mod_object:on_unload()                 -> save_unsaved_settings_to_file()
--
-- BE PRECISE ABOUT WHAT THAT LEAVES UNCOVERED, because I overstated it once and had to
-- be corrected by the config file. Between those two, a clean quit always writes the run
-- correctly: the dirty flag is still up and the in-memory values are already right, so
-- on_unload flushes the lot. Kaizen's failed run persisted perfectly through a normal
-- exit with this whole module doing nothing.
--
-- The gap is a hard kill. A crash, an alt-F4, a power cut: no state change, no unload,
-- and everything since the last level load is gone. A leg failing, a boon picked up or a
-- run abandoned all happen in the Mourningstar with no state change after them, so they
-- sit in memory for as long as you stay there. That window is the entire reason this
-- layer exists. It is a narrow case, not a broken save.
--
-- THE BUG THIS REPLACES
--
-- The previous version reached for the flush function through `rawget(_G, "dmf")`.
-- Line 1 of dmf_loader.lua is `local dmf`, so DMF's own handle is a FILE-LOCAL and
-- never becomes a global at all. The lookup returned nil on every single call and the
-- forced flush silently never ran. It was wrapped in a nil check, so it failed as a
-- no-op rather than an error, which is why it went unnoticed until a failed run was
-- observed still sitting in the config file as active.
--
-- The supported way in is get_mod("DMF"), which is what DMF's own modules use:
-- settings.lua does `local dmf = get_mod("DMF")` and then defines
-- `function dmf.save_unsaved_settings_to_file()` on that object.
--
-- KNOWN LIMITATION, HANDLED
--
-- save_all_settings() writes EVERY mod's settings in one Application.set_user_setting
-- call, and bails out early if that call fails, for instance because some other mod
-- stored a mixed array/map table. It returns nothing either way, so a caller cannot
-- tell success from failure. So we verify instead of trusting: read the value back out
-- of the engine's own settings store and compare. If it does not match, we know the
-- write did not land and we say so, rather than reporting a save that did not happen.
-- ---------------------------------------------------------------------------

local FLUSH_MIN_INTERVAL_S = 2

local _flush_pending = false
local _last_flush_t = -1e9

-- Diagnostics, surfaced by /pil_status. This is the thing that would have caught the
-- bug above on the first test instead of the fifth.
local _flush_info = {
	resolver   = "unresolved",
	attempts   = 0,
	verified   = 0,
	unverified = 0,
	errors     = 0,
	last_error = nil,
}

local function _resolve_flush()
	local ok, dmf_mod = pcall(get_mod, "DMF")
	if ok and type(dmf_mod) == "table"
		and type(dmf_mod.save_unsaved_settings_to_file) == "function" then
		return dmf_mod.save_unsaved_settings_to_file, "get_mod"
	end

	-- Kept only as a fallback in case a future DMF does export a global. It is not
	-- expected to hit.
	local global_dmf = rawget(_G, "dmf")
	if type(global_dmf) == "table"
		and type(global_dmf.save_unsaved_settings_to_file) == "function" then
		return global_dmf.save_unsaved_settings_to_file, "global"
	end

	return nil, "unavailable"
end

-- Reads the setting back out of the engine store and checks that our own value is
-- there. Application.user_setting reads the same table that set_user_setting writes,
-- so this confirms the value reached the engine, which is the step that can silently
-- fail. It does not prove the file hit the disk; nothing available to us does.
local function _verify()
	if not _mod or not _state then return false end

	local ok, all = pcall(Application.user_setting, "mods_settings")
	if not ok or type(all) ~= "table" then return false end

	local mine = all[_mod:get_name()]
	if type(mine) ~= "table" then return false end
	if _character_runs then
		local active_key = _character_runs.key(KEY.active)
		if not active_key then return false end
		return mine[active_key] == (_state.active == true)
			and tonumber(mine[_character_runs.key(KEY.index)]) == math.floor(_state.index or 0)
			and mine[_character_runs.key(KEY.legs_done)] == _encode_list(_state.legs_done)
	end

	return mine[KEY.active] == (_state.active == true)
		and tonumber(mine[KEY.index]) == math.floor(_state.index or 0)
		and mine[KEY.legs_done] == _encode_list(_state.legs_done)
end

-- force = true skips the throttle. Used for every run-shaping transition, where losing
-- the write matters more than the cost of a file write.
function M.flush(force, t)
	t = t or (_shared and _shared.fixed_time and _shared.fixed_time()) or 0

	if not force and (t - _last_flush_t) < FLUSH_MIN_INTERVAL_S then
		_flush_pending = true
		return false, "throttled"
	end

	local flush_fn, resolver = _resolve_flush()
	_flush_info.resolver = resolver

	if not flush_fn then
		_flush_pending = true
		_flush_info.errors = _flush_info.errors + 1
		_flush_info.last_error = "no flush function"
		return false, "unavailable"
	end

	_flush_info.attempts = _flush_info.attempts + 1
	_last_flush_t = t
	_flush_pending = false

	local ok, err = pcall(flush_fn)
	if not ok then
		_flush_info.errors = _flush_info.errors + 1
		_flush_info.last_error = tostring(err)
		return false, tostring(err)
	end

	if _verify() then
		_flush_info.verified = _flush_info.verified + 1
		return true
	end

	-- The engine store does not contain what we just wrote. Almost always this means
	-- Application.set_user_setting threw inside DMF, usually because another mod saved
	-- a mixed table. Retry on the next tick: DMF keeps its dirty flag set, so a later
	-- attempt costs nothing and may succeed once the other mod settles.
	_flush_info.unverified = _flush_info.unverified + 1
	_flush_info.last_error = "write did not verify"
	_flush_pending = true
	return false, "unverified"
end

-- Registered on the tick scheduler. Picks up anything the throttle deferred, and
-- retries a write that failed verification.
function M.flush_tick(t)
	if not _flush_pending then return end
	M.flush(true, t)
end

-- Resolve the flush entry point without writing anything, so /pil_status can answer
-- "will a save actually reach disk" before the first save rather than after it. Called
-- from init. A blank diagnostic at the exact moment you want to check the diagnostic is
-- worth nothing.
function M.probe_flush()
	local flush_fn, resolver = _resolve_flush()
	_flush_info.resolver = resolver
	return flush_fn ~= nil, resolver
end

function M.flush_status()
	return {
		resolver   = _flush_info.resolver,
		attempts   = _flush_info.attempts,
		verified   = _flush_info.verified,
		unverified = _flush_info.unverified,
		errors     = _flush_info.errors,
		last_error = _flush_info.last_error,
		pending    = _flush_pending,
	}
end

-- v0.22.79: second parameter `no_flush`. When true, the settings values
-- are written to DMF's in-memory table (raising its dirty flag, so
-- DMF's own state-change save picks them up) but M.flush is NOT called.
-- This exists because in-mission stat writers fire constantly (the 1s
-- penance_time task, every damage-taken event) and each flush is a
-- SYNCHRONOUS whole-settings-file write; at the flush throttle's 2s
-- minimum interval that produced a metronomic freeze every ~2 seconds
-- in missions (Kaizen's v0.22.77 field report). Run-shaping transitions
-- (run start/advance/end, mission start) still force real flushes, so
-- the crash-safety window only covers in-mission stat increments, which
-- are noise at penance scale.
function M.save(force, no_flush)
	if not _mod or not _state then return end
	if _character_runs and not _character_runs.ready() then return end

	-- The third argument to mod:set is DMF's "notify" flag. false means do not fire
	-- on_setting_changed and do not rebuild the options UI, which we never want for
	-- these internal keys. It does NOT affect the dirty flag: DMFMod:set raises that
	-- unconditionally, so the value is queued for saving either way.
	_mod:set(KEY.active,     _state.active == true, false)
	_mod:set(KEY.seed,       math.floor(_state.seed or 0), false)
	_mod:set(KEY.queue,      _encode_list(_state.queue), false)
	_mod:set(KEY.curse_queue, _encode_list(_state.curse_queue), false)
	_mod:set(KEY.index,      math.floor(_state.index or 0), false)
	_mod:set(KEY.boons,      _encode_counts(_state.boons, PAIR_SEP), false)
	_mod:set(KEY.curses,     _encode_counts(_state.curses, TIER_SEP), false)
	_mod:set(KEY.legs_done,  _encode_list(_state.legs_done), false)
	_mod:set(KEY.started_at, math.floor(_state.started_at or 0), false)
	_mod:set(KEY.draft,      math.floor(_state.draft or 0), false)
	_mod:set(KEY.legendary_misses, math.floor(_state.legendary_misses or 0), false)
	_mod:set(KEY.legendary_eval_draft, math.floor(_state.legendary_eval_draft or 0), false)
	_mod:set(KEY.legendary_eval_chance, math.floor(_state.legendary_eval_chance or 0), false)
	_mod:set(KEY.second_reading_leg, math.floor(_state.second_reading_leg or 0), false)
	_mod:set(KEY.wager_escrow, math.floor(_state.wager_escrow or 0), false)
	_mod:set(KEY.wager_remainder, math.floor(_state.wager_remainder or 0), false)
	_mod:set(KEY.starting_difficulty, math.floor(_state.starting_difficulty or 0), false)
	_mod:set(KEY.plan_id, tostring(_state.plan_id or ""), false)
	_mod:set(KEY.blitz,   _state.blitz == true, false)
	-- v0.22.49: per-run stats
	_mod:set(KEY.stat_archetype,        tostring(_state.stat_archetype or ""),        false)
	_mod:set(KEY.stat_ever_downed,      _state.stat_ever_downed == true,              false)
	_mod:set(KEY.stat_downs,            math.floor(_state.stat_downs or 0),           false)
	_mod:set(KEY.stat_boons_taken,      math.floor(_state.stat_boons_taken or 0),     false)
	_mod:set(KEY.stat_hp_damage_taken,  math.floor(_state.stat_hp_damage_taken or 0), false)
	_mod:set(KEY.stat_ranged_hp_damage, math.floor(_state.stat_ranged_hp_damage or 0),false)
	_mod:set(KEY.stat_shop_purchases,   math.floor(_state.stat_shop_purchases or 0),  false)
	_mod:set(KEY.stat_bots_slotted,     math.floor(_state.stat_bots_slotted or 0),    false)
	-- v0.22.77: damage totals floored (fractional damage points don't
	-- matter at penance scale); time counters kept to one decimal so a
	-- reload doesn't repeatedly shave sub-second remainders.
	_mod:set(KEY.stat_total_damage,     math.floor(_state.stat_total_damage or 0),    false)
	_mod:set(KEY.stat_electric_damage,  math.floor(_state.stat_electric_damage or 0), false)
	_mod:set(KEY.stat_companion_kills,  math.floor(_state.stat_companion_kills or 0), false)
	_mod:set(KEY.stat_martyrdom_time,   math.floor((_state.stat_martyrdom_time or 0) * 10) / 10, false)
	_mod:set(KEY.stat_active_time,      math.floor((_state.stat_active_time or 0) * 10) / 10, false)
	_mod:set(KEY.mission_stat_hp_damage, math.floor(_state.mission_stat_hp_damage or 0), false)
	_mod:set(KEY.mission_stat_mission,  tostring(_state.mission_stat_mission or ""),  false)
	_mod:set(KEY.mission_stat_overload_kills, math.floor(_state.mission_stat_overload_kills or 0), false)
	_mod:set(KEY.mission_stat_ever_downed, _state.mission_stat_ever_downed == true, false)

	-- Default to forcing. Every current caller is a run-shaping transition, and the
	-- throttle exists for the future high-frequency case (boon pickups during a
	-- mission), not for these.
	if not no_flush then
		M.flush(force ~= false)
	end
end

function M.get()
	if not _state then M.load() end
	return _state
end

function M.is_active()
	return M.get().active == true
end

-- ---------------------------------------------------------------------------
-- Mutations. Each one saves, because a run that is not written down is a run that
-- dies with the next loading screen.
-- ---------------------------------------------------------------------------

-- curse_queue is optional and aligned with queue: curse_queue[i] is the circumstance
-- leg i launches under, "default" meaning none. It is route data, decided at preview
-- time, so it is stored with the route rather than rolled at launch: the leg you are
-- auto-chained into and the same leg entered through the terminal must be the same leg.
--
-- v0.20.0: blitz is captured here from whatever the setting says at run
-- start, and lives out the run in this field. Toggling the mod option later
-- does not change the mode of the run in progress.
function M.start(queue, seed, curse_queue, starting_difficulty, plan_id, blitz)
	if _character_runs and not _character_runs.ready() then return false, "operative not available" end
	if _character_runs then
		_mod:set("_run_pending_mission", "", false)
		_mod:set("_run_pending_outcome", "", false)
		_mod:set("_run_pending_result", "", false)
	end
	_state = _blank()
	_state.active = true
	_state.queue = queue or {}
	_state.curse_queue = curse_queue or {}
	_state.index = 1
	_state.seed = seed or 0
	_state.started_at = os.time and os.time() or 0
	-- The starting difficulty is captured AT RUN START and stays fixed for
	-- the run's lifetime, so changing the mod option mid-run doesn't rewrite
	-- the ramp under a running pilgrimage. 0 means "read the option at
	-- launch time" for legacy runs that predate v0.18.0.
	_state.starting_difficulty = math.floor(starting_difficulty or 0)
	_state.plan_id = tostring(plan_id or "")
	_state.blitz = blitz == true

	-- A pilgrimage opens with a choice. Leg 1 is drafted before you ever launch, so the
	-- route preview and the first boon are one visit to the terminal, not two.
	_state.draft = 1
	M.save()

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "run_start",
		id = _event_log.next_id(),
		queue = _encode_list(_state.queue),
		seed = _state.seed,
	})

	return _state
end

function M.abandon(reason)
	local previous = M.get()
	_event_log.emit({
		t = _shared.fixed_time(),
		event = "run_abandon",
		id = _event_log.next_id(),
		reason = tostring(reason or "manual"),
		leg = previous.index,
	})

	_state = _blank()
	M.save()
end

-- End the run WITHOUT wiping it. abandon() clears everything, which is right when
-- you deliberately throw a run away, but wrong when a run ends by failing: the queue,
-- the seed and the per-leg results are exactly what you want to look at afterwards.
-- Boons are RUN SCOPED. Everything picked during a pilgrimage dies with it, whether it
-- ended in success or in failure, and a fresh run starts with nothing.
--
-- They are already inert once the run is inactive, because Boons.apply_all refuses to do
-- anything without an active run. Clearing them anyway matters for two reasons: the
-- terminal would otherwise still list them as owned while showing a dead run, and a
-- future permanent-unlock system must never be able to confuse a leftover temporary boon
-- for something earned.
local function _clear_run_scoped(state)
	for name in pairs(state.boons) do state.boons[name] = nil end
	for name in pairs(state.curses) do state.curses[name] = nil end
	state.draft = 0
	state.legendary_misses = 0
	state.legendary_eval_draft = 0
	state.legendary_eval_chance = 0
	state.second_reading_leg = 0
end

function M.end_run(reason)
	local state = M.get()
	if not state.active then return false end

	state.active = false
	_clear_run_scoped(state)
	M.save()

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "run_ended",
		id = _event_log.next_id(),
		reason = tostring(reason or "ended"),
		leg = state.index,
		legs = #state.queue,
	})

	return true
end

-- ---------------------------------------------------------------------------
-- The boon draft
--
-- Stored as the LEG NUMBER a draft is owed for rather than a boolean, for two reasons.
-- A boolean cannot tell you whether it belongs to the leg you are on or a stale one left
-- behind by a run that ended badly, and the leg number is what seeds the draft, so
-- holding it means the same three choices come back after a crash instead of a fresh
-- roll. 0 means nothing is owed.
-- ---------------------------------------------------------------------------

function M.owe_draft(leg)
	local state = M.get()
	state.draft = math.floor(leg or state.index or 0)
	M.save()
end

function M.clear_draft()
	local state = M.get()
	if state.draft == 0 then return end
	state.draft = 0
	M.save()
end

-- A DEBT, NOT A NOTIFICATION.
--
-- This used to require draft == index, so a pick you were offered on leg 2 stopped
-- counting the moment leg 2 ended. Close the window, or leave the mission, and the boon
-- was gone: the terminal would not offer it and neither would the next leg, because the
-- number no longer matched. The mod was tracking whether a draft had been OFFERED rather
-- than whether one had been TAKEN.
--
-- Now anything owed at or before the current leg is still owed. The debt survives until
-- it is paid by choosing, or written off by the run ending. Ahead of the current leg is
-- still rejected, since that could only be corruption.
function M.draft_pending()
	local state = M.get()
	return state.active and state.draft > 0 and state.draft <= state.index
end

-- v0.28.7: a run-scoped pity curve for the rare in-mission Legendary offer.
-- It starts at 15%, rises by 15 percentage points after each evaluated draft
-- without a Legendary, and caps at 100%. Reopening the same draft reuses the
-- exact chance that was first evaluated, so closing the menu is never a reroll.
local LEGENDARY_PITY_STEP = 15

function M.legendary_leak_chance(draft_leg)
	local state = M.get()
	local leg = math.floor(draft_leg or state.draft or 0)
	if leg > 0 and math.floor(state.legendary_eval_draft or 0) == leg then
		local evaluated = math.floor(state.legendary_eval_chance or 0)
		if evaluated > 0 then return math.min(100, evaluated) end
	end

	local misses = math.max(0, math.floor(state.legendary_misses or 0))
	return math.min(100, LEGENDARY_PITY_STEP * (misses + 1))
end

function M.record_legendary_offer(draft_leg, chance, offered)
	local state = M.get()
	if not state.active then return false end

	local leg = math.floor(draft_leg or state.draft or 0)
	if leg <= 0 or math.floor(state.legendary_eval_draft or 0) == leg then
		return false
	end

	state.legendary_eval_draft = leg
	state.legendary_eval_chance = math.max(0, math.min(100,
		math.floor(chance or M.legendary_leak_chance(leg))))
	if offered then
		state.legendary_misses = 0
	else
		-- Six misses already make the next chance 100%; there is no reason
		-- to let a corrupted or legacy value grow without bound.
		state.legendary_misses = math.min(6,
			math.max(0, math.floor(state.legendary_misses or 0)) + 1)
	end
	M.save()
	return true
end

-- ---------------------------------------------------------------------------
-- The launch record
--
-- Two flat keys, not part of the run proper: they describe the LAST LAUNCH, so
-- the mission-side guard can compare "what is the engine about to run" against
-- "what did the launcher actually ask for". Forced flush, because the whole
-- point is surviving the level load that is about to happen.
-- ---------------------------------------------------------------------------

function M.record_launch(mission_name, circumstance_name)
	if not _mod then return end
	if _character_runs and not _character_runs.record_launch() then return false end
	_mod:set(KEY.launch_mission, tostring(mission_name or ""), false)
	_mod:set(KEY.launch_circumstance, tostring(circumstance_name or "default"), false)
	M.flush(true)
end

-- { mission = "...", circumstance = "..." }, or nil when nothing was recorded.
function M.launch_record()
	if not _mod then return nil end
	if _character_runs and not _character_runs.launch_matches() then return nil end
	local mission = _mod:get(KEY.launch_mission)
	if type(mission) ~= "string" or mission == "" then return nil end
	local circumstance = _mod:get(KEY.launch_circumstance)
	if type(circumstance) ~= "string" or circumstance == "" then
		circumstance = "default"
	end
	return { mission = mission, circumstance = circumstance,
		character_id = _character_runs and _character_runs.owner() or nil }
end

-- The circumstance the CURRENT leg launches under. nil when the run carries no curse
-- for this leg, which the launcher treats as "default".
-- v0.22.34: overwrite the assigned curse for a specific leg. Used by
-- Skip (curse_skip): the shop consumable permanently replaces the
-- skipped leg's curse with "default" in state.curse_queue, so both
-- the current launch and every future stacking pass on later legs
-- naturally exclude the skipped one. Persisted next flush so the
-- change survives a game restart mid-run.
function M.set_curse_at(index, name)
	if not _state.active then return false, "no active run" end
	if type(index) ~= "number" or index < 1 then return false, "bad index" end
	_state.curse_queue[index] = name or "default"
	-- Persist immediately (force=true) so the change survives a game
	-- crash between set and next scheduled flush. Skip is a one-off
	-- purchase; losing which leg it targeted would be much worse than
	-- one extra disk write.
	M.save()
	M.flush(true)
	return true
end

function M.current_curse()
	local state = M.get()
	if not state.active then return nil end
	local curse = state.curse_queue[state.index]
	if not curse or curse == "" or curse == "default" then return nil end
	return curse
end

-- The curses of every assignment up to AND INCLUDING the current one, in queue
-- order. This is the input to curse stacking: assignment N runs the union of
-- these. Holes read as "default" so the list always lines up with the index.
function M.curse_prefix()
	local state = M.get()
	if not state.active then return nil end
	local out = {}
	for i = 1, state.index do
		out[i] = state.curse_queue[i] or "default"
	end
	return out
end

function M.current_mission()
	local state = M.get()
	if not state.active then return nil end
	return state.queue[state.index]
end

-- Returns the next mission name, or nil when the run is finished.
function M.advance(result)
	local state = M.get()
	if not state.active then return nil end

	local finished = state.queue[state.index]
	state.legs_done[#state.legs_done + 1] =
		tostring(finished or "unknown") .. "=" .. tostring(result or "complete")

	state.index = state.index + 1

	local next_mission = state.queue[state.index]
	if not next_mission then
		-- Walked the whole route. The run is over and its boons go with it, exactly as
		-- they would on a failure. Winning does not let you keep them.
		state.active = false
		_clear_run_scoped(state)
	else
		-- Surviving a leg earns the pick for the next one, but ONLY if the last one was
		-- actually taken. An outstanding debt is left standing rather than moved forward,
		-- so skipping a pick does not quietly earn you a second one later. One owed at a
		-- time, and it keeps the leg number that seeds it, so the same three choices come
		-- back rather than a fresh roll.
		if (state.draft or 0) == 0 then
			state.draft = state.index
		end
	end
	M.save()

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "run_advance",
		id = _event_log.next_id(),
		finished = finished,
		result = tostring(result or "complete"),
		next_mission = next_mission,
		leg = state.index,
	})

	return next_mission
end

-- Boons are the one thing that can arrive in bursts, several within a few seconds of
-- each other mid-mission, so these two take the throttled path. Nothing is lost by it:
-- flush_tick picks up whatever the throttle deferred.
function M.add_boon(name, stacks)
	local state = M.get()
	state.boons[name] = (state.boons[name] or 0) + (stacks or 1)
	-- v0.22.49: every boon added counts toward stat_boons_taken. Zero
	-- Waste and Perfect Pilgrimage penances read this. Increments once
	-- per call regardless of `stacks`, matching the "boons taken from
	-- drafts" semantic (each draft pick is one add_boon call).
	state.stat_boons_taken = (state.stat_boons_taken or 0) + 1
	M.save(false)

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "boon_gained",
		id = _event_log.next_id(),
		boon = name,
		stacks = state.boons[name],
	})
end

function M.add_curse(name, level)
	local state = M.get()
	state.curses[name] = math.max(state.curses[name] or 0, level or 1)
	M.save(false)
end

-- ===========================================================================
-- v0.22.49 (Session B): stat mutators
-- ===========================================================================
--
-- One function per stat. Each one is a no-op when there's no active run, so
-- the callers (which live in engine hooks that fire all the time, in and out
-- of missions) don't need their own gating.
--
-- All these take the throttled save path (like add_boon) because they can
-- fire many times per second in combat. flush_tick catches the trailing
-- write. The forced-save path is reserved for run-shaping transitions.
--
-- Cross-run persistent counters (see PERSIST_KEY) live at the bottom of this
-- block; they don't gate on active run and don't touch _state at all.

-- Called ONCE per run from the mission-start hook. Overwrites whatever was
-- there, because a run only has one player archetype (the human host).
function M.set_archetype(archetype_name, no_flush)
	if type(archetype_name) ~= "string" or archetype_name == "" then return end
	local state = M.get()
	if not state.active then return end
	state.stat_archetype = archetype_name
	M.save(true, no_flush)  -- state-entry callers use DMF's single final save
end

function M.mark_downed()
	local state = M.get()
	if not state.active then return end
	state.stat_ever_downed = true
	state.mission_stat_ever_downed = true
	state.stat_downs = (state.stat_downs or 0) + 1
	-- v0.22.79: no_flush; a mid-fight down is a bad moment for a
	-- synchronous settings-file write.
	M.save(false, true)
end

function M.second_reading_used(leg)
	return (M.get().second_reading_leg or 0) == math.floor(tonumber(leg) or -1)
end

function M.use_second_reading(leg)
	local state = M.get()
	leg = math.floor(tonumber(leg) or 0)
	if not state.active or leg <= 0 or state.second_reading_leg == leg then
		return false
	end
	state.second_reading_leg = leg
	M.save(true)
	return true
end

function M.wager_withhold(amount)
	local state = M.get()
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	-- Keep the modulo-four remainder so repeated one-Ordo pickups still
	-- contribute an exact integer 25% over time. This also works after the
	-- final advance flips the run inactive but before its completion bonus is
	-- settled.
	local quarter_units = math.max(0, math.floor(state.wager_remainder or 0)) + amount
	local stake = math.floor(quarter_units / 4)
	state.wager_remainder = quarter_units % 4
	state.wager_escrow = (state.wager_escrow or 0) + stake
	-- Material pickups can arrive repeatedly in combat. Queue the settings
	-- change in memory and let the normal transition save flush it, avoiding a
	-- synchronous whole-settings write on each pickup.
	M.save(false, true)
	return stake
end

function M.wager_escrow()
	return math.max(0, math.floor(M.get().wager_escrow or 0))
end

function M.clear_wager_escrow()
	local state = M.get()
	local amount = math.max(0, math.floor(state.wager_escrow or 0))
	state.wager_escrow = 0
	state.wager_remainder = 0
	M.save(true)
	return amount
end

function M.add_boon_taken()
	local state = M.get()
	if not state.active then return end
	state.stat_boons_taken = (state.stat_boons_taken or 0) + 1
	M.save(false)
end

-- amount: HP points of damage taken. is_ranged: true if from a ranged attack.
-- Both counters run in parallel so a single damage event lands in both the
-- run-total and (conditionally) the ranged-only tally.
function M.add_hp_damage_taken(amount, is_ranged)
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	local state = M.get()
	if not state.active then return end
	state.stat_hp_damage_taken = (state.stat_hp_damage_taken or 0) + amount
	state.mission_stat_hp_damage = (state.mission_stat_hp_damage or 0) + amount
	if is_ranged then
		state.stat_ranged_hp_damage = (state.stat_ranged_hp_damage or 0) + amount
	end
	-- v0.22.79: no_flush; fires on every damage event in combat.
	M.save(false, true)
end

-- v0.22.77 (Session B phase 2): damage DEALT by the human player.
-- amount: damage points. is_electric: true when the damage_type belongs
-- to the electricity family (Biolightning's numerator). Deliberately does
-- NOT call M.save(): this fires many times a second in combat, and the
-- 1s penance_time Tick task (bootstrap.lua) performs the periodic save
-- that folds these into DMF settings. Worst case on a hard kill we lose
-- a second or two of damage stats, which is noise at penance scale.
function M.add_damage_dealt(amount, is_electric)
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	local state = M.get()
	if not state.active then return end
	state.stat_total_damage = (state.stat_total_damage or 0) + amount
	if is_electric then
		state.stat_electric_damage = (state.stat_electric_damage or 0) + amount
	end
end

-- v0.22.77: a kill credited to the player's companion dog (Warrant
-- Served). Low frequency, but rides the same deferred-save cadence as
-- damage for consistency.
function M.add_companion_kill()
	local state = M.get()
	if not state.active then return end
	state.stat_companion_kills = (state.stat_companion_kills or 0) + 1
end

-- v0.22.77: called once per second by the penance_time Tick task while
-- in an active-run MISSION (never the hub, never the Psykhanium, never
-- loading screens; the task gates before calling). delta: seconds since
-- the task's previous sample, clamped by the caller. martyrdom_active:
-- true when the player is a Zealot with the Martyrdom keystone at 3+
-- stacks this sample. This is also the periodic save point that folds
-- the deferred damage/kill counters to DMF settings.
function M.add_combat_time(delta, martyrdom_active)
	delta = tonumber(delta) or 0
	if delta <= 0 then return end
	local state = M.get()
	if not state.active then return end
	state.stat_active_time = (state.stat_active_time or 0) + delta
	if martyrdom_active then
		state.stat_martyrdom_time = (state.stat_martyrdom_time or 0) + delta
	end
	-- v0.22.79: no_flush. This fires every second in missions; flushing
	-- from here was the 2s-freeze bug. See M.save.
	M.save(false, true)
end

function M.add_shop_purchase()
	local state = M.get()
	if not state.active then return end
	state.stat_shop_purchases = (state.stat_shop_purchases or 0) + 1
	M.save(false)
end

function M.set_bots_slotted(n, no_flush)
	n = tonumber(n) or 0
	local state = M.get()
	if not state.active then return end
	state.stat_bots_slotted = math.max(state.stat_bots_slotted or 0, n)
	M.save(false, no_flush)
end

-- Called at the start of each mission (from the launcher's mission-start
-- hook). Resets the per-mission counters (leaving the run-total counters
-- untouched) and records which mission the counter is now covering.
function M.mission_start_stats(mission_name, no_flush)
	local state = M.get()
	if not state.active then return end
	state.mission_stat_hp_damage = 0
	state.mission_stat_mission = tostring(mission_name or "")
	state.mission_stat_overload_kills = 0  -- v0.22.80
	state.mission_stat_ever_downed = false
	M.save(true, no_flush)
end

-- v0.22.80: an elite or specialist destroyed by the local player's
-- Peril overload detonation. Per-mission scope (Idira's Unsanctioned
-- Fury). no_flush like every in-mission stat writer.
function M.add_overload_elite_kill()
	local state = M.get()
	if not state.active then return end
	state.mission_stat_overload_kills = (state.mission_stat_overload_kills or 0) + 1
	M.save(false, true)
end

-- Snapshot every stat as one flat table, suitable for handing to
-- penances.observe as the event payload. Kept as a single helper so future
-- fields go in one place, and so the observe payload stays consistent
-- across all triggers (run_complete, mission_complete).
function M.stat_snapshot()
	local state = M.get()
	local curses_stacked = 0
	for _ in pairs(state.curses or {}) do curses_stacked = curses_stacked + 1 end
	return {
		archetype           = state.stat_archetype or "",
		ever_downed         = state.stat_ever_downed == true,
		downs               = state.stat_downs or 0,
		boons_taken         = state.stat_boons_taken or 0,
		hp_damage_taken     = state.stat_hp_damage_taken or 0,
		ranged_hp_damage    = state.stat_ranged_hp_damage or 0,
		shop_purchases      = state.stat_shop_purchases or 0,
		bots_slotted        = state.stat_bots_slotted or 0,
		curses_stacked      = curses_stacked,
		mission_hp_damage   = state.mission_stat_hp_damage or 0,
		mission_name        = state.mission_stat_mission or "",
		mission_overload_elite_kills = state.mission_stat_overload_kills or 0,  -- v0.22.80
		mission_ever_downed = state.mission_stat_ever_downed == true,
		-- v0.22.77 (Session B phase 2)
		total_damage_dealt       = state.stat_total_damage or 0,
		electricity_damage_dealt = state.stat_electric_damage or 0,
		companion_kills          = state.stat_companion_kills or 0,
		martyrdom_time           = state.stat_martyrdom_time or 0,
		active_time              = state.stat_active_time or 0,
		-- The ratio the Dancing on the Web check reads. 0 until any
		-- in-mission time has been observed.
		martyrdom_time_pct       = (state.stat_active_time or 0) > 0
			and (state.stat_martyrdom_time or 0) / state.stat_active_time or 0,
	}
end

-- ===========================================================================
-- Persistent counters (cross-run)
-- ===========================================================================
--
-- These do NOT live in _state. They're plain settings keys that accumulate
-- forever and survive run resets. Reader/writer for each is a pair of
-- functions rather than a class method, since there's no shared state.

function M.persist_get(key)
	if not _mod then return 0 end
	if not PERSIST_KEY[key] then return 0 end
	return tonumber(_mod:get(PERSIST_KEY[key])) or 0
end

function M.persist_add(key, delta)
	if not _mod then return end
	if not PERSIST_KEY[key] then return end
	delta = tonumber(delta) or 0
	if delta == 0 then return end
	local current = tonumber(_mod:get(PERSIST_KEY[key])) or 0
	_mod:set(PERSIST_KEY[key], current + delta, false)
	-- No forced flush here; DMF's own auto-save at state changes will pick
	-- these up. Persistent stats are less time-critical than run state.
end

-- ---------------------------------------------------------------------------

function M.summary()
	local state = M.get()
	if not state.active then return "no active run" end

	local boons = {}
	for name, stacks in pairs(state.boons) do
		boons[#boons + 1] = name .. " x" .. tostring(stacks)
	end
	table.sort(boons)

	return string.format("leg %d/%d (%s) | seed %d | boons: %s",
		state.index,
		#state.queue,
		tostring(state.queue[state.index] or "?"),
		state.seed,
		#boons > 0 and table.concat(boons, ", ") or "none")
end

function M.init(deps)
	_mod = deps.mod
	_character_runs = deps.character_runs
	_event_log = deps.event_log
	_shared = deps.shared
	M.load()
	-- The mission counter was introduced after the older run counter. Preserve
	-- a conservative lower bound for existing saves: every completed run proves
	-- at least one successful mission, without guessing how many legs it had.
	if _mod then
		local prior_runs = tonumber(_mod:get(PERSIST_KEY.total_runs_completed)) or 0
		local current_missions = tonumber(_mod:get(PERSIST_KEY.total_missions_completed)) or 0
		if prior_runs > current_missions then
			_mod:set(PERSIST_KEY.total_missions_completed, prior_runs, false)
		end
	end
	M.probe_flush()
end

return M
