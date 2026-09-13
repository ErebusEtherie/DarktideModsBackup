local mod = get_mod("testing_utilities")


local test_array = {}
local test_var = test_var

-- General Variables
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local FixedFrame = require("scripts/utilities/fixed_frame")
local SpecialRulesSetting = require("scripts/settings/ability/special_rules_settings")
local CharacterStateConsumed = require("scripts/extension_systems/character_state_machine/character_states/player_character_state_consumed")
local WarpCharge = require("scripts/utilities/warp_charge")
local SpecialKillCount = require("scripts/extension_systems/weapon/special_classes/weapon_special_kill_count_charges")
local Overheat = require("scripts/utilities/overheat")
local Toughness = require("scripts/utilities/toughness/toughness")
local Ammo = require("scripts/utilities/ammo")

local special_rules = SpecialRulesSetting.special_rules
local local_player_unit = local_player_unit

--Toggle Variables
local toggle_buff_handling = toggle_buff_handling
local toggle_health_handling = toggle_health_handling
local toggle_toughness_handling = toggle_toughness_handling
local toggle_combat_ability_handling = toggle_combat_ability_handling
local toggle_grenade_ability_handling = toggle_grenade_ability_handling
local toggle_peril_handling = toggle_peril_handling
local toggle_weapon_heat_handling = toggle_weapon_heat_handling
local toggle_weapon_ammo_handling = toggle_weapon_ammo_handling
local toggle_despawn_units = toggle_despawn_units

local toggle_DD_buff_handling = toggle_DD_buff_handling
local toggle_WS_buff_handling = toggle_WS_buff_handling
local toggle_IJ_buff_handling = toggle_IJ_buff_handling
local toggle_BP_buff_handling = toggle_BP_buff_handling
-- local toggle_until_death_buff_handling = toggle_until_death_buff_handling

local buff_toggles_array = {}

-- Health Variables
local max_player_health = max_player_health
local max_player_wounds = max_player_wounds
local health_per_wound = health_per_wound
local current_player_health = current_player_health
local desired_wounds_remaining = desired_wounds_remaining
local desired_player_health = desired_player_health
local heal_value = heal_value

-- Toughness Variables
local max_player_toughness = max_player_toughness
local current_player_toughness = current_player_toughness
local desired_toughness_percentage = desired_toughness_percentage
local desired_player_toughness = desired_player_toughness
local toughness_change_value = toughness_change_value

-- Assist Variables
local unit_data_extension = unit_data_extension
local character_state_component = character_state_component
local disabled_character_state_component = disabled_character_state_component
local is_knocked_down = is_knocked_down
local is_netted = is_netted
local is_ledge_hanging = is_ledge_hanging

-- Class Buff Templates
local psyker_buff_templates = require("scripts/settings/buff/archetype_buff_templates/psyker_buff_templates")
local zealot_buff_templates = require("scripts/settings/buff/archetype_buff_templates/zealot_buff_templates")
local veteran_buff_templates = require("scripts/settings/buff/archetype_buff_templates/veteran_buff_templates")
local ogryn_buff_templates = require("scripts/settings/buff/archetype_buff_templates/ogryn_buff_templates")
local buff_operations = require("scripts/extension_systems/buff/buffs/buff")

