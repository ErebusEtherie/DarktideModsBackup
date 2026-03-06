-- ===== File: Targeter/scripts/mods/Targeter/Targeter_localization.lua =====

local InputUtils = require("scripts/managers/input/input_utils")
local mod = get_mod("Targeter")

mod:io_dofile("Targeter/scripts/mods/Targeter/Targeter_init")
local Localize = Localize

local string_sub = string.sub
local string_upper = string.upper
local string_match = string.match
local string_gsub = string.gsub
local string_split = string.split
local string_format = string.format
local table_concat = table.concat

local localizations = {
    mod_description                         = {
        en =
        "Customize crosshair color and shape per target (enemy/weakspot), per action state (hip-fire, ADS/Block, Activated Special), and weapon class. Peril/heat crosshairs tint with peril level.",
    },

    color_settings                          = { en = "Universal Colour Settings", },
    color_settings_description              = { en = "These colours/alphas apply to all crosshairs unless a template has its own logic (e.g., Peril/Heat templates tint by peril level).", },
    shape_editor                            = { en = Localize("loc_setting_crosshair_type_override"), },
    shape_editor_description                = { en = "Pick a weapon class and an action state, then choose which crosshair template to use for default/enemy/weakspot targeting. Values are saved per weapon class and per action.", },

    group_default_color                     = { en = Localize("loc_setting_mix_preset_flat") },
    group_default_color_description         = { en = "Colour and opacity when not aiming at an enemy or weakspot." },

    group_target_locked_color               = { en = Localize("loc_weapon_details_body") },
    group_target_locked_color_description   = { en = "Colour and opacity when the reticle is over an enemy (non-weakspot)." },

    group_weakspot_locked_color             = { en = Localize("loc_weapon_details_weakspot") },
    group_weakspot_locked_color_description = { en = "Colour and opacity when the reticle is over a weakspot." },

    default_color                           = { en = "Colour" },
    target_locked_color                     = { en = "Colour" },
    weakspot_locked_color                   = { en = "Colour" },

    default_alpha                           = { en = "Alpha (Opacity)" },
    target_locked_alpha                     = { en = "Alpha (Opacity)" },
    weakspot_locked_alpha                   = { en = "Alpha (Opacity)" },
    shape_editor_weapon_class               = { en = Localize("loc_achievement_category_weapons_label"), },

    shape_editor_weapon_class_description   = { en = "Choose which weapon family to edit.", },

    use_current_ranged_weapon               = { en = "Use Current Ranged Weapon", },
    use_current_ranged_weapon_description   = { en = "Set the Weapon Class dropdown to your currently carried ranged weapon.", },

    shape_editor_action_state               = { en = Localize("loc_item_information_actions"), },
    shape_editor_action_state_description   = { en = "Pick which action you are configuring. ADS/Block is the secondary input: ADS for ranged, Block for melee. Activated Special is the weapon special mode (e.g., flashlight, special shells, relic blades, flip shovels).", },

    action_primary                          = { en = Localize("loc_weapon_action_title_primary") .. " / " .. Localize("loc_ranged_attack_primary") },
    action_secondary                        = { en = Localize("loc_ranged_attack_secondary_ads") .. " / " .. Localize("loc_block") },
    action_special                          = { en = Localize("loc_ingame_weapon_extra") .. " (" .. Localize("loc_weapon_special_activate") .. ")" },

    shape_editor_default_shape              = { en = Localize("loc_setting_mix_preset_flat") },
    shape_editor_default_shape_description  = { en = "Template used when not locked to an enemy or weakspot." },
    shape_editor_enemy_shape                = { en = Localize("loc_weapon_details_body") },
    shape_editor_enemy_shape_description    = { en = "Template used when locked onto an enemy (non-weakspot)." },
    shape_editor_weakspot_shape             = { en = Localize("loc_weapon_details_weakspot") },
    shape_editor_weakspot_shape_description = { en = "Template used when locked onto a weakspot." },

    none                                    = { en = Localize("loc_setting_com_wheel_tap_none") },
    assault                                 = { en = Localize("loc_setting_crosshair_type_override_assault") },
    bfg                                     = { en = Localize("loc_setting_crosshair_type_override_bfg") },
    charge_up                               = { en = Localize("loc_ability_psyker_smite") },
    charge_up_ads                           = { en = Localize("loc_weapon_family_lasgun_p2_m1") },
    cross                                   = { en = Localize("loc_setting_crosshair_type_override_killshot") },
    dot                                     = { en = Localize("loc_setting_crosshair_type_override_dot") },
    larger_dot                              = { en = Localize("loc_setting_crosshair_type_override_dot") .. " (Large)" },
    chevron                                 = { en = "Chevron" },
    flamer                                  = { en = Localize("loc_weapon_family_flamer_p1_m1") },
    ironsight                               = { en = "Ironsight" },
    projectile_drop                         = { en = Localize("loc_weapon_family_ogryn_thumper_p1_m1") },
    shotgun                                 = { en = Localize("loc_setting_crosshair_type_override_shotgun") },
    shotgun_wide                            = { en = Localize("loc_weapon_family_shotgun_p4_m1") },
    spray_n_pray                            = { en = Localize("loc_setting_crosshair_type_override_spray_n_pray") },

    charge_up_peril                         = { en = Localize("loc_ability_psyker_smite") .. " (" .. Localize("loc_settings_menu_peril_effect") .. ")" },
    charge_up_ads_peril                     = { en = Localize("loc_weapon_family_lasgun_p2_m1") .. " (" .. Localize("loc_settings_menu_peril_effect") .. ")" },

    charge_up_peril_larger_dot              = { en = Localize("loc_ability_psyker_smite") .. " (" .. Localize("loc_settings_menu_peril_effect") .. ") + " .. Localize("loc_setting_crosshair_type_override_dot") },
    charge_up_ads_peril_larger_dot          = { en = Localize("loc_weapon_family_lasgun_p2_m1") .. " (" .. Localize("loc_settings_menu_peril_effect") .. ") + " .. Localize("loc_setting_crosshair_type_override_dot") },
}

