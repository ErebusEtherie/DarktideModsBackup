--[[
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Warp Horror                                                                                                            │
│ Mod Description: Enhanced Venting Shriek automation with Warp Siphon integration, Peril of the Warp Explosion Prevention        │
│ Mod Author: Kevinna (collaboration with CrazyMonkey, author of PsykerAutoQuell)                                                  │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
--]]

local mod = get_mod("WarpHorror")

local attempted_ability_usage = false
local ability_triggered = false
local waiting_on_buff = false
local is_perilous_weapon = false
local is_forcesword = false
local perilous_attacks_disabled = false
local warp_unbound_buff_active = false
local current_peril = 0
local warp_unbound_equipped = false
local venting_shriek_equipped = false
local has_warp_siphon = false
local current_souls = 0
local timer = 0
local perilous_action_sent = false
local quell_time_remaining = 0
local quell_active = false
local auto_ability_activation = true
local auto_unbound_time = 0.4

local perilous_weapons = {
    "forcestaff_p4_m1", "forcestaff_p3_m1", "forcestaff_p2_m1", "forcestaff_p1_m1",
    "psyker_throwing_knives", "psyker_smite", "forcesword_p1_m3", "forcesword_p1_m2",
    "forcesword_p1_m1", "forcesword_2h_p1_m1", "forcesword_2h_p1_m2",
}

local forceswords = {
    "forcesword_p1_m1", "forcesword_p1_m2", "forcesword_p1_m3",
    "forcesword_2h_p1_m1", "forcesword_2h_p1_m2",
}

local peril_threshold = mod:get("peril_threshold")
local debounce_enter_percentage = mod:get("debounce_enter_percentage")
local debounce_exit_time = mod:get("debounce_exit_time")
local auto_quell_threshold = mod:get("auto_quell_threshold")
local auto_quell_duration = mod:get("auto_quell_duration")
local venting_shriek_explosion_threshold = mod:get("venting_shriek_explosion_threshold")
local warp_siphon_integration_enable = mod:get("warp_siphon_integration_enable")
local warp_siphon_peril_threshold = mod:get("warp_siphon_peril_threshold")
local warp_siphon_min_souls = mod:get("warp_siphon_min_souls")
local warp_siphon_auto_quell_fallback = mod:get("warp_siphon_auto_quell_fallback")

mod.on_setting_changed = function(setting_id)
    peril_threshold = mod:get("peril_threshold")
    debounce_enter_percentage = mod:get("debounce_enter_percentage")
    debounce_exit_time = mod:get("debounce_exit_time")
    auto_quell_threshold = mod:get("auto_quell_threshold")
    auto_quell_duration = mod:get("auto_quell_duration")
    venting_shriek_explosion_threshold = mod:get("venting_shriek_explosion_threshold")
    warp_siphon_integration_enable = mod:get("warp_siphon_integration_enable")
    warp_siphon_peril_threshold = mod:get("warp_siphon_peril_threshold")
    warp_siphon_min_souls = mod:get("warp_siphon_min_souls")
    warp_siphon_auto_quell_fallback = mod:get("warp_siphon_auto_quell_fallback")
end

local function get_player()
    if Managers and Managers.state and Managers.state.game_mode then
        local player_manager = Managers.player
        return player_manager and player_manager:local_player(1)
    end
    return false
end

local function update_weapon_status()
    is_perilous_weapon = false
    is_forcesword = false
    local player = get_player()
    if not player then return end
    local player_unit = player.player_unit
    if not player_unit or not Unit.alive(player_unit) then return end
    local weapon_extension = ScriptUnit.has_extension(player_unit, "weapon_system")
    if weapon_extension then
        local weapon_template = weapon_extension:weapon_template()
        if weapon_template and weapon_template.name then
            for _, weapon_name in ipairs(perilous_weapons) do
                if weapon_template.name == weapon_name then
                    is_perilous_weapon = true
                    break
                end
            end
            for _, weapon_name in ipairs(forceswords) do
                if weapon_template.name == weapon_name then
                    is_forcesword = true
                    break
                end
            end
        end
    end
end

