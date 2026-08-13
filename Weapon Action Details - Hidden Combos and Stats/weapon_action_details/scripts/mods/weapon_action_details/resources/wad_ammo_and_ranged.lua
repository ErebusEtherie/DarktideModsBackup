-- File: weapon_action_details/scripts/mods/weapon_action_details/resources/wad_ammo_and_ranged.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local ArmorSettings = mod:original_require("scripts/settings/damage/armor_settings")
local Items = mod:original_require("scripts/utilities/items")
local WeaponTweakTemplateSettings = mod:original_require(
    "scripts/settings/equipment/weapon_templates/weapon_tweak_template_settings")
local Localize = Localize

local ARMOR_TYPES = ArmorSettings.types
local template_types = WeaponTweakTemplateSettings and WeaponTweakTemplateSettings.template_types or {}
local AMMO_TEXT_COLOR = "{#color(255,255,255)}"
local DAMAGE_TEXT_COLOR = mod.WAD_DAMAGE_TEXT_COLOR
local DAMAGE_GLYPH = mod.WAD_DAMAGE_GLYPH
local RICH_TEXT_RESET = mod.WAD_RICH_TEXT_RESET

local CHARGED_FLAME_STREAM_WEAPON_TEMPLATE = "forcestaff_p2_m1"
local CHARGED_FLAME_STREAM_ACTION = "action_shoot_charged_flame"
local STREAM_DURATION_LABEL = "Stream"
local STREAM_CYCLES_LABEL = "Cycles"

local PELLET_ARMOR_TYPES = mod.ARMOR_DAMAGE_ORDER

local function action_shotshell(action, use_special_damage_profile)
    local fire_configuration = type(action) == "table" and action.fire_configuration

    if type(fire_configuration) ~= "table" then
        return nil
    end

    if use_special_damage_profile and type(fire_configuration.shotshell_special) == "table" then
        return fire_configuration.shotshell_special
    end

    return type(fire_configuration.shotshell) == "table" and fire_configuration.shotshell or nil
end

function mod.action_pellet_data(action, use_special_damage_profile)
    local shotshell = action_shotshell(action, use_special_damage_profile)
    local num_pellets = shotshell and shotshell.num_pellets

    if type(num_pellets) ~= "number" or num_pellets <= 0 then
        return nil
    end

    local min_num_hits = type(shotshell.min_num_hits) == "table" and shotshell.min_num_hits or {}
    local min_num_hits_by_armor = {}

    for i = 1, #PELLET_ARMOR_TYPES do
        local armor_type = PELLET_ARMOR_TYPES[i]
        local armor_min_num_hits = min_num_hits[armor_type]

        min_num_hits_by_armor[armor_type] =
            type(armor_min_num_hits) == "number" and armor_min_num_hits or 0
    end

    return {
        min_num_hits_by_armor = min_num_hits_by_armor,
        num_pellets = num_pellets,
    }
end

