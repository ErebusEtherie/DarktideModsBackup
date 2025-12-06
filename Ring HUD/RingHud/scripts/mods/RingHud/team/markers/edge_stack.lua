-- File: RingHud/scripts/mods/RingHud/team/markers/edge_stack.lua
-- Purpose: Edge stacking for floating teammate markers (style-offset pushes).
-- Exports:
--   Edge.reset_if_needed()
--   Edge.ensure_bases(marker, style)
--   Edge.update_push(widget, marker, style, step_x, step_y, margins) -> push_x, push_y, edge, axis
--
-- Notes:
--   * Shared per-frame counters on `mod.*` so all markers participate in the same stack.
--   * Applies a uniform offset (px, py) to every style offset, relative to captured base offsets.
--   * Pushes BOTH `style.offset` and (if originally present) `style.default_offset` so engine distance scaling cannot undo pushes.
--   * Per-edge clamp bias: if the first tile needs extra push to fit inside screen, we apply that same baseline to all later tiles on that edge.
--   * `margins` are normalized { left, right, up, down } in 0..1 of screen size.
--   * Vertical stacking (left/right): first tile decides growth dir (top-half => +Y/down, bottom-half => -Y/up).
--   * Horizontal stacking (top/bottom): treat bottom like top; choose dir by screen-half:
--       left half  => push +X (right)
--       right half => push -X (left)

local mod = get_mod("RingHud"); if not mod then return {} end
mod.team_edge_stack        = mod.team_edge_stack or {}
local Edge                 = mod.team_edge_stack

mod._edge_stack_last_frame = mod._edge_stack_last_frame or -1
mod._edge_stack_counts     = mod._edge_stack_counts or { left = 0, right = 0, top = 0, bottom = 0 }
mod._edge_stack_refs       = mod._edge_stack_refs or { top_x = nil, bottom_x = nil }
mod._edge_stack_dirs       = mod._edge_stack_dirs or { left = nil, right = nil }
-- NEW: per-edge baseline clamp bias, reset each frame
mod._edge_stack_bias_y     = mod._edge_stack_bias_y or { left = 0, right = 0 }
mod._edge_stack_bias_x     = mod._edge_stack_bias_x or { top = 0, bottom = 0 }

-- Screen-space gate for top/bottom lane collision (pixels).
-- Wider gate so tiles more readily join the same lane.
-- Override at runtime with: mod.EDGE_COLLIDE_PX = <number>
local function _default_gate_px()
    local s = (mod._settings and mod._settings.team_tiles_scale) or 1
    local base_w = 220                         -- fallback if constants aren't reachable here
    return math.floor(base_w * s * 1.25 + 0.5) -- ~1.25 × tile width
end

local function _resolution_px()
    local w = (rawget(_G, "RESOLUTION_LOOKUP") and RESOLUTION_LOOKUP.width) or 1920
    local h = (rawget(_G, "RESOLUTION_LOOKUP") and RESOLUTION_LOOKUP.height) or 1080
    return w, h
end

local function _screen_edges_px(margins)
    local w, h = _resolution_px()
    local m    = margins or { left = 0.03, right = 0.03, up = 0.06, down = 0.06 }
    local L    = (m.left or 0) * w
    local R    = w - (m.right or 0) * w
    local Tm   = (m.up or 0) * h
    local B    = h - (m.down or 0) * h
    return L, R, Tm, B
end

-- Reset once per world-markers update (driven by a counter set in floating.lua)
function Edge.reset_if_needed()
    local cur = rawget(mod, "_edge_stack_frame_id") or 0
    if cur ~= mod._edge_stack_last_frame then
        mod._edge_stack_last_frame                                = cur
        local c                                                   = mod._edge_stack_counts
        c.left, c.right, c.top, c.bottom                          = 0, 0, 0, 0
        mod._edge_stack_refs.top_x, mod._edge_stack_refs.bottom_x = nil, nil
        mod._edge_stack_dirs.left, mod._edge_stack_dirs.right     = nil, nil
        -- reset per-edge biases
        mod._edge_stack_bias_y.left, mod._edge_stack_bias_y.right = 0, 0
        mod._edge_stack_bias_x.top, mod._edge_stack_bias_x.bottom = 0, 0
    end
end

