--[[
Crusher Attack Indicator
Author: Icetiger540
Date: 11/19/2025
Version: 1.0.0
--]]

local mod = get_mod("crusher_attack_indicator")

local decals = mod:persistent_table("crusher_decals")
local settings_cache = {}
local decal_path = "content/levels/training_grounds/fx/decal_aoe_indicator"
local package_path = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
table.unpack = table.unpack or unpack

local persistent_yellow_rings = {}
local known_crushers = {}
local pending_cleave_indicators = {}

local crusher_attack_states = {}

local CLEAVE_ATTACK_DATA = {
    range = 4.0,
    width = 2.0,
    height = 3.0,
    dodge_range = 2.75,
    dodge_width = 1.1,
    attack_type = "oobb"
}

local crusher_all_sounds = {
    "wwise/events/weapon/play_minion_swing_2h_blunt_large_cleave",
    "wwise/events/minions/play_shared_elite_executor_cleave_warning",
    "wwise/events/weapon/play_minion_swing_2h_blunt_large_sweep",
    "wwise/events/minions/play_shared_foley_chaos_ogryn_elites_heavy_drastic_short",
    "wwise/events/minions/play_shared_foley_chaos_ogryn_elites_heavy_movement_long",
    "wwise/events/minions/play_shared_foley_armoured_body_fall_large",
    "wwise/events/minions/play_shared_foley_chaos_ogryn_elites_heavy_run",
    "wwise/events/minions/stop_all_chaos_ogryn_executor_vce",
    "wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__death_vce",
    "wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__grunt_vce",
    "wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__hurt_vce",
    "wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__special_attack_vce",
    "wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__running_breath_vce",
    "wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__melee_attack_vce",
}

local crusher_cleave_sounds = {
    "wwise/events/weapon/play_minion_swing_2h_blunt_large_cleave",
    "wwise/events/minions/play_shared_elite_executor_cleave_warning",
}

local function get_gameplay_time()
    if Managers and Managers.time and Managers.time.time then
        local success, time = pcall(function() return Managers.time:time("gameplay") end)
        if success then
            return time
        end
    end
    return 0
end

local function get_setting(setting)
    local val = settings_cache[setting]
    if val == nil then
        settings_cache[setting] = mod:get(setting)
        val = settings_cache[setting]
    end
    return val
end

local function get_warning_color()
    return get_setting("warning_color_red") / 100,
        get_setting("warning_color_green") / 100,
        get_setting("warning_color_blue") / 100,
        get_setting("warning_color_alpha") / 100
end

local function get_attack_color()
    return get_setting("attack_color_red") / 100,
        get_setting("attack_color_green") / 100,
        get_setting("attack_color_blue") / 100,
        get_setting("attack_color_alpha") / 100
end

local function is_enabled()
    return get_setting("enabled")
end

local function show_persistent_yellow()
    return get_setting("persistent_yellow")
end

local function clear_settings_cache()
    table.clear(settings_cache)
end

local function is_crusher_unit(unit)
    if not Unit.alive(unit) then
        return false
    end
    
    local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system")
    local breed = unit_data_ext and unit_data_ext:breed()
    
    return breed and breed.name == "chaos_ogryn_executor"
end

local function create_cleave_indicator(unit, world, color_type)
    if not Managers or not Managers.package then
        return nil
    end
    
    local unit_position = POSITION_LOOKUP[unit]
    if not unit_position then
        return nil
    end

    local decal_unit = World.spawn_unit_ex(world, decal_path, nil, unit_position)
    
    if not Unit.alive(decal_unit) then
        return nil
    end

    World.link_unit(world, decal_unit, 1, unit, 1)
    
    local forward_offset = Vector3(0, CLEAVE_ATTACK_DATA.range / 2, 0)
    Unit.set_local_position(decal_unit, 1, forward_offset)
    
    local attack_diameter = CLEAVE_ATTACK_DATA.width
    Unit.set_local_scale(decal_unit, 1, Vector3(attack_diameter, attack_diameter, 1))
    
    local red, green, blue, alpha
    if color_type == "warning" then
        red, green, blue, alpha = get_warning_color()
    else
        red, green, blue, alpha = get_attack_color()
    end
    
    local colour = Quaternion.identity()
    Quaternion.set_xyzw(colour, red, green, blue, 0)
    Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", colour, true)
    Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", alpha)
    
    local decal = {
        unit = decal_unit,
        parent_unit = unit,
        color_type = color_type,
        spawn_time = get_gameplay_time(),
        is_cleave = true,
        world = world
    }
    
    decals[unit] = decal
    return decal
