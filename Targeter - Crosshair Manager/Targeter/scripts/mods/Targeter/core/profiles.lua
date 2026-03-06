-- File: Targeter/scripts/mods/Targeter/core/profiles.lua
-- Color settings, shape-profile storage, and compact editor glue.

local mod = get_mod("Targeter")
if not mod then return end

mod.color_types = mod.color_types or {
    default         = {},
    target_locked   = {},
    weakspot_locked = {},
}

local DEFAULT_PROFILE = mod.DEFAULT_PROFILE
local ACTION_KEYS = { "primary", "secondary", "special" }

-- ####################################################################
-- ##### Colors (universal) ############################################
-- ####################################################################
local function _rgba_from_dropdown(color_setting, alpha_setting)
    local color_name = mod:get(color_setting) or "ui_white"
    local a          = mod:get(alpha_setting) or 255
    local ctor       = Color[color_name]
    if type(ctor) == "function" then
        return ctor(a, true)
    end
    return { a or 255, 255, 255, 255 }
end

function mod.collect_settings()
    local ct           = mod.color_types
    ct.default         = _rgba_from_dropdown("default_color", "default_alpha")
    ct.target_locked   = _rgba_from_dropdown("target_locked_color", "target_locked_alpha")
    ct.weakspot_locked = _rgba_from_dropdown("weakspot_locked_color", "weakspot_locked_alpha")
end

-- ####################################################################
-- ##### Shape profiles (persisted) ####################################
-- ####################################################################
-- Stored as: mod.shape_profiles[weapon_class][action_key].{default|enemy|weakspot} = crosshair_name
mod.shape_profiles = mod.shape_profiles or mod:get("shape_profiles") or nil

local function _ensure_profile_table(tbl)
    if not tbl.primary then
        tbl.primary = mod.deep_clone(DEFAULT_PROFILE.primary)
    end
    if not tbl.secondary then
        tbl.secondary = mod.deep_clone(DEFAULT_PROFILE.secondary)
    end
    if not tbl.special then
        tbl.special = mod.deep_clone(DEFAULT_PROFILE.special)
    end
    return tbl
end

