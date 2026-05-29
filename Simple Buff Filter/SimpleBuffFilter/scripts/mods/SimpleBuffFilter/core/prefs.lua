-- File: scripts/mods/SimpleBuffFilter/core/prefs.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end

--[[
prefs.lua – Simplified flat storage.

Structure:
  mod.prefs.buffs[id] = {
      group = "veteran"|"zealot"|"melee"|"misc"|"moods"|...,
      loc   = "loc_string_key",
      rule  = "allow"|"hide"|"only_in_psykhanium",
      bar   = 1|2|3
  }

Notes:
  • "id" may be a buff id, mood id, or screen-effect id.
  • Rules and bars are shared by (group + loc), not by loc alone.
  • This lets moods + screen effects share rules inside group == "moods",
    while buff-icon groups remain separate even if they use the same loc_* key.
  • mod.prefs.hud = {
      [1] = { x=0, y=0, scale=1.0, opacity=255 },
      [2] = { x=0, y=-65, scale=1.0, opacity=255 },
      [3] = { x=0, y=-130, scale=1.0, opacity=255 }
    }
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

local function _find_scoped_rule(prefs_entries, target_group, target_loc, ignore_id)
    if not target_group or not target_loc then
        return nil
    end

    for existing_id, existing in pairs(prefs_entries) do
        if existing_id ~= ignore_id and existing.group == target_group and existing.loc == target_loc then
            return existing.rule
        end
    end

    return nil
end

local function _find_scoped_bar(prefs_entries, target_group, target_loc, ignore_id)
    if not target_group or not target_loc then
        return nil
    end

    for existing_id, existing in pairs(prefs_entries) do
        if existing_id ~= ignore_id and existing.group == target_group and existing.loc == target_loc then
            return existing.bar
        end
    end

    return nil
end

local function _decode_loc_args(arg1, arg2, arg3)
    if arg3 ~= nil then
        return arg1, arg2, arg3
    end

    return nil, arg1, arg2
end

local function _init_default_hud()
    return {
        { x = 0, y = 0,    scale = 1.0, opacity = 255 },
        { x = 0, y = -65,  scale = 1.0, opacity = 255 },
        { x = 0, y = -130, scale = 1.0, opacity = 255 }
    }
end

-- Bootstrap
if not mod.prefs then
    local p = mod:get("prefs")
    if type(p) ~= "table" then p = {} end

    -- Hard reset ONLY if it's the ancient 1.0 per_archetype nested format
    if p.per_archetype then
        p = {
            buffs = {},
            hud   = _init_default_hud()
        }
    end

    p.buffs = p.buffs or {}

    -- Migrate HUD if it exists but is the old single-table format
    if p.hud and p.hud.x then
        local old_hud = p.hud
        p.hud = _init_default_hud()
        p.hud[1] = old_hud -- Preserve their old settings into Bar 1
    end

    -- Ensure HUD array is initialized if entirely missing
    if not p.hud or not p.hud[1] then
        p.hud = _init_default_hud()
    end

    -- Backward Compatibility: Assign bar 1 to any existing buffs that lack a bar assignment
    local needs_save = false
    for id, entry in pairs(p.buffs) do
        if entry.bar == nil then
            entry.bar = 1
            needs_save = true
        end
    end

    mod.prefs = p

    if needs_save then
        mod._prefs_mark_dirty()
    end
end

-- ===== Public API: Recording & Lookup =====

-- Record or update an entry discovered during gameplay.
-- Rules and Bars inherit only from other entries with the same (group + loc) scope.
function mod.prefs_record_buff(id, group, loc, default_rule, default_bar)
    if not (id and group and loc) then return end

    local p = mod.prefs.buffs
    local entry = p[id]

    if not entry then
        local inherited_rule = _find_scoped_rule(p, group, loc)
        local inherited_bar  = _find_scoped_bar(p, group, loc)

        p[id]                = {
            group = group,
            loc   = loc,
            rule  = inherited_rule or default_rule or "allow",
            bar   = inherited_bar or default_bar or 1
        }

        mod._prefs_mark_dirty()

        -- Trigger option rebuild if we found something new
        local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
        if Rebuilder and Rebuilder.rebuild_debounced then
            Rebuilder.rebuild_debounced()
        end
    else
        -- Update metadata if changed (e.g. better loc resolution found).
        -- If the entry moves into a scope that already has a rule/bar, adopt that scoped rule/bar.
        if entry.group ~= group or entry.loc ~= loc then
            local old_rule = entry.rule
            local old_bar  = entry.bar

            entry.group    = group
            entry.loc      = loc
            entry.rule     = _find_scoped_rule(p, group, loc, id) or old_rule or default_rule or "allow"
            entry.bar      = _find_scoped_bar(p, group, loc, id) or old_bar or default_bar or 1

            mod._prefs_mark_dirty()
        end
    end
end

-- Get rule for a specific discovered ID (fast lookup for HUD/gameplay hooks)
function mod.prefs_get_rule(id)
    local entry = mod.prefs.buffs[id]
    return entry and entry.rule or "allow"
end

-- Get bar for a specific discovered ID
function mod.prefs_get_bar(id)
    local entry = mod.prefs.buffs[id]
    return entry and entry.bar or 1
end

-- Get the shared rule for a loc.
function mod.prefs_get_rule_by_loc(arg1, arg2, arg3)
    local target_group, target_loc, default_rule = _decode_loc_args(arg1, arg2, arg3)
    local p = mod.prefs and mod.prefs.buffs or {}

    if not target_loc then
        return default_rule or "allow"
    end

    for _, entry in pairs(p) do
        local group_matches = (target_group == nil) or (entry.group == target_group)

        if group_matches and entry.loc == target_loc then
            return entry.rule or default_rule or "allow"
        end
    end

    return default_rule or "allow"
end

-- Get the shared bar for a loc.
function mod.prefs_get_bar_by_loc(arg1, arg2, arg3)
    local target_group, target_loc, default_bar = _decode_loc_args(arg1, arg2, arg3)
    local p = mod.prefs and mod.prefs.buffs or {}

    if not target_loc then
        return default_bar or 1
    end

    for _, entry in pairs(p) do
        local group_matches = (target_group == nil) or (entry.group == target_group)

        if group_matches and entry.loc == target_loc then
            return entry.bar or default_bar or 1
        end
    end

    return default_bar or 1
end

-- Update rule for all entries sharing a loc.
function mod.prefs_set_rule_by_loc(arg1, arg2, arg3)
    local target_group, target_loc, new_rule = _decode_loc_args(arg1, arg2, arg3)
    if not target_loc or not new_rule then return end

    local p = mod.prefs.buffs
    local changed = false

    for _, entry in pairs(p) do
        local group_matches = (target_group == nil) or (entry.group == target_group)

        if group_matches and entry.loc == target_loc and entry.rule ~= new_rule then
            entry.rule = new_rule
            changed = true
        end
    end

    if changed then
        mod._prefs_mark_dirty()
    end
end

-- Update bar for all entries sharing a loc.
function mod.prefs_set_bar_by_loc(arg1, arg2, arg3)
    local target_group, target_loc, new_bar = _decode_loc_args(arg1, arg2, arg3)
    if not target_loc or not new_bar then return end

    local p = mod.prefs.buffs
    local changed = false

    for _, entry in pairs(p) do
        local group_matches = (target_group == nil) or (entry.group == target_group)

        if group_matches and entry.loc == target_loc and entry.bar ~= new_bar then
            entry.bar = new_bar
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

function mod.prefs_get_hud(bar_index)
    bar_index = bar_index or 1
    local h = mod.prefs.hud and mod.prefs.hud[bar_index]
    if not h then
        h = { x = 0, y = 0, scale = 1.0, opacity = 255 }
        if mod.prefs.hud then
            mod.prefs.hud[bar_index] = h
        end
    end
    return h
end

function mod.prefs_set_hud(bar_index, key, val)
    bar_index = bar_index or 1
    local h = mod.prefs_get_hud(bar_index)
    if h[key] ~= val then
        h[key] = val
        mod._prefs_mark_dirty()
    end
end
