-- File: RingHud/scripts/mods/RingHud/features/ammo_clip_feature.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local U                     = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local Ammo                  = require("scripts/utilities/ammo")

local AmmoClipFeature       = {}

local AMMO_CLIP_SEGMENT_GAP = 0.015 -- kept local; RingHud constants cover arc min/max and display counts

-- STATE (clip) ---------------------------------------------------------------
-- Populates ammo_data_out with ONLY clip-related fields:
--   - wielded_slot_name
--   - uses_ammo
--   - current_clip
--   - max_clip
-- Does not touch reserve fields (handled elsewhere / ammo_reserve_feature).
function AmmoClipFeature.update_state(unit_data_comp_access_point, weapon_ext, inv_comp, ammo_data_out)
    if not ammo_data_out then return end

    local wielded_slot              = (inv_comp and inv_comp.wielded_slot) or "none"
    ammo_data_out.wielded_slot_name = wielded_slot

    local uses_ammo                 = false
    local current_clip, max_clip    = 0, 0

    -- We only expose clip info when the wielded slot is the secondary AND the template uses ammo.
    if wielded_slot == "slot_secondary" then
        local wielded_template = weapon_ext and weapon_ext:weapon_template()
        local uses_flag = wielded_template
            and wielded_template.hud_configuration
            and wielded_template.hud_configuration.uses_ammunition

        if uses_flag then
            uses_ammo = true

            local secondary_comp = unit_data_comp_access_point and
                unit_data_comp_access_point:read_component("slot_secondary")

            if secondary_comp then
                -- 1.10 multi-clip ammo layout: aggregate all clips in use
                local max_num_clips = (NetworkConstants
                    and NetworkConstants.ammunition_clip_array
                    and NetworkConstants.ammunition_clip_array.max_size) or 0

                for i = 1, max_num_clips do
                    if Ammo.clip_in_use(secondary_comp, i) then
                        max_clip     = max_clip + (secondary_comp.max_ammunition_clip[i] or 0)
                        current_clip = current_clip + (secondary_comp.current_ammunition_clip[i] or 0)
                    end
                end
            end
        end
    end

    ammo_data_out.uses_ammo    = uses_ammo
    ammo_data_out.current_clip = current_clip
    ammo_data_out.max_clip     = max_clip
end

-- Expose to mod so RingHud_state_player.lua can call: mod.ammo_clip_update_state(...)
mod.ammo_clip_update_state = AmmoClipFeature.update_state

