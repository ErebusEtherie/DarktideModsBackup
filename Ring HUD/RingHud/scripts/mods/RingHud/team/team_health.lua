-- File: RingHud/scripts/mods/RingHud/team/team_health.lua
local mod = get_mod("RingHud"); if not mod then return end

if mod.team_health_presentation then
    return mod.team_health_presentation
end

local C                      = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local U                      = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local T                      = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_toughness")
local Notch                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local S                      = {}

mod.team_health_presentation = S

-- Per-segment corruption amount within [0..1] for segment i
local function seg_corruption_for(i, wounds, total_cor_frac)
    local step      = 1 / wounds
    local seg_end   = (wounds + 1 - i) * step
    local seg_start = seg_end - step
    local x         = (total_cor_frac - seg_start) / step
    if x < 0 then
        return 0
    elseif x > 1 then
        return 1
    else
        return x
    end
end

-- Pure presentation:
--  • style: widget.style
--  • tint:  ARGB-255 slot tint for the health fill (or a palette key string)
--  • wounds: integer [1..C.MAX_WOUNDS_CAP]
--  • hp_frac: [0..1] total health fraction
--  • corruption_total_frac: [0..1] total corruption fraction
--  • toughness_state: "overshield" | "broken" | nil (drives outline colors via T.outlines_for)
function S.update(style, tint, wounds, hp_frac, corruption_total_frac, toughness_state)
    wounds                        = math.clamp(tonumber(wounds) or 1, 1, C.MAX_WOUNDS_CAP)
    hp_frac                       = math.clamp(tonumber(hp_frac) or 0, 0, 1)

    -- Outline colors (RGBA 0..1) for HP & corruption layers
    local hp_outline, cor_outline = T.outlines_for(toughness_state)

    -- Extra (+1) HP pass draws the unfilled (top) piece when we split
    local extra_id                = string.format("hp_seg_%d", C.MAX_HP_SEGMENTS)
    local ex_s                    = style and style[extra_id]
    if ex_s then
        U.set_style_visible(ex_s, false)
    end

    local used_extra    = false
    local EPS           = mod.NOTCH_EPSILON or 1e-4

    -- Resolve tint once (accept palette key or ARGB-255 table)
    local resolved_tint = tint
    if type(resolved_tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[resolved_tint] then
        resolved_tint = mod.PALETTE_ARGB255[resolved_tint]
    end

    for seg = 1, C.MAX_WOUNDS_CAP do
        local on    = seg <= wounds
        local hp_id = string.format("hp_seg_%d", seg)
        local co_id = string.format("cor_seg_%d", seg)
        local hp_s  = style and style[hp_id]
        local co_s  = style and style[co_id]

        if hp_s and co_s and on then
            local base       = U.seg_arc_range(seg, wounds) -- {top, bottom} for this wound slot
            local top, bot   = base[1], base[2]
            local seg_len    = top - bot

            -- Corruption fraction within this segment (0..1)
            local cor_f      = seg_corruption_for(seg, wounds, corruption_total_frac)
            local hp_top_raw = top - seg_len * cor_f
            if hp_top_raw < bot then
                hp_top_raw = bot
            end

            -- Spacer between corruption and health (same arc-units thickness as health-edge notch)
            local eff_len_raw = hp_top_raw - bot
            local spacer_len  = math.max(C.HP_LEADING_EDGE_GAP or 0.01, C.MIN_CORR_HEALTH_GAP_PI or 0)
            spacer_len        = math.min(spacer_len, eff_len_raw * 0.98) -- preserve tiny slices
            local half_spacer = spacer_len * 0.5

            -- Apply spacer symmetrically
            local health_top  = math.max(bot, hp_top_raw - half_spacer)
            local cor_bot     = math.min(top, hp_top_raw + half_spacer)

            -- Final available health arc after spacer
            local eff_len     = health_top - bot

            -- Raw fill inside this segment if there were no corruption (0..1)
            local raw         = math.clamp(hp_frac * wounds - (seg - 1), 0, 1)
            local want_len    = seg_len * raw               -- desired health length ignoring corruption
            local real_len    = math.min(eff_len, want_len) -- clamped by available arc

            -----------------------------
            -- Corruption overlay (on top)
            -----------------------------
            do
                local mv      = co_s.material_values
                local visible = (cor_f > EPS) and (top - cor_bot > EPS)
                U.set_style_visible(co_s, visible)

                if visible then
                    U.mv_set_arc(mv, top, cor_bot, false)
                    mv.amount               = 1
                    mv.fill_outline_opacity = { 0.7, 1.3 }
                    U.mv_set_outline(mv, cor_outline)
                    mv.lightning_opacity = 0
                    mv.glow_on_off       = 0
                else
                    -- Collapse to a point to avoid stale arcs
                    U.mv_set_arc(mv, top, top, false)
                    mv.amount = 1
                    U.mv_set_outline(mv, cor_outline)
                end
            end

            -------------------------------------------
            -- Health (base) + split at the leading edge
            -------------------------------------------
            do
                local mv    = hp_s.material_values
                local ex_mv = ex_s and ex_s.material_values or nil

                -- Keep both halves identical in tint
                if type(resolved_tint) == "table" then
                    U.set_style_color(hp_s, resolved_tint)
                    if ex_s then
                        U.set_style_color(ex_s, resolved_tint)
                    end
                end

                local fill_op           = mv and mv.fill_outline_opacity or { 1.3, 1.3 }
                mv.fill_outline_opacity = fill_op
                U.mv_set_outline(mv, hp_outline)
                if ex_mv then
                    ex_mv.fill_outline_opacity = fill_op
                    U.mv_set_outline(ex_mv, hp_outline)
                end

                -- Empty / full / partial (with notch split)
                if eff_len <= EPS or real_len <= EPS then
                    U.mv_set_arc(mv, health_top, bot, false)
                    mv.amount = 0
                elseif real_len >= eff_len - EPS then
                    U.mv_set_arc(mv, health_top, bot, false)
                    mv.amount = 1
                else
                    local fill_frac = real_len / math.max(eff_len, EPS)
                    local r         = Notch.notch_split(health_top, bot, fill_frac)

                    -- Bottom (FILLED) piece
                    U.mv_set_arc(mv, r.base.top, r.base.bottom, false)
                    mv.amount = 1

                    -- Top (UNFILLED) piece via the extra pass
                    if ex_s and ex_mv and r.edge.show then
                        U.mv_set_arc(ex_mv, r.edge.top, r.edge.bottom, false)
                        ex_mv.amount = 0
                        used_extra   = true
                    end
                end
            end

            U.set_style_visible(hp_s, true)
            -- co_s visibility already set above
        else
            if hp_s then
                U.set_style_visible(hp_s, false)
            end
            if co_s then
                U.set_style_visible(co_s, false)
            end
        end
    end

    -- Decide the extra (+1) pass visibility AFTER processing all segments
    if ex_s then
        U.set_style_visible(ex_s, used_extra)
    end
end

return S