end

local function attempt_create_cleave_indicator(unit, world, color_type)
    if not Managers.package:has_loaded(package_path) then
        pending_cleave_indicators[unit] = {
            unit = unit,
            world = world,
            color_type = color_type,
            attempt_time = get_gameplay_time()
        }
        
        Managers.package:load(package_path, "crusher_attack_indicator", function()
            local pending = pending_cleave_indicators[unit]
            if pending then
                create_cleave_indicator(pending.unit, pending.world, pending.color_type)
                pending_cleave_indicators[unit] = nil
            end
        end)
        return nil
    else
        return create_cleave_indicator(unit, world, color_type)
    end
end

local function destroy_cleave_indicator(unit)
    local decal = decals[unit]
    if decal then
        if Unit.alive(decal.unit) then
            World.destroy_unit(decal.world, decal.unit)
        end
        decals[unit] = nil
    end
    pending_cleave_indicators[unit] = nil
end

local function get_persistent_ring(unit, world)
    if not Managers or not Managers.package then
        return nil
    end
    
    local decal = persistent_yellow_rings[unit]
    
    if decal and (not Unit.alive(decal.unit) or not Unit.alive(unit)) then
        if Unit.alive(decal.unit) then
            World.destroy_unit(decal.world, decal.unit)
        end
        persistent_yellow_rings[unit] = nil
        decal = nil
    end
    
    local should_show = is_enabled() and show_persistent_yellow() and Unit.alive(unit)
    
    if should_show and decal == nil then
        if not Managers.package:has_loaded(package_path) then
            Managers.package:load(package_path, "crusher_attack_indicator", function()
                get_persistent_ring(unit, world)
            end)
            return nil
        end

        local unit_position = POSITION_LOOKUP[unit]
        if not unit_position then
            return nil
        end

        decal = {
            unit = World.spawn_unit_ex(world, decal_path, nil, unit_position),
            parent_unit = unit,
            radius = get_setting("ring_radius") or 4.0,
            show = should_show,
            active = true,
            spawn_time = get_gameplay_time(),
            current_color = "warning",
            is_persistent = true,
            world = world
        }

        World.link_unit(world, decal.unit, 1, unit, 1)
        persistent_yellow_rings[unit] = decal
        
        local red, green, blue, alpha = get_warning_color()
        local colour = Quaternion.identity()
        Quaternion.set_xyzw(colour, red, green, blue, 0)
        Unit.set_vector4_for_material(decal.unit, "projector", "particle_color", colour, true)
        Unit.set_scalar_for_material(decal.unit, "projector", "color_multiplier", alpha)
        
        local ring_radius = get_setting("ring_radius") or 4.0
        local diameter = ring_radius * 2
        Unit.set_local_scale(decal.unit, 1, Vector3(diameter, diameter, 1))
    end

    if decal then
        decal.show = should_show
        if should_show and decal.active then
            Unit.set_scalar_for_material(decal.unit, "projector", "color_multiplier", get_setting("warning_color_alpha") / 100)
        end
    end
    return decal
end

local function show_persistent_ring(unit, world)
    if not show_persistent_yellow() then
        return
    end
    
    local decal = get_persistent_ring(unit, world)
    if decal then
        decal.active = true
        Unit.set_scalar_for_material(decal.unit, "projector", "color_multiplier", get_setting("warning_color_alpha") / 100)
    end
end

local function hide_persistent_ring(unit)
    local decal = persistent_yellow_rings[unit]
    if decal and Unit.alive(decal.unit) then
        decal.active = false
        Unit.set_scalar_for_material(decal.unit, "projector", "color_multiplier", 0)
    end
end

