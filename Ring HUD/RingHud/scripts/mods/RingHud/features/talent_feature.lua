-- File: RingHud/scripts/mods/RingHud/features/talent_feature.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local UIWidget                = require("scripts/managers/ui/ui_widget")
local U                       = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local Notch                   = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local TalentFeature           = {}

local SETTINGS                = mod._settings
local EPS                     = mod.NOTCH_EPSILON or 1e-4

-- Using standard UVs { {0,0}, {1,1} } for RingHud right-side bars
local TALENT_ARC_MIN          = 0.51
local TALENT_ARC_MAX          = 0.98

-- Psyker segmented talent (Empowered Grenades)
local PSYKER_TALENT_SEGMENTS  = 3

-- Adamant segmented talent (Terminus Warrant: 2 ranged + 2 melee)
local ADAMANT_TALENT_SEGMENTS = 4
local ADAMANT_SEGMENT_STACKS  = 15
local ADAMANT_MAX_STACKS      = 30

-- Match the dual-shivs segment gap (ChargeFeature uses SEG2_BOTTOM - SEG1_TOP).
local SEGMENT_GAP             = 0.03

local _psyker_style_keys      = {}
for i = 1, PSYKER_TALENT_SEGMENTS do
    _psyker_style_keys[i] = "talent_seg_" .. i
end

local _adamant_style_keys_base = {}
local _adamant_style_keys_edge = {}
for i = 1, ADAMANT_TALENT_SEGMENTS do
    _adamant_style_keys_base[i] = "talent_adamant_seg_" .. i
    _adamant_style_keys_edge[i] = "talent_adamant_seg_" .. i .. "_edge"
end

local function _compute_segment_arcs(num_segments)
    local arcs         = {}
    local total_arc    = TALENT_ARC_MAX - TALENT_ARC_MIN
    local num_gaps     = math.max(0, num_segments - 1)
    local gap_space    = num_gaps * SEGMENT_GAP
    local visual_space = math.max(0, total_arc - gap_space)
    local seg_arc      = (visual_space / num_segments)
    local current_bot  = TALENT_ARC_MIN

    for i = 1, num_segments do
        local top = math.min(TALENT_ARC_MAX, current_bot + seg_arc)
        if i == num_segments then
            top = TALENT_ARC_MAX
        end
        arcs[i] = { top, current_bot } -- {top, bottom}
        current_bot = top + SEGMENT_GAP
    end

    return arcs
end

local PSYKER_ARCS  = _compute_segment_arcs(PSYKER_TALENT_SEGMENTS)
local ADAMANT_ARCS = _compute_segment_arcs(ADAMANT_TALENT_SEGMENTS)

local function _fast_hide_all(widget, style)
    local changed = false
    -- Standard bars
    if style.talent_bar and style.talent_bar.visible then
        style.talent_bar.visible = false; changed = true
    end
    if style.talent_bar_edge and style.talent_bar_edge.visible then
        style.talent_bar_edge.visible = false; changed = true
    end

    -- Psyker segments
    for i = 1, PSYKER_TALENT_SEGMENTS do
        local seg = style[_psyker_style_keys[i]]
        if seg and seg.visible then
            seg.visible = false; changed = true
        end
    end

    -- Adamant segments
    for i = 1, ADAMANT_TALENT_SEGMENTS do
        local base = style[_adamant_style_keys_base[i]]
        local edge = style[_adamant_style_keys_edge[i]]
        if base and base.visible then
            base.visible = false; changed = true
        end
        if edge and edge.visible then
            edge.visible = false; changed = true
        end
    end

    if changed then widget.dirty = true end
end

local function _hide_psyker_segments(style)
    local changed = false
    for i = 1, PSYKER_TALENT_SEGMENTS do
        local seg = style[_psyker_style_keys[i]]
        if seg and seg.visible then
            seg.visible = false; changed = true
        end
    end
    return changed
end

local function _hide_adamant_segments(style)
    local changed = false
    for i = 1, ADAMANT_TALENT_SEGMENTS do
        local base = style[_adamant_style_keys_base[i]]
        local edge = style[_adamant_style_keys_edge[i]]
        if base and base.visible then
            base.visible = false; changed = true
        end
        if edge and edge.visible then
            edge.visible = false; changed = true
        end
    end
    return changed
