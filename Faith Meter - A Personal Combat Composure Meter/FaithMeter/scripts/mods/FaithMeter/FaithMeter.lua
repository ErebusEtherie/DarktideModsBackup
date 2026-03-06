local mod = get_mod("FaithMeter")

-- ---------------------------------------------------------
-- Stable breed-name classification (authoritative keys)
-- ---------------------------------------------------------
local SPECIALIST_BREEDS = {
    chaos_hound = true,
    chaos_poxwalker_bomber = true,
    chaos_ogryn_gunner = true,
    chaos_ogryn_executor = true,
    -- NEW LINES FOR BREEDS
    cultist_berzerker = true,
    cultist_gunner = true,
    cultist_shocktrooper = true,
    renegade_berzerker = true,
    renegade_executor = true,
    renegade_gunner = true,
    renegade_shocktrooper = true,

    --OLD LINES
    chaos_ogryn_bulwark = true,
    cultist_flamer = true,
    cultist_grenadier = true,
    cultist_mutant = true,
    renegade_flamer = true,
    renegade_grenadier = true,
    renegade_netgunner = true,
    renegade_sniper = true,
    -- burster (name varies across patches; include common key)
    chaos_poxwalker_exploder = true,
}

-- Monsters / bosses (excluded from some balance behaviors, e.g., team credit / optional drain)
local BOSS_BREEDS = {
    chaos_spawn = true,
    chaos_beast_of_nurgle = true,
    chaos_daemonhost = true,
    chaos_plague_ogryn = true,
    chaos_plague_ogryn_sprayer = true,
    renegade_captain = true,
    renegade_twin_captain = true,
    renegade_twin_captain_two = true,
}
local BOSS_BREEDS = {
    chaos_spawn = true,
    chaos_beast_of_nurgle = true,
    chaos_daemonhost = true,
    chaos_plague_ogryn = true,
}

local Breeds = require("scripts/settings/breed/breeds")

-- =========================================================
-- FaithMeter
-- HUD + Logic v1.3.1 (cosmetic-only)
--
-- Behavior contract:
--   * Reset ONLY when entering gameplay (missions / Psykhanium), including join-in-progress.
--   * Freeze (do not reset, do not tick) in the hub.
--   * Track ONLY the local human player.
--   * HUD layer unchanged; this file only wires logic + exposes read APIs.
--
-- NOTE (important):
--   Previous "hook add_damage" approaches were unreliable (toughness absorbs most hits)
--   and some hook paths have caused instability. This build uses POLLING of
--   health/toughness percentages and detects drops as "damage taken".
-- =========================================================

-- ---------------------------------------------------------
-- HUD registration (stable; do not change unless planned)
-- ---------------------------------------------------------
mod:register_hud_element({
    class_name = "HudElementFaithMeter",
    filename = "FaithMeter/scripts/mods/FaithMeter/HudElements/HudElementFaithMeter",
    use_hud_scale = true,
    visibility_groups = {
        "alive",
    },
})


-- ---------------------------------------------------------
-- Settings helpers (avoid nils; do not silently fail)
-- ---------------------------------------------------------
local _warned_missing_setting = {}

local function _warn_missing(setting_id)
    if _warned_missing_setting[setting_id] then
        return
    end
    _warned_missing_setting[setting_id] = true
    mod:echo(string.format("[FaithMeter] Missing setting '%s' (likely from an old config). Falling back to defaults.", setting_id))
end

local function _get_bool(setting_id, default)
    local v = mod:get(setting_id)
    if v == nil then
        _warn_missing(setting_id)
        return default == true
    end
    return v == true
end

local function _clamp_num(x, lo, hi)
    if x == nil then return nil end
    if lo ~= nil and x < lo then return lo end
    if hi ~= nil and x > hi then return hi end
    return x
end

local function _get_number(setting_id, default, lo, hi)
    local v = mod:get(setting_id)
    if type(v) ~= "number" then
        if v == nil then
            _warn_missing(setting_id)
        else
            mod:echo(string.format("[FaithMeter] Invalid setting '%s' (expected number). Falling back to defaults.", setting_id))
        end
        v = default
    end
    return _clamp_num(v, lo, hi)
end

-- ---------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------
mod._faith_value = mod._faith_value or 0.0
mod._faith_last_damage_t = mod._faith_last_damage_t -- number or nil
mod._faith_run_active = mod._faith_run_active or false
mod._faith_last_mode_name = mod._faith_last_mode_name
mod._faith_last_t = mod._faith_last_t or 0

-- Polling cache
mod._faith_last_unit = mod._faith_last_unit
mod._faith_last_hp_p = mod._faith_last_hp_p
mod._faith_last_tough_p = mod._faith_last_tough_p


-- ---------------------------------------------------------
-- Special pressure tracking (v1.3 TEST)
--   We track "special" breeds that exist near the player and
--   apply a small Faith drain if they linger too long.
--   This is implemented defensively to avoid invalid unit refs.
-- ---------------------------------------------------------
mod._tracked_specials = mod._tracked_specials or {} -- [unit] = { engaged_t = 0, engaged = false }
mod._sp_debug = mod._sp_debug or { engaged = 0, total = 0, drain_per_s = 0, seen = 0, contributing = 0, loss_per_s = 0, team_mult = 1.0, team_s = 0.0, tk_seen = 0, tk_cred = 0, tk_ign = 0 }
-- Team engagement dampening (additive; does not alter core rhythm logic)
mod._team_engage_s = mod._team_engage_s or 0
mod._team_engage_last_add_t = mod._team_engage_last_add_t or 0
mod._team_hooks = mod._team_hooks or { installed = false }

-- Team pressure debug (Phase 2)
mod._team_track = mod._team_track or {} -- [unit] = per-player rolling state
mod._pressure_debug = mod._pressure_debug or {
    score = 0,
    coh_coverage = 1,
    disabled = 0,
    alive = 1,
    toughness_avg = 1,
    health_avg = 1,
    critical_players = 0,
    toughness_low_players = 0,
    toughness_breaks_per_s = 0,
    relief = false,
    seconds_since_relief = 0,
    threat_silent = false,
    seconds_since_pressure = 0,
    relief_type = "none",
}

function mod.get_pressure_debug()
    return mod._pressure_debug
end

-- Darktide breed.tags are commonly a boolean-map (e.g. { special=true, disabler=true })
-- but some data/mods may expose them as an array. Support both forms.
local function _tag_has(tags, tag)
    if not tags or not tag then
        return false
    end

    -- Map form: tags.special == true
    if type(tags) == "table" and tags[tag] == true then
        return true
    end

    -- Array form: {"special", "disabler"}
    local n = #tags
    if n and n > 0 then
        for i = 1, n do
            if tags[i] == tag then
                return true
            end
        end
    end

    return false
end

local function _is_special_breed(breed)
    if not breed then return false end
    local bname = breed.name
    if bname and SPECIALIST_BREEDS[bname] then return true end
    if breed.is_special then return true end
    if breed.breed_type == "special" then return true end
    if _tag_has(breed.tags, "special") then return true end
    if _tag_has(breed.tags, "disabler") then return true end
    -- Monsters are handled separately via option. Don't classify them as specials.
    if _tag_has(breed.tags, "monster") then return false end
    return false
end

