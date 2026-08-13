-- File: uptime/scripts/mods/uptime/libs/scoreboard_stats.lua
local mod = get_mod("uptime"); if not mod then return end

local math_floor = math.floor
local string_format = string.format
local table_clear = table.clear
local tonumber = tonumber
local type = type

--[[
    Shared scoreboard stat definitions and ranking helpers.

    - Stat definitions are allocated once when the file loads.
    - Ranking work is limited to seven fixed stats per displayed player.
    - Helper functions accept reusable output tables where practical, avoiding repeated table allocation in future live overlay use.
--]]

mod.scoreboard_stat_definitions = {
    {
        key = "horde",
        label = "Horde",
        higher_is_better = true,
        highlight_enabled = true,
        highlight_key = "is_max_horde",
        value_str_key = "horde_str",
    },
    {
        key = "elite",
        label = "Elite",
        higher_is_better = true,
        highlight_enabled = true,
        highlight_key = "is_max_elite",
        value_str_key = "elite_str",
    },
    {
        key = "special",
        label = "Special",
        higher_is_better = true,
        highlight_enabled = true,
        highlight_key = "is_max_special",
        value_str_key = "special_str",
    },
    {
        key = "boss",
        label = "Boss",
        higher_is_better = true,
        highlight_enabled = true,
        highlight_key = "is_max_boss",
        value_str_key = "boss_str",
    },
    {
        key = "total",
        loc_key = "loc_damage_total",
        fallback_label = "Total",
        higher_is_better = true,
        highlight_enabled = true,
        highlight_key = "is_max_total",
        value_str_key = "total_str",
        is_total = true,
    },
    {
        key = "damage_taken",
        label = "Damage Taken",
        higher_is_better = false,
        highlight_enabled = true,
        highlight_key = "is_max_damage_taken",
        value_str_key = "damage_taken_str",
    },
    {
        key = "times_assisted",
        label = "Times Assisted",
        higher_is_better = false,
        highlight_enabled = true,
        highlight_key = "is_max_times_assisted",
        value_str_key = "times_assisted_str",
    },
}

mod.scoreboard_stat_definitions_n = 7

function mod.scoreboard_get_stat_label(stat_definition)
    if not stat_definition then
        return ""
    end

    local loc_key = stat_definition.loc_key

    if loc_key and mod.localize then
        return mod:localize(loc_key)
    end

    return stat_definition.label or stat_definition.fallback_label or stat_definition.key or ""
end

function mod.scoreboard_number(value)
    return tonumber(value) or 0
end

function mod.scoreboard_format_stat_value(value)
    return string_format("%d", math_floor(mod.scoreboard_number(value)))
end

function mod.scoreboard_clear_stat_rows(rows, used_rows)
    if not rows then
        return
    end

    used_rows = used_rows or 0

    local index = used_rows + 1

    while rows[index] do
        rows[index] = nil
        index = index + 1
    end
end

function mod.scoreboard_calculate_ranking_values(damage_data, ranking_values)
    ranking_values = ranking_values or {}

    table_clear(ranking_values)

    if not damage_data then
        return ranking_values
    end

    local stat_definitions = mod.scoreboard_stat_definitions
    local stat_definitions_n = mod.scoreboard_stat_definitions_n

    for _, player_data in pairs(damage_data) do
        if player_data then
            for i = 1, stat_definitions_n do
                local stat_definition = stat_definitions[i]
                local key = stat_definition.key
                local value = mod.scoreboard_number(player_data[key])
                local current_value = ranking_values[key]

                if current_value == nil then
                    ranking_values[key] = value
                elseif stat_definition.higher_is_better then
                    if current_value < value then
                        ranking_values[key] = value
                    end
                elseif value < current_value then
                    ranking_values[key] = value
                end
            end
        end
    end

    return ranking_values
end

function mod.scoreboard_is_ranked_value(stat_definition, value, ranking_values)
    if not stat_definition or not stat_definition.highlight_enabled or not ranking_values then
        return false
    end

    local ranked_value = ranking_values[stat_definition.key]

    if ranked_value == nil then
        return false
    end

    return mod.scoreboard_number(value) == ranked_value
end

function mod.scoreboard_apply_ranking_flags(player_data, ranking_values)
    if not player_data then
        return
    end

    local stat_definitions = mod.scoreboard_stat_definitions
    local stat_definitions_n = mod.scoreboard_stat_definitions_n

    for i = 1, stat_definitions_n do
        local stat_definition = stat_definitions[i]
        local highlight_key = stat_definition.highlight_key

        if highlight_key then
            player_data[highlight_key] = mod.scoreboard_is_ranked_value(
                stat_definition,
                player_data[stat_definition.key],
                ranking_values
            )
        end
    end
end

function mod.scoreboard_prepare_player_stat_rows(player_data, ranking_values, rows)
    rows = rows or {}

    if not player_data then
        mod.scoreboard_clear_stat_rows(rows, 0)

        return rows, 0
    end

    local stat_definitions = mod.scoreboard_stat_definitions
    local stat_definitions_n = mod.scoreboard_stat_definitions_n

    for i = 1, stat_definitions_n do
        local stat_definition = stat_definitions[i]
        local row = rows[i]

        if not row then
            row = {
                key = nil,
                label = nil,
                value = 0,
                value_str = "0",
                is_ranked = false,
                is_total = false,
            }

            rows[i] = row
        end

        local value = mod.scoreboard_number(player_data[stat_definition.key])

        row.key = stat_definition.key
        row.label = mod.scoreboard_get_stat_label(stat_definition)
        row.value = value
        row.value_str = mod.scoreboard_format_stat_value(value)
        row.is_ranked = mod.scoreboard_is_ranked_value(stat_definition, value, ranking_values)
        row.is_total = not not stat_definition.is_total
    end

    mod.scoreboard_clear_stat_rows(rows, stat_definitions_n)

    return rows, stat_definitions_n
end

function mod.scoreboard_apply_stat_strings(player_data)
    if not player_data then
        return
    end

    local stat_definitions = mod.scoreboard_stat_definitions
    local stat_definitions_n = mod.scoreboard_stat_definitions_n

    for i = 1, stat_definitions_n do
        local stat_definition = stat_definitions[i]
        local value_str_key = stat_definition.value_str_key

        if value_str_key then
            player_data[value_str_key] = mod.scoreboard_format_stat_value(player_data[stat_definition.key])
        end
    end
end

return true
