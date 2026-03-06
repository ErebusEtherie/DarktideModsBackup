-- File: scripts/mods/SimpleBuffFilter/core/prefs.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end

--[[
prefs.lua – Simplified flat storage.

Structure:
  mod.prefs.buffs[template_name] = {
      group = "veteran"|"zealot"|"melee"|"misc"|...,
      loc   = "loc_string_key",
      rule  = "allow"|"hide"|"only_in_psykhanium"
  }
  mod.prefs.hud = { x=0, y=0, scale=1.0, opacity=255 }
]]

mod._prefs_dirty = false

function mod._prefs_mark_dirty()
    mod._prefs_dirty = true
end

function mod.flush_prefs_now()
    if mod._prefs_dirty and mod.prefs then
        mod:set("prefs", mod.prefs)
        mod._prefs_dirty = false
    end
end

-- Bootstrap
if not mod.prefs then
    local p = mod:get("prefs")
    if type(p) ~= "table" then p = {} end

    -- Reset if structure is old (simple check: if 'per_archetype' exists, it's the old nested format)
    if p.per_archetype or not p.buffs then
        p = {
            buffs = {},
            hud   = { x = 0, y = 0, scale = 1.0, opacity = 255 }
        }
    end

    p.buffs   = p.buffs or {}
    p.hud     = p.hud or { x = 0, y = 0, scale = 1.0, opacity = 255 }

    mod.prefs = p
end

-- ===== Public API: Recording & Lookup =====

-- Record or update a buff entry (Discovery).
-- Only updates group/loc if missing or changed. Preserves existing rule.
function mod.prefs_record_buff(id, group, loc, default_rule)
    if not (id and group and loc) then return end
    local p = mod.prefs.buffs
    local entry = p[id]

    if not entry then
        local inherited_rule = nil
        for _, existing in pairs(p) do
            if existing.loc == loc then
                inherited_rule = existing.rule
                break
            end
        end

        p[id] = {
            group = group,
            loc   = loc,
            rule  = inherited_rule or default_rule or "allow"
        }
        mod._prefs_mark_dirty()

        -- Trigger option rebuild if we found something new
        local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
        if Rebuilder and Rebuilder.rebuild_debounced then Rebuilder.rebuild_debounced() end
    else
        -- Update metadata if changed (e.g. better loc resolution found), but keep the user's rule
        if entry.group ~= group or entry.loc ~= loc then
            entry.group = group
            entry.loc   = loc
            mod._prefs_mark_dirty()
        end
    end
end

-- Get rule for a specific buff ID (Fast lookup for HUD)
function mod.prefs_get_rule(id)
    local entry = mod.prefs.buffs[id]
    return entry and entry.rule or "allow"
end

-- Update rule for ALL buffs that match a specific localization key
-- This is used by the Options Menu, since the dropdowns are grouped by Loc string.
function mod.prefs_set_rule_by_loc(target_loc, new_rule)
    if not target_loc then return end
    local p = mod.prefs.buffs
    local changed = false

    for id, entry in pairs(p) do
        if entry.loc == target_loc and entry.rule ~= new_rule then
            entry.rule = new_rule
            changed = true
        end
    end

    if changed then
        mod._prefs_mark_dirty()
    end
end

-- ===== Maintenance =====

function mod.prefs_wipe_all()
    mod.prefs.buffs = {}
    mod.flush_prefs_now()
end

function mod.prefs_wipe_group(target_group)
    local p = mod.prefs.buffs
    local changed = false

    -- Handle special wipe targets if needed, or just iterate
    for id, entry in pairs(p) do
        if entry.group == target_group then
            p[id] = nil
            changed = true
        end
    end

    if changed then
        mod.flush_prefs_now()
    end
end

-- ===== HUD Transforms =====

function mod.prefs_get_hud()
    -- Ensure defaults if missing
    local h = mod.prefs.hud
    if not h then
        h = { x = 0, y = 0, scale = 1.0, opacity = 255 }
        mod.prefs.hud = h
    end
    return h
end

function mod.prefs_set_hud(key, val)
    local h = mod.prefs_get_hud()
    if h[key] ~= val then
        h[key] = val
        mod._prefs_mark_dirty()
    end
end