end

local function _hide_standard_passes(style)
    local changed = false
    if style.talent_bar and style.talent_bar.visible then
        style.talent_bar.visible = false; changed = true
    end
    if style.talent_bar_edge and style.talent_bar_edge.visible then
        style.talent_bar_edge.visible = false; changed = true
    end
    return changed
end

local function _write_simple_segment(seg_style, seg_top, seg_bottom, amount, visible, changed)
    if not seg_style or not seg_style.material_values then
        return changed
    end

    local mv = seg_style.material_values
    amount   = (amount == 1) and 1 or 0

    if mv.amount ~= amount then
        mv.amount = amount
        changed = true
    end

    changed = U.mv_set_arc(mv, seg_top, seg_bottom, changed)
    changed = U.set_style_visible(seg_style, visible == true, changed)

    return changed
end

local function _restore_outline_default(style, changed)
    if not (style and style.material_values) then
        return changed
    end
    local def = style.__ringhud_outline_default
    if def then
        changed = U.mv_set_outline(style.material_values, def, changed)
    end
    return changed
end

local function _set_outline_override(style, rgba, changed)
    if rgba and style and style.material_values then
        changed = U.mv_set_outline(style.material_values, rgba, changed)
    end
    return changed
end

local function _write_notched_segment(base_style, edge_style, seg_top, seg_bottom, fraction, show, partial_outline_rgba,
                                      changed)
    if not base_style or not edge_style then return changed end
    if not base_style.material_values or not edge_style.material_values then return changed end

    if show ~= true then
        changed = U.set_style_visible(base_style, false, changed)
        changed = U.set_style_visible(edge_style, false, changed)
        return changed
    end

    fraction = math.clamp(tonumber(fraction) or 0, 0, 1)

    -- Empty segments hidden
    if fraction <= EPS then
        changed = U.set_style_visible(base_style, false, changed)
        changed = U.set_style_visible(edge_style, false, changed)
        return changed
    end

    -- Full segment (no notch) -> restore default outline colour
    if fraction >= 1 - EPS then
        changed = _restore_outline_default(base_style, changed)
        changed = _restore_outline_default(edge_style, changed)

        local mv_base = base_style.material_values
        if mv_base.amount ~= 1 then
            mv_base.amount = 1; changed = true
        end
        changed = U.mv_set_arc(mv_base, seg_top, seg_bottom, changed)
        changed = U.set_style_visible(base_style, true, changed)

        local mv_edge = edge_style.material_values
        if mv_edge.amount ~= 0 then
            mv_edge.amount = 0; changed = true
        end
        changed = U.set_style_visible(edge_style, false, changed)

        return changed
    end

    -- Partial -> outline override colour on BOTH passes
    changed = _set_outline_override(base_style, partial_outline_rgba, changed)
    changed = _set_outline_override(edge_style, partial_outline_rgba, changed)

    -- Partial: split into filled base + outline-only leading edge sliver
    local r = Notch.notch_split(seg_top, seg_bottom, fraction)

    local mv_base = base_style.material_values
    if mv_base.amount ~= 1 then
        mv_base.amount = 1; changed = true
    end
    changed = U.mv_set_arc(mv_base, r.base.top, r.base.bottom, changed)
    changed = U.set_style_visible(base_style, r.base.show, changed)

    local mv_edge = edge_style.material_values
    if mv_edge.amount ~= 0 then
        mv_edge.amount = 0; changed = true
    end
    changed = U.mv_set_arc(mv_edge, r.edge.top, r.edge.bottom, changed)
    changed = U.set_style_visible(edge_style, r.edge.show, changed)

    return changed
end

