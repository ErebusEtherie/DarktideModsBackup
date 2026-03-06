-- File: RingHud/scripts/mods/RingHud/features/charge_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local UIWidget                     = require("scripts/managers/ui/ui_widget")
local Notch                        = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")
local U                            = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

local ChargeFeature                = {}

local CHARGE_MAX_STACK_SOUND_EVENT = "wwise/events/player/play_device_auspex_scanner_minigame_progress_last"

local SETTINGS                     = mod._settings
local EPS                          = mod.NOTCH_EPSILON or 1e-4
local MAX_CHARGE_SEGMENTS          = mod.MAX_CHARGE_SEGMENTS or 6

local COL_DEFAULT                  = mod.PALETTE_RGBA1.GENERIC_WHITE
local COL_DAMAGE                   = mod.PALETTE_RGBA1.default_damage_color_rgba

local SEG1_TOP, SEG1_BOTTOM        = 0.24, 0.01
local SEG2_TOP, SEG2_BOTTOM        = 0.50, 0.27

local CHARGE_ARC_MIN               = math.min(SEG1_BOTTOM, SEG2_BOTTOM) -- 0.01
local CHARGE_ARC_MAX               = math.max(SEG1_TOP, SEG2_TOP)       -- 0.50
local CHARGE_SEGMENT_GAP           = SEG2_BOTTOM - SEG1_TOP             -- same gap as between seg1/seg2

local _seg_style_keys              = {}
local _edge_style_keys             = {}
for i = 1, MAX_CHARGE_SEGMENTS do
    _seg_style_keys[i] = "charge_seg_" .. i
    _edge_style_keys[i] = "charge_seg_edge_" .. i
end

local _cached_arcs = {}

local function _get_arcs_for_count(num_segments)
    if num_segments <= 0 then return nil end

    if _cached_arcs[num_segments] then
        return _cached_arcs[num_segments]
    end

    local arcs         = {}
    local total_arc    = CHARGE_ARC_MAX - CHARGE_ARC_MIN
    local num_gaps     = math.max(0, num_segments - 1)
    local gap_space    = num_gaps * CHARGE_SEGMENT_GAP
    local visual_space = math.max(0, total_arc - gap_space)
    local seg_arc      = (visual_space / num_segments)
    local current_bot  = CHARGE_ARC_MIN

    for i = 1, num_segments do
        local top = math.min(CHARGE_ARC_MAX, current_bot + seg_arc)
        if i == num_segments then
            top = CHARGE_ARC_MAX
        end
        arcs[i] = { top, current_bot }
        current_bot = top + CHARGE_SEGMENT_GAP
    end

    _cached_arcs[num_segments] = arcs
    return arcs
end

local function _fast_hide_all(widget, style)
    local changed = false
    -- Standard bars
    if style.charge_bar_1 and style.charge_bar_1.visible then
        style.charge_bar_1.visible = false; changed = true
    end
    if style.charge_bar_2 and style.charge_bar_2.visible then
        style.charge_bar_2.visible = false; changed = true
    end
    if style.charge_bar_1_edge and style.charge_bar_1_edge.visible then
        style.charge_bar_1_edge.visible = false; changed = true
    end
    if style.charge_bar_2_edge and style.charge_bar_2_edge.visible then
        style.charge_bar_2_edge.visible = false; changed = true
    end

    -- Segmented bars
    for i = 1, MAX_CHARGE_SEGMENTS do
        local s = style[_seg_style_keys[i]]
        local e = style[_edge_style_keys[i]]
        if s and s.visible then
            s.visible = false; changed = true
        end
        if e and e.visible then
            e.visible = false; changed = true
        end
    end

    if changed then widget.dirty = true end
end

local function _hide_all_segmented_passes(style)
    local changed = false
    for i = 1, MAX_CHARGE_SEGMENTS do
        local s = style[_seg_style_keys[i]]
        local e = style[_edge_style_keys[i]]
        if s and s.visible then
            s.visible = false; changed = true
        end
        if e and e.visible then
            e.visible = false; changed = true
        end
    end
    return changed
