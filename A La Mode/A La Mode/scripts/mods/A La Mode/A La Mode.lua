--[[
Title: A La Mode
Author: Wobin
Date: 05/04/2026
Repository: https://github.com/Wobin/ALaMode
Version: 3.2.1
--]]

local mod = get_mod("A la Mode")
mod.version = "3.2.1"

local Color = Color

local valid_weapons = mod:io_dofile("A La Mode/scripts/mods/A La Mode/data/weapon_info")

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
                                    mod:get(weapon .. "-color_2") or Color[defaults[3]](255, true),                                    
                                }
        if defaults[4] then
            weapon_colors[weapon][4] = mod:get(weapon .. "-color_3") or Color[defaults[4]](255, true)
        end
    end    
end


local setup = mod:io_dofile("A La Mode/scripts/mods/A La Mode/data/ui")

mod.game_state = mod:persistent_table("gameState", {})

local current_weapons = {}  -- Cache per slot: {slot_primary = {name, weapon, colours}, slot_secondary = {...}}

mod.init = function()
    get_colours()
    mod:hook_safe(CLASS.HudElementPlayerWeapon,"update", function(self)                  
        local slot = self._slot_name
        if not current_weapons[slot] then
            current_weapons[slot] = {}
        end
        local slot_cache = current_weapons[slot]
        if slot_cache.weapon_name ~= self._weapon_name then
            slot_cache.weapon_name = self._weapon_name
            slot_cache.weapon = valid_weapons[self._weapon_name]
            slot_cache.weapon_colours = weapon_colors[self._weapon_name]
            self._alm_last_applied_color = nil 
        end 
        
        local current_weapon = slot_cache.weapon
        local current_weapon_colours = slot_cache.weapon_colours
        
        if slot == ( current_weapon and current_weapon_colours[1] or "") and self._slot_component.special_active ~= nil then        
            
            local special_active = self._slot_component.special_active
            local icon_widget = self._widgets_by_name.icon
            local icon_style = icon_widget.style.icon
            local current_num_activations = self._slot_component.num_special_charges
            
            local inactive =    current_weapon_colours[2]
            local active =      current_weapon_colours[3]
            local cooldown =    current_weapon_colours[4] or nil            
                                 
            local is_cooldown = cooldown and not special_active and current_num_activations == 0
            local target_color = is_cooldown and cooldown or (special_active and active or inactive)
            
            local color_changed = false
            for i = 2, 4 do 
                if icon_style.color[i] ~= target_color[i] then
                    icon_style.color[i] = target_color[i]
                    color_changed = true
                end
            end
            if color_changed then
                icon_widget.dirty = true
            end
            self._alm_last_applied_color = target_color
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