-- File: RingHud/scripts/mods/RingHud/features/ammo_clip_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local U                     = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local Ammo                  = require("scripts/utilities/ammo")
local NetworkConstants      = require("scripts/network_lookup/network_constants")

local MAX_CLIPS             = (NetworkConstants.ammunition_clip_array
    and NetworkConstants.ammunition_clip_array.max_size) or 1

local AmmoClipFeature       = {}

local AMMO_CLIP_SEGMENT_GAP = 0.015
local AMMO_CLIP_ARC_MIN     = 0.49
local AMMO_CLIP_ARC_MAX     = 0.98
local MAX_LOW_COUNT_DISPLAY = mod.MAX_AMMO_CLIP_LOW_COUNT_DISPLAY or 30

local _multi_style_keys = {}
for i = 1, MAX_LOW_COUNT_DISPLAY do
    _multi_style_keys[i] = "ammo_clip_filled_multi_" .. i
end

local _cached_arcs = {}

local BAR_MODES    = {
    ammo_clip_bar                 = "standard",
    ammo_clip_bar_text            = "standard",
    ammo_clip_bar_forecast        = "standard",
    ammo_clip_bar_always          = "always",
    ammo_clip_bar_text_always     = "always",
    ammo_clip_bar_forecast_always = "always",
    ammo_clip_bar_ads             = "ads",
    ammo_clip_bar_forecast_ads    = "ads",
    -- All others default to nil (disabled)
}

local TEXT_MODES   = {
    ammo_clip_text                = "standard",
    ammo_clip_bar_text            = "standard",
    ammo_clip_forecast            = "forecast",
    ammo_clip_bar_forecast        = "forecast",
    ammo_clip_text_always         = "always",
    ammo_clip_bar_text_always     = "always",
    ammo_clip_forecast_always     = "forecast_always",
    ammo_clip_bar_forecast_always = "forecast_always",
    ammo_clip_bar_forecast_ads    = "forecast_ads",
}

local COL_HIGH     = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH
local COL_MED_H    = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_H
local COL_MED_L    = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L
local COL_LOW      = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_LOW
local COL_CRIT     = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_CRITICAL
local COL_FORECAST = { 180, 100, 100, 100 }

local RGBA_HIGH    = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_HIGH
local RGBA_MED_H   = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_MEDIUM_H
local RGBA_MED_L   = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_MEDIUM_L
local RGBA_LOW     = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_LOW
local RGBA_CRIT    = mod.PALETTE_RGBA1.AMMO_BAR_COLOR_CRITICAL

local function _has_any_latched_clip_data(hud_element)
    return hud_element
        and hud_element._ammo_clip_has_latched_data == true
        and (tonumber(hud_element._latched_max_clip_ammo) or 0) > 0
end

-- STATE (clip) ---------------------------------------------------------------
function AmmoClipFeature.update_state(secondary_comp, secondary_weapon_template, inv_comp, ammo_data_out, archetype_name)
    if not ammo_data_out then
        return
    end

    local wielded_slot              = (inv_comp and inv_comp.wielded_slot) or "none"
    ammo_data_out.wielded_slot_name = wielded_slot

    local current_clip              = 0
    local max_clip                  = 0
    local is_needle_pistol          = false
    local special_active            = false

    local template_name             = secondary_weapon_template and secondary_weapon_template.name
    local hud_configuration         = secondary_weapon_template and secondary_weapon_template.hud_configuration
    local uses_ammo                 = hud_configuration and hud_configuration.uses_ammunition == true or false

    if archetype_name == "broker"
        and type(template_name) == "string"
        and string.find(template_name, "needlepistol", 1, true)
    then
        is_needle_pistol = true
    end

    if secondary_comp then
        local current_values = secondary_comp.current_ammunition_clip
        local max_values     = secondary_comp.max_ammunition_clip

        if type(current_values) == "table" and type(max_values) == "table" then
            for i = 1, MAX_CLIPS do
                if Ammo.clip_in_use(secondary_comp, i) then
                    current_clip = current_clip + (current_values[i] or 0)
                    max_clip     = max_clip + (max_values[i] or 0)
                end
            end
        else
            current_clip = tonumber(current_values) or 0
            max_clip     = tonumber(max_values) or 0
        end

        if is_needle_pistol then
            special_active = secondary_comp.special_active == true
        end
    end

    -- The component values are authoritative if template data is temporarily absent.
    if max_clip > 0 then
        uses_ammo = true
    end

    ammo_data_out.uses_ammo        = uses_ammo
    ammo_data_out.current_clip     = current_clip
    ammo_data_out.max_clip         = max_clip
    ammo_data_out.is_needle_pistol = is_needle_pistol
    ammo_data_out.special_active   = special_active
