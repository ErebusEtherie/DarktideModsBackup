local mod = get_mod("strikemap")

-- ---------------------------------------------------------------------------
-- HUD element registration (same pattern as NumericUI / DMF docs).
-- ---------------------------------------------------------------------------
local ELEMENT_PATH = "strikemap/scripts/mods/strikemap/strikemap_element"
mod:add_require_path(ELEMENT_PATH)


-- Expedition support (live-scanned, tile-composed floor plans for the
-- procedurally assembled expedition game mode).
mod:io_dofile("strikemap/scripts/mods/strikemap/strikemap_expedition")

-- Mission reports (records + persists runs for post-game review).
mod:io_dofile("strikemap/scripts/mods/strikemap/strikemap_reports")

-- Report browser is a proper cursor-driven UIView (registered via DMF), so it
-- gets a real mouse cursor, blocks player movement, and closes on the hotkey.
-- Wrapped in pcall so a UI-load hiccup can never abort the whole mod script.
local REPORT_VIEW_PATH = "strikemap/scripts/mods/strikemap/strikemap_report_view"
mod:add_require_path(REPORT_VIEW_PATH)

pcall(function()
	mod:io_dofile(REPORT_VIEW_PATH)

	if type(mod.register_view) == "function" then
		mod:register_view({
			view_name = "strikemap_report_view",
			view_settings = {
				init_view_function = function(ingame_ui_context)
					return true
				end,
				class = "StrikemapReportView",
				disable_game_world = false,
				game_world_blur = 1.1,
				load_always = true,
				load_in_hub = true,
				package = "packages/ui/views/options_view/options_view",
				path = REPORT_VIEW_PATH,
				state_bound = true,
				display_name = "report_view_title",
			},
			view_transitions = {},
			view_options = { close_all = false, close_previous = false },
		})
	end
end)

local _element_registered = false

if type(mod.register_hud_element) == "function" then
	_element_registered = mod:register_hud_element({
		class_name = "StrikemapElement",
		filename = ELEMENT_PATH,
		use_hud_scale = true,
		visibility_groups = {
			"alive",
			"dead",
		},
	}) == true
end

-- ---------------------------------------------------------------------------
-- Shared state, read by the HUD element via mod.strikemap_state().
-- Everything here is collected from CLIENT-SAFE sources only (no server-only
-- pacing / spawn-point systems): pre-baked map geometry, player units, the
-- game's own live world markers, interactee extensions, and the enemy
-- broadphase (the same source enemies_improved health bars use on clients).
-- ---------------------------------------------------------------------------
local _state = {
	active = false, -- in mission gameplay (panel shows even without map data)
	visible = true,
	geometry_only = false, -- external renderer owns the live HUD; geometry/recording stay active
	mission = nil,
	map = nil, -- parsed map table or nil when this mission has no data
	zoom_mult = 1,
	fullmap = false, -- full-screen overview open?
	fullmap_zoom = 1,
	fullmap_pitch_idx = 2, -- 1 top-down, 2 tactical, 3 low orbit
	objectives = {}, -- array of {x, y, z}
	objective_lines = {}, -- array of {text, progress, side, order} for the panel strip
	objective_events = {}, -- transient area scans: {x,y,z,label,changed_at}
	gates = {}, -- live doors/path blockers: {x,y,z,dx,dy,half,blocked,locked,event,changed_at}
	mission_time = 0,
	pings = {}, -- active player smart tags: {x, y, z, unit, rgb, fade, kind}
	medicae = {}, -- array of {x, y, z, unit, charges}
	supplies = {}, -- openable loot containers: {x, y, z, unit}
	books = {}, -- grimoire/scripture pickups: {x, y, z, unit}
	ammo = {}, -- loose ammo tins/bags: {x, y, z, unit, kind}
	grenades = {}, -- loose grenade pickups: {x, y, z, unit, kind}
	ammo_crates = {}, -- pocketable/deployed ammo crates: {x, y, z, unit, kind}
	med_crates = {}, -- pocketable/deployed medical crates: {x, y, z, unit, kind}
	stimms = {}, -- stimms: {x, y, z, unit, kind}
	materials = {}, -- crafting/other small pickups (opt-in): {x, y, z, unit, kind}
	sight_mode = "team_los",
	sight_observers = {}, -- {x, y, z, fx, fy} for the visible-area cones
	-- enemy positions by category, arrays of {x, y, z, enemy_type}
	enemies = {
		horde = {},
		elite = {},
		special = {},
		monster = {},
	},
}

local MAPS_DIR = "./../mods/strikemap/maps/"
local DIAG_PATH = "./../mods/strikemap/strikemap_diag.txt"
local MAP_LOAD_ATTEMPTS = 3
local ENEMY_TICK = 0.15
local ENEMY_QUERY_RANGE = 90
local PING_POSITION_TTL = 12
local PING_UNIT_TTL = 45
local PING_FADE_TIME = 0.45
local GATE_SCAN_TICK = 0.25
local GATE_EVENT_TTL = 4.5
local OBJECTIVE_EVENT_TTL = 5.5
local SIGHT_RANGE = ENEMY_QUERY_RANGE
local SIGHT_RAY_BUDGET = 120 -- occlusion rays allowed per sight refresh
local SIGHT_CONE_COS = math.cos(62 * math.pi / 180)
local SIGHT_CLOSE_RANGE = 2.5
local SIGHT_EYE_HEIGHT = 1.45
local SIGHT_TARGET_HEIGHT = 1.1
local SIGHT_RAY_TARGET_PADDING = 0.65

-- (LoS raycasts use the single proven PhysicsWorld.raycast form; see
-- raycast_blocked. SIGHT_RAY_TARGET_PADDING is no longer needed because the
-- occlusion check inspects the hit actor instead of shortening the ray.)

local AUTO_DEBRIEF_DELAY = 1.6 -- seconds after the end screen before the debrief pops

local _load_attempts = 0
local _objective_timer = 0
local _gate_timer = 0
local _medicae_timer = 0
local _refresh_timer = 0
local _enemy_timer = 0
local _sight_refresh_due = false
local _markers_live = false -- was the marker pipeline running last update?
local _notified_no_map = false
local _diag_timer = 0
local _diag_written = false
local _mission_time = 0
local _end_screen_seen = false
local _auto_debrief_at = nil
local _auto_debrief_done = false
local _broadphase_results = {}
local _dialogue_restore = {}
local _pings_by_key = {}
local _ping_stats = { seen = 0, unit = 0, position = 0, missed = 0 }
local _los_raycast_candidate = nil
local _los_raycast_disabled = false
local _gate_history = { door = {}, blocker = {} }
local _objective_marker_history = {}
local _objective_name_history = {}
local _objective_marker_snapshot_ready = false
local _objective_name_snapshot_ready = false

local DIALOGUE_POPUP_NAMES = {
	hudelementmissionspeaker = true,
	hudelementmissionspeakerpopup = true,
	hudelementdialogue = true,
	hudelementdialoguepopup = true,
	hudelementdialoguespeaker = true,
	hudelementtransmission = true,
	hudelementtransmissionpopup = true,
	hudelementspeaker = true,
	mission_speaker = true,
	mission_speaker_popup = true,
	dialogue_popup = true,
	transmission_popup = true,
}

local DIALOGUE_POPUP_PATTERNS = {
	"mission_speaker",
	"speaker",
	"dialogue",
	"transmission",
}

local DIALOGUE_POPUP_EXCLUDE_PATTERNS = {
	"chat",
	"combat",
	"communication_wheel",
	"objective",
	"world_marker",
	"worldmarker",
}

local NIL_VALUE = {}
local _ui_settings = NIL_VALUE
local _pickup_settings = NIL_VALUE

local ENEMY_TYPE_SETTING_KEYS = {
	"chaos_poxwalker",
	"chaos_newly_infected",
	"chaos_lesser_mutated_poxwalker",
	"chaos_mutated_poxwalker",
	"chaos_armored_infected",
	"renegade_melee",
	"renegade_assault",
	"renegade_rifleman",
	"cultist_melee",
	"cultist_assault",
	"cultist_rifleman",
	"renegade_executor",
	"chaos_ogryn_executor",
	"chaos_ogryn_bulwark",
	"chaos_ogryn_gunner",
	"renegade_berzerker",
	"cultist_berzerker",
	"renegade_gunner",
	"cultist_gunner",
	"renegade_shocktrooper",
	"cultist_shocktrooper",
	"renegade_plasma_gunner",
	"renegade_flamer",
	"cultist_flamer",
	"renegade_netgunner",
	"renegade_grenadier",
	"cultist_grenadier",
	"renegade_sniper",
	"cultist_mutant",
	"chaos_hound",
	"chaos_armored_hound",
	"chaos_ogryn_houndmaster",
	"chaos_poxwalker_bomber",
	"chaos_plague_ogryn",
	"chaos_spawn",
	"chaos_beast_of_nurgle",
	"chaos_daemonhost",
	"renegade_captain",
	"cultist_captain",
	"renegade_twin_captain",
	"cultist_twin_captain",
	"renegade_radio_operator",
	"cultist_ritualist",
}

local function safe(fn)
	local ok, result = pcall(fn)
	if ok then
		return result
	end
	return nil
end

local function pack_results(...)
	return select("#", ...), { ... }
end

local function get_setting(id, default)
	local ok, value = pcall(mod.get, mod, id)

	if ok and value ~= nil then
		return value
	end

	return default
end

-- ---------------------------------------------------------------------------
-- Settings snapshot: per-frame paths (panel_shown, popup suppression, the
-- enemy tick, the attack hook) read these plain fields instead of walking the
-- settings store. Refreshed on any setting change and at mission start.
-- On-by-default checkboxes use `~= false` so a nil (unset) value reads as ON.
-- ---------------------------------------------------------------------------
local _settings_cache = {
	enable_minimap = true,
	show_when_no_map = true,
	map_corner = "top_right",
	integrate_objectives = true,
	record_reports = true,
	combat_tracking = true,
	enemy_tick = ENEMY_TICK,
	scan_range = ENEMY_QUERY_RANGE,
	horde_los = "cone",
}

local function refresh_settings_snapshot()
	local cache = _settings_cache

	cache.enable_minimap = get_setting("enable_minimap", true) ~= false
	cache.show_when_no_map = get_setting("show_when_no_map", true) ~= false
	cache.map_corner = get_setting("map_corner", "top_right")
	cache.integrate_objectives = get_setting("integrate_objectives", true) ~= false
	cache.record_reports = get_setting("record_reports", true) ~= false
	cache.combat_tracking = get_setting("perf_combat_tracking", true) ~= false
	cache.enemy_tick = (tonumber(get_setting("perf_enemy_tick", 150)) or 150) / 1000
	cache.scan_range = tonumber(get_setting("perf_enemy_scan_range", ENEMY_QUERY_RANGE)) or ENEMY_QUERY_RANGE
	cache.horde_los = get_setting("perf_horde_los", "cone")
end

refresh_settings_snapshot()

-- DMF fires this on every widget change; chain any handler a sibling file may
-- have installed rather than clobbering it.
local _chained_on_setting_changed = mod.on_setting_changed

function mod.on_setting_changed(...)
	if _chained_on_setting_changed then
		pcall(_chained_on_setting_changed, ...)
	end

	refresh_settings_snapshot()
end

-- Safety net: anything that writes a setting without going through DMF's
-- callback (keybind toggles, other mods, the offline harness) would otherwise
-- leave the snapshot stale forever. Two reads a second costs nothing.
local _snapshot_timer = 0

local function tick_settings_snapshot(dt)
	_snapshot_timer = _snapshot_timer - (dt or 0)

	if _snapshot_timer <= 0 then
		_snapshot_timer = 0.5
		refresh_settings_snapshot()
	end
end

local function sight_range()
	return _settings_cache.scan_range or SIGHT_RANGE
end

local function ui_settings()
	if _ui_settings == NIL_VALUE then
		_ui_settings = safe(function()
			return require("scripts/settings/ui/ui_settings")
		end) or false
	end

	return _ui_settings ~= false and _ui_settings or nil
end

local function pickup_settings()
	if _pickup_settings == NIL_VALUE then
		_pickup_settings = safe(function()
			return require("scripts/settings/pickup/pickups")
		end) or false
	end

	return _pickup_settings ~= false and _pickup_settings or nil
end

local function read_unit_alive(unit)
	return Unit.alive(unit) == true
end

local function unit_alive(unit)
	if unit == nil then
		return false
	end

	local ok, alive = pcall(read_unit_alive, unit)

	return ok and alive == true
end

local function read_unit_position(unit)
	if not Unit.alive(unit) then
		return nil
	end

	return Unit.world_position(unit, 1)
end

local function unit_position(unit)
	if unit == nil then
		return nil
	end

	local ok, pos = pcall(read_unit_position, unit)

	if ok then
		return pos
	end

	return nil
end

local function read_unit_data(unit, key)
	if Unit.has_data and not Unit.has_data(unit, key) then
		return nil
	end

	return Unit.get_data and Unit.get_data(unit, key) or nil
end

local function unit_get_data(unit, key)
	if not unit then
		return nil
	end

	local ok, value = pcall(read_unit_data, unit, key)

	if ok then
		return value
	end

	return nil
end

-- Direct (unguarded) form for callers already running under a pcall.
local function extension_interaction_type_raw(ext)
	if not ext then
		return nil
	end

	local interaction_type = ext._active_interaction_type

	if not interaction_type or interaction_type == "none" then
		interaction_type = ext.interaction_type and ext:interaction_type() or nil
	end

	return interaction_type ~= "none" and interaction_type or nil
