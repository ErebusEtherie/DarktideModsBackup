-- File: RingHud/scripts/mods/RingHud/features/talent_feature.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local UIWidget                = require("scripts/managers/ui/ui_widget")
local U                       = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local Notch                   = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local TalentFeature           = {}

local SETTINGS                = mod._settings
local EPS                     = mod.NOTCH_EPSILON or 1e-4

local PSYKER_TALENT_SEGMENTS  = 3

local ADAMANT_TALENT_SEGMENTS = 2
local ADAMANT_SEGMENT_STACKS  = 20
local ADAMANT_MAX_STACKS      = 20

local CRYPTIC_MAX_SEGMENTS    = 7

local OGRYN_BLO_MAX_STACKS     = 10
local OGRYN_BLO_BRIGHT_STACKS  = 9

local SEGMENT_GAP              = 0.03
local OGRYN_BLO_SEGMENT_GAP    = 0.012
local TALENT_ARC_MIN           = 0.49
local TALENT_ARC_MAX           = 0.98

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

local _cryptic_style_keys_base = {}
local _cryptic_style_keys_edge = {}
for i = 1, CRYPTIC_MAX_SEGMENTS do
    _cryptic_style_keys_base[i] = "talent_cryptic_seg_" .. i
    _cryptic_style_keys_edge[i] = "talent_cryptic_seg_" .. i .. "_edge"
end

local _ogryn_blo_style_keys = {}
for i = 1, OGRYN_BLO_MAX_STACKS do
    _ogryn_blo_style_keys[i] = "talent_ogryn_blo_seg_" .. i
end

local function _compute_segment_arcs(num_segments, lo, hi, segment_gap)
    local arcs         = {}
    local total_arc    = hi - lo
    local num_gaps     = math.max(0, num_segments - 1)
    local gap          = segment_gap or SEGMENT_GAP
    local gap_space    = num_gaps * gap
    local visual_space = math.max(0, total_arc - gap_space)
    local seg_arc      = (visual_space / num_segments)
    local current_bot  = lo

    for i = 1, num_segments do
        local top = math.min(hi, current_bot + seg_arc)
        if i == num_segments then
            top = hi
        end
        arcs[i] = { top, current_bot } -- {top, bottom}
        current_bot = top + gap
    end

    return arcs
end

local PSYKER_ARCS    = _compute_segment_arcs(PSYKER_TALENT_SEGMENTS, TALENT_ARC_MIN, TALENT_ARC_MAX)
local ADAMANT_ARCS   = _compute_segment_arcs(ADAMANT_TALENT_SEGMENTS, TALENT_ARC_MIN, TALENT_ARC_MAX)
local OGRYN_BLO_ARCS = _compute_segment_arcs(OGRYN_BLO_MAX_STACKS, TALENT_ARC_MIN, TALENT_ARC_MAX, OGRYN_BLO_SEGMENT_GAP)

-- Cryptic keeps a count-keyed cache because its segment count can change mid-game.
local _cryptic_arcs_cache = {}
local function _get_cryptic_arcs(num_segments)
    if num_segments <= 0 then return nil end
    if _cryptic_arcs_cache[num_segments] then
        return _cryptic_arcs_cache[num_segments]
    end
    local arcs = _compute_segment_arcs(num_segments, TALENT_ARC_MIN, TALENT_ARC_MAX)
    _cryptic_arcs_cache[num_segments] = arcs
    return arcs
end

-- Pre-calculate Opacity Tables
local OPACITY_DIM  = { 0.7, 0.5 }
local OPACITY_FULL = { 1.3, 1.3 }

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

    for i = 1, CRYPTIC_MAX_SEGMENTS do
        local base = style[_cryptic_style_keys_base[i]]
        local edge = style[_cryptic_style_keys_edge[i]]
        if base and base.visible then
            base.visible = false; changed = true
        end
        if edge and edge.visible then
            edge.visible = false; changed = true
        end
    end

    for i = 1, OGRYN_BLO_MAX_STACKS do
        local seg = style[_ogryn_blo_style_keys[i]]
        if seg and seg.visible then
            seg.visible = false; changed = true
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

