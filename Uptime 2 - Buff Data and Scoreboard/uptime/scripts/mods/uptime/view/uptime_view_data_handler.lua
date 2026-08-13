-- File: uptime/scripts/mods/uptime/view/uptime_view_data_handler.lua
local mod = get_mod("uptime"); if not mod then return end

local talent_lib = mod:io_dofile("uptime/scripts/mods/uptime/libs/talents")
local TalentLayoutParser = mod:original_require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local TextUtilities = mod:original_require("scripts/utilities/ui/text")
local ArchetypeSettings = mod:original_require("scripts/settings/archetype/archetype_settings")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")

local function add_archetype_name(archetype_names, archetype_name)
    if type(archetype_name) ~= "string" or archetype_name == "" then
        return
    end

    table.insert(archetype_names, string.lower(archetype_name))
end

local function build_archetype_names()
    local archetype_names = {}
    local archetype_names_array = ArchetypeSettings and ArchetypeSettings.archetype_names_array

    if type(archetype_names_array) == "table" then
        for i = 1, #archetype_names_array do
            add_archetype_name(archetype_names, archetype_names_array[i])
        end
    else
        local archetype_names_lookup = ArchetypeSettings and ArchetypeSettings.archetype_names

        if type(archetype_names_lookup) == "table" then
            for archetype_name, _ in pairs(archetype_names_lookup) do
                add_archetype_name(archetype_names, archetype_name)
            end

            table.sort(archetype_names)
        end
    end

    return archetype_names
end

local ARCHETYPE_NAMES = build_archetype_names()
local archetype_font_icon = UISettings and UISettings.archetype_font_icon or {}
local BUFF_TEMPLATE_NAME_COLOR = Color.ui_grey_medium(255, true)

if not mod.scoreboard_stat_definitions then
    mod:io_dofile("uptime/scripts/mods/uptime/libs/scoreboard_stats")
end

local function normalize_archetype_name(archetype)
    if type(archetype) == "table" then
        archetype = archetype.name or archetype.archetype_name
    end

    if type(archetype) ~= "string" or archetype == "" then
        return nil
    end

    return string.lower(archetype)
end

local function string_contains_archetype(value, archetype_name)
    if type(value) ~= "string" or value == "" or type(archetype_name) ~= "string" or archetype_name == "" then
        return false
    end

    return string.find(string.lower(value), archetype_name, 1, true) ~= nil
end

local function is_talent_buff(buff)
    if not buff or buff.related_item then
        return false
    end

    local category = buff.category

    return category == "talents" or category == "talents_secondary"
end

local function has_displayable_parent_buff(buff_name, buff_data, buffs)
    if type(buff_name) ~= "string" or type(buff_data) ~= "table" or type(buffs) ~= "table" then
        return false
    end

    local child_suffix = "_child"
    local child_suffix_length = #child_suffix

    if string.sub(buff_name, -child_suffix_length) ~= child_suffix then
        return false
    end

    local child_icon = buff_data.icon

    if type(child_icon) ~= "string" or child_icon == "" then
        return false
    end

    local parent_name = string.sub(buff_name, 1, -child_suffix_length - 1) .. "_parent"
    local parent_buff = buffs[parent_name]
    local parent_icon = parent_buff and parent_buff.icon

    return type(parent_icon) == "string" and parent_icon ~= ""
end

local function get_foreign_archetype_from_buff_name(buff_name, buff, player_archetype)
    if not is_talent_buff(buff) then
        return nil
    end

    player_archetype = normalize_archetype_name(player_archetype)

    if not player_archetype then
        return nil
    end

    local name = buff_name or buff.name

    if type(name) ~= "string" or name == "" then
        return nil
    end

    if string_contains_archetype(name, player_archetype) then
        return nil
    end

    local lower_name = string.lower(name)

    for i = 1, #ARCHETYPE_NAMES do
        local archetype_name = ARCHETYPE_NAMES[i]

        if archetype_name ~= player_archetype and string.find(lower_name, archetype_name, 1, true) then
            return archetype_name
        end
    end

    return nil
end

