local mod = get_mod("vfx_swapper")

local _replace_purgator_vfx = nil
-- local _replace_zealot_flamer_vfx = nil
local _kill_flamer_vfx = nil

mod.refresh_flamer_vfx = function()
    _replace_purgator_vfx = mod:get("purgator_vfx")
    -- _replace_zealot_flamer_vfx = mod:get("flamer_swap")
    _kill_flamer_vfx = mod:get("kill_flamer_vfx")
end

mod.refresh_flamer_vfx()
-- ============================================================================
-- Purgator VFX (ServoSkull)
-- ============================================================================

local CompanionServoSkullFlamerSettings = require("scripts/settings/companion/companion_servo_skull_flamer_settings")
local skull_vfx = CompanionServoSkullFlamerSettings.vfx
local servo_skull_effect = require("scripts/settings/fx/effect_templates/companion_servo_skull_flamer")
local orig_skull_update = servo_skull_effect.update

mod.update_purgator_vfx = function()
	if _replace_purgator_vfx then
		CompanionServoSkullFlamerSettings.vfx.flamer_particle = "content/fx/particles/weapons/rifles/player_flamer/flamer_code_control_burst"
	else
		CompanionServoSkullFlamerSettings.vfx.flamer_particle = "content/fx/particles/abilities/cryptic/companion_servo_skull_flamer_code_control"
	end
end

mod.update_purgator_vfx()

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





-- ============================================================================
-- Flamer/inferno swap
-- ============================================================================

-- local _original_values = {}

-- local FlamerTemplate    = require("scripts/settings/equipment/weapon_templates/flamers/flamer_p1_m1")
-- local flamer_burst_fx   = FlamerTemplate.actions.action_shoot.fx
-- local flamer_stream_fx  = FlamerTemplate.actions.action_shoot_braced.fx


-- local InfernoTemplate   = require("scripts/settings/equipment/weapon_templates/force_staffs/forcestaff_p2_m1")
-- local inferno_burst_fx  = InfernoTemplate.actions.action_shoot_flame.fx
-- local inferno_stream_fx = InfernoTemplate.actions.action_shoot_charged_flame.fx


-- _original_values.flamer_burst_stream_name      = flamer_burst_fx.stream_effect.name
-- _original_values.flamer_burst_stream_name_3p   = flamer_burst_fx.stream_effect.name_3p
-- _original_values.flamer_burst_impact           = flamer_burst_fx.impact_effect
-- _original_values.flamer_stream_stream_name     = flamer_stream_fx.stream_effect.name
-- _original_values.flamer_stream_stream_name_3p  = flamer_stream_fx.stream_effect.name_3p
-- _original_values.flamer_stream_impact          = flamer_stream_fx.impact_effect
-- _original_values.inferno_burst_stream_name     = inferno_burst_fx.stream_effect.name
-- _original_values.inferno_burst_stream_name_3p  = inferno_burst_fx.stream_effect.name_3p
-- _original_values.inferno_burst_impact          = inferno_burst_fx.impact_effect
-- _original_values.inferno_stream_stream_name    = inferno_stream_fx.stream_effect.name
-- _original_values.inferno_stream_stream_name_3p = inferno_stream_fx.stream_effect.name_3p
-- _original_values.inferno_stream_impact         = inferno_stream_fx.impact_effect

-- mod.swap_flamer_vfx = function()
--     if _replace_zealot_flamer_vfx then
--         flamer_burst_fx.stream_effect.name     = _original_values.inferno_burst_stream_name
--         flamer_burst_fx.stream_effect.name_3p  = _original_values.inferno_burst_stream_name_3p
--         flamer_burst_fx.impact_effect          = _original_values.inferno_burst_impact
--         flamer_stream_fx.stream_effect.name    = _original_values.inferno_stream_stream_name
--         flamer_stream_fx.stream_effect.name_3p = _original_values.inferno_stream_stream_name_3p
--         flamer_stream_fx.impact_effect         = _original_values.inferno_stream_impact
--     else
--         flamer_burst_fx.stream_effect.name     = _original_values.flamer_burst_stream_name
--         flamer_burst_fx.stream_effect.name_3p  = _original_values.flamer_burst_stream_name_3p
--         flamer_burst_fx.impact_effect          = _original_values.flamer_burst_impact
--         flamer_stream_fx.stream_effect.name    = _original_values.flamer_stream_stream_name
--         flamer_stream_fx.stream_effect.name_3p = _original_values.flamer_stream_stream_name_3p
--         flamer_stream_fx.impact_effect         = _original_values.flamer_stream_impact
--     end
-- end
-- mod.swap_inferno_vfx = function()
--     if _replace_zealot_flamer_vfx then
--         inferno_burst_fx.stream_effect.name     = _original_values.flamer_burst_stream_name
--         inferno_burst_fx.stream_effect.name_3p  = _original_values.flamer_burst_stream_name_3p
--         inferno_burst_fx.impact_effect          = _original_values.flamer_burst_impact
--         inferno_stream_fx.stream_effect.name    = _original_values.flamer_stream_stream_name
--         inferno_stream_fx.stream_effect.name_3p = _original_values.flamer_stream_stream_name_3p
--         inferno_stream_fx.impact_effect         = _original_values.flamer_stream_impact
--     else
--         inferno_burst_fx.impact_effect          = _original_values.inferno_burst_impact
--         inferno_burst_fx.stream_effect.name     = _original_values.inferno_burst_stream_name
--         inferno_burst_fx.stream_effect.name_3p  = _original_values.inferno_burst_stream_name_3p
--         inferno_stream_fx.impact_effect         = _original_values.inferno_stream_impact
--         inferno_stream_fx.stream_effect.name    = _original_values.inferno_stream_stream_name
--         inferno_stream_fx.stream_effect.name_3p = _original_values.inferno_stream_stream_name_3p
--     end
-- end

