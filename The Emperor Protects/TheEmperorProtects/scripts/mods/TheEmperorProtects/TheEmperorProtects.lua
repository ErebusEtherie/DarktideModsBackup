local mod = get_mod("TheEmperorProtects")

local BuffSettings = require("scripts/settings/buff/buff_settings")
local keywords = BuffSettings.keywords

-- Settings
local mod_settings = {
    toggle_mod = mod:get("toggle_mod"),
    prevent_overload = mod:get("prevent_overload"),
    allow_when_warp_unbound_active = mod:get("allow_when_warp_unbound_active"),
    allow_when_venting_shriek_available = mod:get("allow_when_venting_shriek_available"),
    allow_when_scriers_gaze_available = mod:get("allow_when_scriers_gaze_available"),
    auto_use_ability = mod:get("auto_use_ability"),
}

-- Constants
local TIME_MARGIN = 0.1

local WARP_WEAPON_ACTION_DELAYS = {
    action_one_pressed = {
        forcestaff_p1_m1 = {
            fire_delay = 0.21,
            charge_fire_delay = 0.5,
        },
        forcestaff_p2_m1 = {
            fire_delay = 1.15,
            charge_fire_delay = 0.9,
        },
        forcestaff_p3_m1 = {
            fire_delay = 0.21,
            charge_fire_delay = 1.1,
        },
        forcestaff_p4_m1 = {
            fire_delay = 0.21,
            charge_fire_delay = 0.2,
        },
        psyker_throwing_knives = {
            fire_delay = 0.38,
            charge_fire_delay = 0.69,
        },
    },
    action_one_hold = {
        psyker_smite = 0.2,
        forcesword_p1_m1 = 0.55,
        forcesword_p1_m2 = 0.55,
        forcesword_p1_m3 = 0.55,
        forcesword_2h_p1_m1 = 0.55,
        forcesword_2h_p1_m2 = 0.55,
    },
    action_two_hold = {
        forcestaff_p1_m1 = 0,
        forcestaff_p2_m1 = 0,
        forcestaff_p3_m1 = 0,
        forcestaff_p4_m1 = 0,
    },
    weapon_extra_pressed = {
        forcesword_p1_m1 = 0.6,
        forcesword_p1_m2 = 0.6,
        forcesword_p1_m3 = 0.6,
        forcesword_2h_p1_m1 = 0.7,
        forcesword_2h_p1_m2 = 0.7,
        laspistol_p1_m1 = 0.6,
        laspistol_p1_m3 = 0.6,
    }
}

local SMITE_WEAPON_NAMES = {
    psyker_smite = true,
    psyker_throwing_knives = true,
}

local STAFF_WEAPON_NAMES = {
    forcestaff_p1_m1 = true,
    forcestaff_p2_m1 = true,
    forcestaff_p3_m1 = true,
    forcestaff_p4_m1 = true,
}

local BOLT_STAFF_WEAPON_NAMES = {
    forcestaff_p1_m1 = true,
    forcestaff_p3_m1 = true,
    forcestaff_p4_m1 = true,
}

local FORCE_SWORD_WEAPON_NAMES = {
    forcesword_p1_m1 = true,
    forcesword_p1_m2 = true,
    forcesword_p1_m3 = true,
    forcesword_2h_p1_m1 = true,
    forcesword_2h_p1_m2 = true,
}

local CHARGE_WEAPON_NAMES = {
    forcestaff_p1_m1 = true,
    forcestaff_p2_m1 = true,
    forcestaff_p3_m1 = true,
    forcestaff_p4_m1 = true,
    psyker_throwing_knives = true,
}

local CHARGE_ACTION_NAMES = {
    action_charge = true,
    action_charge_flame = true,
    action_zoom = true,
    action_rapid_zoomed = true,
}

local SMITE_TARGETING_ACTION_NAMES = {
    action_charge_target_sticky = true,
    action_charge_target_lock_on = true,
}

local WEAPON_PERIL_THRESHOLDS = {
    forcestaff_p1_m1 = 0.08,
    forcestaff_p2_m1 = 0.06,
    forcestaff_p3_m1 = 0.08,
}

local FORCE_VENT_WEAPON_NAMES = {
    psyker_throwing_knives = true,
    forcestaff_p1_m1 = true,
    forcestaff_p2_m1 = true,
    forcestaff_p3_m1 = true,
    forcestaff_p4_m1 = true,
}

local FORCE_VENT_ACTION_NAMES = {
    action_rapid_right = true,
    action_charge_flame = true,
    action_charge = true,
}

local VENTING_SHRIEK_ABILITY_NAMES = {
    psyker_discharge_shout = true,
    psyker_discharge_shout_improved = true,
}

local SCRIERS_GAZE_ABILITY_NAMES = {
    psyker_overcharge_stance = true,
}

local class_name = nil

local player_buff_extension = nil
local weapon_action_component = nil
local warp_charge_component = nil
local equipped_abilities_component = nil
local combat_ability_component = nil
local exploding_character_state_component = nil

local is_charging = false
local is_smite_targeting = false

local starting_warp_charge_percent = 1

