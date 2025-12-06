local mod = get_mod("BrokerAutoStim")

local PlayerUnitVisualLoadout = require("scripts/extension_systems/visual_loadout/utilities/player_unit_visual_loadout")

local STIMM_SLOT_NAME = "slot_pocketable_small"

local function _debug(message_or_func)
    if not mod:get("enable_debug") then
        return
    end
    local message = type(message_or_func) == "function" and message_or_func() or message_or_func
    mod:echo(message)
end

local AUTO_STIMM_STAGES = {
    NONE = 0,
    SWITCH_TO = 1,
    WAITING_FOR_INJECT = 2,
    SWITCH_BACK = 3,
}

local auto_stimm_stage = AUTO_STIMM_STAGES.NONE
local current_wield_slot = nil
local unwield_to_slot = nil
local input_request = nil
local stage_start_time = nil

local STAGE_TIMEOUTS = {
    [AUTO_STIMM_STAGES.SWITCH_TO] = 3.0,
    [AUTO_STIMM_STAGES.WAITING_FOR_INJECT] = 5.0,
    [AUTO_STIMM_STAGES.SWITCH_BACK] = 3.0,
}

local combat_start_time = nil
local last_injection_time = nil
local last_combat_time = nil
local auto_stim_enabled = true
local last_combat_ability_cooldown = nil
local combat_ability_just_used = false
local combat_ability_just_ended = false
local cached_chem_info = nil
local chem_info_cache_time = nil

local function _get_gameplay_time()
    if Managers.time and Managers.time:has_timer("gameplay") then
        return Managers.time:time("gameplay")
    end
    return nil
end

local function _get_player_unit()
    local plr = Managers.player and Managers.player:local_player_safe(1)
    return plr and plr.player_unit
end

local function _is_local_player(unit)
    local player = Managers.player:local_player(1)
    return player and unit == player.player_unit
end

local function _has_broker_stim()
    local player_unit = _get_player_unit()
    if not player_unit then
        return false
    end
    
    local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
    if not visual_loadout_extension then
        return false
    end
    
    return PlayerUnitVisualLoadout.has_weapon_keyword_from_slot(visual_loadout_extension, STIMM_SLOT_NAME, "pocketable_broker_syringe")
end

local function _has_chemical_dependency()
    local player_unit = _get_player_unit()
    if not player_unit then
        return false
    end
    
    local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
    if not buff_extension then
        return false
    end
    
    return buff_extension:has_buff_using_buff_template("broker_keystone_chemical_dependency") or 
           (buff_extension._stacking_buffs and buff_extension._stacking_buffs["broker_keystone_chemical_dependency_stack"] ~= nil)
end

local function _get_chemical_dependency_info()
    local current_time = _get_gameplay_time()
    if cached_chem_info and chem_info_cache_time and current_time and (current_time - chem_info_cache_time) < 0.1 then
        return cached_chem_info
    end
    
    local player_unit = _get_player_unit()
    if not player_unit then
        cached_chem_info = nil
        chem_info_cache_time = nil
        return nil
    end
    
    local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
    if not buff_extension then
        cached_chem_info = nil
        chem_info_cache_time = nil
        return nil
    end
    
    local buff_instance = buff_extension._stacking_buffs and buff_extension._stacking_buffs["broker_keystone_chemical_dependency_stack"]
    if not buff_instance then
        cached_chem_info = {
            has_keystone = _has_chemical_dependency(),
            current_stacks = 0,
            max_stacks = 3,
            time_until_stack_decay = nil,
            can_gain_stack = true
        }
        chem_info_cache_time = current_time
        return cached_chem_info
    end
    
    local current_stacks = buff_instance:stack_count()
    local max_stacks = buff_instance:max_stacks() or 3
    local duration = buff_instance:duration()
    local start_time = buff_instance:start_time()
    
    if not current_time then
        cached_chem_info = {
            has_keystone = true,
            current_stacks = current_stacks,
            max_stacks = max_stacks,
            time_until_stack_decay = nil,
            can_gain_stack = current_stacks < max_stacks
        }
        chem_info_cache_time = nil
        return cached_chem_info
    end
    
    local time_until_stack_decay = nil
    if duration and start_time then
        local end_time = start_time + duration
        time_until_stack_decay = math.max(0, end_time - current_time)
    end
    
    local can_gain_stack = current_stacks < max_stacks
    
    cached_chem_info = {
        has_keystone = true,
        current_stacks = current_stacks,
        max_stacks = max_stacks,
        time_until_stack_decay = time_until_stack_decay,
        can_gain_stack = can_gain_stack
    }
    chem_info_cache_time = current_time
    return cached_chem_info
