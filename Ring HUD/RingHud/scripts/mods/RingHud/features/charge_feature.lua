-- File: RingHud/scripts/mods/RingHud/features/charge_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

-- UI + shared helpers
local UIWidget                      = require("scripts/managers/ui/ui_widget")
local Notch                         = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")
local U                             = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

local ChargeFeature                 = {}

-- Colouring (same idea as before)
local charge_bar_default_color_rgba = mod.PALETTE_RGBA1.GENERIC_WHITE

-- Segment geometry (matches RingHud_definitions_player.lua)
local SEG1_TOP, SEG1_BOTTOM         = 0.24, 0.01
local SEG2_TOP, SEG2_BOTTOM         = 0.50, 0.27

-- Overall arc range and segment gap (used for dual-shiv segmentation)
local CHARGE_ARC_MIN                = math.min(SEG1_BOTTOM, SEG2_BOTTOM) -- 0.01
local CHARGE_ARC_MAX                = math.max(SEG1_TOP, SEG2_TOP)       -- 0.50
local CHARGE_SEGMENT_GAP            = SEG2_BOTTOM - SEG1_TOP             -- same gap as between seg1/seg2
local MAX_CHARGE_SEGMENTS           = mod.MAX_CHARGE_SEGMENTS or 6

-- Write one charge segment (either the lower or upper one)
-- Uses shared Notch.notch_split(top, bottom, f) for partial fills.
local function _write_segment(style, style_edge, seg_top, seg_bottom, f, visible_gate, outline_rgba, show_empty)
    local changed = false
    local mv_base = style and style.material_values or nil
    local mv_edge = style_edge and style_edge.material_values or nil

    if not (style and mv_base) then return false end

    -- Outline colour on both passes (when present) — dynamic in update
    changed = U.mv_set_outline(mv_base, outline_rgba, changed)
    if mv_edge then
        changed = U.mv_set_outline(mv_edge, outline_rgba, changed)
    end

    -- Clamp fill
    f = math.clamp(f or 0, 0, 1)
    local EPS = mod.NOTCH_EPSILON or 1e-4

    local show_base, show_edge = false, false

    if f <= EPS then
        if show_empty then
            -- Show outline only, full span, amount 0
            if mv_base.amount ~= 0 then
                mv_base.amount = 0; changed = true
            end
            changed = U.mv_set_arc(mv_base, seg_top, seg_bottom, changed)
            show_base = true

            -- Keep edge hidden for empty segment
            if style_edge and mv_edge then
                changed = U.set_style_visible(style_edge, false, changed)
            end
        else
            -- Empty: hide both
            changed = U.set_style_visible(style, false, changed)
            if style_edge then
                changed = U.set_style_visible(style_edge, false, changed)
            end

            -- Reset amounts & collapse arcs to avoid stale lengths
            if mv_base then
                if mv_base.amount ~= 0 then
                    mv_base.amount = 0; changed = true
                end
                changed = U.mv_set_arc(mv_base, seg_bottom, seg_bottom, changed)
            end
            if mv_edge then
                if mv_edge.amount ~= 0 then
                    mv_edge.amount = 0; changed = true
                end
                changed = U.mv_set_arc(mv_edge, seg_top, seg_top, changed)
            end

            return changed
        end
    elseif f >= 1 - EPS then
        -- Full: show base as full length, hide edge (no notch on “full”)
        changed = U.mv_set_arc(mv_base, seg_top, seg_bottom, changed)
        if mv_base.amount ~= 1 then
            mv_base.amount = 1; changed = true
        end
        show_base = true

        if style_edge and mv_edge then
            changed = U.set_style_visible(style_edge, false, changed)
            if mv_edge.amount ~= 0 then
                mv_edge.amount = 0; changed = true
            end
        end
    else
        -- Partial: split-at-the-edge with constant gap via shared helper
        local r = Notch.notch_split(seg_top, seg_bottom, f)

        -- Base (filled) piece
        changed = U.mv_set_arc(mv_base, r.base.top, r.base.bottom, changed)
        if mv_base.amount ~= 1 then
            mv_base.amount = 1; changed = true
        end
        show_base = r.base.show

        -- Edge (unfilled) piece
        if style_edge and mv_edge then
            changed = U.mv_set_arc(mv_edge, r.edge.top, r.edge.bottom, changed)
            if mv_edge.amount ~= 0 then
                mv_edge.amount = 0; changed = true
            end
            show_edge = r.edge.show
        end
    end

    -- Visibility respects force-show (visible_gate) but still suppresses zero-length
    local want_base = visible_gate and show_base
    changed = U.set_style_visible(style, want_base, changed)

    if style_edge and mv_edge then
        local want_edge = visible_gate and show_edge
        changed = U.set_style_visible(style_edge, want_edge, changed)
    end

    return changed