-- Buff Variables
local mod_buffs_table = {
    ----------------- Disrupt Destiny
    DD_base = {
        template_name = "psyker_marked_enemies_passive_bonus_stacking",
        talent_name = "psyker_new_mark_passive",
        buff_name = "Disrupt Destiny",
        base_duration = psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking.duration,
        max_stacks = psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking.max_stacks,
        desired_stacks = "desired_DD_stacks", -- name of DD buff slider
        toggle_var = "toggle_DD_buff_handling"
    },
    DD_extended = {
        template_name = "psyker_marked_enemies_passive_bonus_stacking_increased_duration",
        talent_name = "psyker_mark_increased_duration",
        buff_name = "Disrupt Destiny",
        base_duration = psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking_increased_duration.duration,
        max_stacks = psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking_increased_duration.max_stacks,
        desired_stacks = "desired_DD_stacks",
        toggle_var = "toggle_DD_buff_handling"
    },
    DD_increased_stacks = {
        template_name = "psyker_marked_enemies_passive_bonus_stacking_increased_stacks",
        talent_name = "psyker_mark_increased_max_stacks",
        buff_name = "Disrupt Destiny",
        base_duration = psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking.duration,
        max_stacks = psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking_increased_stacks.max_stacks,
        desired_stacks = "desired_DD_stacks",
        toggle_var = "toggle_DD_buff_handling"
    },
    ----------------- Warp Siphon
    Warp_Siphon = {
        template_name = "psyker_souls",
        talent_name = "psyker_passive_souls_from_elite_kills",
        buff_name = "Warp Siphon",
        base_duration = psyker_buff_templates.psyker_souls.duration,
        max_stacks = psyker_buff_templates.psyker_souls.max_stacks,
        desired_stacks = "desired_WS_stacks",
        toggle_var = "toggle_WS_buff_handling"
    },    
    Warp_Siphon_increased_stacks = {
        template_name = "psyker_souls_increased_max_stacks",
        talent_name = "psyker_increased_max_souls",
        buff_name = "Warp Siphon",
        base_duration = psyker_buff_templates.psyker_souls_increased_max_stacks.duration,
        max_stacks = psyker_buff_templates.psyker_souls_increased_max_stacks.max_stacks,
        desired_stacks = "desired_WS_stacks",
        toggle_var = "toggle_WS_buff_handling"
    },
    -------------------- Misc
    Inexorable_Judgement = {
        template_name = "zealot_quickness_active",
        talent_name = "zealot_quickness_passive",
        buff_name = "Inexorable Judgement",
        base_duration = zealot_buff_templates.zealot_quickness_active.duration,
        max_stacks = zealot_buff_templates.zealot_quickness_active.max_stacks,
        desired_stacks = "desired_IJ_stacks",
        toggle_var = "toggle_IJ_buff_handling"
    },
    Blazing_Piety = {
        template_name = "zealot_fanatic_rage",
        talent_name = "zealot_fanatic_rage",
        buff_name = "Blazing Piety",
        base_duration = zealot_buff_templates.zealot_fanatic_rage_buff.duration,
        max_stacks = 25,
        desired_stacks = 25,
        toggle_var = "toggle_BP_buff_handling"
    } 
    -- Until_Death = {
    --     template_name = "zealot_resist_death",
    --     talent_name = "zealot_resist_death",
    --     buff_name = "Until Death",
    --     base_duration = zealot_buff_templates.zealot_resist_death.active_duration,
    --     max_stacks = 1,
    --     desired_stacks = 1,
    --     toggle_var = "toggle_until_death_buff_handling"
    -- }   
}

local mod_buffs_name_table = {}
local effected_buffs_table = {}

local player_buffs = {}
local current_player_buffs_names = {}

-- General Functions
local get_index_of_value = function(table, value)
    for index, v in ipairs(table) do
        if v == value then
            return index  -- Return the index when the value is found
        end
    end
end

