local mod            = get_mod("AutoMark")
local Breed          = require("scripts/utilities/breed")
local Breeds         = require("scripts/settings/breed/breeds")
local Archetypes     = require("scripts/settings/archetype/archetypes")

local elite_widget   = {
    setting_id    = "toggle_elite",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local special_widget = {
    setting_id    = "toggle_special",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local boss_widget    = {
    setting_id    = "toggle_boss",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local other_widget   = {
    setting_id    = "toggle_other",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local function create_breed_priority_dropdown(breed_name, default_value)
    local breed_priority_setting = {
        setting_id    = breed_name,
        type          = "numeric",
        default_value = breed_name == "chaos_poxwalker_bomber" and 0 or default_value,
        range         = { 0, 30 },
        tooltip       = "tooltip_breed_priority",
    }
    return breed_priority_setting
end

local elite_priority_dropdown   = {}
local special_priority_dropdown = {}
local boss_priority_dropdown    = {}
local other_priority_dropdown   = {}

for breed_name, breed_data in pairs(Breeds) do
    if Breed.is_minion(breed_data) and breed_data.unit_template_name == "minion" and breed_data.smart_tag_target_type == "breed" and breed_data.faction_name ~= "imperium" then
        if breed_data.tags.elite then
            elite_priority_dropdown[#elite_priority_dropdown + 1] = create_breed_priority_dropdown(breed_name, 0)
        elseif breed_data.tags.special then
            special_priority_dropdown[#special_priority_dropdown + 1] = create_breed_priority_dropdown(breed_name, 1)
        elseif breed_data.is_boss then
            boss_priority_dropdown[#boss_priority_dropdown + 1] = create_breed_priority_dropdown(breed_name, 1)
            if breed_data.tags.witch then
                boss_priority_dropdown[#boss_priority_dropdown + 1] = create_breed_priority_dropdown(breed_name .. "_passive", 1)
            end
        else
            other_priority_dropdown[#other_priority_dropdown + 1] = create_breed_priority_dropdown(breed_name, 1)
        end
    end
end

local get_breed_sort = function(breed_name)
    return mod:localize(breed_name)
end

local compare_breed_name = function(a, b)
    return get_breed_sort(a.setting_id) < get_breed_sort(b.setting_id)
end

table.sort(elite_priority_dropdown, compare_breed_name)
table.sort(special_priority_dropdown, compare_breed_name)
table.sort(boss_priority_dropdown, compare_breed_name)
table.sort(other_priority_dropdown, compare_breed_name)

elite_widget.sub_widgets = elite_priority_dropdown
special_widget.sub_widgets = special_priority_dropdown
boss_widget.sub_widgets = boss_priority_dropdown
other_widget.sub_widgets = other_priority_dropdown

local class_options = {
    { text = "adamant_companion",    value = "adamant_companion" },
    { text = "veteran_focus_target", value = "veteran_focus_target" },
    { text = "cryptic_servo_skull",  value = "cryptic_servo_skull" },
}

for class_name, _ in pairs(Archetypes) do
    class_options[#class_options + 1] = { text = class_name, value = class_name }
end

table.sort(class_options, function(a, b) return a.text < b.text end)

local breed_name_options = {}
local elite_breed_names = {}
local special_breed_names = {}
local boss_breed_names = {}
local captain_breed_names = {}
local other_breed_names = {}
for breed_name, breed_data in pairs(Breeds) do
    if Breed.is_minion(breed_data) and breed_data.unit_template_name == "minion" and breed_data.smart_tag_target_type == "breed" and breed_data.faction_name ~= "imperium" then
        if breed_data.tags.elite then
            elite_breed_names[#elite_breed_names + 1] = breed_name
        elseif breed_data.tags.special then
            special_breed_names[#special_breed_names + 1] = breed_name
        elseif breed_data.is_boss then
            if breed_data.tags.captain or breed_data.tags.cultist_captain then
                captain_breed_names[#captain_breed_names + 1] = breed_name
            else
                boss_breed_names[#boss_breed_names + 1] = breed_name
            end
        else
            other_breed_names[#other_breed_names + 1] = breed_name
        end
    end
end
table.sort(elite_breed_names, function(a, b) return get_breed_sort(a) < get_breed_sort(b) end)
table.sort(special_breed_names, function(a, b) return get_breed_sort(a) < get_breed_sort(b) end)
table.sort(boss_breed_names, function(a, b) return get_breed_sort(a) < get_breed_sort(b) end)
table.sort(captain_breed_names, function(a, b) return get_breed_sort(a) < get_breed_sort(b) end)
table.sort(other_breed_names, function(a, b) return get_breed_sort(a) < get_breed_sort(b) end)

for _, breed_name in ipairs(elite_breed_names) do
    breed_name_options[#breed_name_options + 1] = { text = breed_name, value = breed_name }
end
for _, breed_name in ipairs(special_breed_names) do
    breed_name_options[#breed_name_options + 1] = { text = breed_name, value = breed_name }
end
for _, breed_name in ipairs(boss_breed_names) do
    breed_name_options[#breed_name_options + 1] = { text = breed_name, value = breed_name }
end
for _, breed_name in ipairs(captain_breed_names) do
    breed_name_options[#breed_name_options + 1] = { text = breed_name, value = breed_name }
end
for _, breed_name in ipairs(other_breed_names) do
    breed_name_options[#breed_name_options + 1] = { text = breed_name, value = breed_name }
end

-- Manual settings
local widgets = {
    {
        setting_id = "mod_settings",
        type = "group",
        sub_widgets = {
            {
                setting_id    = "toggle_mod",
                type          = "checkbox",
                default_value = true,
            },
            {
                setting_id      = "toggle_mod_keybind",
                type            = "keybind",
                default_value   = {},
                keybind_global  = false,
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "toggle_mod",
            },
            {
                setting_id    = "toggle_mod_notify",
                type          = "checkbox",
                default_value = true,
            },
            {
                setting_id    = "debug_mode",
                type          = "checkbox",
                default_value = false
            },
        }
    },
    {
        setting_id = "adamant_settings",
        type = "group",
        sub_widgets = {
            {
                setting_id      = "companion_mark_keybind",
                type            = "keybind",
                default_value   = {},
                keybind_global  = false,
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "companion_mark",
            },
            {
                setting_id    = "companion_mark_ignore_unaggroed",
                title         = "ignore_unaggroed",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id      = "companion_range_limitation",
                type            = "numeric",
                title           = "companion_range_limitation",
                tooltip         = "companion_range_limitation_tooltip",
                default_value   = 0,
                range           = { 0, 100 },
                unit_text       = "meter",
                decimals_number = 0
            },
            {
                setting_id      = "companion_mark_max_distance",
                type            = "numeric",
                title           = "companion_mark_max_distance",
                tooltip         = "companion_mark_max_distance_tooltip",
                default_value   = 0,
                range           = { 0, 100 },
                unit_text       = "meter",
                decimals_number = 0
            },
            {
                setting_id    = "companion_mark_tagged_always_visible",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id    = "companion_mark_threat_priority",
                title         = "threat_priority",
                tooltip       = "threat_priority_tooltip",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id    = "execution_order_priority",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id    = "execution_order_force_mark",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id    = "companion_mark_sticky_targeting",
                type          = "checkbox",
                title         = "sticky_targeting",
                tooltip       = "sticky_targeting_tooltip",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "companion_mark_sticky_targeting_elite",
                        type          = "checkbox",
                        title         = "elite",
                        tooltip       = "elite_tooltip",
                        default_value = false,
                    },
                    {
                        setting_id    = "companion_mark_sticky_targeting_special",
                        type          = "checkbox",
                        title         = "special",
                        tooltip       = "special_tooltip",
                        default_value = false,
                    },
                    {
                        setting_id    = "companion_mark_sticky_targeting_boss",
                        type          = "checkbox",
                        title         = "boss",
                        tooltip       = "boss_tooltip",
                        default_value = false,
                    },
                }
            },
            {
                setting_id    = "companion_cancel_mark",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "companion_cancel_mark_human",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "companion_cancel_mark_non_human",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id      = "companion_health_threshold",
                        type            = "numeric",
                        title           = "health_threshold",
                        tooltip         = "companion_health_threshold_tooltip",
                        default_value   = 0,
                        unit_text       = "percent",
                        range           = { 0, 100 },
                        decimals_number = 0
                    },
                    {
                        setting_id      = "companion_time_threshold",
                        type            = "numeric",
                        title           = "time_threshold",
                        tooltip         = "companion_time_threshold_tooltip",
                        default_value   = 0,
                        unit_text       = "second",
                        range           = { 0, 25 },
                        decimals_number = 1
                    },
                    {
                        setting_id      = "companion_distance_threshold",
                        type            = "numeric",
                        title           = "distance_threshold",
                        tooltip         = "companion_distance_threshold_tooltip",
                        default_value   = 0,
                        unit_text       = "meter",
                        range           = { 0, 100 },
                        decimals_number = 0
                    },
                }
            },
            {
                setting_id    = "companion_cancel_mark_breed_name",
                type          = "dropdown",
                title         = "enemy_settings",
                tooltip       = "enemy_settings_tooltip",
                default_value = breed_name_options[1].value,
                options       = table.clone(breed_name_options),
                sub_widgets   = {
                    {
                        setting_id           = "reset_all_cyber_mastiff_breed_settings",
                        type                 = "button",
                        title                = "enemy_settings_reset",
                        tooltip              = "enemy_settings_reset_tooltip",
                        button_text          = "hold_to_reset",
                        button_trigger       = "held",
                        button_hold_duration = 1.5,
                        function_name        = "reset_all_cyber_mastiff_breed_settings",
                    },
                    {
                        setting_id    = "companion_cancel_mark_breed_override",
                        type          = "checkbox",
                        title         = "enemy_settings_override",
                        tooltip       = "enemy_settings_override_tooltip",
                        default_value = false,
                        sub_widgets   = {
                            {
                                setting_id      = "companion_range_limitation_breed",
                                type            = "numeric",
                                title           = "companion_range_limitation",
                                tooltip         = "companion_range_limitation_tooltip",
                                default_value   = 0,
                                range           = { 0, 100 },
                                unit_text       = "meter",
                                decimals_number = 0
                            },
                            {
                                setting_id      = "companion_mark_max_distance_breed",
                                type            = "numeric",
                                title           = "companion_mark_max_distance",
                                tooltip         = "companion_mark_max_distance_tooltip",
                                default_value   = 0,
                                range           = { 0, 100 },
                                unit_text       = "meter",
                                decimals_number = 0
                            },
                            {
                                setting_id    = "companion_mark_sticky_targeting_breed",
                                type          = "checkbox",
                                title         = "sticky_targeting",
                                tooltip       = "sticky_targeting_tooltip",
                                default_value = false,
                            },
                            {
                                setting_id      = "companion_cancel_mark_breed_health_threshold",
                                type            = "numeric",
                                title           = "health_threshold",
                                tooltip         = "companion_health_threshold_tooltip",
                                default_value   = 0,
                                range           = { 0, 100 },
                                unit_text       = "percent",
                                decimals_number = 0
                            },
                            {
                                setting_id      = "companion_cancel_mark_breed_time_threshold",
                                type            = "numeric",
                                title           = "time_threshold",
                                tooltip         = "companion_time_threshold_tooltip",
                                default_value   = 0,
                                range           = { 0, 25 },
                                unit_text       = "second",
                                decimals_number = 1
                            },
                            {
                                setting_id      = "companion_cancel_mark_breed_distance_threshold",
                                type            = "numeric",
                                title           = "distance_threshold",
                                tooltip         = "companion_distance_threshold_tooltip",
                                default_value   = 0,
                                range           = { 0, 100 },
                                unit_text       = "meter",
                                decimals_number = 0
                            },
                        }
                    },
                }
            },
        }
    },
    {
        setting_id = "cryptic_settings",
        type = "group",
        sub_widgets = {
            {
                setting_id      = "servo_skull_mark_keybind",
                type            = "keybind",
                default_value   = {},
                keybind_global  = false,
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "servo_skull_mark",
            },
            {
                setting_id    = "servo_skull_mark_ignore_unaggroed",
                type          = "checkbox",
                title         = "ignore_unaggroed",
                default_value = false,
            },
            {
                setting_id      = "servo_skull_range_limitation",
                type            = "numeric",
                title           = "companion_range_limitation",
                tooltip         = "companion_range_limitation_tooltip",
                default_value   = 0,
                range           = { 0, 100 },
                unit_text       = "meter",
                decimals_number = 0
            },
            {
                setting_id    = "servo_skull_mark_threat_priority",
                type          = "checkbox",
                title         = "threat_priority",
                tooltip       = "threat_priority_tooltip",
                default_value = false,
            },
            {
                setting_id      = "hack_mark_keybind",
                type            = "keybind",
                default_value   = {},
                keybind_global  = false,
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "hack_mark",
            },
            {
                setting_id    = "auto_hack",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "disable_auto_hack_for_noospheric_command",
                        type          = "checkbox",
                        default_value = false,
                    },
                }
            },
            {
                setting_id    = "noospheric_command_boost",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "noospheric_command_boost_elite",
                        type          = "checkbox",
                        title         = "elite",
                        default_value = false,
                    },
                    {
                        setting_id    = "noospheric_command_boost_special",
                        type          = "checkbox",
                        title         = "special",
                        default_value = false,
                    },
                    {
                        setting_id    = "noospheric_command_boost_boss",
                        type          = "checkbox",
                        title         = "boss",
                        default_value = false,
                    },
                }
            },
            {
                setting_id    = "capacitance_retention",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id      = "capacitance_retention_elite_threshold",
                        type            = "numeric",
                        title           = "elite",
                        default_value   = 0,
                        range           = { -1000, 1000 },
                        unit_text       = "percent",
                        decimals_number = 0,
                    },
                    {
                        setting_id      = "capacitance_retention_special_threshold",
                        type            = "numeric",
                        title           = "special",
                        default_value   = 0,
                        range           = { -1000, 1000 },
                        unit_text       = "percent",
                        decimals_number = 0,
                    },
                    {
                        setting_id      = "capacitance_retention_boss_threshold",
                        type            = "numeric",
                        title           = "boss",
                        default_value   = 0,
                        range           = { -1000, 1000 },
                        unit_text       = "percent",
                        decimals_number = 0,
                    },
                }
            },
            {
                setting_id    = "servo_skull_mark_sticky_targeting",
                type          = "checkbox",
                title         = "sticky_targeting",
                tooltip       = "sticky_targeting_tooltip",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "servo_skull_mark_sticky_targeting_elite",
                        type          = "checkbox",
                        title         = "elite",
                        tooltip       = "elite_tooltip",
                        default_value = false,
                    },
                    {
                        setting_id    = "servo_skull_mark_sticky_targeting_special",
                        type          = "checkbox",
                        title         = "special",
                        tooltip       = "special_tooltip",
                        default_value = false,
                    },
                    {
                        setting_id    = "servo_skull_mark_sticky_targeting_boss",
                        type          = "checkbox",
                        title         = "boss",
                        tooltip       = "boss_tooltip",
                        default_value = false,
                    },
                }
            },
            {
                setting_id    = "servo_skull_cancel_mark",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id      = "servo_skull_cancel_mark_time_threshold",
                        type            = "numeric",
                        title           = "servo_skull_lose_sight_tolerance",
                        tooltip         = "servo_skull_lose_sight_tolerance_tooltip",
                        default_value   = 0,
                        range           = { 0, 25 },
                        unit_text       = "second",
                        decimals_number = 1
                    },
                    {
                        setting_id      = "servo_skull_cancel_mark_health_threshold",
                        type            = "numeric",
                        title           = "health_threshold",
                        tooltip         = "servo_skull_health_threshold_tooltip",
                        default_value   = 0,
                        range           = { 0, 100 },
                        unit_text       = "percent",
                        decimals_number = 0
                    },
                }
            },
            {
                setting_id    = "noospheric_command_boost_breed_name",
                type          = "dropdown",
                title         = "enemy_settings",
                tooltip       = "enemy_settings_tooltip",
                default_value = breed_name_options[1].value,
                options       = table.clone(breed_name_options),
                sub_widgets   = {
                    {
                        setting_id           = "reset_all_servo_skull_breed_settings",
                        type                 = "button",
                        title                = "enemy_settings_reset",
                        tooltip              = "enemy_settings_reset_tooltip",
                        button_text          = "hold_to_reset",
                        button_trigger       = "held",
                        button_hold_duration = 1.5,
                        function_name        = "reset_all_servo_skull_breed_settings",
                    },
                    {
                        setting_id    = "noospheric_command_boost_breed_override",
                        type          = "checkbox",
                        title         = "enemy_settings_override",
                        tooltip       = "enemy_settings_override_tooltip",
                        default_value = false,
                        sub_widgets   = {
                            {
                                setting_id      = "servo_skull_range_limitation_breed",
                                type            = "numeric",
                                title           = "companion_range_limitation",
                                tooltip         = "companion_range_limitation_tooltip",
                                default_value   = 0,
                                range           = { 0, 100 },
                                unit_text       = "meter",
                                decimals_number = 0
                            },
                            {
                                setting_id    = "noospheric_command_boost_breed_toggle",
                                type          = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id      = "capacitance_retention_breed_threshold",
                                type            = "numeric",
                                default_value   = 0,
                                range           = { -1000, 1000 },
                                unit_text       = "percent",
                                decimals_number = 0,
                            },
                            {
                                setting_id    = "servo_skull_mark_sticky_targeting_breed",
                                type          = "checkbox",
                                title         = "sticky_targeting",
                                tooltip       = "sticky_targeting_tooltip",
                                default_value = false,
                            },
                            {
                                setting_id      = "servo_skull_cancel_mark_breed_time_threshold",
                                type            = "numeric",
                                title           = "servo_skull_lose_sight_tolerance",
                                tooltip         = "servo_skull_lose_sight_tolerance_tooltip",
                                default_value   = 0,
                                range           = { 0, 25 },
                                unit_text       = "second",
                                decimals_number = 1
                            },
                            {
                                setting_id      = "servo_skull_cancel_mark_breed_health_threshold",
                                type            = "numeric",
                                title           = "health_threshold",
                                tooltip         = "servo_skull_health_threshold_tooltip",
                                default_value   = 0,
                                range           = { 0, 100 },
                                unit_text       = "percent",
                                decimals_number = 0
                            },
                        }
                    },
                }
            },
        }
    },
    {
        setting_id  = "veteran_settings",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "focus_target_ignore_unaggroed",
                type          = "checkbox",
                title         = "ignore_unaggroed",
                default_value = false,
            },
            {
                setting_id    = "focus_target_overwrite",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "focus_target_overwrite_delta",
                        type          = "numeric",
                        default_value = 5,
                        range         = { 1, 10 },
                        unit_text     = "stack",
                    },
                }
            },
            {
                setting_id    = "focus_target_switch",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "focus_target_switch_override_manual",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "focus_target_switch_melee",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "focus_target_switch_range",
                        type          = "checkbox",
                        default_value = false,
                    },
                }
            }
        }
    },
    {
        setting_id  = "auto_mark_settings",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "class_selection",
                type          = "dropdown",
                default_value = "adamant",
                options       = class_options,
            },
            {
                setting_id    = "apply_button",
                type          = "dropdown",
                default_value = "blank",
                options       = {
                    { text = "apply_to_normal", value = "apply_to_normal" },
                    { text = "apply_to_all",    value = "apply_to_all" },
                    { text = "blank",           value = "blank" },
                }
            },
            {
                setting_id    = "reset_button",
                type          = "dropdown",
                default_value = "blank",
                options       = {
                    { text = "reset_current", value = "reset_current" },
                    { text = "reset_all",     value = "reset_all" },
                    { text = "blank",         value = "blank" },
                }
            },
            {
                setting_id    = "toggle_class",
                type          = "checkbox",
                default_value = true,
            },
            {
                setting_id      = "interval",
                type            = "numeric",
                default_value   = 1,
                range           = { 0, 50 },
                unit_text       = "second",
                decimals_number = 1
            },
            {
                setting_id      = "cooldown",
                type            = "numeric",
                default_value   = 25,
                range           = { 10, 50 },
                unit_text       = "second",
                decimals_number = 1
            },
            {
                setting_id = "reset_cooldown",
                type = "checkbox",
                default_value = true
            },
            {
                setting_id = "mark_limit",
                type = "checkbox",
                default_value = true
            },
            {
                setting_id      = "min_range",
                type            = "numeric",
                default_value   = 0,
                range           = { 0, 100 },
                unit_text       = "meter",
                decimals_number = 0
            },
            {
                setting_id      = "max_range",
                type            = "numeric",
                default_value   = 100,
                range           = { 1, 100 },
                unit_text       = "meter",
                decimals_number = 0
            },
            {
                setting_id      = "max_angle",
                type            = "numeric",
                default_value   = 0,
                range           = { 0, 180 },
                unit_text       = "degree",
                decimals_number = 0
            },
            {
                setting_id = "override_manual",
                type = "checkbox",
                default_value = false
            },
            {
                setting_id = "priority_switch",
                type = "checkbox",
                default_value = false
            },
            elite_widget,
            special_widget,
            boss_widget,
            other_widget,
        }
    },
}

return {
    name         = mod:localize("mod_name"),
    description  = mod:localize("mod_description"),
    is_togglable = true,
    options      = {
        widgets = widgets
    }
}
