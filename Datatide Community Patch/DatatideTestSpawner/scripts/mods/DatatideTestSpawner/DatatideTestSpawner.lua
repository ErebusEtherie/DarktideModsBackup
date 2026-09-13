local mod = get_mod("DatatideTestSpawner")

local ItemUtils = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local ArchetypeTalents = require("scripts/settings/ability/archetype_talents/archetype_talents")

local local_player_unit = local_player_unit
local Camera = Camera
local Managers = Managers
local PlayerMovement = require("scripts/utilities/player_movement")
local FixedFrame = require("scripts/utilities/fixed_frame")

mod.buff_indices = mod:persistent_table("original_player_abilities", {})
local buff_index = buff_index

local test_selection_index = 1
local test_selection = test_selection
local current_test = current_test
local selected_test_mission = " "
local selected_test_mission_name = " "
local test_name = " "

local test_state = "inactive"
local test_ready_to_save = false
local overwrite_test_data = false
local weapon_notification = false
local step_index = 1

local kill_counter = 0
local kills_needed = 0
local melee_damage = 0
local ranged_damage = 0
local grenade_damage = 0
local combat_ability_used = false
local wielded_slot = ""
local player_starting_hp = player_starting_hp

local time_start_test = 0
local time_end_test = 0
local time_delta_test = 0

local scoreboard = nil
local Breed = nil

local function get_scoreboard()
    if not scoreboard then
        scoreboard = get_mod("scoreboard")
    end
    return scoreboard
end

local function get_breed_util()
    if not Breed then
        scoreboard = get_scoreboard()
        if scoreboard then
            Breed = scoreboard:original_require("scripts/utilities/breed")
        end
    end
    return Breed
end