local contains = function(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true  -- Found the value, return true
        end
    end
    return false  -- Value not found
end

local buff_to_talent_name = function(buff_name)
    for template, data in pairs(mod_buffs_table) do
        if data["template_name"] == buff_name then
            return data["talent_name"]
        end
    end
end

local buff_array_to_names = function(input_array, output_array)
    for _, data in pairs(input_array) do
        table.insert(output_array, data:template_name())
    end
    return output_array
end

local set_toggle_variables = function()
    toggle_buff_handling = mod:get("toggle_buff_handling")
    toggle_health_handling = mod:get("toggle_health_handling")
    toggle_toughness_handling = mod:get("toggle_toughness_handling")
    toggle_combat_ability_handling = mod:get("toggle_combat_ability_handling")
    toggle_grenade_ability_handling = mod:get("toggle_grenade_handling")
    toggle_peril_handling = mod:get("toggle_peril_handling")
    toggle_weapon_heat_handling = mod:get("toggle_weapon_heat_handling")
    toggle_weapon_ammo_handling = mod:get("toggle_weapon_ammo_handling")
    toggle_despawn_units = mod:get("toggle_despawn_units")
    
    toggle_DD_buff_handling = mod:get("toggle_DD_buff_handling")
    toggle_WS_buff_handling = mod:get("toggle_WS_buff_handling")
    toggle_IJ_buff_handling = mod:get("toggle_IJ_buff_handling")
    toggle_BP_buff_handling = mod:get("toggle_BP_buff_handling")

    -- toggle_until_death_buff_handling = mod:get("toggle_until_death_buff_handling")
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

local check_talent_is_equipped = function(self, talent_name)
    ----------------------------------------------------------------------------------------------------------------
    --remove this once mod is fully set up, the main function will handle this before calling to check talents
    local buffs_file = require("scripts/extension_systems/buff/buffs/buff")
    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player)
    ----------------------------------------------------------------------------------------------------------------

    local talent_extension = ScriptUnit.has_extension(local_player_unit, "talent_system")
    local talents_equipped = talent_extension:talents(self)

    if talents_equipped[talent_name] then
        return true
    else
        return false
    end
end

local set_effected_buffs_table = function(self)

    -- Generate list of all buff names for mod, maybe move to initialize function later
    for template, data in pairs(mod_buffs_table) do
        table.insert(mod_buffs_name_table, data["template_name"])
    end

    ----------------------------------------------------------------------------------------------------------------
    --remove this once mod is fully set up, the main function will handle this
    local buffs_file = require("scripts/extension_systems/buff/buffs/buff")
    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player)
    set_toggle_variables()
    ----------------------------------------------------------------------------------------------------------------
    -- Clear effected_buffs_table{}
    for i = 1, #effected_buffs_table do
        table.remove(effected_buffs_table, i)
    end

    local toggled_buffs_table = {}
    local non_equipped_buffs = {}

    for template, data in pairs(mod_buffs_table) do
        if mod:get(data["toggle_var"]) == true then
            table.insert(toggled_buffs_table, data["template_name"])
        end
    end

    effected_buffs_table = toggled_buffs_table

    for i = 1, #effected_buffs_table do
        local buff_name = effected_buffs_table[i]
        local talent_name = buff_to_talent_name(buff_name) 
        if check_talent_is_equipped(local_player_unit, talent_name) == false then
            table.insert(non_equipped_buffs, effected_buffs_table[i])
        end
    end

    for i = 1, #non_equipped_buffs do
        local buff_name = non_equipped_buffs[i]
        local buff_index = get_index_of_value(effected_buffs_table, buff_name)
        table.remove(effected_buffs_table, buff_index)
    end
    -----------------remove superceded buffs PLEASE MAKE BETTER
    if contains(effected_buffs_table, "psyker_marked_enemies_passive_bonus_stacking_increased_duration") or contains(effected_buffs_table, "psyker_marked_enemies_passive_bonus_stacking_increased_stacks") then
        local buff_index = get_index_of_value(effected_buffs_table, "psyker_marked_enemies_passive_bonus_stacking")
        table.remove(effected_buffs_table, buff_index)
    end
    if contains(effected_buffs_table, "psyker_souls_increased_max_stacks") then
        local buff_index = get_index_of_value(effected_buffs_table, "psyker_souls")
        table.remove(effected_buffs_table, buff_index)
    end
    -- test_array = effected_buffs_table
end

mod.reset_update_func = function()
    mod.update = function()
    end
end

