---@type mod
local mod = get_mod("dopamine")

if mod.objective_markers then
	return mod.objective_markers
end

local Unit = Unit
local ScriptUnit = ScriptUnit
local Managers = Managers

local ScoringConstants = mod:core(mod.scoring_constants, "utils/scoring/constants")

local HudElementMissionObjective =
	require("scripts/ui/hud/elements/mission_objective_feed/hud_element_mission_objective")
local InteractionTemplates = require("scripts/settings/interaction/interaction_templates")

local OBJECTIVE_NODE = "ui_objective_marker"

local MARKER_STYLE_MULT = "objective_bonus_mult"
local MARKER_STYLE_SP = "objective_bonus_sp"

local markers_by_unit = setmetatable({}, { __mode = "k" })

local OBJECTIVE_UI_INTERACTION_TYPE = "mission"

local USE_SHOW_MARKER_GATE = {
	decoding = true,
	servo_skull = true,
}

---@param unit Unit
---@return boolean
local function is_objective_interaction(unit)
	local extension = unit and Unit.alive(unit) and ScriptUnit.has_extension(unit, "interactee_system")
	if not extension then
		return false
	end

	local template = InteractionTemplates[extension:interaction_type()]

	return template ~= nil and template.ui_interaction_type == OBJECTIVE_UI_INTERACTION_TYPE
end

---@param unit Unit
---@return boolean
local function is_objective_destructible(unit)
	if not unit or not Unit.alive(unit) then
		return false
	end

	return ScriptUnit.has_extension(unit, "destructible_system") ~= nil
		and ScriptUnit.has_extension(unit, "mission_objective_target_system") ~= nil
end

---@param unit Unit
---@return boolean
local function is_marked_objective(unit)
	return is_objective_interaction(unit) or is_objective_destructible(unit)
end

---@param marker DLH_MarkerHandle
---@return boolean
local function objective_is_interactable(marker)
	local unit = marker.unit

	if not unit or not Unit.alive(unit) then
		return false
	end

	local extension = ScriptUnit.has_extension(unit, "interactee_system")
	if not extension then

		if is_objective_destructible(unit) then
			local health_extension = ScriptUnit.has_extension(unit, "health_system")

			return not health_extension or health_extension:is_alive()
		end

		return false
	end

	if not extension:active() or extension:used() then
		return false
	end

	if USE_SHOW_MARKER_GATE[extension:interaction_type()] then
		local player_unit = mod.dl.player.local_player_unit()

		if not player_unit or not extension:show_marker(player_unit) then
			return false
		end
	end

	return true
end

local function register_marker_style(style_key, color)
	local font_type = mod.dl.fonts.validated("mono_tide_bold")

	mod.dl_hud.marker.register_style(style_key, {
		font = font_type,
		font_size = 26,
		color = color,

		background_color = { 100, color[2], color[3], color[4] },
		background_padding = 2,

		persistent = true,
		animate = mod.dl_hud.marker.animate.static({
			near_distance = 10,
			near_lift = 50,
		}),

		visible_fn = objective_is_interactable,

		world_lift = 0.5,
		scale_near = 1.2,
		scale_near_distance = 5,
		scale_far = 0.8,
		scale_far_distance = 10,

		max_distance = 10,
		fade_in_distance = 3,

		z_layer = 30,

		max_active = 16,
	})
end

register_marker_style(MARKER_STYLE_MULT, mod.constants.COLOR.NUMBERS.ORANGE)
register_marker_style(MARKER_STYLE_SP, mod.constants.COLOR.NUMBERS.GREEN)

---@param unit Unit
---@return table|nil reward

---@param interaction_type string
---@return table|nil reward
local function reward_for_interaction_type(interaction_type)
	local template = InteractionTemplates[interaction_type]

	if not template or template.ui_interaction_type ~= OBJECTIVE_UI_INTERACTION_TYPE then
		return nil
	end

	local rewards = ScoringConstants.OBJECTIVE_INTERACTION_REWARD

	return rewards[interaction_type] or rewards.default
end

local function reward_for_unit(unit)
	local extension = ScriptUnit.has_extension(unit, "interactee_system")
	if extension then
		return reward_for_interaction_type(extension:interaction_type())
	end

	if is_objective_destructible(unit) then
		return ScoringConstants.OBJECTIVE_DESTRUCTIBLE_REWARD
	end

	return nil
end

---@param unit Unit
---@return string style_key, string text
local function marker_content(unit)
	local reward = reward_for_unit(unit)

	if reward and reward.kind == "sp" then
		return MARKER_STYLE_SP, "+" .. mod.dl.str.format_number(reward.sp) .. " SP"
	end

	local add = ScoringConstants.OBJECTIVE_COMPLETE_MULT.add
	return MARKER_STYLE_MULT, "+" .. string.format("%g", add) .. "x MULT BONUS"
