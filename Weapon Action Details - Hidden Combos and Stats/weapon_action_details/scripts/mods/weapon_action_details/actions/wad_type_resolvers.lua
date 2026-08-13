-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_type_resolvers.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local SWEEP_DAMAGE_PROFILE_ACTION_TYPES = {
    "ninja_fencer",
    "linesman",
    "smiter",
    "tank",
}

local RANGED_STANCE_ACTION_KINDS = {
    aim = true,
    unaim = true,
    block_aiming = true,
    block_unaim = true,
}

local ACTION_TYPE_BY_KIND = {
    block = "defence",
    charge_ammo = "charge",
    ranged_load_special = "special_bullet",
    toggle_special = "activate",
    toggle_special_with_block = "activate",
    vent_overheat = "vent",
    vent_warp_charge = "vent",
}

-- ============================================================================
-- TYPE RESOLUTION HELPERS
-- ============================================================================

local function action_type_from_damage_profile_name(damage_profile)
    local profile_name = damage_profile and damage_profile.name
    if type(profile_name) ~= "string" then
        return nil
    end

    local padded_profile_name = "_" .. profile_name .. "_"
    local rightmost_action_type
    local rightmost_position = 0

    for i = 1, #SWEEP_DAMAGE_PROFILE_ACTION_TYPES do
        local action_type = SWEEP_DAMAGE_PROFILE_ACTION_TYPES[i]
        local token = "_" .. action_type .. "_"
        local search_start = 1

        while true do
            local position = string.find(padded_profile_name, token, search_start, true)
            if not position then break end

            if position > rightmost_position then
                rightmost_position = position
                rightmost_action_type = action_type
            end

            search_start = position + 1
        end
    end

    return rightmost_action_type
end

local function combo_entry_action_name(combo_entry)
    if type(combo_entry) == "string" then
        return combo_entry
    end
    return type(combo_entry) == "table" and combo_entry.action_name or nil
end

local function explicit_combo_group_has_action_name(combo_group, action_name)
    if type(combo_group) == "string" then
        return combo_group == action_name
    end
    if type(combo_group) ~= "table" then
        return false
    end
    if combo_group.action_name == action_name then
        return true
    end

    for i = 1, #combo_group do
        if combo_entry_action_name(combo_group[i]) == action_name then
            return true
        end
    end

    return false
end

local function chain_data_has_action_name(chain_data, action_name)
    if type(chain_data) ~= "table" then
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

local function raw_input_is_weapon_extra(input_name)
    return type(input_name) == "string" and string.starts_with(input_name, "weapon_extra")
end

local function input_sequence_uses_weapon_extra(input_sequence)
    if type(input_sequence) ~= "table" then
        return false
    end

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
    if type(input_name) ~= "string" then
        return false
    end
    if mod.action_input_is_weapon_extra and mod.action_input_is_weapon_extra(input_name) then
        return true
    end

    local action_inputs = weapon_template and weapon_template.action_inputs
    local action_input = type(action_inputs) == "table" and action_inputs[input_name]

    return type(action_input) == "table" and input_sequence_uses_weapon_extra(action_input.input_sequence)
end

local function action_has_weapon_extra_chain_source(action_name, weapon_template)
    local actions = weapon_template and weapon_template.actions
    if type(actions) ~= "table" then
        return false
    end

    for _, source_action in pairs(actions) do
        local allowed_chain_actions = type(source_action) == "table" and source_action.allowed_chain_actions
        if type(allowed_chain_actions) == "table" then
            for input_name, chain_data in pairs(allowed_chain_actions) do
                if action_input_uses_weapon_extra(input_name, weapon_template) and
                    chain_data_has_action_name(chain_data, action_name) then
                    return true
                end
            end
        end
    end

    return false
end

local function ranged_input_display_group(input_name, weapon_template)
    if type(input_name) ~= "string" then return nil end

    if action_input_uses_weapon_extra(input_name, weapon_template) then
        return "special"
    end

    if string.find(input_name, "block_shoot", 1, true) or string.find(input_name, "zoom", 1, true) or
        string.find(input_name, "brace", 1, true) or string.find(input_name, "aim", 1, true) then
        return "secondary"
    end

    if string.find(input_name, "shoot", 1, true) then
        return "primary"
    end

    return nil
