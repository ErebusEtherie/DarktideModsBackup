local Targeting = {}

local math_abs = math.abs
local math_deg = math.deg
local math_huge = math.huge

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
	if not navigation_handler then
		return nil
	end

	local player_manager = Managers and Managers.player
	local local_player = compass_element._my_player or (player_manager and player_manager:local_player(1))
	local local_slot = local_player and local_player.slot and local_player:slot()
	local player_angle_radians = compass_element:_get_camera_direction_angle()
	local effective_rotation = player_angle_radians and -math_deg(player_angle_radians)

	local selected_target
	local selected_center_offset = math_huge
	local selected_same_slot = false
	local selected_distance = math_huge

	local function consider_registry(registry)
		for id, position_box in pairs(registry or {}) do
			if position_box then
				local marked_by_player_slot = navigation_handler:player_slot_by_level_marked(id)
				if marked_by_player_slot then
					local position = position_box:unbox()
					local distance = compass_element:_get_distance_to_objective(position)
					local center_offset = get_center_offset(compass_element, position, effective_rotation)
					local same_slot = local_slot and marked_by_player_slot == local_slot or false

					if not selected_target
						or center_offset < selected_center_offset
						or (center_offset == selected_center_offset and same_slot and not selected_same_slot)
						or (center_offset == selected_center_offset and same_slot == selected_same_slot and distance < selected_distance) then
						selected_target = {
							slot = marked_by_player_slot,
							position = position,
							distance = distance,
						}
						selected_center_offset = center_offset
						selected_same_slot = same_slot
						selected_distance = distance
					end
				end
			end
		end
	end

	consider_registry(navigation_handler:get_registered_opportunities())
	consider_registry(navigation_handler:get_registered_exits())
	consider_registry(navigation_handler:get_registered_extractions())

	return selected_target
end

return Targeting
