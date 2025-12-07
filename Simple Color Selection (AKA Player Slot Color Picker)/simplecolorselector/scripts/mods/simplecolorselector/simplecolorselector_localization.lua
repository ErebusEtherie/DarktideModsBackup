local loc = {
    mod_name = {
        en = "Simple Color Selector",
    },
    mod_description = {
        en = "Choose custom RGB or preset colours per player slot (mission only).",
    },
    
    slot1 = {
        en = "Slot 1 (Local Player)",
    },
    slot1_preset = {
        en = "Color Preset",
    },
    slot1_r = {
        en = "Red",
    },
    slot1_g = {
        en = "Green",
    },
    slot1_b = {
        en = "Blue",
    },
    
    slot2 = {
        en = "Slot 2",
    },
    slot2_preset = {
        en = "Color Preset",
    },
    slot2_r = {
        en = "Red",
    },
    slot2_g = {
        en = "Green",
    },
    slot2_b = {
        en = "Blue",
    },
    
    slot3 = {
        en = "Slot 3",
    },
    slot3_preset = {
        en = "Color Preset",
    },
    slot3_r = {
        en = "Red",
    },
    slot3_g = {
        en = "Green",
    },
    slot3_b = {
        en = "Blue",
    },
    
    slot4 = {
        en = "Slot 4",
    },
    slot4_preset = {
        en = "Color Preset",
    },
    slot4_r = {
        en = "Red",
    },
    slot4_g = {
        en = "Green",
    },
    slot4_b = {
        en = "Blue",
    },
    
    bot = {
        en = "Bot Color",
    },
    bot_preset = {
        en = "Color Preset",
    },
    bot_r = {
        en = "Red",
    },
    bot_g = {
        en = "Green",
    },
    bot_b = {
        en = "Blue",
    },
    
    debug_mode_group = {
        en = "Debug Mode",
    },
    enable_debug_mode = {
        en = "Enable Debug Logging",
    },
    
}

-- Add colored "Default" text for each slot's default color
local default_slot_colors = {
    {r = 226, g = 210, b = 117}, -- Slot 1 yellow
    {r = 180, g = 88,  b = 108}, -- Slot 2 red
    {r = 84,  g = 172, b = 121}, -- Slot 3 green
    {r = 126, g = 153, b = 230}, -- Slot 4 blue
    {r = 128, g = 128, b = 128}, -- Bot gray
}

for slot = 1, 4 do
    local c = default_slot_colors[slot]
    local text = string.format("{#color(%s,%s,%s)}Default{#reset()}", c.r, c.g, c.b)
    loc["default_slot" .. slot] = { en = text }
end

-- Bot default
local bot_c = default_slot_colors[5]
loc.default_bot = { en = string.format("{#color(%s,%s,%s)}Default{#reset()}", bot_c.r, bot_c.g, bot_c.b) }

-- Generic default (fallback)
loc.default = { en = "Default" }

-- Auto-generate localization for all color names from Color.list
-- Display each color name in its actual color (like True Level does)
for _, color_name in ipairs(Color.list) do
    local c = Color[color_name](255, true)
    local text = string.format("{#color(%s,%s,%s)}%s{#reset()}", c[2], c[3], c[4], string.gsub(color_name, "_", " "))
    loc[color_name] = { en = text }
end

return loc