local function update_equipped_ability_status()
    warp_unbound_equipped = false
    venting_shriek_equipped = false
    has_warp_siphon = false
    current_souls = 0
    local player = get_player()
    if not player then return end
    local profile = player:profile()
    local has_warp_unbound_talent = profile.talents['psyker_overcharge_stance_infinite_casting'] or 0
    if has_warp_unbound_talent == 1 then
        warp_unbound_equipped = true
    end
    local has_venting_shriek_talent = profile.talents['psyker_shout_vent_warp_charge'] or 0
    if has_venting_shriek_talent == 1 then
        venting_shriek_equipped = true
    end
    -- Check for Warp Siphon keystone
    local has_warp_siphon_talent = profile.talents['psyker_soul_harvest'] or 0
    if has_warp_siphon_talent == 1 then
        has_warp_siphon = true
        local player_unit = player.player_unit
        if player_unit and Unit.alive(player_unit) then
            local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
            if unit_data_extension then
                local talent_resource_component = unit_data_extension:read_component("talent_resource")
                if talent_resource_component then
                    current_souls = talent_resource_component.current_resource or 0
                end
            end
        end
    end
end

local function get_peril_level()
    local player = get_player()
    if not player then return 0 end
    local player_unit = player.player_unit
    if not player_unit or not Unit.alive(player_unit) then return 0 end
    local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
    if unit_data_extension then
        local warp_charge_component = unit_data_extension:read_component("warp_charge")
        if warp_charge_component then
            return warp_charge_component.current_percentage or 0
        end
    end
    return 0
end

local function get_warp_unbound_buff_status()
    local player = get_player()
    if not player then return false end
    local player_unit = player.player_unit
    if not player_unit or not Unit.alive(player_unit) then return false end
    
    local success, buff_extension = pcall(ScriptUnit.extension, player_unit, "buff_system")
    if not success or not buff_extension then return false end

    for _, buff in pairs(buff_extension._buffs_by_index) do
        local template = buff:template()
        if template and template.name == "psyker_overcharge_stance_infinite_casting" then
            return true
        end
    end

    return false
end

local function attack_to_quell(dt)
    if not mod:get("auto_quell_enable") then
        quell_active = false
        quell_time_remaining = 0
        perilous_action_sent = false
        return
    end
    local player = get_player()
    if not player then return end
    current_peril = get_peril_level()
    if perilous_action_sent and current_peril > auto_quell_threshold then
        quell_active = true
        quell_time_remaining = auto_quell_duration
        perilous_action_sent = false
    end
    if quell_active then
        quell_time_remaining = quell_time_remaining - dt
        if quell_time_remaining <= 0 then
            quell_active = false
            quell_time_remaining = 0
        end
    end
end

local function state_debounce()
    if not mod:get("warp_unbound_bug_fix_enable") then return end
    local player = get_player()
    if not player then return end
    local player_unit = player.player_unit
    if not player_unit or not Unit.alive(player_unit) then return end
    current_peril = get_peril_level()
    warp_unbound_buff_active = get_warp_unbound_buff_status()
    if warp_unbound_equipped then
        if current_peril >= debounce_enter_percentage and not warp_unbound_buff_active and not waiting_on_buff then
            perilous_attacks_disabled = true
            waiting_on_buff = true
            ability_triggered = false
        end
        if warp_unbound_buff_active and waiting_on_buff then
            waiting_on_buff = false
            ability_triggered = true
        end
        if warp_unbound_buff_active then
            local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
            if buff_extension then
                local buff = buff_extension:get_first_buff_using_buff_template("psyker_overcharge_stance_infinite_casting")
                if buff then
                    local remaining_time = buff:remaining_duration()
                    if remaining_time and remaining_time <= debounce_exit_time then
                        perilous_attacks_disabled = true
                    else
                        perilous_attacks_disabled = false
                    end
                else
                    perilous_attacks_disabled = false
                end
            else
                perilous_attacks_disabled = false
            end
        else
            perilous_attacks_disabled = false
        end
    end
end

