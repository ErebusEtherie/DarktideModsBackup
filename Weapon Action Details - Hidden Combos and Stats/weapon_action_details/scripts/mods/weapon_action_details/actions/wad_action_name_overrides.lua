-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_name_overrides.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Text = mod:original_require("scripts/utilities/ui/text")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local Localize = Localize

-- ============================================================================
-- OVERRIDE LOOKUP TABLES
-- ============================================================================

local FIRE_MODE_DISPLAY_TEXT = UISettings.weapon_fire_type_display_text or {}

local LASGUN_P2_CHARGED_ACTION_OVERRIDES = {
    action_shoot_hip_charged = {
        localization_key = mod.WAD_LOC.WEAPON_STATS_DISPLAY_HIP_FIRE,
        suffix_localization_key = mod.WAD_LOC.WEAPON_KEYWORD_CHARGED_ATTACK,
        displayed_attack_key = "primary",
    },
    action_zoom_shoot_charged = {
        localization_key = mod.WAD_LOC.RANGED_ATTACK_SECONDARY_ADS,
        suffix_localization_key = mod.WAD_LOC.WEAPON_KEYWORD_CHARGED_ATTACK,
        displayed_attack_key = "secondary",
    },
}

local PLASMAGUN_P1_CHARGED_ACTION_OVERRIDES = {
    action_shoot_charged = {
        localization_key = mod.WAD_LOC.RANGED_ATTACK_SECONDARY_BRACED,
        suffix_localization_key = mod.WAD_LOC.WEAPON_KEYWORD_CHARGED_ATTACK,
        displayed_attack_key = "secondary",
    },
}

local RANGED_SHOOT_ACTION_TEMPLATE_OVERRIDES = {
    dual_stubpistols_p1_m1 = {
        action_special_shoot_right = {
            localization_key = mod.WAD_LOC.WEAPON_SPECIAL_WEAPON_POWERUP_DUAL_STUBPISTOLS_P1,
        },
        action_special_shoot_left = {
            localization_key = mod.WAD_LOC.WEAPON_SPECIAL_WEAPON_POWERUP_DUAL_STUBPISTOLS_P1,
        },
    },
    lasgun_p2_m1 = LASGUN_P2_CHARGED_ACTION_OVERRIDES,
    lasgun_p2_m2 = LASGUN_P2_CHARGED_ACTION_OVERRIDES,
    lasgun_p2_m3 = LASGUN_P2_CHARGED_ACTION_OVERRIDES,
    ogryn_gauntlet_p1_m1 = {
        action_shoot_zoomed = {
            localization_key = mod.WAD_LOC.RANGED_ATTACK_SECONDARY_BRACED,
            fire_mode_localization_key = mod.WAD_LOC.WEAPON_STATS_FIRE_MODE_PROJECTILE,
        },
    },
    plasmagun_p1_m1 = PLASMAGUN_P1_CHARGED_ACTION_OVERRIDES,
    plasmagun_p1_m2 = PLASMAGUN_P1_CHARGED_ACTION_OVERRIDES,
}

local RANGED_SHOOT_ACTION_DISPLAY_DATA = {
    action_shoot = {
        localization_key = mod.WAD_LOC.RANGED_ATTACK_PRIMARY,
        displayed_attack_key = "primary",
    },
    action_shoot_hip = {
        localization_key = mod.WAD_LOC.RANGED_ATTACK_PRIMARY,
        displayed_attack_key = "primary",
    },
    action_shoot_hip_from_reload = {
        prefix_localization_key = mod.WAD_LOC.BASIC_RELOAD_INPUT,
        localization_key = mod.WAD_LOC.RANGED_ATTACK_PRIMARY,
        displayed_attack_key = "primary",
    },
    action_shoot_zoomed = {
        localization_key = mod.WAD_LOC.RANGED_ATTACK_SECONDARY_ADS,
        displayed_attack_key = "secondary",
    },
    action_shoot_braced = {
        localization_key = mod.WAD_LOC.RANGED_ATTACK_SECONDARY_BRACED,
        displayed_attack_key = "secondary",
    },
    action_shoot_blocking = {
        localization_key = mod.WAD_LOC.BLOCK,
        displayed_attack_key = "secondary",
    },
}

-- ============================================================================
-- EXPORTED OVERRIDE RESOLVERS
-- ============================================================================