local function add_foreign_archetype_display_data(display_values, buff_name, buff, player_archetype)
    if not display_values then
        return nil
    end

    local foreign_archetype = get_foreign_archetype_from_buff_name(buff_name, buff, player_archetype)
    local font_icon = foreign_archetype and archetype_font_icon[foreign_archetype]

    if not font_icon then
        return display_values
    end

    display_values.foreign_archetype = foreign_archetype
    display_values.foreign_archetype_font_icon = font_icon
    display_values.foreign_archetype_text_prefix = font_icon

    return display_values
end

local function scoreboard_tracking_enabled()
    if type(mod.scoreboard_tracking_enabled) ~= "function" then
        return false
    end

    return mod.scoreboard_tracking_enabled()
end

local function get_local_account_id()
    local player_manager = Managers.player
    local local_player = player_manager and player_manager:local_player_safe(1)

    if not local_player then
        return nil
    end

    if type(local_player.account_id) == "function" then
        return local_player:account_id()
    end

    if type(local_player.name) == "function" then
        return local_player:name()
    end

    return local_player.name or local_player._name
end

function mod:generate_display_values(entry)
    local has_weapon_tracking = tonumber(entry.version) > 2
    local mission = entry.mission
    local meta_data = entry.meta_data or {}
    local mission_display_values = generate_display_values_for_mission(mission)
    local buff_display_values = generate_display_values_for_buffs(mission, entry.buffs, has_weapon_tracking,
        meta_data.archetype)
    local weapon_display_values = has_weapon_tracking and
        generate_display_values_for_weapons(mission, entry.weapons, entry.buffs) or nil

    local damage_display_values = nil
    if entry.damage and scoreboard_tracking_enabled() then
        damage_display_values = generate_display_values_for_damage(entry.damage, meta_data.account_id,
            entry.loadouts)
    end

    return {
        mission = mission_display_values,
        buffs = buff_display_values,
        weapons = weapon_display_values,
        damage = damage_display_values
    }
end

function mod:generate_live_scoreboard_display_values()
    if not scoreboard_tracking_enabled() then
        return nil
    end

    if type(mod.get_current_damage_tracking) ~= "function" then
        return nil
    end

    local damage_data = mod:get_current_damage_tracking()

    if not damage_data then
        return nil
    end

    local loadouts = nil

    if type(mod.get_current_team_loadouts) == "function" then
        loadouts = mod:get_current_team_loadouts()
    end

    return generate_display_values_for_damage(damage_data, get_local_account_id(), loadouts)
end

local function format_dmg(val, total)
    val = val or 0
    total = total or 0

    local pct = 0
    if total > 0 then pct = (val / total) * 100 end
    local v_str = tostring(math.floor(val))

    if val >= 1000000 then
        v_str = string.format("%.1fM", val / 1000000)
    elseif val >= 1000 then
        v_str = string.format("%.1fk", val / 1000)
    end

    return string.format("%s (%.1f%%)", v_str, pct)
end

local function format_scoreboard_stat_value(stat_definition, value, team_totals)
    value = mod.scoreboard_number(value)

    if stat_definition and stat_definition.key == "times_assisted" then
        return string.format("%d", math.floor(value))
    end

    local total = 0

    if stat_definition and team_totals then
        total = team_totals[stat_definition.key] or 0
    end

    return format_dmg(value, total)
end

local function should_highlight_scoreboard_stat(stat_definition, value, ranking_values)
    if not stat_definition then
        return false
    end

    if stat_definition.higher_is_better and mod.scoreboard_number(value) <= 0 then
        return false
    end

    return mod.scoreboard_is_ranked_value(stat_definition, value, ranking_values)
end

local function localize_or_raw(value)
    if not value then
        return ""
    end

    if string.sub(value, 1, 4) == "loc_" then
        return Localize(value)
    end

    return value
end

local function generate_talent_tooltip(icon_data)
    if not icon_data then
        return nil
    end

    local talent_id = icon_data.talent_id
    local talent = talent_id and talent_lib and talent_lib.get_talent and talent_lib.get_talent(talent_id)

    if talent then
        local title = localize_or_raw(talent.display_name or icon_data.display_name or talent_id)
        local description = TalentLayoutParser.talent_description(talent, 1, Color.ui_terminal(255, true))

        return {
            title = title,
            description = description
        }
    end

    if icon_data.display_name or talent_id then
        return {
            title = localize_or_raw(icon_data.display_name or talent_id),
            description = ""
        }
    end

    return nil
