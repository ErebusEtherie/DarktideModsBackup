local mod = get_mod("better_downed_indicators")
local green_super_light = Color.ui_hud_green_super_light(255, true)
local red_light = Color.ui_hud_red_light(255, true)
local orange_light = Color.ui_orange_light(255, true)

local widgets = {
    {
        setting_id = "group_team_panels",
        type = "group",
        tab = mod:localize("tab_general"),
        sub_widgets = {
            {
                setting_id = "icon_style",
                type = "dropdown",
                default_value = "glowing",
                options = {
                    { text = "icon_style_option_glowing", value = "glowing" },
                    { text = "icon_style_option_plain", value = "plain" },
                    { text = "icon_style_option_plain_slot_color", value = "plain_slot_color" },
                },
            },
            {
                setting_id = "enable_background_tint",
                type = "checkbox",
                default_value = true,
            },
        },
    },
    {
        setting_id = "group_floating_markers",
        type = "group",
        tab = mod:localize("tab_general"),
        sub_widgets = {
            {
                setting_id = "enable_floating_markers",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "floating_icon_style",
                type = "dropdown",
                default_value = "glowing",
                options = {
                    { text = "icon_style_option_glowing", value = "glowing" },
                    { text = "icon_style_option_plain", value = "plain" },
                    { text = "icon_style_option_plain_slot_color", value = "plain_slot_color" },
                },
            },
            {
                setting_id = "floating_icon_size",
                type = "numeric",
                default_value = 65,
                range = { 30, 100 },
            },
        },
    },
}

local statuses_distinct = {
    { "knocked_down", red_light },
    { "ledge_hanging", red_light },
    { "pounced", red_light },
    { "netted", red_light },
    { "consumed", orange_light },
    { "grabbed", orange_light },
    { "mutant_charged", orange_light },
    { "hogtied", green_super_light },
    { "dead", green_super_light },
    { "respawning", green_super_light },
}

local statuses_plain_only = {
    { "warp_grabbed", red_light },
    { "auspex", green_super_light },
    { "luggable", green_super_light },
    { "healing", green_super_light },
    { "helping", green_super_light },
    { "interacting", green_super_light },
}

local function build_status_widgets(status_list)
    local w = {}
    for _, status_data in ipairs(status_list) do
        local status_name = status_data[1]
        local default_color = status_data[2]

        table.insert(w, {
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
    return w
end

table.insert(widgets, {
    setting_id = "group_status_colors",
    type = "group",
    tab = mod:localize("tab_status_colors"),
    sub_widgets = {
        {
            setting_id = "group_distinct_colors",
            type = "group",
            sub_widgets = build_status_widgets(statuses_distinct),
        },
        {
            setting_id = "group_plain_only_colors",
            type = "group",
            sub_widgets = build_status_widgets(statuses_plain_only),
        }
    }
})

table.insert(widgets, {
    setting_id = "aggro_header",
    type = "group",
    tab = mod:localize("tab_aggro"),
    sub_widgets = {
        {
            setting_id = "aggro_pox_burster_enabled",
            type = "checkbox",
            default_value = true,
        },
        {
            setting_id = "aggro_disabler_enabled",
            type = "checkbox",
            default_value = true,
        },
        {
            setting_id = "aggro_sniper_enabled",
            type = "checkbox",
            default_value = false,
        },
        {
            setting_id = "aggro_captain_enabled",
            type = "checkbox",
            default_value = false,
        },
        {
            setting_id = "aggro_monstrosity_enabled",
            type = "checkbox",
            default_value = false,
        },
        {
            setting_id = "aggro_daemonhost_enabled",
            type = "checkbox",
            default_value = false,
        },
        {
            setting_id = "aggro_grenadier_enabled",
            type = "checkbox",
            default_value = false,
        },
        {
            setting_id = "aggro_crusher_enabled",
            type = "checkbox",
            default_value = false,
        },
        {
            setting_id = "aggro_flamer_enabled",
            type = "checkbox",
            default_value = false,
        },
        {
            setting_id = "aggro_rager_enabled",
            type = "checkbox",
            default_value = false,
        },
    },
})

local aggro_types = {
    { "aggro_pox_burster", { 255, 255, 0 } },
    { "aggro_disabler", { 77, 0, 255 } },
    { "aggro_sniper", { 0, 255, 255 } },
    { "aggro_captain", { 255, 96, 0 } },
    { "aggro_monstrosity", { 255, 0, 0 } },
    { "aggro_daemonhost", { 0, 255, 0 } },
    { "aggro_grenadier", { 34, 100, 34 } },
    { "aggro_crusher", { 0, 0, 255 } },
    { "aggro_flamer", { 86, 10, 40 } },
    { "aggro_rager", { 255, 43, 96 } },
}

local aggro_color_widgets = {}

for _, aggro_data in ipairs(aggro_types) do
    local aggro_name = aggro_data[1]
    local default_color = aggro_data[2]

    table.insert(aggro_color_widgets, {
        setting_id = aggro_name .. "_header",
        type = "group",
        sub_widgets = {
            {
                setting_id = aggro_name .. "_r",
                type = "numeric",
                range = { 0, 255 },
                default_value = default_color[1],
            },
            {
                setting_id = aggro_name .. "_g",
                type = "numeric",
                range = { 0, 255 },
                default_value = default_color[2],
            },
            {
                setting_id = aggro_name .. "_b",
                type = "numeric",
                range = { 0, 255 },
                default_value = default_color[3],
            },
        },
    })
end

table.insert(widgets, {
    setting_id = "group_aggro_colors",
    type = "group",
    tab = mod:localize("tab_aggro"),
    sub_widgets = aggro_color_widgets,
})

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets,
    },
}
