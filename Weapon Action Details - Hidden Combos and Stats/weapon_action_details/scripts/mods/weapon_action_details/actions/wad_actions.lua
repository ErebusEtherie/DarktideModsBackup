-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_actions.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local WeaponTemplate = mod:original_require("scripts/utilities/weapon/weapon_template")
local WeaponTweakTemplates = mod:original_require("scripts/extension_systems/weapon/utilities/weapon_tweak_templates")
local WeaponTweakTemplateSettings = mod:original_require(
    "scripts/settings/equipment/weapon_templates/weapon_tweak_template_settings")
local Localize = Localize

local template_types = WeaponTweakTemplateSettings and WeaponTweakTemplateSettings.template_types or {}

local SPECIAL_TAB_DUPLICATE_ACTION_KINDS = {
    block = true,
    push = true,
}

local CHARGE_START_ACTION_KINDS = {
    charge_ammo = true,
    overload_charge = true,
    overload_charge_position_finder = true,
    overload_charge_target_finder = true,
}

local CHARGE_LEVEL_EPSILON = 0.005

local FIXED_CHARGE_LEVELS_BY_WEAPON_TEMPLATE = {
    plasmagun_p1_m1 = {
        action_shoot = 0.516133333,
    },
}

local ACTION_KIND_SORT_GROUPS = {
    wield = 1,
    ranged_wield = 1,
    reload_state = 3,
    reload_shotgun = 3,
    aim = 4,
    unaim = 4,
    block_aiming = 4,
    block_unaim = 4,
}

local SPECIAL_TAB_SECOND_GROUP_LOCALIZATION_KEYS = {
    mod.WAD_LOC.UNLOCKED,
    mod.WAD_LOC.WEAPON_ACTION_TITLE_SPECIAL,
}

local EXCLUDED_ACTION_NAMES_BY_WEAPON_TEMPLATE = {
    galvanic_rifle_p1_m1 = {
        action_toggle_flashlight = true,
        action_toggle_flashlight_zoom = true,
    },
}

local ACTION_COMPOSITES_BY_WEAPON_TEMPLATE = {
    dual_stubpistols_p1_m1 = {
        action_special_shoot_right = {
            "action_special_twirl_right",
            "action_special_shoot_right",
            "action_special_twirl_left",
            "action_special_shoot_left",
        },
        action_special_twirl_right = "action_special_shoot_right",
        action_special_twirl_left = "action_special_shoot_right",
        action_special_shoot_left = "action_special_shoot_right",
    },
    shotpistol_shield_p1_m1 = {
        action_block = {
            "action_block",
            "action_block_from_bash",
            "action_block_from_shoot",
        },
        action_block_from_bash = "action_block",
        action_block_from_shoot = "action_block",
    },
}

local ACTION_START_NAMES_BY_WEAPON_TEMPLATE = {
    dual_stubpistols_p1_m1 = {
        action_special_shoot_right = "action_special_twirl_right",
    },
}

local ACTION_ALIAS_COMPOSITES = {
    action_toggle_flashlight = {
        "action_toggle_flashlight_zoom",
    },
}

local function action_matches_requested_filter(action_name, action, action_filter, special_state_action_names,
                                               special_activation_chain_action_names, has_special_actions,
                                               special_active_windup_action_names, actions)
    local is_special_filter = action_filter == mod.WAD_ACTION_FILTER_SPECIAL

    if has_special_actions and SPECIAL_TAB_DUPLICATE_ACTION_KINDS[action.kind] then
        return true
    end

    if has_special_actions and special_active_windup_action_names and special_active_windup_action_names[action_name] then
        return is_special_filter
    end

    return mod.action_matches_filter(action_name, action, action_filter, special_state_action_names,
        special_activation_chain_action_names, has_special_actions, actions)
end

