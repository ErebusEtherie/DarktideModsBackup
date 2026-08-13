local mod = get_mod("vfx_swapper")
mod:io_dofile("vfx_swapper/scripts/mods/vfx_swapper/additionalvfx")
mod:io_dofile("vfx_swapper/scripts/mods/vfx_swapper/toxicgas")
mod:io_dofile("vfx_swapper/scripts/mods/vfx_swapper/vfx_limiter")
mod:io_dofile("vfx_swapper/scripts/mods/vfx_swapper/havoc")

local DEBUG_LOGGING = false
local LiquidAreaTemplates = require("scripts/settings/liquid_area/liquid_area_templates")

-- ============================================================================
-- Circle Indicator System (shamelessly stolen from danger_zone)
-- ============================================================================
local decal_path = "content/levels/training_grounds/fx/decal_aoe_indicator"
-- local decal_path = "content/fx/particles/abilities/ability_radius_aoe"
local impact_decal_unit_name = "content/fx/units/environment/expeditions/wastes/decal_lightning_strike_charge"
local package_path = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
local expedition_package_path = "packages/game_mode/expedition"
local force_staff_package = "content/fx/units/weapons/decal_force_staff_explosion_marker"
local staff_scaling_effect_name = "content/fx/particles/weapons/force_staff/force_staff_explosion_indicator"
local staff_scale_variable_name = "radius"
local zealot_flamer_package = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_burst"

mod._expedition_package_loaded = false
mod._force_staff_package_loaded = false
mod._zealot_flamer_package_loaded = false

-- Persistent tables for decal tracking
mod._decals = mod:persistent_table("vfx_swapper_decals")

local CIRCLE_TEMPLATES = {
    rotten_armor = "rotten_circle",
    havoc_enemy_corruption_liquid = "blight_circle",
    broker_tox_grenade = "chemnade_circle",
    cultist_grenadier_gas = "gas_grenade_circle",
    fire_grenade = "fire_circle",
}
local CIRCLE_ONLY_TEMPLATES = {
    broker_tox_grenade = true,
    rotten_armor = true,
    havoc_enemy_corruption_liquid = true,
    -- cultist_grenadier_gas = true,
    fire_grenade = true,
}


local _replace_gas_vfx = nil
local _replace_renegade_grenade_vfx = nil
local _replace_renegade_flamer_vfx = nil
local _replace_cultist_flamer_vfx = nil
local _replace_fire_grenade = nil
local _replace_rotten_armor = nil
local _replace_havoc_enemy_corruption_liquid = nil
local _replace_broker_tox_grenade = nil
local _replace_fire_barrel_vfx = nil
local _replace_purgator_vfx = nil

local function refresh_replace_vfx()
    _replace_gas_vfx = mod:get("replace_gas_vfx")
    _replace_renegade_grenade_vfx = mod:get("replace_renegade_grenade_vfx")
    _replace_renegade_flamer_vfx = mod:get("replace_renegade_flamer_vfx")
    _replace_cultist_flamer_vfx = mod:get("replace_cultist_flamer_vfx")
    _replace_fire_grenade = mod:get("replace_fire_grenade")
    _replace_rotten_armor = mod:get("replace_rotten_armor")
    _replace_havoc_enemy_corruption_liquid = mod:get("replace_havoc_enemy_corruption_liquid")
    _replace_broker_tox_grenade = mod:get("replace_broker_tox_grenade")
    _replace_fire_barrel_vfx = mod:get("replace_fire_barrel_vfx")
    _replace_purgator_vfx = mod:get("purgator_vfx")
end

refresh_replace_vfx()

local function get_gameplay_time()
    if Managers.time and Managers.time:has_timer("gameplay") then
        return Managers.time:time("gameplay")
    end
    return nil
end

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

local function should_use_chargeup(template_name)
    local circle_type = CIRCLE_TEMPLATES[template_name]
    if not circle_type then return false end
    return get_circle_setting(circle_type .. "_charge_enabled")    
end

