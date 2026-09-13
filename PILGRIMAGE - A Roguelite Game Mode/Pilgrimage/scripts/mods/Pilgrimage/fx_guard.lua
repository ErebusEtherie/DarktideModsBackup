-- fx_guard.lua
--
-- Stops boon visual effects from crashing missions whose packages do not
-- contain them.
--
-- ===========================================================================
-- THE CRASH THIS FIXES (2026-08-05, mid-mission, core_research)
-- ===========================================================================
--
--   WorldApi create_particles failed, Particle effect '#ID[...]' not loaded
--     fx_system.lua:397 trigger_vfx
--     hordes_elementalist_family_buff_templates.lua:88 proc_func
--
-- The boon hordes_buff_shock_on_blocking_melee_attack procced on a block and
-- asked for content/fx/particles/player_buffs/buff_electricity_one_target_01.
-- That particle ships inside the Mortis Trials level packages and NOTHING
-- ELSE. In a normal mission it is simply not on disk-in-memory, and asking
-- the engine to spawn a particle it never loaded is a hard Lua error in C,
-- sixty fixed frames deep in the buff system: the mission dies on the spot.
--
-- The icon situation all over again, but where icons degrade to a
-- placeholder, particles ASSERT. And unlike the icons there is no package we
-- can politely keep resident: the FX live in the horde LEVEL packages (the
-- Lua-visible package list has no fx packages at all), and loading a whole
-- level package into a running mission is not a thing we should do.
--
-- So: RESIDENCY-GATE THE SPAWN. Every particle a hordes buff can spawn goes
-- through one of four choke points; each gets a hook that skips the spawn
-- when the particle is PROVABLY not loadable, and changes nothing otherwise.
-- The boon keeps its mechanics (the damage, the stagger, the buff itself all
-- still happen); only the cosmetic flash is missing, and the skip is
-- recorded so /pil_mutators can say exactly which effects were suppressed.
--
-- ===========================================================================
-- THE FOUR CHOKE POINTS, AND WHY EACH NEEDS ITS OWN GATE
-- ===========================================================================
--
--   1. FxSystem.trigger_vfx (the crash site). Fire-and-forget, returns
--      nothing. Skipping is trivially safe and also skips the client RPC,
--      which nobody is listening to in a solo session anyway.
--
--   2. PlayerUnitFxExtension.spawn_particles. Gating deeper (at
--      World.create_particles) is NOT enough here: the function goes on to
--      call World.find_particles_variable with the particle NAME, which can
--      fault on a missing particle just like create. Skipping the whole
--      function is safe because it already returns nil routinely (every
--      resimulation frame), so every caller in the game tolerates nil.
--
--   3. PlayerUnitBuffExtension.start_on_screen_effect. Stores the particle
--      id in a list whose STOP path calls the engine with each stored id.
--      A gated create would store nil and fault later at stop time, so the
--      skip has to happen before the store.
--
--   4. World.create_particles itself, the deep net. Two legendary hordes
--      templates call it RAW from inside their buff logic
--      (hordes_legendary_generic_buff_templates.lua:643,690). Their stored
--      ids are nil-guarded on stop, so returning nil there is safe. This
--      net also covers any hordes spawn path the enumeration above missed:
--      a skipped spawn is strictly better than the guaranteed crash the
--      same call would otherwise be.
--
-- ===========================================================================
-- THE GATE ITSELF
-- ===========================================================================
--
-- Application.can_get_resource("particles", name), the same probe idea the
-- icon work proved out for textures and materials. Only an explicit FALSE
-- blocks a spawn; true, nil, or a probe error all mean "behave exactly as
-- vanilla", so on any install where probing misbehaves the mod changes
-- nothing. Verdicts are cached per name: World.create_particles is hot, and
-- one engine probe per UNIQUE particle name per session is the entire cost.

local M = {}

local _mod
local _hooks
local _event_log
local _shared
-- Declared at the top, above every function, because a Lua function only
-- captures locals that exist above its definition (the v0.14.1 boons lesson).
local _debug_log