mod.set_infinite_buffs_update_func = function()
    local big_num = 99999
    for i = 1, #effected_buffs_table do
        if effected_buffs_table[i] == "psyker_marked_enemies_passive_bonus_stacking" then
            psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking.duration = 99999
        end
        if effected_buffs_table[i] == "psyker_marked_enemies_passive_bonus_stacking_increased_duration" then
            psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking_increased_duration.duration = 99999
        end
        if effected_buffs_table[i] == "psyker_marked_enemies_passive_bonus_stacking_increased_stacks" then
            psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking_increased_stacks.duration = 99999
        end
        if effected_buffs_table[i] == "psyker_souls" then
            psyker_buff_templates.psyker_souls.duration = 99999
        end
        if effected_buffs_table[i] == "psyker_souls_increased_max_stacks" then
            psyker_buff_templates.psyker_souls_increased_max_stacks.duration = 99999
        end
        if effected_buffs_table[i] == "zealot_quickness_active" then
            zealot_buff_templates.zealot_quickness_active.duration = 99999
        end
        if effected_buffs_table[i] == "zealot_fanatic_rage" then
            zealot_buff_templates.zealot_fanatic_rage_buff.duration = 99999
        end
    end
end

mod.reset_buff_durations = function()
    for i = 1, #mod_buffs_name_table do
        if mod_buffs_name_table[i] == "psyker_marked_enemies_passive_bonus_stacking" then
            psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking.duration = mod_buffs_table["DD_base"].base_duration
        end
        if mod_buffs_name_table[i] == "psyker_marked_enemies_passive_bonus_stacking_increased_duration" then
            psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking_increased_duration.duration = mod_buffs_table["DD_extended"].base_duration
        end
        if mod_buffs_name_table[i] == "psyker_marked_enemies_passive_bonus_stacking_increased_stacks" then
            psyker_buff_templates.psyker_marked_enemies_passive_bonus_stacking_increased_stacks.duration = mod_buffs_table["DD_increased_stacks"].base_duration
        end
        if mod_buffs_name_table[i] == "psyker_souls" then
            psyker_buff_templates.psyker_souls.duration = mod_buffs_table["DD_increased_stacks"].base_duration
        end
        if mod_buffs_name_table[i] == "psyker_souls_increased_max_stacks" then
            psyker_buff_templates.psyker_souls_increased_max_stacks.duration = mod_buffs_table["DD_increased_stacks"].base_duration
        end
        if mod_buffs_name_table[i] == "zealot_quickness_active" then
            zealot_buff_templates.zealot_quickness_active.duration = mod_buffs_table["Inexorable_Judgement"].base_duration
        end
        if mod_buffs_name_table[i] == "zealot_fanatic_rage" then
            zealot_buff_templates.zealot_fanatic_rage_buff.duration = mod_buffs_table["Blazing_Piety"].base_duration
        end
    end
end

--------------- Event Calls --------------------

mod.on_game_state_changed = function(status, state_name)
    if status == "enter" and state_name == "StateLoading" then
        mod:reset_update_func()
        return
    end
    if status == "enter" and state_name == "StateMainMenu" then
        mod:reset_update_func()
    end
end

mod.on_setting_changed = function(setting_id)

    local local_player = get_player()
    if not local_player then
        mod:error("Local player not found.")
        return
    end
    local_player_unit = get_player_unit(local_player)

    if local_player_unit and is_valid_game_mode() and is_server() then
        if setting_id == "toggle_infinite_buffs" and mod:get(setting_id) then
            mod:set_infinite_buffs_update_func()

        elseif setting_id == "toggle_infinite_buffs" and not mod:get(setting_id) then
            mod:reset_buff_durations()
        end
    end
end

mod.on_enabled = function(initial_call)
    if initial_call then
        return
    end
    local local_player = get_player()
    if not local_player then
        mod:error("Local player not found.")
        return
    end
    local_player_unit = get_player_unit(local_player)

    if local_player_unit and is_valid_game_mode() and is_server() then
        if mod:get("toggle_infinite_buffs") then
            mod:set_infinite_buffs_update_func()
        end
    end
end

mod.on_disabled = function(initial_call)
    mod:reset_buff_durations()
end

-----------------------------------------------------------------------------------------------------

