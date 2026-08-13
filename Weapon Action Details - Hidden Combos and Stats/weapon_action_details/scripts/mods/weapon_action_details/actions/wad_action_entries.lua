-- File: weapon_action_details/scripts/mods/weapon_action_details/actions/wad_action_entries.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Localize = Localize

local MOVEMENT_PREFIX_LOCALIZATION_KEYS = {
    mod.WAD_LOC.INGAME_WIELD_3_4_GAMEPAD,
    mod.WAD_LOC.INGAME_SPRINT,
    mod.WAD_LOC.INGAME_SLIDE,
    mod.WAD_LOC.INGAME_DODGE,
}

function mod.action_display_name_includes_total_time(action)
    local kind = action and action.kind

    return kind == "wield" or kind == "ranged_wield" or kind == "reload_state"
end

function mod.action_entry_display_name(action_name, action, community_action_names, weapon_template,
                                       weapon_tweak_templates, is_special_filter, movement_prefix)
    local display_name = mod.action_display_name(action_name, community_action_names, weapon_template)

    if movement_prefix then
        display_name = movement_prefix .. display_name
    end

    local use_special = is_special_filter or (action and action.activate_special_on_required_ammo)

    if use_special and action then
        local has_special_stats =
            (action.damage_profile_special_active ~= nil and
                action.damage_profile_special_active ~= action.damage_profile) or
            (action.damage_type_special_active ~= nil and
                action.damage_type_special_active ~= action.damage_type) or
            (action.action_armor_hit_mass_mod_special_active ~= nil and
                action.action_armor_hit_mass_mod_special_active ~= action.action_armor_hit_mass_mod) or
            (action.ignore_armor_aborts_attack_special_active ~= nil and
                action.ignore_armor_aborts_attack_special_active ~= action.ignore_armor_aborts_attack) or
            (action.force_abort_breed_tags_special_active ~= nil and
                action.force_abort_breed_tags_special_active ~= action.force_abort_breed_tags)

        if has_special_stats then
            display_name = " " .. display_name
        end
    end

    if mod.action_display_name_includes_total_time(action) then
        local total_time = mod.action_total_time(action, nil, nil, weapon_template, weapon_tweak_templates,
            action_name)

        if total_time then
            display_name = display_name .. " (" .. total_time .. ")"
        end
    end

    if action_name == "action_shoot" or action_name == "action_shoot_hip" or
        action_name == "action_shoot_hip_from_reload" or action_name == "action_shoot_zoomed" or
        action_name == "action_shoot_braced" or action_name == "action_shoot_blocking" then
        local rate_of_fire = mod.action_rate_of_fire_per_second(action, weapon_template, weapon_tweak_templates,
            action_name)
        local rate_of_fire_text = mod.format_number(rate_of_fire)

        if rate_of_fire_text then
            display_name = display_name .. " (" .. rate_of_fire_text .. "/s)"
        end
    end

    local direction = mod.action_attack_direction(action)

    if direction and action_name ~= "action_push" then
        display_name = display_name .. " - " .. direction
    end

    return display_name
end

