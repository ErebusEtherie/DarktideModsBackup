-- probe.lua
--
-- A world inspector, used to pick where the terminal lives.
--
-- Swagger anchors its prompt to a hard-coded world coordinate plus a "fingerprint"
-- of the target unit (bone names and mesh/actor counts) so it can find that unit
-- again reliably. To do the same thing we first need the coordinate and a fingerprint,
-- and the only way to get those is to stand in the game and ask.
--
-- Workflow:
--   1. Stand exactly where you want the terminal, facing the way it should face.
--   2. /pil_here
--   3. Send me dump/pilgrimage_probe.txt
--
-- Output goes to a plain text file rather than the JSONL event log, because this
-- needs to work even when cjson is unavailable, and because a human is going to
-- read it.
--
-- Everything here is wrapped in pcall and rawget. The probe touches more engine
-- surface than the rest of the mod combined, and half of it is API we have not
-- verified on this game build, so it is written to report what works rather than
-- to assume.

local M = {}

local _mod
local _shared

local MAX_UNITS_REPORTED = 40
local DEFAULT_RADIUS = 12

-- ---------------------------------------------------------------------------
-- Small safe wrappers
-- ---------------------------------------------------------------------------

local function safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c
end

-- Vector3 is userdata in the engine, so .x is a property access that can throw if
-- the value is not actually a vector. pcall each component separately.
local function xyz(v)
	if not v then return nil end
	local ok_x, x = pcall(function() return v.x end)
	local ok_y, y = pcall(function() return v.y end)
	local ok_z, z = pcall(function() return v.z end)
	if not (ok_x and ok_y and ok_z) then return nil end
	if type(x) ~= "number" then return nil end
	return x, y, z
end

local function fmt_vec(v)
	local x, y, z = xyz(v)
	if not x then return "nil" end
	return string.format("%.4f, %.4f, %.4f", x, y, z)
end

local function distance_sq(a, b)
	local ax, ay, az = xyz(a)
	local bx, by, bz = xyz(b)
	if not ax or not bx then return nil end
	local dx, dy, dz = ax - bx, ay - by, az - bz
	return dx * dx + dy * dy + dz * dz
end

-- ---------------------------------------------------------------------------
-- Unit identification
--
-- We do not know for certain which of these exist on this build, so we try all of
-- them and report whichever answer. That doubles as an API survey.
-- ---------------------------------------------------------------------------

local UNIT_NAME_CANDIDATES = {
	"id_string", "debug_name", "resource_name", "name",
}

local FINGERPRINT_NODES = {
	"j_head", "j_hips", "j_spine", "root_point", "rp_center", "g_terminal",
}

