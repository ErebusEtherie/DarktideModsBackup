local mod = get_mod("aggro_indicator")

local AggroDetection = {}

AggroDetection.AGGRO_NONE = nil
AggroDetection.AGGRO_POX_BURSTER = "pox_burster"
AggroDetection.AGGRO_TRAPPER = "trapper"
AggroDetection.AGGRO_DOG = "dog"
AggroDetection.AGGRO_MUTANT = "mutant"
AggroDetection.AGGRO_SNIPER = "sniper"
AggroDetection.AGGRO_CAPTAIN = "captain"
AggroDetection.AGGRO_MONSTROSITY = "monstrosity"
AggroDetection.AGGRO_DAEMONHOST = "daemonhost"
AggroDetection.AGGRO_GRENADIER = "grenadier"
AggroDetection.AGGRO_CRUSHER = "crusher"
AggroDetection.AGGRO_FLAMER = "flamer"
AggroDetection.AGGRO_RAGER = "rager"

local AGGRO_PRIORITY = {
    pox_burster = 12,
    trapper = 11,
    dog = 10,
    mutant = 9,
    sniper = 8,
    captain = 7,
    monstrosity = 6,
    daemonhost = 5,
    grenadier = 4,
    crusher = 3,
    flamer = 2,
    rager = 1,
}

local SCAN_INTERVAL = 0.25
local _last_scan_time = 0

local _aggro_state = {}

local function _classify_enemy(enemy_unit)
    local unit_data_ext = ScriptUnit.has_extension(enemy_unit, "unit_data_system")
        and ScriptUnit.extension(enemy_unit, "unit_data_system")
    if not unit_data_ext then
        return nil
    end

    local breed = unit_data_ext:breed()
    if not breed or not breed.tags then
        return nil
    end

    local tags = breed.tags
    local breed_name = breed.name

    if breed_name == "chaos_ogryn_executor" or breed_name == "renegade_executor" then
        return AggroDetection.AGGRO_CRUSHER
    end

    if breed_name == "renegade_berzerker" or breed_name == "cultist_berzerker" then
        return AggroDetection.AGGRO_RAGER
    end

    if breed_name == "renegade_grenadier" or breed_name == "cultist_grenadier" then
        return AggroDetection.AGGRO_GRENADIER
    end

    if breed_name == "renegade_flamer" or breed_name == "cultist_flamer" or breed_name == "renegade_flamer_mutator" then
        return AggroDetection.AGGRO_FLAMER
    end

    if tags.witch then
        return AggroDetection.AGGRO_DAEMONHOST
    end

    if tags.captain or tags.cultist_captain then
        return AggroDetection.AGGRO_CAPTAIN
    end

    if tags.monster then
        return AggroDetection.AGGRO_MONSTROSITY
    end

    if breed_name == "chaos_hound" or breed_name == "chaos_hound_mutator" then
        return AggroDetection.AGGRO_DOG
    end

    if breed_name == "renegade_netgunner" or breed_name == "cultist_netgunner" then
        return AggroDetection.AGGRO_TRAPPER
    end

    if breed_name == "chaos_mutant_charger" or breed_name == "chaos_mutant_mutator" or breed_name == "chaos_mutant" or breed_name == "cultist_mutant" or breed_name == "cultist_mutant_mutator" then
        return AggroDetection.AGGRO_MUTANT
    end

    if tags.sniper then
        return AggroDetection.AGGRO_SNIPER
    end

    if tags.bomber then
        return AggroDetection.AGGRO_POX_BURSTER
    end

    if breed.is_boss then
        return AggroDetection.AGGRO_CAPTAIN
    end

    return nil
end

