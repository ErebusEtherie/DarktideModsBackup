-- File: RingHud/scripts/mods/RingHud/context/pocketables_visibility.lua
local mod = get_mod("RingHud"); if not mod then return {} end

----------------------------------------------------------------
-- Pocketables visibility context (player + team)
--
-- This module centralises all the “when should stimm/crate icons
-- be shown and at what opacity?” rules for:
--  • The local player (ring pocketables)
--  • Teammates (team tiles / nameplates)
--
-- It consumes:
--  • mod._settings.* (pocketable_visibility_dropdown, team_pockets, team_hud_mode)
--  • Proximity context (near_* flags baked into hud_state / team visibility)
--  • Intensity context (mid-event / high-intensity windows)
--  • Wield context (short latches after local player wields a stimm/crate)
--
-- It exposes simple, data-only results that UI code can consume:
--  • PV.player_flags(hud_state, hotkey_override) → player stimm/crate flags
--  • PV.team_flags_for_peer(peer_id, ctx)       → team stimm/crate flags
--
-- “Flags” here are:
--  { enabled = bool, alpha = 0–255, full = bool }
-- plus overall containers:
--  { stimm = {…}, crate = {…} }
--
-- Colour choice remains the responsibility of the feature / team
-- rendering modules – they can use the alpha to tint their palette
-- colours or RecolorStimms overrides.
----------------------------------------------------------------

mod.pocketables_visibility = mod.pocketables_visibility or {}
local PV                   = mod.pocketables_visibility

-- Context providers
local Intensity            = mod:io_dofile("RingHud/scripts/mods/RingHud/context/intensity_context")
mod:io_dofile("RingHud/scripts/mods/RingHud/context/proximity_context")
mod:io_dofile("RingHud/scripts/mods/RingHud/context/wield_context")

-- Team visibility wrapper (already aggregates proximity + wield latches)
mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V               = mod.team_visibility

-- Optional helpers for group crates (team-side only)
local TeamPocketables = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_pocketables")

----------------------------------------------------------------
-- Local helpers
----------------------------------------------------------------

-- Time helper (consistent with other modules)
local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return (MT:time("ui") or MT:time("gameplay") or os.clock())
    end
    return os.clock()
end

-- Clamp to [0,1] using Darktide's math.lua
local function _clamp01(x)
    return math.clamp(tonumber(x) or 0, 0, 1)
end

-- Map x in [hi .. lo] to [0 .. 255] (0 at >=hi, 255 at <=lo), clamped
local function _opacity_from_interval(x, hi, lo)
    local denom = (hi - lo)
    if denom == 0 then return 0 end
    local t = (hi - (x or 0)) / denom
    t = _clamp01(t)
    return math.floor(255 * t)
end

----------------------------------------------------------------
-- Debug / Throttle State
----------------------------------------------------------------
local _debug_throttle_t = 0

-- Helper to check proximity condition and echo if triggered (throttled 1s)
-- condition: boolean (is proximity active?)
-- label: string (for the echo message)
local function _check_prox_and_echo_pv(condition, label)
    if condition then
        -- local t = _now()
        -- if t > _debug_throttle_t then
        --     mod:echo("RingHud Vis: %s", label)
        --     _debug_throttle_t = t + 1.0
        -- end
        return true
    end
    return false
end

-- SETTINGS SNAPSHOT ------------------------------------------------

local _S = {
    team_hud_mode              = "team_hud_docked",
    team_pockets               = "team_pockets_context",
    pocketable_visibility_mode = "pocketable_context",
    ads_visibility_mode        = "ads_vis_context",
}

local function _refresh_settings()
    local s                       = mod._settings or {}

    _S.team_hud_mode              = s.team_hud_mode or "team_hud_docked"
    _S.team_pockets               = s.team_pockets or "team_pockets_context"
    _S.pocketable_visibility_mode = s.pocketable_visibility_dropdown or "pocketable_context"
    _S.ads_visibility_mode        = s.ads_visibility_dropdown or "ads_vis_context"
end

-- Call once on load
_refresh_settings()

-- Centralised hook for the mod's on_setting_changed
function mod.pockets_vis_on_setting_changed()
    _refresh_settings()
end

----------------------------------------------------------------
-- Known / special items
----------------------------------------------------------------

-- Local player + team use the same semantic names
local STIMM_KIND_BY_NAME = {
    syringe_corruption_pocketable    = "corruption",
    syringe_power_boost_pocketable   = "power",
    syringe_speed_boost_pocketable   = "speed",
    syringe_ability_boost_pocketable = "ability",
    syringe_broker_pocketable        = "broker",
}