local function _hide_cryptic_segments(style)
    local changed = false
    for i = 1, CRYPTIC_MAX_SEGMENTS do
        local base = style[_cryptic_style_keys_base[i]]
        local edge = style[_cryptic_style_keys_edge[i]]
        if base and base.visible then
            base.visible = false; changed = true
        end
        if edge and edge.visible then
            edge.visible = false; changed = true
        end
    end
    return changed
end

local function _hide_ogryn_blo_segments(style)
    local changed = false
    for i = 1, OGRYN_BLO_MAX_STACKS do
        local seg = style[_ogryn_blo_style_keys[i]]
        if seg and seg.visible then
            seg.visible = false; changed = true
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
-- Cryptic Update Logic
-- ============================================================
local function _update_cryptic(widget, style, data, force_show, partial_outline_rgba, is_hide_full_mode)
    local changed = _hide_standard_passes(style)
    changed = _hide_psyker_segments(style) or changed
    changed = _hide_adamant_segments(style) or changed
    changed = _hide_ogryn_blo_segments(style) or changed

    local max_charges = math.clamp(tonumber(data and data.segment_max) or 1, 1, CRYPTIC_MAX_SEGMENTS)
    local current_charges = math.clamp(tonumber(data and data.stacks) or 0, 0, max_charges)
    local cooldown_fraction = math.clamp(tonumber(data and data.cooldown_fraction) or 0, 0, 1)

    local arcs = _get_cryptic_arcs(max_charges)

    for i = 1, CRYPTIC_MAX_SEGMENTS do
        local base = style[_cryptic_style_keys_base[i]]
        local edge = style[_cryptic_style_keys_edge[i]]

        if base and edge and base.material_values and edge.material_values then
            if i <= max_charges and arcs and arcs[i] then
                local top, bottom = arcs[i][1], arcs[i][2]
                local frac = 0

                if i <= current_charges then
                    frac = 1
                elseif i == current_charges + 1 then
                    frac = cooldown_fraction
                end

                local show_empty = false
                local outline = nil

                if is_hide_full_mode and current_charges == 0 and i == 1 then
                    show_empty = true
                    outline = partial_outline_rgba
                end

                if frac <= EPS then
                    if force_show or show_empty then
                        local c = false
                        if outline then
                            c = _set_outline_override(base, outline, false)
                        else
                            c = _restore_outline_default(base, false)
                        end
                        local mv_base = base.material_values
                        if mv_base.amount ~= 0 then
                            mv_base.amount = 0; c = true
                        end
                        c = U.mv_set_arc(mv_base, top, bottom, c)
                        c = U.set_style_visible(base, true, c)
                        c = U.set_style_visible(edge, false, c)
                        changed = c or changed
                    else
                        local c = U.set_style_visible(base, false, false)
                        c = U.set_style_visible(edge, false, c)
                        changed = c or changed
                    end
                else
                    changed = _write_notched_segment(base, edge, top, bottom, frac, true, partial_outline_rgba, changed) or
                        changed
                end
            else
                local c = U.set_style_visible(base, false, false)
                c = U.set_style_visible(edge, false, c)
                changed = c or changed
            end
        end
    end

    if changed then widget.dirty = true end
end