local function should_use_staff_circle(template_name)
    local circle_type = CIRCLE_TEMPLATES[template_name]
    if not circle_type then return false end
    return get_circle_setting(circle_type .. "_staff_circle_enabled")
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
    -- mod:echo("position: " .. tostring(unit_position))
    local circle_only = is_circle_only_mode(template_name)
    local decal_units = {}
    local diameter = radius * 2
    

    local decal_unit = World.spawn_unit_ex(world, decal_path, nil, unit_position)
    World.link_unit(world, decal_unit, 1, unit, 1)
    table.insert(decal_units, decal_unit)
    Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, 1))
    local staff_decal = nil
    local staff_particle_id = nil
    local staff_scale_var_index = nil
    if should_use_staff_circle(template_name) then
        local staff_pos = unit_position + Vector3(0, 0, -0.05)
        staff_particle_id = World.create_particles(world, staff_scaling_effect_name, staff_pos)
        staff_scale_var_index = World.find_particles_variable(world, staff_scaling_effect_name, staff_scale_variable_name)
        if staff_scale_var_index then
            World.set_particles_variable(world, staff_particle_id, staff_scale_var_index, Vector3(diameter, diameter, diameter))
        end
    end 

    local charge_unit = nil
    if should_use_chargeup(template_name) then
        charge_unit = World.spawn_unit_ex(world, impact_decal_unit_name, nil, unit_position)
        World.link_unit(world, charge_unit, 1, unit, 1)
        table.insert(decal_units, charge_unit)
        Unit.set_local_scale(charge_unit, 1, Vector3(diameter, diameter, diameter))
        Unit.set_scalar_for_materials(charge_unit, "charge_progress", 0, true)
    end
    

    if circle_only then
        for i = 1, mod:get("circle_count") do
            local mid_decal = World.spawn_unit_ex(world, decal_path, nil, unit_position)
            World.link_unit(world, mid_decal, 1, unit, 1)
            table.insert(decal_units, mid_decal)
        end
    end
    
    -- Look up life_time from template for charge-up animation
    local template_data = LiquidAreaTemplates[template_name]
    local life_time = template_data and template_data.life_time or 10
    local spawn_time = get_gameplay_time() or 0
    
    -- Cache color at creation time to avoid per-frame mod:get() calls
    local circle_type = CIRCLE_TEMPLATES[template_name]
    local red, green, blue, alpha = get_circle_rgba(circle_type)
    
    mod._decals[unit] = {
        unit = decal_unit,        -- Outer colored circle (decal_aoe_indicator)
        charge_unit = charge_unit, -- Inner shrinking circle (decal_lightning_strike_charge)
        staff_decal = staff_decal,              -- Force staff scaling decal
        staff_particle_id = staff_particle_id,  -- Force staff scaling particle
        staff_scale_var_index = staff_scale_var_index,
        units = decal_units,
        radius = 0,               -- Start at 0 so first update_decal always applies
        template_name = template_name,
        circle_only = circle_only,
        decal_world = world,
        spawn_time = spawn_time,
        life_time = life_time,
        cached_red = red,
        cached_green = green,
        cached_blue = blue,
        cached_alpha = alpha,
    }
    
    return mod._decals[unit]
end

-- Apply cached color to all decal units (called on creation and setting change)
local function apply_decal_color(decal)
    if not decal then return end
    local colour = Quaternion.identity()
    Quaternion.set_xyzw(colour, decal.cached_red, decal.cached_green, decal.cached_blue, 0)
    local units = decal.units or {decal.unit}
    for _, decal_unit in ipairs(units) do
        if decal_unit and Unit.is_valid(decal_unit) then
            Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", colour, true)
            Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", decal.cached_alpha)
        end
    end
end

-- Update decal scale and color (called when radius changes)
local function update_decal(decal, radius, template_name)
    if not decal then return end
    apply_decal_color(decal)
    
    -- Handle multiple concentric circles for circle-only
    local units = decal.units or {decal.unit}
    local num_circles = #units
    
    for i, decal_unit in ipairs(units) do
        if decal_unit and Unit.is_valid(decal_unit) then
            -- Scale each circle
            local scale_factor = 1 - ((i - 1) / num_circles)
            if template_name == "broker_tox_grenade" then
                local diameter = radius * 1.8 * scale_factor
                Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, 1))
            elseif template_name == "cultist_grenadier_gas" then
                local diameter = radius * 1.9* scale_factor
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
        -- Destroy the charge progress overlay (tracked separately)
        if decal.charge_unit and Unit.is_valid(decal.charge_unit) then
            World.destroy_unit(Unit.world(decal.charge_unit), decal.charge_unit)
        end
        -- Destroy force staff overlay (tracked separately)
        if decal.staff_decal and Unit.is_valid(decal.staff_decal) then
            World.destroy_unit(Unit.world(decal.staff_decal), decal.staff_decal)
        end
        if decal.staff_particle_id and decal.decal_world then
            World.destroy_particles(decal.decal_world, decal.staff_particle_id)
        end
        -- Destroy outer circle + concentric circles
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
        if Unit.is_valid(unit) then
            destroy_decal(unit)
        else
            -- Clear stale reference from persistent table
            mod._decals[unit] = nil
        end
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