-- ============================================================
-- Adamant Update Logic
-- ============================================================
local function _update_adamant(widget, style, data, force_show, partial_outline_rgba)
    local changed          = _hide_standard_passes(style)
    changed                = _hide_psyker_segments(style) or changed

    local melee_stacks     = math.clamp(tonumber(data and data.adamant_tw_melee_stacks) or 0, 0, ADAMANT_MAX_STACKS)
    local ranged_stacks    = math.clamp(tonumber(data and data.adamant_tw_ranged_stacks) or 0, 0, ADAMANT_MAX_STACKS)

    -- Show gating (empty hidden)
    local ranged_seg1_show = ranged_stacks > 0
    local ranged_seg2_show = ranged_stacks > ADAMANT_SEGMENT_STACKS
    local melee_seg3_show  = melee_stacks > 0
    local melee_seg4_show  = melee_stacks > ADAMANT_SEGMENT_STACKS

    -- Fractions per segment (0..15, 16..30)
    local ranged_seg1_frac = math.clamp(ranged_stacks / ADAMANT_SEGMENT_STACKS, 0, 1)
    local ranged_seg2_frac = math.clamp((ranged_stacks - ADAMANT_SEGMENT_STACKS) / ADAMANT_SEGMENT_STACKS, 0, 1)
    local melee_seg3_frac  = math.clamp(melee_stacks / ADAMANT_SEGMENT_STACKS, 0, 1)
    local melee_seg4_frac  = math.clamp((melee_stacks - ADAMANT_SEGMENT_STACKS) / ADAMANT_SEGMENT_STACKS, 0, 1)

    -- Segment 1 (ranged 0..15)
    changed                = _write_notched_segment(style.talent_adamant_seg_1, style.talent_adamant_seg_1_edge,
        ADAMANT_ARCS[1][1], ADAMANT_ARCS[1][2], ranged_seg1_frac, ranged_seg1_show, partial_outline_rgba, changed)

    -- Segment 2 (ranged 16..30)
    changed                = _write_notched_segment(style.talent_adamant_seg_2, style.talent_adamant_seg_2_edge,
        ADAMANT_ARCS[2][1], ADAMANT_ARCS[2][2], ranged_seg2_frac, ranged_seg2_show, partial_outline_rgba, changed)

    -- Segment 3 (melee 0..15)
    changed                = _write_notched_segment(style.talent_adamant_seg_3, style.talent_adamant_seg_3_edge,
        ADAMANT_ARCS[3][1], ADAMANT_ARCS[3][2], melee_seg3_frac, melee_seg3_show, partial_outline_rgba, changed)

    -- Segment 4 (melee 16..30)
    changed                = _write_notched_segment(style.talent_adamant_seg_4, style.talent_adamant_seg_4_edge,
        ADAMANT_ARCS[4][1], ADAMANT_ARCS[4][2], melee_seg4_frac, melee_seg4_show, partial_outline_rgba, changed)

    if changed then widget.dirty = true end
end

-- ============================================================
-- Psyker Update Logic
-- ============================================================
local function _update_psyker(widget, style, data, force_show)
    local changed = _hide_standard_passes(style)
    changed = _hide_adamant_segments(style) or changed

    local stacks = math.clamp(tonumber(data and data.stacks) or 0, 0, PSYKER_TALENT_SEGMENTS)

    -- Force-show preview with 3 empty segments when no stacks are currently active
    if force_show and stacks == 0 then
        for i = 1, PSYKER_TALENT_SEGMENTS do
            local seg = style[_psyker_style_keys[i]]
            local arc = PSYKER_ARCS[i]
            if seg and arc then
                changed = _write_simple_segment(seg, arc[1], arc[2], 0, true, changed) or changed
            end
        end
    else
        -- Normal render: show exactly N segments (full)
        for i = 1, PSYKER_TALENT_SEGMENTS do
            local seg = style[_psyker_style_keys[i]]
            local arc = PSYKER_ARCS[i]
            if seg and arc then
                local show = (i <= stacks)
                changed = _write_simple_segment(seg, arc[1], arc[2], 1, show, changed) or changed
            end
        end
    end

    if changed then widget.dirty = true end
end

