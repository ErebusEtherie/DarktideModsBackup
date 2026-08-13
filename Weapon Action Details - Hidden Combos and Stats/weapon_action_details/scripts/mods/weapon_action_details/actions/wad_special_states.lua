-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_special_states.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Localize = Localize
local AMMO_TEXT_COLOR = "{#color(255,255,255)}"
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET

local NON_SPECIAL_TOGGLE_ACTION_NAMES = {
    action_toggle_flashlight = true,
    action_toggle_flashlight_zoom = true,
}

local SINGLE_USE_WEAPON_SPECIAL_CLASSES = {
    WeaponSpecialExplodeOnImpact = true,
    WeaponSpecialExplodeOnImpactCooldown = true,
    WeaponSpecialSelfDisorientation = true,
    WeaponSpecialShovels = true,
    WeaponSpecialWarpChargedAttacks = true,
}

function mod.action_input_is_weapon_extra(input_name)
    if type(input_name) ~= "string" then
        return false
    end

    for prefix in pairs(mod.WAD_SPECIAL_ACTION_INPUT_PREFIXES) do
        if string.starts_with(input_name, prefix) then
            return true
        end
    end

    return false
end

function mod.action_can_start_from_weapon_extra(action)
    return action and mod.action_input_is_weapon_extra(action.start_input)
end

function mod.action_is_weapon_extra_chain_action(action_name, actions)
    if not action_name or not actions then
        return false
    end

    for _, source_action in pairs(actions) do
        local allowed_chain_actions = type(source_action) == "table" and source_action.allowed_chain_actions

        if allowed_chain_actions then
            for chain_name, chain_data in pairs(allowed_chain_actions) do
                if mod.action_input_is_weapon_extra(chain_name) then
                    local chain_action_count = type(chain_data) == "table" and #chain_data or 0

                    if chain_action_count > 0 then
                        for i = 1, chain_action_count do
                            local chain_action = chain_data[i]

                            if type(chain_action) == "table" and chain_action.action_name == action_name then
                                return true
                            end
                        end
                    elseif type(chain_data) == "table" and chain_data.action_name == action_name then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function mod.action_uses_weapon_extra_input(action_name, action, actions)
    return mod.action_can_start_from_weapon_extra(action) or
        mod.action_is_weapon_extra_chain_action(action_name, actions)
end

function mod.action_is_special_activation(action_name, action)
    if NON_SPECIAL_TOGGLE_ACTION_NAMES[action_name] then
        return false
    end

    local kind = action and action.kind

    return kind and mod.WAD_SPECIAL_ACTIVATION_ACTION_KINDS[kind] == true
end

function mod.weapon_has_special_state_actions(actions)
    if not actions then
        return false
    end

    for action_name, action in pairs(actions) do
        if type(action) == "table" and mod.action_is_special_activation(action_name, action) then
            return true
        end
    end

    return false
end

function mod.action_name_indicates_special_state(action_name)
    if type(action_name) ~= "string" then
        return false
    end

    return string.find(action_name, "_special", 1, true) ~= nil or
        string.find(action_name, "special_", 1, true) ~= nil
end

function mod.action_only_available_in_special_state(action_name, action, actions)
    if mod.action_is_special_activation(action_name, action) or
        mod.action_uses_weapon_extra_input(action_name, action, actions) then
        return false
    end

    return mod.action_name_indicates_special_state(action_name)
end

function mod.action_has_different_special_active_damage_type(action)
    if type(action) ~= "table" then
        return false
    end

    local damage_type = action.damage_type
    local damage_type_special_active = action.damage_type_special_active

    return damage_type ~= nil and damage_type_special_active ~= nil and
        damage_type_special_active ~= damage_type
end

function mod.action_has_different_special_active_damage_profile(action)
    if type(action) ~= "table" then
        return false
    end

    local damage_profile = action.damage_profile
    local damage_profile_special_active = action.damage_profile_special_active

    return damage_profile ~= nil and damage_profile_special_active ~= nil and
        damage_profile_special_active ~= damage_profile
end

