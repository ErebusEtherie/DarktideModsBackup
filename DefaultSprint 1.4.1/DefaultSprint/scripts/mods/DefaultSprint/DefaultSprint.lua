-- @Author: 我是派蒙啊
-- @Date:   2024-04-26 12:07:26
-- @Last Modified by:   我是派蒙啊
-- @Last Modified time: 2024-12-14 13:56:30
local mod = get_mod("DefaultSprint")
mod.settings = mod:persistent_table("settings")

local weapon_name = "unknown"
local current_slot = "slot_primary"
local is_sprint_allowed = true
local is_hold_walk = false
local is_attacking = false
local attacking_time = 0.0

mod.update = function(dt)
    if attacking_time > 0 then
        is_attacking = true
        attacking_time = attacking_time - dt
    else
        attacking_time = 0
        is_attacking = false
    end
end

mod.toggle_sprint = function()
    is_sprint_allowed = not is_sprint_allowed
end

mod.hold_to_walk = function(held)
    is_hold_walk = held
end

mod.on_setting_changed = function(setting_id)
    mod.settings[setting_id] = mod:get(setting_id)
end

local function initialize_settings_cache()
    mod.settings["walk_speed"] = mod:get("walk_speed")
    mod.settings["disable_for_staff"] = mod:get("disable_for_staff")
    mod.settings["disable_for_range"] = mod:get("disable_for_range")
    mod.settings["disable_when_charge"] = mod:get("disable_when_charge")
end
initialize_settings_cache()

local get_local_player = function()
    return Managers.player:local_player(1)
end

local get_equip_weapon = function()
    local player = get_local_player()
    local profile = player._profile
    local slot = current_slot or "slot_primary"
    local weapon = profile.loadout[slot]
    if not weapon then return "" end
    -- mod:echo(weapon.display_name)
    return weapon.display_name
end

mod:hook_safe("PlayerUnitWeaponExtension", "on_slot_wielded",
    function(self, slot_name, t, skip_wield_action)
        if self._player.viewport_name == "player1" then
            current_slot = slot_name
        end
    end)

local is_walk_act = function(act)
    return act == "move_right"
        or act == "move_left"
        or act == "move_forward"
        or act == "move_backward"
end

local SPRINT_WEAPONS =
{
    "loc_combatknife_p1_m1",
    "loc_combatknife_p1_m2",
    "loc_combatsword_p3_m1",
    "loc_combatsword_p3_m2",
    "loc_combatsword_p3_m3",
    "loc_dual_shivs_p1_m1",
    "loc_dual_shivs_p1_m2",
    -- "loc_powersword_2h_p1_m1",
    -- "loc_powersword_2h_p1_m2",
}

local _input_action_hook = function(func, self, action_name)
    -- Game not start.
    if not Managers.state.game_mode or not is_sprint_allowed then return func(self, action_name) end
    -- Check for hold walk.
    if is_hold_walk then
        if is_walk_act(action_name) then return mod.settings["walk_speed"] * func(self, action_name) end
        if action_name == "sprinting" then return false end
        return func(self, action_name)
    end

    -- Get equiped weapon name
    weapon_name = get_equip_weapon()
    -- mod:echo("weapon_name: " .. weapon_name)
    -- Disable sprint for all range weapons
    if mod.settings["disable_for_range"] and current_slot == "slot_secondary" then return func(self, action_name) end
    -- Disable sprint for all staff weapons
    if mod.settings["disable_for_staff"] and weapon_name:find("staff") then return func(self, action_name) end

    -- Check for attack actions
    -- if action_name == "action_one_hold" and func(self, "action_one_hold") then
    --     -- Disable sprint when melee is charging
    --     is_attacking = mod.settings["disable_when_charge"] and current_slot == "slot_primary"
    --     if is_attacking then attacking_time = 3.0 end
    -- end
    -- if action_name == "action_one_released" and func(self, "action_one_released") then
    --     is_attacking = true
    -- end

    -- Sprint action
    if action_name == "sprinting" then
        -- Firstly, handle sprint weapon, if it could sprint, then let's sprint
        for k, v in ipairs(SPRINT_WEAPONS) do
            if weapon_name == v then return true end
        end

        -- mod:echo("is_attacking: " .. tostring(is_attacking) .. " attacking_time: " .. attacking_time)
        -- Secondly, check attack action, if attack not finish, then continue walk
        if is_attacking then return false end

        -- Finally, let's sprint~~
        return true
    end

    -- Origin action
    return func(self, action_name)
end

-- local is_interrupt_action = function(act)
--     return act == "action_block"
--         or act == "action_wield"
--         or act == "action_unwield"
--         or act == "grenade_ability"
-- end

local is_unsprint_action = function(act)
    -- mod:echo("unsprint_action: " .. act .. " .. ".. weapon_name)
    return act:find("melee_start")
        or act:find("light")
        or act:find("left_heavy")
        or act:find("right_heavy")
        or act:find("action_heavy")
        or act:find("rapid")                             -- staffs
        or act == "action_zealot_channel"      -- Zealot Channel
        or act == "action_spread_charged"    -- Psyker Smite
end

mod:hook_safe("ActionHandler", "start_action",
    function(self, id, action_objects, action_name, action_params, action_settings, ...)
        -- print("action_name: " .. action_name)
        -- mod:echo("action_name: " .. action_name)

        -- Power Sword sprint attack
        if weapon_name:find("loc_powersword_") and action_name == "action_melee_start_sprint" then
            is_attacking = false
            attacking_time = 0
            return
        end

        -- Check for action continued time
        if is_unsprint_action(action_name) then
            local action_time = self:_calculate_action_total_time(action_settings, action_params,
                self:_calculate_time_scale(action_settings))

            -- print("action_name: " .. action_name .. " | action_time: " .. action_time)
            -- mod:echo("action_name: " .. action_name .. " | action_time: " .. action_time)

            -- It was shown that the action only needs about 1/2 time to finish itself, unless the start attack action or zealot channel.
            if not action_name:find("start") then
                action_time = action_time / 2
            end
            -- If the action time is less than 0.5, we should set it to 0.5 to prevent the action from being interrupted.
            if action_time < 0.5 then
                action_time = 0.5
            end
            attacking_time = action_time
            is_attacking = true
            
            -- mod:echo("attacking_time: " .. attacking_time)
            return
        -- -- If we triggered these action, time should be reset.
        -- elseif is_interrupt_action(action_name) then
        --     is_attacking = false
        --     attacking_time = 0
        end

        is_attacking = false
        attacking_time = 0
    end)

-- local is_finish_reason = function(reason)
--     return reason == "action_complete"
--         or reason == "hold_input_released"
--         or reason == "unwield"
-- end

-- mod:hook_safe("ActionHandler", "_finish_action",
--     function(self, handler_data, reason, data, t, next_action_params)
--         -- print("reason: " .. reason)
--         -- mod:echo("reason: " .. reason)
--         if is_finish_reason(reason) then is_attacking = false end
--     end)

mod:hook(CLASS.InputService, "_get", _input_action_hook)
mod:hook(CLASS.InputService, "_get_simulate", _input_action_hook)
