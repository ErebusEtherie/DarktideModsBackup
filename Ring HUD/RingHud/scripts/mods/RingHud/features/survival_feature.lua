-- File: RingHud/scripts/mods/RingHud/features/survival_feature.lua
local mod = get_mod("RingHud")
if not mod then return end

local Colors                       = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local Notch                        = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local SurvivalFeature              = {}

-- =========================
-- Local colour defaults (RGBA 0..1)  -- TODO Color
-- =========================
local dodge_color_full_rgba        = { 0.61, 1.00, 0.31, 1.00 }
local dodge_color_negative_rgba    = { 1.00, 0.31, 0.31, 1.00 }
local default_toughness_color_rgba = { 0.62, 0.77, 0.77, 1.00 } -- teal
local default_damage_color_rgba    = { 0.50, 0.50, 0.50, 1.00 }
local EPS                          = 0.001

-- =========================
-- Stamina arc envelope (must match widget defaults)
-- =========================
local STAMINA_ARC_BOTTOM           = 0.51
local STAMINA_ARC_TOP              = 0.99
local STAMINA_ARC_TOTAL            = (STAMINA_ARC_TOP - STAMINA_ARC_BOTTOM)

-- =========================
-- Toughness ring envelope
-- =========================
local TOUGH_ARC_MIN                = -0.19
local TOUGH_ARC_MAX                = 0.19
local TOUGH_TOTAL                  = (TOUGH_ARC_MAX - TOUGH_ARC_MIN)

-- Utility: set style visibility (and alpha if present)
local function _set_style_visible(style, is_visible)
    if not style then return false end
    local changed = false
    if style.visible ~= is_visible then
        style.visible = is_visible
        changed = true
    end
    if style.color then
        local a = is_visible and 255 or 0
        if style.color[1] ~= a then
            style.color[1] = a
            changed = true
        end
    end
    return changed
end

-- Resolve the local player's unit (robustly)
local function _get_player_unit(hud_element, hud_state)
    if hud_state and hud_state.player_unit then
        return hud_state.player_unit
    end
    if hud_element and hud_element._player and hud_element._player.player_unit then
        return hud_element._player.player_unit
    end
    local lp = Managers.player and Managers.player:local_player_safe(1)
    return (lp and lp.player_unit) or nil
end

-- Ground-truth toughness state from the extension:
-- returns "overshield" | "broken" | nil
local function _toughness_state(unit)
    if not unit or not Unit.alive(unit) then return nil end
    local ext = ScriptUnit.has_extension(unit, "toughness_system") and ScriptUnit.extension(unit, "toughness_system")
    if not ext then return nil end

    local rem = ext.remaining_toughness and ext:remaining_toughness() or nil
    if rem == nil then return nil end

    local vis        = ext.max_toughness_visual and ext:max_toughness_visual() or nil
    local EPS_POINTS = 5 -- epsilon in *points* (not fraction) for float jitter

    if vis and (rem > vis + EPS_POINTS) then
        return "overshield"
    end
    if rem <= EPS_POINTS then
        return "broken"
    end
    return nil
end