end

local function _get_effective_combat_duration()
    local base_duration = mod:get("combat_duration")
    local chem_info = _get_chemical_dependency_info()
    
    if not chem_info or not chem_info.has_keystone then
        return base_duration
    end
    
    if chem_info.can_gain_stack then
        return base_duration
    end
    
    if chem_info.time_until_stack_decay then
        local injection_animation_time = 2.0
        local time_before_decay = math.max(0, chem_info.time_until_stack_decay - injection_animation_time)
        return math.max(base_duration, time_before_decay)
    end
    
    return base_duration
end

local function _mark_combat_started()
    local current_time = _get_gameplay_time()
    if not current_time then
        return
    end
    
    last_combat_time = current_time
    
    if not combat_start_time then
        combat_start_time = current_time
        _debug(function() return "Combat started! Has stim: " .. tostring(_has_broker_stim()) end)
    end
end

local function _is_in_combat()
    if not last_combat_time then
        return false
    end
    
    local current_time = _get_gameplay_time()
    if not current_time then
        return false
    end
    
    local time_since_combat = current_time - last_combat_time
    local combat_timeout = mod:get("out_of_combat_timeout")
    
    return time_since_combat <= combat_timeout
end

local function _can_use_stim()
    local player_unit = _get_player_unit()
    if not player_unit then
        return false
    end
    
    local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")
    if not ability_extension then
        return false
    end
    
    return ability_extension:can_use_ability("pocketable_ability")
end

local function _get_combat_ability_cooldown()
    local player_unit = _get_player_unit()
    if not player_unit then
        return nil
    end
    
    local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")
    if not ability_extension then
        return nil
    end
    
    if not ability_extension:ability_is_equipped("combat_ability") then
        return nil
    end
    
    return ability_extension:remaining_ability_cooldown("combat_ability")
end

local function _reset_auto_stimm_state()
    auto_stimm_stage = AUTO_STIMM_STAGES.NONE
    stage_start_time = nil
    input_request = nil
    unwield_to_slot = nil
end

local function _reset_all_state()
    _reset_auto_stimm_state()
    combat_start_time = nil
    last_injection_time = nil
    last_combat_time = nil
    last_combat_ability_cooldown = nil
    combat_ability_just_used = false
    combat_ability_just_ended = false
    current_wield_slot = nil
    cached_chem_info = nil
    chem_info_cache_time = nil
end

local function _check_stage_timeout()
    if auto_stimm_stage == AUTO_STIMM_STAGES.NONE then
        return false
    end
    
    if not stage_start_time then
        return false
    end
    
    local current_time = _get_gameplay_time()
    if not current_time then
        return false
    end
    
    local timeout = STAGE_TIMEOUTS[auto_stimm_stage]
    if not timeout then
        return false
    end
    
    local time_in_stage = current_time - stage_start_time
    if time_in_stage >= timeout then
        _debug(function()
            local stage_name = auto_stimm_stage == AUTO_STIMM_STAGES.SWITCH_TO and "SWITCH_TO"
                or auto_stimm_stage == AUTO_STIMM_STAGES.WAITING_FOR_INJECT and "WAITING_FOR_INJECT"
                or auto_stimm_stage == AUTO_STIMM_STAGES.SWITCH_BACK and "SWITCH_BACK"
                or "UNKNOWN"
            return string.format("Stage timeout! Resetting from %s after %.2f seconds", stage_name, time_in_stage)
        end)
        _reset_auto_stimm_state()
        return true
    end
    
    return false
end

local function _is_weapon_switching()
    local player_unit = _get_player_unit()
    if not player_unit then
        return false
    end
    
    local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
    if not unit_data_extension then
        return false
    end
    
    local weapon_action_component = unit_data_extension:read_component("weapon_action")
    if not weapon_action_component then
        return false
    end
    
    local current_action_name = weapon_action_component.current_action_name
    return current_action_name == "action_wield" or current_action_name == "action_unwield" or 
           current_action_name == "action_unwield_to_previous" or current_action_name == "action_unwield_to_specific"
end

local function _is_weapon_template_valid(slot_name)
    if not slot_name then
        return false
    end
    
    local player_unit = _get_player_unit()
    if not player_unit then
        return false
    end
    
    local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
    if not visual_loadout_extension then
        return false
    end
    
    local success, weapon_template = pcall(function()
        return visual_loadout_extension:weapon_template_from_slot(slot_name)
    end)
    
    if not success then
        return false
    end
    
    return weapon_template ~= nil
