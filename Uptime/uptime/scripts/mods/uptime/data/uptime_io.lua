local mod = get_mod("uptime")
local DMF = get_mod("DMF")
local json = mod:io_dofile("uptime/scripts/mods/uptime/libs/json")
local v1_migration = mod:io_dofile("uptime/scripts/mods/uptime/data/v1_to_v2")

-- ##### IO and OS functions #####
local _io = DMF:persistent_table("_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
    _io = DMF.deepcopy(Mods.lua.io)
end

-- ##### Helper functions #####
local file_does_not_exist = {}

function path(file_name)
    return mod:appdata_path() .. file_name
end


-- Check if a file or directory exists in this path
local function exists(file)
    local ok, err, code = mod.lib.os.rename(file, file)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    return ok, err
end

-- Check if a directory exists in this path
local function isdir(path)
    -- "/" works on both Unix and Windows
    return exists(path .. "/")
end

-- Check if file exists
local function file_exists(name)
    local f = _io.open(name, "r")
    if f ~= nil then
        _io.close(f)
        return true
    else
        return false
    end
end

-- Get the path to the uptime history directory
mod.appdata_path = function(self)
    local appdata = mod.lib.os.getenv('APPDATA')
    return appdata .. "/Fatshark/Darktide/uptime_history/"
end

-- Create the uptime history directory if it doesn't exist
mod.create_uptime_history_directory = function(self)
    local path = self:appdata_path()
    if not isdir(path) then
        mod.lib.os.execute('mkdir ' .. path) -- ?
        mod.lib.os.execute("mkdir '" .. path .. "'") -- ?
        mod.lib.os.execute('mkdir "' .. path .. '"') -- Windows
    end
end

-- Generate a file path for the current uptime history entry
mod.create_uptime_history_entry_path = function(self)
    local file_name = tostring(self:current_date()) .. ".json"
    return self:appdata_path() .. file_name, file_name
end

mod.current_date = function(self)
    return mod.lib.os.time(mod.lib.os.date("*t"))
end

mod.save_entry = function(self, entry)

    self:create_uptime_history_directory()

    local path, file_name = self:create_uptime_history_entry_path()
    local file = assert(_io.open(path, "w+"))

    for _, buff in pairs(entry.buffs) do
        buff.instance = nil
    end

    local entry_json = json.encode(entry)
    file:write(entry_json)

    file:close()

    local cache = self:get_history_entries_cache()
    cache[#cache + 1] = file_name
    self:set_history_entries_cache(cache)

    if mod:get("delete_old_entries") then
        self:enforce_history_limit(mod:get("number_of_save_files"))
    end
end

-- Load uptime data from a file
function mod:load_entry(file_name)
    local path = path(file_name)

    if not file_exists(path) then
        mod:echo("Error: File not found: " .. path)
        return file_does_not_exist
    end

    local entry = nil
    for entry_json in _io.lines(path) do
        if entry then
            mod:echo("Received more than 1 line when loading file! Save file might be corrupted")
        else
            entry = json.decode(entry_json)
        end
    end

    if entry then
        entry.file = file_name
        entry.file_path = path
    else
        return nil
    end

    if not entry.version then
        local date_str = string.sub(file_name, 1, string.len(file_name) - 4)
        entry.date = v1_migration(entry, tonumber(date_str))
    end

    return entry
end

local function scandir(directory)
    local i, file_names, popen = 0, {}, _io.popen
    local pfile = popen('dir "' .. directory .. '" /b')
    for filename in pfile:lines() do
        i = i + 1
        file_names[i] = filename
    end
    pfile:close()
    return file_names
end

-- Get all uptime history entries
function mod:get_history_entries(scan_dir)
    local entries = {}
    local appdata = self:appdata_path()
    local file_names = self:get_history_entries_cache()

    if scan_dir or not file_names then
        file_names = scandir(appdata)
        self:set_history_entries_cache(file_names)
    end

    for _, file in pairs(file_names) do
        local result = self:load_entry(file)
        if result == file_does_not_exist then
            return self:get_history_entries(true)
        end
        if result then
            entries[#entries + 1] = result
        end
    end

    return entries
end

-- Get cache of history entries
mod.get_history_entries_cache = function(self)
    return self:get("uptime_history_entries") or {}
end

-- Set cache of history entries
mod.set_history_entries_cache = function(self, entries)
    self:set("uptime_history_entries", entries)
end

mod.enforce_history_limit = function(self, max_files)
    max_files = tonumber(max_files) or 30
    local appdata = self:appdata_path()
    local file_names = scandir(appdata)

    if not file_names or #file_names == 0 then
        return
    end

    local files = {}
    for _, name in pairs(file_names) do
        local ts = tonumber(string.match(name, "^(%d+)"))
        if ts then
            files[#files + 1] = { name = name, ts = ts }
        end
    end

    local count = #files

    if count <= max_files then
        return
    end

    table.sort(files, function(a, b)
        return a.ts < b.ts
    end)

    local to_delete = count - max_files

    if to_delete > 0 then
        for i = 1, to_delete do
            -- Safety check that files[i] exists
            if files[i] and files[i].name then
                local full_path = appdata .. files[i].name
                self:delete_entry({ file_path = full_path })
            end
        end
    end

    local remaining = {}
    for i = to_delete + 1, count do
        if files[i] and files[i].name then
            remaining[#remaining + 1] = files[i].name
        end
    end

    self:set_history_entries_cache(remaining)
end

-- Delete an entry and update the cache
function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

mod.delete_entry = function(self, entry)
    -- Only proceed if an entry is provided
    if not entry or not entry.file_path then
        return false
    end

    -- Try to remove the file
    if mod.lib.os.remove(entry.file_path) then
        -- Update the cache to remove the deleted entry
        local cache = mod:get_history_entries_cache()
        local new_cache = {}

        for _, cache_entry in pairs(cache) do
            local is_deleted_entry = ends_with(entry.file_path, cache_entry)
            if not is_deleted_entry then
                new_cache[#new_cache + 1] = cache_entry
            end
        end

        -- Save the updated cache
        mod:set_history_entries_cache(new_cache)
        return true
    end

    return false
end