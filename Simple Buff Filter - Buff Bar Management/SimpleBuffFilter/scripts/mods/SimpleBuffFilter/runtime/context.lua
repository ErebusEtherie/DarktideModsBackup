-- File: scripts/mods/SimpleBuffFilter/runtime/context.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end
--[[
context.lua – session context (time source, local player, buff extension access). (Loaded early and used by other runtime files.)
]]
-- Shared, cross-file runtime context utilities
-- Exports a small, stable API on mod.tbf_ctx for:
--  • time & “dirty” window
--  • where-am-I (Psykhanium?)
--  • local player/profile
--  • unit extensions (buff / visual_loadout)
--  • equipped items
--  • slot → category mapping
--
-- Notes:
--  • Uses Managers.player:local_player_safe(1).
--  • No mod:get calls here (settings are cached elsewhere).

mod.tbf_ctx = mod.tbf_ctx or {}

-- ----- time/dirty ------------------------------------------------------------

function mod.tbf_ctx.now()
    local tm = Managers and Managers.time
    if tm then
        -- prefer gameplay clock
        if tm:has_timer("gameplay") then return tm:time("gameplay") end
        -- then UI clock
        if tm:has_timer("ui") then return tm:time("ui") end
        -- then main clock (menus often tick this)
        if tm:has_timer("main") then return tm:time("main") end
    end
    -- final fallback
    return os.clock()
end

-- Optional: brief per-frame re-eval burst after settings change
function mod._tbf_rules_mark_dirty(seconds)
    local dur = tonumber(seconds) or 0.5
    local now = mod.tbf_ctx.now()
    mod.__tbf_rules_dirty_until = math.max(mod.__tbf_rules_dirty_until or 0, now + dur)
end

-- ----- where am I? -----------------------------------------------------------

function mod.tbf_ctx.is_psykhanium()
    local gm = Managers.state and Managers.state.game_mode
    if not (gm and gm.game_mode_name) then return false end
    return gm:game_mode_name() == "shooting_range"
end

-- ----- local player/profile --------------------------------------------------

function mod.tbf_ctx.local_player()
    return Managers.player and Managers.player:local_player_safe(1) or nil
end

function mod.tbf_ctx.local_player_profile()
    local lp = mod.tbf_ctx.local_player()
    return lp and lp:profile() or nil
end

-- ----- unit extensions -------------------------------------------------------

-- Internals used to detect unit swaps and clear per-extension link maps.
mod.__tbf_prev_unit     = mod.__tbf_prev_unit or nil
mod.__tbf_prev_buff_ext = mod.__tbf_prev_buff_ext or nil

local function _maybe_clear_links_on_unit_change(current_unit, current_ext)
    -- Only run when the unit actually changes.
    if current_unit and current_unit ~= mod.__tbf_prev_unit then
        -- Clear links for the *new* extension so we start fresh this mission/character.
        if current_ext and mod._clear_parent_child_links_for then
            mod._clear_parent_child_links_for(current_ext)
        end

        -- Optionally clear any leftover links for the previous extension (defensive).
        if mod.__tbf_prev_buff_ext and mod._clear_parent_child_links_for then
            mod._clear_parent_child_links_for(mod.__tbf_prev_buff_ext)
        end

        mod.__tbf_prev_unit     = current_unit
        mod.__tbf_prev_buff_ext = current_ext
    end
end

function mod.tbf_ctx.buff_ext()
    local lp   = mod.tbf_ctx.local_player()
    local unit = lp and lp.player_unit
    if not (unit and ScriptUnit and ScriptUnit.has_extension and ScriptUnit.extension) then
        return nil
    end
    if not ScriptUnit.has_extension(unit, "buff_system") then
        return nil
    end

    local ext = ScriptUnit.extension(unit, "buff_system")
    if not ext then return nil end

    -- Ensure we clear parent↔child link maps whenever the unit flips.
    _maybe_clear_links_on_unit_change(unit, ext)

    return ext
end

function mod.tbf_ctx.visual_loadout_ext()
    local lp = mod.tbf_ctx.local_player()
    local unit = lp and lp.player_unit
    if not unit then return nil end
    if not (ScriptUnit and ScriptUnit.has_extension and ScriptUnit.extension) then return nil end
    if not ScriptUnit.has_extension(unit, "visual_loadout_system") then return nil end
    local ext = ScriptUnit.extension(unit, "visual_loadout_system")
    return ext or nil
end

-- ----- equipped items --------------------------------------------------------

local MasterItems = require("scripts/backend/master_items")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")

function mod.tbf_ctx.equipped_item_in_slot(slot_name)
    -- Use Profile Loadout directly (Most reliable source for traits)
    local profile = mod.tbf_ctx.local_player_profile()
    if profile and profile.loadout then
        local item = profile.loadout[slot_name]
        return item -- This is the master item instance with traits
    end
    return nil
end

-- ----- slot → category mapping ----------------------------------------------

local function _category_from_item(item)
    -- 1. Try Weapon Template Keywords (Most accurate)
    if item and item.weapon_template then
        local template = WeaponTemplates[item.weapon_template]
        if template and template.keywords then
            for i = 1, #template.keywords do
                if template.keywords[i] == "ranged" then
                    return "ranged"
                end
            end
            -- If it has a template but no "ranged" keyword, it is melee
            return "melee"
        end
    end

    -- 2. Fallback to Item Type string
    local t = item and item.item_type
    if type(t) == "string" then
        if t:find("RANGED", 1, true) then return "ranged" end
        if t:find("MELEE", 1, true) then return "melee" end
    end

    return nil
end

function mod.tbf_ctx.weapon_category_from_slot(slot_name)
    if not slot_name or slot_name == "" then return nil end

    -- Best: infer from actual equipped item
    local item = mod.tbf_ctx.equipped_item_in_slot(slot_name)
    local cat  = _category_from_item(item)
    if cat then return cat end

    -- Fallback: conventional mapping in Darktide builds
    if slot_name == "slot_primary" then return "melee" end
    if slot_name == "slot_secondary" then return "ranged" end

    -- Unknown/other slots: not a weapon
    return nil
end