end

local function add_tooltips_to_loadout_icons(loadout_icons)
    if type(loadout_icons) ~= "table" then
        return nil
    end

    local icons = {}

    for i = 1, #loadout_icons do
        local icon_data = loadout_icons[i]

        if icon_data then
            icons[i] = {
                category = icon_data.category,
                talent_id = icon_data.talent_id,
                icon = icon_data.icon,
                gradient_map = icon_data.gradient_map,
                display_name = icon_data.display_name,
                tooltip = icon_data.tooltip or generate_talent_tooltip(icon_data),
            }
        end
    end

    return icons
end

local function merge_damage_and_loadout_data(damage_data, loadouts)
    damage_data = damage_data or {}
    loadouts = loadouts or {}

    local merged_damage_data = {}

    for account_id, player_damage in pairs(damage_data) do
        merged_damage_data[account_id] = {
            name = player_damage.name,
            archetype = player_damage.archetype,
            melee = player_damage.melee or 0,
            ranged = player_damage.ranged or 0,
            blitz = player_damage.blitz or 0,
            dot = player_damage.dot or 0,
            horde = player_damage.horde or 0,
            elite = player_damage.elite or 0,
            special = player_damage.special or 0,
            boss = player_damage.boss or 0,
            damage_taken = player_damage.damage_taken or 0,
            times_assisted = player_damage.times_assisted or 0,
            total = player_damage.total or 0,
            loadout_icons = add_tooltips_to_loadout_icons(player_damage.loadout_icons),
            loadout_weapons = player_damage.loadout_weapons,
        }
    end

    for account_id, loadout in pairs(loadouts) do
        local player_data = merged_damage_data[account_id]

        if not player_data then
            player_data = {
                name = loadout.name,
                archetype = loadout.archetype,
                melee = 0,
                ranged = 0,
                blitz = 0,
                dot = 0,
                horde = 0,
                elite = 0,
                special = 0,
                boss = 0,
                damage_taken = 0,
                times_assisted = 0,
                total = 0,
            }

            merged_damage_data[account_id] = player_data
        else
            player_data.name = player_data.name or loadout.name
            player_data.archetype = player_data.archetype or loadout.archetype
        end

        player_data.loadout_icons = add_tooltips_to_loadout_icons(loadout.icons)
        player_data.loadout_weapons = loadout.weapons
    end

    return merged_damage_data
end

