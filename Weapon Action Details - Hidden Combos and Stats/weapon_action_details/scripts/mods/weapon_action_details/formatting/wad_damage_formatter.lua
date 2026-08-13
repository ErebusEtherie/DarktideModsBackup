-- File: weapon_action_details/scripts/mods/weapon_action_details/formatting/wad_damage_formatter.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local Localize = Localize

local DAMAGE_TEXT_COLOR = mod.WAD_DAMAGE_TEXT_COLOR
local IMPACT_TEXT_COLOR = mod.WAD_IMPACT_TEXT_COLOR
local CLEAVE_TEXT_COLOR = mod.WAD_CLEAVE_TEXT_COLOR
local CRIT_TEXT_COLOR = mod.WAD_CRIT_TEXT_COLOR
local CRIT_CHANCE_TEXT_COLOR = mod.WAD_CRIT_CHANCE_TEXT_COLOR
local DAMAGE_GLYPH = mod.WAD_DAMAGE_GLYPH
local IMPACT_GLYPH = mod.WAD_IMPACT_GLYPH
local CLEAVE_GLYPH = mod.WAD_CLEAVE_GLYPH
local CRIT_GLYPH = mod.WAD_CRIT_GLYPH
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET
local PELLET_TEXT_COLOR = "{#color(255,255,255)}"
local IGNORE_SHIELD_TEXT = mod:localize("ignore_shield")
local SHIELD_BREAKER_TEXT = mod:localize("shield_breaker")

local ARMOR_TYPES = ArmorSettings.types

local ARMOR_DAMAGE_ORDER = mod.ARMOR_DAMAGE_ORDER

local function format_range_distance(distance)
    if type(distance) ~= "number" then
        return nil
    end

    local rounded_distance = math.floor(distance + 0.5)

    if math.abs(distance - rounded_distance) <= 0.005 then
        return string.format("%.0f", distance)
    end

    local distance_text = string.format("%.2f", distance)

    distance_text = string.gsub(distance_text, "0+$", "")
    distance_text = string.gsub(distance_text, "%.$", "")

    return distance_text
end

local function format_damage_per_second_suffix(damage_per_second)
    if type(damage_per_second) ~= "number" then
        return ""
    end

    return string.format(" (%.0f/s)", damage_per_second)
end

local function format_range_text(range_data)
    if type(range_data) ~= "table" then
        return nil
    end

    local symbol = range_data.symbol
    local distance_text = format_range_distance(range_data.distance)

    if (symbol ~= "<" and symbol ~= ">") or not distance_text then
        return nil
    end

    local range_prefix = Localize(mod.WAD_LOC.STATS_DISPLAY_RANGE_STAT)
    local suffix = ""

    if mod.wad_range_mode == mod.WAD_RANGE_MODE_OPTIMAL then
        suffix = "(" .. Localize(mod.WAD_LOC.WEAPON_KEYWORD_HIGH_DAMAGE) .. ")"
    elseif mod.wad_range_mode == mod.WAD_RANGE_MODE_NEAR then
        suffix = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_NEAR)
    elseif mod.wad_range_mode == mod.WAD_RANGE_MODE_FAR then
        suffix = Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_FAR)
    end

    return string.format("%s%s %s%sm %s%s", PELLET_TEXT_COLOR, range_prefix, symbol, distance_text, suffix,
        RICH_TEXT_RESET)
end

-- Exported function to format crit chance bonus text
function mod.format_critical_strike_chance_bonus_text(chance_modifier)
    if type(chance_modifier) ~= "number" or chance_modifier == 0 then
        return nil
    end

    -- Uses %+.0f to automatically prepend a '+' to positive values and '-' to negative values.
    return string.format("%s%s %s %+.0f%%%s", CRIT_CHANCE_TEXT_COLOR, CRIT_GLYPH,
        Localize(mod.WAD_LOC.TALENT_CRIT_CHANCE_LOW), chance_modifier * 100, RICH_TEXT_RESET)
end

-- Exported function to format max critical shots text
function mod.format_max_critical_shots_text(max_critical_shots)
    if type(max_critical_shots) ~= "number" or max_critical_shots < 2 then
        return nil
    end

    return string.format("%s%s %s•%s %.0f%s", CRIT_TEXT_COLOR, CRIT_GLYPH,
        Localize(mod.WAD_LOC.WEAPON_DETAILS_CRIT), Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_ATTACK_CHAINS),
        max_critical_shots,
        RICH_TEXT_RESET)
