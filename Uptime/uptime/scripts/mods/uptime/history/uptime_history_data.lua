local mod = get_mod("uptime")
local UISettings = require("scripts/settings/ui/ui_settings")

-- UptimeHistoryData handles all data-related operations for uptime history entries
local UptimeHistoryData = class("UptimeHistoryData")

UptimeHistoryData.init = function(self)
end

-- Get all uptime history entries, optionally forcing a directory scan
UptimeHistoryData.get_list_entries = function(self, scan_dir)
    -- Get all uptime history entries
    local history_entries = mod:get_history_entries(scan_dir)
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

    local data = history_entry.meta_data
    local mission_name = mod.lib.missions.localize_name(data.mission_name)
    local mission_difficulty = mod.lib.missions.localize_difficulty(data.mission_difficulty)
    local mission_modifier = mod.lib.missions.localize_modifier(data.mission_modifier)
    local title = mission_name or "DEBUG"
    if mission_difficulty then
        title = title .. " | " .. mission_difficulty
    end
    if mission_modifier then
        title = title .. " | " .. mission_modifier
    end

    local archetype = history_entry.meta_data.archetype
    local subtitle = ""
    if (archetype) then
        subtitle = UISettings.archetype_font_icon[archetype] .. " "
    end
    local player_name = history_entry.meta_data.player
    if player_name then
        subtitle = subtitle .. player_name
    end
    local date = history_entry.meta_data.date
    if date then
        subtitle = subtitle .. " | " .. mod.ui.format_date(date)
    end


    -- Create and return the entry
    return {
        widget_type = "settings_button",
        title = title,
        subtitle = subtitle,
        history_entry = history_entry,
    }
end

UptimeHistoryData.delete_entry = function(self, entry)
    return mod:delete_entry(entry)
end

return UptimeHistoryData