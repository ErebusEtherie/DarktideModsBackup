local mod = get_mod("strikemap")

-- ---------------------------------------------------------------------------
-- Expedition support: live-scanned, tile-composed floor plans.
--
-- Expeditions (mission "exp_wastes") have no fixed level to bake: every run
-- assembles a random layout of tile levels (256m "location" terrains, safe
-- zones, and small opportunity/traversal/airlock inserts) from a seed that the
-- server syncs to every client, which then spawns the exact same layout
-- locally (MechanismExpedition -> ExpeditionSpawner). Two facts make a map
-- possible anyway:
--
--  1. The client-side spawner records every spawned tile's level_name,
--     world position and rotation - so if we know a TILE's floor plan in
--     tile-local space, we can place it exactly for any run's layout.
--  2. Unlike normal missions (server-only navmesh), expedition clients bake
--     their own nav world at runtime (ExpeditionLogicBase.on_gameplay_init
--     runs BakeNavmesh on everyone), so GwNavQueries flood scanning - the
--     recorder's proven strategy - works for every player here.
--
-- So this module does three things per expedition section:
--   COMPOSE  known tiles: load maps/exp_tile_<key>.lua for each spawned tile
--            and inject its triangles, transformed into this run's layout.
--   SCAN     the rest live: flood-crawl the local nav world and paint
--            triangles into the map as they are discovered.
--   RECORD   scanned geometry per tile, in tile-local space, to
--            recorded_exp_tile_<key>.json - convert_maps.py bakes those into
--            maps/exp_tile_<key>.lua with no tool changes (the recorded_
--            prefix is already understood), so every scanned tile becomes
--            instantly available in all future runs, for scan-less clients
--            too once the baked files ship with the mod.
--
-- The produced map table is renderer-compatible with baked mission maps
-- (flat 7-number triangle array + 16m cell index), except the cell index is
-- born parsed in cell_cache (cells stays empty) and map.revision increments
-- as geometry grows so caches (fullmap bounds, cell fallback, compat
-- context) know to refresh. Section transitions (tiles despawning behind an
-- airlock) reset the map and restart the scan.
-- ---------------------------------------------------------------------------

local GRID_CELL = 16 -- metres; must match convert_maps.py GRID_CELL
local POLL_INTERVAL = 1.0 -- seconds between spawner layout polls
local REVISION_INTERVAL = 1.0 -- min seconds between map.revision bumps
local CELL = 1.0 -- metres; flood visited-grid resolution
local Z_CELL = 2.5 -- metres; separates stacked floors in the visited grid
local QUAD_HALF = 0.9 -- metres; half-size of stamped quads in point mode
local FLOOD_CALLS_PER_TICK = 4 -- each call temp-allocates <=150 Vector3s
local FLOOD_MAX_PER_CALL = 150
local FLOOD_ABOVE, FLOOD_BELOW = 3, 3
local DB_TRIS_PER_TICK = 400 -- db strategy: expedition nav is freshly baked
local RESEED_INTERVAL = 2.5 -- seconds between player-position island checks
local IDLE_FLUSH_TIME = 10 -- seconds with an empty frontier before dumping
local MAX_POSITIONS = 400000 -- runaway safety
local MIN_TILE_DUMP_TRIS = 24 -- don't dump tiles we barely touched
local ROWS_PER_JSON_TILE = 500
local DEFAULT_HALF_SIZE = 131 -- 256m locations + margin; also unsized tiles
local HALF_SIZE_MARGIN = 3 -- metres past the tile's nominal square
local OUT_DIR = "./../mods/strikemap/" -- cwd is binaries/, like the map loader

local function get_setting(id, default)
	local ok, value = pcall(function()
		return mod:get(id)
	end)

	if ok and value ~= nil then
		return value
	end

	return default
end

local function get_io()
	local mods = rawget(_G, "Mods")
	return (mods and mods.lua and mods.lua.io) or rawget(_G, "_io") or rawget(_G, "io")
end

local function say(msg)
	mod:echo(msg)
	pcall(function()
		mod:notify(msg)
	end)
end

-- ---------------------------------------------------------------------------
-- Engine access (every touch pcall-wrapped; nil on any failure)
-- ---------------------------------------------------------------------------
local function get_nav_world()
	local nav_mesh_manager = Managers and Managers.state and Managers.state.nav_mesh
	return nav_mesh_manager and nav_mesh_manager:nav_world()