-- Reset Character Function 
mod.Reset_Character = function(self)
    if Managers.ui:chat_using_input() then
        return
    end

    -- General Variables 
    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player) 
    set_toggle_variables()

    -- Function Conditions
    if local_player_unit and is_valid_game_mode() and is_server() then

        -- Update Toggle Variables
        toggle_combat_ability_handling = mod:get("toggle_combat_ability_handling")
        toggle_despawn_units = mod:get("toggle_despawn_units")
        toggle_buff_handling = mod:get("toggle_buff_handling")
        toggle_peril_handling = mod:get("toggle_peril_handling")

        unit_data_extension = ScriptUnit.has_extension(local_player_unit, "unit_data_system")
        local character_state_component = unit_data_extension:read_component("character_state")
        local disabled_character_state_component = unit_data_extension:read_component("disabled_character_state")
        local buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")

        local is_knocked_down = PlayerUnitStatus.is_knocked_down(character_state_component)
        local is_netted = PlayerUnitStatus.is_netted(disabled_character_state_component)
        local is_ledge_hanging = PlayerUnitStatus.is_ledge_hanging(character_state_component)
        

        -- Call Functions

        if toggle_despawn_units then
            mod:Despawn_Units()
        end
        if is_knocked_down or is_netted or is_ledge_hanging then
            mod:Assist_Player()
        end
        if toggle_health_handling then
            mod:Reset_Health()
        end
        if toggle_toughness_handling then
            mod:Reset_Toughness()
        end
        if toggle_peril_handling then
            mod:Reset_Peril()
        end
        if toggle_weapon_heat_handling then
            mod:Reset_Weapon_Heat()
        end
        if toggle_weapon_ammo_handling then
            mod:Reset_Weapon_Ammunition()
        end
        if toggle_combat_ability_handling == true then
            mod:Reset_Combat_Ability()
        end
        if toggle_grenade_ability_handling == true then
            mod:Reset_Grenade_Ability()
        end

        if toggle_buff_handling == true then
            mod_buffs_table = mod:persistent_table("mod_buffs_table", mod_buffs_table)
            set_effected_buffs_table()
            player_buffs = buff_extension:buffs(local_player_unit) 
            current_player_buffs_names = buff_array_to_names(player_buffs, current_player_buffs_names) 
            local delay_counter = 0
            local delay_time = 0.5
            for i = 1, #player_buffs do
                local buff_name = player_buffs[i]:template_name()
                if contains(mod_buffs_name_table, buff_name) then
                    mod:Remove_Buff(buff_name)
                end
            end
            if contains(current_player_buffs_names, "psyker_marked_enemies_passive_bonus_stacking_increased_stacks") == true then
                delay_time = 0.75
            else
                delay_time = 0.4
            end
            mod.update = function(dt)
                delay_counter = delay_counter + 1*dt
                if delay_counter > delay_time then

                    for i = 1, #effected_buffs_table do
                        mod:reset_buff_durations()
                        mod:Add_Buff(effected_buffs_table[i])
                        mod:reset_update_func()
                    end
                    if mod:get("toggle_infinite_buffs") then
                        mod:set_infinite_buffs_update_func()
                    else
                        mod:reset_buff_durations()
                    end                       
                end               
            end

            --Datatide Tracking
            if #effected_buffs_table > 0 or mod.dt_marty_applied then
                mod.dt_buff_applied = true
                mod.dt_buff_stacks = ""
                for i = 1, #effected_buffs_table do
                    local buff_name = effected_buffs_table[i]
                    for template, data in pairs(mod_buffs_table) do
                        if data["template_name"] == buff_name then
                            local buff_loc = data["buff_name"]
                            local buff_desired_stacks = mod:get(data["desired_stacks"])
                            if not buff_desired_stacks then
                                buff_desired_stacks = data["max_stacks"]
                            end
                            local buff_max_stacks = data["max_stacks"]
                            local buff_stacks = math.min(buff_desired_stacks, buff_max_stacks)
                            mod.dt_buff_stacks = mod.dt_buff_stacks .. buff_loc .. ": " .. buff_stacks
                            if i < #effected_buffs_table or (i == #effected_buffs_table and i ~= 0 and mod.dt_marty_applied) then
                                mod.dt_buff_stacks = mod.dt_buff_stacks .. ", "
                            end
                        end
                    end
                end
                if mod.dt_marty_applied then
                    mod.dt_buff_stacks = mod.dt_buff_stacks .. mod.dt_marty_stacks
                end
            else
                mod.dt_buff_applied = false
                mod.dt_buff_stacks = ""
            end
        else
            if mod.dt_marty_applied == false then
                mod.dt_buff_applied = false
                mod.dt_buff_stacks = ""
            end
        end
    end
