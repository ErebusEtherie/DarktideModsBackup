---@alias use_debug_r { echo: echo, echo_once: echo_once , error_once:error_once,  dump_once: dump_once, notify_once: notify_once }
---@alias use_debug fun(mod: dmf_mod) : use_debug_r

local function concat(...)
    local parts = {}

    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = tostring(v)
    end

    return table.concat(parts, " ")
end

local echo_once_store = {}
local error_once_store = {}
local dump_once_store = {}
local notify_once_store = {}

---@type use_debug
local function use_debug(mod)
    ---@alias echo fun(...)
    ---@type echo
    local function echo(...)
        if mod:get('toggle_debug') then
            mod:echo(concat(...))
        end
    end

    ---@alias echo_once fun(id : string | integer, ...)
    ---@type echo_once
    local function echo_once(id, ...)
        if mod:get('toggle_debug') then
            if not id then
                id = 'placeholder'
            end
            if not echo_once_store[id] then
                mod:echo(concat(...))
                echo_once_store[id] = true
            end
        end
    end

    ---@alias error_once fun(id : string | integer, ...)
    ---@type error_once
    local function error_once(id, ...)
        if not id then
            id = 'placeholder'
        end
        if not error_once_store[id] then
            mod:error(concat(...))
            error_once_store[id] = true
        end
    end

    ---@alias dump_once fun(id : string | integer, value)
    ---@type dump_once
    local function dump_once(id, value)
        if mod:get('toggle_debug') then
            if not id then
                id = 'placeholder'
            end
            if not dump_once_store[id] then
                mod:dump(value)
                dump_once_store[id] = true
            end
        end
    end

    ---@alias notify_once fun(id : string | integer, value)
    ---@type notify_once
    local function notify_once(id, value)
        if not id then
            id = 'placeholder'
        end
        if not notify_once_store[id] then
            mod:echo(value)
            mod:notify(value)
            notify_once_store[id] = true
        end
    end

    return {
        echo = echo,
        error_once = error_once,
        echo_once = echo_once,
        dump_once = dump_once,
        notify_once = notify_once,
    }
end

return use_debug
