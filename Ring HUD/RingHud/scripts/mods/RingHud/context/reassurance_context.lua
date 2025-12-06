-- File: RingHud/scripts/mods/RingHud/context/reassurance_context.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local ReassuranceSystem = {}

local HEALING_LOC_SET = table.set({
    "loc_health_station",
    "loc_pickup_pocketable_01", -- Generic stimm pickup
    "loc_pickup_pocketable_medical_crate_01",
})

local AMMO_LOC_SET = table.set({
    "loc_pickup_consumable_small_clip_01",
    "loc_pickup_consumable_large_clip_01",
    "loc_pickup_deployable_ammo_crate_01",
    "loc_pickup_pocketable_ammo_crate_01",
    "loc_action_interaction_inactive_ammo_full",
    "loc_action_interaction_inactive_no_ammo",
})

function ReassuranceSystem.init()
    mod:hook_safe("HudElementInteraction", "update", function(self)
        if self._active_presentation_data and self._active_presentation_data.interactor_extension then
            local hud_description = self._active_presentation_data.interactor_extension:hud_description()
            if hud_description then
                if AMMO_LOC_SET[hud_description] then
                    mod.reassure_ammo = true
                    mod.reassure_ammo_last_set_time = mod._ringhud_accumulated_time or 0
                elseif HEALING_LOC_SET[hud_description] then
                    mod.reassure_health = true
                    mod.reassure_health_last_set_time = mod._ringhud_accumulated_time or 0
                end
            end
        end
    end)
end

return ReassuranceSystem