function mod.action_has_special_shotshell(action)
    if type(action) ~= "table" then
        return false
    end

    local fire_configuration = action.fire_configuration

    if type(fire_configuration) == "table" and fire_configuration.shotshell_special then
        return true
    end

    local fire_configurations = action.fire_configurations

    if type(fire_configurations) ~= "table" then
        return false
    end

    for i = 1, #fire_configurations do
        fire_configuration = fire_configurations[i]

        if type(fire_configuration) == "table" and fire_configuration.shotshell_special then
            return true
        end
    end

    return false
end

function mod.special_action_ammo_text(action_name, action, weapon_template)
    if type(action_name) ~= "string" or type(action) ~= "table" or type(weapon_template) ~= "table" then
        return nil
    end

    local actions = weapon_template.actions
    local special_action_name = weapon_template.special_action_name

    if type(special_action_name) == "string" then
        if action_name ~= special_action_name then
            return nil
        end
    elseif not mod.action_is_special_activation(action_name, action) and
        not mod.action_uses_weapon_extra_input(action_name, action, actions) then
        return nil
    end

    local tweak_data = weapon_template.weapon_special_tweak_data

    if type(tweak_data) ~= "table" then
        return nil
    end

    local weapon_special_class = weapon_template.weapon_special_class
    local empowered_uses

    if weapon_special_class == "WeaponSpecialDeactivateAfterNumActivations" then
        empowered_uses = tweak_data.num_activations

        local weapon_template_name = weapon_template.name

        if type(empowered_uses) == "number" and type(weapon_template_name) == "string" and
            string.starts_with(weapon_template_name, "powersword_p1_m") then
            empowered_uses = empowered_uses + 2
        end
    elseif tweak_data.keep_active_until_shot_complete == true or
        SINGLE_USE_WEAPON_SPECIAL_CLASSES[weapon_special_class] then
        empowered_uses = 1
    end

    local empowered_uses_text

    if type(empowered_uses) == "number" and empowered_uses > 0 then
        empowered_uses_text = Localize(mod.WAD_LOC.INTERFACE_SETTING_CHAT_BUBBLES_LIFETIME_MULTIPLIER) .. " " ..
            empowered_uses

        local active_duration = tweak_data.active_duration
        local active_duration_text = type(active_duration) == "number" and active_duration > 0 and
            active_duration ~= math.huge and mod.format_time(active_duration)

        if active_duration_text then
            empowered_uses_text = empowered_uses_text .. " (" .. active_duration_text .. ")"
        end
    end

    local capacity = tweak_data.max_num_charges
    local charges_consumed = tweak_data.num_charges_to_consume_on_activation

    if type(capacity) ~= "number" then
        capacity = type(charges_consumed) == "number" and charges_consumed > 0 and tweak_data.max_charges or nil
    end

    local ammo_text

    if type(capacity) == "number" and capacity > 0 then
        local cost_per_use = type(charges_consumed) == "number" and charges_consumed > 0 and
            charges_consumed or 1
        local use_capacity = math.floor(capacity / cost_per_use)

        ammo_text = Localize(mod.WAD_LOC.WEAPON_STAT_TITLE_AMMO) .. " " .. use_capacity
    end

    if empowered_uses_text and ammo_text then
        return AMMO_TEXT_COLOR .. empowered_uses_text .. "  " .. ammo_text .. RICH_TEXT_RESET
    elseif empowered_uses_text then
        return AMMO_TEXT_COLOR .. empowered_uses_text .. RICH_TEXT_RESET
    elseif ammo_text then
        return AMMO_TEXT_COLOR .. ammo_text .. RICH_TEXT_RESET
    end

    return nil
end

function mod.action_condition_func_returns_special_active(action)
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

    return string.find(dumped_func, "inventory_slot_component", 1, true) ~= nil and
        string.find(dumped_func, "special_active", 1, true) ~= nil
end

function mod.action_is_special_state_action(action_name, action)
    if mod.action_is_special_activation(action_name, action) then
        return true
    end

    return mod.action_has_different_special_active_damage_type(action) or
        mod.action_has_different_special_active_damage_profile(action) or
        mod.action_has_special_shotshell(action) or
        mod.action_condition_func_returns_special_active(action)