local function _resolve_target_from_game_object(enemy_unit, game_session, unit_spawner)
    local ok_go_id, game_object_id = pcall(function()
        return unit_spawner:game_object_id(enemy_unit)
    end)

    if not ok_go_id or not game_object_id then
        return nil
    end

    local ok_has_field, has_field = pcall(function()
        return GameSession.has_game_object_field(game_session, game_object_id, "target_unit_id")
    end)

    if not ok_has_field or has_field ~= true then
        return nil
    end

    local ok_target_id, target_unit_id = pcall(function()
        return GameSession.game_object_field(game_session, game_object_id, "target_unit_id")
    end)

    if not ok_target_id or not target_unit_id or target_unit_id == NetworkConstants.invalid_game_object_id then
        return nil
    end

    local ok_unit, target_unit = pcall(function()
        return unit_spawner:unit(target_unit_id)
    end)

    if ok_unit and target_unit and HEALTH_ALIVE[target_unit] and Unit.alive(target_unit) then
        return target_unit
    end

    return nil
end

local function _resolve_target_from_perception(enemy_unit, perception_map)
    if not perception_map then
        return nil
    end

    local ext = perception_map[enemy_unit]
    if not ext then
        return nil
    end

    local perception_component = ext._perception_component
    local target_unit = perception_component and perception_component.target_unit

    if target_unit and HEALTH_ALIVE[target_unit] and Unit.alive(target_unit) then
        return target_unit
    end

    return nil
end

local function _is_player_unit(unit)
    local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn
    if not player_unit_spawn then
        return false
    end

    local owner = player_unit_spawn:owner(unit)
    return owner ~= nil
end

