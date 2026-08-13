-- File: weapon_action_details/scripts/mods/weapon_action_details/combos/wad_training_tab.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local WeaponTemplate = mod:original_require("scripts/utilities/weapon/weapon_template")
local Localize = Localize

local DAMAGE_TEXT_COLOR = mod.WAD_DAMAGE_TEXT_COLOR
local IMPACT_TEXT_COLOR = mod.WAD_IMPACT_TEXT_COLOR
local CLEAVE_TEXT_COLOR = mod.WAD_CLEAVE_TEXT_COLOR
local COMBO_LOOP_TEXT_COLOR = mod.WAD_COMBO_LOOP_TEXT_COLOR
local DAMAGE_GLYPH = mod.WAD_DAMAGE_GLYPH
local IMPACT_GLYPH = mod.WAD_IMPACT_GLYPH
local CLEAVE_GLYPH = mod.WAD_CLEAVE_GLYPH
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET

local TITLE_SEPARATOR = "•"

local SPECIAL_TRAINING_WEAPON_TEMPLATE_NAMES = {
    ogryn_gauntlet_p1_m1 = true,
}

local TRAINING_ENTRIES_BY_ITEM = setmetatable({}, {
    __mode = "k",
})

local function weapon_template_name(item, weapon_template)
    local name = weapon_template and weapon_template.name

    if type(name) == "string" then
        return name
    end

    name = item and item.weapon_template

    return type(name) == "string" and name or nil
end

function mod.weapon_has_training_tab(item, weapon_template)
    weapon_template = weapon_template or
        item and WeaponTemplate.weapon_template_from_item(item)

    if type(weapon_template) ~= "table" then
        return false
    end

    local name = weapon_template_name(item, weapon_template)

    if name and SPECIAL_TRAINING_WEAPON_TEMPLATE_NAMES[name] then
        return true
    end

    local keywords = weapon_template.keywords

    return type(keywords) == "table" and table.contains(keywords, "melee")
end

local function entry_action_names(entry)
    local names = entry and entry.names

    if type(names) == "table" and #names > 0 then
        return names
    end

    local action_name = entry and entry.name

    if type(action_name) == "string" then
        return {
            action_name,
        }
    end

    return nil
end

local function add_entry_to_training_context(context, entry, use_special_damage_profile)
    local action_names = entry_action_names(entry)

    if not action_names then
        return
    end

    local display_name = entry.display_name

    for i = 1, #action_names do
        local action_name = action_names[i]

        if type(action_name) == "string" then
            context.action_data_by_name[action_name] = {
                use_special_damage_profile = use_special_damage_profile == true,
            }

            if type(display_name) == "string" and display_name ~= "" then
                context.display_names_by_action[action_name] = display_name
            end
        end
    end
end

local function add_entries_to_training_context(context, entries, use_special_damage_profile)
    for i = 1, #entries do
        add_entry_to_training_context(context, entries[i], use_special_damage_profile)
    end
end

local function new_training_context()
    return {
        action_data_by_name = {},
        display_names_by_action = {},
    }
end

