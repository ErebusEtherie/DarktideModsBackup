-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_names.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local Localize = Localize

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local LOCALIZED_ACTION_NAMES = {
    action_block = mod.WAD_LOC.BLOCK,
    action_push = mod.WAD_LOC.PUSHING,
    push = mod.WAD_LOC.WEAPON_SPECIAL_WEAPON_BASH,
    action_bash_light = mod.WAD_LOC.WEAPON_SPECIAL_WEAPON_BASH,
    action_wield = mod.WAD_LOC.INGAME_WIELD_3_4_GAMEPAD,
    action_pushfollow = mod.WAD_LOC.PUSH_FOLLOW_UP,
    action_right_light_pushfollow = mod.WAD_LOC.PUSH_FOLLOW_UP,
    action_left_light_pushfollow = mod.WAD_LOC.PUSH_FOLLOW_UP,
    action_find_target = mod.WAD_LOC.PUSH_FOLLOW_UP,
    action_fling_target = mod.WAD_LOC.PUSH_FOLLOW_UP,
    action_reload = mod.WAD_LOC.BASIC_RELOAD_INPUT,
    action_brace_reload = mod.WAD_LOC.BASIC_RELOAD_INPUT,
    action_shoot_hip = mod.WAD_LOC.RANGED_ATTACK_PRIMARY,
    action_cycle_chem = mod.WAD_LOC.WEAPON_SPECIAL_MODE_SWITCH,
    action_pistol_whip = mod.WAD_LOC.WEAPON_SPECIAL_WEAPON_BASH,
    action_parry_special = mod.WAD_LOC.WEAPON_SPECIAL_PARRY,
    action_parry_special_psyker = mod.WAD_LOC.WEAPON_SPECIAL_PARRY,
    action_toggle_flashlight = mod.WAD_LOC.WEAPON_SPECIAL_FLASHLIGHT,
    action_overheat_explode = mod.WAD_LOC.EXPLOSION_ON_OVERHEAT_LOCKOUT,
}

local DETAILED_SPECIAL_ATTACK_KINDS = {
    melee_explosive = true,
    push = true,
    sweep = true,
}

local STANDALONE_SPECIAL_ACTION_KINDS = {
    block = true,
    ranged_load_special = true,
    weapon_shout = true,
    weapon_throw = true,
}

local RANGED_DISPLAY_ACTION_ALIASES = {
    rapid_left = "action_shoot",
}

-- ============================================================================
-- CORE DISPLAY NAME RESOLUTION
-- ============================================================================

function mod.action_display_name(action_name, community_action_names, weapon_template)
    local ranged_action_name = RANGED_DISPLAY_ACTION_ALIASES[action_name] or action_name
    local ranged_display_name = mod.ranged_shoot_action_display_name(ranged_action_name, weapon_template)

    if ranged_display_name then
        return ranged_display_name
    end

    if community_action_names and community_action_names[action_name] then
        return community_action_names[action_name]
    end

    local override_name = mod.manual_action_display_name_override(action_name, weapon_template)

    if override_name then
        return override_name
    end

    local localization_key = LOCALIZED_ACTION_NAMES[action_name]

    if localization_key then
        return Localize(localization_key)
    end

    return action_name
end

-- ============================================================================
-- CHAIN AND PATH RESOLUTION
-- ============================================================================

function mod.chain_data_has_action_name(chain_data, action_name)
    if type(chain_data) ~= "table" or type(action_name) ~= "string" then
        return false
    end

    if chain_data.action_name == action_name then
        return true
    end

    for i = 1, #chain_data do
        local child_chain_data = chain_data[i]

        if type(child_chain_data) == "table" and child_chain_data.action_name == action_name then
            return true
        end
    end

    return false
end

function mod.get_chain_action_name(chain_data)
    if type(chain_data) == "table" then
        if type(chain_data.action_name) == "string" then
            return chain_data.action_name
        elseif #chain_data > 0 and type(chain_data[1]) == "table" and type(chain_data[1].action_name) == "string" then
            return chain_data[1].action_name
        end
    end

    return nil