-- mod.swap_inferno_vfx()
-- mod.swap_flamer_vfx()





local Action = require("scripts/utilities/action/action")
mod:hook("FlamerGasEffects", "_update_effects", function(func, self, dt, t)
    if not _kill_flamer_vfx then
        return func(self, dt, t)
    end

    local weapon_action_component = self._weapon_action_component
    local action_settings = Action.current_action_settings_from_component(weapon_action_component, self._weapon_actions)
    local has_fire_configuration = action_settings and (action_settings.fire_configurations or action_settings.fire_configuration)
    local fx_source_name = self._fx_source_name
    local spawner_pose = self._fx_extension:vfx_spawner_pose(fx_source_name)
    local from_pos = Matrix4x4.translation(spawner_pose)
    local first_person_rotation = self._first_person_component.rotation
    local position_finder_component = self._action_module_position_finder_component
    local to_pos = position_finder_component.position
    local position_valid = position_finder_component.position_valid
    local max_length = self._action_flamer_gas_component.range
    local direction = Vector3.normalize(from_pos + Vector3.multiply(Quaternion.forward(first_person_rotation), max_length) - from_pos)
    local rotation = Quaternion.look(direction)

    if has_fire_configuration then
        local effects = action_settings.fx
        local weapon_extension = self._weapon_extension
        local fire_time = 0.3

        if weapon_extension then
            local weapon_handling_template = weapon_extension:weapon_handling_template()
            fire_time = weapon_handling_template.fire_rate.fire_time
        end
        fire_time = fire_time * 0.7

        local start_t = weapon_action_component.start_t or t
        local time_in_action = t - start_t
        local effect_duration = effects.duration

        if fire_time <= time_in_action and (not effect_duration or effect_duration > time_in_action - fire_time) then
            local sound_direction = direction
            local distance = max_length

            if position_valid then
                local direction_vector = to_pos - from_pos
                distance = Vector3.length(direction_vector)
                sound_direction = Vector3.normalize(direction_vector)
            end

            local sound_distance = math.clamp(distance - 0.1, 0, 4)
            local wanted_sound_source_pos = from_pos + sound_direction * sound_distance

            if not self._looping_source_id then
                local looping_sfx = effects.looping_3d_sound_effect
                if looping_sfx then
                    self._looping_source_id = WwiseWorld.make_manual_source(self._wwise_world, wanted_sound_source_pos, rotation)
                    WwiseWorld.trigger_resource_event(self._wwise_world, looping_sfx, self._looping_source_id)
                    self._source_position = Vector3Box(wanted_sound_source_pos)
                    self._stop_looping_sfx_event = effects.stop_looping_3d_sound_effect
                end
            else
                local current_pos = self._source_position:unbox()
                local new_pos = Vector3.lerp(current_pos, wanted_sound_source_pos, dt * 7)
                self._source_position:store(new_pos)
                WwiseWorld.set_source_position(self._wwise_world, self._looping_source_id, new_pos)
            end
        else
            self:_destroy_effects(true, rotation)
        end
    else
        self:_destroy_effects(true, rotation)
    end

    self:_update_moving_lingering_effects(dt, t)
    self:_update_impact_effects(dt, t)
end)

-------------Original hook. Comment out above and uncomment this to return to original behavior------------

-- mod:hook("FlamerGasEffects", "_update_effects", function(func, self, dt, t)
--     if not _kill_flamer_vfx then
--         return func(self, dt, t)
--     end
--     local weapon_action_component = self._weapon_action_component
--     local action_settings = Action.current_action_settings_from_component(weapon_action_component, self._weapon_actions)
--     local has_fire_configuration = action_settings and (action_settings.fire_configurations or action_settings.fire_configuration)
--     if has_fire_configuration then
--         local fx_source_name = self._fx_source_name
--         local spawner_pose = self._fx_extension:vfx_spawner_pose(fx_source_name)
--         local from_pos = Matrix4x4.translation(spawner_pose)
--         local first_person_rotation = self._first_person_component.rotation
--         local max_length = self._action_flamer_gas_component.range
--         local direction = Vector3.normalize(Vector3.multiply(Quaternion.forward(first_person_rotation), max_length))
--         local rotation = Quaternion.look(direction)
--         self:_destroy_effects(true, rotation)
--         self:_update_moving_lingering_effects(dt, t)
--         self:_update_impact_effects(dt, t)
--     else
--         return func(self, dt, t)
--     end
-- end)
