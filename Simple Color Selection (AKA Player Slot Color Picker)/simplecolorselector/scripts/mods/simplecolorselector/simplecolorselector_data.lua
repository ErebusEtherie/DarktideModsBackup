local mod = get_mod("simplecolorselector")

-- Build dropdown options from engine Color.list (deduplicate like True Level)
local color_options = {}

local function is_duplicated(color_array)
    local join = function(t)
        return string.format("%s,%s,%s", t[2], t[3], t[4])
    end
    
    for _, existing in ipairs(color_options) do
        local existing_color = Color[existing.value](255, true)
        if join(color_array) == join(existing_color) then
            return true
        end
    end
    return false
end

for _, name in ipairs(Color.list) do
    local color_array = Color[name](255, true)
    if not is_duplicated(color_array) then
        color_options[#color_options+1] = { text = name, value = name }
    end
end

table.sort(color_options, function(a,b) return a.text < b.text end)
table.insert(color_options, 1, { text = "default", value = "default" })

-- Default game slot colors (from Color.player_slot_N)
local default_slot_colors = {
    {r = 226, g = 210, b = 117}, -- Slot 1 yellow
    {r = 180, g = 88,  b = 108}, -- Slot 2 red
    {r = 84,  g = 172, b = 121}, -- Slot 3 green
    {r = 126, g = 153, b = 230}, -- Slot 4 blue
    {r = 128, g = 128, b = 128}, -- Bot gray
}

-- Helper to generate widgets for a player slot
local function slot_widgets(slot)
    local prefix = string.format("slot%d", slot)
    local defaults = default_slot_colors[slot]
    
    -- Clone color_options and replace "default" with slot-specific colored default
    local slot_color_options = table.clone(color_options)
    slot_color_options[1] = { text = "default_slot" .. slot, value = "default" }
    
    return {
        setting_id = prefix,
        type = "group",
        sub_widgets = {
            {
                setting_id = prefix .. "_preset",
                type = "dropdown",
                default_value = "default",
                options = slot_color_options,
            },
            {
                setting_id = prefix .. "_r",
                type = "numeric",
                default_value = defaults.r,
                range = {0,255},
            },
            {
                setting_id = prefix .. "_g",
                type = "numeric",
                default_value = defaults.g,
                range = {0,255},
            },
            {
                setting_id = prefix .. "_b",
                type = "numeric",
                default_value = defaults.b,
                range = {0,255},
            },
        }
    }
end

local widgets = {}
for slot=1,4 do
    widgets[#widgets+1] = slot_widgets(slot)
end

-- Bot color settings
local bot_color_options = table.clone(color_options)
bot_color_options[1] = { text = "default_bot", value = "default" }

widgets[#widgets+1] = {
    setting_id = "bot",
    type = "group",
    sub_widgets = {
        {
            setting_id = "bot_preset",
            type = "dropdown",
            default_value = "default",
            options = bot_color_options,
        },
        {
            setting_id = "bot_r",
            type = "numeric",
            default_value = 128,
            range = {0,255},
        },
        {
            setting_id = "bot_g",
            type = "numeric",
            default_value = 128,
            range = {0,255},
        },
        {
            setting_id = "bot_b",
            type = "numeric",
            default_value = 128,
            range = {0,255},
        },
    }
}

widgets[#widgets+1] = {
    setting_id = "debug_mode_group",
    type = "group",
    sub_widgets = {
        {
            setting_id = "enable_debug_mode",
            type = "checkbox",
            default_value = false,
        },
    },
}

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets
    }
}
