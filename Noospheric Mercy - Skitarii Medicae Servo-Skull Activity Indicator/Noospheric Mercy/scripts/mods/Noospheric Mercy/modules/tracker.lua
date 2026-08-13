local mod = get_mod("Noospheric Mercy")
local Phrases = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/phrases")
local Log = mod:io_dofile("Noospheric Mercy/scripts/mods/Noospheric Mercy/modules/log")

local Breed = require("scripts/utilities/breed")
local CompanionServoSkullSettings = require("scripts/settings/companion/companion_servo_skull_settings")

local ScriptUnit = ScriptUnit
local GameSession = GameSession

local SERVO_SKULL_BREED = "companion_servo_skull"

local STATE_INJECT_ALLY = CompanionServoSkullSettings.STATES.inject_ally
local STATE_HACKING = CompanionServoSkullSettings.STATES.hacking

local KIND_RESCUE = "rescue"
local KIND_HACK = "hack"

local Tracker = {
	active = {},
	on_start = nil,
	on_refresh = nil,
	on_end = nil,
}

Tracker.KIND_RESCUE = KIND_RESCUE
Tracker.KIND_HACK = KIND_HACK

local function kind_for_state(state)
	if state == STATE_INJECT_ALLY then
		return KIND_RESCUE
	end

	if state == STATE_HACKING then
		return KIND_HACK
	end

	return nil
end

local _logged_companion = {}
local _logged_state = {}

local function game_object_id(unit)
	local unit_spawner = Managers.state.unit_spawner

	return unit_spawner and unit_spawner:game_object_id(unit)
end

function Tracker.update(dt, t, game_session)
	local active = Tracker.active

	for _, player in pairs(Managers.player:players()) do
		local owner_unit = player.player_unit

		if owner_unit and ALIVE[owner_unit] then
			local spawner = ScriptUnit.has_extension(owner_unit, "companion_spawner_system")

			if spawner then
				local companions = spawner:companion_units()

				for i = 1, #companions do
					local skull = companions[i]
					local breed = skull and ALIVE[skull] and Breed.unit_breed_or_nil(skull)

					if breed and not _logged_companion[skull] then
						_logged_companion[skull] = true
						Log.write("COMPANION owner=%s breed=%s", (player.name and player:name()) or "?", tostring(breed.name))
					end

					local go_id = breed and breed.name == SERVO_SKULL_BREED and game_object_id(skull)

					if go_id then
						local state = GameSession.game_object_field(game_session, go_id, "state")

						if _logged_state[go_id] ~= state then
							local prev = _logged_state[go_id]
							_logged_state[go_id] = state

							if kind_for_state(state) or kind_for_state(prev) then
								Log.write("SKULL owner=%s go_id=%s state=%s", (player.name and player:name()) or "?", tostring(go_id), tostring(state))
							end
						end

						local entry = active[go_id]
						local kind = kind_for_state(state)

						if entry and entry.kind ~= kind then
							if Tracker.on_end then
								Tracker.on_end(go_id, entry.skull_unit, entry.kind)
							end

							active[go_id] = nil
							entry = nil
						end

						if kind then
							if not entry then
								entry = { skull_unit = skull, started_t = t, kind = kind }
								active[go_id] = entry

								if Tracker.on_start then
									Tracker.on_start(go_id, skull, kind)
								end
							end

							if Tracker.on_refresh then
								Tracker.on_refresh(go_id, skull, dt, t, kind)
							end
						end
					end
				end
			end
		end
	end

	for go_id, entry in pairs(active) do
		if not ALIVE[entry.skull_unit] then
			if Tracker.on_end then
				Tracker.on_end(go_id, entry.skull_unit, entry.kind)
			end

			active[go_id] = nil
		end
	end
end

function Tracker.reset()
	for go_id in pairs(Tracker.active) do
		Tracker.active[go_id] = nil
	end

	for unit in pairs(_logged_companion) do
		_logged_companion[unit] = nil
	end

	for go_id in pairs(_logged_state) do
		_logged_state[go_id] = nil
	end
end

return Tracker
