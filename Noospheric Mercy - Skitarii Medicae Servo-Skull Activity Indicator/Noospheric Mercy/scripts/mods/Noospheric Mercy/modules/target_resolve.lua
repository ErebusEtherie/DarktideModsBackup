local mod = get_mod("Noospheric Mercy")
local Phrases = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/phrases")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")

local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

local ScriptUnit = ScriptUnit
local Vector3 = Vector3
local Vector3Box = Vector3Box
local Unit = Unit
local math_huge = math.huge
local math_abs = math.abs
local math_sqrt = math.sqrt

local STICKY_BONUS = 0.15

local TargetResolve = {}

local function position_of(unit)
	if unit and Unit.alive(unit) then
		return Unit.world_position(unit, 1)
	end

	return nil
end

TargetResolve.position_of = position_of

local _state = mod:persistent_table("noospheric_mercy_target_state", { exact = {}, infer = {}, pending = nil })
_state.exact = _state.exact or {}
_state.infer = _state.infer or {}

local _exact = _state.exact
local _infer = _state.infer

local function name_of(unit)
	local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn
	local player = player_unit_spawn and player_unit_spawn:owner(unit)

	return (player and player.name and player:name()) or tostring(unit)
end

TargetResolve.name_of = name_of

local function help_status(unit)
	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")

	if not character_state_component then
		return false, false, false
	end

	local needs = PlayerUnitStatus.requires_allied_interaction_help(character_state_component)
	local ledge = PlayerUnitStatus.is_ledge_hanging(character_state_component)
	local assisted_state_input_component = unit_data_extension:read_component("assisted_state_input")
	local assisted = assisted_state_input_component ~= nil and PlayerUnitStatus.is_assisted(assisted_state_input_component) or false

	return needs, ledge, assisted
end

local function requires_help(unit)
	local needs, ledge, assisted = help_status(unit)

	return needs and not ledge and not assisted
end

local _down_logged = {}

function TargetResolve.log_down_transitions()
	if not Log.enabled() then
		return
	end

	local seen = {}

	for _, player in pairs(Managers.player:players()) do
		local unit = player.player_unit

		if unit and ALIVE[unit] then
			local needs, ledge, assisted = help_status(unit)

			if needs then
				seen[unit] = true

				if not _down_logged[unit] then
					_down_logged[unit] = true

					local who = (player.name and player:name()) or tostring(unit)
					Log.write("DOWN player=%s requires help (ledge_hang=%s, being_assisted=%s, skull_rescuable=%s)",
						who, tostring(ledge), tostring(assisted), tostring(not ledge and not assisted))
				end
			end
		end
	end

	for unit in pairs(_down_logged) do
		if not seen[unit] then
			_down_logged[unit] = nil
			Log.write("RECOVERED player=%s no longer requires help", name_of(unit))
		end
	end
end

function TargetResolve.count_needs_help()
	local count = 0

	for _, player in pairs(Managers.player:players()) do
		local unit = player.player_unit

		if unit and ALIVE[unit] and requires_help(unit) then
			count = count + 1
		end
	end

	return count
end

function TargetResolve.any_needs_help()
	for _, player in pairs(Managers.player:players()) do
		local unit = player.player_unit

		if unit and ALIVE[unit] and requires_help(unit) then
			return true
		end
	end

	return false
end

local _cands = {}

