-- File: weapon_action_details/scripts/mods/weapon_action_details/resources/wad_time.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local WeaponHandlingTemplates = mod:original_require(
    "scripts/settings/equipment/weapon_handling_templates/weapon_handling_templates")
local WeaponTweakTemplates = mod:original_require("scripts/extension_systems/weapon/utilities/weapon_tweak_templates")
local WeaponTweakTemplateSettings = mod:original_require(
    "scripts/settings/equipment/weapon_templates/weapon_tweak_template_settings")
local Localize = Localize

local template_types = WeaponTweakTemplateSettings.template_types
local RELOAD_STAGE_NAME_TEXT_COLOR = "{#color(255,255,255)}"
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET

local RELOAD_STAGE_LOCALIZATION_KEYS = {
    eject_mag = mod.WAD_LOC.ACTION_INTERACTION_UNLOCK,
    remove_canister = mod.WAD_LOC.ACTION_INTERACTION_UNLOCK,
    remove_magazine = mod.WAD_LOC.ACTION_INTERACTION_UNLOCK,
    fit_new_mag = mod.WAD_LOC.ACTION_INTERACTION_INSERT,
    replace_canister = mod.WAD_LOC.ACTION_INTERACTION_INSERT,
    replace_magazine = mod.WAD_LOC.ACTION_INTERACTION_INSERT,
    cock_weapon = mod.WAD_LOC.OBJECTIVE_PSYKHANIUM_PULL_POWER_LEVER_01_HEADER,
    lift_weapon = mod.WAD_LOC.WEAPON_INVENTORY_INSPECT_BUTTON,
    push_down_bullets = mod.WAD_LOC.PUSHING,
    sever_connection = mod.WAD_LOC.TALENT_MENU_TOOLTIP_BUTTON_HINT_REMOVE_LEVEL_FIRST,
}

local ACTION_REPEAT_PATHS_BY_WEAPON_TEMPLATE = {
    dual_stubpistols_p1_m1 = {
        action_special_shoot_right = {
            first_chain_name = "weapon_special",
            repeat_action_name = "action_special_shoot_left",
            return_action_name = "action_special_twirl_left",
            return_chain_name = "shoot_pressed",
        },
    },
    shotpistol_shield_p1_m1 = {
        action_shoot_blocking = {
            first_chain_name = "block_hold",
            minimum_interval = 0.55,
            return_action_name = "action_block_from_shoot",
            return_chain_name = "block_shoot_pressed",
        },
    },
}

local ACTION_INITIAL_PATHS_BY_WEAPON_TEMPLATE = {
    dual_stubpistols_p1_m1 = {
        action_special_shoot_right = {
            chain_name = "shoot_pressed",
            start_action_name = "action_special_twirl_right",
        },
    },
}

mod.ACTION_KIND_TOTAL_TIME_FUNCS = {
    reload_state = function(action)
        return action.total_time
    end,
    toggle_special = function(action)
        return action.total_time
    end,
    toggle_special_with_block = function(action)
        return action.total_time
    end,
}

mod.ACTION_KINDS_WITH_INVERTED_TIMESCALE = {
    overload_charge = true,
    overload_charge_position_finder = true,
    overload_charge_target_finder = true,
    overload_charge_weapon_special = true,
    overload_target_finder = true,
}

local function displayable_time(value)
    return type(value) == "number" and value ~= math.huge and value ~= -math.huge
end

local function resolve_lerp_value_with_flag(value)
    local resolved_value = mod.resolve_lerp_value(value)
    local is_lerp = type(value) == "table" and
        type(value.lerp_basic) == "number" and
        type(value.lerp_perfect) == "number"

    return resolved_value, is_lerp
end

local function reload_stage_display_name(state_name)
    if state_name == "eject_mag_restart" then
        return Localize(mod.WAD_LOC.ACTION_INTERACTION_UNLOCK) .. "•" ..
            Localize(mod.WAD_LOC.GROUP_FINDER_REFRESH_GROUP_LIST_BUTTON)
    end

    local localization_key = RELOAD_STAGE_LOCALIZATION_KEYS[state_name]

    return localization_key and Localize(localization_key) or state_name
end

local function formatted_reload_stage_display_name(state_name)
    return RELOAD_STAGE_NAME_TEXT_COLOR .. reload_stage_display_name(state_name) .. RICH_TEXT_RESET
end

local function reload_stage_remaining_time(reload_state, time_scale)
    local remaining_time = reload_state and reload_state.time

    if not displayable_time(remaining_time) then
        return nil
    end

    local scaled_time = remaining_time / time_scale

    return displayable_time(scaled_time) and scaled_time or nil
