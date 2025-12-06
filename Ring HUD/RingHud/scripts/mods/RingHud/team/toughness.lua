-- team/toughness.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Centralised colours (single source of truth)
local Colors = mod.colors or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local T = {}

-- Returns "overshield" | "broken" | nil
function T.state(unit)
    if not unit or not Unit.alive(unit) then return nil end
    local ext = ScriptUnit.has_extension(unit, "toughness_system") and ScriptUnit.extension(unit, "toughness_system")
    if not ext then return nil end

    local pct            = ext.current_toughness_percent and ext:current_toughness_percent() or nil
    local pct_vis        = ext.current_toughness_percent_visual and ext:current_toughness_percent_visual() or nil
    local rem            = ext.remaining_toughness and ext:remaining_toughness() or nil
    local max_vis_pts    = ext.max_toughness_visual and ext:max_toughness_visual() or nil

    local EPS_F, EPS_PTS = 0.05, 5.0

    -- Overshield (priority)
    if (pct and pct_vis and (pct > pct_vis + EPS_F)) or (rem and max_vis_pts and (rem > max_vis_pts + EPS_PTS)) then
        return "overshield"
    end

    -- Broken
    if (pct and pct <= EPS_F) or (rem and rem <= EPS_PTS) then
        return "broken"
    end

    return nil
end

-- Returns (hp_outline_rgba, cor_outline_rgba) as material RGBA (0..1)
function T.outlines_for(state)
    local DEFAULT_WHITE = { 1, 1, 1, 1 }
    local DEFAULT_COR   = mod.PALETTE_RGBA1.default_corruption_color_rgba

    if state == "broken" then
        local c = mod.PALETTE_RGBA1.TOUGHNESS_BROKEN
        return c, c
    elseif state == "overshield" then
        local c = mod.PALETTE_RGBA1.TOUGHNESS_OVERSHIELD
        return c, c
    else
        -- Default: white HP outline; corruption uses central default tint
        return DEFAULT_WHITE, DEFAULT_COR
    end
end

return T
