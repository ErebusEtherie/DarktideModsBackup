--[[
    cooldown_io.lua
    File I/O for cooldown analysis — saves/loads sessions as JSON.
    Mirrors the pattern established in peril_io.lua.
--]]

local mod  = get_mod("cooldown_analysis")
local DMF  = get_mod("DMF")
local json = mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/libs/json")

-- Access DMF's io table (same pattern as peril tracker / uptime mod)
local _io = DMF:persistent_table("_cooldown_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
    _io = DMF.deepcopy(Mods.lua.io)
end

-- ===== Path helpers =====

mod.appdata_path = function(self)
    local appdata = mod.lib_os.getenv("APPDATA")
    return appdata .. "/Fatshark/Darktide/cooldown_analysis/"
end

local function full_path(file_name)
    return mod:appdata_path() .. file_name
end

local function dir_exists(path)
    local ok, err, code = mod.lib_os.rename(path, path)
    if not ok then
        return code == 13   -- permission denied = exists
    end
    return true
end

local function file_exists(path)
    local f = _io.open(path, "r")
    if f then _io.close(f); return true end
    return false
end

local function scandir(directory)
    if not dir_exists(directory) then return {} end
    local i, names = 0, {}
    local ok, pfile = pcall(function() return _io.popen('dir "' .. directory .. '" /b') end)
    if not ok or not pfile then return {} end
    for name in pfile:lines() do
        if name:match("%.json$") then
            i = i + 1
            names[i] = name
        end
    end
    pfile:close()
    return names
end

-- ===== Directory =====

mod.create_save_directory = function(self)
    local path = self:appdata_path()
    if not dir_exists(path) then
        mod.lib_os.execute('mkdir "' .. path .. '"')
    end
end

-- ===== Timestamp =====

mod.current_timestamp = function(self)
    return mod.lib_os.time(mod.lib_os.date("*t"))
end

-- ===== Save =====

mod.save_cooldown_session = function(self, session)
    self:create_save_directory()

    local ts        = self:current_timestamp()
    local file_name = tostring(ts) .. ".json"
    local path      = full_path(file_name)
    local file      = assert(_io.open(path, "w+"))

    local data = {
        version   = 1,
        timestamp = ts,
        map       = session.map or "unknown",
        archetype = session.archetype or "unknown",
        player    = session.player or "unknown",
        is_psyker = session.is_psyker or false,
        duration  = session.duration or 0,
        uses      = session.uses or {},
    }

    file:write(json.encode(data))
    file:close()

    -- Update file name cache
    local cache = self:get_session_cache()
    cache[#cache + 1] = file_name
    self:set_session_cache(cache)

    if mod:get("delete_old_entries") then
        self:enforce_history_limit(mod:get("number_of_save_files"))
    end

    if mod:get("debug_messages") then
        mod:echo(string.format("[Cooldown Analysis] Session saved: %s", file_name))
    end
end

-- ===== Load =====

mod.load_cooldown_session = function(self, file_name)
    local path = full_path(file_name)
    if not file_exists(path) then return nil end

    local file = _io.open(path, "r")
    if not file then return nil end

    local content = file:read("*l")  -- read first line
    file:close()                      -- always close explicitly

    if not content then return nil end

    local data = json.decode(content)
    if data then
        data.file_name = file_name
        data.file_path = path
    end
    return data
end

-- ===== List all sessions =====

mod.get_all_sessions = function(self, force_scan)
    self:create_save_directory()

    local file_names = self:get_session_cache()

    if force_scan or not file_names or #file_names == 0 then
        file_names = scandir(self:appdata_path())
        self:set_session_cache(file_names)
    end

    local sessions = {}
    for _, name in ipairs(file_names) do
        local s = self:load_cooldown_session(name)
        if s == nil then
            -- File missing — rescan and retry once
            return self:get_all_sessions(true)
        end
        if s then
            sessions[#sessions + 1] = s
        end
    end
    return sessions
end

-- ===== Delete =====

mod.delete_cooldown_session = function(self, session)
    if not session or not session.file_path then return false end

    local ok, removed = pcall(function() return mod.lib_os.remove(session.file_path) end)
    if not ok or not removed then return false end

    local cache = self:get_session_cache()
    local new_cache = {}
    for _, name in ipairs(cache) do
        if name ~= session.file_name then
            new_cache[#new_cache + 1] = name
        end
    end
    self:set_session_cache(new_cache)
    return true
end

-- ===== Cache =====

mod.get_session_cache = function(self)
    return self:get("cooldown_session_cache") or {}
end

mod.set_session_cache = function(self, cache)
    self:set("cooldown_session_cache", cache)
end

-- ===== Enforce file limit =====

mod.enforce_history_limit = function(self, max_files)
    max_files = tonumber(max_files) or 30
    local file_names = scandir(self:appdata_path())
    if not file_names or #file_names == 0 then return end

    local files = {}
    for _, name in ipairs(file_names) do
        local ts = tonumber(string.match(name, "^(%d+)"))
        if ts then
            files[#files + 1] = { name = name, ts = ts }
        end
    end

    if #files <= max_files then return end

    table.sort(files, function(a, b) return a.ts < b.ts end)

    local to_delete = #files - max_files
    for i = 1, to_delete do
        if files[i] then
            mod.lib_os.remove(full_path(files[i].name))
        end
    end

    local remaining = {}
    for i = to_delete + 1, #files do
        if files[i] then remaining[#remaining + 1] = files[i].name end
    end
    self:set_session_cache(remaining)
end
