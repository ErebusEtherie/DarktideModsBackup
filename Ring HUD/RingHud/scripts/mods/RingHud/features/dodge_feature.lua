-- File: RingHud/scripts/mods/RingHud/features/dodge_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

-- Colors palette is initialized elsewhere; we only read from mod.PALETTE_RGBA1 here.
local UIWidget                 = require("scripts/managers/ui/ui_widget")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local U                        = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

local DodgeFeature             = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Cross-file helpers for DODGE (exposed on `mod.*`)
--  Returns: consecutive_dodges, dr_start, dr_limit_base, diminishing_return
-- ─────────────────────────────────────────────────────────────────────────────
function mod.dodge_calculate_diminishing_return(dodge_comp, move_comp, slide_comp, wep_dodge_template, buff_ext, t)
    if not (dodge_comp and move_comp and slide_comp and buff_ext and t) then
        return 0, 1, 0, 1
    end

    local stat_buffs               = buff_ext:stat_buffs()
    local extra_consecutive_dodges = math.round(stat_buffs and stat_buffs.extra_consecutive_dodges or 0)

    local default_settings         = PlayerCharacterConstants and PlayerCharacterConstants.default_dodge_settings
    local default_dr_start         = (default_settings and default_settings.diminishing_return_start) or 2
    local default_dr_limit         = (default_settings and default_settings.diminishing_return_limit) or 1
    local default_dr_modifier      = (default_settings and default_settings.diminishing_return_distance_modifier) or 1

    local dr_start_base            = (wep_dodge_template and wep_dodge_template.diminishing_return_start) or
        default_dr_start
    local dr_limit_base            = (wep_dodge_template and wep_dodge_template.diminishing_return_limit) or
        default_dr_limit
    local dr_start                 = dr_start_base + extra_consecutive_dodges

    if dr_start >= math.huge then
        return (dodge_comp.consecutive_dodges or 0), math.huge, 0, 1
    end

    local consecutive_dodges = math.min(dodge_comp.consecutive_dodges or 0, dr_start + dr_limit_base)
    local is_cooled_down     = (dodge_comp.consecutive_dodges_cooldown or 0) < t

    if is_cooled_down and not move_comp.is_dodging then
        consecutive_dodges = 0
    end

    if is_cooled_down and not (slide_comp.was_in_dodge_cooldown) and move_comp.method == "sliding" then
        consecutive_dodges = 0
    end

    local dodges_into_diminishing = math.max(0, consecutive_dodges - dr_start)
    local dr_dist_mod_base        = (wep_dodge_template and wep_dodge_template.diminishing_return_distance_modifier) or
        default_dr_modifier
    local diminishing_factor      = (dr_limit_base > 0) and math.clamp(dodges_into_diminishing / dr_limit_base, 0, 1) or
        0
    local base                    = 1 - dr_dist_mod_base
    local diminishing_return      = base + dr_dist_mod_base * (1 - diminishing_factor)

    return consecutive_dodges, dr_start, dr_limit_base, diminishing_return
end

-- Draw/update the segmented dodge bar
-- widget: the dodge widget (expects style keys "dodge_bar_1" .. "dodge_bar_N")
-- hud_state: provides hud_state.dodge_data (efficient_dodges_display, remaining_efficient, etc.)
-- hotkey_override: when true, forces visibility regardless of thresholds
function DodgeFeature.update(widget, hud_state, hotkey_override)
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

    -- Outline tint by state
    local outline_color
    if data.has_infinite
        or (data.max_efficient_dodges_actual > 0 and (data.remaining_efficient or 0) >= data.max_efficient_dodges_actual)
    then
        outline_color = mod.PALETTE_RGBA1.dodge_color_full_rgba
    elseif (data.remaining_efficient or 0) > 0 then
        outline_color = mod.PALETTE_RGBA1.dodge_color_positive_rgba
    else
        outline_color = mod.PALETTE_RGBA1.dodge_color_negative_rgba
    end

    -- Settings: 0 = always visible, -1 = always hidden, positive = threshold gating
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
                    or ((data.remaining_efficient or 0) <= threshold
                        and (data.has_infinite or (data.remaining_efficient or 0) < num_disp))
            end

            -- Force show lifts the *root*, but never draws beyond within_max
            local seg_visible = (hotkey_override or normally_visible) and within_max
            local seg_amount  = 0

            if seg_visible and within_max and num_disp > 0 then
                -- Update per-segment arc envelope
                local arc = arcs[i] or { 0.51, 0.51 }
                changed = U.mv_set_arc(mat, arc[1], arc[2], changed)

                -- Filled (amount=1) if this segment index is within remaining efficient dodges
                seg_amount = (data.has_infinite or (data.remaining_efficient or 0) >= i) and 1 or 0

                -- Outline tint
                changed = U.mv_set_outline(mat, outline_color, changed)
            end

            changed = U.set_style_visible(seg_style, seg_visible, changed)

            if mat.amount ~= seg_amount then
                mat.amount = seg_amount
                changed = true
            end
        end
    end

    if changed then widget.dirty = true end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Widget factory
-- add_widgets(dst, styles, metrics, colors)
--   • dst:     table to receive widget defs (keyed)
--   • styles:  shared styles (unused here)
--   • metrics: expects metrics.size
--   • colors:  expects colors.ARGB and colors.RGBA1
-- ─────────────────────────────────────────────────────────────────────────────
function DodgeFeature.add_widgets(dst, styles, metrics, colors)
    local size  = (metrics and metrics.size) or { 240, 240 }
    local ARGB  = (colors and colors.ARGB) or (mod.PALETTE_ARGB255 or {})
    local RGBA1 = (colors and colors.RGBA1) or (mod.PALETTE_RGBA1 or {})
    setmetatable(ARGB, { __index = function() return { 255, 255, 255, 255 } end })
    setmetatable(RGBA1, { __index = function() return { 1, 1, 1, 1 } end })

    -- Build N segment passes (1..MAX_DODGE_SEGMENTS)
    local MAX_DODGE_SEGMENTS = mod.MAX_DODGE_SEGMENTS or 6
    local passes = {}
    for i = 1, MAX_DODGE_SEGMENTS do
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "dodge_bar_" .. i,
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
                    amount = 0,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { 0.51, 0.51 }, -- collapsed; update() sets real arcs
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color = table.clone(RGBA1.dodge_color_positive_rgba),
                },
            },
        }
    end

    dst.dodge_bar = UIWidget.create_definition(passes, "dodge_bar")
end

return DodgeFeature