mod:hook("LiquidAreaExtension", "destroy", function(func, self)
    destroy_decal(self._unit)
    return func(self)
end)

mod:hook("HuskLiquidAreaExtension", "destroy", function(func, self)
    destroy_decal(self._unit)
    return func(self)
end)

-- ============================================================================
-- VFX Swap Hooks
-- ============================================================================

-- VFX swap logic 
local function apply_vfx_swap(self)
    if self._area_template_name == "rotten_armor" then
        if _replace_rotten_armor == "CIRCLE_ONLY" then
            self._vfx_name_filled = nil
        else
		    self._vfx_name_filled = _replace_rotten_armor
        end
	elseif self._area_template_name == "cultist_grenadier_gas" then
		self._vfx_name_filled = _replace_gas_vfx
	elseif self._area_template_name == "fire_grenade" then
        if _replace_fire_grenade == "CIRCLE_ONLY" then
            self._vfx_name_filled = nil
        else
		    self._vfx_name_filled = _replace_fire_grenade
        end
	elseif self._area_template_name == "renegade_grenadier_fire_grenade" then
		self._vfx_name_filled = _replace_renegade_grenade_vfx
	elseif self._area_template_name == "renegade_flamer_liquid_paint" then
		self._vfx_name_filled = _replace_renegade_flamer_vfx
	elseif self._area_template_name == "cultist_flamer_liquid_paint" then
		self._vfx_name_filled = _replace_cultist_flamer_vfx
	elseif self._area_template_name == "havoc_enemy_corruption_liquid" then
        if _replace_havoc_enemy_corruption_liquid == "CIRCLE_ONLY" then
            self._vfx_name_filled = nil
        else
		    self._vfx_name_filled = _replace_havoc_enemy_corruption_liquid
        end
    elseif self._area_template_name == "broker_tox_grenade" then
		if _replace_broker_tox_grenade == "CIRCLE_ONLY" then
			self._vfx_name_filled = nil
		else
			self._vfx_name_filled = _replace_broker_tox_grenade
		end
    elseif self._area_template_name == "prop_fire" then
		self._vfx_name_filled = _replace_fire_barrel_vfx
	end

end

mod:hook("HuskLiquidAreaExtension", "_set_liquid_filled", function(func, self, real_index, ...)
	apply_vfx_swap(self)
	return func(self, real_index, ...)
end)

mod:hook("LiquidAreaExtension", "_set_filled", function(func, self, real_index, ...)
	apply_vfx_swap(self)
	return func(self, real_index, ...)
end)

-- ============================================================================
-- set_drawer hooks (needed for renegade grenade VFX)
-- ============================================================================

mod:hook("LiquidAreaExtension", "set_drawer", function(func, self, drawers)
	if _replace_renegade_grenade_vfx ~= "grenade_vfx_default" then
		if self._use_liquid_drawer == true and self._area_template_name == "renegade_grenadier_fire_grenade" then
		self._use_liquid_drawer = false
		end
	end
    if self._use_liquid_drawer == true then
        if self._area_template_name == "broker_tox_grenade" or self._area_template_name == "fire_grenade" then
            self._use_liquid_drawer = false
        end
    end
	return func(self, drawers)
end)

mod:hook("HuskLiquidAreaExtension", "set_drawer", function(func, self, drawers)
	if _replace_renegade_grenade_vfx ~= "grenade_vfx_default" then
		if self._use_liquid_drawer == true and self._area_template_name == "renegade_grenadier_fire_grenade" then
		self._use_liquid_drawer = false
		end
	end
    if self._use_liquid_drawer == true then
        if self._area_template_name == "broker_tox_grenade" or self._area_template_name == "fire_grenade" then
            self._use_liquid_drawer = false
        end
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
        if decal and decal.radius ~= self._broadphase_radius then
            update_decal(decal, self._broadphase_radius, template_name)
        end
    end
end)

