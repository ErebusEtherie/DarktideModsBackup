-- File: Targeter/scripts/mods/Targeter/core/gear.lua
-- Keep Targeter aware of the carried ranged weapon via on_slot_wielded.
-- (Consolidated with wield.lua)

local mod = get_mod("Targeter")
if not mod then return end

local ScriptUnit_has_extension = ScriptUnit.has_extension

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self, slot_name, ...)
    local pm = Managers and Managers.player
    local local_player = pm and pm:local_player_safe(1)

    if not local_player or self._player ~= local_player then
        return
    end

    mod._last_wielded_slot = slot_name
    mod._ads_poll_active = false

    local weapons = self._weapons
    if not weapons then return end

    local secondary_weapon = weapons.slot_secondary
    local secondary_template = secondary_weapon and secondary_weapon.weapon_template

    if slot_name == "slot_secondary" or not mod._carried_ranged_template then
        if secondary_template then
            mod._carried_ranged_template = secondary_template
            mod._carried_ranged_class = mod.WeaponClassifier.determine_ranged_weapon_class(secondary_template) or nil
            mod._uses_overheat_current = (secondary_template.uses_overheat == true)
        else
            if slot_name == "slot_secondary" then
                mod._carried_ranged_template = nil
                mod._carried_ranged_class = nil
                mod._uses_overheat_current = nil
            end
        end
    end

    if slot_name == "slot_secondary" and secondary_template then
        local unit_data = ScriptUnit_has_extension(self._unit, "unit_data_system")
        if unit_data then
            mod.inventory_slot_component = unit_data:read_component(slot_name)
        end
    end
end)
