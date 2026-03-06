-- File: scripts/mods/SimpleBuffFilter/runtime/buff_introspect.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end
--[[
buff_introspect.lua – helpers to get a buff’s template/name identity info used by the decision logic.

Updated:
• Prefer real template key (instance._template_name / template.name) over hud_icon basename.
• Added template_name_for_talent(): targeted aliasing for talent resolution (Option B).
]]
-- Depends on: runtime/context.lua (for mod.tbf_ctx.*)
mod.tbf_buff = mod.tbf_buff or {}

-- ============================================================================
-- Local helpers
-- ============================================================================
local function _basename_from_hud_icon(tmpl)
    local p = tmpl and tmpl.hud_icon
    if type(p) ~= "string" or p == "" then return nil end
    local base = p:match("([^/]+)$")
    if not base or base == "" then return nil end
    -- Be defensive in case an extension ever appears
    base = base:gsub("%.%w+$", "")
    return base
end

-- Option B: targeted normalization for certain internally-controlled child buffs.
-- Example:
--   zealot_on_perfect_blocking_block_dodging_synergy -> zealot_block_dodging_synergy
local function _alias_template_name_for_talent(name)
    if type(name) ~= "string" or name == "" then return nil end
    local alias = name:gsub("^([A-Za-z]+)_on_perfect_blocking_", "%1_")
    if alias ~= name then
        return alias
    end
    return nil
end

-- ============================================================================
-- Template helpers
-- ============================================================================

---Return a buff template table from a variety of objects or instances.
---@param any any
---@return table|nil
function mod.tbf_buff.template_from(any)
    if not any then return nil end

    -- Method-style accessor (common on live instances)
    if any.template then
        local res = any:template()
        if res then return res end
    end

    -- Common fields on instances
    if any._template then return any._template end
    if any._buff_template then return any._buff_template end

    return nil
end

---Return the runtime template identifier we should use for buff identity (prefs/rules).
---Order:
---  1) instance._template_name (when provided by the engine)
---  2) template.name (runtime key injected/available on many template tables)
---  3) memoized value we stored previously on the instance
---  4) basename(template.hud_icon) (last resort; may be shared across templates)
---@param any any
---@return string|nil
function mod.tbf_buff.template_name(any)
    if not any then return nil end

    -- 1) Engine-provided cached name on instance
    local n = rawget(any, "_template_name")
    if type(n) == "string" and n ~= "" then
        if type(any) == "table" then rawset(any, "_tbf_template_name", n) end
        return n
    end

    -- 2) Prefer runtime template key if present
    local t = mod.tbf_buff.template_from(any)
    local tn = t and t.name
    if type(tn) == "string" and tn ~= "" then
        if type(any) == "table" then rawset(any, "_tbf_template_name", tn) end
        return tn
    end

    -- 3) Our own memo on the instance (cheap & safe)
    if type(any) == "table" then
        local memo = rawget(any, "_tbf_template_name")
        if type(memo) == "string" and memo ~= "" then return memo end
    end

    -- 4) Final fallback: derive from HUD icon path basename
    local from_icon = _basename_from_hud_icon(t)
    if from_icon and from_icon ~= "" then
        if type(any) == "table" then rawset(any, "_tbf_template_name", from_icon) end
        return from_icon
    end

    return nil
end

---Return the template identifier to use for TALENT resolution.
---This keeps the raw buff identity intact (template_name), but provides a targeted
---alias for talent lookup when child-buff names include extra event infixes.
---@param any any
---@return string|nil
function mod.tbf_buff.template_name_for_talent(any)
    if not any then return nil end

    if type(any) == "table" then
        local memo = rawget(any, "_tbf_template_name_for_talent")
        if type(memo) == "string" and memo ~= "" then return memo end
    end

    local raw = mod.tbf_buff.template_name(any)
    if not raw then return nil end

    local alias = _alias_template_name_for_talent(raw) or raw

    if type(any) == "table" then
        rawset(any, "_tbf_template_name_for_talent", alias)
    end

    return alias
end

---If present, return the first related talent id from a template.
---@param buff_template table|nil
---@return string|nil
function mod.tbf_buff.first_related_talent(buff_template)
    -- Accept both the correct and misspelled field; allow single string or array.
    local rel = buff_template and
        (buff_template.related_talents or buff_template.realted_talents or buff_template.related_talent)
    if type(rel) == "table" then
        return rel[1]
    elseif type(rel) == "string" then
        return rel
    end
    return nil
end