-- Create decal (client-side)
mod:hook_safe("HuskLiquidAreaExtension", "_calculate_liquid_size", function(self)
    local template_name = self._template_name or self._area_template_name
    if CIRCLE_TEMPLATES[template_name] then
        local decal = create_decal(self._unit, self._world, self._liquid_radius, template_name)
        if decal and decal.radius ~= self._liquid_radius then
            update_decal(decal, self._liquid_radius, template_name)
        end
    end
end)

-- ============================================================================
-- Lightning Charge-Up Animation (update hooks)
-- ============================================================================


local function update_lightning_charge(decal, fraction)
    if not decal then return end
    local diameter = decal.radius * 2
    
    local charge_unit = decal.charge_unit
    if charge_unit and Unit.is_valid(charge_unit) then
        Unit.set_scalar_for_materials(charge_unit, "charge_progress", fraction, true)
    end
    
    local staff_decal = decal.staff_decal
    if staff_decal and Unit.is_valid(staff_decal) then
        local staff_scale = fraction * diameter
        Unit.set_local_scale(staff_decal, 1, Vector3(staff_scale, staff_scale, 1))
    end
    if decal.staff_particle_id and decal.decal_world and decal.staff_scale_var_index then
        local staff_scale = fraction * diameter
        World.set_particles_variable(decal.decal_world, decal.staff_particle_id, decal.staff_scale_var_index, Vector3(staff_scale, staff_scale, staff_scale))
    end
end


mod:hook("LiquidAreaExtension", "update", function(func, self, unit, dt, t)
    local decal = mod._decals[self._unit]
    if not decal or not decal.life_time then return func(self, unit, dt, t) end
    
    -- fraction = how far through the lifetime (0 at start, 1 at expiry)
    local remaining = self._time_to_remove - t
    local fraction = math.clamp(1 - (remaining / decal.life_time), 0, 1) -- growing inner circle
    -- local fraction = math.clamp(remaining / decal.life_time, 0, 1) -- shrinking inner circle

    update_lightning_charge(decal, fraction)
    return func(self, unit, dt, t)
end)


mod:hook("HuskLiquidAreaExtension", "update", function(func, self, unit, dt, t)
    local decal = mod._decals[self._unit]
    if not decal or not decal.life_time then return func(self, unit, dt, t) end
    
    local elapsed = t - decal.spawn_time
    local fraction = math.clamp(elapsed / decal.life_time, 0, 1)
    -- local fraction = math.clamp(1 - (elapsed / decal.life_time), 0, 1)
    
    update_lightning_charge(decal, fraction)
    return func(self, unit, dt, t)
end)

-- ============================================================================
-- Purgator VFX (ServoSkull)
-- ============================================================================

local CompanionServoSkullFlamerSettings = require("scripts/settings/companion/companion_servo_skull_flamer_settings")
local skull_vfx = CompanionServoSkullFlamerSettings.vfx
local servo_skull_effect = require("scripts/settings/fx/effect_templates/companion_servo_skull_flamer")
local orig_skull_update = servo_skull_effect.update

servo_skull_effect.update = function(template_data, template_context, dt, t)
    local current_particle = skull_vfx.flamer_particle

    if template_data._last_particle and template_data._last_particle ~= current_particle then
        if template_data.stream_effect_id then
            World.stop_spawning_particles(template_context.world, template_data.stream_effect_id)
            template_data.stream_effect_id = nil
        end
        template_data._burst_create_time = nil
    end
    template_data._last_particle = current_particle

    if current_particle == "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_burst" then
        if not template_data._burst_create_time then
            template_data._burst_create_time = t
        end
        local elapsed = t - template_data._burst_create_time
        if elapsed > 2 and template_data.stream_effect_id then
            World.stop_spawning_particles(template_context.world, template_data.stream_effect_id)
            template_data.stream_effect_id = nil
            template_data._burst_create_time = t
        end
    end

    return orig_skull_update(template_data, template_context, dt, t)
end

