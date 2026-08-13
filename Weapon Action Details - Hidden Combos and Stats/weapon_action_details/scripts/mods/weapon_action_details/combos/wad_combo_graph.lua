-- File: weapon_action_details/scripts/mods/weapon_action_details/combos/wad_combo_graph.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local COMBO_CHAIN_RESOLUTION_OPTIONS = {
    include_route_metadata = true,
    preserve_duplicate_targets = true,
}
local NODE_STATE_SEPARATOR = "\30"

-- Exported to allow cycle path constructors to regenerate keys
function mod.combo_node_key(action_name, special_active)
    return action_name .. NODE_STATE_SEPARATOR .. (special_active and "1" or "0")
end

local function action_special_state_requirement(action_name, action, actions)
    if type(mod.action_special_state_requirement) == "function" then
        return mod.action_special_state_requirement(action_name, action, actions)
    end

    if type(mod.action_condition_func_returns_special_active) == "function" and
        mod.action_condition_func_returns_special_active(action) then
        return true
    end

    if type(mod.action_only_available_in_special_state) == "function" and
        mod.action_only_available_in_special_state(action_name, action, actions) then
        return true
    end

    return nil
end

local function action_special_state_after(action_name, action, special_active, actions)
    if type(mod.action_special_state_after) == "function" then
        local state_after = mod.action_special_state_after(action_name, action, special_active, actions)
        if type(state_after) == "boolean" then
            return state_after
        end
    end

    local kind = action and action.kind
    local is_special_activation = type(mod.action_is_special_activation) == "function" and
        mod.action_is_special_activation(action_name, action)

    if is_special_activation then
        if kind == "activate_special" then
            special_active = true
        elseif kind == "toggle_special" or kind == "toggle_special_with_block" then
            special_active = not special_active
        end
    end

    if action and action.activate_special_during_sweep then
        special_active = false
    elseif action and action.toggle_special_on_during_sweep then
        special_active = true
    elseif action and action.toggle_special_off_during_sweep then
        special_active = false
    end

    return special_active
end

local function action_can_start_in_special_state(action_name, action, actions, special_active)
    local requirement = action_special_state_requirement(action_name, action, actions)
    return requirement == nil or requirement == special_active
end

local function movement_prefixed_action_names(actions)
    local movement_action_names = {}
    if type(actions) ~= "table" then
        return movement_action_names
    end

    local chain_source_names = type(mod.direct_chain_source_names) == "function" and
        mod.direct_chain_source_names(actions) or {}
    local movement_condition_names = type(mod.movement_condition_action_names) == "function" and
        mod.movement_condition_action_names(actions, chain_source_names) or {}

    for action_name, action in pairs(actions) do
        if type(action) == "table" then
            local prefix
            if action.kind == "sweep" and type(mod.sweep_movement_requirement_prefix) == "function" then
                prefix = mod.sweep_movement_requirement_prefix(action_name, actions, chain_source_names)
            elseif type(mod.action_movement_requirement_prefix) == "function" then
                prefix = mod.action_movement_requirement_prefix(action_name, action, movement_condition_names)
            end

            if type(prefix) == "string" and prefix ~= "" then
                movement_action_names[action_name] = true
            end
        end
    end

    return movement_action_names
end

local function action_is_traversable(action_name, action, movement_action_names)
    if type(action_name) ~= "string" or type(action) ~= "table" then
        return false
    end
    if movement_action_names[action_name] then
        return false
    end
    return action.kind ~= "windup"
end

local function transition_is_movement_prefixed(transition)
    if type(transition) ~= "table" then
        return false
    end
    if transition.movement_prefixed == true then
        return true
    end
    local movement_prefix = transition.movement_prefix
    return type(movement_prefix) == "string" and movement_prefix ~= ""
end

local function resolved_transition_time(source_action_name, source_action, transition, weapon_template,
                                        weapon_tweak_templates)
    local transition_time = transition and transition.transition_time
    local transition_time_is_lerp = transition and transition.transition_time_is_lerp == true

    if type(transition_time) == "number" and transition_time >= 0 then
        return transition_time, transition_time_is_lerp
    end

    local fallback_time, fallback_time_is_lerp = mod.action_scaled_total_time(
        source_action, weapon_template, weapon_tweak_templates, source_action_name
    )

    if type(fallback_time) == "number" and fallback_time >= 0 then
        return fallback_time, fallback_time_is_lerp == true
    end

    return nil, false
end

local function transition_route_key(transition)
    if type(transition) ~= "table" then
        return ""
    end
    return table.concat({
        transition.chain_name or "",
        transition.windup_action_name or "",
        transition.action_name or "",
        transition.route_key or "",
    }, "\31")
end

