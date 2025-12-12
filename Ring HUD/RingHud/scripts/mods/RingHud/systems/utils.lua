-- File: RingHud/scripts/mods/RingHud/systems/utils.lua
local mod = get_mod("RingHud"); if not mod then return {} end

if mod.utils then
    return mod.utils
end

local C = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")

mod.utils = {}
local RingHudUtils = mod.utils

-- e.g. string.format(RingHudUtils.percent_num_format, 73.2) -> "73%"
RingHudUtils.percent_num_format = "%01.f%%"

--------------------------------------------------------------------------------
-- Color helpers (shared)
--------------------------------------------------------------------------------

-- Compare ARGB255 or RGBA1 4-tuples (tolerant of nil)
function RingHudUtils.colors_equal(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

-- Ensure a valid ARGB255 (fallback to white)
function RingHudUtils.argb255_or_white(t)
    local white = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE) or { 255, 255, 255, 255 }
    if type(t) == "table" then
        return { t[1] or 255, t[2] or 255, t[3] or 255, t[4] or 255 }
    end
    return { white[1], white[2], white[3], white[4] }
end

-- Ensure a valid RGBA1 (fallback to white)
function RingHudUtils.rgba_or_white(t)
    if type(t) == "table" then
        return { t[1] or 1, t[2] or 1, t[3] or 1, t[4] or 1 }
    end
    return { 1, 1, 1, 1 }
end

-- Style text color (ARGB255). Returns true if mutated.
function RingHudUtils.set_style_text_color(style, argb255)
    if not style then return false end
    local nc = RingHudUtils.argb255_or_white(argb255)
    local tc = style.text_color
    if not tc or not RingHudUtils.colors_equal(tc, nc) then
        style.text_color = table.clone(nc)
        return true
    end
    return false
end

-- Style color (ARGB255). Returns true if mutated.
function RingHudUtils.set_style_color(style, argb255)
    if not style then return false end
    local nc = RingHudUtils.argb255_or_white(argb255)
    local c  = style.color
    if not c or not RingHudUtils.colors_equal(c, nc) then
        style.color = table.clone(nc)
        return true
    end
    return false
end

-- Toggle style.visibility and alpha. Returns true if mutated.
function RingHudUtils.set_style_visible(style, is_visible)
    if not style then return false end
    local changed = false

    if style.visible ~= is_visible then
        style.visible = is_visible
        changed = true
    end

    -- If a color is present, drive the alpha channel (ARGB255)
    if style.color then
        local want_a = is_visible and 255 or 0
        if style.color[1] ~= want_a then
            style.color[1] = want_a
            changed = true
        end
    end

    return changed
end

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
-- Offset/scale utilities (generic)
--------------------------------------------------------------------------------

-- Scale size/pivot/font_size by s, and counter-scale offset by 1/s (optional)
function RingHudUtils.apply_scale_and_offset(style, s)
    if not style or not s or s == 1 then return end
    local inv = (s ~= 0) and (1 / s) or 1

    if style.size then
        style.size[1] = style.size[1] * s
        style.size[2] = style.size[2] * s
    end
    if style.pivot then
        style.pivot[1] = style.pivot[1] * s
        style.pivot[2] = style.pivot[2] * s
    end
    if type(style.font_size) == "number" then
        style.font_size = style.font_size * s
    end
    if style.offset then
        style.offset[1] = style.offset[1] * inv
        style.offset[2] = style.offset[2] * inv
        -- z remains unchanged
    end
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

--------------------------------------------------------------------------------
-- ADS helpers (moved from core/HudElementRingHud_player.lua)
--------------------------------------------------------------------------------

function RingHudUtils.is_ads_now()
    local pm = Managers.player
    local player = pm and pm.local_player_safe and pm:local_player_safe(1) or nil
    local unit = player and player.player_unit or nil
    if not unit then return false end

    local ud_ext = ScriptUnit.has_extension(unit, "unit_data_system")
    if not ud_ext then return false end

    local alt = ud_ext:read_component("alternate_fire")
    return (alt and alt.is_active) or false
end

