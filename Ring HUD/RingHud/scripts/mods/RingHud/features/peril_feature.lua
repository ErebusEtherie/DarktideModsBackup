-- File: RingHud/scripts/mods/RingHud/features/peril_feature.lua

local mod = get_mod("RingHud")
if not mod then return {} end

local RingHudUtils      = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local ColorUtilities    = require("scripts/utilities/ui/colors")
local Notch             = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local PerilFeature      = {}

-- Arc envelope must match the widget defaults (arc_top_bottom = { 0.50, 0.01 })
local PERIL_ARC_BOTTOM  = 0.01
local PERIL_ARC_TOP     = 0.50
local PERIL_ARC_TOTAL   = (PERIL_ARC_TOP - PERIL_ARC_BOTTOM)

local peril_color_steps = { 0.2125, 0.425, 0.6375, 0.834, 0.984, 1.0 }

local function _same_color(a, b) -- TODO Put this in utils and use it in munitions feature?
    if a == b then return true end
    if not a or not b then return false end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

function PerilFeature.update(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local style       = widget.style
    local base_style  = style.peril_bar
    local edge_style  = style.peril_edge
    local label_style = style.percent_text
    if not (base_style and base_style.material_values and edge_style and edge_style.material_values and label_style) then
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
        if not _same_color(mod._last_crosshair_override_argb, current_peril_color_argb) then
            mod.override_color = table.clone(current_peril_color_argb)
            if mod.override_color then mod.override_color[1] = 255 end
            mod._last_crosshair_override_argb = table.clone(current_peril_color_argb)
        end
    elseif mod.override_color ~= nil or mod._last_crosshair_override_argb ~= nil then
        mod.override_color = nil
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

    -- Lightning opacity (applied to both passes)
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
    local curb = base_mv.arc_top_bottom
    if (not curb) or curb[1] ~= r.base.top or curb[2] ~= r.base.bottom then
        base_mv.arc_top_bottom = { r.base.top, r.base.bottom }; changed = true
    end
    if base_style.visible ~= (bar_visible and r.base.show) then
        base_style.visible = (bar_visible and r.base.show); changed = true
    end

    -- Edge sliver (unfilled)
    if edge_mv.amount ~= 0 then
        edge_mv.amount = 0; changed = true
    end
    local cure = edge_mv.arc_top_bottom
    if (not cure) or cure[1] ~= r.edge.top or cure[2] ~= r.edge.bottom then
        edge_mv.arc_top_bottom = { r.edge.top, r.edge.bottom }; changed = true
    end
    if edge_style.visible ~= (bar_visible and r.edge.show) then
        edge_style.visible = (bar_visible and r.edge.show); changed = true
    end

    -- Lightning opacity -> both passes
    if base_mv.lightning_opacity ~= new_lightning_opacity then
        base_mv.lightning_opacity = new_lightning_opacity; changed = true
    end
    if edge_mv.lightning_opacity ~= new_lightning_opacity then
        edge_mv.lightning_opacity = new_lightning_opacity; changed = true
    end

    -- Outline color -> both passes
    local function set_outline(mv)
        local oc = mv.outline_color
        if (not oc)
            or oc[1] ~= mod.current_peril_color_rgba[1]
            or oc[2] ~= mod.current_peril_color_rgba[2]
            or oc[3] ~= mod.current_peril_color_rgba[3] then
            mv.outline_color = table.clone(mod.current_peril_color_rgba)
            changed = true
        end
    end
    set_outline(base_mv)
    set_outline(edge_mv)

    -- Label (unchanged)
    if label_style.visible ~= label_visible then
        label_style.visible = label_visible; changed = true
    end
    if label_visible then
        local text = string.format(RingHudUtils.percent_num_format, fraction * 100)
        if widget.content.percent_text ~= text then
            widget.content.percent_text = text; changed = true
        end
        if not label_style.text_color or not _same_color(label_style.text_color, current_peril_color_argb) then
            label_style.text_color = table.clone(current_peril_color_argb)
            changed = true
        end
    elseif widget.content.percent_text ~= "" then
        widget.content.percent_text = ""
        changed = true
    end

    if changed then widget.dirty = true end
end

return PerilFeature