-- Capture bases for BOTH offset and (if originally present) default_offset.
-- Also capture approximate local art bounds (min/max of style offsets) for clamping.
function Edge.ensure_bases(marker, style)
    if marker._edge_stack_bases then return end

    local bases = {}
    local min_x, max_x = math.huge, -math.huge
    local min_y, max_y = math.huge, -math.huge

    for key, st in pairs(style or {}) do
        local off = st and st.offset
        if off and type(off[1]) == "number" and type(off[2]) == "number" then
            local bx, by, bz = off[1], off[2], off[3] or 0

            local doff = st.default_offset
            local has_default = (type(doff) == "table"
                and type(doff[1]) == "number"
                and type(doff[2]) == "number")

            local dbx, dby, dbz = bx, by, bz
            if has_default then
                dbx, dby, dbz = doff[1], doff[2], doff[3] or 0
            end

            bases[key] = {
                bx, by, bz,    -- [1..3] live base
                dbx, dby, dbz, -- [4..6] default base
                has_default    -- [7]    originally had default_offset
            }

            if bx < min_x then min_x = bx end
            if bx > max_x then max_x = bx end
            if by < min_y then min_y = by end
            if by > max_y then max_y = by end
        end
    end

    marker._edge_stack_bases  = bases
    marker._edge_stack_bounds = {
        min_x = (min_x ~= math.huge) and min_x or 0,
        max_x = (max_x ~= -math.huge) and max_x or 0,
        min_y = (min_y ~= math.huge) and min_y or 0,
        max_y = (max_y ~= -math.huge) and max_y or 0,
    }
end

-- Clamp a proposed push so widget.offset + local art-bounds + push stay inside screen edges.
local function _clamp_push(widget, marker, push_x, push_y, L, R, Tm, B, axis)
    local off    = widget.offset or { 0, 0, 0 }
    local wx, wy = off[1] or 0, off[2] or 0
    local b      = marker._edge_stack_bounds
    if not b then return push_x, push_y end

    if axis == "x" then
        local min_world = wx + b.min_x + push_x
        local max_world = wx + b.max_x + push_x
        if min_world < L then
            push_x = push_x + (L - min_world)
        elseif max_world > R then
            push_x = push_x - (max_world - R)
        end
    elseif axis == "y" then
        local min_world = wy + b.min_y + push_y
        local max_world = wy + b.max_y + push_y
        if min_world < Tm then
            push_y = push_y + (Tm - min_world)
        elseif max_world > B then
            push_y = push_y - (max_world - B)
        end
    end

    return push_x, push_y
end

-- Apply push to BOTH live offset and (if it originally existed) default_offset.
local function _apply_style_push(marker, style, px, py)
    local bases = marker._edge_stack_bases
    if not bases then return false end
    local changed = false

    for key, st in pairs(style or {}) do
        local base = bases[key]
        if base and st then
            -- Live offset
            local off = st.offset
            if off then
                local nx, ny = base[1] + px, base[2] + py
                if off[1] ~= nx or off[2] ~= ny then
                    off[1], off[2] = nx, ny
                    changed = true
                end
            end

            -- Default offset (ONLY if it originally existed)
            if base[7] then
                local doff = st.default_offset
                if doff then
                    local ndx, ndy = base[4] + px, base[5] + py
                    if doff[1] ~= ndx or doff[2] ~= ndy then
                        doff[1], doff[2] = ndx, ndy
                        changed = true
                    end
                end
            end
        end
    end

    return changed
end