end

local function main_path_chain_action_name(chain_data, actions)
    if type(chain_data) ~= "table" then return nil end

    if type(chain_data.action_name) == "string" then
        return chain_data.action_name
    end

    local fallback_action_name

    for i = 1, #chain_data do
        local candidate = chain_data[i]
        local candidate_action_name = type(candidate) == "table" and candidate.action_name

        if type(candidate_action_name) == "string" then
            fallback_action_name = fallback_action_name or candidate_action_name

            local candidate_action = actions and actions[candidate_action_name]

            if not mod.action_condition_func_returns_special_active(candidate_action) then
                return candidate_action_name
            end
        end
    end

    return fallback_action_name
end

function mod.find_main_attack_path(actions, chain_input_name)
    local sequence = {}
    local visited = {}
    local wield_action = actions and actions.action_wield

    if not wield_action or not wield_action.allowed_chain_actions then
        return sequence
    end

    local current_action_name = main_path_chain_action_name(wield_action.allowed_chain_actions.start_attack, actions)

    while current_action_name do
        local current_action = actions[current_action_name]

        if not current_action then break end

        if current_action.kind == "sweep" then
            if visited[current_action_name] then break end

            sequence[#sequence + 1] = current_action_name
            visited[current_action_name] = true
        end

        local allowed_chains = current_action.allowed_chain_actions

        if not allowed_chains then break end

        local next_action_name

        if current_action.kind == "windup" then
            next_action_name = main_path_chain_action_name(allowed_chains[chain_input_name], actions)
        else
            next_action_name = main_path_chain_action_name(allowed_chains.start_attack, actions) or
                main_path_chain_action_name(allowed_chains[chain_input_name], actions)
        end

        if not next_action_name then break end

        current_action_name = next_action_name
    end

    return sequence
end

function mod.add_simulated_chain_names(community_action_names, main_attack_action_names, actions, chain_input_name,
                                       localization_key, chain_source_names)
    local sequence = mod.find_main_attack_path(actions, chain_input_name)
    local display_name_prefix = Localize(localization_key)
    local attack_index = 0

    for i = 1, #sequence do
        local action_name = sequence[i]
        local contextual_prefix = mod.sweep_movement_requirement_prefix(action_name, actions, chain_source_names)

        main_attack_action_names[action_name] = true

        if not contextual_prefix then
            attack_index = attack_index + 1
        end

        if not LOCALIZED_ACTION_NAMES[action_name] then
            if contextual_prefix then
                community_action_names[action_name] = contextual_prefix .. display_name_prefix
            else
                community_action_names[action_name] = display_name_prefix .. " " .. attack_index
            end
        end
    end
end

-- ============================================================================
-- SWEEP AND SPECIAL ACTION NAMING
-- ============================================================================

function mod.action_name_has_token(action_name, token)
    return type(action_name) == "string" and type(token) == "string" and
        string.find("_" .. action_name .. "_", "_" .. token .. "_", 1, true) ~= nil
end

local function action_damage_profile(action, field_name)
    if type(action) ~= "table" then return nil end

    field_name = field_name or "damage_profile"

    local damage_profile = action[field_name]

    if type(damage_profile) == "table" then
        return damage_profile
    end

    if field_name == "damage_profile" then
        return Action.damage_template(action)
    end

    return nil
end

local function action_melee_attack_strength(action, action_name, use_light_fallback)
    local light_strength

    for _, field_name in ipairs({ "damage_profile", "inner_damage_profile", "outer_damage_profile" }) do
        local damage_profile = action_damage_profile(action, field_name)
        local melee_attack_strength = damage_profile and damage_profile.melee_attack_strength

        if melee_attack_strength == "heavy" then
            return "heavy"
        elseif melee_attack_strength == "light" then
            light_strength = "light"
        end
    end

    if light_strength then return light_strength end
    if mod.action_name_has_token(action_name, "heavy") then return "heavy" end

    return use_light_fallback and "light" or nil
end

local function add_localized_sweep_names(community_action_names, actions)
    if not actions then return end

    for action_name, action in pairs(actions) do
        local localization_key = type(action) == "table" and action.kind == "sweep" and
            LOCALIZED_ACTION_NAMES[action_name]

        if localization_key then
            community_action_names[action_name] = Localize(localization_key)
        end
    end
end

local function raw_input_is_weapon_extra(input_name)
    return type(input_name) == "string" and string.starts_with(input_name, "weapon_extra")
end

local function input_sequence_uses_weapon_extra(input_sequence)
    if type(input_sequence) ~= "table" then return false end

    for i = 1, #input_sequence do
        local input_data = input_sequence[i]

        if type(input_data) == "table" then
            if raw_input_is_weapon_extra(input_data.input) or raw_input_is_weapon_extra(input_data.hold_input) then
                return true
            end

            local inputs = input_data.inputs

            if type(inputs) == "table" then
                for j = 1, #inputs do
                    if raw_input_is_weapon_extra(inputs[j]) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function action_input_uses_weapon_extra(input_name, weapon_template)
    if type(input_name) ~= "string" then return false end
    if mod.action_input_is_weapon_extra and mod.action_input_is_weapon_extra(input_name) then return true end

    local action_inputs = weapon_template and weapon_template.action_inputs
    local action_input = type(action_inputs) == "table" and action_inputs[input_name]

    return type(action_input) == "table" and input_sequence_uses_weapon_extra(action_input.input_sequence)
end

local function action_has_chain_input_source(action_name, actions, chain_source_names, input_prefix)
    local source_action_names = chain_source_names and chain_source_names[action_name]

    if not source_action_names then return false end

    for source_action_name in pairs(source_action_names) do
        local allowed_chain_actions = actions and actions[source_action_name] and
            actions[source_action_name].allowed_chain_actions

        if allowed_chain_actions then
            for input_name, chain_data in pairs(allowed_chain_actions) do
                if string.starts_with(input_name, input_prefix) and
                    mod.chain_data_has_action_name(chain_data, action_name) then
                    return true
                end
            end
        end
    end

    return false
end

local function action_has_weapon_extra_chain_source(action_name, actions, chain_source_names, weapon_template)
    local source_action_names = chain_source_names and chain_source_names[action_name]

    if not source_action_names then return false end

    for source_action_name in pairs(source_action_names) do
        local source_action = actions and actions[source_action_name]
        local allowed_chain_actions = source_action and source_action.allowed_chain_actions

        if allowed_chain_actions then
            for input_name, chain_data in pairs(allowed_chain_actions) do
                if action_input_uses_weapon_extra(input_name, weapon_template) and
                    mod.chain_data_has_action_name(chain_data, action_name) then
                    return true
                end
            end
        end
    end

    return false
end

local function localized_special_display_name(weapon_template)
    local displayed_attacks = weapon_template and weapon_template.displayed_attacks
    local special_display_name = displayed_attacks and displayed_attacks.special and
        displayed_attacks.special.display_name
    local localization_key = type(special_display_name) == "string" and special_display_name or
        mod.WAD_LOC.WEAPON_SPECIAL_SPECIAL_ATTACK

    return Localize(localization_key)
end

local function dodge_special_localization_key(action_name, weapon_template_name)
    if type(weapon_template_name) ~= "string" then return nil end

    if string.starts_with(weapon_template_name, "combatsword_p1_m") and action_name == "action_attack_special" then
        return mod.WAD_LOC.TALENT_ZEALOT_STACKING_MELEE_DAMAGE_AFTER_DODGE
    end

    if string.starts_with(weapon_template_name, "combatsword_p3_m") and
        (action_name == "action_attack_special_riposte" or
            action_name == "action_attack_special_riposte_psyker") then
        return mod.WAD_LOC.TALENT_ZEALOT_STACKING_MELEE_DAMAGE_AFTER_DODGE
    end

    return nil
end

local function action_is_dodge_special(action_name, weapon_template_name)
    return dodge_special_localization_key(action_name, weapon_template_name) ~= nil
end

local function action_is_excluded_special_activation(action_name, action)
    local kind = action and action.kind

    return kind and mod.WAD_SPECIAL_ACTIVATION_ACTION_KINDS and
        mod.WAD_SPECIAL_ACTIVATION_ACTION_KINDS[kind] == true and
        mod.action_is_special_activation and
        not mod.action_is_special_activation(action_name, action)
end

local function action_belongs_to_weapon_special_branch(action_name, action, actions, chain_source_names, weapon_template,
                                                       weapon_template_name)
    if action_is_excluded_special_activation(action_name, action) then return false end
    if action_is_dodge_special(action_name, weapon_template_name) then return true end
    if weapon_template and weapon_template.special_action_name == action_name then return true end
    if action_input_uses_weapon_extra(action and action.start_input, weapon_template) then return true end

    return action_has_weapon_extra_chain_source(action_name, actions, chain_source_names, weapon_template)
end

local function action_is_detailed_special_attack(action)
    return type(action) == "table" and DETAILED_SPECIAL_ATTACK_KINDS[action.kind] == true
end

local function action_is_standalone_special_action(action_name, action)
    if mod.action_is_special_activation and mod.action_is_special_activation(action_name, action) then
        return true
    end

    return type(action) == "table" and STANDALONE_SPECIAL_ACTION_KINDS[action.kind] == true
end

local function action_is_combo_sweep(action_name, actions, chain_source_names)
    return mod.action_name_has_token(action_name, "combo") or
        action_has_chain_input_source(action_name, actions, chain_source_names, "push_follow_up")
end

local function action_is_unlocked_pushfollow(action_name, actions, chain_source_names)
    return mod.action_name_has_token(action_name, "special") and
        not mod.action_name_has_token(action_name, "combo") and
        action_has_chain_input_source(action_name, actions, chain_source_names, "push_follow_up")
end

local function action_is_unlocked_pushfollow_combo(action_name)
    return mod.action_name_has_token(action_name, "special") and
        mod.action_name_has_token(action_name, "pushfollow") and
        mod.action_name_has_token(action_name, "combo")
end

local function unlocked_pushfollow_display_name(action_name, actions, chain_source_names)
    if action_is_unlocked_pushfollow(action_name, actions, chain_source_names) then
        return Localize(mod.WAD_LOC.UNLOCKED) .. "•" .. Localize(mod.WAD_LOC.PUSH_FOLLOW_UP)
    end

    return nil
end

local function special_sweep_prefix(action_name, action, actions, chain_source_names, weapon_template)
    if mod.action_name_has_token(action_name, "deactivate") then
        return Localize(mod.WAD_LOC.TALENT_MENU_TOOLTIP_BUTTON_HINT_REMOVE_LEVEL_FIRST) .. "•"
    end

    if mod.action_name_has_token(action_name, "activate") then
        return Localize(mod.WAD_LOC.WEAPON_SPECIAL_ACTIVATE) .. "•"
    end

    if action_is_unlocked_pushfollow_combo(action_name) then
        return Localize(mod.WAD_LOC.UNLOCKED) .. "•" .. Localize(mod.WAD_LOC.INVENTORY_WEAPON_BUTTON_MARKS) .. "•"
    end

    if action_is_combo_sweep(action_name, actions, chain_source_names) then
        return Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_SPECIAL) .. "•" ..
            Localize(mod.WAD_LOC.INVENTORY_WEAPON_BUTTON_MARKS) .. "•"
    end

    if (type(action.start_input) == "string" and string.starts_with(action.start_input, "special_action")) or
        action_has_chain_input_source(action_name, actions, chain_source_names, "special_action") then
        local displayed_attacks = weapon_template and weapon_template.displayed_attacks
        local special_display_name = displayed_attacks and displayed_attacks.special and
            displayed_attacks.special.display_name
        local localization_key = type(special_display_name) == "string" and special_display_name or
            mod.WAD_LOC.WEAPON_SPECIAL_SPECIAL_ATTACK

        return Localize(localization_key) .. "•"
    end

    if action_has_chain_input_source(action_name, actions, chain_source_names, "light_attack") or
        action_has_chain_input_source(action_name, actions, chain_source_names, "heavy_attack") then
        return Localize(mod.WAD_LOC.UNLOCKED) .. "•"
    end

    return Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_SPECIAL) .. "•"
