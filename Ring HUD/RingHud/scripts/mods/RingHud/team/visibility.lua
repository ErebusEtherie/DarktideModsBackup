-- File: RingHud/scripts/mods/RingHud/team/visibility.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Public namespace (cross-file): attach to `mod.` per your rule.
mod.team_visibility = mod.team_visibility or {}
local V = mod.team_visibility

local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

-- Internal: Team HUD globally enabled?
local function _enabled()
    local m = mod._settings and mod._settings.team_hud_mode
    return m and m ~= "team_hud_disabled"
end

-- Small helpers for dropdown gating
local function _pocketables_local_enabled()
    local v = mod._settings and mod._settings.pocketable_visibility_dropdown
    -- treat nil/missing as contextual (enabled)
    return v ~= "pocketable_disabled"
end

local function _team_pockets_enabled_now()
    local v = (mod._settings and mod._settings.team_pockets) or "team_pockets_context"
    return v ~= "team_pockets_disabled"
end

-- Utility: current "now" time (ui preferred, then gameplay, then os.clock)
local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("ui") or MT:time("gameplay") or os.clock()
    end
    return os.clock()
end

-- Optional convenience: derive whether "force show" is active right now.
-- (Callers may also pass an explicit boolean to the functions below.)
-- Includes ADS force-show if the mod sets that flag.
function V.force_show_requested()
    if not _enabled() then return false end
    return (mod.show_all_hud_hotkey_active == true)
        or (rawget(mod, "ads_force_show_active") == true)
        or (rawget(mod, "ads_active_force_show") == true) -- alt flag name, if you wire it this way
end

-- ###########
-- New helpers
-- ###########

-- Returns true when the local player is considered "dead" from a HUD POV.
function V.local_player_is_dead()
    -- Always use Managers.player:local_player_safe(1)
    local player = Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)
    local unit   = player and player.player_unit

    if not (unit and Unit.alive(unit)) then
        return true
    end

    local uds = ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
    local he  = ScriptUnit.has_extension(unit, "health_system") and ScriptUnit.extension(unit, "health_system")

    if uds and he then
        local cs = uds:read_component("character_state")
        return PlayerUnitStatus.is_dead(cs, he)
    end

    return false
end

-- Dead OR hogtied wrapper for convenience in context rules.
function V.local_player_dead_or_hogtied()
    if V.local_player_is_dead() then
        return true
    end

    local player = Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)
    local unit   = player and player.player_unit
    if not (unit and Unit.alive(unit)) then
        return true
    end

    local uds = ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
    if not uds then
        return false
    end
    local cs = uds:read_component("character_state")

    -- Try the official util if available; keep it safe with pcall.
    local ok, hog = pcall(function() return PlayerUnitStatus.is_hogtied and PlayerUnitStatus.is_hogtied(cs) end)
    if ok and hog == true then
        return true
    end

    local ok2, dis = pcall(function() return PlayerUnitStatus.is_disabled and PlayerUnitStatus.is_disabled(cs) end)
    if ok2 and dis == true then
        return true
    end

    return false
end

-- High-intensity combat wrapper (centralized for reuse).
function V.high_intensity_active()
    if not _enabled() then
        return false
    end
    if type(mod.high_intensity_active) == "function" then
        local ok, res = pcall(mod.high_intensity_active, mod)
        if ok and res == true then return true end
    end
    return rawget(mod, "high_intensity") == true
end

-- === NEW: unified definition ===============================================
-- interlude is TRUE when either:
--   (A) NOT music-high AND NOT intensity-timer-active AND everyone (local + alive teammates)
--       is FULL on HP, ammo reserve, and toughness
--   OR
--   (B) the local player is dead OR hogtied
local function _unit_is_full(u)
    if not (u and Unit.alive(u)) then
        return false
    end

    -- HP full
    local he = ScriptUnit.has_extension(u, "health_system") and ScriptUnit.extension(u, "health_system")
    local hp_ok = true
    if he and he.current_health_percent then
        hp_ok = ((he:current_health_percent() or 0) >= 0.999)
    end

    -- Ammo reserve full (treat “no reserve concept” as full)
    local uds = ScriptUnit.has_extension(u, "unit_data_system") and ScriptUnit.extension(u, "unit_data_system")
    local ammo_ok = true
    if uds then
        local comp = uds:read_component("slot_secondary")
        if comp and comp.max_ammunition_reserve and comp.max_ammunition_reserve > 0 then
            local frac = math.clamp((comp.current_ammunition_reserve or 0) / comp.max_ammunition_reserve, 0, 1)
            ammo_ok = (frac >= 0.999)
        end
    end

    -- Toughness full
    local t_ext = ScriptUnit.has_extension(u, "toughness_system") and ScriptUnit.extension(u, "toughness_system")
    local tough_ok = true
    if t_ext then
        if t_ext.current_toughness_percent then
            tough_ok = ((t_ext:current_toughness_percent() or 0) >= 0.999)
        elseif t_ext.remaining_toughness and t_ext.max_toughness_visual then
            local cur = t_ext:remaining_toughness() or 0
            local mx  = t_ext:max_toughness_visual() or 0
            tough_ok  = (mx <= 0) or (cur >= mx - 0.5)
        end
    end

    return hp_ok and ammo_ok and tough_ok