local function add_action_name(action_names, action_name_lookup, action_name)
    if type(action_name) == "string" and not action_name_lookup[action_name] then
        action_names[#action_names + 1] = action_name
        action_name_lookup[action_name] = true
    end
end

local function add_chain_action_names(action_names, action_name_lookup, chain_data)
    if type(chain_data) ~= "table" then
        return
    end

    if type(chain_data.action_name) == "string" then
        if not action_name_lookup[chain_data.action_name] then
            action_names[#action_names + 1] = chain_data.action_name
            action_name_lookup[chain_data.action_name] = true
        end

        return
    end

    for i = 1, #chain_data do
        local chain_action = chain_data[i]
        local action_name = type(chain_action) == "table" and chain_action.action_name

        if type(action_name) == "string" and not action_name_lookup[action_name] then
            action_names[#action_names + 1] = action_name
            action_name_lookup[action_name] = true
        end
    end
end

local function add_explicit_combo_action_names(action_names, action_name_lookup, explicit_combo)
    local primary_combo = type(explicit_combo) == "table" and explicit_combo[1]

    if type(primary_combo) == "string" then
        add_action_name(action_names, action_name_lookup, primary_combo)

        return
    end

    if type(primary_combo) ~= "table" then
        return
    end

    for i = 1, #primary_combo do
        local combo_entry = primary_combo[i]
        local combo_action_name = type(combo_entry) == "table" and combo_entry.action_name or combo_entry

        add_action_name(action_names, action_name_lookup, combo_action_name)
    end
end

local function item_is_ranged_weapon(item, weapon_template)
    if item and Items.is_weapon_template_ranged and Items.is_weapon_template_ranged(item) then
        return true
    end

    local keywords = weapon_template and weapon_template.keywords

    return type(keywords) == "table" and table.contains(keywords, "force_staff") or false
end

local function action_uses_ranged_damage_per_second(action, item, weapon_template)
    local kind = action and action.kind

    return type(kind) == "string" and string.find(kind, "shoot", 1, true) == 1 and
        item_is_ranged_weapon(item, weapon_template)
end

-- Exported function to calculate DPS.
function mod.action_ranged_damage_per_second(action, action_name, item, weapon_template, weapon_tweak_templates,
                                             unarmored_damage)
    if type(unarmored_damage) ~= "number" or unarmored_damage <= 0 or
        not action_uses_ranged_damage_per_second(action, item, weapon_template) then
        return nil
    end

    local rate_of_fire = mod.action_rate_of_fire_per_second(action, weapon_template, weapon_tweak_templates, action_name)

    return type(rate_of_fire) == "number" and rate_of_fire > 0 and unarmored_damage * rate_of_fire or nil
end

local function charge_time_for_level(charge_template, charge_level)
    local charge_duration = mod.resolve_lerp_value(charge_template and charge_template.charge_duration)

    if type(charge_duration) ~= "number" or charge_duration < 0 or type(charge_level) ~= "number" then
        return nil
    end

    if charge_level <= 0 then
        return 0
    end

    local charge_delay = mod.resolve_lerp_value(charge_template.charge_delay) or 0
    local min_charge = mod.resolve_lerp_value(charge_template.min_charge) or 0

    if type(charge_delay) ~= "number" or type(min_charge) ~= "number" then
        return nil
    end

    local remaining_charge_range = 1 - min_charge
    local charge_progress

    if remaining_charge_range <= 0 then
        charge_progress = 0
    else
        charge_progress = math.clamp((charge_level - min_charge) / remaining_charge_range, 0, 1)
    end

    return math.max(charge_delay, 0) + charge_duration * charge_progress
end

local function action_ammunition_usage_for_charge_level(action, charge_level)
    if type(action) ~= "table" then
        return nil
    end

    local ammunition_usage

    if action.use_charge then
        local ammunition_usage_min = mod.resolve_lerp_value(action.ammunition_usage_min)
        local ammunition_usage_max = mod.resolve_lerp_value(action.ammunition_usage_max)

        if type(ammunition_usage_min) == "number" and type(ammunition_usage_max) == "number" and
            type(charge_level) == "number" then
            ammunition_usage = math.round(math.lerp(ammunition_usage_min, ammunition_usage_max,
                math.clamp01(charge_level)))
        end
    end

    if type(ammunition_usage) ~= "number" then
        ammunition_usage = mod.resolve_lerp_value(action.ammunition_usage)
    end

    return type(ammunition_usage) == "number" and ammunition_usage > 0 and ammunition_usage or nil
end

local function charge_shot_ammunition_usage(action, charge_level)
    local ammunition_usage = action_ammunition_usage_for_charge_level(action, charge_level)

    return type(ammunition_usage) == "number" and ammunition_usage > 1 and ammunition_usage or nil
end

local function charged_flame_stream_info_parts(action_name, action, weapon_template, weapon_tweak_templates,
                                               charge_level)
    local weapon_template_name = weapon_template and weapon_template.name

    if weapon_template_name ~= CHARGED_FLAME_STREAM_WEAPON_TEMPLATE or
        action_name ~= CHARGED_FLAME_STREAM_ACTION or type(action) ~= "table" or
        type(charge_level) ~= "number" or charge_level <= 0 then
        return nil
    end

    local stream_charge_template = mod.resolved_action_charge_template and
        mod.resolved_action_charge_template(action_name, action, weapon_template, weapon_tweak_templates)
    local charge_cost = mod.resolve_lerp_value(stream_charge_template and stream_charge_template.charge_cost)

    if type(charge_cost) ~= "number" or charge_cost <= 0 then
        return nil
    end

    local stream_duration = charge_level / charge_cost
    local stream_duration_text = mod.format_number(stream_duration)

    if not stream_duration_text then
        return nil
    end

    local info_parts = {
        STREAM_DURATION_LABEL .. " " .. stream_duration_text .. "s",
    }
    local rate_of_fire = mod.action_rate_of_fire_per_second(action, weapon_template, weapon_tweak_templates,
        action_name)

    if type(rate_of_fire) == "number" and rate_of_fire > 0 then
        local cycle_capacity = stream_duration * rate_of_fire
        local cycle_capacity_text = mod.format_number(cycle_capacity)

        if cycle_capacity_text then
            info_parts[#info_parts + 1] = STREAM_CYCLES_LABEL .. " ~" .. cycle_capacity_text
        end
    end

    return info_parts
end

local function charge_shot_info_text(action_name, action, charge_action_name, charge_action, weapon_template,
                                     weapon_tweak_templates)
    local charge_template = mod.resolved_action_charge_template and
        mod.resolved_action_charge_template(charge_action_name, charge_action, weapon_template,
            weapon_tweak_templates)

    if not charge_template then
        return nil
    end

    local charge_level = mod.action_assumed_charge_level(action_name, action, weapon_tweak_templates, weapon_template,
        charge_action_name, charge_action)
    local charge_time = charge_time_for_level(charge_template, charge_level)
    local charge_time_text = mod.format_number(charge_time)
    local ammunition_usage = charge_shot_ammunition_usage(action, charge_level)
    local info_parts = {}

    if charge_time_text then
        info_parts[#info_parts + 1] = Localize(mod.WAD_LOC.GLOSSARY_TERM_CHARGE) .. " " .. charge_time_text .. "s"
    end

    local stream_info_parts = charged_flame_stream_info_parts(action_name, action, weapon_template,
        weapon_tweak_templates, charge_level)

    for i = 1, stream_info_parts and #stream_info_parts or 0 do
        info_parts[#info_parts + 1] = stream_info_parts[i]
    end

    if ammunition_usage then
        info_parts[#info_parts + 1] = Localize(mod.WAD_LOC.WEAPON_STAT_TITLE_AMMO) .. " -" .. ammunition_usage
    end

    if #info_parts == 0 then
        return nil
    end

    return AMMO_TEXT_COLOR .. table.concat(info_parts, "  ") .. RICH_TEXT_RESET
end

function mod.add_charge_shot_info_to_damage_text(damage_text, action_name, action, charge_action_name,
                                                 charge_action, weapon_template, weapon_tweak_templates)
    local info_text = charge_shot_info_text(action_name, action, charge_action_name, charge_action,
        weapon_template, weapon_tweak_templates)

    if not info_text then
        return damage_text or ""
    end

    if not damage_text or damage_text == "" then
        return info_text
    end

    local line_break_start, line_break_end = string.find(damage_text, "\n", 1, true)

    if not line_break_start then
        return damage_text .. "  " .. info_text
    end

    return string.sub(damage_text, 1, line_break_start - 1) .. "  " .. info_text ..
        string.sub(damage_text, line_break_end)
end

local function action_charge_context(actions, action_name)
    local weapon_context = mod.ACTIONS_WEAPON_CONTEXTS and mod.ACTIONS_WEAPON_CONTEXTS[actions]
    local charge_start_names = weapon_context and weapon_context.merged_charge_start_name_by_action_name
    local charge_action_name = charge_start_names and charge_start_names[action_name]
    local charge_action = charge_action_name and actions[charge_action_name]

    return charge_action_name, charge_action
end

local function ranged_weapon_primary_damage_action(wield_action, weapon_template, damage_profile_lerp_values,
                                                   weapon_tweak_templates)
    local actions = weapon_template and weapon_template.actions

    if not actions then
        return nil, nil, nil, nil, nil
    end

    local action_names = {}
    local action_name_lookup = {}
    local visited = {}
    local entry_actions = weapon_template.entry_actions
    local primary_action_name = entry_actions and entry_actions.primary_action
    local allowed_chain_actions = wield_action and wield_action.allowed_chain_actions
    local head = 1

    add_action_name(action_names, action_name_lookup, primary_action_name)
    add_explicit_combo_action_names(action_names, action_name_lookup, weapon_template.explicit_combo)

    if allowed_chain_actions then
        add_chain_action_names(action_names, action_name_lookup, allowed_chain_actions.shoot_pressed)
        add_chain_action_names(action_names, action_name_lookup, allowed_chain_actions.shoot)
    end

    add_action_name(action_names, action_name_lookup, "action_shoot_hip")

    while head <= #action_names do
        local current_action_name = action_names[head]
        local current_action = actions[current_action_name]

        head = head + 1

        if current_action and not visited[current_action_name] then
            visited[current_action_name] = true

            local charge_action_name, charge_action = action_charge_context(actions, current_action_name)
            local values_by_armor = mod.action_damage_values_by_armor(current_action, current_action_name,
                damage_profile_lerp_values, false, weapon_tweak_templates, weapon_template, charge_action_name,
                charge_action)
            local unarmored_damage = values_by_armor and values_by_armor.attack and
                values_by_armor.attack[ARMOR_TYPES.unarmored]

            if type(unarmored_damage) == "number" and unarmored_damage > 0 then
                return current_action_name, current_action, unarmored_damage, charge_action_name, charge_action
            end

            local current_chain_actions = current_action.allowed_chain_actions

            if current_chain_actions then
                for _, chain_data in pairs(current_chain_actions) do
                    add_chain_action_names(action_names, action_name_lookup, chain_data)
                end
            end
        end
    end

    return nil, nil, nil, nil, nil
end

-- Exported function to generate ammo pool data.
function mod.ranged_weapon_wield_ammo_text(action, action_name, item, weapon_template, weapon_tweak_templates,
                                           damage_profile_lerp_values)
    if action_name ~= "action_wield" or not action or not weapon_template or
        not item_is_ranged_weapon(item, weapon_template) then
        return nil
    end

    local hud_configuration = weapon_template.hud_configuration
    local infinite_ammo = hud_configuration and not hud_configuration.uses_ammunition and
        hud_configuration.uses_overheat

    if infinite_ammo then
        return nil
    end

    local ammo_template_name = weapon_template.ammo_template
    local ammo_templates = weapon_tweak_templates and weapon_tweak_templates[template_types.ammo]
    local ammo_template = type(ammo_template_name) == "string" and ammo_template_name ~= "none" and
        ammo_templates and ammo_templates[ammo_template_name]
    local ammunition_clips = ammo_template and ammo_template.ammunition_clips
    local clip_capacity = ammunition_clips and ammunition_clips[1]
    local reserve_capacity = ammo_template and ammo_template.ammunition_reserve

    if type(clip_capacity) ~= "number" or type(reserve_capacity) ~= "number" then
        return nil
    end

    if ammo_template.force_even_numbers then
        clip_capacity = math.round_to_closest_multiple(clip_capacity, 2)
    end

    clip_capacity = math.max(math.floor(clip_capacity), 0)
    reserve_capacity = math.max(math.floor(reserve_capacity), 0)

    local total_ammo = clip_capacity + reserve_capacity

    if total_ammo <= 0 then
        return nil
    end

    local ammo_text = AMMO_TEXT_COLOR .. Localize(mod.WAD_LOC.WEAPON_STAT_TITLE_AMMO) .. " " .. clip_capacity .. "/" ..
        reserve_capacity .. RICH_TEXT_RESET

    local damage_action_name, damage_action, unarmored_damage, charge_action_name, charge_action =
        ranged_weapon_primary_damage_action(action, weapon_template, damage_profile_lerp_values,
            weapon_tweak_templates)
    local charge_level = damage_action_name and
        mod.action_assumed_charge_level(damage_action_name, damage_action, weapon_tweak_templates, weapon_template,
            charge_action_name, charge_action)
    local ammunition_usage = action_ammunition_usage_for_charge_level(damage_action, charge_level) or 1

    if type(unarmored_damage) == "number" and type(ammunition_usage) == "number" and ammunition_usage > 0 then
        local shot_count = damage_action.allow_shots_with_less_than_required_ammo and
            math.ceil(total_ammo / ammunition_usage) or math.floor(total_ammo / ammunition_usage)
        local total_damage = unarmored_damage * shot_count

        ammo_text = ammo_text .. string.format(" (%s%s %.0f%s)", DAMAGE_TEXT_COLOR, DAMAGE_GLYPH, total_damage,
            RICH_TEXT_RESET)
    end

    return ammo_text
end