local CRATE_KIND_BY_NAME = {
    medical_crate_pocketable = "medical",
    ammo_cache_pocketable    = "ammo",
    tome_pocketable          = "tome",
    grimoire_pocketable      = "grimoire",
}

-- Simple “is this a recognised template?” test
local function _stimm_kind(name)
    if not name then return nil, false end
    local kind = STIMM_KIND_BY_NAME[name]
    if kind then
        return kind, true
    end
    return "unknown", false
end

local function _crate_kind(name)
    if not name then return nil, false end
    local kind = CRATE_KIND_BY_NAME[name]
    if kind then
        return kind, true
    end
    return "unknown", false
end

-- Intensity helpers
local function _high_intensity_window()
    local active = false
    if Intensity and Intensity.is_timer_active then
        active = Intensity.is_timer_active() or active
    end
    if Intensity and Intensity.high_intensity_active then
        active = Intensity.high_intensity_active() or active
    end
    return active
end

-- Global “force show all HUD” (show-all hotkey / ADS-hotkey mode)
local function _force_show_all()
    -- Team visibility already centralises this (show_all_hud_hotkey and ADS-gated mode)
    if V and V.force_show_requested and V.force_show_requested() then
        return true
    end
    return false
end

-- Local spectating state (dead / hogtied)
local function _local_player_dead_or_hogtied()
    if Intensity and Intensity.local_player_dead_or_hogtied then
        return Intensity.local_player_dead_or_hogtied()
    end
    if V and V.local_player_is_dead and V.local_player_is_dead() then
        return true
    end
    return false
end

-- Wield latched after local player wields any stimm/crate (team-side only)
local function _any_stimm_wield_latched()
    return V and V.any_stimm_wield_latched and V.any_stimm_wield_latched() or false
end

local function _any_crate_wield_latched()
    return V and V.any_crate_wield_latched and V.any_crate_wield_latched() or false
end

----------------------------------------------------------------
-- Shared opacity rules (used for player + team)
----------------------------------------------------------------

-- Corruption stimm: opacity rises as *carrier* HP falls between two thresholds.
--   • hf = carrier health fraction ∈ [0,1]
--   • At hf >= 0.75:    alpha ≈ 0
--   • At hf <= 0.00:    alpha = 255
local function _alpha_corruption(hf)
    hf = _clamp01(hf or 1)
    return _opacity_from_interval(hf, 0.75, 0.0)
end

-- Ability stimm: opacity falls as ability cooldown *expires*.
--   • rem / max in (0,1]
--   • At full CD (rem == max): alpha ≈ 255
--   • At ready (rem ≈ 0):      alpha ≈ 0
local function _alpha_ability(rem, max_cd)
    if not rem or not max_cd or max_cd <= 0 then return 0 end
    local frac = _clamp01(rem / max_cd) -- 0 = ready, 1 = just started CD
    return math.floor(255 * frac)       -- more remaining ⇒ higher alpha
end

-- Med crate: opacity rises as group health declines.
--   • group_hp is average of (hp+corruption) across alive teammates
-- If TeamPocketables exposes a tuned helper, use that; otherwise fallback
-- to a simple 1 - group_hp mapping.
local function _alpha_med_crate(carrier_hp, group_hp)
    if TeamPocketables and TeamPocketables.opacity_for_medical_crate then
        -- team_pocketables expects (carrier_hp_frac, group_hp_frac)
        return TeamPocketables.opacity_for_medical_crate(carrier_hp, group_hp)
    end

    local group_val = group_hp or carrier_hp or 1
    group_val = _clamp01(group_val)
    return math.floor(255 * (1.0 - group_val))
end

-- Ammo crate: opacity rises as group ammo need increases.
--   • group_need is “team_ammo_need” in [0,1] (0 = full, 1 = empty)
--   • carrier_reserve_frac is only used if group_need is nil (fallback).
local function _alpha_ammo_crate(carrier_reserve_frac, group_need)
    -- If the helper exists, let it own the mapping from (carrier, need) → alpha.
    if TeamPocketables and TeamPocketables.opacity_for_ammo_cache then
        -- team_pocketables expects (carrier_reserve_frac, group_ammo_need)
        return TeamPocketables.opacity_for_ammo_cache(carrier_reserve_frac, group_need)
    end

    local need_val
    if group_need ~= nil then
        -- group_need is already a “need” scalar in [0,1]
        need_val = _clamp01(group_need)
    else
        -- Derive a “need” from the carrier’s own reserve if we don't have a group value.
        local carrier_frac = _clamp01(carrier_reserve_frac or 1)
        need_val = 1.0 - carrier_frac
    end

    return math.floor(255 * need_val)
