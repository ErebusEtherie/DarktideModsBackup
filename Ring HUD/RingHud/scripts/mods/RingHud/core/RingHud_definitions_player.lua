-- File: RingHud/scripts/mods/RingHud/core/RingHud_definitions_player.lua
local mod = get_mod("RingHud")
if not mod then return {} end

mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget            = require("scripts/managers/ui/ui_widget")
local UIFontSettings      = require("scripts/managers/ui/ui_font_settings")

local ARGB                = mod.PALETTE_ARGB255 or {}
local RGBA1               = mod.PALETTE_RGBA1 or {}
setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end })
setmetatable(RGBA1, { __index = function() return { 1, 1, 1, 1 } end })

local function _effective_ring_scale()
    local overrides = mod._runtime_overrides
    if overrides and overrides.ring_scale ~= nil then
        return tonumber(overrides.ring_scale) or 1
    end
    return tonumber(mod._settings and mod._settings.ring_scale) or 1
end

local function _effective_font()
    local font = mod._settings and mod._settings.player_hud_font
    return (not font or font == "") and "proxima_nova_bold" or font
end

local function _effective_text_size(default_size)
    local user_size = tonumber(mod._settings and mod._settings.player_hud_text_size)
    return user_size and (user_size * _effective_ring_scale()) or default_size
end

local function _effective_text_offset()
    return tonumber(mod._settings and mod._settings.player_hud_text_offset) or 0
end

local s = _effective_ring_scale()
local custom_font = _effective_font()
local area_side = 240 * s
local u = area_side / 240
mod.scalable_unit = u

local size = { u * 240, u * 240 }
local offset_correction = u * 13.2
local vertical_offset = u * 39.6
local text_offset = u * 52.8
local outer_size_factor = 1.5
local inner_size_factor = 0.8
local outer_size = { size[1] * outer_size_factor, size[2] * outer_size_factor }
local inner_size = { size[1] * inner_size_factor, size[2] * inner_size_factor }

local user_text_offset_bias = _effective_text_offset() * u
local settings_x = (mod._settings and mod._settings.player_hud_offset_x) or 0
local settings_y = (mod._settings and mod._settings.player_hud_offset_y) or 0
local base_font_size = _effective_text_size(18 * u)

local function create_text_style(offset, align, color, font, font_size, custom_size)
    local style                     = table.clone(UIFontSettings.body_small)
    style.font_type                 = font or custom_font
    style.font_size                 = font_size or base_font_size
    style.drop_shadow               = true
    style.text_horizontal_alignment = align or "right"
    style.text_vertical_alignment   = "center"
    style.offset                    = offset
    if color then style.text_color = color end
    if custom_size then style.size = custom_size end
    return style
end

local percent_text_style      = create_text_style({ -(u * 55.8 + user_text_offset_bias), offset_correction, 2 })
local ability_cd_text_style   = create_text_style({ u * 55.8 + user_text_offset_bias, offset_correction, 2 }, "left")
local ability_buff_text_style = create_text_style({ u * 52.8 + user_text_offset_bias, u * 13.2, 2 }, "left",
    { 255, 0, 255, 0 }, "machine_medium", base_font_size * 1.5)
local stimm_timer_text_style  = create_text_style({ 0, 0, 1 }, "left", { 255, 0, 255, 0 }, nil, nil, { 200 * u, 30 * u })
local ammo_reserve_text_style = create_text_style({ 0, 0, 2 })
local peril_text_style        = create_text_style({ 0, 0, 2 })
local ammo_clip_text_style    = create_text_style({ 0, 0, 1 }, "right", ARGB.GENERIC_WHITE)
local health_text_style       = create_text_style({ 0, 0, 1 }, "center", ARGB.GENERIC_WHITE)

local function create_node(position, node_size, h_align, v_align)
    return {
        parent               = "container",
        horizontal_alignment = h_align or "center",
        vertical_alignment   = v_align or "center",
        position             = position,
        size                 = node_size or size,
    }
end

