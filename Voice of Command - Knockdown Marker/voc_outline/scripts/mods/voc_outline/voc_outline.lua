local mod = get_mod("voc_outline")

local outlined_units = {}
local light_units = {}
local radius = 10
local center_unit = nil
local light_intensity = 200
local light_radius = 2
local light_falloff_start = 1
local outline_type = mod:get("outline_type")

local color_presets = {
    buff = { r = 0.14, g = 0.80, b = 0.10 },
    knocked_down = { r = 1.00, g = 0.50, b = 0.00 },
    default_both_obscured = { r = 0.20, g = 0.50, b = 1.00 }
}

local function get_outline_system()
    return Managers.state.extension and Managers.state.extension:system("outline_system")
end

local function get_world()
    return Managers.world:world("level_world")
end

local function has_talent(unit, talent)
    local player = Managers.state.player_unit_spawn:owner(unit)
    if player then
        local profile = player:profile()
        if profile and profile.archetype and profile.archetype.name == "veteran" then
            return profile.talents and profile.talents[talent]
        end
    end
    return false
end

local function is_knocked_down(unit)
    if not ALIVE[unit] then return false end
    local unit_data = ScriptUnit.extension(unit, "unit_data_system")
    if not unit_data then return false end
    local state_component = unit_data:read_component("character_state")
    if not state_component then return false end
    return state_component.state_name == "knocked_down"
end

local function find_teammates_in_radius(center_pos, radius)
    local teammates_in_radius = {}
    local players = Managers.player:players()
    local local_player_unit = Managers.player:local_player(1).player_unit
    for _, player in pairs(players) do
        local unit = player.player_unit
        if unit ~= local_player_unit and ALIVE[unit] then
            local pos = Unit.local_position(unit, 1)
            if Vector3.distance(center_pos, pos) <= radius and is_knocked_down(unit) then
                teammates_in_radius[unit] = true
            end
        end
    end
    return teammates_in_radius
end

local function spawn_light_for_unit(unit, outline_type)
    local world = get_world()
    if not world or not ALIVE[unit] then return end
    local preset = color_presets[outline_type] or color_presets.buff
    local pos = Unit.world_position(unit, 1)
    local rot = Quaternion.identity()
    local light_unit = World.spawn_unit_ex(world, "core/units/light", nil, pos, rot)
    if light_unit then
        local light_obj = Unit.light(light_unit, 1)
        Light.set_enabled(light_obj, true)
        Light.set_type(light_obj, "omni")
        Light.set_intensity(light_obj, light_intensity)
        Light.set_color_filter(light_obj, Vector3(preset.r, preset.g, preset.b))
        Light.set_falloff_start(light_obj, light_falloff_start)
        Light.set_falloff_end(light_obj, light_radius)
        Light.set_volumetric_intensity(light_obj, 0.3)
        light_units[unit] = light_unit
    end
end

local function destroy_light_for_unit(unit)
    local world = get_world()
    if world and light_units[unit] and Unit.alive(light_units[unit]) then
        World.destroy_unit(world, light_units[unit])
    end
    light_units[unit] = nil
end

local function destroy_all_lights()
    for unit, _ in pairs(light_units) do
        destroy_light_for_unit(unit)
    end
    light_units = {}
end

local function destroy_outline()
    local outline_system = get_outline_system()
    if not outline_system then return end
    for unit, _ in pairs(outlined_units) do
        outline_system:remove_outline(unit, outline_type, true)
        destroy_light_for_unit(unit)
    end
    outlined_units = {}
end

local function update_outlines()
    if not center_unit then return end
    if not has_talent(center_unit, "veteran_combat_ability_revive_nearby_allies") then
        destroy_outline()
        return
    end
    local outline_system = get_outline_system()
    if not outline_system then return end
    local center_pos = Unit.local_position(center_unit, 1)
    local teammates_in_radius = find_teammates_in_radius(center_pos, radius)
    for unit, _ in pairs(outlined_units) do
        if not ALIVE[unit] or not teammates_in_radius[unit] then
            outline_system:remove_outline(unit, outline_type, true)
            destroy_light_for_unit(unit)
            outlined_units[unit] = nil
        end
    end
    for unit, _ in pairs(teammates_in_radius) do
        if not outlined_units[unit] then
            outline_system:add_outline(unit, outline_type, true)
            spawn_light_for_unit(unit, outline_type)
            outlined_units[unit] = true
        end
    end
end

local function update_lights()
    local world = get_world()
    if not world then return end
    for unit, light_unit in pairs(light_units) do
        if ALIVE[unit] and Unit.alive(light_unit) and is_knocked_down(unit) then
            local pos = Unit.world_position(unit, 1)
            Unit.set_local_position(light_unit, 1, pos)
        else
            destroy_light_for_unit(unit)
        end
    end
end

mod:hook_safe("ShoutEffects", "_spawn_aim_shout_effects", function(self, r, unit)
    if not has_talent(unit, "veteran_combat_ability_revive_nearby_allies") then
        return
    end
    center_unit = unit
    radius = r+1 or 10
    local outline_system = get_outline_system()
    if not outline_system then return end
    local center_pos = Unit.local_position(center_unit, 1)
    local teammates = find_teammates_in_radius(center_pos, radius)
    for unit, _ in pairs(teammates) do
        if not outlined_units[unit] then
            outline_system:add_outline(unit, outline_type, true)
            spawn_light_for_unit(unit, outline_type)
            outlined_units[unit] = true
        end
    end
end)

mod:hook_safe("ShoutEffects", "_destroy_aim_shout_effects", function(self)
    destroy_outline()
    destroy_all_lights()
    center_unit = nil
end)

mod.update = function(dt)
    update_outlines()
    update_lights()
end

mod.on_setting_changed = function(setting_name)
	outline_type = mod:get("outline_type")
end