-- File: RingHud/scripts/mods/RingHud/RingHud_definitions.lua
local mod = get_mod("RingHud")
if not mod then return {} end

-- Ensure RingHud palette gets initialized (sets mod.PALETTE_ARGB255 / mod.PALETTE_RGBA1)
mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

-- Safeguard lookups so this file never errors if palettes/constants aren’t ready yet.
local ARGB  = mod.PALETTE_ARGB255 or {}
local RGBA1 = mod.PALETTE_RGBA1 or {}

setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end }) -- ARGB-255 default white
setmetatable(RGBA1, { __index = function() return { 1, 1, 1, 1 } end })        -- RGBA 0..1 default white

-- Cross-file constants with sane fallbacks
local MAX_DODGE_SEGMENTS                          = mod.MAX_DODGE_SEGMENTS or 6
local MAX_GRENADE_SEGMENTS_DISPLAY                = mod.MAX_GRENADE_SEGMENTS_DISPLAY or 6
local MAX_AMMO_CLIP_LOW_COUNT_DISPLAY             = mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY or 6
local AMMO_CLIP_ARC_MIN                           = mod.AMMO_CLIP_ARC_MIN or 0.55
local AMMO_CLIP_ARC_MAX                           = mod.AMMO_CLIP_ARC_MAX or 0.75

-- Darktide UI deps
local UIWorkspaceSettings                         = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget                                    = require("scripts/managers/ui/ui_widget")
local UIFontSettings                              = require("scripts/managers/ui/ui_font_settings")

-- Layout constants
local area_side                                   = 240
local size                                        = { area_side, area_side }
local offset_correction                           = area_side * 0.055
local vertical_offset                             = offset_correction * 3
local text_offset                                 = offset_correction * 4
local outer_size_factor                           = 1.5
local inner_size_factor                           = 0.8

-- Text styles
local percent_text_style                          = table.clone(UIFontSettings.body_small)
percent_text_style.drop_shadow                    = true
percent_text_style.text_horizontal_alignment      = "center"
percent_text_style.text_vertical_alignment        = "center"
percent_text_style.offset                         = { -text_offset - 3, offset_correction, 2 }

local ability_cd_text_style                       = table.clone(UIFontSettings.body_small)
ability_cd_text_style.drop_shadow                 = true
ability_cd_text_style.text_horizontal_alignment   = "center"
ability_cd_text_style.text_vertical_alignment     = "center"
ability_cd_text_style.offset                      = { text_offset + 3, offset_correction, 2 }

local ability_buff_text_style                     = table.clone(ability_cd_text_style)
ability_buff_text_style.font_type                 = "machine_medium"
ability_buff_text_style.drop_shadow               = true
ability_buff_text_style.text_color                = { 255, 0, 255, 0 } -- TODO: tune color
ability_buff_text_style.text_horizontal_alignment = "center"
ability_buff_text_style.text_vertical_alignment   = "center"
ability_buff_text_style.offset                    = { text_offset, offset_correction, 2 }

local ammo_reserve_text_style                     = table.clone(percent_text_style)
ammo_reserve_text_style.drop_shadow               = true
ammo_reserve_text_style.offset                    = { 0, 0, 2 }

local ammo_clip_text_style                        = table.clone(UIFontSettings.body_small)
ammo_clip_text_style.text_color                   = ARGB.GENERIC_WHITE
ammo_clip_text_style.drop_shadow                  = true
ammo_clip_text_style.text_horizontal_alignment    = "center"
ammo_clip_text_style.text_vertical_alignment      = "center"
ammo_clip_text_style.offset                       = { 0, 0, 1 }

local health_text_style                           = table.clone(UIFontSettings.body_small)
health_text_style.text_color                      = ARGB.GENERIC_WHITE
health_text_style.drop_shadow                     = true
health_text_style.text_horizontal_alignment       = "center"
health_text_style.text_vertical_alignment         = "center"
health_text_style.offset                          = { 0, 0, 1 }

-- RGBA 0..1
local AMMO_CLIP_UNFILLED_COLOR                    = { 0.3, 0.3, 0.3, 0.8 }