local function _track_special_unit(unit)
    if not unit or not Unit.alive(unit) then return end
    if mod._tracked_specials[unit] then return end

    local ok, unit_data = pcall(ScriptUnit.extension, unit, "unit_data_system")
    if not ok or not unit_data then return end

    local breed = unit_data:breed()

    -- Track specials by default; optionally include monsters/bosses as pressure sources.
    local include_monsters = _get_bool("sp_include_monsters", true)
    local bname = breed and breed.name
    local is_monster = (bname and BOSS_BREEDS[bname]) or _tag_has(breed and breed.tags, "monster") or breed.breed_type == "monster" or breed.breed_type == "boss"
    if not _is_special_breed(breed) and not (include_monsters and is_monster) then
        return
    end

    mod._tracked_specials[unit] = {
        engaged_t = 0,
        engaged = false,
    }
end

-- Track specials via periodic scanning (SideSystem enemy list).
-- (We intentionally avoid extension init hooks; they are brittle across patches.)

mod._faith_was_alive = mod._faith_was_alive

-- Tunables (v1)
local STARTING_FAITH = 0.0
local SAFE_DELAY_S = 3.5
local SAFE_RECOVERY_PER_S = 0.55

local KILL_BASE_GAIN = 4.0
local KILL_ELITE_BONUS = 1.75
local KILL_SPECIAL_BONUS = 3.50
local KILL_DISABLER_BONUS = 3.55

-- Damage penalty computed from percent drops (since we are polling)
local DAMAGE_LOSS_CAP = 3.0
local TOUGHNESS_DROP_TO_LOSS = 9.0 -- %drop * factor
local HEALTH_DROP_TO_LOSS = 28.0

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------
local function _clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function _safe_call(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then
        return res
    end
    return nil
end

local function _get_unit_breed_name(unit)
    if not unit or not ScriptUnit then return nil end
    local ok, ud = pcall(ScriptUnit.extension, unit, "unit_data_system")
    if not ok or not ud then return nil end
    if ud.breed then
        local ok2, breed = pcall(ud.breed, ud)
        if ok2 and breed then
            local n = breed.name or breed.breed_name
            if type(n) == "string" then return n end
        end

local function _resolve_player_from_unit(unit)
    if not Managers or not Managers.player or not unit then return nil end
    if Managers.player.player_by_unit then
        local ok, p = pcall(Managers.player.player_by_unit, Managers.player, unit)
        if ok and p then return p end
    end

-- Expose resolver for hook scopes that may not capture locals reliably
mod._resolve_player_from_unit = mod._resolve_player_from_unit or _resolve_player_from_unit

    if Managers.player.owner then
        local ok, p = pcall(Managers.player.owner, Managers.player, unit)
        if ok and p then return p end
    end
    local lp = Managers.player.local_player and Managers.player:local_player(1)
    if lp and lp.player_unit and lp.player_unit == unit then
        return lp
    end
    return nil
end
    end
    return nil
end

-- Read a player's current character state name in a way that works for local + remote units.
-- We prefer the character_state_machine_system when available (local), and fall back to unit_data_system character_state for others.

-- ---------------------------------------------------------
-- Sound-event driven special acquisition
--   Purpose: reliably discover specials/bosses in live missions without depending on global enemy enumeration.
-- ---------------------------------------------------------
mod._sp_sound = mod._sp_sound or {
    installed = false,
    events_seen = 0,
    events_matched = 0,
    units_added = 0,
    pos_added = 0,
    last_name = nil,
    last_t = 0,
}
mod._sp_sound_pos = mod._sp_sound_pos or {}

local function _infer_breed_from_sound(name)
    if type(name) ~= "string" then return nil end
    local n = string.lower(name)
    -- broad, resilient substring mapping (can be expanded safely over time)
    if string.find(n, "netgunner") or string.find(n, "trapper") then return "renegade_netgunner" end
    if string.find(n, "gunner") or string.find(n, "chaos_ogryn_gunner") then return "chaos_ogryn_gunner" end
    if string.find(n, "sniper") then return "renegade_sniper" end
    if string.find(n, "berzerker") or string.find (n, "cultist_berzerker") then return "cultist_berzerker" end
    if string.find(n, "cultist_gunner") then return "cultist_gunner" end
    if string.find(n, "shocktrooper") or string.find (n, "cultist_shocktrooper") then return "cultist_shocktrooper" end
    if string.find(n, "renegade_berzerker") then return "renegade_berzerker" end
    if string.find(n, "renegade_executor") then return "renegade_executor" end
    if string.find(n, "renegade_gunner") then return "renegade_gunner" end
    if string.find(n, "renegade_shocktrooper") then return "renegade_shocktrooper" end
    if string.find(n, "gunner") or string.find (n, "chaos_ogryn_executor") then return "chaos_ogryn_executor" end
    if string.find(n, "bulwark") or string.find (n, "chaos_ogryn_bulwark") then return "chaos_ogryn_bulwark" end
    if string.find(n, "bomber") or string.find(n, "grenadier") then return "chaos_poxwalker_bomber" end
    if string.find(n, "flamer") then return "cultist_flamer"end
    if string.find(n, "hound") then return "chaos_hound" end
    if string.find(n, "bulwark") or string.find (n, "chaos_ogryn_bulwark") then return "chaos_ogryn_bulwark" end
    if string.find(n, "mutant") then return "cultist_mutant" end
    if string.find(n, "executor") or string.find (n, "chaos_ogryn_executor") then return "chaos_ogryn_executor" end
    if string.find(n, "gunner") or string.find (n, "chaos_ogryn_executor") then return "chaos_ogryn_executor" end
    if string.find(n, "burster") or string.find(n, "exploder") then return "chaos_poxwalker_exploder" end
    if string.find(n, "gunner") or string.find (n, "chaos_ogryn_gunner") then return "chaos_ogryn_gunner" end
    if string.find(n, "beast_of_nurgle") then return "chaos_beast_of_nurgle" end
    if string.find(n, "daemonhost") then return "chaos_daemonhost" end
    if string.find(n, "plague_ogryn") then return "chaos_plague_ogryn" end
    if string.find(n, "chaos_spawn") then return "chaos_spawn" end
    return nil
end

local function _sp_add_pos_signal(pos, now, inferred_breed)
    if not pos or not now then return end
    local ttl = tonumber(mod:get("sp_sound_signal_ttl")) or 6.0
    if ttl < 0.5 then ttl = 0.5 end
    mod._sp_sound_pos[#mod._sp_sound_pos + 1] = {
        pos = pos,
        t0 = now,
        last = now,
        ttl = ttl,
        breed = inferred_breed,
    }
    mod._sp_sound.pos_added = (mod._sp_sound.pos_added or 0) + 1
end

local function _sp_prune_pos_signals(now)
    local list = mod._sp_sound_pos
    if not list or #list == 0 then return end
    local w = 1
    for i = 1, #list do
        local s = list[i]
        if s and (now - (s.last or 0)) <= (s.ttl or 0) then
            list[w] = s
            w = w + 1
        end
    end
    for i = w, #list do
        list[i] = nil
    end
end

local function _sp_on_sound(name, unit_or_pos, context_unit)
    mod._sp_sound.events_seen = (mod._sp_sound.events_seen or 0) + 1
    mod._sp_sound.last_name = name
    mod._sp_sound.last_t = Managers and Managers.time and Managers.time:time("main") or 0

    if not mod:get("sp_sound_detection") then
        return
    end

    local inferred = _infer_breed_from_sound(name)
    if not inferred then
        return
    end
    mod._sp_sound.events_matched = (mod._sp_sound.events_matched or 0) + 1

    -- Prefer direct unit handle if present
    if unit_or_pos and Unit and Unit.alive and Unit.alive(unit_or_pos) then
        _track_special_unit(unit_or_pos)
        mod._sp_sound.units_added = (mod._sp_sound.units_added or 0) + 1
        return
    end

    -- Try context unit
    if context_unit and Unit and Unit.alive and Unit.alive(context_unit) then
        _track_special_unit(context_unit)
        mod._sp_sound.units_added = (mod._sp_sound.units_added or 0) + 1
        return
    end

    -- Position-only fallback (Vector3)
    if unit_or_pos and Vector3 and Vector3.is_vector3 and Vector3.is_vector3(unit_or_pos) then
        local now = Managers and Managers.time and Managers.time:time("main") or 0
        _sp_add_pos_signal(unit_or_pos, now, inferred)
    end
end

local function _install_sp_sound_hooks()
    if mod._sp_sound.installed then return end
    mod._sp_sound.installed = true

    if not WwiseWorld or not mod.hook_safe then
        return
    end

    mod:hook_safe(WwiseWorld, "trigger_resource_event", function(_wwise_world, wwise_event_name, unit_or_position_or_id)
        if type(wwise_event_name) ~= "string" then return end
        _sp_on_sound(wwise_event_name, unit_or_position_or_id, Application and Application.flow_callback_context_unit and Application.flow_callback_context_unit())
    end)

    mod:hook_safe(WwiseWorld, "trigger_resource_external_event", function(_wwise_world, wwise_source_event, sound_source, file_path, file_format, wwise_source_id)
        if type(file_path) ~= "string" then return end
        _sp_on_sound(file_path, wwise_source_id, Application and Application.flow_callback_context_unit and Application.flow_callback_context_unit())
    end)
end

-- ---------------------------------------------------------
-- Team engagement acquisition (killfeed-driven, Scoreboard pattern)
--   Purpose: capture teammate "handled it" moments reliably on client without enemy enumeration.
--   This feeds a short dampening window that reduces special drain while the team is actively resolving threats.
-- ---------------------------------------------------------
local function _install_team_engagement_hooks()
    if mod._team_hooks.installed then return end
    mod._team_hooks.installed = true

    if not mod.hook_safe or not CLASS or not CLASS.HudElementCombatFeed then
        return
    end

        local function _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
            if type(func) == "function" then
                return func(self, attacking_unit, attacked_unit, ...)
            elseif type(func) == "table" then
                -- DMF hook chains sometimes pass a table wrapper; try common slots.
                local f = func[1] or func.func or func.original
                if type(f) == "function" then
                    return f(self, attacking_unit, attacked_unit, ...)
                end
            end
            -- Fallback: do nothing rather than crash the HUD pipeline.
            return
        end
    
    mod:hook_safe(CLASS.HudElementCombatFeed, "event_combat_feed_kill", function(func, self, attacking_unit, attacked_unit, ...)
        -- Some mods (and some interactions) use combat feed as a message bus (string "attacked_unit"). Ignore those.
        if type(attacked_unit) == "string" then
            return _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
        end

        mod._sp_debug.tk_seen = (mod._sp_debug.tk_seen or 0) + 1

        if not _get_bool("team_enabled", true) then
            mod._sp_debug.tk_ign = (mod._sp_debug.tk_ign or 0) + 1
            return _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
        end        -- Only count kills made by players (local or teammates). Use the same resolver as combat feed.
        local pusm = Managers and Managers.state and Managers.state.player_unit_spawn
        local p = pusm and pusm.owner and pusm:owner(attacking_unit)
        if not p then
            mod._sp_debug.tk_ign = (mod._sp_debug.tk_ign or 0) + 1
            return _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
        end        -- Only count special kills (optionally excludes bosses).
        local unit_data_extension = ScriptUnit and ScriptUnit.has_extension and ScriptUnit.has_extension(attacked_unit, "unit_data_system")
        local breed = unit_data_extension and unit_data_extension.breed and unit_data_extension:breed()
        local tags = breed and breed.tags
        if type(tags) ~= "table" then
            mod._sp_debug.tk_ign = (mod._sp_debug.tk_ign or 0) + 1
            return _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
        end

        -- Boss/monster exclusion
        if _get_bool("team_exclude_bosses", true) and (tags.monster or tags.nemesis or tags.lord or tags.witch) then
            mod._sp_debug.tk_ign = (mod._sp_debug.tk_ign or 0) + 1
            return _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
        end

        -- Credit specials only (combat-feed uses this same tag key for coloring)
        if not tags.special then
            mod._sp_debug.tk_ign = (mod._sp_debug.tk_ign or 0) + 1
            return _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
        end
        -- Apply / extend dampening window.
        local add_s = tonumber(_get_number("team_window_s", 6, 0, 30)) or 6
        if add_s < 0 then add_s = 0 end
        local cap_s = tonumber(_get_number("team_cap_s", 12, 0, 60)) or 12
        if cap_s < add_s then cap_s = add_s end

        mod._team_engage_s = math.min(cap_s, (mod._team_engage_s or 0) + add_s)
        mod._team_engage_last_add_t = Managers.time and Managers.time:time("main") or 0

        mod._sp_debug.tk_cred = (mod._sp_debug.tk_cred or 0) + 1
        return _call_combat_feed_original(func, self, attacking_unit, attacked_unit, ...)
    end)
end

_install_sp_sound_hooks()
_install_team_engagement_hooks()

local function _get_character_state_name(unit)
    if not unit or not Unit.alive(unit) then return nil end

    -- 1) Character state machine (usually local player)
    do
        local ok, csm = pcall(ScriptUnit.extension, unit, "character_state_machine_system")
        if ok and csm and csm.current_state_name then
            local name = _safe_call(csm.current_state_name, csm)
            if type(name) == "string" then
                return name
            end
        end
    end

    -- 2) Unit data (often works for remote teammates)
    do
        local ok, ud = pcall(ScriptUnit.extension, unit, "unit_data_system")
        if ok and ud and ud.read_component then
            local ok2, comp = pcall(ud.read_component, ud, "character_state")
            if ok2 and type(comp) == "table" then
                local name = comp.state_name or comp.state or comp.name
                if type(name) == "string" then
                    return name
                end
            end
        end
    end

    return nil
