local mod = get_mod("vfx_swapper")
local DEBUG_LOGGING = false
local Component = require("scripts/utilities/component")

local function debug_log(message)
    if DEBUG_LOGGING then
        mod:echo("[AdditionalVFX] " .. message)
    end
end
-- ============================================================================
-- Block Toxic Gas Geysers (Corals)
-- ============================================================================

-- The toxic gas geysers (called "corals" in the code) use Unit.flow_event to spawn VFX
mod:hook("Unit", "flow_event", function(func, unit, event_name)

    if event_name and mod:get("disable_coral_vfx") then    
        -- Block toxic gas geyser events
        if event_name == "create_low_gas" or 
           event_name == "create_trigger_gas" or 
           event_name == "despawn_low_gas" then
            debug_log("[BLOCKING GEYSER] " .. tostring(event_name))
            return
        end
    end
    
    -- Block toxic gas fog particles (the persistent cloud)
    if mod:get("disable_toxic_gas") then
        if event_name == "create_particle" or event_name == "destroy_particle" then
            local has_toxic_gas_fog = Component.has_component_by_name(unit, "ToxicGasFog")
            local has_toxic_gas_corals = Component.has_component_by_name(unit, "ToxicGasCorals") 
            if has_toxic_gas_fog or has_toxic_gas_corals then
                debug_log("[BLOCKING PARTICLE] " .. tostring(event_name) .. " (toxic gas unit)")
                return
            end
        end
    end
    
    -- Not a blocked event, call original
    return func(unit, event_name)
end)
        
-- ============================================================================
-- Block Toxic Gas Volumetric Fog (Optional)
-- ============================================================================

mod:hook("Volumetrics", "register_volume", function(func, unit, albedo, extinction, phase, falloff, mesh_name)
    -- Safety check: ensure unit has component extension before querying
    if not ScriptUnit.has_extension(unit, "component_system") then
        return func(unit, albedo, extinction, phase, falloff, mesh_name)
    end
    
    -- Check if this is a toxic gas fog unit
    local has_toxic_gas_fog = Component.has_component_by_name(unit, "ToxicGasFog")
    
    if has_toxic_gas_fog and mod:get("disable_toxic_fog") then
        debug_log("[BLOCKING FOG] register_volume for toxic gas")
        return
    end
    
    -- Not toxic gas, call original
    return func(unit, albedo, extinction, phase, falloff, mesh_name)
end)
