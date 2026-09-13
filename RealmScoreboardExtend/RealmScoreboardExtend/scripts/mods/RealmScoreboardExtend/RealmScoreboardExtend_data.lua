local mod = get_mod("RealmScoreboardExtend")
local function number(id, default, low, high)
    return {setting_id = id, type = "numeric", default_value = default, range = {low, high}, decimals_number = 0}
end
local function key(id, callback, default)
    return {setting_id = id, type = "keybind", default_value = {default}, keybind_trigger = "pressed",
        keybind_type = "function_call", keybind_global = true, function_name = callback}
end
local data = {
    name = mod:localize("mod_name"), description = mod:localize("mod_description"), is_togglable = false,
    options = {widgets = {
        number("max_players", 8, 1, 12),
        number("end_players", 8, 1, 12),
        number("history_players", 8, 1, 12),
        number("width_percent", 100, 60, 140),
        number("font_percent", 100, 75, 140),
        number("equipment_perk_limit", 2, 1, 6),
        number("equipment_blessing_limit", 2, 1, 6),
        {setting_id = "debug_logging", type = "checkbox", default_value = true},
        key("previous_page", "previous_page", "page up"),
        key("next_page", "next_page", "page down"),
    }},
}
local Migration = mod:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/settings_migration")
Migration.import(mod, get_mod("DMF"), data.options.widgets)
return data
