-- File: weapon_action_details/scripts/mods/weapon_action_details/damage/wad_stagger.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Action = mod:original_require("scripts/utilities/action/action")
local Localize = Localize

local STAGGER_CATEGORY_LOCALIZATION_KEYS = {
    melee = mod.WAD_LOC.SETTING_MELEE,
    stab = mod.WAD_LOC.TRAIT_BESPOKE_POWER_BONUS_BASED_ON_CHARGE_TIME,
    sticky = mod.WAD_LOC.STATS_DISPLAY_FIRST_SAW_DAMAGE,
    electrocuted = mod.WAD_LOC.WEAPON_KEYWORD_SHOCK_WEAPON,
    flamer = mod.WAD_LOC.WEAPON_KEYWORD_SPRAY_N_PRAY,
    hatchet = mod.WAD_LOC.WEAPON_FAMILY_COMBATAXE_P2_M1,
    uppercut = mod.WAD_LOC.TG_WEAPON_SPECIAL_COMBATBLADE,
    killshot = mod.WAD_LOC.ITEM_WEAPON_VARIANT_KILLSHOT,
    ranged = mod.WAD_LOC.SETTING_RANGED,
    explosion = mod.WAD_LOC.WEAPON_KEYWORD_EXPLOSIVE,
    force_field = mod.WAD_LOC.EXPEDITIONS_PICKUP_DESCRIPTION_FORCE_FIELD_POCKETABLE,
    blinding = mod.WAD_LOC.TALENT_BROKER_BLITZ_FLASH_GRENADE,
    light = mod.WAD_LOC.SETTINGS_MENU_LOW,
    medium = mod.WAD_LOC.SETTINGS_MENU_MEDIUM,
    heavy = mod.WAD_LOC.SETTINGS_MENU_HIGH,
}

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

