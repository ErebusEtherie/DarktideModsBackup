--[[
Title: Needle Dial
Author: Wobin
Date: 12/12/2025
Repository: https://github.com/Wobin/NeedleDial
Version: 2.0.0
--]]

local mod = get_mod("Needle Dial")
mod.version = "2.0.0"

local Color = Color
local table = table
local equals = table.equals
local Managers = Managers
local ManagersPlayer = Managers.player

local valid_weapons = {
    ["content/items/weapons/player/melee/saw_p1_m1"]  =             {"slot_primary", "yellow", "magenta"},
    ["content/items/weapons/player/melee/crowbar_p1_m1"] =          {"slot_primary", "terminal_text_body", "magenta"},
    ["content/items/weapons/player/ranged/needlepistol_p1_m1"] =    {"slot_secondary", "yellow", "cyan"},
    ["content/items/weapons/player/ranged/needlepistol_p1_m2"] =    {"slot_secondary", "yellow", "cyan"}
}

mod.game_state = mod:persistent_table("gameState", {})

mod.init = function()
    mod:hook_safe(CLASS.HudElementPlayerWeapon,"update", function(self)            
        if self._parent._player._profile.archetype.name == "broker" and self._slot_name == (valid_weapons[self._weapon_name] and valid_weapons[self._weapon_name][1] or "") and self._slot_component.special_active ~= nil then        
            local special_active = self._slot_component.special_active
            local icon_widget = self._widgets_by_name.icon
            local icon_style = icon_widget.style.icon
            local settings = valid_weapons[self._weapon_name]
            
            local inactive = Color[settings[2]](255, true)
            local active = Color[settings[3]](255, true)

            if (special_active and not equals(icon_style.color, active)) or (not special_active and not equals(icon_style.color, inactive)) then            
                icon_style.color = special_active and active or inactive                        
                icon_widget.dirty = true                    
            end                          
        end    
    end)    
    mod.initialized = true    
end

mod.on_game_state_changed = function(status, state_name)        
    if not mod.initialized and status == "enter" and state_name == "GameplayStateRun" then            
        if ManagersPlayer:local_player(1)._profile.archetype.name == "broker" then
            mod:init()
        end
    end
    mod.game_state.status = status
    mod.game_state.state_name = state_name    
end

mod.on_all_mods_loaded = function()
    mod:info(mod.version)
    if mod.game_state.status and mod.game_state.state_name then        
        mod.on_game_state_changed(mod.game_state.status, mod.game_state.state_name)
    end
end