-- ============================================================
-- Standard Update Logic
-- ============================================================
local function _update_standard(widget, style, data, force_show)
    local changed = _hide_psyker_segments(style)
    changed = _hide_adamant_segments(style) or changed

    local base = style.talent_bar
    local edge = style.talent_bar_edge

    if not (base and edge) then
        if changed then widget.dirty = true end
        return
    end

    local fraction = tonumber(data and data.cooldown_fraction) or 0
    local display_fraction = math.clamp(fraction, 0, 1)
    local active = data and data.is_active or false
    local has_fraction = display_fraction > 0

    -- Force-show preview when not actively cooling down:
    -- render the full arc as an empty outline (no fill, no notch)
    if force_show and (not active) and (not has_fraction) then
        local mv_base = base.material_values
        if mv_base.amount ~= 0 then
            mv_base.amount = 0; changed = true
        end
        changed = U.mv_set_arc(mv_base, TALENT_ARC_MAX, TALENT_ARC_MIN, changed)
        changed = U.set_style_visible(base, true, changed)
        changed = U.set_style_visible(edge, false, changed)

        if changed then widget.dirty = true end
        return
    end

    -- EMPTY → outline only (full span), no notch
    if display_fraction <= EPS then
        local mv_base = base.material_values
        if mv_base.amount ~= 0 then
            mv_base.amount = 0; changed = true
        end
        changed = U.mv_set_arc(mv_base, TALENT_ARC_MAX, TALENT_ARC_MIN, changed)
        changed = U.set_style_visible(base, true, changed)

        local mv_edge = edge.material_values
        if mv_edge.amount ~= 0 then
            mv_edge.amount = 0; changed = true
        end
        changed = U.set_style_visible(edge, false, changed)

        if changed then widget.dirty = true end
        return
    end

    -- FULL → filled base over full span, no notch
    if display_fraction >= 1 - EPS then
        local mv_base = base.material_values
        if mv_base.amount ~= 1 then
            mv_base.amount = 1; changed = true
        end
        changed = U.mv_set_arc(mv_base, TALENT_ARC_MAX, TALENT_ARC_MIN, changed)
        changed = U.set_style_visible(base, true, changed)

        local mv_edge = edge.material_values
        if mv_edge.amount ~= 0 then
            mv_edge.amount = 0; changed = true
        end
        changed = U.set_style_visible(edge, false, changed)

        if changed then widget.dirty = true end
        return
    end

    -- PARTIAL → split into filled base and unfilled edge sliver
    local r = Notch.notch_split(TALENT_ARC_MAX, TALENT_ARC_MIN, display_fraction)

    -- Base (Filled)
    local mv_base = base.material_values
    if mv_base.amount ~= 1 then
        mv_base.amount = 1; changed = true
    end
    changed = U.mv_set_arc(mv_base, r.base.top, r.base.bottom, changed)
    changed = U.set_style_visible(base, r.base.show, changed)

    -- Edge (Leading Notch)
    local mv_edge = edge.material_values
    if mv_edge.amount ~= 0 then
        mv_edge.amount = 0; changed = true
    end
    changed = U.mv_set_arc(mv_edge, r.edge.top, r.edge.bottom, changed)
    changed = U.set_style_visible(edge, r.edge.show, changed)

    if changed then widget.dirty = true end
end