end

local function player_position()
	local player = Managers.player and Managers.player:local_player(1)
	local unit = player and player.player_unit

	if unit and Unit.alive(unit) then
		return Unit.world_position(unit, 1)
	end

	return nil
end

-- The expedition mechanism (and only it) exposes levels_spawner(). Returns
-- nil in every other game mode, which is the module's entire activity gate.
local function get_levels_spawner()
	local ok, spawner = pcall(function()
		local mechanism = Managers.mechanism and Managers.mechanism:current_mechanism()

		if mechanism and mechanism.levels_spawner then
			return mechanism:levels_spawner()
		end

		return nil
	end)

	return ok and spawner or nil
end

-- Yaw from a tile's spawn rotation via the engine's own rotate (tiles sit on
-- flat slots, so the rotation is effectively yaw-only). Plain trig from here
-- on keeps the local<->world transform testable outside the engine.
local function quaternion_yaw(rotation)
	local ok, yaw = pcall(function()
		local f = Quaternion.rotate(rotation, Vector3(0, 1, 0))

		return math.atan2(f.x, f.y)
	end)

	return ok and yaw or 0
end

-- ---------------------------------------------------------------------------
-- Tile-local <-> world transforms (pure Lua; unit-tested offline)
-- ---------------------------------------------------------------------------
-- A tile spawned at (px, py, pz) with yaw r maps local (lx, ly, lz) to world
-- (px + lx*cos(r) - ly*sin(r), py + lx*sin(r) + ly*cos(r), pz + lz).

function mod.exp_local_to_world(tile, lx, ly, lz)
	local c, s = tile.cos, tile.sin

	return tile.px + lx * c - ly * s, tile.py + lx * s + ly * c, tile.pz + lz
end

function mod.exp_world_to_local(tile, wx, wy, wz)
	local c, s = tile.cos, tile.sin
	local dx, dy = wx - tile.px, wy - tile.py

	return dx * c + dy * s, -dx * s + dy * c, wz - tile.pz
end

-- Tile key: the level's own directory name. DSL tiles end in ".../world",
-- location/safe-zone missions in ".../missions/mission_<name>".
--   .../op_16m_stash_001/world                        -> op_16m_stash_001
--   .../missions/mission_location_256m_chasm_002      -> location_256m_chasm_002
function mod.exp_tile_key(level_name)
	if type(level_name) ~= "string" then
		return nil
	end

	local last, prev

	for segment in level_name:gmatch("[^/]+") do
		prev = last
		last = segment
	end

	local key = (last == "world" and prev) or last

	if not key then
		return nil
	end

	key = key:gsub("^mission_", ""):gsub("[^%w_%-]", "_")

	return key ~= "" and key or nil
end

-- Half-extent of the tile's footprint square from its size-coded name
-- ("op_32m_", "location_256m_"). Unsized names (safe zones) get the location
-- default; scanned-triangle ownership prefers the SMALLEST containing tile,
-- so an oversized guess only matters where no sized tile also contains it.
function mod.exp_tile_half_size(key)
	local size = key and tonumber(key:match("_(%d+)m_") or key:match("_(%d+)m$"))

	if size then
		return size * 0.5 + HALF_SIZE_MARGIN
	end

	return DEFAULT_HALF_SIZE
end

-- ---------------------------------------------------------------------------
-- Module state
-- ---------------------------------------------------------------------------
local EXP = {
	active = false,
	map = nil, -- renderer-compatible live map table
	tiles = {}, -- expedition_level_id -> tile record
	tile_order = {}, -- ids in insertion order (deterministic dumps/diag)
	poll_timer = 0,
	revision_timer = 0,
	injected = 0, -- tiles composed from baked files
	pending_known = 0, -- known tiles seen but their baked file failed to load
	announced = false,
	-- scanner
	phase = "idle", -- idle | db | flood | watch
	db_tile = 0,
	db_tile_count = 0,
	db_tile_tris = nil,
	db_tri_in_tile = 0,
	db_total = 0,
	visited = nil,
	seen_tris = nil,
	frontier = nil,
	frontier_head = 1,
	frontier_tail = 0,
	positions = 0,
	vertex_mode = nil,
	idle_time = 0,
	reseed_timer = 0,
	scanned = 0, -- triangles painted by the scanner (excludes injected)
	dumped = {}, -- tile key -> row count last considered for writing
}