end

local function _current_game_mode_name()
    local gm = Managers and Managers.state and Managers.state.game_mode
    if not gm or not gm.game_mode_name then
        return nil
    end

    local name = _safe_call(gm.game_mode_name, gm)
    return name
end

local function _is_hub_mode(mode_name)
    -- Keep this conservative: only freeze in the actual hub.
    return mode_name == "hub"
end

local function _local_player()
    local pm = Managers and Managers.player
    if not pm then
        return nil
    end
    return pm:local_player(1) or pm:local_player()
end

local function _local_player_unit(player)
    if not player then return nil end
    return player.player_unit
end

local function _player_unit_is_alive(player)
    if not player then return false end

    -- Prefer PlayerManager API when it exists and returns a boolean.
    if player.unit_is_alive then
        local alive = _safe_call(player.unit_is_alive, player)
        if type(alive) == "boolean" then
            return alive
        end
    end

    local unit = player.player_unit
    if not unit or not ScriptUnit then
        return false
    end

    -- Robust fallback: consult the health extension instead of assuming that
    -- a non-nil unit implies "alive" (that assumption breaks death resets).
    local he = ScriptUnit.has_extension(unit, "health_system")
    if he then
        if he.is_dead then
            local ok, v = pcall(he.is_dead, he)
            if ok and type(v) == "boolean" then
                return not v
            end
        end

        if he.is_alive then
            local ok, v = pcall(he.is_alive, he)
            if ok and type(v) == "boolean" then
                return v
            end
        end

        if he.current_health then
            local ok, v = pcall(he.current_health, he)
            if ok and type(v) == "number" then
                return v > 0
            end
        end
    end

    -- Last resort: if we have a unit reference but no health API, treat it as alive.
    return true