-- name -> true (spawnable or unknown: leave vanilla alone) / false (provably
-- missing: skip). Cleared never; residency of level packages does not change
-- mid-mission, and a stale "false" after a /reload costs one missing flash.
local _verdicts = {}

-- name -> how many spawns were skipped, plus a running total, for reporting.
local _skipped = {}
local _total_skipped = 0

local function _enabled()
	if not _mod or type(_mod.get) ~= "function" then return true end
	local ok, value = pcall(_mod.get, _mod, "fx_guard")
	if not ok or value == nil then return true end
	return value == true
end

-- true = let the engine have it, false = skip. Never false on uncertainty.
local function _resource_ok(kind, name)
	if type(name) ~= "string" or name == "" then return true end

	local key = kind .. "\31" .. name
	local verdict = _verdicts[key]
	if verdict ~= nil then return verdict end

	verdict = true
	local app = rawget(_G, "Application")
	if app and type(app.can_get_resource) == "function" then
		local ok, result = pcall(app.can_get_resource, kind, name)
		if ok and result == false then
			verdict = false
		end
	end

	_verdicts[key] = verdict
	return verdict
end

function M.particle_ok(name)
	return _resource_ok("particles", name)
end

-- ===========================================================================
-- v0.25.1: FULL VISUALS via the Mortis level package.
-- ===========================================================================
--
-- Credit where due: augentism (Chaos Wastes at Home) reached out after
-- the beta launch: "you can just load in the entire psykhanium level
-- package in with the mission at the beginning and it just works."
-- Verified against dt-src: the game's OWN LevelLoader loads mission
-- levels through the exact same call (level_loader.lua:57,
-- Managers.package:load(level_name, ref, callback)), so an extra level
-- package resident alongside the mission is the vanilla pattern, not a
-- hack. The package that owns the hordes buff FX is the Mortis Trials
-- level itself.
--
-- The header of this file used to claim "loading a whole level package
-- into a running mission is not a thing we should do". Field evidence
-- from a mod shipping it says otherwise; the claim is withdrawn.
--
-- COMPOSITION with the guard: the load is asynchronous, kicked at
-- mission start. Until it lands, the residency gates keep skipping
-- (crash-proof); the completion callback clears the verdict cache so
-- every effect probes fresh and starts SPAWNING. The guard is the
-- bridge and the net; the package is the cure. Costs a little load
-- time and memory, per augentism "otherwise it's sound"; the
-- fx_full_visuals setting (default on) turns the load off for anyone
-- memory-constrained, leaving pre-v0.25.1 behaviour exactly.
--
-- The package is NOT released afterwards: it is the same package every
-- mission, PackageManager holds it under our reference for the rest of
-- the game session, and re-loading each mission would re-pay the load
-- time for nothing.

local FX_PACKAGE = "content/levels/horde/missions/mission_psykhanium"
local _fx_package_state = "idle"  -- idle | loading | loaded | failed

function M.reset_verdicts()
	_verdicts = {}
end

function M.fx_package_status()
	return _fx_package_state
end

local function _full_visuals_enabled()
	if not _mod or type(_mod.get) ~= "function" then return true end
	local ok, value = pcall(_mod.get, _mod, "fx_full_visuals")
	if not ok or value == nil then return true end
	return value == true
end

