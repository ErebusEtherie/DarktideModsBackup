-- File: RingHud/scripts/mods/RingHud/features/dodge_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local UIWidget               = require("scripts/managers/ui/ui_widget")
local HudElementDodgeCounter = require("scripts/ui/hud/elements/dodge_counter/hud_element_dodge_counter")
local U                      = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

local DodgeFeature           = {}

local SETTINGS               = mod._settings
local MAX_DODGE_SEGMENTS     = mod.MAX_DODGE_SEGMENTS or 6

local COL_FULL               = mod.PALETTE_RGBA1.dodge_color_full_rgba
local COL_POS                = mod.PALETTE_RGBA1.dodge_color_positive_rgba
local COL_NEG                = mod.PALETTE_RGBA1.dodge_color_negative_rgba

local DODGE_SEGMENT_GAP      = 0.03
local DODGE_ARC_MIN          = 0.51
local DODGE_ARC_MAX          = 0.995

mod._dodge_max_effective     = mod._dodge_max_effective or 0
mod._dodge_effective_left    = mod._dodge_effective_left or 0

local _style_keys            = {}
for i = 1, MAX_DODGE_SEGMENTS do
    _style_keys[i] = "dodge_bar_" .. i
end

local _cached_arcs = {}

local function _fast_hide_all(widget, style)
    local changed = false

    for i = 1, MAX_DODGE_SEGMENTS do
        local seg = style[_style_keys[i]]

        if seg then
            if seg.visible then
                seg.visible = false
                changed = true
            end

            if seg.material_values and seg.material_values.amount ~= 0 then
                seg.material_values.amount = 0
                changed = true
            end
        end
    end

    if changed then
        widget.dirty = true
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Vanilla dodge-counter state
-- ─────────────────────────────────────────────────────────────────────────────
if HudElementDodgeCounter and not mod._dodge_counter_hook_applied then
    mod:hook_safe(HudElementDodgeCounter, "_update_dodge_amount", function(self)
        mod._dodge_max_effective = self and self._max_effective_dodges or 0
        mod._dodge_effective_left = self and self._effective_dodges_left or 0
    end)

    mod._dodge_counter_hook_applied = true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Layout Application
-- ─────────────────────────────────────────────────────────────────────────────
function DodgeFeature.apply_layout(widget, ctx)
    if not widget or not widget.style then
        return
    end

    local changed = false
    local style = widget.style
    local apply_shake_offset = U.apply_shake_to_style_offset

    for i = 1, MAX_DODGE_SEGMENTS do
        local st = style[_style_keys[i]]

        if st
            and apply_shake_offset(
                st,
                0,
                0,
                1,
                ctx.apply_shake,
                ctx.dx,
                ctx.dy,
                ctx.user_bias_px,
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

function DodgeFeature.update(widget, hud_state, hotkey_override)
    if not widget or not widget.style then
        return
    end

    local style = widget.style
    local data = hud_state and hud_state.dodge_data or nil

    if not data then
        return
    end

    local num_disp = data.efficient_dodges_display or 0
    local remaining = data.remaining_efficient or 0
    local threshold = SETTINGS.dodge_viz_threshold

    -- Settings: 0 = always visible, -1 = always hidden, positive = threshold gating
    if threshold == -1 and not hotkey_override then
        _fast_hide_all(widget, style)
        return
    end

    local changed = false

    local arcs = U.get_segment_arcs(_cached_arcs, num_disp, DODGE_ARC_MIN, DODGE_ARC_MAX, DODGE_SEGMENT_GAP)

    local outline_color

    if num_disp > 0 and remaining >= num_disp then
        outline_color = COL_FULL
    elseif remaining > 0 then
        outline_color = COL_POS
    else
        outline_color = COL_NEG
    end

    local current_max = math.clamp(num_disp, 0, MAX_DODGE_SEGMENTS)
    local fallback_arc = { DODGE_ARC_MIN, DODGE_ARC_MIN }

    for i = 1, MAX_DODGE_SEGMENTS do
        local seg_style = style[_style_keys[i]]

        if seg_style and seg_style.material_values then
            local mat = seg_style.material_values
            local within_max = i <= current_max
            local normally_visible = false

            if within_max and num_disp > 0 then
                normally_visible = threshold == 0
                    or num_disp <= threshold
                    or remaining <= threshold and remaining < num_disp
            end

            local seg_visible = (hotkey_override or normally_visible) and within_max

            if seg_visible then
                local arc = arcs and arcs[i] or fallback_arc

                changed = U.mv_set_arc(mat, arc[1], arc[2], changed)

                local seg_amount = remaining >= i and 1 or 0

                if mat.amount ~= seg_amount then
                    mat.amount = seg_amount
                    changed = true
                end

                changed = U.mv_set_outline(mat, outline_color, changed)
            end

            changed = U.set_style_visible(seg_style, seg_visible, changed)
        end
    end

    if changed then
        widget.dirty = true
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Widget factory
-- ─────────────────────────────────────────────────────────────────────────────
function DodgeFeature.add_widgets(dst, styles, metrics, colors)
    local size = metrics and metrics.size or { 240, 240 }
    local ARGB = colors and colors.ARGB or mod.PALETTE_ARGB255 or {}
    local RGBA1 = colors and colors.RGBA1 or mod.PALETTE_RGBA1 or {}

    setmetatable(ARGB, {
        __index = function()
            return { 255, 255, 255, 255 }
        end
    })

    setmetatable(RGBA1, {
        __index = function()
            return { 1, 1, 1, 1 }
        end
    })

    local passes = {}

    for i = 1, MAX_DODGE_SEGMENTS do
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value = "content/ui/materials/effects/forcesword_bar",
            style_id = "dodge_bar_" .. i,
            style = {
                uvs = {
                    { 0, 0 },
                    { 1, 1 }
                },
                horizontal_alignment = "center",
                vertical_alignment = "center",
                offset = { 0, 0, 1 },
                size = size,
                color = ARGB.GENERIC_WHITE,
                visible = false,
                pivot = { 0, 0 },
                angle = 0,
                material_values = {
                    amount = 0,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { DODGE_ARC_MIN, DODGE_ARC_MIN },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = table.clone(RGBA1.dodge_color_positive_rgba),
                    SizeThicknessOutline = { 0.45, 0.03, 0.02 },
                },
            },
        }
    end

    dst.dodge_bar = UIWidget.create_definition(passes, "dodge_bar")
end

return DodgeFeature