local function add_unique_value(values, value)
    for i = 1, #values do
        local existing_value = values[i]

        if type(existing_value) == "number" and type(value) == "number" then
            if math.abs(existing_value - value) <= 0.005 then
                return
            end
        elseif existing_value == value then
            return
        end
    end

    values[#values + 1] = value
end

local function selected_damage_profile(action, template_i, use_special_damage_profile)
    local damage_profile, special_damage_profile = Action.damage_template(action, template_i)

    return (use_special_damage_profile or action.activate_special_on_required_ammo) and special_damage_profile or
        damage_profile
end

local function selected_stagger_resistance_modifier(damage_profile)
    if not damage_profile then
        return nil
    end

    local use_weakspot = mod.WAD_DAMAGE_HIT_ZONE_IS_WEAKSPOT[mod.wad_damage_hit_zone] == true
    local modifier = use_weakspot and damage_profile.weakspot_stagger_resistance_modifier or
        damage_profile.stagger_resistance_modifier

    return resolve_lerp_value(modifier)
end

local function add_damage_profile_stagger_details(stagger_details, damage_profile)
    if not damage_profile then
        return
    end

    if damage_profile.ignore_stagger_reduction then
        stagger_details.ignore_stagger_reduction = true
    end

    local stagger_resistance_modifier = selected_stagger_resistance_modifier(damage_profile)

    if type(stagger_resistance_modifier) == "number" and math.abs(stagger_resistance_modifier - 1) > 0.005 then
        add_unique_value(stagger_details.stagger_resistance_modifiers, stagger_resistance_modifier)
    end
end

local function stagger_category_entry(stagger_categories, stagger_category)
    for i = 1, #stagger_categories do
        local entry = stagger_categories[i]

        if entry.category == stagger_category then
            return entry
        end
    end

    local entry = {
        category = stagger_category,
        overrides = {},
    }

    stagger_categories[#stagger_categories + 1] = entry

    return entry
end

local function add_damage_profile_stagger_category(stagger_categories, damage_profile)
    local stagger_category = damage_profile and damage_profile.stagger_category

    if type(stagger_category) ~= "string" or stagger_category == "" then
        return
    end

    local entry = stagger_category_entry(stagger_categories, stagger_category)
    local stagger_override = damage_profile.stagger_override

    if type(stagger_override) == "string" and stagger_override ~= "" and stagger_override ~= stagger_category then
        add_unique_value(entry.overrides, stagger_override)
    end
end

function mod.action_stagger_categories(action, use_special_damage_profile)
    if not action then
        return nil
    end

    local stagger_categories = {}
    local num_templates = Action.num_damage_templates(action)

    for template_i = 1, num_templates do
        local damage_profile = selected_damage_profile(action, template_i, use_special_damage_profile)

        if damage_profile then
            add_damage_profile_stagger_category(stagger_categories, damage_profile)

            local explosion_template = Action.explosion_template(action, template_i)
            local inner_damage_profile = explosion_template and explosion_template.close_damage_profile

            if inner_damage_profile and inner_damage_profile ~= damage_profile then
                add_damage_profile_stagger_category(stagger_categories, inner_damage_profile)
            end
        end
    end

    if #stagger_categories == 0 then
        return nil
    end

    for i = 1, #stagger_categories do
        table.sort(stagger_categories[i].overrides)
    end

    table.sort(stagger_categories, function(left, right)
        return left.category < right.category
    end)

    return stagger_categories
end

function mod.action_stagger_details(action, use_special_damage_profile)
    if not action then
        return nil
    end

    local stagger_details = {
        ignore_stagger_reduction = false,
        stagger_resistance_modifiers = {},
    }
    local num_templates = Action.num_damage_templates(action)

    for template_i = 1, num_templates do
        local damage_profile = selected_damage_profile(action, template_i, use_special_damage_profile)

        if damage_profile then
            add_damage_profile_stagger_details(stagger_details, damage_profile)

            local explosion_template = Action.explosion_template(action, template_i)
            local inner_damage_profile = explosion_template and explosion_template.close_damage_profile

            if inner_damage_profile and inner_damage_profile ~= damage_profile then
                add_damage_profile_stagger_details(stagger_details, inner_damage_profile)
            end
        end
    end

    local has_stagger_details = stagger_details.ignore_stagger_reduction or
        #stagger_details.stagger_resistance_modifiers > 0

    if not has_stagger_details then
        return nil
    end

    table.sort(stagger_details.stagger_resistance_modifiers)

    return stagger_details
end

local function format_multiplier(multiplier)
    return string.format("%.3gx", multiplier)
end

function mod.localized_stagger_category(stagger_category)
    local localization_key = STAGGER_CATEGORY_LOCALIZATION_KEYS[stagger_category]

    return localization_key and Localize(localization_key) or stagger_category
end

local function format_stagger_overrides(overrides)
    if type(overrides) ~= "table" or #overrides == 0 then
        return nil
    end

    local localized_overrides = {}

    for i = 1, #overrides do
        localized_overrides[i] = mod.localized_stagger_category(overrides[i])
    end

    return table.concat(localized_overrides, "/")
end

function mod.format_stagger_category_text(stagger_categories)
    if type(stagger_categories) ~= "table" or #stagger_categories == 0 then
        return nil
    end

    local localized_categories = {}

    for i = 1, #stagger_categories do
        local stagger_category = stagger_categories[i]
        local localized_category = mod.localized_stagger_category(stagger_category.category)
        local localized_overrides = format_stagger_overrides(stagger_category.overrides)

        localized_categories[i] = localized_overrides and
            string.format("%s (%s)", localized_category, localized_overrides) or localized_category
    end

    return table.concat(localized_categories, "/")
end

function mod.format_stagger_details_text(stagger_details)
    if not stagger_details then
        return nil
    end

    local parts = {}

    if stagger_details.ignore_stagger_reduction then
        parts[#parts + 1] = Localize(mod.WAD_LOC.ABILITY_OGRYN_OBJECTIVE_2)
    end

    if #stagger_details.stagger_resistance_modifiers > 0 then
        local formatted_modifiers = {}

        for i = 1, #stagger_details.stagger_resistance_modifiers do
            formatted_modifiers[i] = format_multiplier(stagger_details.stagger_resistance_modifiers[i])
        end

        parts[#parts + 1] = string.format("%s resistance %s", Localize(mod.WAD_LOC.STAGGER),
            table.concat(formatted_modifiers, "/"))
    end

    if #parts == 0 then
        return nil
    end

    return string.format("%s%s %s%s", mod.WAD_STAGGER_INFO_TEXT_COLOR, mod.WAD_IMPACT_GLYPH,
        table.concat(parts, "  "), mod.WAD_RICH_TEXT_RESET)
end
