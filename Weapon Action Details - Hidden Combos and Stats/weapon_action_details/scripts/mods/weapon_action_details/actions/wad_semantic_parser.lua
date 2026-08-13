-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_semantic_parser.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")

-- ============================================================================
-- CONSTANTS & KEYWORDS
-- ============================================================================

local RANGED_STANCE_ACTION_KINDS = {
    aim = true,
    unaim = true,
    block_aiming = true,
    block_unaim = true,
}

local MECHANICAL_ACTION_KINDS = {
    reload_shotgun = true,
    reload_state = true,
}

local FLAME_SEMANTIC_TOKENS = {
    "flame",
    "flamer",
    "burn",
    "incendiary",
    "phosphor",
}

local EXPLOSION_SEMANTIC_TOKENS = {
    "explosion",
    "explosive",
    "grenade",
    "blast",
    "detonat",
}

local LIGHTNING_SEMANTIC_TOKENS = {
    "lightning",
    "electric",
    "electro",
    "shock",
    "arc_rifle",
    "chain_arc",
    "chain_lightning",
    "smite",
}

local ACTION_SEMANTIC_FIELD_NAMES = {
    "damage_type",
    "damage_type_special_active",
    "damage_profile",
    "damage_profile_special_active",
    "inner_damage_profile",
    "outer_damage_profile",
    "projectile_template",
    "shotshell_template",
    "shot_template",
}

-- ============================================================================
-- SEMANTIC PARSING LOGIC
-- ============================================================================

local function string_has_semantic_token(value, semantic_tokens)
    if type(value) ~= "string" then
        return false
    end

    value = string.lower(value)

    for i = 1, #semantic_tokens do
        if string.find(value, semantic_tokens[i], 1, true) then
            return true
        end
    end

    return false
end

local function semantic_field_value(field_value)
    if type(field_value) == "string" then
        return field_value
    end

    return type(field_value) == "table" and field_value.name or nil
end

function mod.action_has_semantic_token(action_name, action, semantic_tokens)
    if string_has_semantic_token(action_name, semantic_tokens) or
        string_has_semantic_token(action and action.kind, semantic_tokens) then
        return true
    end

    for i = 1, #ACTION_SEMANTIC_FIELD_NAMES do
        local field_value = action and action[ACTION_SEMANTIC_FIELD_NAMES[i]]

        if string_has_semantic_token(semantic_field_value(field_value), semantic_tokens) then
            return true
        end
    end

    if type(action) ~= "table" then
        return false
    end

    local num_damage_templates = Action.num_damage_templates(action)

    for template_index = 1, num_damage_templates do
        local damage_profile, special_damage_profile = Action.damage_template(action, template_index)

        if string_has_semantic_token(damage_profile and damage_profile.name, semantic_tokens) or
            string_has_semantic_token(special_damage_profile and special_damage_profile.name, semantic_tokens) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- FALLBACK ICON RESOLVER
-- ============================================================================

local function action_uses_blocking(action)
    local block_attack_types = action and action.block_attack_types

    return action and action.kind == "block" or
        type(block_attack_types) == "table" and next(block_attack_types) ~= nil
end

local function action_is_melee_attack(action)
    local kind = action and action.kind
    return kind == "sweep" or kind == "push" or kind == "melee_explosive"
end

local function action_is_aiming_operation(action)
    local kind = action and action.kind

    return RANGED_STANCE_ACTION_KINDS[kind] or
        type(kind) == "string" and
        (string.find(kind, "target_finder", 1, true) or string.find(kind, "position_finder", 1, true))
end

local function action_is_ammunition_attack(action)
    local kind = action and action.kind

    return type(kind) == "string" and (string.starts_with(kind, "shoot") or kind == "flamer_gas")
end

function mod.ranged_action_fallback_icon(weapon_template, action_name)
    if not mod.weapon_template_is_ranged(weapon_template) then
        return nil
    end

    local actions = weapon_template.actions
    local action = actions and actions[action_name]

    if type(action) ~= "table" then
        return nil
    end

    if action_uses_blocking(action) then
        return mod.PRESET_ICON_MATERIALS.shield
    elseif mod.action_has_semantic_token(action_name, action, FLAME_SEMANTIC_TOKENS) then
        return mod.PRESET_ICON_MATERIALS.flame
    elseif mod.action_has_semantic_token(action_name, action, EXPLOSION_SEMANTIC_TOKENS) then
        return mod.PRESET_ICON_MATERIALS.explosion
    elseif mod.action_has_semantic_token(action_name, action, LIGHTNING_SEMANTIC_TOKENS) then
        return mod.PRESET_ICON_MATERIALS.lightning
    elseif action_is_melee_attack(action) then
        return mod.PRESET_ICON_MATERIALS.crossed_swords
    elseif action_is_aiming_operation(action) then
        return mod.PRESET_ICON_MATERIALS.crosshairs
    elseif action_is_ammunition_attack(action) then
        return mod.PRESET_ICON_MATERIALS.bullets
    elseif MECHANICAL_ACTION_KINDS[action.kind] then
        return mod.PRESET_ICON_MATERIALS.cogwheel
    end

    return nil
end