end

local function _start_auto_inject()
    if not _has_broker_stim() then
        return false
    end
    
    if not _can_use_stim() then
        return false
    end
    
    if _is_weapon_switching() then
        return false
    end
    
    if not _is_weapon_template_valid(STIMM_SLOT_NAME) then
        return false
    end
    
    local current_time = _get_gameplay_time()
    if current_wield_slot == STIMM_SLOT_NAME then
        auto_stimm_stage = AUTO_STIMM_STAGES.WAITING_FOR_INJECT
        stage_start_time = current_time
        _debug("Stim already wielded, waiting for auto-inject...")
    else
        if not _is_weapon_template_valid(current_wield_slot) then
            return false
        end
        auto_stimm_stage = AUTO_STIMM_STAGES.SWITCH_TO
        stage_start_time = current_time
        _debug("Wielding stim for auto-inject...")
    end
    
    return true
end

mod.toggle_auto_stim = function(keybind_is_pressed)
    if not keybind_is_pressed then
        return
    end
    
    auto_stim_enabled = not auto_stim_enabled
    mod:echo("Auto-stim " .. (auto_stim_enabled and "enabled" or "disabled"))
end

mod.update = function(dt)
    if not auto_stim_enabled then
        return
    end
    
    if auto_stimm_stage ~= AUTO_STIMM_STAGES.NONE then
        _check_stage_timeout()
        return
    end
    
    local chem_info = _get_chemical_dependency_info()
    local has_chemical_dependency = chem_info and chem_info.has_keystone
    
    if mod:get("only_with_chemical_dependency") and not has_chemical_dependency then
        return
    end
    
    local current_combat_ability_cooldown = _get_combat_ability_cooldown()
    if last_combat_ability_cooldown ~= nil and current_combat_ability_cooldown ~= nil then
        if last_combat_ability_cooldown == 0 and current_combat_ability_cooldown > 0 then
            combat_ability_just_ended = true
            _debug("Combat ability cooldown started")
        end
    end
    last_combat_ability_cooldown = current_combat_ability_cooldown
    
    local effective_duration = _get_effective_combat_duration()
    local in_combat = _is_in_combat()
    local stim_trigger_mode = mod:get("stim_trigger_mode")
    
    local should_process = false
    if stim_trigger_mode == "on_ability_use" then
        should_process = combat_ability_just_used
    elseif stim_trigger_mode == "after_ability_end" then
        should_process = combat_ability_just_ended
    elseif stim_trigger_mode == "combat_only" then
        should_process = in_combat and combat_start_time ~= nil
    elseif stim_trigger_mode == "non_combat_only" then
        should_process = not in_combat
    elseif stim_trigger_mode == "always_stim" then
        should_process = true
    end
    
    if should_process then
        local current_time = _get_gameplay_time()
        if not current_time then
            return
        end
        
        local time_since_last_injection = last_injection_time and (current_time - last_injection_time) or math.huge
        local time_in_combat = combat_start_time and (current_time - combat_start_time) or 0
        
        local should_check_injection = false
        if stim_trigger_mode == "on_ability_use" or stim_trigger_mode == "after_ability_end" then
            should_check_injection = true
        elseif stim_trigger_mode == "always_stim" then
            should_check_injection = time_since_last_injection >= effective_duration
        elseif stim_trigger_mode == "combat_only" then
            if not last_injection_time then
                should_check_injection = time_in_combat >= effective_duration
            else
                should_check_injection = time_since_last_injection >= effective_duration
            end
        elseif stim_trigger_mode == "non_combat_only" then
            should_check_injection = time_since_last_injection >= effective_duration
        end
        
        if should_check_injection then
            local has_stim = _has_broker_stim()
            
            if chem_info and chem_info.has_keystone then
                _debug(function()
                    local time_until_decay_str = chem_info.time_until_stack_decay and string.format("%.2f", chem_info.time_until_stack_decay) or "N/A"
                    return string.format("Duration reached! Time since last: %.2f Effective: %.2f Stacks: %d/%d Time until decay: %s", 
                        time_since_last_injection, effective_duration, chem_info.current_stacks, chem_info.max_stacks, time_until_decay_str)
                end)
            else
                _debug(function() return "Duration reached! Time since last: " .. string.format("%.2f", time_since_last_injection) .. " Has stim: " .. tostring(has_stim) end)
            end
            
            if has_stim then
                if not _is_weapon_template_valid(STIMM_SLOT_NAME) then
                    _debug("Stim template not ready yet, waiting...")
                else
                    local can_use = _can_use_stim()
                    if not can_use then
                        _debug("Stim is on cooldown, waiting...")
                    elseif not chem_info or chem_info.can_gain_stack or (chem_info.time_until_stack_decay and chem_info.time_until_stack_decay <= 2.0) then
                        _debug("Starting auto-inject!")
                        if _start_auto_inject() then
                            last_injection_time = current_time
                            if stim_trigger_mode == "on_ability_use" or stim_trigger_mode == "after_ability_end" then
                                combat_ability_just_used = false
                                combat_ability_just_ended = false
                            end
                        end
                    else
                        _debug(function() return string.format("Waiting for Chemical Dependency stack to decay (%.2f seconds remaining)...", chem_info.time_until_stack_decay) end)
                    end
                end
            else
                _debug("No broker stim found!")
            end
        end
    elseif not in_combat and stim_trigger_mode ~= "always_stim" and stim_trigger_mode ~= "non_combat_only" then
        if combat_start_time then
            _debug("Combat ended")
        end
        combat_start_time = nil
        if stim_trigger_mode == "combat_only" then
            last_injection_time = nil
        end
        last_combat_time = nil
    end
