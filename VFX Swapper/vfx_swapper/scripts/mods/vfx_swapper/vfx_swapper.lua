local mod = get_mod("vfx_swapper")
mod:io_dofile("vfx_swapper/scripts/mods/vfx_swapper/additionalvfx")
mod:io_dofile("vfx_swapper/scripts/mods/vfx_swapper/toxicgas")

local DEBUG_LOGGING = false
-- ============================================================================
-- Circle Indicator System (shamelessly stolen from danger_zone)
-- ============================================================================
local decal_path = "content/levels/training_grounds/fx/decal_aoe_indicator"
local package_path = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"

-- Persistent tables for decal tracking
mod._decals = mod:persistent_table("vfx_swapper_decals")

local CIRCLE_TEMPLATES = {
    rotten_armor = "rotten_circle",
    havoc_enemy_corruption_liquid = "blight_circle",
    broker_tox_grenade = "chemnade_circle",
}
local CIRCLE_ONLY_TEMPLATES = {
    broker_tox_grenade = true,
    rotten_armor = true,
    havoc_enemy_corruption_liquid = true,
}
local function get_circle_setting(setting_id)
    return mod:get(setting_id)
end

local function get_circle_rgba(circle_type)
    return get_circle_setting(circle_type .. "_red") / 100,
           get_circle_setting(circle_type .. "_green") / 100,
           get_circle_setting(circle_type .. "_blue") / 100,
           get_circle_setting(circle_type .. "_alpha") / 100
end

local function is_circle_enabled(template_name)
    local circle_type = CIRCLE_TEMPLATES[template_name]
    if not circle_type then return false end
    return get_circle_setting(circle_type .. "_enabled")
end

-- Check if circle-only mode is enabled
local function is_circle_only_mode(template_name)
    if CIRCLE_ONLY_TEMPLATES[template_name] then
        return mod:get("replace_" .. template_name) == "CIRCLE_ONLY"
    end
    return false
end

-- Create a decal
local function create_decal(unit, world, radius, template_name)
    if not is_circle_enabled(template_name) then return nil end
    
    if not Managers.package:has_loaded(package_path) then
        Managers.package:load(package_path, "vfx_swapper", function()
        end)
        return nil
    end
    
    -- Check if decal already exists
    if mod._decals[unit] then return mod._decals[unit] end
    
    local unit_position = POSITION_LOOKUP[unit]
    if not unit_position then return nil end
    
    local circle_only = is_circle_only_mode(template_name)
    local decal_units = {}
    
    -- Main outer circle
    local decal_unit = World.spawn_unit_ex(world, decal_path, nil, unit_position)
    World.link_unit(world, decal_unit, 1, unit, 1)
    table.insert(decal_units, decal_unit)
    
    -- Additional concentric circles for circle-only
    if circle_only then
        -- 2 is enough
        for i = 1, mod:get("circle_count") do
            local mid_decal = World.spawn_unit_ex(world, decal_path, nil, unit_position)
            World.link_unit(world, mid_decal, 1, unit, 1)
            table.insert(decal_units, mid_decal)
        end
    end
    
    mod._decals[unit] = {
        unit = decal_unit,  -- Keep for backwards compatibility
        units = decal_units,
        radius = radius,
        template_name = template_name,
        circle_only = circle_only,
    }
    
    return mod._decals[unit]
end

-- Update decal appearance
local function update_decal(decal, radius, template_name)
    if not decal then return end
    
    local circle_type = CIRCLE_TEMPLATES[template_name]
    if not circle_type then return end
    
    local red, green, blue, alpha = get_circle_rgba(circle_type)
    local colour = Quaternion.identity()
    Quaternion.set_xyzw(colour, red, green, blue, 0)
    
    -- Handle multiple concentric circles for circle-only
    local units = decal.units or {decal.unit}
    local num_circles = #units
    
    for i, decal_unit in ipairs(units) do
        if decal_unit and Unit.is_valid(decal_unit) then
            Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", colour, true)
            Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", alpha)
            
            -- Scale each circle
            local scale_factor = 1 - ((i - 1) / num_circles)
            if template_name == "broker_tox_grenade" then
                local diameter = radius * 1.8 * scale_factor
                Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, 1))
            else
                local diameter = radius * 2 * scale_factor
                Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, 1))
            end
        end
    end
    
    decal.radius = radius
