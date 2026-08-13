-- File: weapon_action_details/scripts/mods/weapon_action_details/resources/wad_stamina.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Archetypes = mod:original_require("scripts/settings/archetype/archetypes")
local AttackSettings = mod:original_require("scripts/settings/damage/attack_settings")
local WeaponTweakTemplateSettings = mod:original_require(
    "scripts/settings/equipment/weapon_templates/weapon_tweak_template_settings")
local attack_types = AttackSettings.attack_types
local template_types = WeaponTweakTemplateSettings.template_types
local Localize = Localize

local STAMINA_TEXT_COLOR = "{#color(255,255,255)}"
local RICH_TEXT_RESET = "{#reset()}"

function mod.action_uses_reactive_block_cost(action)
    if not action then
        return false
    end

    local block_attack_types = action.block_attack_types
    local is_blocking_shot = action.kind == "shoot_pellets" and
        type(block_attack_types) == "table" and next(block_attack_types) ~= nil

    return action.kind == "block" or action.kind == "toggle_special_with_block" or action.parry_block or
        is_blocking_shot
end

function mod.action_uses_push_cost(action)
    return action and action.kind == "push" or false
end

local function selected_hit_stickyness_settings(action, use_special_damage_profile)
    if not action then
        return nil
    end

    if use_special_damage_profile then
        return action.hit_stickyness_settings_special_active or action.hit_stickyness_settings
    end

    return action.hit_stickyness_settings
end

local function action_uses_sticky_dodge_cost(action, use_special_damage_profile)
    local hit_stickyness_settings = selected_hit_stickyness_settings(action, use_special_damage_profile)

    if not hit_stickyness_settings or not (use_special_damage_profile or hit_stickyness_settings.always_sticky) then
        return false
    end

    local damage = hit_stickyness_settings.damage

    return damage and damage.dodge_damage_profile ~= nil or false
end

function mod.action_stamina_template(action, weapon_template, weapon_tweak_templates)
    local stamina_templates = weapon_tweak_templates and weapon_tweak_templates[template_types.stamina]

    if not stamina_templates then
        return nil
    end

    local stamina_template_name = action and action.stamina_template or
        weapon_template and weapon_template.stamina_template

    if not stamina_template_name or stamina_template_name == "none" then
        return nil
    end

    return stamina_templates[stamina_template_name]
end

function mod.action_block_cost_group(stamina_template, attack_type)
    if not stamina_template then
        return nil
    end

    if attack_type == attack_types.ranged then
        return stamina_template.block_cost_ranged or stamina_template.block_cost_default
    end

    return stamina_template.block_cost_melee or stamina_template.block_cost_default
end

function mod.format_stamina_cost_text(value_text)
    if type(value_text) ~= "string" then
        return value_text
    end

    return STAMINA_TEXT_COLOR .. value_text .. RICH_TEXT_RESET
end

function mod.viewed_archetype()
    local local_player = Managers.player:local_player_safe(1)
    local profile = local_player and local_player:profile()
    local profile_archetype = profile and profile.archetype
    local archetype_name = profile_archetype and profile_archetype.name
    local archetype = archetype_name and Archetypes[archetype_name] or profile_archetype

    return archetype, archetype_name
end

function mod.action_sticky_dodge_stamina_cost_text(action, stamina_template, use_special_damage_profile)
    if not action_uses_sticky_dodge_cost(action, use_special_damage_profile) then
        return nil
    end

    local hit_stickyness_settings = selected_hit_stickyness_settings(action, use_special_damage_profile)
    local archetype, archetype_name = mod.viewed_archetype()
    local base_stamina_template = archetype and archetype.stamina
    local base_stamina = base_stamina_template and base_stamina_template.base_stamina

    if type(base_stamina) ~= "number" then
        return nil
    end

    local weapon_stamina_modifier = stamina_template and stamina_template.stamina_modifier or 0
    local stamina_drain_percentage = hit_stickyness_settings.dodge_stamina_drain_percentage or 0.6
    local stamina_cost = (base_stamina + weapon_stamina_modifier) * stamina_drain_percentage
    local stamina_cost_text = mod.format_number(stamina_cost)

    if not stamina_cost_text then
        return nil
    end

    local archetype_display_name = archetype and archetype.archetype_name and Localize(archetype.archetype_name) or
        archetype_name

    if archetype_display_name then
        stamina_cost_text = stamina_cost_text .. " (" .. archetype_display_name .. ")"
    end

    return stamina_cost_text
