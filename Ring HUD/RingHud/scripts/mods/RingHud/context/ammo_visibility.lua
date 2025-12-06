-- File: RingHud/scripts/mods/RingHud/context/ammo_visibility.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Keep everything exposed under mod.* for cross-file access (per your rule)
mod.ammo_visibility = mod.ammo_visibility or {}
local AV            = mod.ammo_visibility

-- Deps
local V             = mod.team_visibility or
    mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")

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
local function _check_prox_and_echo(is_near, current_frac, threshold, label)
    if is_near and current_frac < threshold then
        -- local t = _now()
        -- if t > _debug_throttle_t then
        --     mod:echo("RingHud Vis: %s (Reserve %.0f%%)", label, current_frac * 100)
        --     _debug_throttle_t = t + 1.0
        -- end
        return true
    end
    return false
end

----------------------------------------------------------------
-- Cached Settings (updated via on_setting_changed)
----------------------------------------------------------------
-- NOTE: We assume mod._settings is populated at init and refreshed centrally.
--       We cache only the keys we need in locals for faster access.
local _S = {
    -- "team_hud_disabled" | "team_hud_docked" | "team_hud_floating" | etc.
    team_hud_mode           = nil,

    -- New enum family:
    --   "team_munitions_disabled"
    --   "team_munitions_ammo_only_always"
    --   "team_munitions_ammo_only_context"
    --   "team_munitions_ammo_always_cd_always"
    --   "team_munitions_ammo_context_cd_enabled"
    team_munitions          = nil,

    -- Player reserve visibility mode
    --   "ammo_reserve_disabled"
    --   "ammo_reserve_percent_always"
    --   "ammo_reserve_actual_always"
    --   plus context/auto variants
    ammo_reserve_dropdown   = nil,

    -- kept for completeness; unified force-show already accounts for ADS
    ads_visibility_dropdown = nil,
}

-- Call from your centralised on_setting_changed to refresh these.
function mod.ammo_vis_on_setting_changed()
    local s = rawget(mod, "_settings")
    if not s then return end
    _S.team_hud_mode           = s.team_hud_mode
    _S.team_munitions          = s.team_munitions
    _S.ammo_reserve_dropdown   = s.ammo_reserve_dropdown
    _S.ads_visibility_dropdown = s.ads_visibility_dropdown
end

-- Initialise once
mod.ammo_vis_on_setting_changed()

----------------------------------------------------------------
-- Tunables / thresholds
----------------------------------------------------------------
local TUNE                       = {
    recent_change_secs_player = 3.0,  -- player "pop-on" after reserve change
    recent_change_secs_team   = 10.0, -- teammate "pop-on" after their reserve change
    near_small_clip_threshold = 0.85, -- show if reserve < 85%
    near_large_clip_threshold = 0.65, -- show if reserve < 65%
    near_ammo_cache_threshold = 0.45, -- show if reserve < 45%
    low_reserve_threshold     = 0.25, -- always context-show if reserve < 25%
}

----------------------------------------------------------------
-- Latches & timers
----------------------------------------------------------------
mod._ammo_vis_player_until_t     = mod._ammo_vis_player_until_t or 0
mod._ammo_vis_team_until_by_peer = mod._ammo_vis_team_until_by_peer or {} -- [peer_id] = until_t

-- Public bumpers (call these when a reserve change is detected)
function mod.ammo_vis_player_recent_change_bump()
    mod._ammo_vis_player_until_t = _now() + TUNE.recent_change_secs_player
end

function mod.ammo_vis_team_recent_change_bump(peer_id)
    if not peer_id then return end
    mod._ammo_vis_team_until_by_peer[peer_id] = _now() + TUNE.recent_change_secs_team
end

----------------------------------------------------------------
-- Helpers: state predicates
----------------------------------------------------------------
-- Unified “force show” (hotkey + ADS-hotkey) via team visibility.
local function _force_show_active()
    if V and V.force_show_requested then
        return V.force_show_requested()
    end
    return mod.show_all_hud_hotkey_active == true
end

-- Optional “reassure ammo” flag (e.g. after pickup caches / events).
local function _reassure_ammo_active()
    return rawget(mod, "reassure_ammo") and (mod.reassure_ammo == true)
end

-- Any wield latch that implies “ammo context” (ammo cache / any crate).
local function _wield_latch_active()
    if not V then return false end
    if V.any_ammo_cache_wield_latched and V.any_ammo_cache_wield_latched() then
        return true
    end
    if V.any_crate_wield_latched and V.any_crate_wield_latched() then
        return true
    end
    return false
end

-- Spectating / dead-or-hogtied from a HUD POV.
local function _spectating_active()
    if V and V.local_player_dead_or_hogtied then
        return V.local_player_dead_or_hogtied()
    end

    -- Fallback: conservative default (don’t infer spectate without a clear API)
    local MP = Managers and Managers.player
    if not MP or not MP.local_player_safe then return false end
    local lp = MP:local_player_safe(1)
    if not lp then return false end
    if lp.is_spectator and lp:is_spectator() then return true end
    return false
