local old_empty = table.is_empty

local function _clear_table(tbl)
    if table.clear then
        table.clear(tbl)
        return tbl
    end

    for key in pairs(tbl) do
        tbl[key] = nil
    end

    return tbl
end

table.is_empty = function(tbl)
    if tbl == nil then
        return true
    end

    local base_empty = false
    if old_empty then
        base_empty = old_empty(tbl)
    end

    return table.size(tbl) == 0 or base_empty
end

function table.is_nil_or_empty(tbl)
    return tbl == nil or table.is_empty(tbl)
end

function table.map(tbl, func, destination_table)
    local retTbl = destination_table or {}

    if destination_table then
        _clear_table(retTbl)
    end

    for key, value in pairs(tbl) do
        retTbl[key] = func(value)
    end

    return retTbl
end

function table.to_array(tbl, destination_table)
    local array_tbl = destination_table or {}

    if destination_table then
        _clear_table(array_tbl)
    end

    local index = 0
    for _, value in pairs(tbl) do
        index = index + 1
        array_tbl[index] = value
    end

    return array_tbl
end

function table.is_array(tbl)
    if type(tbl) ~= 'table' then
        return false
    end

    local last_key = nil
    for key, _ in pairs(tbl) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 or (last_key ~= nil and last_key ~= key - 1) then
            return false
        end
        last_key = key
    end

    return true
end

function table.sorted_by_value(tbl, sort_func, destination_table)
    local retTbl = destination_table or {}

    if destination_table then
        _clear_table(retTbl)
    end

    local index = 0
    for _, value in pairs(tbl) do
        index = index + 1
        retTbl[index] = value
    end

    table.sort(retTbl, function(a, b)
        return sort_func(a, b)
    end)

    return retTbl
end