-- Returns the effective offset-bias (0..200), preferring Scanner override, then ADS override, then default.
function RingHudUtils.effective_bias(is_ads)
    local b

    if mod.scanner_active then
        b = tonumber(mod._settings and mod._settings.scanner_offset_bias_override)
        if b ~= nil then
            if b < 0 then b = 0 elseif b > 200 then b = 200 end
            return b
        end
    end

    if is_ads then
        b = tonumber(mod._settings and mod._settings.ads_offset_bias_override)
        if b ~= nil then
            if b < 0 then b = 0 elseif b > 200 then b = 200 end
            return b
        end
    end
    b = tonumber(mod._settings and mod._settings.ring_offset_bias) or 0
    if b < 0 then b = 0 elseif b > 200 then b = 200 end
    return b
end

--------------------------------------------------------------------------------
-- Style offset with optional shake (moved from core/HudElementRingHud_player.lua)
--------------------------------------------------------------------------------

-- Mutates `style.offset` using base + bias (+ optional shake), returns true if changed.
function RingHudUtils.apply_shake_to_style_offset(style, base_x, base_y, base_z,
                                                  apply_shake, dx, dy, px_bias_x, px_bias_y)
    if not style then return false end
    local changed = false

    base_x = base_x or 0
    base_y = base_y or 0
    base_z = base_z or 0

    style.offset = style.offset or { base_x, base_y, base_z }

    local px_x = (px_bias_x or 0)
    local px_y = (px_bias_y or 0)

    if apply_shake then
        px_x = px_x + (dx or 0)
        px_y = px_y + (dy or 0)
    end

    local tx, ty, tz = base_x + px_x, base_y + px_y, base_z

    if style.offset[1] ~= tx then
        style.offset[1] = tx; changed = true
    end
    if style.offset[2] ~= ty then
        style.offset[2] = ty; changed = true
    end
    if style.offset[3] ~= tz then
        style.offset[3] = tz; changed = true
    end

    return changed
end

--------------------------------------------------------------------------------
-- Material-values helpers (charge arcs etc.)
--------------------------------------------------------------------------------

-- mv.outline_color = RGBA1 (only write when changed). Returns true if changed.
function RingHudUtils.mv_set_outline(mv, rgba, changed)
    if not mv then return changed or false end
    local next_rgba = RingHudUtils.rgba_or_white(rgba)
    local curr = mv.outline_color
    if not curr or not RingHudUtils.colors_equal(curr, next_rgba) then
        mv.outline_color = table.clone(next_rgba)
        return true
    end
    return changed or false
end

-- mv.arc_top_bottom = {top, bottom}. Returns true if changed.
function RingHudUtils.mv_set_arc(mv, top, bottom, changed)
    if not mv then return changed or false end
    local curr = mv.arc_top_bottom
    if not curr or curr[1] ~= top or curr[2] ~= bottom then
        mv.arc_top_bottom = { top, bottom }
        return true
    end
    return changed or false
end

--------------------------------------------------------------------------------
-- Ammo helpers
--------------------------------------------------------------------------------

-- Sums a scalar or array field (e.g. ammo reserves in 1.10+).
-- Performance: O(N) where N is array size (usually < 5). Impact is negligible.
function RingHudUtils.sum_ammo_field(v, max_size)
    if type(v) == "number" then
        return v
    elseif type(v) == "table" then
        local total = 0
        local n = max_size or #v
        for i = 1, n do
            local elem = v[i]
            -- Nil protection: stop if the array has a hole, treating end of valid data.
            if elem == nil then break end
            total = total + (elem or 0)
        end
        return total
    end
    return 0
end

--------------------------------------------------------------------------------
-- HUD helpers (UIHud / constant elements)
--------------------------------------------------------------------------------

-- Returns: hud_instance, constant_elements_instance (may be nil, nil)
function RingHudUtils.get_current_hud_instances()
    local ui_manager = Managers.ui
    if not ui_manager then
        return nil, nil
    end

    return ui_manager._hud, ui_manager:ui_constant_elements()
end

-- Given hud/const and a class name, resolve the element instance
function RingHudUtils.resolve_element_instance(hud, const, class_name)
    local inst

    if hud and hud.element then
        inst = hud:element(class_name)
    end

    if (not inst) and const and const.element then
        inst = const:element(class_name)
    end

    return inst
end

return RingHudUtils