local contains = function(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true  -- Found the value, return true
        end
    end
    return false  -- Value not found
end

local get_index_of_value = function(table, value)
    for index, v in ipairs(table) do
        if v == value then
            return index  -- Return the index when the value is found
        end
    end
end

local get_player = function()
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player(1)
  
    return player
end
  
local get_player_unit = function(player)
    player = player or get_player()
    local player_unit = player and player:unit_is_alive() and player.player_unit
  
    return player_unit
end

local player_from_unit = function(unit)
	if not unit then
		return nil
	end
	local spawn_manager = Managers.state and Managers.state.player_unit_spawn
	if spawn_manager then
		return spawn_manager:owner(unit)
	end
	local players = Managers.player and Managers.player:players()
	if players then
		for _, player in pairs(players) do
			if player.player_unit == unit then
				return player
			end
		end
	end
	return nil
end

local reset_update_func = function()
    mod.update = function()
    end
end

local cleanup_ragdolls = function(self)
    local ragdoll_handler = Managers.state and Managers.state.minion_death
    if not ragdoll_handler then
        mod:error("No ragdoll handler found.")
        return
    end
    if ragdoll_handler then
        ragdoll_handler:delete_units()
    end
end

local despawn_units = function(self)
    local minion_spawner = Managers.state and Managers.state.minion_spawn
    if not minion_spawner then
        mod:error("No minion spawner found.")
        return
    end
    if minion_spawner then
        minion_spawner:delete_units()
    end
end

local check_mission = function(self)
    current_mission = Managers.state.mission:mission_name()
    selected_test_mission = mod.Test_Data[test_selection].test_data["test_map"]
    selected_test_mission_name = mod.Test_Data[test_selection].test_data["map_name"]

    if current_mission == selected_test_mission then
        return true
    else
        return false
    end
end

local is_valid_game_mode = function()
    local soloplay = get_mod("SoloPlay")
    local game_mode_name = game_mode_name
    if soloplay then
        if soloplay:is_soloplay() then
            game_mode_name = "solo"
        else
            game_mode_name = Managers.state and Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
        end
    else
        game_mode_name = Managers.state and Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    end

    return game_mode_name == "solo" or game_mode_name == "shooting_range" 
end

local is_server = function()
    return Managers.state and Managers.state.game_session and Managers.state.game_session:is_server()
end

local reset_test_parameters = function()
    test_state = "setup"
    current_test = test_selection
    time_start_test = 0
    time_end_test = 0
    kill_counter = 0
    kills_needed = mod.Test_Data[test_selection].test_data["kills_needed"]
    melee_damage = 0
    ranged_damage = 0
    grenade_damage = 0
    weapon_notification = false
end

local clear_results_table = function(self)
    mod.Test_Results["weapon_name"] = ""
	mod.Test_Results["test_time"] = 0
	mod.Test_Results["enemy_type"] = ""
	mod.Test_Results["class"] = ""
    mod.Test_Results["key_talents"] = ""
	mod.Test_Results["blessing_1"] = ""
	mod.Test_Results["blessing_2"] = ""
	mod.Test_Results["perk_1"] = ""
	mod.Test_Results["perk_2"] = ""
	mod.Test_Results["test_notes"] = ""
	mod.Test_Results["attack_combo"] = ""
	mod.Test_Results["damage_taken"] = 0
	mod.Test_Results["combat_ability_used"] = false
	mod.Test_Results["buffs_applied"] = false
	mod.Test_Results["difficulty"] = ""
	mod.Test_Results["build_name"] = ""	
end

local shorten_weapon_name = function(weapon_name)
    local removed_words = mod.weapon_name_removed_strings

    for key, value in pairs(removed_words) do
        weapon_name = weapon_name:gsub(key, value)
    end

    weapon_name = weapon_name:gsub("%s+", " ")
    weapon_name = weapon_name:gsub("^%s*(.-)%s*$", "%1")

    return weapon_name
end

local get_loadout_data = function(self)
    -- Check if user name and patch are updated, if not try to update again
    -- if mod.Test_Results["user"] == "" then
    local user_name = Managers.account:user_display_name()
    if user_name then
        user_name = user_name:gsub('"', '')
        mod.Test_Results["user"] = user_name
    else
        mod.Test_Results["user"] = ""
    end
    -- end

    if mod.Test_Results["patch"] == "" then
        local patch_number = mod:get("patch")
        if patch_number then
            mod.Test_Results["patch"] = patch_number
        else
            mod.Test_Results["patch"] = ""
        end
    end
    --------------------------------------------------------------------------
    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player)
    local profile = local_player._profile
    local archetype = profile.archetype    

    -- Talents
    local talent_build_str = ""
    local player_build = ""    
    local classes = {Zealot = "zealot", Veteran = "veteran", Psyker = "psyker", Ogryn = "ogryn"}   
	local class_name = class_name

    if Localize(archetype.archetype_name) then
        class_name = Localize(archetype.archetype_name)
    end

    local talent_names = {}
    local modifier_names = {}
    local combat_talent = {}
    local keystone_talent = {}

    local archetype_talents = ArchetypeTalents[classes[class_name]] 
    if archetype_talents then
        local talents = profile.talents
        local combat_abilities = mod.Talents_Combat_Abilitys
        local keystones = mod.Talents_Keystones
        local player_combat_ability = ""
        local player_keystone = ""

        local combat_abilities_list = mod.Talents_Combat_Abilitys
        local keystone_abilities_list = mod.Talents_Keystones

        local is_combat_ability = function(talent)
            local combat_ability = false
            for ability, _ in pairs(combat_abilities_list) do
                if ability == talent then
                    combat_ability = true
                end
            end
            return combat_ability
        end
        local is_keystone = function(talent)
            local keystone_ability = false
            for ability, _ in pairs(keystone_abilities_list) do
                if ability == talent then
                    keystone_ability = true
                end
            end
            return keystone_ability
        end

        for name, _ in pairs(talents) do
            local talent_data = archetype_talents[tostring(name)]
            local display_name = talent_data["display_name"]
            local talent_name = talent_name

            talent_name = Localize(display_name)
            if string.match(talent_name,"unlocalized") then
                talent_name = display_name
            end
            
            if string.match(talent_name, "Boost") or string.match(talent_name, "Damage Reduction") then 
                table.insert(modifier_names, talent_name)
            elseif is_combat_ability(talent_name) then
                table.insert(combat_talent, talent_name)
            elseif is_keystone(talent_name) then
                table.insert(keystone_talent, talent_name)
            else
                table.insert(talent_names, talent_name)
            end
        end
        -- shortening and sorting weird stuff
        if #combat_talent > 1 then
            if contains(combat_talent, "Loyal Protector") then
                local removed_index = get_index_of_value(combat_talent, "Loyal Protector")
                table.remove(combat_talent, removed_index)
            end

            while #combat_talent > 1 do
                table.remove(combat_talent, 2)
            end
        end

        for ability, shorthand in pairs(combat_abilities) do
            if combat_talent[1] == ability then
                player_combat_ability = shorthand
            end
        end
        
        for keystone, shorthand in pairs(keystones) do
            if keystone_talent[1] == keystone then
                player_keystone = shorthand
            end
        end
        -- format talent values
        player_build = string.format("%s%s%s", player_combat_ability, (player_combat_ability ~= "" and player_keystone ~= "" and ", " or ""), player_keystone)
        table.sort(talent_names)
        table.sort(modifier_names)

        for i = 1, #modifier_names do
            table.insert(talent_names, modifier_names[i])
        end

        for i = 1, #keystone_talent do
            table.insert(talent_names, 1, keystone_talent[i])
        end
        for i = 1, #combat_talent do
            table.insert(talent_names, 1, combat_talent[i])
        end        
        
        for i = 1, #talent_names do
            if i < #talent_names then
                talent_build_str = talent_build_str .. talent_names[i] .. ", "
            elseif i == #talent_names then
                talent_build_str = talent_build_str .. talent_names[i]
            end
        end
    else 
        talent_build_str = ""
        player_build = ""
        mod:error("Player talents not found")
    end
    -- Weapon
    local weapon_name = weapon_name
    local blessing_names = {"", ""}
    local perk_names = {"", ""}

    local unit_data_extension = ScriptUnit.has_extension(local_player_unit, "unit_data_system")
    if unit_data_extension then
        local inventory_component = unit_data_extension:read_component("inventory")
        wielded_slot = inventory_component.wielded_slot

        if wielded_slot == "slot_grenade_ability" then
            local grenade_table = mod.Talents_Grenades
            local player_blitz_talent = ""
            local grenade_type = "base_talent" 

            for i = 1, #talent_names do
                for grenade, talent_type in pairs(grenade_table) do
                    if talent_names[i] == grenade and grenade_type == "base_talent" then
                        player_blitz_talent = grenade
                        grenade_type = talent_type
                    end
                end              
            end
            weapon_name = player_blitz_talent
        else
            local weapon = profile.loadout[wielded_slot]

            local weapon_full_name = ""
            if ItemUtils.display_name(weapon) then
                weapon_full_name = ItemUtils.display_name(weapon)
            end
            weapon_name = shorten_weapon_name(weapon_full_name)

            local blessings = weapon["traits"]
            local perks = weapon["perks"]
            
            if blessings then
                for i = 1, 2 do
                    if blessings[i] then
                        local id = blessings[i].id
                        local MasterItem = MasterItems.get_item(id)
                        blessing_names[i] = ItemUtils.display_name(MasterItem)
                    end
                end
                table.sort(blessing_names)
            end

            if perks then
                for i = 1, 2 do
                    if perks[i] then
                        local id = perks[i].id
                        local MasterItem = MasterItems.get_item(id)
                        local perk = mod:localize(string.format("trait_%s",MasterItem.trait))
                        if string.find(perk,"<") then perk = "????" end
                        perk_names[i] = perk
                    end
                end
                table.sort(perk_names)
            end
        end
    else
        weapon_name = ""
        blessing_names = {"", ""}
        perk_names = {"", ""}
        wielded_slot = "slot_primary"
        mod:error("Wielded weapon not found")
    end

    --Difficulty
    local difficulty = ""
    if Managers.state and Managers.state.difficulty then
        if type(Managers.state.difficulty.get_challenge) == "function" then
            local threat_level = Managers.state.difficulty:get_challenge()
            local havoc_data = Managers.state.difficulty:get_parsed_havoc_data()
            local havoc_level = 0
            local difficulty_names = {"Sedition", "Uprising", "Malice", "Heresy", "Damnation"}
            if havoc_data then
                havoc_level = havoc_data.havoc_rank
                difficulty = "H" .. havoc_level
            else
                difficulty = difficulty_names[threat_level]
            end
        else
            mod:error("get_difficulty method not found in difficulty manager")
        end
    else
        mod:error("Difficulty manager not found")
    end
    --Set Results
    mod.Test_Results["weapon_name"] = weapon_name
    mod.Test_Results["blessing_1"] = blessing_names[1]
    mod.Test_Results["blessing_2"] = blessing_names[2]
    mod.Test_Results["perk_1"] = perk_names[1]
    mod.Test_Results["perk_2"] = perk_names[2]
    mod.Test_Results["class"] = class_name
    mod.Test_Results["difficulty"] = difficulty
    mod.Test_Results["build_name"] = talent_build_str
    mod.Test_Results["key_talents"] = player_build

end

local until_death_active = function(self)
    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player) 

    local buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")
    local buffs = buff_extension:buffs(local_player_unit)

    for i = 1, #buffs do
        if buffs[i]:template_name() == "zealot_resist_death" or buffs[i]:template_name() == "zealot_resist_death_improved_with_leech" then 
            local until_death = buffs[i]
            local t = FixedFrame.get_latest_fixed_time()
            local is_active = until_death:_can_activate(t) or until_death:is_proc_active()
            return is_active          
        end
    end

end

local player_hp_lost = function(self)
    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player) 
    local health_extension = ScriptUnit.has_extension(local_player_unit, "health_system")



    if player_starting_hp then
        local current_hp = health_extension:current_health()
        -- Accounting for resist death being active
        if current_hp < 2 then
            current_hp = 0
        end
        local delta_hp = math.floor(player_starting_hp - current_hp)
        return math.max(0, delta_hp)
    else
        local damage_taken = health_extension:damage_taken()
        return math.floor(damage_taken + 0.5)
    end