end

-- Removes All Buffs Handled By the Mod
mod.Remove_Mod_Buffs = function(self)
    if Managers.ui:chat_using_input() then
        return
    end 
    local local_player = get_player()
    if not local_player then
      mod:error("Local player not found.")
      return
    end
    local_player_unit = get_player_unit(local_player) 


    if local_player_unit and is_valid_game_mode() and is_server() then
        local buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")
        mod_buffs_table = mod:persistent_table("mod_buffs_table", mod_buffs_table)

        set_effected_buffs_table()

        player_buffs = buff_extension:buffs(local_player_unit) 
        current_player_buffs_names = buff_array_to_names(player_buffs, current_player_buffs_names) 
        local delay_counter = 0
        local delay_time = 0.75
        for i = 1, #player_buffs do
            local buff_name = player_buffs[i]:template_name()
            if contains(mod_buffs_name_table, buff_name) then
                mod:Remove_Buff(buff_name)
            end
        end

        mod.update = function(dt)
            delay_counter = delay_counter + 1*dt
            if delay_counter > delay_time then
                mod:reset_buff_durations()
                mod:reset_update_func()                 
            end               
        end 
    end
end

-- Reset Health Function
mod.Reset_Health = function(self)     
    -- Set Health Extension Variables
    local health_extension = ScriptUnit.has_extension(local_player_unit, "health_system")
    local full_health_without_marty = mod:get("toggle_non_marty_hp")
    local marty_equipped = check_talent_is_equipped(local_player_unit, "zealot_martyrdom")
        
    max_player_health = health_extension: max_health()
    max_player_wounds = health_extension: max_wounds()
    current_player_health = health_extension: current_health()

    -- Get Settings Variables        
    if full_health_without_marty == false or marty_equipped then   
        desired_wounds_remaining = mod:get("desired_wounds_remaining")
    else
        desired_wounds_remaining = max_player_wounds
    end

    -- Calculate Variables
    health_per_wound = max_player_health/max_player_wounds
    desired_player_health = desired_wounds_remaining * health_per_wound
    heal_value = math.floor(desired_player_health - current_player_health)

        
    health_extension: add_heal(max_player_health + 100, "blessing")
    health_extension: add_heal(heal_value, "healing_station")

    -- Datatide Report Martyrdom
    if marty_equipped then
        local marty_stacks_applied = max_player_wounds - desired_wounds_remaining
        if marty_stacks_applied > 0 then
            mod.dt_marty_applied = true
            mod.dt_marty_stacks = "Martyrdom: " .. marty_stacks_applied
        else
            mod.dt_marty_applied = false
            mod.dt_marty_stacks = ""
        end
    else
        mod.dt_marty_applied = false
        mod.dt_marty_stacks = ""
    end
end

-- Reset Toughness Function
mod.Reset_Toughness = function(self)

    --Get Settings Variables
    -- desired_toughness_percentage = mod:get("desired_toughness_percentage")
    desired_toughness_percentage = 100


    -- Set Toughness Extension Variables
    local toughness_extension = ScriptUnit.has_extension(local_player_unit, "toughness_system")

    max_player_toughness = toughness_extension:max_toughness()
    current_player_toughness = toughness_extension:remaining_toughness()

    -- Calculated Variables       
    desired_player_toughness = 0.01 * desired_toughness_percentage * max_player_toughness
    toughness_change_value = math.abs(desired_player_toughness - current_player_toughness)

    if toughness_extension then
        toughness_extension:recover_flat_toughness(toughness_change_value, true, "melee_kill")
        -- if desired_player_toughness >= current_player_toughness then
        --     toughness_extension:recover_flat_toughness(toughness_change_value, true, "melee_kill")
        -- elseif desired_player_toughness < current_player_toughness then
        --     toughness_extension:add_damage(local_player_unit, toughness_change_value)
        -- end
    end
