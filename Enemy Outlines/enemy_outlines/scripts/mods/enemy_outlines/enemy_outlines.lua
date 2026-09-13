local mod = get_mod("enemy_outlines")

local OutlineSettings = require("scripts/settings/outline/outline_settings")

local function get_rgb_color(prefix)
    local c = mod:get(prefix .. "_color")
    if c and type(c) == "table" and #c >= 3 then
        return { c[2] / 255, c[3] / 255, c[4] / 255 }
    end
    local defaults = {
        aimed = {255, 255, 255},
        human_boss = {255, 50, 100},
        monster = {255, 0, 0},
        disabler = {0, 255, 0},
        ranged_special = {0, 255, 255},
        poxburster = {255, 255, 0},
        ranged_elite = {0, 0, 255},
        melee_elite = {81, 53, 146},
        crushers_maulers = {255, 140, 0},
        shooters = {245, 245, 135},
        chaff = {105, 55, 20},
    }
    local d = defaults[prefix]
    if d then
        return { d[1] / 255, d[2] / 255, d[3] / 255 }
    end
    return { 1, 1, 1 }
end

local function get_material_layers()
    return { "minion_outline", "minion_outline_reversed_depth" }
end

local function _check_line_of_sight(player_unit, target_unit)
    local player_pos = Unit.local_position(player_unit, 1) + Vector3(0, 0, 1.6)
    local target_pos = Unit.local_position(target_unit, 1) + Vector3(0, 0, 1.0)
    local to_target = target_pos - player_pos
    local distance = Vector3.length(to_target)
    if distance < 0.5 then return true end
    local direction = Vector3.normalize(to_target)

    local world = Managers.world:world("level_world")
    if not world then return true end
    local physics_world = World.physics_world(world)
    if not physics_world then return true end

    local hit = PhysicsWorld.raycast(physics_world, player_pos, direction, distance, "closest", "types", "statics", "collision_filter", "filter_minion_line_of_sight_check")
    return not hit
end

local function _minion_alive_check(unit)
    if not HEALTH_ALIVE[unit] then
        return false
    end
    return true
end