end

local test_weapon_damage = function(self)
    -- mod:notify("Melee Damage: " .. melee_damage .. "\nRanged Damage: " .. ranged_damage .. "\nGrenade Damage: " .. grenade_damage)
    local equipped_weapon = 0
    local non_equipped_weapon = 0
    local total_damage = 0
    local damage_percent = 0

    if wielded_slot == "slot_primary" then
        equipped_weapon = melee_damage
    elseif wielded_slot == "slot_secondary" then
        equipped_weapon = ranged_damage
    elseif wielded_slot == "slot_grenade_ability" then
        equipped_weapon = grenade_damage
    end

    total_damage = melee_damage + ranged_damage + grenade_damage
    
    if total_damage > 0 then
        damage_percent = math.floor(equipped_weapon/total_damage * 100 + 0.5)/100        
    else
        damage_percentage = 0
    end
    return damage_percent
end

---------- KEYBIND FUNCTIONS ----------

mod.Spawn_Test = function(self)
    -- Conditions
    if Managers.ui:chat_using_input() then
        return
    end

    if #mod.Test_Names == 0 then
        if Managers.event then
            Managers.event:trigger("event_clear_notifications")
        end
        mod:notify("No tests available, check\ntest maps using chat command\n/dttests")
        return
    end

    if not check_mission() then
        mod:echo("Current mission is incorrect, launch " .. selected_test_mission_name .. " using the 'Solo Play' mod")
        return
    end

    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player)

    if local_player_unit and is_valid_game_mode() and is_server() then
        -- Function
        local minion_spawner = Managers.state and Managers.state.minion_spawn
        if not minion_spawner then
            mod:error("No minion spawner found.")
            return
        end

        local testing_utilities = get_mod("testing_utilities")
        local enemy_breeds = mod.Test_Data[test_selection].enemy_breeds
        test_name = mod.Test_Data[test_selection].test_data["test_name"]

        local player_invisible = mod.Test_Data[test_selection].test_data["player_invisible"]
        local player_XYZ = mod.Test_Data[test_selection].test_data["player_XYZ"]
        local enemy_XYZ = mod.Test_Data[test_selection].enemy_XYZ
        local player_position = Vector3(player_XYZ.x, player_XYZ.y, player_XYZ.z)
        local player_rotation = Quaternion.axis_angle(Vector3(0,0,1), math.rad(player_XYZ.rot))  
        
        -- Reset Test if player changes test inbetween steps
        if test_selection ~= current_test then
            step_index = 1
        end

        if step_index == 1 then
            mod:enable_all_hooks()
            reset_test_parameters()

            -- Teleport Player to Start Location and Set Invis.
            -- local player = Managers.state.player_unit_spawn:owner(local_player_unit)
            -- local pitch = Quaternion.pitch(player_rotation)
            -- local yaw = Quaternion.yaw(player_rotation)
            -- player:set_orientation(yaw, pitch, 0)
            
            PlayerMovement.teleport(local_player, player_position, player_rotation)
            
            mod:set_invisibility()           

            -- Short Delay to avoid crash if despawning enemies in the same frame as killing an enemy
            local delay_counter = 0
            local delay_time = 0.1
            mod.update = function(dt)
                delay_counter = delay_counter + 1*dt
                if delay_counter > delay_time then

                    despawn_units()
                    if mod:get("toggle_cleanup_ragdolls") then
                        cleanup_ragdolls() 
                    end

                    -- Spawn Enemies
                    local total_enemies = 0                    
                    for i = 1, #enemy_XYZ do            
                        local position = Vector3(enemy_XYZ[i].x, enemy_XYZ[i].y, enemy_XYZ[i].z)
                        local rotation = Quaternion.axis_angle(Vector3(0,0,1), math.rad(enemy_XYZ[i].rot))
                        local breed = enemy_breeds[i]
                        local side_id = 2

                        local unit = minion_spawner:spawn_minion(breed, position, rotation, side_id)
                        total_enemies = total_enemies + 1

                        if breed == "renegade_twin_captain_two" or breen == "renegade_twin_captain" then
                            local spawned_unit_toughness_extension = ScriptUnit.extension(unit, "toughness_system")
                            spawned_unit_toughness_extension:set_toughness_damage(0, true)
                        end
                    end

                    mod:echo(test_name .. " test ready, press keybind again to begin")
                    if Managers.event then
                        Managers.event:trigger("event_clear_notifications")
                    end
                    mod:notify("Total Enemies: " .. total_enemies .. "\nKills Needed: " .. kills_needed)
                    step_index = 2

                    reset_update_func()
                end
            end
            return

        elseif step_index == 2 then
            overwrite_test_data = false
            clear_results_table()            
            get_loadout_data()
            local weapon_name = mod.Test_Results["weapon_name"]
            if not weapon_notification then
               mod:notify("Weapon: " .. weapon_name)
               weapon_notification = true
            end
            if mod:get("toggle_reset_scoreboard") then
                local scoreboard = get_scoreboard()
                scoreboard:clear()
            end

            -- check if player is visible during active test
            if player_invisible == false then
                -- Short delay inbetween player pressing keybind for player ready
                local delay_counter = 0
                local delay_time = 1
                local timer_echo_3 = true
                local timer_echo_2 = true
                local timer_echo_1 = true

                mod.update = function(dt)
                    delay_counter = delay_counter + 1*dt

                    if timer_echo_3 == true and delay_counter > delay_time/4 then
                        mod:echo("3...")
                        timer_echo_3 = false
                    elseif timer_echo_2 == true and delay_counter > delay_time*2/4 then
                        mod:echo("2...")
                        timer_echo_2 = false
                    elseif timer_echo_1 == true and delay_counter > delay_time*3/4 then
                        mod:echo("1...")
                        timer_echo_1 = false
                    end

                    if delay_counter > delay_time then
                        mod:set_resist_death()
                        mod:remove_invisibility()                    
                        if testing_utilities then
                            testing_utilities:Reset_Character()
                        end
                        -- Get Player Starting HP after reset
                        local health_extension = ScriptUnit.has_extension(local_player_unit, "health_system")
                        player_starting_hp = health_extension:current_health()
                        -- Get start time, set again on first hit of test                        
                        time_start_test = FixedFrame.get_latest_fixed_time()

                        mod:echo("Starting \"" .. test_name .. "\" test")
                        step_index = 3
                        reset_update_func()
                    end
                end
            elseif player_invisible == true then
                mod:set_resist_death()
                if testing_utilities then
                    testing_utilities:Reset_Character()
                end
                -- Get Player Starting HP after reset
                local health_extension = ScriptUnit.has_extension(local_player_unit, "health_system")
                player_starting_hp = health_extension:current_health()
                -- Get start time, set again on first hit of test
                time_start_test = FixedFrame.get_latest_fixed_time()

                mod:echo("Starting " .. test_name .. " test")
                step_index = 3
            end
            test_ready_to_save = false
            return

        elseif step_index == 3 then
            mod:remove_invisibility()
            if kill_counter < kills_needed then
                test_state = "fail"
            end

            -- Get Time, time_delta_test is rounded to the nearest 0.01 place
            time_end_test = FixedFrame.get_latest_fixed_time()                            
            time_delta_test = math.floor((time_end_test - time_start_test)*100 + 0.5)/100
            local time_bad_test = time_delta_test or 0
            if  test_state == "fail" then
                time_delta_test = "\"" .. "Fail: " .. time_delta_test .. "s | " .. kill_counter .. " kills" .. "\""
            end
            mod.Test_Results["test_time"] = time_delta_test
            mod.Test_Results["enemy_type"] = test_name
            mod.Test_Results["damage_taken"] = player_hp_lost()
            mod.Test_Results["test_weapon_damage"] = test_weapon_damage()

            if testing_utilities then
                mod.Test_Results["buffs_applied"] = testing_utilities.dt_buff_applied
                mod.Buff_Notes = testing_utilities.dt_buff_stacks
            else
                mod.Test_Results["buffs_applied"] = false
                mod.Buff_Notes = ""
            end

            local save_keybind = mod:get("keybind_spawn_test")
            if test_state == "fail" then
                if time_bad_test < 3 and mod:get("toggle_bad") == true then
                    if Managers.event then
                        Managers.event:trigger("event_clear_notifications")
                    end
                    mod:notify("bad")
                end                  
                mod:echo("Test Time: " .. time_delta_test)
                mod:echo("Ending " .. "\"" .. test_name .. "\"" .. " test")
            else              
                mod:echo("Test Time: " .. time_delta_test .. " seconds")
                mod:echo("Ending " ..  "\"" .. test_name .. "\"" .. " test")
            end

            -- Despawn Units, delay needed to avoid crash if last enemy is killed in the same frame.
            local delay_counter = 0
            local delay_time = 0.25
            mod.update = function(dt)
                delay_counter = delay_counter + 1*dt
                if delay_counter > delay_time then
                    despawn_units()
                    reset_update_func()
                end
            end

            -- Reset Test Variables
            kill_counter = 0 
            step_index = 1
            test_ready_to_save = true
            mod:disable_all_hooks()
            mod:hook_enable("PacingManager", "update")
            mod:remove_resist_death()
            mod:Autosave_Test_Result()
        else
            step_index = 1
        end
    end