end

function ChargeFeature.update(widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local charge_fraction      = hud_state.charge_fraction or 0
    local peril_fraction       = hud_state.peril_fraction or 0
    local charge_system_type   = hud_state.charge_system_type

    -- New: dual-shiv specific fields (populated by RingHud_state_player.lua)
    local dual_is_shivs        = hud_state.charge_is_dual_shivs == true
    local dual_current_charges = hud_state.charge_current_charges or 0
    local dual_max_charges     = hud_state.charge_max_charges or 0

    local style                = widget.style
    local s1                   = style.charge_bar_1
    local s2                   = style.charge_bar_2
    local s1e                  = style.charge_bar_1_edge -- may be nil until defs are updated
    local s2e                  = style.charge_bar_2_edge -- may be nil until defs are updated
    local changed              = false

    if not (s1 and s1.material_values and s2 and s2.material_values) then return end

    ----------------------------------------------------------------
    -- Which charge types we display
    ----------------------------------------------------------------
    local show_perilous_normally = mod._settings.charge_perilous_enabled
        and peril_fraction > 0
        and charge_system_type ~= "kill_count"

    local show_kill_normally     = mod._settings.charge_kills_enabled
        and charge_system_type == "kill_count"

    local is_other_charge_type   = (charge_system_type == "block_passive" or charge_system_type == "action_module")
    local show_other_normally    = mod._settings.charge_other_enabled
        and is_other_charge_type
        and peril_fraction <= 0

    -- New: dual-shivs segmented mode gate
    local dual_mode_enabled      = mod._settings.charge_kills_enabled
        and dual_is_shivs
        and (dual_max_charges or 0) > 0

    -- Grenade Bar Dropdown interaction
    local g_setting              = mod._settings.grenade_bar_dropdown
    local is_hide_full_mode      = (g_setting == "grenade_hide_full_compact" or g_setting == "grenade_hide_full")

    local displayable_normally
    if dual_mode_enabled then
        if is_hide_full_mode then
            if dual_current_charges == dual_max_charges then
                displayable_normally = false -- (a) Hide when full
            elseif dual_current_charges == 0 then
                displayable_normally = true  -- (c) Show when empty (special handling in loop)
            else
                displayable_normally = true  -- (b) Normal behavior
            end
        else
            -- Original behavior
            displayable_normally = (dual_current_charges or 0) > 0
        end
    else
        displayable_normally = (charge_fraction > 0)
            and (show_perilous_normally or show_kill_normally or show_other_normally)
    end

    local visible_gate = hotkey_override or displayable_normally

    ----------------------------------------------------------------
    -- Outline tint: peril hue if perilous, else white
    ----------------------------------------------------------------
    local outline_clr_to_use
    if peril_fraction > 0.001 then
        outline_clr_to_use = mod.current_peril_color_rgba or charge_bar_default_color_rgba
    else
        outline_clr_to_use = charge_bar_default_color_rgba
    end

    -- Helper to hard-hide any segmented passes (used when leaving dual mode or when invalid)
    local function _hide_all_dual_segments()
        for i = 1, MAX_CHARGE_SEGMENTS do
            local seg_style  = style["charge_seg_" .. i]
            local edge_style = style["charge_seg_edge_" .. i]
            if seg_style and seg_style.material_values then
                changed = _write_segment(
                    seg_style,
                    edge_style,
                    CHARGE_ARC_MIN,
                    CHARGE_ARC_MIN,
                    0,
                    false,
                    outline_clr_to_use,
                    false
                ) or changed
            end
        end
    end

    if dual_mode_enabled then
        ----------------------------------------------------------------
        -- Dual shivs: segmented “charges” bar
        ----------------------------------------------------------------

        -- Always hide the legacy 2 segments while in dual-seg mode
        changed = _write_segment(s1, s1e, SEG1_TOP, SEG1_BOTTOM, 0, false, outline_clr_to_use, false) or changed
        changed = _write_segment(s2, s2e, SEG2_TOP, SEG2_BOTTOM, 0, false, outline_clr_to_use, false) or changed

        local num_seg_calc = math.min(MAX_CHARGE_SEGMENTS, math.max(0, dual_max_charges or 0))

        if num_seg_calc > 0 then
            -- Precompute arcs (same pattern as grenades_feature)
            local arcs         = {}
            local total_arc    = CHARGE_ARC_MAX - CHARGE_ARC_MIN
            local num_gaps     = math.max(0, num_seg_calc - 1)
            local gap_space    = num_gaps * CHARGE_SEGMENT_GAP
            local visual_space = math.max(0, total_arc - gap_space)
            local seg_arc      = (num_seg_calc > 0) and (visual_space / num_seg_calc) or 0
            local current_bot  = CHARGE_ARC_MIN

            for i = 1, num_seg_calc do
                local top = math.min(CHARGE_ARC_MAX, current_bot + seg_arc)
                if i == num_seg_calc then
                    -- Ensure the last segment ends exactly on CHARGE_ARC_MAX
                    top = CHARGE_ARC_MAX
                end
                arcs[i] = { top, current_bot }
                current_bot = top + CHARGE_SEGMENT_GAP
            end

            -- Apply segments: one fully filled per available charge
            for i = 1, MAX_CHARGE_SEGMENTS do
                local seg_style  = style["charge_seg_" .. i]
                local edge_style = style["charge_seg_edge_" .. i]
                if seg_style and seg_style.material_values then
                    local seg_top, seg_bottom = CHARGE_ARC_MIN, CHARGE_ARC_MIN
                    if i <= num_seg_calc and arcs[i] then
                        seg_top, seg_bottom = arcs[i][1], arcs[i][2]
                    end

                    local f = 0
                    if i <= dual_current_charges then
                        f = 1
                    end

                    -- Special handling for Case (c): Empty (0 charges) in hide_full mode
                    local show_empty = false
                    local seg_outline = outline_clr_to_use

                    if is_hide_full_mode and dual_current_charges == 0 then
                        if i == 1 then
                            show_empty = true
                            seg_outline = mod.PALETTE_RGBA1.default_damage_color_rgba
                        end
                    end

                    changed = _write_segment(
                        seg_style,
                        edge_style,
                        seg_top,
                        seg_bottom,
                        f,
                        visible_gate,
                        seg_outline,
                        show_empty
                    ) or changed
                end
            end
        else
            -- No valid max charges: hide all dual segments
            _hide_all_dual_segments()
        end

        if changed then widget.dirty = true end
        return
    end

    --------------------------------------------------------------------
    -- Non-dual mode: original 2-segment behaviour (kill/block/other)
    --------------------------------------------------------------------

    -- Ensure any dual-shiv segmented passes are hidden when not in dual mode
    _hide_all_dual_segments()

    -- Split the full charge across two fixed segments
    local split_thresh          = 0.5
    local current_fill_fraction = (hotkey_override and charge_fraction == 0) and 0 or charge_fraction
    local f1                    = math.clamp(current_fill_fraction / split_thresh, 0, 1)
    local f2                    = math.clamp((current_fill_fraction - split_thresh) / (1 - split_thresh), 0, 1)

    -- Write lower (seg 1) and upper (seg 2)
    changed                     = _write_segment(
        s1,
        s1e,
        SEG1_TOP,
        SEG1_BOTTOM,
        f1,
        visible_gate,
        outline_clr_to_use,
        false
    ) or changed

    changed                     = _write_segment(
        s2,
        s2e,
        SEG2_TOP,
        SEG2_BOTTOM,
        f2,
        visible_gate,
        outline_clr_to_use,
        false
    ) or changed

    if changed then widget.dirty = true end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Widget factory: defaults-only in defs; dynamic tinting handled in update()
-- ─────────────────────────────────────────────────────────────────────────────
function ChargeFeature.add_widgets(dst, styles, metrics, colors)
    local size = (metrics and metrics.size) or { 240, 240 }
    local ARGB = (colors and colors.ARGB) or (mod.PALETTE_ARGB255 or {})
    setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end })

    local passes = {}

    local function _add_pass(def)
        passes[#passes + 1] = def
    end

    -- Segment 1 (lower)
    _add_pass({
        pass_type = "rotated_texture",
        value     = "content/ui/materials/effects/forcesword_bar",
        style_id  = "charge_bar_1",
        style     = {
            uvs                  = { { 0, 0 }, { 1, 1 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { 0, 0, 1 },
            size                 = size,
            color                = ARGB.GENERIC_WHITE,
            visible              = false,
            pivot                = { 0, 0 },
            angle                = 0,
            material_values      = {
                amount               = 0,
                glow_on_off          = 0,
                lightning_opacity    = 0,
                arc_top_bottom       = { SEG1_TOP, SEG1_BOTTOM },
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = { 1, 1, 1, 1 },
            },
        },
    })

    _add_pass({
        pass_type = "rotated_texture",
        value     = "content/ui/materials/effects/forcesword_bar",
        style_id  = "charge_bar_1_edge",
        style     = {
            uvs                  = { { 0, 0 }, { 1, 1 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { 0, 0, 2 },
            size                 = size,
            color                = ARGB.GENERIC_WHITE,
            visible              = false,
            pivot                = { 0, 0 },
            angle                = 0,
            material_values      = {
                amount               = 0,
                glow_on_off          = 0,
                lightning_opacity    = 0,
                arc_top_bottom       = { SEG1_TOP, SEG1_BOTTOM },
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = { 1, 1, 1, 1 },
            },
        },
    })

    -- Segment 2 (upper)
    _add_pass({
        pass_type = "rotated_texture",
        value     = "content/ui/materials/effects/forcesword_bar",
        style_id  = "charge_bar_2",
        style     = {
            uvs                  = { { 0, 0 }, { 1, 1 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { 0, 0, 2 },
            size                 = size,
            color                = ARGB.GENERIC_WHITE,
            visible              = false,
            pivot                = { 0, 0 },
            angle                = 0,
            material_values      = {
                amount               = 0,
                glow_on_off          = 0,
                lightning_opacity    = 0,
                arc_top_bottom       = { SEG2_TOP, SEG2_BOTTOM },
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = { 1, 1, 1, 1 },
            },
        },
    })

    _add_pass({
        pass_type = "rotated_texture",
        value     = "content/ui/materials/effects/forcesword_bar",
        style_id  = "charge_bar_2_edge",
        style     = {
            uvs                  = { { 0, 0 }, { 1, 1 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { 0, 0, 3 },
            size                 = size,
            color                = ARGB.GENERIC_WHITE,
            visible              = false,
            pivot                = { 0, 0 },
            angle                = 0,
            material_values      = {
                amount               = 0,
                glow_on_off          = 0,
                lightning_opacity    = 0,
                arc_top_bottom       = { SEG2_TOP, SEG2_BOTTOM },
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = { 1, 1, 1, 1 },
            },
        },
    })

    -- New: dual-shiv segmented passes (up to MAX_CHARGE_SEGMENTS)
    for i = 1, MAX_CHARGE_SEGMENTS do
        _add_pass({
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = string.format("charge_seg_%d", i),
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 2 },
                size                 = size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { CHARGE_ARC_MAX, CHARGE_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = { 1, 1, 1, 1 },
                },
            },
        })

        _add_pass({
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = string.format("charge_seg_edge_%d", i),
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 3 },
                size                 = size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { CHARGE_ARC_MAX, CHARGE_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = { 1, 1, 1, 1 },
                },
            },
        })
    end

    dst.charge_bar = UIWidget.create_definition(passes, "charge_bar")
end

return ChargeFeature
