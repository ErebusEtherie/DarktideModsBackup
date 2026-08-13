local mod = get_mod("thank_you")

-- Order here is the order shown in every line dropdown. "off" first so silencing
-- a single trigger without disabling it is the easiest thing to reach.
local LINE_VALUES = {
    "off",
    "thank_you",
    "thank_you_delayed",
    "my_pleasure",
    "for_the_emperor",
    "yes",
    "no",
    "need_health",
    "need_ammo",
    "need_that",
    "take_this",
    "following",
    "over_here",
    "this_way",
    "enemy_there",
}

-- DMF keeps a reference to whatever options table it is handed, so each dropdown
-- gets its own copy.
local function line_options()
    local options = {}

    for i = 1, #LINE_VALUES do
        local value = LINE_VALUES[i]

        options[i] = {
            text = "line_" .. value,
            value = value,
        }
    end

    return options
end

local TRIGGERS = {
    { id = "revived",       default_line = "thank_you_delayed", default_enabled = true },
    { id = "rescued",       default_line = "thank_you_delayed", default_enabled = true },
    { id = "ledge_saved",   default_line = "thank_you_delayed", default_enabled = true },
    -- Replying when actually thanked reads better than announcing "my pleasure"
    -- unprompted, so that is the one that ships on.
    { id = "assisted_ally", default_line = "my_pleasure", default_enabled = false },
    { id = "thanked",       default_line = "my_pleasure", default_enabled = true },
    -- NOT "over_here": that line's dialogue rule shares its 5-second memory key
    -- with Thanks, so a distress call on Over Here silently blocks the thank-you
    -- for the rescue that follows. These two lines use their own keys and leave
    -- the thank-you free to fire the moment you are back on your feet.
    { id = "went_down",     default_line = "need_health", default_enabled = true },
    { id = "disabled",      default_line = "enemy_there", default_enabled = true },
    { id = "low_health",    default_line = "need_health", default_enabled = false },
    { id = "out_of_ammo",   default_line = "need_ammo",   default_enabled = false },
}

local widgets = {
    {
        setting_id = "delay",
        type = "numeric",
        default_value = 1.0,
        range = { 0, 3 },
        decimals_number = 1,
    },
    {
        setting_id = "cooldown",
        type = "numeric",
        default_value = 8,
        range = { 3, 30 },
    },
    {
        setting_id = "send_chat",
        type = "checkbox",
        default_value = false,
    },
    {
        setting_id = "debug_echo",
        type = "checkbox",
        default_value = false,
    },
    {
        setting_id = "file_log",
        type = "checkbox",
        default_value = true,
    },
    {
        setting_id = "test_group",
        type = "group",
        sub_widgets = {
            {
                setting_id = "test_line",
                type = "dropdown",
                default_value = "thank_you",
                options = line_options(),
            },
            {
                setting_id = "test_key",
                type = "keybind",
                default_value = {},
                keybind_trigger = "pressed",
                keybind_type = "function_call",
                function_name = "test_callout",
            },
            {
                setting_id = "report_key",
                type = "keybind",
                default_value = {},
                keybind_trigger = "pressed",
                keybind_type = "function_call",
                function_name = "hook_report",
            },
        },
    },
}

for _, trigger in ipairs(TRIGGERS) do
    local sub_widgets = {
        {
            setting_id = trigger.id .. "_enabled",
            type = "checkbox",
            default_value = trigger.default_enabled,
        },
        {
            setting_id = trigger.id .. "_line",
            type = "dropdown",
            default_value = trigger.default_line,
            options = line_options(),
        },
    }

    if trigger.id == "low_health" then
        sub_widgets[#sub_widgets + 1] = {
            setting_id = "low_health_threshold",
            type = "numeric",
            default_value = 35,
            range = { 10, 75 },
            step_size_value = 5,
        }
    elseif trigger.id == "thanked" then
        sub_widgets[#sub_widgets + 1] = {
            setting_id = "thanked_scope",
            type = "dropdown",
            default_value = "helped",
            options = {
                { text = "thanked_scope_helped", value = "helped" },
                { text = "thanked_scope_anyone", value = "anyone" },
            },
        }
    end

    widgets[#widgets + 1] = {
        setting_id = trigger.id .. "_group",
        type = "group",
        sub_widgets = sub_widgets,
    }
end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets,
    },
}