-- ============================================================
-- Adamant Update Logic
-- ============================================================
local function _update_adamant(widget, style, data, force_show, partial_outline_rgba)
    local changed         = _hide_standard_passes(style)
    changed               = _hide_psyker_segments(style) or changed
    changed               = _hide_cryptic_segments(style) or changed
    changed               = _hide_ogryn_blo_segments(style) or changed

    local melee_stacks    = math.clamp(tonumber(data and data.adamant_tw_melee_stacks) or 0, 0, ADAMANT_MAX_STACKS)
    local ranged_stacks   = math.clamp(tonumber(data and data.adamant_tw_ranged_stacks) or 0, 0, ADAMANT_MAX_STACKS)

    local ranged_frac     = math.clamp(ranged_stacks / ADAMANT_MAX_STACKS, 0, 1)
    local melee_frac      = math.clamp(melee_stacks / ADAMANT_MAX_STACKS, 0, 1)

    -- Dynamic Opacity
    local ranged_opacity  = (ranged_stacks >= 20) and OPACITY_FULL or OPACITY_DIM
    local melee_opacity   = (melee_stacks >= 20) and OPACITY_FULL or OPACITY_DIM

    local function set_opacity(pass_base, pass_edge, opacity)
        local c = false
        if pass_base and pass_base.material_values then
            local mv = pass_base.material_values
            if not mv.fill_outline_opacity or mv.fill_outline_opacity[1] ~= opacity[1] or mv.fill_outline_opacity[2] ~= opacity[2] then
                mv.fill_outline_opacity = opacity
                c = true
            end
        end
        if pass_edge and pass_edge.material_values then
            local mv = pass_edge.material_values
            if not mv.fill_outline_opacity or mv.fill_outline_opacity[1] ~= opacity[1] or mv.fill_outline_opacity[2] ~= opacity[2] then
                mv.fill_outline_opacity = opacity
                c = true
            end
        end
        return c
    end

    changed = set_opacity(style.talent_adamant_seg_1, style.talent_adamant_seg_1_edge, ranged_opacity) or changed
    changed = set_opacity(style.talent_adamant_seg_2, style.talent_adamant_seg_2_edge, melee_opacity) or changed

    -- Rendering logic wrapper to handle "force_show" preview state (empty outlines)
    local function render_segment(base, edge, top, bottom, frac, outline_rgba)
        if frac <= EPS then
            if force_show then
                local c = _restore_outline_default(base, false)
                local mv_base = base.material_values
                if mv_base.amount ~= 0 then
                    mv_base.amount = 0; c = true
                end
                c = U.mv_set_arc(mv_base, top, bottom, c)
                c = U.set_style_visible(base, true, c)
                c = U.set_style_visible(edge, false, c)
                return c
            else
                local c = U.set_style_visible(base, false, false)
                c = U.set_style_visible(edge, false, c)
                return c
            end
        else
            return _write_notched_segment(base, edge, top, bottom, frac, true, outline_rgba, false)
        end
    end

    -- Segment 1 (ranged)
    changed = render_segment(style.talent_adamant_seg_1, style.talent_adamant_seg_1_edge,
        ADAMANT_ARCS[1][1], ADAMANT_ARCS[1][2], ranged_frac, partial_outline_rgba) or changed

    -- Segment 2 (melee)
    changed = render_segment(style.talent_adamant_seg_2, style.talent_adamant_seg_2_edge,
        ADAMANT_ARCS[2][1], ADAMANT_ARCS[2][2], melee_frac, partial_outline_rgba) or changed

    if changed then widget.dirty = true end
end

-- ============================================================
-- Psyker Update Logic
-- ============================================================
local function _update_psyker(widget, style, data, force_show)
    local changed = _hide_standard_passes(style)
    changed = _hide_adamant_segments(style) or changed
    changed = _hide_cryptic_segments(style) or changed
    changed = _hide_ogryn_blo_segments(style) or changed

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
-- Ogryn Lucky Bullet Update Logic
-- ============================================================
local function _update_ogryn_blo(widget, style, data, force_show)
    local changed = _hide_standard_passes(style)
    changed = _hide_psyker_segments(style) or changed
    changed = _hide_adamant_segments(style) or changed
    changed = _hide_cryptic_segments(style) or changed

    local stacks = math.clamp(tonumber(data and data.stacks) or 0, 0, OGRYN_BLO_MAX_STACKS)
    local bright = stacks >= OGRYN_BLO_BRIGHT_STACKS
    local opacity = bright and OPACITY_FULL or OPACITY_DIM
    local arcs = OGRYN_BLO_ARCS

    for i = 1, OGRYN_BLO_MAX_STACKS do
        local seg = style[_ogryn_blo_style_keys[i]]
        local arc = arcs and arcs[i]
        if seg and seg.material_values and arc then
            local mv = seg.material_values
            local outline = bright and seg.__ringhud_outline_bright or seg.__ringhud_outline_dim

            changed = U.mv_set_outline(mv, outline, changed)
            if not mv.fill_outline_opacity
                or mv.fill_outline_opacity[1] ~= opacity[1]
                or mv.fill_outline_opacity[2] ~= opacity[2] then
                mv.fill_outline_opacity = opacity
                changed = true
            end

            local filled = i <= stacks
            local visible = filled or (force_show and stacks == 0)
            changed = _write_simple_segment(seg, arc[1], arc[2], filled and 1 or 0, visible, changed) or changed
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
    changed = _hide_cryptic_segments(style) or changed
    changed = _hide_ogryn_blo_segments(style) or changed

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

