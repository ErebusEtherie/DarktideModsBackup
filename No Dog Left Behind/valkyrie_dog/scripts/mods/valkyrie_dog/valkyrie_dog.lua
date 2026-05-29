local mod = get_mod("valkyrie_dog")
local HUB_ANIM_PATH = "content/characters/player/companion_dog/third_person/animations/hub"
local COMPANION_SLOT_NAME = "slot_companion_gear_full"
local ANIMATION = "sit"
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

    local has_companion = ProfileUtils.has_companion(profile)
    local height_offset = has_companion and 0 or -100
    
    companion_data = companion_data or {}
    local base_pos = companion_data.position or pos or Vector3.zero()

    if mod:get("use_alternative_pos") then
        companion_data.position = base_pos + Vector3(0.5, 0, height_offset)
    else
        local random_offset = math.random(70, 90) / 100
        companion_data.position = base_pos + Vector3(0, -random_offset, height_offset)
    end

    companion_data.state_machine = HUB_ANIM_PATH
    companion_data.animation_event = ANIMATION

    return func(self, profile, loader, pos, rot, scale, sm, anim, fsm, fanim, mip, hair, unit, ign_sm, companion_data)
end)