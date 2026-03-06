-- File: RingHud/scripts/mods/RingHud/team/visibility.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Public namespace (cross-file): attach to `mod.` per your rule.
mod.team_visibility = mod.team_visibility or {}
local V             = mod.team_visibility

local Intensity     = mod:io_dofile("RingHud/scripts/mods/RingHud/context/intensity_context")
-- Centralized Toughness/HP visibility logic
local THV           = mod.toughness_hp_visibility or
    mod:io_dofile("RingHud/scripts/mods/RingHud/context/toughness_hp_visibility")

-- Internal: Team HUD globally enabled?
local function _enabled()
    local m = mod._settings and mod._settings.team_hud_mode
    return m and m ~= "team_hud_disabled"
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
        or (rawget(mod, "ads_active_force_show") == true)
end

-- ###########
-- New helpers
-- ###########

-- Returns true when the local player is considered "dead" from a HUD POV.
-- (Delegated to intensity system; treats hogtied/disabled as 'dead enough' for HUD purposes.)
function V.local_player_is_dead()
    if not _enabled() then return false end
    return Intensity.local_player_dead_or_hogtied()
end

-- Dead OR hogtied wrapper for convenience in context rules.
function V.local_player_dead_or_hogtied()
    if not _enabled() then return false end
    return Intensity.local_player_dead_or_hogtied()
end

-- High-intensity combat wrapper (now delegated).
function V.high_intensity_active()
    if not _enabled() then return false end
    return Intensity.high_intensity_active()
end

-- ########
-- HP bar
-- ########
function V.hp_bar(peer, _force_show_unused)
    if not _enabled() then return false end
    if not THV or not mod.thv_team_for_peer then return false end

    -- Derive a peer_id from common fields used in RingHud ally state.
    local pid = (peer and (peer.peer_id or peer.peer or peer.id)) or "unknown"

    -- Ensure the peer context passed to the central policy contains the proximity flags
    -- if they weren't already provided.
    local peer_ctx = peer or {}
    -- Proximity data now comes from prox_healing integer (set in RingHud_state_team)
    if peer_ctx.prox_healing == nil then
        peer_ctx.prox_healing = mod.prox_healing or 0
    end

    local res = mod.thv_team_for_peer(pid, peer_ctx)
    return res and res.show_bar == true
end

-- ########
-- HP text
-- ########
function V.hp_text(peer, _force_show_unused)
    if not _enabled() then return false end
    if not THV or not mod.thv_team_for_peer then return false end

    local pid = (peer and (peer.peer_id or peer.peer or peer.id)) or "unknown"

    local peer_ctx = peer or {}
    if peer_ctx.prox_healing == nil then
        peer_ctx.prox_healing = mod.prox_healing or 0
    end

    local res = mod.thv_team_for_peer(pid, peer_ctx)
    return res and res.show_text == true
end

-- ############
-- Munitions
-- ############
function V.munitions(force_show)
    if not _enabled() then return false end

    local v = (mod._settings and mod._settings.team_munitions) or "team_munitions_ammo_context_cd_enabled"

    if v == "team_munitions_disabled" then
        return false
    end

    -- Always modes: ammo is shown regardless of context
    if v == "team_munitions_ammo_always_cd_enabled" or v == "team_munitions_ammo_always_cd_always" then
        return true
    end

    -- Contextual modes: driven by ammo-cache wield latch + force_show
    if v == "team_munitions_ammo_context_cd_disabled" or v == "team_munitions_ammo_context_cd_enabled" then
        if V.any_ammo_cache_wield_latched() then
            return true
        end
        return (force_show == true)
    end

    return false
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
-- Wield-latch pocketable gates
-- ================================
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

function V.any_ammo_cache_wield_latched()
    if not _enabled() then
        return false
    end
    local until_t = rawget(mod, "local_wield_ammo_cache_until")
    local now     = _now()
    return (type(until_t) == "number") and (now < until_t)
end

-- =========================================
-- Near-source helpers (pure proximity)
-- =========================================

local function _near_any_stimm_source_raw()
    -- Directly check the new mod-level boolean flag from proximity_context.lua
    return mod.prox_stimm == true
end

local function _near_any_crate_source_raw()
    -- Directly check the new mod-level boolean flag from proximity_context.lua
    return mod.prox_crate == true
end

function V.near_stimm_source(_audience)
    if not _enabled() then return false end
    return _near_any_stimm_source_raw()
end

function V.near_crate_source(_audience)
    if not _enabled() then return false end
    return _near_any_crate_source_raw()
end

-- ############
-- Counters
-- ############
function V.counters(force_show)
    if not _enabled() then return false, false end

    local v = (mod._settings and mod._settings.team_munitions) or "team_munitions_ammo_context_cd_enabled"

    if v == "team_munitions_disabled"
        or v == "team_munitions_ammo_always_cd_enabled"
        or v == "team_munitions_ammo_context_cd_disabled"
    then
        return false, false
    end

    if v == "team_munitions_ammo_always_cd_always" then
        return true, false
    end

    if v == "team_munitions_ammo_context_cd_enabled" then
        if V.any_ammo_cache_wield_latched() or force_show == true then
            return true, false
        end
        return false, false
    end

    return false, false
end

function V.any_counter(force_show)
    local show_cd, show_tough = V.counters(force_show)
    return show_cd or show_tough
end

return V
