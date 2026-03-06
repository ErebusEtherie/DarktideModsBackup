--[[
	File: TalentPreview_data.lua
	Description: Data file to pull setting defaults and data for mod settings
	Overall Release Version: 1.1.5
	File Version: 1.1.5
    File Introduced in: 1.0.0
	Last Updated: 2026-01-21
	Author: LAUREHTE
]]

local mod = get_mod("TalentPreview")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "enable_in_lobby",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_keystone",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_stat",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_default",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_modifiers",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_aura",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_blitz",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_ability_modifiers",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "show_broker_stimm",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "preview_background_style",
                type = "dropdown",
                default_value = "themed",
                options = {
                    { text = "preview_background_off", value = "off" },
                    { text = "preview_background_black", value = "black" },
                    { text = "preview_background_themed", value = "themed" },
                    { text = "preview_background_themed_glow", value = "themed_glow" },
                },
            },
            {
                setting_id = "icon_size",
                type = "numeric",
                default_value = 60,
                range = {25, 100},
                decimals_number = 0,
            },
            {
                setting_id = "icons_per_row",
                type = "numeric",
                default_value = 4,
                range = {3, 10},
                decimals_number = 0,
            },
            {
                setting_id = "preview_offset_y",
                type = "numeric",
                default_value = 170,
                range = {0, 300},
                decimals_number = 0,
            },
            {
                setting_id = "preview_offset_x",
                type = "numeric",
                default_value = 110,
                range = {-200, 200},
                decimals_number = 0,
            },
            {
                setting_id = "tree_scale_percent",
                type = "numeric",
                default_value = 100,
                range = {10, 300},
                decimals_number = 0,
            },
            {
                setting_id = "tree_area_width",
                type = "numeric",
                default_value = 300,
                range = {180, 700},
                decimals_number = 0,
            },
            {
                setting_id = "tree_area_height",
                type = "numeric",
                default_value = 600,
                range = {180, 700},
                decimals_number = 0,
            },
            {
                setting_id = "tree_offset_y",
                type = "numeric",
                default_value = 170,
                range = {0, 300},
                decimals_number = 0,
            },
            {
                setting_id = "tree_offset_x",
                type = "numeric",
                default_value = -55,
                range = {-200, 200},
                decimals_number = 0,
            },
            {
                setting_id = "tree_node_size",
                type = "numeric",
                default_value = 50,
                range = {16, 100},
                decimals_number = 0,
            },
            {
                setting_id = "tree_stimm_gap",
                type = "numeric",
                default_value = 190,
                range = {0, 300},
                decimals_number = 0,
            },
            {
                setting_id = "tree_stimm_offset_x",
                type = "numeric",
                default_value = 1600,
                range = {-2000, 2000},
                decimals_number = 0,
            },
            {
                setting_id = "tree_stimm_offset_y",
                type = "numeric",
                default_value = 350,
                range = {-800, 800},
                decimals_number = 0,
            },
            {
                setting_id = "tree_stimm_scale_percent",
                type = "numeric",
                default_value = 100,
                range = {50, 200},
                decimals_number = 0,
            },
            {
                setting_id = "tree_show_stimm_tree",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "tree_background_style",
                type = "dropdown",
                default_value = "themed",
                options = {
                    { text = "tree_background_off", value = "off" },
                    { text = "tree_background_black", value = "black" },
                    { text = "tree_background_themed", value = "themed" },
                    { text = "tree_background_themed_glow", value = "themed_glow" },
                },
            },
            {
                setting_id = "debug_logging",
                type = "checkbox",
                default_value = false,
            },
        },
    },
}