end

local function _all_alive_teammates_full()
    local pm = Managers.player
    if not (pm and pm.players) then return false end

    local ok, players = pcall(function() return pm:players() end)
    if not ok or type(players) ~= "table" then return false end

    for _, p in pairs(players) do
        local u = p and p.player_unit
        if u and Unit.alive(u) then
            if not _unit_is_full(u) then
                return false
            end
        end
    end

    return true
end

local function _local_player_full()
    local lp  = Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)
    local lpu = lp and lp.player_unit
    return _unit_is_full(lpu)
end

function V.interlude()
    if not _enabled() then
        return false
    end

    -- Read explicit flags if the mod exposes them; otherwise fall back to the
    -- aggregate high-intensity helper.
    local music_hi = rawget(mod, "is_music_high_intensity") == true
    local timer_hi = rawget(mod, "is_high_intensity_timer_active") == true
    local encounter_calm

    if music_hi ~= nil or timer_hi ~= nil then
        encounter_calm = (music_hi == false) and (timer_hi == false)
    else
        -- Fallback: treat "not high_intensity_active()" as calm.
        encounter_calm = (V.high_intensity_active() ~= true)
    end

    local resources_full = _local_player_full() and _all_alive_teammates_full()
    if (encounter_calm and resources_full) then
        return true
    end

    if V.local_player_dead_or_hogtied() then
        return true
    end

    return false
end

