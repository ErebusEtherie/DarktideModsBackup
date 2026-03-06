local mod                   = get_mod("BetterMovement")
local constants             = require("scripts/settings/player_character/player_character_constants")
local ActionAvailability    = require("scripts/extension_systems/weapon/utilities/action_availability")
local ActionHandlerSettings = require("scripts/settings/action/action_handler_settings")
local Sprint                = require(
    "scripts/extension_systems/character_state_machine/character_states/utilities/sprint")


-- Global Cache
local CLASS                      = CLASS
local ScriptUnit                 = ScriptUnit
local Managers                   = Managers
local Vector3                    = Vector3
local vector3_length_squared     = Vector3.length_squared
local vector3_flat               = Vector3.flat
local vector3_normalize          = Vector3.normalize
local math_abs                   = math.abs
local table_clear                = table.clear

-- Plater Cache
local player                     = nil

-- Extensions Cache
local playerBuffExtension        = nil
local playerWeaponExtension      = nil
local playerActionInputExtension = nil

-- Movement Component Cache
local movement_components        = {}

-- Mod settings
local mod_settings               = {
    debug_enabled           = mod:get("debug_enabled"),           -- print some dev gibberish
    better_sprint           = mod:get("better_sprint"),           -- no more toggle sprint off, hold to sprint even in toggle sprint mode, keep sprinting after sliding, jumping, vaulting
    always_sprint           = mod:get("always_sprint"),           -- always sprint, only stop when release mover forward button
    toggle_sprint           = mod:get("toggle_sprint"),           -- toggle continuous sprint on and off with sprint button
    hold_to_sprint          = mod:get("hold_to_sprint"),          -- hold to sprint
    hold_to_walk            = mod:get("hold_to_walk"),            -- hold to walk
    prevent_accidental_jump = mod:get("prevent_accidental_jump"), -- no more unwanted jump when spam dodge button
    sprint_dodge            = mod:get("sprint_dodge"),            -- dodge while sprinting
    easy_dodge_slide        = mod:get("easy_dodge_slide"),        -- double tap dodge to slide
    hold_dodge_slide        = mod:get("hold_dodge_slide"),        -- hold dodge key to slide while dodging
    keep_dodging            = mod:get("keep_dodging"),            -- hold dodge key to keep dodging
    easy_sprint_slide       = mod:get("easy_sprint_slide"),       -- press dodge button to slide forward while sprinting
    auto_vault              = mod:get("auto_vault"),              -- auto vault when airborne
}

-- Game Settings
local hold_to_crouch             = true
local diagonal_forward_dodge     = true
local stationary_dodge           = false
local always_dodge               = false

-- Mod Status
local mod_enabled                = false

-- Player Movement Status
local previous_state_name        = "walking"
local current_state_name         = "walking"
local is_in_hub                  = false
local time_in_dodge              = 0
local no_sprinting_bug_fix       = false
local no_sprinting_stamina       = false
local sprint_action_settings     = nil

-- Input Cache
local sprint_press               = false
local crouch_hold                = false
local move_forward               = 0
local move_backward              = 0
local move_left                  = 0
local move_right                 = 0
local dodge_hold                 = false
local dodge_hold_start_time      = nil

-- Fake Input Flag
local attempt_dodge_slide        = false
local attempt_sprint_slide       = false
local attempt_sprint             = false
local attempt_sprint_dodge       = false

-- Print debug messages
local function print_debug(...)
    if mod_settings.debug_enabled then
        local n = select("#", ...)
        if n == 0 then
            return
        end
        local result = tostring(select(1, ...))
        for i = 2, n do
            local value = select(i, ...)
            result = result .. " " .. tostring(value)
        end
        mod:echo(tostring(result))
    end
end

-- Reset movement parameters
local function reset_params()
    -- Player movement stats
    previous_state_name    = "walking"
    current_state_name     = "walking"
    is_in_hub              = false
    time_in_dodge          = 0
    no_sprinting_bug_fix   = false
    no_sprinting_stamina   = false
    sprint_action_settings = nil
    -- Input Cache
    sprint_press           = false
    crouch_hold            = false
    move_forward           = 0
    move_backward          = 0
    move_left              = 0
    move_right             = 0
    dodge_hold             = false
    dodge_hold_start_time  = nil
    -- Fake Input Flag
    attempt_dodge_slide    = false
    attempt_sprint_slide   = false
    attempt_sprint         = false
    attempt_sprint_dodge   = false
