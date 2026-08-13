

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_global_stats then
	return mod.mission_summary_global_stats
end

local History = mod:core(mod.mission_summary_history, "utils/mission_summary/history_store")
local Presentation = mod:core(mod.mission_summary_presentation, "hud/mission_summary/presentation")

---@class GlobalStats
local GlobalStats = {}

local CLASS_ORDER = { "veteran", "zealot", "psyker", "ogryn", "adamant", "cryptic", "broker" }

local CLASS_SHORT = {
	veteran = "VET",
	zealot = "ZLT",
	psyker = "PSK",
	ogryn = "OGR",
	adamant = "ARB",
	cryptic = "SKT",
	broker = "HIV",
}

---@param seconds number|nil
---@return string
local function format_duration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

---@class GlobalStatsSummary
---@field missions integer
---@field wins integer
---@field total_sp number
---@field kills number
---@field damage number
---@field boss_damage number
---@field headshots number
---@field plasteel number
---@field diamantine number
---@field time number
---@field best MissionSummaryEntry|nil  the single highest-SP run
---@field sp_by_class table<string, number>
---@field runs_by_class table<string, integer>  run count per class (for the average rank)
---@field event_counts table<string, integer>  lifetime fire count per style event, summed across runs

---@type { count: integer, summary: GlobalStatsSummary }|nil
local _cache = nil

