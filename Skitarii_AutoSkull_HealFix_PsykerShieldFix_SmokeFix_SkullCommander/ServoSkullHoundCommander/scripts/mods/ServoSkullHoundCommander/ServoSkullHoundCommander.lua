local mod = get_mod("ServoSkullHoundCommander")

local CompanionServoSkullAbility = require("scripts/utilities/companion/companion_servo_skull_ability")
local CompanionServoSkullSettings = require("scripts/settings/companion/companion_servo_skull_settings")
local NavQueries = require("scripts/utilities/nav_queries")
local OutlineSettings = require("scripts/settings/outline/outline_settings")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local SpecialRulesSettings = require("scripts/settings/ability/special_rules_settings")

local special_rules = SpecialRulesSettings.special_rules
local STATES = CompanionServoSkullSettings.STATES
local OUTLINE_NAME = "sskc_downed_ally"
local OUTLINE_LAYERS = { "player_outline_knocked_down", "player_outline_knocked_down_reversed_depth" }
local GREEN = { 0.1, 1, 0.2 }
local PI = math.pi
local TWO_PI = PI * 2
local HEAL_LAUNCH_MIN_WIELD = 0.5
local HEAL_LAUNCH_MIN_LOCK = 0.12

local HOUNDS = { chaos_hound = true, chaos_hound_mutator = true, chaos_armored_hound = true }
local TRAPPERS = { renegade_netgunner = true }
local FLAMERS = { renegade_flamer = true, renegade_flamer_mutator = true, cultist_flamer = true }
local SNIPERS = { renegade_sniper = true }
local BOMBERS = { renegade_grenadier = true, cultist_grenadier = true }
local GUNNERS = { renegade_gunner = true, cultist_gunner = true }
local REAPERS = { chaos_ogryn_gunner = true }
local HOUNDMASTERS = { chaos_ogryn_houndmaster = true }
local PLASMA = { renegade_plasma_gunner = true }
local SHOTGUNNERS = { renegade_shocktrooper = true, cultist_shocktrooper = true }
local NON_AGGRESSIVE_LEVELS = { tg_shooting_range = true, om_basic_combat_01 = true }
local BURSTERS = { chaos_poxwalker_bomber = true }
local MUTANTS = { cultist_mutant = true, cultist_mutant_mutator = true }
-- Companion kinds the mod can command. Both the Skitarii servo-skull and the
-- Arbites cyber-mastiff take orders through the very same "unit_threat_companion"
-- contextual tag, so the whole ordering pipeline is shared; only the engagement
-- envelope differs (the dog runs to its target, so line-of-sight style checks are
-- meaningless for it and it must not be sent across the map).
local KIND_SKULL = "skull"
local KIND_DOG = "dog"
local COMPANION_BREED_KIND = { companion_servo_skull = KIND_SKULL, companion_dog = KIND_DOG }
local ARCHETYPE_KIND = { cryptic = KIND_SKULL, adamant = KIND_DOG }

local REVIVE_PRIO_KEYS = {
	veteran = "heal_prio_veteran",
	zealot = "heal_prio_zealot",
	psyker = "heal_prio_psyker",
	ogryn = "heal_prio_ogryn",
	adamant = "heal_prio_adamant",
	cryptic = "heal_prio_cryptic",
	broker = "heal_prio_broker",
}
local DEFAULT_REVIVE_PRIO = 50
local HEAL_LOCK_TIMEOUT = 1.5
local HEAL_SKIP_TIME = 3

mod._outlined = mod._outlined or {}
mod._last_order_t = 0
mod._last_manual_t = -1000
mod._last_outline_t = 0
mod._last_think_t = 0
mod._current_target = nil
mod._target_acquired_t = 0
mod._last_dbg_t = -100
mod._last_dbg_msg = nil
mod._pending_order = nil
mod._await_confirm = nil
mod._targeting_ext = nil
mod._known_tags = mod._known_tags or {}
mod._ctx_why = nil
mod._pending_stale = 0
mod._last_slow_t = -100
mod._last_slow_msg = nil
mod._launch_heal = nil
mod._suppress_hold = false
mod._heal_wield_t = nil
mod._heal_wield_last = nil
mod._heal_aligned_since = nil
mod._heal_aligned_last = nil
mod._heal_aligned_ally = nil
mod._skull_state = nil
mod._panic_latch = false
mod._panic_until = 0
mod._disabler_scan_t = -100
mod._disabler_scan_hit = false
mod._companion_kind = nil
mod._dh_scan_t = -100
mod._dh_scan_hit = false
mod._dh_near = false
mod._dh_latched = false
mod._heal_skip = mod._heal_skip or {}
mod._heal_lock_ally = nil
mod._heal_lock_since = nil
mod._rescue_scan_t = -100
mod._rescue_n = 0
mod._det_stage = nil
mod._det_hold_until = 0
mod._det_last_t = -100
mod._det_close_unit = nil
mod._det_close_since = 0
mod._bleed_unit = nil
mod._bleed_scan_t = -100
mod._bleed_hit = false
mod._cur_los_unit = nil
mod._cur_los_t = 0
mod._cur_los_scan_t = -100
mod._dog_close = false
mod._order_key_t = -100
mod._exec_scan_t = -100
mod._exec_n = 0
mod._manual_target = nil
mod._empty_press_t = -100

pcall(function()
	local pt = OutlineSettings.PlayerUnitOutlineExtension
	if pt and not pt[OUTLINE_NAME] then
		pt[OUTLINE_NAME] = {
			priority = 1,
			color = GREEN,
			material_layers = OUTLINE_LAYERS,
			visibility_check = function(unit)
				return HEALTH_ALIVE[unit] and true or false
			end,
		}
	end
end)

local function _time_main()
	return Managers.time:time("main")
end

local function _now()
	local ok, t = pcall(_time_main)
	if ok and t then
		return t
	end
	return nil
end

local function _main_now()
	local ok, t = pcall(_time_main)
	if ok and t then
		return t
	end
	return 0
end

local function _panic_active()
	if mod._panic_latch then
		return true
	end
	return mod._panic_until > _main_now()
end

-- Checkbox settings added after release read back as nil on profiles saved by an
-- older version, so every new boolean goes through this instead of a bare :get().
local function _opt(key, dflt)
	local v = mod:get(key)
	if v == nil then
		return dflt
	end
	return v
end

local function _fmt(fmt, ...)
	if select("#", ...) == 0 then
		return fmt
	end
	local ok, msg = pcall(string.format, fmt, ...)
	return ok and msg or fmt
end

local function _dbg(t, fmt, ...)
	if not mod:get("debug_enabled") then
		return
	end
	local msg = _fmt(fmt, ...)
	if msg == mod._last_dbg_msg and t - mod._last_dbg_t < 1.0 then
		return
	end
	mod._last_dbg_t = t
	mod._last_dbg_msg = msg
	mod:echo("[SSKC] " .. msg)
end

local function _dbg_slow(t, fmt, ...)
	if not mod:get("debug_enabled") then
		return
	end
	local msg = _fmt(fmt, ...)
	if msg == mod._last_slow_msg and t - mod._last_slow_t < 3.0 then
		return
	end
	mod._last_slow_t = t
	mod._last_slow_msg = msg
	mod:echo("[SSKC] " .. msg)
end

local function _breed_name_body(unit)
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = ude and ude:breed()
	return breed and breed.name
end

local function _breed_name(unit)
	local ok, name = pcall(_breed_name_body, unit)
	return ok and name or nil
end

local function _ctx_body()
	local player = Managers.player and Managers.player:local_player_safe(1)
	if not player then
		return nil, "no local player"
	end
	local unit = player.player_unit
	if not unit or not ALIVE[unit] then
		return nil, "player unit dead/missing"
	end
	local profile = player:profile()
	local arch = profile and profile.archetype and profile.archetype.name
	local kind = arch and ARCHETYPE_KIND[arch]
	if not kind then
		if not mod:get("debug_enabled") then
			return nil, "class has no commandable companion"
		end
		return nil, "archetype is '" .. tostring(arch) .. "' (mod supports 'cryptic' and 'adamant')"
	end
	local gm = Managers.state.game_mode
	if not gm then
		return nil, "no game mode"
	end
	if gm.is_social_hub and gm:is_social_hub() then
		return nil, "social hub"
	end
	if gm.is_prologue_hub and gm:is_prologue_hub() then
		return nil, "prologue hub"
	end
	local spawner = ScriptUnit.has_extension(unit, "companion_spawner_system")
	local companion = spawner and spawner:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
	if not companion and spawner then
		local units = spawner:companion_units()
		companion = units and units[1]
	end
	-- The live unit is authoritative: a Skitarii can carry any of the three skull
	-- variants and the archetype table is only the fallback when nothing spawned yet.
	if companion and ALIVE[companion] then
		kind = COMPANION_BREED_KIND[_breed_name(companion)] or kind
	end
	return { player = player, unit = unit, companion = companion, kind = kind }
end

local function _ctx()
	local ok, ctx, why = pcall(_ctx_body)
	if ok then
		mod._ctx_why = ctx and nil or (why or "unknown")
		return ctx
	end
	mod._ctx_why = "ctx error: " .. tostring(ctx)
	return nil
end

-- Per-companion engagement envelope. The dog is a melee pouncer: it has to physically
-- reach the target, so force field / smoke / wall checks (which model the skull's shot
-- line) are skipped for it, and snipers/bombers get no exemption from the range limit —
-- sending the mastiff down a long corridor for a sniper is a straight loss. The limit is
-- purely the mod's own: the game puts no distance cap on a whistle-ordered target (see
-- companion_dog_target_selection_template, the whistle branch checks only alive + token),
-- so dog_max_distance is free to go as high as the player wants.
-- One reusable table: this is read several times per think tick and nobody holds an
-- envelope across a call that could refill it, so there is no reason to feed the GC.
local ENV = {}

local function _env(ctx)
	if ctx.kind == KIND_DOG then
		ENV.max_d = mod:get("dog_max_distance") or 25
		ENV.cone = mod:get("dog_cone_angle") or 180
		ENV.interval = mod:get("dog_interval") or 4
		ENV.switch = mod:get("dog_switch_interval") or 5
		ENV.check_blocks = false
		ENV.far_exempt = false
		ENV.skip_game_excluded = _opt("dog_skip_game_excluded", true)
		-- Hunter reach: snipers and bombers are worth a run beyond the normal leash,
		-- each up to its own distance (0 = no extension). Rescue reach works the same
		-- way for an enemy that is actively holding a teammate.
		ENV.sniper_d = mod:get("dog_dist_sniper") or 40
		ENV.bomber_d = mod:get("dog_dist_bomber") or 80
		ENV.rescue_d = mod:get("dog_rescue_distance") or 40
		ENV.require_los = _opt("dog_require_los", true)
		ENV.los_hunt_exempt = _opt("dog_los_hunters", true)
		ENV.check_nav = _opt("dog_check_navmesh", true)
		ENV.hold_pin = _opt("dog_hold_pin", true)
		-- Close-combat mode (keybind): leash everything to the close radius and guard
		-- all around — no sniper/bomber trips mid-brawl. Teammate rescue keeps its
		-- full reach: a carried ally is exactly the emergency this mode must not mute.
		if mod._dog_close then
			local close_d = mod:get("dog_close_distance") or 10
			ENV.max_d = math.min(ENV.max_d, close_d)
			ENV.sniper_d = math.min(ENV.sniper_d, close_d)
			ENV.bomber_d = math.min(ENV.bomber_d, close_d)
			ENV.cone = 360
		end
		return ENV
	end
	ENV.max_d = mod:get("auto_max_distance") or 40
	ENV.cone = mod:get("auto_cone_angle") or 360
	ENV.interval = mod:get("auto_interval") or 1
	ENV.switch = mod:get("switch_interval") or 3
	ENV.check_blocks = true
	ENV.far_exempt = true
	ENV.skip_game_excluded = false
	ENV.sniper_d = 0
	ENV.bomber_d = 0
	ENV.rescue_d = 0
	ENV.require_los = false
	ENV.los_hunt_exempt = true
	ENV.check_nav = false
	ENV.hold_pin = false
	return ENV
end

-- Breeds the game itself keeps the mastiff away from in its own target selection
-- (Poxbursters, gunships, hazards). A whistle order bypasses that filter, so honour it here.
local function _game_excluded_breed(breed)
	local pounce = breed and breed.companion_pounce_setting
	return pounce and pounce.ignore_target_selection or false
end

local function _skull_go_field_body(skull_unit, field)
	if not ALIVE[skull_unit] then
		return nil
	end
	local gs = Managers.state.game_session:game_session()
	local goid = Managers.state.unit_spawner:game_object_id(skull_unit)
	if not gs or not goid or not GameSession.game_object_exists(gs, goid) then
		return nil
	end
	return GameSession.game_object_field(gs, goid, field)
end

local function _skull_go_field(skull_unit, field)
	local ok, v = pcall(_skull_go_field_body, skull_unit, field)
	if ok then
		return v
	end
	return nil
end

local function _ff_blocked_body(from, to)
	local ffs = Managers.state.extension:system("force_field_system")
	if not ffs then
		return false
	end
	local map = ffs._unit_to_extension_map
	if not map then
		error("force_field_system has no _unit_to_extension_map")
	end
	if not next(map) then
		return false
	end
	local diff = to - from
	local len = Vector3.length(diff)
	if len < 0.05 then
		return false
	end
	local dir = diff / len
	local steps = math.clamp(math.ceil(len / 0.5), 2, 120)
	for unit, ext in pairs(map) do
		if ALIVE[unit] and ext.is_unit_colliding then
			local inside_from = ext:is_unit_colliding(from, 0.3, true) and true or false
			local inside_to = ext:is_unit_colliding(to, 0.3, true) and true or false
			if inside_from or inside_to then
				return true
			end
			if not inside_from and not inside_to then
				for i = 1, steps - 1 do
					local p = from + dir * (len * i / steps)
					if ext:is_unit_colliding(p, 0.3, true) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function _ff_blocked(from, to)
	local ok, blocked = pcall(_ff_blocked_body, from, to)
	if not ok then
		local t = _now()
		if t then
			_dbg_slow(t, "force-field check ERRORED (%s) — treating as not blocked", blocked)
		end
	end
	return ok and blocked or false
end