end

local function sweep_attack_display_name(action_name, action, use_light_fallback)
    if mod.action_name_has_token(action_name, "activate") or
        mod.action_name_has_token(action_name, "deactivate") then
        if mod.action_name_has_token(action_name, "heavy") then
            return Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_HEAVY)
        elseif mod.action_name_has_token(action_name, "light") then
            return Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_LIGHT)
        end
    end

    local melee_attack_strength = action_melee_attack_strength(action, action_name, use_light_fallback)

    if not melee_attack_strength then return nil end

    return melee_attack_strength == "heavy" and Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_HEAVY) or
        Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_LIGHT)
end

local function detailed_special_attack_display_name(action_name, action, weapon_template, weapon_template_name, actions,
                                                    chain_source_names)
    if action.kind == "sweep" then
        local pushfollow_display_name = unlocked_pushfollow_display_name(action_name, actions, chain_source_names)

        if pushfollow_display_name then return pushfollow_display_name end
    end

    local attack_name = sweep_attack_display_name(action_name, action, true)
    local dodge_localization_key = dodge_special_localization_key(action_name, weapon_template_name)
    local prefix

    if dodge_localization_key then
        prefix = Localize(dodge_localization_key) .. "•"
    elseif action.kind == "sweep" then
        prefix = special_sweep_prefix(action_name, action, actions, chain_source_names, weapon_template)
    else
        prefix = localized_special_display_name(weapon_template) .. "•"
    end

    if string.find(action_name, "_from_reload", 1, true) then
        prefix = Localize(mod.WAD_LOC.BASIC_RELOAD_INPUT) .. "•" .. prefix
    end

    return prefix .. attack_name
