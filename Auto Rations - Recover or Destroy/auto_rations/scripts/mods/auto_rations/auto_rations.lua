local mod = get_mod("auto_rations")

local cooldown = 0
local interact_ready = false

function mod.update(dt)
	if not mod:get("enable_ration_mod") then return end

    if cooldown > 0 then
        cooldown = cooldown - dt
    end
end

mod:hook_safe("HudElementInteraction", "update", function(self)
	if not mod:get("enable_ration_mod") then return end

    if not self._active_presentation_data then
        interact_ready = false
        return
    end

    local interactor_extension = self._active_presentation_data.interactor_extension
    local hud_description = interactor_extension and interactor_extension:hud_description()
    if not hud_description then
        interact_ready = false
        return
    end

    if hud_description == "loc_stolen_rations_pickup_small" or hud_description == "loc_stolen_rations_pickup_medium" then
        interact_ready = true
    else
        interact_ready = false
    end
end)

mod:hook("InputService", "_get", function(func, self, action_name)
    if mod:get("enable_ration_mod") and cooldown <= 0 and interact_ready then
        local action = mod:get("ration_action")

        if action == "pickup" and action_name == "interact_primary_pressed" then
            cooldown = 0.35
            return true
        elseif action == "destroy" and action_name == "interact_secondary_pressed" then
            cooldown = 0.35
            return true
        end
    end

    return func(self, action_name)
end)