function generate_display_values_for_damage(damage_data, local_account_id, loadouts)
    damage_data = merge_damage_and_loadout_data(damage_data, loadouts)

    local stat_definitions = mod.scoreboard_stat_definitions
    local stat_definitions_n = mod.scoreboard_stat_definitions_n or 0

    local team_totals = {
        horde = 0,
        elite = 0,
        special = 0,
        boss = 0,
        total = 0,
        damage_taken = 0,
        times_assisted = 0,
    }

    for _, p in pairs(damage_data) do
        if p then
            for i = 1, stat_definitions_n do
                local stat_definition = stat_definitions[i]
                local key = stat_definition.key

                team_totals[key] = (team_totals[key] or 0) + mod.scoreboard_number(p[key])
            end
        end
    end

    local ranking_values = mod.scoreboard_calculate_ranking_values(damage_data)

    local result = { local_player = nil, team = {} }

    for acc_id, p in pairs(damage_data) do
        if acc_id == local_account_id then
            result.local_player = {
                melee_str = format_dmg(p.melee, p.total),
                ranged_str = format_dmg(p.ranged, p.total),
                blitz_str = format_dmg(p.blitz, p.total),
                dot_str = format_dmg(p.dot, p.total),
                total_str = string.format("%d", math.floor(p.total))
            }
        end

        local team_entry = {
            name = p.name,
            archetype = p.archetype,
            loadout_icons = p.loadout_icons,
            loadout_weapons = p.loadout_weapons,
            horde_str = "0 (0.0%)",
            is_max_horde = false,
            elite_str = "0 (0.0%)",
            is_max_elite = false,
            special_str = "0 (0.0%)",
            is_max_special = false,
            boss_str = "0 (0.0%)",
            is_max_boss = false,
            damage_taken_str = "0 (0.0%)",
            is_max_damage_taken = false,
            times_assisted_str = "0",
            is_max_times_assisted = false,
            total_str = "0 (0.0%)",
            is_max_total = false,
            raw_total = mod.scoreboard_number(p.total),
            stat_rows = {},
            stat_rows_n = stat_definitions_n,
        }

        for i = 1, stat_definitions_n do
            local stat_definition = stat_definitions[i]
            local value = mod.scoreboard_number(p[stat_definition.key])
            local value_str = format_scoreboard_stat_value(stat_definition, value, team_totals)
            local is_ranked = should_highlight_scoreboard_stat(stat_definition, value, ranking_values)

            if stat_definition.value_str_key then
                team_entry[stat_definition.value_str_key] = value_str
            end

            if stat_definition.highlight_key then
                team_entry[stat_definition.highlight_key] = is_ranked
            end

            team_entry.stat_rows[i] = {
                key = stat_definition.key,
                label = mod.scoreboard_get_stat_label(stat_definition),
                value = value,
                value_str = value_str,
                is_ranked = is_ranked,
                is_total = not not stat_definition.is_total,
            }
        end

        table.insert(result.team, team_entry)
    end

    table.sort(result.team, function(a, b) return a.raw_total > b.raw_total end)
    return result
end

function generate_display_values_for_mission(mission)
    local total_time = mission.end_time - mission.start_time
    local combat_time = calculate_total_combat_time(mission)
    local combats = mission.combats or {}

    local combat_percentage = 0
    if total_time > 0 then
        combat_percentage = (combat_time / total_time) * 100
    end

    return {
        time = total_time,
        combat_time = combat_time,
        combat_percentage = combat_percentage,
        combats_segments = combats
    }
end

function generate_display_values_for_weapons(mission, weapons, buffs)
    local weapon_display_values = {}

    if not weapons then
        return weapon_display_values
    end

    local mission_start = mission.start_time or 0
    local mission_end = mission.end_time or mission_start
    local mission_time = mission_end - mission_start

    for slot_name, slot_data in pairs(weapons) do
        local events = (slot_data and slot_data.events) or {}

        local active_periods = extract_active_periods(events)
        local active_combat_periods = get_periods_overlaps(active_periods, mission.combats)

        local total_uptime = calculate_uptime(active_periods)
        local uptime_percentage = calculate_uptime_percentage(total_uptime, mission_time)

        local uptime_combat = 0
        local uptime_combat_percentage = 0
        if mission.combats and #mission.combats > 0 then
            local uc, ucp = calculate_combat_uptime(active_periods, mission.combats)
            uptime_combat = uc or 0
            uptime_combat_percentage = ucp or 0
        end
        local weapon_buffs = {}
        for buff_name, buff_data in pairs(buffs) do
            if buff_data.related_item and buff_data.related_item.name == slot_name
                and not has_displayable_parent_buff(buff_name, buff_data, buffs) then
                weapon_buffs[buff_name] = generate_display_values_for_buff(buff_data, mission_time, active_combat_periods)
            end
        end

        weapon_display_values[slot_name] = {
            uptime = total_uptime,
            uptime_percentage = uptime_percentage,
            uptime_combat = uptime_combat,
            uptime_combat_percentage = uptime_combat_percentage,
            active_periods = active_periods,
            active_combat_periods = active_combat_periods,
            tooltip = { title = (slot_data and slot_data.name) or slot_name, description = "" },
            buffs = weapon_buffs
        }
    end

    return weapon_display_values
end

