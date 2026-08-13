---@type mod
local mod = get_mod("dopamine")

if mod.objective_time then
	return mod.objective_time
end

local ScriptUnit = ScriptUnit

local ComboState = mod:core(mod.combo_state, "utils/combo_state")
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")
local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local ScoringConstants = mod:core(mod.scoring_constants, "utils/scoring/constants")
local ObjectiveMarkers = mod:core(mod.objective_markers, "hooks/objective_markers")

local InteractionSettings = require("scripts/settings/interaction/interaction_settings")

local INTERACTION_SUCCESS = InteractionSettings.results.success

local DEFERRED_COMPLETION = {
	decoding = true,
}

local LUGGABLE_SLOT = "slot_luggable"

local TICK_INTERVAL = 1

local FREEZE_REASON = "objective_carry"

local EMPTY_CONTEXT = {}

local tick_timer = 0
local was_carrying = false

local _objectives = 0

---@return DL_PlayerObject|nil
local function local_player()
	return mod.dl.player.local_player()
end

---@return any|nil
local function local_session_id()
	local player = local_player()
	return player and player:session_id() or nil
end

---@return boolean
local function is_carrying_luggable()
	local unit = mod.dl.player.local_player_unit()
	if not unit then
		return false
	end

	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data then
		return false
	end

	local inventory = unit_data:read_component("inventory")

	return inventory ~= nil and inventory.wielded_slot == LUGGABLE_SLOT
end

local function award_objective_mult()
	local config = ScoringConstants.OBJECTIVE_COMPLETE_MULT

	EventManager.add_timed_mult(config.add, config.duration)
end

---@param unit Unit
local function award_for_unit(unit)
	local reward = ObjectiveMarkers.reward_for_unit(unit)

	if reward and reward.kind == "sp" then
		EventManager.add_reward(reward.sp)
		return
	end

	award_objective_mult()
end

mod.dl.game_hooks.hook("InteracteeExtension", "stopped", function(next_fn, self, result, interactor_unit)
	local interaction_type = self:interaction_type()

	next_fn(self, result, interactor_unit)

	if result ~= INTERACTION_SUCCESS then
		return
	end

	if DEFERRED_COMPLETION[interaction_type] then
		return
	end

	local reward = ObjectiveMarkers.reward_for_interaction_type(interaction_type)

	if not reward then
		return
	end

	if interactor_unit == mod.dl.player.local_player_unit() then
		_objectives = _objectives + 1
	end

	if reward.kind == "sp" then
		EventManager.add_reward(reward.sp)
	else
		award_objective_mult()
	end
end)

mod.dl.game_hooks.hook_safe("ActionScanConfirm", "_bank_scannable_unit", function(self)

	local reward = ScoringConstants.OBJECTIVE_INTERACTION_REWARD.scanning

	if reward and reward.kind == "sp" then
		EventManager.add_reward(reward.sp)
	end

	if self._player == local_player() then
		_objectives = _objectives + 1
	end
end)

local paid_destructibles = setmetatable({}, { __mode = "k" })

mod.dl.on_hit.execute("human players", function(event)
	if event.attack_result ~= "died" then
		return
	end

	local unit = event.attacked_unit

	if not unit or paid_destructibles[unit] then
		return
	end

	if not ObjectiveMarkers.is_objective_destructible(unit) then
		return
	end

	paid_destructibles[unit] = true

	award_for_unit(unit)

	if event.attacking_player == local_player() then
		_objectives = _objectives + 1
	end
end)

local MinigameClasses = require("scripts/settings/minigame/minigame_classes")

local PUZZLE_MINIGAMES = {
	"balance",
	"decode_search",
	"decode_symbols",
	"drill",
	"expedition_map",
	"frequency",
}

for i = 1, #PUZZLE_MINIGAMES do
	local class_table = MinigameClasses[PUZZLE_MINIGAMES[i]]

	if class_table then

		mod.dl.game_hooks.hook_safe(class_table, "complete", function(self)
			award_objective_mult()

			local session_id = self:player_session_id()
			if session_id and session_id == local_session_id() then
				_objectives = _objectives + 1
			end
		end)
	end
end

---@class ObjectiveTime
local ObjectiveTime = {}

---@param dt number
function ObjectiveTime.tick(dt)
	local carrying = is_carrying_luggable()

	if carrying ~= was_carrying then
		was_carrying = carrying
		ComboState.set_frozen(FREEZE_REASON, carrying)

		tick_timer = 0
	end

	if not carrying then
		return
	end

	tick_timer = tick_timer - dt

	if tick_timer > 0 then
		return
	end

	tick_timer = TICK_INTERVAL

	EventManager.trigger(EventEnums.EVENT_ID.objective_time, EMPTY_CONTEXT)
end

---@return integer
function ObjectiveTime.objectives()
	return _objectives
end

function ObjectiveTime.reset()
	ComboState.set_frozen(FREEZE_REASON, false)
	was_carrying = false
	tick_timer = 0
	_objectives = 0
end

mod.objective_time = ObjectiveTime

return ObjectiveTime
