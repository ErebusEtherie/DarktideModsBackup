local mod = get_mod("better_downed_indicators")
local green_super_light = Color.ui_hud_green_super_light(255, true)
local red_light = Color.ui_hud_red_light(255, true)
local orange_light = Color.ui_orange_light(255, true)

local widgets = {
    {
        setting_id = "icon_style",
        type = "dropdown",
        default_value = "glowing",
        options = {
            { text = "icon_style_option_glowing", value = "glowing" },
            { text = "icon_style_option_plain_white", value = "plain_white" },
            { text = "icon_style_option_plain_yellow", value = "plain_yellow" },
            { text = "icon_style_option_plain_red", value = "plain_red" },
            { text = "icon_style_option_plain_slot_color", value = "plain_slot_color" },
        },
    },
    {
        setting_id = "enable_background_tint",
        type = "checkbox",
        default_value = true,
    },
    {
        setting_id = "plain_icon_customization_mode",
        type = "dropdown",
        default_value = "off",
        options = {
            { text = "plain_icon_customization_mode_off", value = "off" },
            { text = "plain_icon_customization_mode_customize_all", value = "customize_all" },
            { text = "plain_icon_customization_mode_customize_plain_only", value = "customize_plain_only" },
        },
    },
}

-- Add color settings for each status type with groups
local statuses = {
    -- Death/Respawn states
    { "dead", green_super_light },
    { "respawning", green_super_light },
    -- Downed/Disabled states
    { "knocked_down", red_light },
    { "hogtied", green_super_light },
    { "ledge_hanging", red_light },
    -- Enemy grab/attack states
    { "pounced", red_light },
    { "netted", red_light },
    { "warp_grabbed", red_light },
    { "consumed", orange_light },
    { "grabbed", orange_light },
    { "mutant_charged", orange_light },
    -- Active/Positive states
    { "auspex", green_super_light },
    { "luggable", green_super_light },
    { "healing", green_super_light },
    { "helping", green_super_light },
    { "interacting", green_super_light },
}

for _, status_data in ipairs(statuses) do
    local status_name = status_data[1]
    local default_color = status_data[2]
    
    -- Create group with sub_widgets for RGB settings
    table.insert(widgets, {
        setting_id = status_name .. "_header",
        type = "group",
        sub_widgets = {
            {
                setting_id = status_name .. "_r",
                type = "numeric",
                range = { 0, 255 },
                default_value = default_color[2],
            },
            {
                setting_id = status_name .. "_g",
                type = "numeric",
                range = { 0, 255 },
                default_value = default_color[3],
            },
            {
                setting_id = status_name .. "_b",
                type = "numeric",
                range = { 0, 255 },
                default_value = default_color[4],
            },
        },
    })
end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets,
    },
}
