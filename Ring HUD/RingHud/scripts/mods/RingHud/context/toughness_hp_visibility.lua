-- File: RingHud/scripts/mods/RingHud/context/toughness_hp_visibility.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Public namespace (cross-file): attach to mod.* per your rule.
mod.toughness_hp_visibility = mod.toughness_hp_visibility or {}
local THV                   = mod.toughness_hp_visibility

-- Deps
local Intensity             = mod:io_dofile("RingHud/scripts/mods/RingHud/context/intensity_context")

----------------------------------------------------------------
-- Time helper (prefer UI time, then gameplay, then os.clock)
----------------------------------------------------------------
local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return (MT:time("ui") or MT:time("gameplay") or os.clock())
    end
    return os.clock()
end

----------------------------------------------------------------
-- Debug / Throttle State
----------------------------------------------------------------
local _debug_throttle_t = 0

-- Helper to check proximity condition and echo if triggered (throttled 1s)
local function _check_prox_and_echo_thv(condition, frac, threshold, label)
    if condition and frac < threshold then
        -- local t = _now()
        -- if t > _debug_throttle_t then
        --     mod:echo("RingHud Vis: %s (HP %.0f%%)", label, frac * 100)
        --     _debug_throttle_t = t + 1.0
        -- end
        return true
    end
    return false
end

----------------------------------------------------------------
-- Cached Settings (updated via on_setting_changed)
----------------------------------------------------------------
-- We assume mod._settings is populated at init and refreshed centrally.
local _S = {
    team_hud_mode           = nil, -- "team_hud_disabled" | "team_hud_icons_*" | others
    team_hp_bar             = nil, -- "team_hp_disabled" | "team_hp_bar_context_text_off" | "..._always" | "..._text_*"
    toughness_bar_dropdown  = nil, -- "toughness_bar_disabled" | "..._always*" | "..._context*"
    ads_visibility_dropdown = nil, -- for ADS-as-force-show behavior if you wire it
}

function mod.thv_on_setting_changed()
    local s = rawget(mod, "_settings")
    if not s then return end
    _S.team_hud_mode           = s.team_hud_mode
    _S.team_hp_bar             = s.team_hp_bar
    _S.toughness_bar_dropdown  = s.toughness_bar_dropdown
    _S.ads_visibility_dropdown = s.ads_visibility_dropdown
end

-- Initialise once
mod.thv_on_setting_changed()

----------------------------------------------------------------
-- Tunables / thresholds
----------------------------------------------------------------
local TUNE                  = {
    player_recent_change_secs = 5.0,  -- keep player bar visible after HP/corruption change
    team_recent_change_secs   = 10.0, -- keep peer widget visible after their HP/corruption change
    low_hp_threshold          = 0.20, -- “low HP” fallback
}

----------------------------------------------------------------
-- Latches & timers (stored on mod.* for debug / cross-file access)
----------------------------------------------------------------
mod._thv_player_until_t     = mod._thv_player_until_t or 0
mod._thv_team_until_by_peer = mod._thv_team_until_by_peer or {}

-- Simple public “bump” helpers you can call from wherever you detect deltas
function mod.thv_player_recent_change_bump()
    mod._thv_player_until_t = _now() + TUNE.player_recent_change_secs
end

function mod.thv_team_recent_change_bump(peer_id)
    if not peer_id then return end
    mod._thv_team_until_by_peer[peer_id] = _now() + TUNE.team_recent_change_secs
end

----------------------------------------------------------------
-- Small helpers (signals aggregated from other contexts)
----------------------------------------------------------------
local function _force_show_active()
    -- Unified hotkey already includes ADS force-show via RingHud.lua if you’ve wired it.
    return (mod.show_all_hud_hotkey_active == true)
        or (rawget(mod, "ads_force_show_active") == true)
        or (rawget(mod, "ads_active_force_show") == true)
end

local function _reassure_health_active()
    return rawget(mod, "reassure_health") == true
end

local function _wield_heal_latch_active(now_t)
    local until_t = rawget(mod, "local_wield_heal_tool_until")
    return type(until_t) == "number" and now_t < until_t
end

local function _spectating_active()
    -- Prefer the intensity helper if present so all contexts agree on “dead enough”.
    if Intensity and Intensity.local_player_dead_or_hogtied then
        return Intensity.local_player_dead_or_hogtied()
    end

    -- Conservative fallback if helper not available.
    local MP = Managers and Managers.player
    if not MP or not MP.local_player_safe then
        return false
    end

    local lp = MP:local_player_safe(1)
    if not lp then
        return false
    end

    if lp.is_spectator and lp:is_spectator() then
        return true
    end

    return false
end

----------------------------------------------------------------
-- Disabled / Always-on checks (Teammates)
----------------------------------------------------------------
local function _team_hp_disabled()
    return _S.team_hud_mode == "team_hud_disabled"
        or _S.team_hp_bar == "team_hp_disabled"
        or _S.team_hud_mode == "team_hud_icons_vanilla"
        or _S.team_hud_mode == "team_hud_icons_docked"
end

local function _team_hp_always()
    return _S.team_hp_bar == "team_hp_bar_always_text_off"
        or _S.team_hp_bar == "team_hp_bar_always_text_context"
end

