local mod = get_mod("AutoLoot")

local pickup = false
local cooldown = 0.0

mod:hook("InputService", "_get", function(func, self, action_name)
    if cooldown <= 0 and pickup and action_name == "interact_pressed" then
        cooldown = 0.35
        return true 
    end
    return func(self, action_name)
end)

function mod.update(dt)
    if cooldown > 0 then 
        cooldown = cooldown - dt 
    end
end

mod:hook_safe("HudElementInteraction", "update", function(self)
    if self._active_presentation_data then
        local interactor_extension = self._active_presentation_data.interactor_extension
        local hud_description = interactor_extension:hud_description()

        if hud_description == nil then
            return
        end
        
        pickup = false

        local player = Managers.player:local_player(1)
        local player_unit = player.player_unit
        local unit_data_extension = ScriptUnit.extension(player_unit, "unit_data_system")
        local visual_loadout_extension = ScriptUnit.extension(player_unit, "visual_loadout_system")
        local pocketable_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable")
        local weapon_slot_configuration = visual_loadout_extension:slot_configuration_by_type("weapon")
        local stimm_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable_small")

        if mod:get("open_chests") and (hud_description == "loc_chest") then
            pickup = true
            return
        end

        if mod:get("pickup_materials") and (hud_description == "loc_pickup_small_metal" or hud_description == "loc_pickup_large_metal") then
            pickup = true
            return
        end

        if mod:get("pickup_materials") and (hud_description == "loc_pickup_small_platinum" or hud_description == "loc_pickup_large_platinum") then
            pickup = true
            return
        end

        if mod:get("pickup_crates") and (hud_description == "loc_pickup_pocketable_medical_crate_01" and not pocketable_template) then
            pickup = true
            return
        end

        if mod:get("pickup_crates") and (hud_description == "loc_pickup_pocketable_ammo_crate_01" and not pocketable_template) then
            pickup = true
            return
        end

        if mod:get("pickup_stimms") and not stimm_template and (hud_description == "loc_pickup_pocketable_01" or hud_description == "loc_pickup_syringe_pocketable_02" or hud_description == "loc_pickup_syringe_pocketable_03" or hud_description == "loc_pickup_syringe_pocketable_04") then
            pickup = true
            return
        end


        -- Ammo Function
        local curr_ammo_res = 0
        local curr_ammo_clip = 0
        local max_ammo_res = 0
        local max_ammo_clip = 0

        for slot in pairs(weapon_slot_configuration) do
            local wieldable_component = unit_data_extension:write_component(slot)
            if wieldable_component.max_ammunition_reserve > 0 then
                curr_ammo_res = wieldable_component.current_ammunition_reserve
                curr_ammo_clip = wieldable_component.current_ammunition_clip[1]
                max_ammo_res = wieldable_component.max_ammunition_reserve
                max_ammo_clip = wieldable_component.max_ammunition_clip[1]
                break
            end
        end

        local max_ammo = max_ammo_res + max_ammo_clip
        local curr_ammo = curr_ammo_clip + curr_ammo_res
        local percentage_threshold = curr_ammo / max_ammo
        if mod:get("pickup_ammo") and (hud_description == "loc_pickup_consumable_large_clip_01" or hud_description == "loc_pickup_consumable_small_clip_01") then
            if percentage_threshold <= mod:get("ammo_threshold") / 100 then
                pickup = true
                return
            end
        end


        -- Grenades Function
        local grenades = unit_data_extension._read_components.grenade_ability.num_charges
        if not grenades then
            return
        end

        if mod:get("pickup_grenades") and (hud_description == "loc_pickup_consumable_small_grenade_01" or hud_description == "loc_pickup_consumable_large_grenade_01") then
            if grenades <= mod:get("grenades_threshold") then
                pickup = true
                return
            end
        end
    end
end)