end

mod.Save_Test_Result = function(self)
    if Managers.ui:chat_using_input() then
        return
    end

    if test_ready_to_save == false then
        mod:notify("No test data")
        return 
    end

    local results = mod.Test_Results

    local weapon_name = "\"" .. results["weapon_name"] .. "\""
    local test_time = results["test_time"]
	local enemy_type = "\"" .. results["enemy_type"] .. "\""
	local class = "\"" .. results["class"] .. "\""
    local build = "\"" .. results["key_talents"] .. "\""
	local blessing_1 = "\"" .. results["blessing_1"] .. "\""
	local blessing_2 = "\"" .. results["blessing_2"] .. "\""
	local perk_1 = "\"" .. results["perk_1"] .. "\""
	local perk_2 = "\"" .. results["perk_2"] .. "\""
    local test_notes = ""
    if mod.Buff_Notes == "" then
        test_notes = "\"" .. results["test_notes"] .. "\""
    elseif results["test_notes"] == "" then
	    test_notes = "\"" .. mod.Buff_Notes .. "\""
    else
       test_notes = "\"" .. results["test_notes"] .. " | " .. mod.Buff_Notes .. "\""
    end
	local attack_combo = "\"" .. results["attack_combo"] .. "\""
    local hp_lost = results["damage_taken"]
    local test_weapon_damage = results["test_weapon_damage"]
    local combat_ability_used = tostring(results["combat_ability_used"])
    local buffs_applied = tostring(results["buffs_applied"])
	local difficulty = "\"" .. results["difficulty"] .. "\""
	local build_name = "\"" .. results["build_name"] .. "\""
    local user = "\"" .. results["user"] .. "\""
    local patch =  results["patch"]


    local sheets_array = 
    weapon_name .. "\t" ..
    test_time .. "\t" ..
    enemy_type .. "\t" ..
    class .. "\t" ..
    build .. "\t" ..
    blessing_1 .. "\t" ..
    blessing_2 .. "\t" ..
    perk_1 .. "\t" ..
    perk_2 .. "\t" ..
    test_notes .. "\t" ..
    attack_combo .. "\t" ..
    hp_lost .. "\t" ..
    test_weapon_damage .. "\t" ..
    combat_ability_used .. "\t" ..
    buffs_applied .. "\t" ..
    difficulty .. "\t" ..
    build_name .. "\t" ..
    user .. "\t" ..
    patch 
    

    local current_date = os.date("%Y-%m-%d")
    local DMF = get_mod("DMF")
    local io = DMF:persistent_table("_io")
    io.initialized = io.initialized or false   
    if not io.initialized then
        io = DMF.deepcopy(Mods.lua.io)
    end
    local file = io.open("../mods/DatatideTestSpawner/test_data/test_results " .. current_date .. ".txt", "a+")
    if not file then
        mod:error("Could not open file for reading!")
        return
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()

    if overwrite_test_data == true then

        -- Replace last line with new data
        table.remove(lines)
        table.insert(lines, sheets_array)
    
        -- Open the file in write mode to overwrite the content
        file = io.open("../mods/DatatideTestSpawner/test_data/test_results " .. current_date .. ".txt", "w")
        if not file then
            mod:error("Could not open file for writing!")
            return
        end
    
        for i = 1, #lines do
            if i == 1 then
                file:write(lines[i])
            else
                file:write("\n" .. lines[i])
            end
        end

        file:close()
        mod:echo("Last test result overwritten in: " .. "DatatideTestSpawner/test_data/test_results " .. current_date .. ".txt" .. "\nSaving before next test will overwrite data")
    else
        file = io.open("../mods/DatatideTestSpawner/test_data/test_results " .. current_date .. ".txt", "a")
        if not file then
            mod:error("Could not open file!")
            return
        end

        if #lines == 0 then
            file:write(sheets_array)
            file:close()
        else
            file:write("\n" .. sheets_array)
            file:close()
        end
        mod:echo("Test result saved to: " .. "DatatideTestSpawner/test_data/test_results " .. current_date .. ".txt" .. "\nSaving before next test will overwrite data")
    end
    overwrite_test_data = true
end

