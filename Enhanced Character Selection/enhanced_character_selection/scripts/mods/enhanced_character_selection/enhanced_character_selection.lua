local mod = get_mod("enhanced_character_selection")

local MainMenuBackgroundViewSettings = require("scripts/ui/views/main_menu_background_view/main_menu_background_view_settings")
local ProfileUtils = require("scripts/utilities/profile_utils")
local MasterItems = require("scripts/backend/master_items")

local HUMAN_STATE_MACHINE = "content/characters/player/human/third_person/animations/menu/state_machines/inventory/inventory_cryptic"
local OGRYN_STATE_MACHINE = "content/characters/player/ogryn/third_person/animations/menu/inventory"
local DOG_STATE_MACHINE = "content/characters/player/companion_dog/third_person/animations/hub"
local SERVO_SKULL_STATE_MACHINE = "content/characters/player/companion_servo_skull/third_person/animations/inventory"
local DOG_ANIMATION = "idle"
local SKULL_ANIMATION = "idle"
local HUMAN_END_POSE = {
	"content/items/animations/end_of_round/end_of_round_broker_003",
	"content/items/animations/end_of_round/end_of_round_psyker_001",
	"content/items/animations/end_of_round/end_of_round_veteran_001"
}
local OGRYN_END_POSE = {
	"content/items/animations/end_of_round/end_of_round_ogryn_001",
	"content/items/animations/end_of_round/end_of_round_ogryn_002",
	"content/items/animations/end_of_round/end_of_round_ogryn_003"
}

local FOCUS_POS_Y = 0
local BACK_ROW_Y = -1.5
local BACK_ROW_SPACING = 1.8 
local DEFAULT_CAMERA_Y = 0
local OGRYN_CAMERA_Y = -2.8
local OGRYN_CAMERA_Z = 0.4
local LERP_SPEED = 5
local CAMERA_LERP_SPEED = 3
local UPDATE_INTERVAL = 0.5

local _multi_spawners = {}
local _spawned_ids = {}
local _selected_index = 1
local _target_positions = {}
local _current_positions = {}
local _last_update_t = 0

local math_min = math.min
local math_lerp = math.lerp
local vector3_lerp = Vector3.lerp
local table_insert = table.insert
local table_index_of = table.index_of

local function is_main_menu_view_active()
    local active_views = Managers.ui:active_views()
    for _, view_name in pairs(active_views) do
        if view_name == "main_menu_view" then
            return true
        end
    end
    return false
end

local function clear_all_spawners()
    for _, s in pairs(_multi_spawners) do
        if s then s:destroy() end
    end
    _multi_spawners = {}
    _spawned_ids = {}
    _target_positions = {}
    _current_positions = {}
end

mod.on_unload = function()
    clear_all_spawners()
end

mod:hook("UIProfileSpawner", "ignore_slot", function(func, self, slot_id)
    if is_main_menu_view_active() then
        if slot_id == "slot_primary" or slot_id == "slot_secondary" then
            return false
        end
    end
    return func(self, slot_id)
end)

mod:hook("MainMenuView", "_set_selected_character_list_index", function(func, self, index)
    func(self, index)
    _selected_index = index
    
    local widgets = self._character_list_widgets
    if widgets and #widgets > 0 then
        local all_profiles = {}
        for i = 1, #widgets do
            if widgets[i].content.profile then
                table_insert(all_profiles, widgets[i].content.profile)
            end
        end
        if #all_profiles > 0 then
            Managers.event:trigger("event_main_menu_set_presentation_profile", all_profiles)
        end
    end
end)

mod:hook("MainMenuBackgroundView", "on_exit", function(func, self)
    clear_all_spawners()
    self._cam_x, self._cam_y, self._cam_z = nil, nil, nil
    self._t_cam_x, self._t_cam_y, self._t_cam_z = nil, nil, nil
    return func(self)
end)

mod:hook("MainMenuBackgroundView", "event_main_menu_set_presentation_profile", function(func, self, profiles)
    if type(profiles[1]) ~= "table" then
        if #_multi_spawners > 0 then return end
        return func(self, profiles)
    end

    self._presentation_profiles = profiles
    local ready_to_spawn = true

    for _, profile in ipairs(profiles) do
        local loaded = false
        if self._profiles_loading_data then
            for _, data in ipairs(self._profiles_loading_data) do
                if data.profile == profile and data.loaded then
                    loaded = true
                    break
                end
            end
        end
        if not loaded then
            ready_to_spawn = false
            if table_index_of(self._loading_profile_queue, profile) == -1 then
                self:_load_profile(profile)
            end
        end
    end

    if ready_to_spawn then
        self:_spawn_profile(profiles)
    end
end)