-- BAR (ring) ------------------------------------------------------------------
function AmmoClipFeature.update_bar(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local ammo_clip_dropdown = mod._settings.ammo_clip_dropdown
    if ammo_clip_dropdown == "ammo_clip_disabled" or ammo_clip_dropdown == "ammo_clip_text" then
        local style = widget.style
        if style.ammo_clip_unfilled_background then
            if U.set_style_visible(style.ammo_clip_unfilled_background, false) then widget.dirty = true end
        end
        if style.ammo_clip_filled_single then
            if U.set_style_visible(style.ammo_clip_filled_single, false) then widget.dirty = true end
        end
        for i = 1, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
            local m = style["ammo_clip_filled_multi_" .. i]
            if m and U.set_style_visible(m, false) then
                widget.dirty = true
            end
        end
        return
    end

    local style                                              = widget.style
    local unfilled_style                                     = style.ammo_clip_unfilled_background
    local single_style                                       = style.ammo_clip_filled_single
    local data                                               = hud_state.ammo_data
    local changed                                            = false

    local overall_visible_normally, clip_frac_normally       = false, 0
    local current_ammo_disp_normally, max_ammo_disp_normally = 0, 0

    if data.uses_ammo and data.max_clip and data.max_clip > 0 then
        current_ammo_disp_normally = data.current_clip
        max_ammo_disp_normally     = data.max_clip
        clip_frac_normally         = data.current_clip / data.max_clip
        overall_visible_normally   = data.current_clip < data.max_clip
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

    local overall_visible, clip_frac = false, 0
    local current_ammo_disp, max_ammo_disp = 0, 0

    if hotkey_override then
        if hud_element._latched_max_clip_ammo > 0 then
            overall_visible   = true
            current_ammo_disp = hud_element._latched_current_clip_ammo
            max_ammo_disp     = hud_element._latched_max_clip_ammo
            if max_ammo_disp > 0 then clip_frac = current_ammo_disp / max_ammo_disp else clip_frac = 0 end
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
        changed = U.set_style_visible(unfilled_style, overall_visible, changed)
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
                changed       = U.set_style_visible(single_style, true, changed)
                local arc_len = (mod.AMMO_CLIP_ARC_MAX - mod.AMMO_CLIP_ARC_MIN) * clip_frac
                local arc_top = mod.AMMO_CLIP_ARC_MIN + arc_len
                local mat     = single_style.material_values
                changed       = U.mv_set_arc(mat, arc_top, mod.AMMO_CLIP_ARC_MIN, changed)
                changed       = U.mv_set_outline(mat, border_color, changed)
            end
            for i = 1, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
                local m = style["ammo_clip_filled_multi_" .. i]
                if m then changed = U.set_style_visible(m, false, changed) or changed end
            end
        else
            if single_style then
                changed = U.set_style_visible(single_style, false, changed)
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
                    changed       = U.set_style_visible(multi_s, seg_vis, changed)
                    if seg_vis then
                        if arcs[i] then
                            changed = U.mv_set_arc(mat, arcs[i][1], arcs[i][2], changed)
                        elseif num_draw_seg == 1 and i == 1 then
                            changed = U.mv_set_arc(mat, mod.AMMO_CLIP_ARC_MIN, mod.AMMO_CLIP_ARC_MIN, changed)
                        end
                        changed = U.mv_set_outline(mat, border_color, changed)
                    end
                end
            end
        end
    else
        if single_style then
            changed = U.set_style_visible(single_style, false, changed)
        end
        for i = 1, mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY do
            local m = style["ammo_clip_filled_multi_" .. i]
            if m then changed = U.set_style_visible(m, false, changed) or changed end
        end
    end

    if changed then widget.dirty = true end
end

-- TEXT -----------------------------------------------------------------------
function AmmoClipFeature.update_text(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local ammo_clip_dropdown = mod._settings.ammo_clip_dropdown
    if not (widget and widget.content and widget.style and widget.style.ammo_clip_text_style) then return end

    if ammo_clip_dropdown == "ammo_clip_disabled" or ammo_clip_dropdown == "ammo_clip_bar" then
        local c = widget.content
        local s = widget.style.ammo_clip_text_style
        if U.set_style_visible(s, false) then widget.dirty = true end
        if c.ammo_clip_value_text ~= "" then
            c.ammo_clip_value_text = ""; widget.dirty = true
        end
        return
    end

    local content                  = widget.content
    local text_style               = widget.style.ammo_clip_text_style
    local changed                  = false
    local data                     = hud_state.ammo_data

    local show_text_normally       = false
    local text_to_display_normally = ""
    local current_clip_for_text    = 0
    local max_clip_for_color_calc  = 0
    local has_valid_clip_for_text  = false

    if data and data.uses_ammo and data.max_clip and data.max_clip > 0 then
        current_clip_for_text   = data.current_clip
        max_clip_for_color_calc = data.max_clip
        has_valid_clip_for_text = true
        if data.current_clip < data.max_clip then show_text_normally = true end
    elseif hud_element._ammo_clip_latched_low and hud_element._latched_max_clip_ammo and hud_element._latched_max_clip_ammo > 0 then
        current_clip_for_text   = hud_element._latched_current_clip_ammo
        max_clip_for_color_calc = hud_element._latched_max_clip_ammo
        has_valid_clip_for_text = true
        show_text_normally      = true
    end

    if show_text_normally and has_valid_clip_for_text then
        text_to_display_normally = string.format("%d", current_clip_for_text)
    end

    local show_text_final, text_to_display_final = false, ""
    local clip_fraction_for_color = 0

    if hotkey_override then
        if hud_element._latched_max_clip_ammo > 0 then
            show_text_final       = true
            text_to_display_final = string.format("%d", hud_element._latched_current_clip_ammo)
            if hud_element._latched_max_clip_ammo > 0 then
                clip_fraction_for_color = hud_element._latched_current_clip_ammo / hud_element._latched_max_clip_ammo
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

    changed = U.set_style_visible(text_style, show_text_final, changed)

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
        if U.set_style_text_color(text_style, new_text_color) then
            changed = true
        end
    elseif not show_text_final and content.ammo_clip_value_text ~= "" then
        content.ammo_clip_value_text = ""; changed = true
    end

    if changed then widget.dirty = true end
end

-- FACTORY --------------------------------------------------------------------
-- Injects the ammo-clip ring into widget_definitions as "ammo_clip_bar".
function AmmoClipFeature.add_widgets(widget_defs, _, layout, palettes)
    widget_defs    = widget_defs or {}
    local size     = (layout and layout.size) or
        { 240 * (mod._settings.ring_scale or 1), 240 * (mod._settings.ring_scale or 1) }
    local inner    = (layout and layout.inner_size_factor) or 0.8

    local ARGB     = (palettes and palettes.ARGB) or (mod.PALETTE_ARGB255 or {})
    local RGBA1    = (palettes and palettes.RGBA1) or (mod.PALETTE_RGBA1 or {})

    local UIWidget = require("scripts/managers/ui/ui_widget")

    local function sl(sz, z)
        return {
            uvs = { { 1, 0 }, { 0, 1 } },
            horizontal_alignment = "center",
            vertical_alignment = "center",
            offset = { 0, 0, z },
            size = sz,
            color = ARGB.GENERIC_WHITE,
            visible = false,
            pivot = { 0, 0 },
            angle = 0
        }
    end

    local inner_size = { size[1] * inner, size[2] * inner }

    local passes = {}

    -- Unfilled background
    passes[#passes + 1] = {
        pass_type = "rotated_texture",
        value     = "content/ui/materials/effects/forcesword_bar",
        style_id  = "ammo_clip_unfilled_background",
        style     = (function()
            local s = sl(inner_size, 0)
            s.material_values = {
                amount = 1,
                glow_on_off = 0,
                lightning_opacity = 0,
                arc_top_bottom = { mod.AMMO_CLIP_ARC_MAX, mod.AMMO_CLIP_ARC_MIN },
                fill_outline_opacity = { 0.7, 0.5 },
                outline_color = { 0.3, 0.3, 0.3, 0.8 }, -- AMMO_CLIP_UNFILLED_COLOR
            }
            return s
        end)(),
    }

    -- Single filled bar
    passes[#passes + 1] = {
        pass_type = "rotated_texture",
        value     = "content/ui/materials/effects/forcesword_bar",
        style_id  = "ammo_clip_filled_single",
        style     = (function()
            local s = sl(inner_size, 1)
            s.material_values = {
                amount = 1,
                glow_on_off = 0,
                lightning_opacity = 0,
                arc_top_bottom = { mod.AMMO_CLIP_ARC_MIN, mod.AMMO_CLIP_ARC_MIN },
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color = table.clone(RGBA1.AMMO_BAR_COLOR_HIGH),
            }
            return s
        end)(),
    }

    -- Low-count segments
    for i = 1, (mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY or 6) do
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "ammo_clip_filled_multi_" .. i,
            style     = (function()
                local s = sl(inner_size, 1)
                s.material_values = {
                    amount = 1,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { 0, 0 }, -- set at runtime
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = table.clone(RGBA1.AMMO_BAR_COLOR_HIGH),
                }
                return s
            end)(),
        }
    end

    widget_defs.ammo_clip_bar = UIWidget.create_definition(passes, "ammo_clip_bar")
end

return AmmoClipFeature