end

local function _hide_standard_passes(style)
    local changed = false
    if style.charge_bar_1 and style.charge_bar_1.visible then
        style.charge_bar_1.visible = false; changed = true
    end
    if style.charge_bar_2 and style.charge_bar_2.visible then
        style.charge_bar_2.visible = false; changed = true
    end
    if style.charge_bar_1_edge and style.charge_bar_1_edge.visible then
        style.charge_bar_1_edge.visible = false; changed = true
    end
    if style.charge_bar_2_edge and style.charge_bar_2_edge.visible then
        style.charge_bar_2_edge.visible = false; changed = true
    end
    return changed
end

local function _write_segment(style, style_edge, seg_top, seg_bottom, f, visible_gate, outline_rgba, show_empty)
    local changed = false
    local mv_base = style and style.material_values or nil
    local mv_edge = style_edge and style_edge.material_values or nil

    if not (style and mv_base) then return false end

    -- Outline colour on both passes (when present)
    changed = U.mv_set_outline(mv_base, outline_rgba, changed)
    if mv_edge then
        changed = U.mv_set_outline(mv_edge, outline_rgba, changed)
    end

    f = math.clamp(f or 0, 0, 1)

    local show_base, show_edge = false, false

    if f <= EPS then
        if show_empty then
            if mv_base.amount ~= 0 then
                mv_base.amount = 0
                changed = true
            end
            changed = U.mv_set_arc(mv_base, seg_top, seg_bottom, changed)
            show_base = true

            if style_edge and mv_edge then
                changed = U.set_style_visible(style_edge, false, changed)
            end
        else
            changed = U.set_style_visible(style, false, changed)
            if style_edge then
                changed = U.set_style_visible(style_edge, false, changed)
            end

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
        changed = U.mv_set_arc(mv_base, seg_top, seg_bottom, changed)
        if mv_base.amount ~= 1 then
            mv_base.amount = 1
            changed = true
        end
        show_base = true

        if style_edge and mv_edge then
            changed = U.set_style_visible(style_edge, false, changed)
            if mv_edge.amount ~= 0 then
                mv_edge.amount = 0
                changed = true
            end
        end
    else
        local r = Notch.notch_split(seg_top, seg_bottom, f)

        changed = U.mv_set_arc(mv_base, r.base.top, r.base.bottom, changed)
        if mv_base.amount ~= 1 then
            mv_base.amount = 1
            changed = true
        end
        show_base = r.base.show

        if style_edge and mv_edge then
            changed = U.mv_set_arc(mv_edge, r.edge.top, r.edge.bottom, changed)
            if mv_edge.amount ~= 0 then
                mv_edge.amount = 0
                changed = true
            end
            show_edge = r.edge.show
        end
    end

    local want_base = visible_gate and show_base
    changed = U.set_style_visible(style, want_base, changed)

    if style_edge and mv_edge then
        local want_edge = visible_gate and show_edge
        changed = U.set_style_visible(style_edge, want_edge, changed)
    end

    return changed
end

-- Sub-update: Dual Shivs
local function _update_dual(widget, style, hud_state, outline_clr, is_hide_full_mode, visible_gate)
    local changed = _hide_standard_passes(style)

    local cur = hud_state.charge_current_charges or 0
    local max = hud_state.charge_max_charges or 0
    local num_seg = math.min(MAX_CHARGE_SEGMENTS, math.max(0, max))

    if num_seg > 0 then
        local arcs = _get_arcs_for_count(num_seg)

        for i = 1, MAX_CHARGE_SEGMENTS do
            local seg_style = style[_seg_style_keys[i]]
            local edge_style = style[_edge_style_keys[i]]
            if seg_style and seg_style.material_values then
                local seg_top, seg_bottom = CHARGE_ARC_MIN, CHARGE_ARC_MIN
                if i <= num_seg and arcs[i] then
                    seg_top, seg_bottom = arcs[i][1], arcs[i][2]
                end

                local f = (i <= cur) and 1 or 0
                local show_empty = false
                local seg_outline = outline_clr

                if is_hide_full_mode and cur == 0 and i == 1 then
                    show_empty = true
                    seg_outline = COL_DAMAGE
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
        changed = _hide_all_segmented_passes(style) or changed
    end

    if changed then widget.dirty = true end