local function update_outline_settings()
    local layers = get_material_layers()

    OutlineSettings.MinionOutlineExtension.mod_outline_human_boss = {
        priority = 20,
        color = get_rgb_color("human_boss"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_monster = {
        priority = 20,
        color = get_rgb_color("monster"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_disabler = {
        priority = 20,
        color = get_rgb_color("disabler"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_ranged_special = {
        priority = 20,
        color = get_rgb_color("ranged_special"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_poxburster = {
        priority = 20,
        color = get_rgb_color("poxburster"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_ranged_elite = {
        priority = 20,
        color = get_rgb_color("ranged_elite"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_melee_elite = {
        priority = 20,
        color = get_rgb_color("melee_elite"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_aimed = {
        priority = 0,
        color = get_rgb_color("aimed"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_crushers_maulers = {
        priority = 20,
        color = get_rgb_color("crushers_maulers"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_shooters = {
        priority = 20,
        color = get_rgb_color("shooters"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
    OutlineSettings.MinionOutlineExtension.mod_outline_chaff = {
        priority = 20,
        color = get_rgb_color("chaff"),
        material_layers = layers,
        visibility_check = _minion_alive_check,
    }
end

update_outline_settings()

local _refresh_outlines = false
mod.on_setting_changed = function(setting_id)
    update_outline_settings()
    _refresh_outlines = true
end

local function _resolve_target_from_game_object(enemy_unit, game_session, unit_spawner)
    local ok_go_id, game_object_id = pcall(function() return unit_spawner:game_object_id(enemy_unit) end)
    if not ok_go_id or not game_object_id then return nil end

    local ok_has_field, has_field = pcall(function() return GameSession.has_game_object_field(game_session, game_object_id, "target_unit_id") end)
    if not ok_has_field or has_field ~= true then return nil end

    local ok_target_id, target_unit_id = pcall(function() return GameSession.game_object_field(game_session, game_object_id, "target_unit_id") end)
    if not ok_target_id or not target_unit_id or target_unit_id == NetworkConstants.invalid_game_object_id then return nil end

    local ok_unit, target_unit = pcall(function() return unit_spawner:unit(target_unit_id) end)
    if ok_unit and target_unit and HEALTH_ALIVE[target_unit] and Unit.alive(target_unit) then
        return target_unit
    end
    return nil
end

local function _resolve_target_from_perception(enemy_unit, perception_map)
    if not perception_map then return nil end
    local ext = perception_map[enemy_unit]
    if not ext then return nil end
    local perception_component = ext._perception_component
    local target_unit = perception_component and perception_component.target_unit
    if target_unit and HEALTH_ALIVE[target_unit] and Unit.alive(target_unit) then
        return target_unit
    end
    return nil
end

local function _get_enemy_category(unit)
    local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
    if not unit_data_ext then return nil end
    local breed = unit_data_ext:breed()
    if not breed or not breed.tags then return nil end
    
    if breed.tags.captain or breed.tags.cultist_captain then
        return "human_boss"
    elseif breed.tags.monster then
        return "monster"
    elseif breed.tags.disabler then
        return "disabler"
    elseif breed.tags.special then
        if breed.tags.bomber then
            return "poxburster"
        elseif breed.ranged or breed.tags.scrambler or breed.tags.sniper or breed.name:find("grenadier") or breed.name:find("flamer") then
            return "ranged_special"
        else
            return "poxburster"
        end
    elseif breed.tags.elite then
        if breed.name == "chaos_ogryn_executor" or breed.name == "renegade_executor" then
            return "crushers_maulers"
        elseif breed.ranged then
            return "ranged_elite"
        else
            return "melee_elite"
        end
    elseif breed.name == "cultist_assault" or breed.name == "renegade_assault" or breed.name == "renegade_rifleman" or breed.ranged then
        return "shooters"
    else
        return "chaff"
    end
end

local SCAN_INTERVAL = 0.25
local _last_scan_time = 0

local _unit_category_cache = setmetatable({}, { __mode = "k" })
local _unit_is_enemy_cache = setmetatable({}, { __mode = "k" })

mod.update = function(dt)
    local run_heavy_scan = false
    _last_scan_time = _last_scan_time + dt
    if _last_scan_time >= SCAN_INTERVAL or _refresh_outlines then
        run_heavy_scan = true
        _last_scan_time = 0
    end

    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then return end

    local outline_system = extension_manager:system("outline_system")
    local side_system = extension_manager:system("side_system")
    if not outline_system or not side_system then return end

    local player_unit = Managers.player and Managers.player:local_player(1) and Managers.player:local_player(1).player_unit
    if not player_unit then return end

    local player_side = side_system.side_by_unit[player_unit]
    if not player_side then return end

    local enemy_side_names = player_side:relation_side_names("enemy")
    if not enemy_side_names then return end

    local game_session_manager = Managers.state.game_session
    local unit_spawner = Managers.state.unit_spawner
    local game_session = nil
    if run_heavy_scan and game_session_manager and type(game_session_manager.game_session) == "function" then
        pcall(function() game_session = game_session_manager:game_session() end)
    end

    local perception_system = extension_manager:system("perception_system")
    local perception_map = nil
    if run_heavy_scan and perception_system and type(perception_system.unit_to_extension_map) == "function" then
        pcall(function() perception_map = perception_system:unit_to_extension_map() end)
    end

    local enable_human_bosses = mod:get("outline_human_bosses")
    local enable_monsters = mod:get("outline_monsters")
    local enable_disablers = mod:get("outline_disablers")
    local enable_ranged_specials = mod:get("outline_ranged_specials")
    local enable_poxbursters = mod:get("outline_poxbursters")
    local enable_ranged_elites = mod:get("outline_ranged_elites")
    local enable_melee_elites = mod:get("outline_melee_elites")
    local enable_crushers_maulers = mod:get("outline_crushers_maulers")
    local enable_shooters = mod:get("outline_shooters")
    local enable_chaff = mod:get("outline_chaff")
    local only_targeting_me = mod:get("only_targeting_me")
    local enable_aimed = mod:get("outline_aimed")
    local aimed_target = nil
    if enable_aimed and player_unit then
        local smart_targeting_extension = ScriptUnit.has_extension(player_unit, "smart_targeting_system") and ScriptUnit.extension(player_unit, "smart_targeting_system")
        if smart_targeting_extension then
            local targeting_data = smart_targeting_extension:targeting_data()
            if targeting_data and targeting_data.unit then
                aimed_target = targeting_data.unit
            end
        end
    end
    
    local refresh = _refresh_outlines
    _refresh_outlines = false

    for unit, _ in pairs(side_system.side_by_unit) do
        if HEALTH_ALIVE[unit] and Unit.alive(unit) then
            local is_enemy = _unit_is_enemy_cache[unit]
            if is_enemy == nil then
                is_enemy = false
                local unit_side = side_system.side_by_unit[unit]
                if unit_side then
                    local unit_side_name = unit_side:name()
                    for i = 1, #enemy_side_names do
                        if enemy_side_names[i] == unit_side_name then
                            is_enemy = true
                            break
                        end
                    end
                end
                _unit_is_enemy_cache[unit] = is_enemy
            end

            if is_enemy then
                local category = _unit_category_cache[unit]
                if category == nil then
                    category = _get_enemy_category(unit) or false
                    _unit_category_cache[unit] = category
                end
                
                if category then
                    local allowed_by_settings = false
                    local outline_name = nil

                    if category == "human_boss" and enable_human_bosses then
                        allowed_by_settings = true
                        outline_name = "mod_outline_human_boss"
                    elseif category == "monster" and enable_monsters then
                        allowed_by_settings = true
                        outline_name = "mod_outline_monster"
                    elseif category == "disabler" and enable_disablers then
                        allowed_by_settings = true
                        outline_name = "mod_outline_disabler"
                    elseif category == "ranged_special" and enable_ranged_specials then
                        allowed_by_settings = true
                        outline_name = "mod_outline_ranged_special"
                    elseif category == "poxburster" and enable_poxbursters then
                        allowed_by_settings = true
                        outline_name = "mod_outline_poxburster"
                    elseif category == "ranged_elite" and enable_ranged_elites then
                        allowed_by_settings = true
                        outline_name = "mod_outline_ranged_elite"
                    elseif category == "melee_elite" and enable_melee_elites then
                        allowed_by_settings = true
                        outline_name = "mod_outline_melee_elite"
                    elseif category == "crushers_maulers" and enable_crushers_maulers then
                        allowed_by_settings = true
                        outline_name = "mod_outline_crushers_maulers"
                    elseif category == "shooters" and enable_shooters then
                        allowed_by_settings = true
                        outline_name = "mod_outline_shooters"
                    elseif category == "chaff" and enable_chaff then
                        allowed_by_settings = true
                        outline_name = "mod_outline_chaff"
                    end

                    local has_extension = outline_system._unit_extension_data[unit] ~= nil
                    if has_extension then
                        if refresh then
                            if outline_system:has_outline(unit, "mod_outline_human_boss") then outline_system:remove_outline(unit, "mod_outline_human_boss") end
                            if outline_system:has_outline(unit, "mod_outline_monster") then outline_system:remove_outline(unit, "mod_outline_monster") end
                            if outline_system:has_outline(unit, "mod_outline_disabler") then outline_system:remove_outline(unit, "mod_outline_disabler") end
                            if outline_system:has_outline(unit, "mod_outline_ranged_special") then outline_system:remove_outline(unit, "mod_outline_ranged_special") end
                            if outline_system:has_outline(unit, "mod_outline_poxburster") then outline_system:remove_outline(unit, "mod_outline_poxburster") end
                            if outline_system:has_outline(unit, "mod_outline_ranged_elite") then outline_system:remove_outline(unit, "mod_outline_ranged_elite") end
                            if outline_system:has_outline(unit, "mod_outline_melee_elite") then outline_system:remove_outline(unit, "mod_outline_melee_elite") end
                            if outline_system:has_outline(unit, "mod_outline_crushers_maulers") then outline_system:remove_outline(unit, "mod_outline_crushers_maulers") end
                            if outline_system:has_outline(unit, "mod_outline_shooters") then outline_system:remove_outline(unit, "mod_outline_shooters") end
                            if outline_system:has_outline(unit, "mod_outline_chaff") then outline_system:remove_outline(unit, "mod_outline_chaff") end
                            if outline_system:has_outline(unit, "mod_outline_aimed") then outline_system:remove_outline(unit, "mod_outline_aimed") end
                        end

                        if run_heavy_scan then
                            local should_outline = false
                            if allowed_by_settings then
                                local passes_los = _check_line_of_sight(player_unit, unit)

                                if passes_los then
                                    if only_targeting_me then
                                        local target_unit = nil
                                        if game_session and unit_spawner then
                                            target_unit = _resolve_target_from_game_object(unit, game_session, unit_spawner)
                                        end
                                        if not target_unit then
                                            target_unit = _resolve_target_from_perception(unit, perception_map)
                                        end

                                        if target_unit == player_unit then
                                            should_outline = true
                                        end
                                    else
                                        should_outline = true
                                    end
                                end
                            end

                            if should_outline then
                                if not outline_system:has_outline(unit, outline_name) then
                                    outline_system:add_outline(unit, outline_name)
                                end
                            else
                                if outline_system:has_outline(unit, outline_name) then
                                    outline_system:remove_outline(unit, outline_name)
                                end
                            end
                        end
                        
                        if enable_aimed then
                            if unit == aimed_target then
                                if not outline_system:has_outline(unit, "mod_outline_aimed") then
                                    outline_system:add_outline(unit, "mod_outline_aimed")
                                end
                            else
                                if outline_system:has_outline(unit, "mod_outline_aimed") then
                                    outline_system:remove_outline(unit, "mod_outline_aimed")
                                end
                            end
                        else
                            if outline_system:has_outline(unit, "mod_outline_aimed") then
                                outline_system:remove_outline(unit, "mod_outline_aimed")
                            end
                        end
                    end
                else
                    local has_extension = outline_system._unit_extension_data[unit] ~= nil
                    if has_extension then
                        if refresh and outline_system:has_outline(unit, "mod_outline_aimed") then
                            outline_system:remove_outline(unit, "mod_outline_aimed")
                        end

                        if enable_aimed then
                            if unit == aimed_target then
                                if not outline_system:has_outline(unit, "mod_outline_aimed") then
                                    outline_system:add_outline(unit, "mod_outline_aimed")
                                end
                            else
                                if outline_system:has_outline(unit, "mod_outline_aimed") then
                                    outline_system:remove_outline(unit, "mod_outline_aimed")
                                end
                            end
                        else
                            if outline_system:has_outline(unit, "mod_outline_aimed") then
                                outline_system:remove_outline(unit, "mod_outline_aimed")
                            end
                        end
                    end
                end
            end
        end
    end
end
