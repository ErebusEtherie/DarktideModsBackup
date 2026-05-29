-- BetterLoadouts_data.lua

local mod = get_mod("BetterLoadouts")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,

    options = {
        widgets = {
            {
                setting_id = "preset_limit",
                type = "dropdown",
                default_value = 28,
                tooltip = "preset_limit_tooltip",
                options = {
                    { text = "preset_limit_option_28",  value = 28 },
                    { text = "preset_limit_option_200", value = 200 },
                    { text = "preset_limit_option_300", value = 300 },
                    { text = "preset_limit_option_30",  value = 30 },
                    { text = "preset_limit_option_60",  value = 60 },
                    { text = "preset_limit_option_160", value = 160 },
                    { text = "preset_limit_option_240", value = 240 },
                },
            },
            {
                setting_id      = "move_preset_backward",
                type            = "keybind",
                default_value   = {},
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "move_preset_backward",
            },
            {
                setting_id      = "move_preset_forward",
                type            = "keybind",
                default_value   = {},
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "move_preset_forward",
            },
        },
    },
}