end

local function extension_interaction_type(ext)
	local ok, interaction_type = pcall(extension_interaction_type_raw, ext)

	if ok then
		return interaction_type
	end

	return nil
end

local function read_interactee_extension(unit)
	return ScriptUnit.has_extension(unit, "interactee_system")
		and ScriptUnit.extension(unit, "interactee_system")
end

local function unit_interaction_type(unit)
	local ok, ext = pcall(read_interactee_extension, unit)

	if not ok then
		return nil
	end

	return extension_interaction_type(ext)
end

local function classify_pickup_type(pickup_type)
	if type(pickup_type) ~= "string" then
		return nil
	end

	local settings = pickup_settings()
	local pickup = settings and settings.by_name and settings.by_name[pickup_type] or nil

	if pickup and pickup.is_side_mission_pickup then
		return "book"
	end

	if pickup_type == "small_clip" or pickup_type == "large_clip" then
		return "ammo"
	elseif pickup_type == "small_grenade" then
		return "grenade"
	elseif pickup_type == "ammo_cache_pocketable" or pickup_type == "ammo_cache_deployable" then
		return "ammo_crate"
	elseif pickup_type == "medical_crate_pocketable" or pickup_type == "medical_crate_deployable" then
		return "med_crate"
	elseif pickup_type == "syringe_ability_boost_pocketable" then
		return "stimm_ability"
	elseif pickup_type == "syringe_corruption_pocketable" then
		return "stimm_corruption"
	elseif pickup_type == "syringe_power_boost_pocketable" then
		return "stimm_power"
	elseif pickup_type == "syringe_speed_boost_pocketable" then
		return "stimm_speed"
	elseif pickup_type == "syringe_broker_pocketable" then
		return "stimm_broker"
	elseif pickup_type:find("luggable", 1, true) then
		return "luggable"
	elseif pickup_type:find("metal", 1, true) or pickup_type:find("platinum", 1, true) then
		return "material"
	end

	return nil
end

local function ping_kind_from_unit(unit)
	if not unit_alive(unit) then
		return nil
	end

	local has_health_station = safe(function()
		local ext = ScriptUnit.has_extension(unit, "health_station_system")

		return ext ~= nil and ext ~= false
	end)

	if has_health_station then
		return "medicae"
	end

	local interaction_type = unit_interaction_type(unit)

	if interaction_type == "health_station" then
		return "medicae"
	elseif interaction_type == "ammunition" then
		return "ammo"
	elseif interaction_type == "grenade" then
		return "grenade"
	elseif interaction_type == "side_mission" then
		return "book"
	end

	local pickup_kind = classify_pickup_type(unit_get_data(unit, "pickup_type"))

	if pickup_kind then
		return pickup_kind
	end

	local target_type = unit_get_data(unit, "smart_tag_target_type")

	if target_type == "pickup" then
		return "pickup"
	end

	return nil
end

local function read_position_xyz(pos)
	return pos.x, pos.y, pos.z
end

local function copy_position(pos)
	if pos == nil then
		return nil
	end

	-- Fast path: one pcall on a named reader covers engine Vector3s and plain
	-- {x, y, z} tables without allocating a single closure.
	local fast_ok, fx, fy, fz = pcall(read_position_xyz, pos)

	if fast_ok and type(fx) == "number" and type(fy) == "number" then
		return { x = fx, y = fy, z = tonumber(fz) or 0 }
	end

	local unbox_fn = safe(function()
		return pos.unbox
	end)

	if type(unbox_fn) == "function" then
		local unboxed = safe(function()
			return pos:unbox()
		end)

		if unboxed then
			pos = unboxed
		end
	end

	local x = safe(function()
		return pos.x
	end)
	local y = safe(function()
		return pos.y
	end)
	local z = safe(function()
		return pos.z
	end)

	if type(pos) == "table" then
		x = x or pos[1]
		y = y or pos[2]
		z = z or pos[3]
	end

	x, y, z = tonumber(x), tonumber(y), tonumber(z) or 0

	if x and y then
		return { x = x, y = y, z = z }
	end

	return nil
end

local function marker_visibility_mode()
	local mode = get_setting("marker_visibility_mode", "team_los")

	if mode == "self_los" or mode == "team_los" or mode == "all" then
		return mode
	end

	return "team_los"
end

local function read_world_forward(unit)
	local rot = Unit.world_rotation and Unit.world_rotation(unit, 1)
	return rot and Quaternion and Quaternion.forward and Quaternion.forward(rot) or nil
end

local function read_local_forward(unit)
	local rot = Unit.local_rotation and Unit.local_rotation(unit, 1)
	return rot and Quaternion and Quaternion.forward and Quaternion.forward(rot) or nil
end

local function unit_forward_xy(unit)
	local ok, fwd = pcall(read_world_forward, unit)

	if not ok or not fwd then
		ok, fwd = pcall(read_local_forward, unit)
	end

	local fx, fy

	if ok and fwd then
		local read_ok, x, y = pcall(read_position_xyz, fwd)

		if read_ok then
			fx, fy = tonumber(x), tonumber(y)
		end
	end

	if not fx or not fy then
		return 0, 1
	end

	local len_sq = fx * fx + fy * fy

	if len_sq <= 0.0001 then
		return 0, 1
	end

	local len = math.sqrt(len_sq)
	return fx / len, fy / len
end

local function write_sight_observer(out, index, unit, is_local)
	local pos = copy_position(unit_position(unit))

	if not pos then
		return index
	end

	local fx, fy

	if is_local and type(mod._camera_forward_x) == "number" and type(mod._camera_forward_y) == "number" then
		fx, fy = mod._camera_forward_x, mod._camera_forward_y
	else
		fx, fy = unit_forward_xy(unit)
	end

	local entry = out[index + 1] or {}

	entry.x, entry.y, entry.z = pos.x, pos.y, pos.z
	entry.fx, entry.fy = fx, fy
	entry.is_local = is_local == true
	out[index + 1] = entry

	return index + 1
end

local function collect_sight_observers(mode)
	local observers = _state.sight_observers
	local count = 0

	if mode == "all" then
		for i = 1, #observers do
			observers[i] = nil
		end

		return observers, 0
	end

	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(1)
	local player_unit = player and player.player_unit

	if player_unit and unit_alive(player_unit) then
		count = write_sight_observer(observers, count, player_unit, true)
	end

	if mode == "team_los" and player_manager and player_manager.players then
		local players = safe(function()
			return player_manager:players()
		end)

		if type(players) == "table" then
			for _, other in pairs(players) do
				if other ~= player then
					local unit = other and other.player_unit

					if unit and unit_alive(unit) then
						count = write_sight_observer(observers, count, unit, false)
					end
				end
			end
		end
	end

	for i = count + 1, #observers do
		observers[i] = nil
	end

	return observers, count
end

