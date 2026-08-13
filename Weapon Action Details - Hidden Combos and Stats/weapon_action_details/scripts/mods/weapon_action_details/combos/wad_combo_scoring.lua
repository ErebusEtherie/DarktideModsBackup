-- File: weapon_action_details/scripts/mods/weapon_action_details/combos/wad_combo_scoring.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")

local ARMOR_TYPES = ArmorSettings and ArmorSettings.types or {}

mod.SCORE_EPSILON = 0.000001
mod.WAD_COMBO_OBJECTIVE_SUPER_ARMOR_DAMAGE = "super_armor_damage"
mod.WAD_COMBO_OBJECTIVE_ARMORED_CLEAVE = "armored_cleave"

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function positive_number(value)
    return type(value) == "number" and value > 0 and value or 0
end

local function armor_value(values_by_armor, value_type, armor_type)
    local values = values_by_armor and values_by_armor[value_type]
    local value = values and values[armor_type]

    return type(value) == "number" and value or 0
end

local function optional_armor_value(values_by_armor, value_type, armor_type)
    local values = values_by_armor and values_by_armor[value_type]
    local value = values and values[armor_type]

    return type(value) == "number" and value or nil
end

local function combo_target_armor_type(objective)
    if objective == mod.WAD_COMBO_OBJECTIVE_SUPER_ARMOR_DAMAGE then
        return ARMOR_TYPES.super_armor
    elseif objective == mod.WAD_COMBO_OBJECTIVE_ARMORED_CLEAVE then
        return ARMOR_TYPES.armored
    end

    return nil
end

local function action_horizontal_direction_score(action)
    if type(action) ~= "table" or action.kind ~= "sweep" or
        type(mod.action_attack_direction_ranks) ~= "function" then
        return 0
    end

    local direction_ranks = mod.action_attack_direction_ranks(action)

    if type(direction_ranks) ~= "table" then
        return 0
    end

    return math.max(
        positive_number(direction_ranks.left),
        positive_number(direction_ranks.right)
    )
end

local function action_is_sticky(action, use_special_damage_profile)
    if type(mod.selected_hit_stickyness_settings) ~= "function" then
        return false
    end

    return mod.selected_hit_stickyness_settings(action, use_special_damage_profile) ~= nil
end

local function action_uses_special_damage_profile(action, special_active)
    return special_active == true or action and
        (
            action.activate_special_on_required_ammo == true or
            action.activate_special_during_sweep == true or
            action.toggle_special_on_during_sweep == true
        )
end

-- ============================================================================
-- SCORING EVALUATION
-- ============================================================================

function mod.action_combo_stats(action_name, action, special_active, damage_profile_lerp_values, objective)
    if type(action) ~= "table" then
        return nil, false
    end

    local target_armor_type = combo_target_armor_type(objective)

    if not target_armor_type then
        return nil, false
    end

    local is_sweep = action.kind == "sweep"
    local use_special_damage_profile = action_uses_special_damage_profile(action, special_active)

    if objective == mod.WAD_COMBO_OBJECTIVE_ARMORED_CLEAVE and
        is_sweep and
        action_is_sticky(action, use_special_damage_profile) then
        return nil, true
    end

    local values_by_armor = mod.action_damage_values_by_armor(
        action,
        action_name,
        damage_profile_lerp_values,
        use_special_damage_profile
    )

    local damage = armor_value(values_by_armor, "attack", target_armor_type)
    local impact = armor_value(values_by_armor, "impact", target_armor_type)
    local cleave = armor_value(values_by_armor, "cleave", target_armor_type)
    local crit_damage = optional_armor_value(values_by_armor, "crit_attack", target_armor_type)
    local crit_impact = optional_armor_value(values_by_armor, "crit_impact", target_armor_type)
    local direction_score = objective == mod.WAD_COMBO_OBJECTIVE_ARMORED_CLEAVE and
        action_horizontal_direction_score(action) or 0

    local objective_value
    local displayed_value

    if objective == mod.WAD_COMBO_OBJECTIVE_SUPER_ARMOR_DAMAGE then
        objective_value = damage
        displayed_value = damage
    else
        objective_value = is_sweep and cleave * direction_score or 0
        displayed_value = is_sweep and cleave or 0
    end

    return {
        action_name = action_name,
        cleave = cleave,
        crit_damage = crit_damage,
        crit_damage_modifier = damage > mod.SCORE_EPSILON and crit_damage and crit_damage / damage or nil,
        crit_impact = crit_impact,
        crit_impact_modifier = impact > mod.SCORE_EPSILON and crit_impact and crit_impact / impact or nil,
        damage = damage,
        direction_score = direction_score,
        displayed_value = displayed_value,
        impact = impact,
        is_sweep = is_sweep,
        objective_value = objective_value,
        special_active = special_active == true,
        use_special_damage_profile = use_special_damage_profile,
    }, false
