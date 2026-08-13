local mod = get_mod("vfx_swapper")

local DEBUG_VFX_LOGGING = false
local DEBUG_TWIN_MINE = false  
local DEBUG_TOXIN_DEATH = false
local DEBUG_LOGGING = false	

local _disable_toxin_death_vfx = false
local _disable_death_vfx = false
local _disable_rotten_armor_stages = false
local _disable_rampaging_vfx = false
local _disable_corrupted_enemies_color = false
local _disable_rotten_armor_impact = false
local _disable_bon_death = false
local _disable_burster_death = false

local BLOCKED_VFX = {
    ["content/fx/particles/impacts/flesh/nurgle_corruption_death"] = true,
    ["content/fx/particles/enemies/rotten_armor_death"] = true,
    ["content/fx/particles/enemies/bolstering_shockwave"] = true,
	["content/fx/particles/enemies/beast_of_nurgle/bon_death_splatter"] = true,
	["content/fx/particles/explosions/poxwalker_explode"] = true,
}

local BLOCKED_VFX_RPC = {
    ["primer_explosion"] = _disable_toxin_death_vfx,
    ["primer_gas"] = _disable_toxin_death_vfx,
    ["primer_stun"] = _disable_toxin_death_vfx,
	["beast_of_nurgle_death"] = _disable_bon_death,
	["poxwalker_bomber"] = _disable_burster_death,
}
local function debug_log(message)
    if DEBUG_LOGGING then
        mod:echo("[AdditionalVFX] " .. message)
    end
end

local function refresh_additionalvfx_cache()
    _disable_toxin_death_vfx = mod:get("disable_toxin_death_vfx")
    _disable_death_vfx = mod:get("disable_death_vfx")
    _disable_rotten_armor_stages = mod:get("disable_rotten_armor_stages")
    _disable_rampaging_vfx = mod:get("disable_rampaging_vfx")
    _disable_corrupted_enemies_color = mod:get("disable_corrupted_enemies_color")
    _disable_rotten_armor_impact = mod:get("disable_rotten_armor_impact")
	_disable_bon_death = mod:get("disable_bon_death")
	_disable_burster_death = mod:get("disable_burster_death")

	BLOCKED_VFX_RPC["primer_explosion"] = _disable_toxin_death_vfx
	BLOCKED_VFX_RPC["primer_gas"] = _disable_toxin_death_vfx
	BLOCKED_VFX_RPC["primer_stun"] = _disable_toxin_death_vfx
	BLOCKED_VFX_RPC["beast_of_nurgle_death"] = _disable_bon_death
	BLOCKED_VFX_RPC["poxwalker_bomber"] = _disable_burster_death
end
mod._refresh_additionalvfx_cache = refresh_additionalvfx_cache
refresh_additionalvfx_cache()

-- ============================================================================
-- Block Toxin Death Explosion VFX (From Chem-grenade and Explosive Needler)
-- ============================================================================

mod:hook("WeaponSystem", "rpc_trigger_husk_explosion", function(func, self, channel_id, explosion_template_id, position, rotation, radius_variable_value, weapon_charge_level, optional_attacking_owner_unit_id)
    local explosion_template_name = NetworkLookup.explosion_templates[explosion_template_id]
	if BLOCKED_VFX_RPC[explosion_template_name] then
        return
    end
    return func(self, channel_id, explosion_template_id, position, rotation, radius_variable_value, weapon_charge_level, optional_attacking_owner_unit_id)
end)

mod:hook_require("scripts/utilities/attack/explosion", function(Explosion)
    mod:hook(Explosion, "create_husk_explosion", function(func, world, physics_world, wwise_world, attacking_owner_unit_or_nil, explosion_template, position, rotation, radius_variables, charge_level)
        -- pre-hook logic
		if BLOCKED_VFX_RPC[explosion_template.name] then
			return
		end
        return func(world, physics_world, wwise_world, attacking_owner_unit_or_nil, explosion_template, position, rotation, radius_variables, charge_level)
		 -- post-hook logic
    end)
end)
-- ============================================================================
-- Havoc VFX Blocking Hooks
-- ============================================================================

mod:hook("FxSystem", "trigger_vfx", function(func, self, vfx_name, position, optional_rotation, ...)
    -- if DEBUG_VFX_LOGGING and vfx_name then
    --     debug_log("[VFX] " .. tostring(vfx_name))
    -- end
    
    if _disable_death_vfx and BLOCKED_VFX[vfx_name] then
        -- if DEBUG_VFX_LOGGING then
        --     debug_log("[FxSystem BLOCKED] " .. tostring(vfx_name))
        -- end
        return
    end
    return func(self, vfx_name, position, optional_rotation, ...)
end)

-- Hook RPC handler to block VFX sent from server in multiplayer
mod:hook("FxSystem", "rpc_trigger_vfx", function(func, self, channel_id, vfx_id, ...)
    local vfx_name = NetworkLookup.vfx[vfx_id]
    if _disable_death_vfx then
        if vfx_name and BLOCKED_VFX[vfx_name] then
            -- if DEBUG_VFX_LOGGING then
            --     debug_log("[FxSystem RPC BLOCKED] " .. tostring(vfx_name))
            -- end
            return
		-- elseif vfx_name then
            -- if DEBUG_VFX_LOGGING then
            --     debug_log("[FxSystem RPC] " .. tostring(vfx_name))
            -- end
        end
    end
    
    return func(self, channel_id, vfx_id, ...)
end)

-- block rotten_armor_stages effect template
mod:hook("FxSystem", "start_template_effect", function(func, self, template, ...)
    local template_name = template and template.name
	if DEBUG_VFX_LOGGING and template_name then
        debug_log("[TEMPLATE] " .. tostring(template_name))
    end
    if _disable_rotten_armor_stages and template_name == "mutator_rotten_armor_stages" then
        return
    end
    return func(self, template, ...)
end)

-- block rotten_armor_stages as client 
mod:hook("FxSystem", "rpc_start_template_effect", function(func, self, channel_id, buffer_index, template_id, ...)
    local template_name = NetworkLookup.effect_templates[template_id]
	if DEBUG_VFX_LOGGING and template_name then
        debug_log("[TEMPLATE RPC] " .. tostring(template_name))
    end
    if _disable_rotten_armor_stages and template_name == "mutator_rotten_armor_stages" then
        return
    end
    return func(self, channel_id, buffer_index, template_id, ...)
end)

mod:hook("MinionBuffExtension", "has_keyword", function(func, self, keyword)
    if _disable_rotten_armor_impact and keyword == "rotten_armor" then
        return false
    end
    return func(self, keyword)
end)
