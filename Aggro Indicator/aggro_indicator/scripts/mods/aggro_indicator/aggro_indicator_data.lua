local mod = get_mod("aggro_indicator")

local widgets = {
    {
        setting_id = "group_general",
        type = "group",
        tab = mod:localize("tab_general"),
        sub_widgets = {
            {
                setting_id = "indicator_offset_x",
                type = "numeric",
                range = { -1000, 1000 },
                default_value = -30,
            },
            {
                setting_id = "indicator_offset_y",
                type = "numeric",
                range = { -1000, 1000 },
                default_value = 0,
            },
            {
                setting_id = "indicator_horizontal_alignment",
                type = "dropdown",
                default_value = "center",
                options = {
                    { text = "align_left", value = "left" },
                    { text = "align_center", value = "center" },
                    { text = "align_right", value = "right" },
                },
            },
            {
                setting_id = "indicator_vertical_alignment",
                type = "dropdown",
                default_value = "center",
                options = {
                    { text = "align_top", value = "top" },
                    { text = "align_center", value = "center" },
                    { text = "align_bottom", value = "bottom" },
                },
            },
            {
                setting_id = "indicator_size",
                type = "numeric",
                range = { 1, 50 },
                default_value = 25,
            },
            {
                setting_id = "always_on",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "show_facing_arrow",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "arrow_size",
                type = "numeric",
                range = { 1, 50 },
                default_value = 16,
            },
            {
                setting_id = "arrow_orbit_distance",
                type = "numeric",
                range = { 0, 50 },
                default_value = 5,
            },
        },
    },
    {
        setting_id = "aggro_header",
        type = "group",
        tab = mod:localize("tab_aggro"),
        sub_widgets = {
            { setting_id = "aggro_pox_burster_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_trapper_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_dog_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_mutant_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_sniper_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_captain_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_monstrosity_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_daemonhost_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_grenadier_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_crusher_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_flamer_enabled", type = "checkbox", default_value = true },
            { setting_id = "aggro_rager_enabled", type = "checkbox", default_value = true },
        },
    },
}

local aggro_types = {
    { "aggro_pox_burster", { 255, 255, 255, 0 } },
    { "aggro_trapper", { 255, 70, 0, 150 } },
    { "aggro_dog", { 255, 150, 0, 255 } },
    { "aggro_mutant", { 255, 120, 77, 255 } },
    { "aggro_sniper", { 255, 0, 255, 255 } },
    { "aggro_captain", { 255, 255, 96, 0 } },
    { "aggro_monstrosity", { 255, 255, 0, 0 } },
    { "aggro_daemonhost", { 255, 0, 255, 0 } },
    { "aggro_grenadier", { 255, 34, 100, 34 } },
    { "aggro_crusher", { 255, 0, 0, 255 } },
    { "aggro_flamer", { 255, 86, 10, 40 } },
    { "aggro_rager", { 255, 255, 43, 96 } },
}

local aggro_color_widgets = {}

for _, aggro_data in ipairs(aggro_types) do
    local aggro_name = aggro_data[1]
    local default_color = aggro_data[2]

    table.insert(aggro_color_widgets, {
        setting_id = aggro_name .. "_color",
        type = "color",
        default_value = default_color,
    })
end

table.insert(widgets, {
    setting_id = "group_aggro_colors",
    type = "group",
    tab = mod:localize("tab_aggro_colors"),
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
