-- File: RingHud/scripts/mods/RingHud/team/name_cache.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Unified composer (WRU → TL parity, RingHud fallback)
local Name = mod:io_dofile("RingHud/scripts/mods/RingHud/team/name")

----------------------------------------------------------------
-- Time helper (UI time preferred, then gameplay, then os.clock)
----------------------------------------------------------------
local function _now()
    local MT, TT = Managers and Managers.time, (Managers and Managers.time and Managers.time.time)
    if MT and TT then
        return (MT:time("ui") or MT:time("gameplay") or os.clock())
    end
    return os.clock()
end

----------------------------------------------------------------
-- Small utilities
----------------------------------------------------------------
local function _argb255_equal(a, b) -- TODO move to util?
    if a == b then return true end
    if not a or not b then return false end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function _safe_profile(player)
    local ok, prof = pcall(function() return player and player:profile() end)
    if ok then return prof end
    return nil
end

-- Try to form a key that changes when character identity or slot changes.
local function _player_key(player)
    if not player then return "nil" end
    local slot = (player.slot and player:slot()) or "?"
    local peer = (player.peer_id and player:peer_id()) or "?"
    local prof = _safe_profile(player)
    local cid  = (prof and (prof.character_id or prof.unique_id or prof.id)) or (prof and prof.name) or "?"
    return tostring(peer) .. "|" .. tostring(slot) .. "|" .. tostring(cid)
end

----------------------------------------------------------------
-- Cache object (used only for refresh cadence + memoization)
----------------------------------------------------------------
mod.name_cache                     = mod.name_cache or {}
mod.name_cache._data               = mod.name_cache._data or {}

-- Tunable cadence (seconds)
mod.name_cache._refresh_interval_s = mod.name_cache._refresh_interval_s or 1.25

----------------------------------------------------------------
-- Public: clear everything (e.g., on game mode init / roster change)
----------------------------------------------------------------
function mod.name_cache:invalidate_all()
    self._data = {}
end

function mod.name_cache:invalidate_for_player(player)
    if not player then return end
    local key = _player_key(player)
    self._data[key] = nil
end

----------------------------------------------------------------
-- Build (or refresh) the composed text for a player.
-- Returns the composed WRU→TL string (or RingHud fallback). Never throws.
-- NOTE: Composition is delegated to Name.compose to ensure 1:1 parity.
----------------------------------------------------------------
function mod.name_cache:compose_team_name(player, slot_tint_argb255)
    local now          = _now()
    local key          = _player_key(player)
    local rec          = self._data[key]
    local prof         = _safe_profile(player)

    -- Refresh only if missing/stale, tint changed, or profile pointer changed
    local need_refresh = false
    if not rec then
        need_refresh = true
    else
        if (now - (rec.t or 0)) >= (self._refresh_interval_s or 1.25) then
            need_refresh = true
        elseif not _argb255_equal(rec.tint, slot_tint_argb255) then
            need_refresh = true
        elseif rec.profile ~= prof then
            need_refresh = true
        end
    end

    if not need_refresh and rec and rec.text then
        return rec.text
    end

    -- Delegate to the unified composer (no seeded_text here so it recomputes)
    local ok, composed = pcall(Name.compose, player, prof, slot_tint_argb255, nil)
    composed = (ok and composed) or "?"

    -- Store last-known-good
    self._data[key] = {
        text    = tostring(composed or "?"),
        t       = now,
        tint    = slot_tint_argb255 and
            { slot_tint_argb255[1], slot_tint_argb255[2], slot_tint_argb255[3], slot_tint_argb255[4] } or nil,
        profile = prof,
    }

    return self._data[key].text
end

return mod.name_cache
