-- terminal.lua
--
-- The physical entry point to a pilgrimage: a prop in a side alcove of the Mourningstar
-- that shows a marker from across the room, a prompt when you walk up to it, and opens
-- the route view when you press the interact key.
--
-- ===========================================================================
-- WHY THIS IS HAND-ROLLED INSTEAD OF USING THE GAME'S INTERACTION SYSTEM
-- ===========================================================================
--
-- The obvious approach is to attach an InteracteeExtension to the prop and let the
-- vanilla system do everything: prompt, hold-to-activate, animation. That cannot work
-- here, and it is worth writing down why so nobody tries it again.
--
-- InteractorExtension finds what you are looking at with exactly two physics queries,
-- both against the collision filter "filter_interactable_overlap":
--
--     interactor_extension.lua:443  PhysicsWorld.raycast(... "collision_filter", FILTER)
--     interactor_extension.lua:486  physics_world:immediate_overlap(... "collision_filter", FILTER)
--
-- Only AFTER a physics hit does it ask whether the unit has an interactee extension
-- (line 515). /pil_look already proved this prop returns zero hits under that filter, so
-- it can never become the chosen target no matter what extension we attach. The
-- extension would be dead weight.
--
-- It would also be actively dangerous. The interaction target lives in a NETWORKED
-- component (player_unit_data_component_config.lua:975), so a client-only extension
-- means another machine can receive a target unit it has no extension for, and the very
-- next method call on it errors.
--
-- So: our own marker, our own prompt, our own key poll. We lose the vanilla hold ring
-- and the interact animation. We gain something that cannot desync and does not depend
-- on the prop's physics.
--
-- ===========================================================================
-- WHAT WE DO USE FROM THE GAME
-- ===========================================================================
--
--   * the real world marker system, so the floating icon is the genuine article rather
--     than something drawn by us:
--         Managers.event:trigger("add_world_marker_position", type, position, cb, data)
--     "hub_objective" is the template the Mourningstar itself uses for points of
--     interest (hud_element_mission_objective.lua:38). It fades out as you approach,
--     which is exactly right: the marker gets you there, the prompt takes over.
--
--   * the real input service, so the key we watch is whatever the player actually has
--     bound to interact, including on a controller:
--         Managers.input:get_input_service("Ingame"):get("interact_pressed")

local M = {}

local _mod
local _shared
local _run_state
local _settings
local _event_log
local _fileio
local _probe
local _hooks
local _debug_log
local _command_open_deadline

-- ---------------------------------------------------------------------------
-- The anchor
--
-- id_string is an authored identifier baked into the level, and Kaizen confirmed it is
-- byte-identical across separate game sessions, so matching on it is stable. The
-- position is kept as a fallback for the case where the scan finds nothing, which would
-- otherwise mean no terminal at all after a game patch reshuffles the hub.
-- ---------------------------------------------------------------------------

local TERMINAL_ID_STRING = "#ID[c7a5f74ab1d5e064]"

local FALLBACK_POSITION = { 26.4974, -109.6011, 99.8750 }

-- HEIGHT, and why the first build got it wrong.
--
-- Unit.world_position returns the unit's ORIGIN, which for a wall-mounted prop is its
-- pivot, and that pivot sits on the floor. The probe data proves it: the prop origin is
-- z = 99.8750, the camera was at z = 102.2223, so the origin is roughly 2.3m below eye
-- level, which is below the player's feet. The first version anchored the prompt there,
-- and it appeared lying on the ground.
--
-- The right answer is the prop's visual centre, which the engine will tell us:
--
--     local pose, extents = Unit.box(unit)     -- oriented bounding box
--     Matrix4x4.translation(pose)              -- its centre
--
-- HEIGHT and HORIZONTAL are blended SEPARATELY, along the same line from the prop's
-- origin to its bounding box centre, because the two axes wanted opposite corrections.
--
--     0.0  the origin, the prop's authored pivot
--     1.0  the bounding box centre
--
-- HEIGHT: 0.5. The origin sat on the floor, the box centre sat too high, halfway reads
-- correctly. Confirmed in game.
--
-- HORIZONTAL: 2.0, which is the box centre again as far beyond it as the origin is before
-- it. This is Kaizen's correction, and it is worth spelling out why it is not a guess.
-- Three observations pin the axis down:
--
--     at the origin (1.0 -> 0.0)   the prompt was OUT through the doorway
--     at the box centre (1.0)      it was in the middle of the room, needed to go deeper
--     the terminal                 is deeper still, in the alcove
--
-- So origin, box centre and terminal lie on one line in that order, and moving from the
-- box centre to the origin was a step in exactly the wrong direction. Reversing that step
-- from where it started is 2.0. The pivot being at the outer end of a prop that extends
-- inward is an ordinary way to author one; nothing about it is surprising once the sign
-- is known.
local BOX_CENTRE_BLEND_Z = 0.5
local BOX_CENTRE_BLEND_XY = 2.0

-- ===========================================================================
-- STOP GUESSING AT THE ANCHOR
-- ===========================================================================
--
-- Three attempts have now been made to derive this position from data, and all three were
-- wrong in a different direction: the unit origin put the prompt on the floor, the box
-- centre put it in the middle of the room, and origin-with-blended-height pushed it out
-- through the doorway.
--
-- The mistake underneath all three is the same. I kept treating Unit.world_position as
-- "where the terminal is". It is where the prop's PIVOT is, and for a ten-mesh prop
-- authored into an alcove the pivot can be anywhere, including outside the room. There is
-- no derivation from the unit that reliably lands on the face a player looks at.
--
-- So the anchor is now something you SET by looking at it. /pil_terminal_set fires the
-- same raycast the probe uses and takes the impact point, which is by definition on the
-- surface you are aiming at. That point is stored as an OFFSET from the unit origin, not
-- as an absolute coordinate, so it still follows the prop if a patch moves it.
--
-- The blend below stays as the default for a fresh install, since something has to show
-- before anyone has aimed at anything.
--
-- Note for later: probe.look_at reports hit.position as Unit.world_position(unit, 1),
-- which is the unit ORIGIN, not the impact point. That is precisely why the coordinate I
-- read out of look.txt and treated as "the terminal" was nothing of the sort. The impact
-- point has to be computed from the ray: origin + forward * hit.distance.
-- ===========================================================================

