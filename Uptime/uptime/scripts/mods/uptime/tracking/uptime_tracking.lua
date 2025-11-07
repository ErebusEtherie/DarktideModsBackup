local mod = get_mod("uptime")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_buff_tracking")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_mission_tracking")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_weapon_tracking")
mod:io_dofile("uptime/scripts/mods/uptime/tracking/uptime_override_hud_logic")

mod.mission_params = nil

function mod:try_start_tracking(params)
    if mod:tracking_in_progress() then
        return false
    end
    mod:start_mission_tracking()
    mod:start_buff_tracking()
    mod:start_weapon_tracking()
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

    local player = Managers.player:local_player(1):name()
    local archetype = Managers.player:local_player(1):archetype_name()
    local params = mod.mission_params
    local entry = {
        version = 3,
        buffs = buffs,
        weapons = weapon_tracking,
        mission = mission,
        mission_name = params.mission_name,
        meta_data = {
            mission_name = params.mission_name,
            player = player,
            archetype = archetype,
            mission_difficulty = params.mechanism_data.challenge,
            mission_modifier = params.mechanism_data.circumstance_name,
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