end

-- Set Peril to 0
mod.Reset_Peril = function(self)
    local unit_data_extension = ScriptUnit.extension(local_player_unit, "unit_data_system")
    local warp_charge_component = unit_data_extension:write_component("warp_charge")

    WarpCharge.decrease_immediate(100, warp_charge_component, local_player_unit)
end

-- Reset Weapon Special Heat Mechanic
mod.Reset_Weapon_Heat = function(self)
    local inventory_component = unit_data_extension:read_component("inventory")
	local wielded_slot = inventory_component.wielded_slot
    local inventory_slot_component = unit_data_extension:write_component(wielded_slot)

    if (wielded_slot == "slot_primary" or wielded_slot == "slot_secondary") and inventory_slot_component.overheat_current_percentage then
        Overheat.decrease_immediate(100, inventory_slot_component)
    end

    if (wielded_slot == "slot_primary" or wielded_slot == "slot_secondary") and inventory_slot_component.num_special_charges then
        inventory_slot_component.num_special_charges = 0
    end
end

mod.Reset_Weapon_Ammunition = function(self)
    local inventory_slot_component = unit_data_extension:write_component("slot_secondary")
    local max_ammo_reserve = inventory_slot_component.max_ammunition_reserve
    local max_ammo_clip = inventory_slot_component.max_ammunition_clip

    inventory_slot_component.current_ammunition_reserve = max_ammo_reserve
    inventory_slot_component.current_ammunition_clip = max_ammo_clip
end

-- Reset Combat Abilities
mod.Reset_Combat_Ability = function(self)
    local ability_extension = ScriptUnit.has_extension(local_player_unit, "ability_system")     
    local combat_ability_max_charges = ability_extension:max_ability_charges("combat_ability")
    ability_extension:reduce_ability_cooldown_percentage("combat_ability", 100)
    ability_extension:restore_ability_charge("combat_ability", combat_ability_max_charges)
end

mod.Reset_Grenade_Ability = function(self)
    local ability_extension = ScriptUnit.has_extension(local_player_unit, "ability_system")  
    local grenade_ability_max_charges = ability_extension:max_ability_charges("grenade_ability")
    ability_extension:restore_ability_charge("grenade_ability", grenade_ability_max_charges)
end

-- Assist Player
mod.Assist_Player = function(self)
        unit_data_extension = ScriptUnit.has_extension(local_player_unit, "unit_data_system")
        character_state_component = unit_data_extension:read_component("character_state")
        disabled_character_state_component = unit_data_extension:read_component("disabled_character_state")
        is_knocked_down = PlayerUnitStatus.is_knocked_down(character_state_component)
        is_netted = PlayerUnitStatus.is_netted(disabled_character_state_component)
        is_ledge_hanging = PlayerUnitStatus.is_ledge_hanging(disabled_character_state_component)      
        
      if is_knocked_down or is_netted or is_ledge_hanging then
        local assisted_state_input_component = unit_data_extension:write_component("assisted_state_input")
        assisted_state_input_component.force_assist = true
      end
end

-- Despawn All Units
mod.Despawn_Units = function(self)
    Managers.state.minion_spawn:delete_units()
    mod:echo("Despawning all units.")
end

