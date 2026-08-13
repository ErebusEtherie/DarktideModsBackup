-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_chains.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Localize = Localize

local SPECIAL_TAB_DUPLICATE_ACTION_KINDS = {
    block = true,
    push = true,
}

local WINDUP_ATTACK_CHAIN_NAMES = {
    "light_attack",
    "heavy_attack",
    "light_attack_special",
    "heavy_attack_special",
}

local function chain_display_action_name(action_name, weapon_context)
    local action_composites = weapon_context and weapon_context.action_composites
    local composite_action_name = action_composites and action_composites[action_name]

    return type(composite_action_name) == "string" and composite_action_name or action_name
end

local function action_name_is_composite_representative(action_name, weapon_context)
    local action_composites = weapon_context and weapon_context.action_composites

    return type(action_composites and action_composites[action_name]) == "table"
end

local function for_each_chain_action(chain_name, chain_data, callback_func)
    local chain_action_count = type(chain_data) == "table" and #chain_data or 0

    if chain_action_count > 0 then
        for i = 1, chain_action_count do
            local chain_action = chain_data[i]

            if type(chain_action) == "table" then
                callback_func(chain_action.action_name, chain_action.chain_time)
            end
        end

        return
    end

    local action_name = type(chain_data) == "table" and chain_data.action_name or chain_name
    local chain_time = type(chain_data) == "table" and chain_data.chain_time

    callback_func(action_name, chain_time)
end

local function chain_action_matches_requested_filter(action_name, action, actions, weapon_context)
    if not action or action.kind == "dummy" then
        return false
    end

    local has_special_actions = weapon_context and weapon_context.has_special_actions

    if has_special_actions and SPECIAL_TAB_DUPLICATE_ACTION_KINDS[action.kind] then
        return true
    end

    local action_filter = weapon_context and weapon_context.action_filter
    local special_active_windup_action_names = weapon_context and
        weapon_context.special_active_windup_action_names

    if has_special_actions and special_active_windup_action_names and
        special_active_windup_action_names[action_name] then
        return action_filter == mod.WAD_ACTION_FILTER_SPECIAL
    end

    return mod.action_matches_filter(action_name, action, action_filter,
        weapon_context and weapon_context.special_state_action_names,
        weapon_context and weapon_context.special_activation_chain_action_names, has_special_actions, actions)
end

function mod.add_chain_target_action_name(chain_target_action_names, actions, action_name)
    if action_name and actions[action_name] then
        chain_target_action_names[action_name] = true
    end
end

function mod.add_chain_target_action_names(chain_target_action_names, actions, chain_name, chain_data)
    if type(chain_data) ~= "table" then
        mod.add_chain_target_action_name(chain_target_action_names, actions, chain_name)

        return
    end

    local chain_action_count = #chain_data

    if chain_action_count > 0 then
        for i = 1, chain_action_count do
            local chain_action = chain_data[i]
            local action_name = type(chain_action) == "table" and chain_action.action_name

            mod.add_chain_target_action_name(chain_target_action_names, actions, action_name)
        end

        return
    end

    mod.add_chain_target_action_name(chain_target_action_names, actions, chain_data.action_name or chain_name)
end

function mod.direct_chain_source_names(actions)
    local chain_source_names = {}

    if not actions then
        return chain_source_names
    end

    for source_action_name, source_action in pairs(actions) do
        local allowed_chain_actions = type(source_action) == "table" and source_action.allowed_chain_actions

        if allowed_chain_actions then
            local chain_target_action_names = {}

            for chain_name, chain_data in pairs(allowed_chain_actions) do
                mod.add_chain_target_action_names(chain_target_action_names, actions, chain_name, chain_data)
            end

            for target_action_name in pairs(chain_target_action_names) do
                chain_source_names[target_action_name] = chain_source_names[target_action_name] or {}
                chain_source_names[target_action_name][source_action_name] = true
            end
        end
    end

    return chain_source_names
end

local function resolved_transition_key(transition)
    return table.concat({
        transition.chain_name or "",
        transition.windup_action_name or "",
        transition.action_name or "",
    }, "\31")
end