local Definitions = {
    text_offset           = text_offset,
    offset_correction     = offset_correction,

    scenegraph_definition = {
        screen                         = UIWorkspaceSettings.screen,
        container                      = {
            parent               = "screen",
            vertical_alignment   = "center",
            horizontal_alignment = "center",
            size                 = size,
            position             = { settings_x, vertical_offset + settings_y, 0 },
        },

        peril_bar                      = create_node({ -offset_correction, u * 1, 1 }),
        dodge_bar                      = create_node({ offset_correction, -u * 1, 2 }),
        stamina_bar                    = create_node({ -offset_correction, -u * 1, 3 }),
        charge_bar                     = create_node({ offset_correction, u * 1, 4 }),

        ability_timer                  = create_node({ offset_correction + (text_offset * 2) - (u * 5), u * 1, 5 }, size,
            "left"),

        toughness_bar_corruption       = create_node(
            { (offset_correction * outer_size_factor) - (u * 2), offset_correction, 6 }, outer_size),
        toughness_bar_health           = create_node(
            { (offset_correction * outer_size_factor) - (u * 1), offset_correction, 5 }, outer_size),
        toughness_bar_damage           = create_node(
            { (offset_correction * outer_size_factor) - (u * 1), offset_correction, 5 }, outer_size),

        grenade_bar                    = create_node(
            { (offset_correction * inner_size_factor) - (u * 1), -(offset_correction * inner_size_factor), 7 },
            inner_size),
        ammo_clip_bar                  = create_node(
            { -(offset_correction * inner_size_factor) + (u * 1), -(offset_correction * inner_size_factor) + (u * 2), 8 },
            inner_size),
        talent_bar                     = create_node(
            { (offset_correction * inner_size_factor) - (u * 1), -(offset_correction * inner_size_factor) + (u * 2), 8 },
            inner_size),

        peril_text_display_node        = create_node(
            { -(offset_correction + text_offset + u * 105), u * 1 + offset_correction, 10 }, { u * 150, u * 30 }, "right"),
        ammo_reserve_text_display_node = create_node(
            { -(offset_correction + text_offset + u * 96), u * 14.2, 9 }, { u * 200, u * 30 }, "right",
            "top"),
        ammo_clip_text_display_node    = create_node(
            { -(offset_correction + text_offset + u * 115), -(offset_correction * 2.5) - (u * 8), 10 },
            { u * 150, u * 30 },
            "right"),

        stimm_indicator                = create_node(
            { offset_correction + text_offset + (u * 22), u * 21.2, 11 }, { u * 40, u * 15 }, "center",
            "top"),
        crate_indicator                = create_node(
            { offset_correction + text_offset - (u * 4), offset_correction + (u * 8), 12 }, { u * 15, u * 15 }, "center",
            "top"),
        health_text_display_node       = create_node({ 0, u * 55, 13 }, { u * 250, u * 30 }, "center"),
    },

    widget_definitions    = {
        ability_timer = UIWidget.create_definition({
            { value_id = "ability_text", style_id = "ability_text", pass_type = "text", value = "", style = ability_buff_text_style },
        }, "ability_timer"),

        peril_text_display_widget = UIWidget.create_definition({
            { value_id = "percent_text", style_id = "percent_text_style", pass_type = "text", value = "", style = peril_text_style },
        }, "peril_text_display_node"),

        ammo_reserve_display_widget = UIWidget.create_definition({
            { value_id = "reserve_text_value", style_id = "reserve_text_style", pass_type = "text", value = "", style = ammo_reserve_text_style },
        }, "ammo_reserve_text_display_node"),

        ammo_clip_text_display_widget = UIWidget.create_definition({
            { value_id = "ammo_clip_value_text", style_id = "ammo_clip_text_style", pass_type = "text", value = "", style = ammo_clip_text_style },
        }, "ammo_clip_text_display_node"),

        stimm_indicator_widget = UIWidget.create_definition({
            { pass_type = "texture", value_id = "stimm_icon",       style_id = "stimm_icon",       style = { color = ARGB.GENERIC_WHITE, offset = { 0, 0, 0 }, visible = false, horizontal_alignment = "left", vertical_alignment = "center", size = { u * 15, u * 15 } } },
            { pass_type = "text",    value_id = "stimm_timer_text", style_id = "stimm_timer_text", value = "",                                                                                                                                                            size = { u * 200, u * 30 }, style = stimm_timer_text_style },
        }, "stimm_indicator"),

        crate_indicator_widget = UIWidget.create_definition({
            { pass_type = "texture", value_id = "crate_icon", style_id = "crate_icon", style = { color = ARGB.GENERIC_WHITE, offset = { 0, 0, 0 }, visible = false } }
        }, "crate_indicator"),

        health_text_display_widget = UIWidget.create_definition({
            { value_id = "health_text_value", style_id = "health_text_style", pass_type = "text", value = "", style = health_text_style },
        }, "health_text_display_node"),
    },
}

-- Automatically load and map features to their parameters
local feature_bindings = {
    { name = "stamina_feature" },
    { name = "charge_feature" },
    { name = "dodge_feature" },
    { name = "peril_feature" },
    { name = "toughness_hp_feature", args = { size = size, outer_size_factor = outer_size_factor } },
    { name = "ammo_clip_feature",    args = { size = size, inner_size_factor = inner_size_factor } },
    { name = "grenades_feature",     args = { size = size, inner_size_factor = inner_size_factor } },
}

local colors = { ARGB = ARGB, RGBA1 = RGBA1 }
local default_args = { size = size }

for _, binding in ipairs(feature_bindings) do
    local feature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/" .. binding.name)
    if feature and feature.add_widgets then
        feature.add_widgets(Definitions.widget_definitions, nil, binding.args or default_args, colors)
    end
end

-- Talent bar validation (always created)
local TalentFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/talent_feature")
if TalentFeature and TalentFeature.add_widgets then
    TalentFeature.add_widgets(
        Definitions.widget_definitions,
        nil,
        { size = size, inner_size_factor = inner_size_factor, scenegraph_id = "talent_bar" },
        colors
    )
end

return Definitions