end

local function reload_stage_duration_entries(reload_template, states, time_scale)
    local entries = {}
    local total_duration = 0

    for i = 1, #states do
        local state_name = states[i]
        local remaining_time = reload_stage_remaining_time(reload_template[state_name], time_scale)

        if remaining_time then
            entries[#entries + 1] = {
                state_name = state_name,
                remaining_time = remaining_time,
            }
        end
    end

    for i = 1, #entries do
        local entry = entries[i]
        local next_entry = entries[i + 1]
        local next_remaining_time = next_entry and next_entry.remaining_time or 0
        local duration = entry.remaining_time - next_remaining_time

        if displayable_time(duration) and duration > 0 then
            entry.duration = duration
            total_duration = total_duration + duration
        end
    end

    return entries, total_duration
end

local function normalized_reload_stage_duration(duration, total_stage_duration, total_reload_time)
    if not displayable_time(total_reload_time) or total_reload_time <= 0 or total_stage_duration <= 0 then
        return duration
    end

    return duration * total_reload_time / total_stage_duration
end

function mod.add_chain_times(first_chain_time, second_chain_time, first_chain_time_is_lerp,
                             second_chain_time_is_lerp)
    local total_chain_time = 0
    local has_chain_time = false

    if type(first_chain_time) == "number" then
        if not displayable_time(first_chain_time) then
            return nil, first_chain_time_is_lerp or second_chain_time_is_lerp
        end

        total_chain_time = total_chain_time + first_chain_time
        has_chain_time = true
    end

    if type(second_chain_time) == "number" then
        if not displayable_time(second_chain_time) then
            return nil, first_chain_time_is_lerp or second_chain_time_is_lerp
        end

        total_chain_time = total_chain_time + second_chain_time
        has_chain_time = true
    end

    return has_chain_time and total_chain_time or nil, first_chain_time_is_lerp or second_chain_time_is_lerp
end

function mod.action_time_scale(action, weapon_template, weapon_tweak_templates, action_name)
    if not action then
        return 1, false
    end

    local weapon_handling = weapon_tweak_templates and weapon_tweak_templates[template_types.weapon_handling]

    if weapon_handling and weapon_template then
        local _, lerped_identifier = WeaponTweakTemplates.get_template_identifiers(weapon_template,
            template_types.weapon_handling, action_name)
        local action_stats = lerped_identifier and weapon_handling[lerped_identifier]
        local time_scale = action_stats and action_stats.time_scale

        if type(time_scale) == "number" and time_scale > 0 then
            return time_scale, true
        end
    end

    local weapon_handling_template_name = action.weapon_handling_template or "none"
    local weapon_handling_template = WeaponHandlingTemplates[weapon_handling_template_name]
    local time_scale, time_scale_is_lerp = resolve_lerp_value_with_flag(weapon_handling_template and
        weapon_handling_template.time_scale)

    if type(time_scale) == "number" and time_scale > 0 then
        return time_scale, time_scale_is_lerp
    end

    return 1, false
end

local function configured_action_repeat_interval(action, weapon_template, weapon_tweak_templates, action_name)
    local weapon_template_name = weapon_template and weapon_template.name
    local template_paths = weapon_template_name and
        ACTION_REPEAT_PATHS_BY_WEAPON_TEMPLATE[weapon_template_name]
    local repeat_path = template_paths and template_paths[action_name]

    if not repeat_path then
        return nil
    end

    local actions = weapon_template.actions
    local return_action_name = repeat_path.return_action_name
    local return_action = actions and actions[return_action_name]
    local repeat_action_name = repeat_path.repeat_action_name or action_name
    local first_chain = action.allowed_chain_actions and
        action.allowed_chain_actions[repeat_path.first_chain_name]
    local return_chain = return_action and return_action.allowed_chain_actions and
        return_action.allowed_chain_actions[repeat_path.return_chain_name]

    if type(first_chain) ~= "table" or first_chain.action_name ~= return_action_name or
        type(return_chain) ~= "table" or return_chain.action_name ~= repeat_action_name then
        return nil
    end

    local first_time, first_time_is_lerp = mod.scaled_chain_time(action, first_chain.chain_time, weapon_template,
        weapon_tweak_templates, action_name)
    local return_time, return_time_is_lerp = mod.scaled_chain_time(return_action, return_chain.chain_time,
        weapon_template, weapon_tweak_templates, return_action_name)
    local repeat_interval, repeat_interval_is_lerp = mod.add_chain_times(first_time, return_time,
        first_time_is_lerp, return_time_is_lerp)

    if not displayable_time(repeat_interval) or repeat_interval <= 0 then
        return nil
    end

    local minimum_interval = repeat_path.minimum_interval

    return displayable_time(minimum_interval) and math.max(repeat_interval, minimum_interval) or repeat_interval,
        repeat_interval_is_lerp
