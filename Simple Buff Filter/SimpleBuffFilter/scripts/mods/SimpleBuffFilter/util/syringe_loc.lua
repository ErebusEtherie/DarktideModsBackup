-- File: scripts/mods/SimpleBuffFilter/util/syringe_loc.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return true end
--[[
syringe_loc.lua – maps syringe buff template names (syringe_*) to their loc_* pickup descriptions and provides convenience localization.
]]

--------------------------------------------------------------------------------
-- Syringe → Pickup description (loc_*) mapper
--
-- Goal:
--   For any buff whose name starts with "syringe_" and which has (or can be
--   resolved to) a hud_icon, return the pickup's `description` loc_* string by
--   deriving a shared "base" key from:
--     • the buff's hud_icon leaf, e.g.
--         "content/ui/.../syringe_power_buff_hud" → base "syringe_power_"
--     • or the buff name, e.g.
--         "syringe_power_boost_buff" → base "syringe_power_"
--   If only a buff name is provided, we stay *data-driven* by resolving the
--   hud_icon from the syringe buff templates table before falling back.
--
-- Data sources:
--   • scripts/settings/pickup/pickups.lua (pickups.by_name[name].description)
--   • scripts/settings/buff/syringe_buff_templates.lua (buff_template.hud_icon)
--
-- Public API (cross-file):
--   mod._build_syringe_index()                    -- (re)build cache from pickups
--   mod.syringe_loc_for_buff(buff_name, hud_icon) -- -> loc_key|nil, pickup_name|nil
--   mod.syringe_label_for_buff(name, hud_icon)    -- -> localized string|nil
--------------------------------------------------------------------------------

-- Keep cross-file state on `mod.*` (project convention)
mod._syringe_idx = mod._syringe_idx or nil

