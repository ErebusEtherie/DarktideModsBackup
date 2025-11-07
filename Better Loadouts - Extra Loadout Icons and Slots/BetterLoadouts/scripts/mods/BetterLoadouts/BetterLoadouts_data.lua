-- BetterLoadouts_data.lua

local mod = get_mod("BetterLoadouts")

return {
    name = "BetterLoadouts",
    description = mod and mod:localize("mod_description"),
    is_togglable = false,

    options = {
        widgets = {
            {
                setting_id    = "preset_limit",
                type          = "dropdown",
                default_value = 28,
                tooltip       = "preset_limit_tooltip",
                options       = {
                    { text = "preset_limit_option_28",  value = 28 },
                    { text = "preset_limit_option_200", value = 200 },
                },
            },
        },
    },
}