end


local function _is_hogtied_rescue_state(unit)
    if not unit or not ScriptUnit then
        return false
    end

    local ude = ScriptUnit.has_extension(unit, "unit_data_system")
    if not ude or not ude.read_component then
        return false
    end

    local comp = _safe_call(ude.read_component, ude, "character_state")
    if not comp or type(comp) ~= "table" then
        return false
    end

    local state_name = comp.state_name
    return state_name == "hogtied"
end

local function _is_psyker(player)
    if not player then return false end
    if player.archetype_name then
        local name = _safe_call(player.archetype_name, player)
        if type(name) == "string" then
            return name == "psyker"
        end
    end

    local arch = player.archetype
    if type(arch) == "table" then
        return arch.name == "psyker" or arch.archetype_name == "psyker"
    end

    return false
end

local function _get_warp_charge(unit)
    if not unit or not ScriptUnit then return nil, nil end
    local ude = ScriptUnit.has_extension(unit, "unit_data_system")
    if not ude or not ude.read_component then
        return nil, nil
    end

    local comp = _safe_call(ude.read_component, ude, "warp_charge")
    if type(comp) ~= "table" then
        return nil, nil
    end

    return comp.current_percentage, comp.state
end

local function _get_health_percent(unit)
    if not unit or not ScriptUnit then return nil end
    local he = ScriptUnit.has_extension(unit, "health_system")
    if he and he.current_health_percent then
        return _safe_call(he.current_health_percent, he)
    end
    return nil
end

local function _get_toughness_percent(unit)
    if not unit or not ScriptUnit then return nil end
    local te = ScriptUnit.has_extension(unit, "toughness_system")
    if te and te.current_toughness_percent then
        return _safe_call(te.current_toughness_percent, te)
    end
    return nil
end

local function _has_tag(breed, tag)
    local tags = breed and breed.tags
    return tags and tags[tag] == true
end


-- =========================================================
-- Special pressure (v1.3 TEST)
-- =========================================================
mod._sp_units = mod._sp_units or {}
mod._sp_debug = mod._sp_debug or { seen = 0, contributing = 0, loss_per_s = 0 }

local function _side_system()
    local ext = Managers and Managers.state and Managers.state.extension
    if ext and ext.system then
        return _safe_call(ext.system, ext, "side_system")
    end
    return nil
end

local function _get_unit_pos(u)
    if not u then
        return nil
    end
    -- Unit handles can become invalid between frames (despawn/cleanup). Guard
    -- aggressively: calling into Unit.* on an invalid reference can crash.
    if Unit and Unit.alive and not Unit.alive(u) then
        return nil
    end
    if POSITION_LOOKUP and POSITION_LOOKUP[u] then
        return POSITION_LOOKUP[u]
    end
    if Unit and Unit.world_position then
        return Unit.world_position(u, 1)
    end
    return nil
end

local function _count_alive_human_players()
    local pm = Managers and Managers.player
    if not pm or not pm.players then
        return 1
    end

    local players = pm:players()
    local n = 0

    for _, p in pairs(players) do
        local is_human = true

        if p.is_human_controlled then
            is_human = _safe_call(p.is_human_controlled, p)
        elseif p._is_human_controlled ~= nil then
            is_human = p._is_human_controlled == true
        end

        if is_human then
            local pu = p.player_unit

            if pu and _player_unit_is_alive(p) then
                n = n + 1
            end
        end
    end

    if n < 1 then
        n = 1
    end

    return n
end

local function _clutch_coeff()
    if not _get_bool("sp_clutch_coeff_enabled", true) then
        return 1.0
    end

    local n = _count_alive_human_players()

    if n <= 1 then
        return 0.6
    elseif n == 2 then
        return 0.8
    end

    return 1.0
end

local function _special_allowed_by_tags(tags)
    if not tags or tags.special ~= true then
        return false
    end

    -- Prefer specific tags when available; fall back to "other specials".
    if (tags.bomber and _get_bool("sp_track_bomber", true)) then return true end
    if (tags.flamer and _get_bool("sp_track_flamer", true)) then return true end
    if (tags.sniper and _get_bool("sp_track_sniper", true)) then return true end
    if (tags.trapper and _get_bool("sp_track_trapper", true)) then return true end
    if ((tags.hound or tags.dog or tags.pouncer) and _get_bool("sp_track_hound", true)) then return true end
    if (tags.mutant and _get_bool("sp_track_mutant", true)) then return true end
    if (tags.burster and _get_bool("sp_track_burster", true)) then return true end

    return _get_bool("sp_track_other_specials", true) == true
end

function mod.get_special_pressure_debug()
    return mod._sp_debug
end



-- ---------------------------------------------------------
-- Special pressure scanning helpers
--   We use SideSystem to get current enemy units and then filter by breed tags.
--   This avoids relying on extension init hooks (which are patch-sensitive).
-- ---------------------------------------------------------
local function _enemy_units_table()
    local ext = Managers and Managers.state and Managers.state.extension
    if not ext or not ext.system then
        return nil
    end

    local side_system = _safe_call(ext.system, ext, "side_system")
    if not side_system then
        return nil
    end

    local default_side_name = _safe_call(side_system.get_default_player_side_name, side_system)
    if not default_side_name then
        return nil
    end

    local player_side = _safe_call(side_system.get_side_from_name, side_system, default_side_name)
    if not player_side then
        return nil
    end

    return _safe_call(player_side.relation_units, player_side, "enemy")
end


-- Iterate enemy unit tables that may be sets ([unit]=true), arrays ([i]=unit), or nested tables.
local function _iter_enemy_units(tbl, fn, depth)
    if type(tbl) ~= "table" then
        return
    end
    depth = depth or 0
    if depth > 2 then
        return
    end

    for k, v in pairs(tbl) do
        if type(k) == "userdata" and k and Unit.alive(k) then
            fn(k)
        elseif type(v) == "userdata" and v and Unit.alive(v) then
            fn(v)
        elseif type(k) == "table" then
            _iter_enemy_units(k, fn, depth + 1)
        elseif type(v) == "table" then
            _iter_enemy_units(v, fn, depth + 1)
        end
    end
end

mod._sp_last_scan_t = mod._sp_last_scan_t or 0

local function _scan_for_specials(t)
    -- Scan at most twice per second
    if (t or 0) < (mod._sp_last_scan_t or 0) + 0.5 then
        return
    end
    mod._sp_last_scan_t = t or 0

    local enemies = _enemy_units_table()
    if not enemies then
        return
    end

    _iter_enemy_units(enemies, function(unit)
        _track_special_unit(unit)
    end)
end

