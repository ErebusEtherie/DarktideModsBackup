local mod = get_mod("vfx_swapper")

local DEBUG_VFX_LOGGING = false
local DEBUG_TWIN_MINE = false  
local DEBUG_TOXIN_DEATH = false

local DEBUG_LOGGING = false

local BLOCKED_VFX = {
    ["content/fx/particles/impacts/flesh/nurgle_corruption_death"] = true,
    ["content/fx/particles/enemies/rotten_armor_death"] = true,
    ["content/fx/particles/enemies/bolstering_shockwave"] = true,
}
local BLOCKED_VFX_RPC = {
    ["primer_explosion"] = true,
    ["primer_gas"] = true,
    ["primer_stun"] = true,
}
local function debug_log(message)
    if DEBUG_LOGGING then
        mod:echo("[AdditionalVFX] " .. message)
    end
end



-- ============================================================================
-- Block Toxin Death Explosion VFX (From Chem-grenade and Explosive Needler)
-- ============================================================================

mod:hook("WeaponSystem", "rpc_trigger_husk_explosion", function(func, self, channel_id, explosion_template_id, position, rotation, radius_variable_value, weapon_charge_level, optional_attacking_owner_unit_id)
        -- Lookup explosion template name from network ID
    local explosion_template_name = NetworkLookup.explosion_templates[explosion_template_id]
    if mod:get("disable_toxin_death_vfx") and BLOCKED_VFX_RPC[explosion_template_name] then
        return
    end
        
        -- Not a primer explosion, call original
    return func(self, channel_id, explosion_template_id, position, rotation, radius_variable_value, weapon_charge_level, optional_attacking_owner_unit_id)
end)
    
    -- hook create_husk_explosion for solo/psykhanium (not working because reasons ¯\_(ツ)_/¯)
-- mod:hook("Explosion", "create_husk_explosion", function(func, world, physics_world, wwise_world, attacking_owner_unit_or_nil, explosion_template, position, rotation, radius_variables, charge_level)
--         -- Check explosion template name
--     if explosion_template then
--         mod:echo("[BLOCKING HUSK] " .. tostring(explosion_template))
--             -- Don't play VFX
--         return
--     end
        
--         -- Not blocked, call original
--     return func(world, physics_world, wwise_world, attacking_owner_unit_or_nil, explosion_template, position, rotation, radius_variables, charge_level)
-- end)

-- ============================================================================
-- Havoc VFX Blocking Hooks
-- ============================================================================

mod:hook("FxSystem", "trigger_vfx", function(func, self, vfx_name, position, optional_rotation, ...)
    -- if DEBUG_VFX_LOGGING and vfx_name then
    --     debug_log("[VFX] " .. tostring(vfx_name))
    -- end
    
    if mod:get("disable_death_vfx") then
        if BLOCKED_VFX[vfx_name] then
            -- if DEBUG_VFX_LOGGING then
            --     debug_log("[FxSystem BLOCKED] " .. tostring(vfx_name))
            -- end
            return
        end
    end
    
    -- Call original for all other VFX
    return func(self, vfx_name, position, optional_rotation, ...)
end)

-- Hook RPC handler to block VFX sent from server in multiplayer
mod:hook("FxSystem", "rpc_trigger_vfx", function(func, self, channel_id, vfx_id, position, optional_rotation)
    -- Lookup the vfx_name from the network ID
    local vfx_name = NetworkLookup.vfx[vfx_id]
    
    -- Skip blocked VFX
    if mod:get("disable_death_vfx") then
        if vfx_name and BLOCKED_VFX[vfx_name] then
            -- if DEBUG_VFX_LOGGING then
            --     debug_log("[FxSystem RPC BLOCKED] " .. tostring(vfx_name))
            -- end
            return
        end
    end
    
    return func(self, channel_id, vfx_id, position, optional_rotation)
end)

-- block rotten_armor_stages effect template
mod:hook("FxSystem", "start_template_effect", function(func, self, template, optional_unit, optional_node, optional_position)
    local template_name = template and template.name

    if mod:get("disable_rotten_armor_stages") then
        if template_name == "mutator_rotten_armor_stages" then
            return
        end
    end
    return func(self, template, optional_unit, optional_node, optional_position)
end)

-- block rotten_armor_stages as client 
mod:hook("FxSystem", "rpc_start_template_effect", function(func, self, channel_id, buffer_index, template_id, optional_unit_id, optional_node, optional_position)
    local template_name = NetworkLookup.effect_templates[template_id]

    if mod:get("disable_rotten_armor_stages") then
        if template_name == "mutator_rotten_armor_stages" then
            return
        end
    end
    return func(self, channel_id, buffer_index, template_id, optional_unit_id, optional_node, optional_position)
end)

--  rampaging and corrupted enemies