local KEY_OFFSET_X = "_terminal_offset_x"
local KEY_OFFSET_Y = "_terminal_offset_y"
local KEY_OFFSET_Z = "_terminal_offset_z"
local KEY_OFFSET_SET = "_terminal_offset_set"
local KEY_RETURN_PENDING = "_return_to_terminal_pending"
local KEY_RETURN_CONFIRMED = "_return_to_terminal_confirmed_in_mission"
local KEY_RETURN_ANCHOR_X = "_return_to_terminal_anchor_x"
local KEY_RETURN_ANCHOR_Y = "_return_to_terminal_anchor_y"
local KEY_RETURN_ANCHOR_Z = "_return_to_terminal_anchor_z"

-- Mortis Trials and the Meat Grinder return through HumanPlayer's
-- wanted_spawn_point. Pilgrimage uses its own identifier, intercepted at the
-- player-spawner seam, and uses the normal recent-mission spawn only to obtain
-- a known-good hub floor height and side. The terminal prompt anchor supplies
-- the exact X/Y destination. The custom identifier never enters Fatshark's
-- spawn-point table.
local RETURN_SPAWN_IDENTIFIER = "pilgrimage_terminal"
local RETURN_REFERENCE_IDENTIFIER = "recent_mission"
local RETURN_REQUEST_EXPIRY_S = 12

local PLAYER_MANAGER_PATH = "scripts/foundation/managers/player/player_manager"
local PLAYER_SPAWNER_SYSTEM_PATH =
	"scripts/extension_systems/player_spawner/player_spawner_system"

-- ANCHOR_LIFT is only the fallback for when Unit.box is unavailable or we never found
-- the unit at all. Probe entry [12] records a separate unit at exactly the same x and y
-- as the terminal at z = 102.0000, which is origin + 2.125, the height of the terminal's
-- screen. Halved to match the blend above.
local ANCHOR_LIFT = 1.05

-- Extra height for the floating marker only, so it hovers above the prop rather than
-- sitting on its face. The prompt panel stays at the centre.
local MARKER_HEIGHT_OFFSET = 0.8

M.TERMINAL_ID_STRING = TERMINAL_ID_STRING
M.FALLBACK_POSITION = FALLBACK_POSITION

-- The HUD element that OWNS every world marker. See on_marker_element_created for why
-- the terminal has to know about it at all.
M.WORLD_MARKERS_PATH = "scripts/ui/hud/elements/world_markers/hud_element_world_markers"

-- ---------------------------------------------------------------------------
-- Gating constants
-- ---------------------------------------------------------------------------

-- How far off-axis you may be looking and still get the prompt. The vanilla third
-- person cone is cos(0.8) which is about 0.70, roughly 45 degrees. Ours is deliberately
-- looser, because vanilla can afford to be strict: it has a physics raycast telling it
-- precisely what you are pointing at, and we only have a direction to a point.
local MIN_FACING_DOT = 0.35

-- Re-scan for the prop at most this often. A scan walks every unit in the level, so it
-- must never end up in a per-frame path, and the level is not always populated the
-- instant the hub state is entered.
local RESCAN_INTERVAL_S = 3

-- How long an in-flight marker request may stay in flight before we give up on it and
-- allow another.
--
-- This exists because of a real bug. "add_world_marker_position" is an event, and
-- Managers.event:trigger on an event with no listener does nothing at all: no error, no
-- callback, silence. The world marker HUD element registers that listener when the HUD
-- comes up, which is a moment AFTER the hub state is entered, so an add fired in that
-- window vanishes. The old code set _marker_requested = true, never got the callback,
-- and therefore never allowed another add for the rest of the visit. The marker only
-- came back after a mission, because leaving the hub tears down and clears the flag.
--
-- A timeout is the right shape of fix rather than "wait for the HUD", because we cannot
-- observe the listener and any wait would be a guess at the same number with more code.
local MARKER_REQUEST_TIMEOUT_S = 2

-- ---------------------------------------------------------------------------
-- State
--
-- All of it is per-visit-to-the-hub and torn down on leaving. Nothing here is allowed
-- to survive a level change, because the unit handles certainly do not.
-- ---------------------------------------------------------------------------

local _anchor_unit = nil
local _anchor_position = nil
local _marker_id = nil
local _marker_requested = false
local _marker_request_t = nil
local _last_scan_t = -1e9
local _was_in_hub = false
local _hub_entered_t = nil

local function _save_settings()
	local ok_dmf, dmf_mod = pcall(get_mod, "DMF")
	if ok_dmf and dmf_mod and dmf_mod.save_unsaved_settings_to_file then
		pcall(dmf_mod.save_unsaved_settings_to_file)
	end
end

-- The local HumanPlayer does not carry its wanted spawn point into the new hub
-- session. Keep the exact prompt coordinate separately so it is already available
-- when native player creation runs, before the hub's level-unit scan is guaranteed
-- to be ready.
local function _stored_return_anchor()
	if not _mod then return nil end
	local x = tonumber(_mod:get(KEY_RETURN_ANCHOR_X))
	local y = tonumber(_mod:get(KEY_RETURN_ANCHOR_Y))
	local z = tonumber(_mod:get(KEY_RETURN_ANCHOR_Z))
	if not (x and y and z) then return nil end
	return Vector3(x, y, z)
end

local function _remember_return_anchor(position)
	if not (_mod and position) then return end
	local x = Vector3.x(position)
	local y = Vector3.y(position)
	local z = Vector3.z(position)
	local old_x = tonumber(_mod:get(KEY_RETURN_ANCHOR_X))
	local old_y = tonumber(_mod:get(KEY_RETURN_ANCHOR_Y))
	local old_z = tonumber(_mod:get(KEY_RETURN_ANCHOR_Z))
	if old_x and old_y and old_z
		and math.abs(old_x - x) < 0.001
		and math.abs(old_y - y) < 0.001
		and math.abs(old_z - z) < 0.001 then
		return
	end
	_mod:set(KEY_RETURN_ANCHOR_X, x, false)
	_mod:set(KEY_RETURN_ANCHOR_Y, y, false)
	_mod:set(KEY_RETURN_ANCHOR_Z, z, false)
	_save_settings()
end