---------------------------------------------------------------------
-- Dodge
---------------------------------------------------------------------
function SurvivalFeature.update_dodge(widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local style = widget.style
    local data  = hud_state and hud_state.dodge_data or nil
    if not data then return end

    local num_disp = data.efficient_dodges_display or 0
    local changed  = false

    -- Build arc slices only if we have something to draw
    local arcs     = {}
    if num_disp > 0 then
        local ARC_MIN, ARC_MAX = 0.51, 0.99
        local GAP              = 0.03
        local total_arc        = ARC_MAX - ARC_MIN
        local visual_space     = math.max(0, total_arc - (math.max(0, num_disp - 1) * GAP))
        local seg_arc          = (num_disp > 0) and (visual_space / num_disp) or 0
        local current_bottom   = ARC_MIN

        for i = 1, num_disp do
            local top = math.min(ARC_MAX, current_bottom + seg_arc)
            if i == num_disp then top = ARC_MAX end
            arcs[i] = { top, current_bottom }
            current_bottom = top + GAP
        end
    end

    local outline_color -- TODO Color
    if data.has_infinite or (data.max_efficient_dodges_actual > 0 and data.remaining_efficient >= data.max_efficient_dodges_actual) then
        outline_color = dodge_color_full_rgba
    elseif (data.remaining_efficient or 0) > 0 then
        outline_color = mod.PALETTE_RGBA1.dodge_color_positive_rgba
    else
        outline_color = dodge_color_negative_rgba
    end

    -- Settings (robust): default 1 (per schema), 0 = always visible, -1 = always hidden
    local threshold    = mod._settings.dodge_viz_threshold

    local max_segments = mod.MAX_DODGE_SEGMENTS or 6
    local current_max  = math.clamp(num_disp, 0, max_segments)

    for i = 1, max_segments do
        local seg_style = style["dodge_bar_" .. i]
        if seg_style and seg_style.material_values then
            local mat              = seg_style.material_values
            local within_max       = (i <= current_max)

            -- Visibility heuristic (normal rules) – applies only within capacity
            local normally_visible = false
            if within_max and num_disp > 0 then
                normally_visible = (threshold == 0)
                    or data.has_infinite
                    or (num_disp <= threshold)
                    or ((data.remaining_efficient or 0) <= threshold and (data.has_infinite or (data.remaining_efficient or 0) < num_disp))
            end

            -- Force show lifts the *root*, but never draws beyond within_max
            local seg_visible = (hotkey_override or normally_visible) and within_max
            local seg_amount  = 0

            if seg_visible and within_max and num_disp > 0 then
                local arc = arcs[i] or { 0.51, 0.51 }
                if not mat.arc_top_bottom or mat.arc_top_bottom[1] ~= arc[1] or mat.arc_top_bottom[2] ~= arc[2] then
                    mat.arc_top_bottom = arc
                    changed = true
                end

                seg_amount = (data.has_infinite or (data.remaining_efficient or 0) >= i) and 1 or 0

                local oc = mat.outline_color
                local nc = outline_color -- TODO Util?
                if not oc or oc[1] ~= nc[1] or oc[2] ~= nc[2] or oc[3] ~= nc[3] or oc[4] ~= nc[4] then
                    mat.outline_color = table.clone(nc)
                    changed = true
                end
            end

            if _set_style_visible(seg_style, seg_visible) then
                changed = true
            end

            if mat.amount ~= seg_amount then
                mat.amount = seg_amount
                changed = true
            end
        end
    end

    if changed then widget.dirty = true end
end

---------------------------------------------------------------------
-- Stamina (uses shared notch_split)
---------------------------------------------------------------------
function SurvivalFeature.update_stamina(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local style      = widget.style
    local base_style = style.stamina_bar
    local edge_style = style.stamina_edge
    if not (base_style and base_style.material_values and edge_style and edge_style.material_values) then
        return
    end

    local fraction             = (hud_state and hud_state.stamina_fraction) or 0
    local changed              = false

    -- Visibility gating (same semantics as before)
    local visible_now_normally = false
    local threshold            = mod._settings.stamina_viz_threshold -- Default 0.25 per schema

    if threshold == 0 then
        visible_now_normally = true
    elseif hud_element._stamina_bar_latched_on then
        visible_now_normally = (fraction < 1.0)
    elseif fraction < 1.0 and fraction <= threshold then
        visible_now_normally = true
    end

    if hud_state and hud_state.is_veteran_deadshot_adsing then
        visible_now_normally = true
    end

    local overall_visible  = hotkey_override or visible_now_normally
    local display_fraction = (hotkey_override and fraction) or (visible_now_normally and fraction or 0)
    display_fraction       = math.clamp(display_fraction, 0, 1)

    local base_mv          = base_style.material_values
    local edge_mv          = edge_style.material_values

    -- Split parent arc into base(1) + edge(0) with fixed 0.01 gap (from Notch)
    local r                = Notch.notch_split(STAMINA_ARC_TOP, STAMINA_ARC_BOTTOM, display_fraction)

    -- Base slice
    if base_mv.amount ~= 1 then
        base_mv.amount = 1; changed = true
    end
    local curb = base_mv.arc_top_bottom
    if (not curb) or curb[1] ~= r.base.top or curb[2] ~= r.base.bottom then
        base_mv.arc_top_bottom = { r.base.top, r.base.bottom }; changed = true
    end
    if base_style.visible ~= (overall_visible and r.base.show) then
        base_style.visible = (overall_visible and r.base.show); changed = true
    end

    -- Edge sliver (unfilled)
    if edge_mv.amount ~= 0 then
        edge_mv.amount = 0; changed = true
    end
    local cure = edge_mv.arc_top_bottom
    if (not cure) or cure[1] ~= r.edge.top or cure[2] ~= r.edge.bottom then
        edge_mv.arc_top_bottom = { r.edge.top, r.edge.bottom }; changed = true
    end
    if edge_style.visible ~= (overall_visible and r.edge.show) then
        edge_style.visible = (overall_visible and r.edge.show); changed = true
    end

    if changed then widget.dirty = true end
end

---------------------------------------------------------------------
-- Toughness+HP and HP numeric text
---------------------------------------------------------------------
function SurvivalFeature.update_toughness_and_health(hud_element, widgets, hud_state, hotkey_override)
    if not (widgets and widgets.toughness_bar_corruption and widgets.toughness_bar_health and widgets.toughness_bar_damage) then return end

    local cor_w, hp_w, dmg_w = widgets.toughness_bar_corruption, widgets.toughness_bar_health,
        widgets.toughness_bar_damage
    if not (cor_w.style and hp_w.style and dmg_w.style) then return end

    -- Base passes
    local cor_s = cor_w.style.corruption_segment
    local hp_s  = hp_w.style.health_segment
    local dmg_s = dmg_w.style.damage_segment
    if not (cor_s and cor_s.material_values and hp_s and hp_s.material_values and dmg_s and dmg_s.material_values) then return end

    -- Edge passes (for the notch)
    local cor_e       = cor_w.style.corruption_segment_edge
    local hp_e        = hp_w.style.health_segment_edge
    local dmg_e       = dmg_w.style.damage_segment_edge
    local cor_e_mv    = cor_e and cor_e.material_values
    local hp_e_mv     = hp_e and hp_e.material_values
    local dmg_e_mv    = dmg_e and dmg_e.material_values

    local tbd_setting = mod._settings.toughness_bar_dropdown

    -- Early out: whole ring disabled
    if tbd_setting == "toughness_bar_disabled" then
        local changed_by_disable = false
        if _set_style_visible(cor_s, false) then changed_by_disable = true end
        if _set_style_visible(hp_s, false) then changed_by_disable = true end
        if _set_style_visible(dmg_s, false) then changed_by_disable = true end
        if cor_e and _set_style_visible(cor_e, false) then changed_by_disable = true end
        if hp_e and _set_style_visible(hp_e, false) then changed_by_disable = true end
        if dmg_e and _set_style_visible(dmg_e, false) then changed_by_disable = true end

        if cor_s.material_values.amount ~= 0 then
            cor_s.material_values.amount = 0; changed_by_disable = true
        end
        if hp_s.material_values.amount ~= 0 then
            hp_s.material_values.amount = 0; changed_by_disable = true
        end
        if dmg_s.material_values.amount ~= 0 then
            dmg_s.material_values.amount = 0; changed_by_disable = true
        end

        if changed_by_disable then
            cor_w.dirty = true; hp_w.dirty = true; dmg_w.dirty = true
        end
        return
    end

    local cor_mv, hp_mv, dmg_mv = cor_s.material_values, hp_s.material_values, dmg_s.material_values
    local changed               = false

    local display_tough         = math.clamp(
        (hud_state.toughness_data and hud_state.toughness_data.display_fraction) or 0, 0, 1)

    local health_frac, corrupt_frac
    if tbd_setting == "toughness_bar_always" then
        health_frac, corrupt_frac = 1.0, 0.0
    else
        health_frac  = (hud_state.health_data and hud_state.health_data.current_fraction) or 0
        corrupt_frac = (hud_state.health_data and hud_state.health_data.corruption_fraction) or 0
    end

    local unit            = _get_player_unit(hud_element, hud_state)
    local tough_state     = _toughness_state(unit)
    local has_overshield  = (tough_state == "overshield")

    -- Envelopes for health/damage/corruption (same as before)
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

    local function set_arc(mv, top, bottom)
        local t = math.max(bottom, top)
        local cur = mv.arc_top_bottom
        if not cur or cur[1] ~= t or cur[2] ~= bottom then
            mv.arc_top_bottom = { t, bottom }
            changed = true
        end
    end

    -- Set base envelopes (these are the full segment spans)
    set_arc(hp_mv, hp_top_envelope, TOUGH_ARC_MIN)
    set_arc(dmg_mv, dmg_top_env, dmg_bottom_env)
    set_arc(cor_mv, TOUGH_ARC_MAX, cor_bottom_env)

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
    local cor_fill = (hp_fill >= 1 and dmg_fill >= 1) and
        segment_fill(cor_mv.arc_top_bottom[1], cor_mv.arc_top_bottom[2], fill_point) or 0

    -- Colors
    local main_outline, damage_outline, corrupt_outline
    if has_overshield then
        local gold = mod.PALETTE_RGBA1.TOUGHNESS_OVERSHIELD
        main_outline, damage_outline, corrupt_outline = gold, gold, gold
    else
        main_outline    = default_toughness_color_rgba
        damage_outline  = default_damage_color_rgba
        corrupt_outline = mod.PALETTE_RGBA1.default_corruption_color_rgba
    end

    local function set_outline(mv, color) -- TODO Util?
        local oc = mv.outline_color
        if (not oc) or oc[1] ~= color[1] or oc[2] ~= color[2] or oc[3] ~= color[3] or oc[4] ~= color[4] then
            mv.outline_color = table.clone(color)
            changed = true
        end
    end

    set_outline(hp_mv, main_outline)
    set_outline(dmg_mv, damage_outline)
    set_outline(cor_mv, corrupt_outline)

    -- Helper to drive the notch for a specific segment (now using Notch.notch_split)
    local function drive_notch(base_style, base_mv, edge_style, edge_mv, seg_top, seg_bottom, seg_fill, edge_color)
        if not (base_style and base_mv) then return end

        local seg_len = seg_top - seg_bottom
        if seg_len <= (mod.NOTCH_EPSILON or 1e-4) then
            _set_style_visible(base_style, false)
            if edge_style then _set_style_visible(edge_style, false) end
            base_mv.amount = 0
            if edge_mv then edge_mv.amount = 0 end
            return
        end

        -- Always show the base segment outline for any non-zero span
        _set_style_visible(base_style, true)

        -- EMPTY → outline only, full segment span; edge hidden
        if seg_fill <= (mod.NOTCH_EPSILON or 1e-4) then
            if base_mv.amount ~= 0 then
                base_mv.amount = 0; changed = true
            end
            set_arc(base_mv, seg_top, seg_bottom)
            if edge_style and edge_mv then
                _set_style_visible(edge_style, false)
                if edge_mv.amount ~= 0 then
                    edge_mv.amount = 0; changed = true
                end
            end
            return
        end

        -- FULL → filled base over full span; edge hidden
        if seg_fill >= 1 - (mod.NOTCH_EPSILON or 1e-4) then
            if base_mv.amount ~= 1 then
                base_mv.amount = 1; changed = true
            end
            set_arc(base_mv, seg_top, seg_bottom)
            if edge_style and edge_mv then
                _set_style_visible(edge_style, false)
                if edge_mv.amount ~= 0 then
                    edge_mv.amount = 0; changed = true
                end
            end
            return
        end

        -- PARTIAL → split into filled base and unfilled edge sliver
        local r = Notch.notch_split(seg_top, seg_bottom, seg_fill)

        -- Base (filled)
        if base_mv.amount ~= 1 then
            base_mv.amount = 1; changed = true
        end
        set_arc(base_mv, r.base.top, r.base.bottom)

        -- Edge (unfilled) with outline tint
        if edge_style and edge_mv then
            if edge_mv.amount ~= 0 then
                edge_mv.amount = 0; changed = true
            end
            set_arc(edge_mv, r.edge.top, r.edge.bottom)
            local oc = edge_mv.outline_color
            if (not oc) or oc[1] ~= edge_color[1] or oc[2] ~= edge_color[2] or oc[3] ~= edge_color[3] or oc[4] ~= edge_color[4] then
                edge_mv.outline_color = table.clone(edge_color); changed = true
            end
            _set_style_visible(edge_style, r.edge.show)
        end
    end

    -- Visibility context (unchanged)
    local context_vis = (display_tough < 0.999)
        or (hud_element._health_change_visibility_timer > 0)
        or has_overshield
        or (mod.near_health_station and ((hud_state.health_data and hud_state.health_data.current_fraction) or 0) < 1.0)
        or (mod.near_medical_crate_deployable and (((hud_state.health_data and hud_state.health_data.current_fraction) or 0)
            + ((hud_state.health_data and hud_state.health_data.corruption_fraction) or 0)) < 1.0)
        or
        (mod.near_syringe_corruption_pocketable and (((hud_state.health_data and hud_state.health_data.current_fraction) or 0) < 0.85))
        or mod.reassure_health

    local dropdown_mode = mod._settings.toughness_bar_dropdown
    local overall_vis_normally =
        (dropdown_mode == "toughness_bar_always_hp" or dropdown_mode == "toughness_bar_always_hp_text" or dropdown_mode == "toughness_bar_always")
        and true or context_vis
    local overall_vis = hotkey_override or overall_vis_normally

    -- If not overall visible, just apply visibility and bail
    if not overall_vis then
        local any = false
        if _set_style_visible(hp_s, false) then any = true end
        if _set_style_visible(dmg_s, false) then any = true end
        if _set_style_visible(cor_s, false) then any = true end
        if hp_e and _set_style_visible(hp_e, false) then any = true end
        if dmg_e and _set_style_visible(dmg_e, false) then any = true end
        if cor_e and _set_style_visible(cor_e, false) then any = true end
        if any then
            hp_w.dirty = true; dmg_w.dirty = true; cor_w.dirty = true
        end
        return
    end

    -- Ensure base segment outlines visible when they have non-zero span
    local show_hp  = (hp_mv.arc_top_bottom[1] > hp_mv.arc_top_bottom[2] + EPS)
    local show_dmg = (dmg_mv.arc_top_bottom[1] > dmg_mv.arc_top_bottom[2] + EPS)
    local show_cor = (cor_mv.arc_top_bottom[1] > cor_mv.arc_top_bottom[2] + EPS)
        and ((hud_state.health_data and hud_state.health_data.corruption_fraction or 0) > EPS)

    _set_style_visible(hp_s, show_hp)
    _set_style_visible(dmg_s, show_dmg)
    _set_style_visible(cor_s, show_cor)

    -- Drive the notch on whichever segment is *partially* filled.
    -- Health
    drive_notch(hp_s, hp_mv, hp_e, hp_e_mv, hp_mv.arc_top_bottom[1], hp_mv.arc_top_bottom[2], hp_fill, main_outline)
    -- Damage (only meaningful once HP is full)
    drive_notch(dmg_s, dmg_mv, dmg_e, dmg_e_mv, dmg_mv.arc_top_bottom[1], dmg_mv.arc_top_bottom[2], dmg_fill,
        damage_outline)
    -- Corruption (only meaningful once HP & Damage are full)
    drive_notch(cor_s, cor_mv, cor_e, cor_e_mv, cor_mv.arc_top_bottom[1], cor_mv.arc_top_bottom[2], cor_fill,
        corrupt_outline)

    -- Track damage span changes to trigger reassurance timer (unchanged logic)
    local dmg_len = (dmg_mv.arc_top_bottom[1] > dmg_mv.arc_top_bottom[2] + EPS)
        and (dmg_mv.arc_top_bottom[1] - dmg_mv.arc_top_bottom[2]) or 0
    if math.abs(dmg_len - (hud_element._previous_dmg_effective_length or 0)) > 0.001 then
        hud_element._health_change_visibility_timer = hud_element._health_change_visibility_duration
        changed = true
    end
    hud_element._previous_dmg_effective_length = dmg_len

    if (hud_element._has_overshield_active ~= (tough_state == "overshield")) then changed = true end
    hud_element._has_overshield_active = (tough_state == "overshield")

    if changed then
        widgets.toughness_bar_corruption.dirty = true
        widgets.toughness_bar_health.dirty     = true
        widgets.toughness_bar_damage.dirty     = true
    end
end

---------------------------------------------------------------------
-- HP numeric text (unchanged)
---------------------------------------------------------------------
function SurvivalFeature.update_health_text(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local style   = widget.style.health_text_style
    local content = widget.content
    if not style then return end

    local tbd = mod._settings.toughness_bar_dropdown
    local show_text_mode = (tbd == "toughness_bar_auto_hp_text") or (tbd == "toughness_bar_always_hp_text")

    if not show_text_mode then
        if style.visible then
            style.visible = false; widget.dirty = true
        end
        return
    end

    local display_tough    = math.clamp((hud_state.toughness_data and hud_state.toughness_data.display_fraction) or 0, 0,
        1)
    local unit             = (function()
        if hud_state and hud_state.player_unit then return hud_state.player_unit end
        if hud_element and hud_element._player and hud_element._player.player_unit then
            return hud_element._player.player_unit
        end
        local lp = Managers.player and Managers.player:local_player_safe(1)
        return (lp and lp.player_unit) or nil
    end)()

    local visible_normally = (display_tough < 0.999)
        or (hud_element._health_change_visibility_timer > 0)
        or (function(u)
            if not u or not Unit.alive(u) then return false end
            local ext = ScriptUnit.has_extension(u, "toughness_system") and ScriptUnit.extension(u, "toughness_system")
            if not ext then return false end
            local rem = ext.remaining_toughness and ext:remaining_toughness() or nil
            local vis = ext.max_toughness_visual and ext:max_toughness_visual() or nil
            return (vis and rem and rem > vis + 0.5) or false
        end)(unit)
        or mod.near_health_station
        or mod.near_medical_crate_deployable
        or mod.near_syringe_corruption_pocketable
        or mod.reassure_health

    local visible          = hotkey_override or visible_normally

    local changed          = false
    if style.visible ~= visible then
        style.visible = visible; changed = true
    end

    if visible then
        local text = string.format("%d",
            math.floor((hud_state.health_data and hud_state.health_data.current_health) or 0))
        if content.health_text_value ~= text then
            content.health_text_value = text; changed = true
        end
    end

    if changed then widget.dirty = true end
end

return SurvivalFeature
