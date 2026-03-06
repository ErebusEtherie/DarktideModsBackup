-- File: scripts/mods/SimpleBuffFilter/runtime/traits.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end
--[[
traits.lua – resolver for weapon trait buffs.
Returns the group ("melee"|"ranged") and localization key if the buff matches a trait.
]]

-- Depends on:
--   • runtime/context.lua         (mod.tbf_ctx.*)
--   • runtime/buff_introspect.lua (mod.tbf_buff.*)

local MasterItems = require("scripts/backend/master_items")
local WeaponTraitTemplates = require("scripts/settings/equipment/weapon_traits/weapon_trait_templates")

mod.tbf_traits = mod.tbf_traits or {}

-- ----------------------------------------------------------------------------
-- Localization helpers
-- ----------------------------------------------------------------------------

local function try_localize(key)
    if not key then return nil end
    local val = Localize(key)
    if type(val) ~= "string" then return nil end
    if val:sub(1, 1) == "<" and val:sub(-1) == ">" then return nil end
    return val
end

-- ----------------------------------------------------------------------------
-- Template name normalization
-- ----------------------------------------------------------------------------

local function canonical_template_key(name)
    if not name then return nil end
    return name:gsub("_child$", ""):gsub("_parent$", "")
end

local function base_from_template(tname)
    if not tname then return nil end
    local base = tname
        :gsub("^weapon_trait_bespoke_.-_p%d+_?m?%d*_", "")
        :gsub("^weapon_trait_bespoke_.-_%d+_", "")
        :gsub("^weapon_trait_bespoke_", "")
        :gsub("^weapon_trait_", "")
        :gsub("_parent$", "")
        :gsub("_child$", "")
        :gsub("_buff$", "")
    return base ~= "" and base or nil
end

local function guess_loc_from_template(tname, category)
    local base = base_from_template(tname); if not base then return nil end

    local cand = {
        ("loc_trait_bespoke_%s"):format(base),
        ("loc_trait_%s"):format(base),
        ("loc_trait_%s_display_name"):format(base),
        ("loc_trait_bespoke_%s_desc"):format(base)
    }

    if category then
        table.insert(cand, ("loc_trait_%s_%s_display_name"):format(category, base))
    end

    if base:find("_based_on_", 1, true) then
        local alt = base:gsub("_based_on_", "_on_")
        table.insert(cand, ("loc_trait_bespoke_%s"):format(alt))
    end

    for _, key in ipairs(cand) do
        if try_localize(key) then return key end
    end

    return base
end

-- ----------------------------------------------------------------------------
-- Per-buff memo cache
-- ----------------------------------------------------------------------------
local function _cache_for(buff)
    local c = rawget(buff, "_tbf_trait_cache")
    if not c then
        c = {}
        rawset(buff, "_tbf_trait_cache", c)
    end
    return c
end

-- ----------------------------------------------------------------------------
-- Resolution from a live buff (memoized)
-- ----------------------------------------------------------------------------

function mod.tbf_traits.from_buff(buff)
    local tname = mod.tbf_buff.template_name(buff)
    if not (tname and tname:find("weapon_trait_", 1, true)) then
        return nil, nil, nil
    end

    local cache = _cache_for(buff)
    if cache.trait_loc_key ~= nil or cache.trait_category ~= nil then
        local loc_key  = (cache.trait_loc_key ~= false) and cache.trait_loc_key or nil
        local category = (cache.trait_category ~= false) and cache.trait_category or nil
        return nil, category, loc_key
    end

    -- 1. AUTHORITATIVE LOOKUP
    local found_display_name
    local found_category
    local found_trait_id

    -- Get Buff Details
    local buff_template = mod.tbf_buff.template_from(buff)
    local buff_icon = buff_template and buff_template.hud_icon

    -- [FIX] Check override data for icons (tiered traits often put the specific icon here)
    if not buff_icon and buff._template_override_data then
        buff_icon = buff._template_override_data.hud_icon
    end

    local slots_to_check = { "slot_primary", "slot_secondary" }

    for _, slot_name in ipairs(slots_to_check) do
        if found_display_name then break end

        local weapon_item = mod.tbf_ctx.equipped_item_in_slot(slot_name)
        if weapon_item and weapon_item.traits then
            local category = mod.tbf_ctx.weapon_category_from_slot(slot_name)

            for i = 1, #weapon_item.traits do
                local trait_data = weapon_item.traits[i]
                local full_id = trait_data and trait_data.id

                if type(full_id) == "string" then
                    local trait_item = MasterItems.get_item(full_id)
                    if trait_item then
                        local match = false
                        local trait_icon = trait_item.icon

                        -- STRATEGY A: ICON MATCH (Primary)
                        if buff_icon and trait_icon and buff_icon == trait_icon then
                            match = true
                        end

                        -- STRATEGY B: NAME MATCH (Secondary)
                        if not match and trait_item.trait then
                            local trait_template_name = trait_item.trait

                            if (trait_template_name == tname) or (trait_template_name .. "_parent" == tname) then
                                match = true
                            else
                                local template = WeaponTraitTemplates[trait_template_name]
                                if template and template.buffs then
                                    if template.buffs[tname] then
                                        match = true
                                    else
                                        for buff_key, _ in pairs(template.buffs) do
                                            local clean_buff_key = buff_key:gsub("_parent$", ""):gsub("_child$", "")
                                            local clean_tname = tname:gsub("_parent$", ""):gsub("_child$", "")
                                            if clean_buff_key == clean_tname then
                                                match = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if match then
                            found_trait_id = full_id
                            found_display_name = trait_item.display_name
                            found_category = category
                            break
                        end
                    end
                end
            end
        end
    end

    if found_display_name and found_category then
        cache.trait_category = found_category
        cache.trait_loc_key  = found_display_name
        return found_trait_id, found_category, found_display_name
    end

    -- 2. FALLBACK LOOKUP
    local ctx = rawget(buff, "_template_context")
    local slot = ctx and ctx.item_slot_name
    local category = slot and mod.tbf_ctx.weapon_category_from_slot(slot)
    local guessed_loc = guess_loc_from_template(tname, category)

    if guessed_loc then
        cache.trait_category = category or false
        cache.trait_loc_key  = guessed_loc
        return nil, category, guessed_loc
    end

    cache.trait_category = false
    cache.trait_loc_key  = false
    return nil, nil, nil
end

function mod.tbf_traits.resolve(buff)
    local _, category, loc_key = mod.tbf_traits.from_buff(buff)

    local tname = mod.tbf_buff.template_name(buff)
    if not (tname and tname:match("^weapon_trait_")) then
        return nil, nil
    end

    if category and loc_key then
        return category, loc_key
    end

    return nil, nil
end
