-- File: scripts/mods/SimpleBuffFilter/util/colors.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return {} end
--[[
colors.lua – tint helpers used across options/debug/labels (e.g., rule-colored strings, header glyph colors).
]]
-- We return a module table AND attach it to mod.* for cross-file use
local M = {}
mod.colors_util = M

local TextUtilities = require("scripts/utilities/ui/text")

-- ---------- internals ----------
local function _has_color(name)
    -- Use rawget to check existence without triggering the __index error
    return rawget(Color, name) ~= nil
end

local function _arr(name, a)
    return Color[name](a or 255, true) -- {a,r,g,b}
end

-- Curated UI-ish palette for fallback picks (stable, "native" look)
local _fallback_names = {
    "ui_ability_purple",
    "ui_blue_light",
    "ui_green_light",
    "ui_orange_light",
    "ui_red_light",
    "ui_toughness_default",
}

-- Deterministic small hash (Lua 5.1 safe; no bitwise ops)
local function _hash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 2147483647 -- keep it bounded
    end
    if h < 0 then h = -h end
    return h
end

-- simple array lerp (ARGB), alpha fixed to 255
local function _lerp_arr(a, b, t)
    local aA, aR, aG, aB = a[1], a[2], a[3], a[4]
    local bA, bR, bG, bB = b[1], b[2], b[3], b[4]
    return {
        255,
        math.lerp(aR, bR, t),
        math.lerp(aG, bG, t),
        math.lerp(aB, bB, t),
    }
end

local function _derived_text_from(base_name)
    local base_arr = _arr(base_name, 255)
    local def_arr  = _arr("text_default", 255)
    -- Blend toward UI default text for readability
    return _lerp_arr(base_arr, def_arr, 0.55)
end

-- ---------- public API ----------

---Get a primary & text color for an archetype (arrays {a,r,g,b})
---@param base_arch string  -- e.g. "zealot", "veteran", "ogryn", "psyker", "adamant", "broker"
---@return table primary_argb, table text_argb
function M.archetype_color_pair(base_arch)
    -- 1) Official per-archetype colors if present
    local ui_key      = "ui_" .. base_arch -- e.g. ui_zealot
    local ui_text_key = ui_key .. "_text"  -- e.g. ui_zealot_text
    if _has_color(ui_key) then
        local primary = _arr(ui_key, 255)
        local text    = _has_color(ui_text_key) and _arr(ui_text_key, 255) or _derived_text_from(ui_key)
        return primary, text
    end

    -- 2) Fallback: stable pick from curated palette
    local idx     = (_hash(base_arch or "arch") % #_fallback_names) + 1
    local pick    = _fallback_names[idx]
    local primary = _arr(pick, 255)
    local text    = _derived_text_from(pick)
    return primary, text
end

---Colorize a string using ARGB array (applies {#color} markup)
---@param s string
---@param argb table  -- {a,r,g,b}
---@return string colored
function M.tint_text(s, argb)
    if not s or s == "" then return s end
    local c = argb or _arr("text_default", 255)
    return TextUtilities.apply_color_to_text(s, c)
end

---Convenience: fetch an ARGB array by Color name (e.g., "ui_blue_light")
---@param color_name string
---@param a integer|nil
---@return table argb
function M.color_arr(color_name, a)
    if _has_color(color_name) then
        return _arr(color_name, a or 255)
    end
    return _arr("text_default", a or 255)
end

-- ===== Rule palette & helper =================================================

-- Map each rule to a UI color (ARGB array). Adjust names here if you prefer different tones.
M.RULE_COLORS = {
    allow              = M.color_arr("ui_green_light", 255),
    hide               = M.color_arr("ui_red_light", 255),
    only_in_psykhanium = M.color_arr("ui_ability_purple", 255),
}

---Tint text according to a SimpleBuffFilter rule id.
---@param text string
---@param rule string  -- one of: allow, hide, only_in_psykhanium
---@return string colored_text
function M.tint_rule(text, rule)
    local arr = (M.RULE_COLORS and M.RULE_COLORS[rule]) or _arr("text_default", 255)
    return M.tint_text(text, arr)
end

-- Also expose on mod.* for convenience if other files prefer that style
mod.RULE_COLORS = M.RULE_COLORS
mod.tint_rule   = M.tint_rule

return M
