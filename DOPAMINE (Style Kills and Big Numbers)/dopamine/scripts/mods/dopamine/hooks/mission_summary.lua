

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_hooks then
	return mod.mission_summary_hooks
end

local Manager = mod:core(mod.mission_summary_manager, "utils/mission_summary/manager")
local Stats = mod:core(mod.mission_summary_stats, "utils/mission_summary/stats")
local History = mod:core(mod.mission_summary_history, "utils/mission_summary/history_store")
local Presentation = mod:core(mod.mission_summary_presentation, "hud/mission_summary/presentation")
local GlobalStats = mod:core(mod.mission_summary_global_stats, "utils/mission_summary/global_stats")

mod.dl_hud.mod_menu.add_page({
	id = "mission_summary",
	label = mod:localize("mission_summary_module"),
	element_path = "dopamine/scripts/mods/dopamine/hud/mission_summary/element",
	element_context = { mod_name = "dopamine" },
})

do
	local aside_items = GlobalStats.aside_items()
	for i = 1, #aside_items do
		mod.dl_hud.mod_menu.add_aside_item(aside_items[i])
	end
end

local _saved = false

---@type MissionSummaryEntry|nil
local _final_entry = nil

mod.dl.gameplay.on_enter_gameplay(function(from_reload)
	if from_reload then
		return
	end
	_saved = false
	_final_entry = nil

	Manager.clear_new_run()
	Manager.capture_live_mission()
end)

---@param outcome string|nil
---@return MissionSummaryEntry
local function build_entry(outcome)
	local stats = Stats.current()
	local mission = Manager.mission()
	local local_player = mod.dl.player.local_player()
	local rank = Presentation.rank_for_sp(stats.style_points)
	local won = outcome == "won"

	return {
		mission_id = mission.id or "unknown",
		mission_display = mission.display or "",
		difficulty = mission.difficulty or 0,
		difficulty_name = mission.difficulty_name or "",
		outcome = outcome or "",
		won = won and 1 or 0,
		sp = math.floor(stats.style_points or 0),
		rank = rank,
		kills = math.floor(stats.kills or 0),
		damage = math.floor(stats.damage or 0),
		boss_damage = math.floor(stats.boss_damage or 0),
		boss_max_health = math.floor(stats.boss_max_health or 0),
		headshots = math.floor(stats.headshots or 0),
		time = math.floor(stats.time or 0),
		plasteel = stats.plasteel or 0,
		diamantine = stats.diamantine or 0,
		idols_found = stats.idols_found or 0,
		skulls_found = stats.skulls_found or 0,
		best_combo = math.floor(stats.best_combo or 0),
		objectives = math.floor(stats.objectives or 0),
		rescues = math.floor(stats.rescues or 0),

		elite_damage = math.floor(stats.elite_damage or 0),
		special_damage = math.floor(stats.special_damage or 0),
		regular_damage = math.floor(stats.regular_damage or 0),
		boss_kills = math.floor(stats.boss_kills or 0),
		elite_kills = math.floor(stats.elite_kills or 0),
		special_kills = math.floor(stats.special_kills or 0),
		regular_kills = math.floor(stats.regular_kills or 0),
		regular_spawned = math.floor(stats.regular_spawned or 0),
		elite_spawned = math.floor(stats.elite_spawned or 0),
		special_spawned = math.floor(stats.special_spawned or 0),
		boss_spawned = math.floor(stats.boss_spawned or 0),
		regular_health = math.floor(stats.regular_health or 0),
		elite_health = math.floor(stats.elite_health or 0),
		special_health = math.floor(stats.special_health or 0),

		coherency_time = math.floor(stats.coherency_time or 0),
		stims = math.floor(stats.stims or 0),
		rescues_global = math.floor(stats.rescues_global or 0),

		health_lost = math.floor((stats.health_lost or 0) * 100 + 0.5) / 100,
		downs = math.floor(stats.downs or 0),

		is_auric = mission.is_auric and 1 or 0,
		is_maelstrom = mission.is_maelstrom and 1 or 0,
		is_havoc = mission.is_havoc and 1 or 0,
		havoc_rank = math.floor(mission.havoc_rank or 0),
		circumstance_name = mission.circumstance_name or "",
		event_counts = Presentation.event_counts_for_save(stats.event_counts),
		archetype = mod.dl.player.archetype_name(local_player) or "",
		player_name = mod.dl.player.name(local_player) or "",
	}
end

mod.dl.game_hooks.hook_safe(CLASS.GameModeManager, "_set_end_conditions_met", function(self, outcome)

	Manager.capture_live_mission()
	Manager.set_outcome(outcome)
	if Manager.mission().id then
		_final_entry = build_entry(outcome)

		if not _saved and _final_entry and Manager.is_real_mission() then
			History.save(_final_entry)
			Manager.mark_new_run(_final_entry)
			_saved = true
		end
	end
end)

mod.dl.game_hooks.hook_safe(CLASS.EndView, "on_enter", function(self)
	if not _saved and _final_entry then
		History.save(_final_entry)
		Manager.mark_new_run(_final_entry)
		_saved = true
	end
	if mod.dl.settings.enable_mission_summary ~= false then
		Manager.show_end_summary(_final_entry)
	end
end)

local MissionSummaryHooks = {}

mod.mission_summary_hooks = MissionSummaryHooks

return MissionSummaryHooks
