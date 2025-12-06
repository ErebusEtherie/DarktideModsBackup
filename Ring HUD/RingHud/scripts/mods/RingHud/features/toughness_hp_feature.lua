-- File: RingHud/scripts/mods/RingHud/features/toughness_hp_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

-- Deps (presentation only)
local Notch              = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")
local UIWidget           = require("scripts/managers/ui/ui_widget")
local U                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

-- Centralized visibility (context/toughness_hp_visibility.lua)
local THV                = mod.toughness_hp_visibility or
    mod:io_dofile("RingHud/scripts/mods/RingHud/context/toughness_hp_visibility")

local ToughnessHpFeature = {}

local EPS                = 0.001

-- =========================
-- Toughness ring envelope
-- =========================
local TOUGH_ARC_MIN      = -0.19
local TOUGH_ARC_MAX      = 0.19
local TOUGH_TOTAL        = (TOUGH_ARC_MAX - TOUGH_ARC_MIN)

-- Helper: drive base+edge with a notch split for a segment
local function _drive_notch(base_style, base_mv, edge_style, edge_mv, seg_top, seg_bottom, seg_fill, edge_color)
    local changed = false
    if not (base_style and base_mv) then return false end

    local seg_len = seg_top - seg_bottom
    if seg_len <= (mod.NOTCH_EPSILON or 1e-4) then
        changed = U.set_style_visible(base_style, false) or changed
        if edge_style then changed = U.set_style_visible(edge_style, false) or changed end
        if base_mv.amount ~= 0 then
            base_mv.amount = 0; changed = true
        end
        if edge_mv and edge_mv.amount ~= 0 then
            edge_mv.amount = 0; changed = true
        end
        return changed
    end

    -- Always show the base outline for any non-zero span
    changed = U.set_style_visible(base_style, true) or changed

    -- EMPTY → outline only, full span; edge hidden
    if seg_fill <= (mod.NOTCH_EPSILON or 1e-4) then
        if base_mv.amount ~= 0 then
            base_mv.amount = 0; changed = true
        end
        changed = U.mv_set_arc(base_mv, seg_top, seg_bottom, changed)
        if edge_style and edge_mv then
            changed = U.set_style_visible(edge_style, false) or changed
            if edge_mv.amount ~= 0 then
                edge_mv.amount = 0; changed = true
            end
        end
        return changed
    end

    -- FULL → filled base over full span; edge hidden
    if seg_fill >= 1 - (mod.NOTCH_EPSILON or 1e-4) then
        if base_mv.amount ~= 1 then
            base_mv.amount = 1; changed = true
        end
        changed = U.mv_set_arc(base_mv, seg_top, seg_bottom, changed)
        if edge_style and edge_mv then
            changed = U.set_style_visible(edge_style, false) or changed
            if edge_mv.amount ~= 0 then
                edge_mv.amount = 0; changed = true
            end
        end
        return changed
    end

    -- PARTIAL → split into filled base and unfilled edge sliver
    local r = Notch.notch_split(seg_top, seg_bottom, seg_fill)

    -- Base (filled)
    if base_mv.amount ~= 1 then
        base_mv.amount = 1; changed = true
    end
    changed = U.mv_set_arc(base_mv, r.base.top, r.base.bottom, changed)

    -- Edge (unfilled) with outline tint
    if edge_style and edge_mv then
        if edge_mv.amount ~= 0 then
            edge_mv.amount = 0; changed = true
        end
        changed = U.mv_set_arc(edge_mv, r.edge.top, r.edge.bottom, changed)
        changed = U.mv_set_outline(edge_mv, edge_color, changed)
        changed = U.set_style_visible(edge_style, r.edge.show) or changed
    end

    return changed
end