end

local function block_cost_value_text(block_cost_group)
    local inner_cost_text = mod.format_number(block_cost_group and block_cost_group.inner)
    local outer_cost_text = mod.format_number(block_cost_group and block_cost_group.outer)

    if inner_cost_text and outer_cost_text then
        return inner_cost_text .. "/" .. outer_cost_text
    elseif inner_cost_text then
        return inner_cost_text
    elseif outer_cost_text then
        return outer_cost_text
    end

    return nil
end

local function action_block_stamina_cost_text(action, stamina_template)
    local block_attack_types = type(action.block_attack_types) == "table" and action.block_attack_types
    local has_explicit_attack_types = block_attack_types and next(block_attack_types) ~= nil
    local blocks_melee = not has_explicit_attack_types or block_attack_types[attack_types.melee] == true
    local blocks_ranged = has_explicit_attack_types and block_attack_types[attack_types.ranged] == true

    local melee_cost_text = blocks_melee and (action.block_goes_brrr and mod.format_number(0) or
        block_cost_value_text(mod.action_block_cost_group(stamina_template, attack_types.melee)))
    local ranged_cost_text = blocks_ranged and (action.block_goes_brrr and mod.format_number(0) or
        block_cost_value_text(mod.action_block_cost_group(stamina_template, attack_types.ranged)))

    if not melee_cost_text and not ranged_cost_text then
        return nil
    end

    local prefix = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_STAMINA) .. "•" ..
        Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_BLOCK_EFFICIENCY) .. ": "

    if melee_cost_text and ranged_cost_text then
        return prefix .. melee_cost_text .. " " .. Localize(mod.WAD_LOC.SETTING_MELEE) .. " / " ..
            ranged_cost_text .. " " .. Localize(mod.WAD_LOC.SETTING_RANGED)
    elseif melee_cost_text then
        return prefix .. melee_cost_text
    elseif ranged_cost_text then
        return prefix .. ranged_cost_text .. " " .. Localize(mod.WAD_LOC.SETTING_RANGED)
    end
end

function mod.action_stamina_cost_text(action, weapon_template, weapon_tweak_templates, use_special_damage_profile)
    local stamina_template = mod.action_stamina_template(action, weapon_template, weapon_tweak_templates)
    local stamina_text

    if mod.action_uses_push_cost(action) then
        local stamina_cost_text = mod.format_number(stamina_template and stamina_template.push_cost)

        if stamina_cost_text then
            stamina_text = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_STAMINA) .. "•" ..
                Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_PUSH_COST) .. ": " .. stamina_cost_text
        end
    elseif mod.action_uses_reactive_block_cost(action) then
        stamina_text = action_block_stamina_cost_text(action, stamina_template)
    elseif action_uses_sticky_dodge_cost(action, use_special_damage_profile) then
        local stamina_cost_text = mod.action_sticky_dodge_stamina_cost_text(action, stamina_template,
            use_special_damage_profile)

        if stamina_cost_text then
            stamina_text = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_STAMINA) .. "•" ..
                Localize(mod.WAD_LOC.INGAME_DODGE) .. ": " .. stamina_cost_text
        end
    end

    return stamina_text and mod.format_stamina_cost_text(stamina_text) or ""
end

function mod.add_stamina_cost_to_damage_text(damage_text, action, weapon_template, weapon_tweak_templates,
                                             use_special_damage_profile)
    local stamina_text = mod.action_stamina_cost_text(action, weapon_template, weapon_tweak_templates,
        use_special_damage_profile)

    if not stamina_text or stamina_text == "" then
        return damage_text or ""
    end

    if not damage_text or damage_text == "" then
        return stamina_text
    end

    local line_break_start, line_break_end = string.find(damage_text, "\n", 1, true)

    if not line_break_start then
        return damage_text .. "  " .. stamina_text
    end

    return string.sub(damage_text, 1, line_break_start - 1) .. "  " .. stamina_text ..
        string.sub(damage_text, line_break_end)
end
