-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_sprint_tech.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Localize = Localize

local SPRINT_TECH_TEXT_COLOR = mod.WAD_SPRINT_TECH_TEXT_COLOR
local SPRINT_TECH_GLYPH = mod.WAD_SPRINT_TECH_GLYPH
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET
local SPRINT_TECH_START_MODIFIER_THRESHOLD = 1.25
local SPRINT_TECH_SUSTAINED_PEAK_MODIFIER_THRESHOLD = 1.3
local SPRINT_TECH_WINDUP_MAX_HOLD_MODIFIER_THRESHOLD = 1.2

local function action_sprint_heavy_windup_sources(action_name, actions, chain_source_names)
    local source_action_names = chain_source_names and chain_source_names[action_name]
    local sources = {}

    if not actions or not source_action_names then
        return sources
    end

    for source_action_name in pairs(source_action_names) do
        local source_action = actions[source_action_name]
        local allowed_chain_actions = source_action and source_action.allowed_chain_actions

        if source_action and source_action.kind == "windup" and source_action.allowed_during_sprint == true and
            mod.chain_data_has_action_name(allowed_chain_actions and allowed_chain_actions.heavy_attack,
                action_name) then
            sources[#sources + 1] = source_action
        end
    end

    return sources
end

local function chain_data_has_allowed_sprint_windup(chain_data, actions)
    if type(chain_data) ~= "table" or not actions then
        return false
    end

    if type(chain_data.action_name) == "string" then
        local chained_action = actions[chain_data.action_name]

        return chained_action and chained_action.kind == "windup" and chained_action.allowed_during_sprint == true
    end

    for i = 1, #chain_data do
        local child_chain_data = chain_data[i]

        if type(child_chain_data) == "table" and type(child_chain_data.action_name) == "string" then
            local chained_action = actions[child_chain_data.action_name]

            if chained_action and chained_action.kind == "windup" and chained_action.allowed_during_sprint == true then
                return true
            end
        end
    end

    return false
end

local function action_chains_to_allowed_sprint_windup(action, actions)
    local allowed_chain_actions = action and action.allowed_chain_actions

    return chain_data_has_allowed_sprint_windup(allowed_chain_actions and allowed_chain_actions.start_attack, actions)
end

local function sprint_tech_peak_modifier(movement_curve)
    if type(movement_curve) ~= "table" or type(movement_curve.start_modifier) ~= "number" then
        return nil
    end

    local peak_modifier = movement_curve.start_modifier

    for i = 1, #movement_curve do
        local curve_point = movement_curve[i]
        local modifier = type(curve_point) == "table" and curve_point.modifier

        if type(modifier) == "number" and modifier > peak_modifier then
            peak_modifier = modifier
        end
    end

    return peak_modifier
end

local function sprint_tech_max_hold_modifier(movement_curve)
    if type(movement_curve) ~= "table" then
        return nil
    end

    local max_t = nil
    local max_hold_modifier = nil

    for i = 1, #movement_curve do
        local curve_point = movement_curve[i]
        local modifier = type(curve_point) == "table" and curve_point.modifier
        local t = type(curve_point) == "table" and curve_point.t

        if type(modifier) == "number" and type(t) == "number" and
            (max_t == nil or t > max_t or t == max_t and modifier > max_hold_modifier) then
            max_t = t
            max_hold_modifier = modifier
        end
    end

    return max_hold_modifier
end

local function action_has_sprint_tech_curve(action)
    if type(action) ~= "table" or action.kind ~= "sweep" or action.allowed_during_sprint ~= true then
        return false
    end

    local movement_curve = action.action_movement_curve
    local start_modifier = type(movement_curve) == "table" and movement_curve.start_modifier
    local peak_modifier = sprint_tech_peak_modifier(movement_curve)

    return type(start_modifier) == "number" and type(peak_modifier) == "number" and
        start_modifier >= SPRINT_TECH_START_MODIFIER_THRESHOLD and
        peak_modifier >= SPRINT_TECH_SUSTAINED_PEAK_MODIFIER_THRESHOLD
end

local function action_has_sprint_tech_windup_curve(source_action)
    if type(source_action) ~= "table" or source_action.kind ~= "windup" or
        source_action.allowed_during_sprint ~= true then
        return false
    end

    local max_hold_modifier = sprint_tech_max_hold_modifier(source_action.action_movement_curve)

    return type(max_hold_modifier) == "number" and
        max_hold_modifier >= SPRINT_TECH_WINDUP_MAX_HOLD_MODIFIER_THRESHOLD
end

local function action_has_sprint_tech_source_windup(action_name, actions, chain_source_names)
    local source_actions = action_sprint_heavy_windup_sources(action_name, actions, chain_source_names)

    for i = 1, #source_actions do
        if action_has_sprint_tech_windup_curve(source_actions[i]) then
            return true
        end
    end

    return false
end

local function action_has_sprint_heavy_windup_source(action_name, actions, chain_source_names)
    return #action_sprint_heavy_windup_sources(action_name, actions, chain_source_names) > 0
end

local function action_has_sprint_tech(action_name, action, actions, chain_source_names)
    if type(action) ~= "table" or action.kind ~= "sweep" or action.allowed_during_sprint ~= true or
        not action_chains_to_allowed_sprint_windup(action, actions) or
        not action_has_sprint_heavy_windup_source(action_name, actions, chain_source_names) then
        return false
    end

    return action_has_sprint_tech_curve(action) or
        action_has_sprint_tech_source_windup(action_name, actions, chain_source_names)
end

local function format_sprint_tech_text()
    return string.format("%s%s %s%s", SPRINT_TECH_TEXT_COLOR, SPRINT_TECH_GLYPH,
        Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_SPRINT_SPEED), RICH_TEXT_RESET)
end

function mod.add_sprint_tech_to_damage_text(damage_text, action_name, action, actions, chain_source_names)
    if not action_has_sprint_tech(action_name, action, actions, chain_source_names) then
        return damage_text or ""
    end

    local sprint_tech_text = format_sprint_tech_text()

    if not damage_text or damage_text == "" then
        return sprint_tech_text
    end

    local line_break_start, line_break_end = string.find(damage_text, "\n", 1, true)

    if not line_break_start then
        return damage_text .. "  " .. sprint_tech_text
    end

    return string.sub(damage_text, 1, line_break_start - 1) .. "  " .. sprint_tech_text ..
        string.sub(damage_text, line_break_end)
end