-- ─────────────────────────────────────────────────────────────────────────────
-- Layout Application
-- ─────────────────────────────────────────────────────────────────────────────
function TalentFeature.apply_layout(widget, ctx)
    if not widget or not widget.style then return end

    local changed = false
    local style = widget.style
    local apply_shake_offset = U.apply_shake_to_style_offset

    if style.talent_bar and apply_shake_offset(
            style.talent_bar, 0, 0, 1, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
        ) then
        changed = true
    end
    if style.talent_bar_edge and apply_shake_offset(
            style.talent_bar_edge, 0, 0, 2, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
        ) then
        changed = true
    end

    for i = 1, PSYKER_TALENT_SEGMENTS do
        local st = style[_psyker_style_keys[i]]
        if st and apply_shake_offset(
                st, 0, 0, 1, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
            ) then
            changed = true
        end
    end

    for i = 1, ADAMANT_TALENT_SEGMENTS do
        local st  = style[_adamant_style_keys_base[i]]
        local ste = style[_adamant_style_keys_edge[i]]

        if st and apply_shake_offset(
                st, 0, 0, 1, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
            ) then
            changed = true
        end
        if ste and apply_shake_offset(
                ste, 0, 0, 2, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
            ) then
            changed = true
        end
    end

    for i = 1, CRYPTIC_MAX_SEGMENTS do
        local st  = style[_cryptic_style_keys_base[i]]
        local ste = style[_cryptic_style_keys_edge[i]]

        if st and apply_shake_offset(
                st, 0, 0, 1, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
            ) then
            changed = true
        end
        if ste and apply_shake_offset(
                ste, 0, 0, 2, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
            ) then
            changed = true
        end
    end

    for i = 1, OGRYN_BLO_MAX_STACKS do
        local st = style[_ogryn_blo_style_keys[i]]
        if st and apply_shake_offset(
                st, 0, 0, 1, ctx.apply_shake, ctx.dx, ctx.dy, ctx.user_bias_px, ctx.n_user_bias_px
            ) then
            changed = true
        end
    end

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
    local is_hide_full_mode    = false

    if mode == "adamant_terminus_warrant" then
        visible = (melee_stacks > 0) or (ranged_stacks > 0) or force_show
    elseif mode == "psyker_empowered_grenades" then
        visible = (stacks > 0) or (force_show and available)
    elseif mode == "ogryn_blo_melee" then
        visible = (stacks > 0) or (force_show and available)
    elseif mode == "cryptic_ability_charges" then
        local g_setting = SETTINGS.grenade_bar_dropdown
        is_hide_full_mode = (g_setting == "grenade_hide_full_compact" or g_setting == "grenade_hide_full")

        if is_hide_full_mode then
            if stacks == (data.segment_max or 0) then
                visible = force_show
            else
                visible = true
            end
        else
            local has_fraction = fraction > 0
            visible = (stacks > 0) or has_fraction or force_show
        end
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
    elseif mode == "ogryn_blo_melee" then
        _update_ogryn_blo(widget, widget.style, data, force_show)
    elseif mode == "cryptic_ability_charges" then
        _update_cryptic(widget, widget.style, data, force_show, partial_outline_rgba, is_hide_full_mode)
    else
        _update_standard(widget, widget.style, data, force_show)
    end
end