end

-- Expose to mod so RingHud_state_player.lua can call: mod.ammo_clip_update_state(...)
mod.ammo_clip_update_state = AmmoClipFeature.update_state

local function _resolve_display_clip(hud_element, data, mode, hotkey_override)
    local live_max    = data and tonumber(data.max_clip) or 0
    local has_live    = data and data.uses_ammo == true and live_max > 0
    local has_latched = _has_any_latched_clip_data(hud_element)

    if not has_live and not has_latched then
        return false, 0, 0, false, false
    end

    local current_clip
    local max_clip
    local is_needle_pistol = false
    local special_active   = false

    if has_live then
        current_clip     = tonumber(data.current_clip) or 0
        max_clip         = live_max
        is_needle_pistol = data.is_needle_pistol == true
        special_active   = data.special_active == true
    else
        current_clip = tonumber(hud_element._latched_current_clip_ammo) or 0
        max_clip     = tonumber(hud_element._latched_max_clip_ammo) or 0
    end

    if max_clip <= 0 then
        return false, 0, 0, false, false
    end

    local is_always_mode = mode == "always" or mode == "forecast_always"
    local is_ads_mode    = mode == "ads" or mode == "forecast_ads"
    local is_wielded     = data and data.wielded_slot_name == "slot_secondary"
    local is_low_latched = hud_element and hud_element._ammo_clip_latched_low == true

    local visible

    if hotkey_override then
        visible = true
    elseif is_always_mode then
        visible = true
    elseif is_ads_mode then
        visible = hud_element and hud_element._ads_active == true
    else
        -- Preserve the existing low-clip latch while allowing its value to remain
        -- live when the ammunition weapon is stowed.
        visible = (is_wielded and current_clip < max_clip)
            or (not is_wielded and is_low_latched)
    end

    return visible, current_clip, max_clip, is_needle_pistol, special_active
end

local function _bar_output_is_unchanged(
    hud_element,
    widget,
    visible,
    current_clip,
    max_clip,
    arc_min,
    arc_max,
    is_needle_pistol,
    special_active
)
    local cache = hud_element and hud_element._ammo_clip_bar_output_cache

    if not cache
        or cache.widget ~= widget
        or cache.visible ~= visible
    then
        return false
    end

    if not visible then
        return true
    end

    return cache.current_clip == current_clip
        and cache.max_clip == max_clip
        and cache.arc_min == arc_min
        and cache.arc_max == arc_max
        and cache.is_needle_pistol == is_needle_pistol
        and cache.special_active == special_active
end

local function _store_bar_output(
    hud_element,
    widget,
    visible,
    current_clip,
    max_clip,
    arc_min,
    arc_max,
    is_needle_pistol,
    special_active
)
    if not hud_element then
        return
    end

    local cache = hud_element._ammo_clip_bar_output_cache

    if not cache then
        cache = {}
        hud_element._ammo_clip_bar_output_cache = cache
    end

    cache.widget           = widget
    cache.visible          = visible
    cache.current_clip     = current_clip
    cache.max_clip         = max_clip
    cache.arc_min          = arc_min
    cache.arc_max          = arc_max
    cache.is_needle_pistol = is_needle_pistol
    cache.special_active   = special_active
end

local function _text_output_is_unchanged(hud_element, widget, visible, display_number, text_color)
    local cache = hud_element and hud_element._ammo_clip_text_output_cache

    if not cache
        or cache.widget ~= widget
        or cache.visible ~= visible
    then
        return false
    end

    if not visible then
        return true
    end

    return cache.display_number == display_number
        and cache.text_color == text_color
end

