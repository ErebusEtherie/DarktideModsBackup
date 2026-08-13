-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_movement.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Localize = Localize

local function action_condition_func_has_tokens(action, required_tokens)
    local action_condition_func = type(action) == "table" and action.action_condition_func

    if type(action_condition_func) ~= "function" or not string.dump then
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

    for i = 1, #required_tokens do
        if string.find(dumped_func, required_tokens[i], 1, true) == nil then
            return false
        end
    end

    return true
end

local function action_condition_func_requires_sliding(action)
    return action_condition_func_has_tokens(action, {
        "movement_state_component",
        "sliding",
    })
end

local function action_condition_func_requires_sprinting(action)
    return action_condition_func_has_tokens(action, {
        "sprint_character_state_component",
        "is_sprinting",
    })
end

local function action_condition_func_requires_dodging(action)
    return action_condition_func_has_tokens(action, {
        "movement_state_component",
        "is_dodging",
    })
end

local function action_is_wield(action)
    local kind = type(action) == "table" and action.kind

    return kind == "wield" or kind == "ranged_wield"
end

local function action_has_only_condition_windup_chain_sources(action_name, actions, chain_source_names,
                                                              action_condition_func)
    local source_action_names = chain_source_names and chain_source_names[action_name]

    if not source_action_names then
        return false
    end

    for source_action_name in pairs(source_action_names) do
        local source_action = actions and actions[source_action_name]

        if not source_action or source_action.kind ~= "windup" or not action_condition_func(source_action) then
            return false
        end
    end

    return true
end

local function windup_has_only_wield_chain_sources(action_name, actions, chain_source_names)
    local source_action_names = chain_source_names and chain_source_names[action_name]

    if not source_action_names then
        return false
    end

    local has_source = false

    for source_action_name in pairs(source_action_names) do
        has_source = true

        if not action_is_wield(actions and actions[source_action_name]) then
            return false
        end
    end

    return has_source
end

local function condition_windup_chain_action_names(actions, action_condition_func, chain_source_names)
    local names = {}

    if not actions then
        return names
    end

    chain_source_names = chain_source_names or mod.direct_chain_source_names(actions)

    for action_name, action in pairs(actions) do
        if type(action) == "table" and action_has_only_condition_windup_chain_sources(action_name, actions,
                chain_source_names, action_condition_func) then
            names[action_name] = true
        end
    end

    return names
end

function mod.movement_condition_action_names(actions, chain_source_names)
    return {
        sliding = condition_windup_chain_action_names(actions, action_condition_func_requires_sliding,
            chain_source_names),
        sprinting = condition_windup_chain_action_names(actions, action_condition_func_requires_sprinting,
            chain_source_names),
    }
end

function mod.sweep_movement_requirement_prefix(action_name, actions, chain_source_names)
    if type(action_name) ~= "string" or type(actions) ~= "table" then
        return nil
    end

    chain_source_names = chain_source_names or mod.direct_chain_source_names(actions)

    local source_action_names = chain_source_names[action_name]

    if not source_action_names then
        return nil
    end

    local allows_wielding = false
    local allows_sprinting = false
    local allows_sliding = false
    local allows_dodging = false

    for source_action_name in pairs(source_action_names) do
        local source_action = actions[source_action_name]
        local source_allows_wielding = action_is_wield(source_action)
        local source_allows_sprinting = false
        local source_allows_sliding = false
        local source_allows_dodging = false

        if not source_allows_wielding then
            if type(source_action) ~= "table" or source_action.kind ~= "windup" then
                return nil
            end

            source_allows_wielding = windup_has_only_wield_chain_sources(source_action_name, actions,
                chain_source_names)
            source_allows_sprinting = action_condition_func_requires_sprinting(source_action)
            source_allows_sliding = action_condition_func_requires_sliding(source_action)
            source_allows_dodging = action_condition_func_requires_dodging(source_action)
        end

        if not source_allows_wielding and not source_allows_sprinting and not source_allows_sliding and
            not source_allows_dodging then
            return nil
        end

        allows_wielding = allows_wielding or source_allows_wielding
        allows_sprinting = allows_sprinting or source_allows_sprinting
        allows_sliding = allows_sliding or source_allows_sliding
        allows_dodging = allows_dodging or source_allows_dodging
    end

    local prefix

    if allows_wielding then
        prefix = Localize(mod.WAD_LOC.INGAME_WIELD_3_4_GAMEPAD)
    end

    if allows_sprinting then
        prefix = prefix and prefix .. "/" .. Localize(mod.WAD_LOC.INGAME_SPRINT) or
            Localize(mod.WAD_LOC.INGAME_SPRINT)
    end

    if allows_sliding then
        prefix = prefix and prefix .. "/" .. Localize(mod.WAD_LOC.INGAME_SLIDE) or
            Localize(mod.WAD_LOC.INGAME_SLIDE)
    end

    if allows_dodging then
        prefix = prefix and prefix .. "/" .. Localize(mod.WAD_LOC.INGAME_DODGE) or
            Localize(mod.WAD_LOC.INGAME_DODGE)
    end

    return prefix and prefix .. "•" or nil
end

function mod.action_movement_requirement_prefix(action_name, action, movement_condition_names)
    if type(action) == "table" and action.kind == "sweep" then
        return nil
    end

    local requires_sliding = action_condition_func_requires_sliding(action) or
        movement_condition_names and movement_condition_names.sliding and
        movement_condition_names.sliding[action_name]
    local requires_sprinting = action_condition_func_requires_sprinting(action) or
        movement_condition_names and movement_condition_names.sprinting and
        movement_condition_names.sprinting[action_name]

    if not requires_sliding and not requires_sprinting then
        return nil
    end

    local slide_prefix = Localize(mod.WAD_LOC.INGAME_SLIDE) .. "•"
    local sprint_prefix = Localize(mod.WAD_LOC.INGAME_SPRINT) .. "•"

    if requires_sliding and requires_sprinting then
        if string.find(action_name, "slide", 1, true) then
            return slide_prefix
        elseif string.find(action_name, "sprint", 1, true) then
            return sprint_prefix
        end

        return slide_prefix .. sprint_prefix
    end

    return requires_sliding and slide_prefix or sprint_prefix
end

function mod.special_active_windup_chain_action_names(actions, chain_source_names)
    return condition_windup_chain_action_names(actions, mod.action_condition_func_returns_special_active,
        chain_source_names)
end