-- Compute & apply push based on which screen edge the marker is near.
-- Returns push_x, push_y, edge, axis. (edge ∈ {"left","right","top","bottom"} or nil; axis ∈ {"x","y"} or nil)
function Edge.update_push(widget, marker, style, step_x, step_y, margins)
    if not (widget and marker and style) then return 0, 0, nil, nil end

    local STEP_X = step_x or 0
    local STEP_Y = step_y or 0

    -- Fast exit if no push at all
    if STEP_X == 0 and STEP_Y == 0 then
        local last = marker._edge_stack_last or { 0, 0 }
        if (last[1] ~= 0 or last[2] ~= 0) and _apply_style_push(marker, style, 0, 0) then
            widget.dirty = true
        end
        marker._edge_stack_last = { 0, 0 }
        return 0, 0, nil, nil
    end

    local L, R, Tm, B = _screen_edges_px(margins)
    local off         = widget.offset or { 0, 0, 0 }
    local x, y        = off[1], off[2]
    local EPS         = mod.EDGE_MARGIN_EPS or 10

    local near_left   = x and ((x - L) <= EPS) or false
    local near_right  = x and ((R - x) <= EPS) or false
    local near_top    = y and ((y - Tm) <= EPS) or false
    local near_bottom = y and ((B - y) <= EPS) or false
    local prefer_vert = (near_left or near_right) and (near_top or near_bottom)

    local edge, axis  = nil, nil
    if near_left then
        edge, axis = "left", "y"
    elseif near_right then
        edge, axis = "right", "y"
    elseif not prefer_vert and near_top then
        edge, axis = "top", "x"
    elseif not prefer_vert and near_bottom then
        edge, axis = "bottom", "x"
    elseif marker.is_clamped then
        -- If clamped, infer edge from clamp angle (treat bottom like top for horizontal stacking)
        local a = (marker.angle) or (widget.content and widget.content.angle)
        if a then
            local PI, TAU = math.pi, math.pi * 2
            local function norm(v)
                v = (v + PI) % TAU; if v < 0 then v = v + TAU end; return v - PI
            end
            local function nearang(v, tgt) return math.abs(norm(v - tgt)) < 0.4 end
            a = norm(a)
            if nearang(a, 0) then
                edge, axis = "left", "y"
            elseif nearang(a, PI) then
                edge, axis = "right", "y"
            elseif nearang(a, PI * 0.5) then
                edge, axis = "top", "x"
            elseif nearang(a, -PI * 0.5) then
                edge, axis = "bottom", "x"
            end
        end
    end

    -- Compute push
    local push_x, push_y = 0, 0
    if edge then
        local counts = mod._edge_stack_counts

        if axis == "y" then
            -- Vertical stacking for left/right edges (with per-edge baseline bias)
            local dirs   = mod._edge_stack_dirs
            local biases = mod._edge_stack_bias_y
            local mid_y  = 0.5 * (Tm + B)

            if edge == "left" then
                if dirs.left == nil then dirs.left = (y and y > mid_y) and -1 or 1 end
                counts.left = (counts.left or 0) + 1
                local base_push = (counts.left - 1) * STEP_Y * dirs.left + (biases.left or 0)
                push_y = base_push
                local before = push_y
                _, push_y = _clamp_push(widget, marker, 0, push_y, L, R, Tm, B, "y")
                if (biases.left or 0) == 0 then
                    local delta = push_y - before
                    if delta ~= 0 then biases.left = delta end
                end
            else -- right
                if dirs.right == nil then dirs.right = (y and y > mid_y) and -1 or 1 end
                counts.right = (counts.right or 0) + 1
                local base_push = (counts.right - 1) * STEP_Y * dirs.right + (biases.right or 0)
                push_y = base_push
                local before = push_y
                _, push_y = _clamp_push(widget, marker, 0, push_y, L, R, Tm, B, "y")
                if (biases.right or 0) == 0 then
                    local delta = push_y - before
                    if delta ~= 0 then biases.right = delta end
                end
            end
        else
            -- Horizontal stacking for top/bottom edges (with per-edge baseline bias)
            local collides, idx = false, 0
            local dir = 1
            if x then
                local mid_x   = 0.5 * (L + R)
                dir           = (x < mid_x) and 1 or -1

                local gate_px = tonumber(mod.EDGE_COLLIDE_PX) or _default_gate_px()
                local refs    = mod._edge_stack_refs
                if edge == "top" then
                    if refs.top_x == nil then
                        refs.top_x = x
                        mod._edge_stack_counts.top = 1
                        idx = 0
                    else
                        if math.abs(x - refs.top_x) <= gate_px then
                            collides = true
                            idx = mod._edge_stack_counts.top or 0
                            mod._edge_stack_counts.top = (mod._edge_stack_counts.top or 0) + 1
                        end
                    end
                else -- bottom (treated like top)
                    if refs.bottom_x == nil then
                        refs.bottom_x = x
                        mod._edge_stack_counts.bottom = 1
                        idx = 0
                    else
                        if math.abs(x - refs.bottom_x) <= gate_px then
                            collides = true
                            idx = mod._edge_stack_counts.bottom or 0
                            mod._edge_stack_counts.bottom = (mod._edge_stack_counts.bottom or 0) + 1
                        end
                    end
                end
            end

            local biases    = mod._edge_stack_bias_x
            local bias      = (edge == "top") and (biases.top or 0) or (biases.bottom or 0)

            local magnitude = collides and (idx * STEP_X) or 0
            local base_push = magnitude * dir + bias
            push_x          = base_push
            local before    = push_x
            push_x, _       = _clamp_push(widget, marker, push_x, 0, L, R, Tm, B, "x")

            if bias == 0 then
                local delta = push_x - before
                if delta ~= 0 then
                    if edge == "top" then biases.top = delta else biases.bottom = delta end
                end
            end
        end
    end

    -- Apply only when changed since last frame
    local last = marker._edge_stack_last or { 0, 0 }
    if last[1] ~= push_x or last[2] ~= push_y then
        if _apply_style_push(marker, style, push_x, push_y) then
            widget.dirty = true
        end
        last[1], last[2] = push_x, push_y
        marker._edge_stack_last = last
    end

    return push_x, push_y, edge, axis
end

-- Optional export (handy for switching clamp helpers)
function Edge.screen_edges_px(margins)
    return _screen_edges_px(margins)
end

return Edge
