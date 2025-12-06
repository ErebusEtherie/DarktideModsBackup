-- File: RingHud/scripts/mods/RingHud/systems/utils.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local C = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")

local RingHudUtils = {}

-- e.g. string.format(RingHudUtils.percent_num_format, 73.2) -> "73%"
RingHudUtils.percent_num_format = "%01.f%%"

--------------------------------------------------------------------------------
-- Segments / arcs
--------------------------------------------------------------------------------

-- Returns {top, bottom} for the i-th segment out of n, respecting gaps.
function RingHudUtils.seg_arc_range(i, n)
    n            = (n and n > 0) and n or 1 -- guard against divide-by-zero
    local span   = (C.ARC_MAX - C.ARC_MIN)
    local seg    = span / n
    local gap    = C.SEGMENT_GAP
    local bottom = C.ARC_MIN + (i - 1) * seg + gap
    local top    = C.ARC_MIN + i * seg - gap
    return { top, bottom }
end

--------------------------------------------------------------------------------
-- Player utilities
--------------------------------------------------------------------------------

function RingHudUtils.sorted_teammates()
    local pm = Managers.player
    if not pm then return {} end

    local local_player = pm.local_player_safe and pm:local_player_safe(1) or nil
    local humans = (pm.human_players and pm:human_players()) or {}
    local out = {}

    for _, p in pairs(humans) do
        if p ~= local_player then
            out[#out + 1] = p
        end
    end

    table.sort(out, function(a, b)
        return (a:session_id() or "") < (b:session_id() or "")
    end)

    return out
end

--------------------------------------------------------------------------------
-- Opacity for timers (0..255)
--------------------------------------------------------------------------------

function RingHudUtils.calculate_opacity(timer, max_duration)
    if not timer or timer <= 0 then return 0 end
    max_duration = math.max(max_duration or 0, 0.001)
    local t_clamped = math.clamp(timer, 0, max_duration)
    return math.floor(math.lerp(0, 255, 1 - (t_clamped / max_duration)))
end

--------------------------------------------------------------------------------
-- Offset-bias utilities (for the "ring_offset_bias" setting)
--------------------------------------------------------------------------------

local function _ensure_base(widget, style_key)
    if not (widget and widget.style and widget.style[style_key]) then return nil end
    local s = widget.style[style_key]
    s.offset = s.offset or { 0, 0, 0 }

    widget._ringhud_base_offsets = widget._ringhud_base_offsets or {}
    local base = widget._ringhud_base_offsets[style_key]

    if not base then
        base = { s.offset[1] or 0, s.offset[2] or 0, s.offset[3] or 0 }
        widget._ringhud_base_offsets[style_key] = base
    end

    return base, s
end

function RingHudUtils.apply_offset_bias(widget, style_key, dx, dy)
    local base, s = _ensure_base(widget, style_key)
    if not (base and s) then return end

    dx, dy = dx or 0, dy or 0
    s.offset[1] = base[1] + dx
    s.offset[2] = base[2] + dy
end

function RingHudUtils.apply_offset_bias_many(widget, style_keys, dx, dy)
    if not (widget and style_keys) then return end
    for i = 1, #style_keys do
        RingHudUtils.apply_offset_bias(widget, style_keys[i], dx, dy)
    end
end

-- Apply a positional bias only when `current_bias` changes.
function RingHudUtils.apply_bias_once(widget, current_bias, applier_fn)
    if not widget then return end
    current_bias = current_bias or 0

    if widget._ringhud_bias_version ~= current_bias then
        widget._ringhud_bias_version = current_bias
        if type(applier_fn) == "function" then
            applier_fn(current_bias)
        end
        widget.dirty = true
    end
end

return RingHudUtils
