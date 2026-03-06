-- File: RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_docked.lua
local mod = get_mod("RingHud"); if not mod then return end
local UIWidget            = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings      = require("scripts/managers/ui/ui_font_settings")
local C                   = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local U                   = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

local W                   = {}

local GAP_Y               = C.TILE_SIZE / 1.5

local STACK_Y_OFFSET      = C.STACK_Y_OFFSET or math.floor(C.TILE_SIZE * 0.5)

local function _add_pass(passes, style_map, pass)
    passes[#passes + 1] = pass
    if pass.style_id and pass.style then
        style_map[pass.style_id] = pass.style
    end
end

local function make_tile_only_widget_def(node_name)
    local content = {
        -- Status & archetype
        status_icon            = nil, -- runtime material path (applier fills)
        status_icon_tint       = nil, -- runtime tint RGBA/ARGB (applier may mirror/touch)

        arch_icon              = "?",

        -- Ledge progress (bar shown only when ledge_hanging)
        ledge_bar_visible      = false, -- coarse gate
        -- Per-pass visibility (set by applier with EPS check; must stay false for zero-length slices)
        ledge_bar_base_visible = false,
        ledge_bar_edge_visible = false,

        -- Texts & auxiliary icons
        reserve_text_value     = "", -- driven by team_ammo.update_ammo(...)
        ability_cd_text        = "", -- driven by team_ability.update_ability_cd(...)
        crate_icon             = nil,
        stimm_icon             = nil,

        -- Throwable: seed with nil; TH.update toggles visibility and Apply sets the path via cache.
        throwable_icon         = nil,

        toughness_text_value   = "", -- driven by team_toughness.update_text(...)
        health_value_text      = "", -- set by apply when enabled
    }

    local passes  = {}
    local style   = {}

    -- Health segments (base layer)
    -- NOTE: Now builds up to C.MAX_HP_SEGMENTS (one extra pass reserved for the split/“notch”).
    for i = 1, C.MAX_HP_SEGMENTS do
        local cid = string.format("hp_seg_%d_visible", i)
        content[cid] = false
        _add_pass(passes, style, {
            pass_type            = "rotated_texture",
            value                = "content/ui/materials/effects/forcesword_bar",
            style_id             = string.format("hp_seg_%d", i),
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            visibility_function  = function(c) return c[cid] end,
            style                = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { C.TILE_SIZE / 16, C.TILE_SIZE / 8, 1 },
                size                 = { C.ARC_SIZE, C.ARC_SIZE },
                pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },
                angle                = 0,
                color                = { 255, 255, 255, 255 },
                material_values      = {
                    amount               = 0,
                    -- Safe default for the extra (+1) pass: clamp index so seg_arc_range never goes OOB.
                    arc_top_bottom       = U.seg_arc_range(math.min(i, C.MAX_WOUNDS_CAP), C.MAX_WOUNDS_CAP),
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = { 1, 1, 1, 1 },
                    lightning_opacity    = 0,
                    glow_on_off          = 0,
                },
            }
        })
    end

    -- Corruption overlay segments (drawn ON TOP of health)
    -- NOTE: Stays at C.MAX_WOUNDS_CAP (unsplit).
    for i = 1, C.MAX_WOUNDS_CAP do
        local cid = string.format("cor_seg_%d_visible", i)
        content[cid] = false
        _add_pass(passes, style, {
            pass_type            = "rotated_texture",
            value                = "content/ui/materials/effects/forcesword_bar",
            style_id             = string.format("cor_seg_%d", i),
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            visibility_function  = function(c) return c[cid] end,
            style                = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { C.TILE_SIZE / 16, C.TILE_SIZE / 8, 2 },
                size                 = { C.ARC_SIZE, C.ARC_SIZE },
                pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },
                angle                = 0,
                color                = { 255, 255, 255, 255 },
                material_values      = {
                    amount               = 1,
                    arc_top_bottom       = U.seg_arc_range(i, C.MAX_WOUNDS_CAP),
                    fill_outline_opacity = { 0.7, 1.3 },
                    outline_color        = { 0.8, 0.27, 0.8, 1.0 },
                    lightning_opacity    = 0,
                    glow_on_off          = 0,
                },
            }
        })
    end

    -- Ledge progress bar (split into base + edge passes, both gated by per-pass booleans)
    -- BASE: amount = 1, sits above base health but under the edge pass
    _add_pass(passes, style, {
        pass_type            = "rotated_texture",
        value                = "content/ui/materials/effects/forcesword_bar",
        style_id             = "ledge_bar_base",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c)
            return c.ledge_bar_visible and c.ledge_bar_base_visible
        end,
        style                = {
            uvs                  = { { 0, 0 }, { 1, 1 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { C.TILE_SIZE / 16, C.TILE_SIZE / 8, 2 }, -- same z as corruption overlay
            size                 = { C.ARC_SIZE, C.ARC_SIZE },
            pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },
            angle                = 0,
            color                = { 255, 255, 255, 255 },
            material_values      = {
                amount               = 1,                     -- filled slice
                arc_top_bottom       = U.seg_arc_range(1, 1), -- runtime will narrow this to [bottom, edge-half_gap]
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = { 1, 0.2, 0.2, 1.0 },  -- overwritten at runtime as needed
                lightning_opacity    = 0,
                glow_on_off          = 0,
            },
        }
    })

    -- EDGE: amount = 0, sits above the base pass to render the notch
    _add_pass(passes, style, {
        pass_type            = "rotated_texture",
        value                = "content/ui/materials/effects/forcesword_bar",
        style_id             = "ledge_bar_edge",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c)
            return c.ledge_bar_visible and c.ledge_bar_edge_visible
        end,
        style                = {
            uvs                  = { { 0, 0 }, { 1, 1 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { C.TILE_SIZE / 16, C.TILE_SIZE / 8, 3 }, -- above base
            size                 = { C.ARC_SIZE, C.ARC_SIZE },
            pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },
            angle                = 0,
            color                = { 255, 255, 255, 255 },
            material_values      = {
                amount               = 0,                     -- empty slice
                arc_top_bottom       = U.seg_arc_range(1, 1), -- runtime will narrow this to [edge+half_gap, top]
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = { 1, 0.2, 0.2, 1.0 },  -- overwritten at runtime as needed
                lightning_opacity    = 0,
                glow_on_off          = 0,
            },
        }
    })

    -- Status icon (replaces archetype icon while active)
    _add_pass(passes, style, {
        pass_type            = "texture",
        value_id             = "status_icon",
        style_id             = "status_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c) return c.status_icon ~= nil end,
        style                = {
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.TILE_SIZE / 3.8, C.TILE_SIZE / 3.8 },
            offset               = { C.TILE_SIZE / 80, 0, 3 },
            color                = { 255, 255, 255, 255 }, -- applier may override via RingHud_state_team.status_icon_tint
        }
    })

    -- Archetype icon (hidden when a status icon is present)
    _add_pass(passes, style, {
        pass_type            = "text",
        value_id             = "arch_icon",
        style_id             = "arch_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c) return c.status_icon == nil end,
        style                = {
            font_type                 = "machine_medium",
            drop_shadow               = true,
            font_size                 = C.TILE_SIZE / 5.5,
            text_horizontal_alignment = "center",
            text_vertical_alignment   = "center",
            size                      = { C.TILE_SIZE, C.TILE_SIZE },
            offset                    = { C.TILE_SIZE / 80, 0, 3 },
            text_color                = { 255, 255, 255, 255 },
        }
    })

    -- Throwable (grenade) icon — center, above ring
    _add_pass(passes, style, {
        pass_type            = "texture",
        value_id             = "throwable_icon",
        style_id             = "throwable_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = {
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.THROWABLE_ICON_SIZE, C.THROWABLE_ICON_SIZE },
            offset               = { -C.TILE_SIZE / 9, -C.TILE_SIZE / 50, 4 },
            color                = { 255, 255, 255, 255 },
            visible              = false,
        }
    })

    -- Crate icon
    _add_pass(passes, style, {
        pass_type            = "texture",
        value_id             = "crate_icon",
        style_id             = "crate_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = {
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.CRATE_ICON_SIZE, C.CRATE_ICON_SIZE },
            offset               = { C.TILE_SIZE / 7.25, -C.TILE_SIZE / 16, 5 },
            color                = { 255, 255, 255, 255 },
            visible              = false,
        }
    })

    -- Stimm icon — diagonal
    _add_pass(passes, style, {
        pass_type            = "texture",
        value_id             = "stimm_icon",
        style_id             = "stimm_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = {
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.STIMM_ICON_SIZE, C.STIMM_ICON_SIZE },
            offset               = { C.TILE_SIZE / 7.25, C.TILE_SIZE / 100, 6 },
            color                = { 255, 255, 255, 255 },
            visible              = false,
        }
    })

    -- Ammo reserve %: left/center (visibility driven by team_ammo)
    _add_pass(passes, style, {
        pass_type            = "text",
        value_id             = "reserve_text_value",
        style_id             = "reserve_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s                     = table.clone(UIFontSettings.body_small or {})
            s.drop_shadow               = true
            s.text_horizontal_alignment = "center"
            s.text_vertical_alignment   = "center"
            s.size                      = { C.TILE_SIZE, C.TILE_SIZE / 13.5 }
            s.offset                    = { -C.TILE_SIZE / 4, C.TILE_SIZE / 2.25, 7 }
            s.text_color                = { 255, 168, 191, 153 }
            s.font_size                 = C.TILE_SIZE / 13.5
            s.visible                   = false
            return s
        end)()
    })

    -- Ability cooldown: right/center (visibility driven by team_ability)
    _add_pass(passes, style, {
        pass_type            = "text",
        value_id             = "ability_cd_text",
        style_id             = "ability_cd_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s                     = table.clone(UIFontSettings.body_small or {})
            s.drop_shadow               = true
            s.text_horizontal_alignment = "center"
            s.text_vertical_alignment   = "center"
            s.size                      = { C.TILE_SIZE, C.TILE_SIZE / 13.5 }
            s.offset                    = { C.TILE_SIZE / 4, C.TILE_SIZE / 2.25, 8 }
            local WHITE                 = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or
                { 255, 255, 255, 255 }
            s.text_color                = table.clone(WHITE)
            s.font_size                 = C.TILE_SIZE / 13.5
            s.visible                   = false
            return s
        end)()
    })

    -- Toughness integer (right side; above ability CD). Visibility driven by team_toughness
    _add_pass(passes, style, {
        pass_type            = "text",
        value_id             = "toughness_text_value",
        style_id             = "toughness_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s                     = table.clone(UIFontSettings.body_small or {})
            s.drop_shadow               = true
            s.text_horizontal_alignment = "center"
            s.text_vertical_alignment   = "center"
            s.size                      = { C.TILE_SIZE, C.TILE_SIZE / 13.5 }
            s.offset                    = { C.TILE_SIZE / 4, C.TILE_SIZE / 1.6, 9 }
            s.text_color                = { 255, 108, 187, 196 } -- ARGB teal-ish default
            s.font_size                 = C.TILE_SIZE / 13.5
            s.visible                   = false
            return s
        end)()
    })

    -- Health integer (left lower). Visibility driven by apply.lua
    _add_pass(passes, style, {
        pass_type            = "text",
        value_id             = "health_value_text",
        style_id             = "health_value_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s                     = table.clone(UIFontSettings.body_small or {})
            s.drop_shadow               = true
            s.text_horizontal_alignment = "center"
            s.text_vertical_alignment   = "center"
            s.size                      = { C.TILE_SIZE, C.TILE_SIZE / 13.5 }
            s.offset                    = { -C.TILE_SIZE / 4, C.TILE_SIZE / 1.6, 10 }
            s.text_color                = { 255, 255, 255, 255 } -- pure white
            s.font_size                 = C.TILE_SIZE / 13.5
            s.visible                   = false
            return s
        end)()
    })

    return UIWidget.create_definition(passes, node_name, content, style)
