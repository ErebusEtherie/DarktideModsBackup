-- Compare rendering inputs, including direct plugin writes that bypass update_stat.
-- Never traverse the mod object or retained engine profile objects.
local R = {}
local function encode(value, out, seen)
    local kind = type(value)
    if kind ~= "table" then
        local text = tostring(value)
        out[#out+1] = kind .. #text .. ":" .. text
        return
    end
    if seen[value] then out[#out+1] = "cycle"; return end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do keys[#keys+1] = key end
    table.sort(keys, function(a,b) return type(a)..tostring(a) < type(b)..tostring(b) end)
    out[#out+1] = "{"
    for _, key in ipairs(keys) do encode(key,out,seen); encode(value[key],out,seen) end
    out[#out+1] = "}"
    seen[value] = nil
end
function R.stamp(rows, players, options, model)
    local out = {}
    encode(options, out, {})
    for _, player in ipairs(players) do
        encode({model.key(player), model.value(player,"name"), player.string_symbol},out,{})
    end
    for _, row in ipairs(rows or {}) do
        local fields = {}
        for key,value in pairs(row) do if key ~= "mod" then fields[key] = value end end
        if row.mod and row.setting then
            fields._setting_value = row.mod:get(row.setting:match("^(%S+)"))
        end
        encode(fields,out,{})
    end
    return table.concat(out)
end
return R
