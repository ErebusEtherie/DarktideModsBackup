local mod = get_mod("helbore_passive_charge")

-- State variables
local is_enabled = true
local wielding_charge = false
local currently_aiming = false
local next_release = false
local next_release_forced = false
local can_release_again = true

mod:io_dofile("helbore_passive_charge/scripts/mods/helbore_passive_charge/create_ui")

-- Toggle function
mod._toggle_select = function()
    if wielding_charge then 
        is_enabled = not is_enabled
    end
    local hud_elem = mod:get_hud_element()
    if hud_elem then
        hud_elem:set_active(is_enabled)
    end
end

-- Update wielding_charge on weapon switch
mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self, slot_name, ...)
    if self._player == Managers.player:local_player(1) then
        local wep_template = self._weapons[slot_name].weapon_template
        wielding_charge = wep_template.displayed_attacks
                        and wep_template.displayed_attacks.primary.type == "charge"
                        and wep_template.actions.vent == nil
    else
        wielding_charge = false
    end    
    local hud_elem = mod:get_hud_element()
    if hud_elem then
        hud_elem:set_enabled(wielding_charge)
    end
end)

-- Get local player unit
local _get_player_unit = function()
    local plr = Managers.player and Managers.player:local_player(1)
    return plr and plr.player_unit
end

-- Direct input detection for M2 (secondary fire)
local _input_action_hook = function(func, self, action_name)
    local val = func(self, action_name)

    if not is_enabled then
        return val
    end

    -- Track secondary fire key directly
    if action_name == "action_two_hold" then
        currently_aiming = wielding_charge and val
    end

    -- Original LMB charge logic
    local is_lmb_action = action_name == "action_one_hold"
    local lmb_release_action_pressed = action_name == "action_one_release" and val

    if wielding_charge then
        if is_lmb_action and can_release_again then
            
            if next_release_forced then
                next_release_forced = false
                return false
            end

            if next_release then
                next_release = false
                can_release_again = false
                return false
            end

            if currently_aiming then
                if val then
                    next_release = true
                end
                return true
            end
        elseif lmb_release_action_pressed and not can_release_again then
            next_release_forced = true
            can_release_again = true
            return true
        end
    end

    return val
end

-- Hook input service
mod:hook(CLASS.InputService, "_get", _input_action_hook)
mod:hook(CLASS.InputService, "_get_simulate", _input_action_hook)