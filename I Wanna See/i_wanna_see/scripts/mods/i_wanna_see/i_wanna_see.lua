local mod = get_mod("i_wanna_see")

local package_name = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
local decal_unit_name = "content/levels/training_grounds/fx/decal_aoe_indicator"
local bubble_decals = mod:persistent_table("shield_bubble_decals")
local SpecialRulesSetting = require("scripts/settings/ability/special_rules_settings")
local TalentSettings = require("scripts/settings/talent/talent_settings")
local ForceFieldExtension = require("scripts/extension_systems/force_field/force_field_extension")
local special_rules = SpecialRulesSetting.special_rules
local talent_settings = TalentSettings.psyker_3.combat_ability
local SOUND_EVENTS_WALL = {
	start = "wwise/events/player/play_ability_psyker_protectorate_shield",
	stop = "wwise/events/player/stop_ability_psyker_protectorate_shield",
}
local SOUND_EVENTS_SPHERE = {
	start = "wwise/events/player/play_ability_psyker_shield_dome",
	stop = "wwise/events/player/stop_ability_psyker_shield_dome",
}
local PARTICLES_WALL = {
	start = "content/fx/particles/abilities/protectorate_forward_shield_init",
	stop = "content/fx/particles/abilities/protectorate_forward_shield_fade",
}
local PARTICLES_SPHERE = {
	start = "content/fx/particles/abilities/protectorate_sphere_shield_init",
	stop = "content/fx/particles/abilities/protectorate_sphere_shield_fade",
}

local function destroy_aoe_decal(unit)
	local world = Unit.world(unit)
  	local bubble_decal = bubble_decals[unit]
  	if bubble_decal then
    	World.destroy_unit(world, bubble_decal)
			bubble_decals[unit] = nil
  	end
end

local function set_decal_color(decal_unit, r, g, b)
  local identity_value = Quaternion.identity()
	Quaternion.set_xyzw(identity_value, r, g, b, 0.5)
	Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", identity_value, true)
	Unit.set_scalar_for_material( decal_unit, "projector", "color_multiplier", 0.05)
end

local function get_decal_unit(unit, r, g, b)
  
	local world = Unit.world(unit)
	local position = Unit.local_position(unit, 1)

	local decal_unit = World.spawn_unit_ex(world, decal_unit_name, nil, position + Vector3(0, 0, 0.1))

	local diameter = 6 * 2 + 1.5
	Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, 1))
  
  set_decal_color(decal_unit, r, g, b)
  
  return decal_unit
end

local function shield_spawned(unit, dont_load_package)
	if not unit then
		return
	end
	if not Managers.package:has_loaded(package_name) and not dont_load_package then
		Managers.package:load(package_name, "i_wanna_see", function()
			shield_spawned(unit, true)
		end)
		return
	end

  
  local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
	bubble_decals[unit] = get_decal_unit(unit, mod:get("R"), mod:get("G"), mod:get("B"))
end