mod:hook("MainMenuBackgroundView", "_spawn_profile", function(func, self, profiles)
    if type(profiles[1]) ~= "table" then 
        if #_multi_spawners > 0 or self._presentation_profiles then 
            if self._profile_spawner then
                self._profile_spawner:destroy()
                self._profile_spawner = nil
            end
            return 
        end
        return func(self, profiles) 
    end

    local world = self._world_spawner:world()
    local camera = self._world_spawner:camera()
    local unit_spawner = self._world_spawner:unit_spawner()

    if not world or not self._spawn_point_unit then return end

    if self._profile_spawner then
        self._profile_spawner:destroy()
        self._profile_spawner = nil
    end

    Unit.set_unit_visibility(self._dummy_unit, false, true)

    local changed = #profiles ~= #_spawned_ids
    if not changed then
        for i, p in ipairs(profiles) do
            if _spawned_ids[i] ~= p.character_id then 
                changed = true 
                break 
            end
        end
    end

    if changed then 
        clear_all_spawners() 
    end

    local selected_profile = profiles[_selected_index]
    local is_selected_ogryn = selected_profile and selected_profile.archetype.name == "ogryn"
    
    self._t_cam_x = is_selected_ogryn and -0.15 or 0
    self._t_cam_y = is_selected_ogryn and OGRYN_CAMERA_Y or DEFAULT_CAMERA_Y
    self._t_cam_z = is_selected_ogryn and OGRYN_CAMERA_Z or 0

    self._cam_x = self._cam_x or self._t_cam_x
    self._cam_y = self._cam_y or self._t_cam_y
    self._cam_z = self._cam_z or self._t_cam_z

    local base_pos = Unit.world_position(self._spawn_point_unit, 1)
    local base_rot = Unit.world_rotation(self._spawn_point_unit, 1)
    local right = Quaternion.right(base_rot)
    local forward = Quaternion.forward(base_rot)
	local up = Quaternion.up(base_rot)

    local shuffled_human = {}
    local shuffled_ogryn = {}

    local human_index = 1
    local ogryn_index = 1

    for i = 1, #HUMAN_END_POSE do
        shuffled_human[i] = HUMAN_END_POSE[i]
    end
    for i = #shuffled_human, 2, -1 do
        local j = math.random(i)
        shuffled_human[i], shuffled_human[j] = shuffled_human[j], shuffled_human[i]
    end

    for i = 1, #OGRYN_END_POSE do
        shuffled_ogryn[i] = OGRYN_END_POSE[i]
    end
    for i = #shuffled_ogryn, 2, -1 do
        local j = math.random(i)
        shuffled_ogryn[i], shuffled_ogryn[j] = shuffled_ogryn[j], shuffled_ogryn[i]
    end

    for i, profile in ipairs(profiles) do
        local target_pos

        if i == _selected_index then
            target_pos = base_pos + (forward * FOCUS_POS_Y)
        else
            local offset_factor = i - _selected_index
            target_pos = base_pos + (forward * BACK_ROW_Y) + (right * offset_factor * BACK_ROW_SPACING)
        end

        if not _multi_spawners[i] then
            local spawner = UIProfileSpawner:new("MultiSpawner_"..i, world, camera, unit_spawner)

            for _, slot in ipairs(MainMenuBackgroundViewSettings.ignored_slots) do
                spawner:ignore_slot(slot)
            end

            local anim_setting = mod:get("anim_type")
            local wpn_setting = mod:get("wpn_anim_type")
            
            local use_weapon_anim = false
            if anim_setting == "wpn_poses" then
                use_weapon_anim = true
            elseif anim_setting == "both_poses" then
                use_weapon_anim = math.random() < 0.5
            end

            local archetype = profile.archetype.name
            local is_ogryn = archetype == "ogryn"
            
            local possible_slots = {}
            if wpn_setting == "wpn_melee_poses" then
                possible_slots = {"slot_primary"}
            elseif wpn_setting == "wpn_ranged_poses" then
                possible_slots = {"slot_secondary"}
            else
                possible_slots = {"slot_primary", "slot_secondary"}
            end

            local selected_slot = possible_slots[math.random(#possible_slots)]
            local slot_item = profile.loadout[selected_slot]
            
            if not slot_item then
                selected_slot = (selected_slot == "slot_primary") and "slot_secondary" or "slot_primary"
                slot_item = profile.loadout[selected_slot]
            end

            local item_event = slot_item and slot_item.inventory_animation_event or "inventory_idle_default"
            local final_anim, final_state
            local end_pose_id = nil

            if not use_weapon_anim then
                if is_ogryn then
                    end_pose_id = shuffled_ogryn[ogryn_index]
                    ogryn_index = (ogryn_index % #shuffled_ogryn) + 1
                else
                    end_pose_id = shuffled_human[human_index]
                    human_index = (human_index % #shuffled_human) + 1
                end
            end

            local anim_item_data = end_pose_id and MasterItems.get_item(end_pose_id)

            if anim_item_data then
                final_anim = anim_item_data.animation_event
                final_state = anim_item_data.state_machine
            else
                final_anim = item_event
                final_state = is_ogryn and OGRYN_STATE_MACHINE or HUMAN_STATE_MACHINE
            end

            local has_companion = ProfileUtils.has_companion(profile)
            local companion_data = nil
            if archetype == "adamant" and has_companion then
                companion_data = {
                    position = target_pos + (right * 0.7),
                    rotation = base_rot,
                    state_machine = DOG_STATE_MACHINE,
                    --animation_event = DOG_ANIMATION
                }
            end
			
			if archetype == "cryptic" and has_companion then
				companion_data = {
					position = target_pos + (right * -0.8) + (forward * -0.5),
					rotation = base_rot,
					state_machine = SERVO_SKULL_STATE_MACHINE,
					--animation_event = SKULL_ANIMATION
				}
			end

            spawner:spawn_profile(
                profile,
                target_pos,
                base_rot,
                nil, nil, nil, nil, nil, nil, nil, nil, nil,
                companion_data
            )

            spawner:assign_state_machine(final_state, final_anim)

            if final_anim == item_event and slot_item and spawner.wield_slot then
                spawner:wield_slot(selected_slot)
            end

            spawner:toggle_companion(has_companion)

            _multi_spawners[i] = spawner
            _spawned_ids[i] = profile.character_id
            _current_positions[i] = Vector3Box(target_pos)
        end

        _target_positions[i] = Vector3Box(target_pos)
    end
end)

mod:hook("MainMenuBackgroundView", "update", function(func, self, dt, t)
    func(self, dt, t)
    
    if t > _last_update_t then
        _last_update_t = t + UPDATE_INTERVAL
        
        local main_menu_view = Managers.ui:view_instance("main_menu_view")
        if main_menu_view then
            local widgets = main_menu_view._character_list_widgets
            if widgets and #widgets > 0 and #widgets ~= #_spawned_ids then
                local all_profiles = {}
                local has_missing_profile = false
                
                for i = 1, #widgets do
                    local profile = widgets[i].content.profile
                    if profile then
                        table_insert(all_profiles, profile)
                    else
                        has_missing_profile = true
                        break
                    end
                end
                
                if #all_profiles > 0 and not has_missing_profile then
                    _selected_index = main_menu_view._selected_character_list_index or 1
                    self:event_main_menu_set_presentation_profile(all_profiles)
                end
            end
        end
    end

    local lerp_t = math_min(dt * LERP_SPEED, 1)
    local any_spawner_active = false

    for i, spawner in pairs(_multi_spawners) do
        if spawner then
            any_spawner_active = true
            local target_box = _target_positions[i]
            local current_box = _current_positions[i]
            
            if target_box and current_box then
                local target = target_box:unbox()
                local current = current_box:unbox()
                
                if Vector3.distance_squared(current, target) > 0.0001 then
                    local new_pos = vector3_lerp(current, target, lerp_t)
                    current_box:store(new_pos)
                    spawner:set_character_position(new_pos)
                end
            end
            spawner:update(dt, t)
        end
    end

    if any_spawner_active and self._t_cam_y and self._cam_y then
        local cam_lerp_t = math_min(dt * CAMERA_LERP_SPEED, 1)
 
        self._cam_x = math_lerp(self._cam_x, self._t_cam_x, cam_lerp_t)
		self._cam_y = math_lerp(self._cam_y, self._t_cam_y, cam_lerp_t)
		self._cam_z = math_lerp(self._cam_z, self._t_cam_z, cam_lerp_t)
            
		if self._world_spawner then
			self._world_spawner:set_target_camera_offset(self._cam_x, self._cam_y, self._cam_z)
		end
    end
end)

--Visible Equipment compatibility
mod.get_view = function(self, view_name)
    local ui_manager = Managers.ui
    return ui_manager:view_active(view_name) and ui_manager:view_instance(view_name) or nil
end

mod.is_in_main_menu_background_view = function(self)
    return self:get_view("main_menu_background_view") ~= nil
end

mod.visible_equipment_plugin = {
    compatibility = {
        skip_companion_spawn_modification = function(self)
            return self:is_in_main_menu_background_view()
        end,
    }
}