end

-- Sub-update: Thrust
local function _update_thrust(widget, style, hud_state, outline_clr, visible_gate)
    local changed = _hide_standard_passes(style)

    local stacks = hud_state.charge_thrust_stacks or 0
    local prog = hud_state.charge_thrust_progress or 0
    local max_stacks = hud_state.charge_thrust_max_stacks or 3
    local num_seg = math.min(MAX_CHARGE_SEGMENTS, math.max(1, max_stacks))
    local arcs = _get_arcs_for_count(num_seg)
    local total_fill = math.clamp(stacks + prog, 0, num_seg)

    for i = 1, MAX_CHARGE_SEGMENTS do
        local seg_style = style[_seg_style_keys[i]]
        local edge_style = style[_edge_style_keys[i]]
        if seg_style and seg_style.material_values then
            if i <= num_seg and arcs[i] then
                local seg_top, seg_bottom = arcs[i][1], arcs[i][2]
                local f = math.clamp(total_fill - (i - 1), 0, 1)

                changed = _write_segment(
                    seg_style,
                    edge_style,
                    seg_top,
                    seg_bottom,
                    f,
                    visible_gate,
                    outline_clr,
                    false
                ) or changed
            else
                changed = _write_segment(
                    seg_style,
                    edge_style,
                    CHARGE_ARC_MIN,
                    CHARGE_ARC_MIN,
                    0,
                    false,
                    outline_clr,
                    false
                ) or changed
            end
        end
    end

    if changed then widget.dirty = true end
end

-- Sub-update: Standard (2-segment)
local function _update_standard(widget, style, hud_state, outline_clr, hotkey_override, visible_gate)
    local changed = _hide_all_segmented_passes(style)

    local split_thresh = 0.5
    local fraction = hud_state.charge_fraction or 0
    local current_fill = (hotkey_override and fraction == 0) and 0 or fraction
    local f1 = math.clamp(current_fill / split_thresh, 0, 1)
    local f2 = math.clamp((current_fill - split_thresh) / (1 - split_thresh), 0, 1)

    changed = _write_segment(
        style.charge_bar_1,
        style.charge_bar_1_edge,
        SEG1_TOP, SEG1_BOTTOM,
        f1,
        visible_gate,
        outline_clr,
        false
    ) or changed

    changed = _write_segment(
        style.charge_bar_2,
        style.charge_bar_2_edge,
        SEG2_TOP, SEG2_BOTTOM,
        f2,
        visible_gate,
        outline_clr,
        false
    ) or changed

    if changed then widget.dirty = true end
end

