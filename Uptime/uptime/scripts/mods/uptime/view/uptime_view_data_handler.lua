local mod = get_mod("uptime")

local talent_lib = mod:io_dofile("uptime/scripts/mods/uptime/libs/talents")
local TalentLayoutParser = mod:original_require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")

function mod:generate_display_values(entry)
    local has_weapon_tracking = tonumber(entry.version) > 2
    local mission = entry.mission
    local mission_display_values = generate_display_values_for_mission(mission)
    local buff_display_values = generate_display_values_for_buffs(mission, entry.buffs, has_weapon_tracking)
    local weapon_display_values = has_weapon_tracking and generate_display_values_for_weapons(mission, entry.weapons, entry.buffs) or nil
    return {
        mission = mission_display_values,
        buffs = buff_display_values,
        weapons = weapon_display_values
    }
end

function generate_display_values_for_mission(mission)
    -- Calculate total mission time (end_time - start_time)
    local total_time = mission.end_time - mission.start_time

    -- Calculate total combat time by summing up all combat sections
    local combat_time = calculate_total_combat_time(mission)
    local combats = mission.combats or {}

    -- Calculate combat percentage (avoid division by zero)
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
            if buff_data.related_item and buff_data.related_item.name == slot_name then
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

function generate_display_values_for_buffs(mission, buffs, handle_weapon_blessing_separately)
    local buff_display_values = {}

    local mission_time = mission.end_time - mission.start_time

    if buffs then
        for buff_name, buff_data in pairs(buffs) do
            local is_weapon_buff = buff_data.related_item
            local show_buff = not is_weapon_buff or not handle_weapon_blessing_separately
            if show_buff then
                buff_display_values[buff_name] = generate_display_values_for_buff(buff_data, mission_time, mission.combats)
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

    -- Initialize combat uptime variables
    local uptime_combat = 0
    local uptime_combat_percentage = 0
    local total_combat_time = 0

    -- Process buff events to calculate combat uptime
    if buff.events and combats then
        uptime_combat, uptime_combat_percentage, total_combat_time = calculate_combat_uptime(active_periods, combats)
    end

    -- Calculate time per stack
    local time_per_stack = calculate_time_per_stack(buff.events, max_stacks)

    -- Calculate combat time per stack
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

-- Extract active periods from buff events
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

-- Calculate uptime percentage based on mission time
function calculate_uptime(active_periods)
    local total_time = 0
    for _, period in ipairs(active_periods) do
        total_time = total_time + period.end_time - period.start_time
    end
    return total_time
end

-- Calculate uptime percentage based on mission time
function calculate_uptime_percentage(total_uptime, mission_time)
    local uptime_percentage = 0
    if mission_time > 0 then
        uptime_percentage = (total_uptime / mission_time) * 100
    end
    return uptime_percentage
end


-- Calculate total combat time in mission
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

-- Calculate combat uptime and percentage
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

        -- Calculate overlap between current periods
        local overlap_start = math.max(a.start_time, b.start_time)
        local overlap_end = math.min(a.end_time, b.end_time)

        -- If overlap exists, record it
        if overlap_start < overlap_end then
            table.insert(overlaps, { start_time = overlap_start, end_time = overlap_end })
        end

        -- Move the pointer that ends first
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

-- Calculate time spent at each stack level
function calculate_time_per_stack(buff_events, max_stacks)
    local time_per_stack = {}
    for i = 1, max_stacks do
        time_per_stack[i] = 0
    end

    if buff_events then
        local current_stack = 0
        local last_time = nil

        for _, event in ipairs(buff_events) do
            -- If we have a previous event, calculate time at that stack level
            if last_time and current_stack > 0 then
                local duration = event.time - last_time
                time_per_stack[current_stack] = (time_per_stack[current_stack] or 0) + duration
            end

            -- Update stack count and time for next calculation
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
            -- If we have a previous event and valid stack, calculate combat time for that stack
            if last_time and current_stack > 0 then
                -- For each period between events, check overlap with combat
                for _, combat in ipairs(combats) do
                    local period_start = last_time
                    local period_end = event.time

                    local overlap_start = math.max(period_start, combat.start_time)
                    local overlap_end = math.min(period_end, combat.end_time)

                    if overlap_end > overlap_start then
                        combat_time_per_stack[current_stack] = (combat_time_per_stack[current_stack] or 0) + (overlap_end - overlap_start)
                    end
                end
            end

            -- Update stack count and time for next calculation
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
    return {
        title = title,
        description = description
    }
end