function TalentFeature.update(widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local setting = SETTINGS.timer_buff_dropdown
    local enabled = (setting == "all")

    if not enabled then
        _fast_hide_all(widget, widget.style)
        return
    end

    local data                 = hud_state and hud_state.talent_data or nil
    local mode                 = (data and data.mode) or "cooldown"
    local force_show           = hotkey_override == true

    local RGBA1                = mod.PALETTE_RGBA1
    local partial_outline_rgba = RGBA1 and RGBA1.default_damage_color_rgba or nil

    local stacks               = data and data.stacks or 0
    local active               = data and data.is_active or false
    local available            = data and data.is_available or false
    local fraction             = tonumber(data and data.cooldown_fraction) or 0
    local melee_stacks         = math.clamp(tonumber(data and data.adamant_tw_melee_stacks) or 0, 0, ADAMANT_MAX_STACKS)
    local ranged_stacks        = math.clamp(tonumber(data and data.adamant_tw_ranged_stacks) or 0, 0, ADAMANT_MAX_STACKS)

    local visible              = false

    if mode == "adamant_terminus_warrant" then
        visible = (melee_stacks > 0) or (ranged_stacks > 0)
    elseif mode == "psyker_empowered_grenades" then
        visible = (stacks > 0) or (force_show and available)
    else
        -- Standard Cooldown
        local has_fraction = fraction > 0
        visible = (active or has_fraction or (force_show and available))
    end

    if not visible then
        _fast_hide_all(widget, widget.style)
        return
    end

    -- Render
    if mode == "adamant_terminus_warrant" then
        _update_adamant(widget, widget.style, data, force_show, partial_outline_rgba)
    elseif mode == "psyker_empowered_grenades" then
        _update_psyker(widget, widget.style, data, force_show)
    else
        _update_standard(widget, widget.style, data, force_show)
    end
end

function TalentFeature.add_widgets(widget_defs, _, layout, palettes)
    local size             = (layout and layout.size) or { 240, 240 }
    local inner            = (layout and layout.inner_size_factor) or 0.8
    local parent_id        = (layout and layout.scenegraph_id) or "talent_bar"
    local ARGB             = (palettes and palettes.ARGB) or (mod.PALETTE_ARGB255 or {})
    local RGBA1            = (palettes and palettes.RGBA1) or (mod.PALETTE_RGBA1 or {})

    local inner_size       = { size[1] * inner, size[2] * inner }

    -- Outlines:
    --  • Default cooldown (Zealot + Broker countdown): same outline
    --  • Psyker segments: purple
    --  • Adamant Terminus Warrant: active (ranged) / inactive (melee)
    local zealot_outline   = table.clone(RGBA1.dodge_color_negative_rgba or { 1, 0, 0, 1 })
    local psyker_outline   = table.clone(RGBA1.GRIMOIRE_PURPLE or { 0.6, 0.2, 0.8, 1 })
    local adamant_inactive = table.clone(RGBA1.NEEDLE_SPECIAL_INACTIVE or { 0.75, 0.75, 0.75, 1 })
    local adamant_active   = table.clone(RGBA1.NEEDLE_SPECIAL_ACTIVE or { 0.2, 1.0, 0.8, 1 })

    local passes           = {
        -- Cooldown base
        {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_bar",
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 1 },
                size                 = inner_size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = 1,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MAX, TALENT_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = zealot_outline,
                },
            },
        },
        -- Cooldown notch edge
        {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_bar_edge",
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 2 },
                size                 = inner_size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MAX, TALENT_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(zealot_outline),
                },
            },
        },
    }

    -- Psyker segmented passes (3)
    for i = 1, PSYKER_TALENT_SEGMENTS do
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_seg_" .. i,
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 1 },
                size                 = inner_size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MIN, TALENT_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(psyker_outline),
                },
            },
        }
    end

    -- Adamant segmented passes (4 segments, each with a notch/edge split)
    -- NOTE: Seg 1-2 are RANGED (active), Seg 3-4 are MELEE (inactive)
    for i = 1, ADAMANT_TALENT_SEGMENTS do
        local outline = (i <= 2) and adamant_active or adamant_inactive

        -- Base (filled)
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_adamant_seg_" .. i,
            style     = {
                uvs                       = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment      = "center",
                vertical_alignment        = "center",
                offset                    = { 0, 0, 1 },
                size                      = inner_size,
                color                     = ARGB.GENERIC_WHITE,
                visible                   = false,
                pivot                     = { 0, 0 },
                angle                     = 0,
                __ringhud_outline_default = table.clone(outline),
                material_values           = {
                    amount               = 1,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MIN, TALENT_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(outline),
                },
            },
        }

        -- Edge (outline-only leading sliver)
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_adamant_seg_" .. i .. "_edge",
            style     = {
                uvs                       = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment      = "center",
                vertical_alignment        = "center",
                offset                    = { 0, 0, 2 },
                size                      = inner_size,
                color                     = ARGB.GENERIC_WHITE,
                visible                   = false,
                pivot                     = { 0, 0 },
                angle                     = 0,
                __ringhud_outline_default = table.clone(outline),
                material_values           = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MIN, TALENT_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(outline),
                },
            },
        }
    end

    widget_defs.talent_bar = UIWidget.create_definition(passes, parent_id)
end

return TalentFeature