end

-- Exported function to format suppression text
function mod.format_suppression_text(amount, radius)
    if type(amount) ~= "number" and type(radius) ~= "number" then
        return nil
    end

    local text_parts = {}

    if type(amount) == "number" then
        text_parts[#text_parts + 1] = string.format("%.0f", amount)
    end

    if type(radius) == "number" then
        text_parts[#text_parts + 1] = string.format("%.1fm", radius)
    end

    return string.format("%s%s %s: %s%s", IMPACT_TEXT_COLOR, IMPACT_GLYPH,
        Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_SUPPRESSION), table.concat(text_parts, " / "), RICH_TEXT_RESET)
end

local function format_stagger_category_text(stagger_categories)
    local stagger_category_text = mod.format_stagger_category_text(stagger_categories)

    if not stagger_category_text then
        return nil
    end

    return string.format("%s%s %s%s", IMPACT_TEXT_COLOR, IMPACT_GLYPH, stagger_category_text, RICH_TEXT_RESET)
end

local function pellet_value_text(pellet_data, armor_type)
    local num_pellets = pellet_data and pellet_data.num_pellets
    local min_num_hits_by_armor = pellet_data and pellet_data.min_num_hits_by_armor
    local min_num_hits = type(min_num_hits_by_armor) == "table" and min_num_hits_by_armor[armor_type]

    if type(num_pellets) ~= "number" or num_pellets <= 0 or type(min_num_hits) ~= "number" then
        return nil
    end

    return string.format("%s%s•%s: %.0f-%.0f%s", PELLET_TEXT_COLOR, Localize(mod.WAD_LOC.WEAPON_STATS_FIRE_MODE_SHOTGUN),
        Localize(mod.WAD_LOC.WEAPON_STATS_FIRE_MODE_PROJECTILE), min_num_hits, num_pellets, RICH_TEXT_RESET)
end

local function majority_armor_text(text_by_armor)
    if type(text_by_armor) ~= "table" then
        return nil
    end

    local majority_text
    local majority_count = 0

    for i = 1, #ARMOR_DAMAGE_ORDER do
        local candidate_text = text_by_armor[ARMOR_DAMAGE_ORDER[i]]

        if candidate_text then
            local candidate_count = 0

            for j = 1, #ARMOR_DAMAGE_ORDER do
                if text_by_armor[ARMOR_DAMAGE_ORDER[j]] == candidate_text then
                    candidate_count = candidate_count + 1
                end
            end

            if candidate_count > majority_count then
                majority_text = candidate_text
                majority_count = candidate_count
            end
        end
    end

    if not majority_text then
        return nil
    end

    for i = 1, #ARMOR_DAMAGE_ORDER do
        if text_by_armor[ARMOR_DAMAGE_ORDER[i]] == nil then
            return nil
        end
    end

    return majority_text
end

local function armor_texts_have_value(text_by_armor)
    for i = 1, #ARMOR_DAMAGE_ORDER do
        if text_by_armor[ARMOR_DAMAGE_ORDER[i]] then
            return true
        end
    end

    return false
end

local function combined_details_text(first_text, second_text)
    local has_first = type(first_text) == "string" and first_text ~= ""
    local has_second = type(second_text) == "string" and second_text ~= ""

    if has_first and has_second then
        return first_text .. "  " .. second_text
    elseif has_first then
        return first_text
    elseif has_second then
        return second_text
    end

    return ""
end

local function crit_damage_ratio_text(base_damage, crit_damage)
    if type(base_damage) ~= "number" or base_damage <= 0 or type(crit_damage) ~= "number" then
        return nil
    end

    local ratio_text = string.format("%.2f", crit_damage / base_damage):gsub("0+$", ""):gsub("%.$", "")

    return string.format("%s%s%s 1:%s%s", CRIT_TEXT_COLOR, CRIT_GLYPH, DAMAGE_GLYPH, ratio_text, RICH_TEXT_RESET)
end

function mod.format_combined_armor_modifier_text(base_data, crit_data, shared_data)
    if type(base_data) ~= "table" or type(crit_data) ~= "table" or type(shared_data) ~= "table" then
        return "", nil
    end

    local pellet_text_by_armor = {}
    local base_cleave_text_by_armor = {}
    local crit_cleave_text_by_armor = {}
    local base_range_text_by_armor = {}
    local crit_range_text_by_armor = {}
    local crit_damage_ratio_text_by_armor = {}

    for i = 1, #ARMOR_DAMAGE_ORDER do
        local armor_type = ARMOR_DAMAGE_ORDER[i]

        pellet_text_by_armor[armor_type] = pellet_value_text(shared_data.pellet_data, armor_type)
        base_cleave_text_by_armor[armor_type] = mod.format_cleave_details_text(base_data.cleave_details, armor_type)
        crit_cleave_text_by_armor[armor_type] = mod.format_cleave_details_text(crit_data.cleave_details, armor_type)
        base_range_text_by_armor[armor_type] = format_range_text(base_data.range and base_data.range[armor_type])
        crit_range_text_by_armor[armor_type] = format_range_text(crit_data.range and crit_data.range[armor_type])
        crit_damage_ratio_text_by_armor[armor_type] = crit_damage_ratio_text(
            base_data.damage and base_data.damage[armor_type], crit_data.damage and crit_data.damage[armor_type])
    end

    local majority_pellet_text = majority_armor_text(pellet_text_by_armor)
    local majority_base_cleave_text = majority_armor_text(base_cleave_text_by_armor)
    local majority_crit_cleave_text = majority_armor_text(crit_cleave_text_by_armor)
    local majority_base_range_text = majority_armor_text(base_range_text_by_armor)
    local majority_crit_range_text = majority_armor_text(crit_range_text_by_armor)
    local majority_crit_damage_ratio_text = majority_armor_text(crit_damage_ratio_text_by_armor)

    local has_damage = mod.damage_values_have_positive_value(base_data.damage) or
        mod.damage_values_have_positive_value(crit_data.damage)
    local has_impact = mod.damage_values_have_positive_value(base_data.impact) or
        mod.damage_values_have_positive_value(crit_data.impact)
    local has_cleave = mod.damage_values_have_positive_value(base_data.cleave) or
        mod.damage_values_have_positive_value(crit_data.cleave)
    local has_critical_strike_chance_bonus = type(shared_data.critical_strike_chance_bonus) == "number" and
        shared_data.critical_strike_chance_bonus ~= 0
    local has_max_critical_shots = type(shared_data.max_critical_shots) == "number" and
        shared_data.max_critical_shots >= 2
    local has_suppression = type(shared_data.suppression_amount) == "number" or
        type(shared_data.suppression_radius) == "number"
    local has_backstab_bonus = type(shared_data.backstab_bonus) == "number" and shared_data.backstab_bonus > 0
    local has_peril = shared_data.peril_text ~= nil and shared_data.peril_text ~= ""
    local has_heat = shared_data.heat_text ~= nil and shared_data.heat_text ~= ""
    local has_stagger_categories = shared_data.stagger_categories ~= nil
    local has_stagger_details = base_data.stagger_details ~= nil or crit_data.stagger_details ~= nil
    local has_cleave_details = base_data.cleave_details ~= nil or crit_data.cleave_details ~= nil
    local has_ignore_shield = shared_data.ignores_shield == true
    local has_shield_breaker = shared_data.shield_breaker == true
    local has_ammo = shared_data.ammo_text ~= nil and shared_data.ammo_text ~= ""
    local has_pellet_data = armor_texts_have_value(pellet_text_by_armor)
    local has_range_data = armor_texts_have_value(base_range_text_by_armor) or
        armor_texts_have_value(crit_range_text_by_armor)

    if not has_damage and not has_impact and not has_cleave and not has_critical_strike_chance_bonus and
        not has_max_critical_shots and not has_peril and not has_heat and not has_stagger_categories and
        not has_stagger_details and not has_cleave_details and not has_ignore_shield and not has_shield_breaker and
        not has_ammo and not has_suppression and not has_backstab_bonus and not has_pellet_data and
        not has_range_data then
        return "", nil
    end

    local base_unarmored_damage = base_data.damage and base_data.damage[ARMOR_TYPES.unarmored]
    local crit_unarmored_damage = crit_data.damage and crit_data.damage[ARMOR_TYPES.unarmored]
    local base_unarmored_cleave = base_data.cleave and base_data.cleave[ARMOR_TYPES.unarmored]
    local armor_localizations = UISettings.weapon_stats_armor_types or {}
    local base_parts = {}

    if has_ammo then base_parts[#base_parts + 1] = shared_data.ammo_text end
    if has_cleave and type(base_unarmored_cleave) == "number" then
        base_parts[#base_parts + 1] = string.format("%s%s %.2f%s", CLEAVE_TEXT_COLOR, CLEAVE_GLYPH, base_unarmored_cleave,
            RICH_TEXT_RESET)
    end

    local stagger_category_text = format_stagger_category_text(shared_data.stagger_categories)
    if stagger_category_text then base_parts[#base_parts + 1] = stagger_category_text end
    if majority_pellet_text then base_parts[#base_parts + 1] = majority_pellet_text end

    local crit_bonus_text = mod.format_critical_strike_chance_bonus_text(shared_data.critical_strike_chance_bonus)
    if crit_bonus_text then base_parts[#base_parts + 1] = crit_bonus_text end

    local max_crit_shots_text = mod.format_max_critical_shots_text(shared_data.max_critical_shots)
    if max_crit_shots_text then base_parts[#base_parts + 1] = max_crit_shots_text end
    if has_backstab_bonus then
        base_parts[#base_parts + 1] = string.format("%s%s %s +%.0f%%%s", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH,
            Localize(mod.WAD_LOC.TALENT_ZEALOT_INCREASED_BACKSTAB_DAMAGE), shared_data.backstab_bonus * 100,
            RICH_TEXT_RESET)
    end
    if has_peril then base_parts[#base_parts + 1] = shared_data.peril_text end
    if has_heat then base_parts[#base_parts + 1] = shared_data.heat_text end
    if has_ignore_shield then
        base_parts[#base_parts + 1] = string.format("%s%s %s%s", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH, IGNORE_SHIELD_TEXT,
            RICH_TEXT_RESET)
    end
    if has_shield_breaker then
        base_parts[#base_parts + 1] = string.format("%s%s %s%s", IMPACT_TEXT_COLOR, IMPACT_GLYPH, SHIELD_BREAKER_TEXT,
            RICH_TEXT_RESET)
    end

    local base_stagger_details_text = mod.format_stagger_details_text(base_data.stagger_details)
    local crit_stagger_details_text = mod.format_stagger_details_text(crit_data.stagger_details)
    if base_stagger_details_text then base_parts[#base_parts + 1] = base_stagger_details_text end
    if crit_stagger_details_text and crit_stagger_details_text ~= base_stagger_details_text then
        base_parts[#base_parts + 1] = crit_stagger_details_text
    end

    local suppression_text = mod.format_suppression_text(shared_data.suppression_amount, shared_data.suppression_radius)
    if suppression_text then base_parts[#base_parts + 1] = suppression_text end

    local base_general_cleave_text = mod.format_cleave_details_text(base_data.cleave_details)
    local crit_general_cleave_text = mod.format_cleave_details_text(crit_data.cleave_details)
    if base_general_cleave_text then base_parts[#base_parts + 1] = base_general_cleave_text end
    if crit_general_cleave_text and crit_general_cleave_text ~= base_general_cleave_text then
        base_parts[#base_parts + 1] = crit_general_cleave_text
    end
    if majority_base_cleave_text then base_parts[#base_parts + 1] = majority_base_cleave_text end
    if majority_crit_cleave_text and majority_crit_cleave_text ~= majority_base_cleave_text then
        base_parts[#base_parts + 1] = majority_crit_cleave_text
    end
    if majority_base_range_text then base_parts[#base_parts + 1] = majority_base_range_text end
    if majority_crit_range_text and majority_crit_range_text ~= majority_base_range_text then
        base_parts[#base_parts + 1] = majority_crit_range_text
    end
    if majority_crit_damage_ratio_text then base_parts[#base_parts + 1] = majority_crit_damage_ratio_text end

    local armor_grid = {}

    local valid_base_damage = has_damage and type(base_unarmored_damage) == "number" and base_unarmored_damage > 0
    local valid_crit_damage = has_damage and type(crit_unarmored_damage) == "number" and crit_unarmored_damage > 0

    for i = 1, #ARMOR_DAMAGE_ORDER do
        local armor_type = ARMOR_DAMAGE_ORDER[i]
        local b_dmg = base_data.damage and base_data.damage[armor_type]
        local c_dmg = crit_data.damage and crit_data.damage[armor_type]
        local b_imp = base_data.impact and base_data.impact[armor_type]
        local c_imp = crit_data.impact and crit_data.impact[armor_type]
        local b_info = base_cleave_text_by_armor[armor_type]
        local c_info = crit_cleave_text_by_armor[armor_type]
        local b_range_text = base_range_text_by_armor[armor_type]
        local c_range_text = crit_range_text_by_armor[armor_type]
        local crit_damage_ratio = crit_damage_ratio_text_by_armor[armor_type]
        local shared_det = {}
        local b_det = {}
        local c_det = {}
        local pellet_text = pellet_text_by_armor[armor_type]

        if pellet_text ~= majority_pellet_text and pellet_text then
            shared_det[#shared_det + 1] = pellet_text
        end

        if b_info == majority_base_cleave_text then b_info = nil end
        if c_info == majority_crit_cleave_text then c_info = nil end

        if b_info == c_info and b_info then
            shared_det[#shared_det + 1] = b_info
        else
            if b_info then b_det[#b_det + 1] = b_info end
            if c_info then c_det[#c_det + 1] = c_info end
        end

        if b_range_text == majority_base_range_text then b_range_text = nil end
        if c_range_text == majority_crit_range_text then c_range_text = nil end

        if b_range_text == c_range_text and b_range_text then
            shared_det[#shared_det + 1] = b_range_text
        else
            if b_range_text then b_det[#b_det + 1] = b_range_text end
            if c_range_text then c_det[#c_det + 1] = c_range_text end
        end

        if crit_damage_ratio and crit_damage_ratio ~= majority_crit_damage_ratio_text then
            shared_det[#shared_det + 1] = crit_damage_ratio
        end

        local armor_has_data = type(b_dmg) == "number" or type(c_dmg) == "number" or type(b_imp) == "number" or
            type(c_imp) == "number" or #shared_det > 0 or #b_det > 0 or #c_det > 0

        if armor_has_data then
            local armor_loc_key = armor_localizations[armor_type]
            local armor_name = armor_loc_key and Localize(armor_loc_key) or armor_type
            local b_val_parts = {}
            local c_val_parts = {}

            if armor_type == ARMOR_TYPES.unarmored then
                if type(b_dmg) == "number" and b_dmg > 0 then
                    b_val_parts[#b_val_parts + 1] = string.format("%s%s %.0f%s%s", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH,
                        b_dmg, format_damage_per_second_suffix(shared_data.damage_per_second), RICH_TEXT_RESET)
                end
                if type(c_dmg) == "number" and c_dmg > 0 then
                    c_val_parts[#c_val_parts + 1] = string.format("%s%s %.0f%s%s", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH,
                        c_dmg, format_damage_per_second_suffix(shared_data.critical_damage_per_second), RICH_TEXT_RESET)
                end
            else
                if valid_base_damage and type(b_dmg) == "number" then
                    b_val_parts[#b_val_parts + 1] = string.format("%s%s %.0f%%%s", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH,
                        b_dmg / base_unarmored_damage * 100, RICH_TEXT_RESET)
                end
                if valid_crit_damage and type(c_dmg) == "number" then
                    c_val_parts[#c_val_parts + 1] = string.format("%s%s %.0f%%%s", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH,
                        c_dmg / crit_unarmored_damage * 100, RICH_TEXT_RESET)
                end
            end

            if type(b_imp) == "number" then
                b_val_parts[#b_val_parts + 1] =
                    string.format("%s%s %.0f%s", IMPACT_TEXT_COLOR, IMPACT_GLYPH, b_imp, RICH_TEXT_RESET)
            end
            if type(c_imp) == "number" then
                c_val_parts[#c_val_parts + 1] =
                    string.format("%s%s %.0f%s", IMPACT_TEXT_COLOR, IMPACT_GLYPH, c_imp, RICH_TEXT_RESET)
            end

            armor_grid[#armor_grid + 1] = {
                armor_type = armor_type,
                label = armor_name,
                base_values = combined_details_text(table.concat(b_val_parts, "  "), table.concat(b_det, "  ")),
                crit_values = combined_details_text(table.concat(c_val_parts, "  "), table.concat(c_det, "  ")),
                details = table.concat(shared_det, "  "),
            }
        end
    end

    return table.concat(base_parts, "  "), #armor_grid > 0 and armor_grid or nil
end
