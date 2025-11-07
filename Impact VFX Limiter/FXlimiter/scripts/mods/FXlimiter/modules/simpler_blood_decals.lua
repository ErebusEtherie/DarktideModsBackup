local mod = get_mod("FXlimiter")
local BloodSettings = require("scripts/settings/blood/blood_settings")
local blood_ball_settings = BloodSettings.blood_ball
local damage_type_speed = BloodSettings.blood_ball.damage_type_speed
local default_speed = damage_type_speed.default
local blood_ball_to_type = {
	["content/decals/blood_ball/blood_ball_poxwalker"] = "poxwalker",
	["content/decals/blood_ball/blood_ball"] = "default"
}

mod:hook(CLASS.BloodManager, "queue_blood_ball", function(func, self, position, direction, blood_ball_unit, optional_damage_type)
	local blood_decals_enabled = self:_blood_decals_enabled()

	if not blood_decals_enabled then
		return
	end
	
	if not Vector3.is_valid(position) then
		return
	end

	if not mod:get("simpler_blood_decals") then
		return func(self, position, direction, blood_ball_unit, optional_damage_type)
	end

	if Managers.state.decal ~= nil then
		local speed = damage_type_speed[optional_damage_type]
	
		if not speed then
			speed = default_speed
		end
		
		local physics_world = Managers.state.extension:system("fx_system")._physics_world
		
		--cast it 7.5 meters, blood balls move at what i assume is 15 meters per second
		local ray, hit_pos, dis, normal, _ = PhysicsWorld.raycast(physics_world, position, direction, 7.5, "types", "statics", "collision_filter", "filter_player_character_shooting_raycast_statics")
		
		if ray and normal then
			local dot_value = Vector3.dot(normal, direction)
			local tangent = Vector3.normalize(direction - dot_value * normal)
			local tangent_rotation = Quaternion.look(tangent, normal)
			local blood_type = blood_ball_to_type[blood_ball_unit] or "default"
			local decals = blood_ball_settings.blood_type_decal[blood_type]
			local decal_unit_name = decals[math.random(1, #decals)]
			local extents = Vector3(2.5, 2.5, 2.5)
			local t = Managers.time:time("gameplay")

			Managers.state.decal:add_projection_decal(decal_unit_name, hit_pos, tangent_rotation, normal, extents, nil, nil, t)
		end
	end
end)