local function add_resolved_transition(transitions_by_action_name, action_name, transition_time,
                                       transition_time_is_lerp, chain_name, windup_action_name)
    if type(action_name) ~= "string" then
        return
    end

    local transition = {
        action_name = action_name,
        chain_name = chain_name,
        transition_time = transition_time,
        transition_time_is_lerp = transition_time_is_lerp == true,
        windup_action_name = windup_action_name,
    }
    local existing_transition = transitions_by_action_name[action_name]

    if existing_transition then
        local existing_time = existing_transition.transition_time
        local new_time_is_number = type(transition_time) == "number"
        local existing_time_is_number = type(existing_time) == "number"

        if existing_time_is_number and
            (not new_time_is_number or transition_time > existing_time) then
            return
        end

        if new_time_is_number and existing_time_is_number and transition_time == existing_time and
            resolved_transition_key(transition) >= resolved_transition_key(existing_transition) then
            return
        end

        if not new_time_is_number and not existing_time_is_number and
            resolved_transition_key(transition) >= resolved_transition_key(existing_transition) then
            return
        end
    end

    transitions_by_action_name[action_name] = transition
end

local function add_windup_attack_transitions(transitions_by_action_name, source_chain_name, previous_time,
                                             previous_time_is_lerp, windup_action_name, windup_action, actions,
                                             weapon_template, weapon_tweak_templates)
    local windup_chain_actions = windup_action and windup_action.allowed_chain_actions

    if not windup_chain_actions then
        return
    end

    for i = 1, #WINDUP_ATTACK_CHAIN_NAMES do
        local attack_chain_name = WINDUP_ATTACK_CHAIN_NAMES[i]
        local attack_chain_data = windup_chain_actions[attack_chain_name]

        if attack_chain_data then
            for_each_chain_action(attack_chain_name, attack_chain_data, function(action_name, chain_time)
                if action_name and actions[action_name] then
                    local scaled_time, scaled_time_is_lerp = mod.scaled_chain_time(windup_action, chain_time,
                        weapon_template, weapon_tweak_templates, windup_action_name)
                    local total_time, total_time_is_lerp = mod.add_chain_times(previous_time, scaled_time,
                        previous_time_is_lerp, scaled_time_is_lerp)

                    add_resolved_transition(transitions_by_action_name, action_name, total_time,
                        total_time_is_lerp, source_chain_name, windup_action_name)
                end
            end)
        end
    end
end

local function add_chain_data_transitions(transitions_by_action_name, source_action_name, source_action,
                                          chain_name, chain_data, actions, weapon_template,
                                          weapon_tweak_templates)
    for_each_chain_action(chain_name, chain_data, function(action_name, chain_time)
        local chained_action = action_name and actions[action_name]

        if not chained_action then
            return
        end

        local scaled_time, scaled_time_is_lerp = mod.scaled_chain_time(source_action, chain_time,
            weapon_template, weapon_tweak_templates, source_action_name)

        if chained_action.kind == "windup" then
            add_windup_attack_transitions(transitions_by_action_name, chain_name, scaled_time,
                scaled_time_is_lerp, action_name, chained_action, actions, weapon_template,
                weapon_tweak_templates)

            return
        end

        add_resolved_transition(transitions_by_action_name, action_name, scaled_time,
            scaled_time_is_lerp, chain_name)
    end)
end

