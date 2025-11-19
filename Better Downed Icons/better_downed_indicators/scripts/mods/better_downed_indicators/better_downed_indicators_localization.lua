local loc = {}

loc.mod_name = {
    en = "Better Downed Indicators",
}
loc.mod_description = {
    en = "Replaces the generic exclamation point icon on teammate and personal HUD panels with specific icons that show what took them down (pounced by dog, netted by trapper, etc.), making it clearer how to respond.",
}
loc.icon_style = {
    en = "Icon Style",
}
loc.icon_style_option_glowing = {
    en = "Glowing",
}
loc.icon_style_option_plain_white = {
    en = "Plain (White)",
}
loc.icon_style_option_plain_yellow = {
    en = "Plain (Yellow)",
}
loc.icon_style_option_plain_red = {
    en = "Plain (Red)",
}
loc.icon_style_option_plain_slot_color = {
    en = "Plain (Teammate Color)",
}
loc.plain_icon_customization_mode = {
    en = "Plain Icon Customization Mode",
}
loc.plain_icon_customization_mode_off = {
    en = "Off (Use Style Setting)",
}
loc.plain_icon_customization_mode_customize_all = {
    en = "Customize All Icons (No Glowly)",
}
loc.plain_icon_customization_mode_customize_plain_only = {
    en = "Only Customize Plain Icons (Keep Glowly)",
}
loc.enable_background_tint = {
    en = "Enable Background Tint",
}

-- Add color settings for each status type
-- Icons WITHOUT distinct plain versions (same path for both) get "(glowy customizable)" label
local statuses = {
    -- Death/Respawn states
    { "dead", "Dead (glowy customizable)" },
    { "respawning", "Respawning (glowy customizable)" },
    -- Downed/Disabled states
    { "knocked_down", "Knocked-down" },
    { "hogtied", "Hogtied" },
    { "ledge_hanging", "Hanging" },
    -- Enemy grab/attack states
    { "pounced", "Pounced" },
    { "netted", "Netted" },
    { "warp_grabbed", "Warp-grabbed (glowy customizable)" },
    { "consumed", "Consumed" },
    { "grabbed", "Grabbed" },
    { "mutant_charged", "Mutant-charged" },
    -- Active/Positive states
    { "auspex", "Auspex (glowy customizable)" },
    { "luggable", "Luggable (glowy customizable)" },
    { "healing", "Healing (glowy customizable)" },
    { "helping", "Helping (glowy customizable)" },
    { "interacting", "Interacting (glowy customizable)" },
}

for _, v in ipairs(statuses) do
    -- Header title
    loc[v[1] .. "_header"] = { en = v[2] }
    -- RGB settings (just the color name since header already shows the status)
    loc[v[1] .. "_r"] = { en = "Red" }
    loc[v[1] .. "_g"] = { en = "Green" }
    loc[v[1] .. "_b"] = { en = "Blue" }
end

return loc