-- Quick helper to hard-hide all ring segments
local function _hide_all_segments(cor_s, hp_s, dmg_s, cor_e, hp_e, dmg_e, cor_w, hp_w, dmg_w)
    local any = false
    any = U.set_style_visible(hp_s, false) or any
    any = U.set_style_visible(dmg_s, false) or any
    any = U.set_style_visible(cor_s, false) or any
    if hp_e then any = U.set_style_visible(hp_e, false) or any end
    if dmg_e then any = U.set_style_visible(dmg_e, false) or any end
    if cor_e then any = U.set_style_visible(cor_e, false) or any end
    if any then
        hp_w.dirty  = true
        dmg_w.dirty = true
        cor_w.dirty = true
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Three-layer ring (HP, damage, corruption) — presentation only
-- ─────────────────────────────────────────────────────────────────────────────
function ToughnessHpFeature.update(hud_element, widgets, hud_state, _hotkey_override_unused)
    if not (widgets
            and widgets.toughness_bar_corruption
            and widgets.toughness_bar_health
            and widgets.toughness_bar_damage) then
        return
    end

    local cor_w, hp_w, dmg_w = widgets.toughness_bar_corruption, widgets.toughness_bar_health,
        widgets.toughness_bar_damage
    if not (cor_w.style and hp_w.style and dmg_w.style) then return end

    -- Base passes
    local cor_s = cor_w.style.corruption_segment
    local hp_s  = hp_w.style.health_segment
    local dmg_s = dmg_w.style.damage_segment
    if not (cor_s and cor_s.material_values and hp_s and hp_s.material_values and dmg_s and dmg_s.material_values) then
        return
    end

    -- Edge passes
    local cor_e      = cor_w.style.corruption_segment_edge
    local hp_e       = hp_w.style.health_segment_edge
    local dmg_e      = dmg_w.style.damage_segment_edge
    local cor_e_mv   = cor_e and cor_e.material_values
    local hp_e_mv    = hp_e and hp_e.material_values
    local dmg_e_mv   = dmg_e and dmg_e.material_values

    -- ── Visibility: delegate to centralized context module ────────────────────
    local ctx        = {
        hp_fraction         = (hud_state.health_data and hud_state.health_data.current_fraction) or 0,
        corruption_fraction = (hud_state.health_data and hud_state.health_data.corruption_fraction) or 0,
        toughness_fraction  = (hud_state.toughness_data and hud_state.toughness_data.display_fraction) or 0,
        has_overshield      = hud_state.toughness_data and hud_state.toughness_data.has_overshield or false,
        -- near_* left nil → THV can read mod.near_* if needed
    }

    local vis_result = { bar = true, text = false }
    if THV and mod.thv_player then
        vis_result = mod.thv_player(ctx)
    end

    local overall_vis = vis_result.bar
    local cor_mv, hp_mv, dmg_mv = cor_s.material_values, hp_s.material_values, dmg_s.material_values

    if not overall_vis then
        -- Zero amounts so fragments don't linger when hidden
        if cor_mv.amount ~= 0 then cor_mv.amount = 0 end
        if hp_mv.amount ~= 0 then hp_mv.amount = 0 end
        if dmg_mv.amount ~= 0 then dmg_mv.amount = 0 end
        _hide_all_segments(cor_s, hp_s, dmg_s, cor_e, hp_e, dmg_e, cor_w, hp_w, dmg_w)
        return
    end

    -- ── Presentation logic ────────────────────────────────────────────────────
    local changed         = false

    local display_tough   = math.clamp(ctx.toughness_fraction or 0, 0, 1)
    local health_frac     = math.clamp(ctx.hp_fraction or 0, 0, 1)
    local corrupt_frac    = math.clamp(ctx.corruption_fraction or 0, 0, 1)
    local has_overshield  = ctx.has_overshield == true

    -- Envelopes for health/damage/corruption
    local HP_GAP, COR_GAP = 0.025, 0.025

    local hp_end          = TOUGH_ARC_MIN + TOUGH_TOTAL * health_frac
    local cor_start       = TOUGH_ARC_MAX - TOUGH_TOTAL * corrupt_frac

    local hp_top_envelope = math.max(TOUGH_ARC_MIN, hp_end - (HP_GAP / 2))
    local dmg_bottom_env  = math.min(TOUGH_ARC_MAX, hp_end + (HP_GAP / 2))

    local cor_bottom_env  = math.max(TOUGH_ARC_MIN, cor_start + (COR_GAP / 2))
    local dmg_top_env     = math.min(TOUGH_ARC_MAX, cor_start - (COR_GAP / 2))

    -- ensure proper ordering
    dmg_bottom_env        = math.max(dmg_bottom_env, hp_top_envelope)
    if dmg_top_env < dmg_bottom_env then dmg_top_env = dmg_bottom_env end
    cor_bottom_env = math.max(cor_bottom_env, dmg_top_env)
    if cor_bottom_env > TOUGH_ARC_MAX then cor_bottom_env = TOUGH_ARC_MAX end

    -- Set base envelopes (these are the full segment spans)
    changed = U.mv_set_arc(hp_mv, hp_top_envelope, TOUGH_ARC_MIN, changed)
    changed = U.mv_set_arc(dmg_mv, dmg_top_env, dmg_bottom_env, changed)
    changed = U.mv_set_arc(cor_mv, TOUGH_ARC_MAX, cor_bottom_env, changed)

    -- Compute where the *toughness fill* lies
    local fill_point = TOUGH_ARC_MIN + (TOUGH_TOTAL * display_tough)

    local function segment_fill(top, bottom, target)
        local len = top - bottom
        if len > EPS then
            return math.clamp((target - bottom) / len, 0, 1)
        end
        return (target >= bottom) and 1 or 0
    end

    local hp_fill  = segment_fill(hp_mv.arc_top_bottom[1], hp_mv.arc_top_bottom[2], fill_point)
    local dmg_fill = (hp_fill >= 1) and segment_fill(dmg_mv.arc_top_bottom[1], dmg_mv.arc_top_bottom[2], fill_point) or 0
    local cor_fill = (hp_fill >= 1 and dmg_fill >= 1)
        and segment_fill(cor_mv.arc_top_bottom[1], cor_mv.arc_top_bottom[2], fill_point) or 0

    -- Colors
    local main_outline, damage_outline, corrupt_outline
    if has_overshield then
        local gold = mod.PALETTE_RGBA1.TOUGHNESS_OVERSHIELD
        main_outline, damage_outline, corrupt_outline = gold, gold, gold
    else
        main_outline    = mod.PALETTE_RGBA1.TOUGHNESS_TEAL
        damage_outline  = mod.PALETTE_RGBA1.default_damage_color_rgba
        corrupt_outline = mod.PALETTE_RGBA1.default_corruption_color_rgba
    end

    -- Directly apply outline colors to bases (fix for full segments where edge is hidden).
    changed        = U.mv_set_outline(hp_mv, main_outline, changed)
    changed        = U.mv_set_outline(dmg_mv, damage_outline, changed)
    changed        = U.mv_set_outline(cor_mv, corrupt_outline, changed)

    -- Ensure base segment outlines visible when they have non-zero span
    local show_hp  = (hp_mv.arc_top_bottom[1] > hp_mv.arc_top_bottom[2] + EPS)
    local show_dmg = (dmg_mv.arc_top_bottom[1] > dmg_mv.arc_top_bottom[2] + EPS)
    local show_cor = (cor_mv.arc_top_bottom[1] > cor_mv.arc_top_bottom[2] + EPS)
        and (corrupt_frac > EPS)

    U.set_style_visible(hp_s, show_hp)
    U.set_style_visible(dmg_s, show_dmg)
    U.set_style_visible(cor_s, show_cor)

    -- Drive the notch on whichever segment is partially filled
    if _drive_notch(hp_s, hp_mv, hp_e, hp_e_mv,
            hp_mv.arc_top_bottom[1], hp_mv.arc_top_bottom[2], hp_fill, main_outline) then
        changed = true
    end
    if _drive_notch(dmg_s, dmg_mv, dmg_e, dmg_e_mv,
            dmg_mv.arc_top_bottom[1], dmg_mv.arc_top_bottom[2], dmg_fill, damage_outline) then
        changed = true
    end
    if _drive_notch(cor_s, cor_mv, cor_e, cor_e_mv,
            cor_mv.arc_top_bottom[1], cor_mv.arc_top_bottom[2], cor_fill, corrupt_outline) then
        changed = true
    end

    -- Centralized "recent change" latch: bump when the damage span changes
    local dmg_len = (dmg_mv.arc_top_bottom[1] > dmg_mv.arc_top_bottom[2] + EPS)
        and (dmg_mv.arc_top_bottom[1] - dmg_mv.arc_top_bottom[2]) or 0
    if math.abs(dmg_len - (hud_element._previous_dmg_effective_length or 0)) > 0.001 then
        if mod.thv_player_recent_change_bump then
            mod.thv_player_recent_change_bump()
        end
        changed = true
    end
    hud_element._previous_dmg_effective_length = dmg_len

    if changed then
        cor_w.dirty = true
        hp_w.dirty  = true
        dmg_w.dirty = true
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HP numeric text (visibility via THV; text mode via dropdown)
-- ─────────────────────────────────────────────────────────────────────────────
function ToughnessHpFeature.update_health_text(_hud_element, widget, hud_state, _hotkey_override_unused)
    if not widget or not widget.style then return end

    local style   = widget.style.health_text_style
    local content = widget.content
    if not style then return end

    -- Delegate visibility to THV (same ctx as the ring)
    local ctx = {
        hp_fraction         = (hud_state.health_data and hud_state.health_data.current_fraction) or 0,
        corruption_fraction = (hud_state.health_data and hud_state.health_data.corruption_fraction) or 0,
        toughness_fraction  = (hud_state.toughness_data and hud_state.toughness_data.display_fraction) or 0,
        has_overshield      = hud_state.toughness_data and hud_state.toughness_data.has_overshield or false,
    }

    local visible = false
    if THV and mod.thv_player then
        local res = mod.thv_player(ctx)
        visible = res.text
    end

    local changed = false
    if style.visible ~= visible then
        style.visible = visible
        changed       = true
    end

    if visible then
        local text = string.format("%d",
            math.floor((hud_state.health_data and hud_state.health_data.current_health) or 0))
        if content.health_text_value ~= text then
            content.health_text_value = text
            changed                   = true
        end
    end

    if changed then widget.dirty = true end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- add_widgets(...) — factory for corruption/health/damage ring widgets