end

-- Get Extensions
local function get_player_data_extension()
    return player and ScriptUnit.extension(player.player_unit, "unit_data_system")
end

local function get_player_buff_extension()
    return player and ScriptUnit.extension(player.player_unit, "buff_system")
end

local function get_player_weapon_extension()
    return player and ScriptUnit.extension(player.player_unit, "weapon_system")
end

local function get_player_action_input_extension()
    return player and ScriptUnit.extension(player.player_unit, "action_input_system")
end

-- Init Player Cache
local function init_player()
    local result = Managers.player:local_player_safe(1)
    if result then
        player = result
    end
end

-- Init Extensions Cache
local function init_extensions()
    local result = get_player_buff_extension()
    if result then
        playerBuffExtension = result
    end
    result = get_player_weapon_extension()
    if result then
        playerWeaponExtension = result
    end
    result = get_player_action_input_extension()
    if result then
        playerActionInputExtension = result
    end
end

-- Init Movement Component Cache
local function init_movement_component(playerDataExtension)
    playerDataExtension = playerDataExtension or get_player_data_extension()
    if not playerDataExtension then
        return
    end

    print_debug("Init movement component")
    movement_components.movement_state = playerDataExtension:read_component("movement_state")
    movement_components.hub_jog_character_state = playerDataExtension:read_component("hub_jog_character_state")
    movement_components.sprint_character_state = playerDataExtension:read_component("sprint_character_state")
    movement_components.dodge_character_state = playerDataExtension:read_component("dodge_character_state")
    movement_components.locomotion = playerDataExtension:read_component("locomotion")
end

-- Init Cache
local function init_cache()
    init_player()
    init_extensions()
    init_movement_component()
end

local function init_game_settings()
    hold_to_crouch         = Managers.save:account_data().input_settings.hold_to_crouch
    diagonal_forward_dodge = Managers.save:account_data().input_settings.diagonal_forward_dodge
    stationary_dodge       = Managers.save:account_data().input_settings.stationary_dodge
    always_dodge           = Managers.save:account_data().input_settings.always_dodge
end

-- Turn on Hold to Sprint if Better Sprint Enabled
local function enable_hold_to_sprint()
    if not mod_settings.better_sprint or not mod_enabled then
        return
    end

    local input_settings = Managers.save:account_data().input_settings
    if not input_settings.hold_to_sprint then
        input_settings.hold_to_sprint = true
    end
end

-- Solve Conflict settings
local conflict_setting_ids = {
    toggle_sprint = true,
    hold_to_sprint = true,
    hold_to_walk = true,
}
local function handle_conflict_settings(setting_id, result)
    if not conflict_setting_ids[setting_id] or not result then
        return
    end

    for conflict_setting_id, _ in pairs(conflict_setting_ids) do
        if conflict_setting_id ~= setting_id then
            mod:set(conflict_setting_id, false, true)
        end
    end
end

local function init_conflict_settings()
    for setting_id, _ in pairs(conflict_setting_ids) do
        handle_conflict_settings(setting_id, mod_settings[setting_id])
    end
end

-- Check if player is in hub
local function check_is_in_hub()
    local gameModeManager = Managers.state.game_mode
    is_in_hub = gameModeManager and (gameModeManager:is_social_hub() or gameModeManager:is_prologue_hub())
    print_debug("is in hub:", is_in_hub)
end

-- Time for Now
local function main_time()
    return Managers.time:time("main")
end

-- Check if slide action is valid
local function can_dodge_slide()
    if not movement_components.locomotion or not movement_components.dodge_character_state then
        return true
    end

    local velocity = movement_components.locomotion.velocity_current
    if not velocity then
        return true
    end

    local started_from_crouch = movement_components.dodge_character_state.started_from_crouch
    local distance_left = movement_components.dodge_character_state.distance_left
    local current_length_sq = vector3_length_squared(vector3_flat(velocity))
    local slide_threshold_sq = constants.slide_move_speed_threshold_sq
    return
        not started_from_crouch
        and distance_left > 0
        and current_length_sq > slide_threshold_sq
