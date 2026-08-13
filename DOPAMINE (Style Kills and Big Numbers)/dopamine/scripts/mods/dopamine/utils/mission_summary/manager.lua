

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_manager then
	return mod.mission_summary_manager
end

local Stats = mod:core(mod.mission_summary_stats, "utils/mission_summary/stats")
local History = mod:core(mod.mission_summary_history, "utils/mission_summary/history_store")
local Presentation = mod:core(mod.mission_summary_presentation, "hud/mission_summary/presentation")
local C = mod:core(mod.mission_summary_constants, "hud/mission_summary/constants")

local DIFFICULTY_NAMES = { "Sedition", "Uprising", "Malice", "Heresy", "Damnation" }

local REAL_MISSION_MODES = {
	coop_complete_objective = true,
	expedition = true,
	survival = true,
}

---@class MissionSummaryMission
---@field id string|nil
---@field difficulty number|nil
---@field difficulty_name string|nil
---@field display string|nil
---@field outcome string|nil
---@field is_auric boolean|nil       -- auric mission (challenge 5 / resistance 5 danger tier)
---@field is_maelstrom boolean|nil   -- maelstrom, i.e. a "flash mission" circumstance
---@field is_havoc boolean|nil       -- havoc mission
---@field havoc_rank number|nil      -- havoc rank (nil when not a havoc mission)
---@field circumstance_name string|nil  -- active circumstance id (nil when none)
local _mission = {}

local _selected_index = nil

local _end_summary = false
---@type MissionSummaryEntry|nil
local _end_entry = nil

local _viewed_mission_id = nil

local SELECTED_MISSION_KEY = "mission_summary_selected_mission"
local SELECTED_ENTRY_KEY = "mission_summary_selected_entry"

---@class MissionSummaryNewRun
---@field timestamp number|nil
---@field mission_id string|nil
local _new_run = mod:persistent_table("mission_summary_new_run", {})

---@class MissionSummaryManager
local Manager = {}

---@param entry MissionSummaryEntry|nil
function Manager.mark_new_run(entry)
	if not entry or not entry.timestamp then
		return
	end
	_new_run.timestamp = entry.timestamp
	_new_run.mission_id = entry.mission_id
end

function Manager.clear_new_run()
	_new_run.timestamp = nil
	_new_run.mission_id = nil
end

local function mod_menu()
	return mod.dl_hud.mod_menu
end

local function reset_view_state()
	_end_summary = false
	_end_entry = nil
	_selected_index = nil
	_viewed_mission_id = nil
end

function Manager.is_open()
	return mod_menu().is_open()
end

function Manager.close()
	mod_menu().close()
	_end_summary = false
	_end_entry = nil
end

---@param entry MissionSummaryEntry|nil
function Manager.show_end_summary(entry)
	entry = entry or History.most_recent()
	_end_summary = true
	_end_entry = entry
	_selected_index = nil
	Manager.remember_run(entry)
	local mm = mod_menu()
	mm.set_active_page("mission_summary")

	mm.open({ force_fancy = true })
end

---@param mission_id string|nil
---@return string|nil
local function resolve_mission_display(mission_id)
	if not mission_id then
		return nil
	end

	local ok, templates = pcall(require, "scripts/settings/mission/mission_templates")
	if ok and templates and templates[mission_id] and templates[mission_id].mission_name then
		local lok, text = pcall(function()
			return Managers.localization:localize(templates[mission_id].mission_name)
		end)
		if lok and text and text ~= "" then
			return text
		end
	end

	return mod.dl.str.machine_to_human_text(mission_id)
end

---@param challenge number|nil
---@return string
local function resolve_difficulty_name(challenge)
	return (challenge and DIFFICULTY_NAMES[challenge]) or ("Difficulty " .. tostring(challenge or "?"))
end

