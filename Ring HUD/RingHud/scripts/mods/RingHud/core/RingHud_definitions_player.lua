-- File: RingHud/scripts/mods/RingHud/core/RingHud_definitions_player.lua
local mod = get_mod("RingHud")
if not mod then return {} end

-- Ensure RingHud palette gets initialized (sets mod.PALETTE_ARGB255 / mod.PALETTE_RGBA1)
mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

-- NEW: pull widget factories from feature files
local StaminaFeature     = mod:io_dofile("RingHud/scripts/mods/RingHud/features/stamina_feature")
local ChargeFeature      = mod:io_dofile("RingHud/scripts/mods/RingHud/features/charge_feature")
local DodgeFeature       = mod:io_dofile("RingHud/scripts/mods/RingHud/features/dodge_feature")
local PerilFeature       = mod:io_dofile("RingHud/scripts/mods/RingHud/features/peril_feature")
local ToughnessHpFeature = mod:io_dofile("RingHud/scripts/mods/RingHud/features/toughness_hp_feature")
local AmmoClipFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ammo_clip_feature")
local GrenadesFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/grenades_feature")

-- Safeguard lookups so this file never errors if palettes/constants aren’t ready yet.
local ARGB               = mod.PALETTE_ARGB255 or {}
local RGBA1              = mod.PALETTE_RGBA1 or {}
setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end })
setmetatable(RGBA1, { __index = function() return { 1, 1, 1, 1 } end })

-- Cross-file constants with sane fallbacks
local MAX_DODGE_SEGMENTS              = mod.MAX_DODGE_SEGMENTS or 6
local MAX_GRENADE_SEGMENTS_DISPLAY    = mod.MAX_GRENADE_SEGMENTS_DISPLAY or 6
local MAX_AMMO_CLIP_LOW_COUNT_DISPLAY = mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY or 6
local AMMO_CLIP_ARC_MIN               = mod.AMMO_CLIP_ARC_MIN or 0.55
local AMMO_CLIP_ARC_MAX               = mod.AMMO_CLIP_ARC_MAX or 0.75

-- Darktide UI deps
local UIWorkspaceSettings             = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget                        = require("scripts/managers/ui/ui_widget")
local UIFontSettings                  = require("scripts/managers/ui/ui_font_settings")

-- Layout constants
local function _effective_ring_scale()
    local forced = mod._runtime_overrides and mod._runtime_overrides.ring_scale
    if forced ~= nil then
        return tonumber(forced) or 1
    end
    return tonumber(mod._settings and mod._settings.ring_scale) or 1
end

local s                                         = _effective_ring_scale()
local area_side                                 = 240 * s
mod.scalable_unit                               = area_side / 240 -- replaces px(n): n * unit
local size                                      = { area_side, area_side }
local offset_correction                         = area_side * 0.055
local vertical_offset                           = offset_correction * 3
local text_offset                               = offset_correction * 4
local outer_size_factor                         = 1.5
local inner_size_factor                         = 0.8

local settings_x                                = (mod._settings and mod._settings.player_hud_offset_x) or 0
local settings_y                                = (mod._settings and mod._settings.player_hud_offset_y) or 0

-- Text styles
local percent_text_style                        = table.clone(UIFontSettings.body_small)
percent_text_style.drop_shadow                  = true
percent_text_style.text_horizontal_alignment    = "center"
percent_text_style.text_vertical_alignment      = "center"
percent_text_style.offset                       = { -(text_offset + 3 * mod.scalable_unit), offset_correction, 2 }

local ability_cd_text_style                     = table.clone(UIFontSettings.body_small)
ability_cd_text_style.drop_shadow               = true
ability_cd_text_style.text_horizontal_alignment = "left"
ability_cd_text_style.text_vertical_alignment   = "center"
ability_cd_text_style.offset                    = { text_offset + 3 * mod.scalable_unit, offset_correction, 2 }

local ability_buff_text_style                   = table.clone(ability_cd_text_style)
ability_buff_text_style.font_type               = "machine_medium"
ability_buff_text_style.drop_shadow             = true
ability_buff_text_style.text_color              = { 255, 0, 255, 0 }
ability_buff_text_style.offset                  = { text_offset, offset_correction, 2 }

local ammo_reserve_text_style                   = table.clone(percent_text_style)
ammo_reserve_text_style.drop_shadow             = true
ammo_reserve_text_style.offset                  = { 0, 0, 2 }

local ammo_clip_text_style                      = table.clone(UIFontSettings.body_small)
ammo_clip_text_style.text_color                 = ARGB.GENERIC_WHITE
ammo_clip_text_style.drop_shadow                = true
ammo_clip_text_style.text_horizontal_alignment  = "center"
ammo_clip_text_style.text_vertical_alignment    = "center"
ammo_clip_text_style.offset                     = { 0, 0, 1 }

local health_text_style                         = table.clone(UIFontSettings.body_small)
health_text_style.text_color                    = ARGB.GENERIC_WHITE
health_text_style.drop_shadow                   = true
health_text_style.text_horizontal_alignment     = "center"
health_text_style.text_vertical_alignment       = "center"
health_text_style.offset                        = { 0, 0, 1 }

-- RGBA 0..1
local AMMO_CLIP_UNFILLED_COLOR                  = { 0.3, 0.3, 0.3, 0.8 }