-- Tiny helpers (fallbacks if engine's string helpers aren't present)
local _starts = string.starts_with or function(s, p)
    return s ~= nil and p ~= nil and s:sub(1, #p) == p
end

local _ends = string.ends_with or function(s, suf)
    return s ~= nil and suf ~= nil and s:sub(- #suf) == suf
end

-- Lazy-require pickups (defensive: don't explode in title screen)
local _pickups
local function _require_pickups()
    if _pickups then
        return _pickups
    end
    local res = require("scripts/settings/pickup/pickups")
    if type(res) == "table" then
        _pickups = res
        return _pickups
    end
    return nil
end

-- Normalise a pickup name like "syringe_power_boost_pocketable" to a base "syringe_power_"
local function _base_from_pickup_name(pickup_name)
    local token = type(pickup_name) == "string" and pickup_name:match("^syringe_([^_]+)") or nil
    return token and ("syringe_" .. token .. "_") or nil
end

-- Normalise a hud_icon leaf like "syringe_power_buff_hud" → "syringe_power_"
local function _base_from_hud_icon(hud_icon)
    if type(hud_icon) ~= "string" or hud_icon == "" then
        return nil
    end
    local leaf = hud_icon:match("([^/]+)$") or hud_icon
    -- common endings: "_buff_hud" (current), future-proof: also strip "_buff" or trailing "_hud"
    local base = leaf:gsub("_buff_hud$", "_")
    if base == leaf then base = base:gsub("_buff$", "_") end
    if base == leaf then base = base:gsub("_hud$", "_") end
    return _starts(base, "syringe_") and base or nil
end

-- Normalise a buff name like "syringe_power_boost_buff" → "syringe_power_"
local function _base_from_buff_name(buff_name)
    local token = type(buff_name) == "string" and buff_name:match("^syringe_([^_]+)") or nil
    return token and ("syringe_" .. token .. "_") or nil
end

-- Choose the better candidate record when multiple pickups collapse to the same base
local function _prefer(a, b)
    if not a then return b end
    if not b then return a end
    -- Prefer entries with a non-empty description; then prefer names ending with "_pocketable"; then longer name.
    local a_has = a.desc and a.desc ~= ""
    local b_has = b.desc and b.desc ~= ""
    if a_has ~= b_has then
        return b_has and b or a
    end
    local a_pocket = _ends(a.name or "", "_pocketable")
    local b_pocket = _ends(b.name or "", "_pocketable")
    if a_pocket ~= b_pocket then
        return b_pocket and b or a
    end
    if (a.name and b.name) and (#b.name ~= #a.name) then
        return (#b.name > #a.name) and b or a
    end
    return a
end

-- Build cache: base "syringe_power_" → { name="syringe_power_boost_pocketable", desc="loc_*" }
function mod._build_syringe_index()
    local pickups = _require_pickups()
    local by_name = pickups and pickups.by_name
    if type(by_name) ~= "table" then
        mod._syringe_idx = {}
        return
    end

    local idx = {}
    for name, data in pairs(by_name) do
        -- Heuristic: pickup is syringe-related
        if type(name) == "string" and _starts(name, "syringe_") then
            if type(data) == "table" then
                local base = _base_from_pickup_name(name)
                if base then
                    local rec = {
                        name = name,
                        desc = (type(data.description) == "string" and data.description) or nil,
                    }
                    idx[base] = _prefer(idx[base], rec)
                end
            end
        end
    end

    mod._syringe_idx = idx
end

-- Data-driven resolution of hud_icon from syringe buff templates (used when only buff_name is known)
local function _hud_icon_from_syringe_templates(buff_name)
    if type(buff_name) ~= "string" or not buff_name:find("^syringe_") then
        return nil
    end
    local tbl = require("scripts/settings/buff/syringe_buff_templates")
    if type(tbl) ~= "table" then
        return nil
    end
    -- Some packs export directly as [name] = template; others as { templates = { ... } }
    local t = tbl[buff_name] or (tbl.templates and tbl.templates[buff_name])
    local icon = t and t.hud_icon
    return (type(icon) == "string" and icon ~= "") and icon or nil
end

--- From a buff (id/name + hud_icon) → pickup description loc key (or nil)
-- @param buff_name string?  e.g. "syringe_power_boost_buff"
-- @param hud_icon  string?  e.g. "content/ui/.../syringe_power_buff_hud"
-- @return loc_key|nil, pickup_name|nil
function mod.syringe_loc_for_buff(buff_name, hud_icon)
    if not mod._syringe_idx then
        mod._build_syringe_index()
    end

    -- 1) Prefer icon-derived base (most reliable)
    local base = _base_from_hud_icon(hud_icon)

    -- 2) If no icon was provided, try to fetch it from the syringe buff templates table (purely data-driven).
    --    This fixes the "heal_corruption" buff id vs "corruption" icon/pickup token mismatch.
    if (not base) and type(buff_name) == "string" and buff_name:find("^syringe_") then
        local tmpl_icon = _hud_icon_from_syringe_templates(buff_name)
        base = _base_from_hud_icon(tmpl_icon) or base
    end

    -- 3) If base still missing (or not indexed yet), last fallback:
    --    search the built pickup-index keys for a substring match within the buff name,
    --    picking the *longest* candidate (most specific).
    if (not base) or (not mod._syringe_idx[base]) then
        local best_key, best_len
        if type(buff_name) == "string" then
            for candidate_base, _ in pairs(mod._syringe_idx or {}) do
                local i = buff_name:find(candidate_base, 1, true)
                if i then
                    local len = #candidate_base
                    if not best_len or len > best_len then
                        best_key, best_len = candidate_base, len
                    end
                end
            end
        end
        base = best_key or base
    end

    local hit = base and mod._syringe_idx[base]
    if hit and type(hit.desc) == "string" and hit.desc ~= "" then
        return hit.desc, hit.name
    end
    return nil, hit and hit.name or nil
end

--- Convenience: return a localized label (Localize(loc_*)) or nil
function mod.syringe_label_for_buff(buff_name, hud_icon)
    local loc_id = mod.syringe_loc_for_buff(buff_name, hud_icon)
    if loc_id and _G.Localize then
        local text = _G.Localize(loc_id)
        if type(text) == "string" and text ~= "" and text ~= ("<" .. loc_id .. ">") then
            return text
        end
    end
    return nil
end

return true
