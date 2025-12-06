-- File: RingHud/scripts/mods/RingHud/team/widgets_marker.lua
-- Purpose: Build a SINGLE teammate tile widget definition for world-markers,
--          reusing the docked visuals but as one widget for HEWM.
--
-- Notes:
-- - Sizes come from C.* (which are pre-scaled); if `scale ~= 1`, we allow the
--   caller to additionally scale size and inversely scale offsets so the
--   center anchor doesn’t drift.
-- - World-marker distance scaling uses style.default_* baselines. We populate
--   default_size/default_offset/default_pivot/default_font_size so the engine
--   can scale the widget cleanly at runtime.

local mod = get_mod("RingHud"); if not mod then return {} end

local UIWidget       = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

local C              = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")
local U              = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

--========================
-- Small helpers / guards
--========================

-- RGBA (0..1) fallback to opaque white if palette entry is missing.
local function _rgba_or_white(t)
    if type(t) == "table" then
        -- copy to avoid sharing the same table across widgets
        return { t[1] or 1, t[2] or 1, t[3] or 1, t[4] or 1 }
    end
    return { 1, 1, 1, 1 }
end

-- ARGB-255 fallback to white if palette entry is missing.
local function _argb_or_white255(t)
    if type(t) == "table" then
        return { t[1] or 255, t[2] or 255, t[3] or 255, t[4] or 255 }
    end
    local white = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 }
    return { white[1], white[2], white[3], white[4] }
end

-- Multiply size by `s`; multiply offset by inverse(s) so the center anchor
-- doesn’t drift when scaling. Also scale pivot & font_size to keep visuals true.
local function _apply_scale_and_offset(style, s)
    if not style or not s or s == 1 then return end
    local inv = (s ~= 0) and (1 / s) or 1

    if style.size then
        if type(style.size[1]) == "number" then style.size[1] = style.size[1] * s end
        if type(style.size[2]) == "number" then style.size[2] = style.size[2] * s end
    end
    if style.offset then
        if type(style.offset[1]) == "number" then style.offset[1] = style.offset[1] * inv end
        if type(style.offset[2]) == "number" then style.offset[2] = style.offset[2] * inv end
    end
    if style.pivot then
        if type(style.pivot[1]) == "number" then style.pivot[1] = style.pivot[1] * s end
        if type(style.pivot[2]) == "number" then style.pivot[2] = style.pivot[2] * s end
    end
    if style.font_size and type(style.font_size) == "number" then
        style.font_size = style.font_size * s
    end
end

-- After all style values are finalized (including any caller scale),
-- capture defaults so the world-marker system can apply distance scaling.
local function _ensure_default_scalables(style_table)
    if not style_table then return end
    for _, st in pairs(style_table) do
        if st.size and not st.default_size then
            st.default_size = { st.size[1], st.size[2] }
        end
        if st.offset and not st.default_offset then
            st.default_offset = { st.offset[1], st.offset[2] }
        end
        if st.pivot and not st.default_pivot then
            st.default_pivot = { st.pivot[1], st.pivot[2] }
        end
        if st.font_size and not st.default_font_size then
            st.default_font_size = st.font_size
        end
    end
end

local W = {}