-- ---------------------------------------------------------
-- Special pressure update (runs in mod.update)
--   * Tracks SPECIAL units seen in the world (via HealthExtension init hooks)
--   * Considers a special "engaged" once within engage radius of the local player
--   * Applies a small Faith drain if an engaged special lingers beyond grace time
--   * Uses only Unit.alive + Unit.world_position; no world_pose calls
-- ---------------------------------------------------------
local function _update_special_pressure(local_unit, t, dt)
    -- Default debug (HUD reads these)
    mod._sp_debug.engaged = 0
    mod._sp_debug.total = 0
    mod._sp_debug.drain_per_s = 0

    if not (_get_bool("sp_enabled", false) and mod._faith_run_active) or mod._faith_initial_lock_active then
        -- When disabled / not in run, keep list pruned to avoid stale refs.
        for u, _ in pairs(mod._tracked_specials) do
            if not Unit.alive(u) then
                mod._tracked_specials[u] = nil
            end
        end
        return
    end

    if not (local_unit and Unit.alive(local_unit)) then
        return
    end

    _scan_for_specials(now)

    local engage_radius = tonumber(_get_number("sp_engage_radius", 25, 5, 80)) or 30
    if engage_radius < 1 then engage_radius = 1 end
    local engage_r2 = engage_radius * engage_radius

    local grace = tonumber(_get_number("sp_grace_seconds", 15, 0, 120)) or 12
    if grace < 0 then grace = 0 end

    local per_s = tonumber(_get_number("sp_loss_per_second", 0.06, 0.0, 1.0)) or 0.06
    if per_s < 0 then per_s = 0 end

    -- Proximity pressure (Phase 2.6)
    local prox_enabled = _get_bool("sp_proximity_enabled", true)
    local prox_radius = tonumber(_get_number("sp_proximity_radius", 35, 0, 100)) or 35
    if prox_radius < 0 then prox_radius = 0 end
    local prox_r2 = prox_radius * prox_radius

    local prox_per_s = tonumber(_get_number("sp_proximity_loss_per_second", 0.20, 0.0, 2.0)) or 0.20
    if prox_per_s < 0 then prox_per_s = 0 end

    local ppos = Unit.world_position(local_unit, 1)
    if not ppos then return end

    local now = t or 0

    -- prune sound-only signals (position-only specials)
    _sp_prune_pos_signals(now)

    local contributing_prox = 0
    local contributing_grace = 0
    local engaged = 0
    local total_tracked = 0
    local total_nearby = 0

    local interest_r2 = math.max(engage_r2, prox_r2)

    for u, entry in pairs(mod._tracked_specials) do
        if not Unit.alive(u) then
            mod._tracked_specials[u] = nil
        else
            total_tracked = total_tracked + 1

            local upos = Unit.world_position(u, 1)
            if upos and Vector3 and Vector3.distance_squared then
                local dist2 = Vector3.distance_squared(ppos, upos)
                local within_interest = dist2 <= interest_r2
                local within_engage = dist2 <= engage_r2
                local within_prox = prox_enabled and dist2 <= prox_r2

                -- For debug/readability, count only specials "in the area" (within the larger of engage/prox radii).
                if within_interest then
                    total_nearby = total_nearby + 1
                end

                -- Proximity pressure contributes immediately (lower, steady drain).
                if within_prox then
                    engaged = engaged + 1
                    contributing_prox = contributing_prox + 1
                end

                -- Engagement pressure (legacy) ramps after a grace period (stronger drain).
                if within_engage then
                    if not entry.engaged then
                        entry.engaged = true
                        entry.engaged_t = 0
                    end

                    entry.engaged_t = (entry.engaged_t or 0) + (dt or 0)

                    if entry.engaged_t >= grace then
                        contributing_grace = contributing_grace + 1
                    end
                else
                    -- If the unit leaves engage radius, decay engagement timer so it must re-apply pressure.
                    if entry.engaged_t and entry.engaged_t > 0 then
                        entry.engaged_t = math.max(0, entry.engaged_t - (dt or 0) * 0.5)
                    end
                end
            end
        end
    end


    -- Team engagement dampening: if the team is actively resolving specials, reduce drain rate (additive tuning only).
    if mod._team_engage_s and mod._team_engage_s > 0 then
        mod._team_engage_s = math.max(0, mod._team_engage_s - (dt or 0))
    end
    local team_mult = 1.0
    if (mod._team_engage_s or 0) > 0 and (contributing_prox + contributing_grace) > 0 then
        team_mult = tonumber(_get_number("team_mult", 0.70, 0.10, 1.00)) or 0.70
        if team_mult < 0.10 then team_mult = 0.10 end
        if team_mult > 1.00 then team_mult = 1.00 end
    end
    local coeff = _clutch_coeff()
    local drain_per_s_total = (contributing_prox * prox_per_s + contributing_grace * per_s) * coeff * team_mult

    -- Include sound-only position signals as special-pressure sources (prevents silent 0/0 failure)
    do
        local sigs = mod._sp_sound_pos
        if sigs and #sigs > 0 and Vector3 and Vector3.distance_squared then
            for i = 1, #sigs do
                local s = sigs[i]
                if s and s.pos then
                    local d2 = Vector3.distance_squared(ppos, s.pos)
                    if d2 <= interest_r2 then
                        total_nearby = total_nearby + 1
                        if d2 <= prox_r2 and prox_enabled then
                            contributing_prox = contributing_prox + 1
                        elseif d2 <= engage_r2 then
                            contributing_grace = contributing_grace + 1
                        end
                    end
                end
            end
        end
    end

    -- Debug values (used by HUD)
    -- "seen" is rendered in the HUD as the denominator. Make it reflect specials detected within our interest window.
    mod._sp_debug.seen = total_nearby
    mod._sp_debug.contributing = contributing_prox + contributing_grace
    mod._sp_debug.team_mult = team_mult
    mod._sp_debug.team_s = mod._team_engage_s or 0
    mod._sp_debug.loss_per_s = drain_per_s_total
    mod._sp_debug.engaged = engaged
    mod._sp_debug.total = total_nearby
    mod._sp_debug.drain_per_s = drain_per_s_total
    -- extra internal/debug detail
    mod._sp_debug.tracked = total_tracked
    mod._sp_debug.snd_seen = mod._sp_sound and (mod._sp_sound.events_seen or 0) or 0
    mod._sp_debug.snd_match = mod._sp_sound and (mod._sp_sound.events_matched or 0) or 0
    mod._sp_debug.snd_addU = mod._sp_sound and (mod._sp_sound.units_added or 0) or 0
    mod._sp_debug.snd_pos = mod._sp_sound and (mod._sp_sound.pos_added or 0) or 0


    local loss = drain_per_s_total * (dt or 0)

    if loss > 0 then
        mod._faith_value = math.max(0, mod._faith_value - loss)
        -- Pressure counts as "not safe" so recovery stays paused while contributing specials exist.
        mod._faith_last_damage_t = now
    end

    mod._sp_debug.prox = contributing_prox
    mod._sp_debug.grace = contributing_grace
end

-- Export for any call sites that use method/field syntax (prevents nil func spam)
mod._update_special_pressure = _update_special_pressure

local function _reset_for_gameplay(t)
    mod._faith_value = STARTING_FAITH
    mod._faith_last_damage_t = t
    mod._faith_run_active = true

    -- Initial lock: hold the meter at a fixed value until the first special engagement signal is observed.
    -- This prevents early mission drift before the pressure rhythm meaningfully starts.
    if not mod._faith_initial_lock_started then
        mod._faith_initial_lock_started = true
        mod._faith_initial_lock_active = _get_bool("initial_lock_enabled", false)
        if mod._faith_initial_lock_active then
            mod._faith_value = _get_number("initial_lock_value", 0.0, 0.0, 100.0)
        end
    end

    mod._faith_last_unit = nil
    mod._faith_last_hp_p = nil
    mod._faith_last_tough_p = nil
    mod._faith_was_alive = true
end

local function _apply_damage_drop(delta_percent, is_health, t)
    if not delta_percent or delta_percent <= 0 then return end

    local loss = (is_health and HEALTH_DROP_TO_LOSS or TOUGHNESS_DROP_TO_LOSS) * delta_percent
    if loss > DAMAGE_LOSS_CAP then
        loss = DAMAGE_LOSS_CAP
    end

    mod._faith_value = _clamp(mod._faith_value - loss, 0.0, 100.0)
    mod._faith_last_damage_t = t
end

local function _apply_kill_gain(amount)
    if not amount or amount <= 0 then return end
    if mod._faith_block_positive then return end
    mod._faith_value = _clamp(mod._faith_value + amount, 0.0, 100.0)
