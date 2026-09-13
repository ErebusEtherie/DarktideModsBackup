-- Display text is separate from statistic IDs and persisted roster status.
local T = {}
function T.language()
    return Application and Application.user_setting("language_id") or "en"
end
function T.literal(value)
    if type(value) == "table" then
        value = value[T.language()] or value.en or value["zh-cn"]
    end
    return value ~= nil and tostring(value) or ""
end
function T.lookup(owner, key)
    if not owner or type(key) ~= "string" then return nil end
    local dmf = get_mod("DMF")
    -- DMF's regular localize formats even labels without arguments. The raw
    -- lookup accepts literal percentages in third-party translations as well.
    if dmf and dmf.quick_localize then
        local ok, translated = pcall(dmf.quick_localize, owner, key)
        if ok and type(translated) == "string" then return (translated:gsub("%%%%", "%%")) end
    end
    if type(owner.localize) == "function" then
        local ok, translated = pcall(owner.localize, owner, key)
        if ok and translated ~= "<>" and translated ~= "<" .. key .. ">" then return translated end
    end
end
function T.label(row, groups, history)
    if groups and groups[row.text] ~= nil then return T.literal(groups[row.text]) end
    if history then return T.literal(row.text) end
    local result = T.lookup(row.mod, row.text) or T.literal(row.text)
    if row.setting and type(row.text) == "string" and row.mod and row.mod.get then
        local setting = row.setting:match("^(%S+)")
        local value = row.mod:get(setting)
        if value ~= nil then result = T.lookup(row.mod, row.text .. "_" .. tostring(value)) or result end
    end
    return result
end
function T.history_rank(name)
    name = T.literal(name)
    return name:sub(-6) == " [BOT]" and 3 or name:sub(-5) == " [DC]" and 2 or 1
end
function T.player_name(player, model, ext, history)
    local name = T.literal(model.value(player, "name"))
    local rank = player._rank
    if player._sr_label ~= nil then
        name = T.literal(player._sr_label)
    elseif history then
        rank = T.history_rank(name)
        if rank == 3 then name = name:sub(1, -7)
        elseif rank == 2 then name = name:sub(1, -6) end
    else
        rank = nil -- A real player's name may itself contain "[BOT]".
    end
    local key = rank == 3 and "player_bot" or rank == 2 and "player_offline"
    return name .. (key and " [" .. ext:localize(key) .. "]" or "")
end
function T.replace_literal(text, needle, replacement)
    if needle == "" then return text end
    local parts, position = {}, 1
    while true do
        local first, last = text:find(needle, position, true)
        if not first then parts[#parts + 1] = text:sub(position); break end
        parts[#parts + 1] = text:sub(position, first - 1)
        parts[#parts + 1] = replacement
        position = last + 1
    end
    return table.concat(parts)
end

-- Keep the original semicolon-delimited history readable by scoreboard.
-- A marker opts new files into escaping; old files containing %xx stay literal.
T.history_marker = "#rse_utf8;1"
function T.history_field(value)
    local text = T.literal(value)
    if text == "" then return "%empty" end
    return (text:gsub("[%z\1-\31%%;#]", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end
local function unescape(value)
    if type(value) ~= "string" then return value end
    if value == "%empty" then return "" end
    return (value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end
function T.restore_history(entry, groups)
    for _, player in pairs(entry.players or {}) do
        for _, key in ipairs({"name", "account_id", "string_symbol"}) do player[key] = unescape(player[key]) end
    end
    for _, row in pairs(entry.rows or {}) do
        for _, key in ipairs({"name", "text", "group", "setting", "parent", "icon", "icon_package"}) do
            row[key] = unescape(row[key])
        end
        for i, value in ipairs(row.summary or {}) do row.summary[i] = unescape(value) end
        local data = {}
        for account, value in pairs(row.data or {}) do
            -- Equipment metadata already has its own lossless SR1 codec.
            if row.name ~= "sr_equipment_snapshot_v1" then value.text_data = unescape(value.text_data) end
            data[unescape(account)] = value
        end
        row.data = data
    end
    local restored = {}
    for key, value in pairs(groups or {}) do restored[unescape(key)] = unescape(value) end
    return entry, groups and restored
end
function T.install_history_reader(ext, scoreboard, file_io)
    ext.bindings.wrap(scoreboard, "load_scoreboard_history_entry", function(func, self, path, ...)
        local entry, groups = func(self, path, ...)
        local file = entry and file_io.open(path, "r")
        if file then
            local marker = file:read("*l")
            file:close()
            if marker == T.history_marker then return T.restore_history(entry, groups) end
        end
        return entry, groups
    end)
end
return T