end

----------------------------------------------------------------
-- Player-side: pocketables on the Ring
----------------------------------------------------------------

-- Returns:
-- {
--   stimm = { enabled, alpha, full },
--   crate = { enabled, alpha, full },
-- }
--
-- NOTE:
--  • “full” means 100% opacity (alpha = 255) due to a hard trigger:
--      hotkey, intensity, wield proximity, being near a pickup, etc.
--  • When full == false but enabled == true, alpha contains a
--    0–255 value from the variable-opacity rules (corruption/ability/
--    group health/ammo).
function PV.player_flags(hud_state, hotkey_override)
    local result = {
        stimm = { enabled = false, alpha = 0, full = false },
        crate = { enabled = false, alpha = 0, full = false },
    }

    local mode = _S.pocketable_visibility_mode or "pocketable_context"

    -- Global disable: nothing shown for the local player
    if mode == "pocketable_disabled" then
        return result
    end

    local stimm_name = hud_state.stimm_item_name
    local crate_name = hud_state.crate_item_name

    local stimm_exists = (stimm_name ~= nil) and (hud_state.stimm_icon_path ~= nil)
    local crate_exists = (crate_name ~= nil) and (hud_state.crate_icon_path ~= nil)

    -- Always-on: show when carried at full opacity
    if mode == "pocketable_always" then
        if stimm_exists then
            result.stimm.enabled = true
            result.stimm.full    = true
            result.stimm.alpha   = 255
        end
        if crate_exists then
            result.crate.enabled = true
            result.crate.full    = true
            result.crate.alpha   = 255
        end
        return result
    end

    -- Contextual mode
    local stimm_kind, stimm_known = _stimm_kind(stimm_name)
    local crate_kind, crate_known = _crate_kind(crate_name)

    local stimm_full              = false
    local crate_full              = false
    local stimm_alpha             = 0
    local crate_alpha             = 0

    -- Force-show hotkey / ADS-hotkey: show what you carry at full opacity
    if hotkey_override or _force_show_all() then
        if stimm_exists then stimm_full = true end
        if crate_exists then crate_full = true end
    end

    -- Special crates: grimoires always visible (100% opacity)
    if crate_name == "grimoire_pocketable" then
        crate_full = true
    end

    -- Unknown/seasonal items: safest to show when carried (100% opacity)
    if stimm_exists and not stimm_known then stimm_full = true end
    if crate_exists and not crate_known then crate_full = true end

    -- Intensity: highlight key pocketables during high-intensity windows
    if _high_intensity_window() then
        if stimm_kind == "power" or stimm_kind == "speed" or stimm_kind == "broker" then
            stimm_full = true
        end
        if crate_kind == "medical" or crate_kind == "ammo" then
            crate_full = true
        end
    end

    -- Near pickups: show the corresponding carried item
    if stimm_exists and _check_prox_and_echo_pv(hud_state.near_any_stimm_source, "Near Stimm Source") then
        stimm_full = true
    end
    if crate_exists and _check_prox_and_echo_pv(hud_state.near_any_crate_source, "Near Crate Source") then
        crate_full = true
    end

    -- Recent pickup/change: burst of visibility for whichever item changed
    if (hud_state.pocketable_pickup_timer or 0) > 0 then
        if hud_state.last_picked_up_pocketable_name == stimm_name then
            stimm_full = true
        elseif hud_state.last_picked_up_pocketable_name == crate_name then
            crate_full = true
        end
    end

    -- Variable-opacity rules (only if not already forced to full)
    local health_data = hud_state.health_data or {}
    local timer_data  = hud_state.timer_data or {}
    local hp_frac     = health_data.current_fraction or 1

    -- Stimm: corruption (player health threshold rule)
    if not stimm_full and stimm_kind == "corruption" then
        stimm_alpha = math.max(stimm_alpha, _alpha_corruption(hp_frac))
    end

    -- Stimm: ability cooldown (player ability CD rule)
    if not stimm_full and stimm_kind == "ability" then
        local rem    = timer_data.ability_cooldown_remaining or 0
        local max_cd = timer_data.max_combat_ability_cooldown or 0
        if rem > 0 and max_cd > 0 then
            stimm_alpha = math.max(stimm_alpha, _alpha_ability(rem, max_cd))
        end
    end

    -- Crate: group health / corruption (player-side view)
    if not crate_full and crate_kind == "medical" then
        local group_hp = hud_state.team_average_health_fraction
        if group_hp ~= nil then
            crate_alpha = math.max(crate_alpha, _alpha_med_crate(hp_frac, group_hp))
        end
    end

    -- Crate: group ammo (reserve -> need)
    if not crate_full and crate_kind == "ammo" then
        local group_ammo = hud_state.team_average_ammo_fraction
        if group_ammo ~= nil then
            -- Convert “average ammo fraction” into a “need” fraction in [0,1]
            local need = 1.0 - _clamp01(group_ammo)
            crate_alpha = math.max(crate_alpha, _alpha_ammo_crate(nil, need))
        end
    end

    -- Finalise stimm flags
    if stimm_full and stimm_exists then
        result.stimm.enabled = true
        result.stimm.full    = true
        result.stimm.alpha   = 255
    elseif stimm_alpha > 0 and stimm_exists then
        result.stimm.enabled = true
        result.stimm.full    = false
        result.stimm.alpha   = math.clamp(stimm_alpha, 0, 255)
    end

    -- Finalise crate flags
    if crate_full and crate_exists then
        result.crate.enabled = true
        result.crate.full    = true
        result.crate.alpha   = 255
    elseif crate_alpha > 0 and crate_exists then
        result.crate.enabled = true
        result.crate.full    = false
        result.crate.alpha   = math.clamp(crate_alpha, 0, 255)
    end

    return result
