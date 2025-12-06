-- File: RingHud/scripts/mods/RingHud/features/munitions_feature.lua
local mod = get_mod("RingHud"); if not mod then return end

local Colors                = mod.colors or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local RingHudUtils          = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local Notch                 = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split") -- notch_split / notch_apply
local MunitionsFeature      = {}

local GRENADE_OUTLINE_COLOR = mod.PALETTE_RGBA1.dodge_color_full_rgba -- {0.61,1.00,0.31,1.00}
local AMMO_CLIP_SEGMENT_GAP = 0.015                                   -- TODO Evaluate for constants
local GRENADE_ARC_MIN       = -0.25
local GRENADE_ARC_MAX       = 0.25
local GRENADE_SEGMENT_GAP   = 0.025

function MunitionsFeature.update_grenades(widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local grenade_bar_dropdown = mod._settings.grenade_bar_dropdown

    local style                = widget.style
    local data                 = hud_state.grenade_data or {}
    local changed              = false

    -- Use the effective max coming from state (observed+latched). Fallbacks are kept for safety.
    local current              = data.current or data.current_charges or 0
    local live_max             = data.live_max or data.max or data.max_charges or 0

    -- Treat non-charge blitz (live_max <= 0) as "no bar at all", even on force-show
    local charge_based         = (live_max or 0) > 0
    if not charge_based then
        -- Hide every grenade segment, reset materials, and bail.
        for i = 1, mod.MAX_GRENADE_SEGMENTS_DISPLAY do
            local seg_style  = style["grenade_segment_" .. i]
            local edge_style = style["grenade_segment_edge_" .. i]
            if seg_style then
                if seg_style.visible then
                    seg_style.visible = false; changed = true
                end
                local mat = seg_style.material_values
                if mat then
                    if mat.amount ~= 0 then
                        mat.amount = 0; changed = true
                    end
                    local atb = mat.arc_top_bottom
                    if not atb or atb[1] ~= 0 or atb[2] ~= 0 then
                        mat.arc_top_bottom = { 0, 0 }; changed = true
                    end
                end
            end
            if edge_style then
                if edge_style.visible then
                    edge_style.visible = false; changed = true
                end
                local em = edge_style.material_values
                if em and em.amount ~= 0 then
                    em.amount = 0; changed = true
                end
            end
        end
        if changed then widget.dirty = true end
        return
    end

    local overall_visible_normally = false
    if live_max and live_max > 0 then
        if grenade_bar_dropdown == "grenade_hide_empty_compact" or grenade_bar_dropdown == "grenade_hide_empty" then
            if current and current > 0 then
                overall_visible_normally = true
            elseif current == 0 and data.is_regenerating and data.regen_progress and data.regen_progress > 0.001 then
                overall_visible_normally = true
            end
        else
            if current and live_max then
                if current < live_max then
                    overall_visible_normally = true
                elseif current >= live_max then
                    if data.is_regenerating and data.regen_progress and data.regen_progress > 0.001 and
                        data.regen_progress < 0.999 then
                        overall_visible_normally = true
                    end
                end
            end
        end
    end

    local should_render_bar_at_all = (hotkey_override or overall_visible_normally)
        and grenade_bar_dropdown ~= "grenade_disabled"

    -- Limit how many segments we actually draw
    local num_seg_calc = math.min(live_max or 0, mod.MAX_GRENADE_SEGMENTS_DISPLAY)

    -- Precompute arcs
    local arcs = {}
    if num_seg_calc > 0 then
        local total_arc      = GRENADE_ARC_MAX - GRENADE_ARC_MIN
        local num_gaps       = math.max(0, num_seg_calc - 1)
        local gap_space      = num_gaps * GRENADE_SEGMENT_GAP
        local visual_space   = math.max(0, total_arc - gap_space)
        local seg_arc        = (num_seg_calc > 0) and (visual_space / num_seg_calc) or 0
        local current_bottom = GRENADE_ARC_MIN
        for i = 1, num_seg_calc do
            local top = math.min(GRENADE_ARC_MAX, current_bottom + seg_arc)
            if i == num_seg_calc then top = GRENADE_ARC_MAX end
            arcs[i] = { top, current_bottom }
            current_bottom = top + GRENADE_SEGMENT_GAP
        end
    end

    for i = 1, mod.MAX_GRENADE_SEGMENTS_DISPLAY do
        local seg_style  = style["grenade_segment_" .. i]
        local edge_style = style["grenade_segment_edge_" .. i] -- may be nil until defs are updated
        if seg_style and seg_style.material_values then
            local mat                         = seg_style.material_values

            local final_segment_visible_state = false
            local final_segment_amount        = 0
            local final_segment_color         = mod.PALETTE_RGBA1.default_damage_color_rgba
            local final_segment_arc           = { 0, 0 }

            if should_render_bar_at_all then
                local seg_vis_normally = false
                local seg_amt_normally = 0
                local seg_clr_normally = mod.PALETTE_RGBA1.default_damage_color_rgba

                if overall_visible_normally and i <= num_seg_calc and current ~= nil then
                    if i <= current then
                        seg_vis_normally = true
                        seg_amt_normally = 1
                        seg_clr_normally = GRENADE_OUTLINE_COLOR
                    else
                        local is_compact_mode =
                            (grenade_bar_dropdown == "grenade_hide_full_compact" or
                                grenade_bar_dropdown == "grenade_hide_empty_compact")
                        if is_compact_mode then
                            if i == current + 1 then
                                seg_vis_normally = true
                                if data.is_regenerating and data.regen_progress and data.regen_progress > 0.001 then
                                    seg_amt_normally = data.regen_progress
                                end
                            end
                        else
                            seg_vis_normally = true
                            if i == current + 1 then
                                if data.is_regenerating and data.regen_progress and data.regen_progress > 0.001 then
                                    seg_amt_normally = data.regen_progress
                                end
                            end
                        end
                    end
                end

                if hotkey_override then
                    -- Force show: show only the drawable segments, do not fabricate beyond num_seg_calc
                    final_segment_visible_state = i <= num_seg_calc
                    if final_segment_visible_state and current ~= nil then
                        if i <= current then
                            final_segment_amount = 1
                            final_segment_color  = GRENADE_OUTLINE_COLOR
                        elseif i == current + 1 and data.is_regenerating then
                            final_segment_amount = data.regen_progress or 0
                            final_segment_color  = mod.PALETTE_RGBA1.default_damage_color_rgba
                        else
                            final_segment_amount = 0
                            final_segment_color  = mod.PALETTE_RGBA1.default_damage_color_rgba
                        end
                    elseif final_segment_visible_state then
                        final_segment_amount = 0
                        final_segment_color  = mod.PALETTE_RGBA1.default_damage_color_rgba
                    end
                else
                    final_segment_visible_state = seg_vis_normally
                    final_segment_amount        = seg_amt_normally
                    final_segment_color         = seg_clr_normally
                end

                if final_segment_visible_state and arcs[i] then
                    final_segment_arc = arcs[i]
                end
            end

            -- === Apply (with notch only when 0 < amount < 1 and we have an edge pass) ===
            local arc_top, arc_bottom = final_segment_arc[1], final_segment_arc[2]
            local amt                 = final_segment_amount
            local want_partial_notch  = final_segment_visible_state and arcs[i] and (amt > 0 and amt < 1)

            if want_partial_notch and edge_style and edge_style.material_values then
                -- Split parent arc into base + edge (fixed gap)
                local res = Notch.notch_split(arc_top, arc_bottom, amt, nil, nil)

                -- Base (amount=1)
                local atb = mat.arc_top_bottom
                if not atb or atb[1] ~= res.base.top or atb[2] ~= res.base.bottom then
                    mat.arc_top_bottom = { res.base.top, res.base.bottom }; changed = true
                end
                if mat.amount ~= 1 then
                    mat.amount = 1; changed = true
                end
                local oc = mat.outline_color
                local nc = final_segment_color
                if not oc or oc[1] ~= nc[1] or oc[2] ~= nc[2] or oc[3] ~= nc[3] or oc[4] ~= nc[4] then
                    mat.outline_color = table.clone(nc); changed = true
                end

                -- Edge (amount=0)
                local em   = edge_style.material_values
                local eatb = em.arc_top_bottom
                if not eatb or eatb[1] ~= res.edge.top or eatb[2] ~= res.edge.bottom then
                    em.arc_top_bottom = { res.edge.top, res.edge.bottom }; changed = true
                end
                if em.amount ~= 0 then
                    em.amount = 0; changed = true
                end
                local eoc = em.outline_color
                if not eoc or eoc[1] ~= nc[1] or eoc[2] ~= nc[2] or eoc[3] ~= nc[3] or eoc[4] ~= nc[4] then
                    em.outline_color = table.clone(nc); changed = true
                end

                -- Visibility
                if seg_style.visible ~= (final_segment_visible_state and res.base.show) then
                    seg_style.visible = (final_segment_visible_state and res.base.show); changed = true
                end
                if edge_style.visible ~= (final_segment_visible_state and res.edge.show) then
                    edge_style.visible = (final_segment_visible_state and res.edge.show); changed = true
                end
            else
                -- Fallback / non-partial: classic single-pass behavior
                if seg_style.visible ~= final_segment_visible_state then
                    seg_style.visible = final_segment_visible_state; changed = true
                end
                if final_segment_visible_state then
                    if mat.amount ~= amt then
                        mat.amount = amt; changed = true
                    end
                    local oc = mat.outline_color
                    local nc = final_segment_color
                    if not oc or oc[1] ~= nc[1] or oc[2] ~= nc[2] or oc[3] ~= nc[3] or oc[4] ~= nc[4] then
                        mat.outline_color = table.clone(nc); changed = true
                    end
                    local atb = mat.arc_top_bottom
                    if not atb or atb[1] ~= arc_top or atb[2] ~= arc_bottom then
                        mat.arc_top_bottom = { arc_top, arc_bottom }; changed = true
                    end
                else
                    if mat.amount ~= 0 then
                        mat.amount = 0; changed = true
                    end
                    local atb = mat.arc_top_bottom
                    if not atb or atb[1] ~= 0 or atb[2] ~= 0 then
                        mat.arc_top_bottom = { 0, 0 }; changed = true
                    end
                end

                -- Make sure any edge pass (if present) is hidden for non-partial cases
                if edge_style and edge_style.visible then
                    edge_style.visible = false; changed = true
                end
                if edge_style and edge_style.material_values and edge_style.material_values.amount ~= 0 then
                    edge_style.material_values.amount = 0; changed = true
                end
            end
        end
    end

    if changed then widget.dirty = true end
end

function MunitionsFeature.update_ammo_clip_bar(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local ammo_clip_dropdown = mod._settings.ammo_clip_dropdown

    if ammo_clip_dropdown == "ammo_clip_disabled" or ammo_clip_dropdown == "ammo_clip_text" then
        local style = widget.style
        if style.ammo_clip_unfilled_background and style.ammo_clip_unfilled_background.visible then
            style.ammo_clip_unfilled_background.visible = false; widget.dirty = true
        end
        if style.ammo_clip_filled_single and style.ammo_clip_filled_single.visible then
            style.ammo_clip_filled_single.visible = false; widget.dirty = true
        end
        for i = 1, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
            local m = style["ammo_clip_filled_multi_" .. i]
            if m and m.visible then
                m.visible = false; widget.dirty = true
            end
        end
        return
    end

    local style                                              = widget.style
    local unfilled_style                                     = style.ammo_clip_unfilled_background
    local single_style                                       = style.ammo_clip_filled_single
    local data                                               = hud_state.ammo_data or {}
    local changed                                            = false

    -- Enforce numeric clip values (1.10-safe even if upstream ever passes arrays)
    local current_clip                                       = tonumber(data.current_clip) or 0
    local max_clip                                           = tonumber(data.max_clip) or 0

    local overall_visible_normally, clip_frac_normally       = false, 0
    local current_ammo_disp_normally, max_ammo_disp_normally = 0, 0

    if data.uses_ammo and max_clip > 0 then
        current_ammo_disp_normally = current_clip
        max_ammo_disp_normally     = max_clip
        clip_frac_normally         = (max_clip > 0) and (current_clip / max_clip) or 0
        overall_visible_normally   = current_clip < max_clip
    elseif hud_element._ammo_clip_latched_low then
        overall_visible_normally   = true
        current_ammo_disp_normally = hud_element._latched_current_clip_ammo
        max_ammo_disp_normally     = hud_element._latched_max_clip_ammo
        if max_ammo_disp_normally > 0 then
            clip_frac_normally = current_ammo_disp_normally / max_ammo_disp_normally
        else
            clip_frac_normally = 0
        end
    end

    local overall_visible   = false
    local clip_frac         = 0
    local current_ammo_disp = 0
    local max_ammo_disp     = 0

    if hotkey_override then
        if hud_element._latched_max_clip_ammo > 0 then
            overall_visible   = true
            current_ammo_disp = hud_element._latched_current_clip_ammo
            max_ammo_disp     = hud_element._latched_max_clip_ammo
            if max_ammo_disp > 0 then
                clip_frac = current_ammo_disp / max_ammo_disp
            else
                clip_frac = 0
            end
        else
            overall_visible = false
        end
    else
        overall_visible   = overall_visible_normally
        clip_frac         = clip_frac_normally
        current_ammo_disp = current_ammo_disp_normally
        max_ammo_disp     = max_ammo_disp_normally
    end

    if unfilled_style then
        if unfilled_style.visible ~= overall_visible then
            unfilled_style.visible = overall_visible; changed = true
        end
    end

    if overall_visible then
        local border_color
        if clip_frac >= 0.85 then
            border_color = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_HIGH
        elseif clip_frac >= 0.65 then
            border_color = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_MEDIUM_H
        elseif clip_frac >= 0.45 then
            border_color = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_MEDIUM_L
        elseif clip_frac >= 0.25 then
            border_color = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_LOW
        else
            border_color = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_CRITICAL
        end

        if max_ammo_disp > mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY then
            if single_style then
                if not single_style.visible then
                    single_style.visible = true; changed = true
                end
                local arc_len = (mod.AMMO_CLIP_ARC_MAX - mod.AMMO_CLIP_ARC_MIN) * clip_frac
                local arc_top = mod.AMMO_CLIP_ARC_MIN + arc_len
                local mat     = single_style.material_values
                if not mat.arc_top_bottom or mat.arc_top_bottom[1] ~= arc_top or
                    mat.arc_top_bottom[2] ~= mod.AMMO_CLIP_ARC_MIN then
                    mat.arc_top_bottom = { arc_top, mod.AMMO_CLIP_ARC_MIN }; changed = true
                end
                if not mat.outline_color or
                    mat.outline_color[1] ~= border_color[1] or
                    mat.outline_color[2] ~= border_color[2] or
                    mat.outline_color[3] ~= border_color[3] or
                    mat.outline_color[4] ~= border_color[4] then
                    mat.outline_color = table.clone(border_color); changed = true
                end
            end
            for i = 1, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
                local m = style["ammo_clip_filled_multi_" .. i]
                if m and m.visible then
                    m.visible = false; changed = true
                end
            end
        else
            if single_style and single_style.visible then
                single_style.visible = false; changed = true
            end

            local num_draw_seg = math.min(max_ammo_disp, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY)
            if max_ammo_disp == 0 and overall_visible then num_draw_seg = 1 end

            local arcs = {}
            if num_draw_seg > 0 then
                local total_arc  = mod.AMMO_CLIP_ARC_MAX - mod.AMMO_CLIP_ARC_MIN
                local num_gaps   = math.max(0, num_draw_seg - 1)
                local visual_sp  = math.max(0, total_arc - (num_gaps * AMMO_CLIP_SEGMENT_GAP))
                local seg_arc    = (num_draw_seg > 0) and (visual_sp / num_draw_seg) or 0
                local cur_bottom = mod.AMMO_CLIP_ARC_MIN
                for i = 1, num_draw_seg do
                    local top = math.min(mod.AMMO_CLIP_ARC_MAX, cur_bottom + seg_arc)
                    if i == num_draw_seg then top = mod.AMMO_CLIP_ARC_MAX end
                    arcs[i] = { top, cur_bottom }
                    cur_bottom = top + AMMO_CLIP_SEGMENT_GAP
                end
            end

            for i = 1, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
                local multi_s = style["ammo_clip_filled_multi_" .. i]
                if multi_s then
                    local mat     = multi_s.material_values
                    local seg_vis = i <= current_ammo_disp and i <= num_draw_seg and overall_visible
                    if multi_s.visible ~= seg_vis then
                        multi_s.visible = seg_vis; changed = true
                    end
                    if seg_vis then
                        if arcs[i] then
                            local atb = mat.arc_top_bottom
                            if not atb or atb[1] ~= arcs[i][1] or atb[2] ~= arcs[i][2] then
                                mat.arc_top_bottom = arcs[i]; changed = true
                            end
                        elseif num_draw_seg == 1 and i == 1 then
                            local atb = mat.arc_top_bottom
                            if not atb or atb[1] ~= mod.AMMO_CLIP_ARC_MIN or atb[2] ~= mod.AMMO_CLIP_ARC_MIN then
                                mat.arc_top_bottom = { mod.AMMO_CLIP_ARC_MIN, mod.AMMO_CLIP_ARC_MIN }; changed = true
                            end
                        end
                        local oc = mat.outline_color
                        if not oc or oc[1] ~= border_color[1] or oc[2] ~= border_color[2] or
                            oc[3] ~= border_color[3] or oc[4] ~= border_color[4] then
                            mat.outline_color = table.clone(border_color); changed = true
                        end
                    end
                end
            end
        end
    else
        if single_style and single_style.visible then
            single_style.visible = false; changed = true
        end
        for i = 1, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
            local m = style["ammo_clip_filled_multi_" .. i]
            if m and m.visible then
                m.visible = false; changed = true
            end
        end
    end

    if changed then widget.dirty = true end
end

-- RESERVE TEXT: computed *only* from hud_state.ammo_data (secondary slot),
-- never by scanning other slots. Latching is used only for visibility timing elsewhere.
function MunitionsFeature.update_ammo_reserve_text(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end
    local content               = widget.content
    local text_style            = widget.style.reserve_text_style
    local changed               = false

    local ammo_reserve_dropdown = mod._settings.ammo_reserve_dropdown

    local data                  = hud_state.ammo_data or {}
    local max_reserve           = tonumber(data.max_reserve) or 0
    local cur_reserve           = tonumber(data.current_reserve) or 0
    local has_finite_reserve    = max_reserve > 0

    -- Hide if disabled or infinite/no reserve
    if ammo_reserve_dropdown == "ammo_reserve_disabled" or not has_finite_reserve then
        if text_style and text_style.visible then
            text_style.visible = false; changed = true
        end
        if content.reserve_text_value ~= "" then
            content.reserve_text_value = ""; changed = true
        end
        if changed then widget.dirty = true end
        return
    end

    -- Compute fraction from secondary-only ammo_data
    local reserve_frac    = (max_reserve > 0) and math.clamp(cur_reserve / max_reserve, 0, 1) or 0
    local reserve_actual  = cur_reserve

    -- Decide visibility
    local show_text_final = false
    if ammo_reserve_dropdown == "ammo_reserve_percent_always"
        or ammo_reserve_dropdown == "ammo_reserve_actual_always" then
        show_text_final = true
    else
        local show_text_normally = false
        -- keep using the existing visibility timer + proximity heuristics
        if hud_element._ammo_reserve_visibility_timer > 0 then show_text_normally = true end
        if not show_text_normally and (
                (reserve_frac < 0.85 and mod.near_small_clip) or
                (reserve_frac < 0.65 and mod.near_large_clip) or
                (reserve_frac < 0.45 and mod.near_ammo_cache_deployable) or
                (reserve_frac < 0.25) or
                mod.reassure_ammo
            ) then
            show_text_normally = true
        end
        if hotkey_override or show_text_normally then show_text_final = true end
    end

    -- Value + color
    local text_val_final = ""
    local color_frac     = reserve_frac

    if show_text_final then
        if ammo_reserve_dropdown == "ammo_reserve_actual_auto"
            or ammo_reserve_dropdown == "ammo_reserve_actual_always" then
            text_val_final = string.format("%d", reserve_actual)
        else
            text_val_final = string.format(RingHudUtils.percent_num_format, reserve_frac * 100)
        end
    end

    if text_style then
        if text_style.visible ~= show_text_final then
            text_style.visible = show_text_final; changed = true
        end
        if show_text_final then
            local new_color
            if color_frac >= 0.85 then
                new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH
            elseif color_frac >= 0.65 then
                new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_H
            elseif color_frac >= 0.45 then
                new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L
            elseif color_frac >= 0.25 then
                new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_LOW
            else
                new_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_CRITICAL
            end
            local tc = text_style.text_color
            if not tc or tc[1] ~= new_color[1] or tc[2] ~= new_color[2] or tc[3] ~= new_color[3] or
                tc[4] ~= new_color[4] then
                text_style.text_color = table.clone(new_color); changed = true
            end
        end
    end

    if content.reserve_text_value ~= text_val_final then
        content.reserve_text_value = text_val_final; changed = true
    end

    if changed then widget.dirty = true end
end

function MunitionsFeature.update_ammo_clip_text(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local ammo_clip_dropdown = mod._settings.ammo_clip_dropdown

    if not (widget and widget.content and widget.style and widget.style.ammo_clip_text_style) then return end

    if ammo_clip_dropdown == "ammo_clip_disabled" or ammo_clip_dropdown == "ammo_clip_bar" then
        local c = widget.content
        local s = widget.style.ammo_clip_text_style
        if s.visible then
            s.visible = false; widget.dirty = true
        end
        if c.ammo_clip_value_text ~= "" then
            c.ammo_clip_value_text = ""; widget.dirty = true
        end
        return
    end

    local content                  = widget.content
    local text_style               = widget.style.ammo_clip_text_style
    local changed                  = false
    local data                     = hud_state.ammo_data or {}

    -- Numeric, 1.10-safe copy of clip values
    local current_clip             = tonumber(data.current_clip) or 0
    local max_clip                 = tonumber(data.max_clip) or 0

    local show_text_normally       = false
    local text_to_display_normally = ""
    local current_clip_for_text    = 0
    local max_clip_for_color_calc  = 0
    local has_valid_clip_for_text  = false

    if data.uses_ammo and max_clip > 0 then
        current_clip_for_text   = current_clip
        max_clip_for_color_calc = max_clip
        has_valid_clip_for_text = true
        if current_clip < max_clip then show_text_normally = true end
    elseif hud_element._ammo_clip_latched_low and hud_element._latched_max_clip_ammo and
        hud_element._latched_max_clip_ammo > 0 then
        current_clip_for_text   = hud_element._latched_current_clip_ammo
        max_clip_for_color_calc = hud_element._latched_max_clip_ammo
        has_valid_clip_for_text = true
        show_text_normally      = true
    end

    if show_text_normally and has_valid_clip_for_text then
        text_to_display_normally = string.format("%d", current_clip_for_text)
    end

    local show_text_final         = false
    local text_to_display_final   = ""
    local clip_fraction_for_color = 0

    if hotkey_override then
        if hud_element._latched_max_clip_ammo > 0 then
            show_text_final       = true
            text_to_display_final = string.format("%d", hud_element._latched_current_clip_ammo)
            if hud_element._latched_max_clip_ammo > 0 then
                clip_fraction_for_color =
                    hud_element._latched_current_clip_ammo / hud_element._latched_max_clip_ammo
            end
        else
            show_text_final       = false
            text_to_display_final = ""
        end
    else
        show_text_final       = show_text_normally
        text_to_display_final = text_to_display_normally
        if has_valid_clip_for_text and max_clip_for_color_calc > 0 then
            clip_fraction_for_color = current_clip_for_text / max_clip_for_color_calc
        end
    end

    if text_style.visible ~= show_text_final then
        text_style.visible = show_text_final; changed = true
    end

    if show_text_final then
        if content.ammo_clip_value_text ~= text_to_display_final then
            content.ammo_clip_value_text = text_to_display_final; changed = true
        end
        local new_text_color
        if clip_fraction_for_color >= 0.85 then
            new_text_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH
        elseif clip_fraction_for_color >= 0.65 then
            new_text_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_H
        elseif clip_fraction_for_color >= 0.45 then
            new_text_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L
        elseif clip_fraction_for_color >= 0.25 then
            new_text_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_LOW
        else
            new_text_color = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_CRITICAL
        end
        local tc = text_style.text_color
        if not tc or tc[1] ~= new_text_color[1] or tc[2] ~= new_text_color[2] or tc[3] ~= new_text_color[3] or
            tc[4] ~= new_text_color[4] then
            text_style.text_color = table.clone(new_text_color); changed = true
        end
    elseif not show_text_final and content.ammo_clip_value_text ~= "" then
        content.ammo_clip_value_text = ""; changed = true
    end

    if changed then widget.dirty = true end
end

return MunitionsFeature