function generate_display_values_for_buffs(mission, buffs, handle_weapon_blessing_separately, player_archetype)
    local buff_display_values = {}
    local mission_time = mission.end_time - mission.start_time

    if buffs then
        for buff_name, buff_data in pairs(buffs) do
            local is_weapon_buff = buff_data.related_item
            local show_buff = (not is_weapon_buff or not handle_weapon_blessing_separately)
                and not has_displayable_parent_buff(buff_name, buff_data, buffs)
            if show_buff then
                local display_values = generate_display_values_for_buff(buff_data, mission_time, mission.combats)

                buff_display_values[buff_name] = add_foreign_archetype_display_data(
                    display_values,
                    buff_name,
                    buff_data,
                    player_archetype
                )
            end
        end
    end
    return buff_display_values
end

function generate_display_values_for_buff(buff, mission_time, combats)
    local max_stacks = buff.max_stacks or 1

    local active_periods = extract_active_periods(buff.events)
    local total_uptime = calculate_uptime(active_periods)

    local mission_combat_time = calculate_total_time(combats)

    local uptime_percentage = (total_uptime / mission_time) * 100

    local uptime_combat = 0
    local uptime_combat_percentage = 0
    local total_combat_time = 0

    if buff.events and combats then
        uptime_combat, uptime_combat_percentage, total_combat_time = calculate_combat_uptime(active_periods, combats)
    end

    local time_per_stack = calculate_time_per_stack(buff.events, max_stacks)
    local combat_time_per_stack = calculate_combat_time_per_stack(buff.events, combats, max_stacks)
    local combat_time_at_max_stack = combat_time_per_stack[max_stacks] or 0

    return {
        uptime = total_uptime,
        uptime_percentage = uptime_percentage,
        uptime_combat = uptime_combat,
        uptime_combat_percentage = uptime_combat_percentage,

        max_stacks = max_stacks,
        stackable = buff.stackable,

        time_per_stack = time_per_stack,
        combat_time_per_stack = combat_time_per_stack,
        combat_percentage_per_stack = calculate_combat_percentage_per_stack(combat_time_per_stack, mission_combat_time),

        time_at_max_stack = time_per_stack[max_stacks] or 0,
        combat_time_at_max_stack = combat_time_at_max_stack,
        combat_percentage_at_max_stack = combat_time_at_max_stack / uptime_combat * 100,

        average_stacks = calculate_average_stacks(time_per_stack, total_uptime, max_stacks),
        average_stacks_combat = calculate_average_stacks(combat_time_per_stack, uptime_combat, max_stacks),

        icon = buff.icon,
        gradient_map = buff.gradient_map,

        tooltip = generate_tooltip(buff)
    }
end

function extract_active_periods(events)
    local active_periods = {}
    local current_period = nil

    for _, event in ipairs(events) do
        if event.type == "add" or event.type == "equipped" then
            current_period = {
                start_time = event.time,
                end_time = nil
            }
        elseif (event.type == "remove" or event.type == "unequipped") and current_period then
            current_period.end_time = event.time
            table.insert(active_periods, current_period)
            current_period = nil
        end
    end

    return active_periods
end

function calculate_uptime(active_periods)
    local total_time = 0
    for _, period in ipairs(active_periods) do
        total_time = total_time + period.end_time - period.start_time
    end
    return total_time
end

function calculate_uptime_percentage(total_uptime, mission_time)
    local uptime_percentage = 0
    if mission_time > 0 then
        uptime_percentage = (total_uptime / mission_time) * 100
    end
    return uptime_percentage
end

function calculate_total_combat_time(mission)
    local total_combat_time = 0
    local combats = mission.combats or {}

    for _, combat in ipairs(combats) do
        local combat_start = math.max(combat.start_time, mission.start_time)
        local combat_end = math.min(combat.end_time, mission.end_time)

        if combat_end > combat_start then
            total_combat_time = total_combat_time + (combat_end - combat_start)
        end
    end

    return total_combat_time
end

function calculate_combat_uptime(active_periods, combats)
    local uptime_combat_percentage = 0

    local active_combat_periods = get_periods_overlaps(active_periods, combats)
    local uptime_combat = calculate_total_time(active_combat_periods)
    local total_combat_time = calculate_total_time(combats)

    if total_combat_time > 0 then
        uptime_combat_percentage = (uptime_combat / total_combat_time) * 100
    end

    return uptime_combat, uptime_combat_percentage, total_combat_time