-- Called from a Pilgrimage.lua tick while a run mission is up. Idempotent
-- per VM; every failure path leaves the guard doing its old job.
function M.ensure_fx_package()
	if _fx_package_state ~= "idle" then return _fx_package_state end
	if not _full_visuals_enabled() then return "disabled" end
	local Managers = rawget(_G, "Managers")
	local pm = Managers and Managers.package
	if not pm then return "idle" end

	local ok_has, has = pcall(pm.has_loaded, pm, FX_PACKAGE)
	if ok_has and has then
		-- Resident already (this VM reloaded mid-mission, or a previous
		-- mission loaded it and the engine kept it). Fresh verdicts so
		-- the gates notice.
		_fx_package_state = "loaded"
		M.reset_verdicts()
		_debug_log("fx_guard", _shared and _shared.fixed_time() or 0,
			"Mortis FX package already resident; full boon visuals on", 0, "info")
		return _fx_package_state
	end

	local ok_load, err = pcall(function()
		pm:load(FX_PACKAGE, "Pilgrimage_fx", function()
			_fx_package_state = "loaded"
			M.reset_verdicts()
			_debug_log("fx_guard", _shared and _shared.fixed_time() or 0,
				"Mortis FX package loaded; full boon visuals on", 0, "info")
		end)
	end)
	if ok_load then
		_fx_package_state = "loading"
	else
		_fx_package_state = "failed"
		_debug_log("fx_guard", _shared and _shared.fixed_time() or 0,
			"Mortis FX package load failed (" .. tostring(err)
			.. "); residency gates remain the only layer", 0, "warn")
	end
	return _fx_package_state
end

-- For the one boon whose GAMEPLAY (not just visuals) rides an asset: the
-- telekine dome is a spawned UNIT, and spawning an unloaded unit faults the
-- same way an unloaded particle does.
function M.unit_ok(name)
	return _resource_ok("unit", name)
end

local function _note_skip(name, where)
	local count = (_skipped[name] or 0) + 1
	_skipped[name] = count
	_total_skipped = _total_skipped + 1

	-- Say it once per effect, not once per proc. A popular boon can proc
	-- every couple of seconds for a whole mission.
	if count == 1 then
		_debug_log("fx_guard:" .. name, _shared and _shared.fixed_time() or 0,
			"suppressed unloadable particle (" .. tostring(where) .. "): " .. name,
			0, "info")
		if _event_log and _event_log.emit then
			_event_log.emit({
				t = _shared and _shared.fixed_time() or 0,
				event = "fx_suppressed",
				id = _event_log.next_id(),
				particle = name,
				where = tostring(where),
			})
		end
	end
end