function TalentFeature.add_widgets(widget_defs, _, layout, palettes)
    local size                                 = (layout and layout.size) or { 240, 240 }
    local inner                                = (layout and layout.inner_size_factor) or 0.8
    local parent_id                            = (layout and layout.scenegraph_id) or "talent_bar"
    local ARGB                                 = (palettes and palettes.ARGB) or (mod.PALETTE_ARGB255 or {})
    local RGBA1                                = (palettes and palettes.RGBA1) or (mod.PALETTE_RGBA1 or {})

    local inner_size                           = { size[1] * inner, size[2] * inner }

    -- Outlines:
    --  • Default cooldown (Zealot + Broker countdown): same outline
    --  • Psyker segments: purple
    --  • Adamant Terminus Warrant: active (ranged) / inactive (melee)
    --  • Cryptic segments: cyan
    --  • Ogryn Back Off stacks: grey below guaranteed chance, orange at 9+
    local zealot_outline                       = table.clone(RGBA1.dodge_color_negative_rgba or { 1, 0, 0, 1 })
    local psyker_outline                       = table.clone(RGBA1.GRIMOIRE_PURPLE or { 0.6, 0.2, 0.8, 1 })
    local adamant_inactive                     = table.clone(RGBA1.NEEDLE_SPECIAL_INACTIVE or { 0.75, 0.75, 0.75, 1 })
    local adamant_active                       = table.clone(RGBA1.NEEDLE_SPECIAL_ACTIVE or { 0.2, 1.0, 0.8, 1 })
    -- local cryptic_outline                      = table.clone(RGBA1.GENERIC_CYAN or { 0.24, 0.86, 0.86, 1 })
    local cryptic_outline                      = table.clone(RGBA1.NEEDLE_SPECIAL_ACTIVE or { 0.2, 1.0, 0.8, 1 })
    local ogryn_blo_dim_outline                 = table.clone(RGBA1.default_damage_color_rgba or { 0.5, 0.5, 0.5, 1 })
    local ogryn_blo_bright_outline              = table.clone(RGBA1.AMMO_ORANGE or { 1.0, 0.51, 0.0, 1 })

    local passes                               = {
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
                    -- SizeThicknessOutline = { 0.405, 0.027, 0.018 },
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
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
                    -- SizeThicknessOutline = { 0.405, 0.027, 0.018 },
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
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
                    -- SizeThicknessOutline = { 0.405, 0.027, 0.018 },
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
                },
            },
        }
    end

    -- Adamant segmented passes (2 segments, each with a notch/edge split)
    -- NOTE: Seg 1 is RANGED (active), Seg 2 is MELEE (inactive)
    for i = 1, ADAMANT_TALENT_SEGMENTS do
        local outline = (i == 1) and adamant_active or adamant_inactive

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
                    fill_outline_opacity = { 0.7, 0.5 },
                    outline_color        = table.clone(outline),
                    -- SizeThicknessOutline = { 0.405, 0.027, 0.018 },
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
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
                    fill_outline_opacity = { 0.7, 0.5 },
                    outline_color        = table.clone(outline),
                    -- SizeThicknessOutline = { 0.405, 0.027, 0.018 },
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
                },
            },
        }
    end

    -- Cryptic segmented passes
    for i = 1, CRYPTIC_MAX_SEGMENTS do
        -- Base (filled)
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_cryptic_seg_" .. i,
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
                __ringhud_outline_default = table.clone(cryptic_outline),
                material_values           = {
                    amount               = 1,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MIN, TALENT_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(cryptic_outline),
                    -- SizeThicknessOutline = { 0.405, 0.027, 0.018 },
                    SizeThicknessOutline = { 0.405, 0.027, 0.036 },
                },
            },
        }

        -- Edge (outline-only leading sliver)
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_cryptic_seg_" .. i .. "_edge",
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
                __ringhud_outline_default = table.clone(cryptic_outline),
                material_values           = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MIN, TALENT_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(cryptic_outline),
                    -- SizeThicknessOutline = { 0.405, 0.027, 0.018 },
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
                },
            },
        }
    end

    -- Ogryn Back Off stacks (10 discrete segments)
    for i = 1, OGRYN_BLO_MAX_STACKS do
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "talent_ogryn_blo_seg_" .. i,
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
                __ringhud_outline_dim      = table.clone(ogryn_blo_dim_outline),
                __ringhud_outline_bright   = table.clone(ogryn_blo_bright_outline),
                material_values           = {
                    amount               = 1,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { TALENT_ARC_MIN, TALENT_ARC_MIN },
                    fill_outline_opacity = { 0.7, 0.5 },
                    outline_color        = table.clone(ogryn_blo_dim_outline),
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
                },
            },
        }
    end

    widget_defs.talent_bar = UIWidget.create_definition(passes, parent_id)
end

return TalentFeature