end

----------------------------------------------------------------
-- Team-side: pocketables on team tiles / nameplates
----------------------------------------------------------------

-- ctx is a plain table with the data that RingHud_state_team already knows:
-- {
--   t                    = gameplay time (for pickup latches)
--   hp_frac              = this teammate's health fraction (0..1)
--   ability_cd_remaining = remaining ability cooldown (seconds)
--   ability_cd_max       = max ability cooldown (seconds)
--   stimm_cd_remaining   = remaining stimm cooldown (seconds) -- NEW
--   stimm_cd_max         = max stimm cooldown (seconds)       -- NEW
--   reserve_frac         = this teammate's reserve ammo fraction (0..1) or nil
--   group_hp_avg         = average hp+corruption over alive strike team (0..1) or nil
--   group_ammo_need      = team-wide ammo need metric (0..1, where 1 = huge need)
--   stimm_icon           = icon material for the stimm (may be nil)
--   crate_icon           = icon material for the crate (may be nil)
--   stimm_kind           = "corruption"/"power"/"speed"/"ability"/"unknown" or nil
--   stimm_mapping_known  = bool
--   crate_kind           = "medical"/"ammo"/"tome"/"grimoire"/"unknown" or nil
--   crate_mapping_known  = bool
--   stimm_show_until     = time until which recent-pickup latch applies or nil
--   crate_show_until     = time until which recent-pickup latch applies or nil
--   force_show           = per-ally force flag (revive, ping focus, etc.)
-- }
--
-- Returns the same structure as player_flags (stimm + crate tables).
function PV.team_flags_for_peer(peer_id, ctx)
    local result = {
        stimm = { enabled = false, alpha = 0, full = false },
        crate = { enabled = false, alpha = 0, full = false },
    }

    -- Global “team HUD disabled” mode: hide pockets entirely
    local hud_mode = _S.team_hud_mode
    if hud_mode == "team_hud_disabled" then
        return result
    end

    local team_pockets_opt = _S.team_pockets or "team_pockets_context"

    -- Per-mod explicit pockets toggle
    if team_pockets_opt == "team_pockets_disabled" then
        return result
    end

    local s_icon           = ctx.stimm_icon
    local c_icon           = ctx.crate_icon
    local s_kind           = ctx.stimm_kind
    local s_map_known      = ctx.stimm_mapping_known
    local c_kind           = ctx.crate_kind
    local c_map_known      = ctx.crate_mapping_known
    local stimm_show_until = ctx.stimm_show_until or 0
    local crate_show_until = ctx.crate_show_until or 0
    local t                = ctx.t or 0

    local hp_frac          = ctx.hp_frac or 1
    local ability_secs     = ctx.ability_cd_remaining or 0
    local ability_max      = ctx.ability_cd_max or 0
    local reserve_frac     = ctx.reserve_frac
    local group_hp         = ctx.group_hp_avg
    local group_ammo_need  = ctx.group_ammo_need
    local force_show       = ctx.force_show or false

    -- Always-on team mode: visible if icon exists, at full opacity
    if team_pockets_opt == "team_pockets_always" then
        if s_icon ~= nil then
            result.stimm.enabled = true
            result.stimm.full    = true
            result.stimm.alpha   = 255
        end
        if c_icon ~= nil then
            result.crate.enabled = true
            result.crate.full    = true
            result.crate.alpha   = 255
        end
        return result
    end

    -- Context mode
    local latched_stimm   = _any_stimm_wield_latched()
    local latched_crate   = _any_crate_wield_latched()
    local local_dead      = _local_player_dead_or_hogtied()
    local force_all       = force_show or _force_show_all()
    local near_stimm_src  = V and V.near_stimm_source and V.near_stimm_source() or false
    local near_crate_src  = V and V.near_crate_source and V.near_crate_source() or false
    local hi_window       = _high_intensity_window()
    local stimm_picked_up = (stimm_show_until or 0) > t
    local crate_picked_up = (crate_show_until or 0) > t

    -- ---------- STIMM ----------
    local stimm_full      = false
    local stimm_alpha     = 0

    if s_icon ~= nil then
        -- FULL OPACITY triggers
        stimm_full =
            local_dead or                                                 -- “Spectating” → show all teammate pockets
            force_all or                                                  -- hotkey / explicit force
            latched_stimm or                                              -- recent local wield of any stimm
            (s_map_known == false) or                                     -- unknown / seasonal stimm: safest to always show
            (hi_window and (s_kind == "power" or s_kind == "speed")) or   -- high-intensity: show power/speed stimms
            _check_prox_and_echo_pv(near_stimm_src, "Team Near Stimm") or -- near stimm pickup
            stimm_picked_up                                               -- recent change
    end

    if stimm_full then
        result.stimm.enabled = true
        result.stimm.full    = true
        result.stimm.alpha   = 255
    else
        -- Variable opacity (teammate health / ability rules)
        if s_icon ~= nil and s_kind == "corruption" then
            stimm_alpha = math.max(stimm_alpha, _alpha_corruption(hp_frac))
        end
        if s_icon ~= nil and s_kind == "ability" and ability_max > 0 and ability_secs > 0 then
            stimm_alpha = math.max(stimm_alpha, _alpha_ability(ability_secs, ability_max))
        end

        -- Broker stimm variable opacity: use stimm cooldown
        if s_icon ~= nil and s_kind == "broker" then
            local rem = ctx.stimm_cd_remaining or 0
            local max = ctx.stimm_cd_max or 0
            if rem > 0 and max > 0 then
                stimm_alpha = math.max(stimm_alpha, _alpha_ability(rem, max))
            end
        end

        if stimm_alpha > 0 then
            result.stimm.enabled = true
            result.stimm.full    = false
            result.stimm.alpha   = math.clamp(stimm_alpha, 0, 255)
        end
    end

    -- ---------- CRATE ----------
    local crate_full  = false
    local crate_alpha = 0

    if c_icon ~= nil then
        -- FULL OPACITY triggers
        crate_full =
            local_dead or                                                 -- spectating → show all teammate pockets
            force_all or                                                  -- hotkey / explicit force
            latched_crate or                                              -- recent local wield of any crate
            (c_kind == "grimoire") or                                     -- grimoires always visible
            (c_map_known == false) or                                     -- unknown crate: safest to always show
            (hi_window and (c_kind == "medical" or c_kind == "ammo")) or  -- high-intensity: med/ammo crates
            _check_prox_and_echo_pv(near_crate_src, "Team Near Crate") or -- near crate pickup
            crate_picked_up                                               -- recent change
    end

    if crate_full then
        result.crate.enabled = true
        result.crate.full    = true
        result.crate.alpha   = 255
    else
        -- Variable opacity (group health / ammo rules)
        if c_icon ~= nil and c_kind == "medical" then
            crate_alpha = math.max(crate_alpha, _alpha_med_crate(hp_frac, group_hp))
        end
        if c_icon ~= nil and c_kind == "ammo" then
            crate_alpha = math.max(crate_alpha, _alpha_ammo_crate(reserve_frac, group_ammo_need))
        end
        if crate_alpha > 0 then
            result.crate.enabled = true
            result.crate.full    = false
            result.crate.alpha   = math.clamp(crate_alpha, 0, 255)
        end
    end

    return result
end

return PV
