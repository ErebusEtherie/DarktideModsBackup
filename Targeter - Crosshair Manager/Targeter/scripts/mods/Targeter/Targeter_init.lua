-- File: Targeter/scripts/mods/Targeter/Targeter_init.lua
-- Boot-time discovery & registration helpers (names for UI + external crosshairs).

local mod = get_mod("Targeter")
if not mod then return end

if mod._targeter_init_done then return end
mod._targeter_init_done = true

local DMF = get_mod and get_mod("DMF") or nil
local string_sub = string.sub

mod.all_crosshair_names = mod.all_crosshair_names or {}

local _crosshair_seen = {}
for i = 1, #mod.all_crosshair_names do
    _crosshair_seen[mod.all_crosshair_names[i]] = true
end

local function _add_crosshair(name)
    if not _crosshair_seen[name] then
        _crosshair_seen[name] = true
        mod.all_crosshair_names[#mod.all_crosshair_names + 1] = name
    end
end

mod.vanilla_crosshair_names = {
    "none", "assault", "bfg", "charge_up", "charge_up_ads", "cross", "dot",
    "flamer", "ironsight", "projectile_drop", "shotgun", "shotgun_wide", "spray_n_pray",
}
for i = 1, #mod.vanilla_crosshair_names do
    _add_crosshair(mod.vanilla_crosshair_names[i])
end

local targeter_crosshairs = {
    "larger_dot", "chevron",
    "charge_up_peril", "charge_up_ads_peril",
    "charge_up_peril_larger_dot", "charge_up_ads_peril_larger_dot",
}
for i = 1, #targeter_crosshairs do
    _add_crosshair(targeter_crosshairs[i])
end

mod.custom_crosshair_names     = mod.custom_crosshair_names or {}
mod.custom_crosshair_templates = mod.custom_crosshair_templates or {}

if DMF and DMF.mods then
    for _, other_mod in pairs(DMF.mods) do
        if type(other_mod) == "table" then
            local is_enabled = other_mod.is_enabled
            local enabled = (is_enabled == nil) or
                (type(is_enabled) == "function" and other_mod:is_enabled()) or
                (type(is_enabled) == "boolean" and is_enabled)

            local remap_crosshairs = other_mod.crosshair_remap_crosshairs
            if enabled and type(remap_crosshairs) == "table" then
                for i = 1, #remap_crosshairs do
                    local settings = remap_crosshairs[i]
                    local n = settings and settings.name
                    local p = settings and settings.template
                    if n and p and not _crosshair_seen[n] then
                        mod.custom_crosshair_names[#mod.custom_crosshair_names + 1] = n
                        mod.custom_crosshair_templates[n] = p
                        _add_crosshair(n)
                    end
                end
            end
        end
    end
end

function mod.get_crosshair_options()
    local names = mod.all_crosshair_names
    local opts = Script.new_array(#names)
    for i = 1, #names do
        local name = names[i]
        opts[i] = { text = name, value = name }
    end
    return opts
end

local SHAPE_SETTINGS = {
    shape_editor_default_shape = true,
    shape_editor_enemy_shape = true,
    shape_editor_weakspot_shape = true,
}

function mod.populate_shape_options()
    if not (DMF and DMF.options_widgets_data) then return end
    local crosshair_options = mod.get_crosshair_options()
    local widgets_data = DMF.options_widgets_data

    for i = 1, #widgets_data do
        local mod_widgets = widgets_data[i]
        if mod_widgets[1] and mod_widgets[1].mod_name == "Targeter" then
            for j = 1, #mod_widgets do
                local widget = mod_widgets[j]
                if widget.type == "dropdown" and type(widget.setting_id) == "string" and SHAPE_SETTINGS[widget.setting_id] then
                    widget.options = crosshair_options
                end
            end
            break
        end
    end
end

-- ####################################################################
-- ##### Dynamic Weapon Class Generation ##############################
-- ####################################################################
mod.HARDCODED_CLASSES = {
    "melee_class",
    "melee_throwing_class",
    "psyker_smite_class",
    "psyker_throwing_knives_class",
    "psyker_chain_lightning_class",
    "broker_missile_launcher_class",
}

local split_families = {
    shotgun_p1 = true,
    shotgun_p4 = true,
    stubrevolver_p1 = true,
}

mod.dynamic_weapon_classes = {}
mod.weapon_class_to_template_map = {}
mod.weapon_class_loc_keys = {}

local function init_dynamic_classes()
    local UiSettings = require("scripts/settings/ui/ui_settings")
    local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")

    for family_name, family_data in pairs(UiSettings.weapon_patterns) do
        local marks = family_data.marks
        if marks and #marks > 0 then
            local is_ranged = false
            for i = 1, #marks do
                local template = WeaponTemplates[marks[i].name]
                local keywords = template and template.keywords
                if keywords then
                    for j = 1, #keywords do
                        if keywords[j] == "ranged" then
                            is_ranged = true
                            break
                        end
                    end
                end
                if is_ranged then break end
            end

            -- Optimization: string.sub is faster than string.find
            if is_ranged and string_sub(family_name, 1, 4) ~= "bot_" then
                if split_families[family_name] then
                    local loc_key = family_data.display_name or ("loc_weapon_family_" .. family_name)
                    for i = 1, #marks do
                        local mark = marks[i]
                        local template = WeaponTemplates[mark.name]
                        if template then
                            local class_id = mark.name .. "_class"
                            mod.dynamic_weapon_classes[#mod.dynamic_weapon_classes + 1] = class_id
                            mod.weapon_class_to_template_map[mark.name] = class_id
                            mod.weapon_class_loc_keys[class_id] = { type = "mark", key = mark.name, family_loc = loc_key }
                        end
                    end
                else
                    local class_id = family_name .. "_class"
                    mod.dynamic_weapon_classes[#mod.dynamic_weapon_classes + 1] = class_id

                    for i = 1, #marks do
                        mod.weapon_class_to_template_map[marks[i].name] = class_id
                    end
                    local loc_key = family_data.display_name or ("loc_weapon_family_" .. family_name)
                    mod.weapon_class_loc_keys[class_id] = { type = "family", key = loc_key }
                end
            end
        end
    end
    table.sort(mod.dynamic_weapon_classes)
end

init_dynamic_classes()
