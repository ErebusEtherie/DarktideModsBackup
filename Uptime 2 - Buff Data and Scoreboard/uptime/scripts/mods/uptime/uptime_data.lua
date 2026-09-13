-- File: uptime/scripts/mods/uptime/uptime_data.lua
local mod = get_mod("uptime"); if not mod then return end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    options = {
        widgets = {
            {
                setting_id = "save_files_options",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "open_uptime_history",
                        type = "keybind",
                        default_value = {},
                        keybind_trigger = "pressed",
                        keybind_type = "view_toggle",
                        view_name = "uptime_history_view"
                    },
                    { setting_id = "track_meat_grinder",           type = "checkbox", default_value = false },
                    { setting_id = "delete_old_entries",           type = "checkbox", default_value = true },
                    { setting_id = "legacy_history_compatibility", type = "checkbox", default_value = true },
                    {
                        setting_id = "number_of_save_files",
                        type = "numeric",
                        default_value = 30,
                        range = { 1, 100 },
                    },
                }
            },
            {
                setting_id = "data_display_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "show_uptime_mode",
                        type = "dropdown",
                        default_value = "none",
                        options = {
                            { text = "loc_dropdown_none",       value = "none" },
                            { text = "loc_dropdown_time",       value = "time" },
                            { text = "loc_dropdown_percentage", value = "percentage" },
                            { text = "loc_dropdown_both",       value = "both" }
                        }
                    },
                    {
                        setting_id = "show_uptime_combat_mode",
                        type = "dropdown",
                        default_value = "percentage",
                        options = {
                            { text = "loc_dropdown_none",       value = "none" },
                            { text = "loc_dropdown_time",       value = "time" },
                            { text = "loc_dropdown_percentage", value = "percentage" },
                            { text = "loc_dropdown_both",       value = "both" }
                        }
                    },
                    { setting_id = "show_combat_percentage_per_stack", type = "checkbox", default_value = true },
                    {
                        setting_id = "show_combat_max_stack_mode",
                        type = "dropdown",
                        default_value = "percentage",
                        options = {
                            { text = "loc_dropdown_none",       value = "none" },
                            { text = "loc_dropdown_time",       value = "time" },
                            { text = "loc_dropdown_percentage", value = "percentage" },
                            { text = "loc_dropdown_both",       value = "both" }
                        }
                    },
                    { setting_id = "show_average_stacks_combat",       type = "checkbox", default_value = true },
                    {
                        setting_id = "track_damage",
                        type = "dropdown",
                        default_value = "view_tactical_end",
                        options = {
                            { text = "loc_track_damage_off",               value = "off" },
                            { text = "loc_track_damage_view",              value = "view" },
                            { text = "loc_track_damage_view_and_tactical", value = "view_and_tactical" },
                            { text = "loc_track_damage_view_tactical_end", value = "view_tactical_end" },
                        },
                    },
                    {
                        setting_id = "end_view_scoreboard_position",
                        type = "dropdown",
                        default_value = "down",
                        options = {
                            { text = "loc_end_view_scoreboard_position_down", value = "down" },
                            { text = "loc_end_view_scoreboard_position_up",   value = "up" },
                        },
                    },
                },
            },
        },
    },
}
