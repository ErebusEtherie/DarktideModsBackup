local mod = get_mod("transonic_slayer")
mod._is_slayer = false

local TRANSIONIC_WEAPON_NAME = "transonic_sword_transonic_knife_p1_m1"

local RELEVANT_MATERIALS = {
    blade_energy = true,
    blade_wiggle = true,
}

local function make_mapper(min_out, max_out)
    local min_in, max_in = 10, 100
    return function(value)
        local result = ((value - min_in) / (max_in - min_in)) * (min_out - max_out) + max_out
        return math.max(min_out, math.min(max_out, result))
    end
end 

local map_energy = make_mapper(-1.0, -0.05)
local map_wiggle = make_mapper(-1.0, -0.25)

local function track_slayer_state(self, is_active, reason)
    if reason ~= "manual_toggle" and reason ~= "unwield" then
      return
    end

    local weapon_template = self:weapon_template()
    local template_name = weapon_template and weapon_template.name

    if template_name and template_name == TRANSIONIC_WEAPON_NAME then
        mod._is_slayer = is_active
    end
end

-- https://github.com/Aussiemon/Darktide-Source-Code/blob/master/scripts/extension_systems/weapon/player_unit_weapon_extension.lua
mod:hook_safe("PlayerUnitWeaponExtension", "set_wielded_weapon_weapon_special_active", function(self, t, is_active, reason)
    track_slayer_state(self, is_active, reason)
end)

mod:hook("Unit", "set_scalar_for_material", function(func, unit, material, property, value)
    if not RELEVANT_MATERIALS[material] then
        return func(unit, material, property, value)
    end

    if mod._is_slayer then
        if material == "blade_energy" then
            value = map_energy(mod:get("blade_energy") or 15)
        elseif material == "blade_wiggle" then
            value = map_wiggle(mod:get("blade_wiggle") or 15)
        end
    end

    return func(unit, material, property, value)
end)