local function update_purgator_vfx()
	if _replace_purgator_vfx == true then
		CompanionServoSkullFlamerSettings.vfx.flamer_particle = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_burst"
	else
		CompanionServoSkullFlamerSettings.vfx.flamer_particle = "content/fx/particles/abilities/cryptic/companion_servo_skull_flamer_code_control"
	end
end

update_purgator_vfx()

-- ============================================================================
-- Mod Lifecycle Hooks
-- ============================================================================

mod.on_all_mods_loaded = function()
    local vfxl =  get_mod("vfx_limiter")
    if vfxl then
        mod:echo("WARNING: vfx_limiter no longer compatible with VFX Swapper and limiter options are now a part of VFX Swapper. Please disable vfx_limiter")
    end
    mod.havoc_enemy_vfx()
    if not Managers.package:has_loaded(expedition_package_path) then
        Managers.package:load(expedition_package_path, "vfx_swapper_expedition", function()
            mod._expedition_package_loaded = true
        end)
    else
        mod._expedition_package_loaded = true
    end
    if not Managers.package:has_loaded(force_staff_package) then
        Managers.package:load(force_staff_package, "vfx_swapper_force_staff", function()
            mod._force_staff_package_loaded = true
        end)
    else
        mod._force_staff_package_loaded = true
    end
    if not Managers.package:has_loaded(zealot_flamer_package) then
        Managers.package:load(zealot_flamer_package, "vfx_swapper_zealot_flamer", function()
            mod._zealot_flamer_package_loaded = true
        end)
    else
        mod._zealot_flamer_package_loaded = true
    end
    -- mod:echo("expedition package loaded: " .. tostring(mod._expedition_package_loaded))  
    mod._refresh_vfx_limiter_cache()
    mod._refresh_additionalvfx_cache()
    refresh_replace_vfx()
    mod._refresh_toxicgas_cache()
end

mod.on_enabled = function()
    if not Managers.package:has_loaded(package_path) then
        Managers.package:load(package_path, "vfx_swapper")
    end
end

mod.on_disabled = function()
    destroy_all_decals()
end

mod.on_setting_changed = function(setting_id)
    -- Refresh cached colors on existing decals when color settings change
    for unit, decal in pairs(mod._decals) do
        if Unit.is_valid(unit) then
            local circle_type = CIRCLE_TEMPLATES[decal.template_name]
            if circle_type then
                local red, green, blue, alpha = get_circle_rgba(circle_type)
                decal.cached_red = red
                decal.cached_green = green
                decal.cached_blue = blue
                decal.cached_alpha = alpha
                apply_decal_color(decal)
            end
        end
    end
    -- Refresh caches in sub-modules
    mod._refresh_vfx_limiter_cache()
    mod._refresh_additionalvfx_cache()
    refresh_replace_vfx()
    mod._refresh_toxicgas_cache()
    mod.havoc_enemy_vfx()
    update_purgator_vfx()
end

mod:hook_safe("UIManager", "cb_on_game_state_change", function()
    destroy_all_decals()
end)
-- save scroll position
-- Author: Alfthebigheaded
local last_scroll_amount = 0
local last_category = nil

local function is_my_category(self)
    return self._selected_category == mod:localize("mod_name")
        or self._selected_category == mod:localize("mod_name_pizazz")
end

mod:hook_safe(CLASS.BaseView, "on_exit", function(self)
    last_category = nil
end)

mod:hook_safe(CLASS.BaseView, "update", function(self)
    if self.view_name ~= "dmf_options_view" then
        return
    end

    local grid = self._navigation_grids
    if not (grid and grid[2] and grid[2]._scrollbar_widget) then
        return
    end

    local scrollbar_widget = grid[2]._scrollbar_widget
    local current_category = self._selected_category
    local in_my_category = is_my_category(self)

    --  Detect category switch into my mod
    if in_my_category and (last_category ~= current_category or last_category == nil) then
        scrollbar_widget.content.scroll_value = last_scroll_amount
        scrollbar_widget.content.value = last_scroll_amount
    end

    --  Always track scroll while inside my mod
    if in_my_category then
        if grid[2]._scroll_progress and last_scroll_amount ~= grid[2]._scroll_progress then
            last_scroll_amount = grid[2]._scroll_progress
        end
    end

    last_category = current_category
end)