function M.status()
	local names = {}
	for name in pairs(_skipped) do names[#names + 1] = name end
	table.sort(names)
	return {
		total = _total_skipped,
		names = names,
		counts = _skipped,
	}
end

-- ---------------------------------------------------------------------------
-- Hook installation. Every handler follows the same shape: enabled and
-- provably missing means skip and record, anything else means call the
-- original untouched.
-- ---------------------------------------------------------------------------

function M.install_fx_system(FxSystem)
	if _hooks.claim(FxSystem, "__pilgrimage_fx_guard") then return end

	_mod:hook(FxSystem, "trigger_vfx", function(func, self, vfx_name, position, optional_rotation)
		if _enabled() and not M.particle_ok(vfx_name) then
			_note_skip(vfx_name, "trigger_vfx")
			return
		end
		return func(self, vfx_name, position, optional_rotation)
	end)
end

function M.install_player_fx(PlayerUnitFxExtension)
	if _hooks.claim(PlayerUnitFxExtension, "__pilgrimage_fx_guard") then return end

	-- Returning nil mirrors the function's own resimulation path, which every
	-- caller already survives.
	_mod:hook(PlayerUnitFxExtension, "spawn_particles", function(func, self, particle_name, ...)
		if _enabled() and not M.particle_ok(particle_name) then
			_note_skip(particle_name, "spawn_particles")
			return nil
		end
		return func(self, particle_name, ...)
	end)
end

function M.install_buff_extension(PlayerUnitBuffExtension)
	if _hooks.claim(PlayerUnitBuffExtension, "__pilgrimage_fx_guard") then return end

	_mod:hook(PlayerUnitBuffExtension, "start_on_screen_effect",
		function(func, self, index, on_screen_effect, stop_type, world)
			if _enabled() and not M.particle_ok(on_screen_effect) then
				_note_skip(on_screen_effect, "on_screen_effect")
				return
			end
			return func(self, index, on_screen_effect, stop_type, world)
		end)
end

-- The buff NODE EFFECTS path (minion ailment visuals like the shock ailment's
-- glow, and some player buff auras). This one cannot be gated by skipping the
-- call or by the World net: _start_node_effects creates a particle and
-- immediately LINKS it to the unit (nil id faults at the link), and
-- _stop_node_effects later re-reads the SAME template table and dereferences
-- an entry it expects _start to have created. The only shape that keeps start
-- and stop consistent is sanitising the template IN PLACE: an entry whose
-- particle is provably missing loses its vfx block (sounds stay), so both
-- passes skip it cleanly forever after. Per-VM, like every template mutation,
-- which is exactly the lifetime residency verdicts have.
function M.install_buff_base(BuffExtensionBase)
	if _hooks.claim(BuffExtensionBase, "__pilgrimage_fx_guard") then return end

	_mod:hook(BuffExtensionBase, "_start_node_effects",
		function(func, self, template_name, node_effects, optional_priority)
			if _enabled() and type(node_effects) == "table" then
				for i = 1, #node_effects do
					local entry = node_effects[i]
					local vfx = entry and entry.vfx
					local particle = vfx and vfx.particle_effect
					if particle and not M.particle_ok(particle) then
						entry.vfx = nil
						_note_skip(particle, "node_effects")
					end
				end
			end
			return func(self, template_name, node_effects, optional_priority)
		end)
end

-- The telekine dome: several classes' grenade boons can draft "warp shield on
-- grenade explosion", but the dome it spawns is the PSYKER's force-field
-- unit, resident only when psyker assets are loaded. Spawning an unloaded
-- unit is the particle crash all over again, so the spawn is gated on unit
-- residency. When suppressed, the boon's dome simply does not appear; its
-- passive grenade replenishment (granted separately by the same buff) still
-- works. This is the ONE boon in the pool whose gameplay, not just visuals,
-- can be reduced outside Mortis Trials.
local DOME_UNIT = "content/characters/player/human/attachments_combat/psyker_shield/shield_sphere_functional"

function M.install_hordes_utilities(HordesBuffsUtilities)
	if _hooks.claim(HordesBuffsUtilities, "__pilgrimage_fx_guard") then return end
	if type(HordesBuffsUtilities.spawn_telekine_dome_at_position) ~= "function" then return end

	_mod:hook(HordesBuffsUtilities, "spawn_telekine_dome_at_position",
		function(func, physics_world, owner_unit, target_position)
			if _enabled() and not M.unit_ok(DOME_UNIT) then
				_note_skip(DOME_UNIT, "telekine_dome")
				return
			end
			return func(physics_world, owner_unit, target_position)
		end)
end

-- World is an engine global, not a required file, so this cannot ride a
-- hook_require fanout; bootstrap calls it directly at init. Note the flat
-- call shape: World.create_particles(world, name, ...), no self.
local _world_hooked = false

function M.install_world()
	if _world_hooked then return end
	local world_api = rawget(_G, "World")
	if type(world_api) ~= "table" or type(world_api.create_particles) ~= "function" then
		return
	end
	_world_hooked = true

	-- pcall'd because World is an engine namespace, not a game class, and a
	-- DMF that refuses to hook it must cost us this one net, not the mod.
	-- The three class-level hooks still cover every enumerated spawn path.
	local ok, err = pcall(function()
		_mod:hook(world_api, "create_particles", function(func, world, name, ...)
			if _enabled() and not M.particle_ok(name) then
				_note_skip(name, "create_particles")
				return nil
			end
			return func(world, name, ...)
		end)
	end)
	if not ok then
		_world_hooked = false
		_debug_log("fx_guard:world", 0,
			"World.create_particles hook refused: " .. tostring(err), 0, "error")
	end
end

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_hooks = deps.hooks
	_event_log = deps.event_log
	_shared = deps.shared
	_debug_log = deps.debug_log or function() end
end

return M