end

local function add_generated_special_action_display_names(community_action_names, weapon_template, actions,
                                                          chain_source_names, item)
    local detailed_special_action_names = {}
    local generated_special_action_names = {}

    if type(actions) ~= "table" or
        (mod.special_action_display_name_excluded and
            mod.special_action_display_name_excluded(weapon_template)) then
        return detailed_special_action_names, generated_special_action_names
    end

    local weapon_template_name = weapon_template and weapon_template.name or item and item.weapon_template

    for action_name, action in pairs(actions) do
        if type(action) == "table" then
            local is_special_pushfollow_shout = action.kind == "weapon_shout" and
                action_is_unlocked_pushfollow(action_name, actions, chain_source_names)

            if is_special_pushfollow_shout then
                community_action_names[action_name] = Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_SPECIAL) .. "•" ..
                    Localize(mod.WAD_LOC.PUSH_FOLLOW_UP)
                generated_special_action_names[action_name] = true
            elseif action_belongs_to_weapon_special_branch(action_name, action, actions, chain_source_names,
                    weapon_template, weapon_template_name) then
                if action_is_detailed_special_attack(action) then
                    community_action_names[action_name] = detailed_special_attack_display_name(action_name, action,
                        weapon_template, weapon_template_name, actions, chain_source_names)
                    detailed_special_action_names[action_name] = true
                    generated_special_action_names[action_name] = true
                elseif action_is_standalone_special_action(action_name, action) then
                    community_action_names[action_name] = localized_special_display_name(weapon_template)
                    generated_special_action_names[action_name] = true
                end
            end
        end
    end

    return detailed_special_action_names, generated_special_action_names