end

local function add_ranged_display_group(current_group, new_group)
    if not new_group then return current_group end
    if current_group and current_group ~= new_group then return false end
    return new_group
end

local function incoming_ranged_display_group(action_name, weapon_template)
    local actions = weapon_template and weapon_template.actions
    local resolved_group

    if type(actions) ~= "table" then return nil end

    for _, source_action in pairs(actions) do
        local allowed_chain_actions = type(source_action) == "table" and source_action.allowed_chain_actions
        if type(allowed_chain_actions) == "table" then
            for input_name, chain_data in pairs(allowed_chain_actions) do
                if chain_data_has_action_name(chain_data, action_name) then
                    resolved_group = add_ranged_display_group(resolved_group,
                        ranged_input_display_group(input_name, weapon_template))
                    if resolved_group == false then
                        return nil
                    end
                end
            end
        end
    end

    return resolved_group
end

local function action_name_ranged_display_group(action_name)
    if string.find(action_name, "blocking", 1, true) or string.find(action_name, "zoom", 1, true) or
        string.find(action_name, "brace", 1, true) or string.find(action_name, "aim", 1, true) then
        return "secondary"
    end

    if string.find(action_name, "hip", 1, true) or action_name == "action_shoot" then
        return "primary"
    end

    return nil
end


-- ============================================================================
-- EXPORTED TYPE RESOLVERS
-- ============================================================================

function mod.weapon_template_is_ranged(weapon_template)
    local keywords = weapon_template and weapon_template.keywords

    if type(keywords) == "table" and table.contains(keywords, "ranged") then
        return true
    end

    local displayed_attacks = weapon_template and weapon_template.displayed_attacks
    local primary_type = displayed_attacks and displayed_attacks.primary and displayed_attacks.primary.type
    local secondary_type = displayed_attacks and displayed_attacks.secondary and displayed_attacks.secondary.type

    return primary_type == "hipfire" or primary_type == "ads" or primary_type == "brace" or
        primary_type == "charge" or secondary_type == "hipfire" or secondary_type == "ads" or
        secondary_type == "brace" or secondary_type == "charge"
end

function mod.action_type_from_sweep_damage_profiles(weapon_template, action_name)
    local actions = weapon_template and weapon_template.actions
    local action = actions and actions[action_name]

    if type(action) ~= "table" or action.kind ~= "sweep" then
        return nil
    end

    local resolved_action_type
    local num_damage_templates = Action.num_damage_templates(action)

    for template_index = 1, num_damage_templates do
        local damage_profile, special_damage_profile = Action.damage_template(action, template_index)
        local damage_profile_action_type = action_type_from_damage_profile_name(damage_profile)
        local special_damage_profile_action_type = action_type_from_damage_profile_name(special_damage_profile)

        if damage_profile_action_type then
            if resolved_action_type and resolved_action_type ~= damage_profile_action_type then
                return nil
            end
            resolved_action_type = damage_profile_action_type
        end

        if special_damage_profile_action_type then
            if resolved_action_type and resolved_action_type ~= special_damage_profile_action_type then
                return nil
            end
            resolved_action_type = special_damage_profile_action_type
        end
    end

    return resolved_action_type
end

function mod.action_type_from_explicit_combo(weapon_template, action_name)
    local explicit_combo = weapon_template and weapon_template.explicit_combo
    local displayed_attacks = weapon_template and weapon_template.displayed_attacks
    local action_display_order = UISettings.weapon_action_display_order_array

    if type(explicit_combo) ~= "table" or type(displayed_attacks) ~= "table" or type(action_display_order) ~= "table" then
        return nil
    end

    local resolved_action_type

    for attack_index = 1, #action_display_order do
        if explicit_combo_group_has_action_name(explicit_combo[attack_index], action_name) then
            local display_data = displayed_attacks[action_display_order[attack_index]]
            local action_type = mod.supported_action_type(display_data and display_data.type)

            if action_type then
                if resolved_action_type and resolved_action_type ~= action_type then
                    return nil
                end
                resolved_action_type = action_type
            end
        end
    end

    return resolved_action_type