local function _clear_return_pending()
	if not _mod then return end
	_mod:set(KEY_RETURN_PENDING, false, false)
	_mod:set(KEY_RETURN_CONFIRMED, false, false)
	_save_settings()
end

-- The launcher first PREPARES the persistent request with confirmed=false.
-- Once terminal.tick sees the exact active Pilgrimage mission, it promotes the
-- request with confirmed=true. Only that second state may move the player.
-- This prevents the outbound Mourningstar spawn teardown from consuming its
-- own future return request.
function M.request_return(confirmed_in_mission)
	if not _mod then return false end
	local wanted_confirmed = confirmed_in_mission == true
	if M.return_pending()
		and (_mod:get(KEY_RETURN_CONFIRMED) == true) == wanted_confirmed then
		return true
	end
	_mod:set(KEY_RETURN_PENDING, true, false)
	_mod:set(KEY_RETURN_CONFIRMED, wanted_confirmed, false)

	_save_settings()

	return true
end

function M.return_pending()
	return _mod and _mod:get(KEY_RETURN_PENDING) == true or false
end

function M.return_ready()
	return M.return_pending()
		and _mod:get(KEY_RETURN_CONFIRMED) == true
end

-- Arm the return while the player is demonstrably inside the active
-- Pilgrimage leg. Keeping the flag persistent from mission entry, rather than
-- trying to predict each possible exit callback, covers success, failure,
-- leaving through the options menu, disconnects and even a game restart.
local function _confirmed_active_pilgrimage_mission()
	if not _run_state or type(_run_state.is_active) ~= "function"
		or not _run_state.is_active() then
		return false
	end
	if _shared.is_in_psykhanium and _shared.is_in_psykhanium() then return false end

	local expected = type(_run_state.current_mission) == "function"
		and _run_state.current_mission() or nil
	local actual = _shared.mission_name and _shared.mission_name() or nil
	return type(expected) == "string" and expected ~= "" and expected == actual
end

-- Assign the custom wanted-spawn identifier while the HumanPlayer still
-- exists in the mission session. This is needed for menu exits: unlike normal
-- success/failure, Managers.multiplayer_session:leave("leave_mission") does
-- not pass through PlayerManager:set_last_mission before the hub transition.
function M.arm_return_spawn()
	if not M.return_ready() or not _confirmed_active_pilgrimage_mission() then
		return false, "no confirmed active Pilgrimage mission"
	end

	local player_manager = Managers and Managers.player
	local players = player_manager and player_manager._human_players or {}
	local armed = 0
	for _, player in pairs(players) do
		if player and type(player.set_wanted_spawn_point) == "function" then
			player:set_wanted_spawn_point(RETURN_SPAWN_IDENTIFIER)
			armed = armed + 1
		end
	end

	if armed > 0 then
		_debug_log("terminal:return", _shared.fixed_time(),
			"armed native terminal spawn before menu/session leave",
			0, "info")
		return true, armed
	end
	return false, "no human player accepted a wanted spawn point"
end

local function _return_spawn_transform(reference_position, reference_rotation,
	anchor_position)
	if not reference_position or not anchor_position then return nil, nil end

	-- The prompt anchor is the one calibrated terminal coordinate. Reuse its
	-- horizontal position exactly. Its Z is intentionally raised to the screen,
	-- so retain the native recent-mission floor height for safe player creation.
	local x = Vector3.x(anchor_position)
	local y = Vector3.y(anchor_position)
	local z = Vector3.z(reference_position)
	return Vector3(x, y, z), reference_rotation
end

local function _return_matches_last_pilgrimage_mission(mission_name)
	if not M.return_ready() or not _run_state
		or type(_run_state.launch_record) ~= "function" then
		return false
	end
	local ok, record = pcall(_run_state.launch_record)
	return ok and type(record) == "table"
		and record.mission ~= nil and record.mission == mission_name
end

local function _install_player_manager_hook(PlayerManager)
	if not PlayerManager or type(PlayerManager.set_last_mission) ~= "function" then return end
	if _hooks.claim(PlayerManager, "__pilgrimage_terminal_return_manager") then return end

	_mod:hook(PlayerManager, "set_last_mission",
			function(func, self, mission_name)
				local result = func(self, mission_name)
				if _return_matches_last_pilgrimage_mission(mission_name) then
					local players = self._human_players or {}
					for _, player in pairs(players) do
						if player and type(player.set_wanted_spawn_point) == "function" then
							player:set_wanted_spawn_point(RETURN_SPAWN_IDENTIFIER)
						end
					end
				end
				return result
			end)
end

local function _install_player_spawner_hook(PlayerSpawnerSystem)
	if not PlayerSpawnerSystem
		or type(PlayerSpawnerSystem.next_free_spawn_point) ~= "function" then return end
	if _hooks.claim(PlayerSpawnerSystem, "__pilgrimage_terminal_return_spawner") then return end

	_mod:hook(PlayerSpawnerSystem, "next_free_spawn_point",
			function(func, self, optional_spawn_identifier)
				-- HumanPlayer.init deliberately starts the new local hub player with a
				-- nil wanted spawn. The persistent confirmed request is therefore the
				-- authoritative return signal; the custom identifier is only a useful
				-- fast-path hint when Darktide happens to preserve it.
				-- This method is called while the hub player is being created,
				-- before the higher-level game-state helper reliably reports that
				-- the hub is active. PlayerSpawnerSystem already owns the exact,
				-- authoritative flag from its initialization context. Using it makes
				-- the first spawn query consume the return request. Waiting for
				-- shared.is_in_hub() caused a later query to move an already-running
				-- player, which looked like the old delayed fallback teleport.
				local spawning_in_hub = self and self._in_hub == true
				if not M.return_ready() or not spawning_in_hub then
					return func(self, optional_spawn_identifier)
				end
				-- A spawn query is not necessarily initial creation. Once a local
				-- character exists, never consume a stale return as another placement.
				-- This intentionally leaves ordinary engine corrections alone.
				local existing_unit = _shared.local_player_unit and _shared.local_player_unit()
				if existing_unit then
					_clear_return_pending()
					_debug_log("terminal:return", _shared.fixed_time(),
						"ignored late terminal spawn request: local character already exists", 0, "warning")
					return func(self, optional_spawn_identifier)
				end

				-- Ask the native spawner for the normal valid floor/side, then move
				-- that spawn transform to the already-calibrated prompt anchor.
				local reference_position, reference_rotation, reference_parent, side = func(
					self,
					RETURN_REFERENCE_IDENTIFIER
				)
				local anchor_position = _stored_return_anchor()
				if not anchor_position then
					local _, located_position, how = M.locate()
					if how ~= "fallback_position" then
						anchor_position = located_position
					end
				end
				local position, rotation = _return_spawn_transform(
					reference_position,
					reference_rotation,
					anchor_position
				)
				if not position then
					-- Do not leave a failed request armed for a later respawn. A normal
					-- native spawn is preferable to a surprise second movement.
					_clear_return_pending()
					return reference_position, reference_rotation, reference_parent, side
				end

				-- The native player-spawn pipeline now owns the only placement.
				-- Clear the request immediately so no later tick can move the player.
				_clear_return_pending()
				_debug_log("terminal:return", _shared.fixed_time(),
					"native hub spawn placed at cached Pilgrimage terminal prompt anchor; requested="
						.. tostring(optional_spawn_identifier),
					0, "info")
				return position, rotation, nil, side
			end)