end

-- Check if player is sprinting or sprint-jumping
local function is_sprint_jumping()
    if is_in_hub then
        if not movement_components.hub_jog_character_state then
            return false
        end

        return movement_components.hub_jog_character_state.move_state == "sprint"
    else
        if not movement_components.sprint_character_state then
            return false
        end

        return movement_components.sprint_character_state.is_sprinting
            or movement_components.sprint_character_state.is_sprint_jumping
    end
end

-- Check if player's move input can dodge
local function is_dodge_direction()
    local move = Vector3(move_right - move_left, move_forward - move_backward, 0)
    local normalized_move = vector3_normalize(move)
    local y = normalized_move.y
    local x = normalized_move.x
    return
        y < 0 or (y == 0 and x ~= 0)
        or (diagonal_forward_dodge and y > 0 and math_abs(x) > 0.707)
        or (stationary_dodge and y == 0 and x == 0)
        or always_dodge
end

-- Check if jump action is valid
local function can_jump()
    if current_state_name == "sprinting" and not mod_settings.sprint_dodge then
        return true
    end

    return not is_dodge_direction()
end

-- Check if player has move input
local function has_move_input()
    if is_in_hub then
        return move_forward ~= move_backward or move_right ~= move_left
    else
        return move_forward - move_backward > 0
    end
end

-- Check if sprinting is valid
local function is_sprinting_valid()
    if not playerBuffExtension or not playerWeaponExtension or not playerActionInputExtension then
        return true
    end

    local weapon_action_input = playerActionInputExtension:peek_next_input("weapon_action")
    if not weapon_action_input then
        return true
    end

    local action_settings = playerWeaponExtension:action_settings_from_action_input(weapon_action_input)
    if not action_settings then
        return true
    end

    local allowed_during_sprint, buff_keyword_allows_action_during_sprint =
        ActionAvailability.available_in_sprint(action_settings, playerBuffExtension)
    local requires_press_to_interrupt = Sprint.requires_press_to_interrupt(action_settings)
    local no_interruption_for_sprint = Sprint.no_interruption_for_sprint(action_settings)
    if buff_keyword_allows_action_during_sprint or allowed_during_sprint or requires_press_to_interrupt or no_interruption_for_sprint then
        return true
    end

    print_debug("next action will be interrupted by sprinting")
    return false
end