function mod:on_crusher_sound(sound_name, unit_or_position)
    if not is_enabled() then 
        return 
    end
    
    local unit = nil
    
    if Unit.alive(unit_or_position) then
        unit = unit_or_position
    else
        local flow_unit = Application.flow_callback_context_unit()
        if Unit.alive(flow_unit) then
            unit = flow_unit
        end
    end
    
    if not unit then
        return
    end
    
    if not is_crusher_unit(unit) then
        return
    end
    
    known_crushers[unit] = get_gameplay_time()
    
    if not crusher_attack_states[unit] then
        crusher_attack_states[unit] = "idle"
    end
    
    local current_state = crusher_attack_states[unit]
    local world = Unit.world(unit)
    
    if sound_name:match("cleave_warning") then
        if show_persistent_yellow() then
            hide_persistent_ring(unit)
        end
        
        destroy_cleave_indicator(unit)
        
        attempt_create_cleave_indicator(unit, world, "warning")
        crusher_attack_states[unit] = "warning"
        
    elseif sound_name:match("play_minion_swing_2h_blunt_large_cleave") then
        destroy_cleave_indicator(unit)
        
        attempt_create_cleave_indicator(unit, world, "attack")
        crusher_attack_states[unit] = "attack"
        
    elseif sound_name:match("play_minion_swing_2h_blunt_large_sweep") then
        
    else
        local is_other_crusher_sound = false
        for _, crusher_sound in ipairs(crusher_all_sounds) do
            if sound_name:match(crusher_sound) then
                is_other_crusher_sound = true
                break
            end
        end
        
        if is_other_crusher_sound then
            if current_state == "idle" then
                if show_persistent_yellow() then
                    show_persistent_ring(unit, world)
                end
            end
        end
    end
end

function mod.find_nearby_crushers()
    if not Managers.state or not Managers.state.side then
        return
    end
    
    local side = Managers.state.side:get_side_from_name("enemy")
    if not side then
        return
    end
    
    local enemy_units = side.valid_enemy_units
    if not enemy_units then
        return
    end
    
    for _, unit in ipairs(enemy_units) do
        if is_crusher_unit(unit) then
            known_crushers[unit] = get_gameplay_time()
            
            if show_persistent_yellow() and not decals[unit] then
                local world = Unit.world(unit)
                show_persistent_ring(unit, world)
            end
        end
    end
end

function mod.update(dt)
    if not Managers or not Managers.time then
        return
    end
    
    local current_time = get_gameplay_time()
    
    for unit, pending in pairs(pending_cleave_indicators) do
        if current_time - pending.attempt_time > 5.0 or not Unit.alive(unit) then
            pending_cleave_indicators[unit] = nil
        end
    end
    
    for unit, decal in pairs(decals) do
        if decal and decal.is_cleave and Unit.alive(decal.unit) then
            if decal.color_type == "warning" then
                if current_time - decal.spawn_time > 3.0 then
                    destroy_cleave_indicator(unit)
                    crusher_attack_states[unit] = "idle"
                end
            elseif decal.color_type == "attack" then
                if current_time - decal.spawn_time > 2.5 then
                    destroy_cleave_indicator(unit)
                    crusher_attack_states[unit] = "idle"
                    
                    if show_persistent_yellow() then
                        show_persistent_ring(unit, Unit.world(unit))
                    end
                end
            end
        end
    end
    
    for unit, last_seen in pairs(known_crushers) do
        if current_time - last_seen > 15.0 or not Unit.alive(unit) then
            known_crushers[unit] = nil
            crusher_attack_states[unit] = nil
            destroy_cleave_indicator(unit)
            local decal = persistent_yellow_rings[unit]
            if decal and Unit.alive(decal.unit) then
                World.destroy_unit(decal.world, decal.unit)
            end
            persistent_yellow_rings[unit] = nil
        end
    end
    
    if show_persistent_yellow() then
        for unit, _ in pairs(known_crushers) do
            if Unit.alive(unit) and not decals[unit] and crusher_attack_states[unit] == "idle" then
                local world = Unit.world(unit)
                show_persistent_ring(unit, world)
            end
        end
    end
    
    if current_time % 3.0 < dt then
        mod.find_nearby_crushers()
    end
end

