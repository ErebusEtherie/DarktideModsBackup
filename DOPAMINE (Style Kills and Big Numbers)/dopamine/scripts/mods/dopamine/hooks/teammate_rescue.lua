---@type mod
local mod = get_mod("dopamine")

if mod.teammate_rescue then
	return mod.teammate_rescue
end

local Unit = Unit

local EventManager = mod:core(mod.event_manager, "utils/event/manager")
local ScoringConstants = mod:core(mod.scoring_constants, "utils/scoring/constants")

local InteractionSettings = require("scripts/settings/interaction/interaction_settings")

local INTERACTION_SUCCESS = InteractionSettings.results.success

local MARKER_STYLE_MULT = "teammate_bonus_mult"
local MARKER_STYLE_SP = "teammate_bonus_sp"

local TEAMMATE_NODE = "ui_interaction_marker"

local STATE_INTERACTION = {
	knocked_down = "revive",
	hogtied = "rescue",
	netted = "remove_net",
}

local markers_by_unit = setmetatable({}, { __mode = "k" })

local _rescue_counts = { revive = 0, rescue = 0, remove_net = 0 }

local _global_rescues = 0
local GLOBAL_RESCUE_TYPES = {
	revive = true,
	rescue = true,
	remove_net = true,
	pull_up = true,
}

---@param marker DLH_MarkerHandle
---@return boolean
local function teammate_needs_rescue(marker)
	local unit = marker.unit

	if not unit or not Unit.alive(unit) then
		return false
	end

	local state = mod.dl.player.character_state(unit)

	return state ~= nil and STATE_INTERACTION[state] ~= nil
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

		visible_fn = teammate_needs_rescue,

		world_lift = 0.5,
		scale_near = 1.2,
		scale_near_distance = 5,
		scale_far = 0.8,
		scale_far_distance = 15,

		max_distance = 30,
		fade_in_distance = 5,

		z_layer = 30,

		max_active = 8,
	})
end

register_marker_style(MARKER_STYLE_MULT, mod.constants.COLOR.NUMBERS.ORANGE)
register_marker_style(MARKER_STYLE_SP, mod.constants.COLOR.NUMBERS.GREEN)

---@param interaction_type string
---@return string style_key, string text
local function marker_content(interaction_type)
	local reward = ScoringConstants.TEAMMATE_RESCUE_REWARD[interaction_type]

	if reward.kind == "sp" then
		return MARKER_STYLE_SP, "+" .. mod.dl.str.format_number(reward.sp) .. " SP"
	end

	return MARKER_STYLE_MULT, "+" .. string.format("%g", reward.add) .. "x MULT BONUS"
end

---@param unit Unit
---@param style_key string
---@param text string
local function add_marker(unit, style_key, text)
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
		unit_node = TEAMMATE_NODE,
		text = text,
	})

	if handle then
		markers_by_unit[unit] = { handle = handle, style = style_key }
	end
end

mod.dl.game_hooks.hook("PlayerInteracteeExtension", "stopped", function(next_fn, self, result, interactor_unit)
	local interaction_type = self:interaction_type()

	next_fn(self, result, interactor_unit)

	if result ~= INTERACTION_SUCCESS then
		return
	end

	if GLOBAL_RESCUE_TYPES[interaction_type] then
		_global_rescues = _global_rescues + 1
	end

	if interactor_unit ~= mod.dl.player.local_player_unit() then
		return
	end

	local reward = ScoringConstants.TEAMMATE_RESCUE_REWARD[interaction_type]

	if not reward then
		return
	end

	_rescue_counts[interaction_type] = (_rescue_counts[interaction_type] or 0) + 1

	if reward.kind == "sp" then

		EventManager.add_reward(reward.sp)
	else
		EventManager.add_timed_mult(reward.add, reward.duration)
	end
end)

local RECONCILE_INTERVAL = 0.5
local reconcile_timer = 0

local live_rescuable = {}

---@class TeammateRescue
local TeammateRescue = {}

---@return integer
function TeammateRescue.rescue_count()
	return _rescue_counts.revive + _rescue_counts.rescue + _rescue_counts.remove_net
end

---@return integer
function TeammateRescue.global_rescue_count()
	return _global_rescues
end

---@param dt number
function TeammateRescue.tick(dt)
	reconcile_timer = reconcile_timer - dt

	if reconcile_timer > 0 then
		return
	end

	reconcile_timer = RECONCILE_INTERVAL

	for unit, _ in pairs(live_rescuable) do
		live_rescuable[unit] = nil
	end

	local local_player = mod.dl.player.local_player()

	for _, player in pairs(mod.dl.player.players()) do
		if player ~= local_player then
			local unit = mod.dl.player.unit(player)
			local state = unit and mod.dl.player.character_state(unit)
			local interaction_type = state and STATE_INTERACTION[state]

			if interaction_type then
				live_rescuable[unit] = true
				add_marker(unit, marker_content(interaction_type))
			end
		end
	end

	for unit, record in pairs(markers_by_unit) do
		if not live_rescuable[unit] then
			mod.dl_hud.marker.remove(record.handle)
			markers_by_unit[unit] = nil
		end
	end
end

function TeammateRescue.reset()
	for unit, _ in pairs(markers_by_unit) do
		markers_by_unit[unit] = nil
	end

	_rescue_counts.revive = 0
	_rescue_counts.rescue = 0
	_rescue_counts.remove_net = 0
	_global_rescues = 0

	reconcile_timer = 0
end

mod.teammate_rescue = TeammateRescue

return TeammateRescue