end

local function off_path_sweep_display_name(action_name, action, actions, chain_source_names, weapon_template)
    local pushfollow_display_name = unlocked_pushfollow_display_name(action_name, actions, chain_source_names)

    if pushfollow_display_name then return pushfollow_display_name end

    local attack_name = sweep_attack_display_name(action_name, action, false)

    if not attack_name then return nil end

    local prefix

    if mod.action_name_has_token(action_name, "special") then
        prefix = special_sweep_prefix(action_name, action, actions, chain_source_names, weapon_template)
    elseif mod.action_name_has_token(action_name, "combo") then
        prefix = Localize(mod.WAD_LOC.INVENTORY_WEAPON_BUTTON_MARKS) .. "•"
    else
        prefix = mod.sweep_movement_requirement_prefix and
            mod.sweep_movement_requirement_prefix(action_name, actions, chain_source_names)
    end

    return (prefix or Localize(mod.WAD_LOC.INVENTORY_WEAPON_BUTTON_MARKS) .. "•") .. attack_name
end

local function add_non_main_sweep_action_display_names(community_action_names, weapon_template, actions,
                                                       main_attack_action_names, chain_source_names,
                                                       detailed_special_action_names)
    if not actions then return end

    for action_name, action in pairs(actions) do
        if type(action) == "table" and action.kind == "sweep" and
            not main_attack_action_names[action_name] and
            not detailed_special_action_names[action_name] and
            not LOCALIZED_ACTION_NAMES[action_name] then
            community_action_names[action_name] = off_path_sweep_display_name(action_name, action, actions,
                chain_source_names, weapon_template)
        end
    end
