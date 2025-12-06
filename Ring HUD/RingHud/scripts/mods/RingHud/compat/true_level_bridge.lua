-- File: RingHud/scripts/mods/RingHud/compat/true_level_bridge.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Optional dependency
local TL = get_mod("true_level")

local Bridge = {}

----------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------
local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("ui") or MT:time("gameplay") or os.clock()
    end
    return os.clock()
end

-- TL available for team usage?
local function _tl_available_for_team()
    return TL and TL.is_enabled_feature and TL.is_enabled_feature("team_panel") == true
end

-- Read TL setting with per-element fallback ("..._team_panel" → global when "use_global")
local function _tl_get_setting(base_id, element)
    if not (TL and TL.get) then return nil end
    local per  = TL:get(base_id .. "_" .. element) -- e.g. "level_color_team_panel"
    local glob = TL:get(base_id)                   -- e.g. "level_color"
    if per == "use_global" then return glob end
    return per
end

-- Convert TL/Color name → ARGB-255 table {a,r,g,b}
local function _color_from_name(name)
    if not name or name == "default" then return nil end
    if not Color or not Color[name] then return nil end
    local v = Color[name](255, true) -- {a,r,g,b}
    -- Convert to a plain table copy to avoid accidental mutation
    return { v[1], v[2], v[3], v[4] }
end

-- Find a Player by peer_id (string/number)
local function _player_by_peer_id(pid_any)
    if not (Managers and Managers.player and Managers.player.players) then return nil end
    local want = tostring(pid_any)
    for _, p in pairs(Managers.player:players() or {}) do
        local ok, pid = pcall(function() return p.peer_id and p:peer_id() end)
        if ok and pid and tostring(pid) == want then
            return p
        end
        local raw = rawget(p, "peer_id")
        if raw and tostring(raw) == want then
            return p
        end
    end
    return nil
end

-- Resolve character_id from a Player (safe)
local function _char_id_from_player(p)
    if not p then return nil end
    local ok, prof = pcall(function() return p.profile and p:profile() end)
    if not ok or not prof then return nil end
    return prof.character_id or prof.unique_id or prof.id
end

-- Read true_levels table from TL for a character_id
local function _true_levels_for_char_id(cid)
    if not (cid and TL) then return nil end

    -- Try both call styles
    local ok1, res1 = pcall(function() return TL.get_true_levels and TL.get_true_levels(cid) end)
    if ok1 and type(res1) == "table" then return res1 end

    local ok2, res2 = pcall(function() return TL.get_true_levels and TL:get_true_levels(cid) end)
    if ok2 and type(res2) == "table" then return res2 end

    return nil
end

----------------------------------------------------------------
-- Cache (peer_id keyed; short refresh)
----------------------------------------------------------------
Bridge._by_peer            = Bridge._by_peer or {} -- pid -> { t, data }
Bridge._refresh_interval_s = Bridge._refresh_interval_s or 1.0

function Bridge.invalidate_all()
    Bridge._by_peer = {}
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

-- Is TL present/ready for team usage?
function Bridge.available()
    return _tl_available_for_team()
end

-- Return TL info for a peer_id:
-- { true_level=number, havoc_rank=number,
--   color_argb255?=table, use_color?=boolean,
--   level_color_argb255?=table, havoc_color_argb255?=table }
function Bridge.peer_info(peer_id)
    if not _tl_available_for_team() then return nil end
    if not peer_id then return nil end

    -- Cache check
    local now = _now()
    local pid = tostring(peer_id)
    local rec = Bridge._by_peer[pid]
    if rec and (now - (rec.t or 0) < Bridge._refresh_interval_s) then
        return rec.data
    end

    -- Resolve character -> TL data
    local player = _player_by_peer_id(pid)
    local cid    = _char_id_from_player(player)
    if not cid then
        Bridge._by_peer[pid] = { t = now, data = nil }
        return nil
    end

    local tl_tbl = _true_levels_for_char_id(cid)
    if type(tl_tbl) ~= "table" then
        Bridge._by_peer[pid] = { t = now, data = nil }
        return nil
    end

    -- Compose payload
    local level_total      = tl_tbl.true_level or tl_tbl.current_level or tl_tbl.level
    local havoc_rank       = tl_tbl.havoc_rank or 0

    local level_color_name = _tl_get_setting("level_color", "team_panel")
    local havoc_color_name = _tl_get_setting("havoc_rank_color", "team_panel")

    local level_color_argb = _color_from_name(level_color_name)
    local havoc_color_argb = _color_from_name(havoc_color_name)

    -- FIX: consider either element's color as enabling TL coloring
    local use_color        = (level_color_argb ~= nil) or (havoc_color_argb ~= nil)

    local data             = {
        true_level          = tonumber(level_total) or 0,
        havoc_rank          = tonumber(havoc_rank) or 0,
        -- Primary keys requested:
        color_argb255       = level_color_argb, -- for callers that expect a single color
        use_color           = use_color,
        -- Extra convenience keys (optional but handy):
        level_color_argb255 = level_color_argb,
        havoc_color_argb255 = havoc_color_argb,
    }

    Bridge._by_peer[pid]   = { t = now, data = data }
    return data
end

-- Expose under mod.* and return
mod.true_level_bridge = Bridge
return Bridge