local _cached_weapon_classes = nil
local function _all_weapon_classes()
    if _cached_weapon_classes then
        return _cached_weapon_classes
    end

    local classes = {}

    if mod.HARDCODED_CLASSES then
        for _, hc in ipairs(mod.HARDCODED_CLASSES) do
            classes[#classes + 1] = hc
        end
    end

    if mod.dynamic_weapon_classes then
        for _, dyn in ipairs(mod.dynamic_weapon_classes) do
            classes[#classes + 1] = dyn
        end
    end

    _cached_weapon_classes = classes
    return classes
end

function mod.ensure_shape_profiles()
    if not mod.shape_profiles then mod.shape_profiles = {} end

    for _, cls in ipairs(_all_weapon_classes()) do
        if not mod.shape_profiles[cls] then
            local base = mod.DEFAULT_PROFILE
            mod.shape_profiles[cls] = mod.deep_clone(base)
        else
            _ensure_profile_table(mod.shape_profiles[cls])
            for _, action_key in ipairs(ACTION_KEYS) do
                local action_tbl = mod.shape_profiles[cls][action_key]
                if type(action_tbl) == "string" then
                    mod.shape_profiles[cls][action_key] = {
                        default = action_tbl,
                        enemy = action_tbl,
                        weakspot = action_tbl
                    }
                else
                    action_tbl.default  = action_tbl.default or mod.DEFAULT_PROFILE[action_key].default
                    action_tbl.enemy    = action_tbl.enemy or mod.DEFAULT_PROFILE[action_key].enemy
                    action_tbl.weakspot = action_tbl.weakspot or mod.DEFAULT_PROFILE[action_key].weakspot
                end
            end
        end
    end
end

local function _current_secondary_ranged_class()
    local parent = mod.crosshair_ui_hud
    local exts   = parent and parent.player_extensions and parent:player_extensions()
    if exts then
        local weapon_ext = exts.weapon
        local weapons    = weapon_ext and weapon_ext._weapons
        local ranged     = weapons and weapons.slot_secondary
        local tpl        = ranged and ranged.weapon_template
        if tpl then
            return mod.WeaponClassifier.determine_ranged_weapon_class(tpl)
        end
    end

    local pman   = Managers and Managers.player
    local player = pman and pman:local_player_safe(1)
    local unit   = player and player.player_unit
    if unit and Unit.alive(unit) then
        local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system")
        local weapon_ext    = ScriptUnit.has_extension(unit, "weapon_system")
        local weapons       = weapon_ext and weapon_ext._weapons
        local ranged        = weapons and weapons.slot_secondary
        local tpl           = ranged and ranged.weapon_template
        if tpl then return mod.WeaponClassifier.determine_ranged_weapon_class(tpl) end
    end

    return nil
end

function mod.sync_editor_fields_to_class(target_class)
    mod.ensure_shape_profiles()
    local cls       = target_class or mod:get("shape_editor_weapon_class") or "melee_class"
    local action    = mod:get("shape_editor_action_state") or "primary"
    local prof      = mod.shape_profiles[cls] or mod.DEFAULT_PROFILE
    local state_tbl = (prof and prof[action]) or mod.DEFAULT_PROFILE[action]
    mod:set("shape_editor_default_shape", state_tbl.default, false)
    mod:set("shape_editor_enemy_shape", state_tbl.enemy, false)
    mod:set("shape_editor_weakspot_shape", state_tbl.weakspot, false)
end

function mod.save_editor_fields_to_class_action(target_class, action)
    mod.ensure_shape_profiles()
    local cls               = target_class or mod:get("shape_editor_weapon_class") or "melee_class"
    local act               = action or mod:get("shape_editor_action_state") or "primary"
    mod.shape_profiles[cls] = _ensure_profile_table(mod.shape_profiles[cls] or {})
    local state_tbl         = mod.shape_profiles[cls][act]
    state_tbl.default       = mod:get("shape_editor_default_shape")
    state_tbl.enemy         = mod:get("shape_editor_enemy_shape")
    state_tbl.weakspot      = mod:get("shape_editor_weakspot_shape")
    mod:set("shape_profiles", mod.shape_profiles, true)
end

function mod.save_editor_fields_to_class(target_class)
    return mod.save_editor_fields_to_class_action(target_class, nil)
end

-- ####################################################################
-- ##### DMF Events ###################################################
-- ####################################################################
mod.on_enabled = function()
    mod.collect_settings()
    mod.ensure_shape_profiles()
    mod.sync_editor_fields_to_class(mod:get("shape_editor_weapon_class") or "melee_class")
    mod._last_weapon_class = mod:get("shape_editor_weapon_class") or "melee_class"
    mod._last_action_state = mod:get("shape_editor_action_state") or "primary"
    mod:set("shape_profiles", mod.shape_profiles, true)
end

mod.on_all_mods_loaded = function()
    mod.collect_settings()
    mod.ensure_shape_profiles()
    mod.sync_editor_fields_to_class(mod:get("shape_editor_weapon_class") or "melee_class")
    mod._last_weapon_class = mod:get("shape_editor_weapon_class") or "melee_class"
    mod._last_action_state = mod:get("shape_editor_action_state") or "primary"
    mod:set("shape_profiles", mod.shape_profiles, true)
end

mod.on_setting_changed = function(id)
    if id == "default_color" or id == "default_alpha"
        or id == "target_locked_color" or id == "target_locked_alpha"
        or id == "weakspot_locked_color" or id == "weakspot_locked_alpha" then
        mod.collect_settings()
        return
    end

    if id == "use_current_ranged_weapon" and mod:get("use_current_ranged_weapon") then
        local cls = _current_secondary_ranged_class()
        if cls then
            mod:set("shape_editor_weapon_class", cls, true)
        else
            mod:echo("Could not resolve secondary ranged class right now.")
        end
        mod:set("use_current_ranged_weapon", false, false)
        return
    end

    if id == "shape_editor_action_state" then
        local prev_action = mod._last_action_state or "primary"
        mod.save_editor_fields_to_class_action(mod:get("shape_editor_weapon_class"), prev_action)
        mod._last_action_state = mod:get("shape_editor_action_state") or "primary"
        mod.sync_editor_fields_to_class(mod:get("shape_editor_weapon_class"))
        return
    end

    if id == "shape_editor_weapon_class" then
        local prev_class = mod._last_weapon_class or (mod:get("shape_editor_weapon_class") or "melee_class")
        mod.save_editor_fields_to_class_action(prev_class, mod:get("shape_editor_action_state") or "primary")
        mod._last_weapon_class = mod:get("shape_editor_weapon_class") or "melee_class"
        mod.sync_editor_fields_to_class(mod._last_weapon_class)
        return
    end

    if id == "shape_editor_default_shape" or id == "shape_editor_enemy_shape" or id == "shape_editor_weakspot_shape" then
        mod.save_editor_fields_to_class(mod:get("shape_editor_weapon_class"))
        return
    end
end