local function disabled_players()
	table.clear(_cands)

	for _, player in pairs(Managers.player:players()) do
		local unit = player.player_unit

		if unit and ALIVE[unit] and requires_help(unit) then
			_cands[#_cands + 1] = unit
		end
	end

	return _cands
end

local function store_pos(st, pos)
	if st.prev_pos then
		st.prev_pos:store(pos)
	else
		st.prev_pos = Vector3Box(pos)
	end
end

local function infer(skull_unit)
	local cands = disabled_players()
	local n = #cands

	if n == 0 then
		_infer[skull_unit] = nil

		return nil, nil, false
	end

	local st = _infer[skull_unit]

	if not st then
		st = {}
		_infer[skull_unit] = st
	end

	local skull_pos = position_of(skull_unit)

	if st.locked and ALIVE[st.locked] and requires_help(st.locked) then
		if skull_pos then
			store_pos(st, skull_pos)
		end

		return st.locked, Phrases.CONFIDENCE_CERTAIN, true
	end

	st.locked = nil

	if n == 1 then
		local only = cands[1]
		local only_pos = position_of(only)

		if skull_pos and only_pos and Vector3.distance_squared(skull_pos, only_pos) < Phrases.ARRIVAL_DISTANCE_SQ then
			st.locked = only
		end

		if skull_pos then
			store_pos(st, skull_pos)
		end

		return only, Phrases.CONFIDENCE_CERTAIN, st.locked ~= nil
	end

	local heading

	if skull_pos and st.prev_pos then
		local vel = skull_pos - st.prev_pos:unbox()
		local vlen = Vector3.length(vel)

		if vlen > 0.001 then
			heading = vel / vlen
		end
	end

	local prev_leading = st.leading
	local best, best_eff, best_d2, best_raw = nil, -math_huge, math_huge, 0

	for i = 1, n do
		local unit = cands[i]
		local p = position_of(unit)

		if p and skull_pos then
			local d2 = Vector3.distance_squared(skull_pos, p)
			local score = 0

			if heading then
				local to = p - skull_pos
				local tlen = Vector3.length(to)

				if tlen > 0.001 then
					score = Vector3.dot(heading, to / tlen)
				end
			end

			local effective = score

			if unit == prev_leading then
				effective = effective + STICKY_BONUS
			end

			if effective > best_eff + 0.01 or (math_abs(effective - best_eff) <= 0.01 and d2 < best_d2) then
				best, best_eff, best_d2, best_raw = unit, effective, d2, score
			end
		end
	end

	st.leading = best

	if best and best_d2 < Phrases.ARRIVAL_DISTANCE_SQ then
		st.locked = best
	end

	if skull_pos then
		store_pos(st, skull_pos)
	end

	if st.locked then
		if Log.enabled() and st.logged_locked ~= st.locked then
			st.logged_locked = st.locked
			st.logged_best = nil
			Log.write("INFER lock: skull arrived at %s (guess -> certain)", name_of(st.locked))
		end

		return st.locked, Phrases.CONFIDENCE_CERTAIN, true
	end

	if Log.enabled() and best and st.logged_best ~= best then
		st.logged_best = best
		st.logged_locked = nil
		Log.write("INFER guess: %d candidates, leading=%s (heading_dot=%.2f, dist=%.1fm)", n, name_of(best), best_raw, math_sqrt(best_d2))
	end

	return best, Phrases.CONFIDENCE_GUESS, false
end

function TargetResolve.set_exact(skull_unit, ally_unit)
	local changed = _exact[skull_unit] ~= ally_unit
	_exact[skull_unit] = ally_unit

	if changed then
		Log.write("SET_EXACT firer hook -> target=%s", name_of(ally_unit))
	end

	return changed
end

function TargetResolve.set_pending(ally_unit)
	local changed = _state.pending ~= ally_unit
	_state.pending = ally_unit

	if changed then
		Log.write("SET_PENDING chat broadcast -> target=%s", name_of(ally_unit))
	end
end

function TargetResolve.clear(skull_unit)
	if _exact[skull_unit] then
		Log.write("CLEAR exact target for skull")
	end

	_exact[skull_unit] = nil
	_infer[skull_unit] = nil

	if _state.pending and not (ALIVE[_state.pending] and requires_help(_state.pending)) then
		_state.pending = nil
	end
end

function TargetResolve.resolve(go_id, skull_unit, dt)
	local ally = _exact[skull_unit]

	if ally and ALIVE[ally] and requires_help(ally) then
		return ally, Phrases.CONFIDENCE_CERTAIN, true, "exact"
	end

	if _state.pending and ALIVE[_state.pending] and requires_help(_state.pending) then
		return _state.pending, Phrases.CONFIDENCE_CERTAIN, true, "pending"
	end

	local unit, confidence, locked = infer(skull_unit)

	return unit, confidence, locked, "infer"
end

return TargetResolve
