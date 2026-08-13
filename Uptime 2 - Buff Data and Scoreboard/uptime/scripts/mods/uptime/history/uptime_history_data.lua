-- File: uptime/scripts/mods/uptime/history/uptime_history_data.lua
local mod = get_mod("uptime"); if not mod then return end
local UISettings = require("scripts/settings/ui/ui_settings")

-- UptimeHistoryData handles all data-related operations for uptime history entries
local UptimeHistoryData = class("UptimeHistoryData")

local function clean_note_text(note)
    note = tostring(note or "")
    note = note:gsub("[\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")

    return note
end

UptimeHistoryData.init = function(self)
end

-- Get all uptime history entries, optionally forcing a directory scan
UptimeHistoryData.get_list_entries = function(self, scan_dir)
    -- Get lightweight metadata entries for the list; full entries are loaded only when selected.
    local history_entries = mod:get_history_metadata_entries(scan_dir)
    local entries = {}
    local entries_by_title = {}

    -- Process each history entry
    for i = 1, #history_entries do
        local history_entry = history_entries[i]
        local entry = self:create_list_entry(history_entry)
        entries[#entries + 1] = entry
        entries_by_title[entry.title] = entry
    end

    -- Return the processed entries and the default entry if available
    local default_entry = history_entries[1] and history_entries[1].date or nil
    return entries, entries_by_title, default_entry
end

-- Create an entry from history data
UptimeHistoryData.create_list_entry = function(self, history_entry)
    local data = history_entry.meta_data or {}
    local mission_name = mod.lib.missions.localize_name(data.mission_name)
    local mission_difficulty = mod.lib.missions.localize_difficulty(data.mission_difficulty)
    local mission_modifier = mod.lib.missions.localize_modifier(data.mission_modifier)
    local title = mission_name or "LEGACY"
    if data.favourite then
        title = " " .. title
    end
    if mission_difficulty then
        title = title .. " | " .. mission_difficulty
    end
    if mission_modifier then
        title = title .. " | " .. mission_modifier
    end

    local archetype = data.archetype
    local subtitle = ""
    if (archetype) then
        subtitle = UISettings.archetype_font_icon[archetype] .. " "
    end
    local player_name = data.player
    if player_name then
        subtitle = subtitle .. player_name
    end
    local date = data.date
    if date then
        subtitle = subtitle .. " | " .. mod.ui.format_date(date)
    end


    local note = clean_note_text(data.note)
    local note_text = ""

    if note ~= "" then
        note_text = Localize("loc_note_prefix") .. ": " .. note
    end

    -- Create and return the entry
    return {
        widget_type = "settings_button",
        title = title,
        subtitle = subtitle,
        note = note_text,
        history_entry = history_entry,
    }
end

UptimeHistoryData.get_full_entry = function(self, entry)
    if not entry then
        return nil
    end

    if entry.metadata_only and entry.file then
        local full_entry = mod:load_entry(entry.file)

        if full_entry and full_entry.file_path then
            return full_entry
        end

        return nil
    end

    return entry
end

UptimeHistoryData.delete_entry = function(self, entry)
    return mod:delete_entry(entry)
end

UptimeHistoryData.set_entry_note = function(self, entry, note)
    return mod:update_entry_note(entry, note)
end

UptimeHistoryData.toggle_entry_favourite = function(self, entry)
    return mod:toggle_entry_favourite(entry)
end

return UptimeHistoryData