local function unit_identity(Unit, unit)
	local out = {}

	for i = 1, #UNIT_NAME_CANDIDATES do
		local key = UNIT_NAME_CANDIDATES[i]
		local value = safe(Unit[key], unit)
		if value ~= nil and value ~= "" then
			out[#out + 1] = key .. "=" .. tostring(value)
		end
	end

	local actors = safe(Unit.num_actors, unit)
	local meshes = safe(Unit.num_meshes, unit)
	if actors then out[#out + 1] = "actors=" .. tostring(actors) end
	if meshes then out[#out + 1] = "meshes=" .. tostring(meshes) end

	local nodes = {}
	for i = 1, #FINGERPRINT_NODES do
		local node = FINGERPRINT_NODES[i]
		if safe(Unit.has_node, unit, node) == true then
			nodes[#nodes + 1] = node
		end
	end
	if #nodes > 0 then out[#out + 1] = "nodes={" .. table.concat(nodes, ",") .. "}" end

	return table.concat(out, "  ")
end

-- ---------------------------------------------------------------------------
-- Player pose
--
-- Position comes from the locomotion component on unit_data_system, not from
-- Unit.world_position, because the component is the network-authoritative value and
-- is what everything else in the game agrees on.
-- ---------------------------------------------------------------------------

local function component_position(unit, component_name)
	local extension = _shared.extension(unit, "unit_data_system")
	if not extension or not extension.read_component then return nil end
	local component = safe(extension.read_component, extension, component_name)
	return component and component.position or nil
end

function M.player_pose()
	local Unit = rawget(_G, "Unit")
	local Quaternion = rawget(_G, "Quaternion")

	local unit = _shared.local_player_unit()
	if not unit then return nil, "no local player unit" end

	local position = component_position(unit, "locomotion")
		or component_position(unit, "first_person")
		or safe(Unit and Unit.world_position, unit, 1)

	if not position then return nil, "could not read player position" end

	local rotation = safe(Unit and Unit.local_rotation, unit, 1)
	local forward = rotation and Quaternion and safe(Quaternion.forward, rotation) or nil

	return {
		unit = unit,
		position = position,
		rotation = rotation,
		forward = forward,
	}
end

-- ---------------------------------------------------------------------------
-- Look-at raycast
--
-- Proximity alone cannot tell us WHICH prop is the terminal, only what is nearby.
-- This casts a ray the way the game's own interaction system does and reports
-- exactly what is under the crosshair.
--
-- Copied from InteractorExtension._find_object_in_direct_line_of_sight
-- (scripts/extension_systems/interaction/interactor_extension.lua:443-446) on
-- decompiled 1.12.3, so the filter and the hit layout are the game's, not a guess:
--
--   local hits = PhysicsWorld.raycast(physics_world, fp_position, fp_forward,
--                    max_distance, "all", "collision_filter", "filter_interactable_overlap")
--   hit[2] = distance, hit[4] = actor        (INDEX_DISTANCE = 2, INDEX_ACTOR = 4)
--   local hit_unit, hit_node = Actor.unit(collision_actor)
--
-- We cast three filters, because the interactable filter only sees things the game
-- considers interactable and our terminal prop may not be one of those:
--   filter_interactable_overlap        what the game would let you interact with
--   filter_look_at_object_ray          the engine's generic "what am I looking at"
--   filter_player_character_shooting_raycast_statics   static geometry, catches props
-- ---------------------------------------------------------------------------

local RAY_FILTERS = {
	"filter_interactable_overlap",
	"filter_look_at_object_ray",
	"filter_player_character_shooting_raycast_statics",
}

local INDEX_DISTANCE = 2
local INDEX_ACTOR = 4

-- The game raycasts from the FIRST PERSON position and forward, not from the player
-- unit's origin. Camera position is the closest equivalent we can reach from a mod.
function M.look_origin()
	local player = _shared.local_player()
	if not player then return nil, nil, "no local player" end

	local viewport_name = player.viewport_name
	if not viewport_name then return nil, nil, "player has no viewport_name" end

	local camera_manager = Managers and Managers.state and Managers.state.camera
	if not camera_manager then return nil, nil, "no camera manager" end

	local position = safe(camera_manager.camera_position, camera_manager, viewport_name)
	local rotation = safe(camera_manager.camera_rotation, camera_manager, viewport_name)
	if not position or not rotation then return nil, nil, "camera position/rotation unavailable" end

	local Quaternion = rawget(_G, "Quaternion")
	local forward = Quaternion and safe(Quaternion.forward, rotation)
	if not forward then return nil, nil, "Quaternion.forward unavailable" end

	return position, forward
end

function M.look_at(max_distance)
	max_distance = tonumber(max_distance) or 8

	local PhysicsWorld = rawget(_G, "PhysicsWorld")
	local World = rawget(_G, "World")
	local Actor = rawget(_G, "Actor")
	local Unit = rawget(_G, "Unit")
	if not (PhysicsWorld and World and Actor and Unit) then
		return nil, "physics globals unavailable"
	end

	local origin, forward, err = M.look_origin()
	if not origin then return nil, err end

	local world = Managers and Managers.world
		and safe(Managers.world.world, Managers.world, "level_world")
	if not world then return nil, "no level_world" end

	local physics_world = safe(World.get_data, world, "physics_world")
	if not physics_world then return nil, "no physics_world" end

	local results = {}

	for i = 1, #RAY_FILTERS do
		local filter = RAY_FILTERS[i]
		local hits = safe(PhysicsWorld.raycast, physics_world, origin, forward,
			max_distance, "all", "collision_filter", filter)

		local entry = { filter = filter, hits = {} }

		if type(hits) == "table" then
			for h = 1, #hits do
				local hit = hits[h]
				local actor = hit[INDEX_ACTOR]
				local unit, node = actor and Actor.unit(actor)
				if unit then
					entry.hits[#entry.hits + 1] = {
						unit = unit,
						node = node,
						distance = hit[INDEX_DISTANCE],
						position = safe(Unit.world_position, unit, 1),
						-- The game skips units flagged this way when deciding what
						-- you are pointing at.
						ignored = safe(Unit.get_data, unit, "ignored_by_interaction_raycast"),
					}
				end
			end
		end

		results[#results + 1] = entry
	end

	return results, nil, origin, forward
end

-- ---------------------------------------------------------------------------
-- Nearby level units
-- ---------------------------------------------------------------------------

function M.nearby_units(origin, radius)
	radius = radius or DEFAULT_RADIUS
	local radius_sq = radius * radius

	local World = rawget(_G, "World")
	local Level = rawget(_G, "Level")
	local Unit = rawget(_G, "Unit")
	if not (World and Level and Unit) then return {}, "engine globals unavailable" end

	local world = Managers and Managers.world and safe(Managers.world.world, Managers.world, "level_world")
	if not world then return {}, "no level_world" end

	local levels = safe(World.levels, world)
	if type(levels) ~= "table" then return {}, "World.levels returned nothing" end

	local found = {}
	local level_names = {}

	for i = 1, #levels do
		local level = levels[i]
		local level_name = safe(Level.name, level) or "?"
		level_names[#level_names + 1] = tostring(level_name)

		-- The second argument asks for all units, including ones not currently
		-- spawned in. That is what Swagger uses to find its NPC.
		local units = safe(Level.units, level, true)
		if type(units) == "table" then
			for u = 1, #units do
				local unit = units[u]
				if safe(Unit.alive, unit) ~= false then
					local position = safe(Unit.world_position, unit, 1)
					local d2 = position and distance_sq(origin, position)
					if d2 and d2 <= radius_sq then
						found[#found + 1] = {
							unit = unit,
							level = tostring(level_name),
							position = position,
							distance = math.sqrt(d2),
						}
					end
				end
			end
		end
	end

	table.sort(found, function(a, b) return a.distance < b.distance end)
	return found, nil, level_names
end

-- ---------------------------------------------------------------------------
-- File output
-- ---------------------------------------------------------------------------

-- File writing lives in fileio.lua and is driven by debug.lua. This module only
-- builds the report.

-- ---------------------------------------------------------------------------
-- The command body
-- ---------------------------------------------------------------------------

function M.here(radius)
	radius = tonumber(radius) or DEFAULT_RADIUS

	local lines = {}
	local function add(text) lines[#lines + 1] = text end

	local Unit = rawget(_G, "Unit")

	add("Pilgrimage placement probe")
	add("mod version: " .. tostring(_mod.version))
	add("game mode:   " .. tostring(_shared.game_mode_name()))
	add("solo host:   " .. tostring(_shared.is_solo_host()))
	add("radius:      " .. tostring(radius))
	add("")

	local pose, pose_err = M.player_pose()
	if not pose then
		add("PLAYER POSE UNAVAILABLE: " .. tostring(pose_err))
	else
		local x, y, z = xyz(pose.position)
		add("PLAYER POSE")
		add("  position: " .. fmt_vec(pose.position))
		add("  forward:  " .. fmt_vec(pose.forward))
		add("")
		add("  paste-ready:")
		if x then
			add(string.format("  local TERMINAL_POSITION = { x = %.4f, y = %.4f, z = %.4f }", x, y, z))
		end
		add("")
	end

	-- What is under the crosshair. This is the question proximity cannot answer.
	add("=== LOOKING AT ===")
	local hits_by_filter, look_err, origin, forward = M.look_at(12)
	if not hits_by_filter then
		add("  unavailable: " .. tostring(look_err))
	else
		add("  camera origin:  " .. fmt_vec(origin))
		add("  camera forward: " .. fmt_vec(forward))
		local any = false
		for i = 1, #hits_by_filter do
			local entry = hits_by_filter[i]
			add("")
			add("  [" .. entry.filter .. "] " .. #entry.hits .. " hit(s)")
			for h = 1, math.min(#entry.hits, 8) do
				local hit = entry.hits[h]
				any = true
				add(string.format("    %5.2fm  node=%s%s  %s",
					hit.distance or -1,
					tostring(hit.node),
					hit.ignored and "  IGNORED_BY_INTERACTION" or "",
					fmt_vec(hit.position)))
				add("           " .. (unit_identity(Unit, hit.unit) or "no identity"))
				-- If the prop carries the game's marker node we can hang the prompt
				-- there instead of guessing a height offset.
				if safe(Unit.has_node, hit.unit, "ui_interaction_marker") == true then
					add("           HAS ui_interaction_marker NODE (use this for the prompt anchor)")
				end
			end
		end
		if not any then
			add("")
			add("  Nothing hit. Stand closer, or aim directly at the prop.")
		end
	end
	add("")

	local units, units_err, level_names = M.nearby_units(pose and pose.position, radius)

	if level_names then
		add("LEVELS: " .. table.concat(level_names, ", "))
		add("")
	end

	if units_err then
		add("NEARBY UNITS UNAVAILABLE: " .. tostring(units_err))
	else
		add(string.format("NEARBY UNITS (%d found, showing up to %d)", #units, MAX_UNITS_REPORTED))
		local shown = math.min(#units, MAX_UNITS_REPORTED)
		for i = 1, shown do
			local entry = units[i]
			add(string.format("  [%2d] %5.2fm  %s", i, entry.distance, fmt_vec(entry.position)))
			add("       " .. (unit_identity(Unit, entry.unit) or "no identity"))
		end
	end

	add("")
	add("API SURVEY (which Unit functions exist on this build)")
	for i = 1, #UNIT_NAME_CANDIDATES do
		local key = UNIT_NAME_CANDIDATES[i]
		add(string.format("  Unit.%-14s %s", key,
			type(Unit and Unit[key]) == "function" and "present" or "MISSING"))
	end
	for _, key in ipairs({ "num_actors", "num_meshes", "has_node", "node",
	                       "world_position", "local_rotation", "alive" }) do
		add(string.format("  Unit.%-14s %s", key,
			type(Unit and Unit[key]) == "function" and "present" or "MISSING"))
	end

	-- On-screen confirmation of the one number the player might want to see
	-- immediately. The caller writes the file.
	if pose then
		_shared.notify("Pilgrimage: " .. fmt_vec(pose.position))
	end

	return lines
end

-- Exposed so debug.lua can format its own report without duplicating the helpers.
M.fmt_vec = fmt_vec

function M.identity(unit)
	local Unit = rawget(_G, "Unit")
	if not Unit then return "no Unit global" end
	return unit_identity(Unit, unit) or "no identity"
end

function M.has_node(unit, node_name)
	local Unit = rawget(_G, "Unit")
	if not Unit or not Unit.has_node then return nil end
	return safe(Unit.has_node, unit, node_name)
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
end

return M
