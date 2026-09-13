-- Pure roster/layout model. Preserve upstream statistic keys when unambiguous;
-- separate missing/duplicate identities using local roster keys.
local M = {}
function M.value(player, key)
    if not player then return nil end
    local value = player[key]
    if type(value) ~= "function" then return value end
    local ok, result = pcall(value, player)
    if ok then return result end
end
function M.key(player, state)
    if state and state.player_keys[player] then return state.player_keys[player] end
    return M.value(player, "account_id") or M.value(player, "name")
end
function M.new()
    return {entries = {}, sequence = 0, player_keys = setmetatable({}, {__mode = "k"}), slots = {}, aliases = {}}
end
local function slot_key(player)
    local peer, id = M.value(player, "peer_id"), M.value(player, "local_player_id")
    -- Zero is a valid Realms bot slot; never iterate local IDs with ipairs.
    if peer ~= nil and id ~= nil then return tostring(peer) .. ":" .. tostring(id) end
end
function M.capture(state, players)
    for _, entry in pairs(state.entries) do entry.active = false end
    local seen, report = {}, {live = 0, missing = 0, collisions = 0}
    for _, player in pairs(players or {}) do
        if not seen[player] then
            seen[player] = true
            report.live = report.live + 1
            local raw_key = M.key(player)
            local slot = slot_key(player)
            local human = M.value(player, "is_human_controlled")
            local key = state.player_keys[player]
            local previous = slot and state.entries[state.slots[slot]]
            if not key and previous and (previous.raw_key == raw_key or previous.raw_key == nil or raw_key == nil) then
                key = previous.key
            end
            if not key then
                key = state.aliases[raw_key] or raw_key
                local occupied = key and state.entries[key]
                -- Preserve account-based human reconnects. Separate concurrent
                -- players and distinct bot slots even if their names coincide.
                if key == nil or key == "" or occupied and (occupied.active or
                    human == false and occupied.slot and slot and occupied.slot ~= slot) then
                    key = "rse_player:" .. (slot or tostring(state.sequence + 1))
                    while state.entries[key] do key = key .. ":next" end
                end
            end
            local entry = state.entries[key]
            if not entry then
                state.sequence = state.sequence + 1
                entry = {key = key, order = state.sequence}
                state.entries[key] = entry
            end
            state.player_keys[player] = key
            if slot then state.slots[slot] = key end
            entry.slot = slot or entry.slot
            entry.raw_key = raw_key
            entry._from_rows = nil
            if raw_key == nil or raw_key == "" then report.missing = report.missing + 1 end
            if raw_key ~= nil and raw_key ~= key then
                if state.entries[raw_key] and state.entries[raw_key]._from_rows then state.entries[raw_key] = nil end
                if state.entries[raw_key] or state.aliases[raw_key] and state.aliases[raw_key] ~= key then
                    report.collisions = report.collisions + 1
                else state.aliases[raw_key] = key end
            end
            entry.active = true
            entry.profile_data = M.value(player, "profile") or entry.profile_data or {}
            entry.label = M.value(player, "name") or entry.profile_data.name or entry.label or "?"
            entry.string_symbol = player.string_symbol or entry.string_symbol
            if human ~= nil then entry.bot = not human end
        end
    end
    state.report = report
    return report
end
function M.list(state, rows)
    for _, row in pairs(rows or {}) do
        for key in pairs(row.data or {}) do
            if not state.entries[key] and not state.aliases[key] then
                state.sequence = state.sequence + 1
                state.entries[key] = {key = key, label = tostring(key), order = state.sequence, active = false, _from_rows = true}
            end
        end
    end
    local result = {}
    for _, entry in pairs(state.entries) do
        local e = entry
        result[#result + 1] = {
            account_id = function() return e.key end,
            name = function() return e.label .. (e.bot and " [BOT]" or not e.active and " [DC]" or "") end,
            profile = function() return e.profile_data or {} end,
            is_human_controlled = function() return not e.bot end,
            string_symbol = e.string_symbol,
            _sr_label = e.label,
            _rank = e.bot and 3 or (e.active and 1 or 2), _order = e.order,
        }
    end
    table.sort(result, function(a, b)
        if a._rank ~= b._rank then return a._rank < b._rank end
        return a._order < b._order
    end)
    return result
end
-- Apply late-arriving stat keys only to rendering/saving copies. A shared
-- legacy name bucket stays with its original record, never duplicated as two
-- independent players' statistics. The extra player's known equipment remains
-- separate through its resolved roster key.
function M.project_rows(state, rows, copy)
    local result = {}
    for i, row in ipairs(rows or {}) do
        local entry = {}
        for key, value in pairs(row) do entry[key] = key == "data" and copy(value) or value end
        for alias, key in pairs(state.aliases) do
            if entry.data and entry.data[alias] and not entry.data[key] then
                entry.data[key], entry.data[alias] = entry.data[alias], nil
            end
        end
        result[i] = entry
    end
    return result
end
function M.layout(count, limit, width, height, scale, width_percent, label_width)
    scale = math.max(tonumber(scale) or 1, 0.1)
    local available = math.max(320, width / scale - 80)
    local columns = math.max(1, math.min(count, limit, 12))
    local wanted_label = label_width or 420
    local panel = math.min(available, (wanted_label + columns * 150) * width_percent / 100)
    local label = math.min(wanted_label, panel * 0.45)
    return {width = panel, label = label, column = (panel - label - 24) / columns,
        columns = columns, height = math.max(200, height / scale - 100)}
end
function M.page(players, limit, requested)
    local pages = math.max(1, math.ceil(#players / limit))
    local page = math.max(1, math.min(requested, pages))
    local result = {}
    for i = (page - 1) * limit + 1, math.min(page * limit, #players) do result[#result + 1] = players[i] end
    return result, page, pages
end
return M
