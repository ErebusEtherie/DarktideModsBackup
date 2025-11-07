--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Auto Vault                                                                      │
│ Mod Description: Automatically vaults over obstables.                                     |
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]
local mod = get_mod("AutoVault")
-- local LedgeVaulting = require("scripts/extension_systems/character_state_machine/character_states/utilities/ledge_vaulting")

-- mod:hook_safe("PlayerCharacterStateJumping", "_check_transition", function(self, unit, t, next_state_params, input_source, velocity_current)
--     local character_state_component = self._character_state_component
-- 	local previous_state_name = character_state_component.previous_state_name
-- 	local dodge_jumping = previous_state_name == "dodging"
--     local can_vault, ledge = LedgeVaulting.can_enter(self._ledge_finder_extension, self._ledge_vault_tweak_values, self._unit_data_extension, self._input_extension, self._visual_loadout_extension)
--     if can_vault then
--         next_state_params.ledge = ledge

--         if self._sprint_character_state_component.is_sprint_jumping then
--             next_state_params.was_sprinting = true
--         end
--         return "ledge_vaulting"
--     end
-- end)

local enabled = true
mod.on_enabled = function() enabled = true f = mod:get("onlyForward") end
mod.on_disabled = function() enabled = false end
local f = false
mod.on_setting_changed = function()
    f = mod:get("onlyForward")
end

mod:hook("InputService", "_get", function(f, s, action_name)
    local x = f(s, action_name)
    if action_name == "jump_held" and enabled then
        if (f(s, "move_forward") == 1 and f) or not f then
            return true
        else
            return false
        end
    end
    -- if x == true or x == 1 then mod:echo(action_name) end
    return x
end)