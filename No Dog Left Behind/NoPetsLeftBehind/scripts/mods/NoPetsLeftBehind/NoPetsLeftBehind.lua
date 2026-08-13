local mod = get_mod("NoPetsLeftBehind")
local DOG_STATE_MACHINE = "content/characters/player/companion_dog/third_person/animations/hub"
local SERVO_SKULL_STATE_MACHINE = "content/characters/player/companion_servo_skull/third_person/animations/inventory"
local COMPANION_SLOT_NAME = "slot_companion_gear_full"
local DOG_ANIMATION = "sit"
local SKULL_ANIMATION = "idle"
local ProfileUtils = require("scripts/utilities/profile_utils")

local function is_mission_intro_active()
    local active_views = Managers.ui:active_views()
    for _, view_name in pairs(active_views) do
        if view_name == "mission_intro_view" then
            return true
        end
    end
    return false
end

mod:hook("UIProfileSpawner", "ignore_slot", function(func, self, slot_id)
    if is_mission_intro_active() and slot_id == COMPANION_SLOT_NAME then
        return true
    end

    return func(self, slot_id)
end)

mod:hook("UIProfileSpawner", "_spawn_character_profile", function(func, self, profile, loader, pos, rot, scale, sm, anim, fsm, fanim, mip, hair, unit, ign_sm, companion_data)
    if not is_mission_intro_active() then
        return func(self, profile, loader, pos, rot, scale, sm, anim, fsm, fanim, mip, hair, unit, ign_sm, companion_data)
    end

    local archetype = profile.archetype.name
    local archetypes_config = {
        ["adamant"] = {
            state_machine = DOG_STATE_MACHINE,
            --animation_event = DOG_ANIMATION,
            get_pos = function(base_pos, height_offset)
                if mod:get("use_alternative_pos") then
                    return base_pos + Vector3(0.5, 0, height_offset)
                end
                return base_pos + Vector3(0, -(math.random(70, 90) / 100), height_offset)
            end,
            get_height = function(has_companion) return has_companion and 0 or -100 end
        },
        ["cryptic"] = {
            state_machine = SERVO_SKULL_STATE_MACHINE,
            --animation_event = SKULL_ANIMATION,
            get_pos = function(base_pos, height_offset)
                return base_pos + Vector3(0.2, -0.1, height_offset)
            end,
            get_height = function(has_companion) return has_companion and 0.7 or -100 end
        }
    }

    local config = archetypes_config[archetype]
    
    if config then
        companion_data = companion_data or {}
        local has_companion = ProfileUtils.has_companion(profile)
        local base_pos = companion_data.position or pos or Vector3.zero()
        local height_offset = config.get_height(has_companion)

        companion_data.position = config.get_pos(base_pos, height_offset)
        companion_data.state_machine = config.state_machine
        companion_data.animation_event = config.animation_event
    end

    return func(self, profile, loader, pos, rot, scale, sm, anim, fsm, fanim, mip, hair, unit, ign_sm, companion_data)
end)

--Visible Equipment compatibility
mod.get_view = function(self, view_name)
    local ui_manager = Managers.ui
    return ui_manager:view_active(view_name) and ui_manager:view_instance(view_name) or nil
end

mod.is_in_mission_intro_view = function(self)
    return self:get_view("mission_intro_view") ~= nil
end

mod.visible_equipment_plugin = {
    compatibility = {
        skip_companion_spawn_modification = function(self)
            return self:is_in_mission_intro_view()
        end,
    }
}
