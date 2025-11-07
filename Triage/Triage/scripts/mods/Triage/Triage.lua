--[[
Title: Triage
Author: Wobin
Date: 02/10/2025
Repository: https://github.com/Wobin/Triage
Version: 1.1
--]]
local mod = get_mod("Triage")

local CLASS = CLASS
local Managers = Managers
local ScriptUnit = ScriptUnit
local PlayerManager = Managers.player
local HasExtension = ScriptUnit.has_extension

local health_syringe = "content/items/pocketable/syringe_corruption_pocketable"

mod.targets = {}
mod.outlined = {}

local targets = mod.targets
local outlined = mod.outlined

mod.on_game_state_changed = function()
    mod:clean_outline()    
    mod.wielding = nil
end

mod.clean_outline = function()
    local outline_system = Managers.state and Managers.state.extension and Managers.state.extension:system("outline_system")
    if not outline_system then return end
    for player, _ in pairs(outlined) do                           
        outline_system:remove_outline(player, "triage")
        outline_system:remove_outline(player, "triage_health")
    end
    targets = {}
    outlined = {}
end

mod:hook_require("scripts/settings/outline/outline_settings", function(settings)    
     settings.PlayerUnitOutlineExtension.triage = {
        priority = 1,
        color = {0,0,1},
        material_layers = {
            "player_outline_knocked_down",
            "player_outline_knocked_down_reversed_depth"
        },
        visibility_check = function(unit) return targets[unit] == "wound" end
    }
    settings.PlayerUnitOutlineExtension.triage_health = {
        priority = 1,
        color = {1,0,0},
        material_layers = {
            "player_outline_knocked_down",
            "player_outline_knocked_down_reversed_depth"
        },
        visibility_check = function(unit) return targets[unit] == "health" end
    }
end)

local throttle = 0
mod.update = function(dt)
    if not mod.wielding then 
        if next(outlined, nil) then 
            mod:clean_outline()
        end
        return             
    end
    if dt + throttle < 1 then 
        throttle = throttle + dt
        return             
    end
    throttle = 0
    mod:check_health()
end
   
mod.check_health = function()  
    local players = PlayerManager:players()
    for _, player in pairs(players) do
        if player then
            local health_sys = HasExtension(player.player_unit, "health_system")
            local corrupted = health_sys and health_sys:permanent_damage_taken_percent() 
            local max_wounds = health_sys and health_sys:max_wounds()           
            local health_percent = health_sys and health_sys:current_health_percent()           
            
            if not health_sys then return end
            targets[player.player_unit] = nil
            if  ( health_percent < (mod:get("health_threshold")/100)) then
                targets[player.player_unit] = "health"                
            end
            if (corrupted > 0 and  corrupted >= (1 - 1 / max_wounds)) then                                  
                targets[player.player_unit] = "wound"                               
            end                    
        end    
    end
end

mod:hook_safe(CLASS.ActionHandler, "start_action", function(self, _, _, action_name)            
        
        local outline_system = Managers.state and Managers.state.extension:system("outline_system")
        local players = PlayerManager:players()    
        if (action_name == "action_wield" or action_name == "action_aim") and self._inventory_component[self._inventory_component.wielded_slot] == health_syringe then
            mod.wielding = true
	        for _, player in pairs(players) do           
			    outline_system:add_outline(player.player_unit, "triage")
                outline_system:add_outline(player.player_unit, "triage_health")
                outlined[player.player_unit] = true
            end
        else
            mod:clean_outline()            
            mod.wielding = false
        end
end)

