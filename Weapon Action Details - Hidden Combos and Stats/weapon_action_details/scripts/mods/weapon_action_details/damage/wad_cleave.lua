-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_cleave.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local Localize = Localize

local ARMOR_TYPES = ArmorSettings.types

local ARMOR_DAMAGE_ORDER = mod.ARMOR_DAMAGE_ORDER

local function resolve_lerp_value(value)
    if type(value) ~= "table" then
        return value
    end

    local lerp_basic = value.lerp_basic
    local lerp_perfect = value.lerp_perfect

    if type(lerp_basic) == "number" and type(lerp_perfect) == "number" then
        return math.lerp(lerp_basic, lerp_perfect, 0.5)
    end

    return nil
end

local function selected_damage_profile(action, template_i, use_special_damage_profile)
    local damage_profile, special_damage_profile = Action.damage_template(action, template_i)

    return (use_special_damage_profile or action.activate_special_on_required_ammo) and special_damage_profile or
        damage_profile
end

local function add_unique_value(values, value)
    for i = 1, #values do
        if values[i] == value then
            return
        end
    end

    values[#values + 1] = value
end

local function add_general_detail(cleave_details, detail)
    local general_details = cleave_details and cleave_details.general

    if general_details and detail ~= nil then
        add_unique_value(general_details, detail)
    end
end

local function add_armor_detail(cleave_details, armor_type, detail)
    local armor = cleave_details and cleave_details.armor

    if not armor or armor_type == nil or detail == nil then
        return
    end

    local armor_details = armor[armor_type]

    if not armor_details then
        armor_details = {}
        armor[armor_type] = armor_details
    end

    add_unique_value(armor_details, detail)
end

local function format_multiplier(multiplier)
    local rounded_multiplier = math.round(multiplier * 100) / 100

    if rounded_multiplier == math.floor(rounded_multiplier) then
        return string.format("%dx", rounded_multiplier)
    elseif rounded_multiplier * 10 == math.floor(rounded_multiplier * 10) then
        return string.format("%.1fx", rounded_multiplier)
    end

    return string.format("%.2fx", rounded_multiplier)
end

local function format_inverse_multiplier(multiplier)
    if multiplier == 0 then
        return "infx"
        -- return "∞x"
    end

    return format_multiplier(1 / multiplier)
end

local function format_number(value)
    return string.format("%.3g", value)
end

local function armor_display_name(armor_type)
    local armor_localizations = UISettings.weapon_stats_armor_types or {}
    local armor_localization_key = armor_localizations[armor_type]

    return armor_localization_key and Localize(armor_localization_key) or armor_type
end

local function add_damage_profile_cleave_details(cleave_details, damage_profile)
    if not damage_profile then
        return
    end

    local hit_mass_override = resolve_lerp_value(damage_profile.hit_mass_override)

    if type(hit_mass_override) == "number" then
        add_general_detail(cleave_details, string.format("Hit mass override %s", format_number(hit_mass_override)))
    end
end

local function add_action_armor_hit_mass_mod_details(cleave_details, action, use_special_damage_profile)
    local action_armor_hit_mass_mod = action.action_armor_hit_mass_mod

    if use_special_damage_profile and action.action_armor_hit_mass_mod_special_active ~= nil then
        action_armor_hit_mass_mod = action.action_armor_hit_mass_mod_special_active
    end

    if type(action_armor_hit_mass_mod) ~= "table" then
        return
    end

    for i = 1, #ARMOR_DAMAGE_ORDER do
        local armor_type = ARMOR_DAMAGE_ORDER[i]
        local hit_mass_modifier = resolve_lerp_value(action_armor_hit_mass_mod[armor_type])

        if type(hit_mass_modifier) == "number" and math.abs(hit_mass_modifier - 1) > 0.005 then
            add_armor_detail(cleave_details, armor_type, string.format("%s %s",
                Localize(mod.WAD_LOC.STATS_DISPLAY_CLEAVE_DAMAGE_AND_TARGETS_STAT),
                format_inverse_multiplier(hit_mass_modifier)))
        end
    end
end

local function add_ignore_armor_aborts_attack_details(cleave_details, action, use_special_damage_profile)
    local ignore_armor_aborts_attack = action.ignore_armor_aborts_attack

    if use_special_damage_profile and action.ignore_armor_aborts_attack_special_active ~= nil then
        ignore_armor_aborts_attack = action.ignore_armor_aborts_attack_special_active
    end

    if not ignore_armor_aborts_attack then
        return
    end

    local armor_aborts_attack = ArmorSettings.aborts_attack or {}

    for armor_type, aborts_attack in pairs(armor_aborts_attack) do
        if aborts_attack then
            add_armor_detail(cleave_details, armor_type, Localize(mod.WAD_LOC.WEAPON_KEYWORD_HIGH_CLEAVE))
        end
    end
end

local function add_force_abort_breed_tags_details(cleave_details, action, use_special_damage_profile)
    local force_abort_breed_tags = action.force_abort_breed_tags

    if use_special_damage_profile and action.force_abort_breed_tags_special_active ~= nil then
        force_abort_breed_tags = action.force_abort_breed_tags_special_active
    end

    if type(force_abort_breed_tags) == "table" and #force_abort_breed_tags > 0 then
        add_general_detail(cleave_details, mod:localize("elite_special_stop"))
    end
end

function mod.action_cleave_details(action, use_special_damage_profile)
    if not action or action.kind ~= "sweep" then
        return nil
    end

    local cleave_details = {
        general = {},
        armor = {},
    }

    add_action_armor_hit_mass_mod_details(cleave_details, action, use_special_damage_profile)
    add_ignore_armor_aborts_attack_details(cleave_details, action, use_special_damage_profile)
    add_force_abort_breed_tags_details(cleave_details, action, use_special_damage_profile)

    local hit_mass_damage_profile = selected_damage_profile(action, 1, use_special_damage_profile)

    add_damage_profile_cleave_details(cleave_details, hit_mass_damage_profile)

    local has_cleave_details = #cleave_details.general > 0

    if not has_cleave_details then
        for _, armor_details in pairs(cleave_details.armor) do
            if #armor_details > 0 then
                has_cleave_details = true

                break
            end
        end
    end

    return has_cleave_details and cleave_details or nil
end

function mod.format_cleave_details_text(cleave_details, armor_type)
    if not cleave_details then
        return nil
    end

    local details

    if armor_type == nil then
        details = cleave_details.general
    else
        local armor = cleave_details.armor

        details = armor and armor[armor_type]
    end

    if not details or #details == 0 then
        return nil
    end

    return string.format("%s%s %s%s", mod.WAD_CLEAVE_INFO_TEXT_COLOR, mod.WAD_CLEAVE_GLYPH,
        table.concat(details, "  "), mod.WAD_RICH_TEXT_RESET)
end

function mod.cleave_details_have_armor_rows(cleave_details)
    local armor = cleave_details and cleave_details.armor

    if not armor then
        return false
    end

    for i = 1, #ARMOR_DAMAGE_ORDER do
        local armor_type = ARMOR_DAMAGE_ORDER[i]
        local armor_details = armor[armor_type]

        if armor_details and #armor_details > 0 then
            return true
        end
    end

    return false
end

function mod.format_cleave_armor_name(armor_type)
    return armor_display_name(armor_type)
end
