local mod = get_mod("Noospheric Mercy")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")

local GameSession = GameSession
local Unit = Unit

local INVALID_UNIT_ID = 0
local IS_LEVEL_UNIT = true

local HackTarget = {}

local _logged = {}

function HackTarget.resolve(game_session, go_id)
	if not game_session then
		local manager = Managers.state and Managers.state.game_session

		game_session = manager and manager:game_session()
	end

	if not game_session or not go_id then
		return nil
	end

	local hacking_unit_id = GameSession.game_object_field(game_session, go_id, "hacking_unit_id")

	if not hacking_unit_id or hacking_unit_id <= INVALID_UNIT_ID then
		return nil
	end

	local unit_spawner = Managers.state.unit_spawner

	if not unit_spawner then
		return nil
	end

	local unit = unit_spawner:unit(hacking_unit_id, IS_LEVEL_UNIT)

	if not unit or not ALIVE[unit] then
		return nil
	end

	if _logged[go_id] ~= unit then
		_logged[go_id] = unit
		Log.write("HACK target resolved skull go_id=%s -> unit_id=%s", tostring(go_id), tostring(hacking_unit_id))
	end

	return unit
end

function HackTarget.position_of(unit, node_name)
	if not unit or not Unit.alive(unit) then
		return nil
	end

	local node = node_name and Unit.has_node(unit, node_name) and Unit.node(unit, node_name) or 1

	return Unit.world_position(unit, node)
end

function HackTarget.clear(go_id)
	_logged[go_id] = nil
end

function HackTarget.reset()
	for go_id in pairs(_logged) do
		_logged[go_id] = nil
	end
end

return HackTarget