function ChargeFeature.update(widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local charge_fraction    = hud_state.charge_fraction or 0
    local peril_fraction     = hud_state.peril_fraction or 0
    local charge_system_type = hud_state.charge_system_type

    -- Max Stacks Sound Logic
    local hud                = mod.hud_instance
    if hud and SETTINGS.charge_other_enabled then
        local current_stacks = hud_state.charge_thrust_stacks or 0
        local last = hud._last_charge_thrust_stacks or 0
        if current_stacks >= 5 and last < 5 then
            if hud._play_sound then
                hud:_play_sound(CHARGE_MAX_STACK_SOUND_EVENT)
            end
        end
        hud._last_charge_thrust_stacks = current_stacks
    elseif hud then
        hud._last_charge_thrust_stacks = 0
    end

    -- State determination
    local dual_is_shivs    = hud_state.charge_is_dual_shivs == true
    local thrust_has       = hud_state.charge_has_thrust == true

    local show_perilous    = SETTINGS.charge_perilous_enabled
        and peril_fraction > 0.001
        and charge_system_type ~= "kill_count"

    local show_kill        = SETTINGS.charge_kills_enabled
        and charge_system_type == "kill_count"

    local is_other         = (charge_system_type == "block_passive"
        or charge_system_type == "action_module"
        or charge_system_type == "ogryn_powermaul")

    local show_other       = SETTINGS.charge_other_enabled
        and is_other
        and peril_fraction <= 0.001

    local active_wants_bar = (charge_fraction > 0)
        and (show_perilous or (show_kill and not dual_is_shivs) or show_other)

    -- Fallback latch for dual shivs
    if not active_wants_bar and not dual_is_shivs then
        local latched_max = hud_state.latched_dual_shiv_max or 0
        if latched_max > 0 then
            dual_is_shivs = true
            hud_state.charge_max_charges = latched_max
            hud_state.charge_current_charges = hud_state.latched_dual_shiv_current or 0
        end
    end

    local dual_mode_enabled   = SETTINGS.charge_kills_enabled
        and dual_is_shivs
        and (hud_state.charge_max_charges or 0) > 0

    local thrust_mode_enabled = SETTINGS.charge_other_enabled
        and charge_system_type == "action_module"
        and thrust_has
        and (hud_state.charge_thrust_max_stacks or 0) > 0

    local g_setting           = SETTINGS.grenade_bar_dropdown
    local is_hide_full_mode   = (g_setting == "grenade_hide_full_compact" or g_setting == "grenade_hide_full")

    -- Calculate Visibility
    local displayable         = false

    if active_wants_bar then
        displayable = true
    elseif dual_mode_enabled then
        local cur = hud_state.charge_current_charges or 0
        local max = hud_state.charge_max_charges or 0
        if is_hide_full_mode then
            if cur == max then
                displayable = false
            else
                displayable = true
            end
        else
            displayable = cur > 0
        end
    elseif thrust_mode_enabled then
        displayable = (hud_state.charge_thrust_stacks > 0)
            or (hud_state.charge_thrust_progress > 0)
            or (charge_fraction > 0)
    elseif charge_system_type == "ogryn_powermaul" and show_other then
        displayable = true
        if is_hide_full_mode and charge_fraction >= 0.99 then
            displayable = false
        end
    else
        displayable = (charge_fraction > 0)
            and (show_perilous or show_kill or show_other)
    end

    local visible_gate = hotkey_override or displayable

    -- [Perf] Fast Path: Early Exit if hidden
    if not visible_gate then
        _fast_hide_all(widget, widget.style)
        return
    end

    -- Determine Color
    local outline_clr = COL_DEFAULT
    if peril_fraction > 0.001 then
        outline_clr = mod.current_peril_color_rgba or COL_DEFAULT
    end

    -- Render
    if dual_mode_enabled then
        _update_dual(widget, widget.style, hud_state, outline_clr, is_hide_full_mode, visible_gate)
    elseif thrust_mode_enabled then
        _update_thrust(widget, widget.style, hud_state, outline_clr, visible_gate)
    else
        _update_standard(widget, widget.style, hud_state, outline_clr, hotkey_override, visible_gate)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Widget factory
-- ─────────────────────────────────────────────────────────────────────────────
function ChargeFeature.add_widgets(dst, styles, metrics, colors)
    local size = (metrics and metrics.size) or { 240, 240 }
    local ARGB = (colors and colors.ARGB) or (mod.PALETTE_ARGB255 or {})
    setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end })

    local passes = {}
    local function _add_pass(def) passes[#passes + 1] = def end

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

    -- Segmented passes (used by dual shivs AND thrust)
    for i = 1, MAX_CHARGE_SEGMENTS do
        _add_pass({
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = _seg_style_keys[i],
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
            style_id  = _edge_style_keys[i],
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