end

-- The separate name-only widget (sibling of tile under a per-teammate group node)
local function make_name_only_widget_def(node_name)
    local content = { name_text_value = "" }
    local passes  = {}
    local style   = {}

    _add_pass(passes, style, {
        pass_type            = "text",
        value_id             = "name_text_value",
        style_id             = "name_text_style",
        horizontal_alignment = "left",
        vertical_alignment   = "top",
        visibility_function  = function(c)
            return type(c.name_text_value) == "string" and c.name_text_value ~= ""
        end,
        style                = (function()
            local s                     = {}
            s.font_type                 = "proxima_nova_bold"
            s.drop_shadow               = true
            s.text_horizontal_alignment = "center"
            s.text_vertical_alignment   = "bottom"
            s.size                      = { C.TILE_SIZE, C.TILE_SIZE / 12 }
            s.offset                    = { 0, 0, 50 }
            s.font_size                 = C.TILE_SIZE / 13.5
            s.visible                   = true
            return s
        end)()
    })

    return UIWidget.create_definition(passes, node_name, content, style)
end

--------------------------------------------------------------------------------
-- LoadoutMonitor compatibility widget (definition only)
-- (Actual feeding/visibility is handled in HudElementRingHud_team_docked.lua)
--------------------------------------------------------------------------------
local LM_TEXT_COLOR    = { 255, 239, 238, 238 }
local LM_TRAIT_OFFSETS = { bless = { 280 }, perk = { 370 } }

