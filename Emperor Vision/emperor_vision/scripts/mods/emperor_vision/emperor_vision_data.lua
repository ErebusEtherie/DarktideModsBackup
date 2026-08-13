local mod = get_mod("emperor_vision")
local config = mod:io_dofile("emperor_vision/scripts/mods/emperor_vision/emperor_vision_config")

local general_title = mod:localize("general_title")
local force_outline_visibility_title = mod:localize("force_outline_visibility_title")
local require_line_of_sight_title = mod:localize("require_line_of_sight_title")
local preserve_custom_color_on_ally_tag_title = mod:localize("preserve_custom_color_on_ally_tag_title")
local preserve_custom_color_on_veteran_tag_title = mod:localize("preserve_custom_color_on_veteran_tag_title")
local preserve_custom_color_on_companion_command_tag_title = mod:localize("preserve_custom_color_on_companion_command_tag_title")
local use_global_outline_override_title = mod:localize("use_global_outline_override_title")
local global_outline_visibility_title = mod:localize("global_outline_visibility_title")
local global_outline_distance_title = mod:localize("global_outline_distance_title")
local toggle_key_title = mod:localize("toggle_key_title")

local enable_this_mob_title = mod:localize("enable_this_mob_title")
local los_behavior_title = mod:localize("los_behavior_title")
local los_behavior_global_option = mod:localize("los_behavior_global_option")
local los_behavior_enabled_option = mod:localize("los_behavior_enabled_option")
local los_behavior_disabled_option = mod:localize("los_behavior_disabled_option")
local outline_visibility_title = mod:localize("outline_visibility_title")
local outline_distance_title = mod:localize("outline_distance_title")
local color_r_title = mod:localize("color_r_title")
local color_g_title = mod:localize("color_g_title")
local color_b_title = mod:localize("color_b_title")
local unknown_units_title = mod:localize("unknown_units_title")

local function localized_category_label(category)
    local category_key = "category_label_" .. tostring(category or "enemy")
    local localized = mod:localize(category_key)

    if localized and localized ~= category_key then
        return localized
    end

    return config.get_category_label(category)
end

local widgets = {
    {
        setting_id = "general_group",
        type = "group",
        tab = general_title,
        title = general_title,
        localize = false,
        sub_widgets = {
            {
                setting_id = "force_outline_visibility",
                type = "checkbox",
                title = force_outline_visibility_title,
                tooltip = mod:localize("force_outline_visibility_tooltip"),
                default_value = true,
                localize = false,
            },
            {
                setting_id = "require_line_of_sight",
                type = "checkbox",
                title = require_line_of_sight_title,
                tooltip = mod:localize("require_line_of_sight_tooltip"),
                default_value = false,
                localize = false,
            },
            {
                setting_id = "preserve_custom_color_on_ally_tag",
                type = "checkbox",
                title = preserve_custom_color_on_ally_tag_title,
                tooltip = mod:localize("preserve_custom_color_on_ally_tag_tooltip"),
                default_value = true,
                localize = false,
            },
            {
                setting_id = "preserve_custom_color_on_veteran_tag",
                type = "checkbox",
                title = preserve_custom_color_on_veteran_tag_title,
                tooltip = mod:localize("preserve_custom_color_on_veteran_tag_tooltip"),
                default_value = true,
                localize = false,
            },
            {
                setting_id = "preserve_custom_color_on_companion_command_tag",
                type = "checkbox",
                title = preserve_custom_color_on_companion_command_tag_title,
                tooltip = mod:localize("preserve_custom_color_on_companion_command_tag_tooltip"),
                default_value = true,
                localize = false,
            },
            {
                setting_id = "use_global_outline_override",
                type = "checkbox",
                title = use_global_outline_override_title,
                tooltip = mod:localize("use_global_outline_override_tooltip"),
                default_value = false,
                localize = false,
            },
            {
                setting_id = "global_outline_visibility",
                type = "numeric",
                title = global_outline_visibility_title,
                tooltip = mod:localize("global_outline_visibility_tooltip"),
                default_value = 100,
                range = { 0, 100 },
                decimals_number = 0,
                localize = false,
            },
            {
                setting_id = "global_outline_distance",
                type = "numeric",
                title = global_outline_distance_title,
                tooltip = mod:localize("global_outline_distance_tooltip"),
                default_value = 120,
                range = { 5, 120 },
                decimals_number = 0,
                localize = false,
            },
            {
                setting_id = "toggle_key",
                type = "keybind",
                title = toggle_key_title,
                tooltip = mod:localize("toggle_key_tooltip"),
                keybind_trigger = "pressed",
                keybind_type = "function_call",
                default_value = {},
                function_name = "toggle_emperor_vision",
                localize = false,
            },
        },
    },
}

local function add_breed_group_widget(breed_key, display_name, category, defaults)
    local ids = config.get_setting_ids(breed_key)
    local category_label = localized_category_label(category)

    widgets[#widgets + 1] = {
        setting_id = ids.group,
        type = "group",
        tab = display_name,
        title = string.format("%s (%s)", display_name, category_label),
        localize = false,
        sub_widgets = {
            {
                setting_id = ids.enabled,
                type = "checkbox",
                title = enable_this_mob_title,
                default_value = defaults.enabled,
                localize = false,
            },
            {
                setting_id = ids.los_behavior,
                type = "dropdown",
                title = los_behavior_title,
                tooltip = mod:localize("los_behavior_tooltip"),
                default_value = config.LOS_BEHAVIOR_GLOBAL,
                options = {
                    {
                        text = los_behavior_global_option,
                        value = config.LOS_BEHAVIOR_GLOBAL,
                    },
                    {
                        text = los_behavior_enabled_option,
                        value = config.LOS_BEHAVIOR_ENABLED,
                    },
                    {
                        text = los_behavior_disabled_option,
                        value = config.LOS_BEHAVIOR_DISABLED,
                    },
                },
                localize = false,
            },
            {
                setting_id = ids.visibility,
                type = "numeric",
                title = outline_visibility_title,
                default_value = defaults.visibility,
                range = { 0, 100 },
                decimals_number = 0,
                localize = false,
            },
            {
                setting_id = ids.distance,
                type = "numeric",
                title = outline_distance_title,
                default_value = defaults.distance,
                range = { 5, 120 },
                decimals_number = 0,
                localize = false,
            },
            {
                setting_id = ids.color_r,
                type = "numeric",
                title = color_r_title,
                default_value = defaults.color_r,
                range = { 0, 255 },
                decimals_number = 0,
                localize = false,
            },
            {
                setting_id = ids.color_g,
                type = "numeric",
                title = color_g_title,
                default_value = defaults.color_g,
                range = { 0, 255 },
                decimals_number = 0,
                localize = false,
            },
            {
                setting_id = ids.color_b,
                type = "numeric",
                title = color_b_title,
                default_value = defaults.color_b,
                range = { 0, 255 },
                decimals_number = 0,
                localize = false,
            },
        },
    }
end

local ordered_entries = config.get_ordered_breed_entries()
for i = 1, #ordered_entries do
    local entry = ordered_entries[i]
    add_breed_group_widget(entry.breed_name, entry.display_name, entry.category, entry.defaults)
end

local unknown_defaults = config.get_unknown_defaults()
add_breed_group_widget(config.UNKNOWN_BREED_KEY, unknown_units_title, "unknown", unknown_defaults)

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    localize = false,
    options = {
        widgets = widgets,
    },
}