end

local function _install_native_return_hooks()
	-- These classes are not guaranteed to exist when Pilgrimage itself loads.
	-- hook_require_now handles both cases: install immediately if already loaded,
	-- or install at the exact moment Darktide requires the module later.
	_hooks.require_now(PLAYER_MANAGER_PATH, _install_player_manager_hook)
	_hooks.require_now(PLAYER_SPAWNER_SYSTEM_PATH, _install_player_spawner_hook)
end

-- What the HUD element reads each frame. Kept as one table that we mutate in place
-- rather than a fresh table per frame, because this is read at frame rate and churning
-- garbage for the collector every frame is exactly the kind of thing that shows up as a
-- stutter later.
local _prompt = {
	visible = false,
	world_position = nil,
	top_text = "PILGRIMAGE",
	bottom_text = "",
}

local _stats = {
	scans = 0,
	found_by = "none",
	markers_added = 0,
	markers_removed = 0,
	marker_requests = 0,
	marker_timeouts = 0,
	marker_resets = 0,
	opens = 0,
	anchor_from = "none",
	last_error = nil,
}

-- ---------------------------------------------------------------------------
-- Finding the prop
-- ---------------------------------------------------------------------------

-- Level.units(level, true) returns every unit authored into the level, and the true
-- means "include sub levels", which matters because hub props are frequently nested.
-- It allocates a fresh table per call, hence the throttle on the caller side.
local function _level_units()
	local spawner = Managers.state and Managers.state.unit_spawner
	if not spawner or not spawner.level_by_index then return nil, "no unit spawner" end

	local ok, level = pcall(spawner.level_by_index, spawner, 1)
	if not ok or not level then return nil, "no level" end

	local ok_units, units = pcall(Level.units, level, true)
	if not ok_units or type(units) ~= "table" then return nil, "Level.units failed" end

	return units
end

-- The point we hang the prompt and the marker off. Prefers the prop's oriented bounding
-- box centre, because the origin is a pivot and pivots sit on the floor.
-- A manually placed anchor wins over anything we could work out ourselves.
local function _stored_offset()
	if not _mod then return nil end
	if _mod:get(KEY_OFFSET_SET) ~= true then return nil end

	local x = tonumber(_mod:get(KEY_OFFSET_X))
	local y = tonumber(_mod:get(KEY_OFFSET_Y))
	local z = tonumber(_mod:get(KEY_OFFSET_Z))
	if not (x and y and z) then return nil end

	return x, y, z
end

local function _anchor_for(unit, origin)
	local dx, dy, dz = _stored_offset()
	if dx then
		_stats.anchor_from = "manual_offset"
		return Vector3(Vector3.x(origin) + dx, Vector3.y(origin) + dy, Vector3.z(origin) + dz)
	end

	if unit and rawget(_G, "Unit") and Unit.box and rawget(_G, "Matrix4x4") then
		local ok, pose = pcall(Unit.box, unit)
		if ok and pose then
			local ok_centre, centre = pcall(Matrix4x4.translation, pose)
			if ok_centre and centre then
				_stats.anchor_from = "box_blend"

				-- One line, two blend factors. Both axes are measured from the origin
				-- toward the box centre; height stops halfway, horizontal overshoots to
				-- twice, which carries it past the box centre and into the alcove.
				local function blend(from, to, factor)
					return from + (to - from) * factor
				end

				return Vector3(
					blend(Vector3.x(origin), Vector3.x(centre), BOX_CENTRE_BLEND_XY),
					blend(Vector3.y(origin), Vector3.y(centre), BOX_CENTRE_BLEND_XY),
					blend(Vector3.z(origin), Vector3.z(centre), BOX_CENTRE_BLEND_Z))
			end
		end
	end

	_stats.anchor_from = "origin_plus_lift"
	return Vector3(Vector3.x(origin), Vector3.y(origin), Vector3.z(origin) + ANCHOR_LIFT)
end

