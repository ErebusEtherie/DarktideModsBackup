local mod = get_mod("uptime")

local mission_tracking = {
    start_time = nil,
    end_time = nil,
    combats = {}
}

function mod:tracking_in_progress()
    local has_started = mission_tracking.start_time ~= nil
    local has_ended = mission_tracking.end_time ~= nil
    return has_started and (not has_ended)
end

function mod:start_mission_tracking()
    mission_tracking.start_time = mod:now()
    mission_tracking.end_time = nil
    mission_tracking.combats = {}
end

function mod:end_mission_tracking()
    local end_time = mod:now()
    mission_tracking.end_time = end_time

    local combats = mission_tracking.combats
    if #combats > 0 then
        local last_combat = combats[#combats]
        if last_combat.end_time > end_time then
            last_combat.end_time = end_time
        end
    end
    return mission_tracking
end

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage,
                                                                       attack_result, attack_type, damage_efficiency, ...)
    if not mod:tracking_in_progress() then
        return
    end
    add_combat(attacking_unit, attacked_unit)
end)

function add_combat(attacking_unit, attacked_unit)
    if not is_local_player(attacking_unit) and not is_local_player(attacked_unit) then
        return
    end

    local now = mod:now()
    local combats = mission_tracking.combats
    local combat_duration = 5 -- Duration to extend combat in seconds

    if #combats > 0 then
        local last_combat = combats[#combats]

        if now >= last_combat.start_time and now <= last_combat.end_time then
            -- Current time is within the last combat window, extend the end time
            last_combat.end_time = now + combat_duration
        elseif now > last_combat.end_time then
            -- Current time is past the last combat window, create a new entry
            table.insert(combats, {
                start_time = now,
                end_time = now + combat_duration
            })
        end
    else
        -- No combat entries yet, create the first one
        table.insert(combats, {
            start_time = now,
            end_time = now + combat_duration
        })
    end
end

function is_local_player(unit)
    local player = Managers.player:local_player(1)
    return unit == player.player_unit
end