function AggroDetection.scan(dt)
    _last_scan_time = _last_scan_time + dt
    if _last_scan_time < SCAN_INTERVAL then
        return
    end
    _last_scan_time = 0

    table.clear(_aggro_state)

    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then
        return
    end

    local side_system = extension_manager:system("side_system")
    if not side_system then
        return
    end

    local local_player = Managers.player and Managers.player:local_player(1)
    if not local_player or not local_player.player_unit then
        return
    end

    local player_unit = local_player.player_unit
    local player_side = side_system.side_by_unit[player_unit]
    if not player_side then
        return
    end

    local enemy_side_names = player_side:relation_side_names("enemy")
    if not enemy_side_names then
        return
    end

    local game_session_manager = Managers.state.game_session
    local unit_spawner = Managers.state.unit_spawner

    local game_session = nil
    if game_session_manager and type(game_session_manager.game_session) == "function" then
        local ok, gs = pcall(function() return game_session_manager:game_session() end)
        if ok then
            game_session = gs
        end
    end

    local perception_system = extension_manager:system("perception_system")
    local perception_map = nil
    if perception_system and type(perception_system.unit_to_extension_map) == "function" then
        local ok, map = pcall(function() return perception_system:unit_to_extension_map() end)
        if ok and type(map) == "table" then
            perception_map = map
        end
    end

    local enable_pox_burster = mod:get("aggro_pox_burster_enabled")
    if enable_pox_burster == nil then enable_pox_burster = true end
    local enable_trapper = mod:get("aggro_trapper_enabled")
    if enable_trapper == nil then enable_trapper = true end
    local enable_dog = mod:get("aggro_dog_enabled")
    if enable_dog == nil then enable_dog = true end
    local enable_mutant = mod:get("aggro_mutant_enabled")
    if enable_mutant == nil then enable_mutant = true end
    local enable_sniper = mod:get("aggro_sniper_enabled")
    if enable_sniper == nil then enable_sniper = true end
    local enable_captain = mod:get("aggro_captain_enabled")
    if enable_captain == nil then enable_captain = true end
    local enable_monstrosity = mod:get("aggro_monstrosity_enabled")
    if enable_monstrosity == nil then enable_monstrosity = true end
    local enable_daemonhost = mod:get("aggro_daemonhost_enabled")
    if enable_daemonhost == nil then enable_daemonhost = true end
    local enable_grenadier = mod:get("aggro_grenadier_enabled")
    if enable_grenadier == nil then enable_grenadier = false end
    local enable_crusher = mod:get("aggro_crusher_enabled")
    if enable_crusher == nil then enable_crusher = false end
    local enable_flamer = mod:get("aggro_flamer_enabled")
    if enable_flamer == nil then enable_flamer = false end
    local enable_rager = mod:get("aggro_rager_enabled")
    if enable_rager == nil then enable_rager = false end

    for unit, _ in pairs(side_system.side_by_unit) do
        if HEALTH_ALIVE[unit] and Unit.alive(unit) then
            local unit_side = side_system.side_by_unit[unit]
            local is_enemy = false

            if unit_side then
                local unit_side_name = unit_side:name()
                for i = 1, #enemy_side_names do
                    if enemy_side_names[i] == unit_side_name then
                        is_enemy = true
                        break
                    end
                end
            end

            if is_enemy then
                local aggro_type = _classify_enemy(unit)

                if aggro_type then
                    local allowed = false
                    if aggro_type == AggroDetection.AGGRO_POX_BURSTER then
                        allowed = enable_pox_burster
                    elseif aggro_type == AggroDetection.AGGRO_TRAPPER then
                        allowed = enable_trapper
                    elseif aggro_type == AggroDetection.AGGRO_DOG then
                        allowed = enable_dog
                    elseif aggro_type == AggroDetection.AGGRO_MUTANT then
                        allowed = enable_mutant
                    elseif aggro_type == AggroDetection.AGGRO_SNIPER then
                        allowed = enable_sniper
                    elseif aggro_type == AggroDetection.AGGRO_CAPTAIN then
                        allowed = enable_captain
                    elseif aggro_type == AggroDetection.AGGRO_MONSTROSITY then
                        allowed = enable_monstrosity
                    elseif aggro_type == AggroDetection.AGGRO_DAEMONHOST then
                        allowed = enable_daemonhost
                    elseif aggro_type == AggroDetection.AGGRO_GRENADIER then
                        allowed = enable_grenadier
                    elseif aggro_type == AggroDetection.AGGRO_CRUSHER then
                        allowed = enable_crusher
                    elseif aggro_type == AggroDetection.AGGRO_FLAMER then
                        allowed = enable_flamer
                    elseif aggro_type == AggroDetection.AGGRO_RAGER then
                        allowed = enable_rager
                    end

                    if allowed then
                        local target_unit = nil
                        if game_session and unit_spawner then
                            target_unit = _resolve_target_from_game_object(unit, game_session, unit_spawner)
                        end
                        if not target_unit then
                            target_unit = _resolve_target_from_perception(unit, perception_map)
                        end

                        if target_unit and _is_player_unit(target_unit) then
                            local existing = _aggro_state[target_unit]
                            local new_priority = AGGRO_PRIORITY[aggro_type] or 0
                            local existing_priority = existing and AGGRO_PRIORITY[existing.type] or 0

                            if new_priority > existing_priority then
                                _aggro_state[target_unit] = {
                                    type = aggro_type,
                                    enemy_unit = unit,
                                }
                            elseif new_priority == existing_priority and existing then
                                local target_pos = POSITION_LOOKUP[target_unit] or (Unit.alive(target_unit) and Unit.local_position(target_unit, 1))
                                local current_enemy_pos = POSITION_LOOKUP[existing.enemy_unit] or (Unit.alive(existing.enemy_unit) and Unit.local_position(existing.enemy_unit, 1))
                                local new_enemy_pos = POSITION_LOOKUP[unit] or (Unit.alive(unit) and Unit.local_position(unit, 1))
                                
                                if target_pos and current_enemy_pos and new_enemy_pos then
                                    local current_dist = Vector3.distance_squared(target_pos, current_enemy_pos)
                                    local new_dist = Vector3.distance_squared(target_pos, new_enemy_pos)
                                    if new_dist < current_dist then
                                        _aggro_state[target_unit] = {
                                            type = aggro_type,
                                            enemy_unit = unit,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function AggroDetection.get_aggro_for_unit(player_unit)
    local state = _aggro_state[player_unit]
    if state then
        return state.type, state.enemy_unit
    end
    return nil, nil
end

function AggroDetection.clear()
    table.clear(_aggro_state)
    _last_scan_time = 0
end

return AggroDetection