end

local function _is_infinite_or_unknown(reserve_frac_or_nil)
    -- If we don't have a finite reserve fraction, treat as non-displayable
    return reserve_frac_or_nil == nil
end

local function _player_reserve_frac_from_state(hud_state)
    if not hud_state then return nil end
    if hud_state.reserve_frac ~= nil then
        return hud_state.reserve_frac
    end
    local ad = hud_state.ammo_data
    if ad and (ad.max_reserve or 0) > 0 then
        local cur = ad.current_reserve or 0
        local max = ad.max_reserve or 0
        return math.clamp(cur / max, 0, 1)
    end
    return nil -- infinite/unknown
end

----------------------------------------------------------------
-- Central rule evaluators
----------------------------------------------------------------

-- Player decision: return boolean "show?"
-- hud_state may omit reserve_frac; we’ll derive from hud_state.ammo_data if needed.
function mod.ammo_vis_player(hud_state)
    -- Disabled entirely?
    if _S.ammo_reserve_dropdown == "ammo_reserve_disabled" then
        return false
    end

    local reserve_frac = _player_reserve_frac_from_state(hud_state)
    local now_t        = _now()

    -- Infinite/unknown reserve? Hide.
    if _is_infinite_or_unknown(reserve_frac) then
        return false
    end

    -- Always-on modes
    if _S.ammo_reserve_dropdown == "ammo_reserve_percent_always"
        or _S.ammo_reserve_dropdown == "ammo_reserve_actual_always" then
        return true
    end

    -- Global context gates
    if _force_show_active() then return true end
    if _reassure_ammo_active() then return true end
    if _wield_latch_active() then return true end
    if now_t < (mod._ammo_vis_player_until_t or 0) then return true end

    -- Proximity thresholds
    -- NOTE: Uses helper to echo debug alerts when these specific rules trigger
    if _check_prox_and_echo(mod.near_small_clip, reserve_frac, TUNE.near_small_clip_threshold, "Near Small Clip") then return true end
    if _check_prox_and_echo(mod.near_large_clip, reserve_frac, TUNE.near_large_clip_threshold, "Near Large Clip") then return true end
    if _check_prox_and_echo(mod.near_ammo_cache_deployable, reserve_frac, TUNE.near_ammo_cache_threshold, "Near Ammo Cache") then return true end

    -- Low-reserve failsafe
    if reserve_frac < TUNE.low_reserve_threshold then return true end

    return false
end

-- Team decision: return boolean "show?" for a given teammate
-- Inputs:
--   peer_id (string/number) – teammate key for timers
--   reserve_frac_or_nil     – nil for infinite/unknown (will hide)
function mod.ammo_vis_team_for_peer(peer_id, reserve_frac_or_nil)
    -- Team HUD disabled or icons-only? (no munitions in icon-only modes)
    if _S.team_hud_mode == "team_hud_disabled"
        or _S.team_hud_mode == "team_hud_icons_vanilla"
        or _S.team_hud_mode == "team_hud_icons_docked"
    then
        return false
    end

    -- Normalize mode and apply the new enum family.
    local mode = _S.team_munitions or "team_munitions_ammo_context_cd_enabled"

    -- Team munitions disabled?
    if mode == "team_munitions_disabled" then
        return false
    end

    -- Infinite/unknown reserve? Hide this peer regardless of mode.
    if _is_infinite_or_unknown(reserve_frac_or_nil) then
        return false
    end

    local reserve_frac = reserve_frac_or_nil
    local now_t        = _now()

    -- Always-on team modes (both ammo-only and ammo+CD variants)
    if mode == "team_munitions_ammo_only_always"
        or mode == "team_munitions_ammo_always_cd_always"
    then
        return true
    end

    -- Contextual modes:
    --   "team_munitions_ammo_only_context"
    --   "team_munitions_ammo_context_cd_enabled"
    -- (and any unknown future value) are treated as contextual gates.
    -- Global context gates
    if _force_show_active() then return true end
    if _reassure_ammo_active() then return true end
    if _wield_latch_active() then return true end
    if _spectating_active() then return true end

    -- Recent-change window (per peer)
    local until_t = mod._ammo_vis_team_until_by_peer[peer_id]
    if until_t and now_t < until_t then
        return true
    end

    -- Proximity thresholds (mirror player rules)
    if mod.near_small_clip and reserve_frac < TUNE.near_small_clip_threshold then return true end
    if mod.near_large_clip and reserve_frac < TUNE.near_large_clip_threshold then return true end
    if mod.near_ammo_cache_deployable and reserve_frac < TUNE.near_ammo_cache_threshold then return true end

    -- Low-reserve failsafe
    if reserve_frac < TUNE.low_reserve_threshold then return true end

    return false
end

return AV