local function _team_hp_text_enabled()
    local v = _S.team_hp_bar
    return v == "team_hp_bar_always_text_context"
        or v == "team_hp_bar_context_text_context"
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------
-- PLAYER ----------------------------------------------------------------------
-- Returns table { bar = bool, text = bool }
function mod.thv_player(ctx)
    local result  = { bar = false, text = false }
    local setting = _S.toughness_bar_dropdown

    -- 1. Disabled Check
    if setting == "toughness_bar_disabled" then
        return result
    end

    -- 2. Define Mode Capabilities
    -- "Always" modes for the BAR
    local bar_always    = (setting == "toughness_bar_always")
        or (setting == "toughness_bar_always_hp")
        or (setting == "toughness_bar_always_hp_text")

    -- "Text" modes (if not in this list, text is hidden)
    local text_possible = (setting == "toughness_bar_auto_hp_text")
        or (setting == "toughness_bar_always_hp_text")

    -- Optimization: If we know bar is visible and text is impossible, we can return early without context checks.
    if bar_always and not text_possible then
        return { bar = true, text = false }
    end

    -- 3. Calculate Context (Is the player in a state where HUD is relevant?)
    -- We need context if the bar is NOT always on, OR if text IS enabled (text is always context-driven per new rules).
    local context_active = false

    local now_t          = _now()
    local hp_frac        = tonumber(ctx and ctx.hp_fraction) or 0
    local cor_frac       = tonumber(ctx and ctx.corruption_fraction) or 0
    local tough_frac     = tonumber(ctx and ctx.toughness_fraction) or 0
    local near_station   = (ctx and ctx.near_health_station) ~= nil and ctx.near_health_station or
        (rawget(mod, "near_health_station") == true)
    local near_med_crate = (ctx and ctx.near_med_crate) ~= nil and ctx.near_med_crate or
        (rawget(mod, "near_medical_crate_deployable") == true)

    -- Context Checks
    if _force_show_active() then
        context_active = true
    elseif _reassure_health_active() then
        context_active = true
    elseif _wield_heal_latch_active(now_t) then
        context_active = true
    elseif tough_frac < 0.999 then
        context_active = true
    elseif ctx and ctx.has_overshield == true then
        context_active = true
    elseif _check_prox_and_echo_thv(near_station, hp_frac, 0.999, "Near Health Station") then
        context_active = true
    elseif _check_prox_and_echo_thv(near_med_crate, hp_frac + cor_frac, 0.999, "Near Med Crate") then
        context_active = true
    elseif hp_frac <= TUNE.low_hp_threshold then
        context_active = true
    elseif (mod._thv_player_until_t or 0) > now_t then
        context_active = true
    end

    -- 4. Apply Logic
    -- Bar: Visible if mode is "Always" OR if Context is active
    result.bar = bar_always or context_active

    -- Text: Visible ONLY if text mode is enabled AND Context is active
    result.text = text_possible and context_active

    return result
end

-- TEAMMATE --------------------------------------------------------------------
-- peer_ctx:
--   hp_fraction            ∈ [0..1]
--   corruption_fraction    ∈ [0..1]
--   max_wounds_segments    integer (>=1)
--   tough_overshield       boolean
--   tough_broken           boolean
--   is_spectating_local    boolean (optional; falls back to shared helper)
--   near_health_station    boolean (optional)
--   near_med_crate         boolean (optional)
-- returns { show_bar = bool, show_text = bool }
function mod.thv_team_for_peer(peer_id, peer_ctx)
    local result = { show_bar = false, show_text = false }

    -- Team HP disabled entirely or icons-only?
    if _team_hp_disabled() then
        return result
    end

    local text_enabled = _team_hp_text_enabled()

    -- Always-on?
    if _team_hp_always() then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end

    local now_t          = _now()
    local hp_frac        = tonumber(peer_ctx and peer_ctx.hp_fraction) or 0
    local cor_frac       = tonumber(peer_ctx and peer_ctx.corruption_fraction) or 0
    local wounds_max     = math.max(tonumber(peer_ctx and peer_ctx.max_wounds_segments) or 0, 0)
    local near_station   = (peer_ctx and peer_ctx.near_health_station) ~= nil and peer_ctx.near_health_station or
        (rawget(mod, "near_health_station") == true)
    local near_med_crate = (peer_ctx and peer_ctx.near_med_crate) ~= nil and peer_ctx.near_med_crate or
        (rawget(mod, "near_medical_crate_deployable") == true)
    local spectating     = (peer_ctx and peer_ctx.is_spectating_local) ~= nil and peer_ctx.is_spectating_local or
        _spectating_active()

    -- Global context gates
    local forced         = _force_show_active() or _reassure_health_active() or _wield_heal_latch_active(now_t)
    if forced then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end

    -- Spectating (local dead/hogtied): show all teammate health widgets
    if spectating then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end

    -- Toughness states (peer) - either makes the widget visible
    if peer_ctx and (peer_ctx.tough_overshield == true or peer_ctx.tough_broken == true) then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end

    -- Proximity rules
    if _check_prox_and_echo_thv(near_station, hp_frac, 0.999, "Team Near Health Station") then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end
    if _check_prox_and_echo_thv(near_med_crate, hp_frac + cor_frac, 0.999, "Team Near Med Crate") then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end

    -- Low HP / last wound failsafe
    local low_hp     = (hp_frac <= TUNE.low_hp_threshold)
    local last_wound = (wounds_max >= 1) and (hp_frac <= (1.0 / wounds_max + 1e-5))
    if low_hp or last_wound then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end

    -- Recent change window (per peer)
    local until_t = mod._thv_team_until_by_peer[peer_id]
    if until_t and now_t < until_t then
        result.show_bar  = true
        result.show_text = text_enabled
        return result
    end

    -- Otherwise hidden in contextual mode
    return result
end

return THV