local function level_physics_world()
	local world = safe(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	return safe(function()
		local physics = Managers.state and Managers.state.physics
		return physics and physics.physics_world and physics:physics_world() or nil
	end) or safe(function()
		return world and World.get_data and World.get_data(world, "physics_world") or nil
	end) or safe(function()
		return world and World.physics_world and World.physics_world(world) or nil
	end)
end

-- Occlusion check via the ONE raycast form proven to work in-game on clients
-- (enemies_improved's outline check uses it verbatim): filter that collides
-- with level statics AND minion bodies, then inspect WHAT was hit - a hit on
-- the target itself means visible. Guessed alternates are worse than none: a
-- call that "succeeds" but never hits anything reads as X-ray vision.
local function raycast_blocked(physics_world, ox, oy, oz, tx, ty, tz, target_unit)
	if _los_raycast_disabled or not physics_world then
		return nil
	end

	-- Existence checks only: in-game Vector3 is a TABLE with a __call
	-- metamethod, not a function - a type()=="function" guard silently skipped
	-- every raycast (LoS modes degraded to cone-only "wallhack"). The pcall
	-- below catches anything genuinely uncallable.
	local vector3 = rawget(_G, "Vector3")
	local physics = rawget(_G, "PhysicsWorld")
	local raycast = physics and physics.raycast

	if vector3 == nil or raycast == nil then
		_los_raycast_disabled = true
		mod._los_error = vector3 == nil and "Vector3 missing" or "PhysicsWorld.raycast missing"

		return nil
	end

	local dx, dy, dz = tx - ox, ty - oy, tz - oz
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

	if distance <= 0.01 then
		return false
	end

	local ok, r1, r2, r3, r4, r5 = pcall(raycast, physics_world, vector3(ox, oy, oz),
		vector3(dx / distance, dy / distance, dz / distance), distance,
		"closest", "collision_filter", "filter_minion_line_of_sight_check")

	if not ok then
		_los_raycast_disabled = true
		mod._los_error = tostring(r1)

		return nil
	end

	_los_raycast_candidate = "filter_minion_line_of_sight_check"

	if not r1 then
		return false -- clear line all the way to the target
	end

	-- The filter collides with minion bodies, so a ray that reaches the target
	-- itself means VISIBLE. Darktide's binding (proven via enemies_improved)
	-- returns one table {position, distance, normal, actor}; classic Stingray
	-- returns multiple values, boolean-first or position-first. Accept all
	-- three shapes rather than bet the feature on one.
	local actor

	if type(r1) == "table" then
		actor = r1[4]
	elseif r1 == true then
		actor = r5 -- hit, position, distance, normal, actor
	else
		actor = r4 -- position, distance, normal, actor
	end

	if actor and target_unit then
		local actor_api = rawget(_G, "Actor")
		local unit_of = actor_api and actor_api.unit

		if unit_of then
			local hit_ok, hit_unit = pcall(unit_of, actor)

			if hit_ok and hit_unit == target_unit then
				return false -- the first thing the ray touched IS the target
			end
		end
	end

	return true
end

-- Occlusion rays are the most expensive thing the mod does, and they all land
-- on the same frame. _ray_budget bounds one refresh; lists resume from where
-- the previous refresh ran out (_sight_cursor) so nothing starves, and entries
-- that miss out simply keep the visibility they already had.
local _ray_budget = 0
local _sight_cursor = setmetatable({}, { __mode = "k" })

local function target_visible_to_observer(target, observer, physics_world, skip_raycast)
	if not target or not observer or type(target.x) ~= "number" or type(target.y) ~= "number" then
		return true
	end

	local dx, dy = target.x - observer.x, target.y - observer.y
	local dist_sq = dx * dx + dy * dy
	local close_sq = SIGHT_CLOSE_RANGE * SIGHT_CLOSE_RANGE
	local range = sight_range()
	local range_sq = range * range

	if dist_sq > range_sq then
		return false
	end

	if dist_sq > close_sq then
		local dist = math.sqrt(dist_sq)
		local dot = (dx * observer.fx + dy * observer.fy) / dist

		if dot < SIGHT_CONE_COS then
			return false
		end
	end

	-- Cone + range only: horde dots on the cheap setting, and anything left
	-- after the ray budget is spent.
	if skip_raycast or _ray_budget <= 0 then
		return true
	end

	_ray_budget = _ray_budget - 1

	local target_z = (target.z or observer.z or 0) + SIGHT_TARGET_HEIGHT
	local blocked = raycast_blocked(
		physics_world,
		observer.x,
		observer.y,
		(observer.z or 0) + SIGHT_EYE_HEIGHT,
		target.x,
		target.y,
		target_z,
		target.unit
	)

	return blocked ~= true
end

local function target_visible_to_observers(target, observers, observer_count, physics_world, skip_raycast)
	if observer_count <= 0 then
		return true
	end

	for i = 1, observer_count do
		if target_visible_to_observer(target, observers[i], physics_world, skip_raycast) then
			return true
		end
	end

	return false
end

local function apply_sight_visibility(list, observers, observer_count, physics_world, visible, skip_raycast)
	if type(list) ~= "table" then
		return
	end

	local count = #list

	if count == 0 then
		return
	end

	if visible ~= nil then
		for i = 1, count do
			local entry = list[i]

			if type(entry) == "table" then
				entry.visible_by_sight = visible
			end
		end

		return
	end

	local start = _sight_cursor[list] or 0

	if start >= count then
		start = 0
	end

	for n = 1, count do
		local i = (start + n - 1) % count + 1
		local entry = list[i]

		if type(entry) == "table" then
			entry.visible_by_sight =
				target_visible_to_observers(entry, observers, observer_count, physics_world, skip_raycast)
		end

		if not skip_raycast and _ray_budget <= 0 then
			-- Out of rays: resume here next refresh rather than always
			-- re-checking the head of the list.
			_sight_cursor[list] = i
			return
		end
	end

	_sight_cursor[list] = 0
end

local function refresh_sight_visibility()
	local mode = marker_visibility_mode()
	_state.sight_mode = mode
	_ray_budget = SIGHT_RAY_BUDGET

	local observers, observer_count = collect_sight_observers(mode)
	local physics_world = mode ~= "all" and level_physics_world() or nil
	local forced_visible = mode == "all" and true or nil

	apply_sight_visibility(_state.objectives, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.pings, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.medicae, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.supplies, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.books, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.ammo, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.grenades, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.ammo_crates, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.med_crates, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.stimms, observers, observer_count, physics_world, forced_visible)
	apply_sight_visibility(_state.materials, observers, observer_count, physics_world, forced_visible)

	-- Horde dots are the bulk of every wave; per-dot occlusion is precision
	-- nobody reads off a 280 px panel, so the cheap setting skips their rays.
	local horde_cone_only = _settings_cache.horde_los ~= "raycast"

	for kind, list in pairs(_state.enemies) do
		apply_sight_visibility(
			list,
			observers,
			observer_count,
			physics_world,
			forced_visible,
			horde_cone_only and kind == "horde" or nil
		)
	end
end

local POSITION_FIELDS = {
	"_target_position",
	"target_position",
	"_world_position",
	"world_position",
	"_position",
	"position",
	"_location",
	"location",
	"_target_location",
	"target_location",
	"_hit_position",
	"hit_position",
}

local POSITION_METHODS = {
	"target_position",
	"world_position",
	"position",
}

local function position_from_fields(source)
	if source == nil then
		return nil
	end

	if type(source) == "table" then
		for i = 1, #POSITION_FIELDS do
			local pos = copy_position(rawget(source, POSITION_FIELDS[i]))

			if pos then
				return pos
			end
		end
	end

	for i = 1, #POSITION_METHODS do
		local method = safe(function()
			return source[POSITION_METHODS[i]]
		end)

		if type(method) == "function" then
			local pos = copy_position(safe(function()
				return method(source)
			end))

			if pos then
				return pos
			end
		end
	end

	return nil
end

local function position_from_args(...)
	local n = select("#", ...)

	for i = 1, n do
		local arg = select(i, ...)
		local pos = copy_position(arg) or position_from_fields(arg)

		if pos then
			return pos
		end
	end

	return nil
end

local function player_from_unit(unit)
	if not unit then
		return nil
	end

	local players = safe(function()
		return Managers.player and Managers.player:players()
	end)

	if type(players) == "table" then
		for _, player in pairs(players) do
			if player and player.player_unit == unit then
				return player
			end
		end
	end

	return nil
end

local function rgb_from_tagger_unit(tagger_unit)
	local player = player_from_unit(tagger_unit)
	local settings = ui_settings()
	local slot_colors = settings and settings.player_slot_colors
	local slot = player and player.slot and safe(function()
		return player:slot()
	end)
	local slot_color = slot_colors and slot and slot_colors[slot]

	if type(slot_color) == "table" and #slot_color >= 4 then
		return { slot_color[2], slot_color[3], slot_color[4] }
	end

	return { 110, 214, 235 }
end

local function clear_ping_keys(entry)
	if type(entry) ~= "table" or type(entry.keys) ~= "table" then
		return
	end

	for i = 1, #entry.keys do
		local key = entry.keys[i]

		if _pings_by_key[key] == entry then
			_pings_by_key[key] = nil
		end
	end

	entry.keys = {}
end

local function remember_ping_key(entry, key)
	if key == nil then
		return
	end

	_pings_by_key[key] = entry
	entry.keys = entry.keys or {}
	entry.keys[#entry.keys + 1] = key
end

local function release_ping_entry(entry)
	if entry and not entry.removed_at then
		entry.removed_at = _mission_time
		entry.fade = 1
	end
end

local function raw_field(source, field)
	if type(source) == "table" then
		return rawget(source, field)
	end

	return nil
end

local function track_smart_tag_ping(smart_tag, tag_id, template, tagger_unit, target_unit, ...)
	-- Geometry-only mode has no live Strikemap HUD to consume pings. Avoid
	-- accumulating unit references while an external renderer owns the map.
	if _state.geometry_only then
		return
	end

	tagger_unit = tagger_unit or raw_field(smart_tag, "_tagger_unit") or raw_field(smart_tag, "tagger_unit")
	target_unit = target_unit or raw_field(smart_tag, "_target_unit") or raw_field(smart_tag, "target_unit")

	local unit = unit_alive(target_unit) and target_unit or nil
	local pos = unit and unit_position(unit)
		or position_from_fields(smart_tag)
		or position_from_args(template, tagger_unit, target_unit, ...)

	if not pos then
		_ping_stats.missed = _ping_stats.missed + 1
		return
	end

	local key = tag_id or smart_tag or (#_state.pings + 1)
	local entry = _pings_by_key[key]
	local is_new = entry == nil

	entry = entry or {}

	clear_ping_keys(entry)

	entry.x, entry.y, entry.z = pos.x, pos.y, pos.z
	entry.unit = unit
	entry.kind = unit and ping_kind_from_unit(unit) or nil
	entry.rgb = rgb_from_tagger_unit(tagger_unit)
	entry.started_at = _mission_time
	entry.removed_at = nil
	entry.fade = 1
	entry.expires_at = _mission_time + (unit and PING_UNIT_TTL or PING_POSITION_TTL)
	entry.tag_id = tag_id

	if is_new then
		_state.pings[#_state.pings + 1] = entry
	end

	remember_ping_key(entry, key)
	remember_ping_key(entry, smart_tag)
	remember_ping_key(entry, tag_id)
	remember_ping_key(entry, raw_field(smart_tag, "_tag_id"))
	remember_ping_key(entry, raw_field(smart_tag, "tag_id"))

	_ping_stats.seen = _ping_stats.seen + 1

	if unit then
		_ping_stats.unit = _ping_stats.unit + 1
	else
		_ping_stats.position = _ping_stats.position + 1
	end
end

local function release_smart_tag_ping(smart_tag, tag_id)
	local entry = _pings_by_key[smart_tag]
		or _pings_by_key[tag_id]
		or _pings_by_key[raw_field(smart_tag, "_tag_id")]
		or _pings_by_key[raw_field(smart_tag, "tag_id")]

	release_ping_entry(entry)
end

local function refresh_pings()
	local now = _mission_time
	local kept = 0

	for i = 1, #_state.pings do
		local entry = _state.pings[i]

		if entry.unit then
			local pos = unit_position(entry.unit)

			if pos then
				entry.x, entry.y, entry.z = pos.x, pos.y, pos.z
				entry.kind = ping_kind_from_unit(entry.unit) or entry.kind
			else
				entry.unit = nil
				release_ping_entry(entry)
			end
		end

		if not entry.removed_at and entry.expires_at and now > entry.expires_at then
			release_ping_entry(entry)
		end

		if entry.removed_at then
			entry.fade = math.max(0, 1 - (now - entry.removed_at) / PING_FADE_TIME)
		else
			entry.fade = 1
		end

		if entry.fade > 0 then
			kept = kept + 1
			_state.pings[kept] = entry
		else
			clear_ping_keys(entry)
		end
	end

	for i = kept + 1, #_state.pings do
		_state.pings[i] = nil
	end
end

local function migrate_enemy_theme_defaults()
	if type(mod.get) ~= "function" or type(mod.set) ~= "function" or mod:get("_enemy_theme_defaults_v2") == true then
		return
	end

	mod:set("enemy_type_overrides", false, false)
	mod:set("special_icon", nil, false)
	mod:set("elite_icon", nil, false)

	for i = 1, #ENEMY_TYPE_SETTING_KEYS do
		local prefix = "enemy_type_" .. ENEMY_TYPE_SETTING_KEYS[i]

		mod:set(prefix .. "_icon", nil, false)
		mod:set(prefix .. "_color", nil, false)
		mod:set(prefix .. "_scale", nil, false)
	end

	mod:set("_enemy_theme_defaults_v2", true, false)
end

safe(migrate_enemy_theme_defaults)

local function panel_shown()
	return _state.active and _state.visible ~= false
		and _state.geometry_only ~= true
		and get_setting("enable_minimap", true) ~= false
		and (_state.map ~= nil or get_setting("show_when_no_map", true) ~= false)
end

local function should_suppress_dialogue_popup()
	-- Popups live along the top of the screen; only a top-anchored map covers them.
	local corner = get_setting("map_corner", "top_right")

	return panel_shown() and (corner == "top_right" or corner == "top_center")
end

-- The vanilla objective feed is hidden while the panel draws its own themed
-- objective strip (integrate_objectives).
local function should_suppress_objective_feed()
	return panel_shown() and get_setting("integrate_objectives", true) ~= false
end

-- Memoized: this runs against every HUD element name several times per frame,
-- and the name set is small and fixed â€” never pay the lower/gsub twice.
local _dialogue_name_matches = {}

local function dialogue_popup_name_matches(name)
	if type(name) ~= "string" then
		return false
	end

	local cached = _dialogue_name_matches[name]

	if cached ~= nil then
		return cached
	end

	local key = name:lower():gsub("[%s%-]+", "_")
	local matched = DIALOGUE_POPUP_NAMES[key] == true

	if not matched then
		matched = true

		for i = 1, #DIALOGUE_POPUP_EXCLUDE_PATTERNS do
			if key:find(DIALOGUE_POPUP_EXCLUDE_PATTERNS[i], 1, true) then
				matched = false
				break
			end
		end

		if matched then
			matched = false

			for i = 1, #DIALOGUE_POPUP_PATTERNS do
				if key:find(DIALOGUE_POPUP_PATTERNS[i], 1, true) then
					matched = true
					break
				end
			end
		end
	end

	_dialogue_name_matches[name] = matched

	return matched
end

local function remember_field(target, field)
	if type(target) ~= "table" then
		return nil
	end

	local rec = _dialogue_restore[target]

	if not rec then
		rec = {}
		_dialogue_restore[target] = rec
	end

	if rec[field] == nil then
		local value = target[field]
		rec[field] = value == nil and NIL_VALUE or value
	end

	return rec
end

local function hide_widget(widget)
	if type(widget) ~= "table" then
		return
	end

	if type(widget.style) ~= "table" and type(widget.content) ~= "table" and widget.visible == nil then
		return
	end

	remember_field(widget, "visible")
	widget.visible = false

	if widget.dirty ~= nil then
		widget.dirty = true
	end
end

local function hide_widget_table(widgets)
	if type(widgets) ~= "table" then
		return
	end

	for _, widget in pairs(widgets) do
		hide_widget(widget)
	end
end

local function hide_dialogue_element(element)
	if type(element) ~= "table" then
		return
	end

	hide_widget_table(rawget(element, "_widgets_by_name"))
	hide_widget_table(rawget(element, "_widgets"))
	hide_widget_table(rawget(element, "_widget_array"))

	mod._dialogue_popup_suppressed = true
end

local function restore_dialogue_popup()
	for target, rec in pairs(_dialogue_restore) do
		if type(target) == "table" and type(rec) == "table" then
			for field, value in pairs(rec) do
				target[field] = value == NIL_VALUE and nil or value
			end
		end
	end

	_dialogue_restore = {}
	mod._dialogue_popup_suppressed = false
end

-- Which gates were active last frame; when the combination changes, restore
-- everything once and re-hide the current set in the same pass (no flash,
-- and originals are re-captured from their restored values).
local _suppress_sig = 0

local function suppress_dialogue_popup(hud)
	local hide_popups = should_suppress_dialogue_popup()
	local sig = hide_popups and 1 or 0

	if sig ~= _suppress_sig then
		restore_dialogue_popup()
		_suppress_sig = sig
	end

	if not hide_popups then
		return
	end

	hud = hud or safe(function()
		return Managers.ui and Managers.ui:get_hud()
	end)

	if type(hud) ~= "table" then
		return
	end

	local elements = rawget(hud, "_elements")

	if type(elements) ~= "table" then
		return
	end

	-- _dialogue_restore must NOT be reset here: this runs every frame, and the
	-- widgets are already hidden by then â€” wiping the table would re-capture
	-- "hidden" as the original state. Only restore_dialogue_popup clears it.
	for element_name, element in pairs(elements) do
		if dialogue_popup_name_matches(element_name) then
			hide_dialogue_element(element)
		end
	end
end

-- HUD widgets are pooled and can become active long after mission start (the
-- expedition tracker is one example). Restore the state captured after the
-- previous update, let vanilla advance its widgets, then capture that fresh
-- state before hiding them for rendering. This prevents an initially-hidden
-- pooled widget from being restored to false forever when the panel closes.
local function update_hud_with_suppression(func, self, ...)
	restore_dialogue_popup()

	local num_results, results = pack_results(func(self, ...))

	suppress_dialogue_popup(self)

	return unpack(results, 1, num_results)
end

if type(mod.hook) == "function" then
	local class_lookup = rawget(_G, "CLASS")
	local ui_hud_class = class_lookup and class_lookup.UIHud or "UIHud"

	mod:hook(ui_hud_class, "update", update_hud_with_suppression)

	-- Never mutate objective-feed widgets. Expeditions reuse and reactivate
	-- these pooled widgets during a run, so saving their mission-start
	-- visibility can strand the expedition panel in a hidden state. Skipping
	-- only the draw leaves vanilla's lifecycle untouched and needs no restore.
	local function hook_objective_draw(class_name)
		mod:hook(class_name, "_draw_widgets", function(func, self, ...)
			if should_suppress_objective_feed() then
				return
			end

			return func(self, ...)
		end)
	end

	hook_objective_draw("HudElementMissionObjectiveFeed")
	hook_objective_draw("HudElementMissionObjectiveTracker")

	mod:hook("SmartTag", "init", function(func, self, tag_id, template, tagger_unit, target_unit, ...)
		local args = { ... }
		local args_n = select("#", ...)
		local num_results, results = pack_results(func(self, tag_id, template, tagger_unit, target_unit, unpack(args, 1, args_n)))

		safe(function()
			track_smart_tag_ping(self, tag_id, template, tagger_unit, target_unit, unpack(args, 1, args_n))
		end)

		return unpack(results, 1, num_results)
	end)

	mod:hook("SmartTag", "destroy", function(func, self, ...)
		safe(function()
			release_smart_tag_ping(self)
		end)

		local num_results, results = pack_results(func(self, ...))

		return unpack(results, 1, num_results)
	end)
end

-- ---------------------------------------------------------------------------
-- End-of-mission debrief: when the end screen appears, freeze the report
-- capture (the mission is decided) and, if enabled, pop the report browser
-- with an automatic replay - the scoreboard-mod pattern, but for the map.
-- ---------------------------------------------------------------------------
local function on_mission_end_screen()
	if _end_screen_seen or not _state.mission then
		return
	end

	_end_screen_seen = true

	if mod.report_freeze then
		safe(mod.report_freeze)
	end
end

-- EndView is the normal end screen; EndPlayerView is hooked as a fallback so
-- the debrief still fires if a flow ever skips straight to the player cards.
if type(mod.hook_safe) == "function" then
	pcall(function()
		mod:hook_safe("EndView", "on_enter", on_mission_end_screen)
	end)
	pcall(function()
		mod:hook_safe("EndPlayerView", "on_enter", on_mission_end_screen)
	end)
end

local function auto_debrief_tick()
	if not _end_screen_seen or _auto_debrief_done then
		return
	end

	_auto_debrief_at = _auto_debrief_at or (_mission_time + AUTO_DEBRIEF_DELAY)

	if _mission_time < _auto_debrief_at then
		return
	end

	_auto_debrief_done = true

	if get_setting("auto_open_report", true) == false then
		return
	end

	local already_open = safe(function()
		return mod.report_view and mod.report_view().open
	end)

	if already_open then
		return
	end

	mod._auto_replay_pending = true

	local opened = safe(function()
		Managers.ui:open_view("strikemap_report_view")

		return true
	end)

	if not opened then
		mod._auto_replay_pending = nil
	end
end

function mod.strikemap_state()
	return _state
end

-- ---------------------------------------------------------------------------
-- Keybind functions (referenced by name from strikemap_data.lua)
-- ---------------------------------------------------------------------------
local function report_open()
	return mod.report_view and mod.report_view().open
end

-- While the report browser is open, the shared strikemap keys drive it so the
-- whole feature needs only ONE extra keybind (open/close): toggle = cycle
-- overlay, zoom in/out = next/previous run. While the full map is open, the
-- same key cycles its pitch (top-down / tactical / low orbit) instead.
function mod.toggle_strikemap()
	if report_open() then
		if mod.report_cycle_layer then
			mod.report_cycle_layer()
		end
		return
	end

	if _state.geometry_only then
		return
	end

	if _state.fullmap then
		_state.fullmap_pitch_idx = (_state.fullmap_pitch_idx or 2) % 3 + 1
		return
	end

	_state.visible = not _state.visible
end

-- Full-screen tactical overview. Zoom keybinds retarget to it while it is open.
function mod.toggle_fullmap()
	if _state.geometry_only then
		return
	end

	_state.fullmap = not _state.fullmap
end

function mod.strikemap_zoom_in()
	if report_open() then
		if mod.report_browser_next then
			mod.report_browser_next()
		end
	elseif _state.geometry_only then
		return
	elseif _state.fullmap then
		_state.fullmap_zoom = math.min(4, (_state.fullmap_zoom or 1) * 1.15)
	else
		_state.zoom_mult = math.max(0.4, _state.zoom_mult / 1.25)
	end
end

function mod.strikemap_zoom_out()
	if report_open() then
		if mod.report_browser_prev then
			mod.report_browser_prev()
		end
	elseif _state.geometry_only then
		return
	elseif _state.fullmap then
		_state.fullmap_zoom = math.max(0.5, (_state.fullmap_zoom or 1) / 1.15)
	else
		_state.zoom_mult = math.min(2.5, _state.zoom_mult * 1.25)
	end
end

-- ---------------------------------------------------------------------------
-- Map data loading. Files are generated by tools/convert_maps.py; triangle
-- coords live in packed strings (LuaJIT constant-count limits) so we parse
-- them into one flat number array here, once per mission. Cell index strings
-- are parsed lazily by the element.
-- ---------------------------------------------------------------------------
-- File IO must go through Mods.lua.io: the DMF mod environment has no usable
-- global `io` (DMF itself and scoreboard-ii both deepcopy Mods.lua.io). This
-- was the reason v1 shipped with an invisible map: the loader silently got nil.
local function get_io()
	local mods = rawget(_G, "Mods")
	return (mods and mods.lua and mods.lua.io) or rawget(_G, "_io") or rawget(_G, "io")
end

local function load_lua_table_file(path)
	local io_lib = get_io()
	local load_fn = (rawget(_G, "Mods") and Mods.lua and Mods.lua.loadstring)
		or rawget(_G, "loadstring")
		or load

	if not io_lib or not load_fn or not path then
		return nil
	end

	local file = io_lib.open(path, "r")

	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	if type(content) ~= "string" or content == "" then
		return nil
	end

	local chunk = load_fn(content, path)

	if not chunk then
		return nil
	end

	local ok, result = pcall(chunk)

	if ok and type(result) == "table" then
		return result
	end

	return nil
end

local function parse_map(raw)
	if type(raw) ~= "table" or type(raw.tdata) ~= "table" or type(raw.cells) ~= "table" then
		return nil
	end

	local function parse_chunks(chunks)
		local values = {}
		local n = 0

		if type(chunks) ~= "table" then
			return values, 0
		end

		for i = 1, #chunks do
			local chunk = chunks[i]

			if type(chunk) == "string" then
				for num in chunk:gmatch("[^,;]+") do
					n = n + 1
					values[n] = tonumber(num) or 0
				end
			end
		end

		return values, n
	end

	local t, n = parse_chunks(raw.tdata)

	if n < 7 then
		return nil
	end

	local contours, contour_n = parse_chunks(raw.cdata)
	local stairs, stair_n = parse_chunks(raw.sdata)
	local hatches, hatch_n = parse_chunks(raw.hdata)
	local transitions, transition_n = parse_chunks(raw.rdata)

	return {
		mission = raw.mission,
		format_version = raw.format_version or 1,
		z_band = raw.z_band or 2.5,
		hatch_spacing = raw.hatch_spacing or 2,
		grid_cell = raw.grid_cell or 16,
		tri_count = math.floor(n / 7),
		t = t,
		cells = raw.cells,
		cell_cache = {},
		contour_count = math.floor(contour_n / 5),
		c = contours,
		contour_cells = type(raw.contour_cells) == "table" and raw.contour_cells or {},
		contour_cell_cache = {},
		stair_count = math.floor(stair_n / 6),
		s = stairs,
		stair_cells = type(raw.stair_cells) == "table" and raw.stair_cells or {},
		stair_cell_cache = {},
		hatch_count = math.floor(hatch_n / 5),
		h = hatches,
		hatch_cells = type(raw.hatch_cells) == "table" and raw.hatch_cells or {},
		hatch_cell_cache = {},
		transition_count = math.floor(transition_n / 4),
		r = transitions,
		transition_cells = type(raw.transition_cells) == "table" and raw.transition_cells or {},
		transition_cell_cache = {},
	}
end

local function try_load_map(mission_name)
	local raw = load_lua_table_file(MAPS_DIR .. mission_name .. ".lua")

	if not raw then
		return nil
	end

	return safe(function()
		return parse_map(raw)
	end)
end

-- Load a parsed floor plan by mission id (used by the report browser to draw
-- the map of a run that is not the one currently being played).
function mod.load_map(mission_name)
	return try_load_map(mission_name)
end

-- World-space bounds of a parsed map, for standalone report rendering.
function mod.map_bounds(map)
	if not map or not map.t or not map.tri_count or map.tri_count <= 0 then
		return nil
	end

	local t = map.t
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	local z0, z1 = math.huge, -math.huge

	for i = 0, map.tri_count - 1 do
		local o = i * 7

		for k = 0, 2 do
			local x = t[o + 1 + k * 2]
			local y = t[o + 2 + k * 2]

			if x < x0 then x0 = x end
			if x > x1 then x1 = x end
			if y < y0 then y0 = y end
			if y > y1 then y1 = y end
		end

		local z = t[o + 7]

		if z < z0 then z0 = z end
		if z > z1 then z1 = z end
	end

	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1, z0 = z0, z1 = z1 }
end

-- ---------------------------------------------------------------------------
-- External minimap compatibility API. COMPATIBILITY_API.txt is the public
-- contract; keep this table session-stable and the map context mission-stable.
-- Geometry arrays and the packed spatial index are deliberately shared by
-- reference with Strikemap's renderer, making the API zero-copy and read-only.
-- ---------------------------------------------------------------------------
local COMPAT_API_VERSION = 1

local _compat_api = nil
local _compat_context = nil
local _compat_context_failed = false
local _compat_vectors = nil
local _compat_vectors_failed = false
local _compat_revision = 0
local _compat_consumers = {}
local _compat_consumer_count = 0
local _compat_status = {}
local _compat_logged = {}

local function compat_log_once(key, message)
	if _compat_logged[key] then
		return
	end

	_compat_logged[key] = true
	safe(function()
		if type(mod.info) == "function" then
			mod:info(message)
		end
	end)
end

local function compat_api_enabled()
	return get_setting("compat_api_enabled", true) ~= false
end

-- Manual geometry-only mode remains useful even with API sharing disabled.
-- Automatic takeover, however, only applies while the API itself is enabled;
-- otherwise a stale registration could hide Strikemap while exposing nothing.
local function compat_geometry_only_enabled()
	if get_setting("compat_geometry_only", false) == true then
		return true
	end

	return compat_api_enabled()
		and _compat_consumer_count > 0
		and get_setting("compat_auto_geometry_only", false) == true
end

local function build_compat_context(mission_name, map)
	local bounds = mod.map_bounds(map)

	if not bounds then
		error("map bounds are unavailable")
	end

	local spatial_index = map.cells

	-- Live expedition maps build their renderer index directly as arrays so
	-- triangles can be appended cheaply. The public API promises packed index
	-- strings, so snapshot that index whenever the geometry revision changes.
	if map.live then
		spatial_index = {}

		for key, ids in pairs(map.cell_cache or {}) do
			if type(ids) == "table" and #ids > 0 then
				local packed = {}

				for i = 1, #ids do
					packed[i] = tostring(ids[i])
				end

				spatial_index[key] = table.concat(packed, ",")
			end
		end
	end

	return {
		api_version = COMPAT_API_VERSION,
		mission_name = mission_name,
		map_id = mission_name,
		revision = _compat_revision,
		triangles = map.t,
		tri_count = map.tri_count,
		triangle_stride = 7,
		grid_cell = map.grid_cell or 16,
		spatial_index = spatial_index,
		bounds = bounds,
		minimum_z = bounds.z0,
		maximum_z = bounds.z1,
	}
end

-- Vector layers (walls, stair ticks, deck hatching, incline ink, ramp
-- anchors + chain classification) for consumers rendering the tactical
-- style themselves. Contours/stairs/hatches/transitions come baked or from
-- the runtime fallback; slope ink and chain classification are derived by
-- the element's builders, which the exported trigger runs on demand so a
-- geometry-only consumer never depends on Strikemap drawing a frame.
local function build_vector_context(mission_name, map)
	if mod._ensure_map_vectors then
		mod._ensure_map_vectors(map)
	end

	local chains = {}
	local chain_of = {}
	local id_by_chain = {}
	local anchor_chain = map.anchor_chain

	if anchor_chain then
		for i = 1, map.transition_count or 0 do
			local chain = anchor_chain[i]

			if chain then
				local id = id_by_chain[chain]

				if not id then
					id = #chains + 1
					id_by_chain[chain] = id
					chains[id] = { zlo = chain.zlo, zhi = chain.zhi, steep = chain.steep == true }
				end

				chain_of[i] = id
			end
		end
	end

	return {
		api_version = COMPAT_API_VERSION,
		mission_name = mission_name,
		map_id = mission_name,
		revision = _compat_revision,
		contours = map.c or {},
		contour_count = map.contour_count or 0,
		contour_stride = 5,
		stairs = map.s or {},
		stair_count = map.stair_count or 0,
		stair_stride = 6,
		hatches = map.h or {},
		hatch_count = map.hatch_count or 0,
		hatch_stride = 5,
		hatch_spacing = map.hatch_spacing or 2,
		slopes = map.slope_segs or {},
		slope_count = map.slope_seg_count or 0,
		slope_stride = 5,
		transitions = map.r or {},
		transition_count = map.transition_count or 0,
		transition_stride = 4,
		transition_chain = chain_of,
		chains = chains,
	}
end

-- Build once after the mission map is parsed. Consumers cache this exact table
-- until geometry_revision changes; no context or geometry is copied per frame.
local function compat_refresh_context(mission_name)
	if _compat_context or _compat_context_failed or not _state.map or not compat_api_enabled() then
		return
	end

	-- A live expedition map exists before its first scan result. Keep the API
	-- in "loading" instead of publishing infinite bounds or latching an error.
	if (_state.map.tri_count or 0) <= 0 then
		return
	end

	_compat_revision = _compat_revision + 1

	local ok, context = pcall(build_compat_context, mission_name, _state.map)

	if ok and context then
		_compat_context = context
		compat_log_once("api_ready", "Compatibility API ready.")
	else
		_compat_context_failed = true
		compat_log_once("context_failed", "Compatibility context build failed: " .. tostring(context))
	end
end

local function compat_clear_context()
	if _compat_context then
		_compat_revision = _compat_revision + 1
		_compat_context = nil
	end

	_compat_context_failed = false
	_compat_vectors = nil
	_compat_vectors_failed = false
end

local function compat_status_name()
	if not compat_api_enabled() then
		return "disabled"
	elseif not _state.active or not _state.mission then
		return "not_in_mission"
	elseif _compat_context then
		return "map_loaded"
	elseif _compat_context_failed then
		return "error"
	elseif _state.map or _load_attempts < MAP_LOAD_ATTEMPTS then
		return "loading"
	end

	return "map_unavailable"
end

local function compat_get_status()
	local status = _compat_status
	local name = compat_status_name()

	status.api_version = COMPAT_API_VERSION
	status.available = name ~= "disabled"
	status.status = name
	status.map_loaded = name == "map_loaded"
	status.mission_name = _state.mission
	status.map_id = _state.mission
	status.geometry_revision = _compat_revision
	status.geometry_only = _state.geometry_only == true
	status.recording_active = get_setting("record_reports", true) ~= false

	return status
end

local function compat_get_map_context()
	if _compat_context and compat_api_enabled() then
		return _compat_context
	end

	return nil
end

-- Lazily built on first request per geometry revision, then the exact same
-- table until the revision changes (same caching contract as the map
-- context). Never raises; a failed build latches nil until the next
-- revision/mission.
local function compat_get_vector_context()
	if not _compat_context or not compat_api_enabled() or not _state.map then
		return nil
	end

	if _compat_vectors and _compat_vectors.revision == _compat_revision then
		return _compat_vectors
	end

	-- a failed build latches nil only for ITS revision; expedition growth
	-- bumps the revision without a mission change and gets a fresh attempt
	if _compat_vectors_failed == _compat_revision then
		return nil
	end

	local ok, context = pcall(build_vector_context, _compat_context.mission_name, _state.map)

	if ok and context then
		_compat_vectors = context
	else
		_compat_vectors = nil
		_compat_vectors_failed = _compat_revision
		compat_log_once("vector_context_failed",
			"Compatibility vector context build failed: " .. tostring(context))
	end

	return _compat_vectors
end

local function compat_register_consumer(consumer_id)
	if type(consumer_id) ~= "string" or consumer_id == "" then
		return false
	end

	if not _compat_consumers[consumer_id] then
		_compat_consumers[consumer_id] = true
		_compat_consumer_count = _compat_consumer_count + 1
		compat_log_once("consumer_on_" .. consumer_id,
			"External geometry consumer registered: " .. consumer_id .. ".")
	end

	return true
end

local function compat_unregister_consumer(consumer_id)
	if type(consumer_id) ~= "string" or not _compat_consumers[consumer_id] then
		return false
	end

	_compat_consumers[consumer_id] = nil
	_compat_consumer_count = math.max(0, _compat_consumer_count - 1)
	compat_log_once("consumer_off_" .. consumer_id,
		"External geometry consumer unregistered: " .. consumer_id .. ".")

	return true
end

-- Works with both strikemap:get_compatibility_api() and the dot form. Lua
-- ignores the extra self argument, and repeated calls return the same table.
function mod.get_compatibility_api()
	if not _compat_api then
		_compat_api = {
			api_version = COMPAT_API_VERSION,
			get_status = compat_get_status,
			get_map_context = compat_get_map_context,
			get_vector_context = compat_get_vector_context,
			register_consumer = compat_register_consumer,
			unregister_consumer = compat_unregister_consumer,
		}
	end

	return _compat_api
end

-- ---------------------------------------------------------------------------
-- Marker collection
-- ---------------------------------------------------------------------------
-- Objective TEXT entries (header + progress) for the on-panel objective strip.
-- Same client-safe source the vanilla tracker reads.
local function collect_objective_lines()
	local lines = _state.objective_lines
	local count = 0

	if get_setting("integrate_objectives", true) ~= false then
		local active = safe(function()
			local em = Managers.state and Managers.state.extension
			local system = em and em:system("mission_objective_system")

			return system and system:active_objectives()
		end)

		if type(active) == "table" then
			for objective in pairs(active) do
				safe(function()
					if objective:use_hud() ~= false and objective:hide_widget() ~= true then
						local header = objective:header()

						if type(header) == "string" and header ~= "" then
							if header:sub(1, 4) == "loc_" then
								header = safe(function()
									return Localize(header)
								end) or header
							end

							local has_second = safe(function()
								return objective:has_second_progression()
							end) == true
							local progress = safe(function()
								return has_second and objective:second_progression()
									or objective:progression()
							end)

							count = count + 1

							local entry = lines[count] or {}
							entry.text = header
							entry.name = safe(function()
								return objective:name()
							end) or header
							entry.progress = safe(function()
								return objective:progress_bar()
							end) == true and tonumber(progress) or nil
							entry.side = safe(function()
								return objective:is_side_mission()
							end) == true
							entry.order = tonumber(safe(function()
								return objective:order_of_activation()
							end)) or 0
							lines[count] = entry
						end
					end
				end)
			end
		end
	end

	for i = count + 1, #lines do
		lines[i] = nil
	end

	if count > 1 then
		table.sort(lines, function(a, b)
			if a.side ~= b.side then
				return not a.side -- main objectives first
			end

			return a.order < b.order
		end)
	end
end

local function objective_activation_label()
	local current = {}
	local label

	for i = 1, #_state.objective_lines do
		local line = _state.objective_lines[i]
		local name = tostring(line.name or line.text or i)

		current[name] = true

		if _objective_name_snapshot_ready and not _objective_name_history[name] then
			local lower = string.lower(name .. " " .. tostring(line.text or ""))

			if lower:find("extract", 1, true) or lower:find("evac", 1, true)
				or lower:find("escape", 1, true) or lower:find("end_zone", 1, true) then
				label = "EXTRACTION OPEN"
			else
				label = label or "ACCESS GRANTED"
			end
		end
	end

	_objective_name_history = current
	_objective_name_snapshot_ready = true

	return label
end

local function push_objective_event(x, y, z, label)
	if type(x) ~= "number" or type(y) ~= "number" then
		return
	end

	local events = _state.objective_events

	if #events >= 8 then
		table.remove(events, 1)
	end

	events[#events + 1] = {
		x = x,
		y = y,
		z = z,
		label = label or "ACCESS GRANTED",
		changed_at = _mission_time,
	}
end

local function clear_objective_tracking()
	_objective_marker_history = {}
	_objective_name_history = {}
	_objective_marker_snapshot_ready = false
	_objective_name_snapshot_ready = false
	_state.objective_events = {}
end

local function collect_objectives()
	local out = _state.objectives
	local count = 0
	local pending_label
	local event_emitted = false
	local seen_markers = {}
	local valid_marker_snapshot = false

	safe(collect_objective_lines)
	pending_label = objective_activation_label()

	if mod:get("show_objectives") ~= false then
		local by_type = safe(function()
			local hud = Managers.ui and Managers.ui:get_hud()
			local wm = hud and hud:element("HudElementWorldMarkers")
			return wm and rawget(wm, "_markers_by_type")
		end)

		if type(by_type) == "table" then
			valid_marker_snapshot = true

			for marker_type, markers in pairs(by_type) do
				if type(marker_type) == "string" and marker_type:find("objective") and type(markers) == "table" then
					for i = 1, #markers do
						local marker = markers[i]
						local pos
						local marker_key = tostring(marker_type) .. ":" .. tostring(marker.id or marker.unit or marker)

						if marker.world_position then
							pos = safe(function()
								return marker.world_position:unbox()
							end)
						elseif marker.unit then
							pos = safe(function()
								return Unit.alive(marker.unit) and Unit.world_position(marker.unit, 1) or nil
							end)
						end

						if pos then
							seen_markers[marker_key] = true
							count = count + 1
							local entry = out[count] or {}
							entry.x, entry.y, entry.z = pos.x, pos.y, pos.z
							entry.marker_type = marker_type
							out[count] = entry

							local history = _objective_marker_history[marker_key]

							if not history then
								_objective_marker_history[marker_key] = { x = pos.x, y = pos.y, z = pos.z }

								if _objective_marker_snapshot_ready and get_setting("show_tactical_updates", true) ~= false then
									local lower_type = string.lower(tostring(marker_type))
									local label = pending_label

									if lower_type:find("extract", 1, true) or lower_type:find("end_zone", 1, true) then
										label = "EXTRACTION OPEN"
									end

									push_objective_event(pos.x, pos.y, pos.z, label or "ACCESS GRANTED")
									event_emitted = true
								end
							else
								history.x, history.y, history.z = pos.x, pos.y, pos.z
							end
						end
					end
				end
			end
		end
	end

	if valid_marker_snapshot then
		for key in pairs(_objective_marker_history) do
			if not seen_markers[key] then
				_objective_marker_history[key] = nil
			end
		end

		_objective_marker_snapshot_ready = true
	end

	if pending_label and not event_emitted and count > 0 and get_setting("show_tactical_updates", true) ~= false then
		push_objective_event(out[1].x, out[1].y, out[1].z, pending_label)
	end

	for i = #_state.objective_events, 1, -1 do
		if _mission_time - (_state.objective_events[i].changed_at or _mission_time) > OBJECTIVE_EVENT_TTL then
			table.remove(_state.objective_events, i)
		end
	end

	for i = count + 1, #out do
		out[i] = nil
	end
end

-- Replicated tactical topology. Darktide does not expose an authoritative
-- client-side "can I path there?" query: nav-layer blocking is maintained on
-- the server. Door animation state and MissionPathBlocker component state do
-- replicate, however, so these make a reliable cross-client live gate layer.
local function gate_geometry(unit)
	local pos = safe(function()
		return Unit.alive(unit) and Unit.world_position(unit, 1) or nil
	end)

	if not pos then
		return nil
	end

	local geometry = {
		x = pos.x,
		y = pos.y,
		z = pos.z,
		dx = 1,
		dy = 0,
		half = 1.5,
	}
	local box = safe(function()
		local tm, half_size = Unit.box(unit)

		return { tm = tm, half_size = half_size }
	end)

	if box and box.tm and box.half_size and Matrix4x4 then
		-- The root node of door units sits at the hinge/frame edge, not the
		-- leaf's middle - centring the bar on it draws the door beside its
		-- actual opening. The oriented box centre is the real door centre.
		local center = safe(function()
			local t = Matrix4x4.translation(box.tm)

			return t and { x = t.x, y = t.y, z = t.z } or nil
		end)

		if center then
			geometry.x, geometry.y, geometry.z = center.x, center.y, center.z
		end

		local axis = safe(function()
			local right = Matrix4x4.right(box.tm)
			local forward = Matrix4x4.forward(box.tm)
			local hs = box.half_size
			local right_len = math.sqrt(right.x * right.x + right.y * right.y)
			local forward_len = math.sqrt(forward.x * forward.x + forward.y * forward.y)
			local right_span = math.abs(hs.x or 0) * right_len
			local forward_span = math.abs(hs.y or 0) * forward_len
			local v = right_span >= forward_span and right or forward
			local len = math.sqrt(v.x * v.x + v.y * v.y)

			if len <= 0.001 then
				return nil
			end

			return {
				dx = v.x / len,
				dy = v.y / len,
				half = math.max(1.2, math.min(6, right_span >= forward_span and right_span or forward_span)),
			}
		end)

		if axis then
			geometry.dx, geometry.dy, geometry.half = axis.dx, axis.dy, axis.half
		end
	end

	return geometry
end

local function clear_gate_tracking()
	_gate_history = { door = {}, blocker = {} }
	_state.gates = {}
end

local function collect_live_gates()
	local out = _state.gates
	local count = 0
	local seen = { door = {}, blocker = {} }
	local now = _mission_time

	local function record(kind, unit, blocked, locked)
		if unit == nil then
			return
		end

		seen[kind][unit] = true

		local history = _gate_history[kind]
		local entry = history[unit]
		local geometry = gate_geometry(unit)

		if not geometry then
			return
		end

		if not entry then
			entry = { unit = unit, kind = kind, blocked = blocked, locked = locked }
			history[unit] = entry
		elseif entry.blocked ~= blocked then
			entry.changed_at = now
			entry.event = blocked and (locked and "locked" or "sealed") or "opened"
		elseif blocked and entry.locked ~= locked then
			entry.changed_at = now
			entry.event = locked and "locked" or "unlocked"
		end

		entry.x, entry.y, entry.z = geometry.x, geometry.y, geometry.z
		entry.dx, entry.dy, entry.half = geometry.dx, geometry.dy, geometry.half
		entry.blocked, entry.locked = blocked, locked
		entry.last_seen = now

		local event_live = entry.changed_at and now - entry.changed_at <= GATE_EVENT_TTL

		if blocked or event_live then
			count = count + 1
			out[count] = entry
		end
	end

	if get_setting("show_live_gates", true) ~= false then
		local extension_manager = Managers.state and Managers.state.extension
		local door_system = extension_manager and safe(function()
			return extension_manager:system("door_system")
		end)
		local doors = door_system and door_system._unit_to_extension_map

		if type(doors) == "table" then
			for unit, extension in pairs(doors) do
				safe(function()
					local door_state = extension._current_state

					if door_state ~= nil and door_state ~= "none" then
						local blocked = door_state == "closed"
						local interactee = extension._interactee_extension
						local interactable = interactee and safe(function()
							return interactee:active()
						end) == true
						local locked = blocked and (not interactable or extension._open_type == "close_only")

						record("door", unit, blocked, locked)
					end
				end)
			end
		end

		local component_system = extension_manager and safe(function()
			return extension_manager:system("component_system")
		end)
		local blocker_units = component_system and safe(function()
			return component_system:get_units_from_component_name("MissionPathBlocker")
		end)

		if type(blocker_units) == "table" then
			for i = 1, #blocker_units do
				local unit = blocker_units[i]
				local components = safe(function()
					return component_system:get_components(unit, "MissionPathBlocker")
				end)

				if type(components) == "table" then
					for j = 1, #components do
						local component = components[j]
						local blocked = component and component._enabled == true

						record("blocker", unit, blocked, blocked)
					end
				end
			end
		end
	end

	for i = count + 1, #out do
		out[i] = nil
	end

	-- Units can be streamed out between sections. Forget unseen records rather
	-- than turning disappearance into a fake "route opened" notification.
	for kind, history in pairs(_gate_history) do
		for unit, entry in pairs(history) do
			if not seen[kind][unit] and now - (entry.last_seen or now) > 2 then
				history[unit] = nil
			end
		end
	end
end

-- One pass over level units, bucketing everything the radar can mark:
-- medicae stations (+charges), ammo/grenade caches, grimoire/scripture
-- pickups, and (opt-in, they are numerous) small pickups.
local function medicae_charges(unit)
	return safe(function()
		local ext = ScriptUnit.has_extension(unit, "health_station_system")
			and ScriptUnit.extension(unit, "health_station_system")

		return ext and ext.charge_amount and ext:charge_amount() or nil
	end)
end

-- ---------------------------------------------------------------------------
-- Level pickup/station scan.
--
-- World.units("level_world") returns every unit in the level - thousands on a
-- big mission - and this used to classify all of them inside a single frame,
-- every 5 seconds, allocating a closure and a pcall per unit. That was a
-- measured ~39 ms hitch on a metronome. It now runs as a budgeted job spread
-- across frames, writing into staging lists that are published atomically when
-- the sweep completes, so the visible marker set never flickers mid-scan.
--
-- Everything lives on one table because this chunk is close to LuaJIT's
-- 200-local ceiling; a dozen file-locals here will not compile.
-- ---------------------------------------------------------------------------
local Scan = {
	job = nil,
	recycle = nil,
	budget = 250, -- level units classified per frame
	buckets = {
		"medicae", "supplies", "books", "ammo", "grenades",
		"ammo_crates", "med_crates", "stimms", "materials",
	},
}

-- Returns bucket name + detected kind, or nil. Called under ONE pcall per unit
-- instead of building a closure for each.
function Scan.classify(unit, interactee_ext, pickup_type_hint, interaction_type_hint, want)
	if not Unit.alive(unit) then
		return nil
	end

	if ScriptUnit.has_extension(unit, "health_station_system") then
		return want.medicae and "medicae" or nil
	end

	local pickup_type = unit_get_data(unit, "pickup_type") or pickup_type_hint
	local pickup_kind = classify_pickup_type(pickup_type)

	if pickup_kind == "book" then
		return want.books and "books" or nil, pickup_kind
	elseif pickup_kind == "ammo" then
		return want.ammo and "ammo" or nil, pickup_kind
	elseif pickup_kind == "grenade" then
		return want.grenades and "grenades" or nil, pickup_kind
	elseif pickup_kind == "ammo_crate" then
		return want.ammo_crates and "ammo_crates" or nil, pickup_kind
	elseif pickup_kind == "med_crate" then
		return want.med_crates and "med_crates" or nil, pickup_kind
	elseif pickup_kind and pickup_kind:find("stimm_", 1, true) == 1 then
		return want.stimms and "stimms" or nil, pickup_kind
	elseif pickup_kind or type(pickup_type) == "string" then
		return want.materials and "materials" or nil, pickup_kind
	end

	local interaction_type = extension_interaction_type(interactee_ext)
		or unit_interaction_type(unit) or interaction_type_hint

	if interaction_type == "health_station" then
		return want.medicae and "medicae" or nil, pickup_kind
	elseif interaction_type == "side_mission" then
		return want.books and "books" or nil, "book"
	elseif interaction_type == "chest" then
		return want.supplies and "supplies" or nil, pickup_kind
	elseif interaction_type == "ammunition" then
		return want.ammo and "ammo" or nil, "ammo"
	elseif interaction_type == "grenade" then
		return want.grenades and "grenades" or nil, "grenade"
	elseif interaction_type == "pickup" or interaction_type == "forge_material" then
		return want.materials and "materials" or nil, pickup_kind
	end

	if unit_get_data(unit, "smart_tag_target_type") == "pickup" then
		return want.materials and "materials" or nil, pickup_kind
	end

	return nil
end

function Scan.visit(job, unit, interactee_ext, pickup_type_hint, interaction_type_hint)
	if not unit or job.seen[unit] then
		return
	end

	local ok, bucket, detected_kind =
		pcall(Scan.classify, unit, interactee_ext, pickup_type_hint, interaction_type_hint, job.want)

	if not ok or not bucket then
		return
	end

	job.seen[unit] = true

	local pos = unit_position(unit)

	if not pos then
		return
	end

	local list = job.staged[bucket]
	local count = job.counts[bucket] + 1
	job.counts[bucket] = count

	local entry = list[count] or {}
	entry.x, entry.y, entry.z = pos.x, pos.y, pos.z
	entry.unit = unit
	entry.kind = detected_kind
	entry.charges = bucket == "medicae" and medicae_charges(unit) or nil
	entry.visible_by_sight = nil
	list[count] = entry
end

function Scan.read_level_units()
	local world = Managers.world:world("level_world")

	return world and World.units(world) or nil
end

function Scan.read_interactees()
	local extension_manager = Managers.state and Managers.state.extension
	local system = extension_manager and extension_manager:system("interactee_system")

	return system and system._unit_to_extension_map or nil
end

function Scan.read_marker_groups()
	local hud = Managers.ui and Managers.ui:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")

	return world_markers and world_markers._markers_by_type or nil
end

function Scan.begin()
	local staged, counts = {}, {}
	local names = Scan.buckets

	for i = 1, #names do
		local name = names[i]
		-- Last scan's published list becomes this scan's staging array, so the
		-- pooled entry tables are reused instead of reallocated.
		staged[name] = Scan.recycle and Scan.recycle[name] or {}
		counts[name] = 0
	end

	local ok, units = pcall(Scan.read_level_units)

	Scan.recycle = nil
	Scan.job = {
		want = {
			medicae = mod:get("show_medicae") ~= false,
			supplies = mod:get("show_supplies") ~= false,
			books = mod:get("show_books") ~= false,
			ammo = mod:get("show_ammo_pickups") ~= false,
			grenades = mod:get("show_grenades") ~= false,
			ammo_crates = mod:get("show_ammo_crates") ~= false,
			med_crates = mod:get("show_med_crates") ~= false,
			stimms = mod:get("show_stimms") ~= false,
			materials = mod:get("show_materials") == true,
		},
		units = ok and units or nil,
		i = 0,
		seen = {},
		staged = staged,
		counts = counts,
	}
end

-- Publishes the staged lists and returns how many markers were found.
function Scan.finish(job)
	-- Spawned pickups are owned by InteracteeSystem and are not guaranteed to
	-- appear in World.units("level_world") on clients. Its live registry is the
	-- same client-side source used by the game's interaction HUD. Both this and
	-- the marker sweep below are small, so they run in the closing frame.
	local ok, interactees = pcall(Scan.read_interactees)

	if ok and type(interactees) == "table" then
		for unit, ext in pairs(interactees) do
			Scan.visit(job, unit, ext)
		end
	end

	-- Networked/deployable pickups can be represented by a HUD interaction
	-- marker before either collection above exposes them. Fold those units in
	-- as a final client-safe fallback.
	local marker_ok, marker_groups = pcall(Scan.read_marker_groups)

	if marker_ok and type(marker_groups) == "table" then
		for _, markers in pairs(marker_groups) do
			if type(markers) == "table" then
				for i = 1, #markers do
					local marker = markers[i]
					local data = marker and marker.data
					local pickup_type_hint = data and (data.type or data.pickup_type)
					local interaction_type_hint = data and data._active_interaction_type

					Scan.visit(job, marker and marker.unit, nil, pickup_type_hint, interaction_type_hint)
				end
			end
		end
	end

	local recycle, total = {}, 0
	local names = Scan.buckets

	for i = 1, #names do
		local name = names[i]
		local list = job.staged[name]
		local count = job.counts[name]

		for n = count + 1, #list do
			list[n] = nil
		end

		-- Swap in the freshly built list and keep the outgoing one for reuse.
		recycle[name] = _state[name]
		_state[name] = list
		total = total + count
	end

	Scan.recycle = recycle
	Scan.job = nil

	return total
end

-- Runs one frame's slice of the sweep. Returns the marker total when a sweep
-- completes, or nil while more slices remain. `full` forces a single-frame
-- sweep, which mission start and the offline harness both want.
function Scan.step(full)
	if not Scan.job then
		Scan.begin()
	end

	local job = Scan.job

	if not job then
		return 0
	end

	local units = job.units

	if units then
		local n = #units
		local budget = full and n or Scan.budget
		local stop = math.min(n, job.i + budget)

		for i = job.i + 1, stop do
			Scan.visit(job, units[i])
		end

		job.i = stop

		if job.i < n then
			return nil
		end
	end

	return Scan.finish(job)
end

-- Cheap between-scans tick: refresh medicae charges and drop entries whose
-- unit is gone (picked-up books/pickups vanish within ~2s, not ~30s).
local function refresh_level_units()
	local m = _state.medicae

	for i = 1, #m do
		m[i].charges = m[i].unit and medicae_charges(m[i].unit) or m[i].charges
	end

	for _, list in ipairs({ _state.supplies, _state.books, _state.ammo, _state.grenades,
		_state.ammo_crates, _state.med_crates, _state.stimms, _state.materials }) do
		local kept = 0

		for i = 1, #list do
			local entry = list[i]
			local alive = entry.unit and safe(function()
				return Unit.alive(entry.unit)
			end)

			if alive then
				kept = kept + 1
				list[kept] = entry
			end
		end

		for i = kept + 1, #list do
			list[i] = nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- Enemy collection via broadphase (client-safe; enemies_improved pattern).
-- Categories by breed tags: monster (incl. captains/daemonhosts), special
-- (incl. disablers/snipers), elite, horde (everything else).
-- ---------------------------------------------------------------------------
local ENEMY_TYPE_ALIASES = {
	chaos_witch = "chaos_daemonhost",
	cultist_elite_gunner = "cultist_gunner",
	cultist_elite_shocktrooper = "cultist_shocktrooper",
	cultist_specialist_flamer = "cultist_flamer",
	renegade_elite_executor = "renegade_executor",
	renegade_elite_gunner = "renegade_gunner",
	renegade_elite_shocktrooper = "renegade_shocktrooper",
	renegade_specialist_flamer = "renegade_flamer",
	renegade_specialist_grenadier = "renegade_grenadier",
	renegade_specialist_netgunner = "renegade_netgunner",
	renegade_specialist_sniper = "renegade_sniper",
	-- Rodin and Rinda are two renegade-prefixed runtime breeds. Keep separate
	-- user-facing controls by mapping the second breed to the Dreg Twin key.
	renegade_twin_captain_two = "cultist_twin_captain",
}

-- Memoized (false = "sanitizes to nothing"): runs per enemy per tick, and the
-- breed-name set is small and fixed â€” the lower/gsub chain allocates 4 strings
-- per call, which adds up exactly during hordes.
local _enemy_type_by_name = {}

local function sanitize_enemy_type(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end

	local cached = _enemy_type_by_name[name]

	if cached ~= nil then
		return cached or nil
	end

	local key = name:lower():gsub("[^%w_]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	local result = key ~= "" and (ENEMY_TYPE_ALIASES[key] or key) or false

	_enemy_type_by_name[name] = result

	return result or nil
end

local function enemy_type_from_breed(breed)
	if type(breed) ~= "table" then
		return nil
	end

	return sanitize_enemy_type(breed.name)
		or sanitize_enemy_type(breed.breed_name)
		or sanitize_enemy_type(breed.breed_type)
		or sanitize_enemy_type(breed.id)
		or sanitize_enemy_type(breed.display_name)
end

local function classify_tags(tags)
	if not tags then
		return "horde"
	end

	if tags.monster or tags.captain or tags.cultist_captain or tags.witch then
		return "monster"
	elseif tags.special or tags.disabler or tags.sniper then
		return "special"
	elseif tags.elite then
		return "elite"
	end

	return "horde"
end

local _enemy_counts = { horde = 0, elite = 0, special = 0, monster = 0 }
-- flat alive-enemy snapshot handed to the report capture each scan
local _report_units = {}
local _report_pos = {}

local function collect_enemies()
	local counts = _enemy_counts
	counts.horde, counts.elite, counts.special, counts.monster = 0, 0, 0, 0
	local report_n = 0

	local enabled = mod:get("show_horde") ~= false
		or mod:get("show_elites") ~= false
		or mod:get("show_specials") ~= false
		or mod:get("show_monsters") ~= false

	if enabled then
		local player = Managers.player and Managers.player:local_player(1)
		local player_unit = player and player.player_unit
		local alive_lookup = rawget(_G, "HEALTH_ALIVE")

		if player_unit and Unit.alive(player_unit) and alive_lookup then
			local extension_manager = Managers.state.extension
			local broadphase_system = extension_manager and extension_manager:system("broadphase_system")
			local side_system = extension_manager and extension_manager:system("side_system")
			local side = side_system and side_system.side_by_unit and side_system.side_by_unit[player_unit]

			if broadphase_system and side then
				local broadphase = broadphase_system.broadphase
				local enemy_side_names = side:relation_side_names("enemy")
				local from_pos = Unit.world_position(player_unit, 1)
				local results = _broadphase_results

				for i = 1, #results do
					results[i] = nil
				end

				local num_hits = broadphase.query(broadphase, from_pos, sight_range(), results, enemy_side_names)

				for i = 1, num_hits do
					local unit = results[i]

					if unit and alive_lookup[unit] and Unit.alive(unit) then
						local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
						local breed = unit_data and unit_data:breed()

						if breed then
							local category = classify_tags(breed.tags)
							local list = _state.enemies[category]
							local count = counts[category] + 1
							counts[category] = count

							local pos = Unit.world_position(unit, 1)
							local entry = list[count] or {}
							entry.x, entry.y, entry.z = pos.x, pos.y, pos.z
							entry.unit = unit
							entry.enemy_type = enemy_type_from_breed(breed)
							list[count] = entry

							report_n = report_n + 1
							_report_units[report_n] = unit
							local rp = _report_pos[report_n] or {}
							rp.x, rp.y, rp.z = pos.x, pos.y, pos.z
							_report_pos[report_n] = rp
						end
					end
				end
			end
		end
	end

	for category, list in pairs(_state.enemies) do
		for i = counts[category] + 1, #list do
			list[i] = nil
		end
	end

	if mod.report_capture_enemies then
		safe(function()
			mod.report_capture_enemies(_report_units, _report_pos, report_n)
		end)
	end
end

-- Geometry-only mode still feeds the Mission Debrief's proximity-based kill
-- locations, but avoids category bucketing, marker allocation and LoS work.
local function collect_report_enemies()
	local report_n = 0
	local player = Managers.player and Managers.player:local_player(1)
	local player_unit = player and player.player_unit
	local alive_lookup = rawget(_G, "HEALTH_ALIVE")

	if player_unit and Unit.alive(player_unit) and alive_lookup then
		local extension_manager = Managers.state.extension
		local broadphase_system = extension_manager and extension_manager:system("broadphase_system")
		local side_system = extension_manager and extension_manager:system("side_system")
		local side = side_system and side_system.side_by_unit and side_system.side_by_unit[player_unit]

		if broadphase_system and side then
			local broadphase = broadphase_system.broadphase
			local enemy_side_names = side:relation_side_names("enemy")
			local from_pos = Unit.world_position(player_unit, 1)
			local results = _broadphase_results

			for i = 1, #results do
				results[i] = nil
			end

			local num_hits = broadphase.query(broadphase, from_pos, sight_range(), results, enemy_side_names)

			for i = 1, num_hits do
				local unit = results[i]

				if unit and alive_lookup[unit] and Unit.alive(unit) then
					local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
					local breed = unit_data and unit_data:breed()

					if breed then
						local pos = Unit.world_position(unit, 1)

						report_n = report_n + 1
						_report_units[report_n] = unit
						local rp = _report_pos[report_n] or {}
						rp.x, rp.y, rp.z = pos.x, pos.y, pos.z
						_report_pos[report_n] = rp
					end
				end
			end
		end
	end

	if mod.report_capture_enemies then
		safe(function()
			mod.report_capture_enemies(_report_units, _report_pos, report_n)
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Attributed combat capture: AttackReportManager fires on every peer for every
-- hit (the scoreboard mods are built on it), so kills, damage dealt/taken and
-- boss fights can be credited to players on clients too. All handlers are
-- hook_safe + pcall'd: a bad report can never touch gameplay.
-- ---------------------------------------------------------------------------
local KILL_CLASS = { horde = 1, elite = 2, special = 3, monster = 4 }

-- Breeds that count as a boss encounter (mirrors the scoreboard's list).
local BOSS_BREEDS = {
	chaos_beast_of_nurgle = "Beast of Nurgle",
	chaos_daemonhost = "Daemonhost",
	chaos_mutator_daemonhost = "Daemonhost",
	chaos_spawn = "Chaos Spawn",
	chaos_plague_ogryn = "Plague Ogryn",
	chaos_plague_ogryn_sprayer = "Plague Ogryn",
	chaos_ogryn_houndmaster = "Houndmaster",
	renegade_captain = "Scab Captain",
	cultist_captain = "Dreg Captain",
	renegade_twin_captain = "Karnak Twin",
	renegade_twin_captain_two = "Karnak Twin",
	cultist_twin_captain = "Karnak Twin",
}

-- Display names for "downed by <enemy>" attribution; falls back to prettified
-- breed names for anything not listed.
local ENEMY_LABELS = {
	chaos_poxwalker = "Poxwalker",
	chaos_newly_infected = "Newly Infected",
	chaos_lesser_mutated_poxwalker = "Mutated Poxwalker",
	chaos_mutated_poxwalker = "Tentacled Poxwalker",
	chaos_armored_infected = "Moebian 21st Infected",
	renegade_melee = "Scab Bruiser",
	renegade_assault = "Scab Stalker",
	renegade_rifleman = "Scab Shooter",
	cultist_melee = "Dreg Bruiser",
	cultist_assault = "Dreg Stalker",
	cultist_rifleman = "Dreg Shooter",
	renegade_executor = "Scab Mauler",
	chaos_ogryn_executor = "Crusher",
	chaos_ogryn_bulwark = "Bulwark",
	chaos_ogryn_gunner = "Reaper",
	renegade_berzerker = "Scab Rager",
	cultist_berzerker = "Dreg Rager",
	renegade_gunner = "Scab Gunner",
	cultist_gunner = "Dreg Gunner",
	renegade_shocktrooper = "Scab Shotgunner",
	cultist_shocktrooper = "Dreg Shotgunner",
	renegade_plasma_gunner = "Scab Plasma Gunner",
	renegade_flamer = "Scab Flamer",
	cultist_flamer = "Tox Flamer",
	renegade_netgunner = "Trapper",
	renegade_grenadier = "Bomber",
	cultist_grenadier = "Tox Bomber",
	renegade_sniper = "Sniper",
	cultist_mutant = "Mutant",
	chaos_hound = "Pox Hound",
	chaos_armored_hound = "Armoured Hound",
	chaos_ogryn_houndmaster = "Houndmaster",
	chaos_poxwalker_bomber = "Poxburster",
	renegade_radio_operator = "Radio Operator",
	cultist_ritualist = "Ritualist",
}

local function enemy_label(breed)
	local key = enemy_type_from_breed(breed)

	if not key then
		return nil
	end

	if BOSS_BREEDS[key] then
		return BOSS_BREEDS[key]
	end

	if ENEMY_LABELS[key] then
		return ENEMY_LABELS[key]
	end

	-- prettify: strip faction prefix, underscores to spaces, title case
	local label = key:gsub("^chaos_", ""):gsub("^renegade_", ""):gsub("^cultist_", ""):gsub("_", " ")

	return (label:gsub("(%a)([%w]*)", function(a, b)
		return a:upper() .. b
	end))
end

local function unit_breed(unit)
	return safe(function()
		local ud = unit and ScriptUnit.has_extension(unit, "unit_data_system")

		return ud and ud.breed and ud:breed() or nil
	end)
end

local function on_attack_report(attacked_unit, attacking_unit, hit_world_position, damage, attack_result, hit_weakspot)
	-- Fires for every hit by every peer, so the disabled check has to come
	-- before the breed/crit/position work, not after it inside the receiver.
	if not _settings_cache.record_reports or not _settings_cache.combat_tracking then
		return
	end

	local victim_breed = unit_breed(attacked_unit)
	local tags = victim_breed and victim_breed.tags

	if tags and tags.minion then
		-- a minion got hit: credit the attacker if it is a player
		local breed_name = victim_breed.name
		local boss_label = breed_name and BOSS_BREEDS[sanitize_enemy_type(breed_name) or breed_name]
		local class_code = boss_label and 4 or KILL_CLASS[classify_tags(tags)] or 1
		local hx, hy, hz

		if hit_world_position then
			hx = tonumber(safe(function()
				return hit_world_position.x
			end))
			hy = tonumber(safe(function()
				return hit_world_position.y
			end))
			hz = tonumber(safe(function()
				return hit_world_position.z
			end))
		end

		-- crit state comes from the attacker's own component (scoreboard pattern)
		local crit = safe(function()
			local ud = attacking_unit and ScriptUnit.has_extension(attacking_unit, "unit_data_system")
			local component = ud and ud.read_component and ud:read_component("critical_strike")

			return component and component.is_active
		end) == true

		mod.report_damage_dealt(attacking_unit, damage, attack_result == "died",
			class_code, boss_label, attacked_unit, hx, hy, hz, hit_weakspot == true, crit)
	elseif victim_breed then
		-- a player (or other non-minion) got hit: log damage taken + attacker,
		-- so an immediate knockdown reads "downed by <enemy>"
		local attacker_breed = unit_breed(attacking_unit)
		local label = attacker_breed and attacker_breed.tags and attacker_breed.tags.minion
			and enemy_label(attacker_breed) or nil

		mod.report_player_damaged(attacked_unit, label, damage)
	end
end

-- Lazily resolved interaction "success" result (settings module; cached).
local _interaction_success = NIL_VALUE

local function interaction_success()
	if _interaction_success == NIL_VALUE then
		_interaction_success = safe(function()
			local settings = require("scripts/settings/interaction/interaction_settings")

			return settings and settings.results and settings.results.success or nil
		end) or false
	end

	return _interaction_success ~= false and _interaction_success or nil
end

local RESCUE_INTERACTIONS = {
	revive = true,
	rescue = true,
	pull_up = true,
	remove_net = true,
}

-- The engine's stopped() may clear _interactor_unit before our post-hook runs
-- (hook_safe fires AFTER the original), and on clients the field may never be
-- set for remote players' interactions. Prefer the interactor_unit argument
-- the engine passes to stopped(); fall back to the field, then to the
-- interactee component (better_downed_indicators' proven chain).
local function resolve_interactor(ext, interactor_unit)
	if interactor_unit then
		return interactor_unit
	end

	local from_field = rawget(ext, "_interactor_unit")

	if from_field then
		return from_field
	end

	return safe(function()
		local unit = rawget(ext, "_unit")
		local uds = unit and ScriptUnit.has_extension(unit, "unit_data_system")
			and ScriptUnit.extension(unit, "unit_data_system")
		local comp = uds and uds.read_component and uds:read_component("interactee")

		return comp and comp.interactor_unit
	end)
end

if type(mod.hook_safe) == "function" then
	pcall(function()
		mod:hook_safe("AttackReportManager", "add_attack_result",
			function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position,
				hit_weakspot, damage, attack_result, attack_type, ...)
				safe(function()
					if mod.report_damage_dealt then
						on_attack_report(attacked_unit, attacking_unit, hit_world_position, damage,
							attack_result, hit_weakspot)
					end
				end)
			end)
	end)

	-- who finished the revive/rescue/untangle on whom
	pcall(function()
		mod:hook_safe("PlayerInteracteeExtension", "stopped", function(self, result, interactor_unit, ...)
			safe(function()
				local success = interaction_success()

				if success ~= nil and result == success then
					local kind = self.interaction_type and self:interaction_type()

					if kind and RESCUE_INTERACTIONS[kind] and mod.report_rescue then
						mod.report_rescue(resolve_interactor(self, interactor_unit), rawget(self, "_unit"))
					end
				end
			end)
		end)
	end)

	-- ammo pickups + medicae station uses
	pcall(function()
		mod:hook_safe("InteracteeExtension", "stopped", function(self, result, interactor_unit, ...)
			safe(function()
				local success = interaction_success()

				if success ~= nil and result ~= success then
					return
				end

				local kind = self.interaction_type and self:interaction_type()
				local interactor = resolve_interactor(self, interactor_unit)

				if not (kind and interactor and mod.report_pickup) then
					return
				end

				if kind == "ammunition" then
					mod.report_pickup(interactor, "ammo")
				elseif kind == "health_station" then
					mod.report_pickup(interactor, "med")
				elseif kind == "forge_material" then
					-- plasteel/diamantine still flow through this interaction
					-- type; description + amount live in the override contexts
					local ctx = rawget(self, "_override_contexts")

					ctx = ctx and (ctx.forge_material or ctx.pickup or ctx)

					local desc = ctx and (ctx.description or ctx.pickup_name or ctx.name
						or ctx.localized_string or ctx.item)

					if type(desc) == "string" then
						local d = desc:lower()
						local large = d:find("large", 1, true) ~= nil or d:find("big", 1, true) ~= nil
						local count = tonumber(ctx.amount or ctx.count or ctx.value)
							or (large and 25 or 10)

						if d:find("plasteel", 1, true) then
							mod.report_pickup(interactor, "plasteel", count)
						elseif d:find("diamantine", 1, true) then
							mod.report_pickup(interactor, "diamantine", count)
						end
					end
				end
			end)
		end)
	end)
end

-- ---------------------------------------------------------------------------
-- Diagnostics: /strikemap_diag chat command + one-shot file write in-mission.
-- ---------------------------------------------------------------------------
local function diag_lines()
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end

	add("=== strikemap diag ===")
	add("build: perf-r2 (sliced level scan, histogram detail budget, reports subfolder)")
	add("registered: " .. tostring(_element_registered))
	add("mission: " .. tostring(_state.mission))
	add("active: " .. tostring(_state.active) .. "  visible: " .. tostring(_state.visible))
	add("map: " .. (_state.map and ("loaded, " .. tostring(_state.map.tri_count) .. " tris") or "NOT LOADED"))
	add("load_attempts: " .. tostring(_load_attempts))
	add("element injected: " .. tostring(safe(function()
		local hud = Managers.ui and Managers.ui:get_hud()
		return hud and hud:element("StrikemapElement") ~= nil
	end)))
	add("element inited: " .. tostring(mod._element_inited))
	add("draw ticks: " .. tostring(mod._draw_ticks or 0))
	add("geometry drawn: " .. tostring(mod._last_geometry_drawn or 0))
	local floor_diag = mod._floor_diag
	if floor_diag then
		add(string.format("floor: player=%.2f target=%.2f display=%.2f tiers=%d/%d/%d/%d contours=%d stairs=%d hatches=%d ramps=%d",
			floor_diag.player_z or 0, floor_diag.target_z or 0, floor_diag.display_z or 0,
			floor_diag.current or 0, floor_diag.above or 0, floor_diag.below or 0, floor_diag.far_below or 0,
			floor_diag.contours or 0, floor_diag.stairs or 0, floor_diag.hatches or 0, floor_diag.transitions or 0))
	end
	add("element error: " .. tostring(mod._element_error))
	add("objectives: " .. tostring(#_state.objectives) .. "  live gates: " .. tostring(#_state.gates)
		.. "  medicae: " .. tostring(#_state.medicae)
		.. "  supplies: " .. tostring(#_state.supplies) .. "  books: " .. tostring(#_state.books)
		.. "  materials: " .. tostring(#_state.materials))
	add("pickups ammo/grenade/ammo-crate/med-crate/stimm: " .. tostring(#_state.ammo)
		.. "/" .. tostring(#_state.grenades) .. "/" .. tostring(#_state.ammo_crates)
		.. "/" .. tostring(#_state.med_crates) .. "/" .. tostring(#_state.stimms))
	add("marker visibility: " .. tostring(_state.sight_mode) .. "  observers: " .. tostring(#_state.sight_observers))
	add("LoS raycast: " .. (_los_raycast_disabled and ("DISABLED " .. tostring(mod._los_error))
		or (_los_raycast_candidate and "active" or "untested")))
	add("pings: " .. tostring(#_state.pings) .. "  seen/unit/pos/missed: "
		.. tostring(_ping_stats.seen) .. "/" .. tostring(_ping_stats.unit)
		.. "/" .. tostring(_ping_stats.position) .. "/" .. tostring(_ping_stats.missed))
	add("enemies h/e/s/m: " .. #_state.enemies.horde .. "/" .. #_state.enemies.elite
		.. "/" .. #_state.enemies.special .. "/" .. #_state.enemies.monster)
	add("end screen: " .. tostring(_end_screen_seen) .. "  auto-debrief done: " .. tostring(_auto_debrief_done))
	add("compat: status=" .. compat_status_name() .. "  rev=" .. tostring(_compat_revision)
		.. "  consumers=" .. tostring(_compat_consumer_count)
		.. "  geometry_only=" .. tostring(_state.geometry_only))

	if mod.expedition_diag_lines then
		safe(function()
			mod.expedition_diag_lines(add)
		end)
	end

	if mod.report_diag_lines then
		safe(function()
			mod.report_diag_lines(add)
		end)
	end

	return lines
end

local function write_diag_file()
	local io_lib = get_io()
	local file = io_lib and io_lib.open(DIAG_PATH, "w")

	if not file then
		return
	end

	local lines = diag_lines()

	for i = 1, #lines do
		file:write(lines[i] .. "\n")
	end

	file:close()
end

mod:command("strikemap_diag", "print strikemap diagnostic state", function()
	local lines = diag_lines()

	for i = 1, #lines do
		mod:echo(lines[i])
	end

	safe(write_diag_file)
end)

-- ---------------------------------------------------------------------------
-- Lifecycle: detect entering/leaving mission gameplay by polling managers
-- (gameplay modules must not be required at mod top level or the whole
-- script dies in the menu).
-- ---------------------------------------------------------------------------
local function clear_live_markers()
	-- Drop any sweep in flight: it holds references to the outgoing lists and
	-- would publish a previous mission's markers over the cleared state.
	Scan.job = nil
	Scan.recycle = nil
	_medicae_timer = 0

	_state.objectives = {}
	_state.objective_lines = {}
	_state.objective_events = {}
	_state.gates = {}
	_state.pings = {}
	_state.medicae = {}
	_state.supplies = {}
	_state.books = {}
	_state.ammo = {}
	_state.grenades = {}
	_state.ammo_crates = {}
	_state.med_crates = {}
	_state.stimms = {}
	_state.materials = {}
	_state.sight_observers = {}
	_state.enemies = { horde = {}, elite = {}, special = {}, monster = {} }
	_pings_by_key = {}
	_sight_refresh_due = false
end

local function reset_state()
	_state.active = false
	_state.mission = nil
	_state.map = nil
	_state.exp_revision = nil
	_state.fullmap = false
	_state.fullmap_zoom = 1
	_state.fullmap_pitch_idx = 2
	_state.geometry_only = false
	_state.sight_mode = "team_los"
	_state.mission_time = 0
	clear_live_markers()
	clear_gate_tracking()
	clear_objective_tracking()
	compat_clear_context()
	_ping_stats = { seen = 0, unit = 0, position = 0, missed = 0 }
	_load_attempts = 0
	_objective_timer = 0
	_gate_timer = 0
	_medicae_timer = 0
	_refresh_timer = 0
	_enemy_timer = 0
	_notified_no_map = false
	_diag_timer = 0
	_diag_written = false
	_mission_time = 0
	_end_screen_seen = false
	_auto_debrief_at = nil
	_auto_debrief_done = false
	mod._auto_replay_pending = nil

	-- Leaving the mission: let go of any popup widgets we were suppressing â€”
	-- they belong to the outgoing HUD, and holding them would keep it alive.
	restore_dialogue_popup()

	if mod.expedition_reset then
		safe(mod.expedition_reset)
	end

	restore_dialogue_popup()
end

local function current_mission_name()
	local mission = Managers and Managers.state and Managers.state.mission
	return mission and mission:mission_name()
end

function mod.update(dt)
	tick_settings_snapshot(dt)

	local mission_name = safe(current_mission_name)

	if not mission_name or mission_name == "hub_ship" then
		if _state.mission then
			if mod.report_finalize then
				safe(mod.report_finalize)
			end
			reset_state()
		end
		return
	end

	if mission_name ~= _state.mission then
		reset_state()
		_state.mission = mission_name
	end

	-- The panel is active in any mission; map geometry is optional (missions
	-- missing from the dataset fall back to a geometry-less radar).
	_state.active = true
	_mission_time = _mission_time + dt
	_state.mission_time = _mission_time

	-- An external renderer can take over the live HUD without affecting map
	-- loading, the compatibility API, report capture or navmesh recording.
	local geometry_only = compat_geometry_only_enabled()

	if geometry_only ~= _state.geometry_only then
		_state.geometry_only = geometry_only
		_objective_timer = 0
		_gate_timer = 0
		_medicae_timer = 0
		_refresh_timer = 0
		_enemy_timer = 0

		if geometry_only then
			compat_log_once("geometry_only", "Geometry-only mode active.")
			_state.fullmap = false
			clear_live_markers()
			clear_gate_tracking()
			clear_objective_tracking()
		end
	end

	-- Nothing on the marker pipeline (enemy scans, occlusion rays, gate and
	-- objective sweeps, ping refresh) is worth paying for while no map is on
	-- screen. Debrief capture keeps running through the cheap report path
	-- below, exactly as it does in geometry-only mode.
	local markers_wanted = panel_shown() or _state.fullmap == true
	local hud_active = not geometry_only and markers_wanted

	if hud_active ~= _markers_live then
		_markers_live = hud_active

		if hud_active then
			-- Repopulate on the next update rather than showing a stale frame.
			_enemy_timer = 0
			_gate_timer = 0
			_objective_timer = 0
		else
			clear_live_markers()
		end
	end

	-- Expeditions have no baked per-mission map: geometry is composed from
	-- known tiles and painted live by the nav scanner instead. The returned
	-- table grows in place; a fresh table appears after a section transition.
	local expedition_map = mod.expedition_update
		and safe(function()
			return mod.expedition_update(dt, mission_name)
		end)

	if expedition_map then
		if _state.map ~= expedition_map then
			-- new section (or first activation): retire any context built on
			-- the previous geometry
			compat_clear_context()
			_state.map = expedition_map
			_state.exp_revision = nil
		end

		-- Live geometry grew: refresh the shared compat context in place and
		-- bump the revision so consumers re-read counts/bounds.
		local revision = expedition_map.revision or 0

		if _compat_context and _state.exp_revision ~= revision then
			local refreshed = safe(function()
				local bounds = mod.map_bounds(expedition_map)

				if not bounds then
					return false
				end

				local fresh = build_compat_context(mission_name, expedition_map)

				_compat_revision = _compat_revision + 1
				_compat_context.revision = _compat_revision
				_compat_context.tri_count = fresh.tri_count
				_compat_context.spatial_index = fresh.spatial_index
				_compat_context.bounds = bounds
				_compat_context.minimum_z = bounds.z0
				_compat_context.maximum_z = bounds.z1

				return true
			end)

			if refreshed then
				_state.exp_revision = revision
			end
		end
	elseif not _state.map and _load_attempts < MAP_LOAD_ATTEMPTS then
		_load_attempts = _load_attempts + 1
		_state.map = try_load_map(mission_name)

		if not _state.map and _load_attempts == MAP_LOAD_ATTEMPTS then
			compat_log_once("no_map_" .. mission_name,
				"No map geometry is available for the current mission.")

			if mission_name ~= "shooting_range" and not _notified_no_map
				and not (mod.expedition_active and mod.expedition_active()) then
				_notified_no_map = true
				safe(function()
					mod:notify(mod:localize("no_map_data") .. " (" .. tostring(mission_name) .. ")")
				end)
			end
		end
	end

	compat_refresh_context(mission_name)

	-- The first live context was built from this exact revision. Recording it
	-- here avoids a redundant revision bump on the following frame.
	if expedition_map and _compat_context and _state.exp_revision == nil then
		_state.exp_revision = expedition_map.revision or 0
	end

	if hud_active then
		_gate_timer = _gate_timer - dt
		if _gate_timer <= 0 then
			_gate_timer = GATE_SCAN_TICK
			safe(collect_live_gates)
		end

		_objective_timer = _objective_timer - dt
		if _objective_timer <= 0 then
			_objective_timer = 0.4
			safe(collect_objectives)
		end

		-- A sweep in progress keeps stepping every frame until it completes; the
		-- timer only decides when the NEXT one starts. Pickup distribution
		-- completes after medicae stations already exist and deployables can
		-- appear at any time, so keep a modest live rescan cadence.
		if Scan.job then
			pcall(Scan.step)
		else
			_medicae_timer = _medicae_timer - dt

			if _medicae_timer <= 0 then
				_medicae_timer = 5
				pcall(Scan.step)
			end
		end

		_refresh_timer = _refresh_timer - dt
		if _refresh_timer <= 0 then
			_refresh_timer = 2
			safe(refresh_level_units)
		end
	end

	_enemy_timer = _enemy_timer - dt
	if _enemy_timer <= 0 then
		_enemy_timer = _settings_cache.enemy_tick or ENEMY_TICK

		if hud_active then
			safe(collect_enemies)
			-- LoS raycasts are the most expensive calls the mod makes, and enemy
			-- positions only change on this tick â€” refreshing visibility any faster
			-- than ENEMY_TICK is pure waste (worst exactly during hordes).
			_sight_refresh_due = true
		elseif get_setting("record_reports", true) ~= false then
			safe(collect_report_enemies)
		end
	end

	if mod.report_tick then
		pcall(mod.report_tick, dt, mission_name, _state.map)
	end

	safe(auto_debrief_tick)

	if hud_active then
		safe(refresh_pings)

		if _sight_refresh_due then
			_sight_refresh_due = false
			safe(refresh_sight_visibility)
		end
	end

	safe(suppress_dialogue_popup)

	-- One-shot diag file ~12s into the mission so a failed first run can be
	-- debugged from disk without the user typing anything.
	if not _diag_written and _mission_time > 12 then
		_diag_written = true
		safe(write_diag_file)
	end
end

function mod.on_game_state_changed(status, state_name)
	if state_name == "StateLoading" or state_name == "StateMainMenu" then
		reset_state()
	end
end

function mod.on_disabled()
	reset_state()
	restore_dialogue_popup()
end

-- Exposed for the offline LuaJIT test harness (tools/verify_mod.py); unused in game.
mod.__test = {
	state = _state,
	scan_running = function()
		return Scan.job ~= nil
	end,
	reset_scan = function()
		Scan.job = nil
		Scan.recycle = nil
		_medicae_timer = 0
	end,
	-- Single-frame sweep, bypassing the per-frame slice budget.
	full_scan = function()
		Scan.job = nil

		return Scan.step(true)
	end,
	parse_map = parse_map,
	load_lua_table_file = load_lua_table_file,
	classify_tags = classify_tags,
	enemy_type_from_breed = enemy_type_from_breed,
	diag_lines = diag_lines,
	should_suppress_dialogue_popup = should_suppress_dialogue_popup,
	should_suppress_objective_feed = should_suppress_objective_feed,
	collect_live_gates = collect_live_gates,
	clear_gate_tracking = clear_gate_tracking,
	collect_objectives = collect_objectives,
	clear_objective_tracking = clear_objective_tracking,
	push_objective_event = push_objective_event,
	suppress_dialogue_popup = suppress_dialogue_popup,
	restore_dialogue_popup = restore_dialogue_popup,
	update_hud_with_suppression = update_hud_with_suppression,
	track_smart_tag_ping = track_smart_tag_ping,
	release_smart_tag_ping = release_smart_tag_ping,
	refresh_pings = refresh_pings,
	on_mission_end_screen = on_mission_end_screen,
}