-- Returns unit, position, how_we_found_it.
function M.locate()
	_stats.scans = _stats.scans + 1

	local units, err = _level_units()
	if units then
		for i = 1, #units do
			local unit = units[i]
			local ok, id = pcall(Unit.id_string, unit)
			if ok and id == TERMINAL_ID_STRING then
				local ok_pos, position = pcall(Unit.world_position, unit, 1)
				if ok_pos and position then
					_stats.found_by = "id_string"
					return unit, _anchor_for(unit, position), "id_string"
				end
			end
		end
		_stats.last_error = "id_string not found among " .. tostring(#units) .. " units"
	else
		_stats.last_error = tostring(err)
	end

	-- Nothing matched. Fall back to the recorded coordinates so the terminal still
	-- exists, and record that we did, because a silent fallback would hide the fact
	-- that a game update moved or renamed the prop.
	local ok, position = pcall(Vector3, FALLBACK_POSITION[1], FALLBACK_POSITION[2],
		FALLBACK_POSITION[3] + ANCHOR_LIFT)
	if ok and position then
		_stats.found_by = "fallback_position"
		_stats.anchor_from = "fallback_plus_lift"
		return nil, position, "fallback_position"
	end

	_stats.found_by = "none"
	return nil, nil, "none"
end

-- ---------------------------------------------------------------------------
-- Placing the anchor by hand
-- ---------------------------------------------------------------------------

-- Aim at the terminal and call this. Takes the point the ray actually strikes and stores
-- it as an offset from the prop's origin.
function M.set_anchor_from_aim(max_distance)
	if not _probe then return false, "probe unavailable" end
	if not _anchor_unit then return false, "terminal not located yet" end

	local hits_by_filter, err, ray_origin, forward = _probe.look_at(max_distance or 8)
	if not hits_by_filter then return false, tostring(err) end

	-- Nearest hit on the terminal itself, across every filter the probe tries. Matching on
	-- the unit means aiming slightly off and striking the wall behind cannot silently
	-- reposition the prompt onto the wall.
	local best_distance, best = nil, nil
	for i = 1, #hits_by_filter do
		local hits = hits_by_filter[i].hits
		for h = 1, #hits do
			local hit = hits[h]
			local ok, id = pcall(Unit.id_string, hit.unit)
			if ok and id == TERMINAL_ID_STRING and hit.distance then
				if not best_distance or hit.distance < best_distance then
					best_distance, best = hit.distance, hit
				end
			end
		end
	end

	if not best then
		return false, "you are not looking at the terminal"
	end

	-- The impact point. probe reports hit.position as the unit ORIGIN, so this has to be
	-- reconstructed from the ray rather than read off the hit.
	local impact = ray_origin + forward * best_distance

	local ok_origin, origin = pcall(Unit.world_position, _anchor_unit, 1)
	if not ok_origin or not origin then return false, "lost the prop position" end

	local dx = Vector3.x(impact) - Vector3.x(origin)
	local dy = Vector3.y(impact) - Vector3.y(origin)
	local dz = Vector3.z(impact) - Vector3.z(origin)

	_mod:set(KEY_OFFSET_X, dx, false)
	_mod:set(KEY_OFFSET_Y, dy, false)
	_mod:set(KEY_OFFSET_Z, dz, false)
	_mod:set(KEY_OFFSET_SET, true, false)
	_remember_return_anchor(impact)

	-- Force it to disk now, same reasoning as the run state: nothing else is going to
	-- flush this before the next thing that could crash.
	local ok_dmf, dmf_mod = pcall(get_mod, "DMF")
	if ok_dmf and dmf_mod and dmf_mod.save_unsaved_settings_to_file then
		pcall(dmf_mod.save_unsaved_settings_to_file)
	end

	-- Re-locate so the new offset takes effect immediately rather than on the next scan.
	M.remove_marker()
	_anchor_position = Vector3Box and Vector3Box(Vector3(
		Vector3.x(origin) + dx, Vector3.y(origin) + dy, Vector3.z(origin) + dz)) or nil
	_stats.anchor_from = "manual_offset"

	return true, { dx = dx, dy = dy, dz = dz, distance = best_distance }
end

function M.clear_anchor_offset()
	if not _mod then return false end
	_mod:set(KEY_OFFSET_SET, false, false)
	_last_scan_t = -1e9
	_anchor_position = nil
	M.remove_marker()
	return true
end

-- ---------------------------------------------------------------------------
-- Marker lifecycle
--
-- The add is asynchronous in the sense that the id comes back through a callback, so
-- _marker_requested guards against firing a second add while the first is still in
-- flight. Without it, a couple of frames of latency would leave us with two markers and
-- only the id of one, and the orphan would sit in the world until the level unloaded.
-- ---------------------------------------------------------------------------

-- t is the caller's clock, used only for the request timeout. It is optional so the
-- tests and the debug command can call this without inventing one; without it the
-- request simply never times out, which is the old behaviour.
function M.add_marker(position, t)
	if _marker_id or _marker_requested then return false, "already present" end
	if not position then return false, "no position" end
	if not (Managers.event and Managers.event.trigger) then return false, "no event manager" end

	local raised = Vector3(Vector3.x(position), Vector3.y(position),
		Vector3.z(position) + MARKER_HEIGHT_OFFSET)

	_marker_requested = true
	_marker_request_t = t
	_stats.marker_requests = _stats.marker_requests + 1

	local ok, err = pcall(function()
		Managers.event:trigger("add_world_marker_position", "hub_objective", raised,
			function(id)
				_marker_id = id
				_marker_requested = false
				_marker_request_t = nil
				_stats.markers_added = _stats.markers_added + 1
			end,
			-- hub_objective reads its data with plain field reads and calls no methods
			-- on it, so a bare table is enough. ui_target_type "default" selects the
			-- point-of-interest icon and frame.
			{ ui_target_type = "default" })
	end)

	if not ok then
		_marker_requested = false
		_marker_request_t = nil
		_stats.last_error = tostring(err)
		return false, tostring(err)
	end

	return true
end

-- ---------------------------------------------------------------------------
-- The marker's landlord just changed, and our lease went with it.
--
-- This is the fix for the marker being missing on a fresh boot and only appearing
-- after a mission. The timeout above was built for the case where the add EVENT went
-- unanswered. The real failure was crueller: the add WAS answered. World markers live
-- inside HudElementWorldMarkers, in plain tables on the element instance
-- (hud_element_world_markers.lua:31), and the game builds that element more than once
-- while a level settles. Our add landed in an early instance, the callback delivered a
-- real id, and then the element was torn down and rebuilt, taking every stored marker
-- with it. We sat holding a valid-looking id for a marker that no longer existed,
-- refusing to add another. After a mission the timing happens to put our add after the
-- final rebuild, which is why it "worked" then, and only then.
--
-- So: Pilgrimage.lua hook_safes the element's init through the same fanout mechanism
-- every other class hook uses, and a new instance being born means every id we hold is
-- void. Drop them and let the tick re-add against the instance that is actually on
-- screen. The request flag drops too, because a callback owed by a dead element is
-- never coming.
-- ---------------------------------------------------------------------------

function M.on_marker_element_created()
	local had = _marker_id ~= nil or _marker_requested

	_marker_id = nil
	_marker_requested = false
	_marker_request_t = nil

	if had then
		_stats.marker_resets = _stats.marker_resets + 1

		_event_log.emit({
			t = _shared.fixed_time(),
			event = "marker_element_reset",
			id = _event_log.next_id(),
		})
	end
end

function M.install(HudElementWorldMarkers)
	if not HudElementWorldMarkers then return end
	if _hooks and _hooks.claim and _hooks.claim(HudElementWorldMarkers, "__pilgrimage_terminal_installed") then
		return
	end

	-- hook_safe: observe only. Nothing we do may interfere with the element that every
	-- nameplate and objective marker in the game depends on.
	_mod:hook_safe(HudElementWorldMarkers, "init", function()
		M.on_marker_element_created()
	end)
end

-- Returns true if a stuck request was cleared, so the caller may try again this tick.
function M.expire_marker_request(t)
	if not _marker_requested then return false end
	if not (_marker_request_t and t) then return false end
	if (t - _marker_request_t) < MARKER_REQUEST_TIMEOUT_S then return false end

	_marker_requested = false
	_marker_request_t = nil
	_stats.marker_timeouts = _stats.marker_timeouts + 1
	return true
end

function M.remove_marker()
	if not _marker_id then
		-- A request may still be in flight. Dropping the flag means the next add is
		-- allowed, and the callback for the in-flight one will set an id we then clear
		-- on the next teardown. Not perfect, but it cannot leak more than one.
		_marker_requested = false
		_marker_request_t = nil
		return false
	end

	pcall(function()
		Managers.event:trigger("remove_world_marker", _marker_id)
	end)

	_marker_id = nil
	_marker_requested = false
	_marker_request_t = nil
	_stats.markers_removed = _stats.markers_removed + 1
	return true
end

-- ---------------------------------------------------------------------------
-- Proximity and facing
-- ---------------------------------------------------------------------------

-- Vector3 values handed out by the engine come from a pool and are recycled, so holding
-- one across frames hands you someone else's coordinates later. Vector3Box copies the
-- numbers out. Everything stored is boxed, everything used is unboxed, and this is the
-- one place that knows the difference.
local function _unbox(value)
	if not value then return nil end
	if type(value) == "userdata" and Vector3Box then
		-- Already a raw Vector3. Boxes are tables with an unbox method.
		return value
	end
	if type(value) == "table" and value.unbox then return value:unbox() end
	return value
end

-- Returns distance, facing_dot. facing_dot is 1 when you are looking straight at the
-- terminal, 0 at ninety degrees, negative when it is behind you.
function M.player_relation(position)
	position = _unbox(position or _anchor_position)
	if not position then return nil, nil end

	local player_unit = _shared.local_player_unit()
	if not player_unit then return nil, nil end

	local ok, player_position = pcall(Unit.world_position, player_unit, 1)
	if not ok or not player_position then return nil, nil end

	local to_terminal = position - player_position
	local distance = Vector3.length(to_terminal)

	-- Facing is measured against the character's forward, not the camera's. In the
	-- Mourningstar the camera is third person and can orbit, so the character's facing
	-- is the better answer to "is the player addressing this thing".
	local ok_rot, rotation = pcall(Unit.local_rotation, player_unit, 1)
	if not ok_rot or not rotation then return distance, 1 end

	local forward = Quaternion.forward(rotation)

	-- Flatten to the horizontal plane. Otherwise standing right next to a prop that sits
	-- slightly above or below you tanks the dot product for no good reason.
	local flat = Vector3(Vector3.x(to_terminal), Vector3.y(to_terminal), 0)
	local flat_length = Vector3.length(flat)
	if flat_length < 0.01 then return distance, 1 end

	local dot = Vector3.dot(Vector3.normalize(flat),
		Vector3.normalize(Vector3(Vector3.x(forward), Vector3.y(forward), 0)))

	return distance, dot
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

-- True when something else owns the keyboard: a view is open, or the chat box has focus.
-- Pressing E to type a message in chat must never launch a pilgrimage.
--
-- NOTE THE ARGUMENTS. UIManager.using_input(ignore_hud, ignore_views, ignore_constant_elements)
-- checks all three by default, and in the Mourningstar the HUD and the constant elements
-- report "using input" during perfectly ordinary play. Calling it bare would block the
-- terminal permanently. We only care about views and chat, so the other two are ignored
-- explicitly rather than left to chance.
function M.input_is_claimed()
	local ui = Managers.ui
	if not ui then return false end

	if ui.chat_using_input then
		local ok, chatting = pcall(ui.chat_using_input, ui)
		if ok and chatting then return true end
	end

	if ui.using_input then
		local ok, claimed = pcall(ui.using_input, ui, true, false, true)
		if ok and claimed then return true end
	end

	return false
end

-- ---------------------------------------------------------------------------
-- Reading the interact key
--
-- WHY THE FIRST VERSION NEVER FIRED
--
-- "interact_pressed" is declared with type = "pressed"
-- (default_ingame_input_settings.lua:379), which means it is true for exactly ONE FRAME,
-- the frame the key goes down. The terminal tick runs four times a second. Sampling a
-- one-frame signal four times a second means missing it almost every time. The key was
-- being read correctly and the answer was almost always honestly false.
--
-- So the poll now runs at frame rate, in its own tiny task that early-outs on a boolean
-- unless the prompt is actually up. Everything expensive stays on the slow tick.
--
-- We read it off the PLAYER UNIT's input extension first, which is the same source
-- InteractorExtension uses (interactor_extension.lua:33, 291), so we see exactly what the
-- game's own interaction code would see, including the buffered handler. The input
-- service is the fallback for when there is no player unit yet.
-- ---------------------------------------------------------------------------

local function _pressed_via_extension()
	local player_unit = _shared.local_player_unit()
	if not player_unit then return nil end

	local extension = _shared.extension(player_unit, "input_system")
	if not extension or type(extension.get) ~= "function" then return nil end

	local ok, pressed = pcall(extension.get, extension, "interact_pressed")
	if not ok then return nil end
	return pressed == true
end

local function _pressed_via_service()
	local input = Managers.input
	if not input or not input.get_input_service then return false end

	local ok, service = pcall(input.get_input_service, input, "Ingame")
	if not ok or not service then return false end

	-- has() first. Asking an input service for an action it does not define is an error
	-- in some paths, and the action list differs between game states.
	if service.has then
		local ok_has, present = pcall(service.has, service, "interact_pressed")
		if not ok_has or not present then return false end
	end

	local ok_get, pressed = pcall(service.get, service, "interact_pressed")
	return ok_get and pressed == true
end

function M.interact_pressed()
	local via_extension = _pressed_via_extension()
	if via_extension ~= nil then return via_extension end
	return _pressed_via_service()
end

-- ---------------------------------------------------------------------------
-- The prompt, as the HUD element sees it
-- ---------------------------------------------------------------------------

function M.prompt_data()
	if not _prompt.visible then return nil end
	return _prompt
end

local function _set_prompt(visible, position, bottom_text)
	_prompt.visible = visible
	_prompt.world_position = position
	if bottom_text then _prompt.bottom_text = bottom_text end
end

-- "Press E" with whatever key is actually bound, including a controller glyph. Falls
-- back to naming the key plainly if the lookup fails, because a prompt that says
-- "Press <nil>" is worse than one that is slightly generic.
-- InputUtils is a MODULE, not a global. The first version did rawget(_G, "InputUtils"),
-- which is nil, so the glyph lookup silently never ran and the prompt showed no key at
-- all. hud_element_interaction.lua:5 is where the correct path comes from.
local _input_utils = nil

local function _get_input_utils()
	if _input_utils ~= nil then return _input_utils end

	local ok, module = pcall(function()
		return _mod:original_require("scripts/managers/input/input_utils")
	end)

	_input_utils = (ok and module) or false
	return _input_utils
end

function M.interact_hint()
	local InputUtils = _get_input_utils()

	if InputUtils and InputUtils.input_text_for_current_input_device then
		-- Asks for the alias, "interact", not the action. That is what resolves to the
		-- key the player actually has bound, or to a controller glyph on a pad.
		local ok, text = pcall(InputUtils.input_text_for_current_input_device,
			"Ingame", "interact")
		if ok and type(text) == "string" and text ~= "" then
			return text .. "  Open the pilgrimage terminal"
		end
	end

	return "Open the pilgrimage terminal"
end

-- ---------------------------------------------------------------------------
-- Opening
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- OPENING, and the crash that taught me to pre-flight it
-- ===========================================================================
--
-- UIViewHandler builds a view like this (ui_view_handler.lua:798-805):
--
--     active_views_data[view_name] = view_data      -- registered FIRST
--     local class = require(view_settings.path)
--     local instance = class:new(view_settings, context)
--     view_data.instance = instance                 -- filled in LAST
--
-- If require or the constructor throws, the view stays registered as active with a nil
-- instance, forever. On the very next frame _update_view_hotkeys calls
-- allow_close_hotkey_for_view, which does `view_instance:allow_close_hotkey()` with no
-- nil guard, and the game hard crashes.
--
-- The first version wrapped open_view in a bare pcall. That caught the real Lua error,
-- discarded the message, returned a tidy "false" to the caller, and left the game in
-- that poisoned state. A clean, diagnosable error became a crash with no explanation.
-- The actual fault was mundane: mod:add_require_path had never been called for the view
-- path, so require fell through to the engine, which has no such bundled file.
--
-- Two changes. Pre-flight the require ourselves, so a broken view is reported and NOT
-- opened rather than half-opened. And write the message to a file, because a swallowed
-- error is worse than no error handling at all.
-- ===========================================================================

local VIEW_NAME = "pilgrimage_route_view"
local VIEW_PATH = "Pilgrimage/scripts/mods/Pilgrimage/route_view"

M.VIEW_NAME = VIEW_NAME
M.VIEW_PATH = VIEW_PATH

-- Loads the view class exactly as UIViewHandler will. If this throws, the game would
-- have thrown at the same point, but with the crash consequences described above.
local function _preflight_view()
	local ok, result = pcall(require, VIEW_PATH)
	if not ok then return false, tostring(result) end
	if type(result) ~= "table" then
		return false, "view file returned " .. type(result) .. ", expected a class table"
	end
	return true
end

local function _record_open_failure(reason)
	_stats.last_error = tostring(reason)

	if _fileio then
		_fileio.write("terminal_error.txt", {
			"Pilgrimage: the route view failed to open",
			"",
			"when:   " .. _fileio.timestamp(),
			"view:   " .. VIEW_NAME,
			"path:   " .. VIEW_PATH,
			"reason: " .. tostring(reason),
			"",
			"The view was NOT handed to the game, so nothing is left half-registered.",
		})
	end

	_shared.notify("Pilgrimage: terminal failed to open, see terminal_error.txt", "alert")
end

function M.command_location_allowed()
	-- Solo Play can launch this same training mission under a different mode.
	-- Check its actual identity, not all training/tutorial game modes.
	return _shared.is_in_hub() or _shared.mission_name() == "tg_shooting_range"
end

function M.request_open()
	if not M.command_location_allowed() then
		return false, "the terminal can only be opened in the Mourningstar or Meat Grinder"
	end
	-- Command handlers run before the chat view has relinquished input.
	_command_open_deadline = _shared.fixed_time() + 5
	return true
end

function M.open()
	if M.input_is_claimed() then return false, "input claimed" end
	local api = _mod and _mod.pilgrimage_route_api
	if api and api.ensure_character and not api.ensure_character() then
		return false, "operative not available yet"
	end

	local ui = Managers.ui
	if not ui or not ui.open_view then return false, "no ui manager" end

	if ui.view_active then
		local ok, active = pcall(ui.view_active, ui, VIEW_NAME)
		if ok and active then return false, "already open" end
	end

	local loadable, load_error = _preflight_view()
	if not loadable then
		_record_open_failure(load_error)
		return false, load_error
	end

	local ok, err = pcall(ui.open_view, ui, VIEW_NAME)
	if not ok then
		_record_open_failure(err)
		return false, tostring(err)
	end

	_stats.opens = _stats.opens + 1

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "terminal_opened",
		id = _event_log.next_id(),
		found_by = _stats.found_by,
	})

	return true