local function _smoke_blocked_body(from, to, skull_unit)
	local sfs = Managers.state.extension:system("smoke_fog_system")
	if not sfs then
		return false
	end
	if not sfs.check_fog_los then
		error("smoke_fog_system has no check_fog_los")
	end
	return sfs:check_fog_los(from, to, skull_unit, true) and true or false
end

local function _smoke_blocked(from, to, skull_unit)
	local ok, blocked = pcall(_smoke_blocked_body, from, to, skull_unit)
	if not ok then
		local t = _now()
		if t then
			_dbg_slow(t, "smoke check ERRORED (%s) — treating as not blocked", blocked)
		end
	end
	return ok and blocked or false
end

local function _wall_blocked_body(from, to, target_unit)
	local world = Managers.world:world("level_world")
	local pw = World.physics_world(world)
	local diff = to - from
	local dist = Vector3.length(diff)
	if dist < 0.05 then
		return false
	end
	local dir = diff / dist
	local hit, _, hit_distance, _, actor = PhysicsWorld.raycast(pw, from, dir, dist, "closest", "collision_filter", "filter_minion_line_of_sight_check")
	if not hit then
		return false
	end
	local hit_unit = actor and Actor.unit(actor)
	if hit_unit and hit_unit == target_unit then
		return false
	end
	if hit_distance and dist - hit_distance <= 1.6 then
		return false
	end
	return true
end

local function _wall_blocked(from, to, target_unit)
	local ok, blocked = pcall(_wall_blocked_body, from, to, target_unit)
	return ok and blocked or false
end

local function _charge_gate_body(player_unit)
	local ae = ScriptUnit.has_extension(player_unit, "ability_system")
	if not ae then
		return true
	end
	local charges = ae:remaining_ability_charges("combat_ability") or 0
	local maxc = ae:max_ability_charges("combat_ability") or charges
	local total = charges
	if charges < maxc then
		local rem = ae:remaining_ability_cooldown("combat_ability") or 0
		local maxcd = ae:max_ability_cooldown("combat_ability") or 0
		local progress = maxcd > 0 and math.clamp(1 - rem / maxcd, 0, 1) or 0
		total = charges + progress
	end
	local wanted = (mod:get("gate_charges") or 1) + (mod:get("gate_percent") or 1) / 100
	-- Without the extra-charge talents (Redline / Power Generation) the reserve
	-- can never reach a threshold above the build's own maximum, which would
	-- silence auto-attack for good. Clamp to the live max so the high options
	-- just mean "keep a full bar" until the talent granting those charges is taken.
	local threshold = math.min(wanted, maxc)
	return total >= threshold, total, threshold, wanted, maxc
end

local function _charge_gate_ok(player_unit)
	if not mod:get("gate_enabled") then
		return true
	end
	local ok, res, total, threshold, wanted, maxc = pcall(_charge_gate_body, player_unit)
	if ok then
		return res, total, threshold, wanted, maxc
	end
	return true
end

-- Positions via Unit.world_position on purpose: this runs from the order-key keybind
-- callback too, where POSITION_LOOKUP values arrive as raw userdata that Vector3
-- arithmetic rejects (the pcall wrapper would silently disable the guard).
local function _teammate_within_body(epos, radius)
	local local_player = Managers.player:local_player_safe(1)
	for _, p in pairs(Managers.player:players()) do
		if p ~= local_player then
			local u = p.player_unit
			if u and HEALTH_ALIVE[u] then
				local up = Unit.world_position(u, 1)
				if up and Vector3.distance(epos, up) < radius then
					return true
				end
			end
		end
	end
	return false
end

local function _teammate_within(epos, radius)
	local ok, res = pcall(_teammate_within_body, epos, radius)
	return ok and res or false
end

local function _unaggroed_body(unit)
	local gs = Managers.state.game_session:game_session()
	local goid = Managers.state.unit_spawner:game_object_id(unit)
	if not gs or not goid or not GameSession.game_object_exists(gs, goid) then
		return false
	end
	if GameSession.has_game_object_field and not GameSession.has_game_object_field(gs, goid, "target_unit_id") then
		return false
	end
	return GameSession.game_object_field(gs, goid, "target_unit_id") == NetworkConstants.invalid_game_object_id
end

local function _unaggroed(unit)
	local ok, res = pcall(_unaggroed_body, unit)
	return ok and res or false
end

local function _aimed_unit_body(player_unit)
	local ste = ScriptUnit.has_extension(player_unit, "smart_targeting_system")
	local td = ste and ste:smart_tag_targeting_data()
	return td and td.unit
end

local function _aimed_unit(player_unit)
	local ok, unit = pcall(_aimed_unit_body, player_unit)
	return ok and unit or nil
end

local function _is_enemy_body(player_unit, unit)
	local side_sys = Managers.state.extension:system("side_system")
	return side_sys and side_sys:is_enemy(player_unit, unit) or false
end

local function _is_enemy(player_unit, unit)
	local ok, res = pcall(_is_enemy_body, player_unit, unit)
	return ok and res or false
end

-- Charge-gate override scan. Skull-only by construction: the charge gate exists only
-- with the Improved Tagging talent (a Cryptic special rule), so the skull's own threat
-- distance sliders are the right ones to read here even after the per-companion split.
local function _disabler_scan_body(ctx)
	local side_sys = Managers.state.extension:system("side_system")
	local side = side_sys and side_sys:get_side_from_name(side_sys:get_default_player_side_name())
	local enemies = side and side:relation_units("enemy")
	local ppos = POSITION_LOOKUP[ctx.unit]
	if not enemies or not ppos then
		return false
	end
	local d_trapper = mod:get("dist_trapper") or 15
	local d_hound = mod:get("dist_hound") or 15
	local ignore_un = mod:get("ignore_unaggroed")
	for i = 1, #enemies do
		local e = enemies[i]
		if HEALTH_ALIVE[e] then
			local name = _breed_name(e)
			if name and (TRAPPERS[name] or HOUNDS[name]) then
				local epos = POSITION_LOOKUP[e]
				local d = epos and Vector3.distance(ppos, epos)
				if d and d <= (TRAPPERS[name] and d_trapper or d_hound) then
					if not ignore_un or not _unaggroed(e) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function _disabler_in_range(t, ctx)
	if t - mod._disabler_scan_t < 0.3 then
		return mod._disabler_scan_hit
	end
	mod._disabler_scan_t = t
	local ok, hit = pcall(_disabler_scan_body, ctx)
	mod._disabler_scan_hit = ok and hit or false
	return mod._disabler_scan_hit
end

-- The "witch" breed tag is what the game itself checks for daemonhosts (both the regular
-- and the mutator one), so it stays right if a new variant is ever added.
local function _is_daemonhost_body(unit)
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = ude and ude:breed()
	local tags = breed and breed.tags
	return tags and tags.witch or false
end

local function _is_daemonhost(unit)
	local ok, res = pcall(_is_daemonhost_body, unit)
	return ok and res or false
end

-- Fail-CLOSED awake probe for daemonhosts. _unaggroed fails toward "has a target"
-- (safe where it engages protection), which is exactly the WRONG direction for
-- authorizing an attack: here every unreadable state counts as "asleep, hands off".
local function _dh_awake_body(unit)
	local gs = Managers.state.game_session:game_session()
	local goid = Managers.state.unit_spawner:game_object_id(unit)
	if not gs or not goid or not GameSession.game_object_exists(gs, goid) then
		return false
	end
	if GameSession.has_game_object_field and not GameSession.has_game_object_field(gs, goid, "target_unit_id") then
		return false
	end
	local id = GameSession.game_object_field(gs, goid, "target_unit_id")
	return id ~= nil and id ~= NetworkConstants.invalid_game_object_id
end

local function _dh_awake(unit)
	local ok, res = pcall(_dh_awake_body, unit)
	return ok and res or false
end

-- True while the mod refuses to point the companion at this daemonhost at all.
local function _dh_order_blocked(unit)
	if not _is_daemonhost(unit) then
		return false
	end
	-- A sleeping daemonhost is never a legal aim-switch target, whatever the settings.
	if not _dh_awake(unit) then
		return true
	end
	-- Awake: the opt-in slider unlocks it; otherwise the auto guard decides.
	if (mod:get("dh_awake_prio") or 0) > 0 then
		return false
	end
	return _opt("dh_block_auto", true)
end

local function _dh_scan_body(ctx)
	local side_sys = Managers.state.extension:system("side_system")
	local side = side_sys and side_sys:get_side_from_name(side_sys:get_default_player_side_name())
	local enemies = side and side:relation_units("enemy")
	local ppos = POSITION_LOOKUP[ctx.unit]
	if not enemies or not ppos then
		return false
	end
	-- A little hysteresis on the way out, so walking along the edge of the radius does
	-- not flap the protection (and its chat notification) on and off.
	local radius = (mod:get("dh_dist") or 25) + (mod._dh_latched and 3 or 0)
	local include_sleeping = _opt("dh_include_sleeping", false)
	for i = 1, #enemies do
		local e = enemies[i]
		if HEALTH_ALIVE[e] and _is_daemonhost(e) then
			local epos = POSITION_LOOKUP[e]
			local d = epos and Vector3.distance(ppos, epos)
			if d and d <= radius and (include_sleeping or not _unaggroed(e)) then
				return true
			end
		end
	end
	return false
end

local function _dh_in_range(t, ctx)
	if t - mod._dh_scan_t < 0.3 then
		return mod._dh_scan_hit
	end
	mod._dh_scan_t = t
	local ok, hit = pcall(_dh_scan_body, ctx)
	mod._dh_scan_hit = ok and hit or false
	return mod._dh_scan_hit
end

-- Only one mastiff may pin a given enemy: the pin is gated by a per-target "pounced"
-- token, and the server aborts the approach outright when another dog holds it. The
-- token table is private but the assign/free RPCs keep it filled on clients too, so
-- this is replicated state — just unofficial, hence the pcall wrapper at the call site.
local function _pin_owner_body(unit)
	local te = ScriptUnit.has_extension(unit, "token_system")
	local owned = te and te._owned_tokens
	return owned and owned.pounced or nil
end

local function _pin_owner(unit)
	if not unit or not ALIVE[unit] then
		return nil
	end
	local ok, owner = pcall(_pin_owner_body, unit)
	if not ok or not owner then
		return nil
	end
	-- A token whose owner died mid-approach is stale: the server re-assigns it to the
	-- next dog that asks, so treating it as "pinned by another mastiff" would block a
	-- perfectly orderable target for as long as it lives.
	if not HEALTH_ALIVE[owner] then
		return nil
	end
	return owner
end

-- True while our mastiff is already ON this exact unit: pinning it (exclusive token)
-- or biting at point-blank with it as its replicated perception target. In that state
-- the game will not drop the target by itself, so re-ordering it is pure spam — every
-- re-tag replays the marker and the whistle voice line for the whole lobby.
local function _dog_engaged_body(ctx, unit)
	local dog = ctx.companion
	if not dog or not ALIVE[dog] or not unit or not HEALTH_ALIVE[unit] then
		return false
	end
	if _pin_owner(unit) == dog then
		return true
	end
	local tid = _skull_go_field(dog, "target_unit_id")
	if not tid or tid == NetworkConstants.invalid_game_object_id then
		return false
	end
	if Managers.state.unit_spawner:unit(tid) ~= unit then
		return false
	end
	local dpos = POSITION_LOOKUP[dog]
	local tpos = POSITION_LOOKUP[unit]
	if not dpos or not tpos then
		return false
	end
	return Vector3.distance(dpos, tpos) < 4
end

local function _dog_engaged(ctx, unit)
	local ok, res = pcall(_dog_engaged_body, ctx, unit)
	return ok and res or false
end

-- Bleed hand-off probe: the pounce damage profiles (and several Adamant talents) apply
-- the stacking "bleed" DoT, and both the enemy's health and its buff list replicate to
-- clients. An engaged victim below the HP threshold with enough bleed stacks is dead
-- on its own — the mastiff is worth more on the next target than watching it expire.
local function _bleed_doomed_body(unit)
	-- Never for monsters/captains: a few bleed stacks cannot finish 10% of a boss's
	-- health pool, and pulling the dog off a latched boss also destroys the
	-- auto-detonation window.
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = ude and ude:breed()
	local tags = breed and breed.tags
	if not tags or tags.monster or tags.captain or tags.cultist_captain then
		return false
	end
	local he = ScriptUnit.has_extension(unit, "health_system")
	if not he or not he.current_health_percent then
		return false
	end
	local hp = he:current_health_percent()
	if not hp or hp * 100 > (mod:get("dog_bleed_hp") or 10) then
		return false
	end
	local be = ScriptUnit.has_extension(unit, "buff_system")
	local buffs = be and be._buffs
	if not buffs then
		return false
	end
	local stacks = 0
	for i = 1, #buffs do
		local b = buffs[i]
		local tpl = b and b._template
		local name = tpl and tpl.name
		if name and string.find(name, "bleed") then
			local bctx = b._template_context
			stacks = stacks + (bctx and bctx.stack_count or 1)
		end
	end
	return stacks >= (mod:get("dog_bleed_stacks") or 5)
end

local function _bleed_doomed(t, unit)
	if mod._bleed_unit == unit and t - mod._bleed_scan_t < 0.5 then
		return mod._bleed_hit
	end
	mod._bleed_unit = unit
	mod._bleed_scan_t = t
	local ok, res = pcall(_bleed_doomed_body, unit)
	mod._bleed_hit = ok and res or false
	return mod._bleed_hit
end

-- The same navmesh probe the dog's own approach runs before moving (ABOVE/BELOW/LATERAL
-- = 1/2/0.3). The server never refuses an order at an off-mesh target — the dog just
-- parks at the nearest reachable point until the 25 s order tag expires — so the client
-- has to do this check itself. Fails open: no nav world (hub, load) means "reachable".
local function _nav_reachable_body(epos)
	local nmm = Managers.state.nav_mesh
	if not nmm then
		return true
	end
	local nav_world = nmm:nav_world()
	if not nav_world then
		return true
	end
	local tl = nmm.client_traverse_logic and nmm:client_traverse_logic() or nil
	return NavQueries.position_on_mesh_with_outside_position(nav_world, tl, epos, 1, 2, 0.3) and true or false
end

local function _nav_reachable(epos)
	local ok, res = pcall(_nav_reachable_body, epos)
	if not ok then
		return true
	end
	return res