end

local function configured_action_initial_time(weapon_template, weapon_tweak_templates, action_name)
    local weapon_template_name = weapon_template and weapon_template.name
    local template_paths = weapon_template_name and
        ACTION_INITIAL_PATHS_BY_WEAPON_TEMPLATE[weapon_template_name]
    local initial_path = template_paths and template_paths[action_name]

    if not initial_path then
        return nil
    end

    local actions = weapon_template.actions
    local start_action_name = initial_path.start_action_name
    local start_action = actions and actions[start_action_name]
    local initial_chain = start_action and start_action.allowed_chain_actions and
        start_action.allowed_chain_actions[initial_path.chain_name]

    if type(initial_chain) ~= "table" or initial_chain.action_name ~= action_name then
        return nil
    end

    return mod.scaled_chain_time(start_action, initial_chain.chain_time, weapon_template,
        weapon_tweak_templates, start_action_name)
end

function mod.action_sequence_timing_text(action, weapon_template, weapon_tweak_templates, action_name)
    if type(action) ~= "table" or type(action_name) ~= "string" then
        return nil
    end

    local initial_time, initial_time_is_lerp = configured_action_initial_time(weapon_template,
        weapon_tweak_templates, action_name)
    local repeat_interval, repeat_interval_is_lerp = configured_action_repeat_interval(action, weapon_template,
        weapon_tweak_templates, action_name)

    if not initial_time then
        return nil
    end

    local timing_text = ""

    if initial_time then
        local initial_time_text = mod.format_time(initial_time)

        if initial_time_text then
            timing_text = mod:localize("first_shot") .. " " ..
                (initial_time_is_lerp and mod.format_lerp_value_text(initial_time_text) or initial_time_text)
        end
    end

    if repeat_interval then
        local repeat_interval_text = mod.format_time(repeat_interval)

        if repeat_interval_text then
            repeat_interval_text = mod:localize("repeat_interval") .. " " ..
                (repeat_interval_is_lerp and mod.format_lerp_value_text(repeat_interval_text) or repeat_interval_text)
            timing_text = timing_text ~= "" and timing_text .. "  " .. repeat_interval_text or repeat_interval_text
        end
    end

    return timing_text ~= "" and timing_text or nil
end

function mod.action_rate_of_fire_per_second(action, weapon_template, weapon_tweak_templates, action_name)
    if not action or type(action_name) ~= "string" then
        return nil
    end

    local weapon_handling = weapon_tweak_templates and weapon_tweak_templates[template_types.weapon_handling]
    local weapon_handling_template_name = action.weapon_handling_template or "none"
    local weapon_handling_template = weapon_handling and weapon_handling[weapon_handling_template_name] or
        WeaponHandlingTemplates[weapon_handling_template_name]
    local fire_rate = weapon_handling_template and weapon_handling_template.fire_rate

    if weapon_handling and weapon_template then
        local _, lerped_identifier = WeaponTweakTemplates.get_template_identifiers(weapon_template,
            template_types.weapon_handling, action_name)
        local action_stats = lerped_identifier and weapon_handling[lerped_identifier]

        fire_rate = action_stats and action_stats.fire_rate or fire_rate
    end

    local auto_fire_time = mod.resolve_lerp_value(fire_rate and fire_rate.auto_fire_time)

    if displayable_time(auto_fire_time) and auto_fire_time > 0 then
        return 1 / auto_fire_time
    end

    local configured_repeat_interval = configured_action_repeat_interval(action, weapon_template,
        weapon_tweak_templates, action_name)

    if configured_repeat_interval then
        return 1 / configured_repeat_interval
    end

    local repeat_time = displayable_time(action.total_time) and action.total_time or nil
    local allowed_chain_actions = action.allowed_chain_actions

    if allowed_chain_actions then
        for _, chain_data in pairs(allowed_chain_actions) do
            if type(chain_data) == "table" and chain_data.action_name == action_name then
                local chain_time = chain_data.chain_time

                if displayable_time(chain_time) then
                    repeat_time = repeat_time and math.min(chain_time, repeat_time) or chain_time
                end

                break
            end
        end
    end

    if not repeat_time or repeat_time <= 0 then
        return nil
    end

    local time_scale = mod.action_time_scale(action, weapon_template, weapon_tweak_templates, action_name)
    local repeat_interval = repeat_time / time_scale

    return displayable_time(repeat_interval) and repeat_interval > 0 and 1 / repeat_interval or nil