local function sorted_chain_names(allowed_chain_actions)
    local chain_names = {}

    for chain_name in pairs(allowed_chain_actions) do
        chain_names[#chain_names + 1] = chain_name
    end

    table.sort(chain_names)

    return chain_names
end

local function sorted_resolved_transitions(transitions_by_action_name, transition_buffer)
    local action_names = {}

    for action_name in pairs(transitions_by_action_name) do
        action_names[#action_names + 1] = action_name
    end

    table.sort(action_names)

    for i = 1, #action_names do
        transition_buffer[i] = transitions_by_action_name[action_names[i]]
    end

    return #action_names
end

function mod.resolved_chain_transitions(source_action_name, actions, weapon_template, weapon_tweak_templates,
                                        transition_buffer, requested_chain_name, requested_chain_data,
                                        source_action)
    transition_buffer = transition_buffer or {}
    table.clear_array(transition_buffer, #transition_buffer)

    if type(actions) ~= "table" then
        return 0, transition_buffer
    end

    source_action = source_action or
        type(source_action_name) == "string" and actions[source_action_name]

    if type(source_action) ~= "table" then
        return 0, transition_buffer
    end

    local allowed_chain_actions = source_action.allowed_chain_actions

    if type(allowed_chain_actions) ~= "table" then
        return 0, transition_buffer
    end

    local transitions_by_action_name = {}

    if type(requested_chain_name) == "string" then
        local chain_data = requested_chain_data

        if chain_data == nil then
            chain_data = allowed_chain_actions[requested_chain_name]
        end

        add_chain_data_transitions(transitions_by_action_name, source_action_name, source_action,
            requested_chain_name, chain_data, actions, weapon_template, weapon_tweak_templates)
    else
        local chain_names = sorted_chain_names(allowed_chain_actions)

        for i = 1, #chain_names do
            local chain_name = chain_names[i]

            add_chain_data_transitions(transitions_by_action_name, source_action_name, source_action,
                chain_name, allowed_chain_actions[chain_name], actions, weapon_template,
                weapon_tweak_templates)
        end
    end

    return sorted_resolved_transitions(transitions_by_action_name, transition_buffer), transition_buffer
end

function mod.chain_action_display_text(action_name, display_action_name, actions, community_action_names,
                                       previous_time, previous_time_is_lerp, weapon_template,
                                       weapon_tweak_templates, weapon_context)
    local display_text = mod.action_display_name(display_action_name, community_action_names, weapon_template)
    local action = actions and actions[action_name]
    local total_time = mod.action_total_time(action, previous_time, previous_time_is_lerp, weapon_template,
        weapon_tweak_templates, action_name)

    if not total_time and type(previous_time) == "number" and
        action_name_is_composite_representative(display_action_name, weapon_context) then
        local transition_time = mod.format_time(previous_time)

        if transition_time then
            total_time = previous_time_is_lerp and mod.format_lerp_value_text(transition_time) or transition_time
        end
    end

    if total_time then
        display_text = display_text .. " (" .. total_time .. ")"
    end

    return display_text
end

function mod.add_chain_action_name(action_names, action_name_lookup, action_name, actions, community_action_names,
                                   previous_time, previous_time_is_lerp, weapon_template, weapon_tweak_templates,
                                   weapon_context)
    if not action_name then
        return
    end

    local display_action_name = chain_display_action_name(action_name, weapon_context)

    if action_name_lookup[display_action_name] then
        return
    end

    local action = actions and actions[action_name]

    if not chain_action_matches_requested_filter(action_name, action, actions, weapon_context) then
        return
    end

    action_names[#action_names + 1] = mod.chain_action_display_text(action_name, display_action_name, actions,
        community_action_names, previous_time, previous_time_is_lerp, weapon_template, weapon_tweak_templates,
        weapon_context)
    action_name_lookup[display_action_name] = true
end

function mod.add_resolved_chain_action(action_names, action_name_lookup, source_action, chain_name, chain_data,
                                       actions, community_action_names, weapon_template, weapon_tweak_templates,
                                       action_names_by_action, weapon_context)
    local source_action_name = action_names_by_action and action_names_by_action[source_action]
    local transitions = {}
    local num_transitions = mod.resolved_chain_transitions(source_action_name, actions, weapon_template,
        weapon_tweak_templates, transitions, chain_name, chain_data, source_action)
    local chain_name_is_excluded = mod.EXCLUDED_CHAIN_ACTION_NAMES[chain_name]

    for i = 1, num_transitions do
        local transition = transitions[i]
        local transition_action = actions and actions[transition.action_name]
        local is_special_action_sweep = chain_name == "special_action" and
            transition_action and transition_action.kind == "sweep"

        if not chain_name_is_excluded or is_special_action_sweep or
            mod.action_should_use_special_display_name(transition.action_name, transition_action, actions,
                weapon_template) then
            mod.add_chain_action_name(action_names, action_name_lookup, transition.action_name, actions,
                community_action_names, transition.transition_time, transition.transition_time_is_lerp,
                weapon_template, weapon_tweak_templates, weapon_context)
        end
    end
end

function mod.action_chain_text(action, actions, community_action_names)
    local allowed_chain_actions = action.allowed_chain_actions

    if not allowed_chain_actions then
        return ""
    end

    local action_names = {}
    local action_name_lookup = {}
    local weapon_context = mod.ACTIONS_WEAPON_CONTEXTS[actions]
    local weapon_template = weapon_context and weapon_context.weapon_template
    local weapon_tweak_templates = weapon_context and weapon_context.weapon_tweak_templates
    local action_names_by_action = weapon_context and weapon_context.action_names_by_action

    for chain_name, chain_data in pairs(allowed_chain_actions) do
        mod.add_resolved_chain_action(action_names, action_name_lookup, action, chain_name, chain_data, actions,
            community_action_names, weapon_template, weapon_tweak_templates, action_names_by_action,
            weapon_context)
    end

    table.sort(action_names)

    if #action_names == 0 then
        return ""
    end

    local text = Localize(mod.WAD_LOC.CHAIN_LIGHT) .. ": " .. table.concat(action_names, ", ")

    if mod.visible_text_length(text) > mod.MAX_ACTION_CHAIN_TEXT_LENGTH then
        text = mod.truncate_rich_text(text, mod.MAX_ACTION_CHAIN_TEXT_LENGTH - 3) .. "..."
    end

    return text
end