end

-- ============================================================================
-- DEDUPLICATION
-- ============================================================================

local function number_duplicate_action_names(community_action_names, actions, generated_special_action_names)
    if not actions then return end

    local distances = mod.get_shortest_paths and mod.get_shortest_paths(actions) or {}
    local names_by_display_name = {}

    for action_name, action in pairs(actions) do
        -- Only number sweeps pre-deduplication. Special actions will be numbered post-deduplication
        -- to ensure contiguous numbering in the UI.
        local should_number = type(action) == "table" and action.kind == "sweep"
        local display_name = should_number and community_action_names[action_name]

        if type(display_name) == "string" then
            local names = names_by_display_name[display_name]

            if not names then
                names = {}
                names_by_display_name[display_name] = names
            end

            names[#names + 1] = {
                action_name = action_name,
                distance = distances[action_name] or math.huge,
            }
        end
    end

    for display_name, names in pairs(names_by_display_name) do
        if #names > 1 then
            table.sort(names, function(a, b)
                if a.distance == b.distance then
                    return a.action_name < b.action_name
                end

                return a.distance < b.distance
            end)

            for i = 1, #names do
                community_action_names[names[i].action_name] = display_name .. " " .. i
            end
        end
    end
end

-- ============================================================================
-- EXPORTED ORCHESTRATOR
-- ============================================================================

function mod.community_action_display_names(weapon_template, actions, item)
    local community_action_names = {}
    local main_attack_action_names = {}
    local chain_source_names = mod.direct_chain_source_names and mod.direct_chain_source_names(actions) or {}

    add_localized_sweep_names(community_action_names, actions)

    mod.add_simulated_chain_names(community_action_names, main_attack_action_names, actions, "light_attack",
        mod.WAD_LOC.WEAPON_ACTION_TITLE_LIGHT, chain_source_names)
    mod.add_simulated_chain_names(community_action_names, main_attack_action_names, actions, "heavy_attack",
        mod.WAD_LOC.WEAPON_ACTION_TITLE_HEAVY, chain_source_names)

    local detailed_special_action_names, generated_special_action_names = add_generated_special_action_display_names(
        community_action_names, weapon_template, actions, chain_source_names, item
    )

    add_non_main_sweep_action_display_names(community_action_names, weapon_template, actions, main_attack_action_names,
        chain_source_names, detailed_special_action_names)

    -- Extracted to wad_action_archetypes.lua
    if mod.add_archetype_action_name_suffixes then
        mod.add_archetype_action_name_suffixes(community_action_names, weapon_template, actions, item)
    end

    number_duplicate_action_names(community_action_names, actions, generated_special_action_names)

    return community_action_names
end