-- Add Buffs Toggled in Menu
mod.Add_Buff = function(self, buff_name)  

    local buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")
    local talent_extension = ScriptUnit.has_extension(local_player_unit, "talent_system")
  ------------------------------------------  
    local t = FixedFrame.get_latest_fixed_time()
    -- local player_buffs = buff_extension:buffs(local_player_unit)
    local added_buff = added_buff
    local buff_duration = buff_duration
    local buff_max_stacks = buff_max_stacks
    local buff_desired_stacks = buff_desired_stacks
    local buff_applied_stacks = buff_applied_stacks

    -- Set buff data from mod_buff_table
    for template, data in pairs(mod_buffs_table) do
        if data["template_name"] == buff_name then
            buff_duration = data["base_duration"]
            buff_max_stacks = data["max_stacks"]
            -- buff_desired_stacks = mod:get(data["desired_stacks"])
            if mod:get(data["desired_stacks"]) then
                buff_desired_stacks = mod:get(data["desired_stacks"])
            else
                buff_desired_stacks = data["desired_stacks"]
            end
        end
    end

    buff_applied_stacks = math.min(buff_max_stacks, buff_desired_stacks)

    if buff_name == "zealot_fanatic_rage" then
        for i = 1, #player_buffs do
            if player_buffs[i]:template_name() == "zealot_fanatic_rage" then 
                blazing_piety = i            
            end
        end

        local  _fanatic_rage_add_stack  = function(template_data, template_context)
            local current_resource = template_data.talent_resource_component.current_resource
            local max_resource = template_data.talent_resource_component.max_resource
            local t = FixedFrame.get_latest_fixed_time()
        
            current_resource = math.min(max_resource, current_resource + 1)
        
            if current_resource == max_resource then
                Managers.stats:record_private("hook_zealot_fanatic_rage_start", template_context.player)
                template_data.buff_extension:add_internally_controlled_buff("zealot_fanatic_rage_buff", t)
            end
        
            template_data.talent_resource_component.current_resource = current_resource
            template_data.remove_stack_t = t + 8
            --wierd prob not gonna work
            unit_data_extension = ScriptUnit.has_extension(local_player_unit, "unit_data_system")
            template_data.talent_resource_component = unit_data_extension:write_component("talent_resource")
        end
       
        for i = 1, buff_applied_stacks do
            _fanatic_rage_add_stack(player_buffs[blazing_piety]:template_data(), player_buffs[blazing_piety]:template_context())
        end

        for i = 1, #player_buffs do
            if player_buffs[i]:template_name() == "zealot_fanatic_rage_buff" then 
                added_buff = i            
            end
        end
        if added_buff then
            -- mod:echo("reset duration working")
            player_buffs[added_buff]._template.duration = buff_duration
        else
            -- mod:echo("doesn't work buddy")
        end
    else
        buff_extension: add_internally_controlled_buff_with_stacks(buff_name, buff_applied_stacks, t, "owner_unit", local_player_unit)
        for i = 1, #player_buffs do
            if player_buffs[i]:template_name() == buff_name then 
                added_buff = i            
            end
        end
        player_buffs[added_buff]._template.duration = buff_duration  
    end

end

mod.Remove_Buff = function(self, buff_name)

    local buff_extension = ScriptUnit.has_extension(local_player_unit, "buff_system")
    local t = FixedFrame.get_latest_fixed_time()
    
    local buffs = buff_extension:buffs(local_player_unit)
    local removed_buff = removed_buff
    set_effected_buffs_table()
    -- while current_buff_stacks > 0 do

    if buff_name == "zealot_fanatic_rage" then
        for i = 1, #buffs do
            if buffs[i]:template_name() == "zealot_fanatic_rage_buff" then 
                removed_buff = i            
            end
        end     
    else
        for i = 1, #buffs do
            if buffs[i]:template_name() == buff_name then 
                removed_buff = i            
            end
        end        
    end

    if removed_buff then
        buffs[removed_buff]._template.duration = 0.00
    end

    mod.update = function()
    end
end

-- mod.test_func_2 = function()
--     local local_player = get_player()
--     if not local_player then
--       mod:error("Local player not found.")
--       return
--     end
--     local_player_unit = get_player_unit(local_player)
--     local ability_extension = ScriptUnit.has_extension(local_player_unit, "ability_system")
--     unit_data_extension = ScriptUnit.has_extension(local_player_unit, "unit_data_system")     

--     mod.Reset_Weapon_Ammunition()

-- end