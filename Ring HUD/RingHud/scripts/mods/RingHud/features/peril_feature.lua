-- File: RingHud/scripts/mods/RingHud/features/peril_feature.lua

local mod = get_mod("RingHud")
if not mod then return {} end

local UIWidget                 = require("scripts/managers/ui/ui_widget")
local RingHudUtils             = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local U                        = RingHudUtils
local ColorUtilities           = require("scripts/utilities/ui/colors")
local Notch                    = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local UIFontSettings           = require("scripts/managers/ui/ui_font_settings")

local PerilFeature             = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Cross-file helpers for PERIL/OVERHEAT (exposed on `mod.*`)
-- ─────────────────────────────────────────────────────────────────────────────
function mod.peril_slot_is_weapon(slot_name)
    if not slot_name or slot_name == "none" then return false end
    local cfg = PlayerCharacterConstants
        and PlayerCharacterConstants.slot_configuration
        and PlayerCharacterConstants.slot_configuration[slot_name]
    return cfg and cfg.slot_type == "weapon" or false
end

function mod.peril_template_generates_overheat(wep_template)
    if not wep_template then return false end
    if wep_template.hud_configuration and wep_template.hud_configuration.uses_overheat then
        return true
    end
    if wep_template.overheat_configuration then
        return true
    end
    return false
end

function mod.peril_read_slot_overheat(unit_data_comp_access_point, slot_name)
    if not mod.peril_slot_is_weapon(slot_name) then return 0 end
    local comp = unit_data_comp_access_point and unit_data_comp_access_point:read_component(slot_name)
    return (comp and comp.overheat_current_percentage) or 0
end

-- Arc envelope must match the widget defaults (arc_top_bottom = { 0.50, 0.01 })
local PERIL_ARC_BOTTOM  = 0.01
local PERIL_ARC_TOP     = 0.50

local peril_color_steps = { 0.2125, 0.425, 0.6375, 0.834, 0.984, 1.0 }