end

-- ---------------------------------------------------------
-- Public API for HUD
-- ---------------------------------------------------------
function mod:get_faith_norm()
    return _clamp((self._faith_value or STARTING_FAITH) / 100.0, 0.0, 1.0)
end

function mod:get_faith()
    return _clamp(self._faith_value or STARTING_FAITH, 0.0, 100.0)
end

-- ---------------------------------------------------------
-- Faith state labels (v1.2 test feature; cosmetic-only)
-- ---------------------------------------------------------
local FLAVOR_DURATION_S = 4.0
local FLAVOR_COOLDOWN_S = 20.0

local function _state_for_value(v)
    if v < 0.20 then return 1, "Shattered" end
    if v < 20.0 then return 2, "Wavering" end
    if v < 40.0 then return 3, "Steeled" end
    if v < 60.0 then return 4, "Resolute" end
    if v < 80.0 then return 5, "Zealous" end
    return 6, "Divine"
end

local FLAVOR_UP = {
    [1] = "Faith begins with resolve.",
    [2] = "Doubt is the first heresy.",
    [3] = "Resolve hardens into steel.",
    [4] = "Stand firm. The Emperor watches.",
    [5] = "Zeal carries you through the storm.",
    [6] = "Faith made manifest.",
}

local FLAVOR_DOWN = {
    [1] = "Doubt tests you. Overcome it.",
    [2] = "Wavering. Regain your composure.",
    [3] = "Discipline falters. Focus.",
    [4] = "Your resolve is tested. Endure.",
    [5] = "Reclaim the initiative!",
    [6] = "Even saints bleed.",
}

local function _maybe_emit_flavor(new_id, old_id, t)
    if not new_id or not old_id or new_id == old_id then
        return
    end
    local last = mod._faith_flavor_last_t or -9999
    if (t - last) < FLAVOR_COOLDOWN_S then
        return
    end

    local going_up = new_id > old_id
    local line = going_up and FLAVOR_UP[new_id] or FLAVOR_DOWN[new_id]
    if not line then
        return
    end

    mod._faith_flavor_text = line
    mod._faith_flavor_until_t = t + FLAVOR_DURATION_S
    mod._faith_flavor_last_t = t
end

function mod:get_faith_state_text()
    return self._faith_state_name or "Resolute"
end

function mod:get_faith_flavor_text()
    local until_t = self._faith_flavor_until_t
    if until_t and self._faith_last_t and self._faith_last_t < until_t then
        return self._faith_flavor_text or ""
    end
    return ""
end


-- ---------------------------------------------------------
-- Kill attribution (keeps what already worked)
-- ---------------------------------------------------------
if CLASS and CLASS.AttackReportManager then
    mod:hook(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit,
        attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, ...)

        -- Only count kills by the local player unit.
        local lp = _local_player()
        local lpu = _local_player_unit(lp)
        if lpu and attacking_unit == lpu and attack_result == "died" then
            local breed = nil
            if ScriptUnit and attacked_unit then
                local unit_data = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
                breed = unit_data and unit_data.breed and unit_data:breed() or nil
            end

            _apply_kill_gain(KILL_BASE_GAIN)

            if _has_tag(breed, "elite") then
                _apply_kill_gain(KILL_ELITE_BONUS)
            elseif _has_tag(breed, "special") then
                _apply_kill_gain(KILL_SPECIAL_BONUS)
            end

            if _has_tag(breed, "disabler") then
                _apply_kill_gain(KILL_DISABLER_BONUS)
            end
        end

        -- Team engagement credit (special kills by any player unit)
        -- Purpose: dampen special-drain when the team is actively resolving specials.
        -- This is intentionally derived from AttackReportManager (authoritative per-client) rather than combat-feed UI,
        -- because combat-feed callbacks can arrive with missing/shifted parameters or units already stripped of extensions.
        if attack_result == "died" and _get_bool("team_enabled", true) then
            local pusm = Managers and Managers.state and Managers.state.player_unit_spawn
            local p = nil
            if pusm and pusm.owner then
                local ok, pp = pcall(pusm.owner, pusm, attacking_unit)
                if ok and pp then p = pp end
            end
            if not p and Managers and Managers.player and Managers.player.player_by_unit then
                local ok, pp = pcall(Managers.player.player_by_unit, Managers.player, attacking_unit)
                if ok and pp then p = pp end
            end
            if not p and Managers and Managers.player and Managers.player.owner then
                local ok, pp = pcall(Managers.player.owner, Managers.player, attacking_unit)
                if ok and pp then p = pp end
            end
            if not p and mod and mod._resolve_player_from_unit and type(mod._resolve_player_from_unit) == "function" then
                local ok, pp = pcall(mod._resolve_player_from_unit, attacking_unit)
                if ok and pp then p = pp end
            end

            if p and ScriptUnit and attacked_unit then
                local unit_data_extension = ScriptUnit.has_extension and ScriptUnit.has_extension(attacked_unit, "unit_data_system")
                local breed = unit_data_extension and unit_data_extension.breed and unit_data_extension:breed() or nil
                local tags = breed and breed.tags

                -- Credit specials only; optionally exclude bosses/monsters.
                if type(tags) == "table" and tags.special then
                    if (not _get_bool("team_exclude_bosses", true)) or not (tags.monster or tags.nemesis or tags.lord or tags.witch) then
                        local add_s = tonumber(_get_number("team_window_s", 6, 0, 30)) or 6
                        if add_s < 0 then add_s = 0 end
                        local cap_s = tonumber(_get_number("team_cap_s", 12, 0, 60)) or 12
                        if cap_s < add_s then cap_s = add_s end

                        mod._team_engage_s = math.min(cap_s, (mod._team_engage_s or 0) + add_s)
                        mod._team_engage_last_add_t = Managers.time and Managers.time:time("main") or 0

                        -- Reuse tk_cred counter so the HUD debug line remains a single source of truth.
                        mod._sp_debug.tk_cred = (mod._sp_debug.tk_cred or 0) + 1
                    end
                end
            end
        end

        return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot,
            damage, attack_result, attack_type, damage_efficiency, ...)
    end)
end

