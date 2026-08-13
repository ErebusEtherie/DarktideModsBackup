local function safe_method(object, name, ...)
    if not object then return nil end
    local fn = object[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    return ok and value or nil
end

local function safe_field(object, name)
    local ok, value = pcall(function() return object and object[name] end)
    return ok and value or nil
end

local function player_name(player)
    if not player then return "Unknown" end
    return safe_method(player, "name") or safe_field(player, "name") or safe_method(player, "account_name") or "Unknown"
end

-- Normalize a direct Scores metric cell.
local function direct_score(entry)
    if type(entry) == "number" then return entry, "number" end
    if type(entry) ~= "table" then return nil, nil end
    if entry.score ~= nil then return tonumber(entry.score), "score" end
    if entry.value ~= nil then return tonumber(entry.value), "value" end
    if entry.total ~= nil then return tonumber(entry.total), "total" end
    return nil, nil
end


local Adapter = {id = "scores", display_name = "Scores"}

Adapter.metric_rows = {
    damage_taken = "damage_taken", times_downed = "times_downed", times_disabled = "times_disabled", deaths = "deaths",
    attacks_blocked = "attacks_blocked",
    damage_dealt = "damage_dealt", weakspot_hits = "weakspot_hits", melee_kills = "melee_kills", ranged_kills = "ranged_kills",
    weakspot_hit_percent = "weakspot_hit_percent", critical_hits = "critical_hits", accuracy = "accuracy",
    damaging_hits = "damaging_hits", ranged_shots_fired = "ranged_shots_fired",
    lesser_enemies = "lesser_enemies", melee_ranged_threats = "melee_ranged_threats", special_threats = "special_threats",
    boss_damage_dealt = "boss_damage_dealt", coherency_efficiency = "coherency_efficiency",
    revived_operative = "revived_operative", team_saves = "team_saves", ammo_score = "ammo_collected",
    heal_station_used = "heal_station_used", operated = "operated", resources_collected = "resources_collected",
}

-- Scores deliberately persists only rows enabled in its own settings. Respect
-- that policy: disabled metrics stay absent so History can distinguish missing
-- data from a valid recorded zero.
function Adapter:required_history_rows(sorted_rows)
    return {}
end

function Adapter:is_available() return get_mod("scores") ~= nil end
function Adapter:mod() return get_mod("scores") end

-- Resolve a canonical Scores row by name.
function Adapter:row(row_name)
    local source = self:mod()
    if not source then return nil end
    local row = safe_method(source, "get_scoreboard_row", row_name)
    if row then return row end
    for _, candidate in pairs(source.registered_scoreboard_rows or {}) do
        if candidate.name == row_name then return candidate end
    end
end

function Adapter:all_rows_grouped()
    local source = self:mod()
    if not source then return {{}} end
    local rows = {}
    for _, row in pairs(source.registered_scoreboard_rows or {}) do
        rows[#rows + 1] = row
    end
    return {rows}
end

-- Resolve Scores summary rows and their display companions.
-- Essential for Tactical Swarmers, Elites, Specials, and Boss metrics.
function Adapter:display_model(row)
    local source = self:mod()
    if not source or not row then return nil end
    return safe_method(source, "row_display_model", row, self:all_rows_grouped(), nil, nil, false, true)
end

function Adapter:players()
    local source = self:mod()
    if not source then return {} end
    return safe_method(source, "scoreboard_players", source.player_manager or (Managers and Managers.player), nil, true) or {}
end

function Adapter:account_id(player)
    local source = self:mod()
    return source and safe_method(source, "account_id_from_player", player) or nil
end

function Adapter:local_account_id()
    local source = self:mod()
    local id = source and safe_method(source, "me") or nil
    if id then return id end
    local manager = Managers and Managers.player
    local player = manager and manager.local_player and manager:local_player(1)
    id = self:account_id(player)
    if id then return id end
    local improve_yourself = get_mod("improve-yourself")
    local cached_id = improve_yourself and type(improve_yourself.local_identity) == "function"
        and select(1, improve_yourself:local_identity())
        or nil
    return cached_id
end

function Adapter:capabilities()
    local result = {}
    for metric, row_name in pairs(self.metric_rows) do result[metric] = self:row(row_name) ~= nil end
    return result
end

function Adapter:active_metrics()
    local improve_yourself = get_mod("improve-yourself")
    local result = {}
    for metric in pairs(self.metric_rows) do
        result[metric] = not improve_yourself
            or type(improve_yourself.is_metric_enabled) ~= "function"
            or improve_yourself:is_metric_enabled(metric)
    end
    return result
end

-- Adapt both direct and summary Scores metrics.
function Adapter:get_metric(metric, account_id)
    local row = self:row(self.metric_rows[metric])
    if not row then return nil, nil end

    -- Coherency is the one Scores row whose visible value is normalized
    -- so that the squad average becomes 100. Its saved history keeps the raw
    -- accumulated sample score instead. Improve Yourself calculates squad share
    -- itself, so use the same raw value that Scores persists.
    if metric == "coherency_efficiency" then
        local raw_score = direct_score(row.data and row.data[account_id])
        if raw_score ~= nil then return raw_score, "raw_score" end
    end

    -- Scores stores the accumulated match result in `score`, while
    -- `value` is often only the most recent event. Summary rows do not keep
    -- their own live data and must be resolved through row_display_model.
    local model = self:display_model(row)
    local display_entry = model and model.display_data and model.display_data[account_id]
    local score, field = direct_score(display_entry)
    if score ~= nil then return score, "display_score" end

    score, field = direct_score(row.data and row.data[account_id])
    return score, field
end

local function has_any_metric(metrics)
    for _, value in pairs(metrics or {}) do
        if value ~= nil then return true end
    end
    return false
end

-- Build the normalized live match consumed by the Tactical Overlay.
function Adapter:get_current_match()
    local source = self:mod()
    if not source then return nil end
    local local_id = self:local_account_id()
    local players, seen = {}, {}

    for _, player in pairs(self:players()) do
        local id = self:account_id(player)
        if id and not seen[id] then
            seen[id] = true
            local metrics, metric_fields = {}, {}
            for metric in pairs(self.metric_rows) do
                local value, field = self:get_metric(metric, id)
                metrics[metric] = value
                metric_fields[metric] = field
            end
            -- Stale player-manager entries can remain during a mission. Keep only
            -- entries that are either the local player or have scoreboard data.
            if id == local_id or has_any_metric(metrics) then
                local profile = safe_method(player, "profile") or safe_field(player, "_profile")
                local archetype = profile and profile.archetype
                players[#players + 1] = {
                    account_id = id,
                    name = player_name(player),
                    account_name = safe_method(player, "account_name") or safe_field(player, "account_name"),
                    string_symbol = safe_field(player, "string_symbol") or (archetype and archetype.string_symbol),
                    archetype_name = archetype and archetype.name,
                    is_local = id == local_id,
                    metrics = metrics,
                    metric_fields = metric_fields,
                }
            end
        end
    end

    table.sort(players, function(a, b)
        if a.is_local ~= b.is_local then return a.is_local end
        return tostring(a.name) < tostring(b.name)
    end)

    local team_totals = {}
    for metric in pairs(self.metric_rows) do
        local total, available = 0, false
        for _, player in ipairs(players) do
            local value = tonumber(player.metrics[metric])
            if value then total = total + value; available = true end
        end
        team_totals[metric] = available and total or nil
    end

    for _, player in ipairs(players) do
        player.shares = {}
        for metric in pairs(self.metric_rows) do
            local value, total = tonumber(player.metrics[metric]), tonumber(team_totals[metric])
            player.shares[metric] = value and total and total ~= 0 and (value / total * 100) or nil
        end
    end

    local duration = nil
    if tonumber(source.timer) then duration = math.max(0, os.time() - tonumber(source.timer)) end
    return {
        source = self.id,
        source_name = self.display_name,
        source_version = tostring(source.version or source.VERSION or "unknown"),
        mission = {
            name = source.mission_name,
            difficulty = source.mission_challenge,
            result = source.victory_defeat,
            duration_seconds = duration,
        },
        players = players,
        team_totals = team_totals,
        local_account_id = local_id,
        capabilities = self:capabilities(),
        active_metrics = self:active_metrics(),
    }
end

return Adapter