end

-- Ally-rescue scan. `disabled_character_state` (including WHO is holding the ally) is
-- replicated to every client through the husk HUD data object — the team panel reads it
-- the same way — so this needs no proximity guessing: it returns the exact hound that
-- pounced, mutant that grabbed, trapper whose net landed, spawn/beast that is eating.
-- The local player is skipped on purpose: while the OWNER is held, the dog's own target
-- selection hard-overrides any order with the owner's disabler already.
local RESCUE_CHECKS = {
	PlayerUnitStatus.is_pounced,
	PlayerUnitStatus.is_mutant_charged,
	PlayerUnitStatus.is_netted,
	PlayerUnitStatus.is_grabbed,
	PlayerUnitStatus.is_consumed,
}

local RESCUE_SET = {}

local function _rescue_scan_body(ctx)
	-- A holder the mastiff can never be ordered at must not look like an emergency:
	-- with the rescue slider at 0 every holder scores 0, and beyond the rescue leash
	-- the pick's range gate drops it — either way it would only latch the emergency
	-- state and disable the switch timer / pin hold for a rescue that cannot happen.
	if (mod:get("dog_prio_rescue") or 100) <= 0 then
		return 0
	end
	local ppos = POSITION_LOOKUP[ctx.unit]
	if not ppos then
		return 0
	end
	local env = _env(ctx)
	local reach = math.max(env.max_d, env.rescue_d)
	local n = 0
	for _, p in pairs(Managers.player:players()) do
		local u = p.player_unit
		if u and u ~= ctx.unit and HEALTH_ALIVE[u] then
			local ude = ScriptUnit.has_extension(u, "unit_data_system")
			local dcs = ude and ude:read_component("disabled_character_state")
			if dcs and dcs.is_disabled then
				for i = 1, #RESCUE_CHECKS do
					local hit, disabler = RESCUE_CHECKS[i](dcs)
					if hit then
						-- A daemonhost holding an ally stays under daemonhost protection —
						-- unless the player opted into fighting awakened daemonhosts (a
						-- grabbing one is awake by definition), in which case the rescue
						-- machinery applies to it like to any other holder.
						if disabler and HEALTH_ALIVE[disabler]
							and (not _is_daemonhost(disabler) or (mod:get("dh_awake_prio") or 0) > 0)
							and ScriptUnit.has_extension(disabler, "smart_tag_system") then
							local dpos = POSITION_LOOKUP[disabler]
							if dpos and Vector3.distance(ppos, dpos) <= reach then
								RESCUE_SET[disabler] = true
								n = n + 1
							end
						end
						break
					end
				end
			end
		end
	end
	return n
end

local function _rescue_units(t, ctx)
	if ctx.kind ~= KIND_DOG or not _opt("dog_rescue_enabled", true) then
		return nil
	end
	if t - mod._rescue_scan_t >= 0.25 then
		mod._rescue_scan_t = t
		for u in pairs(RESCUE_SET) do
			RESCUE_SET[u] = nil
		end
		local ok, n = pcall(_rescue_scan_body, ctx)
		mod._rescue_n = ok and n or 0
	end
	if mod._rescue_n > 0 then
		return RESCUE_SET
	end
	return nil
end

-- Execution Order support. The keystone marks its kill targets by pushing the
-- "adamant_mark_target" outline onto the enemy, and the outline system replicates
-- that to the owning client — OutlineSystem.has_outline is the official query. All
-- currently marked enemies are collected here; the dog's threat table then gives
-- them their own priority (killing marks procs the whole keystone package, and the
-- companion pounce on a mark has its own bonus on top).
local EXEC_SET = {}

local function _exec_scan_body(ctx)
	local osys = Managers.state.extension:system("outline_system")
	if not osys or not osys.has_outline then
		return 0
	end
	local side_sys = Managers.state.extension:system("side_system")
	local side = side_sys and side_sys:get_side_from_name(side_sys:get_default_player_side_name())
	local enemies = side and side:relation_units("enemy")
	if not enemies then
		return 0
	end
	local n = 0
	for i = 1, #enemies do
		local e = enemies[i]
		-- The outline-extension guard is load-bearing: OutlineSystem.has_outline
		-- hard-indexes the extension, and spineless breeds (nurgle flies, the sand
		-- vortex) sit on the enemy side without one — a single such unit would error
		-- the whole scan and silently blind the feature for as long as it lives.
		if HEALTH_ALIVE[e] and ScriptUnit.has_extension(e, "outline_system")
			and osys:has_outline(e, "adamant_mark_target") then
			EXEC_SET[e] = true
			n = n + 1
		end
	end
	return n
end

-- The scan only runs while the local player actually carries the keystone buff: that
-- keeps it free for non-keystone builds and drops the mark set the moment the buff
-- owner no longer exists (marks left outlined by a dead instance stop proccing).
local function _exec_has_keystone_body(unit)
	local be = ScriptUnit.has_extension(unit, "buff_system")
	return be and be:has_buff_using_buff_template("adamant_execution_order") or false
end

local function _exec_refresh(t, ctx)
	if ctx.kind ~= KIND_DOG or not _opt("dog_exec_enabled", true)
		or (mod:get("dog_prio_exec") or 90) <= 0 then
		mod._exec_n = 0
		return
	end
	if t - mod._exec_scan_t >= 0.4 then
		mod._exec_scan_t = t
		for u in pairs(EXEC_SET) do
			EXEC_SET[u] = nil
		end
		local ok_ks, has_ks = pcall(_exec_has_keystone_body, ctx.unit)
		if not ok_ks or not has_ks then
			mod._exec_n = 0
			return
		end
		local ok, n = pcall(_exec_scan_body, ctx)
		mod._exec_n = ok and n or 0
		if not ok then
			_dbg_slow(t, "Execution Order scan ERRORED (%s)", tostring(n))
		end
	end
end

local function _exec_marked(unit)
	return mod._exec_n > 0 and unit and EXEC_SET[unit] or false
end

-- The servo-skull's threat table. Fully separate from the mastiff's: the skull is a
-- gun, so its ranking only cares about how dangerous the enemy is to the player.
local function _score_skull(name, tags, d, epos)
	if BURSTERS[name] then
		if mod:get("burster_never") then
			return 0
		end
		local forbidden = mod:get("dist_burster_forbidden") or 10
		if d < forbidden then
			return 0
		end
		if epos and mod:get("burster_team_radius") and _teammate_within(epos, forbidden) then
			return 0
		end
		return mod:get("prio_burster_far") or 0
	end
	if HOUNDS[name] then
		if d <= (mod:get("dist_hound") or 15) then
			return mod:get("prio_hound_close") or 0
		end
		return mod:get("prio_hound_far") or 0
	end
	if TRAPPERS[name] then
		if d <= (mod:get("dist_trapper") or 15) then
			return mod:get("prio_trapper_close") or 0
		end
		return mod:get("prio_trapper_far") or 0
	end
	if MUTANTS[name] then
		return mod:get("prio_mutant") or 0
	end
	if SNIPERS[name] then
		return mod:get("prio_sniper") or 0
	end
	if BOMBERS[name] then
		return mod:get("prio_bomber") or 0
	end
	local s = 0
	if FLAMERS[name] then
		if d <= (mod:get("dist_flamer") or 15) then
			s = math.max(s, mod:get("prio_flamer_close") or 0)
		else
			s = math.max(s, mod:get("prio_special_other") or 0)
		end
	end
	if SHOTGUNNERS[name] then
		if d <= (mod:get("dist_shotgunner") or 15) then
			s = math.max(s, mod:get("prio_shotgunner_close") or 0)
		else
			s = math.max(s, mod:get("prio_gunner") or 0)
		end
	elseif REAPERS[name] then
		s = math.max(s, mod:get("prio_reaper") or 0)
	elseif PLASMA[name] then
		s = math.max(s, mod:get("prio_plasma") or 0)
	elseif GUNNERS[name] then
		s = math.max(s, mod:get("prio_gunner") or 0)
	end
	if tags.monster or tags.captain or tags.cultist_captain then
		s = math.max(s, mod:get("prio_monster") or 0)
	end
	if s == 0 and tags.elite then
		if d <= (mod:get("dist_elite") or 10) then
			s = mod:get("prio_elite_close") or 0
		else
			s = mod:get("prio_elite_far") or 0
		end
	end
	if s == 0 and tags.special then
		s = mod:get("prio_special_other") or 0
	end
	return s
end

-- The mastiff's own threat table. Its ranking also cares about what the dog can DO to
-- the enemy: everything it can pin (human-sized shooters and specials) ranks like the
-- skull's table, while kick-only breeds (hounds, mutants, ogryn-sized elites, the
-- houndmaster) sit at 0 by default — one kick, leap away, 1.5 s cooldown, start over.
local function _score_dog(name, tags, d, epos)
	if BURSTERS[name] then
		-- Only reachable with 'skip targets the game keeps it away from' turned off.
		-- The kick on a Poxburster deals zero damage (safe knockback), but the
		-- forbidden radius still applies: a knockback TOWARD someone helps nobody.
		if _opt("dog_burster_never", false) then
			return 0
		end
		local forbidden = mod:get("dog_dist_burster_forbidden") or 10
		if d < forbidden then
			return 0
		end
		if epos and mod:get("burster_team_radius") and _teammate_within(epos, forbidden) then
			return 0
		end
		return mod:get("dog_prio_burster_far") or 0
	end
	-- Kick-only breeds first. A hound/mutant actually holding an ally never reaches
	-- these lines — the rescue branch in _score catches it earlier.
	if HOUNDS[name] then
		return mod:get("dog_prio_hound") or 0
	end
	if MUTANTS[name] then
		return mod:get("dog_prio_mutant") or 0
	end
	if REAPERS[name] then
		return mod:get("dog_prio_reaper") or 0
	end
	if HOUNDMASTERS[name] then
		-- "pushed_away" breed: the pounce deals zero damage and the dog is shoved
		-- off with 10 s of stagger immunity on the target — a strictly wasted order.
		return mod:get("dog_prio_houndmaster") or 0
	end
	if tags.elite and tags.ogryn then
		-- Crushers / Bulwarks: only scratched with a full re-approach per hit.
		return mod:get("dog_prio_elite_ogryn") or 0
	end
	if TRAPPERS[name] then
		if d <= (mod:get("dog_dist_trapper") or 15) then
			return mod:get("dog_prio_trapper_close") or 0
		end
		return mod:get("dog_prio_trapper_far") or 0
	end
	if SNIPERS[name] then
		return mod:get("dog_prio_sniper") or 0
	end
	if BOMBERS[name] then
		return mod:get("dog_prio_bomber") or 0
	end
	local s = 0
	-- Gunners/plasma/shotgunners carry the elite tag and flamers the special tag, so a
	-- slider zeroed by the user must not resurrect through the generic fallbacks below —
	-- in this table 0 means never. (The skull table keeps its historical behaviour.)
	local matched = false
	if FLAMERS[name] then
		matched = true
		if d <= (mod:get("dog_dist_flamer") or 15) then
			s = math.max(s, mod:get("dog_prio_flamer_close") or 0)
		else
			s = math.max(s, mod:get("dog_prio_special_other") or 0)
		end
	end
	if SHOTGUNNERS[name] then
		matched = true
		if d <= (mod:get("dog_dist_shotgunner") or 15) then
			s = math.max(s, mod:get("dog_prio_shotgunner_close") or 0)
		else
			s = math.max(s, mod:get("dog_prio_gunner") or 0)
		end
	elseif PLASMA[name] then
		matched = true
		s = math.max(s, mod:get("dog_prio_plasma") or 0)
	elseif GUNNERS[name] then
		matched = true
		s = math.max(s, mod:get("dog_prio_gunner") or 0)
	end
	if tags.monster or tags.captain or tags.cultist_captain then
		-- The dog hangs on a Plague Ogryn / Chaos Spawn / Beast for ~1.5 s of
		-- monster-grade bites, but only kicks captains and twins once.
		s = math.max(s, mod:get("dog_prio_monster") or 0)
	end
	if not matched and s == 0 and tags.elite then
		-- Human-sized elites only (Ragers, Maulers...): ogryn-sized ones returned above.
		if d <= (mod:get("dog_dist_elite") or 10) then
			s = mod:get("dog_prio_elite_close") or 0
		else
			s = mod:get("dog_prio_elite_far") or 0
		end
	end
	if not matched and s == 0 and tags.special then
		s = mod:get("dog_prio_special_other") or 0
	end
	return s
end

local function _score(is_dog, rescue, name, tags, d, epos, unit)
	-- An enemy actively holding a teammate outranks its own breed rules: this is the
	-- one moment a hound or mutant IS worth the mastiff's time — knock it off, kill it,
	-- go back to eating rangers. Checked BEFORE the daemonhost branch on purpose: a
	-- daemonhost only enters the rescue set at all when the awakened opt-in is on (see
	-- _rescue_scan_body), and a holder is awake by definition — scoring it here keeps
	-- the rescue priority paired with the rescue gate exemptions.
	if rescue and unit and rescue[unit] then
		return mod:get("dog_prio_rescue") or 100
	end
	if tags.witch then
		-- The awake probe fails CLOSED: any unreadable state counts as sleeping, and a
		-- sleeping daemonhost is never ordered on whatever the settings say (the game
		-- refuses those orders outright anyway).
		local awake = unit and _dh_awake(unit) or false
		-- Opt-in: fight a daemonhost that is already awake (it has a combat target —
		-- someone triggered it anyway), overriding the guard below just for that case.
		local awake_prio = mod:get("dh_awake_prio") or 0
		if awake_prio > 0 and awake then
			return awake_prio
		end
		-- Default is a hard "never". With the guard switched off an awakened daemonhost
		-- falls through to the boss/captain slider.
		if _opt("dh_block_auto", true) then
			return 0
		end
		if not awake then
			return 0
		end
	end
	-- Execution Order mark: killing it procs the whole keystone package, so it gets
	-- its own priority ahead of the breed tables (rescue and the daemonhost guard
	-- above still outrank it). Bursters are excepted: the keystone can mark them
	-- (they carry the special tag), but the burster safety logic in the breed table —
	-- forbidden radius, never-switch, teammate protection — must keep the last word.
	if is_dog and _exec_marked(unit) and not BURSTERS[name] then
		return mod:get("dog_prio_exec") or 90
	end
	if is_dog then
		return _score_dog(name, tags, d, epos)
	end
	return _score_skull(name, tags, d, epos)