local function add_unique_chain_action_name(action_names, action_name)
    if type(action_name) ~= "string" or action_name == "" then
        return
    end

    for i = 1, #action_names do
        if action_names[i] == action_name then
            return
        end
    end

    action_names[#action_names + 1] = action_name
end

local function chain_action_names(chain_data)
    local action_names = {}

    if type(chain_data) ~= "table" then
        return action_names
    end

    if type(chain_data.action_name) == "string" then
        add_unique_chain_action_name(action_names, chain_data.action_name)

        return action_names
    end

    for i = 1, #chain_data do
        local child_chain_data = chain_data[i]

        if type(child_chain_data) == "table" then
            add_unique_chain_action_name(action_names, child_chain_data.action_name)
        end
    end

    return action_names
end

local function unique_merged_action_pairs(candidate_start_names_by_action_name)
    local start_name_by_action_name = {}
    local action_name_by_start_name = {}

    for action_name, candidate_start_names in pairs(candidate_start_names_by_action_name) do
        local start_action_name
        local num_start_actions = 0

        for candidate_start_action_name in pairs(candidate_start_names) do
            num_start_actions = num_start_actions + 1
            start_action_name = candidate_start_action_name

            if num_start_actions > 1 then
                break
            end
        end

        if num_start_actions == 1 then
            start_name_by_action_name[action_name] = start_action_name
            action_name_by_start_name[start_action_name] = action_name
        end
    end

    return start_name_by_action_name, action_name_by_start_name
end

local function merged_special_action_pairs(actions)
    local candidate_start_names_by_activation_name = {}

    for start_action_name, start_action in pairs(actions) do
        if type(start_action) == "table" and start_action.kind == "block_windup" then
            local allowed_chain_actions = start_action.allowed_chain_actions
            local release_chain = allowed_chain_actions and allowed_chain_actions.special_action_release
            local activation_action_names = chain_action_names(release_chain)

            if #activation_action_names == 1 then
                local activation_action_name = activation_action_names[1]
                local activation_action = actions[activation_action_name]

                if type(activation_action) == "table" and activation_action.kind == "weapon_shout" then
                    local candidate_start_names =
                        candidate_start_names_by_activation_name[activation_action_name]

                    if not candidate_start_names then
                        candidate_start_names = {}
                        candidate_start_names_by_activation_name[activation_action_name] = candidate_start_names
                    end

                    candidate_start_names[start_action_name] = true
                end
            end
        end
    end

    return unique_merged_action_pairs(candidate_start_names_by_activation_name)
end

local function action_is_charge_release_attack(action)
    local kind = action and action.kind

    if type(kind) ~= "string" then
        return false
    end

    if string.find(kind, "shoot", 1, true) == 1 or kind == "chain_lightning" or kind == "flamer_gas" or
        kind == "trigger_explosion" then
        return true
    end

    return kind == "spawn_projectile" and action.use_charge == true
end

local function charge_release_action_names(start_action, actions)
    local release_action_names = {}
    local allowed_chain_actions = start_action and start_action.allowed_chain_actions

    if type(allowed_chain_actions) ~= "table" then
        return release_action_names
    end

    for _, chain_data in pairs(allowed_chain_actions) do
        local target_action_names = chain_action_names(chain_data)

        for i = 1, #target_action_names do
            local action_name = target_action_names[i]
            local action = actions[action_name]

            if action_is_charge_release_attack(action) then
                add_unique_chain_action_name(release_action_names, action_name)
            end
        end
    end

    return release_action_names
end

local function merged_charge_action_pairs(actions)
    local candidate_start_names_by_release_name = {}

    for start_action_name, start_action in pairs(actions) do
        if type(start_action) == "table" and CHARGE_START_ACTION_KINDS[start_action.kind] then
            local release_action_names = charge_release_action_names(start_action, actions)

            if #release_action_names == 1 then
                local release_action_name = release_action_names[1]
                local candidate_start_names = candidate_start_names_by_release_name[release_action_name]

                if not candidate_start_names then
                    candidate_start_names = {}
                    candidate_start_names_by_release_name[release_action_name] = candidate_start_names
                end

                candidate_start_names[start_action_name] = true
            end
        end
    end

    return unique_merged_action_pairs(candidate_start_names_by_release_name)
end

local function chain_data_time_for_action(chain_data, action_name)
    if type(chain_data) ~= "table" then
        return nil
    end

    if chain_data.action_name == action_name then
        local chain_time = mod.resolve_lerp_value(chain_data.chain_time)

        return type(chain_time) == "number" and math.max(chain_time, 0) or 0
    end

    local earliest_chain_time

    for i = 1, #chain_data do
        local child_chain_time = chain_data_time_for_action(chain_data[i], action_name)

        if type(child_chain_time) == "number" and
            (earliest_chain_time == nil or child_chain_time < earliest_chain_time) then
            earliest_chain_time = child_chain_time
        end
    end

    return earliest_chain_time
end

local function earliest_release_chain_time(charge_action, action_name)
    local allowed_chain_actions = charge_action and charge_action.allowed_chain_actions

    if type(allowed_chain_actions) ~= "table" or type(action_name) ~= "string" then
        return nil
    end

    local earliest_chain_time

    for _, chain_data in pairs(allowed_chain_actions) do
        local chain_time = chain_data_time_for_action(chain_data, action_name)

        if type(chain_time) == "number" and
            (earliest_chain_time == nil or chain_time < earliest_chain_time) then
            earliest_chain_time = chain_time
        end
    end

    if type(earliest_chain_time) ~= "number" then
        return nil
    end

    local minimum_hold_time = mod.resolve_lerp_value(charge_action.minimum_hold_time)

    if type(minimum_hold_time) == "number" then
        earliest_chain_time = math.max(earliest_chain_time, minimum_hold_time)
    end

    return earliest_chain_time
end

local function minimum_releasable_charge_level(action_name, charge_action, charge_template)
    local release_time = earliest_release_chain_time(charge_action, action_name)
    local charge_duration = mod.resolve_lerp_value(charge_template and charge_template.charge_duration)

    if type(release_time) ~= "number" or type(charge_duration) ~= "number" or charge_duration <= 0 then
        return nil
    end

    local charge_delay = mod.resolve_lerp_value(charge_template.charge_delay) or 0
    local template_min_charge = mod.resolve_lerp_value(charge_template.min_charge) or 0
    local charge_progress = math.clamp((release_time - math.max(charge_delay, 0)) / charge_duration, 0, 1)

    return template_min_charge + (1 - template_min_charge) * charge_progress
end

local function action_has_direct_variable_charge(action)
    if type(action) ~= "table" or not action.charge_template then
        return false
    end

    if CHARGE_START_ACTION_KINDS[action.kind] or action.use_charge == true then
        return true
    end

    local fire_configuration = action.fire_configuration

    return type(fire_configuration) == "table" and fire_configuration.use_charge == true
end

local function action_is_excluded(action_name, action, is_merged_charge_release)
    if action_name == "rapid_left" or is_merged_charge_release then
        return false
    end

    return type(action) == "table" and mod.EXCLUDED_ACTION_KINDS[action.kind] == true
end

function mod.action_fixed_charge_level(action_name, weapon_template)
    if type(action_name) ~= "string" then
        return nil
    end

    local weapon_template_name = weapon_template and weapon_template.name
    local weapon_fixed_charge_levels = type(weapon_template_name) == "string" and
        FIXED_CHARGE_LEVELS_BY_WEAPON_TEMPLATE[weapon_template_name]
    local charge_level = weapon_fixed_charge_levels and weapon_fixed_charge_levels[action_name]

    return type(charge_level) == "number" and charge_level or nil
end

function mod.resolved_action_charge_template(action_name, action, weapon_template, weapon_tweak_templates)
    if type(action) ~= "table" then
        return nil
    end

    local charge_template_type = template_types.charge
    local charge_templates = charge_template_type and weapon_tweak_templates and
        weapon_tweak_templates[charge_template_type]

    if type(charge_templates) == "table" and weapon_template and type(action_name) == "string" then
        local _, lerped_identifier = WeaponTweakTemplates.get_template_identifiers(weapon_template,
            charge_template_type, action_name)
        local charge_template = lerped_identifier and charge_templates[lerped_identifier]

        if type(charge_template) == "table" then
            return charge_template
        end
    end

    return mod.action_charge_template and mod.action_charge_template(action, weapon_tweak_templates) or nil
end

function mod.action_charge_level_bounds(action_name, action, charge_action_name, charge_action, weapon_template,
                                        weapon_tweak_templates)
    if type(action) ~= "table" then
        return nil, nil
    end

    local fixed_charge_level = mod.action_fixed_charge_level(action_name, weapon_template)

    if type(fixed_charge_level) == "number" then
        return fixed_charge_level, fixed_charge_level
    end

    local source_action = type(charge_action) == "table" and charge_action or action
    local source_action_name = type(charge_action_name) == "string" and charge_action_name or action_name
    local charge_template = mod.resolved_action_charge_template(source_action_name, source_action, weapon_template,
        weapon_tweak_templates)

    if type(charge_template) ~= "table" then
        return nil, nil
    end

    local template_min_charge = mod.resolve_lerp_value(charge_template.min_charge)
    local min_charge = type(template_min_charge) == "number" and template_min_charge or 0
    local required_charge_level = mod.resolve_lerp_value(action.required_charge_level)
    local source_required_charge_level = mod.resolve_lerp_value(source_action.required_charge_level)

    if type(required_charge_level) == "number" then
        min_charge = math.max(min_charge, required_charge_level)
    end

    if type(source_required_charge_level) == "number" then
        min_charge = math.max(min_charge, source_required_charge_level)
    end

    if source_action ~= action then
        local release_min_charge = minimum_releasable_charge_level(action_name, source_action, charge_template)

        if type(release_min_charge) == "number" then
            min_charge = math.max(min_charge, release_min_charge)
        end
    end

    local fully_charged_charge_level = mod.resolve_lerp_value(charge_template.fully_charged_charge_level)
    local max_charge = type(fully_charged_charge_level) == "number" and fully_charged_charge_level or 1

    if charge_template.limit_max_charge_to_ammo_clip then
        local max_charge_limit_func = charge_template.max_charge_limit_func
        local ammo_limited_max_charge

        if type(max_charge_limit_func) == "function" then
            ammo_limited_max_charge = max_charge_limit_func(1)
        else
            local starting_min_charge = type(template_min_charge) == "number" and template_min_charge or 0

            ammo_limited_max_charge = math.clamp01(starting_min_charge + 1)
        end

        if type(ammo_limited_max_charge) == "number" then
            max_charge = math.min(max_charge, ammo_limited_max_charge)
        end
    end

    min_charge = math.clamp01(min_charge)
    max_charge = math.clamp01(max_charge)

    if max_charge < min_charge then
        max_charge = min_charge
    end

    return min_charge, max_charge
end

local function action_has_variable_charge_range(action_name, action, charge_action_name, charge_action, weapon_template,
                                                weapon_tweak_templates)
    local min_charge, max_charge = mod.action_charge_level_bounds(action_name, action, charge_action_name, charge_action,
        weapon_template, weapon_tweak_templates)

    return type(min_charge) == "number" and type(max_charge) == "number" and
        max_charge - min_charge > CHARGE_LEVEL_EPSILON
end

local function copy_action_composites(source)
    local target = {}

    for action_name, composite in pairs(source or {}) do
        if type(composite) == "table" then
            local composite_names = {}

            for i = 1, #composite do
                composite_names[i] = composite[i]
            end

            target[action_name] = composite_names
        else
            target[action_name] = composite
        end
    end

    return target
end

local function add_merged_action_composites(action_composites, start_name_by_action_name)
    for action_name, start_action_name in pairs(start_name_by_action_name or {}) do
        if action_composites[action_name] == nil and action_composites[start_action_name] == nil then
            action_composites[action_name] = {
                start_action_name,
                action_name,
            }
            action_composites[start_action_name] = action_name
        end
    end
end

local function add_action_alias_composites(action_composites, actions)
    for representative_action_name, alias_action_names in pairs(ACTION_ALIAS_COMPOSITES) do
        if type(actions[representative_action_name]) == "table" and
            action_composites[representative_action_name] == nil then
            local composite_action_names = {
                representative_action_name,
            }

            for i = 1, #alias_action_names do
                local alias_action_name = alias_action_names[i]

                if type(actions[alias_action_name]) == "table" and action_composites[alias_action_name] == nil then
                    composite_action_names[#composite_action_names + 1] = alias_action_name
                    action_composites[alias_action_name] = representative_action_name
                end
            end

            if #composite_action_names > 1 then
                action_composites[representative_action_name] = composite_action_names
            end
        end
    end
end

local function build_action_composites(weapon_template_name, actions, merged_special_start_name_by_action_name,
                                       merged_charge_start_name_by_action_name)
    local action_composites = copy_action_composites(
        ACTION_COMPOSITES_BY_WEAPON_TEMPLATE[weapon_template_name])

    add_action_alias_composites(action_composites, actions)
    add_merged_action_composites(action_composites, merged_special_start_name_by_action_name)
    add_merged_action_composites(action_composites, merged_charge_start_name_by_action_name)

    return next(action_composites) and action_composites or nil
end

local function action_name_is_direct_special_attack(entry, action_name)
    local actions = entry.actions
    local action = type(actions) == "table" and actions[action_name]

    return type(action) == "table" and
        mod.action_uses_weapon_extra_input(action_name, action, actions)
end

local function action_name_has_special_tab_second_group_prefix(entry, action_name)
    local community_action_names = entry.community_action_names
    local community_action_name = type(community_action_names) == "table" and
        community_action_names[action_name]

    if type(community_action_name) ~= "string" then
        return false
    end

    for i = 1, #SPECIAL_TAB_SECOND_GROUP_LOCALIZATION_KEYS do
        local prefix = Localize(SPECIAL_TAB_SECOND_GROUP_LOCALIZATION_KEYS[i]) .. "•"

        if string.find(community_action_name, prefix, 1, true) == 1 then
            return true
        end
    end

    return false
end

local function action_name_is_special_tab_second_group(entry, action_name)
    return action_name_is_direct_special_attack(entry, action_name) or
        action_name_has_special_tab_second_group_prefix(entry, action_name)
end

local function special_tab_action_sort_group(entry)
    if mod.action_is_special_activation(entry.name, entry.action) then
        return 1
    end

    local names = entry.names

    if names then
        for i = 1, #names do
            if action_name_is_special_tab_second_group(entry, names[i]) then
                return 2
            end
        end
    elseif action_name_is_special_tab_second_group(entry, entry.name) then
        return 2
    end

    return 3
end

function mod.action_detail_text(action_name, action, weapon_template, weapon_tweak_templates)
    return mod.action_sequence_timing_text and
        mod.action_sequence_timing_text(action, weapon_template, weapon_tweak_templates, action_name) or ""
end

local function number_duplicate_entries(entries, actions)
    local distances = mod.get_shortest_paths and mod.get_shortest_paths(actions) or {}
    local entries_by_name = {}

    for i = 1, #entries do
        local entry = entries[i]
        local name = entry.display_name

        if name then
            entries_by_name[name] = entries_by_name[name] or {}
            entries_by_name[name][#entries_by_name[name] + 1] = entry
        end
    end

    for name, group in pairs(entries_by_name) do
        if #group > 1 then
            for i = 1, #group do
                local entry = group[i]
                local min_dist = math.huge

                if entry.names then
                    for j = 1, #entry.names do
                        min_dist = math.min(min_dist, distances[entry.names[j]] or math.huge)
                    end
                elseif entry.name then
                    min_dist = distances[entry.name] or math.huge
                end

                entry._dist = min_dist
            end

            table.sort(group, function(a, b)
                if a._dist == b._dist then
                    local a_name = a.name or ""
                    local b_name = b.name or ""
                    return a_name < b_name
                end
                return a._dist < b._dist
            end)

            for i = 1, #group do
                group[i].display_name = name .. " " .. i
            end
        end
    end
end

function mod.sorted_action_entries(item, action_filter)
    local weapon_template = WeaponTemplate.weapon_template_from_item(item)
    local actions = weapon_template and weapon_template.actions
    local entries = {}

    if not actions then
        return entries
    end

    local community_action_names = mod.community_action_display_names(weapon_template, actions, item)
    local weapon_tweak_templates, damage_profile_lerp_values = mod.item_weapon_tweak_templates(item, weapon_template)
    local weapon_template_name = weapon_template and weapon_template.name or item and item.weapon_template
    local excluded_action_names = EXCLUDED_ACTION_NAMES_BY_WEAPON_TEMPLATE[weapon_template_name]
    local configured_start_name_by_action_name = ACTION_START_NAMES_BY_WEAPON_TEMPLATE[weapon_template_name]
    local action_names_by_action = {}
    local chain_source_names = mod.direct_chain_source_names(actions)
    local special_activation_chain_action_names = mod.special_activation_chain_action_names(actions)
    local special_state_action_names = mod.special_state_action_names(actions, special_activation_chain_action_names)
    local special_active_windup_action_names = mod.special_active_windup_chain_action_names(actions, chain_source_names)
    local movement_condition_names = mod.movement_condition_action_names(actions, chain_source_names)
    local merged_special_start_name_by_action_name, merged_action_name_by_special_start_name =
        merged_special_action_pairs(actions)
    local merged_charge_start_name_by_action_name, merged_action_name_by_charge_start_name =
        merged_charge_action_pairs(actions)
    local action_composites = build_action_composites(weapon_template_name, actions,
        merged_special_start_name_by_action_name, merged_charge_start_name_by_action_name)
    local has_special_actions = mod.weapon_has_special_state_actions(actions)
    local is_special_filter = action_filter == mod.WAD_ACTION_FILTER_SPECIAL
    local dedupe_entries_by_key = {}
    local range_affects_performance = false
    local has_charge_actions = false

    local sorted_action_names = table.keys(actions)
    table.sort(sorted_action_names)

    for i = 1, #sorted_action_names do
        local action_name = sorted_action_names[i]
        local action = actions[action_name]

        if type(action) == "table" then
            action_names_by_action[action] = action_name
        end
    end

    for i = 1, #sorted_action_names do
        local action_name = sorted_action_names[i]
        local charge_action_name = merged_charge_start_name_by_action_name[action_name]

        if charge_action_name then
            local action = actions[action_name]
            local charge_action = actions[charge_action_name]

            if type(action) == "table" and not (excluded_action_names and excluded_action_names[action_name]) and
                not action_is_excluded(action_name, action, true) and
                action_matches_requested_filter(action_name, action, action_filter, special_state_action_names,
                    special_activation_chain_action_names, has_special_actions, special_active_windup_action_names,
                    actions) and
                action_has_variable_charge_range(action_name, action, charge_action_name, charge_action, weapon_template,
                    weapon_tweak_templates) then
                has_charge_actions = true

                break
            end
        end
    end

    if not has_charge_actions then
        for i = 1, #sorted_action_names do
            local action_name = sorted_action_names[i]
            local action = actions[action_name]

            if action_has_direct_variable_charge(action) and
                merged_action_name_by_charge_start_name[action_name] == nil and
                not (excluded_action_names and excluded_action_names[action_name]) and
                not action_is_excluded(action_name, action) and
                action_matches_requested_filter(action_name, action, action_filter, special_state_action_names,
                    special_activation_chain_action_names, has_special_actions, special_active_windup_action_names,
                    actions) and
                action_has_variable_charge_range(action_name, action, nil, nil, weapon_template,
                    weapon_tweak_templates) then
                has_charge_actions = true

                break
            end
        end
    end

    mod.ACTIONS_WEAPON_CONTEXTS[actions] = {
        action_composites = action_composites,
        action_filter = action_filter,
        action_names_by_action = action_names_by_action,
        has_special_actions = has_special_actions,
        has_charge_actions = has_charge_actions,
        merged_charge_start_name_by_action_name = merged_charge_start_name_by_action_name,
        item = item,
        special_activation_chain_action_names = special_activation_chain_action_names,
        special_active_windup_action_names = special_active_windup_action_names,
        special_state_action_names = special_state_action_names,
        weapon_template = weapon_template,
        weapon_tweak_templates = weapon_tweak_templates,
    }

    for i = 1, #sorted_action_names do
        local action_name = sorted_action_names[i]
        local action = actions[action_name]
        local action_composite = action_composites and action_composites[action_name]
        local configured_start_name = configured_start_name_by_action_name and
            configured_start_name_by_action_name[action_name]
        local merged_special_start_name = merged_special_start_name_by_action_name[action_name]
        local merged_charge_start_name = merged_charge_start_name_by_action_name[action_name]
        local merged_start_name = configured_start_name or merged_special_start_name or merged_charge_start_name
        local merged_start_action = merged_start_name and actions[merged_start_name]
        local merged_charge_start_action = merged_charge_start_name and actions[merged_charge_start_name]
        local is_merged_start_action = merged_action_name_by_special_start_name[action_name] ~= nil or
            merged_action_name_by_charge_start_name[action_name] ~= nil or type(action_composite) == "string"
        local context_action_name = merged_special_start_name or action_name
        local context_action = merged_special_start_name and merged_start_action or action

        if type(action) == "table" and not is_merged_start_action and
            not (excluded_action_names and excluded_action_names[action_name]) and
            not action_is_excluded(action_name, action, merged_charge_start_name ~= nil) and
            action_matches_requested_filter(context_action_name, context_action, action_filter,
                special_state_action_names, special_activation_chain_action_names, has_special_actions,
                special_active_windup_action_names, actions) then
            local detail_text = mod.action_detail_text(action_name, action, weapon_template, weapon_tweak_templates)
            local chain_text = mod.action_chain_text(action, actions, community_action_names)
            local movement_prefix = mod.action_movement_requirement_prefix(context_action_name, context_action,
                movement_condition_names)
            local icon = mod.action_type_icon(weapon_template, action_name)
            local damage_text
            local armor_grid
            local tooltip_grid
            local action_range_affects_performance = false

            if action.kind == "reload_state" then
                damage_text = mod.action_reload_stages_text(action, weapon_template, weapon_tweak_templates,
                    action_name)
            else
                damage_text, armor_grid, action_range_affects_performance =
                    mod.action_damage_breakdown_text(action, action_name, damage_profile_lerp_values,
                        is_special_filter, weapon_template, weapon_tweak_templates, item, merged_charge_start_name,
                        merged_charge_start_action)
                range_affects_performance = range_affects_performance or action_range_affects_performance

                tooltip_grid = icon and mod.action_tooltip_damage_grid_data(action, action_name,
                    damage_profile_lerp_values, is_special_filter, weapon_tweak_templates, weapon_template,
                    merged_charge_start_name, merged_charge_start_action) or nil

                if merged_charge_start_action and mod.add_charge_shot_info_to_damage_text then
                    damage_text = mod.add_charge_shot_info_to_damage_text(damage_text, action_name, action,
                        merged_charge_start_name, merged_charge_start_action, weapon_template,
                        weapon_tweak_templates)
                end

                damage_text = mod.add_stamina_cost_to_damage_text(damage_text, action, weapon_template,
                    weapon_tweak_templates, is_special_filter)
                damage_text = mod.add_sprint_tech_to_damage_text(damage_text, action_name, action, actions,
                    chain_source_names)
            end

            local merged_names = type(action_composite) == "table" and action_composite or
                merged_start_name and {
                    merged_start_name,
                    action_name,
                } or nil

            mod.add_sorted_action_entry(entries, dedupe_entries_by_key, {
                action = action,
                actions = actions,
                armor_grid = armor_grid,
                chain_text = chain_text,
                community_action_names = community_action_names,
                damage_text = damage_text,
                detail_text = detail_text,
                icon = icon,
                tooltip_grid = tooltip_grid,
                movement_prefix = movement_prefix,
                name = action_name,
                range_affects_performance = action_range_affects_performance,
                names = merged_names,
                merged_start_kind = merged_start_action and merged_start_action.kind or nil,
                merged_start_name = merged_start_name,
                weapon_template_name = weapon_template_name,
                display_name = mod.action_entry_display_name(action_name, action, community_action_names,
                    weapon_template, weapon_tweak_templates, is_special_filter, movement_prefix),
                kind = action.kind or "",
            })
        end
    end

    number_duplicate_entries(entries, actions)

    table.sort(entries, function(a, b)
        if is_special_filter then
            local a_special_group = special_tab_action_sort_group(a)
            local b_special_group = special_tab_action_sort_group(b)

            if a_special_group ~= b_special_group then
                return a_special_group < b_special_group
            end
        end

        local a_group = ACTION_KIND_SORT_GROUPS[a.kind] or 2
        local b_group = ACTION_KIND_SORT_GROUPS[b.kind] or 2

        if a_group ~= b_group then
            return a_group < b_group
        end

        if a.kind == b.kind then
            local a_bucket = mod.action_entry_sweep_sort_bucket(a)
            local b_bucket = mod.action_entry_sweep_sort_bucket(b)

            if a_bucket ~= b_bucket then
                return a_bucket < b_bucket
            end

            return a.display_name < b.display_name
        end

        return a.kind > b.kind
    end)

    local innate_trait_entries = mod.innate_trait_action_entries(weapon_template_name, is_special_filter)

    for i = 1, innate_trait_entries and #innate_trait_entries or 0 do
        entries[#entries + 1] = innate_trait_entries[i]
    end

    local toxin_entries = mod.toxin_action_entries(weapon_template_name, is_special_filter)

    for i = 1, toxin_entries and #toxin_entries or 0 do
        entries[#entries + 1] = toxin_entries[i]
    end

    local bleed_entries = mod.bleed_action_entries(weapon_template_name, is_special_filter)

    for i = 1, bleed_entries and #bleed_entries or 0 do
        entries[#entries + 1] = bleed_entries[i]
    end

    local burning_entries = mod.burning_action_entries(
        weapon_template_name,
        is_special_filter,
        weapon_template,
        weapon_tweak_templates
    )

    for i = 1, burning_entries and #burning_entries or 0 do
        entries[#entries + 1] = burning_entries[i]
    end

    if not is_special_filter and mod.weapon_has_warpfire(actions) then
        local warpfire_entry = mod.warpfire_action_entry()

        if warpfire_entry then
            entries[#entries + 1] = warpfire_entry
        end
    end

    mod.add_original_action_names_to_kind_rows(entries)

    entries.range_affects_performance = range_affects_performance

    return entries
end