-- ─────────────────────────────────────────────────────────────────────────────
function ToughnessHpFeature.add_widgets(dst, _, params, palettes)
    dst                     = dst or {}
    params                  = params or {}
    palettes                = palettes or {}

    local size              = params.size or { 240, 240 }
    local outer_size_factor = params.outer_size_factor or 1.5
    local outer_size        = { size[1] * outer_size_factor, size[2] * outer_size_factor }

    local ARGB              = (palettes.ARGB or mod.PALETTE_ARGB255) or {}
    local RGBA1             = (palettes.RGBA1 or mod.PALETTE_RGBA1) or {}

    local white             = ARGB.GENERIC_WHITE or { 255, 255, 255, 255 }

    local function make_pass(style_id, amount, arc_tb, outline_rgba, z)
        return {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = style_id,
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, z or 1 },
                size                 = outer_size,
                color                = white,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = amount,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = arc_tb,
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(outline_rgba),
                },
            },
        }
    end

    -- Corruption (base + edge)
    dst.toughness_bar_corruption = UIWidget.create_definition({
        make_pass("corruption_segment", 1, { 0, 0 }, RGBA1.default_corruption_color_rgba, 0),
        make_pass("corruption_segment_edge", 0, { 0, 0 }, RGBA1.default_corruption_color_rgba, 1),
    }, "toughness_bar_corruption")

    -- Health (base + edge) — base starts visible=true in original defs; keep behavior
    local health_base            = make_pass("health_segment", 0, { 0, 0 }, RGBA1.TOUGHNESS_TEAL, 1)
    health_base.style.visible    = true
    dst.toughness_bar_health     = UIWidget.create_definition({
        health_base,
        make_pass("health_segment_edge", 0, { 0, 0 }, RGBA1.TOUGHNESS_TEAL, 2),
    }, "toughness_bar_health")

    -- Damage (base + edge) — base starts visible=true in original defs; keep behavior
    local damage_base            = make_pass("damage_segment", 0, { 0, 0 }, RGBA1.default_damage_color_rgba, 2)
    damage_base.style.visible    = true
    dst.toughness_bar_damage     = UIWidget.create_definition({
        damage_base,
        make_pass("damage_segment_edge", 0, { 0, 0 }, RGBA1.default_damage_color_rgba, 3),
    }, "toughness_bar_damage")

    return dst
end

return ToughnessHpFeature