end

function mod.action_base_total_time(action)
    if not action then
        return nil
    end

    local total_time = action.damage_window_end

    if type(total_time) ~= "number" then
        local total_time_func = mod.ACTION_KIND_TOTAL_TIME_FUNCS[action.kind]

        total_time = total_time_func and total_time_func(action) or action.total_time
    end

    if not displayable_time(total_time) then
        return nil
    end

    return total_time
end

function mod.action_scaled_total_time(action, weapon_template, weapon_tweak_templates, action_name)
    local total_time = mod.action_base_total_time(action)

    if type(total_time) ~= "number" then
        return nil
    end

    local time_scale, time_scale_is_lerp = mod.action_time_scale(action, weapon_template, weapon_tweak_templates,
        action_name)

    total_time = total_time / time_scale

    return displayable_time(total_time) and total_time or nil, time_scale_is_lerp
end

function mod.scaled_chain_time(action, chain_time, weapon_template, weapon_tweak_templates, action_name)
    if not displayable_time(chain_time) then
        return nil
    end

    local time_scale, time_scale_is_lerp = mod.action_time_scale(action, weapon_template, weapon_tweak_templates,
        action_name)
    local scaled_time

    if time_scale < 1 and action and mod.ACTION_KINDS_WITH_INVERTED_TIMESCALE[action.kind] then
        scaled_time = chain_time * time_scale
    else
        scaled_time = chain_time / time_scale
    end

    return displayable_time(scaled_time) and scaled_time or nil, time_scale_is_lerp
end

function mod.action_reload_stages_text(action, weapon_template, weapon_tweak_templates, action_name)
    if not action or action.kind ~= "reload_state" then
        return nil
    end

    local reload_template = weapon_template and weapon_template.reload_template
    local states = reload_template and reload_template.states

    if not states then
        return nil
    end

    local time_scale, time_scale_is_lerp = mod.action_time_scale(action, weapon_template, weapon_tweak_templates,
        action_name)
    local total_reload_time, total_reload_time_is_lerp = mod.action_scaled_total_time(action, weapon_template,
        weapon_tweak_templates, action_name)
    local stage_entries, total_stage_duration = reload_stage_duration_entries(reload_template, states, time_scale)
    local stage_time_is_lerp = time_scale_is_lerp or total_reload_time_is_lerp
    local output = {}
    local num_output = 0

    if total_stage_duration <= 0 then
        return nil
    end

    for i = 1, #stage_entries do
        local stage_entry = stage_entries[i]
        local stage_duration = stage_entry.duration

        if displayable_time(stage_duration) and stage_duration > 0 then
            stage_duration = normalized_reload_stage_duration(stage_duration, total_stage_duration, total_reload_time)

            local stage_time_text = mod.format_time(stage_duration)

            if stage_time_text then
                local reload_state = reload_template[stage_entry.state_name]
                local heat_text = mod.reload_state_heat_text(stage_entry.state_name, reload_state, weapon_template)
                local output_text = formatted_reload_stage_display_name(stage_entry.state_name) .. " (" ..
                    (stage_time_is_lerp and mod.format_lerp_value_text(stage_time_text) or stage_time_text) .. ")"

                if heat_text then
                    output_text = output_text .. " " .. heat_text
                end

                num_output = num_output + 1
                output[num_output] = output_text
            end
        end
    end

    return num_output > 0 and table.concat(output, "\n") or nil
end

function mod.action_total_time(action, previous_time, previous_time_is_lerp, weapon_template, weapon_tweak_templates,
                               action_name)
    local total_time, total_time_is_lerp = mod.action_scaled_total_time(action, weapon_template,
        weapon_tweak_templates, action_name)

    if type(total_time) ~= "number" then
        return nil
    end

    if type(previous_time) == "number" and previous_time > 0 then
        if not displayable_time(previous_time) then
            return nil
        end

        total_time = total_time + previous_time
        total_time_is_lerp = total_time_is_lerp or previous_time_is_lerp
    end

    if not displayable_time(total_time) then
        return nil
    end

    -- Relies on mod.format_time and mod.format_lerp_value_text located in wad_text_utils.lua
    local total_time_text = mod.format_time(total_time)

    return total_time_is_lerp and mod.format_lerp_value_text(total_time_text) or total_time_text
end
