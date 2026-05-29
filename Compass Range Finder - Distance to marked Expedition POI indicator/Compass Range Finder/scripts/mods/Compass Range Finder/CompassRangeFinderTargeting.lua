local Targeting = {}

local math_abs = math.abs
local math_deg = math.deg
local math_huge = math.huge
local Managers = rawget(_G, "Managers")


local function get_center_offset(compass_element, position, effective_rotation)
	if not effective_rotation then
		return math_huge
	end
	local target_angle_radians = compass_element:_get_position_direction_angle(position)
	if not target_angle_radians then
		return math_huge
	end
	local target_angle_degrees = math_deg(target_angle_radians)
	return math_abs((target_angle_degrees - effective_rotation + 540) % 360 - 180)
end

-- Helper to consider a registry for marked expedition targets
local function consider_registry(registry, navigation_handler, compass_element, effective_rotation, local_slot, selected)
	for id, position_box in pairs(registry or {}) do
		if position_box then
			local marked_by_player_slot = navigation_handler:player_slot_by_level_marked(id)
			if marked_by_player_slot then
				local position = position_box:unbox()
				local distance = compass_element:_get_distance_to_objective(position)
				local center_offset = get_center_offset(compass_element, position, effective_rotation)
				local same_slot = (local_slot ~= nil) and (marked_by_player_slot == local_slot)
				if not selected.target
					or center_offset < selected.center_offset
					or (center_offset == selected.center_offset and same_slot and not selected.same_slot)
					or (center_offset == selected.center_offset and same_slot == selected.same_slot and distance < selected.distance) then
					selected.target = {
						slot = marked_by_player_slot,
						position = position,
						distance = distance,
					}
					selected.center_offset = center_offset
					selected.same_slot = same_slot
					selected.distance = distance
				end
			end
		end
	end
end

Targeting.is_expedition_active = function(compass_element)
	if not compass_element or not compass_element._show_compass then
		return false
	end

	local navigation_handler = compass_element._navigation_handler
	if not navigation_handler or not navigation_handler.is_active then
		return false
	end

	return navigation_handler:is_active()
end

Targeting.get_marked_expedition_target = function(compass_element)
	local navigation_handler = compass_element and compass_element._navigation_handler
	if not navigation_handler then return nil end

	local player_manager = Managers and Managers.player
	local local_player = compass_element._my_player or (player_manager and player_manager:local_player(1))
	local local_slot = local_player and local_player.slot and local_player:slot()
	local player_angle_radians = compass_element:_get_camera_direction_angle()
	local effective_rotation = player_angle_radians and -math_deg(player_angle_radians)

	local selected = {
		target = nil,
		center_offset = math_huge,
		same_slot = false,
		distance = math_huge,
	}

	consider_registry(navigation_handler:get_registered_opportunities(), navigation_handler, compass_element, effective_rotation, local_slot, selected)
	consider_registry(navigation_handler:get_registered_exits(), navigation_handler, compass_element, effective_rotation, local_slot, selected)
	consider_registry(navigation_handler:get_registered_extractions(), navigation_handler, compass_element, effective_rotation, local_slot, selected)

	return selected.target
end

Targeting.get_extra_opportunities_target = function(compass_element)
	if not compass_element then
		return nil
	end

	local extra_mod = get_mod("Extra Opportunities")
	if not extra_mod or not extra_mod.get_closest_traversal_target then
		return nil
	end

	if extra_mod.is_enabled and not extra_mod:is_enabled() then
		return nil
	end

	local ok, target = pcall(extra_mod.get_closest_traversal_target, compass_element)
	   if not ok or not target or not target.position or type(target.distance) ~= "number" then
		   return nil
	   end
	return target
end

return Targeting
