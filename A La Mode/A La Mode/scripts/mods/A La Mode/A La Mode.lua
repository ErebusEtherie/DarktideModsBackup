--[[
Title: A La Mode
Author: Wobin
Date: 15/12/2025
Repository: https://github.com/Wobin/ALaMode
Version: 3.1.0
--]]

local mod = get_mod("A la Mode")
mod.version = "3.1.0"

local Color = Color
local table = table
local equals = table.equals

local valid_weapons = mod:io_dofile("A La Mode/scripts/mods/A La Mode/data/weapon_info")

-- Storing in a local and calling on start/settings change to avoid overhead on mod:get()
local weapon_colors = {}

local get_colours = function(setting_id)
    if setting_id == "alm_open_setup" then
        mod:set("alm_open_setup", false, false)  
        if mod.setup then
            mod.setup:open()
            return
        end
    end
    weapon_colors = {}
    for weapon,defaults in pairs(valid_weapons)     do
        weapon_colors[weapon] = { ( weapon:match("melee") and "slot_primary" or "slot_secondary"), 
                                    mod:get(weapon .. "-color_1") or Color[defaults[2]](255, true), 
                                    mod:get(weapon .. "-color_2") or Color[defaults[3]](255, true)
                                }
    end    
end


local setup = mod:io_dofile("A La Mode/scripts/mods/A La Mode/data/ui")

mod.game_state = mod:persistent_table("gameState", {})
mod.weapons = {}

mod.init = function()
    get_colours()
    mod:hook_safe(CLASS.HudElementPlayerWeapon,"update", function(self)                    
        if self._slot_name == (valid_weapons[self._weapon_name] and weapon_colors[self._weapon_name][1] or "") and self._slot_component.special_active ~= nil then        
            
            local special_active = self._slot_component.special_active
            local icon_widget = self._widgets_by_name.icon
            local icon_style =  icon_widget.style.icon
            local settings =    weapon_colors[self._weapon_name]
            
            mod.weapons[self._slot_name] = settings

            local inactive =    settings[2]
            local active =      settings[3]

            if (special_active and not equals(icon_style.color, active)) or (not special_active and not equals(icon_style.color, inactive)) then            
                icon_style.color[2] = special_active and active[2] or inactive[2]                        
                icon_style.color[3] = special_active and active[3] or inactive[3]                        
                icon_style.color[4] = special_active and active[4] or inactive[4]                        
                icon_widget.dirty = true                    
            end                          
        end    
    end)            
    mod.initialized = true    
end

mod.on_game_state_changed = function(status, state_name)        
    if not mod.initialized and status == "enter" and state_name == "GameplayStateRun" then            
        mod:init()
    end    
    mod.game_state.status = status
    mod.game_state.state_name = state_name        
end

mod.on_all_mods_loaded = function()
    mod:info(mod.version)
    mod.setup = setup:new()
    if mod.game_state.status and mod.game_state.state_name then        
        mod.on_game_state_changed(mod.game_state.status, mod.game_state.state_name)
    end
    if get_mod("Needle Dial") then
        mod:echo("Please uninstall Needle Dial. A La Mode is the replacement mod")
    end
end

mod.on_setting_changed = get_colours

mod.update = function(dt)
    if mod.setup and mod.setup._is_open then
        mod.setup:update(dt)
    end
end

mod:command("alm", mod:localize("alm_open_setup"), function ()
	mod.setup:open()
end)