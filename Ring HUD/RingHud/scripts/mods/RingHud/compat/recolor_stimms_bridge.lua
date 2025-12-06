-- File: RingHud/scripts/mods/RingHud/compat/recolor_stimms_bridge.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Public adapter (keep it tiny)
mod.recolor_stimms_bridge = mod.recolor_stimms_bridge or {}
local Bridge = mod.recolor_stimms_bridge

-- Lazy handle (no color caching)
local _RS = nil
local function _rs()
    _RS = _RS or (get_mod and get_mod("RecolorStimms") or nil)
    return _RS
end

local function _rs_enabled(rs)
    return rs and (not rs.is_enabled or rs:is_enabled())
end

-- Optional priming (harmless)
function Bridge.refresh()
    _RS = get_mod and get_mod("RecolorStimms") or nil
    return Bridge.is_available()
end

function Bridge.is_available()
    local rs = _rs()
    return _rs_enabled(rs) and ((type(rs.get_stimm_argb_255) == "function") or (type(rs.get_stimm_color) == "function"))
end

-- Strict, on-demand lookup. Caller MUST pass an exact RS stimm id and a fallback ARGB255 table.
-- Returns ARGB255 table.
function Bridge.stimm_argb255(stimm_id, fallback_argb255)
    local rs = _rs()
    if _rs_enabled(rs) and stimm_id then
        local fn255 = rs and rs.get_stimm_argb_255
        if type(fn255) == "function" then
            local c = fn255(stimm_id) -- NOTE: dot call (no self)
            if c and c[1] then return { c[1], c[2], c[3], c[4] } end
        end
        local fn01 = rs and rs.get_stimm_color
        if type(fn01) == "function" then
            local c01 = fn01(stimm_id) -- NOTE: dot call (no self)
            if c01 and c01[1] then
                return {
                    255,
                    math.floor((c01[1] or 0) * 255 + 0.5),
                    math.floor((c01[2] or 0) * 255 + 0.5),
                    math.floor((c01[3] or 0) * 255 + 0.5),
                }
            end
        end
    end
    return fallback_argb255
end

return Bridge
