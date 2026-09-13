local mod = get_mod('better_buff_management')

return {
    name = mod:localize('mod_name'),
    description = mod:localize('mod_description'),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = 'configure_buffs',
                type = 'keybind',
                default_value = {},
                keybind_global = false,
                keybind_trigger = 'pressed',
                keybind_type = 'function_call',
                function_name = 'configure_buffs'
            },
            -- {
            --     setting_id = 'add_buff_direction',
            --     type = 'dropdown',
            --     default_value = 'end',
            --     options = {
            --         { text = 'add_buff_direction_option_end', value = 'end' },
            --         { text = 'add_buff_direction_option_middle', value = 'middle' },
            --         { text = 'add_buff_direction_option_start', value = 'start' }
            --     }
            -- },
            -- {
            --     setting_id = 'toggle_hidden_buffs',
            --     type = 'checkbox',
            --     default_value = false
            -- },
            {
                setting_id = 'toggle_default_bar',
                type = 'checkbox',
                default_value = false
            },
            {
                setting_id = 'leave_default_bar_alone',
                type = 'checkbox',
                default_value = false
            },
            {
                setting_id = 'group_buffs_in_categories',
                type = 'checkbox',
                default_value = false
            },
            {
                setting_id = 'enable_recent_buff_observer',
                type = 'checkbox',
                default_value = false
            },
            {
                setting_id = 'recent_buffs_display_limit',
                type = 'dropdown',
                default_value = 30,
                options = {
                    { text = 'recent_buffs_display_limit_option_5', value = 5 },
                    { text = 'recent_buffs_display_limit_option_10', value = 10 },
                    { text = 'recent_buffs_display_limit_option_15', value = 15 },
                    { text = 'recent_buffs_display_limit_option_20', value = 20 },
                    { text = 'recent_buffs_display_limit_option_25', value = 25 },
                    { text = 'recent_buffs_display_limit_option_30', value = 30 },
                    { text = 'recent_buffs_display_limit_option_35', value = 35 },
                    { text = 'recent_buffs_display_limit_option_40', value = 40 },
                    { text = 'recent_buffs_display_limit_option_45', value = 45 },
                    { text = 'recent_buffs_display_limit_option_50', value = 50 }
                }
            },
            {
                setting_id = 'configure_window_width',
                type = 'numeric',
                default_value = 800,
                range = { 400, 2000 }
            },
            {
                setting_id = 'configure_window_height',
                type = 'numeric',
                default_value = 500,
                range = { 300, 1400 }
            },
            {
                setting_id = 'configure_window_x',
                type = 'numeric',
                default_value = 200,
                range = { 0, 3840 }
            },
            {
                setting_id = 'configure_window_y',
                type = 'numeric',
                default_value = 150,
                range = { 0, 2160 }
            }
        }
    }
}