local warp_unbound_should_active = false

local function get_player_data_extension()
    local player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "unit_data_system")
end

local function get_player_buff_extension()
    local player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "buff_system")
end

local function init_class_name()
    local player = Managers.player:local_player_safe(1)
    local result = player and player:archetype_name()
    if result then
        class_name = result
    end
end

local function init_extensions()
    player_buff_extension = get_player_buff_extension()
end

local function init_components(player_data_extension)
    player_data_extension = player_data_extension or get_player_data_extension()
    if not player_data_extension then
        return
    end

    weapon_action_component             = player_data_extension:read_component("weapon_action")
    warp_charge_component               = player_data_extension:read_component("warp_charge")
    equipped_abilities_component        = player_data_extension:read_component("equipped_abilities")
    combat_ability_component            = player_data_extension:read_component("combat_ability")
    exploding_character_state_component = player_data_extension:read_component("exploding_character_state")
end

local function reset_components()
    weapon_action_component = nil
    warp_charge_component = nil
    equipped_abilities_component = nil
    combat_ability_component = nil
    exploding_character_state_component = nil
end

local function init_context()
    init_class_name()
    init_extensions()
    init_components()
end

local function reset_context()
    is_charging = false
    is_smite_targeting = false
    starting_warp_charge_percent = 1
    warp_unbound_should_active = false
end

mod.on_enabled = function()
    init_context()
end

mod.on_disabled = function()
    reset_context()
end

mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then

        elseif status == "exit" then
            reset_context()
        end
    end
end

mod.on_setting_changed = function(setting_id)
    local result = mod:get(setting_id)
    mod_settings[setting_id] = result
end

mod.toggle_mod = function()
    mod:notify("The Emperor Protects " .. (not mod_settings.toggle_mod and "Enabled" or "Disabled"))
    mod:set("toggle_mod", not mod_settings.toggle_mod, true)
end