function PerilFeature.update(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local style            = widget.style
    local base_style       = style.peril_bar
    local edge_style       = style.peril_edge
    local other_edge_style = style.peril_other_edge
    local label_style      = style.percent_text

    -- Only require the bar pieces; label is optional
    if not (base_style and base_style.material_values and edge_style and edge_style.material_values) then
        return
    end

    local fraction          = (hud_state.peril_data and hud_state.peril_data.value) or hud_state.peril_fraction or 0
    mod.is_peril_driven     = hud_state.is_peril_driven_by_warp

    -- Color stepper (cache & only recompute when peril moves)
    local previous_fraction = hud_element._previous_peril_fraction or -1
    if math.abs(fraction - previous_fraction) > 0.001 then
        local new_color_argb = mod.PALETTE_ARGB255.peril_color_spectrum[1]
        local new_color_rgba = mod.PALETTE_RGBA1.peril_color_spectrum[1]
        for i = 1, #peril_color_steps do
            if fraction < peril_color_steps[i] then
                new_color_argb = mod.PALETTE_ARGB255.peril_color_spectrum[i]
                new_color_rgba = mod.PALETTE_RGBA1.peril_color_spectrum[i]
                break
            elseif i == #peril_color_steps and fraction >= peril_color_steps[i] then
                new_color_argb = mod.PALETTE_ARGB255.peril_color_spectrum[#mod.PALETTE_ARGB255.peril_color_spectrum]
                new_color_rgba = mod.PALETTE_RGBA1.peril_color_spectrum[#mod.PALETTE_RGBA1.peril_color_spectrum]
                break
            end
        end
        hud_element._current_peril_color_argb = new_color_argb
        hud_element._current_peril_color_rgba = new_color_rgba
        hud_element._previous_peril_fraction  = fraction
    end

    local current_peril_color_argb = hud_element._current_peril_color_argb
        or mod.PALETTE_ARGB255.peril_color_spectrum[1]
    mod.current_peril_color_rgba = hud_element._current_peril_color_rgba
        or mod.PALETTE_RGBA1.peril_color_spectrum[1]

    -- Crosshair override mirrors existing behavior
    if mod._settings.peril_crosshair_enabled and fraction > 0 then
        local last = mod._last_crosshair_override_argb
        local cur  = current_peril_color_argb
        if (not last)
            or last[1] ~= cur[1] or last[2] ~= cur[2]
            or last[3] ~= cur[3] or last[4] ~= cur[4] then
            -- Fix: Use the Crosshair module API if available, ensuring 255 alpha
            local target_color = table.clone(cur)
            target_color[1] = 255

            if mod.crosshair and mod.crosshair.set_override_color then
                mod.crosshair.set_override_color(target_color)
            else
                -- Fallback for legacy state
                mod.override_color = target_color
            end

            mod._last_crosshair_override_argb = table.clone(cur)
        end
    elseif mod._last_crosshair_override_argb ~= nil then
        -- Fix: Use the Crosshair module API to clear
        if mod.crosshair and mod.crosshair.clear_override_color then
            mod.crosshair.clear_override_color()
        else
            mod.override_color = nil
        end
        mod._last_crosshair_override_argb = nil
    end

    -- Visibility (unchanged semantics)
    local peril_mode             = mod._settings.peril_bar_dropdown
    local bar_visible_normally   = (fraction > 0) and (peril_mode ~= "peril_bar_disabled")
    local label_visible_normally = (fraction > 0) and mod._settings.peril_label_enabled

    local bar_visible            = hotkey_override or bar_visible_normally
    local label_visible          = hotkey_override or label_visible_normally

    if hotkey_override and fraction == 0 and peril_mode ~= "peril_bar_disabled" then
        bar_visible   = true
        label_visible = mod._settings.peril_label_enabled
    end

    local changed = false

    -- Lightning opacity (applied to all peril passes)
    local new_lightning_opacity = 0
    if fraction >= 0.9 and peril_mode == "peril_lightning_enabled" then
        new_lightning_opacity = math.lerp(0, 1, (fraction - 0.9) * 10)
    end

    -- Geometry: filled base + unfilled remainder via shared notch helper
    local display_fraction = (hotkey_override and fraction) or (bar_visible_normally and fraction or 0)
    display_fraction       = math.clamp(display_fraction, 0, 1)

    -- Split parent arc into base(1) + edge(0) with fixed 0.01 gap (helper default)
    local r                = Notch.notch_split(PERIL_ARC_TOP, PERIL_ARC_BOTTOM, display_fraction)

    local base_mv          = base_style.material_values
    local edge_mv          = edge_style.material_values

    -- Base slice (filled)
    if base_mv.amount ~= 1 then
        base_mv.amount = 1; changed = true
    end
    changed = U.mv_set_arc(base_mv, r.base.top, r.base.bottom, changed)
    changed = U.set_style_visible(base_style, (bar_visible and r.base.show) == true, changed)

    -- Edge sliver (unfilled)
    if edge_mv.amount ~= 0 then
        edge_mv.amount = 0; changed = true
    end
    changed = U.mv_set_arc(edge_mv, r.edge.top, r.edge.bottom, changed)
    changed = U.set_style_visible(edge_style, (bar_visible and r.edge.show) == true, changed)

    -- Lightning opacity -> base & main edge
    if base_mv.lightning_opacity ~= new_lightning_opacity then
        base_mv.lightning_opacity = new_lightning_opacity; changed = true
    end
    if edge_mv.lightning_opacity ~= new_lightning_opacity then
        edge_mv.lightning_opacity = new_lightning_opacity; changed = true
    end

    -- Outline color -> base & main edge
    changed = U.mv_set_outline(base_mv, mod.current_peril_color_rgba, changed)
    changed = U.mv_set_outline(edge_mv, mod.current_peril_color_rgba, changed)

    -- ─────────────────────────────────────────────────────────────────────────
    -- “Other overheat” notch (thin sliver at other_overheat_fraction)
    -- ─────────────────────────────────────────────────────────────────────────
    if other_edge_style and other_edge_style.material_values then
        local other_mv = other_edge_style.material_values
        local other_fraction = (hud_state.peril_data and hud_state.peril_data.other_overheat_fraction) or 0
        other_fraction = math.clamp(other_fraction, 0, 1)

        local show_other = (not hud_state.is_peril_driven_by_warp) and (other_fraction > 0 and other_fraction < 1) and
            bar_visible

        if other_mv.amount ~= 0 then
            other_mv.amount = 0; changed = true
        end

        if show_other then
            local r_other = Notch.notch_split(PERIL_ARC_TOP, PERIL_ARC_BOTTOM, other_fraction)
            changed = U.mv_set_arc(other_mv, r_other.edge.top, r_other.edge.bottom, changed)
            changed = U.set_style_visible(other_edge_style, r_other.edge.show == true, changed)
        else
            changed = U.set_style_visible(other_edge_style, false, changed)
        end

        -- Match lightning glow & outline color to primary peril color
        if other_mv.lightning_opacity ~= new_lightning_opacity then
            other_mv.lightning_opacity = new_lightning_opacity; changed = true
        end
        changed = U.mv_set_outline(other_mv, mod.current_peril_color_rgba, changed)
    end

    -- Label (optional; render only if style exists)
    if label_style then
        local want_label = label_visible
        changed = U.set_style_visible(label_style, want_label == true, changed)

        if want_label then
            local text = string.format(U.percent_num_format, fraction * 100)
            if widget.content.percent_text ~= text then
                widget.content.percent_text = text; changed = true
            end
            if U.set_style_text_color(label_style, current_peril_color_argb) then
                changed = true
            end
        elseif widget.content.percent_text ~= "" then
            widget.content.percent_text = ""
            changed = true
        end
    end

    if changed then widget.dirty = true end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Widget factory
-- ─────────────────────────────────────────────────────────────────────────────
function PerilFeature.add_widgets(dst, styles, metrics, colors)
    local size  = (metrics and metrics.size) or { 240, 240 }
    local ARGB  = (colors and colors.ARGB) or (mod.PALETTE_ARGB255 or {})
    local RGBA1 = (colors and colors.RGBA1) or (mod.PALETTE_RGBA1 or {})
    setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end })
    setmetatable(RGBA1, { __index = function() return { 1, 1, 1, 1 } end })

    -- Local text style for the peril label
    local percent_text_style                     = table.clone(UIFontSettings.body_small)
    percent_text_style.drop_shadow               = true
    percent_text_style.text_horizontal_alignment = "center"
    percent_text_style.text_vertical_alignment   = "center"
    percent_text_style.offset                    = { 0, 0, 2 }
    percent_text_style.font_size                 = (percent_text_style.font_size or 18) * mod.scalable_unit

    local passes                                 = {
        -- Filled base slice
        {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "peril_bar",
            style     = {
                uvs                  = { { 1, 0 }, { 0, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 1 },
                size                 = size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount = 1,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { PERIL_ARC_TOP, PERIL_ARC_BOTTOM },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = { 1, 1, 1, 1 },
                },
            },
        },
        -- Unfilled edge slice (remainder)
        {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "peril_edge",
            style     = {
                uvs                  = { { 1, 0 }, { 0, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 1 },
                size                 = size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount = 0,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { PERIL_ARC_TOP, PERIL_ARC_BOTTOM },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = { 1, 1, 1, 1 },
                },
            },
        },
        -- Thin sliver for “other overheat” notch (drawn on top of edge)
        {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "peril_other_edge",
            style     = {
                uvs                  = { { 1, 0 }, { 0, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 1 },
                size                 = size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount = 0,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { PERIL_ARC_TOP, PERIL_ARC_BOTTOM }, -- placeholder
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = { 1, 1, 1, 1 },
                },
            },
        },
        -- Percent label pass (value_id/style_id = "percent_text")
        {
            value_id = "percent_text",
            style_id = "percent_text",
            pass_type = "text",
            value = "",
            style = percent_text_style,
        },
    }

    dst.peril_bar                                = UIWidget.create_definition(passes, "peril_bar")
end

return PerilFeature
