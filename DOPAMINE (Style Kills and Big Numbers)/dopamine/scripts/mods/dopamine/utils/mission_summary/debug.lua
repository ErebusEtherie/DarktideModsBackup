

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_debug then
	return mod.mission_summary_debug
end

local History = mod:core(mod.mission_summary_history, "utils/mission_summary/history_store")
local Manager = mod:core(mod.mission_summary_manager, "utils/mission_summary/manager")
local Presentation = mod:core(mod.mission_summary_presentation, "hud/mission_summary/presentation")
local C = mod:core(mod.mission_summary_constants, "hud/mission_summary/constants")

local math_random = math.random
local math_floor = math.floor

local function millions(n)
	return n * 1000000
end

local DUMMY_MISSION_ID = "op_train"
local DUMMY_MISSION_DISPLAY = "Rolling Steel"

local DIFFICULTY_NAMES = { "Sedition", "Uprising", "Malice", "Heresy", "Damnation" }

local ARCHETYPES = { "veteran", "zealot", "psyker", "ogryn" }

local EVENT_LISTS = { C.VICTIMS_EVENTS, C.METHOD_EVENTS, C.STYLE_EVENTS, C.TEAM_EVENTS }

---@class MissionSummaryDebug
local Debug = {}

---@return table<string, integer>
local function random_event_counts()
	local counts = {}
	for l = 1, #EVENT_LISTS do
		local list = EVENT_LISTS[l]
		for r = 1, #list do
			local row = list[r]
			if row.combine then
				for j = 1, #row.combine do
					counts[row.combine[j]] = math_random(0, 120)
				end
			elseif row.combine_stat_time then
				counts[row.combine_stat_time.time_event] = math_random(30, 300)
			elseif not row.stat and not row.is_coherency_pct then
				counts[row.id] = row.is_time and math_random(30, 300) or math_random(0, 120)
			end
		end
	end
	return counts
end

---@return MissionSummaryEntry
local function build_random_entry()
	local thresholds = C.RANK_THRESHOLDS
	local i = math_random(1, #thresholds)
	local lo = thresholds[i].min
	local hi = (i > 1) and thresholds[i - 1].min or (lo + millions(2))
	local sp = math_floor(lo + math_random() * (hi - lo))

	local boss_max_health = math_random(300, 1200) * 1000
	local boss_damage = math_floor(math_random() * boss_max_health)
	local won = math_random(0, 1)
	local difficulty = math_random(1, #DIFFICULTY_NAMES)
	local time = math_random(600, 2400)

	local regular_spawned = math_random(200, 800)
	local elite_spawned = math_random(10, 70)
	local special_spawned = math_random(5, 35)
	local regular_health = regular_spawned * math_random(80, 140)
	local elite_health = elite_spawned * math_random(400, 700)
	local special_health = special_spawned * math_random(200, 500)
	local regular_damage = math_floor(regular_health * math_random(50, 100) / 100)
	local elite_damage = math_floor(elite_health * math_random(30, 100) / 100)
	local special_damage = math_floor(special_health * math_random(20, 100) / 100)
	local rescues = math_random(0, 8)

	---@type MissionSummaryEntry
	return {
		mission_id = DUMMY_MISSION_ID,
		mission_display = DUMMY_MISSION_DISPLAY,
		difficulty = difficulty,
		difficulty_name = DIFFICULTY_NAMES[difficulty],
		outcome = won == 1 and "won" or "lost",
		won = won,
		sp = sp,
		rank = Presentation.rank_for_sp(sp),
		kills = math_random(150, 1500),
		damage = math_random(300, 6000) * 1000,
		boss_damage = boss_damage,
		boss_max_health = boss_max_health,
		headshots = math_random(20, 600),
		time = time,
		plasteel = math_random(0, 400),
		diamantine = math_random(0, 120),
		idols_found = math_random(0, 3),
		skulls_found = math_random(0, 1),
		best_combo = math_random(15, 400),
		objectives = math_random(0, 6),
		rescues = rescues,
		event_counts = random_event_counts(),

		regular_spawned = regular_spawned,
		elite_spawned = elite_spawned,
		special_spawned = special_spawned,
		boss_spawned = math_random(0, 3),
		regular_health = regular_health,
		elite_health = elite_health,
		special_health = special_health,
		regular_damage = regular_damage,
		elite_damage = elite_damage,
		special_damage = special_damage,
		regular_kills = math_floor(regular_spawned * math_random(50, 100) / 100),
		elite_kills = math_floor(elite_spawned * math_random(30, 100) / 100),
		special_kills = math_floor(special_spawned * math_random(20, 100) / 100),
		boss_kills = math_random(0, 3),

		coherency_time = math_floor(time * math_random(40, 95) / 100),
		stims = math_random(0, 6),
		rescues_global = rescues + math_random(0, 6),

		health_lost = math_random(50, 1200) / 100,
		downs = math_random(0, 4),

		archetype = ARCHETYPES[math_random(1, #ARCHETYPES)],
		player_name = "Debug Dummy",
	}
end

---@return MissionSummaryEntry
function Debug.create_dummy_entry()
	local entry = build_random_entry()
	History.save(entry)
	return entry
end

function Debug.simulate_end_mission()
	local entry = build_random_entry()
	History.save(entry)
	Manager.mark_new_run(entry)
	Manager.show_end_summary(entry)
end

mod.__debug__simulate_end_mission = function(_, is_pressed)
	if is_pressed == false then
		return
	end
	Debug.simulate_end_mission()
end

mod.__debug__create_dummy_entry = function(_, is_pressed)
	if is_pressed == false then
		return
	end
	local entry = Debug.create_dummy_entry()
	mod:echo("Saved dummy Rolling Steel run: " .. entry.rank .. " rank, " .. tostring(entry.sp) .. " SP.")
end

mod.mission_summary_debug = Debug

return Debug