mod.Autosave_Test_Result = function(self)

    -- Pass if player failed test
    if test_state == "fail" then
        return 
    end

    -- Pass if player manually saved test
    if overwrite_test_data == true then
        return
    end

    local current_date = os.date("%Y-%m-%d")
    local current_time = os.date("%H:%M:%S")
    local results = mod.Test_Results

    local weapon_name = "\"" .. results["weapon_name"] .. "\""
    local test_time = results["test_time"]
	local enemy_type = "\"" .. results["enemy_type"] .. "\""
	local class = "\"" .. results["class"] .. "\""
    local build = "\"" .. results["key_talents"] .. "\""
	local blessing_1 = "\"" .. results["blessing_1"] .. "\""
	local blessing_2 = "\"" .. results["blessing_2"] .. "\""
	local perk_1 = "\"" .. results["perk_1"] .. "\""
	local perk_2 = "\"" .. results["perk_2"] .. "\""
    local test_notes = ""
    if mod.Buff_Notes == "" then
        test_notes = "\"" .. results["test_notes"] .. " | " .. current_date .. " " .. current_time .. "\""
    elseif results["test_notes"] == "" then
	    test_notes = "\"" .. mod.Buff_Notes .. " | " .. current_date .. " " .. current_time .. "\""
    else
       test_notes = "\"" .. results["test_notes"] .. " | " .. mod.Buff_Notes .. " | " .. current_date .. " " .. current_time .. "\""
    end
	local attack_combo = "\"" .. results["attack_combo"] .. "\""
    local hp_lost = results["damage_taken"]
    local test_weapon_damage = results["test_weapon_damage"]
    local combat_ability_used = tostring(results["combat_ability_used"])
    local buffs_applied = tostring(results["buffs_applied"])
	local difficulty = "\"" .. results["difficulty"] .. "\""
	local build_name = "\"" .. results["build_name"] .. "\""
    local user = "\"" .. results["user"] .. "\""
    local patch =  results["patch"]


    local sheets_array = 
    weapon_name .. "\t" ..
    test_time .. "\t" ..
    enemy_type .. "\t" ..
    class .. "\t" ..
    build .. "\t" ..
    blessing_1 .. "\t" ..
    blessing_2 .. "\t" ..
    perk_1 .. "\t" ..
    perk_2 .. "\t" ..
    test_notes .. "\t" ..
    attack_combo .. "\t" ..
    hp_lost .. "\t" ..
    test_weapon_damage .. "\t" ..
    combat_ability_used .. "\t" ..
    buffs_applied .. "\t" ..
    difficulty .. "\t" ..
    build_name .. "\t" ..
    user .. "\t" ..
    patch 

    local max_autosaves = mod:get("autosave_slider")
    local DMF = get_mod("DMF")
    local io = DMF:persistent_table("_io")
    io.initialized = io.initialized or false   
    if not io.initialized then
        io = DMF.deepcopy(Mods.lua.io)
    end

    local file = io.open("../mods/DatatideTestSpawner/test_data/autosave_test_data.txt", "a+")
    if not file then
        mod:error("Could not open file for reading!")
        return
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()

    if #lines >=  max_autosaves then
        -- Remove oldest lines until not over autosave limit, add new data if max saves > 0
        while #lines > max_autosaves do
            table.remove(lines, 1)
        end

        table.remove(lines, 1)

        if max_autosaves > 0 then
            table.insert(lines, sheets_array)
        end
    
        -- Open the file in write mode to overwrite the content
        file = io.open("../mods/DatatideTestSpawner/test_data/autosave_test_data.txt", "w")
        if not file then
            mod:error("Could not open file for reading!")
            return
        end
    
        for i = 1, #lines do
            if i == 1 then
                file:write(lines[i])
            else
                file:write("\n" .. lines[i])
            end
        end

        file:close()
    else
        file = io.open("../mods/DatatideTestSpawner/test_data/autosave_test_data.txt", "a")
        if not file then
            mod:error("Could not open file!")
            return
        end

        if #lines == 0 then
            file:write(sheets_array)
            file:close()
        else       
            file:write("\n" .. sheets_array)
            file:close()
        end
    end
end

mod.Set_Test_Group = function(self)
    local game_state = Managers.presence and Managers.presence._current_game_state_name
    local selected_group = mod:get("test_group_dropdown")
    
    if game_state == "StateGameplay" then
        local current_mission = Managers.state.mission:mission_name() 
        local test_data = mod.Test_Data
        local previous_test_names = mod.Test_Names
        mod.Test_Names = {}

        if selected_group == "any" then
            for test, data in pairs(test_data) do
                if data["test_data"].test_map == current_mission then
                    table.insert(mod.Test_Names, test)
                end
            end
        else
            for test, data in pairs(test_data) do
                local test_map = data["test_data"].test_map
                local test_group = data["test_data"].group
                if test_map == current_mission and contains(test_group, selected_group) then
                    table.insert(mod.Test_Names, test)
                end
            end
        end
        table.sort(mod.Test_Names)

        if mod.Test_Names ~= previous_test_names then
            test_selection_index = 1
            test_selection = mod.Test_Names[test_selection_index]
        end
    else
        mod.Test_Names = {}
    end
end

mod.Next_Test_Selection = function(self)

    if Managers.ui:chat_using_input() then
        return
    end

    if #mod.Test_Names > 0 then
        local test_group = mod:get("test_group_dropdown")
        local max_index = #mod.Test_Names
        if test_selection_index < max_index then
            test_selection_index = test_selection_index + 1
        else
            test_selection_index = 1
        end
        test_selection = mod.Test_Names[test_selection_index]
        test_name = mod.Test_Data[test_selection].test_data["test_name"]
        selected_test_mission_name = mod.Test_Data[test_selection].test_data["map_name"]

        if Managers.event then
            Managers.event:trigger("event_clear_notifications")
        end
        mod:notify("Test Selection:\n" ..  test_name .. "\n\nTest Group:\n" .. mod:localize(test_group))
        -- mod:echo("\nTest Selection: " .. "\"" ..  test_name .. "\"\nTest Group: " .. mod:localize(test_group))
    else
        if Managers.event then
            Managers.event:trigger("event_clear_notifications")
        end
        mod:notify("No tests available,\nuse command /dttests")
    end
end

mod.Previous_Test_Selection = function(self)

    if Managers.ui:chat_using_input() then
        return
    end

    if #mod.Test_Names > 0 then
        local test_group = mod:get("test_group_dropdown")
        local max_index = #mod.Test_Names
        if test_selection_index > 1 then
            test_selection_index = test_selection_index - 1
        else
            test_selection_index = max_index
        end
        test_selection = mod.Test_Names[test_selection_index]
        test_name = mod.Test_Data[test_selection].test_data["test_name"]
        selected_test_mission_name = mod.Test_Data[test_selection].test_data["map_name"]

        if Managers.event then
            Managers.event:trigger("event_clear_notifications")
        end
        mod:notify("Test Selection:\n" ..  test_name .. "\n\nTest Group:\n" .. mod:localize(test_group))
        -- mod:echo("\nTest Selection: " .. "\"" ..  test_name .. "\"\nTest Group: " .. mod:localize(test_group))
    else
        if Managers.event then
            Managers.event:trigger("event_clear_notifications")
        end
        mod:notify("No tests available,\nuse command /dttests")
    end