mod.on_all_mods_loaded = function()
    if Managers and Managers.package then
        if not Managers.package:has_loaded(package_path) then
            Managers.package:load(package_path, "crusher_attack_indicator", function() end)
        end
    end
    
    mod:hook_safe(WwiseWorld, "trigger_resource_event", function(_wwise_world, wwise_event_name, unit_or_position_or_id)
        for _, sound_name in ipairs(crusher_all_sounds) do    
            if wwise_event_name:match(sound_name) then
                mod:on_crusher_sound(wwise_event_name, unit_or_position_or_id)
                break
            end
        end
    end)
    
    mod:hook_safe(WwiseWorld, "trigger_resource_external_event", function(_wwise_world, sound_event, sound_source, file_path, file_format, wwise_source_id)
        for _, sound_name in ipairs(crusher_all_sounds) do    
            if file_path:match(sound_name) then
                mod:on_crusher_sound(file_path, wwise_source_id)
                break
            end
        end
    end)
end

mod.on_setting_changed = function(setting_id)
    local new_val = mod:get(setting_id)
    settings_cache[setting_id] = new_val
    
    if setting_id == "persistent_yellow" and not new_val then
        for unit, decal in pairs(persistent_yellow_rings) do
            if Unit.alive(decal.unit) then
                World.destroy_unit(decal.world, decal.unit)
            end
        end
        table.clear(persistent_yellow_rings)
    elseif setting_id == "persistent_yellow" and new_val then
        for unit, _ in pairs(known_crushers) do
            if Unit.alive(unit) and not decals[unit] and crusher_attack_states[unit] == "idle" then
                local world = Unit.world(unit)
                show_persistent_ring(unit, world)
            end
        end
    elseif setting_id == "enabled" and not new_val then
        for unit, decal in pairs(decals) do
            if Unit.alive(decal.unit) then
                World.destroy_unit(decal.world, decal.unit)
            end
        end
        table.clear(decals)
        table.clear(pending_cleave_indicators)
        table.clear(crusher_attack_states)
    end
end

mod.on_enabled = function(_)
    clear_settings_cache()
end

mod.on_disabled = function(_)
    for unit, decal in pairs(decals) do
        if Unit.alive(decal.unit) then
            World.destroy_unit(decal.world, decal.unit)
        end
    end
    for unit, decal in pairs(persistent_yellow_rings) do
        if Unit.alive(decal.unit) then
            World.destroy_unit(decal.world, decal.unit)
        end
    end
    table.clear(decals)
    table.clear(persistent_yellow_rings)
    table.clear(pending_cleave_indicators)
    table.clear(crusher_attack_states)
    table.clear(known_crushers)
end

mod:hook_safe("HealthExtension", "kill", function(self)
    local unit = self._unit
    destroy_cleave_indicator(unit)
    known_crushers[unit] = nil
    crusher_attack_states[unit] = nil
    local decal = persistent_yellow_rings[unit]
    if decal and Unit.alive(decal.unit) then
        World.destroy_unit(decal.world, decal.unit)
    end
    persistent_yellow_rings[unit] = nil
end)

mod:hook_safe("MinionDeathManager", "set_dead", function(_, unit)
    destroy_cleave_indicator(unit)
    known_crushers[unit] = nil
    crusher_attack_states[unit] = nil
    local decal = persistent_yellow_rings[unit]
    if decal and Unit.alive(decal.unit) then
        World.destroy_unit(decal.world, decal.unit)
    end
    persistent_yellow_rings[unit] = nil
end)

mod:hook_safe("UIManager", "cb_on_game_state_change", function()
    for unit, decal in pairs(decals) do
        if Unit.alive(decal.unit) then
            World.destroy_unit(decal.world, decal.unit)
        end
    end
    for unit, decal in pairs(persistent_yellow_rings) do
        if Unit.alive(decal.unit) then
            World.destroy_unit(decal.world, decal.unit)
        end
    end
    table.clear(decals)
    table.clear(persistent_yellow_rings)
    table.clear(pending_cleave_indicators)
    table.clear(crusher_attack_states)
    table.clear(known_crushers)
end)

mod:hook_safe("HealthExtension", "init", function(_, extension_init_context, unit)
    if is_crusher_unit(unit) then
        known_crushers[unit] = get_gameplay_time()
        
        if show_persistent_yellow() then
            local world = extension_init_context.world
            show_persistent_ring(unit, world)
        end
    end
end)