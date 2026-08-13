---@class mod : DL_Mod
---@field constants Constants
---@field movement_handler MovementHandler
---@field unit_hit_tracker UnitHitTracker
---@field kill_handler KillHandler
---@field combo_state ComboState
---@field breed_fatigue_relief BreedFatigueRelief
---@field fury_meter_presentation FuryMeterPresentation
---@field fury_meter_constants FuryMeterConstants
---@field style_meter_presentation StyleMeterPresentation
---@field style_meter_constants StyleMeterConstants
---@field task_presentation TaskPresentation
---@field task_constants TaskConstants
---@field stat_chart_presentation StatChartPresentation
---@field stat_chart_constants StatChartConstants
---@field stats_manager StatsManager
---@field task_registry TaskRegistry
---@field task_manager TaskManager
---@field event_registry EventRegistry
---@field event_manager EventManager
---@field event_resolver EventResolver
---@field event_scoring EventScoring
---@field runtime Runtime
---@field rumble Rumble
---@field scoring_constants ScoringConstants
---@field thresholds Thresholds
---@field shuffle_bag ShuffleBag
---@field time_window TimeWindow
---@field runtime_state RuntimeState
---@field layout Layout
---@field task_enums TaskEnums
---@field horde_signal HordeSignal
---@field event_enums EventEnums
---@field hit_trackers HitTrackers
---@field settings_schema DLH_SettingsMenuSchema
---@field mission_summary_constants MissionSummaryConstants
---@field mission_summary_presentation MissionSummaryPresentation
---@field mission_summary_stats MissionSummaryStats
---@field mission_summary_history MissionSummaryHistory
---@field mission_summary_manager MissionSummaryManager
---@field mission_summary_global_stats GlobalStats
---@field mission_summary_hooks table
---@field lib memo_fn
---@field core memo_fn
local mod = get_mod("dopamine")

mod.bootstrap.script_phase()

mod.dl_hud.settings_menu.build_menu(mod.settings_schema, {
	title = "settings_module",
})

mod.__dl_toggle_settings_menu = function(_, is_pressed)
	if is_pressed == false then
		return
	end
	local mm = mod.dl_hud.mod_menu
	if not mm.is_open() then
		local ui = Managers and Managers.ui
		if ui and ui.chat_using_input and ui:chat_using_input() then
			return
		end
	end
	mm.set_active_page("settings")
	mm.open()
end

mod:command(
	"dopamine_clear_missions_this_is_irreversible",
	"IRREVERSIBLE!! Deletes all saved dopamine mission summary data",
	function()
		local History = mod:core(mod.mission_summary_history, "utils/mission_summary/history_store")
		local removed = History.clear_all()
		mod:echo("Cleared " .. tostring(removed) .. " mission summary record(s).")
	end
)

mod.__debug__add_10_debug_fury = function(pressed)
	if not pressed then
		return
	end

	mod:set("debug_lock_fury_fatigue", true)

	mod:set("debug_fury_pct", math.max((mod:get("debug_fury_pct") or 10) + 10, 0))
	mod.dl.settings.invalidate_settings()
end

mod.__debug__take_10_debug_fury = function(pressed)
	if not pressed then
		return
	end
	mod:set("debug_lock_fury_fatigue", true)

	mod:set("debug_fury_pct", math.max((mod:get("debug_fury_pct") or 10) - 10, 0))
	mod.dl.settings.invalidate_settings()
end

mod.__debug__toggle_fury_lock = function(pressed)
	if not pressed then
		return
	end

	mod:set("debug_lock_fury_fatigue", false)
	mod.dl.settings.invalidate_settings()
end