end

-- ---------------------------------------------------------------------------
-- Teardown
--
-- Called on leaving the hub and on mission start. Everything here holds either a unit
-- handle or a marker id, and both are meaningless once the level changes, so keeping
-- any of it would be worse than useless: a stale unit handle passed to Unit.* is a hard
-- engine fault, not a Lua error we can catch.
-- ---------------------------------------------------------------------------

function M.teardown()
	_command_open_deadline = nil
	M.remove_marker()
	_marker_requested = false
	_marker_request_t = nil
	_anchor_unit = nil
	_anchor_position = nil
	_last_scan_t = -1e9
	_set_prompt(false, nil)
end

M.reset = M.teardown

-- ---------------------------------------------------------------------------
-- The tick
-- ---------------------------------------------------------------------------

function M.tick(t)
	local in_hub = _shared.is_in_hub()

	-- The launcher's prepared request is deliberately ineligible during the
	-- outbound transition. Promote it on the first confirmed in-mission tick,
	-- long before any return path can tear the session down.
	if not in_hub and _confirmed_active_pilgrimage_mission() then
		M.request_return(true)
	end

	if not _was_in_hub and in_hub then
		_hub_entered_t = t
	end

	-- Falling edge: we just left the hub.
	if _was_in_hub and not in_hub then
		M.teardown()
	end
	_was_in_hub = in_hub

	if not in_hub then return end

	local terminal_enabled = _settings.is_feature_enabled("terminal_prompt")
	if not terminal_enabled and not M.return_pending() then
		-- The setting is a full off switch, not just a prompt hider, so the marker goes
		-- too. Otherwise turning the feature off leaves an icon pointing at nothing.
		if _marker_id then M.remove_marker() end
		_set_prompt(false, nil)
		return
	end

	-- Find the prop. Throttled, because the scan is not cheap and the level is not
	-- necessarily populated the moment the hub state is entered.
	if not _anchor_position and (t - _last_scan_t) >= RESCAN_INTERVAL_S then
		_last_scan_t = t

		local unit, position, how = M.locate()
		if position then
			_anchor_unit = unit
			_anchor_position = Vector3Box and Vector3Box(position) or position
			_remember_return_anchor(position)

			_debug_log("terminal:found", t,
				"terminal anchor located by " .. tostring(how), 0, "info")

			_event_log.emit({
				t = t,
				event = "terminal_located",
				id = _event_log.next_id(),
				found_by = how,
				has_unit = unit ~= nil,
			})
		end
	end

	if not _anchor_position then return end

	local position = _unbox(_anchor_position)

	-- There is deliberately no delayed teleport. If the native return hook did
	-- not consume the request, expire it without moving an already-spawned player.
	if M.return_ready() and _hub_entered_t
		and t - _hub_entered_t >= RETURN_REQUEST_EXPIRY_S then
		_clear_return_pending()
		_debug_log("terminal:return", t,
			"native terminal spawn request expired without a second teleport", 0, "warn")
	end

	if not terminal_enabled then
		if _marker_id then M.remove_marker() end
		_set_prompt(false, nil)
		return
	end

	-- Clear a request the marker system never answered, then let the add below retry
	-- this same tick rather than waiting for the next one.
	M.expire_marker_request(t)

	if not _marker_id and not _marker_requested then
		M.add_marker(position, t)
	end

	local distance, facing = M.player_relation(position)
	if not distance then
		_set_prompt(false, nil)
		return
	end

	local range = _settings.terminal_prompt_distance()
	local visible = distance <= range and (facing or 1) >= MIN_FACING_DOT

	if visible then
		_set_prompt(true, position, M.interact_hint())
	else
		_set_prompt(false, nil)
	end