end

function mod.action_type_from_special_metadata(weapon_template, action_name)
    local displayed_attacks = weapon_template and weapon_template.displayed_attacks
    local special_action_type = displayed_attacks and displayed_attacks.special and
        mod.supported_action_type(displayed_attacks.special.type)

    if not special_action_type then
        return nil
    end

    if weapon_template.special_action_name == action_name then
        return special_action_type
    end

    local actions = weapon_template.actions
    local action = actions and actions[action_name]

    if action_input_uses_weapon_extra(action and action.start_input, weapon_template) or action_has_weapon_extra_chain_source(action_name, weapon_template) then
        return special_action_type
    end

    return nil
end

function mod.action_type_from_ranged_context(weapon_template, action_name)
    if not mod.weapon_template_is_ranged(weapon_template) then
        return nil
    end

    local actions = weapon_template.actions
    local action = actions and actions[action_name]
    local displayed_attacks = weapon_template.displayed_attacks

    if type(action) ~= "table" or type(displayed_attacks) ~= "table" then
        return nil
    end

    local display_group
    if RANGED_STANCE_ACTION_KINDS[action.kind] then
        display_group = "secondary"
    else
        display_group = ranged_input_display_group(action.start_input, weapon_template) or
            incoming_ranged_display_group(action_name, weapon_template) or
            action_name_ranged_display_group(action_name)
    end

    local display_data = display_group and displayed_attacks[display_group]
    return mod.supported_action_type(display_data and display_data.type)
end

function mod.action_type_from_kind(action)
    local kind = action and action.kind
    if type(kind) ~= "string" then
        return nil
    end

    local action_type = ACTION_TYPE_BY_KIND[kind]
    if not action_type and string.starts_with(kind, "overload_charge") then
        action_type = "charge"
    end

    return mod.supported_action_type(action_type)
end

function mod.action_type_from_generated_stats(weapon_template, action_name)
    if not weapon_template or type(action_name) ~= "string" then
        return nil
    end

    local displayed_attacks = weapon_template.displayed_attacks
    local statistics_template = weapon_template.displayed_weapon_stats_table
    local damage_actions = statistics_template and statistics_template.damage
    local action_display_order = UISettings.weapon_action_display_order_array

    if not displayed_attacks or not damage_actions or not action_display_order then
        return nil
    end

    for attack_index = 1, #action_display_order do
        local key = action_display_order[attack_index]
        local display_data = displayed_attacks[key]
        local damage_action_table = damage_actions[attack_index]

        if display_data and damage_action_table then
            local attack_chain = display_data.attack_chain
            local fallback_attack_type = display_data.type

            for chain_index = 1, #damage_action_table do
                local damage_action = damage_action_table[chain_index]

                if damage_action and damage_action.action_name == action_name then
                    return attack_chain and attack_chain[chain_index] or fallback_attack_type
                end
            end
        end
    end

    return nil
end

function mod.action_type_from_action_name(weapon_template, action_name)
    if not weapon_template or type(action_name) ~= "string" then
        return nil
    end

    local displayed_attacks = weapon_template.displayed_attacks
    local weapon_action_type_icons = UISettings.weapon_action_type_icons

    if not displayed_attacks or not weapon_action_type_icons then
        return nil
    end

    if action_name == "action_block" and weapon_action_type_icons.defence then
        return "defence"
    elseif action_name == "action_push" and weapon_action_type_icons.melee then
        return "melee"
    elseif string.find(action_name, "activate_special", 1, true) and displayed_attacks.special then
        return displayed_attacks.special.type
    elseif string.find(action_name, "special", 1, true) and displayed_attacks.special then
        return displayed_attacks.special.type
    elseif string.find(action_name, "light", 1, true) and displayed_attacks.primary then
        return displayed_attacks.primary.type
    elseif string.find(action_name, "heavy", 1, true) and displayed_attacks.secondary then
        return displayed_attacks.secondary.type
    end

    return nil
end