-- Input action hook, simulate action inputs based on movement states for player
local function input_service_hook(func, self, action_name)
    local result = func(self, action_name)
    if action_name == "sprint" then
        -- sprint input control continuous sprint
        if mod_settings.better_sprint then
            if mod_settings.hold_to_sprint then
                -- do nothing
            elseif mod_settings.hold_to_walk then
                result = false
            elseif mod_settings.toggle_sprint then
                if result then
                    attempt_sprint = not attempt_sprint
                    result = attempt_sprint
                end
            else
                attempt_sprint = attempt_sprint or result
            end
            if result then
                sprint_press = true
                no_sprinting_bug_fix = false
                no_sprinting_stamina = false
            end
        end
    elseif action_name == "sprinting" then
        -- sprinting input control continuous sprint
        if mod_settings.better_sprint then
            if mod_settings.hold_to_sprint then
                attempt_sprint = result
            elseif mod_settings.hold_to_walk then
                attempt_sprint = not result
            elseif mod_settings.toggle_sprint then
                -- do nothing
            else
                if result then
                    attempt_sprint = true
                    no_sprinting_stamina = false
                end
            end
            if not has_move_input() then
                sprint_press = false
                attempt_sprint = mod_settings.toggle_sprint and attempt_sprint or false
            end
        end
        -- sprint dodge stop sprint
        if mod_settings.sprint_dodge and attempt_sprint_dodge then
            return false
        end
        -- continous sprint for game's hold-to-sprint
        if mod_settings.better_sprint then
            if sprint_press then
                return true
            end
            return attempt_sprint and not no_sprinting_bug_fix and not no_sprinting_stamina and is_sprinting_valid()
        end
    elseif action_name == "move_forward" then
        move_forward = result
    elseif action_name == "move_backward" then
        move_backward = result
    elseif action_name == "move_left" then
        move_left = result
    elseif action_name == "move_right" then
        move_right = result
    elseif action_name == "jump" then
        if mod_settings.prevent_accidental_jump then
            if current_state_name == "dodging" then
                return false
            elseif
                (current_state_name == "walking" or current_state_name == "sprinting")
                and not can_jump()
            then
                return false
            end
        end
    elseif action_name == "jump_held" then
        if
            mod_settings.auto_vault
            and (current_state_name == "jumping" or current_state_name == "falling")
        then
            return true
        end
    elseif action_name == "dodge" then
        if result then
            dodge_hold = true
            dodge_hold_start_time = main_time()
        end
        if not func(self, "dodge_hold") then
            dodge_hold = false
            dodge_hold_start_time = nil
        end
        if current_state_name == "dodging" then
            if mod_settings.easy_dodge_slide then
                attempt_dodge_slide = attempt_dodge_slide or result
            end
            if mod_settings.hold_dodge_slide then
                attempt_dodge_slide =
                    attempt_dodge_slide
                    or dodge_hold and time_in_dodge > 0.2 and main_time() - dodge_hold_start_time > 0.2
            end
        elseif is_sprint_jumping() then
            if
                mod_settings.sprint_dodge
                and current_state_name == "sprinting"
                and is_dodge_direction()
            then
                attempt_sprint_dodge =
                    attempt_sprint_dodge
                    or result
                    or mod_settings.keep_dodging and dodge_hold
            elseif mod_settings.easy_sprint_slide then
                attempt_sprint_slide = attempt_sprint_slide or result
            end
        elseif current_state_name == "walking" then
            if mod_settings.sprint_dodge and attempt_sprint_dodge then
                if is_dodge_direction() then
                    return true
                else
                    attempt_sprint_dodge = false
                end
            end
            if mod_settings.keep_dodging and dodge_hold then
                return true
            end
        end
    elseif action_name == "crouching" then
        crouch_hold = result
        if hold_to_crouch then
            if mod_settings.easy_dodge_slide or mod_settings.hold_dodge_slide then
                if
                    current_state_name == "dodging"
                    and attempt_dodge_slide
                    and can_dodge_slide()
                then
                    return true
                end
            end
            if mod_settings.easy_sprint_slide then
                if is_sprint_jumping() and attempt_sprint_slide then
                    return true
                end
            end
        end
    elseif action_name == "crouch" then
        if not hold_to_crouch then
            if mod_settings.easy_dodge_slide or mod_settings.hold_dodge_slide then
                if
                    current_state_name == "dodging"
                    and attempt_dodge_slide
                    and not movement_components.movement_state.is_crouching
                    and can_dodge_slide()
                then
                    return true
                end
            end
            if mod_settings.easy_sprint_slide then
                if
                    is_sprint_jumping()
                    and attempt_sprint_slide
                    and not movement_components.movement_state.is_crouching
                then
                    return true
                end
            end
        end
    end
    return result
end

--  Mod Enabled
mod.on_enabled = function()
    mod_enabled = true
    init_cache()
    init_game_settings()
    enable_hold_to_sprint()
    check_is_in_hub()
end

--  Mod Disabled
mod.on_disabled = function()
    mod_enabled = false
    reset_params()
end

mod.on_all_mods_loaded = function()
    init_cache()
    init_game_settings()
    init_conflict_settings()
    enable_hold_to_sprint()
    check_is_in_hub()
end

mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then
            init_game_settings()
            enable_hold_to_sprint()
            check_is_in_hub()
        elseif status == "exit" then
            reset_params()
        end
    end
end

mod.on_setting_changed = function(setting_id)
    local result = mod:get(setting_id)
    mod_settings[setting_id] = result
    handle_conflict_settings(setting_id, result)
    if setting_id == "better_sprint" and result then
        enable_hold_to_sprint()
    end
end