end


mod:hook_safe(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage,
                                                                       attack_result, attack_type, damage_efficiency, ...)
    if _is_local_player(attacking_unit) or _is_local_player(attacked_unit) then
        _mark_combat_started()
    end
end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self, slot_name, ...)
    if self._player == Managers.player:local_player(1) then
        current_wield_slot = slot_name
        if auto_stimm_stage == AUTO_STIMM_STAGES.SWITCH_BACK then
            if input_request and (not unwield_to_slot or slot_name == unwield_to_slot) then
                _reset_auto_stimm_state()
                _debug("Switched back, injection complete")
            end
        elseif auto_stimm_stage == AUTO_STIMM_STAGES.SWITCH_TO and slot_name == STIMM_SLOT_NAME then
            local current_time = _get_gameplay_time()
            auto_stimm_stage = AUTO_STIMM_STAGES.WAITING_FOR_INJECT
            stage_start_time = current_time
            _debug("Stim wielded, waiting for auto-inject...")
        end
    end
end)

mod:hook_safe(CLASS.ActionHandler, "start_action", function(self, id, action_objects, action_name, action_params, action_settings, used_input, ...)
    if _get_player_unit() == self._unit then
        if id == "combat_ability_action" then
            combat_ability_just_used = true
            _debug("Combat ability button pressed - action starting")
        end
        
        if auto_stimm_stage == AUTO_STIMM_STAGES.SWITCH_BACK and (action_name == "action_unwield_to_previous" or action_name == "action_wield") and used_input ~= "quick_wield" then
            input_request = unwield_to_slot == "slot_secondary" and "wield_2"
                or unwield_to_slot == "slot_grenade_ability" and "grenade_ability_pressed"
                or "wield_1"
            unwield_to_slot = input_request == "wield_1" and "slot_primary"
                or input_request == "wield_2" and "slot_secondary"
                or input_request == "grenade_ability_pressed" and "slot_grenade_ability"
                or nil
        elseif action_name == "action_wield" then
            local slot_name = self._inventory_component.wielded_slot
            unwield_to_slot = slot_name ~= STIMM_SLOT_NAME and slot_name or unwield_to_slot
        elseif auto_stimm_stage == AUTO_STIMM_STAGES.WAITING_FOR_INJECT and current_wield_slot == STIMM_SLOT_NAME and action_name == "action_use_self" then
            _debug("Auto-inject detected! Will switch back after injection completes")
            local current_time = _get_gameplay_time()
            auto_stimm_stage = AUTO_STIMM_STAGES.SWITCH_BACK
            stage_start_time = current_time
            last_injection_time = current_time
        end
    end
end)

local _input_action_hook = function(func, self, action_name)
    local val = func(self, action_name)
    
    return input_request and action_name == input_request
        or auto_stimm_stage == AUTO_STIMM_STAGES.SWITCH_TO and action_name == "wield_4"
        or val
end
mod:hook(CLASS.InputService, "_get", _input_action_hook)
mod:hook(CLASS.InputService, "_get_simulate", _input_action_hook)

mod.on_game_state_changed = function(status, state_name)
    if status == "enter" and state_name == "StateGameplay" then
        _reset_all_state()
    end
end

Managers.event:register(mod, "player_unit_spawned", function(player)
    if player == Managers.player:local_player(1) then
        _reset_all_state()
    end
end)



