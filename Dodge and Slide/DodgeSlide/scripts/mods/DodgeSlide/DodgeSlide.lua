local mod = get_mod("DodgeSlide")

local PlayerCharacterStateDodging = require("scripts/extension_systems/character_state_machine/character_states/player_character_state_dodging")
local PlayerCharacterStateSprinting = require("scripts/extension_systems/character_state_machine/character_states/player_character_state_sprinting")
local is_hold_to_crouch = Managers.save:account_data().input_settings["hold_to_crouch"]
local is_sprinting = false
local is_dodging = false
local crouch = false
local shift = false

mod:hook_safe(PlayerCharacterStateSprinting, "on_enter", function(self, unit, dt, t, previous_state, params)
    is_sprinting = true
end)

mod:hook_safe(PlayerCharacterStateSprinting, "on_exit", function(self, unit, t, next_state)
    is_sprinting = false
end)

mod:hook_safe(PlayerCharacterStateDodging, "on_enter", function(self, unit, dt, t, previous_state, params)
    is_dodging = true
end)

mod:hook_safe(PlayerCharacterStateDodging, "on_exit", function(self, unit, t, next_state)
    is_dodging = false
end)

mod:hook_safe(CLASS.EventManager, "trigger", function(self, event_name, ...)
    if event_name == "event_on_input_settings_changed" then
        is_hold_to_crouch = Managers.save:account_data().input_settings["hold_to_crouch"]
    end
end)

local input_action_hook = function(func, self, action_name)
    local result = func(self, action_name)
    if action_name == "sprinting" then
        shift = result
    end
    if action_name == "dodge" and result and (is_sprinting or (is_dodging and shift)) then
        crouch = true
        return false
    end
    if crouch then
         if is_hold_to_crouch and action_name == "crouching" then
            crouch = false
            return true
        elseif not is_hold_to_crouch and action_name == "crouch" then
            crouch = false
            return true
        end
    end
    return result
end

mod:hook(CLASS.InputService, "_get", input_action_hook)
mod:hook(CLASS.InputService, "_get_simulate", input_action_hook)