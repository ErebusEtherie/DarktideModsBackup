local mod = get_mod("Killfeed_Reborn")
local DMF = get_mod("DMF")

local debug_utils = {}

local _io = DMF:persistent_table("_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
    _io = DMF.deepcopy(Mods.lua.io)
    _io.initialized = true
end

local _os = DMF:persistent_table("_os")
_os.initialized = _os.initialized or false
if not _os.initialized then
    _os = DMF.deepcopy(Mods.lua.os)
    _os.initialized = true
end

local OUTPUT_DIRECTORY = "Killfeed_Reborn_output"
local NON_MISSION_NAMES = {
    hub_ship = true,
    tg_shooting_range = true,
}
local mission_roster = {}

local function strip_markup(text)
    if not text then
        return nil
    end

    local clean = string.gsub(text, "{#.-}", "")
    clean = string.gsub(clean, "{#reset%(%)%}", "")

    return clean
end

local function stringify_debug_value(value)
    if value == nil then
        return "nil"
    end

    return tostring(value)
end

local function current_date()
    return _os.time(_os.date("*t"))
end

local function current_time_text()
    return os.date("[%H:%M:%S]")
end

local function format_fields(...)
    local parts = { ... }

    for i = 1, #parts do
        parts[i] = tostring(parts[i])
    end

    return table.concat(parts, " | ")
end

local function format_assignment(label, value)
    return string.format("%s %s", tostring(label), stringify_debug_value(value))
end

local function format_category_bucket(categories)
    if not categories or #categories == 0 then
        return "nil"
    end

    return table.concat(categories, ",")
end

local function build_mission_output_file_name()
    local unix_timestamp = current_date()

    if unix_timestamp then
        return string.format("%s.lua", tostring(unix_timestamp))
    end

    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    return string.format("%s.lua", timestamp)
end

local function output_to_file_enabled()
    return mod:get("output_to_file") == true
end

function debug_utils.create_output_directory()
    local appdata = _os.getenv("APPDATA")
    local dir_path = appdata .. "/Fatshark/Darktide/" .. OUTPUT_DIRECTORY .. "/"

    if not _os.rename(dir_path, dir_path) then
        _os.execute('mkdir "' .. dir_path .. '"')
    end
end

local function get_output_file_path()
    if not mod._active_output_file_name then
        return nil
    end

    local appdata = _os.getenv("APPDATA")
    return appdata .. "/Fatshark/Darktide/" .. OUTPUT_DIRECTORY .. "/" .. mod._active_output_file_name
end

function debug_utils.append_output_line(line)
    if not output_to_file_enabled() then
        return
    end

    debug_utils.create_output_directory()

    local path = get_output_file_path()
    if not path then
        return
    end

    local file = assert(_io.open(path, "a+"))

    file:write(current_time_text() .. " " .. tostring(line) .. "\n")
    file:close()
end

function debug_utils.begin_mission_output(mission_name)
    if not mission_name or NON_MISSION_NAMES[mission_name] then
        mod._active_output_file_name = nil
        mod._active_mission_name = nil
        table.clear(mission_roster)
        return
    end

    if mod._active_mission_name == mission_name and mod._active_output_file_name then
        return
    end

    if mod._active_output_file_name then
        debug_utils.end_mission_output()
    end

    local file_name = build_mission_output_file_name()

    table.clear(mission_roster)
    mod._active_output_file_name = file_name
    mod._active_mission_name = mission_name

    if output_to_file_enabled() then
        debug_utils.create_output_directory()
        local path = get_output_file_path()
        if path then
            local file = assert(_io.open(path, "w+"))
            file:close()
        end
    end
end

local function get_actor_class(unit)
    if not unit then
        return nil
    end

    local player_manager = Managers.state and Managers.state.player_unit_spawn
    local player = player_manager and player_manager:owner(unit)
    local profile = player and player.profile and player:profile()
    local archetype = profile and profile.archetype

    if archetype and archetype.name then
        return archetype.name
    end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    if unit_data_extension and unit_data_extension.archetype_name then
        return unit_data_extension:archetype_name()
    end

    return nil
end

local function get_actor_weapon_name(unit, slot_name)
    if not unit then
        return nil
    end

    local visual_loadout_extension = ScriptUnit.has_extension(unit, "visual_loadout_system")
    local item = visual_loadout_extension and visual_loadout_extension.item_from_slot and visual_loadout_extension:item_from_slot(slot_name)

    if item and item.name then
        return item.name
    end

    return nil
end

local function cache_actor_roster(unit, actor_name)
    local roster_name = strip_markup(actor_name) or actor_name

    if not roster_name then
        return
    end

    for i = 1, #mission_roster do
        if mission_roster[i].name == roster_name then
            return
        end
    end

    mission_roster[#mission_roster + 1] = {
        name = roster_name,
        class_name = get_actor_class(unit),
        primary_weapon = get_actor_weapon_name(unit, "slot_primary"),
        secondary_weapon = get_actor_weapon_name(unit, "slot_secondary"),
    }
end

function debug_utils.append_kill_debug_line(attacker, killer_name, data, message, detected_category, chosen_category, category_reason, source_entry, phrase_meta)
    if not output_to_file_enabled() then
        return
    end

    cache_actor_roster(attacker, killer_name)

    local had_damage_cache = data ~= nil
    local profile_name = data and data.profile_name or "nil"
    local attack_type = data and data.attack_type or nil
    local attack_result = data and data.attack_result or nil
    local message_text = strip_markup(message) or tostring(message)
    local profile_text = stringify_debug_value(profile_name)
    local type_text = stringify_debug_value(attack_type)
    local result_text = stringify_debug_value(attack_result)
    local cache_text = had_damage_cache and "yes" or "no"
    local reason_text = stringify_debug_value(category_reason)
    local source_text = source_entry and source_entry.source or "nil"
    local broad_text = format_category_bucket(source_entry and source_entry.broad)
    local specific_text = format_category_bucket(source_entry and source_entry.specific)
    local selection = phrase_meta and phrase_meta.selection or nil
    local mix_mode_text = selection and selection.mode or "nil"
    local roll_text = selection and selection.roll or "nil"
    local threshold_text = selection and selection.threshold or "nil"
    local bucket_text = selection and selection.bucket or "nil"
    local funny_roll_text = selection and selection.funny_roll or "nil"
    local funny_threshold_text = selection and selection.funny_threshold or "nil"
    local funny_applied_text = selection and selection.funny_applied or "no"
    local bag_cycle_text = phrase_meta and phrase_meta.bag_cycle or "nil"
    local bag_remaining_text = phrase_meta and phrase_meta.bag_remaining or "nil"
    local pool_size_text = phrase_meta and phrase_meta.pool_size or "nil"
    local phrase_index_text = phrase_meta and phrase_meta.phrase_index or "nil"
    local bag_reset_text = phrase_meta and (phrase_meta.bag_reset and "yes" or "no") or "nil"

    debug_utils.append_output_line(format_fields(
        format_assignment("message", message_text),
        format_assignment("detected", detected_category),
        format_assignment("chosen", chosen_category),
        format_assignment("reason", reason_text),
        format_assignment("broad", broad_text),
        format_assignment("specific", specific_text),
        format_assignment("source", source_text),
        format_assignment("mix", mix_mode_text),
        format_assignment("roll", roll_text),
        format_assignment("threshold", threshold_text),
        format_assignment("bucket", bucket_text),
        format_assignment("funny_roll", funny_roll_text),
        format_assignment("funny_threshold", funny_threshold_text),
        format_assignment("funny", funny_applied_text),
        format_assignment("cycle", bag_cycle_text),
        format_assignment("reset", bag_reset_text),
        format_assignment("remaining", bag_remaining_text),
        format_assignment("pool", pool_size_text),
        format_assignment("index", phrase_index_text),
        format_assignment("profile", profile_text),
        format_assignment("type", type_text),
        format_assignment("result", result_text),
        format_assignment("cache", cache_text)
    ))
end

function debug_utils.append_player_state_debug_line(player_unit, player_name, message, state_text, bucket, attack_result)
    if not output_to_file_enabled() then
        return
    end

    cache_actor_roster(player_unit, player_name)

    debug_utils.append_output_line(format_fields(
        format_assignment("message", strip_markup(message) or tostring(message)),
        format_assignment("state", state_text),
        format_assignment("bucket", bucket),
        format_assignment("result", attack_result)
    ))
end

function debug_utils.end_mission_output()
    if output_to_file_enabled() and #mission_roster > 0 then
        debug_utils.append_output_line("MISSION ROSTER")

        for i = 1, #mission_roster do
            local entry = mission_roster[i]

            debug_utils.append_output_line(format_fields(
                entry.name,
                format_assignment("class", entry.class_name),
                format_assignment("primary", entry.primary_weapon),
                format_assignment("secondary", entry.secondary_weapon)
            ))
        end
    end

    table.clear(mission_roster)
    mod._active_output_file_name = nil
    mod._active_mission_name = nil
end

return debug_utils