localizations.melee_class = { en = Localize("loc_glossary_term_melee_weapons") }
localizations.melee_throwing_class = {
    en = Localize("loc_ability_zealot_throwing_knifes") .. " / " .. Localize("loc_weapon_family_dual_shivs_p1_m1")
}
localizations.psyker_smite_class = {
    en = Localize("loc_class_psyker_title") .. " " .. Localize("loc_ability_psyker_smite")
}
localizations.psyker_throwing_knives_class = {
    en = Localize("loc_class_psyker_title") .. " " .. Localize("loc_ability_psyker_blitz_throwing_knives")
}
localizations.psyker_chain_lightning_class = {
    en = Localize("loc_class_psyker_title") .. " " .. Localize("loc_ability_psyker_chain_lightning")
}
localizations.broker_missile_launcher_class = {
    en = Localize("loc_class_broker_title") .. " " .. Localize("loc_talent_broker_blitz_missile_launcher")
}

if mod.weapon_class_loc_keys then
    for class_id, info in pairs(mod.weapon_class_loc_keys) do
        if info.type == "family" then
            local loc_str = Localize(info.key)
            if string_sub(loc_str, 1, 5) == "<loc_" then
                loc_str = info.key
            end
            localizations[class_id] = { en = loc_str }
        elseif info.type == "mark" then
            local family_loc = Localize(info.family_loc)
            if not family_loc or string_sub(family_loc, 1, 1) == "<" then
                family_loc = string_match(info.key, "^(.-_p%d+)") or info.key
            end

            local pattern_loc = Localize("loc_weapon_pattern_" .. info.key)
            if not pattern_loc or string_sub(pattern_loc, 1, 1) == "<" then
                local fallback_key = string_gsub(info.key, "_m%d+", "_m1")
                pattern_loc = Localize("loc_weapon_pattern_" .. fallback_key)
                if not pattern_loc or string_sub(pattern_loc, 1, 1) == "<" then
                    pattern_loc = ""
                end
            end

            local mark_loc = Localize("loc_weapon_mark_" .. info.key)
            if not mark_loc or string_sub(mark_loc, 1, 1) == "<" then
                local mark_num = string_match(info.key, "m(%d+)$")
                if mark_num then
                    mark_loc = "Mk " .. mark_num
                else
                    mark_loc = info.key
                end
            end

            local bracket_text
            if pattern_loc ~= "" then
                bracket_text = pattern_loc .. " " .. mark_loc
            else
                bracket_text = mark_loc
            end

            localizations[class_id] = { en = string_format("%s (%s)", family_loc, bracket_text) }
        end
    end
end

local function readable(text)
    local tokens = string_split(text, "_")
    local num_tokens = #tokens
    local out = Script.new_array(num_tokens)

    for i = 1, num_tokens do
        local token = tokens[i]
        local first_letter = string_sub(token, 1, 1)
        out[i] = string_upper(first_letter) .. string_sub(token, 2)
    end

    return table_concat(out, " ")
end

local color_list = Color.list
for i = 1, #color_list do
    local color_name          = color_list[i]
    local ctor                = Color[color_name]
    local values              = type(ctor) == "function" and ctor(255, true) or Color.ui_terminal(255, true)
    local text                = InputUtils.apply_color_to_input_text(readable(color_name), values)
    localizations[color_name] = { en = text }
end

return localizations