end

---@alias MarkerSource "objective" | "interaction"

---@param unit Unit
---@param source MarkerSource
local function add_marker(unit, source)

	if type(unit) ~= "userdata" or not Unit.alive(unit) or not is_marked_objective(unit) then
		return
	end

	local style_key, text = marker_content(unit)
	local existing = markers_by_unit[unit]

	if existing then

		if existing.style == style_key and mod.dl_hud.marker.is_active(existing.handle) then
			return
		end

		mod.dl_hud.marker.remove(existing.handle)
		markers_by_unit[unit] = nil
	end

	local handle = mod.dl_hud.marker.fire(style_key, {

		unit = unit,
		unit_node = OBJECTIVE_NODE,
		text = text,
	})

	if handle then
		markers_by_unit[unit] = { handle = handle, style = style_key, source = source }
	end
end

---@param unit Unit
---@param source MarkerSource|nil
local function remove_marker(unit, source)
	local record = markers_by_unit[unit]
	if not record then
		return
	end

	if source and record.source ~= source then
		return
	end

	mod.dl_hud.marker.remove(record.handle)
	markers_by_unit[unit] = nil
end

mod.dl.game_hooks.hook_safe(HudElementMissionObjective, "_add_unit_marker", function(_self, unit)
	add_marker(unit, "objective")
end)

mod.dl.game_hooks.hook_safe(HudElementMissionObjective, "_remove_unit_markers", function(_self, unit)
	remove_marker(unit, "objective")
end)

mod.dl.game_hooks.hook(HudElementMissionObjective, "_destroy_markers", function(next_fn, self)
	local marker_ids = self._marker_ids

	if marker_ids then
		for unit, _ in pairs(marker_ids) do
			remove_marker(unit, "objective")
		end
	end

	return next_fn(self)
end)

local RECONCILE_INTERVAL = 0.5
local reconcile_timer = 0

local live_objective_units = {}
local live_interaction_units = {}

---@return table<Unit, boolean>|nil
local function collect_live_objective_units()
	local hud = Managers.ui and Managers.ui:get_hud()
	local feed = hud and hud:element("HudElementMissionObjectiveFeed")
	local hud_objectives = feed and feed._hud_objectives

	if not hud_objectives then
		return nil
	end

	for unit, _ in pairs(live_objective_units) do
		live_objective_units[unit] = nil
	end

	for _, hud_objective in pairs(hud_objectives) do
		local marker_ids = hud_objective._marker_ids

		if marker_ids then
			for unit, _ in pairs(marker_ids) do
				live_objective_units[unit] = true
			end
		end
	end

	return live_objective_units
end

---@return table<Unit, boolean>|nil
local function collect_live_interaction_units()
	local hud = Managers.ui and Managers.ui:get_hud()
	local element = hud and hud:element("HudElementInteraction")
	local interaction_units = element and element._interaction_units

	if not interaction_units then
		return nil
	end

	for unit, _ in pairs(live_interaction_units) do
		live_interaction_units[unit] = nil
	end

	for unit, _ in pairs(interaction_units) do
		live_interaction_units[unit] = true
	end

	return live_interaction_units
end

---@class ObjectiveMarkers
local ObjectiveMarkers = {}

ObjectiveMarkers.is_objective_interaction = is_objective_interaction

ObjectiveMarkers.is_objective_destructible = is_objective_destructible

ObjectiveMarkers.reward_for_unit = reward_for_unit

ObjectiveMarkers.reward_for_interaction_type = reward_for_interaction_type

---@param dt number
function ObjectiveMarkers.tick(dt)
	reconcile_timer = reconcile_timer - dt

	if reconcile_timer > 0 then
		return
	end

	reconcile_timer = RECONCILE_INTERVAL

	local live_objective = collect_live_objective_units()
	local live_interaction = collect_live_interaction_units()

	if not live_objective and not live_interaction then
		return
	end

	if live_objective then
		for unit, _ in pairs(live_objective) do
			add_marker(unit, "objective")
		end
	end

	if live_interaction then
		for unit, _ in pairs(live_interaction) do
			add_marker(unit, "interaction")
		end
	end

	for unit, record in pairs(markers_by_unit) do
		local live = record.source == "interaction" and live_interaction or live_objective

		if live and (not live[unit] or not Unit.alive(unit) or not is_marked_objective(unit)) then
			remove_marker(unit, record.source)
		end
	end
end

function ObjectiveMarkers.reset()
	for unit, _ in pairs(markers_by_unit) do
		markers_by_unit[unit] = nil
	end

	reconcile_timer = 0
end

mod.objective_markers = ObjectiveMarkers

return ObjectiveMarkers