end

-- ---------------------------------------------------------------------------
-- The frame-rate half
--
-- This is the ONLY thing in the mod that runs every frame, and it exists because
-- "interact_pressed" is true for a single frame and cannot be caught by a 4Hz poll.
--
-- The cost when the prompt is down is one table lookup and one comparison, which is why
-- it is safe to have here at all. The key is only ever read when the prompt is already
-- up, so there is no way to trigger the terminal from across the room, with your back to
-- it, or while a menu owns the keyboard.
-- ---------------------------------------------------------------------------

function M.input_tick(t)
	if _command_open_deadline then
		if not M.command_location_allowed() or t > _command_open_deadline then
			_command_open_deadline = nil
		elseif not M.input_is_claimed() then
			_command_open_deadline = nil
			local ok, err = M.open()
			if not ok and err ~= "already open" then
				_shared.notify("Pilgrimage: could not open terminal, " .. tostring(err), "alert")
			end
			return
		end
	end
	if not _prompt.visible then return end
	if not M.interact_pressed() then return end
	if M.input_is_claimed() then return end

	local ok, err = M.open()
	if not ok then
		_debug_log("terminal:open_failed", t,
			"terminal open failed: " .. tostring(err), 2, "info")
	end
end

-- ---------------------------------------------------------------------------