end

---------- BUFFS ----------

mod.set_invisibility = function(self)
    local local_player = get_player()
    if not local_player then
        mod:echo("Local player not found")
        return
    end
    local_player_unit = get_player_unit(local_player)
	local player_buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")

	if not player_buff_extension then
		return
	end

	local buff_name = "datatide_invisibility"

    buff_index = player_buff_extension:_add_buff({
        name = buff_name,
        class_name = "buff",
        keywords = { "unperceivable" },
    }, Managers.time:time("main"))

    mod.buff_indices[#mod.buff_indices + 1] = buff_index
end

mod.remove_invisibility = function(self)
    local local_player = get_player()
    if not local_player then
        mod:echo("Local player not found")
        return
    end
    local_player_unit = get_player_unit(local_player)
	local player_buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")

    if not player_buff_extension then
		return
	end

	local buff_name = "datatide_invisibility"
    local player_buffs = player_buff_extension._buffs_by_index
    
    for i, buff_index in ipairs(mod.buff_indices) do
        local buff = player_buff_extension._buffs_by_index[buff_index]

        if buff and buff:template_name() == buff_name then
            player_buff_extension:_remove_buff(buff_index)
        end

        mod.buff_indices[i] = nil
    end
end

mod.set_resist_death = function(self)
    local local_player = get_player()
    if not local_player then
        mod:echo("Local player not found")
        return
    end
    local_player_unit = get_player_unit(local_player)
	local player_buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")

	if not player_buff_extension then
		return
	end

	local buff_name = "datatide_resist_death"

    buff_index = player_buff_extension:_add_buff({
        name = buff_name,
        class_name = "buff",
        keywords = { "resist_death" },
    }, Managers.time:time("main"))

    mod.buff_indices[#mod.buff_indices + 1] = buff_index
end

mod.remove_resist_death = function(self)
    local local_player = get_player()
    if not local_player then
        mod:echo("Local player not found")
        return
    end
    local_player_unit = get_player_unit(local_player)
	local player_buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")

    if not player_buff_extension then
		return
	end

	local buff_name = "datatide_resist_death"
    local player_buffs = player_buff_extension._buffs_by_index
    
    for i, buff_index in ipairs(mod.buff_indices) do
        local buff = player_buff_extension._buffs_by_index[buff_index]

        if buff and buff:template_name() == buff_name then
            player_buff_extension:_remove_buff(buff_index)
        end

        mod.buff_indices[i] = nil
    end
end

---------- HOOKS ----------

-- track ability usage
mod:hook(CLASS.PlayerUnitAbilityExtension, "use_ability_charge", function(func, self, ability_type, optional_num_charges)
    -- mod:echo("hoooooooook")
    if ability_type == "combat_ability" and (test_state == "active" or test_state == "setup") then
        mod.Test_Results["combat_ability_used"] = true
    end
    -- if test_state == "setup" and step_index == 2 and ability_type == "combat_ability" then
    --     step_index = 1
    --     mod:Spawn_Test()
    --     mod:echo("Test reset. Wait until invisibility is removed to use combat ability")
    -- end
    return func(self, ability_type, optional_num_charges)
end)

-- remove minion friendly fire damage
mod:hook(CLASS.HealthExtension, "add_damage", function (func, self, damage_amount, permanent_damage, hit_actor, damage_profile, attack_type, attack_direction, attacking_unit)
	if attacking_unit and damage_amount and damage_amount > 0 then
		local Breed = get_breed_util()
		if Breed then
			local attacking_unit_data_extension = ScriptUnit.has_extension(attacking_unit, "unit_data_system")
			local attacker_breed_or_nil = attacking_unit_data_extension and attacking_unit_data_extension:breed()
			local attacker_is_minion = attacker_breed_or_nil and Breed.is_minion(attacker_breed_or_nil)

			if attacker_is_minion then
				local target_unit = self._unit
				local target_unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
				local target_breed_or_nil = target_unit_data_extension and target_unit_data_extension:breed()
				local target_is_minion = target_breed_or_nil and Breed.is_minion(target_breed_or_nil)

				if target_is_minion then
					damage_amount = 0
				end
			end
		end
	end

    return func(self, damage_amount, permanent_damage, hit_actor, damage_profile, attack_type, attack_direction, attacking_unit)
end)

-- track kills, stats
mod:hook(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
    -- mod:echo("hook!")
	if get_scoreboard() and is_valid_game_mode() then
		local Breed = get_breed_util()
		local player = attacking_unit and player_from_unit(attacking_unit)
		local target_is_player = attacked_unit and player_from_unit(attacked_unit)
        local actual_damage = 0

        local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
        local breed_or_nil = unit_data_extension and unit_data_extension:breed()
        local target_is_minion = breed_or_nil and Breed.is_minion(breed_or_nil)

        if test_state == "setup" and step_index == 3 then
            local valid_results = {
                toughness_absorbed = true,
                toughness_absorbed_melee = true,
                toughness_broken = true,
                shield_blocked = true
            }

            if player and target_is_minion and valid_results[attack_result] then 
                test_state = "active"
                time_start_test = FixedFrame.get_latest_fixed_time()
                mod:notify("Timer Started")
            end 
        end

        if damage > 0 then	

            if target_is_player then
                local player_health_extension = ScriptUnit.has_extension(attacked_unit, "health_system")
                current_player_health = player_health_extension and player_health_extension:current_health()

                local auto_fail = mod:get("toggle_auto_fail")
                local until_death_fail = mod:get("toggle_until_death_fail")

                if auto_fail and current_player_health < 2 and (test_state == "active" or test_state == "setup") then
                    if until_death_fail then
                        mod.Spawn_Test()
                    elseif not until_death_active() then
                        mod.Spawn_Test()
                    end
                end
            end

            if attack_type == "ranged" and not player and target_is_minion then
                if test_state == "active" and attack_result == "died" then
                    mod:notify("Kill from debuff, not tracked in scoreboard")
                    kill_counter = kill_counter + 1
                    if kill_counter == kills_needed then
                        test_state = "success"
                        mod.Spawn_Test()
                    end
                end
            end

            if player then
                if target_is_minion then
                    -- mod:echo(breed_or_nil.name)
                    local unit_health_extension = ScriptUnit.has_extension(attacked_unit, "health_system")
                    local damage_taken = unit_health_extension and unit_health_extension:damage_taken()
                    local max_health = unit_health_extension and unit_health_extension:max_health()

                    if test_state == "setup" and step_index == 3 then
                        test_state = "active"
                        time_start_test = FixedFrame.get_latest_fixed_time()
                        mod:notify("Timer Started")
                    elseif test_state == "setup" and step_index == 2 then
                        step_index = 1
                        mod:Spawn_Test()
                        mod:notify("Test reset. Wait until invisibility is removed to damage enemies")
                    end

                    -- handle kill counter, set state to success/call test func if limit is reached. fail if player health == 0 or player calls function manually when kill_counter < kills_needed
                    if test_state == "active" then
                        if attack_result == "died" then
                            kill_counter = kill_counter + 1
                            if kill_counter == kills_needed then
                                test_state = "success"
                                mod.Spawn_Test()
                            end

                            actual_damage = max_health - damage_taken + damage
                        else
                            actual_damage = damage
                        end

                        local unit_data_extension = ScriptUnit.has_extension(attacking_unit, "unit_data_system")
                        local inventory_component = unit_data_extension:read_component("inventory")
                        local current_slot = inventory_component.wielded_slot

                        if current_slot == "slot_primary" then
                            melee_damage = melee_damage + actual_damage
                        elseif current_slot == "slot_secondary" then
                            ranged_damage = ranged_damage + actual_damage
                        elseif current_slot == "slot_grenade_ability" then
                            grenade_damage = grenade_damage + actual_damage
                        end                          
                    end
                end
            end
        end
    end
	return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
end)

mod:hook("PacingManager", "update", function(func, self, dt, t)
    Managers.state.pacing._disabled = true
    return func(self, dt, t)
end)

-- Guard against invalid or already-removed volume errors when removing nav cost map volumes
mod:hook("NavMeshManager", "remove_nav_cost_map_volume", function(func, self, volume_id, cost_map_id)
    if not volume_id or not cost_map_id then
        return
    end

    local cost_map_data = self._nav_cost_maps_data and self._nav_cost_maps_data[cost_map_id]
    local volumes = cost_map_data and cost_map_data.volumes
    local volume = volumes and volumes[volume_id]

    if not volume then
        return
    end

    return func(self, volume_id, cost_map_id)
end)

-- Suppress crash when leaving mission with ritual daemonhost spawned
mod:hook("BtChaosMutatorDaemonhostPassiveAction", "leave", function(func, self, unit, breed, blackboard, scratchpad, action_data, t, reason, destroy)
    local position = POSITION_LOOKUP[unit]
    local is_teardown = destroy or reason == "despawned" or reason == "aborted" or reason == "game_mode_ended" or not position

    if is_teardown then
        local locomotion_extension = scratchpad.locomotion_extension
        if locomotion_extension then
            local original_rotation_speed = scratchpad.original_rotation_speed
            if original_rotation_speed then
                locomotion_extension:set_rotation_speed(original_rotation_speed)
            end
        end

        if scratchpad.health_extension then
            scratchpad.health_extension:set_invulnerable(false)
        end

        if scratchpad.chanting_effect_id and scratchpad.fx_system then
            scratchpad.fx_system:stop_template_effect(scratchpad.chanting_effect_id)
            scratchpad.chanting_effect_id = nil
        end

        local cultists = scratchpad.chanting_units
        if cultists then
            for _, cultist in pairs(cultists) do
                if HEALTH_ALIVE[cultist] then
                    local DamageProfileTemplates = require("scripts/settings/damage/damage_profile_templates")
                    local Attack = require("scripts/utilities/attack/attack")
                    Attack.execute(cultist, DamageProfileTemplates.default, "power_level", 2000, "attack_direction", Vector3.up(), "instakill", true)
                end
            end
        end

        local Threat = require("scripts/utilities/threat")
        Threat.set_threat_decay_enabled(unit, true)

        local nav_cost_map_volume_id = scratchpad.nav_cost_map_volume_id
        local nav_cost_map_id = scratchpad.nav_cost_map_id
        if nav_cost_map_volume_id and nav_cost_map_id and Managers.state and Managers.state.nav_mesh then
            Managers.state.nav_mesh:remove_nav_cost_map_volume(nav_cost_map_volume_id, nav_cost_map_id)
            scratchpad.nav_cost_map_volume_id = nil
        end

        if Managers.state and Managers.state.pacing then
            local Blackboard = require("scripts/extension_systems/blackboard/utilities/blackboard")
            local statistics_component = Blackboard.write_component(blackboard, "statistics")
            Managers.state.pacing:set_minion_listening_for_player_deaths(unit, statistics_component, true)
        end

        return
    end

    local success, result = pcall(func, self, unit, breed, blackboard, scratchpad, action_data, t, reason, destroy)
    if not success then
        return
    end
    return result
end)

---------- EVENT CALLS ----------

mod.on_enabled = function(initial_call)

    test_selection = mod.Test_Names[test_selection_index]
    current_test = mod.Test_Names[test_selection_index]

    if initial_call then
        -- local current_date = os.date("%Y-%m-%d")
        -- local current_time = os.date("%H:%M:%S")
        -- local DMF = get_mod("DMF")
        -- local io = DMF:persistent_table("_io")
        -- io.initialized = io.initialized or false
        
        -- if not io.initialized then
        --     io = DMF.deepcopy(Mods.lua.io)
        -- end
    
        -- local file = io.open("../mods/DatatideTestSpawner/test_data/test_results " .. current_date .. ".txt", "a")
        -- file:write("--------------------" .. current_time .. "--------------------" .. "\n")
        -- file:close()
        mod:data_line_break()

        local patch_number = mod:get("patch")
        if patch_number then
            mod.Test_Results["patch"] = patch_number
        else
            mod.Test_Results["patch"] = ""
        end
        
        local user_name = Managers.account:user_display_name()
        if user_name then
            mod.Test_Results["user"] = user_name
        else
            mod.Test_Results["user"] = ""
        end
        for test, _ in pairs(mod.Test_Data) do
            table.insert(mod.Test_Names, test)
        end
    end
    mod:disable_all_hooks()
    mod:Set_Test_Group()

end

mod.on_game_state_changed = function(status, state_name)
    if state_name == "StateLoading" then
        mod:disable_all_hooks()
        mod:Set_Test_Group()
        step_index = 1
    end

    if status == "enter" and state_name == "StateGameplay" then
        local delay_counter = 0
        local delay_time = 1

        mod.update = function(dt)
            delay_counter = delay_counter + 1*dt

            if delay_counter > delay_time then
                mod:Set_Test_Group()
                reset_update_func()
            end
        end        
    end
end

mod.on_setting_changed = function(setting_id)
    if setting_id == "test_group_dropdown" and is_valid_game_mode() then
        mod:Set_Test_Group()
    end
end

---------- COMMANDS ----------

mod:command("dtnotes", "saves test notes entered in field: dtnotes \"...\"",
function(...) mod.save_test_notes(...) end)

mod.save_test_notes = function(...)
    local notes = table.concat({...}, " ")
    notes = notes:gsub('"', "")
    mod.Test_Results["test_notes"] = notes
    -- mod:echo("Test Notes saved as \"" .. notes .. "\"")
    mod:Save_Test_Result()
end

mod:command("dtcombo", "saves attack combo entered in field: dtcombo \"...\"",
function(...) mod.save_attack_combo(...) end)

mod.save_attack_combo = function(...)
    local combo = table.concat({...}, " ")
    combo = combo:gsub('"', "")
    mod.Test_Results["attack_combo"] = combo
    -- mod:echo("Attack Combo saved as \"" .. combo .. "\"")
    mod:Save_Test_Result()
end

mod:command("dtpatch", "sets the patch entered in field: dtpatch \"...\", this value is persistent between instances of Darktide",
function(...) mod.save_patch(...) end)

mod.save_patch = function(...)
    local patch_number = table.concat({...}, " ")
    mod:set("patch", patch_number)
    mod.Test_Results["patch"] = patch_number
    mod:echo("Persistent Patch Number saved as " .. patch_number)
end

mod:command("dtlinebreak", "adds a line to the test data file with a timestamp",
function() mod.data_line_break() end)

mod.data_line_break = function(self)

    local current_date = os.date("%Y-%m-%d")
    local current_time = os.date("%H:%M:%S")
    local DMF = get_mod("DMF")
    local io = DMF:persistent_table("_io")
    io.initialized = io.initialized or false
    
    if not io.initialized then
        io = DMF.deepcopy(Mods.lua.io)
    end

    local filename = "../mods/DatatideTestSpawner/test_data/test_results " .. current_date .. ".txt"
    
    -- Check if file exists
    local file = io.open(filename, "r")
    if not file then
        return  -- If file doesn't exist, exit the function
    end
    
    -- Read the last line of the file
    local last_line = ""
    for line in file:lines() do
        last_line = line
    end
    file:close()

    -- Check if the file is empty (i.e., last_line is still empty)
    if last_line == "" then
        -- File is empty, append a new line
        file = io.open(filename, "a")
        if not file then
            mod:echo("Could not open file!")
            return
        end
        file:write("--------------------" .. current_time .. "--------------------")
        file:close()
        
        mod:notify("Timestamp Added")
        mod:echo("added line")
        return
    end

    -- If the last line contains "--------------------", replace it
    file = io.open(filename, "a")  -- Open in append mode for the main logic
    if last_line:match("--------------------") then
        -- Open the file for reading again
        local file = io.open(filename, "r")
        if not file then
            print("Could not open file for reading!")
            return
        end

        local lines = {}
        for line in file:lines() do
            table.insert(lines, line)
        end
        file:close()
    
        -- Replace last line with new data
        table.remove(lines)
        table.insert(lines, "--------------------" .. current_time .. "--------------------")
    
        -- Open the file in write mode to overwrite the content
        file = io.open(filename, "w")
        if not file then
            print("Could not open file for writing!")
            return
        end
    
        -- Write the remaining lines back to the file
        for _, line in ipairs(lines) do
            file:write(line .. "\n")
        end
        file:close()
        
        -- mod:notify("Timestamp Added")
        -- mod:echo("replaced line")
    else
        -- If the last line doesn't match "--------------------", append a new one
        local file = io.open(filename, "a")
        if not file then
            mod:echo("Could not open file!")
            return
        end
        file:write("\n--------------------" .. current_time .. "--------------------")
        file:close()
        
        -- mod:notify("Timestamp Added")
        -- mod:echo("added line")
    end
end

mod:command("dttests", "echos all maps and available tests",
function() mod.echo_tests() end)

mod.echo_tests = function(self)
    local test_data = mod.Test_Data
    local test_maps = {}
    local test_map_pairs = {}

    for test, data in pairs(test_data) do
        local mission_name = data["test_data"].map_name
        local test_name = data["test_data"].test_name
        if not contains(test_maps, mission_name) then
            table.insert(test_maps, mission_name)
        end
        test_map_pairs[test_name] = mission_name
    end

    for i = 1, #test_maps do
        local test_list = ""
        local first = true  -- This flag tracks whether we're adding the first test name

        -- Loop through the test_map_pairs and add tests for the current map
        for test, map in pairs(test_map_pairs) do
            if map == test_maps[i] then
                if first then
                    test_list = "\"" .. test .. "\""
                    first = false
                else
                    test_list = test_list .. ", \"" .. test .. "\""
                end
            end
        end

        -- Echo the map and its test list
        mod:echo(test_maps[i] .. ":\n" .. test_list)
    end
end

---------- Utilities ----------

mod.Position_at_Cursor = function(self)
    if Managers.ui:chat_using_input() then
        return
    end

    local game_state = Managers.presence and Managers.presence._current_game_state_name
    if game_state ~= "StateGameplay" then
        return
    end

    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end

    local viewport_name = local_player.viewport_name

    local camera_position = Managers.state.camera:camera_position(viewport_name)
    local camera_rotation = Managers.state.camera:camera_rotation(viewport_name)
    local camera_direction = Quaternion.forward(camera_rotation)
  
    local range = 500
  
    local world = Managers.world:world("level_world")
    local physics_world = World.get_data(world, "physics_world")
  
    local new_position
    local result = PhysicsWorld.immediate_raycast(physics_world,
                            camera_position,
                            camera_direction, range,
                            "all", "types",
                            "both", "collision_filter",
                            "filter_player_character_shooting_raycast_statics"
                            )
  
    if result then
      local num_hits = #result
  
      for i = 1, num_hits, 1 do
        local hit = result[i]
        local hit_actor = hit[4]
        local hit_unit = Actor.unit(hit_actor)
        local player_unit = get_player_unit()
        local ray_hit_self = player_unit and
                     (hit_unit == player_unit)
  
        if not ray_hit_self then
          new_position = hit[1]
          break
        end
      end
    end
    mod:echo(new_position)
    return new_position
end

mod.Echo_Mission_Name = function(self)
    if Managers.ui:chat_using_input() then
        return
    end

    local game_state = Managers.presence and Managers.presence._current_game_state_name
    if game_state ~= "StateGameplay" then
        return
    end

    local current_mission = Managers.state.mission:mission_name() 
    mod:echo(current_mission)
end

mod.Test_Func_1 = function(self)

end

-- mod.Test_Func_2 = function(self)
--     local position = Vector3(-166.5, 11.25, 0.5)
--     local rotation = Quaternion.axis_angle(Vector3(0,0,1), math.rad(180))

--     local twin_unit_2 = Managers.state.minion_spawn:spawn_minion("renegade_twin_captain_two", position, rotation, 2)
-- 	local spawned_unit_health_extension_2 = ScriptUnit.extension(twin_unit_2, "health_system")
-- 	local spawned_unit_toughness_extension_2 = ScriptUnit.extension(twin_unit_2, "toughness_system")

-- 	spawned_unit_toughness_extension_2:set_toughness_damage(0, reactivation_override)
-- end

-- mod.Test_Func_3 = function(self)
--     local local_player = get_player()
--     if not local_player then
--       mod:error("Local player not found.")
--       return
--     end
--     local_player_unit = get_player_unit(local_player)
--     local unit_data_extension = ScriptUnit.has_extension(local_player_unit, "unit_data_system")    
-- 	local combat_ability_component = unit_data_extension:write_component("combat_ability")

-- 	combat_ability_component.active = false
-- end