local function add_shortest_graph_edge(edge_by_target_node_key, target_node_key, transition_time, transition_time_is_lerp,
                                       transition)
    local existing_edge = edge_by_target_node_key[target_node_key]
    local route_key = transition_route_key(transition)

    if existing_edge then
        if existing_edge.transition_time < transition_time then
            return
        end
        if existing_edge.transition_time == transition_time and existing_edge.route_key <= route_key then
            return
        end
    end

    edge_by_target_node_key[target_node_key] = {
        chain_name = transition and transition.chain_name,
        route_key = route_key,
        target_node_key = target_node_key,
        transition_time = transition_time,
        transition_time_is_lerp = transition_time_is_lerp == true,
        windup_action_name = transition and transition.windup_action_name,
    }
end

local function sorted_graph_edges(edge_by_target_node_key)
    local edges = {}
    for _, edge in pairs(edge_by_target_node_key) do
        edges[#edges + 1] = edge
    end
    table.sort(edges, function(a, b)
        if a.target_node_key == b.target_node_key then
            if a.transition_time == b.transition_time then
                return a.route_key < b.route_key
            end
            return a.transition_time < b.transition_time
        end
        return a.target_node_key < b.target_node_key
    end)
    return edges
end

local function add_graph_node(nodes_by_key, stats_by_node_key, queue, node_key, action_name, special_active, actions,
                              damage_profile_lerp_values, objective)
    if nodes_by_key[node_key] then
        return true
    end

    local action = actions[action_name]
    local stats, excluded = mod.action_combo_stats(action_name, action, special_active, damage_profile_lerp_values,
        objective)

    if excluded then
        return false
    end

    nodes_by_key[node_key] = {
        action_name = action_name,
        special_active = special_active == true,
    }
    stats_by_node_key[node_key] = stats
    queue[#queue + 1] = node_key

    return true
end

local function add_root_nodes(root_node_lookup, nodes_by_key, stats_by_node_key, queue, root_action_names, actions,
                              movement_action_names, damage_profile_lerp_values, objective)
    local num_roots = type(root_action_names) == "table" and #root_action_names or 0

    for i = 1, num_roots do
        local action_name = root_action_names[i]
        local action = type(action_name) == "string" and actions[action_name]

        if action_is_traversable(action_name, action, movement_action_names) and
            action_can_start_in_special_state(action_name, action, actions, false) then
            local node_key = mod.combo_node_key(action_name, false)

            if add_graph_node(nodes_by_key, stats_by_node_key, queue, node_key, action_name, false, actions, damage_profile_lerp_values, objective) then
                root_node_lookup[node_key] = true
            end
        end
    end
end

-- Exported Graph Builder
function mod.build_combo_graph(actions, root_action_names, weapon_template, weapon_tweak_templates,
                               damage_profile_lerp_values, objective)
    local graph = {}
    local nodes_by_key = {}
    local stats_by_node_key = {}
    local root_node_lookup = {}
    local queue = {}
    local queue_index = 1
    local movement_action_names = movement_prefixed_action_names(actions)
    local transition_buffer = {}

    if type(mod.resolved_chain_transitions) ~= "function" then
        return graph, nodes_by_key, stats_by_node_key, root_node_lookup
    end

    add_root_nodes(root_node_lookup, nodes_by_key, stats_by_node_key, queue, root_action_names, actions,
        movement_action_names, damage_profile_lerp_values, objective)

    while queue_index <= #queue do
        local source_node_key = queue[queue_index]
        local source_node = nodes_by_key[source_node_key]
        local source_action_name = source_node.action_name
        local source_action = actions[source_action_name]
        local special_active_after = action_special_state_after(source_action_name, source_action,
            source_node.special_active, actions)
        local edge_by_target_node_key = {}

        queue_index = queue_index + 1

        local num_transitions = mod.resolved_chain_transitions(
            source_action_name,
            actions,
            weapon_template,
            weapon_tweak_templates,
            transition_buffer,
            nil,
            nil,
            source_action,
            COMBO_CHAIN_RESOLUTION_OPTIONS
        )

        for i = 1, num_transitions or 0 do
            local transition = transition_buffer[i]
            local target_action_name = transition and transition.action_name
            local target_action = target_action_name and actions[target_action_name]

            if action_is_traversable(target_action_name, target_action, movement_action_names) and
                not transition_is_movement_prefixed(transition) and
                action_can_start_in_special_state(target_action_name, target_action, actions, special_active_after) then
                local transition_time, transition_time_is_lerp = resolved_transition_time(
                    source_action_name, source_action, transition, weapon_template, weapon_tweak_templates
                )

                if type(transition_time) == "number" and transition_time >= 0 then
                    local target_node_key = mod.combo_node_key(target_action_name, special_active_after)

                    if add_graph_node(nodes_by_key, stats_by_node_key, queue, target_node_key, target_action_name, special_active_after, actions, damage_profile_lerp_values, objective) then
                        add_shortest_graph_edge(edge_by_target_node_key, target_node_key, transition_time,
                            transition_time_is_lerp, transition)
                    end
                end
            end
        end

        graph[source_node_key] = sorted_graph_edges(edge_by_target_node_key)
    end

    return graph, nodes_by_key, stats_by_node_key, root_node_lookup
end
