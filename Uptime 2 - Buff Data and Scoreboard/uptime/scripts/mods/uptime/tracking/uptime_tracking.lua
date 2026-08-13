-- File: uptime/scripts/mods/uptime/tracking/uptime_tracking.lua
local mod = get_mod("uptime"); if not mod then return end
local Havoc = mod:original_require("scripts/utilities/havoc")
local Danger = mod:original_require("scripts/utilities/danger")

mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_buff_tracking")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_mission_tracking")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_weapon_tracking")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_loadout_tracking")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_override_hud_logic")

mod.mission_params = nil

local HAVOC_CIRCUMSTANCE_SEPARATOR = " • "

local function scoreboard_tracking_enabled()
    if type(mod.scoreboard_tracking_enabled) ~= "function" then
        return false
    end

    return mod.scoreboard_tracking_enabled()
end

local function get_parsed_havoc_data(params)
    local difficulty_manager = Managers.state and Managers.state.difficulty
    local parsed_havoc_data = difficulty_manager and difficulty_manager.get_parsed_havoc_data and
        difficulty_manager:get_parsed_havoc_data()

    if parsed_havoc_data then
        return parsed_havoc_data
    end

    local mechanism_data = params and params.mechanism_data
    local havoc_data = mechanism_data and mechanism_data.havoc_data

    if havoc_data and Havoc and Havoc.parse_data then
        return Havoc.parse_data(havoc_data)
    end

    return nil
end

local function get_mission_difficulty(params)
    local parsed_havoc_data = get_parsed_havoc_data(params)
    local havoc_rank = parsed_havoc_data and parsed_havoc_data.havoc_rank

    if havoc_rank then
        return "Havoc Rank " .. tostring(havoc_rank)
    end

    local mechanism_data = params and params.mechanism_data
    local challenge = mechanism_data and mechanism_data.challenge
    local resistance = mechanism_data and mechanism_data.resistance

    if challenge and Danger and Danger.calculate_danger then
        local danger_index = Danger.calculate_danger(challenge, resistance)

        if danger_index then
            return danger_index
        end
    end

    return challenge
end

local function add_havoc_circumstance(circumstances, seen_circumstances, circumstance_name)
    if not circumstance_name or circumstance_name == "" or seen_circumstances[circumstance_name] then
        return
    end

    circumstances[#circumstances + 1] = circumstance_name
    seen_circumstances[circumstance_name] = true
end

local function extract_havoc_circumstance_name(circumstance)
    if type(circumstance) == "table" then
        return circumstance.name or circumstance.circumstance_name or circumstance[1]
    end

    return circumstance
end

local function get_havoc_circumstances_modifier(parsed_havoc_data)
    local parsed_circumstances = parsed_havoc_data and parsed_havoc_data.circumstances

    if not parsed_circumstances then
        return nil
    end

    local circumstances = {}
    local seen_circumstances = {}

    for i = 1, #parsed_circumstances do
        add_havoc_circumstance(
            circumstances,
            seen_circumstances,
            extract_havoc_circumstance_name(parsed_circumstances[i])
        )
    end

    if #circumstances == 0 then
        for circumstance_name, enabled in pairs(parsed_circumstances) do
            if enabled then
                add_havoc_circumstance(circumstances, seen_circumstances, circumstance_name)
            end
        end
    end

    if #circumstances > 0 then
        return table.concat(circumstances, HAVOC_CIRCUMSTANCE_SEPARATOR)
    end

    return nil
end

local function get_mission_modifier(params)
    local parsed_havoc_data = get_parsed_havoc_data(params)
    local havoc_rank = parsed_havoc_data and parsed_havoc_data.havoc_rank

    if havoc_rank then
        local havoc_circumstances_modifier = get_havoc_circumstances_modifier(parsed_havoc_data)

        if havoc_circumstances_modifier then
            return havoc_circumstances_modifier
        end
    end

    local mechanism_data = params and params.mechanism_data

    return mechanism_data and mechanism_data.circumstance_name
end

function mod:try_start_tracking(params)
    if mod:tracking_in_progress() then
        return false
    end

    mod:start_mission_tracking()
    mod:start_buff_tracking()
    mod:start_weapon_tracking()

    if scoreboard_tracking_enabled() and type(mod.start_damage_tracking) == "function" then
        mod:start_damage_tracking()
    end

    mod.mission_params = params

    return true
end

function mod:try_end_tracking()
    if not mod:tracking_in_progress() then
        return false
    end

    local mission = mod:end_mission_tracking()
    local buffs = mod:end_buff_tracking(mission.end_time)
    local weapon_tracking = mod:end_weapon_tracking(mission.end_time)
    local damage_tracking = nil
    local loadout_tracking = nil

    if scoreboard_tracking_enabled() then
        if type(mod.end_damage_tracking) == "function" then
            damage_tracking = mod:end_damage_tracking()
        end

        if type(mod.capture_team_loadouts) == "function" then
            loadout_tracking = mod:capture_team_loadouts()
        end
    end

    local player = Managers.player:local_player_safe(1)
    local player_name = player and player:name()
    local account_id = player and player:account_id() or player_name
    local archetype = player and player:archetype_name()
    local params = mod.mission_params or {}
    local entry = {
        version = 4,
        buffs = buffs,
        weapons = weapon_tracking,
        damage = damage_tracking,
        loadouts = loadout_tracking,
        mission = mission,
        mission_name = params.mission_name,
        meta_data = {
            mission_name = params.mission_name,
            player = player_name,
            account_id = account_id,
            archetype = archetype,
            mission_difficulty = get_mission_difficulty(params),
            mission_modifier = get_mission_modifier(params),
            date = mod:current_date(),
        },
    }

    mod:save_entry(entry)

    return true
end

function mod:now()
    if not Managers.time:has_timer("gameplay") then
        return 0
    end

    return Managers.time:time("gameplay")
end
