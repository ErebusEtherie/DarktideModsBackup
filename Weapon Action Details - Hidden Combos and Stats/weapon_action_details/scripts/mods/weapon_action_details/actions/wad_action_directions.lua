-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_directions.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Localize = Localize
local DARK_GREEN = "{#color(40,40,40)}"
local RESET = "{#reset()}"

local function get_direction_tokens(val)
    local res = {}

    if type(val) == "string" and val ~= "" then
        for t in string.gmatch(string.lower(val), "[^_]+") do
            if t == "stab" or t == "thrust" or t == "push" then
                res.thrust = true
            elseif t == "up" or t == "down" or t == "left" or t == "right" or t == "cross" then
                res[t] = true
            end
        end
    end

    return res
end

local function get_localized_direction(key)
    if key == "up" then return Localize(mod.WAD_LOC.ALIAS_VIEW_NAVIGATE_UP) end
    if key == "down" then return Localize(mod.WAD_LOC.ALIAS_VIEW_NAVIGATE_DOWN) end
    if key == "left" then return Localize(mod.WAD_LOC.ALIAS_VIEW_NAVIGATE_LEFT) end
    if key == "right" then return Localize(mod.WAD_LOC.ALIAS_VIEW_NAVIGATE_RIGHT) end
    if key == "thrust" then return Localize(mod.WAD_LOC.TRAIT_BESPOKE_POWER_BONUS_BASED_ON_CHARGE_TIME) end

    if key == "cross" then
        return Localize(mod.WAD_LOC.ALIAS_VIEW_NAVIGATE_LEFT) ..
            "•" .. Localize(mod.WAD_LOC.ALIAS_VIEW_NAVIGATE_RIGHT)
    end

    return ""
end

local SORT_ORDER = {
    thrust = 1,
    up = 2,
    down = 3,
    left = 4,
    right = 5,
    cross = 6,
}

function mod.action_attack_direction_ranks(action)
    if type(action) ~= "table" then
        return nil
    end

    local override_tokens = get_direction_tokens(action.attack_direction_override)
    local anim_tokens = get_direction_tokens(action.anim_event)
    local p3_tokens = get_direction_tokens(action.anim_event_3p)

    local ranks = {
        up = 0,
        down = 0,
        left = 0,
        right = 0,
        cross = 0,
        thrust = 0,
    }

    for _, token_set in ipairs({
        override_tokens,
        anim_tokens,
        p3_tokens,
    }) do
        for key in pairs(token_set) do
            ranks[key] = ranks[key] + 1
        end
    end

    if not anim_tokens.thrust then
        local thrust_bonus = (override_tokens.thrust and 1 or 0) +
            (p3_tokens.thrust and 1 or 0)

        if thrust_bonus > 0 then
            if anim_tokens.up then
                ranks.up = ranks.up + thrust_bonus
            end

            if anim_tokens.down then
                ranks.down = ranks.down + thrust_bonus
            end
        end
    end

    return ranks
end

function mod.action_attack_direction(action)
    local ranks = mod.action_attack_direction_ranks(action)

    if not ranks then
        return nil
    end

    local valid_items = {}

    for key, rank in pairs(ranks) do
        if rank > 0 then
            valid_items[#valid_items + 1] = {
                key = key,
                rank = rank,
            }
        end
    end

    if #valid_items == 0 then
        return nil
    end

    table.sort(valid_items, function(a, b)
        if a.rank == b.rank then
            return SORT_ORDER[a.key] < SORT_ORDER[b.key]
        end

        return a.rank > b.rank
    end)

    local top_rank = valid_items[1].rank
    local parts = {}

    if ranks.cross > 0 then
        parts[#parts + 1] = "X"
    end

    for i = 1, #valid_items do
        local item = valid_items[i]
        local text = get_localized_direction(item.key)

        if item.rank < top_rank then
            text = DARK_GREEN .. text .. RESET
        end

        parts[#parts + 1] = text
    end

    return "(" .. table.concat(parts, "•") .. ")"
end
