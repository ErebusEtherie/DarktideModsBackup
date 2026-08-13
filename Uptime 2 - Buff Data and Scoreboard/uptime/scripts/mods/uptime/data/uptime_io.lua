-- File: uptime/scripts/mods/uptime/data/uptime_io.lua
local mod = get_mod("uptime"); if not mod then return end
local DMF = get_mod("DMF")
local json = mod:io_dofile("uptime/scripts/mods/uptime/libs/json")
local v1_migration = mod:io_dofile("uptime/scripts/mods/uptime/data/v1_to_v2")

-- ##### IO and OS functions #####
local _io = DMF:persistent_table("_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
    _io = DMF.deepcopy(Mods.lua.io)
    _io.initialized = true
end

-- ##### Helper functions #####
local file_does_not_exist = {}
local file_too_large = {}

local max_history_entry_bytes = 3 * 1024 * 1024
local metadata_file_suffix = ".meta"
local skipped_oversized_files = {}

local function make_path(file_name)
    return mod:appdata_path() .. file_name
end

local function make_metadata_path(file_name)
    return make_path(file_name .. metadata_file_suffix)
end

local function is_history_entry_file(file_name)
    return type(file_name) == "string" and string.match(file_name, "^%d+%.json$") ~= nil
end

local function legacy_history_compatibility_enabled()
    return mod.legacy_history_compatibility ~= false
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

local function file_size(path)
    local file = _io.open(path, "rb")
    if not file then
        return nil
    end

    local size = file:seek("end")
    file:close()

    return size
end

local function is_oversized_history_file(path)
    local size = file_size(path)

    return size and size > max_history_entry_bytes, size
end

local function echo_oversized_file_once(file_name, size)
    if skipped_oversized_files[file_name] then
        return
    end

    skipped_oversized_files[file_name] = true

    local size_mb = size and string.format("%.1f", size / 1024 / 1024) or "unknown"
    mod:echo("Uptime skipped oversized history file: " .. file_name .. " (" .. size_mb .. " MB).")
end

local function create_history_entry_metadata(entry, file_name, file_path)
    local meta_data = entry and entry.meta_data or {}
    local date_str = file_name and string.match(file_name, "^(%d+)") or nil
    local date = meta_data.date or tonumber(date_str)

    return {
        version = entry and entry.version or nil,
        file = file_name,
        file_path = file_path,
        file_size = file_path and file_size(file_path) or nil,
        date = date,
        mission_name = entry and entry.mission_name or meta_data.mission_name,
        meta_data = {
            mission_name = meta_data.mission_name,
            player = meta_data.player,
            account_id = meta_data.account_id,
            archetype = meta_data.archetype,
            mission_difficulty = meta_data.mission_difficulty,
            mission_modifier = meta_data.mission_modifier,
            date = date,
            note = meta_data.note,
            favourite = meta_data.favourite,
        },
        metadata_only = true,
    }
end

local function write_history_entry_metadata(entry, file_name, file_path)
    if not entry or not file_name or not file_path then
        return false
    end

    local metadata_path = make_metadata_path(file_name)
    local metadata_file = _io.open(metadata_path, "w+")

    if not metadata_file then
        return false
    end

    metadata_file:write(json.encode(create_history_entry_metadata(entry, file_name, file_path)))
    metadata_file:close()

    return true
end

local function load_history_entry_metadata(file_name)
    local metadata_path = make_metadata_path(file_name)

    if not file_exists(metadata_path) then
        return nil
    end

    local metadata = nil
    for metadata_json in _io.lines(metadata_path) do
        if metadata then
            mod:echo("Received more than 1 line when loading metadata! Metadata file might be corrupted")
        else
            metadata = json.decode(metadata_json)
        end
    end

    if metadata then
        metadata.file = file_name
        metadata.file_path = make_path(file_name)
        metadata.metadata_only = true
    end

    return metadata
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
        mod.lib.os.execute('mkdir ' .. path)         -- ?
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

    local entry_json = json.encode(entry)
    file:write(entry_json)

    file:close()
    write_history_entry_metadata(entry, file_name, path)

    local cache = self:get_history_entries_cache()
    cache[#cache + 1] = file_name
    self:set_history_entries_cache(cache)

    if mod.delete_old_entries then
        self:enforce_history_limit(mod.number_of_save_files)
    end
end

local function clean_entry_note(note)
    note = tostring(note or "")
    note = note:gsub("[\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")

    return note
end

mod.save_existing_entry = function(self, entry)
    if not entry or not entry.file_path then
        return false
    end

    if entry.metadata_only and entry.file then
        local full_entry = self:load_entry(entry.file)
        if not full_entry or full_entry == file_does_not_exist or full_entry == file_too_large then
            return false
        end

        local source_meta_data = entry.meta_data or {}
        local target_meta_data = full_entry.meta_data or {}
        full_entry.meta_data = target_meta_data
        target_meta_data.note = source_meta_data.note
        target_meta_data.favourite = source_meta_data.favourite

        return self:save_existing_entry(full_entry)
    end

    local file_name = entry.file
    local file_path = entry.file_path

    entry.file = nil
    entry.file_path = nil

    local entry_json = json.encode(entry)

    entry.file = file_name
    entry.file_path = file_path

    local file = _io.open(file_path, "w+")
    if not file then
        return false
    end

    file:write(entry_json)
    file:close()
    write_history_entry_metadata(entry, file_name, file_path)

    return true
end

mod.update_entry_note = function(self, entry, note)
    if not entry then
        return false
    end

    local meta_data = entry.meta_data
    if not meta_data then
        meta_data = {}
        entry.meta_data = meta_data
    end

    local cleaned_note = clean_entry_note(note)
    meta_data.note = cleaned_note ~= "" and cleaned_note or nil

    return self:save_existing_entry(entry)
end

mod.toggle_entry_favourite = function(self, entry)
    if not entry then return false end

    local meta_data = entry.meta_data
    if not meta_data then
        meta_data = {}
        entry.meta_data = meta_data
    end

    meta_data.favourite = not meta_data.favourite

    return self:save_existing_entry(entry)
end

-- Load uptime data from a file
function mod:load_entry(file_name)
    local path = make_path(file_name)

    if not file_exists(path) then
        mod:echo("Error: File not found: " .. path)
        return file_does_not_exist
    end

    local oversized, size = is_oversized_history_file(path)
    if oversized then
        echo_oversized_file_once(file_name, size)
        return file_too_large
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

    write_history_entry_metadata(entry, file_name, path)

    return entry
end

function mod:load_entry_metadata(file_name)
    if not is_history_entry_file(file_name) then
        return nil
    end

    local path = make_path(file_name)

    if not file_exists(path) then
        mod:echo("Error: File not found: " .. path)
        return file_does_not_exist
    end

    local metadata = load_history_entry_metadata(file_name)
    if metadata then
        return metadata
    end

    if legacy_history_compatibility_enabled() then
        local entry = self:load_entry(file_name)

        if entry == file_does_not_exist then
            return file_does_not_exist
        end

        if entry and entry ~= file_too_large then
            return load_history_entry_metadata(file_name) or create_history_entry_metadata(entry, file_name, path)
        end
    end

    return create_history_entry_metadata(nil, file_name, path)
end

local function scandir(directory)
    local i, file_names, popen = 0, {}, _io.popen
    local pfile = popen('dir "' .. directory .. '" /b')
    for filename in pfile:lines() do
        if is_history_entry_file(filename) then
            i = i + 1
            file_names[i] = filename
        end
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
        if is_history_entry_file(file) then
            local result = self:load_entry(file)
            if result == file_does_not_exist then
                return self:get_history_entries(true)
            end
            if result and result ~= file_too_large then
                entries[#entries + 1] = result
            end
        end
    end

    return entries
end

function mod:get_history_metadata_entries(scan_dir)
    local entries = {}
    local appdata = self:appdata_path()
    local file_names = self:get_history_entries_cache()

    if scan_dir or not file_names then
        file_names = scandir(appdata)
        self:set_history_entries_cache(file_names)
    end

    for _, file in pairs(file_names) do
        if is_history_entry_file(file) then
            local result = self:load_entry_metadata(file)
            if result == file_does_not_exist then
                return self:get_history_metadata_entries(true)
            end
            if result then
                entries[#entries + 1] = result
            end
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

    local files_to_consider = {}
    local new_cache = {}

    for _, name in pairs(file_names) do
        local ts = tonumber(string.match(name, "^(%d+)"))
        if ts then
            local metadata = load_history_entry_metadata(name)

            if metadata and metadata.meta_data and metadata.meta_data.favourite then
                new_cache[#new_cache + 1] = name
            else
                files_to_consider[#files_to_consider + 1] = { name = name, ts = ts }
            end
        end
    end

    local count = #files_to_consider
    local to_delete = count - max_files

    if to_delete > 0 then
        -- Sort chronologically (oldest files first)
        table.sort(files_to_consider, function(a, b)
            return a.ts < b.ts
        end)

        local deleted = {}
        local deleted_count = 0

        for i = 1, count do
            if deleted_count >= to_delete then
                break
            end

            local candidate = files_to_consider[i]

            if candidate and candidate.name then
                local metadata = load_history_entry_metadata(candidate.name)
                local favourite = metadata and metadata.meta_data and metadata.meta_data.favourite

                if metadata == nil then
                    if legacy_history_compatibility_enabled() then
                        local entry = self:load_entry(candidate.name)

                        -- If the file is too large to decode safely, preserve it.
                        -- It may be a favourite, and deleting it without decoding would be unsafe.
                        if entry == file_too_large then
                            favourite = true
                        elseif entry and entry ~= file_does_not_exist then
                            favourite = entry.meta_data and entry.meta_data.favourite
                        end
                    else
                        -- Without legacy compatibility, do not decode old files during cleanup.
                        -- Preserve them because they may be favourites.
                        favourite = true
                    end
                end

                if favourite then
                    new_cache[#new_cache + 1] = candidate.name
                else
                    local full_path = appdata .. candidate.name
                    -- Directly remove the file without rebuilding the cache every single iteration
                    if mod.lib.os.remove(full_path) then
                        mod.lib.os.remove(make_metadata_path(candidate.name))
                    end

                    deleted[candidate.name] = true
                    deleted_count = deleted_count + 1
                end
            end
        end

        -- Add the remaining non-deleted files to the final cache
        for i = 1, count do
            if files_to_consider[i] and files_to_consider[i].name and not deleted[files_to_consider[i].name] then
                local already_cached = false

                for j = 1, #new_cache do
                    if new_cache[j] == files_to_consider[i].name then
                        already_cached = true
                        break
                    end
                end

                if not already_cached then
                    new_cache[#new_cache + 1] = files_to_consider[i].name
                end
            end
        end
    else
        -- If we didn't delete anything, simply append all the considered files
        for i = 1, count do
            if files_to_consider[i] and files_to_consider[i].name then
                new_cache[#new_cache + 1] = files_to_consider[i].name
            end
        end
    end

    -- Write the fully constructed cache
    self:set_history_entries_cache(new_cache)
end

-- Delete an entry and update the cache
local function ends_with(str, ending)
    return ending == "" or str:sub(- #ending) == ending
end

mod.delete_entry = function(self, entry)
    -- Only proceed if an entry is provided and it is NOT a favourite
    if not entry or not entry.file_path then
        return false
    end
    if entry.meta_data and entry.meta_data.favourite then
        return false
    end

    -- Try to remove the file
    if mod.lib.os.remove(entry.file_path) then
        if entry.file then
            mod.lib.os.remove(make_metadata_path(entry.file))
        end

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