-- HOOKS
local function on_state_change()
    if current_state_name == "sprinting" then
        sprint_press = false
    else
        attempt_sprint_slide = false
    end

    if current_state_name ~= "dodging" then
        attempt_dodge_slide = false
        time_in_dodge = 0
    end

    if current_state_name == "sliding" then
        attempt_sprint_slide = false
        attempt_dodge_slide = false
    end

    if current_state_name == "walking" then
        if
            not mod_settings.always_sprint
            and not mod_settings.toggle_sprint
            and not mod_settings.hold_to_sprint
            and not mod_settings.hold_to_walk
            and previous_state_name == "sliding"
            and crouch_hold
        then
            attempt_sprint = false
        end
    else
        attempt_sprint_dodge = false
    end
end

-- Hook CharacterStateMachine for Movement State
mod:hook_safe(CLASS.CharacterStateMachine, "_change_state", function(self, unit, dt, t, next_state, params)
    if self._unit_data_extension._player.viewport_name == 'player1' then
        previous_state_name = current_state_name
        current_state_name = next_state
        on_state_change()
        print_debug("local player state", current_state_name)
    end
end)

mod:hook_safe(CLASS.CharacterStateMachine, "server_correction_occurred", function(self, unit)
    if self._unit_data_extension._player.viewport_name == 'player1' then
        previous_state_name = current_state_name
        current_state_name = self:current_state_name()
        on_state_change()
        print_debug("server player state", current_state_name)
    end
end)

-- Stop sprint if player stop it
mod:hook_safe(CLASS.PlayerCharacterStateSprinting, "_check_transition",
    function(self, unit, t, next_state_params, input_source, decreasing_speed, action_move_speed_modifier,
             sprint_momentum, wants_slide, wants_to_stop, has_weapon_action_input, weapon_action_input, move_direction,
             move_speed_without_weapon_actions)
        if not mod_settings.better_sprint or self._player.viewport_name ~= "player1" then
            return
        end

        if has_weapon_action_input then
            sprint_action_settings = self._weapon_extension:action_settings_from_action_input(weapon_action_input)
        end

        if
            not mod_settings.always_sprint
            and not mod_settings.toggle_sprint
            and not mod_settings.hold_to_sprint
            and not mod_settings.hold_to_walk
            and not attempt_sprint_dodge
            and wants_to_stop
        then
            attempt_sprint = false
            print_debug("player abort sprint")
        end
    end)

-- Calculate time in dodge
mod:hook_safe(CLASS.PlayerCharacterStateDodging, "fixed_update",
    function(self, unit, dt, t, next_state_params, fixed_frame)
        if self._player.viewport_name == "player1" then
            time_in_dodge = t - self._character_state_component.entered_t
        end
    end)

-- Check if player action can abort sprint
local ALLOWED_INPUTS_IN_SPRINT = {
    combat_ability = true,
    wield = true,
}
local abort_sprint_table = {}
for i = 1, #ActionHandlerSettings.abort_sprint do
    local action_kind = ActionHandlerSettings.abort_sprint[i]
    abort_sprint_table[action_kind] = true
end
local function abort_sprint(action_settings)
    local action_settings_abort_sprint =
        action_settings.abort_sprint
        and not action_settings.override_allow_during_sprint
    if action_settings_abort_sprint ~= nil then
        return action_settings_abort_sprint
    end
    local action_kind = action_settings.kind
    local action_kind_abort_sprint =
        abort_sprint_table[action_kind]
        and not action_settings.override_allow_during_sprint
    return action_kind_abort_sprint
end

local function on_action_change(self, id, running_action)
    if not mod_settings.better_sprint then
        return
    end

    local action_settings = running_action:action_settings()
    local allowed_during_sprint, buff_keyword_allows_action_during_sprint =
        ActionAvailability.available_in_sprint(action_settings, self._buff_extension)
    if id == "weapon_action" then
        local requires_press_to_interrupt = Sprint.requires_press_to_interrupt(action_settings)
        local no_interruption_for_sprint = Sprint.no_interruption_for_sprint(action_settings)
        if not allowed_during_sprint and not buff_keyword_allows_action_during_sprint and not requires_press_to_interrupt and not no_interruption_for_sprint then
            no_sprinting_bug_fix = true
        end

        if not mod_settings.hold_to_walk and not mod_settings.hold_to_sprint then
            if sprint_action_settings == action_settings then
                no_sprinting_stamina = true
            end
            sprint_action_settings = nil
        end
    end

    if mod_settings.always_sprint or mod_settings.hold_to_walk or mod_settings.hold_to_sprint then
        return
    end

    local weapon_template = running_action._weapon_template
    local is_allowed = (weapon_template and weapon_template.allowed_inputs_in_sprint or ALLOWED_INPUTS_IN_SPRINT)
        [action_settings.start_input]
    local is_abort_sprint = abort_sprint(action_settings)
    if not allowed_during_sprint and not is_allowed or is_abort_sprint then
        print_debug("local action", action_settings.kind, "abort sprint")
        attempt_sprint = false
    end
