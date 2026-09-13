-- Immutable, normalized equipment snapshots. No game objects or executable data
-- are serialized into history. Rendering limits never discard collected traits.
local E = {}
local slots = {"slot_primary", "slot_secondary"}
local categories = {"perks", "traits"}
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function ordered(list)
    local keys, result = {}, {}
    for k, v in pairs(type(list) == "table" and list or {}) do
        if type(k) == "number" and type(v) == "table" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do result[#result + 1] = list[k] end
    return result
end
function E.capture(profile, api, previous)
    if type(profile) ~= "table" or type(profile.loadout) ~= "table" then return previous end
    local snapshot = {weapons = {}, feats = call(api.feats, profile) or ""}
    local found = false
    for i, slot in ipairs(slots) do
        local item = profile.loadout[slot]
        if type(item) == "table" then
            found = true
            local weapon = {name = call(api.name, item) or item.display_name or item.name or "?"}
            snapshot.weapons[i] = weapon
            for _, category in ipairs(categories) do
                weapon[category] = {}
                for _, trait in ipairs(ordered(item[category])) do
                    local text = call(api.trait, trait, category)
                    weapon[category][#weapon[category] + 1] = {
                        text = tostring(text or trait.id or "?"), rarity = tostring(trait.rarity or "")}
                end
            end
        elseif previous then
            -- A transient incomplete profile must not erase a known weapon.
            snapshot.weapons[i] = previous.weapons[i]
        end
    end
    return found and snapshot or previous
end
function E.fingerprint(profile)
    if type(profile) ~= "table" or type(profile.loadout) ~= "table" then return nil end
    local fields = {}
    local function put(value)
        value = tostring(value or "")
        fields[#fields + 1] = #value .. ":" .. value
    end
    for _, slot in ipairs(slots) do
        local item = profile.loadout[slot]
        if type(item) == "table" then
            put(item.name); put(item.id); put(item.display_name)
            for _, category in ipairs(categories) do
                local traits = ordered(item[category])
                put(#traits)
                for _, trait in ipairs(traits) do put(trait.id); put(trait.rarity) end
            end
        else put("missing") end
    end
    local talents = {}
    for key,value in pairs(profile.talents or {}) do talents[#talents+1]=tostring(key).."="..tostring(value) end
    table.sort(talents)
    put(table.concat(talents, ";"))
    put(profile.archetype and profile.archetype.name)
    return table.concat(fields, "|")
end
local function escape(s)
    return (tostring(s or ""):gsub("([^%w_%-%.])", function(c) return string.format("%%%02X", string.byte(c)) end))
end
function E.encode(snapshot)
    if not snapshot then return "" end
    local fields = {"SR1", escape(snapshot.feats)}
    for i = 1, 2 do
        local weapon = snapshot.weapons[i]
        fields[#fields + 1] = escape(weapon and weapon.name)
        for _, category in ipairs(categories) do
            local traits = weapon and weapon[category] or {}
            fields[#fields + 1] = tostring(#traits)
            for _, trait in ipairs(traits) do
                fields[#fields + 1] = escape(trait.text)
                fields[#fields + 1] = escape(trait.rarity)
            end
        end
    end
    return table.concat(fields, "|")
end
function E.decode(text)
    if type(text) ~= "string" or #text > 524288 then return nil end
    local fields = {}
    for value in (text .. "|"):gmatch("(.-)|") do fields[#fields + 1] = value end
    if fields[1] ~= "SR1" then return nil end
    local index = 1
    local function take()
        index = index + 1
        local value = fields[index]
        return value and value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    end
    local snapshot = {feats = take(), weapons = {}}
    for i = 1, 2 do
        local weapon = {name = take()}
        if weapon.name == nil then return nil end
        for _, category in ipairs(categories) do
            local count = tonumber(take())
            if not count or count < 0 or count > 256 or count % 1 ~= 0 then return nil end
            weapon[category] = {}
            for j = 1, count do
                local label, rarity = take(), take()
                if label == nil or rarity == nil then return nil end
                weapon[category][j] = {text = label, rarity = rarity}
            end
        end
        if weapon.name ~= "" then snapshot.weapons[i] = weapon end
    end
    return index == #fields and snapshot or nil
end
function E.trait_text(trait)
    if not trait then return "—" end
    local ranks = {"I", "II", "III", "IV", "V", "VI"}
    local rarity = trait.rarity
    return trait.text .. (rarity ~= "" and " [" .. (ranks[tonumber(rarity)] or rarity) .. "]" or "")
end
return E