function mod.ranged_shoot_action_display_name(action_name, weapon_template)
    local weapon_template_name = weapon_template and weapon_template.name
    local template_overrides = weapon_template_name and RANGED_SHOOT_ACTION_TEMPLATE_OVERRIDES[weapon_template_name]
    local template_override = template_overrides and template_overrides[action_name]

    -- Handle template-specific hardcoded overrides (e.g. Helbore Lasguns)
    if template_override then
        local display_name = Localize(template_override.localization_key)
        local suffix_localization_key = template_override.suffix_localization_key

        if suffix_localization_key then
            display_name = display_name .. "•" .. Localize(suffix_localization_key)
        end

        local fire_mode_localization_key = template_override.fire_mode_localization_key
        local displayed_attack_key = template_override.displayed_attack_key

        if not fire_mode_localization_key and displayed_attack_key then
            local displayed_attacks = weapon_template and weapon_template.displayed_attacks
            local displayed_attack = displayed_attacks and displayed_attacks[displayed_attack_key]
            local fire_mode = displayed_attack and displayed_attack.fire_mode

            fire_mode_localization_key = type(fire_mode) == "string" and FIRE_MODE_DISPLAY_TEXT[fire_mode]
        end

        if fire_mode_localization_key then
            display_name = display_name .. "•" .. Text.localize_to_title_case(fire_mode_localization_key)
        end

        return display_name
    end

    -- Handle generic ranged shoot actions
    local display_data = RANGED_SHOOT_ACTION_DISPLAY_DATA[action_name]
    if not display_data then
        return nil
    end

    local display_name = Localize(display_data.localization_key)
    local prefix_localization_key = display_data.prefix_localization_key

    if prefix_localization_key then
        display_name = Localize(prefix_localization_key) .. "•" .. display_name
    end

    local displayed_attacks = weapon_template and weapon_template.displayed_attacks
    local displayed_attack = displayed_attacks and displayed_attacks[display_data.displayed_attack_key]
    local fire_mode = displayed_attack and displayed_attack.fire_mode
    local fire_mode_localization_key = type(fire_mode) == "string" and FIRE_MODE_DISPLAY_TEXT[fire_mode]

    if fire_mode_localization_key then
        display_name = display_name .. "•" .. Text.localize_to_title_case(fire_mode_localization_key)
    end

    return display_name
end

function mod.manual_action_display_name_override(action_name, weapon_template)
    local actions = weapon_template and weapon_template.actions
    local action = actions and actions[action_name]
    local action_kind = action and action.kind

    if action_name == "action_vent" and action_kind == "vent_warp_charge" then
        return Localize(mod.WAD_LOC.INPUT_DESCRIPTION_VENT)
    elseif (action_name == "action_vent" or action_name == "action_vent_override") and
        action_kind == "vent_overheat" then
        return Localize(mod.WAD_LOC.WEAPON_SPECIAL_WEAPON_VENT)
    end

    local displayed_attacks = weapon_template and weapon_template.displayed_attacks
    local secondary_attack = displayed_attacks and displayed_attacks.secondary
    local secondary_stance_localization_key = secondary_attack and secondary_attack.type == "brace" and
        mod.WAD_LOC.RANGED_ATTACK_SECONDARY_BRACED or mod.WAD_LOC.RANGED_ATTACK_SECONDARY_ADS

    if action_name == "action_unzoom" then
        return Localize(mod.WAD_LOC.TRAINING_GROUNDS_CHOICE_QUIT) .. "•" ..
            Localize(secondary_stance_localization_key)
    elseif action_name == "action_zoom" then
        return Localize(mod.WAD_LOC.TRAINING_GROUNDS_VIEW_OPTION_ENTER) .. "•" ..
            Localize(secondary_stance_localization_key)
    elseif action_name == "action_zoom_fast" then
        return Localize(mod.WAD_LOC.CONTINUE) .. "•" ..
            Localize(secondary_stance_localization_key)
    elseif action_name == "action_zoom_from_shoot" then
        return Localize(mod.WAD_LOC.RANGED_ATTACK_PRIMARY) .. "•" ..
            Localize(mod.WAD_LOC.TRAINING_GROUNDS_VIEW_OPTION_ENTER) .. "•" ..
            Localize(secondary_stance_localization_key)
    elseif action_name == "action_unzoom_from_shoot" then
        return Localize(mod.WAD_LOC.RANGED_ATTACK_PRIMARY) .. "•" ..
            Localize(mod.WAD_LOC.TRAINING_GROUNDS_CHOICE_QUIT) .. "•" ..
            Localize(secondary_stance_localization_key)
    elseif action_name == "action_unbrace" or action_name == "action_unaim" then
        return Localize(mod.WAD_LOC.TRAINING_GROUNDS_CHOICE_QUIT) .. "•" ..
            Localize(mod.WAD_LOC.RANGED_ATTACK_SECONDARY_BRACED)
    elseif action_name == "action_brace" then
        return Localize(mod.WAD_LOC.TRAINING_GROUNDS_VIEW_OPTION_ENTER) .. "•" ..
            Localize(mod.WAD_LOC.RANGED_ATTACK_SECONDARY_BRACED)
    elseif action_name == "action_reload_loop" then
        return Localize(mod.WAD_LOC.CONTINUE) .. "•" ..
            Localize(mod.WAD_LOC.BASIC_RELOAD_INPUT)
    elseif action_name == "action_start_reload" then
        return Localize(mod.WAD_LOC.MAIN_MENU_PLAY_BUTTON) .. "•" ..
            Localize(mod.WAD_LOC.BASIC_RELOAD_INPUT)
    end

    return nil
end