local Definitions                                 = {
    text_offset           = text_offset,
    offset_correction     = offset_correction,

    scenegraph_definition = {
        screen                         = UIWorkspaceSettings.screen,
        container                      = {
            parent = "screen",
            vertical_alignment = "center",
            horizontal_alignment = "center",
            size = size,
            position = { 0, vertical_offset, 0 },
        },

        peril_bar                      = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { -offset_correction, 1, 1 }, size = size },
        dodge_bar                      = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { offset_correction, -1, 2 }, size = size },
        stamina_bar                    = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { -offset_correction, -1, 3 }, size = size },
        charge_bar                     = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { offset_correction, 1, 4 }, size = size },
        ability_timer                  = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { offset_correction, 1, 5 }, size = size },

        toughness_bar_corruption       = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { offset_correction * outer_size_factor - 1, offset_correction, 6 },
            size                 = { size[1] * outer_size_factor, size[2] * outer_size_factor },
        },
        toughness_bar_health           = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { offset_correction * outer_size_factor - 1, offset_correction, 5 },
            size                 = { size[1] * outer_size_factor, size[2] * outer_size_factor },
        },
        toughness_bar_damage           = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { offset_correction * outer_size_factor - 1, offset_correction, 5 },
            size                 = { size[1] * outer_size_factor, size[2] * outer_size_factor },
        },

        grenade_bar                    = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { offset_correction * inner_size_factor - 1, -offset_correction * inner_size_factor, 7 },
            size                 = { size[1] * inner_size_factor, size[2] * inner_size_factor },
        },
        ammo_clip_bar                  = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { -offset_correction * inner_size_factor + 1, -offset_correction * inner_size_factor + 2, 8 },
            size                 = { size[1] * inner_size_factor, size[2] * inner_size_factor },
        },

        ammo_reserve_text_display_node = {
            parent = "container",
            position = { -(offset_correction + text_offset + 3), 1 + offset_correction, 9 },
            size = { 80, 30 },
            horizontal_alignment = "center",
            vertical_alignment = "top",
        },
        ammo_clip_text_display_node    = {
            parent = "container",
            position = { -offset_correction - text_offset - 3 - 12, -offset_correction * 2.5 - 8, 10 },
            size = { 80, 30 },
            horizontal_alignment = "center",
            vertical_alignment = "center",
        },

        stimm_indicator                = {
            parent = "container",
            position = { offset_correction + text_offset + 10, offset_correction + 8, 11 },
            size = { 15, 15 },
            horizontal_alignment = "center",
            vertical_alignment = "top",
        },
        crate_indicator                = {
            parent = "container",
            position = { offset_correction + text_offset - 4, offset_correction + 8, 12 },
            size = { 15, 15 },
            horizontal_alignment = "center",
            vertical_alignment = "top",
        },

        health_text_display_node       = {
            parent = "container",
            position = { 0, 55, 13 },
            size = { 100, 30 },
            horizontal_alignment = "center",
            vertical_alignment = "center",
        },
    },

    widget_definitions    = {

        -- PERIL
        peril_bar = UIWidget.create_definition({
            { value_id = "percent_text", style_id = "percent_text", pass_type = "text", value = "", style = percent_text_style },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "peril_bar",
                style = {
                    uvs = { { 1, 0 }, { 0, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 1 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 1,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.50, 0.01 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "peril_edge",
                style = {
                    uvs = { { 1, 0 }, { 0, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 1 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.50, 0.01 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
        }, "peril_bar"),

        -- DODGE
        dodge_bar = UIWidget.create_definition((function()
            local passes = {}
            for i = 1, MAX_DODGE_SEGMENTS do
                passes[#passes + 1] = {
                    pass_type = "rotated_texture",
                    value     = "content/ui/materials/effects/forcesword_bar",
                    style_id  = "dodge_bar_" .. i,
                    style     = {
                        uvs = { { 0, 0 }, { 1, 1 } },
                        horizontal_alignment = "center",
                        vertical_alignment = "center",
                        offset = { 0, 0, 1 },
                        size = size,
                        color = ARGB.GENERIC_WHITE,
                        visible = false,
                        pivot = { 0, 0 },
                        angle = 0,
                        material_values = {
                            amount = 0,
                            glow_on_off = 0,
                            lightning_opacity = 0,
                            arc_top_bottom = { 0.51, 0.51 },
                            fill_outline_opacity = { 1.3, 1.3 },
                            outline_color = table.clone(RGBA1.dodge_color_positive_rgba),
                        },
                    },
                }
            end
            return passes
        end)(), "dodge_bar"),

        -- STAMINA
        stamina_bar = UIWidget.create_definition({
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "stamina_bar",
                style = {
                    uvs = { { 1, 0 }, { 0, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 1 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 1,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.99, 0.51 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "stamina_edge",
                style = {
                    uvs = { { 1, 0 }, { 0, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 2 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.99, 0.51 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
        }, "stamina_bar"),

        -- CHARGE
        charge_bar = UIWidget.create_definition({
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "charge_bar_1",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 1 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.24, 0.01 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "charge_bar_1_edge",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 2 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.24, 0.01 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "charge_bar_2",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 2 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.50, 0.27 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "charge_bar_2_edge",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 3 },
                    size = size,
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0.50, 0.27 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = { 1, 1, 1, 1 },
                    },
                },
            },
        }, "charge_bar"),

        -- ABILITY TIMER
        ability_timer = UIWidget.create_definition({
            { value_id = "ability_text", style_id = "ability_text", pass_type = "text", value = "", style = ability_buff_text_style },
        }, "ability_timer"),

        -- TOUGHNESS CORRUPTION
        toughness_bar_corruption = UIWidget.create_definition({
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "corruption_segment",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 0 },
                    size = { size[1] * outer_size_factor, size[2] * outer_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 1,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0, 0 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = table.clone(RGBA1.default_corruption_color_rgba),
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "corruption_segment_edge",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 1 },
                    size = { size[1] * outer_size_factor, size[2] * outer_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0, 0 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = table.clone(RGBA1.default_corruption_color_rgba),
                    },
                },
            },
        }, "toughness_bar_corruption"),

        -- TOUGHNESS HEALTH
        toughness_bar_health = UIWidget.create_definition({
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "health_segment",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 1 },
                    size = { size[1] * outer_size_factor, size[2] * outer_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = true,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0, 0 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = table.clone(RGBA1.default_toughness_color_rgba),
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "health_segment_edge",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 2 },
                    size = { size[1] * outer_size_factor, size[2] * outer_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0, 0 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = table.clone(RGBA1.default_toughness_color_rgba),
                    },
                },
            },
        }, "toughness_bar_health"),

        -- TOUGHNESS DAMAGE
        toughness_bar_damage = UIWidget.create_definition({
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "damage_segment",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 2 },
                    size = { size[1] * outer_size_factor, size[2] * outer_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = true,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0, 0 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = table.clone(RGBA1.default_damage_color_rgba),
                    },
                },
            },
            {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "damage_segment_edge",
                style = {
                    uvs = { { 0, 0 }, { 1, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 3 },
                    size = { size[1] * outer_size_factor, size[2] * outer_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 0,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { 0, 0 },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = table.clone(RGBA1.default_damage_color_rgba),
                    },
                },
            },
        }, "toughness_bar_damage"),

        -- GRENADES
        grenade_bar = UIWidget.create_definition((function()
            local passes = {}
            for i = 1, MAX_GRENADE_SEGMENTS_DISPLAY do
                -- Base segment
                passes[#passes + 1] = {
                    pass_type = "rotated_texture",
                    value     = "content/ui/materials/effects/forcesword_bar",
                    style_id  = "grenade_segment_" .. i,
                    style     = {
                        uvs = { { 0, 0 }, { 1, 1 } },
                        horizontal_alignment = "center",
                        vertical_alignment = "center",
                        offset = { 0, 0, 1 },
                        size = { size[1] * inner_size_factor, size[2] * inner_size_factor },
                        color = ARGB.GENERIC_WHITE,
                        visible = false,
                        pivot = { 0, 0 },
                        angle = 0,
                        material_values = {
                            amount = 0,
                            glow_on_off = 0,
                            lightning_opacity = 0,
                            arc_top_bottom = { 0, 0 },
                            fill_outline_opacity = { 1.3, 1.3 },
                            outline_color = table.clone(RGBA1.default_damage_color_rgba),
                        },
                    },
                }
                -- Edge sliver (for partial notch)
                passes[#passes + 1] = {
                    pass_type = "rotated_texture",
                    value     = "content/ui/materials/effects/forcesword_bar",
                    style_id  = "grenade_segment_edge_" .. i,
                    style     = {
                        uvs = { { 0, 0 }, { 1, 1 } },
                        horizontal_alignment = "center",
                        vertical_alignment = "center",
                        offset = { 0, 0, 2 },
                        size = { size[1] * inner_size_factor, size[2] * inner_size_factor },
                        color = ARGB.GENERIC_WHITE,
                        visible = false,
                        pivot = { 0, 0 },
                        angle = 0,
                        material_values = {
                            amount = 0,
                            glow_on_off = 0,
                            lightning_opacity = 0,
                            arc_top_bottom = { 0, 0 },
                            fill_outline_opacity = { 1.3, 1.3 },
                            outline_color = table.clone(RGBA1.default_damage_color_rgba),
                        },
                    },
                }
            end
            return passes
        end)(), "grenade_bar"),

        -- AMMO CLIP
        ammo_clip_bar = UIWidget.create_definition((function()
            local passes = {}

            passes[#passes + 1] = {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "ammo_clip_unfilled_background",
                style = {
                    uvs = { { 1, 0 }, { 0, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 0 },
                    size = { size[1] * inner_size_factor, size[2] * inner_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 1,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { AMMO_CLIP_ARC_MAX, AMMO_CLIP_ARC_MIN },
                        fill_outline_opacity = { 0.7, 0.5 },
                        outline_color = table.clone(AMMO_CLIP_UNFILLED_COLOR),
                    },
                },
            }

            passes[#passes + 1] = {
                pass_type = "rotated_texture",
                value = "content/ui/materials/effects/forcesword_bar",
                style_id = "ammo_clip_filled_single",
                style = {
                    uvs = { { 1, 0 }, { 0, 1 } },
                    horizontal_alignment = "center",
                    vertical_alignment = "center",
                    offset = { 0, 0, 1 },
                    size = { size[1] * inner_size_factor, size[2] * inner_size_factor },
                    color = ARGB.GENERIC_WHITE,
                    visible = false,
                    pivot = { 0, 0 },
                    angle = 0,
                    material_values = {
                        amount = 1,
                        glow_on_off = 0,
                        lightning_opacity = 0,
                        arc_top_bottom = { AMMO_CLIP_ARC_MIN, AMMO_CLIP_ARC_MIN },
                        fill_outline_opacity = { 1.3, 1.3 },
                        outline_color = table.clone(RGBA1.AMMO_BAR_COLOR_HIGH),
                    },
                },
            }

            for i = 1, MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
                passes[#passes + 1] = {
                    pass_type = "rotated_texture",
                    value = "content/ui/materials/effects/forcesword_bar",
                    style_id = "ammo_clip_filled_multi_" .. i,
                    style = {
                        uvs = { { 1, 0 }, { 0, 1 } },
                        horizontal_alignment = "center",
                        vertical_alignment = "center",
                        offset = { 0, 0, 1 },
                        size = { size[1] * inner_size_factor, size[2] * inner_size_factor },
                        color = ARGB.GENERIC_WHITE,
                        visible = false,
                        pivot = { 0, 0 },
                        angle = 0,
                        material_values = {
                            amount = 1,
                            glow_on_off = 0,
                            lightning_opacity = 0,
                            arc_top_bottom = { 0, 0 },
                            fill_outline_opacity = { 1.3, 1.3 },
                            outline_color = table.clone(RGBA1.AMMO_BAR_COLOR_HIGH),
                        },
                    },
                }
            end

            return passes
        end)(), "ammo_clip_bar"),

        -- TEXT/ICONS
        ammo_reserve_display_widget = UIWidget.create_definition({
            { value_id = "reserve_text_value", style_id = "reserve_text_style", pass_type = "text", value = "", style = ammo_reserve_text_style },
        }, "ammo_reserve_text_display_node"),

        ammo_clip_text_display_widget = UIWidget.create_definition({
            { value_id = "ammo_clip_value_text", style_id = "ammo_clip_text_style", pass_type = "text", value = "", style = ammo_clip_text_style },
        }, "ammo_clip_text_display_node"),

        stimm_indicator_widget = UIWidget.create_definition({
            {
                pass_type = "texture",
                value_id = "stimm_icon",
                style_id = "stimm_icon",
                style = { color = ARGB.GENERIC_WHITE, offset = { 0, 0, 0 }, visible = false }
            },
        }, "stimm_indicator"),

        crate_indicator_widget = UIWidget.create_definition({
            {
                pass_type = "texture",
                value_id = "crate_icon",
                style_id = "crate_icon",
                style = { color = ARGB.GENERIC_WHITE, offset = { 0, 0, 0 }, visible = false }
            },
        }, "crate_indicator"),

        health_text_display_widget = UIWidget.create_definition({
            { value_id = "health_text_value", style_id = "health_text_style", pass_type = "text", value = "", style = health_text_style },
        }, "health_text_display_node"),
    },
}

return Definitions