end

function get_periods_overlaps(periods_a, periods_b)
    local overlaps = {}

    local i, j = 1, 1
    while i <= #periods_a and j <= #periods_b do
        local a = periods_a[i]
        local b = periods_b[j]

        local overlap_start = math.max(a.start_time, b.start_time)
        local overlap_end = math.min(a.end_time, b.end_time)

        if overlap_start < overlap_end then
            table.insert(overlaps, { start_time = overlap_start, end_time = overlap_end })
        end

        if a.end_time < b.end_time then
            i = i + 1
        else
            j = j + 1
        end
    end

    return overlaps
end

function calculate_total_time(periods)
    local total_time = 0

    for _, period in ipairs(periods) do
        total_time = total_time + (period.end_time - period.start_time)
    end

    return total_time
end

function calculate_time_per_stack(buff_events, max_stacks)
    local time_per_stack = {}
    for i = 1, max_stacks do
        time_per_stack[i] = 0
    end

    if buff_events then
        local current_stack = 0
        local last_time = nil

        for _, event in ipairs(buff_events) do
            if last_time and current_stack > 0 then
                local duration = event.time - last_time
                time_per_stack[current_stack] = (time_per_stack[current_stack] or 0) + duration
            end

            if event.type == "add" or event.type == "stack_change" then
                current_stack = event.stack_count or 1
            elseif event.type == "remove" then
                current_stack = 0
            end

            last_time = event.time
        end
    end

    return time_per_stack
end

function calculate_combat_time_per_stack(buff_events, combats, max_stacks)
    local combat_time_per_stack = {}
    for i = 1, max_stacks do
        combat_time_per_stack[i] = 0
    end

    if buff_events and combats then
        local current_stack = 0
        local last_time = nil

        for _, event in ipairs(buff_events) do
            if last_time and current_stack > 0 then
                for _, combat in ipairs(combats) do
                    local period_start = last_time
                    local period_end = event.time

                    local overlap_start = math.max(period_start, combat.start_time)
                    local overlap_end = math.min(period_end, combat.end_time)

                    if overlap_end > overlap_start then
                        combat_time_per_stack[current_stack] = (combat_time_per_stack[current_stack] or 0) +
                            (overlap_end - overlap_start)
                    end
                end
            end

            if event.type == "add" or event.type == "stack_change" then
                current_stack = event.stack_count or 1
            elseif event.type == "remove" then
                current_stack = 0
            end

            last_time = event.time
        end
    end

    return combat_time_per_stack
end

function calculate_combat_percentage_per_stack(combat_time_per_stack, combat_time)
    local percentages = {}
    for i, value in pairs(combat_time_per_stack) do
        percentages[i] = (value / combat_time) * 100
    end
    return percentages
end

function calculate_average_stacks(time_per_stack, total_uptime, max_stacks)
    local average_stacks = 0

    if total_uptime > 0 then
        local weighted_sum = 0
        for stack = 1, max_stacks do
            weighted_sum = weighted_sum + (stack * time_per_stack[stack])
        end
        average_stacks = weighted_sum / total_uptime
    end

    return average_stacks
end

function generate_tooltip(buff)
    local title, description
    local item = buff.related_item
    local talent = talent_lib.get_talent_for_buff(buff)
    if talent then
        title = Localize(talent.display_name)
        description = TalentLayoutParser.talent_description(talent, 1, Color.ui_terminal(255, true))
    elseif item then
        title = item.name
        description = ""
        if item.blessing then
            title = title .. "\n" .. item.blessing.name or ""
            description = item.blessing.description or Localize("loc_unknown_blessing")
        end
    else
        return nil
    end

    local buff_template_name = buff.template_name

    if type(buff_template_name) == "string" and buff_template_name ~= "" then
        local formatted_template_name = TextUtilities.apply_color_to_text(
            buff_template_name,
            BUFF_TEMPLATE_NAME_COLOR
        )

        description = description ~= "" and description .. "\n" .. formatted_template_name or formatted_template_name
    end

    return {
        title = title,
        description = description
    }
end