end

local function _sort_candidates(a, b)
	if a.score ~= b.score then
		return a.score > b.score
	end
	-- An enemy holding a teammate wins every tie: prio_trapper_close / prio_flamer_close
	-- also default to 100 and the rescue slider cannot be raised above them, so without
	-- this a netgunner standing next to the mastiff would outrank the rescue on distance.
	if a.rescue ~= b.rescue then
		return a.rescue
	end
	-- sort_d is the distance to the COMPANION for the dog (the pack standing next to it
	-- after a far kill comes before an identical enemy back at the player's feet) and
	-- the plain player distance for the skull.
	return a.sort_d < b.sort_d
end

local function _read_camera(player)
	local cm = Managers.state.camera
	local vp = player.viewport_name
	local p = cm:camera_position(vp)
	local rot = cm:camera_rotation(vp)
	if p and rot then
		return p, Quaternion.forward(rot)
	end
	return nil
end

local function _pick_target_body(ctx, ignore_blocks, rescue, exclude_unit)
	local side_sys = Managers.state.extension:system("side_system")
	if not side_sys then
		return nil
	end
	local side = side_sys:get_side_from_name(side_sys:get_default_player_side_name())
	local enemies = side and side:relation_units("enemy")
	if not enemies then
		return nil
	end
	local ppos = POSITION_LOOKUP[ctx.unit]
	if not ppos then
		return nil
	end
	local env = _env(ctx)
	local is_dog = ctx.kind == KIND_DOG
	local max_d = env.max_d
	local hard_cap = max_d
	if env.far_exempt then
		hard_cap = math.max(90, max_d)
	elseif is_dog then
		hard_cap = math.max(max_d, env.sniper_d, env.bomber_d, rescue and env.rescue_d or 0)
	end
	local cone_angle = env.cone
	local cam_pos, cam_fwd, cos_half
	if cone_angle < 360 or env.require_los then
		local ok_cam, p, fwd = pcall(_read_camera, ctx.player)
		if ok_cam and p and fwd then
			cam_pos = p
			cam_fwd = fwd
		end
		if cam_fwd and cone_angle < 360 then
			cos_half = math.cos(math.rad(cone_angle * 0.5))
		end
	end
	local dogpos = is_dog and ctx.companion and ALIVE[ctx.companion] and Unit.world_position(ctx.companion, 1) or nil
	local ignore_un = mod:get("ignore_unaggroed")
	local list = {}
	for i = 1, #enemies do
		local e = enemies[i]
		if e ~= exclude_unit and HEALTH_ALIVE[e] and ScriptUnit.has_extension(e, "smart_tag_system") then
			local ude = ScriptUnit.has_extension(e, "unit_data_system")
			local breed = ude and ude:breed()
			local tags = breed and breed.tags
			local epos = tags and POSITION_LOOKUP[e]
			if epos and not (env.skip_game_excluded and _game_excluded_breed(breed)) then
				local name = breed.name
				local is_rescue = rescue and rescue[e] or false
				local in_cone = true
				-- Rescue targets ignore the view cone (an ally dragged away behind your
				-- back still needs the dog), and so do bombers for the dog: their
				-- grenades arrive from anywhere and hunting them is the mastiff's best job.
				if cos_half and not is_rescue and not (is_dog and BOMBERS[name]) then
					local to_t = (epos + Vector3(0, 0, 1.3)) - cam_pos
					local len = Vector3.length(to_t)
					in_cone = len < 0.05 or Vector3.dot(cam_fwd, to_t / len) >= cos_half
				end
				local d = Vector3.distance(ppos, epos)
				if in_cone and d <= hard_cap then
					local within = d <= max_d
					if not within then
						if env.far_exempt then
							within = SNIPERS[name] or BOMBERS[name] or false
						elseif is_dog then
							within = SNIPERS[name] and d <= env.sniper_d
								or BOMBERS[name] and d <= env.bomber_d
								or is_rescue and d <= env.rescue_d
								or false
						end
					end
					if within then
						local s = _score(is_dog, rescue, name, tags, d, epos, e)
						if s > 0 and (is_rescue or not ignore_un or not _unaggroed(e)) then
							list[#list + 1] = {
								unit = e,
								score = s,
								dist = d,
								name = name,
								sort_d = dogpos and Vector3.distance(dogpos, epos) or d,
								rescue = is_rescue,
								hunter = SNIPERS[name] or TRAPPERS[name] or BOMBERS[name] or false,
								exec = is_dog and _exec_marked(e) or false,
							}
						end
					end
				end
			end
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, _sort_candidates)
	-- The mastiff walks to whatever it is pointed at, so none of the shot-line checks
	-- apply. It has its own gates instead, cheapest first, capped like the skull's:
	-- a target pinned by another mastiff is a wasted order (the pounce token is
	-- exclusive), a target off the navmesh parks the dog until the tag expires (the
	-- server never refuses the order), and an out-of-sight ordinary enemy sends it
	-- around three corners — specials worth hunting (sniper/trapper/bomber) and
	-- rescue targets are exempt from the line-of-sight gate on purpose.
	if not env.check_blocks then
		if not is_dog then
			return list[1]
		end
		local checked = 0
		for i = 1, #list do
			local cand = list[i]
			local tpos = POSITION_LOOKUP[cand.unit]
			if tpos then
				local blocked = false
				if env.hold_pin and not cand.rescue then
					local pin_owner = _pin_owner(cand.unit)
					if pin_owner and pin_owner ~= ctx.companion then
						blocked = true
						if mod:get("debug_enabled") then
							mod:echo("[SSKC] skip (pinned by another mastiff): " .. tostring(cand.name))
						end
					end
				end
				if not blocked and env.check_nav and not cand.rescue and not _nav_reachable(tpos) then
					blocked = true
					if mod:get("debug_enabled") then
						mod:echo("[SSKC] skip (off navmesh): " .. tostring(cand.name))
					end
				end
				if not blocked and env.require_los and cam_pos and not cand.rescue and not cand.exec
					and not (cand.hunter and env.los_hunt_exempt)
					and _wall_blocked(cam_pos, tpos + Vector3(0, 0, 1.3), cand.unit) then
					blocked = true
					if mod:get("debug_enabled") then
						mod:echo("[SSKC] skip (no LOS): " .. tostring(cand.name))
					end
				end
				if not blocked then
					return cand
				end
				checked = checked + 1
				if checked >= 6 then
					return nil
				end
			end
		end
		return nil
	end
	local skull = ctx.companion
	local spos = skull and ALIVE[skull] and Unit.world_position(skull, 1)
	local check_ff = not ignore_blocks and mod:get("auto_block_shield")
	local check_smoke = not ignore_blocks and mod:get("auto_block_smoke")
	if not spos then
		return list[1]
	end
	local checked = 0
	for i = 1, #list do
		local cand = list[i]
		local tpos = POSITION_LOOKUP[cand.unit]
		if tpos then
			tpos = tpos + Vector3(0, 0, 1.3)
			local blocked = false
			if check_ff and _ff_blocked(spos, tpos) then
				blocked = true
				if mod:get("debug_enabled") then
					mod:echo("[SSKC] skip (force field): " .. tostring(cand.name))
				end
			end
			if not blocked and check_smoke and _smoke_blocked(spos, tpos, skull) then
				blocked = true
				if mod:get("debug_enabled") then
					mod:echo("[SSKC] skip (smoke): " .. tostring(cand.name))
				end
			end
			if not blocked and _wall_blocked(spos, tpos, cand.unit) then
				blocked = true
				if mod:get("debug_enabled") then
					mod:echo("[SSKC] skip (no LOS): " .. tostring(cand.name))
				end
			end
			if not blocked then
				return cand
			end
			checked = checked + 1
			if checked >= 6 then
				return nil
			end
		end
	end
	return nil
end

local function _pick_target(ctx, ignore_blocks, rescue, exclude_unit)
	local ok, res = pcall(_pick_target_body, ctx, ignore_blocks, rescue, exclude_unit)
	if ok then
		return res
	end
	return nil
end

local function _sort_by_dist(a, b)
	return a.dist < b.dist
end

