local profile_logger = {}
local DMF = get_mod("DMF")

local _io = DMF:persistent_table("Killfeed_Reborn_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
    _io = DMF.deepcopy(Mods.lua.io)
    _io.initialized = true
end

local _os = DMF:persistent_table("Killfeed_Reborn_os")
_os.initialized = _os.initialized or false
if not _os.initialized then
    _os = DMF.deepcopy(Mods.lua.os)
    _os.initialized = true
end

local OUTPUT_DIRECTORY = "Killfeed_Reborn_output"
local UNCLASSIFIED_OUTPUT_FILE_NAME = "unclassified_profiles.lua"

local function get_output_file_path()
    local appdata = _os.getenv("APPDATA")

    return appdata .. "/Fatshark/Darktide/" .. OUTPUT_DIRECTORY .. "/" .. UNCLASSIFIED_OUTPUT_FILE_NAME
end

local function create_output_directory()
    local appdata = _os.getenv("APPDATA")
    local dir_path = appdata .. "/Fatshark/Darktide/" .. OUTPUT_DIRECTORY .. "/"

    if not _os.rename(dir_path, dir_path) then
        _os.execute('mkdir "' .. dir_path .. '"')
    end
end

function profile_logger.append(profile_type, profile_name)
    create_output_directory()

    local file = assert(_io.open(get_output_file_path(), "a+"))
    local timestamp = _os.date("%H:%M:%S")

    file:write(string.format("[%s] %s | %s\n", tostring(timestamp), tostring(profile_type), tostring(profile_name or "nil")))
    file:close()
end

return profile_logger