local function _store_text_output(hud_element, widget, visible, display_number, text_color)
    if not hud_element then
        return
    end

    local cache = hud_element._ammo_clip_text_output_cache

    if not cache then
        cache = {}
        hud_element._ammo_clip_text_output_cache = cache
    end

    cache.widget         = widget
    cache.visible        = visible
    cache.display_number = display_number
    cache.text_color     = text_color
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Layout Application
-- ─────────────────────────────────────────────────────────────────────────────
function AmmoClipFeature.apply_layout(widget, text_widget, ctx)
    local apply_shake_offset = U.apply_shake_to_style_offset

    if widget and widget.style then
        local changed = false
        local style   = widget.style

        if style.ammo_clip_unfilled_background and apply_shake_offset(
                style.ammo_clip_unfilled_background,
                0,
                0,
                0,
                ctx.apply_shake,
                ctx.dx,
                ctx.dy,
                ctx.n_user_bias_px,
                ctx.n_user_bias_px
            )
        then
            changed = true
        end

        if style.ammo_clip_filled_single and apply_shake_offset(
                style.ammo_clip_filled_single,
                0,
                0,
                1,
                ctx.apply_shake,
                ctx.dx,
                ctx.dy,
                ctx.n_user_bias_px,
                ctx.n_user_bias_px
            )
        then
            changed = true
        end

        for i = 1, MAX_LOW_COUNT_DISPLAY do
            local segment_style = style[_multi_style_keys[i]]

            if segment_style and apply_shake_offset(
                    segment_style,
                    0,
                    0,
                    1,
                    ctx.apply_shake,
                    ctx.dx,
                    ctx.dy,
                    ctx.n_user_bias_px,
                    ctx.n_user_bias_px
                )
            then
                changed = true
            end
        end

        if changed then
            widget.dirty = true
        end
    end

    if text_widget
        and text_widget.style
        and text_widget.style.ammo_clip_text_style
    then
        if apply_shake_offset(
                text_widget.style.ammo_clip_text_style,
                0,
                0,
                1,
                ctx.apply_shake,
                ctx.dx,
                ctx.dy,
                ctx.n_text_bias_comb,
                0
            )
        then
            text_widget.dirty = true
        end
    end
end