-- Daemonhost protection, "keep busy" half. An ordered target pins the companion
-- (the whistle target wins over the game's own selection), so the danger window is
-- exactly the moment the mod has nothing to order: the game is then free to pick the
-- awakened daemonhost by itself. This finds the nearest ordinary alerted enemy,
-- ignoring the priority table entirely, purely to keep that window shut.
local function _pick_decoy_body(ctx)
	local side_sys = Managers.state.extension:system("side_system")
	if not side_sys then
		return nil
	end
	local side = side_sys:get_side_from_name(side_sys:get_default_player_side_name())
	local enemies = side and side:relation_units("enemy")
	local ppos = POSITION_LOOKUP[ctx.unit]
	if not enemies or not ppos then
		return nil
	end
	local env = _env(ctx)
	local list = {}
	for i = 1, #enemies do
		local e = enemies[i]
		if HEALTH_ALIVE[e] and ScriptUnit.has_extension(e, "smart_tag_system") then
			local ude = ScriptUnit.has_extension(e, "unit_data_system")
			local breed = ude and ude:breed()
			local tags = breed and breed.tags
			local name = tags and breed.name
			-- Never the daemonhost itself, never a Poxburster (a decoy is not worth a
			-- blast) and never an enemy that has not noticed anyone yet.
			if name and not tags.witch and not BURSTERS[name]
				and not (env.skip_game_excluded and _game_excluded_breed(breed))
				and not _unaggroed(e) then
				local epos = POSITION_LOOKUP[e]
				local d = epos and Vector3.distance(ppos, epos)
				if d and d <= env.max_d then
					list[#list + 1] = { unit = e, score = 1, dist = d, name = name }
				end
			end
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, _sort_by_dist)
	if not env.check_blocks then
		return list[1]
	end
	local companion = ctx.companion
	local spos = companion and ALIVE[companion] and Unit.world_position(companion, 1)
	if not spos then
		return list[1]
	end
	local checked = 0
	for i = 1, #list do
		local cand = list[i]
		local tpos = POSITION_LOOKUP[cand.unit]
		if tpos then
			tpos = tpos + Vector3(0, 0, 1.3)
			local blocked = mod:get("auto_block_shield") and _ff_blocked(spos, tpos)
				or mod:get("auto_block_smoke") and _smoke_blocked(spos, tpos, companion)
				or _wall_blocked(spos, tpos, cand.unit)
			if not blocked then
				return cand
			end
			checked = checked + 1
			if checked >= 6 then
				return nil
			end
		end
	end
	return nil
end

local function _pick_decoy(ctx)
	local ok, res = pcall(_pick_decoy_body, ctx)
	return ok and res or nil
end

local function _score_unit_body(ctx, unit, rescue)
	if not HEALTH_ALIVE[unit] then
		return 0
	end
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = ude and ude:breed()
	local tags = breed and breed.tags
	if not tags then
		return 0
	end
	local ppos = POSITION_LOOKUP[ctx.unit]
	local epos = POSITION_LOOKUP[unit]
	if not ppos or not epos then
		return 0
	end
	local dist = Vector3.distance(ppos, epos)
	local name = breed.name
	local env = _env(ctx)
	local is_dog = ctx.kind == KIND_DOG
	local max_d = env.max_d
	if dist > max_d then
		local far_ok = false
		if env.far_exempt then
			far_ok = SNIPERS[name] or BOMBERS[name] or false
		elseif is_dog then
			far_ok = SNIPERS[name] and dist <= env.sniper_d
				or BOMBERS[name] and dist <= env.bomber_d
				or rescue and rescue[unit] and dist <= env.rescue_d
				or false
		end
		if not far_ok then
			return 0
		end
	end
	if env.skip_game_excluded and _game_excluded_breed(breed) then
		return 0
	end
	local sc = _score(is_dog, rescue, name, tags, dist, epos, unit)
	if sc <= 0 then
		return 0
	end
	if is_dog and not (rescue and rescue[unit]) then
		-- The current target has to keep clearing the exclusive-pin gate: if another
		-- mastiff has since pinned it, our whistle order is dead on arrival and keeping
		-- it as current would only block the re-pick. Our own pin is the opposite case
		-- and is held earlier in _auto_tick.
		if env.hold_pin then
			local pin_owner = _pin_owner(unit)
			if pin_owner and pin_owner ~= ctx.companion then
				return 0
			end
		end
		-- Same reasoning for a target that wandered off the navmesh: re-ordering it
		-- would just park the dog. LOS is deliberately NOT re-checked here — an
		-- in-flight run must survive the player looking away.
		if env.check_nav and not _nav_reachable(epos) then
			return 0
		end
	end
	local skull = ctx.companion
	local spos = env.check_blocks and skull and ALIVE[skull] and Unit.world_position(skull, 1)
	if spos then
		local tpos = epos + Vector3(0, 0, 1.3)
		if mod:get("auto_block_shield") and _ff_blocked(spos, tpos) then
			return 0
		end
		if mod:get("auto_block_smoke") and _smoke_blocked(spos, tpos, skull) then
			return 0
		end
		if _wall_blocked(spos, tpos, unit) then
			return 0
		end
	end
	return sc, dist, name
end

local function _score_unit(ctx, unit, rescue)
	local ok, s, d, nm = pcall(_score_unit_body, ctx, unit, rescue)
	if ok then
		return s or 0, d, nm
	end
	return 0
end

local function _mission_name()
	return Managers.state.mission:mission_name()
end

local function _needs_help_body(unit)
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local cs = ude and ude:read_component("character_state")
	return cs and PlayerUnitStatus.requires_allied_interaction_help(cs) or false
end

-- Whether auto-ordering should pause because of the OWN player's state. The dog uses
-- the wider help set: while its owner is pounced/grabbed/charged/consumed the game's
-- own target selection hard-overrides every order with the owner's disabler, so orders
-- sent in that window are dead on arrival (and the game already handles the rescue).
local function _own_pause_body(unit, kind)
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local cs = ude and ude:read_component("character_state")
	if not cs then
		return false
	end
	if kind == KIND_DOG then
		return PlayerUnitStatus.requires_help(cs) or false
	end
	return PlayerUnitStatus.requires_allied_interaction_help(cs) or false
end

local function _wielded_slot_body(unit)
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local inv = ude and ude:read_component("inventory")
	return inv and inv.wielded_slot
end

local function _has_tag_talent_body(unit)
	local te = ScriptUnit.has_extension(unit, "talent_system")
	return te and te:has_special_rule(special_rules.cryptic_servo_skull_improved_tagging) or false
end

-- Current-target visibility timeout (dog). The pick-time LOS gate only filters NEW
-- targets; one acquired in sight and then gone a floor below or around two corners
-- would keep soaking re-orders forever. Pins, rescue targets and (with their
-- exemption on) hunt specials are never dropped, and the grace period keeps ordinary
-- strafing behind cover from flapping the target. Returns the (possibly zeroed) score.
local CUR_LOS_GRACE = 2.5

local function _cur_los_tick(t, ctx, cur_target, cur_score, rescue, cur_name)
	local env = _env(ctx)
	if not env.require_los or not _opt("dog_los_current", true) then
		return cur_score
	end
	-- In-flight grace: a fresh order needs travel time before the timeout may judge it,
	-- or every longer run would be cancelled the moment the player looks away — churning
	-- exactly the marker/voice-line spam the engaged skip exists to remove.
	if t - mod._target_acquired_t < 4 then
		return cur_score
	end
	if mod._cur_los_unit ~= cur_target then
		mod._cur_los_unit = cur_target
		mod._cur_los_t = t
	end
	if t - mod._cur_los_scan_t >= 0.3 then
		mod._cur_los_scan_t = t
		local keep = false
		local name = _breed_name(cur_target)
		local is_hunter = name and (SNIPERS[name] or TRAPPERS[name] or BOMBERS[name]) or false
		if is_hunter and env.los_hunt_exempt
			or rescue and rescue[cur_target]
			or _exec_marked(cur_target)
			or ctx.companion and _pin_owner(cur_target) == ctx.companion then
			keep = true
		else
			local ok_cam, p = pcall(_read_camera, ctx.player)
			local tpos = POSITION_LOOKUP[cur_target]
			if not ok_cam or not p or not tpos then
				-- Cannot judge visibility: fail open, keep the target.
				keep = true
			elseif not _wall_blocked(p, tpos + Vector3(0, 0, 1.3), cur_target) then
				keep = true
			end
		end
		if keep then
			mod._cur_los_t = t
		end
	end
	if t - mod._cur_los_t > CUR_LOS_GRACE then
		_dbg(t, "current target unseen for %.1fs (%s) — releasing it", CUR_LOS_GRACE, tostring(cur_name))
		return 0
	end
	return cur_score
end

local function _auto_tick(t, ctx)
	local panic = _panic_active()
	if not panic and not mod:get("auto_enabled") then
		_dbg_slow(t, "auto-attack is OFF (auto_enabled=false) — toggle it in settings or with the keybind")
		return
	end
	-- Per-companion switches under the master toggle, so a player of both classes can
	-- automate one companion and keep full manual control of the other.
	if ctx.kind == KIND_DOG and not _opt("dog_auto_enabled", true) then
		_dbg_slow(t, "mastiff auto-attack is switched off (per-companion checkbox in the Cyber-Mastiff group)")
		return
	end
	if ctx.kind == KIND_SKULL and not _opt("skull_auto_enabled", true) then
		_dbg_slow(t, "servo-skull auto-attack is switched off (per-companion checkbox in the Servo-skull group)")
		return
	end
	if panic then
		_dbg_slow(t, "PANIC MODE active — charge gate bypassed, attacking regardless of ability charges")
	end
	local dh_full_stop = _opt("dh_full_stop", false)
	if mod._dh_near and dh_full_stop then
		_dbg_slow(t, "daemonhost protection: auto-attack fully stopped (daemonhost within %d m)", mod:get("dh_dist") or 25)
		return
	end
	local dh_divert = mod._dh_near and _opt("dh_divert", true) and not dh_full_stop
	-- Dog only: enemies currently holding a teammate (hound on top, mutant carrying,
	-- trapper whose net landed, spawn/beast eating). Non-nil only when there is at
	-- least one such enemy right now.
	local rescue = _rescue_units(t, ctx)
	_exec_refresh(t, ctx)
	-- A just-pressed order key holds auto-attack unconditionally for a moment, even
	-- with the manual pause disabled: the explicit press must reach the input poll
	-- before an auto pick can overwrite the single pending-order slot.
	if t - mod._order_key_t < 0.6 then
		_dbg(t, "paused: order-key press in flight")
		return
	end
	if mod:get("manual_pause_enabled") and t - mod._last_manual_t < (mod:get("manual_pause_time") or 2) then
		-- A teammate being held outranks the courtesy pause after a manual order.
		if not rescue then
			_dbg(t, "paused after manual order")
			return
		end
		_dbg(t, "manual-order pause bypassed: an ally is being held by a disabler")
	end
	local ok_mn, mission_name = pcall(_mission_name)
	mission_name = ok_mn and mission_name or nil
	if mission_name and NON_AGGRESSIVE_LEVELS[mission_name] then
		if not mod:get("auto_in_training") then
			_dbg(t, "training area (%s): auto-attack off here; enable 'Attack in training areas' to try", mission_name)
			return
		end
		_dbg(t, "training area (%s): attempting order (may not work — game keeps companion passive here)", mission_name)
	end
	local companion = ctx.companion
	if not companion or not ALIVE[companion] then
		_dbg(t, "companion unit not found via spawner — sending orders anyway")
	elseif ctx.kind == KIND_SKULL then
		-- Only the skull publishes a busy state; the mastiff has no such field and
		-- accepts a new order at any point of its run.
		local state = _skull_go_field(companion, "state")
		if state and state ~= STATES.following and state ~= STATES.following_shooting and state ~= STATES.following_shooting_ability then
			_dbg(t, "skull busy (state %s), skipping", state)
			return
		end
	end
	local ok_cs, own_needs_help = pcall(_own_pause_body, ctx.unit, ctx.kind)
	if ok_cs and own_needs_help then
		_dbg(t, "you are downed/disabled — auto-attack paused")
		return
	end
	local ok_ws, wielded_slot = pcall(_wielded_slot_body, ctx.unit)
	if ok_ws and wielded_slot == "slot_grenade_ability" then
		_dbg(t, "blitz raised — auto-attack paused so the companion can settle for the order")
		return
	end
	local ok_te, has_tag_talent = pcall(_has_tag_talent_body, ctx.unit)
	has_tag_talent = ok_te and has_tag_talent or false
	if not panic and has_tag_talent then
		local gate_ok, _, _, gate_wanted, gate_max = _charge_gate_ok(ctx.unit)
		if not gate_ok then
			if mod:get("gate_override_disablers") and _disabler_in_range(t, ctx) then
				_dbg_slow(t, "charge gate bypassed: trapper/hound in range (disabler override)")
			elseif dh_divert and _opt("dh_override_gate", false) then
				_dbg_slow(t, "charge gate bypassed: daemonhost nearby (daemonhost protection override)")
			else
				if gate_wanted and gate_max and gate_wanted > gate_max then
					_dbg_slow(t, "charge gate: 'keep %d' is above your max of %d charges (extra-charge talent not taken) — treated as 'keep a full bar'", math.floor(gate_wanted), gate_max)
				else
					_dbg(t, "charge gate: not enough combat ability reserve")
				end
				return
			end
		end
	end
	local prev_target = mod._current_target
	-- Manual target lock (mastiff): a manually ordered enemy stays THE target until it
	-- dies. Priorities, the aim switch and the bleed hand-off all wait; a new manual
	-- order replaces the lock. Three things end it early: the target getting pinned by
	-- ANOTHER mastiff (our orders would be dead on arrival and only spam the whistle),
	-- the daemonhost guard (mirrors the aim-switch re-check), and a teammate rescue —
	-- which only BORROWS the dog: the lock resumes if the locked enemy is still alive.
	local locked_target
	if ctx.kind == KIND_DOG and _opt("dog_manual_lock", true) then
		local mt = mod._manual_target
		if mt and HEALTH_ALIVE[mt] and ScriptUnit.has_extension(mt, "smart_tag_system")
			and _is_enemy(ctx.unit, mt) and not _dh_order_blocked(mt) then
			local pin_owner = _pin_owner(mt)
			if pin_owner and pin_owner ~= ctx.companion then
				mod._manual_target = nil
			elseif not (rescue and not rescue[mt]) then
				locked_target = mt
			end
		else
			mod._manual_target = nil
		end
	end
	local aim_target
	if not locked_target and mod:get("aim_switch_enabled") then
		local aimed = _aimed_unit(ctx.unit)
		if aimed and HEALTH_ALIVE[aimed] and ScriptUnit.has_extension(aimed, "smart_tag_system")
			and _is_enemy(ctx.unit, aimed) then
			-- The aim override bypasses the whole priority table, so the daemonhost
			-- guard has to be repeated here or a stray crosshair still sends the order.
			if _dh_order_blocked(aimed) then
				_dbg_slow(t, "aim switch ignored: crosshair is on a daemonhost (daemonhost protection)")
			else
				aim_target = aimed
			end
		end
	end
	local target_unit, target_name, target_dist, target_score
	if locked_target then
		target_unit = locked_target
		target_name = _breed_name(locked_target) or "target"
		local pp = POSITION_LOOKUP[ctx.unit]
		local ep = POSITION_LOOKUP[locked_target]
		target_dist = pp and ep and Vector3.distance(pp, ep) or 0
		target_score = 100
		if locked_target ~= prev_target then
			mod._target_acquired_t = t
			_dbg(t, "manual lock: holding %s until it dies", tostring(target_name))
		end
	elseif aim_target then
		-- Pure aim override: tag whatever the crosshair is on, ignoring the
		-- priority table, view cone, distance limit and shield/smoke/wall checks.
		target_unit = aim_target
		target_name = _breed_name(aim_target) or "target"
		local pp = POSITION_LOOKUP[ctx.unit]
		local ep = POSITION_LOOKUP[aim_target]
		target_dist = pp and ep and Vector3.distance(pp, ep) or 0
		target_score = 100
		if aim_target ~= prev_target then
			mod._target_acquired_t = t
			_dbg(t, "aim switch: %s (priority/cone/blocks bypassed)", tostring(target_name))
		end
	else
		local cur_target = mod._current_target
		local cur_score, cur_dist, cur_name = 0, nil, nil
		if cur_target and HEALTH_ALIVE[cur_target] then
			cur_score, cur_dist, cur_name = _score_unit(ctx, cur_target, rescue)
		end
		local released = false
		if ctx.kind == KIND_DOG and cur_score and cur_score > 0 then
			-- Bleed hand-off: a victim the dog has bled down dies on its own — free the
			-- mastiff for the next target instead of watching this one expire. Applies
			-- to pins too (releasing a doomed pin is fine, it stays doomed). The doomed
			-- unit is EXCLUDED from the re-pick below: it would otherwise win the sort
			-- right back (it is the closest thing to the dog) and nothing would change.
			if _opt("dog_bleed_release", true) and _dog_engaged(ctx, cur_target) and _bleed_doomed(t, cur_target) then
				cur_score = 0
				released = true
			end
			if not released then
				cur_score = _cur_los_tick(t, ctx, cur_target, cur_score, rescue, cur_name)
			end
		end
		local exclude = released and cur_target or nil
		local burster_emergency = false
		if cur_target and HEALTH_ALIVE[cur_target] and (not cur_score or cur_score == 0) then
			local cur_bname = _breed_name(cur_target)
			if cur_bname and BURSTERS[cur_bname] then
				burster_emergency = true
			end
		end
		-- An ally is being held and the dog is not already on one of the holders:
		-- re-pick immediately, skipping the hold timer — every second is chip damage
		-- on the held teammate. The emergency only counts when the pick actually
		-- surfaces a holder (in reach, not gated away, winning the sort): otherwise a
		-- rescue the mastiff structurally cannot perform would keep the switch timer
		-- and the pin hold switched off for its whole duration.
		local rescue_emergency, rescue_best = false, nil
		if rescue and not (cur_target and rescue[cur_target] and cur_score and cur_score > 0) then
			rescue_best = _pick_target(ctx, false, rescue, exclude)
			if rescue_best and rescue_best.rescue then
				rescue_emergency = true
			end
		end
		-- Our own mastiff is mid-pin: the pin lasts until the victim dies, and any
		-- re-order elsewhere releases it, so the pin is held BEFORE the score is
		-- consulted — the pinned victim quickly drops out of range (score 0) as the
		-- squad moves on. Only a real rescue — or a bleed hand-off — may end it early.
		local own_pin = not released and _env(ctx).hold_pin and cur_target and HEALTH_ALIVE[cur_target]
			and ctx.companion and _pin_owner(cur_target) == ctx.companion or false
		if own_pin and not rescue_emergency then
			target_unit = cur_target
			target_name = cur_name or _breed_name(cur_target) or "target"
			target_dist = cur_dist
			target_score = cur_score and cur_score > 0 and cur_score or 1
			_dbg(t, "holding pin on %s (kept regardless of range/priority)", tostring(target_name))
		elseif cur_score and cur_score > 0 and not rescue_emergency then
			local switch_delay = _env(ctx).switch
			if t - mod._target_acquired_t >= switch_delay then
				local best = _pick_target(ctx, false, rescue)
				if best and best.unit ~= cur_target and best.score > cur_score then
					target_unit, target_name, target_dist, target_score = best.unit, best.name, best.dist, best.score
					mod._target_acquired_t = t
					_dbg(t, "switch to higher-priority target: %s", best.name)
				else
					target_unit, target_name, target_dist, target_score = cur_target, cur_name, cur_dist, cur_score
				end
			else
				target_unit, target_name, target_dist, target_score = cur_target, cur_name, cur_dist, cur_score
			end
		else
			local best = not burster_emergency and rescue_best or _pick_target(ctx, burster_emergency, rescue, exclude)
			if best then
				target_unit, target_name, target_dist, target_score = best.unit, best.name, best.dist, best.score
				mod._target_acquired_t = t
				if burster_emergency then
					_dbg(t, "burster too close to someone — emergency switch to %s (shield/smoke checks skipped)", tostring(best.name))
				elseif rescue_emergency and rescue[best.unit] then
					_dbg(t, "RESCUE: %s is holding a teammate — sending the mastiff", tostring(best.name))
				elseif released then
					_dbg(t, "bleed hand-off: %s is bleeding out — mastiff moves to %s", tostring(cur_name), tostring(best.name))
				end
			end
		end
	end
	local used_decoy = false
	if not target_unit and dh_divert then
		local decoy = _pick_decoy(ctx)
		if decoy then
			target_unit, target_name, target_dist, target_score = decoy.unit, decoy.name, decoy.dist, decoy.score
			used_decoy = true
			if target_unit ~= prev_target then
				mod._target_acquired_t = t
				_dbg(t, "daemonhost protection: no priority target — keeping the companion busy on %s so the game cannot pick the daemonhost", tostring(target_name))
			end
		else
			_dbg_slow(t, "daemonhost protection: nothing to divert the companion onto (no other alerted enemy in range)")
		end
	end
	if not target_unit then
		_dbg(t, "no valid target (nothing scored > 0, blocked by shield/wall, or outside view cone)")
		return
	end
	local is_new = target_unit ~= prev_target
	local interval = _env(ctx).interval
	if used_decoy then
		interval = math.min(interval, mod:get("dh_divert_interval") or 0.8)
	end
	if not is_new and t - mod._last_order_t < interval then
		return
	end
	-- Already biting or pinning exactly this target: nothing to gain from a re-order,
	-- it only spams the marker and the whistle line. Re-orders resume automatically the
	-- moment the dog's replicated target drifts to something else. Two bounds: the
	-- game's order tag lives 25 s and a lapsed tag silently hands the dog back to its
	-- own target selection, so one refresh still goes out before expiry; and daemonhost
	-- keep-busy (decoy) orders keep their fast cadence — the fresh tag IS their point.
	if not is_new and not used_decoy and ctx.kind == KIND_DOG
		and t - mod._last_order_t < 20 and _dog_engaged(ctx, target_unit) then
		return
	end
	if mod._pending_order then
		mod._pending_stale = mod._pending_stale + 1
		if mod._pending_stale >= 20 then
			_dbg_slow(t, "WARNING: orders are queued but the smart_tag input poll never consumes them — InputService._get hook is not firing")
		end
	else
		mod._pending_stale = 0
	end
	mod._current_target = target_unit
	mod._pending_order = {
		unit = target_unit,
		name = target_name,
		dist = target_dist,
		score = target_score,
		expire_t = _main_now() + 0.5,
	}
	mod._n_queued = (mod._n_queued or 0) + 1
	_dbg(t, "queued: %s (prio %d) — waiting for smart_tag input poll", tostring(target_name), target_score or 0)
end

-- Auto-detonation ("подрыв"). The Detonation blitz (special rule adamant_whistle)
-- explodes at the DOG's position: 4 m frag blast plus a 5 m electrocute-stagger shout.
-- While biting a monster the dog is glued to it, so firing the blitz in that window
-- centres the whole package on the boss. The blitz is a normal grenade-key action,
-- so the mod presses it the same way it already synthesizes the smart_tag input.
local DET_RADIUS = 2.6
local DET_DWELL = 0.2
local DET_COOLDOWN = 3

local function _det_target_valid(unit)
	if not unit or not HEALTH_ALIVE[unit] then
		return false
	end
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = ude and ude:breed()
	local tags = breed and breed.tags
	if not tags or tags.witch then
		return false
	end
	if tags.monster then
		return true
	end
	if (tags.captain or tags.cultist_captain) and _opt("dog_det_captains", false) then
		return true
	end
	return false
end

local function _detonate_body(t, ctx)
	if not _opt("dog_det_enabled", false) then
		return
	end
	if mod._det_stage then
		-- A synthesized press the input poll never consumed (menu opened, state change)
		-- must not jam auto-detonation forever.
		if t - mod._det_last_t > DET_COOLDOWN then
			mod._det_stage = nil
		end
		return
	end
	if t - mod._det_last_t < DET_COOLDOWN then
		return
	end
	local dog = ctx.companion
	if not dog or not ALIVE[dog] then
		mod._det_close_unit = nil
		return
	end
	local te = ScriptUnit.has_extension(ctx.unit, "talent_system")
	if not te or not te:has_special_rule(special_rules.adamant_whistle) then
		return
	end
	local ae = ScriptUnit.has_extension(ctx.unit, "ability_system")
	local charges = ae and ae:remaining_ability_charges("grenade_ability") or 0
	if charges <= (mod:get("dog_det_keep_charges") or 1) then
		_dbg_slow(t, "auto-detonate armed but held back: keeping %d blitz charge(s) in reserve", mod:get("dog_det_keep_charges") or 1)
		return
	end
	-- Never fight the player's own blitz press.
	local ok_ws, wielded_slot = pcall(_wielded_slot_body, ctx.unit)
	if ok_ws and wielded_slot == "slot_grenade_ability" then
		return
	end
	-- The dog publishes no behaviour state, but its perception target and its position
	-- are replicated; "target is a boss AND the dog is on top of it for a moment" is
	-- exactly the biting/latched window.
	local tid = _skull_go_field(dog, "target_unit_id")
	local tgt = tid and tid ~= NetworkConstants.invalid_game_object_id and Managers.state.unit_spawner:unit(tid) or nil
	if not _det_target_valid(tgt) then
		mod._det_close_unit = nil
		return
	end
	local dpos = POSITION_LOOKUP[dog] or Unit.world_position(dog, 1)
	local tpos = POSITION_LOOKUP[tgt]
	if not dpos or not tpos or Vector3.distance(dpos, tpos) > DET_RADIUS then
		mod._det_close_unit = nil
		return
	end
	if mod._det_close_unit ~= tgt then
		mod._det_close_unit = tgt
		mod._det_close_since = t
		return
	end
	if t - mod._det_close_since < DET_DWELL then
		return
	end
	mod._det_stage = "press"
	mod._det_hold_until = 0
	mod._det_last_t = t
	mod._det_close_unit = nil
	if _opt("dog_det_notify", true) then
		mod:echo(mod:localize("sskc_det_fired") .. " (" .. tostring(_breed_name(tgt)) .. ")")
	end
	_dbg(t, "auto-detonate: mastiff is on %s — pressing the blitz", tostring(_breed_name(tgt)))
end

local function _detonate_tick(t, ctx)
	pcall(_detonate_body, t, ctx)
end

local function _apply_green_slots(unit, col)
	local vle = ScriptUnit.has_extension(unit, "visual_loadout_system")
	if not vle then
		return
	end
	local slots = vle:inventory_slots()
	for slot_name, slot in pairs(slots) do
		if slot.use_outline then
			local slot_unit, attachments = vle:slot_unit(slot_name)
			if slot_unit then
				for i = 1, #OUTLINE_LAYERS do
					pcall(Unit.set_vector3_for_material, slot_unit, OUTLINE_LAYERS[i], "outline_color", col)
				end
			end
			if attachments then
				for j = 1, #attachments do
					for i = 1, #OUTLINE_LAYERS do
						pcall(Unit.set_vector3_for_material, attachments[j], OUTLINE_LAYERS[i], "outline_color", col)
					end
				end
			end
		end
	end
end

local function _apply_green(unit)
	local col = Vector3(GREEN[1], GREEN[2], GREEN[3])
	for i = 1, #OUTLINE_LAYERS do
		pcall(Unit.set_vector3_for_material, unit, OUTLINE_LAYERS[i], "outline_color", col)
	end
	pcall(_apply_green_slots, unit, col)
end

local function _outline_system()
	return Managers.state.extension:system("outline_system")
end

local function _remove_outline_one(osys, u)
	if ALIVE[u] then
		osys:remove_outline(u, OUTLINE_NAME)
	end
end

local function _clear_outlines()
	local ok, osys = pcall(_outline_system)
	for u in pairs(mod._outlined) do
		if ok and osys then
			pcall(_remove_outline_one, osys, u)
		end
		mod._outlined[u] = nil
	end
end

local function _revive_prio(p)
	local profile = p.profile and p:profile()
	local arch = profile and profile.archetype and profile.archetype.name
	local key = arch and REVIVE_PRIO_KEYS[arch]
	local v = key and mod:get(key)
	if v == nil then
		return DEFAULT_REVIVE_PRIO
	end
	return v
end

local function _collect_downed_allies(want, own_unit)
	local ignore_bots = _opt("heal_ignore_bots", false)
	for _, p in pairs(Managers.player:players()) do
		local u = p.player_unit
		if u and u ~= own_unit and HEALTH_ALIVE[u] and _needs_help_body(u) then
			-- Only outline allies the heal order is actually allowed to reach, so the
			-- highlight never promises a revive the mod will refuse to send.
			local excluded = ignore_bots and not p:is_human_controlled() or _revive_prio(p) <= 0
			if not excluded then
				want[u] = true
			end
		end
	end
end

local function _outline_tick(ctx)
	if not mod:get("heal_outline_enabled") then
		if next(mod._outlined) then
			_clear_outlines()
		end
		return
	end
	local want = {}
	pcall(_collect_downed_allies, want, ctx.unit)
	local ok, osys = pcall(_outline_system)
	if not ok or not osys then
		return
	end
	for u in pairs(mod._outlined) do
		if not want[u] then
			pcall(_remove_outline_one, osys, u)
			mod._outlined[u] = nil
		end
	end
	for u in pairs(want) do
		if not mod._outlined[u] then
			local ok_add = pcall(osys.add_outline, osys, u, OUTLINE_NAME)
			if ok_add then
				mod._outlined[u] = true
			end
		end
		_apply_green(u)
	end
end

local function _think()
	local t = _now()
	if not t then
		return
	end
	if t - mod._last_think_t < 0.1 then
		return
	end
	mod._last_think_t = t
	mod._n_think = (mod._n_think or 0) + 1
	if mod._panic_until > 0 and _main_now() >= mod._panic_until then
		mod._panic_until = 0
		mod:echo(mod:localize("sskc_panic_off"))
	end
	local ctx = _ctx()
	if not ctx then
		mod._skull_state = nil
		mod._companion_kind = nil
		mod._dh_near = false
		mod._dh_latched = false
		if next(mod._outlined) then
			_clear_outlines()
		end
		if mod:get("auto_enabled") then
			_dbg_slow(t, "inactive: %s", mod._ctx_why or "unknown reason")
		end
		return
	end
	mod._companion_kind = ctx.kind
	if ctx.kind == KIND_SKULL and ctx.companion and ALIVE[ctx.companion] then
		mod._skull_state = _skull_go_field(ctx.companion, "state")
	else
		mod._skull_state = nil
	end
	-- Scanned here rather than inside the auto-attack tick so the notification latch
	-- does not get stuck "on" when auto-attack is switched off mid-encounter. The
	-- per-companion switch is part of the condition for the same reason: a protection
	-- for orders that are not being sent must not scan or announce anything.
	local dh_watching = _opt("dh_full_stop", false) or _opt("dh_divert", true)
	local auto_kind_on = ctx.kind == KIND_DOG and _opt("dog_auto_enabled", true)
		or ctx.kind == KIND_SKULL and _opt("skull_auto_enabled", true)
	mod._dh_near = dh_watching and auto_kind_on and (mod:get("auto_enabled") or _panic_active()) and _dh_in_range(t, ctx) or false
	if mod._dh_near ~= mod._dh_latched then
		mod._dh_latched = mod._dh_near
		if _opt("dh_notify", true) then
			mod:echo(mod:localize(mod._dh_near and "sskc_dh_on" or "sskc_dh_off"))
		end
	end
	if t - mod._last_outline_t >= 0.3 then
		mod._last_outline_t = t
		_outline_tick(ctx)
	end
	_auto_tick(t, ctx)
	-- Independent of auto-attack: detonating over a boss the dog reached via a MANUAL
	-- order is just as valuable, so the opt-in auto-detonate runs on its own switch.
	if ctx.kind == KIND_DOG then
		_detonate_tick(t, ctx)
	end
end

-- The manual-guard bodies read positions via Unit.world_position, not POSITION_LOOKUP:
-- they also run from the order-key keybind callback, where POSITION_LOOKUP values are
-- raw userdata that Vector3 arithmetic rejects.
local function _manual_ff_body(skull, target_unit)
	local spos = Unit.world_position(skull, 1)
	local tpos = Unit.world_position(target_unit, 1)
	if not spos or not tpos then
		return false
	end
	return _ff_blocked(spos, tpos + Vector3(0, 0, 1.3))
end

local function _manual_smoke_body(skull, target_unit)
	local spos = Unit.world_position(skull, 1)
	local tpos = Unit.world_position(target_unit, 1)
	if not spos or not tpos then
		return false
	end
	return _smoke_blocked(spos, tpos + Vector3(0, 0, 1.3), skull)
end

local function _manual_burster_body(ctx, target_unit)
	local name = _breed_name(target_unit)
	if not name or not BURSTERS[name] then
		return false
	end
	local epos = Unit.world_position(target_unit, 1)
	if not epos then
		return false
	end
	local radius = mod:get("dist_burster_manual") or 10
	local ppos = Unit.world_position(ctx.unit, 1)
	if ppos and Vector3.distance(ppos, epos) < radius then
		return true
	end
	if mod:get("burster_team_radius") and _teammate_within(epos, radius) then
		return true
	end
	return false
end

local function _manual_verdict(target_unit)
	local ctx = _ctx()
	if not ctx then
		return "allow"
	end
	-- First, and independent of the companion: waking a daemonhost by a mis-aimed
	-- double-tap is the one order that cannot be taken back.
	if _opt("dh_block_manual", true) and target_unit and ALIVE[target_unit] and _is_daemonhost(target_unit) then
		return "block_daemonhost"
	end
	-- Checked before the companion gate: the blast is dangerous whatever the companion
	-- is doing, and it needs no line of sight to be decided.
	if mod:get("manual_block_burster") and target_unit and ALIVE[target_unit] then
		local ok, blocked = pcall(_manual_burster_body, ctx, target_unit)
		if ok and blocked then
			return "block_burster"
		end
	end
	if not ctx.companion or not ALIVE[ctx.companion] then
		return "allow"
	end
	-- The remaining guards all model the skull's shot line and its busy states; the
	-- mastiff has neither, so it is never blocked by them.
	if ctx.kind ~= KIND_SKULL then
		return "allow"
	end
	if mod:get("manual_block_busy") then
		local state = _skull_go_field(ctx.companion, "state")
		if state and state ~= STATES.following and state ~= STATES.following_shooting and state ~= STATES.following_shooting_ability then
			return "block_busy"
		end
	end
	if mod:get("manual_block_shield") and target_unit and ALIVE[target_unit] then
		local ok, blocked = pcall(_manual_ff_body, ctx.companion, target_unit)
		if ok and blocked then
			return "block_shield"
		end
	end
	if mod:get("manual_block_smoke") and target_unit and ALIVE[target_unit] then
		local ok, blocked = pcall(_manual_smoke_body, ctx.companion, target_unit)
		if ok and blocked then
			return "block_smoke"
		end
	end
	return "allow"
end

local function _notify_block(verdict)
	if not mod:get("block_notify") then
		return
	end
	local key = verdict == "block_busy" and "sskc_blocked_busy"
		or verdict == "block_smoke" and "sskc_blocked_smoke"
		or verdict == "block_burster" and "sskc_blocked_burster"
		or verdict == "block_daemonhost" and "sskc_blocked_daemonhost"
		or "sskc_blocked_shield"
	mod:echo(mod:localize(key))
end

local function _note_manual_order()
	local t = _now()
	if t then
		mod._last_manual_t = t
	end
end

-- Remembers the player's own companion order for the manual target lock. Only orders
-- that passed the guards get here — but the game fires the companion_order path for
-- whatever the interactor resolves to (a netted ALLY in front of you included; only
-- its own later checks discard non-enemies), so hostile-breed-ness must be verified
-- before latching or the lock would jam auto-attack on a teammate forever. Bursters
-- are never latched either: a lock bypasses the emergency switch that protects the
-- squad from them, and one kick settles a burster anyway.
local function _note_manual_target(target_unit)
	if not target_unit or not HEALTH_ALIVE[target_unit] then
		return
	end
	local name = _breed_name(target_unit)
	if not name or BURSTERS[name] then
		return
	end
	local player = Managers.player and Managers.player:local_player_safe(1)
	local player_unit = player and player.player_unit
	if not player_unit or not _is_enemy(player_unit, target_unit) then
		return
	end
	mod._manual_target = target_unit
end

mod:hook("HudElementSmartTagging", "_trigger_smart_tag_unit_contextual", function(func, self, target_unit, alternate)
	if alternate == "companion_order" then
		local verdict = _manual_verdict(target_unit)
		if verdict ~= "allow" then
			_notify_block(verdict)
			return func(self, target_unit, nil)
		end
		_note_manual_order()
		_note_manual_target(target_unit)
	end
	return func(self, target_unit, alternate)
end)

mod:hook("HudElementSmartTagging", "_trigger_smart_tag_interaction", function(func, self, tag_id, target_unit, optional_override_tag_name)
	if optional_override_tag_name == "companion_order" then
		local verdict = _manual_verdict(target_unit)
		if verdict ~= "allow" then
			_notify_block(verdict)
			return
		end
		_note_manual_order()
		_note_manual_target(target_unit)
	end
	return func(self, tag_id, target_unit, optional_override_tag_name)
end)

mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "targeting_data", function(self)
	mod._targeting_ext = self
end)