---@return { is_auric: boolean, is_maelstrom: boolean, is_havoc: boolean, havoc_rank: number|nil, circumstance_name: string|nil }
local function capture_live_modifiers()
	local state = Managers and Managers.state
	local difficulty = state and state.difficulty

	local havoc = difficulty and difficulty.get_parsed_havoc_data and difficulty:get_parsed_havoc_data() or nil
	local is_havoc = havoc ~= nil
	local havoc_rank = havoc and havoc.havoc_rank or nil

	local is_auric = false
	if not is_havoc and difficulty and difficulty.get_danger_settings then
		local ok, danger = pcall(difficulty.get_danger_settings, difficulty)
		is_auric = (ok and danger and danger.is_auric) or false
	end

	local circumstance = state and state.circumstance
	local circumstance_name = circumstance and circumstance.circumstance_name and circumstance:circumstance_name() or nil
	local is_maelstrom = circumstance_name ~= nil and string.find(circumstance_name, "flash_mission", 1, true) ~= nil

	return {
		is_auric = is_auric,
		is_maelstrom = is_maelstrom,
		is_havoc = is_havoc,
		havoc_rank = havoc_rank,
		circumstance_name = circumstance_name,
	}
end

---@param mission_id string|nil
---@param difficulty number|nil
---@param modifiers { is_auric: boolean, is_maelstrom: boolean, is_havoc: boolean, havoc_rank: number|nil, circumstance_name: string|nil }|nil
function Manager.set_mission(mission_id, difficulty, modifiers)
	_mission.id = mission_id
	_mission.difficulty = difficulty
	_mission.difficulty_name = resolve_difficulty_name(difficulty)
	_mission.display = resolve_mission_display(mission_id)
	_mission.outcome = nil
	modifiers = modifiers or {}
	_mission.is_auric = modifiers.is_auric or false
	_mission.is_maelstrom = modifiers.is_maelstrom or false
	_mission.is_havoc = modifiers.is_havoc or false
	_mission.havoc_rank = modifiers.havoc_rank
	_mission.circumstance_name = modifiers.circumstance_name
	_selected_index = nil
end

---@param outcome string|nil
function Manager.set_outcome(outcome)
	_mission.outcome = outcome
end

function Manager.capture_live_mission()
	local state = Managers and Managers.state
	local mission_id = state and state.mission and state.mission:mission_name() or nil
	if not mission_id then
		return
	end
	local challenge = state and state.difficulty and state.difficulty:get_challenge() or nil
	Manager.set_mission(mission_id, challenge, capture_live_modifiers())
end

---@return MissionSummaryMission
function Manager.mission()
	return _mission
end

---@return boolean
function Manager.is_real_mission()
	local mode = mod.dl.gameplay.game_mode_name()
	return mode ~= nil and REAL_MISSION_MODES[mode] == true
end

---@return table<string, number>
local function totals_by_mission()
	local all = History.all_entries()
	local totals = {}
	for i = 1, #all do
		local id = all[i].mission_id
		if id then
			totals[id] = (totals[id] or 0) + (all[i].sp or 0)
		end
	end
	return totals
end

---@return boolean
function Manager.is_browsing()
	return not _end_summary and not Manager.is_real_mission()
end

---@return string|nil
local function active_mission_id()
	if _end_summary and _end_entry then
		return _end_entry.mission_id
	end
	if Manager.is_real_mission() then
		return _mission.id
	end
	return _viewed_mission_id
end

