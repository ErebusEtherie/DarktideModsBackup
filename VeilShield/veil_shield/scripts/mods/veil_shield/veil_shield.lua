local mod = get_mod("veil_shield")

local TARGET_ITEMS = {
    slab_shield = "content/items/weapons/player/melee/ogryn_powermaul_slabshield_p1_m1",
    suppression_shields = {
        "content/items/weapons/player/melee/powermaul_shield_p1_m1",
        "content/items/weapons/player/melee/powermaul_shield_p1_m2",
    },
}

local current_weapon_unit = nil
local hidden_weapon_unit = nil
local fade_target_alpha = 0
local current_alpha = 0
local fade_speed = mod:get("fade_speed")

local function is_valid(unit)
    return unit and Unit.is_valid(unit)
end

local function get_active_item_name()
    local local_player = Managers.player:local_player_safe(1)
    if not local_player then return end

    local player_unit = local_player.player_unit
    if not player_unit or not ALIVE[player_unit] then return end

    local unit_data_ext = ScriptUnit.has_extension(player_unit, "unit_data_system")
    if not unit_data_ext then return end

    local inventory_component = unit_data_ext:read_component("inventory")
    local slot_name = inventory_component and inventory_component.wielded_slot
    if not slot_name then return end

    local visual_loadout_ext = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
    if not visual_loadout_ext then return end

    local slot = visual_loadout_ext:item_from_slot(slot_name)
    return slot and slot.name, slot_name, player_unit
end

local function set_unit_transparency(unit, alpha)
    if not is_valid(unit) then return end
    Unit.set_shader_pass_flag_for_meshes(unit, "one_bit_alpha", true, true)
    Unit.set_scalar_for_materials(unit, "inv_jitter_alpha", alpha, true)
end

local function should_hide_item(item_name)
    if not item_name then return false end
    if item_name == TARGET_ITEMS.slab_shield then
        return mod:get("hide_slab_shield")
    end
    for _, name in ipairs(TARGET_ITEMS.suppression_shields) do
        if item_name == name then
            return mod:get("hide_suppression_shield")
        end
    end
    return false
end

mod:hook_safe("PlayerUnitWeaponExtension", "_wielded_weapon", function(self, inventory_component, weapons)
    current_weapon_unit = weapons and weapons.slot_primary and weapons.slot_primary.weapon_unit or nil

    if hidden_weapon_unit and hidden_weapon_unit ~= current_weapon_unit then
        set_unit_transparency(hidden_weapon_unit, 0)
        hidden_weapon_unit = nil
        current_alpha = 0
    end

    local item_name = get_active_item_name()
    if should_hide_item(item_name) and is_valid(current_weapon_unit) then
        hidden_weapon_unit = current_weapon_unit
    end
end)

mod:hook_safe("ActionBlock", "start", function(self, action_settings, t, time_scale, action_start_params)
    if action_settings.kind ~= "block_windup" and is_valid(hidden_weapon_unit) then
        local item_name = get_active_item_name()
        if should_hide_item(item_name) then
            fade_target_alpha = mod:get("shield_opacity")
        end
    end
end)

mod:hook_safe("ActionBlock", "finish", function(self, reason, data, t, ...)
    if is_valid(hidden_weapon_unit) then
        fade_target_alpha = 0
    end
end)

mod:hook("World", "create_particles", function(func, world, particle_name, ...)
    if particle_name == "content/fx/particles/weapons/shields/arbites_shield_chargeup_lightnings_01" then
        return
    end
    return func(world, particle_name, ...)
end)

mod.on_setting_changed = function(name)
    if name == "fade_speed" then
        fade_speed = mod:get("fade_speed")
    end
end

mod.update = function(dt)
    if is_valid(hidden_weapon_unit) then
        if math.abs(current_alpha - fade_target_alpha) > 0.001 then
            if current_alpha < fade_target_alpha then
                current_alpha = math.min(fade_target_alpha, current_alpha + fade_speed * dt)
            else
                current_alpha = math.max(fade_target_alpha, current_alpha - fade_speed * dt)
            end
            set_unit_transparency(hidden_weapon_unit, current_alpha)
        else
            current_alpha = fade_target_alpha
            set_unit_transparency(hidden_weapon_unit, current_alpha)
        end
    end
end
