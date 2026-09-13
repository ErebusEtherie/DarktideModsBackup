local mod = get_mod("better_downed_indicators")
local green_super_light = Color.ui_hud_green_super_light(255, true)
local red_light = Color.ui_hud_red_light(255, true)
local orange_light = Color.ui_orange_light(255, true)

local widgets = {
    {
        setting_id = "group_panel_styling",
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
        setting_id = "group_personal_panel",
        type = "group",
        tab = mod:localize("tab_general"),
        sub_widgets = {
            {
                setting_id = "enable_personal_panel_indicators",
                type = "checkbox",
                default_value = true,
                sub_widgets = {
                    {
                        setting_id = "personal_panel_offset_x",
                        type = "numeric",
                        default_value = 0,
                        range = { -300, 300 },
                        decimals_number = 0,
                        step_size_value = 1,
                    },
                    {
                        setting_id = "personal_panel_offset_y",
                        type = "numeric",
                        default_value = 0,
                        range = { -300, 300 },
                        decimals_number = 0,
                        step_size_value = 1,
                    },
                },
            },
        },
    },
    {
        setting_id = "group_team_panels",
        type = "group",
        tab = mod:localize("tab_general"),
        sub_widgets = {
            {
                setting_id = "enable_team_panel_indicators",
                type = "checkbox",
                default_value = true,
                sub_widgets = {
                    {
                        setting_id = "team_panel_offset_x",
                        type = "numeric",
                        default_value = 0,
                        range = { -300, 300 },
                        decimals_number = 0,
                        step_size_value = 1,
                    },
                    {
                        setting_id = "team_panel_offset_y",
                        type = "numeric",
                        default_value = 0,
                        range = { -300, 300 },
                        decimals_number = 0,
                        step_size_value = 1,
                    },
                },
            },
        },
    },
    {
        setting_id = "group_floating_markers",
        type = "group",
        tab = mod:localize("tab_world_markers"),
        sub_widgets = {
            {
                setting_id = "enable_floating_markers",
                type = "checkbox",
                default_value = true,
                sub_widgets = {
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
                        decimals_number = 0,
                        step_size_value = 1,
                    },
                },
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
            setting_id = status_name .. "_color",
            type = "color",
            default_value = default_color,
            title = status_name .. "_header",
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
    setting_id = "aggro_panel_display_group",
    type = "group",
    tab = mod:localize("tab_aggro"),
    sub_widgets = {
        {
            setting_id = "aggro_enable_on_self",
            type = "checkbox",
            default_value = true,
        },
        {
            setting_id = "aggro_enable_on_teammates",
            type = "checkbox",
            default_value = true,
        },
    },
})

local aggro_types = {
    { "aggro_pox_burster", true, { 255, 255, 255, 0 } },
    { "aggro_disabler", true, { 255, 77, 0, 255 } },
    { "aggro_sniper", false, { 255, 0, 255, 255 } },
    { "aggro_captain", false, { 255, 255, 96, 0 } },
    { "aggro_monstrosity", false, { 255, 255, 0, 0 } },
    { "aggro_daemonhost", false, { 255, 0, 255, 0 } },
    { "aggro_grenadier", false, { 255, 34, 100, 34 } },
    { "aggro_crusher", false, { 255, 0, 0, 255 } },
    { "aggro_flamer", false, { 255, 86, 10, 40 } },
    { "aggro_rager", false, { 255, 255, 43, 96 } },
}

local aggro_enemy_widgets = {}

for _, aggro_data in ipairs(aggro_types) do
    local aggro_name = aggro_data[1]
    local default_enabled = aggro_data[2]
    local default_color = aggro_data[3]

    table.insert(aggro_enemy_widgets, {
        setting_id = aggro_name .. "_enabled",
        type = "checkbox",
        default_value = default_enabled,
        sub_widgets = {
            {
                setting_id = aggro_name .. "_color",
                type = "color",
                default_value = default_color,
                title = "title_color",
            },
        },
    })
end

table.insert(widgets, {
    setting_id = "aggro_header",
    type = "group",
    tab = mod:localize("tab_aggro"),
    sub_widgets = aggro_enemy_widgets,
})

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets,
    },
}