end

function mod.evaluate_cycle(path, path_transition_times, path_transition_lerp_flags, closing_edge, stats_by_node_key)
    local num_actions = #path
    local duration = 0
    local objective_total = 0
    local displayed_total = 0
    local scoring_sweep_count = 0
    local node_keys = {}
    local transition_times = {}
    local transition_time_is_lerp = {}

    for i = 1, num_actions do
        local node_key = path[i]
        local stats = stats_by_node_key[node_key]
        local transition_time = i < num_actions and path_transition_times[i] or closing_edge.transition_time
        local time_is_lerp = i < num_actions and path_transition_lerp_flags[i] or closing_edge.transition_time_is_lerp

        duration = duration + transition_time
        objective_total = objective_total + (stats and stats.objective_value or 0)
        displayed_total = displayed_total + (stats and stats.displayed_value or 0)
        scoring_sweep_count = scoring_sweep_count + (stats and stats.is_sweep and stats.objective_value > 0 and 1 or 0)

        node_keys[i] = node_key
        transition_times[i] = transition_time
        transition_time_is_lerp[i] = time_is_lerp == true
    end

    if duration <= mod.SCORE_EPSILON or objective_total <= 0 or scoring_sweep_count == 0 then
        return nil
    end

    return {
        displayed_rate = displayed_total / duration,
        duration = duration,
        key = table.concat(node_keys, "\31"),
        node_keys = node_keys,
        num_actions = num_actions,
        score = objective_total / duration,
        transition_time_is_lerp = transition_time_is_lerp,
        transition_times = transition_times,
    }
end

function mod.combo_is_better(candidate, current_best)
    if not current_best then
        return true
    end

    if candidate.score > current_best.score + mod.SCORE_EPSILON then
        return true
    elseif candidate.score < current_best.score - mod.SCORE_EPSILON then
        return false
    end

    if candidate.displayed_rate > current_best.displayed_rate + mod.SCORE_EPSILON then
        return true
    elseif candidate.displayed_rate < current_best.displayed_rate - mod.SCORE_EPSILON then
        return false
    end

    if candidate.duration and current_best.duration then
        if candidate.duration < current_best.duration - mod.SCORE_EPSILON then
            return true
        elseif candidate.duration > current_best.duration + mod.SCORE_EPSILON then
            return false
        end
    end

    if candidate.setup_duration and current_best.setup_duration then
        if candidate.setup_duration < current_best.setup_duration - mod.SCORE_EPSILON then
            return true
        elseif candidate.setup_duration > current_best.setup_duration + mod.SCORE_EPSILON then
            return false
        end
    end

    if candidate.cycle_duration and current_best.cycle_duration then
        if candidate.cycle_duration < current_best.cycle_duration - mod.SCORE_EPSILON then
            return true
        elseif candidate.cycle_duration > current_best.cycle_duration + mod.SCORE_EPSILON then
            return false
        end
    end

    local candidate_num_actions = candidate.num_actions or (candidate.rows and #candidate.rows)
    local current_best_num_actions = current_best.num_actions or (current_best.rows and #current_best.rows)

    if candidate_num_actions ~= current_best_num_actions then
        return candidate_num_actions < current_best_num_actions
    end

    return candidate.key and current_best.key and candidate.key < current_best.key or false
end
