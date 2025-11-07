local mod = get_mod("TraumaOutlines")

local function get_outline_color()
    return mod:get("outline_color")
end

local function get_center_color()
    return mod:get("center_color")
end

local function is_center_only()
    return mod:get("center_only")
end

local function is_center()
    return mod:get("show_center")
end

local function is_player_only()
    return mod:get("player_only")
end

local outlined_units = {}
local center_units = {}

local function get_outline_system()
    return Managers.state.extension and Managers.state.extension:system("outline_system")
end

local function find_enemies_in_radius(center, radius)
    local side_system = Managers.state.extension and Managers.state.extension:system("side_system")
    local player_side = side_system and side_system:get_side_from_name("heroes")
    if not player_side then
        return {}
    end
    local enemy_units_list = player_side:relation_units("enemy")
    local enemy_units_set = {}
    for i = 1, #enemy_units_list do
        local unit = enemy_units_list[i]
        if ALIVE[unit] then
            local pos = Unit.local_position(unit, 1)
            if Vector3.distance(center, pos) <= radius then
                enemy_units_set[unit] = true
            end
        end
    end
    return enemy_units_set
end

mod:hook_require("scripts/extension_systems/visual_loadout/wieldable_slot_scripts/force_staff_aoe_targeting_effects", function(class)
    local old_update_effect_positions = class._update_effect_positions
    
    class._update_effect_positions = function(self, action_settings, position_finder_fx, decal_unit, effect_id, scaling_effect_id, scale_variable_index, source_id, parameter_name)
        
        old_update_effect_positions(self, action_settings, position_finder_fx, decal_unit, effect_id, scaling_effect_id, scale_variable_index, source_id, parameter_name)
        
        if is_player_only() then
            local player = Managers.player:local_player(1)
            if self._owner_unit ~= player.player_unit then
                return
            end
        end
        
        local target_position = self._action_module_position_finder_component.position
        local charge_level = self._action_module_charge_component.charge_level
        local explode_action_name = position_finder_fx.explode_action_name
        local explode_action = self._weapon_actions and self._weapon_actions[explode_action_name]
        if not explode_action or not explode_action.explosion_template then return end
        
        local explosion_template = explode_action.explosion_template
        local stat_buffs = self._buff_extension:stat_buffs()
        local lerp_values = require("scripts/utilities/attack/explosion").lerp_values(self._owner_unit, explosion_template.name, explode_action_name)
        local _, inner_radius = require("scripts/utilities/attack/explosion").radii(explosion_template, 1, lerp_values, "explosion", stat_buffs, self._breed)
        local aoe_radius = charge_level * inner_radius * 0.9
        local center_radius = inner_radius * 0.3
        
        local enemies_set = {}
        if not is_center_only() then
            enemies_set = find_enemies_in_radius(target_position, aoe_radius)
        end
        
        local center_enemies_set = {}
        if is_center() then
            center_enemies_set = find_enemies_in_radius(target_position, center_radius)
        end

        local outline_system = get_outline_system()
        local outline_color = get_outline_color()
        local center_color = get_center_color()
    
        if is_center() then
            for unit, _ in pairs(center_units) do
                if not center_enemies_set[unit] then
                    outline_system:remove_outline(unit, center_color, true)
                    outlined_units[unit] = nil
                    center_units[unit] = nil
                end
            end
            
            for unit, _ in pairs(center_enemies_set) do
                if not center_units[unit] then
                    outline_system:remove_outline(unit, outline_color, true)
                    outline_system:add_outline(unit, center_color, true)
                    center_units[unit] = true
                end
            end
        end

        if not is_center_only() then
            for unit, _ in pairs(outlined_units) do
                if not enemies_set[unit] then
                    outline_system:remove_outline(unit, outline_color, true)
                    outlined_units[unit] = nil
                end
            end

            for unit, _ in pairs(enemies_set) do
                if (not outlined_units[unit]) and (not center_units[unit]) then
                    outline_system:add_outline(unit, outline_color, true)
                    outlined_units[unit] = true
                end
            end
        end
    end
    
    local old_destroy_effects = class._destroy_effects
    class._destroy_effects = function(self, ...)
        if next(outlined_units) or next(center_units) then
            local outline_system = get_outline_system()
            
            if not is_center_only() and next(outlined_units) then
                local outline_color = get_outline_color()
                for unit, _ in pairs(outlined_units) do
                    outline_system:remove_outline(unit, outline_color, true)
                end
                outlined_units = {}
            end
            
            if is_center() and next(center_units) then 
                local center_color = get_center_color()
                for unit, _ in pairs(center_units) do
                    outline_system:remove_outline(unit, center_color, true)
                end
                center_units = {}
            end
        end
        return old_destroy_effects(self, ...)
    end
end)