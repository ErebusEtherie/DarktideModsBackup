-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_archetypes.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Localize = Localize

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function item_allows_archetype(item, archetype_name, archetype)
    if type(item) ~= "table" or type(archetype_name) ~= "string" or type(archetype) ~= "table" then
        return false
    end

    local item_archetypes = item.archetypes
    if type(item_archetypes) == "table" and next(item_archetypes) ~= nil and not table.contains(item_archetypes, archetype_name) then
        return false
    end

    local item_breeds = item.breeds
    return type(item_breeds) ~= "table" or next(item_breeds) == nil or
        type(archetype.breed) == "string" and table.contains(item_breeds, archetype.breed)
end

local function item_eligible_archetype_count(item, archetypes)
    local count = 0

    if type(item) ~= "table" or type(archetypes) ~= "table" then
        return count
    end

    for archetype_name, archetype in pairs(archetypes) do
        if item_allows_archetype(item, archetype_name, archetype) then
            count = count + 1
        end
    end

    return count
end

-- Reads the bytecode string and search for specific archetype/breed tokens. C functions return false automatically.
local function action_condition_func_mentions_archetype(action, archetype_name)
    local action_condition_func = type(action) == "table" and action.action_condition_func

    if type(action_condition_func) ~= "function" or type(archetype_name) ~= "string" or not string.dump then
        return false
    end

    local debug_getinfo = debug and debug.getinfo
    if debug_getinfo then
        local info = debug_getinfo(action_condition_func, "S")
        if info and info.what == "C" then
            return false
        end
    end

    local dumped_func = string.dump(action_condition_func)

    return string.find(dumped_func, "archetype", 1, true) ~= nil and
        string.find(dumped_func, "name", 1, true) ~= nil and
        string.find(dumped_func, archetype_name, 1, true) ~= nil
end

local function action_requires_archetype(action_name, action, archetype_name, actions, chain_source_names)
    local action_name_matches = mod.action_name_has_token(action_name, archetype_name)

    if action_name_matches and action_condition_func_mentions_archetype(action, archetype_name) then
        return true
    end

    local source_action_names = chain_source_names and chain_source_names[action_name]
    if not source_action_names then
        return false
    end

    local has_source = false
    for source_action_name in pairs(source_action_names) do
        local source_action = actions and actions[source_action_name]

        if not action_condition_func_mentions_archetype(source_action, archetype_name) or
            (not action_name_matches and not mod.action_name_has_token(source_action_name, archetype_name)) then
            return false
        end

        has_source = true
    end

    return has_source
end

-- ============================================================================
-- EXPORTED FUNCTIONS
-- ============================================================================

function mod.add_archetype_action_name_suffixes(community_action_names, weapon_template, actions, item)
    local archetypes = mod:original_require("scripts/settings/archetype/archetypes")

    if type(actions) ~= "table" or type(archetypes) ~= "table" or item_eligible_archetype_count(item, archetypes) < 2 then
        return
    end

    local chain_source_names = mod.direct_chain_source_names(actions)

    for action_name, action in pairs(actions) do
        if type(action) == "table" then
            local required_archetype

            for archetype_name, archetype in pairs(archetypes) do
                if item_allows_archetype(item, archetype_name, archetype) and
                    action_requires_archetype(action_name, action, archetype_name, actions, chain_source_names) then
                    -- If multiple archetypes are valid, cancel out specific tagging
                    if required_archetype then
                        required_archetype = false
                        break
                    end

                    required_archetype = archetype
                end
            end

            local archetype_localization_key = type(required_archetype) == "table" and required_archetype.archetype_name

            if type(archetype_localization_key) == "string" then
                local display_name = mod.action_display_name(action_name, community_action_names, weapon_template)

                community_action_names[action_name] = display_name .. "•" .. Localize(archetype_localization_key)
            end
        end
    end
end
