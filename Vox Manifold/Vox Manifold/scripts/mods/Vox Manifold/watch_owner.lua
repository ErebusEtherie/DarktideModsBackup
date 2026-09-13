local pairs = pairs
local next = next
local type = type
local string_format = string.format

local M = {}

function M.new(deps)
    local presence = deps.presence
    local is_registered = deps.is_registered
    local warn = deps.warn
    local max_per_consumer = deps.max_per_consumer

    if type(max_per_consumer) ~= "number" then
        error("watch_owner.new requires deps.max_per_consumer as a number")
    end

    local max_temp_per_consumer = deps.max_temp_per_consumer or 0

    local by_consumer = {}
    local by_consumer_temp = {}
    local owners = {}
    local warned = {}
    local warned_temp = {}

    local w = {}

    local function count_in(pool, id)
        local set = pool[id]

        if not set then
            return 0
        end

        local n = 0

        for _ in pairs(set) do
            n = n + 1
        end

        return n
    end

    local function count(id)
        return count_in(by_consumer, id)
    end

    local function key_of(ref)
        if type(ref) == "table" and ref.vm_ref_key ~= nil then
            return ref.vm_ref_key
        end

        return presence.ref_key(ref)
    end

    local function hold(id, key, field)
        local holders = owners[key] or {}
        owners[key] = holders
        local record = holders[id] or {}
        holders[id] = record
        record[field] = true
    end

    local function release_field(id, key, field)
        local holders = owners[key]

        if not holders then
            return
        end

        local record = holders[id]

        if record then
            record[field] = nil

            if not record.permanent and not record.temporary then
                holders[id] = nil
            end
        end

        if next(holders) == nil then
            owners[key] = nil
            presence.unwatch(key)
        end
    end

    local function release(id, key)
        release_field(id, key, "permanent")
    end

    function w.watch(id, ref)
        if not is_registered(id) then
            return nil, "unknown consumer id"
        end

        local key = presence.ref_key(ref)

        if not key then
            return nil, "watch requires a table with an id"
        end

        local set = by_consumer[id]

        if set and set[key] then
            return true
        end

        if count(id) >= max_per_consumer then
            if not warned[id] then
                warned[id] = true
                warn(string_format(
                    "[Vox Manifold] %s reached the watch limit of %d accounts. " ..
                    "Additional watches are refused.", tostring(id), max_per_consumer))
            end

            return nil, "watch limit reached"
        end

        local handle, err = presence.watch(ref)

        if not handle then
            return nil, err
        end

        set = set or {}
        by_consumer[id] = set
        set[key] = true

        hold(id, key, "permanent")

        return true
    end

    function w.watch_temp(id, ref)
        if not is_registered(id) then
            return nil, "unknown consumer id"
        end

        local key = presence.ref_key(ref)

        if not key then
            return nil, "watch requires a table with an id"
        end

        local set = by_consumer_temp[id]

        if set and set[key] then
            return true
        end

        if count_in(by_consumer_temp, id) >= max_temp_per_consumer then
            if not warned_temp[id] then
                warned_temp[id] = true
                warn(string_format(
                    "[Vox Manifold] %s reached the temporary watch limit of %d accounts. " ..
                    "Additional temporary watches are refused.", tostring(id), max_temp_per_consumer))
            end

            return nil, "temporary watch limit reached"
        end

        local handle, err = presence.watch(ref)

        if not handle then
            return nil, err
        end

        set = set or {}
        by_consumer_temp[id] = set
        set[key] = true

        hold(id, key, "temporary")

        return true
    end

    function w.release_temp(id)
        local set = by_consumer_temp[id]

        if not set then
            return 0
        end

        local released = 0

        for key in pairs(set) do
            release_field(id, key, "temporary")
            released = released + 1
        end

        by_consumer_temp[id] = nil
        warned_temp[id] = nil

        return released
    end

    function w.unwatch(id, ref)
        local key = key_of(ref)
        local set = by_consumer[id]

        if not key or not set or not set[key] then
            return false
        end

        set[key] = nil
        release(id, key)

        return true
    end

    function w.watched(id)
        local out = {}
        local seen = {}

        local function collect(set)
            if not set then
                return
            end

            for key in pairs(set) do
                if not seen[key] then
                    seen[key] = true
                    local handle = presence.handle(key)

                    if handle then
                        out[#out + 1] = handle
                    end
                end
            end
        end

        collect(by_consumer[id])
        collect(by_consumer_temp[id])

        return out
    end

    function w.drop_consumer(id)
        local set = by_consumer[id]
        local temp_set = by_consumer_temp[id]

        if not set and not temp_set then
            return false
        end

        if set then
            for key in pairs(set) do
                release_field(id, key, "permanent")
            end
            by_consumer[id] = nil
        end

        if temp_set then
            for key in pairs(temp_set) do
                release_field(id, key, "temporary")
            end
            by_consumer_temp[id] = nil
        end

        warned[id] = nil
        warned_temp[id] = nil

        return true
    end

    function w.clear()
        by_consumer = {}
        by_consumer_temp = {}
        owners = {}
        warned = {}
        warned_temp = {}
        presence.clear_watches()
    end

    function w.usage()
        local per_consumer = {}
        local temp_per_consumer = {}

        for id in pairs(by_consumer) do
            per_consumer[id] = count(id)
        end

        for id in pairs(by_consumer_temp) do
            temp_per_consumer[id] = count_in(by_consumer_temp, id)
        end

        return {
            cap               = max_per_consumer,
            per_consumer      = per_consumer,
            temp_cap          = max_temp_per_consumer,
            temp_per_consumer = temp_per_consumer,
        }
    end

    return w
end

return M