local function _read_real_input(input_service, action_name)
	local action_rule = input_service._actions and input_service._actions[action_name]
	if not action_rule then
		return nil
	end
	local out
	if action_rule.filter then
		out = action_rule.eval_func(action_rule.eval_obj, action_rule.eval_param)
	else
		out = action_rule.default_func()
		local action_type = action_rule.type
		local combiner = InputService.ACTION_TYPES[action_type].combine_func
		for _, cb in ipairs(action_rule.callbacks) do
			out = combiner(out, cb())
		end
	end
	return out
end

mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
	if action_name == "grenade_ability_hold" and mod:get("heal_block_second")
		and mod._skull_state ~= nil and mod._skull_state == STATES.inject_ally then
		mod._launch_heal = nil
		local t0 = _now()
		if t0 then
			_dbg(t0, "second heal order blocked: skull is still reviving an ally (inject_ally)")
		end
		return false
	end
	if action_name == "grenade_ability_hold" and (mod._launch_heal or mod._suppress_hold) then
		local held = _read_real_input(self, action_name)
		if held == nil then
			return func(self, action_name)
		end
		if not held then
			mod._launch_heal = nil
			mod._suppress_hold = false
			return func(self, action_name)
		end
		mod._launch_heal = nil
		mod._suppress_hold = true
		return false
	end
	-- Synthesized Detonation press: one frame of grenade_ability_pressed=true, a short
	-- forced hold, then the genuine released state chains the game's own aim_released →
	-- action_order_companion (the actual explosion fires 0.3 s in, server-side). A real
	-- key press from the player always wins and cancels the synthetic one.
	if action_name == "grenade_ability_pressed" and mod._det_stage == "press" then
		local real = _read_real_input(self, action_name)
		if real == nil then
			mod._det_stage = nil
			return func(self, action_name)
		end
		if real then
			mod._det_stage = nil
			return real
		end
		mod._det_stage = "hold"
		mod._det_hold_until = _main_now() + 0.15
		return true
	end
	if action_name == "grenade_ability_hold" and mod._det_stage == "hold" then
		local real = _read_real_input(self, action_name)
		if real then
			mod._det_stage = nil
			return real
		end
		if _main_now() < mod._det_hold_until then
			return true
		end
		mod._det_stage = nil
		return false
	end
	if action_name ~= "smart_tag" or not mod._pending_order then
		return func(self, action_name)
	end
	local out = _read_real_input(self, action_name)
	if out == nil then
		return func(self, action_name)
	end
	if out then
		mod._pending_order = nil
		return out
	end
	local pending = mod._pending_order
	mod._pending_order = nil
	mod._pending_stale = 0
	if _main_now() > pending.expire_t or not HEALTH_ALIVE[pending.unit] then
		local t0 = _now()
		if t0 then
			_dbg(t0, "pending order dropped (expired or target died before the input poll)")
		end
		return func(self, action_name)
	end
	local player = Managers.player:local_player_safe(1)
	local player_unit = player and player.player_unit
	if not player_unit or not ALIVE[player_unit] then
		return func(self, action_name)
	end
	local sts = Managers.state.extension:system("smart_tag_system")
	if not sts then
		return func(self, action_name)
	end
	local td = mod._targeting_ext and mod._targeting_ext._targeting_data
	local saved_aim = td and td.unit
	if td then
		td.unit = pending.unit
	end
	local ok, err = pcall(sts.set_contextual_unit_tag, sts, player_unit, pending.unit, true)
	if td then
		td.unit = saved_aim
	end
	local t = _now()
	if ok then
		mod._n_sent = (mod._n_sent or 0) + 1
		if t then
			mod._last_order_t = t
			_dbg(t, "order sent: %s (%.0fm, prio %d) — waiting for tag in _all_tags", tostring(pending.name), pending.dist or 0, pending.score or 0)
		end
		if mod:get("debug_enabled") then
			mod._await_confirm = {
				unit = pending.unit,
				name = pending.name,
				deadline_t = _main_now() + 0.6,
			}
		end
		return false
	end
	if t then
		_dbg(t, "order call failed: %s", err)
	end
	return func(self, action_name)
