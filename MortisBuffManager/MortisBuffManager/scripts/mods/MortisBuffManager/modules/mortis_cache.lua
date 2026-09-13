-- Small value snapshots detect in-place edits; table identity alone is not a
-- valid build/filter revision. Cached catalog results are read-only to callers.
local Cache = {}
function Cache.equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not Cache.equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function Cache.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = Cache.copy(v) end
    return result
end
return Cache