local Definitions                               = {
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

        peril_bar                      = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { -offset_correction, 1 * mod.scalable_unit, 1 }, size = size },
        dodge_bar                      = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { offset_correction, -1 * mod.scalable_unit, 2 }, size = size },
        stamina_bar                    = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { -offset_correction, -1 * mod.scalable_unit, 3 }, size = size },
        charge_bar                     = { parent = "container", horizontal_alignment = "center", vertical_alignment = "center", position = { offset_correction, 1 * mod.scalable_unit, 4 }, size = size },
        ability_timer                  = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { offset_correction + (text_offset * 2), 1 * mod.scalable_unit, 5 },
            size                 = size
        },

        toughness_bar_corruption       = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { (offset_correction * outer_size_factor) - (1 * mod.scalable_unit), offset_correction, 6 },
            size                 = { size[1] * outer_size_factor, size[2] * outer_size_factor },
        },
        toughness_bar_health           = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { (offset_correction * outer_size_factor) - (1 * mod.scalable_unit), offset_correction, 5 },
            size                 = { size[1] * outer_size_factor, size[2] * outer_size_factor },
        },
        toughness_bar_damage           = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { (offset_correction * outer_size_factor) - (1 * mod.scalable_unit), offset_correction, 5 },
            size                 = { size[1] * outer_size_factor, size[2] * outer_size_factor },
        },

        grenade_bar                    = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { (offset_correction * inner_size_factor) - (1 * mod.scalable_unit), -(offset_correction * inner_size_factor), 7 },
            size                 = { size[1] * inner_size_factor, size[2] * inner_size_factor },
        },
        ammo_clip_bar                  = {
            parent               = "container",
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            position             = { -(offset_correction * inner_size_factor) + (1 * mod.scalable_unit), -(offset_correction * inner_size_factor) + (2 * mod.scalable_unit), 8 },
            size                 = { size[1] * inner_size_factor, size[2] * inner_size_factor },
        },

        ammo_reserve_text_display_node = {
            parent               = "container",
            position             = { -((offset_correction + text_offset) + 3 * mod.scalable_unit), (1 * mod.scalable_unit) + offset_correction, 9 },
            size                 = { 80 * mod.scalable_unit, 30 * mod.scalable_unit },
            horizontal_alignment = "center",
            vertical_alignment   = "top",
        },
        ammo_clip_text_display_node    = {
            parent               = "container",
            position             = { -(offset_correction + text_offset + 15 * mod.scalable_unit), -(offset_correction * 2.5) - (8 * mod.scalable_unit), 10 },
            size                 = { 80 * mod.scalable_unit, 30 * mod.scalable_unit },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
        },

        stimm_indicator                = {
            parent               = "container",
            position             = { offset_correction + text_offset + (10 * mod.scalable_unit), offset_correction + (8 * mod.scalable_unit), 11 },
            size                 = { 15 * mod.scalable_unit, 15 * mod.scalable_unit },
            horizontal_alignment = "center",
            vertical_alignment   = "top",
        },
        crate_indicator                = {
            parent               = "container",
            position             = { offset_correction + text_offset - (4 * mod.scalable_unit), offset_correction + (8 * mod.scalable_unit), 12 },
            size                 = { 15 * mod.scalable_unit, 15 * mod.scalable_unit },
            horizontal_alignment = "center",
            vertical_alignment   = "top",
        },

        health_text_display_node       = {
            parent               = "container",
            position             = { 0, 55 * mod.scalable_unit, 13 },
            size                 = { 100 * mod.scalable_unit, 30 * mod.scalable_unit },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
        },
    },

    widget_definitions    = {

        -- (PERIL moved to features/peril_feature.lua)
        -- (DODGE moved to features/dodge_feature.lua)
        -- (STAMINA moved to features/stamina_feature.lua)
        -- (CHARGE moved to features/charge_feature.lua)
        -- (TOUGHNESS* moved to features/toughness_hp_feature.lua)
        -- (GRENADES moved to features/grenades_feature.lua)
        -- (AMMO CLIP moved to features/ammo_clip_feature.lua)

        -- ABILITY TIMER
        ability_timer = UIWidget.create_definition({
            { value_id = "ability_text", style_id = "ability_text", pass_type = "text", value = "", style = ability_buff_text_style },
        }, "ability_timer"),

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

-- Let features inject their widget(s)
StaminaFeature.add_widgets(Definitions.widget_definitions, nil, { size = size }, { ARGB = ARGB, RGBA1 = RGBA1 })
ChargeFeature.add_widgets(Definitions.widget_definitions, nil, { size = size }, { ARGB = ARGB, RGBA1 = RGBA1 })
DodgeFeature.add_widgets(Definitions.widget_definitions, nil, { size = size }, { ARGB = ARGB, RGBA1 = RGBA1 })
PerilFeature.add_widgets(Definitions.widget_definitions, nil, { size = size }, { ARGB = ARGB, RGBA1 = RGBA1 })
ToughnessHpFeature.add_widgets(Definitions.widget_definitions, nil, { size = size, outer_size_factor = 1.5 },
    { ARGB = ARGB, RGBA1 = RGBA1 })
AmmoClipFeature.add_widgets(Definitions.widget_definitions, nil, { size = size, inner_size_factor = inner_size_factor },
    { ARGB = ARGB, RGBA1 = RGBA1 })
GrenadesFeature.add_widgets(Definitions.widget_definitions, nil, { size = size, inner_size_factor = inner_size_factor },
    { ARGB = ARGB, RGBA1 = RGBA1 })

return Definitions
