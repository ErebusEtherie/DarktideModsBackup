-- File: RingHud/scripts/mods/RingHud/context/wield_context.lua

local mod = get_mod("RingHud")
if not mod then return {} end

if mod.wield_context_initialized then
    return {}
end
mod.wield_context_initialized = true

-- Team/shared constants
local C = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")

-- Consistent time source (match other RingHud modules: ui -> gameplay -> os.clock)
local function _now_ui_pref()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("ui") or MT:time("gameplay") or os.clock()
    end
    return os.clock()
end

-- Templates that should drive the pocketables latches
local STIMM_TEMPLATES = {
    syringe_corruption_pocketable    = true,
    syringe_power_boost_pocketable   = true,
    syringe_speed_boost_pocketable   = true,
    syringe_ability_boost_pocketable = true,
}

local CRATE_TEMPLATES = {
    medical_crate_pocketable = true,
    ammo_cache_pocketable    = true,
    tome_pocketable          = true,
    grimoire_pocketable      = true,
}

-- Install the hook once.
if not mod._wield_hook_applied and CLASS and CLASS.PlayerUnitWeaponExtension then
    mod:hook(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded",
        function(func, weapon_ext_self, slot_name, t, skip_wield_action)
            local result = func(weapon_ext_self, slot_name, t, skip_wield_action)

            -- Only care about local-player wields
            local pm = Managers.player
            local local_player = pm and pm.local_player_safe and pm:local_player_safe(1)
            local local_player_unit = local_player and local_player.player_unit

            if not local_player_unit or weapon_ext_self._unit ~= local_player_unit then
                return result
            end

            local now = _now_ui_pref()

            -- Try to read template (used for heal-tool and pocketable latches)
            local visual_loadout_ext = ScriptUnit.has_extension(weapon_ext_self._unit, "visual_loadout_system")
                and ScriptUnit.extension(weapon_ext_self._unit, "visual_loadout_system") or nil
            local weapon_template = visual_loadout_ext and visual_loadout_ext:weapon_template_from_slot(slot_name) or nil
            local item_name = weapon_template and weapon_template.name or ""

            ----------------------------------------------------------------
            -- Heal-tool latch (existing behaviour, preserved)
            ----------------------------------------------------------------
            -- Specifically corruption syringe OR medical crate → drives teammate HP reassurance rules.
            if item_name == "syringe_corruption_pocketable"
                or item_name == "medical_crate_pocketable"
            then
                -- Keep local player ring visible briefly (existing behavior)
                if mod.hud_instance and mod.hud_instance._health_change_visibility_timer ~= nil then
                    mod.hud_instance._health_change_visibility_timer =
                        mod.hud_instance._health_change_visibility_duration
                end

                -- Publish heal-wield latch for teammate HP context rules
                local heal_dur = (C and C.LOCAL_WIELD_LATCH_SEC) or 10
                mod.local_wield_heal_tool_until = now + heal_dur
            end

            ----------------------------------------------------------------
            -- Pocketables latches (for central visibility policy)
            ----------------------------------------------------------------
            local latch_dur = (C and (C.WIELD_POCKETABLE_LATCH_SEC or C.LOCAL_WIELD_LATCH_SEC)) or 10

            -- Any *known* stimm template: drives `any_stimm_wield_latched()`
            if STIMM_TEMPLATES[item_name] then
                mod.local_wield_any_stimm_until = now + latch_dur
            end

            -- Any *known* crate/tome/grimoire template: drives `any_crate_wield_latched()`
            if CRATE_TEMPLATES[item_name] then
                mod.local_wield_any_crate_until = now + latch_dur

                -- Specific ammo-cache wield latch (drives teammate munitions visibility)
                if item_name == "ammo_cache_pocketable" then
                    mod.local_wield_ammo_cache_until = now + latch_dur
                end
            end

            return result
        end
    )

    mod._wield_hook_applied = true
end

return {}