local BOLSTERING_COLOR = {
	0.98,
	0.27,
	0,
}
local BOLSTER_1_COLOR = {
	BOLSTERING_COLOR[1] * 0.25,
	BOLSTERING_COLOR[2] * 0.25,
	BOLSTERING_COLOR[3] * 0.25,
}
local BOLSTER_2_COLOR = {
	BOLSTERING_COLOR[1] * 0.35,
	BOLSTERING_COLOR[2] * 0.35,
	BOLSTERING_COLOR[3] * 0.35,
}
local BOLSTER_3_COLOR = {
	BOLSTERING_COLOR[1] * 0.65,
	BOLSTERING_COLOR[2] * 0.65,
	BOLSTERING_COLOR[3] * 0.65,
}
local BOLSTER_4_COLOR = {
	BOLSTERING_COLOR[1] * 0.85,
	BOLSTERING_COLOR[2] * 0.85,
	BOLSTERING_COLOR[3] * 0.85,
}
local HavocTemplates = require("scripts/settings/buff/havoc_buff_templates")
local BuffSettings = require("scripts/settings/buff/buff_settings")
local minion_effects_priorities = BuffSettings.minion_effects_priorities
mod.havoc_enemy_vfx = function(self)
    if mod:get("disable_rampaging_vfx") then
        HavocTemplates.havoc_bolstering.minion_effects.node_effects_priotity = nil
        HavocTemplates.havoc_bolstering.minion_effects.stack_material_vectors = nil
        HavocTemplates.havoc_bolstering.minion_effects.stack_node_effects = nil
        HavocTemplates.havoc_bolstering.minion_effects.material_vector = nil
    else 
        HavocTemplates.havoc_bolstering.minion_effects = {
		node_effects_priotity = minion_effects_priorities.mutators,
		stack_material_vectors = {
			material_vector = {
				name = "stimmed_color",
				value = BOLSTER_1_COLOR,
				priority = minion_effects_priorities.mutators,
			},
			material_vector = {
				name = "stimmed_color",
				value = BOLSTER_2_COLOR,
				priority = minion_effects_priorities.mutators,
			},
			material_vector = {
				name = "stimmed_color",
				value = BOLSTER_3_COLOR,
				priority = minion_effects_priorities.mutators,
			},
			material_vector = {
				name = "stimmed_color",
				value = BOLSTER_4_COLOR,
				priority = minion_effects_priorities.mutators,
			},
			material_vector = {
				name = "stimmed_color",
				value = BOLSTERING_COLOR,
				priority = minion_effects_priorities.mutators,
			},
		},
		stack_node_effects = {
			[5] = {
				    node_name = "j_lefteye",
				    vfx = {
					    orphaned_policy = "stop",
					    particle_effect = "content/fx/particles/enemies/red_glowing_eyes",
					    stop_type = "destroy",
				        material_variables = {
					    {
						    material_name = "eye_socket",
						    variable_name = "material_variable_21872256",
						    value = BOLSTERING_COLOR,
					    },
					    {
						    material_name = "eye_glow",
						    variable_name = "trail_color",
						    value = BOLSTERING_COLOR,
					    },
					    {
						    material_name = "eye_glow",
						    variable_name = "material_variable_21872256_69bf7e2a",
						    value = BOLSTER_1_COLOR,
					    },
				    },
			    },
		    },
		    {
			        node_name = "j_righteye",
			        vfx = {
				        orphaned_policy = "stop",
				        particle_effect = "content/fx/particles/enemies/red_glowing_eyes",
				        stop_type = "destroy",
				        material_variables = {
				        {
					        material_name = "eye_socket",
					        variable_name = "material_variable_21872256",
					        value = BOLSTERING_COLOR,
					    },
					    {
					        material_name = "eye_glow",
					        variable_name = "trail_color",
					        value = BOLSTERING_COLOR,
					    },
					    {
					        material_name = "eye_glow",
					        variable_name = "material_variable_21872256_69bf7e2a",
						value = BOLSTERING_COLOR,
					    },
				    },
			    },
		    },
		},
		material_vector = {
				name = "stimmed_color",
				value = BOLSTER_1_COLOR,
				priority = minion_effects_priorities.mutators,
			},
	    }
    end
    
    if mod:get("disable_corrupted_enemies_vfx") then
        HavocTemplates.havoc_corrupted_enemies.minion_effects.node_effects = nil
    end
end

--  corrupted enemies color
mod:hook("Unit", "set_vector3_for_materials", function(func, unit, material_name, color, ...)
    if mod:get("disable_corrupted_enemies_color") then
        if material_name == "stimmed_color" and color then
            -- debug_log(material_name .. " " .. tostring(color)) --[[ TODO: remove ]]
            local r, g, b = Vector3.to_elements(color)
            local tolerance = 0.001
            if (math.approximately_equal(r, 0.3725, tolerance) and math.approximately_equal(g, 0.6823, tolerance) and math.approximately_equal(b, 0.0, tolerance)) then
                return 
            end
        end
    end
    return func(unit, material_name, color, ...)
end)

--  rotten armor impact vfx (leak)
mod:hook("MinionBuffExtension", "has_keyword", function(func, self, keyword)
    if mod:get("disable_rotten_armor_impact") and keyword == "rotten_armor" then
        return false
    end
    return func(self, keyword)
end)


-- ============================================================================
-- Rotten Armor Impact FX (For TEAMMATE'S attacks on rotten armor - potentially hurt performance?)
-- ============================================================================

--
-- Only runs for NETWORKED impacts (teammate attacks)
-- if mod:get("disable_rotten_armor_impact") then
--     mod:hook("FxSystem", "rpc_play_impact_fx", function(func, self, channel_id, impact_fx_name_id, position, ...)
--         -- Lookup the impact fx name from network ID
--         local impact_fx_name = NetworkLookup.impact_fx_names[impact_fx_name_id]
        
--         -- Check if it's rotten armor (simple string check)
--         if impact_fx_name and impact_fx_name:find("rotten_armor") then
--             -- early return
--             return
--         end
        
--         -- Not rotten armor, call original
--         return func(self, channel_id, impact_fx_name_id, position, ...)
--     end)
-- end