-- File: RingHud/scripts/mods/RingHud/features/stamina_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local UIWidget           = require("scripts/managers/ui/ui_widget")
local Notch              = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")
local U                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

local StaminaFeature     = {}

-- =========================
-- Stamina arc envelope (must match widget defaults)
-- =========================
local STAMINA_ARC_BOTTOM = 0.51
local STAMINA_ARC_TOP    = 0.99

-- Draw/update the stamina arc + edge using the shared notch helper.
-- hud_element: used for the _stamina_bar_latched_on flag
-- widget: expects style.stamina_bar + style.stamina_edge (both with .material_values)
-- hud_state: provides hud_state.stamina_fraction and is_veteran_deadshot_adsing
-- hotkey_override: when true, forces visibility (shows current fraction)
function StaminaFeature.update(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local style      = widget.style
    local base_style = style.stamina_bar
    local edge_style = style.stamina_edge
    if not (base_style and base_style.material_values and edge_style and edge_style.material_values) then
        return
    end

    local fraction             = (hud_state and hud_state.stamina_fraction) or 0
    local changed              = false

    -- Visibility gating
    local visible_now_normally = false
    local threshold            = mod._settings.stamina_viz_threshold -- e.g. 0.25 by schema

    if threshold == 0 then
        visible_now_normally = true
    elseif hud_element and hud_element._stamina_bar_latched_on then
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

    -- Split parent arc into base(1) + edge(0) with fixed internal gap
    local r                = Notch.notch_split(STAMINA_ARC_TOP, STAMINA_ARC_BOTTOM, display_fraction)

    -- Base slice (filled)
    if base_mv.amount ~= 1 then
        base_mv.amount = 1; changed = true
    end
    changed = U.mv_set_arc(base_mv, r.base.top, r.base.bottom, changed)
    changed = U.set_style_visible(base_style, (overall_visible and r.base.show) == true, changed)

    -- Edge slice (unfilled)
    if edge_mv.amount ~= 0 then
        edge_mv.amount = 0; changed = true
    end
    changed = U.mv_set_arc(edge_mv, r.edge.top, r.edge.bottom, changed)
    changed = U.set_style_visible(edge_style, (overall_visible and r.edge.show) == true, changed)

    if changed then widget.dirty = true end
end

-- =========================
-- Widget factory (moves “how to draw it” here)
-- =========================
-- add_widgets(dst, styles, metrics, colors)
--   • dst      : table to receive widget_definitions (keyed)
--   • styles   : shared text/style tables (unused here, but kept for parity)
--   • metrics  : expects metrics.size (ring size)
--   • colors   : expects colors.ARGB / colors.RGBA1 (unused here; we keep white)
function StaminaFeature.add_widgets(dst, styles, metrics, colors)
    local size = (metrics and metrics.size)
    local ARGB = (colors and colors.ARGB) or (mod.PALETTE_ARGB255 or {})
    setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end })

    dst.stamina_bar = UIWidget.create_definition({
        {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "stamina_bar",
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
                    arc_top_bottom = { STAMINA_ARC_TOP, STAMINA_ARC_BOTTOM },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = { 1, 1, 1, 1 },
                },
            },
        },
        {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "stamina_edge",
            style     = {
                uvs                  = { { 1, 0 }, { 0, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 2 },
                size                 = size,
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount = 0,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { STAMINA_ARC_TOP, STAMINA_ARC_BOTTOM },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = { 1, 1, 1, 1 },
                },
            },
        },
    }, "stamina_bar")
end

return StaminaFeature