end

local function destroy_decal(unit)
    local decal = mod._decals[unit]
    if decal then
        -- Handle multiple circles
        local units = decal.units or {decal.unit}
        for _, decal_unit in ipairs(units) do
            if decal_unit and Unit.is_valid(decal_unit) then
                World.destroy_unit(Unit.world(decal_unit), decal_unit)
            end
        end
        mod._decals[unit] = nil
    end
end

local function destroy_all_decals()
    for unit, _ in pairs(mod._decals) do
        destroy_decal(unit)
    end
end

-- Debug logging helper
local function debug_log(message)
    if DEBUG_LOGGING then
        mod:echo("[VFX Swapper] " .. message)
    end
end

-- ============================================================================
-- Force Destroy on Cleanup
-- ============================================================================

mod:hook_safe("LiquidAreaExtension", "destroy", function(self)
    destroy_decal(self._unit)
end)

mod:hook_safe("HuskLiquidAreaExtension", "destroy", function(self)
    destroy_decal(self._unit)
end)

-- ============================================================================
-- VFX Swap Hooks
-- ============================================================================

mod:hook("HuskLiquidAreaExtension", "_set_liquid_filled", function(func, self, real_index)
	if self._area_template_name == "toxic_gas" then
        self._vfx_name_filled = nil
    elseif self._area_template_name == "rotten_armor" then
        if mod:get("replace_rotten_armor") == "CIRCLE_ONLY" then
            self._vfx_name_filled = nil
        else
		self._vfx_name_filled = mod:get("replace_rotten_armor")
        end
	elseif self._area_template_name == "cultist_grenadier_gas" then
		self._vfx_name_filled = mod:get("replace_gas_vfx")
	elseif self._area_template_name == "fire_grenade" then
		self._vfx_name_filled = mod:get("replace_immolation_vfx")
	elseif self._area_template_name == "renegade_grenadier_fire_grenade" then
		self._vfx_name_filled = mod:get("replace_renegade_grenade_vfx")
	elseif self._area_template_name == "renegade_flamer_liquid_paint" then
		self._vfx_name_filled = mod:get("replace_renegade_flamer_vfx")
	elseif self._area_template_name == "cultist_flamer_liquid_paint" then
		self._vfx_name_filled = mod:get("replace_cultist_flamer_vfx")
	elseif self._area_template_name == "havoc_enemy_corruption_liquid" then
        if mod:get("replace_havoc_enemy_corruption_liquid") == "CIRCLE_ONLY" then
            self._vfx_name_filled = nil
        else
		    self._vfx_name_filled = mod:get("replace_havoc_enemy_corruption_liquid")
        end
    elseif self._area_template_name == "broker_tox_grenade" then
		if mod:get("replace_broker_tox_grenade") == "CIRCLE_ONLY" then
			self._vfx_name_filled = nil
		else
			self._vfx_name_filled = mod:get("replace_broker_tox_grenade")
		end
    elseif self._area_template_name == "prop_fire" then
		self._vfx_name_filled = mod:get("replace_fire_barrel_vfx")
	end
	
	return func(self, real_index)
end)