local function make_loadout_monitor_widget_def(node_name)
    -- Copied structurally from LoadoutMonitor's playerloadout_definition, but:
    -- - mod.text_color -> LM_TEXT_COLOR (because here `mod` is RingHud, not LoadoutMonitor)
    -- - trait_offsets  -> LM_TRAIT_OFFSETS
    return UIWidget.create_definition(
        {
            {
                pass_type = "text",
                value_id = "loadout_intel_Feats",
                style_id = "loadout_intel_Feats",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 0, 11.5, 150 },
                    size = { 500, 100 },
                    text_color = Color.golden_rod(255, true),
                    font_size = 18,
                },

            },
            {
                pass_type = "texture",
                value_id = "loadout_intel_icon_1",
                style_id = "loadout_intel_icon_1",
                value = "content/ui/materials/icons/talents/talent_icon_container",
                style = {
                    vertical_alignment = "top",
                    horizontal_alignment = "left",
                    offset = { 200, 0, 150 },
                    size = { 36, 36 },
                    color = Color.aqua(0, true),
                    material_values = {
                        icon_texture = "",
                        intensity = 1,
                    },
                },
            },
            {
                pass_type = "texture",
                value_id = "loadout_intel_icon_2",
                style_id = "loadout_intel_icon_2",
                value = "content/ui/materials/icons/talents/talent_icon_container",
                style = {
                    vertical_alignment = "top",
                    horizontal_alignment = "left",
                    offset = { 200, 0, 150 },
                    size = { 36, 36 },
                    color = Color.aqua(0, true),
                    material_values = {
                        icon_texture = "",
                        intensity = 1,
                    },
                },
            },
            {
                pass_type = "texture",
                value_id = "loadout_intel_icon_3",
                style_id = "loadout_intel_icon_3",
                value = "content/ui/materials/icons/talents/talent_icon_container",
                style = {
                    vertical_alignment = "top",
                    horizontal_alignment = "left",
                    offset = { 200, 0, 150 },
                    size = { 36, 36 },
                    color = Color.aqua(0, true),
                    material_values = {
                        icon_texture = "",
                        intensity = 1,
                    },
                },
            },
            {
                pass_type = "texture",
                value_id = "loadout_intel_icon_4",
                style_id = "loadout_intel_icon_4",
                value = "content/ui/materials/icons/talents/talent_icon_container",
                style = {
                    vertical_alignment = "top",
                    horizontal_alignment = "left",
                    offset = { 200, 0, 150 },
                    size = { 36, 36 },
                    color = Color.aqua(0, true),
                    material_values = {
                        icon_texture = "",
                        intensity = 1,
                    },
                },
            },
            {
                pass_type = "texture",
                value_id = "loadout_intel_icon_5",
                style_id = "loadout_intel_icon_5",
                value = "content/ui/materials/icons/talents/talent_icon_container",
                style = {
                    vertical_alignment = "top",
                    horizontal_alignment = "left",
                    offset = { 200, 0, 150 },
                    size = { 36, 36 },
                    color = Color.aqua(0, true),
                    material_values = {
                        icon_texture = "",
                        intensity = 1,
                    },
                },
            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Class",
                style_id = "loadout_intel_Class",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 105, 6.5, 150 },
                    size = { 500, 100 },
                    text_color = Color.golden_rod(255, true),
                    font_size = 18,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_PlayerName",
                style_id = "loadout_intel_PlayerName",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 300, 6.5, 150 },
                    size = { 500, 100 },
                    text_color = Color.golden_rod(255, true),
                    font_size = 18,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_companion_name",
                style_id = "loadout_intel_companion_name",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 300, 6.5, 150 },
                    size = { 500, 100 },
                    text_color = Color.golden_rod(255, true),
                    font_size = 18,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Melee",
                style_id = "loadout_intel_Melee",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 0, 29.5, 200 },
                    size = { 275, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 20,
                    line_spacing = 0.8,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Melee_bless_1",
                style_id = "loadout_intel_Melee_bless_1",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { LM_TRAIT_OFFSETS.bless[1], 22.5, 200 },
                    size = { 500, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Melee_bless_2",
                style_id = "loadout_intel_Melee_bless_2",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { LM_TRAIT_OFFSETS.bless[1], 38.5, 200 },
                    size = { 500, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Melee_perk_1",
                style_id = "loadout_intel_Melee_perk_1",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 370, 23, 200 },
                    size = { 275, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Melee_perk_2",
                style_id = "loadout_intel_Melee_perk_2",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 370, 39, 200 },
                    size = { 500, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Range",
                style_id = "loadout_intel_Range",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 0, 59.5, 200 },
                    size = { 275, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 20,
                    line_spacing = 0.8,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Range_bless_1",
                style_id = "loadout_intel_Range_bless_1",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { LM_TRAIT_OFFSETS.bless[1], 57, 200 },
                    size = { 500, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Range_bless_2",
                style_id = "loadout_intel_Range_bless_2",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { LM_TRAIT_OFFSETS.bless[1], 72, 200 },
                    size = { 500, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Range_perk_1",
                style_id = "loadout_intel_Range_perk_1",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 370, 57, 200 },
                    size = { 500, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
            {
                pass_type = "text",
                value_id = "loadout_intel_Range_perk_2",
                style_id = "loadout_intel_Range_perk_2",
                value = " ",
                style = {
                    vertical_alignment = "top",
                    text_vertical_alignment = "top",
                    horizontal_alignment = "left",
                    text_horizontal_alignment = "left",
                    offset = { 370, 72, 200 },
                    size = { 500, 100 },
                    text_color = LM_TEXT_COLOR,
                    font_size = 14,
                },

            },
        },
        node_name
    )
end

function W.build_definitions()
    local scenegraph_definition = { screen = UIWorkspaceSettings.screen }
    local widget_definitions    = {}

    local BASE_Y                = (C.START_Y or 650) + STACK_Y_OFFSET
    local axis                  = mod._settings and mod._settings.team_docked_axis or "vertical"

    local off_x                 = (mod._settings and mod._settings.team_hud_offset_x) or 0
    local off_y                 = (mod._settings and mod._settings.team_hud_offset_y) or 0

    local has_loadout_monitor   = (mod._compat_loadout_monitor ~= nil and mod._compat_loadout_monitor ~= false)

    for i = 1, 3 do
        local base         = string.format("rh_team_%d", i)
        local group_node   = base .. "_group"
        local tile_node    = base .. "_tile_node"
        local name_node    = base .. "_name_node"
        local loadout_node = base .. "_loadout_node"

        local align_h, align_v, px, py

        if axis == "horizontal" then
            align_h = "center"
            align_v = "bottom"
            py      = -0.25 * C.TILE_SIZE
            if i == 1 then
                px = 0
            elseif i == 2 then
                px = -1 * C.TILE_SIZE
            else
                px = 1 * C.TILE_SIZE
            end
        else
            align_h = "left"
            align_v = "top"
            px      = C.START_X
            py      = BASE_Y - (i - 1) * GAP_Y
        end

        scenegraph_definition[group_node] = {
            parent               = "screen",
            vertical_alignment   = align_v,
            horizontal_alignment = align_h,
            size                 = { C.TILE_SIZE, C.TILE_SIZE },
            position             = { px + off_x, py + off_y, 20 + i },
        }

        scenegraph_definition[tile_node] = {
            parent               = group_node,
            vertical_alignment   = "top",
            horizontal_alignment = "left",
            size                 = { C.TILE_SIZE, C.TILE_SIZE },
            position             = { 0, 0, 0 },
        }

        scenegraph_definition[name_node] = {
            parent               = group_node,
            vertical_alignment   = "top",
            horizontal_alignment = "left",
            size                 = { C.TILE_SIZE, C.TILE_SIZE / 8 },
            position             = { 0, C.TILE_SIZE / 4, 40 },
        }

        if has_loadout_monitor then
            -- Attach the LM panel to the *group* so it can extend beyond the tile.
            scenegraph_definition[loadout_node] = {
                parent               = group_node,
                vertical_alignment   = "top",
                horizontal_alignment = "left",
                size                 = { 500, 100 },
                position             = { C.TILE_SIZE + 10, -12, 60 },
            }
        end

        local tile_widget_name               = string.format("rh_team_tile_%d", i)
        local name_widget_name               = string.format("rh_team_name_%d", i)
        local loadout_widget_name            = string.format("rh_team_loadout_%d", i)

        widget_definitions[tile_widget_name] = make_tile_only_widget_def(tile_node)
        widget_definitions[name_widget_name] = make_name_only_widget_def(name_node)

        if has_loadout_monitor then
            widget_definitions[loadout_widget_name] = make_loadout_monitor_widget_def(loadout_node)
        end
    end

    return {
        scenegraph_definition = scenegraph_definition,
        widget_definitions    = widget_definitions,
    }
end

return W