function M.status()
	local position = _unbox(_anchor_position)

	local distance, facing = nil, nil
	if position then distance, facing = M.player_relation(position) end

	return {
		enabled        = _settings.is_feature_enabled("terminal_prompt"),
		in_hub         = _was_in_hub,
		found_by       = _stats.found_by,
		anchor_from    = _stats.anchor_from,
		has_unit       = _anchor_unit ~= nil,
		has_position   = position ~= nil,
		anchor_x       = position and Vector3.x(position) or nil,
		anchor_y       = position and Vector3.y(position) or nil,
		anchor_z       = position and Vector3.z(position) or nil,
		marker_id      = _marker_id,
		marker_pending = _marker_requested,
		scans          = _stats.scans,
		markers_added  = _stats.markers_added,
		markers_removed = _stats.markers_removed,
		marker_requests = _stats.marker_requests,
		marker_timeouts = _stats.marker_timeouts,
		marker_resets  = _stats.marker_resets,
		opens          = _stats.opens,
		prompt_visible = _prompt.visible,
		distance       = distance,
		facing_dot     = facing,
		range          = _settings.terminal_prompt_distance(),
		input_claimed  = M.input_is_claimed(),
		last_error     = _stats.last_error,
	}
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_run_state = deps.run_state
	_settings = deps.settings
	_event_log = deps.event_log
	_fileio = deps.fileio
	_probe = deps.probe
	_hooks = deps.hooks
	_debug_log = deps.debug_log or function() end

	-- The HUD element cannot receive injected dependencies, because DMF constructs it.
	-- So it reaches back through the mod object for exactly one function, and this is
	-- that function. Keeping it to a single read-only accessor keeps the coupling
	-- narrow and obvious.
	_mod.pilgrimage_terminal_prompt = M.prompt_data
	_install_native_return_hooks()
end

return M