local last_ping = 0
mod:hook_safe("PingReporter", "_take_measure", function(self, dt)
    last_ping = (self._measures[#self._measures] or 0) / 1000
end)

local function on_action_start(id, component, action_name, running_action)
    if id == "weapon_action" then
        local weapon_name = component.template_name
        if CHARGE_WEAPON_NAMES[weapon_name] and CHARGE_ACTION_NAMES[action_name] then
            is_charging = true
        elseif weapon_name == "psyker_smite" and SMITE_TARGETING_ACTION_NAMES[action_name] then
            is_smite_targeting = true
            starting_warp_charge_percent = running_action._starting_warp_charge_percent or 1
        end
    end
end

local function on_action_finish(id)
    if id == "weapon_action" then
        is_charging = false
        is_smite_targeting = false
    end
end

mod:hook_safe(CLASS.ActionHandler, "start_action",
    function(self, id, action_objects, action_name, action_params, action_settings, used_input, t, transition_type,
             condition_func_params, automatic_input, reset_combo_override)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        local handler_data = self._registered_components[id]
        on_action_start(id, handler_data.component, action_name, handler_data.running_action)
    end)

mod:hook_safe(CLASS.ActionHandler, "server_correction_occurred",
    function(self, id, action_objects, action_params, actions)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        local handler_data = self._registered_components[id]
        local component = handler_data.component
        local current_action_name = component.current_action_name
        if current_action_name == "none" then
            on_action_finish(id)
        else
            on_action_start(id, component, current_action_name, handler_data.running_action)
        end
    end)

mod:hook_safe(CLASS.ActionHandler, "_finish_action",
    function(self, handler_data, reason, data, t, next_action_params, condition_func_params)
        local id = handler_data.id
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        on_action_finish(id)
    end)

local function is_warp_unbound_active(buff_extension, action_delay)
    if warp_unbound_should_active then
        return true
    end

    if not buff_extension:has_keyword(keywords.psychic_fortress) then
        return false
    end

    local buffs = buff_extension._buffs
    for i = 1, #buffs do
        local buff = buffs[i]
        if buff._template_name == "psyker_overcharge_stance_cool_off" or buff._template_name == "psyker_overcharge_stance_infinite_casting" then
            local duration = buff:duration()
            local duration_progress = buff:duration_progress()
            local remaining_time = duration * duration_progress
            if remaining_time > action_delay + last_ping + TIME_MARGIN then
                return true
            end
        end
    end

    return false
end

local function peril_multiplier()
    local stat_buffs = player_buff_extension and player_buff_extension:stat_buffs()
    local buff_multiplier = stat_buffs and stat_buffs.warp_charge_amount * stat_buffs.warp_charge_over_time_amount or 1
    return buff_multiplier
end

local function is_venting_shriek_ready()
    if not equipped_abilities_component or not combat_ability_component then
        return false
    end

    return VENTING_SHRIEK_ABILITY_NAMES[equipped_abilities_component.combat_ability]
        and combat_ability_component.cooldown == 0 and combat_ability_component.num_charges >= 1
end

local function is_scriers_gaze_ready()
    if not equipped_abilities_component or not combat_ability_component then
        return false
    end

    return SCRIERS_GAZE_ABILITY_NAMES[equipped_abilities_component.combat_ability]
        and combat_ability_component.cooldown == 0 and combat_ability_component.num_charges >= 1
end

local function prevent_explosion(action_name)
    if not weapon_action_component or not warp_charge_component or not player_buff_extension
        or mod_settings.allow_when_venting_shriek_available and is_venting_shriek_ready()
        or mod_settings.allow_when_scriers_gaze_available and is_scriers_gaze_ready()
    then
        return false
    end

    local weapon_delays = WARP_WEAPON_ACTION_DELAYS[action_name]
    if not weapon_delays then
        return false
    end

    local weapon_name = weapon_action_component.template_name
    local action_delays = weapon_delays[weapon_name]
    if not action_delays then
        return false
    end

    if WEAPON_PERIL_THRESHOLDS[weapon_name] then
        if action_name == "action_two_hold" then
            if weapon_action_component.current_action_name == "none" then
                if warp_charge_component.current_percentage < 1 - WEAPON_PERIL_THRESHOLDS[weapon_name] * peril_multiplier() then
                    return false
                end
            elseif weapon_action_component.current_action_name == "action_shoot_charged_flame" then
                if warp_charge_component.current_percentage < 1 or warp_charge_component.starting_percentage < 1 then
                    return false
                end
            else
                if warp_charge_component.current_percentage < 1 then
                    return false
                end
            end
        else
            if warp_charge_component.current_percentage < 1 then
                return false
            end
        end
    elseif FORCE_SWORD_WEAPON_NAMES[weapon_name] then
        if warp_charge_component.current_percentage < 1 or action_name == "action_one_hold" and weapon_action_component.current_action_name ~= "action_push" then
            return false
        end
    elseif weapon_name == "psyker_smite" then
        if warp_charge_component.current_percentage < 0.97 or is_smite_targeting and starting_warp_charge_percent < 0.97 or player_buff_extension:has_keyword(keywords.psyker_empowered_grenade) then
            return false
        end
    elseif weapon_name == "psyker_throwing_knives" then
        if warp_charge_component.current_percentage < 1 or player_buff_extension:has_keyword(keywords.psyker_empowered_grenade) then
            return false
        end
    else
        if warp_charge_component.current_percentage < 1 then
            return false
        end
    end

    if not mod_settings.allow_when_warp_unbound_active then
        return true
    end

    local action_delay = 0
    if type(action_delays) == "table" then
        action_delay = is_charging and action_delays.charge_fire_delay or action_delays.fire_delay
    else
        action_delay = action_delays
    end

    if is_warp_unbound_active(player_buff_extension, action_delay) then
        return false
    end

    return true
end

local function force_vent(action_name)
    if action_name == "weapon_reload_hold"
        and weapon_action_component and FORCE_VENT_WEAPON_NAMES[weapon_action_component.template_name] and FORCE_VENT_ACTION_NAMES[weapon_action_component.current_action_name]
        and warp_charge_component and warp_charge_component.current_percentage >= 1
        and player_buff_extension and not is_warp_unbound_active(player_buff_extension, 0)
        and (not mod_settings.allow_when_venting_shriek_available or not is_venting_shriek_ready())
        and (not mod_settings.allow_when_scriers_gaze_available or not is_scriers_gaze_ready())
    then
        return true
    end

    return false
end

local function auto_use_ability(action_name)
    if action_name == "combat_ability_pressed"
        and exploding_character_state_component
        and exploding_character_state_component.is_exploding
        and exploding_character_state_component.reason == "warp_charge"
        and (is_venting_shriek_ready() or is_scriers_gaze_ready())
    then
        return true
    end
end

mod:hook(CLASS.InputService, "_get",
    function(func, self, action_name)
        if mod_settings.toggle_mod and class_name == "psyker" then
            if mod_settings.prevent_overload then
                if prevent_explosion(action_name) then
                    return false
                end
                if force_vent(action_name) then
                    return true
                end
            end
            if mod_settings.auto_use_ability then
                if auto_use_ability(action_name) then
                    return true
                end
            end
        end
        return func(self, action_name)
    end)

mod:hook_safe(CLASS.HumanPlayer, "set_profile",
    function(self)
        if self.viewport_name == "player1" then
            class_name = self:archetype_name()
        end
    end)

mod:hook_safe(CLASS.PlayerUnitBuffExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            player_buff_extension = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitBuffExtension, "delete",
    function(self)
        if self._player.viewport_name == "player1" then
            player_buff_extension = nil
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            init_components(self)
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "destroy",
    function(self)
        if self._player.viewport_name == "player1" then
            reset_components()
        end
    end)

mod:hook_safe(CLASS.Buff, "init",
    function(self)
        if not self._player or self._player.viewport_name ~= "player1" then
            return
        end

        if self._template_name == "psyker_overcharge_stance" then
            warp_unbound_should_active = true
        elseif self._template_name == "psyker_overcharge_stance_cool_off" or self._template_name == "psyker_overcharge_stance_infinite_casting" then
            warp_unbound_should_active = false
        end
    end)