-- Hook into PlayerUnitAbilityExtension to confirm ability is actually used
mod:hook_safe("PlayerUnitAbilityExtension", "use_ability_charge", function(self, ability_type, optional_num_charges)
    if ability_type == "combat_ability" and attempted_ability_usage and warp_unbound_equipped then
        ability_triggered = true
        attempted_ability_usage = false
        waiting_on_buff = true
    end
end)

-- Hook into InputService to disable certain actions when necessary
mod:hook("InputService", "_get", function(func, self, action_name)
    if action_name ~= "action_one_pressed" and
        action_name ~= "action_one_hold" and
        action_name ~= "action_one_release" and
        action_name ~= "action_two_pressed" and
        action_name ~= "action_two_hold" and
        action_name ~= "action_two_release" and
        action_name ~= "weapon_extra_pressed" and
        action_name ~= "weapon_extra_hold" and
        action_name ~= "weapon_extra_release" and
        action_name ~= "weapon_reload" and
        action_name ~= "weapon_reload_hold" and
        action_name ~= "combat_ability_pressed" and
        action_name ~= "combat_ability_hold" and
        action_name ~= "combat_ability_release"
    then
        return func(self, action_name)
    end

    update_equipped_ability_status()
    update_weapon_status()
    current_peril = get_peril_level()
    warp_unbound_buff_active = get_warp_unbound_buff_status()
    perilous_attacks_disabled = false

    if waiting_on_buff and warp_unbound_buff_active and warp_unbound_equipped then
        waiting_on_buff = false
    end

    if mod:get("auto_quell_enable") and (current_peril > auto_quell_threshold) and 
       perilous_action_sent == false and is_perilous_weapon and 
       (not waiting_on_buff) and (not warp_unbound_buff_active) then
        perilous_action_sent = true
    end

    if action_name == "combat_ability_pressed" and auto_ability_activation then
        if mod:get("auto_gaze_enable") and warp_unbound_equipped and warp_unbound_buff_active and (timer < auto_unbound_time) then
            attempted_ability_usage = true
            return true
        end
        if mod:get("auto_vent_enable") and venting_shriek_equipped and current_peril > peril_threshold then
            attempted_ability_usage = true
            return true
        end
        if venting_shriek_equipped and current_peril >= venting_shriek_explosion_threshold then
            attempted_ability_usage = true
            return true
        end
        if warp_siphon_integration_enable and has_warp_siphon and venting_shriek_equipped then
            if current_peril >= warp_siphon_peril_threshold and current_souls >= warp_siphon_min_souls then
                attempted_ability_usage = true
                return true
            end
            if warp_siphon_auto_quell_fallback and current_peril < 0.99 and current_peril > auto_quell_threshold then
                perilous_action_sent = true
            end
        end
    end

    if action_name == "weapon_reload_hold" and quell_active == true then
        return true
    end

    if mod:get("prevent_psyker_explosion_enable") and (current_peril >= peril_threshold) and 
       not waiting_on_buff and not warp_unbound_buff_active then
        perilous_attacks_disabled = true
    end

    if mod:get("warp_unbound_bug_fix_enable") then
        state_debounce()
        if action_name == "combat_ability_hold" and warp_unbound_equipped then
            if func(self, action_name) then
                attempted_ability_usage = true
            end
        end
        if action_name == "combat_ability_release" and func(self, action_name) and ability_triggered and warp_unbound_equipped then
            ability_triggered = false
            attempted_ability_usage = false
        end
    end
    
    if perilous_attacks_disabled and is_perilous_weapon then
        if (not is_forcesword) and (action_name == "action_one_pressed" or action_name == "action_one_hold" or 
            action_name == "action_one_release" or action_name == "action_two_pressed" or 
            action_name == "action_two_hold" or action_name == "action_two_release") then
            return false
        end
        if is_forcesword and (action_name == "weapon_extra_pressed" or action_name == "weapon_extra_hold" or 
            action_name == "weapon_extra_release") then
            return false
        end
        if (current_peril > 0.99) and waiting_on_buff and (action_name == "weapon_reload" or action_name == "weapon_reload_hold") then
            return false
        end
    end

    return func(self, action_name)
end)

function mod.update(dt)
    attack_to_quell(dt)
end

return mod