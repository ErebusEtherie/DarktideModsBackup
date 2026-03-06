-- File: Targeter/scripts/mods/Targeter/core/util.lua
-- Shared helpers, state, classifiers, constants, and default shape profiles.

local mod = get_mod("Targeter")
if not mod then return end

mod.crosshair_ui_hud         = mod.crosshair_ui_hud or nil
mod.crosshair_state          = mod.crosshair_state or "default"

mod.game_mode_is_hub         = (mod.game_mode_is_hub ~= nil) and mod.game_mode_is_hub or false

mod._carried_ranged_template = mod._carried_ranged_template or nil
mod._carried_ranged_class    = mod._carried_ranged_class or nil

mod.inventory_slot_component = mod.inventory_slot_component or nil

mod.ADS_END_GRACE            = mod.ADS_END_GRACE or 0.2

mod.template_paths           = mod.template_paths or {
    "Targeter/scripts/mods/Targeter/crosshairs/larger_dot",
    "Targeter/scripts/mods/Targeter/crosshairs/chevron",
    "Targeter/scripts/mods/Targeter/crosshairs/crosshair_template_charge_up_peril",
    "Targeter/scripts/mods/Targeter/crosshairs/crosshair_template_charge_up_ads_peril",
    "Targeter/scripts/mods/Targeter/crosshairs/crosshair_template_charge_up_peril_larger_dot",
    "Targeter/scripts/mods/Targeter/crosshairs/crosshair_template_charge_up_ads_peril_larger_dot",
}

function mod.now()
    local tman = Managers and Managers.time
    if tman and tman.time then
        return tman:time("gameplay") or tman:time("ui") or tman:time("main") or 0
    end
    return (os and os.clock and os.clock()) or 0
end

if not mod.deep_clone then
    function mod.deep_clone(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do
            out[mod.deep_clone(k)] = mod.deep_clone(v)
        end
        return out
    end
end

function mod.has_zealot_throwing_knives()
    local mgr = Managers and Managers.player
    local player = mgr and mgr:local_player_safe(1)
    if not player then return false end

    local profile = player:profile()
    if not profile then return false end

    if player.archetype_name and player:archetype_name() ~= "zealot" then return false end

    local talents = profile.talents
    local v = talents and talents.zealot_throwing_knives
    return v == true or v == 1
end

mod.WeaponClassifier = mod.WeaponClassifier or {}

local SPECIAL_WEAPON_CLASSES = {
    psyker_smite = "psyker_smite_class",
    psyker_throwing_knives = "psyker_throwing_knives_class",
    psyker_chain_lightning = "psyker_chain_lightning_class",
    missile_launcher = "broker_missile_launcher_class",
}

function mod.WeaponClassifier.determine_ranged_weapon_class(weapon_template)
    if not weapon_template then return nil end
    local name = weapon_template.name

    local special_class = SPECIAL_WEAPON_CLASSES[name]
    if special_class then return special_class end

    local map = mod.weapon_class_to_template_map
    return map and map[name] or nil
end

function mod.current_carried_ranged_weapon_template()
    if mod._carried_ranged_template then
        return mod._carried_ranged_template
    end

    local ui_hud     = mod.crosshair_ui_hud
    local exts       = ui_hud and ui_hud.player_extensions and ui_hud:player_extensions()

    local weapon_ext = exts and exts.weapon
    local weapons    = weapon_ext and weapon_ext._weapons
    local ranged     = weapons and weapons.slot_secondary
    return ranged and ranged.weapon_template or nil
end

function mod.current_carried_ranged_weapon_class()
    if mod._carried_ranged_class then
        return mod._carried_ranged_class
    end
    local tmpl = mod.current_carried_ranged_weapon_template()
    return tmpl and mod.WeaponClassifier.determine_ranged_weapon_class(tmpl) or nil
end

function mod.current_weapon_class_or_fallback()
    return mod.current_carried_ranged_weapon_class() or nil
end

mod.DEFAULT_PROFILE = mod.DEFAULT_PROFILE or {
    primary   = { default = "dot", enemy = "larger_dot", weakspot = "larger_dot" },
    secondary = { default = "dot", enemy = "larger_dot", weakspot = "larger_dot" },
    special   = { default = "none", enemy = "none", weakspot = "none" },
}