local function action_entry_key_part(value)
    if type(value) ~= "string" then
        value = tostring(value or "")
    end

    return string.format("%d:%s", #value, value)
end

local function action_entry_armor_grid_key_part(armor_grid)
    if type(armor_grid) ~= "table" or #armor_grid == 0 then
        return action_entry_key_part("")
    end

    local row_parts = {}

    for i = 1, #armor_grid do
        local row = armor_grid[i]

        if type(row) == "table" then
            row_parts[#row_parts + 1] = table.concat({
                action_entry_key_part(row.armor_type),
                action_entry_key_part(row.label),
                action_entry_key_part(row.base_values),
                action_entry_key_part(row.crit_values),
                action_entry_key_part(row.details),
            }, "|")
        else
            row_parts[#row_parts + 1] = action_entry_key_part(row)
        end
    end

    return action_entry_key_part(table.concat(row_parts, "|"))
end

local function action_entry_dedupe_key(entry)
    return table.concat({
        action_entry_key_part(entry.detail_text),
        action_entry_key_part(entry.chain_text),
        action_entry_key_part(entry.damage_text),
        action_entry_armor_grid_key_part(entry.armor_grid),
        action_entry_key_part(entry.kind),
        action_entry_key_part(entry.icon),
        action_entry_key_part(entry.movement_prefix),
        action_entry_key_part(entry.merged_start_kind),
        action_entry_key_part(entry.merged_start_name),
    }, "|")
end

local function add_unique_action_entry_name(names, name)
    if not name or name == "" then
        return
    end

    for i = 1, #names do
        if names[i] == name then
            return
        end
    end

    names[#names + 1] = name
end

local function add_action_entry_names(names, entry)
    local entry_names = entry.names

    if type(entry_names) == "table" and #entry_names > 0 then
        for i = 1, #entry_names do
            add_unique_action_entry_name(names, entry_names[i])
        end
    else
        add_unique_action_entry_name(names, entry.name)
    end
end

function mod.add_sorted_action_entry(entries, dedupe_entries_by_key, entry)
    if mod.WAD_SPECIAL_ACTIVATION_ACTION_KINDS[entry.kind] or entry.kind == "vent_overheat" then
        local dedupe_key = action_entry_dedupe_key(entry)
        local existing_entry = dedupe_entries_by_key[dedupe_key]

        if existing_entry then
            existing_entry.names = existing_entry.names or {}

            add_action_entry_names(existing_entry.names, entry)

            if not existing_entry.armor_grid and entry.armor_grid then
                existing_entry.armor_grid = entry.armor_grid
            end

            if not existing_entry.tooltip_grid and entry.tooltip_grid then
                existing_entry.tooltip_grid = entry.tooltip_grid
            end

            return
        end

        if type(entry.names) ~= "table" or #entry.names == 0 then
            entry.names = {
                entry.name,
            }
        end

        dedupe_entries_by_key[dedupe_key] = entry
    end

    entries[#entries + 1] = entry
end

local function action_entry_kind_display_text(entry)
    local kind = entry.kind or ""
    local merged_start_kind = entry.merged_start_kind

    if type(merged_start_kind) == "string" and merged_start_kind ~= "" then
        kind = merged_start_kind .. " → " .. kind
    end

    local weapon_template_name = entry.weapon_template_name
    local prefix = type(weapon_template_name) == "string" and weapon_template_name ~= "" and
        kind .. " / " .. weapon_template_name or kind
    local names = entry.names

    if names and #names > 1 then
        if not entry.merged_start_name then
            table.sort(names)
        end

        return prefix .. " / " .. table.concat(names, ", ")
    end

    if entry.name and entry.name ~= "" then
        return prefix .. " / " .. entry.name
    end

    return prefix
end

function mod.add_original_action_names_to_kind_rows(entries)
    for i = 1, #entries do
        entries[i].kind = action_entry_kind_display_text(entries[i])
    end
end

local function action_entry_community_name(entry)
    if entry.kind ~= "sweep" or not entry.community_action_names or type(entry.name) ~= "string" then
        return nil
    end

    local community_name = entry.community_action_names[entry.name]

    return type(community_name) == "string" and community_name or nil
end

local function text_starts_with_context_prefix(text, prefix)
    return string.find(text, prefix .. "•", 1, true) == 1 or
        string.find(text, prefix .. "/", 1, true) == 1
end

local function action_entry_is_movement_prefixed_sweep(entry)
    local community_name = action_entry_community_name(entry)

    if not community_name then
        return false
    end

    for i = 1, #MOVEMENT_PREFIX_LOCALIZATION_KEYS do
        local movement_name = Localize(MOVEMENT_PREFIX_LOCALIZATION_KEYS[i])

        if text_starts_with_context_prefix(community_name, movement_name) then
            return true
        end
    end

    return false
end

local function action_entry_is_main_path_sweep(entry)
    local community_name = action_entry_community_name(entry)

    if not community_name then
        return false
    end

    local light_name = Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_LIGHT)
    local heavy_name = Localize(mod.WAD_LOC.WEAPON_ACTION_TITLE_HEAVY)

    return string.find(community_name, light_name .. " ", 1, true) == 1 or
        string.find(community_name, heavy_name .. " ", 1, true) == 1
end

local function action_entry_is_combo_prefixed_sweep(entry)
    local community_name = action_entry_community_name(entry)

    if not community_name then
        return false
    end

    local combo_name = Localize(mod.WAD_LOC.INVENTORY_WEAPON_BUTTON_MARKS)

    return text_starts_with_context_prefix(community_name, combo_name) or
        string.find(community_name, "•" .. combo_name .. "•", 1, true) ~= nil or
        string.find(community_name, "•" .. combo_name .. "/", 1, true) ~= nil
end

function mod.action_entry_sweep_sort_bucket(entry)
    if entry.kind ~= "sweep" then
        return 0
    end

    if action_entry_is_movement_prefixed_sweep(entry) then
        return 1
    elseif action_entry_is_main_path_sweep(entry) then
        return 2
    elseif action_entry_is_combo_prefixed_sweep(entry) then
        return 3
    end

    return 4
end
