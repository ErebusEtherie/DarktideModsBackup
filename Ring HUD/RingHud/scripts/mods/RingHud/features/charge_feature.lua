-- File: RingHud/scripts/mods/RingHud/features/charge_feature.lua
local mod = get_mod("RingHud")
if not mod then return end

-- Shared notch helper (0.01 gap, epsilon guards, etc.)
local Notch                         = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local ChargeFeature                 = {}

-- Colouring (same idea as before)
local charge_bar_default_color_rgba = mod.PALETTE_RGBA1.GENERIC_WHITE

-- Segment geometry (matches RingHud_definitions.lua)
local SEG1_TOP, SEG1_BOTTOM         = 0.24, 0.01
local SEG2_TOP, SEG2_BOTTOM         = 0.50, 0.27

-- Helper: set arc safely and track change
local function _set_arc(mv, top, bottom, changed_flag)
    local t = math.max(bottom, top)
    local cur = mv.arc_top_bottom
    if not cur or cur[1] ~= t or cur[2] ~= bottom then
        mv.arc_top_bottom = { t, bottom }
        return true
    end
    return changed_flag
end

local function _set_outline(mv, rgba, changed_flag) -- TODO shared util?
    local oc = mv.outline_color
    if (not oc) or oc[1] ~= rgba[1] or oc[2] ~= rgba[2] or oc[3] ~= rgba[3] or oc[4] ~= rgba[4] then
        mv.outline_color = table.clone(rgba)
        return true
    end
    return changed_flag
end

-- Write one charge segment (either the lower or upper one)
-- Uses shared Notch.notch_split(top, bottom, f) for partial fills.
local function _write_segment(style, style_edge, seg_top, seg_bottom, f, visible_gate, outline_rgba)
    local changed = false
    local mv_base = style and style.material_values or nil
    local mv_edge = style_edge and style_edge.material_values or nil

    if not (style and mv_base) then return false end

    -- Outline colour on both passes (when present)
    changed = _set_outline(mv_base, outline_rgba, changed)
    if mv_edge then
        changed = _set_outline(mv_edge, outline_rgba, changed)
    end

    -- Clamp fill
    f = math.clamp(f or 0, 0, 1)
    local EPS = mod.NOTCH_EPSILON or 1e-4

    local show_base, show_edge = false, false

    if f <= EPS then
        -- Empty: hide both
        if style.visible then
            style.visible = false; changed = true
        end
        if style_edge and style_edge.visible then
            style_edge.visible = false; changed = true
        end

        -- Reset amounts & collapse arcs to avoid stale lengths
        if mv_base then
            if mv_base.amount ~= 0 then
                mv_base.amount = 0; changed = true
            end
            changed = _set_arc(mv_base, seg_bottom, seg_bottom, changed)
        end
        if mv_edge then
            if mv_edge.amount ~= 0 then
                mv_edge.amount = 0; changed = true
            end
            changed = _set_arc(mv_edge, seg_top, seg_top, changed)
        end

        return changed
    end

    if f >= 1 - EPS then
        -- Full: show base as full length, hide edge (no notch on “full”)
        changed = _set_arc(mv_base, seg_top, seg_bottom, changed)
        if mv_base.amount ~= 1 then
            mv_base.amount = 1; changed = true
        end
        show_base = true

        if style_edge and mv_edge then
            if style_edge.visible then
                style_edge.visible = false; changed = true
            end
            if mv_edge.amount ~= 0 then
                mv_edge.amount = 0; changed = true
            end
        end
    else
        -- Partial: split-at-the-edge with constant gap via shared helper
        local r = Notch.notch_split(seg_top, seg_bottom, f) -- uses default 0.01 gap & epsilon

        -- Base (filled) piece
        changed = _set_arc(mv_base, r.base.top, r.base.bottom, changed)
        if mv_base.amount ~= 1 then
            mv_base.amount = 1; changed = true
        end
        show_base = r.base.show

        -- Edge (unfilled) piece
        if style_edge and mv_edge then
            changed = _set_arc(mv_edge, r.edge.top, r.edge.bottom, changed)
            if mv_edge.amount ~= 0 then
                mv_edge.amount = 0; changed = true
            end
            show_edge = r.edge.show
        end
    end

    -- Visibility respects force-show (visible_gate) but still suppresses zero-length
    local want_base = visible_gate and show_base
    if style.visible ~= want_base then
        style.visible = want_base; changed = true
    end

    if style_edge and mv_edge then
        local want_edge = visible_gate and show_edge
        if style_edge.visible ~= want_edge then
            style_edge.visible = want_edge; changed = true
        end
    end

    return changed
end

function ChargeFeature.update(widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local charge_fraction    = hud_state.charge_fraction or 0
    local peril_fraction     = hud_state.peril_fraction or 0
    local charge_system_type = hud_state.charge_system_type

    local style              = widget.style
    local s1                 = style.charge_bar_1
    local s2                 = style.charge_bar_2
    local s1e                = style.charge_bar_1_edge -- may be nil until defs are updated
    local s2e                = style.charge_bar_2_edge -- may be nil until defs are updated
    local changed            = false

    if not (s1 and s1.material_values and s2 and s2.material_values) then return end

    -- Which charge types we display (same gates as before)
    local show_perilous_normally = mod._settings.charge_perilous_enabled and peril_fraction > 0
        and charge_system_type ~= "kill_count"
    local show_kill_normally     = mod._settings.charge_kills_enabled and charge_system_type == "kill_count"
    local is_other_charge_type   = (charge_system_type == "block_passive" or charge_system_type == "action_module")
    local show_other_normally    = mod._settings.charge_other_enabled and is_other_charge_type and peril_fraction <= 0
    local displayable_normally   = (charge_fraction > 0) and
        (show_perilous_normally or show_kill_normally or show_other_normally)
    local visible_gate           = hotkey_override or displayable_normally

    -- Outline tint: peril hue if perilous, else white
    local outline_clr_to_use
    if peril_fraction > 0.001 then
        outline_clr_to_use = mod.current_peril_color_rgba or charge_bar_default_color_rgba
    else
        outline_clr_to_use = charge_bar_default_color_rgba
    end

    -- Split the full charge across two fixed segments
    local split_thresh          = 0.5
    local current_fill_fraction = (hotkey_override and charge_fraction == 0) and 0 or charge_fraction
    local f1                    = math.clamp(current_fill_fraction / split_thresh, 0, 1)
    local f2                    = math.clamp((current_fill_fraction - split_thresh) / (1 - split_thresh), 0, 1)

    -- Write lower (seg 1) and upper (seg 2)
    changed                     = _write_segment(s1, s1e, SEG1_TOP, SEG1_BOTTOM, f1, visible_gate, outline_clr_to_use) or
        changed
    changed                     = _write_segment(s2, s2e, SEG2_TOP, SEG2_BOTTOM, f2, visible_gate, outline_clr_to_use) or
        changed

    if changed then widget.dirty = true end
end

return ChargeFeature