mod:hook(CLASS.ForceFieldExtension, "init", function (func, self, extension_init_context, unit, extension_init_data, game_object_data_or_game_session, unit_spawn_parameter_or_game_object_id)
	self._unit = unit

	local world = extension_init_context.world
	local wwise_world = extension_init_context.wwise_world

	self._world = world
	self._wwise_world = wwise_world

	local is_server = extension_init_context.is_server

	self._is_server = is_server
	self.owner_unit = extension_init_data.owner_unit

	local player_unit_spawn_manager = Managers.state.player_unit_spawn
	local owner_player = player_unit_spawn_manager:owner(self.owner_unit)

	if owner_player then
		player_unit_spawn_manager:assign_unit_ownership(unit, owner_player)
	end

	self._game_session = game_object_data_or_game_session
	self._game_object_id = unit_spawn_parameter_or_game_object_id

	local rotation = Unit.local_rotation(unit, 1)
	local position = Unit.local_position(unit, 1)

	self._rotation = QuaternionBox(rotation)
	self._position = Vector3Box(position)

	if is_server then
		local side_system = Managers.state.extension:system("side_system")

		self.side = side_system.side_by_unit[self.owner_unit]
		self.enemy_side_names = self.side:relation_side_names("enemy")
	end

	local width = 7
	local forward = Quaternion.forward(rotation)
	local rotation_left = Quaternion.from_euler_angles_xyz(0, 0, 90)
	local left = Quaternion.rotate(rotation_left, forward) * width / 2
	local p1 = Vector3Box(position + forward * 0.5)
	local p2 = Vector3Box(position + left * 0.3 + forward * 0.45)
	local p3 = Vector3Box(position + left * 0.6 + forward * 0.3)
	local p4 = Vector3Box(position + left * 0.9)
	local p5 = Vector3Box(position - left * 0.3 + forward * 0.45)
	local p6 = Vector3Box(position - left * 0.6 + forward * 0.3)
	local p7 = Vector3Box(position - left * 0.9)

	self._points = {
		p1,
		p2,
		p3,
		p4,
		p5,
		p6,
		p7,
	}

	local owner_unit = self.owner_unit

	self.buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
	self.talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
	self._shape_override = extension_init_data.shape_override

	local override_shield_as_sphere = extension_init_data.shape_override == "sphere"
	local sphere_shield = override_shield_as_sphere or self.talent_extension:has_special_rule(special_rules.psyker_sphere_shield)

	self._sphere_shield = sphere_shield

	local duration = talent_settings.duration
	local sphere_duration = talent_settings.sphere_duration

	self._duration = self._sphere_shield and sphere_duration or duration
	local start_particle_effect = sphere_shield and PARTICLES_SPHERE.start or PARTICLES_WALL.start
	self._max_duration = self._duration
	if not mod:get("remove_shield_sound") then 
		local start_sound_event = sphere_shield and SOUND_EVENTS_SPHERE.start or SOUND_EVENTS_WALL.start
		local source_id = WwiseWorld.make_manual_source(wwise_world, position + Vector3.up() * 1.5, rotation)
		self._playing_id, self._source_id = WwiseWorld.trigger_resource_event(wwise_world, start_sound_event, source_id)
	else 
		self._playing_id, self._source_id = nil, nil
	end
	if mod:get("remove_shield_effect") then
		if self._sphere_shield ~= nil then
			self._effect_id = nil
		else
			self._effect_id = World.create_particles(world, start_particle_effect, position, rotation)
		end
		Unit.set_unit_visibility(self._unit, false, true)
	else
		self._effect_id = World.create_particles(world, start_particle_effect, position, rotation)
	end
	self._players_inside = {}
	self.is_expired = false
	self.buff_affected_units = {}
	self._in_sheild_buff_template_name = nil
	self._leaving_shield_buff_template_name = nil
	self._end_shield_buff_template_name = nil
	if self._sphere_shield ~= nil and mod:get("display_shield_radius") then
		shield_spawned(unit, false)
	end

	if is_server then
		local talent_extension = ScriptUnit.has_extension(owner_unit, "talent_system")
		local has_special_rule = talent_extension and talent_extension:has_special_rule(special_rules.psyker_boost_allies_in_sphere)

		if has_special_rule and sphere_shield then
			self._in_sheild_buff_template_name = "psyker_boost_allies_in_sphere_buff"
			self._leaving_shield_buff_template_name = nil
			self._end_shield_buff_template_name = "psyker_boost_allies_in_sphere_end_buff"
		end
	end
end)

mod:hook(CLASS.ForceFieldExtension, "_trigger_death_effects", function (func, self)
	local world = self._world
	local wwise_world = self._wwise_world
	local source_id = self._source_id
	local effect_id = self._effect_id
	local sphere_shield = self._sphere_shield
	local unit = self._unit
	local stop_sound_event = sphere_shield and SOUND_EVENTS_SPHERE.stop or SOUND_EVENTS_WALL.stop

	if not mod:get("remove_shield_sound") then
		local stop_sound_event = sphere_shield and SOUND_EVENTS_SPHERE.stop or SOUND_EVENTS_WALL.stop
		WwiseWorld.trigger_resource_event(wwise_world, stop_sound_event, source_id)
		WwiseWorld.destroy_manual_source(wwise_world, source_id)		
	end
	self._source_id = nil

	if effect_id and World.are_particles_playing(world, effect_id) then
		World.destroy_particles(world, effect_id)
	end
	local stop_particle_effect = sphere_shield and PARTICLES_SPHERE.stop or PARTICLES_WALL.stop
	if mod:get("display_shield_radius") then
		destroy_aoe_decal(unit)
	end
	if mod:get("remove_shield_effect") then
		self._effect_id = nil
	else
		self._effect_id = World.create_particles(world, stop_particle_effect, self._position:unbox(), self._rotation:unbox())
	end
end)

local Action = require("scripts/utilities/action/action")
local ChainLightningTarget = require("scripts/utilities/action/chain_lightning_target")
mod:hook(CLASS.ChainLightningLinkEffects, "_find_root_targets", function (func, self, t)
	local DEFAULT_HAND = "both"
	local action_settings = Action.current_action_settings_from_component(self._weapon_action_component, self._weapon_actions)
	local action_kind = action_settings and action_settings.kind
	local attacking = action_kind == "chain_lightning"

	if attacking then
		local chain_root_node = self._chain_root_node
		local chain_settings = action_settings.chain_settings

		if mod:get("remove_smite_effect") then
			if chain_settings.staff and not mod:get("remove_electro_effect") then
				return func(self, t)
			end
			ChainLightningTarget.remove_all_child_nodes(chain_root_node, _on_remove_func, self._func_context)
			self:_clear_initial_targets()
			self:_clear_no_target()
			return
		end
	end
	return func(self, t)
end)

