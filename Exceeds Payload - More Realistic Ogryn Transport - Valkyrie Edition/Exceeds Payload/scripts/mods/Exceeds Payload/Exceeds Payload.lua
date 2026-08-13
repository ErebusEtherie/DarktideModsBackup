--[[
Name: Exceeds Payload
Author: Wobin
Date: 29/05/2026
Version: 1.0
Repository: https://github.com/Wobin/Exceeds-Payload
--]]

local mod = get_mod("Exceeds Payload")
mod.version = "1.0"

local Unit = Unit
local World = World
local Camera = Camera
local Vector3 = Vector3
local Quaternion = Quaternion
local Managers = Managers
local pairs = pairs
local math_sin = math.sin
local math_rad = math.rad

local BOB_SPEED = 0.9
local WALLOW_DEG = 1.5
local WALLOW_SPEED = 0.6

local function count_ogryn()
	local count = 0
	local players = Managers.player and Managers.player:players()

	if players then
		for _, player in pairs(players) do
			if player:breed_name() == "ogryn" then
				count = count + 1
			end
		end
	end

	return count
end

local function resolve_tilt(ep, spawn_slots, cam_pos, cam_rot)
	local positions = ep.ogryn_positions

	if not positions then
		if not spawn_slots then
			return 0
		end

		positions = {}

		for ii = 1, #spawn_slots do
			local slot = spawn_slots[ii]

			if slot.occupied and slot.player and slot.player:breed_name() == "ogryn" then
				positions[#positions + 1] = slot.boxed_position
			end
		end

		if #positions == 0 then
			return 0
		end

		ep.ogryn_positions = positions
	end

	local net = 0
	local right = Quaternion.right(cam_rot)

	for ii = 1, #positions do
		local to_slot = Vector3.from_array(positions[ii]) - cam_pos

		net = net + (Vector3.dot(to_slot, right) >= 0 and 1 or -1)
	end

	return net
end
mod.on_all_mods_loaded = function()
	mod:info(mod.version)
	
	mod:hook_safe("MissionIntroView", "event_register_mission_intro_camera", function(self, camera_unit)
		local count = count_ogryn()

		if count <= 0 then
			return
		end

		self._ep = {
			cam_unit = camera_unit,
			camera   = self._world_spawner:camera(),
			world    = self._world_spawner:world(),
			ogryn    = count,
		}
	end)

	mod:hook_safe("MissionIntroView", "update", function(self, dt, t, input_service)
		local ep = self._ep
		local camera = ep and ep.camera

		if not camera or ep.ogryn <= 0 then
			return
		end

		local cam_unit = ep.cam_unit
		local per_ogryn_sag = mod:get("ep_sag_deg")
		local per_ogryn_settle = mod:get("ep_settle_deg")
		local per_imbalance_tilt = mod:get("ep_list_deg")

		local node_pos = Unit.world_position(cam_unit, 1)
		local node_rot = Unit.world_rotation(cam_unit, 1)
		local cam_pos = node_pos + Quaternion.rotate(node_rot, Camera.local_position(camera, cam_unit))
		local cam_rot = Quaternion.multiply(node_rot, Camera.local_rotation(camera, cam_unit))

		local pitch = ep.ogryn * per_ogryn_sag + math_sin(t * BOB_SPEED) * (ep.ogryn * per_ogryn_settle)
		local roll = math_sin(t * WALLOW_SPEED) * WALLOW_DEG

		if per_imbalance_tilt > 0 then
			roll = roll - resolve_tilt(ep, self._spawn_slots, cam_pos, cam_rot) * per_imbalance_tilt
		end

		local new_rot = Quaternion.multiply(Quaternion.axis_angle(Quaternion.right(cam_rot), math_rad(-pitch)), cam_rot)

		if roll ~= 0 then
			new_rot = Quaternion.multiply(Quaternion.axis_angle(Quaternion.forward(new_rot), math_rad(roll)), new_rot)
		end

		Unit.set_local_position(cam_unit, 1, cam_pos)
		Unit.set_local_rotation(cam_unit, 1, new_rot)
		World.update_unit(ep.world, cam_unit)
	end)
end