---@return { id: string, display: string, level: MissionLevel }[]
function Manager.mission_list()
	local seen = {}
	local list = {}
	local totals = totals_by_mission()

	local ok, templates = pcall(require, "scripts/settings/mission/mission_templates")
	if ok and templates then
		for id, tmpl in pairs(templates) do
			if type(tmpl) == "table" and tmpl.game_mode_name == "coop_complete_objective" and not seen[id] then
				seen[id] = true
				list[#list + 1] = { id = id, display = resolve_mission_display(id) or id }
			end
		end
	end

	local all = History.all_entries()
	for i = 1, #all do
		local id = all[i].mission_id
		if id and not seen[id] then
			seen[id] = true
			list[#list + 1] = { id = id, display = (all[i].mission_display ~= "" and all[i].mission_display) or id }
		end
	end

	for i = 1, #list do
		list[i].level = Presentation.level_for_sp(totals[list[i].id] or 0)
	end

	table.sort(list, function(a, b)
		return a.display < b.display
	end)
	return list
end

local function persist_browse_selection()
	mod:set(SELECTED_MISSION_KEY, _viewed_mission_id)
	local leaderboard = Manager.leaderboard()
	local entry = _selected_index and leaderboard[_selected_index] or nil
	mod:set(SELECTED_ENTRY_KEY, entry and entry.timestamp or nil)
end

---@param index integer|nil
function Manager.select_entry(index)
	_selected_index = index

	if Manager.is_browsing() then
		persist_browse_selection()
	end
end

---@param mission_id string
function Manager.select_mission(mission_id)
	_viewed_mission_id = mission_id
	_selected_index = 1
	persist_browse_selection()
end

---@param entry MissionSummaryEntry|nil
function Manager.remember_run(entry)
	if not entry or not entry.mission_id then
		return
	end
	_viewed_mission_id = entry.mission_id
	mod:set(SELECTED_MISSION_KEY, entry.mission_id)
	mod:set(SELECTED_ENTRY_KEY, entry.timestamp)
end

function Manager.show_live()
	_selected_index = nil
end

---@return boolean deleted
function Manager.delete_selected_run()
	local leaderboard = Manager.leaderboard()
	local index = _selected_index
	local entry = index and leaderboard[index] or nil
	if not entry then
		return false
	end

	History.delete(entry)

	if _new_run.timestamp and _new_run.timestamp == entry.timestamp then
		Manager.clear_new_run()
	end

	if _end_entry and _end_entry.timestamp == entry.timestamp then
		_end_entry = nil
	end

	local remaining = Manager.leaderboard()
	if #remaining == 0 then
		_selected_index = nil
	else
		_selected_index = math.min(index, #remaining)
	end

	if Manager.is_browsing() then
		persist_browse_selection()
	end
	return true
end

---@return integer|nil
function Manager.selected_index()
	return _selected_index
end

---@return table values
local function live_values()
	local values = Stats.current()

	values.difficulty = _mission.difficulty
	values.is_auric = _mission.is_auric
	values.is_maelstrom = _mission.is_maelstrom
	values.is_havoc = _mission.is_havoc
	values.havoc_rank = _mission.havoc_rank
	return values
end

---@param entry MissionSummaryEntry
---@return table values
local function entry_values(entry)
	return {
		timestamp = entry.timestamp,

		difficulty = entry.difficulty,
		is_auric = entry.is_auric,
		is_maelstrom = entry.is_maelstrom,
		is_havoc = entry.is_havoc,
		havoc_rank = entry.havoc_rank,
		time = entry.time,
		kills = entry.kills,
		damage = entry.damage,
		boss_damage = entry.boss_damage,
		boss_max_health = entry.boss_max_health,
		style_points = entry.sp,
		plasteel = entry.plasteel,
		diamantine = entry.diamantine,
		idols_found = entry.idols_found,
		skulls_found = entry.skulls_found,
		best_combo = entry.best_combo,
		objectives = entry.objectives,
		rescues = entry.rescues,
		event_counts = entry.event_counts,

		elite_damage = entry.elite_damage,
		special_damage = entry.special_damage,
		regular_damage = entry.regular_damage,
		boss_kills = entry.boss_kills,
		elite_kills = entry.elite_kills,
		special_kills = entry.special_kills,
		regular_kills = entry.regular_kills,
		regular_spawned = entry.regular_spawned,
		elite_spawned = entry.elite_spawned,
		special_spawned = entry.special_spawned,
		boss_spawned = entry.boss_spawned,
		regular_health = entry.regular_health,
		elite_health = entry.elite_health,
		special_health = entry.special_health,

		coherency_time = entry.coherency_time,
		stims = entry.stims,
		rescues_global = entry.rescues_global,

		health_lost = entry.health_lost,
		downs = entry.downs,
	}
end

---@param entry MissionSummaryEntry
---@return string letter, argb_table color, number|nil score
local function entry_overall_rank(entry)
	local f = Presentation.factors(entry_values(entry))
	if f then
		return f.composite_letter, f.composite_color, Presentation.composite_score(f)
	end
	local letter, color = Presentation.rank_for_sp(entry.sp or 0, Presentation.difficulty_rank_key(entry))
	return letter, color, nil
end

---@param entry MissionSummaryEntry
---@return number
local function entry_composite_score(entry)
	return select(3, entry_overall_rank(entry)) or -math.huge
end

---@return MissionSummaryEntry[]
function Manager.leaderboard()
	local id = active_mission_id()
	if not id then
		return {}
	end
	local entries = History.entries_for(id)
	for i = 1, #entries do
		entries[i]._composite = entry_composite_score(entries[i])
	end
	table.sort(entries, function(a, b)
		if a._composite ~= b._composite then
			return a._composite > b._composite
		end
		return (a.sp or 0) > (b.sp or 0)
	end)
	return entries
end

---@param mission_list { id: string }[]|nil
---@param mission_id string|nil
---@return boolean
local function mission_in_list(mission_list, mission_id)
	if not mission_list or not mission_id then
		return false
	end
	for i = 1, #mission_list do
		if mission_list[i].id == mission_id then
			return true
		end
	end
	return false
end

---@param mission_list { id: string }[]|nil
local function restore_browse_mission(mission_list)
	if _viewed_mission_id then
		return
	end
	local persisted = mod:get(SELECTED_MISSION_KEY)
	if mission_in_list(mission_list, persisted) then
		_viewed_mission_id = persisted
	elseif mission_list and mission_list[1] then
		_viewed_mission_id = mission_list[1].id
	end
end

---@param leaderboard MissionSummaryEntry[]
---@return integer|nil
local function resolve_selected_index(leaderboard)
	local ts = mod:get(SELECTED_ENTRY_KEY)
	if ts then
		for i = 1, #leaderboard do
			if leaderboard[i].timestamp == ts then
				return i
			end
		end
	end
	return leaderboard[1] and 1 or nil
end

---@class HighscoreDisplayRow
---@field kind "entry"|"current"|"ellipsis"
---@field entry MissionSummaryEntry|nil
---@field lb_index integer|nil
---@field gold boolean
---@field badge string|nil
---@field badge_color argb_table|nil
---@field selectable boolean
---@field rank_letter string|nil     -- overall (composite) rank letter shown in the row
---@field rank_color argb_table|nil

---@class HighscoreCurrentRun
---@field entry MissionSummaryEntry
---@field sp number
---@field score number                -- composite score, for splicing at the right leaderboard rank
---@field timestamp number|nil
---@field lb_index integer|nil
---@field badge string
---@field badge_color argb_table
---@field rank_letter string|nil     -- overall (composite) rank letter, precomputed for the row
---@field rank_color argb_table|nil

---@param leaderboard MissionSummaryEntry[]
---@param current HighscoreCurrentRun|nil
---@param selected_index integer|nil  leaderboard index of the selected (gold) row, or nil
---@param allow_select boolean         false during a live run (no hover / no click)
---@return HighscoreDisplayRow[]
local function build_highscore_rows(leaderboard, current, selected_index, allow_select)
	local max_saved = C.MAX_HIGHSCORE_ROWS
	local rows = {}

	local current_ts = current and current.timestamp or nil
	local others = {}
	for i = 1, #leaderboard do
		if not current_ts or leaderboard[i].timestamp ~= current_ts then
			others[#others + 1] = { entry = leaderboard[i], lb_index = i }
		end
	end

	---@param o { entry: MissionSummaryEntry, lb_index: integer }
	---@return HighscoreDisplayRow
	local function entry_row(o)
		local rank_letter, rank_color = entry_overall_rank(o.entry)
		return {
			kind = "entry",
			entry = o.entry,
			lb_index = o.lb_index,
			gold = allow_select and selected_index == o.lb_index or false,
			selectable = allow_select,
			rank_letter = rank_letter,
			rank_color = rank_color,
		}
	end

	if not current then
		for i = 1, math.min(#others, max_saved) do
			rows[i] = entry_row(others[i])
		end
		return rows
	end

	local is_live = current.timestamp == nil
	---@type HighscoreDisplayRow
	local current_row = {
		kind = "current",
		entry = current.entry,
		lb_index = current.lb_index,
		gold = is_live or (allow_select and current.lb_index ~= nil and selected_index == current.lb_index) or false,
		badge = current.badge,
		badge_color = current.badge_color,
		selectable = (not is_live) and allow_select or false,
		rank_letter = current.rank_letter,
		rank_color = current.rank_color,
	}

	local current_score = current.score or -math.huge
	local rank = 1
	for i = 1, #others do
		local other = others[i].entry
		local other_score = other._composite or entry_composite_score(other)
		local ahead = other_score > current_score
			or (other_score == current_score and (other.sp or 0) > current.sp)
		if ahead then
			rank = rank + 1
		else
			break
		end
	end

	if rank <= max_saved then

		local oi = 1
		for slot = 1, max_saved + 1 do
			if slot == rank then
				rows[slot] = current_row
			elseif oi <= #others then
				rows[slot] = entry_row(others[oi])
				oi = oi + 1
			else
				break
			end
		end
	else

		for i = 1, max_saved do
			if others[i] then
				rows[i] = entry_row(others[i])
			end
		end
		rows[max_saved + 1] = { kind = "ellipsis", gold = false, selectable = false }
		rows[max_saved + 2] = current_row
	end

	return rows
end

---@param values table  live stat values (Stats.current())
---@return HighscoreCurrentRun
local function live_current_run(values)
	local local_player = mod.dl.player.local_player()
	---@type MissionSummaryEntry
	local entry = {
		mission_id = _mission.id or "",
		mission_display = _mission.display or "",
		difficulty = _mission.difficulty or 0,
		difficulty_name = _mission.difficulty_name or "",

		is_auric = _mission.is_auric and 1 or 0,
		is_maelstrom = _mission.is_maelstrom and 1 or 0,
		is_havoc = _mission.is_havoc and 1 or 0,
		havoc_rank = _mission.havoc_rank or 0,
		sp = math.floor(values.style_points or 0),
		archetype = mod.dl.player.archetype_name(local_player) or "",

	}

	local rank_letter, rank_color
	local score = -math.huge
	local f = Presentation.factors(values)
	if f then
		rank_letter, rank_color = f.composite_letter, f.composite_color
		score = Presentation.composite_score(f)
	end
	return {
		entry = entry,
		sp = entry.sp,
		score = score,
		timestamp = nil,
		badge = mod:localize("mission_summary_current_run"),
		badge_color = C.COLOR.CURRENT_RUN,
		rank_letter = rank_letter,
		rank_color = rank_color,
	}
end

---@param leaderboard MissionSummaryEntry[]
---@return HighscoreCurrentRun|nil
local function new_run_current(leaderboard)
	if not _new_run.timestamp then
		return nil
	end
	for i = 1, #leaderboard do
		local entry = leaderboard[i]
		if entry.timestamp == _new_run.timestamp then
			local rank_letter, rank_color = entry_overall_rank(entry)
			return {
				entry = entry,
				sp = entry.sp or 0,
				score = entry._composite or entry_composite_score(entry),
				timestamp = entry.timestamp,
				lb_index = i,
				badge = mod:localize("mission_summary_new_run"),
				badge_color = C.COLOR.NEW_RUN,
				rank_letter = rank_letter,
				rank_color = rank_color,
			}
		end
	end
	return nil
end

---@class MissionSummarySnapshot
---@field mode "live"|"entry"|"empty"  -- what the run/big blocks show
---@field browse boolean               -- the grid is the mission selector
---@field mission_list { id: string, display: string, level: MissionLevel }[]
---@field selected_mission_id string|nil
---@field level_name string|nil         -- mission name shown in the header
---@field level MissionLevel|nil        -- per-mission level (cumulative SP) for the header
---@field intro number|nil              -- end-summary count-up key (the run's timestamp); nil = no intro
---@field level_start_sp number|nil     -- pre-run cumulative SP (header bar sweep start)
---@field level_end_sp number|nil       -- post-run cumulative SP (header bar sweep end)
---@field difficulty_name string|nil
---@field is_auric boolean               -- the shown run was an auric mission
---@field is_maelstrom boolean           -- the shown run was a maelstrom (flash) mission
---@field is_havoc boolean               -- the shown run was a havoc mission
---@field havoc_rank number|nil          -- havoc rank of the shown run (nil when not havoc)
---@field values table|nil
---@field factors MissionFactors|nil    -- VIOLENCE/UNITY/FINESSE/STYLE ranks (big rows)
---@field rank_letter string|nil        -- the shown run's composite rank (the big glyph box)
---@field rank_color argb_table|nil
---@field leaderboard MissionSummaryEntry[]
---@field selected_index integer|nil
---@field rows HighscoreDisplayRow[]      -- the drawable high-score rows (with the current run)
---@field in_live_run boolean             -- a live mission is in progress (rows aren't clickable)
---@field can_show_live boolean
---@field can_delete_run boolean          -- a saved run is selected, so the DELETE RUN button shows
---@return MissionSummarySnapshot
function Manager.snapshot()
	local browse = Manager.is_browsing()

	local in_live_run = Manager.is_real_mission() and not _end_summary
	if in_live_run then
		_selected_index = nil
	end

	local mission_list = browse and Manager.mission_list() or nil
	if browse then
		restore_browse_mission(mission_list)
	end

	local leaderboard = Manager.leaderboard()
	if browse then
		_selected_index = resolve_selected_index(leaderboard)
	elseif _end_summary and _selected_index == nil then

		_selected_index = resolve_selected_index(leaderboard)
	end
	local selected = _selected_index and leaderboard[_selected_index] or nil

	---@type MissionSummarySnapshot
	local snapshot = {
		mode = "empty",
		browse = browse,
		mission_list = mission_list or {},
		selected_mission_id = active_mission_id(),
		leaderboard = leaderboard,
		selected_index = selected and _selected_index or nil,
		is_auric = false,
		is_maelstrom = false,
		is_havoc = false,
		havoc_rank = nil,

		can_show_live = Manager.is_real_mission() and not _end_summary and selected ~= nil,

		can_delete_run = selected ~= nil,
	}

	---@param entry MissionSummaryEntry
	local function apply_entry_modifiers(entry)
		snapshot.is_auric = (entry.is_auric or 0) ~= 0
		snapshot.is_maelstrom = (entry.is_maelstrom or 0) ~= 0
		snapshot.is_havoc = (entry.is_havoc or 0) ~= 0
		snapshot.havoc_rank = snapshot.is_havoc and (entry.havoc_rank or 0) > 0 and entry.havoc_rank or nil
	end

	if selected then

		snapshot.mode = "entry"
		snapshot.level_name = selected.mission_display
		snapshot.difficulty_name = selected.difficulty_name
		apply_entry_modifiers(selected)
		snapshot.values = entry_values(selected)
	elseif _end_summary and _end_entry then
		snapshot.mode = "entry"
		snapshot.level_name = _end_entry.mission_display
		snapshot.difficulty_name = _end_entry.difficulty_name
		apply_entry_modifiers(_end_entry)
		snapshot.values = entry_values(_end_entry)
	elseif Manager.is_real_mission() then

		if not _mission.id then
			Manager.capture_live_mission()
		end
		snapshot.mode = "live"
		snapshot.level_name = _mission.display
		snapshot.difficulty_name = _mission.difficulty_name
		snapshot.is_auric = _mission.is_auric or false
		snapshot.is_maelstrom = _mission.is_maelstrom or false
		snapshot.is_havoc = _mission.is_havoc or false
		snapshot.havoc_rank = _mission.havoc_rank
		snapshot.values = live_values()
	end

	if snapshot.values then
		snapshot.factors = Presentation.factors(snapshot.values)
		if snapshot.factors then
			snapshot.rank_letter = snapshot.factors.composite_letter
			snapshot.rank_color = snapshot.factors.composite_color
		end
	end

	if browse and snapshot.mode == "empty" and mission_list then
		local vid = active_mission_id()
		for i = 1, #mission_list do
			if mission_list[i].id == vid then
				snapshot.level_name = mission_list[i].display
				break
			end
		end
	end

	local active_id = active_mission_id()
	if active_id then
		local total = totals_by_mission()[active_id] or 0
		snapshot.level = Presentation.level_for_sp(total)

		if _end_summary and _end_entry then
			local run_sp = _end_entry.sp or 0
			snapshot.intro = _end_entry.timestamp or 0
			snapshot.level_start_sp = math.max(0, total - run_sp)
			snapshot.level_end_sp = total
		end
	end

	local current
	if in_live_run then
		current = snapshot.values and live_current_run(snapshot.values) or nil
	else
		current = new_run_current(leaderboard)
	end
	snapshot.in_live_run = in_live_run
	snapshot.rows = build_highscore_rows(leaderboard, current, snapshot.selected_index, not in_live_run)

	return snapshot
end

mod.__toggle_mod_menu = function(_, is_pressed)
	if is_pressed == false then
		return
	end

	local mm = mod.dl_hud.mod_menu
	if mm.is_open() then
		Manager.close()
		return
	end
	local ui = Managers and Managers.ui
	if ui and ui.chat_using_input and ui:chat_using_input() then
		return
	end
	reset_view_state()
	mm.open()
end

mod.mission_summary_manager = Manager

return mod.mission_summary_manager
