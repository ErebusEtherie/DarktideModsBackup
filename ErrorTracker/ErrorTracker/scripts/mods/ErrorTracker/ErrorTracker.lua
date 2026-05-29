local mod = get_mod("ErrorTracker")
local dmf = get_mod("DMF")

local REPORT_DIR = "./../mods/ErrorTracker/reports"
local STATE_FILE = "./../mods/ErrorTracker/last_session.txt"
local LAST_MOD_FILE = "./../mods/ErrorTracker/last_mod.txt"
local TRACE_FILE = "./../mods/ErrorTracker/last_trace.txt"

local BANNER = "[!!! ERROR TRACKER !!!] [ET_REPORT]"
local DIVIDER = "============================================================"

local _io = (Mods and Mods.lua and Mods.lua.io) or io
local _os = (Mods and Mods.lua and Mods.lua.os) or os

local crash_counts = {}
local AUTO_DISABLE_THRESHOLD = 1

-- PERFORMANCE SETTINGS
local MAX_TRACE = 50
local WRITE_INTERVAL = 3 -- seconds
local last_write_time = 0

local trace_buffer = {}

--------------------------------------------------
-- UTIL
--------------------------------------------------

local function safe(v)
    local ok, res = pcall(tostring, v)
    return ok and res or "<unprintable>"
end

local function now()
    return os.clock()
end

local function ensure_report_dir()
    if _os and _os.execute then
        pcall(_os.execute, 'mkdir "' .. REPORT_DIR .. '" 2>nul')
    end
end

local function write_file(path, content)
    local file = _io.open(path, "w+")
    if file then
        file:write(content)
        file:close()
    end
end

local function read_file(path)
    local file = _io.open(path, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

local function print_block(title, lines)
    mod:error("%s", DIVIDER)
    mod:error("%s %s", BANNER, title)

    for i = 1, #lines do
        mod:error("%s %s", BANNER, lines[i])
    end

    mod:error("%s", DIVIDER)
end

--------------------------------------------------
-- SMART FILTER (BIG FPS FIX)
--------------------------------------------------

local function should_track(mod_name, context)
    if not mod_name then return false end
    if mod_name == "DMF" or mod_name == "ErrorTracker" then return false end

    if context then
        if string.find(context, "update", 1, true) then return false end
        if string.find(context, "draw", 1, true) then return false end
        if string.find(context, "ui", 1, true) then return false end
    end

    return true
end

--------------------------------------------------
-- TRACE SYSTEM (OPTIMIZED)
--------------------------------------------------

local function flush_trace_file()
    local t = now()
    if t - last_write_time < WRITE_INTERVAL then return end
    last_write_time = t

    local lines = {}

    for i = 1, #trace_buffer do
        local e = trace_buffer[i]
        lines[#lines + 1] = e.mod_name .. "|" .. e.context
    end

    write_file(TRACE_FILE, table.concat(lines, "\n"))
end

local function track_last_mod(mod_name, context)
    if not should_track(mod_name, context) then return end

    write_file(LAST_MOD_FILE, mod_name)

    trace_buffer[#trace_buffer + 1] = {
        mod_name = mod_name,
        context = context or "UNKNOWN"
    }

    while #trace_buffer > MAX_TRACE do
        table.remove(trace_buffer, 1)
    end

    flush_trace_file()
end

--------------------------------------------------
-- REPORT
--------------------------------------------------

local function save_report(mod_name, context, err)
    ensure_report_dir()

    local path = REPORT_DIR .. "/crash.txt"

    local content = table.concat({
        "ERROR TRACKER CRASH REPORT",
        "",
        "Mod: " .. safe(mod_name),
        "Context: " .. safe(context),
        "",
        safe(err)
    }, "\n")

    write_file(path, content)
    return path
end

--------------------------------------------------
-- CORE HOOK
--------------------------------------------------

local function install_hook()
    if not dmf or not dmf.safe_call then return end
    if mod._installed then return end
    mod._installed = true

    mod:echo("ErrorTracker optimized mode enabled")

    dmf.safe_call = function(target_mod, error_prefix_data, func, ...)
        local mod_name = target_mod and target_mod.get_name and target_mod:get_name() or "UNKNOWN"
        local context = safe(error_prefix_data)

        track_last_mod(mod_name, context)

        local function handler(err)
            save_report(mod_name, context, err)

            print_block("CRASH DETECTED", {
                "Mod: " .. mod_name,
                "Error: " .. safe(err)
            })

            return err
        end

        return xpcall(func, handler, ...)
    end
end

--------------------------------------------------
-- LIFECYCLE
--------------------------------------------------

mod.on_enabled = function()
    write_file(STATE_FILE, "RUNNING")
    install_hook()
end

mod.on_disabled = function()
    write_file(STATE_FILE, "CLEAN_EXIT")
end