-- Creates a single world-marker widget definition that visually matches a
-- docked team tile (ring + segments + icons + texts).
function W.build_marker_definitions(scale, scenegraph_id)
    -- IMPORTANT: `C` already encodes the cached scale; default to 1 here.
    local s       = tonumber(scale) or 1.0

    -- CONTENT ---------------------------------------------------------
    local content = {
        -- TL compatibility: vanilla nameplate key some mods read/patch
        header_text            = "",

        status_icon            = nil, -- runtime material path (applier fills)
        status_icon_tint       = nil, -- runtime tint RGBA (applier fills)
        arch_icon              = "?",
        name_text_value        = "",

        -- Ledge/assist progress (coarse + per-pass gates)
        ledge_bar_visible      = false,
        ledge_bar_base_visible = false,
        ledge_bar_edge_visible = false,

        throwable_icon         = nil,
        crate_icon             = nil,
        stimm_icon             = nil,
        reserve_text_value     = "",
        ability_cd_text        = "",
        toughness_text_value   = "",
        health_value_text      = "",
    }

    -- PASSES ----------------------------------------------------------
    local passes  = {}
    local style   = {}

    local function add_pass(p)
        passes[#passes + 1] = p

        -- Style table registration for this style_id (no cloning of nil)
        if p.style_id and p.style then
            style[p.style_id] = p.style
        end

        -- Initialize content slot types for new value_ids to avoid nil surprises
        if p.value_id and content[p.value_id] == nil then
            if p.pass_type == "text" then
                content[p.value_id] = ""
            elseif p.pass_type == "texture" or p.pass_type == "rotated_texture" then
                content[p.value_id] = content[p.value_id] or nil
            else
                content[p.value_id] = false
            end
        end
    end

    -- Health segments (base) — outline uses material RGBA teal
    -- NOTE: Build up to C.MAX_HP_SEGMENTS (one extra pass reserved for the split/"notch").
    for i = 1, C.MAX_HP_SEGMENTS do
        local cid = string.format("hp_seg_%d_visible", i)
        content[cid] = false
        add_pass({
            pass_type            = "rotated_texture",
            value                = "content/ui/materials/effects/forcesword_bar",
            style_id             = string.format("hp_seg_%d", i),
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            visibility_function  = function(c) return c[cid] end,
            style                = {
                uvs                  = { { 0, 1 }, { 1, 0 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { C.TILE_SIZE / 16, -C.TILE_SIZE / 5.7, 1 }, -- 12.5, -35.1
                size                 = { C.ARC_SIZE, C.ARC_SIZE },                  -- 200, 200
                pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },              -- 100, 200
                angle                = 0,
                color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or
                    { 255, 255, 255, 255 }, -- ARGB-255
                material_values      = {
                    amount               = 0,
                    -- Clamp index so seg_arc_range never goes OOB for the extra (+1) pass.
                    arc_top_bottom       = U.seg_arc_range(math.min(i, C.MAX_WOUNDS_CAP), C.MAX_WOUNDS_CAP),
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = _rgba_or_white(mod.PALETTE_RGBA1 and
                        mod.PALETTE_RGBA1.default_toughness_color_rgba), -- RGBA 0..1
                    lightning_opacity    = 0,
                    glow_on_off          = 0,
                },
            }
        })
    end

    -- Corruption overlay segments (on top) — outline uses material RGBA purple
    -- NOTE: Stays at C.MAX_WOUNDS_CAP (unsplit).
    for i = 1, C.MAX_WOUNDS_CAP do
        local cid = string.format("cor_seg_%d_visible", i)
        content[cid] = false
        add_pass({
            pass_type            = "rotated_texture",
            value                = "content/ui/materials/effects/forcesword_bar",
            style_id             = string.format("cor_seg_%d", i),
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            visibility_function  = function(c) return c[cid] end,
            style                = {
                uvs                  = { { 0, 1 }, { 1, 0 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { C.TILE_SIZE / 16, -C.TILE_SIZE / 5.7, 2 }, -- 12.5, -35.1
                size                 = { C.ARC_SIZE, C.ARC_SIZE },                  -- 200, 200
                pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },              -- 100, 200
                angle                = 0,
                color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or
                    { 255, 255, 255, 255 }, -- ARGB-255
                material_values      = {
                    amount               = 1,
                    arc_top_bottom       = U.seg_arc_range(i, C.MAX_WOUNDS_CAP),
                    fill_outline_opacity = { 0.7, 1.3 },
                    outline_color        = _rgba_or_white(mod.PALETTE_RGBA1 and
                        mod.PALETTE_RGBA1.default_corruption_color_rgba), -- RGBA 0..1
                    lightning_opacity    = 0,
                    glow_on_off          = 0,
                },
            }
        })
    end

    -- Archetype icon
    add_pass({
        pass_type            = "text",
        value_id             = "arch_icon",
        style_id             = "arch_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c) return c.status_icon == nil end,
        style                = {
            font_type                 = "machine_medium",
            drop_shadow               = true,
            font_size                 = C.TILE_SIZE / 5.5, -- 36.4
            horizontal_alignment      = "center",
            vertical_alignment        = "center",
            text_horizontal_alignment = "center",
            text_vertical_alignment   = "center",
            size                      = { C.TILE_SIZE, C.TILE_SIZE },                 -- 200, 200
            offset                    = { C.TILE_SIZE / 80, -C.TILE_SIZE / 16.7, 3 }, -- 2.5, -12
            text_color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or
                { 255, 255, 255, 255 },
        }
    })

    -- Status icon (replaces archetype while active)
    add_pass({
        pass_type            = "texture",
        value_id             = "status_icon", -- runtime material path
        style_id             = "status_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c) return c.status_icon ~= nil end,
        style                = {
            font_type            = "machine_medium",
            font_size            = C.TILE_SIZE / 5.5, -- 36.4
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.TILE_SIZE / 3.8, C.TILE_SIZE / 3.8 },                                              -- 52.6, 52.6
            offset               = { C.TILE_SIZE / 80, -C.TILE_SIZE / 16.7, 4 },                                          -- 2.5, -12
            color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 }, -- applier may override
        }
    })

    -- Teammate name (above the glyph)
    add_pass({
        pass_type            = "text",
        value_id             = "name_text_value",
        style_id             = "name_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        -- Belt-and-braces: ONLY draw in strict floating; if not, hard-blank.
        visibility_function  = function(c)
            local strict = (mod and mod._settings and mod._settings.team_hud_mode == "team_hud_floating")
            if not strict then
                if c.name_text_value ~= "" then
                    c.name_text_value = "" -- side-effect: ensure blank in non-floating modes
                end
                return false
            end
            return type(c.name_text_value) == "string" and c.name_text_value ~= ""
        end,
        style                = (function()
            local s_                     = table.clone(UIFontSettings.body_small)
            s_.font_type                 = "proxima_nova_bold"
            s_.text_horizontal_alignment = "center"
            s_.text_vertical_alignment   = "bottom"
            s_.horizontal_alignment      = "center"
            s_.vertical_alignment        = "center"
            s_.size                      = { C.TILE_SIZE, C.TILE_SIZE / 12 } -- 200, 16.7
            s_.offset                    = { 0, -C.TILE_SIZE / 2.9, 5 }      -- 0, -69
            s_.text_color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or
                { 255, 255, 255, 255 }
            s_.drop_shadow               = true
            s_.font_size                 = C.TILE_SIZE / 13.5 -- 14.8
            s_.visible                   = true
            return s_
        end)(),
    })

    -- Throwable (grenade)
    add_pass({
        pass_type            = "texture",
        value_id             = "throwable_icon",
        value                = "content/ui/materials/hud/icons/party_throwable",
        style_id             = "throwable_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = {
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.THROWABLE_ICON_SIZE, C.THROWABLE_ICON_SIZE },
            offset               = { -C.TILE_SIZE / 9, -C.TILE_SIZE / 25, 6 }, -- -22.2, -8
            color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 },
            visible              = false,
        }
    })

    -- Crate icon
    add_pass({
        pass_type            = "texture",
        value_id             = "crate_icon",
        style_id             = "crate_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = {
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.CRATE_ICON_SIZE, C.CRATE_ICON_SIZE },
            offset               = { C.TILE_SIZE / 7.25, -C.TILE_SIZE / 25, 7 }, -- 22.2, -8
            color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 },
            visible              = false,
        }
    })

    -- Stimm icon (auxiliary; kept for potential future use)
    add_pass({
        pass_type            = "texture",
        value_id             = "stimm_icon",
        style_id             = "stimm_icon",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = {
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            size                 = { C.STIMM_ICON_SIZE, C.STIMM_ICON_SIZE },
            offset               = { C.TILE_SIZE / 7.25, -C.TILE_SIZE / 9, 8 }, -- 27.6, -22.2
            color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 },
            visible              = false,
        }
    })

    -- Ammo reserve % (left) — default hidden; TXT.update_ammo drives visibility.
    add_pass({
        pass_type            = "text",
        value_id             = "reserve_text_value",
        style_id             = "reserve_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s_                     = table.clone(UIFontSettings.body_small)
            s_.text_horizontal_alignment = "center"
            s_.text_vertical_alignment   = "center"
            s_.horizontal_alignment      = "center"
            s_.vertical_alignment        = "center"
            s_.size                      = { C.TILE_SIZE, C.TILE_SIZE / 13.5 }         -- 200, 14.8
            s_.offset                    = { -C.TILE_SIZE / 4, -C.TILE_SIZE / 25, 12 } -- -50, -8
            local ammo_col               = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH)
            s_.text_color                = _argb_or_white255(ammo_col)                 -- ARGB-255
            s_.font_size                 = C.TILE_SIZE / 11                            -- 18.8
            s_.drop_shadow               = true
            s_.visible                   = false
            return s_
        end)(),
    })

    -- Ability cooldown (right) — default hidden; TXT.update_ability_cd drives visibility.
    add_pass({
        pass_type            = "text",
        value_id             = "ability_cd_text",
        style_id             = "ability_cd_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s_                     = table.clone(UIFontSettings.body_small)
            s_.text_horizontal_alignment = "center"
            s_.text_vertical_alignment   = "center"
            s_.horizontal_alignment      = "center"
            s_.vertical_alignment        = "center"
            s_.size                      = { C.TILE_SIZE, C.TILE_SIZE / 13.5 }        -- 200, 14.8
            s_.offset                    = { C.TILE_SIZE / 4, -C.TILE_SIZE / 25, 11 } -- 50, -8
            s_.text_color                = C.ABILITY_CD_TEXT_COLOR                    -- ARGB-255
            s_.font_size                 = C.TILE_SIZE / 11                           -- 18.8
            s_.drop_shadow               = true
            s_.visible                   = false
            return s_
        end)(),
    })

    -- Toughness integer (right, below) — default hidden; applier drives visibility.
    add_pass({
        pass_type            = "text",
        value_id             = "toughness_text_value",
        style_id             = "toughness_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s_                     = table.clone(UIFontSettings.body_small)
            s_.text_horizontal_alignment = "center"
            s_.text_vertical_alignment   = "center"
            s_.horizontal_alignment      = "center"
            s_.vertical_alignment        = "center"
            s_.size                      = { C.TILE_SIZE / 3, C.TILE_SIZE / 12 }       -- 66.7, 16.7
            s_.offset                    = { C.TILE_SIZE / 4, -C.TILE_SIZE / 4.5, 10 } -- 50, -45.4
            s_.text_color                = { 255, 108, 187, 196 }                      -- ARGB teal
            s_.font_size                 = C.TILE_SIZE / 12                            -- 16.7
            s_.drop_shadow               = true
            s_.visible                   = false                                       -- start hidden
            return s_
        end)(),
    })

    -- Health integer (left, below) — default hidden; applier drives visibility.
    add_pass({
        pass_type            = "text",
        value_id             = "health_value_text",
        style_id             = "health_value_text_style",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        style                = (function()
            local s_                     = table.clone(UIFontSettings.body_small)
            s_.text_horizontal_alignment = "center"
            s_.text_vertical_alignment   = "center"
            s_.horizontal_alignment      = "center"
            s_.vertical_alignment        = "center"
            s_.size                      = { C.TILE_SIZE / 3, C.TILE_SIZE / 12 }       -- 66.7, 16.7
            s_.offset                    = { -C.TILE_SIZE / 4, -C.TILE_SIZE / 4.5, 9 } -- -50, -45.4
            s_.text_color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or
                { 255, 255, 255, 255 }
            s_.font_size                 = C.TILE_SIZE / 12 -- 16.7
            s_.drop_shadow               = true
            s_.visible                   = false
            return s_
        end)(),
    })

    -- Ledge/pull-up/respawn bar (SPLIT: base + edge). These are driven by the applier:
    -- - base: amount = 1, arc => [bottom .. edge - half_gap]
    -- - edge: amount = 0, arc => [edge + half_gap .. top]
    add_pass({
        pass_type            = "rotated_texture",
        value                = "content/ui/materials/effects/forcesword_bar",
        style_id             = "ledge_bar_base",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c)
            return c.ledge_bar_visible and c.ledge_bar_base_visible
        end,
        style                = {
            uvs                  = { { 0, 1 }, { 1, 0 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { C.TILE_SIZE / 16, -C.TILE_SIZE / 5.7, 13 },
            size                 = { C.ARC_SIZE, C.ARC_SIZE },
            pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },
            angle                = 0,
            color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 },
            material_values      = {
                amount               = 1,
                arc_top_bottom       = U.seg_arc_range(1, 1),
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = _rgba_or_white(mod.PALETTE_RGBA1 and
                    mod.PALETTE_RGBA1.dodge_color_negative_rgba),
                lightning_opacity    = 0,
                glow_on_off          = 0,
            },
        }
    })

    add_pass({
        pass_type            = "rotated_texture",
        value                = "content/ui/materials/effects/forcesword_bar",
        style_id             = "ledge_bar_edge",
        horizontal_alignment = "center",
        vertical_alignment   = "center",
        visibility_function  = function(c)
            return c.ledge_bar_visible and c.ledge_bar_edge_visible
        end,
        style                = {
            uvs                  = { { 0, 1 }, { 1, 0 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { C.TILE_SIZE / 16, -C.TILE_SIZE / 5.7, 14 }, -- above base
            size                 = { C.ARC_SIZE, C.ARC_SIZE },
            pivot                = { C.ARC_SIZE / 2, C.ARC_SIZE },
            angle                = 0,
            color                = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 },
            material_values      = {
                amount               = 0,
                arc_top_bottom       = U.seg_arc_range(1, 1),
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = _rgba_or_white(mod.PALETTE_RGBA1 and
                    mod.PALETTE_RGBA1.dodge_color_negative_rgba),
                lightning_opacity    = 0,
                glow_on_off          = 0,
            },
        }
    })

    -- SCALE & OFFSET COMPENSATION ------------------------------------
    if s ~= 1 then
        for _, st in pairs(style) do
            _apply_scale_and_offset(st, s)
        end
    end

    -- Capture default_* AFTER any static scaling so distance scaling
    -- uses these as the baseline.
    _ensure_default_scalables(style)

    -- RETURN A PROPER UIWidget DEFINITION -----------------------------
    return UIWidget.create_definition(passes, scenegraph_id or "screen", content, style)
end

return W
