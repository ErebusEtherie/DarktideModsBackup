-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_icons.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local UISettings = mod:original_require("scripts/settings/ui/ui_settings")

-- ============================================================================
-- CONSTANTS & CACHE
-- ============================================================================

-- Exported so the fallback resolvers can return these specific UI textures
mod.PRESET_ICON_MATERIALS = {
    blood_drop = "content/ui/materials/icons/presets/preset_13",
    bullets = "content/ui/materials/icons/presets/preset_16",
    cogwheel = "content/ui/materials/icons/presets/preset_02",
    crossed_swords = "content/ui/materials/icons/presets/preset_01",
    crosshairs = "content/ui/materials/icons/presets/preset_14",
    explosion = "content/ui/materials/icons/presets/preset_19",
    flame = "content/ui/materials/icons/presets/preset_20",
    lightning = "content/ui/materials/icons/presets/preset_11",
    shield = "content/ui/materials/icons/presets/preset_04",
    skull = "content/ui/materials/icons/presets/preset_05",
}

-- Weak-keyed table prevents memory leaks when weapon templates are garbage collected
local ACTION_ICON_CACHE = setmetatable({}, {
    __mode = "k",
})

-- ============================================================================
-- ICON RESOLUTION HELPERS
-- ============================================================================

function mod.supported_action_type(action_type)
    local weapon_action_type_icons = UISettings.weapon_action_type_icons

    return type(action_type) == "string" and weapon_action_type_icons and
        weapon_action_type_icons[action_type] and action_type or nil
end

local function action_type_icon_material(action_type)
    local supported_type = mod.supported_action_type(action_type)

    return supported_type and UISettings.weapon_action_type_icons[supported_type] or nil
end

local function resolve_action_type_icon(weapon_template, action_name)
    local action_type = mod.supported_action_type(mod.action_type_from_generated_stats(weapon_template, action_name))

    if not action_type then
        action_type = mod.action_type_from_explicit_combo(weapon_template, action_name)
    end

    if not action_type then
        action_type = mod.action_type_from_special_metadata(weapon_template, action_name)
    end

    if not action_type then
        action_type = mod.action_type_from_ranged_context(weapon_template, action_name)
    end

    if not action_type then
        local actions = weapon_template and weapon_template.actions
        action_type = mod.action_type_from_kind(actions and actions[action_name])
    end

    if not action_type then
        action_type = mod.supported_action_type(mod.action_type_from_sweep_damage_profiles(weapon_template, action_name))
    end

    if not action_type then
        action_type = mod.supported_action_type(mod.action_type_from_action_name(weapon_template, action_name))
    end

    return action_type_icon_material(action_type) or mod.ranged_action_fallback_icon(weapon_template, action_name)
end

-- ============================================================================
-- EXPORTED ORCHESTRATOR
-- ============================================================================

function mod.action_type_icon(weapon_template, action_name)
    if type(weapon_template) ~= "table" or type(action_name) ~= "string" then
        return nil
    end

    local cached_icons = ACTION_ICON_CACHE[weapon_template]

    if not cached_icons then
        cached_icons = {}
        ACTION_ICON_CACHE[weapon_template] = cached_icons
    elseif cached_icons[action_name] ~= nil then
        return cached_icons[action_name] or nil
    end

    local icon = resolve_action_type_icon(weapon_template, action_name)

    cached_icons[action_name] = icon or false

    return icon
end