-- ---------------------------------------------------------
-- Update loop (DMF)
-- ---------------------------------------------------------
function mod.update(dt, t)
    if type(dt) ~= "number" then
        return
    end

    if type(t) ~= "number" then
        t = os.clock()
    end

    mod._faith_last_t = t

    local mode_name = _current_game_mode_name()
    mod._faith_last_mode_name = mode_name or mod._faith_last_mode_name

    -- Guard: during boot/title screens the game_mode is not ready and calling
    -- PlayerManager:local_player() can crash the engine on some setups.
    if not mode_name then
        return
    end

    -- Hub behavior: freeze faith and do not tick.
    if _is_hub_mode(mode_name) then
        mod._faith_run_active = false
        -- Initial lock: reset per-run flags when returning to the hub.
        mod._faith_initial_lock_active = false
        mod._faith_initial_lock_started = false
        return
    end

    -- Ensure we consider ourselves "in a run" once we've seen non-hub mode.
    mod._faith_run_active = true

    -- Resolve local player (still needed for some guards + legacy behavior).
    local lp = _local_player()
    if not lp then
        return
    end

    local local_unit = _local_player_unit(lp)
    if not local_unit then
        return
    end

    -- Death detection (local player) - keep v1 behavior: dying zeroes the meter.
    local local_alive = _player_unit_is_alive(lp)
    if mod._faith_was_alive == nil then
        mod._faith_was_alive = local_alive
    elseif mod._faith_was_alive == true and local_alive == false then
        mod._faith_value = 0.0
        mod._last_relief_t = t
    end
    mod._faith_was_alive = local_alive

    -- ---------------------------------------------------------
    -- Phase 2: Team Pressure + Rhythm Model
    -- ---------------------------------------------------------
    mod._pressure_accum = (mod._pressure_accum or 0) + dt
    local tick_s = _get_number("pressure_tick_seconds", 0.25, 0.05, 1.0)

    if mod._pressure_accum < tick_s then
        -- Still run special pressure maintenance so its tracking stays in sync.
        _update_special_pressure(local_unit, t, dt)
        return
    end

    local step = mod._pressure_accum
    mod._pressure_accum = 0

    local pm = Managers and Managers.player
    if not pm or not pm.players then
        return
    end

    local players = pm:players()

    -- Threat Silence: initialize pressure event timestamp once per session.
    if not mod._last_pressure_event_t then
        mod._last_pressure_event_t = t
    end
    if not players then
        return
    end

    local crit_hp_p = _get_number("pressure_health_critical_p", 0.25, 0.05, 0.9)
    local tough_low_p = _get_number("pressure_toughness_low_p", 0.20, 0.0, 0.95)
    local coh_isolate_grace = _get_number("pressure_coherency_isolate_grace_s", 8.0, 0.0, 60.0)
    local disable_grace = _get_number("pressure_disable_grace_s", 3.0, 0.0, 30.0)
    local spike_hp_drop = _get_number("pressure_health_spike_drop_p", 0.12, 0.01, 0.9)
    local tough_break_p = _get_number("pressure_toughness_break_p", 0.05, 0.0, 0.3)

    -- Threat Silence detection (Phase 2.5)
    -- A "pressure event" is recorded when we observe meaningful recent health/toughness loss or active incap states.
    local hp_loss_event_p = _get_number("pressure_hp_loss_event_p", 0.01, 0.0, 0.2)
    local tough_loss_event_p = _get_number("pressure_tough_loss_event_p", 0.02, 0.0, 0.2)
    local silence_window_s = _get_number("pressure_silence_window_s", 4.0, 0.0, 30.0)

    -- Relief window config (rhythm)
    local relief_coh_min = _get_number("pressure_relief_coherency_min", 0.75, 0.0, 1.0)
    local relief_tough_min = _get_number("pressure_relief_toughness_min", 0.30, 0.0, 1.0)
    local relief_timeout_s = _get_number("pressure_relief_timeout_s", 10.0, 1.0, 60.0)

    -- Weighting
    local w_coh = _get_number("pressure_weight_coherency", 1.25, 0.0, 5.0)
    local w_tough = _get_number("pressure_weight_toughness", 1.10, 0.0, 5.0)
    local w_health = _get_number("pressure_weight_health", 0.85, 0.0, 5.0)
    local w_disable = _get_number("pressure_weight_incap", 1.80, 0.0, 6.0)

    local alive = 0
    local in_coh = 0
    local disabled = 0
    local critical_players = 0
    local tough_low_players = 0

    local hp_sum = 0
    local tough_sum = 0

    local spike_events = 0
    local break_events = 0

    -- Build/update per-player telemetry.
    for _, p in pairs(players) do
        local is_human = true
        if p and p.is_human_controlled then
            is_human = _safe_call(p.is_human_controlled, p)
        elseif p and p._is_human_controlled ~= nil then
            is_human = p._is_human_controlled == true
        end

        if is_human and p then
            local u = p.player_unit
            if u and _player_unit_is_alive(p) then
                alive = alive + 1

                local track = mod._team_track[u]
                if not track then
                    track = {
                        last_hp = nil,
                        last_tough = nil,
                        isolated_s = 0,
                        crit_s = 0,
                        tough_low_s = 0,
                        disabled_s = 0,
                        last_break_t = nil,
                    }
                    mod._team_track[u] = track
                end

                local hp_p = _get_health_percent(u)
                local tough_p = _get_toughness_percent(u)

                if type(hp_p) == "number" then
                    hp_sum = hp_sum + hp_p
                end
                if type(tough_p) == "number" then
                    tough_sum = tough_sum + tough_p

                -- Record pressure events for Threat Silence.
                if type(hp_p) == "number" and type(track.last_hp) == "number" then
                    if (track.last_hp - hp_p) >= hp_loss_event_p then
                        mod._last_pressure_event_t = t
                    end
                end
                if type(tough_p) == "number" and type(track.last_tough) == "number" then
                    if (track.last_tough - tough_p) >= tough_loss_event_p then
                        mod._last_pressure_event_t = t
                    end
                end
                end

                -- Health spike detection
                if type(hp_p) == "number" and type(track.last_hp) == "number" then
                    local d = track.last_hp - hp_p
                    if d >= spike_hp_drop then
                        spike_events = spike_events + 1
                    end
                end

                -- Toughness break detection
                if type(tough_p) == "number" and type(track.last_tough) == "number" then
                    local was_ok = track.last_tough > 0.20
                    local now_broken = tough_p <= tough_break_p
                    if was_ok and now_broken then
                        break_events = break_events + 1
                        track.last_break_t = t
                    end
                end

                -- Critical health duration
                if type(hp_p) == "number" and hp_p <= crit_hp_p then
                    track.crit_s = (track.crit_s or 0) + step
                    critical_players = critical_players + 1
                else
                    track.crit_s = math.max(0, (track.crit_s or 0) - step * 0.5)
                end

                -- Low toughness duration
                if type(tough_p) == "number" and tough_p <= tough_low_p then
                    track.tough_low_s = (track.tough_low_s or 0) + step
                    tough_low_players = tough_low_players + 1
                else
                    track.tough_low_s = math.max(0, (track.tough_low_s or 0) - step * 0.5)
                end

                -- Coherency (proxy: has anyone in coherency table)
                local coh_ext = ScriptUnit and ScriptUnit.has_extension and ScriptUnit.has_extension(u, "coherency_system")
                local is_in_coh = false
                if coh_ext and coh_ext.in_coherence_units then
                    local tbl = _safe_call(coh_ext.in_coherence_units, coh_ext)
                    if tbl and type(tbl) == "table" then
                        -- Some implementations include self or use key/value units. Count *other* coherent units.
                        local has_other = false
                        for k, v in pairs(tbl) do
                            local other = nil
                            if type(v) == "userdata" then
                                other = v
                            elseif type(k) == "userdata" then
                                other = k
                            end
                            if other and other ~= u then
                                has_other = true
                                break
                            end
                        end
                        is_in_coh = has_other
                    end
                end

                if is_in_coh then
                    in_coh = in_coh + 1
                    track.isolated_s = math.max(0, (track.isolated_s or 0) - step * 1.0)
                else
                    track.isolated_s = (track.isolated_s or 0) + step
                end

                -- Incap/disabled detection via state machine extension
                local state_name = _get_character_state_name(u)
                local is_disabled = false
                if type(state_name) == "string" then
                    -- Conservative list: expand later as needed.
                    if state_name == "knocked_down"
                        or state_name == "hogtied"
                        or state_name == "pounced"
                        or state_name == "grabbed"
                        or state_name == "netted"
                        or state_name == "dead"
                        or state_name == "ledge_hanging"
                        or state_name == "mutant_charged"
                    then
                        is_disabled = true
                    end
                end

                if is_disabled then
                    track.disabled_s = (track.disabled_s or 0) + step
                    disabled = disabled + 1
                    mod._last_pressure_event_t = t
                else
                    track.disabled_s = math.max(0, (track.disabled_s or 0) - step * 1.0)
                end

                track.last_hp = hp_p
                track.last_tough = tough_p
            end
        end
    end

    if alive < 1 then
        alive = 1
    end

    -- Prune dead units to avoid stale references
    for u, _ in pairs(mod._team_track) do
        if not Unit.alive(u) then
            mod._team_track[u] = nil
        end
    end

    local coh_cov = in_coh / alive
    local hp_avg = hp_sum / alive
    local tough_avg = tough_sum / alive

    -- Isolation penalty: count players isolated beyond grace
    local isolated_long = 0
    local disabled_long = 0
    for u, tr in pairs(mod._team_track) do
        if tr.isolated_s and tr.isolated_s >= coh_isolate_grace then
            isolated_long = isolated_long + 1
        end
        if tr.disabled_s and tr.disabled_s >= disable_grace then
            disabled_long = disabled_long + 1
        end
    end

    local isolated_long_frac = isolated_long / alive
    local disabled_frac = disabled / alive

    -- Compute sub-scores (0..1, higher is better)
    local coh_score = _clamp(coh_cov - isolated_long_frac * 0.60, 0, 1)
    local tough_score = 1.0
    -- Toughness being low is a strong indicator of losing tempo; also include the actual average.
    tough_score = tough_score - _clamp((tough_low_players / alive) * 0.80, 0, 1)
    tough_score = tough_score - _clamp((break_events / alive) * 0.45, 0, 1)
    tough_score = tough_score * _clamp(tough_avg, 0, 1)
    tough_score = _clamp(tough_score, 0, 1)

    local health_score = 1.0
    -- Persistent low health is a failure signature; spikes are worse.
    health_score = health_score - _clamp((1.0 - _clamp(hp_avg, 0, 1)) * 0.55, 0, 1)
    health_score = health_score - _clamp((critical_players / alive) * 0.80, 0, 1)
    health_score = health_score - _clamp((spike_events / alive) * 0.45, 0, 1)
    health_score = _clamp(health_score, 0, 1)

    local incap_score = 1.0
    incap_score = incap_score - _clamp(disabled_frac * 1.10, 0, 1)
    -- Extra penalty if disables persist
    incap_score = incap_score - _clamp((disabled_long / alive) * 0.60, 0, 1)
    incap_score = _clamp(incap_score, 0, 1)

    local w_sum = (w_coh + w_tough + w_health + w_disable)
    if w_sum <= 0 then
        w_sum = 1
    end

    local pressure_norm = (coh_score * w_coh + tough_score * w_tough + health_score * w_health + incap_score * w_disable) / w_sum
    pressure_norm = _clamp(pressure_norm, 0, 1)

    -- Relief detection: coherency stable, no disables, toughness not bottomed out.
    -- Threat Silence: if we have not observed any meaningful pressure events recently,
    -- allow a "recovery relief" window even if the team is still rebuilding toughness/coherency.
    local specials_engaged_now = false
    if mod._sp_debug and type(mod._sp_debug.engaged) == "number" then
        specials_engaged_now = mod._sp_debug.engaged > 0
    end

    local seconds_since_pressure = t - (mod._last_pressure_event_t or t)
    local threat_silent = (disabled == 0) and (not specials_engaged_now) and (seconds_since_pressure >= silence_window_s)

    -- Relief detection:
    --  * Combat relief: team is stabilized (coherency + no incaps + toughness above floor + no critical health).
    --  * Recovery relief: threat has gone quiet for long enough; we treat this as a reset window.
    local relief_combat = (coh_cov >= relief_coh_min) and (disabled == 0) and (tough_avg >= relief_tough_min) and (critical_players == 0) and (tough_low_players <= 1)
    local relief_recovery = threat_silent
    local relief = relief_combat or relief_recovery
    local relief_type = relief_combat and "combat" or (relief_recovery and "recovery" or "none")

    if relief then
        mod._last_relief_t = t
    end
    if not mod._last_relief_t then
        mod._last_relief_t = t
    end

    local since_relief = t - (mod._last_relief_t or t)
    local relief_penalty = 0
    if (not threat_silent) and since_relief > relief_timeout_s then
        relief_penalty = _clamp((since_relief - relief_timeout_s) / relief_timeout_s, 0, 1)
    end

    -- Publish debug fields
    mod._pressure_debug.threat_silent = threat_silent
    mod._pressure_debug.seconds_since_pressure = seconds_since_pressure
    mod._pressure_debug.relief_type = relief_type
    -- Convert to Faith deltas: reward control, punish sustained lack of relief and incaps.
    local gain_per_s = _get_number("pressure_faith_gain_per_s", 2.5, 0.0, 20.0)
    local decay_per_s = _get_number("pressure_faith_decay_per_s", 3.0, 0.0, 30.0)

    -- Map: 0.5 is neutral
    local centered = (pressure_norm - 0.5) * 2.0 -- [-1..1]
    local delta = centered * gain_per_s * step

    -- Additional decay when no relief windows occur
    delta = delta - decay_per_s * relief_penalty * step

    -- Incap snowball penalty: very strong signal of failure.
    if disabled >= 2 then
        delta = delta - _get_number("pressure_multi_incap_penalty", 6.0, 0.0, 50.0) * step
    elseif disabled == 1 then
        delta = delta - _get_number("pressure_single_incap_penalty", 2.0, 0.0, 30.0) * step
    end

    -- Block positive gains while local player is hogtied rescue state (hands tied behind back).
    mod._faith_block_positive = _is_hogtied_rescue_state(local_unit)
    if mod._faith_block_positive and delta > 0 then
        delta = 0
    end

    -- ---------------------------------------------------------
    -- Initial meter lock (start-of-mission)
    --   Hold faith at a fixed value until the first special engagement signal is observed.
    --   Any INCAP/disabled state immediately breaks the lock (incap is pressure).
    -- ---------------------------------------------------------
    if mod._faith_initial_lock_active then
        local unlock_by_special = (mod._sp_sound and (mod._sp_sound.events_matched or 0) > 0) or false
        if disabled > 0 or unlock_by_special then
            mod._faith_initial_lock_active = false
        else
            -- While locked, do not apply any delta and do not allow special pressure drain to modify the meter.
            delta = 0
            mod._faith_value = _get_number("initial_lock_value", 50.0, 0.0, 100.0)
        end
    end

    -- Apply
    mod._faith_value = _clamp((mod._faith_value or 50) + delta, 0.0, 100.0)

    -- Keep special pressure drain as an optional extra mechanic
    _update_special_pressure(local_unit, t, step)

    -- Update debug
    mod._pressure_debug.score = math.floor(mod._faith_value + 0.5)
    mod._pressure_debug.coh_coverage = coh_cov
    mod._pressure_debug.disabled = disabled
    mod._pressure_debug.alive = alive
    mod._pressure_debug.toughness_avg = tough_avg
    mod._pressure_debug.health_avg = hp_avg
    mod._pressure_debug.critical_players = critical_players
    mod._pressure_debug.toughness_low_players = tough_low_players
    mod._pressure_debug.toughness_breaks_per_s = break_events / math.max(0.001, step)
    mod._pressure_debug.relief = relief
    mod._pressure_debug.seconds_since_relief = since_relief
    mod._pressure_debug.initial_lock = mod._faith_initial_lock_active and 1 or 0

    -- Update faith state + emit a brief flavor line when crossing thresholds.
    local sid, sname = _state_for_value(mod._faith_value or 50)
    local old = mod._faith_state_id
    mod._faith_state_id = sid
    mod._faith_state_name = sname
    _maybe_emit_flavor(sid, old, t)
end

function mod.on_setting_changed(setting_id)
    -- HUD reads settings live; no action needed.
end

return mod