local function training_search_contexts(item, actions)
    local normal_entries = mod.sorted_action_entries(item, mod.WAD_ACTION_FILTER_NORMAL)
    local normal_context = new_training_context()
    local contexts = {
        normal_context,
    }

    add_entries_to_training_context(normal_context, normal_entries, false)

    if mod.weapon_has_special_state_actions(actions) then
        local special_entries = mod.sorted_action_entries(item, mod.WAD_ACTION_FILTER_SPECIAL)
        local special_context = new_training_context()

        add_entries_to_training_context(special_context, normal_entries, false)
        add_entries_to_training_context(special_context, special_entries, true)

        contexts[#contexts + 1] = special_context
    end

    return contexts
end

local function compact_number(value, decimal_places)
    if type(value) ~= "number" then
        return "0"
    end

    decimal_places = decimal_places or 0

    local text = string.format("%." .. decimal_places .. "f", value)

    if decimal_places > 0 then
        text = string.gsub(text, "0+$", "")
        text = string.gsub(text, "%.$", "")
    end

    return text
end

local function training_action_display_name(action_name, display_names_by_action)
    local display_name = display_names_by_action and
        display_names_by_action[action_name]

    if type(display_name) == "string" and display_name ~= "" then
        return display_name
    end

    return type(action_name) == "string" and action_name or ""
end

local function copy_combo_row(row, display_name)
    return {
        action_name = row.action_name,
        cleave = row.cleave or 0,
        damage = row.damage or 0,
        damage_per_second = row.damage_per_second or 0,
        display_name = display_name,
        duration = row.duration or 0,
        impact = row.impact or 0,
        is_loop = row.is_loop == true,
        use_special_damage_profile = row.use_special_damage_profile == true,
    }
end

local function merge_combo_rows(target, source)
    local total_duration = (target.duration or 0) + (source.duration or 0)
    local total_damage = (target.damage or 0) + (source.damage or 0)

    target.cleave = (target.cleave or 0) + (source.cleave or 0)
    target.damage = total_damage
    target.duration = total_duration
    target.impact = (target.impact or 0) + (source.impact or 0)
    target.is_loop = target.is_loop or source.is_loop == true
    target.use_special_damage_profile = target.use_special_damage_profile or
        source.use_special_damage_profile == true
    target.damage_per_second = total_duration > 0 and
        total_damage / total_duration or 0
end

local function combo_display_rows(combo, display_names_by_action)
    local display_rows = {}
    local rows = combo and combo.rows

    for i = 1, rows and #rows or 0 do
        local row = rows[i]
        local display_name = training_action_display_name(row.action_name,
            display_names_by_action)
        local previous_row = display_rows[#display_rows]

        if previous_row and previous_row.display_name == display_name then
            merge_combo_rows(previous_row, row)
        else
            display_rows[#display_rows + 1] = copy_combo_row(row,
                display_name)
        end
    end

    return display_rows
end

local function combo_action_name_text(row)
    local display_name = row.display_name

    if row.is_loop then
        return COMBO_LOOP_TEXT_COLOR .. display_name .. RICH_TEXT_RESET
    end

    return display_name
end

local function combo_action_stats_text(row)
    local damage_per_second_text = compact_number(row.damage_per_second, 0)
    local impact_text = compact_number(row.impact, 0)
    local cleave_text = compact_number(row.cleave, 2)

    return string.format(
        "%s%s %s/s%s  %s%s %s%s  %s%s %s%s",
        DAMAGE_TEXT_COLOR,
        DAMAGE_GLYPH,
        damage_per_second_text,
        RICH_TEXT_RESET,
        IMPACT_TEXT_COLOR,
        IMPACT_GLYPH,
        impact_text,
        RICH_TEXT_RESET,
        CLEAVE_TEXT_COLOR,
        CLEAVE_GLYPH,
        cleave_text,
        RICH_TEXT_RESET
    )
end

local function combo_body_text(combo, display_names_by_action)
    local display_rows = combo_display_rows(combo, display_names_by_action)
    local lines = {}

    for i = 1, #display_rows do
        local row = display_rows[i]

        lines[i] = combo_action_name_text(row) ..
            "    " .. combo_action_stats_text(row)
    end

    return table.concat(lines, "\n"), #display_rows
end

local function training_entry_title(armor_localization_key,
                                    objective_localization_key)
    return table.concat({
        Localize(mod.WAD_LOC.WEAPON_STATS_DISPLAY_ATTACK_CHAINS),
        Localize(armor_localization_key),
        Localize(objective_localization_key),
    }, TITLE_SEPARATOR)
end

local function training_entry(combo, context, title, objective)
    local body_text = ""
    local row_count = 0

    if combo and context then
        body_text, row_count = combo_body_text(combo,
            context.display_names_by_action)
    end

    return {
        body_text = body_text,
        combo = combo,
        objective = objective,
        row_count = row_count,
        title = title,
    }
end

local function best_training_combo(actions, contexts, weapon_template,
                                   weapon_tweak_templates,
                                   damage_profile_lerp_values, objective)
    local combo = mod.best_action_combo_for_contexts(
        actions,
        contexts,
        weapon_template,
        weapon_tweak_templates,
        damage_profile_lerp_values,
        objective
    )

    if not combo then
        return nil, nil
    end

    return combo, contexts[combo.context_index]
end

local function build_training_entries(item, weapon_template)
    local actions = weapon_template and weapon_template.actions

    if type(actions) ~= "table" then
        return {}
    end

    local weapon_tweak_templates, damage_profile_lerp_values =
        mod.item_weapon_tweak_templates(item, weapon_template)
    local contexts = training_search_contexts(item, actions)

    local damage_combo, damage_context = best_training_combo(
        actions,
        contexts,
        weapon_template,
        weapon_tweak_templates,
        damage_profile_lerp_values,
        mod.WAD_COMBO_OBJECTIVE_SUPER_ARMOR_DAMAGE
    )
    local cleave_combo, cleave_context = best_training_combo(
        actions,
        contexts,
        weapon_template,
        weapon_tweak_templates,
        damage_profile_lerp_values,
        mod.WAD_COMBO_OBJECTIVE_ARMORED_CLEAVE
    )

    return {
        training_entry(
            damage_combo,
            damage_context,
            training_entry_title(
                mod.WAD_LOC.WEAPON_STATS_DISPLAY_SUPER_ARMOR,
                mod.WAD_LOC.STATS_DISPLAY_DAMAGE_STAT
            ),
            mod.WAD_COMBO_OBJECTIVE_SUPER_ARMOR_DAMAGE
        ),
        training_entry(
            cleave_combo,
            cleave_context,
            training_entry_title(
                mod.WAD_LOC.WEAPON_STATS_DISPLAY_ARMORED,
                mod.WAD_LOC.STATS_DISPLAY_CLEAVE_TARGETS_STAT
            ),
            mod.WAD_COMBO_OBJECTIVE_ARMORED_CLEAVE
        ),
    }
end

function mod.training_entries(item)
    if not item then
        return {}
    end

    local weapon_template = WeaponTemplate.weapon_template_from_item(item)

    if not mod.weapon_has_training_tab(item, weapon_template) then
        return {}
    end

    local hit_zone = mod.wad_damage_hit_zone
    local cached = TRAINING_ENTRIES_BY_ITEM[item]

    if cached and cached.hit_zone == hit_zone then
        return cached.entries
    end

    local entries = build_training_entries(item, weapon_template)

    TRAINING_ENTRIES_BY_ITEM[item] = {
        entries = entries,
        hit_zone = hit_zone,
    }

    return entries
end