end)

local function _process_own_tags(all_tags, t)
	local player = Managers.player:local_player_safe(1)
	if not player then
		return
	end
	for tag_id, tag in pairs(all_tags) do
		local tagger = tag.tagger_player and tag:tagger_player()
		if tagger == player then
			local is_new = not mod._known_tags[tag_id]
			mod._known_tags[tag_id] = true
			local template = tag._template
			local marker = template and template.marker_type
			if is_new and t then
				_dbg(t, "own tag appeared in _all_tags: %s (id %s)", tostring(marker), tostring(tag_id))
			end
			if mod._await_confirm then
				local target = tag.target_unit and tag:target_unit()
				if target == mod._await_confirm.unit then
					if t then
						_dbg(t, "ORDER CONFIRMED: %s tag on %s is in _all_tags", tostring(marker), tostring(mod._await_confirm.name))
					end
					mod._await_confirm = nil
				end
			end
		end
	end
	for tag_id in pairs(mod._known_tags) do
		if not all_tags[tag_id] then
			mod._known_tags[tag_id] = nil
			if t then
				_dbg(t, "own tag removed from _all_tags (id %s)", tostring(tag_id))
			end
		end
	end
end

mod:hook_safe(CLASS.SmartTagSystem, "update", function(self)
	_think()
	local debug_on = mod:get("debug_enabled")
	if not mod._await_confirm and not debug_on then
		return
	end
	local tt = _now()
	if debug_on and tt and tt - (mod._last_hb_t or -100) >= 5 then
		mod._last_hb_t = tt
		mod:echo(string.format("[SSKC] hb: companion=%s dh_near=%s dmf_update=%d think=%d queued=%d sent=%d", tostring(mod._companion_kind), tostring(mod._dh_near), mod._n_update or 0, mod._n_think or 0, mod._n_queued or 0, mod._n_sent or 0))
	end
	local all_tags = self._all_tags
	if not all_tags then
		return
	end
	local t = _now()
	pcall(_process_own_tags, all_tags, t)
	if mod._await_confirm and _main_now() > mod._await_confirm.deadline_t then
		if t then
			_dbg(t, "ORDER NOT CONFIRMED: no tag on %s appeared in _all_tags within 0.6s — game rejected/ignored the order", tostring(mod._await_confirm.name))
		end
		mod._await_confirm = nil
	end
end)

local function _step_angle(cur, want, max_step)
	local dlt = (want - cur + PI) % TWO_PI - PI
	dlt = math.clamp(dlt, -max_step, max_step)
	return math.mod_two_pi(cur + dlt)
end

local function _heal_lock_body(ude, ally)
	local tf = ude:read_component("action_module_ability_target_finder")
	return tf and tf.target_unit_1 == ally or false
end

local function _heal_game_lock(ude, ally)
	local ok, locked = pcall(_heal_lock_body, ude, ally)
	if ok then
		return locked
	end
	local ext = mod._targeting_ext
	local td = ext and ext._targeting_data
	return td and td.unit == ally or false
end

local function _heal_aim_body(self, snap_on, launch_on, main_dt)
	local player = self._player
	local unit = player and player.player_unit
	if not unit or not ALIVE[unit] then
		return
	end
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	local inv = ude and ude:read_component("inventory")
	if not inv or inv.wielded_slot ~= "slot_grenade_ability" then
		return
	end
	local t = _main_now()
	if not mod._heal_wield_t or t - (mod._heal_wield_last or 0) > 0.25 then
		mod._heal_wield_t = t
		-- A fresh hold re-evaluates everything: drop the "could not lock" skip list
		-- so the top-priority ally always gets the first shot again.
		mod._heal_lock_ally = nil
		mod._heal_lock_since = nil
		for u in pairs(mod._heal_skip) do
			mod._heal_skip[u] = nil
		end
	end
	mod._heal_wield_last = t
	local te = ScriptUnit.has_extension(unit, "talent_system")
	if not te or not te:has_special_rule(special_rules.cryptic_servo_skull_inject_ally) then
		return
	end
	local spawner = ScriptUnit.has_extension(unit, "companion_spawner_system")
	local skull = spawner and spawner:spawned_unit_lookup(special_rules.cryptic_servo_skull_inject_ally)
	if not skull or not ALIVE[skull] then
		return
	end
	local ability_ext = ScriptUnit.has_extension(unit, "ability_system")
	if not ability_ext then
		return
	end
	local fp = self._first_person_component
	local cam_pos = fp and fp.position
	if not cam_pos then
		return
	end
	local cos_half, cam_fwd
	local cone_angle = mod:get("heal_snap_cone") or 360
	if cone_angle < 360 then
		local o = self._orientation
		if o then
			local cp = math.cos(o.pitch)
			cam_fwd = Vector3(-cp * math.sin(o.yaw), cp * math.cos(o.yaw), math.sin(o.pitch))
			cos_half = math.cos(math.rad(cone_angle * 0.5))
		end
	end
	-- Candidates are tracked in two slots — best human and best bot — instead of a list,
	-- so this runs allocation-free every frame the blitz is held. Highest class priority
	-- wins, distance only breaks ties.
	local ignore_bots = _opt("heal_ignore_bots", false)
	local bots_last = _opt("heal_bots_last", true)
	local best_h, best_h_prio, best_h_d
	local best_b, best_b_prio, best_b_d
	local n_candidates = 0
	for _, p in pairs(Managers.player:players()) do
		local tu = p.player_unit
		if tu and tu ~= unit and HEALTH_ALIVE[tu] then
			local is_bot = not p:is_human_controlled()
			local skip_until = mod._heal_skip[tu]
			if not (is_bot and ignore_bots) and not (skip_until and t < skip_until) then
				local prio = _revive_prio(p)
				if prio > 0 and CompanionServoSkullAbility.validate_target_func_inject_ally_ability(tu, ability_ext, skull) then
					local tp = POSITION_LOOKUP[tu]
					if tp then
						local in_cone = true
						if cos_half then
							local to_t = (tp + Vector3(0, 0, 0.5)) - cam_pos
							local len = Vector3.length(to_t)
							in_cone = len < 0.05 or Vector3.dot(cam_fwd, to_t / len) >= cos_half
						end
						local d = Vector3.distance(cam_pos, tp)
						if in_cone and d <= CompanionServoSkullSettings.max_target_distance_range then
							n_candidates = n_candidates + 1
							if is_bot then
								if not best_b_prio or prio > best_b_prio or prio == best_b_prio and d < best_b_d then
									best_b, best_b_prio, best_b_d = tu, prio, d
								end
							elseif not best_h_prio or prio > best_h_prio or prio == best_h_prio and d < best_h_d then
								best_h, best_h_prio, best_h_d = tu, prio, d
							end
						end
					end
				end
			end
		end
	end
	local best
	if best_h and best_b then
		if bots_last then
			best = best_h
		elseif best_b_prio > best_h_prio or best_b_prio == best_h_prio and best_b_d < best_h_d then
			best = best_b
		else
			best = best_h
		end
	else
		best = best_h or best_b
	end
	if not best then
		return
	end
	-- Priority can pick an ally the game's own targeting cannot lock (through a wall,
	-- or too far for the reticle). Without this the revive would stall on them forever,
	-- so after a moment that candidate is parked and the next one gets its turn.
	local locked = _heal_game_lock(ude, best)
	if best ~= mod._heal_lock_ally then
		mod._heal_lock_ally = best
		mod._heal_lock_since = t
	elseif locked then
		mod._heal_lock_since = t
	elseif n_candidates > 1 and t - (mod._heal_lock_since or t) > HEAL_LOCK_TIMEOUT then
		mod._heal_skip[best] = t + HEAL_SKIP_TIME
		mod._heal_lock_ally = nil
		mod._heal_lock_since = nil
		local tt = _now()
		if tt then
			_dbg(tt, "heal: no target lock on the top-priority ally within %.1fs — trying the next candidate", HEAL_LOCK_TIMEOUT)
		end
		return
	end
	local tpos
	if Unit.has_node(best, "j_spine") then
		tpos = Unit.world_position(best, Unit.node(best, "j_spine"))
	else
		tpos = POSITION_LOOKUP[best] + Vector3(0, 0, 0.3)
	end
	local dir = Vector3.normalize(tpos - cam_pos)
	local wanted_yaw = math.mod_two_pi(math.atan2(dir.y, dir.x) - PI * 0.5)
	local wanted_pitch = math.mod_two_pi(math.asin(dir.z))
	local ori = self._orientation
	if snap_on then
		local max_step = math.rad(mod:get("heal_snap_speed") or 360) * (main_dt or 0.016)
		ori.yaw = _step_angle(ori.yaw, wanted_yaw, max_step)
		local new_pitch = _step_angle(ori.pitch, wanted_pitch, max_step)
		local mn, mx = self._min_pitch, self._max_pitch
		if mn and mx then
			new_pitch = math.clamp((new_pitch + PI) % TWO_PI - PI, mn, mx) % TWO_PI
		end
		ori.pitch = new_pitch
	end
	if launch_on and not mod._suppress_hold then
		if locked then
			if mod._heal_aligned_ally ~= best or not mod._heal_aligned_last or t - mod._heal_aligned_last > 0.25 then
				mod._heal_aligned_ally = best
				mod._heal_aligned_since = t
			end
			mod._heal_aligned_last = t
			if t - mod._heal_wield_t >= HEAL_LAUNCH_MIN_WIELD and t - mod._heal_aligned_since >= HEAL_LAUNCH_MIN_LOCK then
				mod._launch_heal = true
				mod._heal_aligned_ally = nil
				mod._heal_aligned_since = nil
				mod._heal_aligned_last = nil
				local tt = _now()
				if tt then
					_dbg(tt, "heal auto-launch: game targeting locked the ally — releasing the order")
				end
			end
		else
			mod._heal_aligned_ally = nil
			mod._heal_aligned_since = nil
			mod._heal_aligned_last = nil
			local tt = _now()
			if tt then
				_dbg_slow(tt, "heal: aiming at ally, waiting for the game's target lock (skull must be idle in 'following' and the reticle on the body)")
			end
		end
	end