-- BAR (ring) ------------------------------------------------------------------
function AmmoClipFeature.update_bar(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then
        return
    end

    local style          = widget.style
    local dropdown_value = mod._settings.ammo_clip_dropdown
    local mode           = BAR_MODES[dropdown_value]

    if not mode then
        if _bar_output_is_unchanged(
                hud_element,
                widget,
                false,
                0,
                0,
                0,
                0,
                false,
                false
            ) then
            return
        end

        local changed = false

        if style.ammo_clip_unfilled_background then
            changed = U.set_style_visible(
                style.ammo_clip_unfilled_background,
                false,
                changed
            )
        end

        if style.ammo_clip_filled_single then
            changed = U.set_style_visible(
                style.ammo_clip_filled_single,
                false,
                changed
            )
        end

        for i = 1, MAX_LOW_COUNT_DISPLAY do
            local segment_style = style[_multi_style_keys[i]]

            if segment_style then
                changed = U.set_style_visible(segment_style, false, changed)
            end
        end

        _store_bar_output(
            hud_element,
            widget,
            false,
            0,
            0,
            0,
            0,
            false,
            false
        )

        if changed then
            widget.dirty = true
        end

        return
    end

    local data = hud_state.ammo_data

    local visible, current_clip, max_clip, is_needle_pistol, special_active =
        _resolve_display_clip(
            hud_element,
            data,
            mode,
            hotkey_override
        )

    local arc_min, arc_max = AMMO_CLIP_ARC_MIN, AMMO_CLIP_ARC_MAX

    if _bar_output_is_unchanged(
            hud_element,
            widget,
            visible,
            current_clip,
            max_clip,
            arc_min,
            arc_max,
            is_needle_pistol,
            special_active
        ) then
        return
    end

    local unfilled_style = style.ammo_clip_unfilled_background
    local single_style   = style.ammo_clip_filled_single
    local changed        = false

    if unfilled_style then
        changed = U.set_style_visible(unfilled_style, visible, changed)

        if visible then
            changed = U.mv_set_arc(
                unfilled_style.material_values,
                arc_max,
                arc_min,
                changed
            )
        end
    end

    if visible then
        local clip_fraction = math.clamp(current_clip / max_clip, 0, 1)
        local border_color

        if is_needle_pistol then
            border_color = special_active
                and mod.PALETTE_RGBA1.NEEDLE_SPECIAL_ACTIVE
                or mod.PALETTE_RGBA1.NEEDLE_SPECIAL_INACTIVE
        elseif clip_fraction >= 0.85 then
            border_color = RGBA_HIGH
        elseif clip_fraction >= 0.65 then
            border_color = RGBA_MED_H
        elseif clip_fraction >= 0.45 then
            border_color = RGBA_MED_L
        elseif clip_fraction >= 0.25 then
            border_color = RGBA_LOW
        else
            border_color = RGBA_CRIT
        end

        if max_clip > MAX_LOW_COUNT_DISPLAY then
            if single_style then
                changed          = U.set_style_visible(single_style, true, changed)

                local arc_length = (arc_max - arc_min) * clip_fraction
                local arc_top    = arc_min + arc_length
                local material   = single_style.material_values

                changed          = U.mv_set_arc(material, arc_top, arc_min, changed)
                changed          = U.mv_set_outline(material, border_color, changed)
            end

            for i = 1, MAX_LOW_COUNT_DISPLAY do
                local segment_style = style[_multi_style_keys[i]]

                if segment_style then
                    changed = U.set_style_visible(segment_style, false, changed)
                end
            end
        else
            if single_style then
                changed = U.set_style_visible(single_style, false, changed)
            end

            local segment_count = math.min(max_clip, MAX_LOW_COUNT_DISPLAY)
            local arcs = U.get_segment_arcs(
                _cached_arcs,
                segment_count,
                arc_min,
                arc_max,
                AMMO_CLIP_SEGMENT_GAP
            )

            for i = 1, MAX_LOW_COUNT_DISPLAY do
                local segment_style = style[_multi_style_keys[i]]

                if segment_style then
                    local segment_visible = i <= current_clip and i <= segment_count

                    changed = U.set_style_visible(
                        segment_style,
                        segment_visible,
                        changed
                    )

                    if segment_visible then
                        local material = segment_style.material_values
                        local arc      = arcs and arcs[i]

                        if arc then
                            changed = U.mv_set_arc(
                                material,
                                arc[1],
                                arc[2],
                                changed
                            )
                        end

                        changed = U.mv_set_outline(
                            material,
                            border_color,
                            changed
                        )
                    end
                end
            end
        end
    else
        if single_style then
            changed = U.set_style_visible(single_style, false, changed)
        end

        for i = 1, MAX_LOW_COUNT_DISPLAY do
            local segment_style = style[_multi_style_keys[i]]

            if segment_style then
                changed = U.set_style_visible(segment_style, false, changed)
            end
        end
    end

    _store_bar_output(
        hud_element,
        widget,
        visible,
        current_clip,
        max_clip,
        arc_min,
        arc_max,
        is_needle_pistol,
        special_active
    )

    if changed then
        widget.dirty = true
    end
end

-- TEXT -----------------------------------------------------------------------
function AmmoClipFeature.update_text(hud_element, widget, hud_state, hotkey_override)
    if not widget
        or not widget.content
        or not widget.style
        or not widget.style.ammo_clip_text_style
    then
        return
    end

    local content        = widget.content
    local text_style     = widget.style.ammo_clip_text_style
    local dropdown_value = mod._settings.ammo_clip_dropdown
    local mode           = TEXT_MODES[dropdown_value]

    if not mode then
        if _text_output_is_unchanged(
                hud_element,
                widget,
                false,
                0,
                nil
            ) then
            return
        end

        local changed = U.set_style_visible(text_style, false)

        if content.ammo_clip_value_text ~= "" then
            content.ammo_clip_value_text = ""
            changed = true
        end

        _store_text_output(
            hud_element,
            widget,
            false,
            0,
            nil
        )

        if changed then
            widget.dirty = true
        end

        return
    end

    local visible, current_clip, max_clip =
        _resolve_display_clip(
            hud_element,
            hud_state.ammo_data,
            mode,
            hotkey_override
        )

    local is_forecast_mode                = mode == "forecast"
        or mode == "forecast_always"
        or mode == "forecast_ads"

    local shot_cost                       = tonumber(hud_state.most_recent_shot_cost_this_mission) or 0
    local has_forecast_data               = shot_cost > 0
    local display_number                  = 0
    local text_color

    if visible then
        if is_forecast_mode and has_forecast_data then
            display_number = math.ceil(current_clip / shot_cost)
        else
            display_number = current_clip
        end

        local clip_fraction = math.clamp(current_clip / max_clip, 0, 1)

        if is_forecast_mode and not has_forecast_data then
            text_color = COL_FORECAST
        elseif clip_fraction >= 0.85 then
            text_color = COL_HIGH
        elseif clip_fraction >= 0.65 then
            text_color = COL_MED_H
        elseif clip_fraction >= 0.45 then
            text_color = COL_MED_L
        elseif clip_fraction >= 0.25 then
            text_color = COL_LOW
        else
            text_color = COL_CRIT
        end
    end

    -- Performance impact: reduced. Formatting and style writes only occur when
    -- the rendered number, color, visibility, or widget instance changes.
    if _text_output_is_unchanged(
            hud_element,
            widget,
            visible,
            display_number,
            text_color
        ) then
        return
    end

    local changed = U.set_style_visible(text_style, visible)

    if visible then
        local display_text = string.format("%d", display_number)

        if content.ammo_clip_value_text ~= display_text then
            content.ammo_clip_value_text = display_text
            changed = true
        end

        if U.set_style_text_color(text_style, text_color) then
            changed = true
        end
    elseif content.ammo_clip_value_text ~= "" then
        content.ammo_clip_value_text = ""
        changed = true
    end

    _store_text_output(
        hud_element,
        widget,
        visible,
        display_number,
        text_color
    )

    if changed then
        widget.dirty = true
    end
end

-- FACTORY --------------------------------------------------------------------
-- Injects the ammo-clip ring into widget_definitions as "ammo_clip_bar".
function AmmoClipFeature.add_widgets(widget_defs, _, layout, palettes)
    widget_defs    = widget_defs or {}

    local size     = (layout and layout.size)
        or {
            240 * (mod._settings.ring_scale or 1),
            240 * (mod._settings.ring_scale or 1)
        }

    local inner    = layout.inner_size_factor or 0.8

    local ARGB     = mod.PALETTE_ARGB255 or {}

    local RGBA1    = mod.PALETTE_RGBA1 or {}

    local UIWidget = require("scripts/managers/ui/ui_widget")

    local function sl(sz, z)
        return {
            uvs                  = { { 1, 0 }, { 0, 1 } },
            horizontal_alignment = "center",
            vertical_alignment   = "center",
            offset               = { 0, 0, z },
            size                 = sz,
            color                = ARGB.GENERIC_WHITE,
            visible              = false,
            pivot                = { 0, 0 },
            angle                = 0
        }
    end

    local inner_size = {
        size[1] * inner,
        size[2] * inner
    }

    local passes = {}

    -- Unfilled background
    passes[#passes + 1] = {
        pass_type = "rotated_texture",
        value     = "content/ui/materials/effects/forcesword_bar",
        style_id  = "ammo_clip_unfilled_background",
        style     = (function()
            local s = sl(inner_size, 0)

            s.material_values = {
                amount               = 1,
                glow_on_off          = 0,
                lightning_opacity    = 0,
                arc_top_bottom       = {
                    AMMO_CLIP_ARC_MAX,
                    AMMO_CLIP_ARC_MIN
                },
                fill_outline_opacity = { 0.7, 0.5 },
                outline_color        = { 0.3, 0.3, 0.3, 0.8 },
                SizeThicknessOutline = { 0.405, 0.027, 0.037 },
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
                amount               = 1,
                glow_on_off          = 0,
                lightning_opacity    = 0,
                arc_top_bottom       = {
                    AMMO_CLIP_ARC_MAX,
                    AMMO_CLIP_ARC_MIN
                },
                fill_outline_opacity = { 1.3, 1.3 },
                outline_color        = table.clone(RGBA1.AMMO_BAR_COLOR_HIGH),
                SizeThicknessOutline = { 0.405, 0.027, 0.037 },
            }

            return s
        end)(),
    }

    -- Low-count segments
    for i = 1, MAX_LOW_COUNT_DISPLAY do
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "ammo_clip_filled_multi_" .. i,
            style     = (function()
                local s = sl(inner_size, 1)

                s.material_values = {
                    amount               = 1,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { 0, 0 },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(RGBA1.AMMO_BAR_COLOR_HIGH),
                    SizeThicknessOutline = { 0.405, 0.027, 0.037 },
                }

                return s
            end)(),
        }
    end

    widget_defs.ammo_clip_bar = UIWidget.create_definition(
        passes,
        "ammo_clip_bar"
    )
end

return AmmoClipFeature
