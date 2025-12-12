-- File: RingHud/scripts/mods/RingHud/team/name_cache.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Unified composer (WRU → TL parity, RingHud fallback)
local Name = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_names")
local U    = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

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
-- Small utilities (no pcalls; guard by type checks)
----------------------------------------------------------------
local function _safe_profile(player)
    if not player then return nil end
    if type(player.profile) == "function" then
        return player:profile()
    end
    return rawget(player, "profile")
end

local function _safe_peer_id(player)
    if not player then return "?" end
    if type(player.peer_id) == "function" then
        local v = player:peer_id()
        if v ~= nil then return tostring(v) end
    end
    local raw = rawget(player, "peer_id")
    if raw ~= nil then return tostring(raw) end
    return "?"
end

local function _safe_slot(player)
    if not player then return "?" end
    if type(player.slot) == "function" then
        local v = player:slot()
        if v ~= nil then return v end
    end
    local raw = rawget(player, "slot")
    return raw ~= nil and raw or "?"
end

-- Try to form a key that changes when character identity or slot changes.
local function _player_key(player)
    if not player then return "nil" end
    local slot = _safe_slot(player)
    local peer = _safe_peer_id(player)
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
    -- Invalidate broadly (prefix variations are suffixes to the key)
    -- Since we can't easily regex keys, wiping the specific one is tricky if we don't know the current prefix.
    -- Simple approach: iterate and clear.
    local partial = key
    for k, _ in pairs(self._data) do
        if string.sub(k, 1, #partial) == partial then
            self._data[k] = nil
        end
    end
end

----------------------------------------------------------------
-- Build (or refresh) the composed text for a player.
-- Returns the composed WRU→TL string (or RingHud fallback). Never throws.
-- NOTE: Composition is delegated to Name.compose to ensure 1:1 parity.
----------------------------------------------------------------
function mod.name_cache:compose_team_name(player, slot_tint_argb255, optional_prefix, context_or_opts)
    local now = _now()

    -- Helper to stringify context for keying
    local ctx_str = ""
    if type(context_or_opts) == "string" then
        ctx_str = context_or_opts
    elseif type(context_or_opts) == "table" and context_or_opts.context then
        ctx_str = tostring(context_or_opts.context)
    end

    -- Include prefix and context in key so changing settings/context (docked vs floating)
    -- creates distinct cache entries.
    local key          = _player_key(player) .. "|" .. (optional_prefix or "") .. "|" .. ctx_str

    local rec          = self._data[key]
    local prof         = _safe_profile(player)

    -- Refresh only if missing/stale, tint changed, or profile pointer changed
    local need_refresh = false
    if not rec then
        need_refresh = true
    else
        if (now - (rec.t or 0)) >= (self._refresh_interval_s or 1.25) then
            need_refresh = true
        elseif not U.colors_equal(rec.tint, slot_tint_argb255) then
            need_refresh = true
        elseif rec.profile ~= prof then
            need_refresh = true
        end
    end

    if not need_refresh and rec and rec.text then
        return rec.text
    end

    -- Delegate to the unified composer (no seeded_text here so it recomputes)
    local composed = Name and Name.compose and
        Name.compose(player, prof, slot_tint_argb255, nil, optional_prefix, context_or_opts) or "?"

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