local Action = require("scripts/utilities/action/action")
mod:hook_origin(CLASS.FlamerGasEffects, "_update_effects", function(self, dt, t)
	local world = self._world
	local weapon_action_component = self._weapon_action_component
	local action_settings = Action.current_action_settings_from_component(weapon_action_component, self._weapon_actions)
	local fire_configuration = action_settings and action_settings.fire_configuration
	local fx_source_name = self._fx_source_name
	local spawner_pose = self._fx_extension:vfx_spawner_pose(fx_source_name)
	local from_pos = Matrix4x4.translation(spawner_pose)
	local first_person_rotation = self._first_person_component.rotation
	local position_finder_component = self._action_module_position_finder_component
	local to_pos = position_finder_component.position
	local position_valid = position_finder_component.position_valid
	local stream_effect_id = self._stream_effect_id
	local max_length = self._action_flamer_gas_component.range
	local direction = Vector3.normalize(from_pos + Vector3.multiply(Quaternion.forward(first_person_rotation), max_length) - from_pos)
	local rotation = Quaternion.look(direction)
	if fire_configuration then
		if mod:get("remove_purgatus_effect") and action_settings.fire_configuration.damage_type == "warpfire" then
			self:_destroy_effects(true, rotation)
			self:_update_moving_lingering_effects(dt, t)
			self:_update_impact_effects(dt, t)
			return
		elseif mod:get("remove_flamer_effect") and action_settings.fire_configuration.damage_type == "burning" then
			self:_destroy_effects(true, rotation)
			self:_update_moving_lingering_effects(dt, t)
			self:_update_impact_effects(dt, t)
			return
		else
			local effects = action_settings.fx
			local stream_effect_data = effects.stream_effect
			local should_play_husk_effect = self._fx_extension:should_play_husk_effect()
			local stream_effect_name = should_play_husk_effect and stream_effect_data.name_3p or stream_effect_data.name
			local move_after_stop = effects.move_after_stop
			local effect_duration = effects.duration
			local weapon_extension = self._weapon_extension
			local fire_time = 0.3

			if weapon_extension then
				local weapon_handling_template = weapon_extension:weapon_handling_template()

				fire_time = weapon_handling_template.fire_rate.fire_time
			end

			fire_time = fire_time * 0.7

			local start_t = weapon_action_component.start_t or t
			local time_in_action = t - start_t

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

				if not stream_effect_id then
					local effect_id = World.create_particles(world, stream_effect_name, from_pos, rotation, nil, self._particle_group_id)

					self._stream_effect_id = effect_id
					self._move_after_stop = move_after_stop

					local in_first_person = self._is_in_first_person

					if in_first_person then
						World.set_particles_use_custom_fov(world, effect_id, true)
					end

					local looping_sfx = effects.looping_3d_sound_effect

					if looping_sfx then
						self._looping_source_id = WwiseWorld.make_manual_source(self._wwise_world, wanted_sound_source_pos, rotation)

						WwiseWorld.trigger_resource_event(self._wwise_world, looping_sfx, self._looping_source_id)

						self._source_position = Vector3Box(wanted_sound_source_pos)
						self._stop_looping_sfx_event = effects.stop_looping_3d_sound_effect
					end
				else
					World.move_particles(world, stream_effect_id, from_pos, rotation)

					if self._looping_source_id then
						local current_pos = self._source_position:unbox()
						local new_pos = Vector3.lerp(current_pos, wanted_sound_source_pos, dt * 7)

						self._source_position:store(new_pos)
						WwiseWorld.set_source_position(self._wwise_world, self._looping_source_id, new_pos)
					end
				end

				local speed = stream_effect_data.speed
				local life = distance / speed
				local variable_index = World.find_particles_variable(self._world, stream_effect_name, "life")

				World.set_particles_variable(self._world, self._stream_effect_id, variable_index, Vector3(life, life, life))

				if self._impact_spawn_time == 0 and position_valid then
					local impact_time = t + life * 1.25
					local impact_index = self._impact_index
					local impact_data = self._impact_data
					local data = impact_data[impact_index]
					local normal = position_finder_component.normal

					data.position:store(to_pos)
					data.normal:store(normal)

					data.time = impact_time
					data.effect_name = effects.impact_effect

					local new_impact_index

					new_impact_index = impact_index == #impact_data and 1 or impact_index + 1
					self._impact_index = new_impact_index
					self._impact_spawn_time = self._impact_spawn_rate
				end
			else
				self:_destroy_effects(true, rotation)
			end
		end
	else
		self:_destroy_effects(true, rotation)
	end
	self:_update_moving_lingering_effects(dt, t)
	self:_update_impact_effects(dt, t)
end)

mod:hook("FlamerGasEffects", "_update_impact_effects", function(func, self, dt, t)
	local impact_data = self._impact_data
	local particle_group_id = self._particle_group_id

	for i = 1, #impact_data do
		local data = impact_data[i]
		local impact_time = data.time

		if impact_time and impact_time < t then
			local effect_name = data.effect_name
			if mod:get("remove_flamer_effect") and effect_name == "content/fx/particles/weapons/rifles/zealot_flamer/zealot_flamer_impact_delay" then
				return
			elseif mod:get("remove_purgatus_effect") and effect_name == "content/fx/particles/weapons/flame_staff/psyker_flame_staff_impact_delay" then
				return
			end
		end
	end
	
	return func(self, dt, t)
end)


mod:hook_safe("FlamerPilotLightEffects", "_create_effects", function(self)
	if mod:get("remove_flamer_effect") then
		World.destroy_particles(self._world, self._looping_effect_id)
		self._looping_effect_id = nil
	end
end)