end

mod:hook_safe(CLASS.ActionHandler, "start_action",
    function(self, id, action_objects, action_name, action_params, action_settings, used_input, t, transition_type,
             condition_func_params, automatic_input, reset_combo_override)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        print_debug("start", id, action_name)
        local handler_data = self._registered_components[id]
        local running_action = handler_data.running_action
        on_action_change(self, id, running_action)
    end)

mod:hook_safe(CLASS.ActionHandler, "server_correction_occurred",
    function(self, id, action_objects, action_params, actions)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        local handler_data = self._registered_components[id]
        local current_action_name = handler_data.component.current_action_name
        print_debug("correct", id, current_action_name)
        if current_action_name ~= "none" then
            local running_action = handler_data.running_action
            on_action_change(self, id, running_action)
        elseif id == "weapon_action" then
            no_sprinting_bug_fix = false
            no_sprinting_stamina = false
        end
    end)

mod:hook_safe(CLASS.ActionHandler, "_finish_action",
    function(self, handler_data, reason, data, t, next_action_params, condition_func_params)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        print_debug("finish", handler_data.id, "reason", reason)
        -- cancel no sprinting if weapon action finished
        if handler_data.id == "weapon_action" then
            no_sprinting_bug_fix = false
            if reason ~= "new_interrupting_action" then
                no_sprinting_stamina = false
            end
        end
    end)

-- Update settings when input settings changed
mod:hook_safe(CLASS.EventManager, "trigger", function(self, event_name, ...)
    if event_name == "event_on_input_settings_changed" then
        print_debug("input settings changed")
        init_game_settings()
        enable_hold_to_sprint()
    end
end)

-- Add dodge held input detection
mod:hook_require("scripts/settings/input/default_ingame_input_settings", function(instance)
    instance.settings.dodge_hold = {
        key_alias = "dodge",
        type = "held",
    }
end)

-- Player Cache Hook
mod:hook_safe(CLASS.HumanPlayer, "init",
    function(self, ...)
        if self.viewport_name == "player1" then
            print_debug("HumanPlayer init")
            player = self
        end
    end)

mod:hook_safe(CLASS.HumanPlayer, "destroy",
    function(self, ...)
        if self.viewport_name == "player1" then
            print_debug("HumanPlayer destroy")
            player = nil
        end
    end)

-- Extensions Hook
mod:hook_safe(CLASS.PlayerUnitBuffExtension, "init",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitBuffExtension init")
            playerBuffExtension = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitBuffExtension, "delete",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitBuffExtension delete")
            playerBuffExtension = nil
        end
    end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "init",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitWeaponExtension init")
            playerWeaponExtension = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "delete",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitWeaponExtension delete")
            playerWeaponExtension = nil
        end
    end)

mod:hook_safe(CLASS.PlayerUnitActionInputExtension, "init",
    function(self, ...)
        print_debug("PlayerUnitActionInputExtension init")
        playerActionInputExtension = self
    end)

mod:hook_safe(CLASS.PlayerUnitActionInputExtension, "delete",
    function(self, ...)
        print_debug("PlayerUnitActionInputExtension delete")
        playerActionInputExtension = nil
    end)

-- Player Unit Data Hook
mod:hook_safe(CLASS.PlayerUnitDataExtension, "init",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitDataExtension init")
            init_movement_component(self)
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "destroy",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitDataExtension destroy")
            table_clear(movement_components)
        end
    end)

-- Inpute Service Hook for fake input
mod:hook(CLASS.InputService, "_get", input_service_hook)
mod:hook(CLASS.InputService, "_get_simulate", input_service_hook)
