-- File: RingHud/scripts/mods/RingHud/systems/notch_split.lua
-- Purpose: Shared "split one parent arc into base + edge with a fixed gap".
-- Contract used across stamina/peril/toughness/charge + team tiles.

local mod = get_mod("RingHud"); if not mod then return {} end

-- Global defaults so all call sites stay consistent
mod.NOTCH_GAP_DEFAULT = mod.NOTCH_GAP_DEFAULT or 0.01 -- fixed gap in [0..1] arc units
mod.NOTCH_EPSILON     = mod.NOTCH_EPSILON or 1e-4     -- visibility threshold

--- Split a parent arc into "base" (amount=1) and "edge" (amount=0) with a centered gap.
-- @param top     number  Parent arc top (same units as shader's arc_top_bottom[1])
-- @param bottom  number  Parent arc bottom (arc_top_bottom[2])
-- @param amount  number  Parent fill amount in [0..1]
-- @param gap     number? Optional gap size; defaults to mod.NOTCH_GAP_DEFAULT
-- @param eps     number? Optional epsilon for visibility; defaults to mod.NOTCH_EPSILON
-- @return table { base={top,bottom,show}, edge={top,bottom,show} }
function mod.notch_split(top, bottom, amount, gap, eps)
    if top == nil or bottom == nil or amount == nil then
        return {
            base = { top = top, bottom = bottom, show = false },
            edge = { top = top, bottom = bottom, show = false }
        }
    end

    local g        = gap or mod.NOTCH_GAP_DEFAULT
    local e        = eps or mod.NOTCH_EPSILON
    amount         = math.clamp(amount, 0, 1)

    local span     = top - bottom
    local span_abs = math.abs(span)
    if span_abs <= e then
        -- Degenerate parent: nothing to show
        return {
            base = { top = top, bottom = bottom, show = false },
            edge = { top = top, bottom = bottom, show = false }
        }
    end

    -- Edge position along the parent arc
    local edge_pos = bottom + span * amount

    -- Half-gap along the arc direction; clamp so we never invert the children
    local half = 0.5 * g
    if half * 2 >= span_abs - e then
        half = math.max(0, 0.5 * (span_abs - e))
    end

    -- Move "outwards" along the arc direction
    local sgn         = (span >= 0) and 1 or -1

    -- Base (filled) inherits parent bottom; its top stops just before the gap.
    local base_top    = edge_pos - sgn * half
    local base_bottom = bottom

    -- Edge (unfilled) inherits parent top; its bottom starts just after the gap.
    local edge_top    = top
    local edge_bottom = edge_pos + sgn * half

    -- Normalize to keep "top" the numerically larger endpoint (what the shader expects)
    local function norm_pair(a, b)
        return (a >= b) and a or b, (a >= b) and b or a
    end
    base_top, base_bottom = norm_pair(base_top, base_bottom)
    edge_top, edge_bottom = norm_pair(edge_top, edge_bottom)

    local base_len = math.abs(base_top - base_bottom)
    local edge_len = math.abs(edge_top - edge_bottom)

    return {
        base = { top = base_top, bottom = base_bottom, show = (amount > 0) and (base_len > e) },
        edge = { top = edge_top, bottom = edge_bottom, show = (amount < 1) and (edge_len > e) },
    }
end

-- Tiny convenience to write arc + visibility into a widget (optional).
-- Pass the style_ids for each child and (optionally) content visibility keys.
function mod.notch_apply(widget, style_id_base, style_id_edge, amount, parent_top, parent_bottom, gap, eps, content_keys)
    local res = mod.notch_split(parent_top, parent_bottom, amount, gap, eps)

    local sb = widget.style[style_id_base]
    local se = widget.style[style_id_edge]
    if sb and sb.material_values then
        sb.material_values.arc_top_bottom = { res.base.top, res.base.bottom }
        sb.material_values.amount         = 1
    end
    if se and se.material_values then
        se.material_values.arc_top_bottom = { res.edge.top, res.edge.bottom }
        se.material_values.amount         = 0
    end

    if content_keys and widget.content then
        local k_base, k_edge = content_keys.base, content_keys.edge
        if k_base then widget.content[k_base] = res.base.show end
        if k_edge then widget.content[k_edge] = res.edge.show end
    end

    return res
end

return {
    notch_split = mod.notch_split,
    notch_apply = mod.notch_apply,
}