-- ---------------
-- Context gate(s)
-- ---------------
local function _teammate_context_gate(peer, force_show)
    if not _enabled() then
        return false
    end

    peer = peer or {}

    -- Force channels (unified hotkey already includes ADS via RingHud.lua)
    local forced = (force_show == true) or V.force_show_requested()
    if forced then
        return true
    end

    -- Visible in interlude (per new unified definition)
    if V.interlude() then
        return true
    end

    -- Visible while reassurance flag is set
    if rawget(mod, "reassure_health") == true then
        return true
    end

    -- Recent HP change latch (mirrors the local player's toughness bar rule)
    local now = _now()
    if type(peer.hp_show_until) == "number" and now < peer.hp_show_until then
        return true
    end

    -- Overshield or toughness broken on that teammate
    if peer.tough_overshield == true or peer.tough_broken == true then
        return true
    end

    -- Proximity-driven rules (local player near X …)
    local hp_frac  = math.clamp(peer.hp_fraction or 1, 0, 1)
    local cor_frac = math.clamp(peer.corruption_fraction or 0, 0, 1)

    -- near_health_station and teammate HP < 100%
    if rawget(mod, "near_health_station") == true and hp_frac < 0.999 then
        return true
    end

    -- near_medical_crate_deployable and teammate (HP + corruption) < 100%
    if rawget(mod, "near_medical_crate_deployable") == true and (hp_frac + cor_frac) < 0.999 then
        return true
    end

    -- near_syringe_corruption_pocketable and teammate HP < 85%
    if rawget(mod, "near_syringe_corruption_pocketable") == true and hp_frac < 0.85 then
        return true
    end

    -- Local player is currently wielding any stimm or any crate (new unified latches)
    if V.any_stimm_wield_latched() or V.any_crate_wield_latched() then
        return true
    end

    -- Low HP fail-safe: below 20% OR below 1 whole segment (whichever is LOWER).
    local segs    = tonumber(peer.max_wounds_segments) or 0
    local one_seg = (segs > 0) and (1.0 / segs) or 1.0
    local thresh  = math.min(0.20, one_seg)
    if hp_frac <= (thresh + 1e-6) then
        return true
    end

    return false
end

-- ########
-- HP bar
-- ########
function V.hp_bar(peer, force_show)
    if not _enabled() then return false end
    local v = (mod._settings and mod._settings.team_hp_bar) or "team_hp_bar_context"
    if v == "team_hp_bar_disabled" then return false end
    if v == "team_hp_bar_always" then return true end
    return _teammate_context_gate(peer, force_show)
end

-- ########
-- HP text
-- ########
function V.hp_text(peer, force_show)
    if not _enabled() then return false end
    local v = (mod._settings and mod._settings.team_hp_bar) or "team_hp_bar_context"
    if v == "team_hp_bar_text_always" then
        return true
    elseif v == "team_hp_bar_text_context" then
        return _teammate_context_gate(peer, force_show)
    end
    return false
end

-- ############
-- Munitions
-- ############
function V.munitions(force_show)
    if not _enabled() then return false end
    local v = (mod._settings and mod._settings.team_munitions) or "team_munitions_context"
    if v == "team_munitions_disabled" then return false end
    if v == "team_munitions_always" then return true end

    -- NEW: show munitions contextually when local just wielded an ammo cache
    if V.any_ammo_cache_wield_latched() then
        return true
    end

    return (force_show == true)
end

-- #########
-- Pockets
-- #########
function V.pockets(force_show)
    if not _enabled() then return false end
    local v = (mod._settings and mod._settings.team_pockets) or "team_pockets_context"
    if v == "team_pockets_disabled" then return false end
    if v == "team_pockets_always" then return true end
    return (force_show == true)
end

-- ================================
-- NEW: wield-latch pocketable gates
-- ================================
-- IMPORTANT: These latches should NOT depend on team pockets visibility.
-- They’re used by teammate HP gating as well.
function V.any_stimm_wield_latched()
    if not _enabled() then
        return false
    end
    local until_t = rawget(mod, "local_wield_any_stimm_until")
    local now     = _now()
    return (type(until_t) == "number") and (now < until_t)
end

function V.any_crate_wield_latched()
    if not _enabled() then
        return false
    end
    local until_t = rawget(mod, "local_wield_any_crate_until")
    local now     = _now()
    return (type(until_t) == "number") and (now < until_t)
end

-- NEW: ammo-cache–specific wield latch (drives teammate munitions visibility)
function V.any_ammo_cache_wield_latched()
    if not _enabled() then
        return false
    end
    local until_t = rawget(mod, "local_wield_ammo_cache_until")
    local now     = _now()
    return (type(until_t) == "number") and (now < until_t)
end

-- =========================================
-- NEW: near-source helpers with audience gate
-- =========================================
-- Prefer the proximity_system function; otherwise fall back to flags
local function _near_any_stimm_source_raw()
    if type(mod.near_stimm_source) == "function" then
        local ok, res = pcall(mod.near_stimm_source, mod); if ok and res then return true end
    end
    -- Fallbacks: align with proximity_system.lua published flags
    return rawget(mod, "near_syringe_corruption_pocketable") == true
        or rawget(mod, "near_syringe_power_boost_pocketable") == true
        or rawget(mod, "near_syringe_speed_boost_pocketable") == true
        or rawget(mod, "near_syringe_ability_boost_pocketable") == true
        or rawget(mod, "near_health_station") == true
end

local function _near_any_crate_source_raw()
    if type(mod.near_crate_source) == "function" then
        local ok, res = pcall(mod.near_crate_source, mod); if ok and res then return true end
    end
    return rawget(mod, "near_medical_crate_pocketable") == true
        or rawget(mod, "near_medical_crate_deployable") == true
        or rawget(mod, "near_ammo_cache_pocketable") == true
        or rawget(mod, "near_ammo_cache_deployable") == true
end

-- audience: "team" (default) or "local"
function V.near_stimm_source(audience)
    if not _enabled() then return false end
    local near = _near_any_stimm_source_raw()
    if not near then return false end

    local who = audience or "team"
    if who == "local" then
        return _pocketables_local_enabled()
    else -- "team" path (default)
        return _team_pockets_enabled_now() and _pocketables_local_enabled()
    end
end

function V.near_crate_source(audience)
    if not _enabled() then return false end
    local near = _near_any_crate_source_raw()
    if not near then return false end

    local who = audience or "team"
    if who == "local" then
        return _pocketables_local_enabled()
    else
        return _team_pockets_enabled_now() and _pocketables_local_enabled()
    end
end

-- ############
-- Counters
-- ############
function V.counters(force_show)
    if not _enabled() then return false, false end
    local v = (mod._settings and mod._settings.team_counters) or "team_counters_cd"
    if v == "team_counters_disabled" then return false, false end
    if v == "team_counters_cd" then return true, false end
    if v == "team_counters_toughness" then return false, true end
    if v == "team_counters_cd_toughness" then return true, true end
    if force_show == true then
        return true, true
    end
    return false, false
end

function V.any_counter(force_show)
    local show_cd, show_tough = V.counters(force_show)
    return show_cd or show_tough
end

return V