---@return GlobalStatsSummary
function GlobalStats.summary()
	local entries = History.all_entries()
	if _cache and _cache.count == #entries then
		return _cache.summary
	end

	---@type GlobalStatsSummary
	local summary = {
		missions = #entries,
		wins = 0,
		total_sp = 0,
		kills = 0,
		damage = 0,
		boss_damage = 0,
		headshots = 0,
		plasteel = 0,
		diamantine = 0,
		time = 0,
		best = nil,
		sp_by_class = {},
		runs_by_class = {},
		event_counts = {},
	}

	for i = 1, #entries do
		local entry = entries[i]

		local counts = entry.event_counts
		if counts then
			for event_id, count in pairs(counts) do
				summary.event_counts[event_id] = (summary.event_counts[event_id] or 0) + (count or 0)
			end
		end
		summary.wins = summary.wins + (entry.won or 0)
		summary.total_sp = summary.total_sp + (entry.sp or 0)
		summary.kills = summary.kills + (entry.kills or 0)
		summary.damage = summary.damage + (entry.damage or 0)
		summary.boss_damage = summary.boss_damage + (entry.boss_damage or 0)
		summary.headshots = summary.headshots + (entry.headshots or 0)
		summary.plasteel = summary.plasteel + (entry.plasteel or 0)
		summary.diamantine = summary.diamantine + (entry.diamantine or 0)
		summary.time = summary.time + (entry.time or 0)

		if not summary.best or (entry.sp or 0) > (summary.best.sp or 0) then
			summary.best = entry
		end

		local archetype = entry.archetype
		if archetype and archetype ~= "" then

			local id = mod.dl.archetypes.resolve(archetype) or archetype
			summary.sp_by_class[id] = (summary.sp_by_class[id] or 0) + (entry.sp or 0)
			summary.runs_by_class[id] = (summary.runs_by_class[id] or 0) + 1
		end
	end

	_cache = { count = #entries, summary = summary }
	return summary
end

local COLOR = mod.constants.COLOR

local WIN_COLOR = COLOR.NUMBERS.GREEN
local LOSS_COLOR = COLOR.UI_RED

local ICON_FONT = mod.dl.fonts.validated("mono_tide_medium", "proxima_nova_medium")

---@param value number
---@return string
local function number(value)
	return mod.dl.str.format_number(value)
end

---@param archetype string
---@return string
local function class_icon(archetype)
	return mod.dl.str.rich_text(Presentation.class_icon(archetype), { font = ICON_FONT })
end

---@return string
local function missions_value()
	local summary = GlobalStats.summary()
	local wins = summary.wins
	local losses = summary.missions - wins
	return tostring(summary.missions)
		.. "  ("
		.. mod.dl.str.rich_text(tostring(wins), { color = WIN_COLOR })
		.. "/"
		.. mod.dl.str.rich_text(tostring(losses), { color = LOSS_COLOR })
		.. ")"
end

---@param archetype string
---@return string
local function class_value(archetype)
	local summary = GlobalStats.summary()
	local total = summary.sp_by_class[archetype] or 0
	local runs = summary.runs_by_class[archetype] or 0
	if runs == 0 then
		return "-"
	end
	local letter, color = Presentation.rank_for_sp(total / runs)
	return mod.dl.str.rich_text(letter, { color = color }) .. " " .. number(total)
end

local EVENT_ASIDE_IDS = {
	"boss_kill",

	"generic_headshot",
	"multi_kill",
	"dodge",
}

---@param event_ids string[]
---@return DLH_ModMenuAsideItem[]
function GlobalStats.event_aside_items(event_ids)
	---@type DLH_ModMenuAsideItem[]
	local items = {
		{ id = "gs_events_gap", spacer = true },
		{ id = "gs_events_header", heading = true, label = mod:localize("mission_summary_events_heading") },
	}

	for i = 1, #event_ids do
		local event_id = event_ids[i]
		items[#items + 1] = {
			id = "gs_event_" .. event_id,
			label = Presentation.event_label(event_id),
			value = function()
				return number(GlobalStats.summary().event_counts[event_id] or 0)
			end,
		}
	end

	return items
end

---@return DLH_ModMenuAsideItem[]
function GlobalStats.aside_items()
	---@type DLH_ModMenuAsideItem[]
	local items = {

		{
			id = "gs_career_header",
			heading = true,
			label = mod:localize("career"),
		},
		{
			id = "gs_total_sp",
			label = "SP",
			value = function()
				return number(GlobalStats.summary().total_sp)
			end,
		},
		{
			id = "gs_missions",
			label = mod:localize("global_stats_missions"),
			value = missions_value,
		},
		{
			id = "gs_time_played",
			label = mod:localize("global_stats_time_played"),
			value = function()
				return format_duration(GlobalStats.summary().time)
			end,
		},

		{ id = "gs_class_gap", spacer = true },
		{
			id = "gs_class_header",
			heading = true,
			label = mod:localize("global_stats_class_col"),
			label_right = mod:localize("global_stats_class_header"),
		},
	}

	for i = 1, #CLASS_ORDER do
		local archetype = CLASS_ORDER[i]
		items[#items + 1] = {
			id = "gs_class_" .. archetype,
			label = class_icon(archetype) .. " " .. (CLASS_SHORT[archetype] or ""),
			value = function()
				return class_value(archetype)
			end,
		}
	end

	local event_items = GlobalStats.event_aside_items(EVENT_ASIDE_IDS)
	for i = 1, #event_items do
		items[#items + 1] = event_items[i]
	end

	local totals_items = {
		{ id = "gs_totals_gap", spacer = true },
		{
			id = "gs_total_header",
			heading = true,
			label = mod:localize("total"),
		},

		{
			id = "gs_kills",
			label = mod:localize("kills"),
			value = function()
				return number(GlobalStats.summary().kills)
			end,
		},
		{
			id = "gs_damage",
			label = mod:localize("damage"),
			value = function()
				return number(GlobalStats.summary().damage)
			end,
		},
		{
			id = "gs_boss_damage",
			label = mod:localize("global_stats_boss_damage"),
			value = function()
				return number(GlobalStats.summary().boss_damage)
			end,
		},
		{
			id = "gs_headshots",
			label = mod:localize("global_stats_headshots"),
			value = function()
				return number(GlobalStats.summary().headshots)
			end,
		},
	}

	for i = 1, #totals_items do
		items[#items + 1] = totals_items[i]
	end

	local misc_items = {
		{ id = "gs_misc_gap", spacer = true },
		{
			id = "gs_misc_header",
			heading = true,
			label = mod:localize("misc"),
		},
		{
			id = "gs_plasteel",
			label = mod:localize("global_stats_plasteel"),
			value = function()
				return number(GlobalStats.summary().plasteel)
			end,
		},
		{
			id = "gs_diamantine",
			label = mod:localize("global_stats_diamantine"),
			value = function()
				return number(GlobalStats.summary().diamantine)
			end,
		},
	}

	for i = 1, #misc_items do
		items[#items + 1] = misc_items[i]
	end

	return items
end

mod.mission_summary_global_stats = GlobalStats

return mod.mission_summary_global_stats