end

mod:hook_safe("DefaultPlayerOrientation", "pre_update", function(self, main_t, main_dt)
	local snap_on = mod:get("heal_snap_enabled")
	local launch_on = mod:get("heal_auto_launch")
	if not snap_on and not launch_on then
		return
	end
	pcall(_heal_aim_body, self, snap_on, launch_on, main_dt)
end)

mod.sskc_toggle_auto = function()
	local v = not mod:get("auto_enabled")
	mod:set("auto_enabled", v)
	mod:echo(mod:localize(v and "sskc_auto_on" or "sskc_auto_off"))
	if v then
		local ctx = _ctx()
		if not ctx then
			mod:echo("[SSKC] not active: not playing Skitarii or Arbites (or in a menu/hub)")
		elseif not ctx.companion or not ALIVE[ctx.companion] then
			mod:echo("[SSKC] warning: companion not found (Skitarii needs the skull blitz equipped)")
		elseif ctx.kind == KIND_DOG then
			mod:echo("[SSKC] active: Arbites + cyber-mastiff detected")
		else
			mod:echo("[SSKC] active: Skitarii + servo-skull detected")
		end
	end
end

mod.sskc_panic = function()
	if _panic_active() then
		mod._panic_latch = false
		mod._panic_until = 0
		mod:echo(mod:localize("sskc_panic_off"))
		return
	end
	if mod:get("panic_hold") then
		mod._panic_latch = true
		mod._panic_until = 0
		mod:echo(mod:localize("sskc_panic_on_hold"))
	elseif mod:get("panic_timed") then
		local dur = mod:get("panic_duration") or 30
		mod._panic_latch = false
		mod._panic_until = _main_now() + dur
		mod:echo(mod:localize("sskc_panic_on_timed") .. " (" .. tostring(dur) .. "s)")
	else
		mod._panic_latch = true
		mod._panic_until = 0
		mod:echo(mod:localize("sskc_panic_on_hold"))
	end
end

-- Close-combat mode toggle: while active the mastiff's whole engagement envelope is
-- leashed to the close radius (see _env) — a bodyguard for tense melees.
mod.sskc_dog_close = function()
	local ctx = _ctx()
	if not ctx or ctx.kind ~= KIND_DOG then
		mod:echo(mod:localize("sskc_close_na"))
		return
	end
	mod._dog_close = not mod._dog_close
	mod:echo(mod:localize(mod._dog_close and "sskc_close_on" or "sskc_close_off"))
end

-- True when both key tables describe the same physical binding (same key + modifiers,
-- order-insensitive). DMF stores keybinds as arrays of key-name strings.
local function _same_keybind(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a == 0 or #a ~= #b then
		return false
	end
	local set = {}
	for i = 1, #a do
		set[tostring(a[i])] = true
	end
	for i = 1, #b do
		if not set[tostring(b[i])] then
			return false
		end
	end
	return true
end

-- Skitarii UI Fix deconfliction: when that mod is enabled and its order key is bound
-- to the SAME physical key as ours, one press would fire both handlers and send two
-- skull orders back to back (its key is Skitarii-only, so the mastiff never doubles).
-- In that exact case our handler yields the skull to it and keeps only the mastiff.
local function _suif_owns_skull_order()
	local ok, owns = pcall(function()
		local suif = get_mod("SkitariiUIFix")
		if not suif or suif.is_enabled and not suif:is_enabled() then
			return false
		end
		return _same_keybind(suif:get("order_keybind"), mod:get("order_key"))
	end)
	return ok and owns or false
end

-- One-press attack order at the crosshair target (the SkitariiUiFix-style button),
-- for BOTH companions. Runs through the mod's own manual-order guards (daemonhost,
-- Poxburster, busy/shield/smoke per settings) and the same pending-order pipeline as
-- auto-attack, and pauses auto-attack like any manual order.
mod.sskc_order = function()
	local ctx = _ctx()
	if not ctx then
		return
	end
	local t = _now()
	if not t then
		return
	end
	if ctx.kind == KIND_SKULL and _suif_owns_skull_order() then
		_dbg(t, "order key: yielding the skull order to Skitarii UI Fix (same key bound there)")
		return
	end
	-- Re-press cooldown so mashing the key cannot fire an order every frame; stamped
	-- only when an order is actually queued, so a wasted press never blocks.
	if t - mod._order_key_t < 0.3 then
		return
	end
	local aimed = _aimed_unit(ctx.unit)
	if not aimed or not HEALTH_ALIVE[aimed] or not ScriptUnit.has_extension(aimed, "smart_tag_system")
		or not _is_enemy(ctx.unit, aimed) then
		-- Escape valve: a deliberate DOUBLE press (within 0.6 s) at empty space releases
		-- the manual lock. A single missed press during a frantic fight must neither
		-- drop the lock the player asked for nor say anything in chat — combat presses
		-- miss all the time, and the old single-press clear spammed the release notice.
		if mod._manual_target and t - mod._empty_press_t < 0.6 then
			mod._manual_target = nil
			mod._empty_press_t = -100
			if _opt("dog_lock_notify", true) then
				mod:echo(mod:localize("sskc_lock_cleared"))
			end
		else
			mod._empty_press_t = t
			_dbg(t, "order key: no valid enemy under the crosshair%s",
				mod._manual_target and " (press again quickly to release the manual lock)" or "")
		end
		return
	end
	local verdict = _manual_verdict(aimed)
	if verdict ~= "allow" then
		_notify_block(verdict)
		return
	end
	_note_manual_order()
	_note_manual_target(aimed)
	mod._order_key_t = t
	-- Keybind callbacks run outside the frame context in which POSITION_LOOKUP hands
	-- out usable Vector3s (its values arrive as raw userdata here and Vector3.distance
	-- rejects them), so positions must come from Unit.world_position in this function.
	local dist = 0
	local ok_d, d = pcall(function()
		return Vector3.distance(Unit.world_position(ctx.unit, 1), Unit.world_position(aimed, 1))
	end)
	if ok_d and d then
		dist = d
	end
	mod._current_target = aimed
	mod._target_acquired_t = t
	mod._pending_order = {
		unit = aimed,
		name = _breed_name(aimed) or "target",
		dist = dist,
		score = 100,
		expire_t = _main_now() + 0.5,
	}
	_dbg(t, "order key: %s queued", tostring(mod._pending_order.name))
end

mod.update = function(dt)
	mod._n_update = (mod._n_update or 0) + 1
	_think()
end

mod.on_all_mods_loaded = function()
	-- The rename changed the DMF settings namespace (settings are keyed by the id given
	-- to new_mod), so an upgrader's whole tuned profile would silently reset to factory
	-- defaults. One-time copy of the old "ServoSkullCommander" namespace into this one;
	-- old-format keys inside it are then handled by the migrations below, in order.
	if not mod:get("sskc_migrated_rename_v1") then
		mod:set("sskc_migrated_rename_v1", true)
		pcall(function()
			local all = Application.user_setting("mods_settings")
			local old = all and all.ServoSkullCommander
			if type(old) == "table" then
				for k, v in pairs(old) do
					if k ~= "sskc_migrated_rename_v1" then
						mod:set(k, v)
					end
				end
				mod:echo(mod:localize("sskc_rename_migrated"))
			end
		end)
	end
	if not mod:get("sskc_migrated_split_v1") then
		local old_disabler = mod:get("prio_disabler_los")
		if old_disabler ~= nil then
			mod:set("prio_hound_far", old_disabler)
			mod:set("prio_trapper_far", old_disabler)
			mod:set("prio_mutant", old_disabler)
		end
		local old_sniper_bomber = mod:get("prio_sniper_bomber")
		if old_sniper_bomber ~= nil then
			mod:set("prio_sniper", old_sniper_bomber)
			mod:set("prio_bomber", old_sniper_bomber)
		end
		mod:set("sskc_migrated_split_v1", true)
	end
	-- The game fixed the servo-skull refusing to shoot through smoke and allied force
	-- fields, so all four shot-line guards default OFF now. Profiles saved while the
	-- bug still existed carry the old "true", hence this one-time flip; the settings
	-- themselves stay available in case a future patch breaks the fix again.
	if not mod:get("sskc_migrated_smoke_fix_v1") then
		mod:set("auto_block_shield", false)
		mod:set("auto_block_smoke", false)
		mod:set("manual_block_shield", false)
		mod:set("manual_block_smoke", false)
		mod:set("sskc_migrated_smoke_fix_v1", true)
	end
	-- The mastiff got its own priority table (dog_* ids). Old shared-table values are
	-- deliberately NOT copied over — the new dog defaults are the whole point of the
	-- redesign (kick-only breeds at 0, trapper hunting up) — but the reset must not be
	-- silent for players who had tuned the shared sliders for their dog.
	if not mod:get("sskc_migrated_tabs_v1") then
		mod:set("sskc_migrated_tabs_v1", true)
		pcall(function()
			mod:echo(mod:localize("sskc_tabs_notice"))
		end)
	end
end

mod.on_game_state_changed = function(status, state_name)
	if state_name == "StateGameplay" and status == "exit" then
		mod._outlined = {}
		mod._current_target = nil
		mod._target_acquired_t = 0
		mod._last_order_t = 0
		mod._last_manual_t = -1000
		mod._pending_order = nil
		mod._await_confirm = nil
		mod._targeting_ext = nil
		mod._known_tags = {}
		mod._pending_stale = 0
		mod._launch_heal = nil
		mod._suppress_hold = false
		mod._heal_wield_t = nil
		mod._heal_wield_last = nil
		mod._heal_aligned_since = nil
		mod._heal_aligned_last = nil
		mod._heal_aligned_ally = nil
		mod._skull_state = nil
		mod._panic_latch = false
		mod._panic_until = 0
		mod._disabler_scan_t = -100
		mod._disabler_scan_hit = false
		mod._companion_kind = nil
		mod._dh_scan_t = -100
		mod._dh_scan_hit = false
		mod._dh_near = false
		mod._dh_latched = false
		mod._rescue_scan_t = -100
		mod._rescue_n = 0
		mod._det_stage = nil
		mod._det_hold_until = 0
		mod._det_last_t = -100
		mod._det_close_unit = nil
		mod._det_close_since = 0
		mod._bleed_unit = nil
		mod._bleed_scan_t = -100
		mod._bleed_hit = false
		mod._cur_los_unit = nil
		mod._cur_los_t = 0
		mod._cur_los_scan_t = -100
		mod._dog_close = false
		mod._order_key_t = -100
		mod._exec_scan_t = -100
		mod._exec_n = 0
		mod._manual_target = nil
		mod._empty_press_t = -100
		for u in pairs(EXEC_SET) do
			EXEC_SET[u] = nil
		end
		for u in pairs(RESCUE_SET) do
			RESCUE_SET[u] = nil
		end
		mod._heal_skip = {}
		mod._heal_lock_ally = nil
		mod._heal_lock_since = nil
		mod._last_think_t = 0
		mod._last_outline_t = 0
		mod._last_dbg_t = -100
		mod._last_dbg_msg = nil
		mod._last_slow_t = -100
		mod._last_slow_msg = nil
		mod._last_hb_t = nil
	end
end

mod.on_disabled = function()
	_clear_outlines()
	mod._dog_close = false
	mod._det_stage = nil
	mod._pending_order = nil
	mod._manual_target = nil
	mod._exec_n = 0
end

mod.on_unload = function()
	_clear_outlines()
end