local function new_live_map()
	return {
		mission = "exp_wastes",
		live = true,
		revision = 0,
		dirty = false,
		grid_cell = GRID_CELL,
		tri_count = 0,
		t = {},
		cells = {}, -- stays empty: the index below is born parsed
		cell_cache = {}, -- "gx:gy" -> array of triangle indices
	}
end

local function add_triangle(map, x1, y1, x2, y2, x3, y3, z)
	local t = map.t
	local n = map.tri_count * 7

	t[n + 1], t[n + 2] = x1, y1
	t[n + 3], t[n + 4] = x2, y2
	t[n + 5], t[n + 6] = x3, y3
	t[n + 7] = z
	map.tri_count = map.tri_count + 1

	local idx = map.tri_count
	local cell = map.grid_cell
	local cx0 = math.floor(math.min(x1, x2, x3) / cell)
	local cx1 = math.floor(math.max(x1, x2, x3) / cell)
	local cy0 = math.floor(math.min(y1, y2, y3) / cell)
	local cy1 = math.floor(math.max(y1, y2, y3) / cell)
	local cache = map.cell_cache

	for gx = cx0, cx1 do
		for gy = cy0, cy1 do
			local key = gx .. ":" .. gy
			local ids = cache[key]

			-- the renderer negative-caches misses as false; overwrite those
			if type(ids) ~= "table" then
				ids = {}
				cache[key] = ids
			end

			ids[#ids + 1] = idx
		end
	end

	map.dirty = true
end

-- ---------------------------------------------------------------------------
-- Tile bookkeeping
-- ---------------------------------------------------------------------------
local function make_tile(id, level_data)
	local ok, tile = pcall(function()
		local position = level_data.position and level_data.position:unbox()

		if not position then
			return nil
		end

		local rotation = level_data.rotation and level_data.rotation:unbox()
		local yaw = rotation and quaternion_yaw(rotation) or 0
		local key = mod.exp_tile_key(level_data.level_name)

		if not key then
			return nil
		end

		return {
			id = id,
			key = key,
			px = position.x,
			py = position.y,
			pz = position.z,
			cos = math.cos(yaw),
			sin = math.sin(yaw),
			half = mod.exp_tile_half_size(key),
			known = false, -- baked file injected
			rows = nil, -- packed tile-local rows pending dump
			row_count = 0,
		}
	end)

	return ok and tile or nil
end

-- Owning tile of a scanned point: the smallest spawned tile whose footprint
-- square (in its own rotated frame) contains it. Small inserts sit ON the big
-- location terrain, so smallest-wins carves their patch out of the location's
-- plan - which is exactly what makes the per-tile library recompose cleanly
-- under a different run's slot assignments.
local function owning_tile(x, y, z)
	local best, best_half

	for i = 1, #EXP.tile_order do
		local tile = EXP.tiles[EXP.tile_order[i]]

		if tile and (not best_half or tile.half < best_half) then
			local lx, ly, lz = mod.exp_world_to_local(tile, x, y, z)

			if lx >= -tile.half and lx <= tile.half
				and ly >= -tile.half and ly <= tile.half
				and lz >= -40 and lz <= 40 then
				best, best_half = tile, tile.half
			end
		end
	end

	return best
end

-- Inject a baked tile plan (tile-local space) into the live map at the
-- run's spawn transform. mod.load_map already parses maps/<id>.lua files.
local function inject_known_tile(tile)
	local parsed = mod.load_map and mod.load_map("exp_tile_" .. tile.key)

	if not parsed or not parsed.t or not parsed.tri_count then
		return false
	end

	local map = EXP.map
	local t = parsed.t

	for i = 0, parsed.tri_count - 1 do
		local o = i * 7
		local z = t[o + 7]
		local x1, y1 = mod.exp_local_to_world(tile, t[o + 1], t[o + 2], z)
		local x2, y2 = mod.exp_local_to_world(tile, t[o + 3], t[o + 4], z)
		local x3, y3 = mod.exp_local_to_world(tile, t[o + 5], t[o + 6], z)

		add_triangle(map, x1, y1, x2, y2, x3, y3, z + tile.pz)
	end

	tile.known = true
	EXP.injected = EXP.injected + 1

	return true
end

-- ---------------------------------------------------------------------------
-- Per-tile recording (tile-local rows -> recorded_exp_tile_<key>.json)
-- ---------------------------------------------------------------------------
local function bucket_triangle(tile, ax, ay, az, bx, by, bz, cx, cy, cz)
	local lax, lay, laz = mod.exp_world_to_local(tile, ax, ay, az)
	local lbx, lby, lbz = mod.exp_world_to_local(tile, bx, by, bz)
	local lcx, lcy, lcz = mod.exp_world_to_local(tile, cx, cy, cz)
	local rows = tile.rows

	if not rows then
		rows = {}
		tile.rows = rows
	end

	local n = tile.row_count + 1

	tile.row_count = n
	rows[n] = string.format("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f",
		lax, lay, laz, lbx, lby, lbz, lcx, lcy, lcz)
end

local function tile_out_path(key)
	return OUT_DIR .. "recorded_exp_tile_" .. key .. ".json"
end

-- Same "bigger file wins" upgrade rule as the mission recorder: a partial
-- scan can never clobber a fuller previous dump, and a later fuller crawl
-- passes the size check and upgrades the file.
local function write_tile_dump(tile)
	local io_lib = get_io()

	if not io_lib or not tile.rows or tile.row_count < MIN_TILE_DUMP_TRIS then
		return false
	end

	local chunks = {}

	for c0 = 1, tile.row_count, ROWS_PER_JSON_TILE do
		local rows = {}
		local count = 0

		for i = c0, math.min(c0 + ROWS_PER_JSON_TILE - 1, tile.row_count) do
			count = count + 1
			rows[count] = string.format('"%d":"%s"', count, tile.rows[i])
		end

		chunks[#chunks + 1] = string.format('"%d":{%s,"size":%d}',
			#chunks + 1, table.concat(rows, ","), count)
	end

	local body = '{"mission":"exp_tile_' .. tile.key .. '","tile_local":true,'
		.. table.concat(chunks, ",") .. "}"
	local path = tile_out_path(tile.key)
	local existing = io_lib.open(path, "r")

	if existing then
		local existing_size = existing:seek("end")

		existing:close()

		if existing_size and existing_size >= #body then
			return false
		end
	end

	local file = io_lib.open(path, "w")

	if not file then
		return false
	end

	file:write(body)
	file:close()

	return true
end

local function flush_tile_dumps(reason)
	local written = 0

	for i = 1, #EXP.tile_order do
		local tile = EXP.tiles[EXP.tile_order[i]]

		local last_rows = tile and (EXP.dumped[tile.key] or 0) or 0

		if tile and tile.rows and not tile.known and tile.row_count > last_rows then
			local ok, wrote = pcall(write_tile_dump, tile)

			if ok then
				-- Mark even when an existing, fuller file wins. A later crawl can
				-- still retry once this tile has accumulated additional rows.
				EXP.dumped[tile.key] = tile.row_count

				if wrote then
					written = written + 1
				end
			end
		end
	end

	if written > 0 then
		say(mod:localize("exp_tiles_recorded") .. " (" .. written .. " - " .. reason .. ")")
	end

	return written
end

-- ---------------------------------------------------------------------------
-- Scanner (flood + database strategies shared with the mission scanner; here
-- results paint the live map instead of accumulating a mission-wide dump)
-- ---------------------------------------------------------------------------
local function scan_cell_key(x, y, z)
	return math.floor(x / CELL) .. ":" .. math.floor(y / CELL) .. ":" .. math.floor(z / Z_CELL)
end

local function visit(x, y, z)
	local key = scan_cell_key(x, y, z)

	if EXP.visited[key] then
		return false
	end

	EXP.visited[key] = true
	EXP.positions = EXP.positions + 1
	EXP.frontier_tail = EXP.frontier_tail + 1
	EXP.frontier[EXP.frontier_tail] = { x, y, z }

	return true
end

local function looks_like_vertex(v, x, y, z)
	local ok, good = pcall(function()
		local dx, dy = v.x - x, v.y - y

		return type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number"
			and dx * dx + dy * dy < 2500 and math.abs(v.z - z) < 30
	end)

	return ok and good or false
end

-- One scanned world-space triangle: bucket it for the tile library and, when
-- its tile has no baked plan already drawn, paint it into the live map.
local function triangle_key(ax, ay, az, bx, by, bz, cx, cy, cz)
	local a = string.format("%.2f,%.2f,%.2f", ax, ay, az)
	local b = string.format("%.2f,%.2f,%.2f", bx, by, bz)
	local c = string.format("%.2f,%.2f,%.2f", cx, cy, cz)

	-- Triangle queries may rotate the same three vertices. Canonical ordering
	-- makes the database sweep and later flood reseeds share one de-dupe set.
	if a > b then a, b = b, a end
	if b > c then b, c = c, b end
	if a > b then a, b = b, a end

	return a .. "|" .. b .. "|" .. c
end

local function accept_triangle(ax, ay, az, bx, by, bz, cx, cy, cz)
	local mx = (ax + bx + cx) / 3
	local my = (ay + by + cy) / 3
	local mz = (az + bz + cz) / 3
	local tile = owning_tile(mx, my, mz)

	if tile and tile.known then
		-- plan already drawn from the baked file; nothing to record either
		return
	end

	local seen = EXP.seen_tris

	if not seen then
		seen = {}
		EXP.seen_tris = seen
	end

	local key = triangle_key(ax, ay, az, bx, by, bz, cx, cy, cz)

	if seen[key] then
		return
	end

	seen[key] = true

	if tile then
		bucket_triangle(tile, ax, ay, az, bx, by, bz, cx, cy, cz)
	end

	add_triangle(EXP.map, ax, ay, bx, by, cx, cy, mz)
	EXP.scanned = EXP.scanned + 1
end

local function emit_geometry_at(nav_world, x, y, z)
	if EXP.vertex_mode ~= false then
		local ok, altitude, va, vb, vc = pcall(GwNavQueries.triangle_from_position,
			nav_world, Vector3(x, y, z), FLOOD_ABOVE, FLOOD_BELOW)

		if ok and altitude
			and looks_like_vertex(va, x, y, z)
			and looks_like_vertex(vb, x, y, z)
			and looks_like_vertex(vc, x, y, z) then
			if EXP.vertex_mode == nil then
				EXP.vertex_mode = true
			end

			accept_triangle(va.x, va.y, va.z, vb.x, vb.y, vb.z, vc.x, vc.y, vc.z)

			return
		end

		if EXP.vertex_mode == nil and ok and altitude then
			EXP.vertex_mode = false
		end
	end

	if EXP.vertex_mode == false then
		local h = QUAD_HALF

		accept_triangle(x - h, y - h, z, x + h, y - h, z, x - h, y + h, z)
		accept_triangle(x + h, y - h, z, x + h, y + h, z, x - h, y + h, z)
	end
end

local _flood_out = {}

local function flood_step(nav_world, dt)
	for _ = 1, FLOOD_CALLS_PER_TICK do
		local head = EXP.frontier_head

		if head > EXP.frontier_tail then
			break
		end

		local pos = EXP.frontier[head]

		EXP.frontier[head] = nil
		EXP.frontier_head = head + 1

		local x, y, z = pos[1], pos[2], pos[3]

		emit_geometry_at(nav_world, x, y, z)

		if EXP.positions < MAX_POSITIONS then
			local out = _flood_out

			for i = 1, #out do
				out[i] = nil
			end

			local ok, count = pcall(GwNavQueries.flood_fill_from_position,
				nav_world, Vector3(x, y, z), FLOOD_ABOVE, FLOOD_BELOW, FLOOD_MAX_PER_CALL, out)

			if ok and count then
				for i = 1, count do
					local p = out[i]

					if p then
						visit(p.x, p.y, p.z)
					end
				end
			end
		end
	end

	if EXP.frontier_head <= EXP.frontier_tail then
		EXP.idle_time = 0
	else
		EXP.idle_time = EXP.idle_time + dt
	end

	return EXP.idle_time > IDLE_FLUSH_TIME
end

-- Expedition navmeshes are freshly baked by BakeNavmesh at runtime, so the
-- triangle database (empty for streamed mission navs) may actually be
-- populated here - a full sweep beats crawling when it works.
local function db_step(nav_world)
	local budget = DB_TRIS_PER_TICK

	while budget > 0 do
		if not EXP.db_tile_tris then
			EXP.db_tile = EXP.db_tile + 1

			if EXP.db_tile > EXP.db_tile_count then
				return true
			end

			EXP.db_tile_tris = GwNavWorld.database_tile_triangle_count(nav_world, EXP.db_tile) or 0
			EXP.db_tri_in_tile = 0
		end

		while EXP.db_tri_in_tile < EXP.db_tile_tris and budget > 0 do
			EXP.db_tri_in_tile = EXP.db_tri_in_tile + 1
			budget = budget - 1

			local a, b, c = GwNavWorld.database_triangle(nav_world, EXP.db_tile, EXP.db_tri_in_tile)

			if a and b and c then
				EXP.db_total = EXP.db_total + 1
				accept_triangle(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z)
			end
		end

		if EXP.db_tri_in_tile >= EXP.db_tile_tris then
			EXP.db_tile_tris = nil
		end
	end

	return false
end

local function reseed_from_player(dt)
	EXP.reseed_timer = EXP.reseed_timer - dt

	if EXP.reseed_timer > 0 then
		return
	end

	EXP.reseed_timer = RESEED_INTERVAL

	local ok, pos = pcall(player_position)

	if ok and pos and visit(pos.x, pos.y, pos.z) and EXP.phase == "watch" then
		EXP.phase = "flood"
		EXP.idle_time = 0
	end
end

local function start_scan()
	local nav_world = get_nav_world()
	local pos = nav_world and player_position()

	if not pos then
		return false
	end

	local ok, tile_count = pcall(GwNavWorld.database_tile_count, nav_world)

	EXP.phase = "db"
	EXP.db_tile = 0
	EXP.db_tile_count = ok and tile_count or 0
	EXP.db_tile_tris = nil
	EXP.db_tri_in_tile = 0
	EXP.db_total = 0
	EXP.visited = {}
	EXP.seen_tris = {}
	EXP.frontier = {}
	EXP.frontier_head = 1
	EXP.frontier_tail = 0
	EXP.positions = 0
	EXP.vertex_mode = nil
	EXP.idle_time = 0
	EXP.reseed_timer = 0
	EXP.scanned = 0

	visit(pos.x, pos.y, pos.z)

	return true
end

local function scan_step(dt)
	local nav_world = get_nav_world()

	if not nav_world then
		EXP.phase = "idle"

		return
	end

	if EXP.phase == "db" then
		if db_step(nav_world) then
			if EXP.db_total > 0 then
				flush_tile_dumps("database")

				EXP.phase = "watch" -- full sweep done; keep watching for islands
			else
				EXP.phase = "flood"
			end
		end
	elseif EXP.phase == "flood" then
		reseed_from_player(dt)

		if flood_step(nav_world, dt) then
			flush_tile_dumps("scan settled")

			EXP.phase = "watch"
		end
	elseif EXP.phase == "watch" then
		reseed_from_player(dt)
	end
end

-- ---------------------------------------------------------------------------
-- Layout polling / section transitions
-- ---------------------------------------------------------------------------
local function reset_section()
	flush_tile_dumps("section end")

	EXP.map = new_live_map()
	EXP.tiles = {}
	EXP.tile_order = {}
	EXP.injected = 0
	EXP.pending_known = 0
	EXP.phase = "idle"
	EXP.scanned = 0
end

local function poll_layout()
	local spawner = get_levels_spawner()

	if not spawner then
		return false
	end

	local ok, sections = pcall(function()
		return spawner:expedition()
	end)

	if not ok or type(sections) ~= "table" then
		return true -- expedition mode, layout not readable yet
	end

	-- Collect currently spawned tiles keyed by their stable layout id.
	local present = {}
	local removed = false

	for _, section in ipairs(sections) do
		local levels_data = section.levels_data

		if type(levels_data) == "table" then
			for _, level_data in ipairs(levels_data) do
				if level_data.spawned and level_data.expedition_level_id then
					present[level_data.expedition_level_id] = level_data
				end
			end
		end
	end

	for id in pairs(EXP.tiles) do
		if not present[id] then
			removed = true

			break
		end
	end

	-- Tiles despawned: the section behind the airlock is gone and its world
	-- space may be reused, so start the map over for the new section.
	if removed then
		reset_section()
	end

	local pending = 0

	for id, level_data in pairs(present) do
		local tile = EXP.tiles[id]

		if not tile then
			tile = make_tile(id, level_data)

			if tile then
				EXP.tiles[id] = tile
				EXP.tile_order[#EXP.tile_order + 1] = id
			end
		end

		if tile and not tile.known and not tile.inject_failed then
			local injected = pcall(inject_known_tile, tile)

			if not injected or not tile.known then
				-- no baked plan (or unreadable): the scanner covers this tile
				tile.inject_failed = true
				pending = pending + 1
			end
		end
	end

	EXP.pending_known = pending

	return true
end

-- ---------------------------------------------------------------------------
-- Public surface (consumed by strikemap.lua)
-- ---------------------------------------------------------------------------

-- Cheap gate for the recorder/notify paths: is this mission an expedition?
function mod.expedition_active()
	return EXP.active
end

-- Per-tick driver. Returns the live map table while in an expedition (the
-- same table across ticks, growing in place; a NEW table after a section
-- transition) and nil in every other game mode.
function mod.expedition_update(dt, mission_name)
	if get_setting("expedition_live_map", true) == false then
		if EXP.active then
			flush_tile_dumps("disabled")
			EXP.active = false
			EXP.map = nil
		end

		return nil
	end

	EXP.poll_timer = EXP.poll_timer - dt

	if not EXP.active then
		if EXP.poll_timer > 0 then
			return nil
		end

		EXP.poll_timer = POLL_INTERVAL

		if not get_levels_spawner() then
			return nil
		end

		EXP.active = true
		EXP.map = new_live_map()
		EXP.map.mission = mission_name or "exp_wastes"
		EXP.tiles = {}
		EXP.tile_order = {}
		EXP.injected = 0
		EXP.dumped = {}
		EXP.announced = false
	end

	if EXP.poll_timer <= 0 then
		EXP.poll_timer = POLL_INTERVAL
		pcall(poll_layout)

		if not EXP.announced and EXP.map.tri_count > 0 then
			EXP.announced = true

			if EXP.injected > 0 then
				say(mod:localize("exp_compose_ready") .. " (" .. EXP.injected .. ")")
			else
				say(mod:localize("exp_scan_started"))
			end
		end
	end

	if EXP.phase == "idle" then
		pcall(start_scan)
	else
		local ok, err = pcall(scan_step, dt)

		if not ok then
			EXP.phase = "watch" -- keep the composed map; stop the crawler
			mod:info("Expedition scan error: " .. tostring(err))
		end
	end

	-- Throttled revision bumps let renderer/compat caches refresh at most
	-- once a second while geometry streams in.
	EXP.revision_timer = EXP.revision_timer - dt

	if EXP.map.dirty and EXP.revision_timer <= 0 then
		EXP.revision_timer = REVISION_INTERVAL
		EXP.map.dirty = false
		EXP.map.revision = EXP.map.revision + 1
	end

	return EXP.map
end

-- Mission teardown (strikemap.lua reset_state): dump what we learned first.
function mod.expedition_reset()
	if EXP.active then
		pcall(flush_tile_dumps, "mission end")
	end

	EXP.active = false
	EXP.map = nil
	EXP.tiles = {}
	EXP.tile_order = {}
	EXP.injected = 0
	EXP.pending_known = 0
	EXP.phase = "idle"
	EXP.poll_timer = 0
	EXP.revision_timer = 0
	EXP.scanned = 0
	EXP.dumped = {}
	EXP.announced = false
end

function mod.expedition_diag_lines(add)
	if not EXP.active then
		add("expedition: inactive")

		return
	end

	add("expedition: phase " .. EXP.phase
		.. "  tiles " .. #EXP.tile_order
		.. " (known " .. EXP.injected .. ", unscanned " .. EXP.pending_known .. ")"
		.. "  tris " .. (EXP.map and EXP.map.tri_count or 0)
		.. " (scanned " .. EXP.scanned .. ")"
		.. "  positions " .. EXP.positions
		.. "  frontier " .. math.max(0, EXP.frontier_tail - EXP.frontier_head + 1))

	for i = 1, #EXP.tile_order do
		local tile = EXP.tiles[EXP.tile_order[i]]

		if tile then
			add("  tile " .. tile.key
				.. (tile.known and " [baked]" or (" [" .. tile.row_count .. " rows]"))
				.. string.format("  @ %.0f,%.0f,%.0f", tile.px, tile.py, tile.pz))
		end
	end
end

-- Test hook: the offline harness drives transforms/bucketing without engine
-- globals via this table.
function mod.expedition_test_state()
	return EXP, {
		new_live_map = new_live_map,
		add_triangle = add_triangle,
		accept_triangle = accept_triangle,
		owning_tile = owning_tile,
		write_tile_dump = write_tile_dump,
		make_tile = make_tile,
	}
end