mod:hook("LiquidAreaExtension", "_set_filled", function(func, self, real_index)
    if self._area_template_name == "toxic_gas" then
        self._vfx_name_filled = nil
    elseif self._area_template_name == "rotten_armor" then
        if mod:get("replace_rotten_armor") == "CIRCLE_ONLY" then
            self._vfx_name_filled = nil
        else
		    self._vfx_name_filled = mod:get("replace_rotten_armor")
        end
	elseif self._area_template_name == "cultist_grenadier_gas" then
		self._vfx_name_filled = mod:get("replace_gas_vfx")
	elseif self._area_template_name == "fire_grenade" then
		self._vfx_name_filled = mod:get("replace_immolation_vfx")
	elseif self._area_template_name == "renegade_grenadier_fire_grenade" then
		self._vfx_name_filled = mod:get("replace_renegade_grenade_vfx")
	elseif self._area_template_name == "renegade_flamer_liquid_paint" then
		self._vfx_name_filled = mod:get("replace_renegade_flamer_vfx")
	elseif self._area_template_name == "cultist_flamer_liquid_paint" then
		self._vfx_name_filled = mod:get("replace_cultist_flamer_vfx")
	elseif self._area_template_name == "havoc_enemy_corruption_liquid" then
        if mod:get("replace_havoc_enemy_corruption_liquid") == "CIRCLE_ONLY" then
            self._vfx_name_filled = nil
        else
		    self._vfx_name_filled = mod:get("replace_havoc_enemy_corruption_liquid")
        end
    elseif self._area_template_name == "broker_tox_grenade" then
		if mod:get("replace_broker_tox_grenade") == "CIRCLE_ONLY" then
			self._vfx_name_filled = nil
		else
			self._vfx_name_filled = mod:get("replace_broker_tox_grenade")
		end
	elseif self._area_template_name == "prop_fire" then
		self._vfx_name_filled = mod:get("replace_fire_barrel_vfx")
	end
	
	return func(self, real_index)
end)

-- ============================================================================
-- set_drawer hooks (needed for renegade grenade VFX)
-- ============================================================================

mod:hook("LiquidAreaExtension", "set_drawer", function(func, self, drawers)
	if mod:get("replace_renegade_grenade_vfx") ~= "grenade_vfx_default" then
		if self._use_liquid_drawer == true and self._area_template_name == "renegade_grenadier_fire_grenade" then
		self._use_liquid_drawer = false
		end
	end
    -- ALWAYS disable liquid drawer for chemnade to allow other indicators to show through
    if self._use_liquid_drawer == true and self._area_template_name == "broker_tox_grenade" then
        self._use_liquid_drawer = false
    end
	return func(self, drawers)
end)

mod:hook("HuskLiquidAreaExtension", "set_drawer", function(func, self, drawers)
	if mod:get("replace_renegade_grenade_vfx") ~= "grenade_vfx_default" then
		if self._use_liquid_drawer == true and self._area_template_name == "renegade_grenadier_fire_grenade" then
		self._use_liquid_drawer = false
		end
	end
    -- ALWAYS disable liquid drawer for chemnade to allow other indicators to show through
    if self._use_liquid_drawer == true and self._area_template_name == "broker_tox_grenade" then
        self._use_liquid_drawer = false
    end
	return func(self, drawers)
end)

-- ============================================================================
-- Circle Indicator Hooks
-- ============================================================================
 
-- Create decal (server-side)
mod:hook_safe("LiquidAreaExtension", "_calculate_broadphase_size", function(self)
    local template_name = self._template_name or self._area_template_name
    if CIRCLE_TEMPLATES[template_name] then
        local decal = create_decal(self._unit, self._world, self._broadphase_radius, template_name)
        if decal then
            update_decal(decal, self._broadphase_radius, template_name)
        end
    end
end)

-- Create decal (client-side)
mod:hook_safe("HuskLiquidAreaExtension", "_calculate_liquid_size", function(self)
    local template_name = self._template_name or self._area_template_name
    if CIRCLE_TEMPLATES[template_name] then
        local decal = create_decal(self._unit, self._world, self._liquid_radius, template_name)
        if decal then
            update_decal(decal, self._liquid_radius, template_name)
        end
    end
end)

-- ============================================================================
-- Mod Lifecycle Hooks
-- ============================================================================

mod.on_all_mods_loaded = function()
    local vfxl =  get_mod("vfx_limiter")
    if vfxl then
        local vfxl_check = vfxl.hey_im_the_slim_version
        if not vfxl_check then
            mod:echo("WARNING: incompatible version of vfx_limiter found. Please disable or update vfx_limiter to the version under 'optional' files in vfx_swapper's Nexus page.")
        end
    end
end

mod.on_enabled = function()
    if not Managers.package:has_loaded(package_path) then
        Managers.package:load(package_path, "vfx_swapper")
    end
end

mod.on_disabled = function()
    destroy_all_decals()
end

-- mod.on_setting_changed = function(setting_id)
-- end

mod:hook_safe("UIManager", "cb_on_game_state_change", function()
    mod.havoc_enemy_vfx()
    destroy_all_decals()
end)
