-- File: weapon_action_details/scripts/mods/weapon_action_details/combos/wad_combo_cycles.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local DEFAULT_ROOT_ACTION_NAMES = {
    "action_wield",
}
local DEFAULT_OMITTED_ROOT_ACTION_NAMES = {
    action_wield = true,
}

-- ============================================================================
-- GRAPH TRAVERSAL & PATHFINDING
-- ============================================================================

local function reverse_graph(graph)
    local reverse_edges = {}

    for source_node_key, edges in pairs(graph) do
        reverse_edges[source_node_key] = reverse_edges[source_node_key] or {}

        for i = 1, #edges do
            local target_node_key = edges[i].target_node_key
            local sources = reverse_edges[target_node_key]

            if not sources then
                sources = {}
                reverse_edges[target_node_key] = sources
            end

            sources[#sources + 1] = source_node_key
        end
    end

    return reverse_edges
end

local function nodes_that_can_reach_scoring_sweep(graph, stats_by_node_key)
    local reverse_edges = reverse_graph(graph)
    local eligible = {}
    local queue = {}
    local queue_index = 1

    for node_key, stats in pairs(stats_by_node_key) do
        if stats and stats.is_sweep and stats.objective_value > 0 then
            eligible[node_key] = true
            queue[#queue + 1] = node_key
        end
    end

    while queue_index <= #queue do
        local node_key = queue[queue_index]
        local sources = reverse_edges[node_key]

        queue_index = queue_index + 1

        for i = 1, sources and #sources or 0 do
            local source_node_key = sources[i]

            if not eligible[source_node_key] then
                eligible[source_node_key] = true
                queue[#queue + 1] = source_node_key
            end
        end
    end

    return eligible
end

local function sorted_cycle_node_keys(graph, root_node_lookup, eligible_cycle_nodes)
    local node_keys = {}

    for node_key in pairs(graph) do
        if not root_node_lookup[node_key] and eligible_cycle_nodes[node_key] then
            node_keys[#node_keys + 1] = node_key
        end
    end

    table.sort(node_keys)
    return node_keys
end

local function find_best_cycle(graph, root_node_lookup, eligible_cycle_nodes, stats_by_node_key)
    local ordered_node_keys = sorted_cycle_node_keys(graph, root_node_lookup, eligible_cycle_nodes)
    local node_order = {}
    local visited = {}
    local path = {}
    local path_transition_times = {}
    local path_transition_lerp_flags = {}
    local best_cycle

    for i = 1, #ordered_node_keys do
        node_order[ordered_node_keys[i]] = i
    end

    local function visit(current_node_key, start_node_key, start_order)
        local edges = graph[current_node_key]

        for i = 1, edges and #edges or 0 do
            local edge = edges[i]
            local target_node_key = edge.target_node_key
            local target_order = node_order[target_node_key]

            if target_node_key == start_node_key then
                local candidate = mod.evaluate_cycle(
                    path,
                    path_transition_times,
                    path_transition_lerp_flags,
                    edge,
                    stats_by_node_key
                )

                if candidate and mod.combo_is_better(candidate, best_cycle) then
                    best_cycle = candidate
                end
            elseif target_order and target_order >= start_order and not visited[target_node_key] then
                local path_index = #path

                path_transition_times[path_index] = edge.transition_time
                path_transition_lerp_flags[path_index] = edge.transition_time_is_lerp == true
                path[path_index + 1] = target_node_key
                visited[target_node_key] = true

                visit(target_node_key, start_node_key, start_order)

                visited[target_node_key] = nil
                path[path_index + 1] = nil
                path_transition_times[path_index] = nil
                path_transition_lerp_flags[path_index] = nil
            end
        end
    end

    for start_order = 1, #ordered_node_keys do
        local start_node_key = ordered_node_keys[start_order]

        path[1] = start_node_key
        visited[start_node_key] = true

        visit(start_node_key, start_node_key, start_order)

        visited[start_node_key] = nil
        path[1] = nil
    end

    return best_cycle
end

local function sorted_graph_node_keys(graph)
    local node_keys = {}
    for node_key in pairs(graph) do
        node_keys[#node_keys + 1] = node_key
    end
    table.sort(node_keys)
    return node_keys
end

local function shortest_paths_from_roots(graph, root_node_lookup)
    local node_keys = sorted_graph_node_keys(graph)
    local distances = {}
    local predecessor_node_keys = {}
    local predecessor_transition_times = {}
    local predecessor_transition_lerp_flags = {}
    local visited = {}

    for node_key in pairs(root_node_lookup) do
        if graph[node_key] then
            distances[node_key] = 0
        end
    end

    for _ = 1, #node_keys do
        local current_node_key
        local current_distance

        for i = 1, #node_keys do
            local node_key = node_keys[i]
            local distance = distances[node_key]

            if not visited[node_key] and type(distance) == "number" and
                (current_distance == nil or distance < current_distance or
                    distance == current_distance and node_key < current_node_key) then
                current_node_key = node_key
                current_distance = distance
            end
        end

        if not current_node_key then
            break
        end

        visited[current_node_key] = true

        local edges = graph[current_node_key]

        for i = 1, edges and #edges or 0 do
            local edge = edges[i]
            local target_node_key = edge.target_node_key
            local new_distance = current_distance + edge.transition_time
            local old_distance = distances[target_node_key]
            local old_predecessor = predecessor_node_keys[target_node_key]

            if old_distance == nil or new_distance < old_distance - mod.SCORE_EPSILON or
                (math.abs(new_distance - old_distance) <= mod.SCORE_EPSILON and
                    (not old_predecessor or current_node_key < old_predecessor)) then
                distances[target_node_key] = new_distance
                predecessor_node_keys[target_node_key] = current_node_key
                predecessor_transition_times[target_node_key] = edge.transition_time
                predecessor_transition_lerp_flags[target_node_key] = edge.transition_time_is_lerp == true
            end
        end
    end

    return distances, predecessor_node_keys, predecessor_transition_times, predecessor_transition_lerp_flags
end

local function best_cycle_entry_node(best_cycle, distances)
    local entry_node_key
    local entry_distance

    for i = 1, best_cycle.num_actions do
        local node_key = best_cycle.node_keys[i]
        local distance = distances[node_key]

        if type(distance) == "number" and
            (entry_distance == nil or distance < entry_distance or
                distance == entry_distance and node_key < entry_node_key) then
            entry_node_key = node_key
            entry_distance = distance
        end
    end

    return entry_node_key, entry_distance
end

local function reconstruct_setup_path(entry_node_key, predecessor_node_keys)
    local reverse_path = {}
    local node_key = entry_node_key

    while node_key do
        reverse_path[#reverse_path + 1] = node_key
        node_key = predecessor_node_keys[node_key]
    end

    local path = {}
    local num_reverse_nodes = #reverse_path

    for i = num_reverse_nodes, 1, -1 do
        path[num_reverse_nodes - i + 1] = reverse_path[i]
    end

    return path
end

local function rotated_cycle(best_cycle, entry_node_key)
    local entry_index

    for i = 1, best_cycle.num_actions do
        if best_cycle.node_keys[i] == entry_node_key then
            entry_index = i
            break
        end
    end

    if not entry_index then
        return nil
    end

    local node_keys = {}
    local transition_times = {}
    local transition_time_is_lerp = {}

    for i = 1, best_cycle.num_actions do
        local source_index = (entry_index + i - 2) % best_cycle.num_actions + 1

        node_keys[i] = best_cycle.node_keys[source_index]
        transition_times[i] = best_cycle.transition_times[source_index]
        transition_time_is_lerp[i] = best_cycle.transition_time_is_lerp[source_index]
    end

    return node_keys, transition_times, transition_time_is_lerp
end

local function append_combo_row(rows, node_key, transition_time, transition_time_is_lerp, is_loop, nodes_by_key,
                                stats_by_node_key)
    local node = nodes_by_key[node_key]
    local stats = stats_by_node_key[node_key]

    if not node or not stats then
        return
    end

    local damage_per_second = transition_time > mod.SCORE_EPSILON and stats.damage / transition_time or nil

    rows[#rows + 1] = {
        action_name = node.action_name,
        cleave = stats.cleave,
        crit_damage = stats.crit_damage,
        crit_damage_modifier = stats.crit_damage_modifier,
        crit_impact = stats.crit_impact,
        crit_impact_modifier = stats.crit_impact_modifier,
        damage = stats.damage,
        damage_per_second = damage_per_second,
        duration = transition_time,
        duration_is_lerp = transition_time_is_lerp == true,
        impact = stats.impact,
        is_loop = is_loop == true,
        is_sweep = stats.is_sweep,
        node_key = node_key,
        special_active = node.special_active,
        use_special_damage_profile = stats.use_special_damage_profile,
    }
end

local function build_combo_result(best_cycle, graph, root_node_lookup, omitted_root_action_names, nodes_by_key,
                                  stats_by_node_key, objective)
    local distances, predecessor_node_keys, predecessor_transition_times, predecessor_transition_lerp_flags =
        shortest_paths_from_roots(graph, root_node_lookup)

    local entry_node_key, setup_duration = best_cycle_entry_node(best_cycle, distances)

    if not entry_node_key then
        return nil
    end

    local setup_path = reconstruct_setup_path(entry_node_key, predecessor_node_keys)
    local cycle_node_keys, cycle_transition_times, cycle_transition_lerp_flags = rotated_cycle(best_cycle, entry_node_key)

    if not cycle_node_keys then
        return nil
    end

    local rows = {}
    local num_setup_nodes = #setup_path

    for i = 1, num_setup_nodes - 1 do
        local node_key = setup_path[i]
        local next_node_key = setup_path[i + 1]
        local node = nodes_by_key[node_key]
        local omitted = node and omitted_root_action_names and omitted_root_action_names[node.action_name]

        if node and not omitted then
            append_combo_row(
                rows,
                node_key,
                predecessor_transition_times[next_node_key],
                predecessor_transition_lerp_flags[next_node_key],
                false,
                nodes_by_key,
                stats_by_node_key
            )
        end
    end

    local loop_start_index = #rows + 1

    for i = 1, best_cycle.num_actions do
        append_combo_row(
            rows,
            cycle_node_keys[i],
            cycle_transition_times[i],
            cycle_transition_lerp_flags[i],
            true,
            nodes_by_key,
            stats_by_node_key
        )
    end

    if #rows == 0 then
        return nil
    end

    local entry_node = nodes_by_key[entry_node_key]

    return {
        cycle_duration = best_cycle.duration,
        displayed_rate = best_cycle.displayed_rate,
        entry_action_name = entry_node and entry_node.action_name,
        entry_node_key = entry_node_key,
        loop_start_index = loop_start_index,
        objective = objective,
        rows = rows,
        score = best_cycle.score,
        setup_duration = setup_duration or 0,
    }
end

-- ============================================================================
-- EXPORTED COMBO EVALUATORS
-- ============================================================================

function mod.best_action_combo(actions, action_data_by_name, root_action_names, omitted_root_action_names,
                               weapon_template, weapon_tweak_templates, damage_profile_lerp_values, objective)
    if type(actions) ~= "table" or type(mod.resolved_chain_transitions) ~= "function" then
        return nil
    end

    action_data_by_name = type(action_data_by_name) == "table" and action_data_by_name or {}
    root_action_names = root_action_names or DEFAULT_ROOT_ACTION_NAMES
    omitted_root_action_names = omitted_root_action_names or DEFAULT_OMITTED_ROOT_ACTION_NAMES

    local graph, nodes_by_key, stats_by_node_key, root_node_lookup = mod.build_combo_graph(
        actions,
        root_action_names,
        weapon_template,
        weapon_tweak_templates,
        damage_profile_lerp_values,
        objective
    )

    if next(root_node_lookup) == nil or next(graph) == nil then
        return nil
    end

    local eligible_cycle_nodes = nodes_that_can_reach_scoring_sweep(graph, stats_by_node_key)
    local best_cycle = find_best_cycle(graph, root_node_lookup, eligible_cycle_nodes, stats_by_node_key)

    if not best_cycle then
        return nil
    end

    local combo = build_combo_result(
        best_cycle,
        graph,
        root_node_lookup,
        omitted_root_action_names,
        nodes_by_key,
        stats_by_node_key,
        objective
    )

    if combo then
        combo.action_data_by_name = action_data_by_name
    end

    return combo
end

function mod.best_action_combo_for_contexts(actions, contexts, weapon_template, weapon_tweak_templates,
                                            damage_profile_lerp_values, objective)
    if type(contexts) ~= "table" then
        return nil
    end

    local best_combo

    for i = 1, #contexts do
        local context = contexts[i]

        if type(context) == "table" then
            local combo = mod.best_action_combo(
                actions,
                context.action_data_by_name,
                context.root_action_names,
                context.omitted_root_action_names,
                weapon_template,
                weapon_tweak_templates,
                damage_profile_lerp_values,
                objective
            )

            if combo and mod.combo_is_better(combo, best_combo) then
                combo.context_index = i
                best_combo = combo
            end
        end
    end

    return best_combo
end