end

function mod.action_has_only_special_activation_chain_sources(action_name, actions, chain_source_names)
    local source_action_names = chain_source_names and chain_source_names[action_name]

    if not source_action_names then
        return false
    end

    for source_action_name in pairs(source_action_names) do
        if not mod.action_is_special_activation(source_action_name, actions[source_action_name]) then
            return false
        end
    end

    return true
end

function mod.action_has_only_special_activation_windup_chain_sources(action_name, actions, chain_source_names)
    local source_action_names = chain_source_names and chain_source_names[action_name]

    if not source_action_names then
        return false
    end

    for source_action_name in pairs(source_action_names) do
        local source_action = actions[source_action_name]

        if not source_action or source_action.kind ~= "windup" or
            not mod.action_has_only_special_activation_chain_sources(source_action_name, actions,
                chain_source_names) then
            return false
        end
    end

    return true
end

function mod.action_can_only_chain_from_special_activation(action_name, actions, chain_source_names)
    return mod.action_has_only_special_activation_chain_sources(action_name, actions, chain_source_names) or
        mod.action_has_only_special_activation_windup_chain_sources(action_name, actions, chain_source_names)
end

function mod.special_activation_chain_action_names(actions)
    local special_activation_chain_action_names = {}

    if not actions then
        return special_activation_chain_action_names
    end

    local chain_source_names = mod.direct_chain_source_names(actions)

    for action_name, action in pairs(actions) do
        if type(action) == "table" and
            mod.action_can_only_chain_from_special_activation(action_name, actions, chain_source_names) then
            special_activation_chain_action_names[action_name] = true
        end
    end

    return special_activation_chain_action_names
end

function mod.special_state_action_names(actions, special_activation_chain_action_names)
    local special_state_action_names = {}

    if not actions then
        return special_state_action_names
    end

    special_activation_chain_action_names = special_activation_chain_action_names or
        mod.special_activation_chain_action_names(actions)

    for action_name, action in pairs(actions) do
        if type(action) == "table" and
            (mod.action_is_special_state_action(action_name, action) or
                special_activation_chain_action_names[action_name]) then
            special_state_action_names[action_name] = true
        end
    end

    return special_state_action_names
end

function mod.action_matches_filter(action_name, action, action_filter, special_state_action_names,
                                   special_activation_chain_action_names, has_special_actions, actions)
    if action_filter == mod.WAD_ACTION_FILTER_SPECIAL then
        return special_state_action_names and special_state_action_names[action_name] == true
    end

    if has_special_actions and
        (mod.action_condition_func_returns_special_active(action) or
            special_activation_chain_action_names and special_activation_chain_action_names[action_name]) then
        return false
    end

    return not mod.action_only_available_in_special_state(action_name, action, actions) or
        not (special_state_action_names and special_state_action_names[action_name])
end

function mod.special_action_display_name_excluded(weapon_template)
    local excluded_weapon_templates = mod.EXCLUDED_SPECIAL_ACTION_DISPLAY_NAME_WEAPON_TEMPLATES
    local weapon_template_name = weapon_template and weapon_template.name

    return excluded_weapon_templates and excluded_weapon_templates[weapon_template_name]
end

function mod.action_should_use_special_display_name(action_name, action, actions, weapon_template)
    if mod.special_action_display_name_excluded(weapon_template) then
        return false
    end

    local kind = action and action.kind

    if kind ~= "sweep" and kind ~= "weapon_throw" then
        return false
    end

    return mod.action_uses_weapon_extra_input(action_name, action, actions)
end

function mod.add_special_action_display_names(community_action_names, weapon_template, actions)
    local displayed_attacks = weapon_template.displayed_attacks
    local special_display_name = displayed_attacks and displayed_attacks.special and
        displayed_attacks.special.display_name
    local localized_special_display_name = special_display_name and Localize(special_display_name)

    if not localized_special_display_name then
        return
    end

    for action_name, action in pairs(actions) do
        if type(action) == "table" and
            mod.action_should_use_special_display_name(action_name, action, actions, weapon_template) then
            community_action_names[action_name] = localized_special_display_name
        end
    end
end
