local mod = get_mod("uptime")

return {
    name = "uptime",
    description = mod:localize("mod_description"),
    is_togglable = false,
    options = {
        widgets = {
            { setting_id = "open_uptime_history",
              type = "keybind",
              default_value = { "f8" },
              keybind_trigger = "pressed",
              keybind_type = "view_toggle",
              view_name = "uptime_history_view"
            }, {
                setting_id = "track_meat_grinder",
                type = "checkbox",
                default_value = false,
            }, {
                setting_id = "save_files_options",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "delete_old_entries",
                        type = "checkbox",
                        default_value = false,
                    }, {
                        setting_id = "number_of_save_files",
                        type = "numeric",
                        default_value = 30,
                        range = { 1, 100 },
                    },
                }
            }, {
                setting_id = "data_display_settings",
                type = "group",
                sub_widgets = {
                    { setting_id = "show_uptime",
                      type = "checkbox",
                      default_value = false
                    },
                    { setting_id = "show_uptime_percentage",
                      type = "checkbox",
                      default_value = false
                    },
                    { setting_id = "show_uptime_combat",
                      type = "checkbox",
                      default_value = false
                    },
                    { setting_id = "show_uptime_combat_percentage",
                      type = "checkbox",
                      default_value = true
                    },
                    { setting_id = "show_combat_percentage_per_stack",
                      type = "checkbox",
                      default_value = true
                    },
                    { setting_id = "show_combat_time_at_max_stack",
                      type = "checkbox",
                      default_value = false
                    },
                    { setting_id = "show_combat_percentage_at_max_stack",
                      type = "checkbox",
                      default_value = true
                    },
                    { setting_id = "show_average_stacks_combat",
                      type = "checkbox",
                      default_value = true
                    },
                }
            }
        }
    }
}
