local mod                           = get_mod("BetterMovement")
local constants                     = require("scripts/settings/player_character/player_character_constants")
local ActionAvailability            = require("scripts/extension_systems/weapon/utilities/action_availability")
local ActionHandlerSettings         = require("scripts/settings/action/action_handler_settings")
local Sprint                        = require(
    "scripts/extension_systems/character_state_machine/character_states/utilities/sprint")

-- Global Cache
local CLASS                         = CLASS
local ScriptUnit                    = ScriptUnit
local Managers                      = Managers
local Vector3                       = Vector3
local Vector3_length                = Vector3.length
local Vector3_length_squared        = Vector3.length_squared
local Vector3_flat                  = Vector3.flat
local vector3_normalize             = Vector3.normalize
local math_abs                      = math.abs
local math_max                      = math.max
local table_clear                   = table.clear

-- Constants
local TICK_RATE                     = 52
local FIXED_DT                      = 1 / TICK_RATE

local MELEE_ACTION_KINDS            = {
    windup = true,
    sweep = true,
}

local LUGGABLE_WEAPON_NAMES         = {
    luggable = true,
    luggable_light = true,
    luggable_mission = true,
}

-- Plater Cache
local player                        = nil

-- Extensions Cache
local player_buff_extension         = nil
local player_weapon_extesnion       = nil
local player_action_input_extension = nil

-- Component Cache
local components                    = {}

-- Mod settings
local mod_settings                  = {
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
    better_toggle_crouch    = mod:get("better_toggle_crouch"),    -- better toggle crouch
    easy_sprint_slide       = mod:get("easy_sprint_slide"),       -- press dodge button to slide forward while sprinting
    auto_vault              = mod:get("auto_vault"),              -- auto vault when airborne
    luggable_keep_push      = mod:get("luggable_keep_push"),      -- keep push when carrying luggable
    no_sprinting_stamina    = mod:get("no_sprinting_stamina"),    -- pause sprinting to recover stamina
}

-- Game Settings
local hold_to_sprint                = true
local hold_to_crouch                = true
local diagonal_forward_dodge        = true
local stationary_dodge              = false
local always_dodge                  = false

-- Mod Status
local mod_enabled                   = false

-- Player Movement Status
local previous_state_name           = "walking"
local current_state_name            = "walking"
local is_in_hub                     = false
local no_sprinting_bug_fix          = false
local no_sprinting_stamina          = false
local sprint_action_settings        = nil
local run_n_gun_need_sprint         = false
local sliding_speed                 = 0
local crouching_override            = false

-- Input Cache
local crouch_hold                   = false
local move_forward                  = 0
local move_backward                 = 0
local move_left                     = 0
local move_right                    = 0
local dodge_hold                    = false
local dodge_hold_start_time         = nil
local dodge_press_in_dodging        = false

-- Fake Input Flag
local attempt_dodge_slide           = false
local attempt_sprint_slide          = false
local attempt_sprint                = false
local attempt_sprint_dodge          = false
local attempt_crouch                = false

-- Reset movement parameters
local function reset_params()
    -- Player movement stats
    previous_state_name    = "walking"
    current_state_name     = "walking"
    is_in_hub              = false
    no_sprinting_bug_fix   = false
    no_sprinting_stamina   = false
    sprint_action_settings = nil
    run_n_gun_need_sprint  = false
    sliding_speed          = 0
    crouching_override     = false
    -- Input Cache
    crouch_hold            = false
    move_forward           = 0
    move_backward          = 0
    move_left              = 0
    move_right             = 0
    dodge_hold             = false
    dodge_hold_start_time  = nil
    dodge_press_in_dodging = false
    -- Fake Input Flag
    attempt_dodge_slide    = false
    attempt_sprint_slide   = false
    attempt_sprint         = false
    attempt_sprint_dodge   = false
    attempt_crouch         = false
end

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
        mod:echo(result)
    end
end

-- Time for Now
local function main_time()
    return Managers.time:time("main")
end

local function gameplay_time()
    return Managers.time:time("gameplay")
end

-- Get Extensions
local function get_player_data_extension()
    local result = Managers.player:local_player_safe(1)
    return result and ScriptUnit.extension(result.player_unit, "unit_data_system")
end

local function get_player_buff_extension()
    local result = Managers.player:local_player_safe(1)
    return result and ScriptUnit.extension(result.player_unit, "buff_system")
end

local function get_player_weapon_extension()
    local result = Managers.player:local_player_safe(1)
    return result and ScriptUnit.extension(result.player_unit, "weapon_system")
end

local function get_player_action_input_extension()
    local result = Managers.player:local_player_safe(1)
    return result and ScriptUnit.extension(result.player_unit, "action_input_system")
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
        player_buff_extension = result
    end
    result = get_player_weapon_extension()
    if result then
        player_weapon_extesnion = result
    end
    result = get_player_action_input_extension()
    if result then
        player_action_input_extension = result
    end
end

-- Init Movement Component Cache
local function init_components(player_data_extension)
    player_data_extension = player_data_extension or get_player_data_extension()
    if not player_data_extension then
        return
    end

    print_debug("Init components")
    components.movement_state          = player_data_extension:read_component("movement_state")
    components.hub_jog_character_state = player_data_extension:read_component("hub_jog_character_state")
    components.sprint_character_state  = player_data_extension:read_component("sprint_character_state")
    components.dodge_character_state   = player_data_extension:read_component("dodge_character_state")
    components.locomotion              = player_data_extension:read_component("locomotion")
    components.character_state         = player_data_extension:read_component("character_state")
    components.locomotion_steering     = player_data_extension:read_component("locomotion_steering")
    components.weapon_action           = player_data_extension:read_component("weapon_action")
end

-- Init Cache
local function init_cache()
    init_player()
    init_extensions()
    init_components()
end

local function init_game_settings()
    hold_to_sprint         = Managers.save:account_data().input_settings.hold_to_sprint
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
        hold_to_sprint = true
    end
end

-- Turn on Hold to Crouch if Better Toggle Crouch Enabled
local function enable_hold_to_crouch()
    if not mod_settings.better_toggle_crouch or not mod_enabled then
        return
    end

    local input_settings = Managers.save:account_data().input_settings
    if not input_settings.hold_to_crouch then
        input_settings.hold_to_crouch = true
        hold_to_crouch = true
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

-- Check if slide action is valid
local function can_dodge_slide()
    if not components.locomotion or not components.dodge_character_state then
        return true
    end

    local velocity = components.locomotion.velocity_current
    if not velocity then
        return true
    end

    if components.dodge_character_state.started_from_crouch then
        return false
    end

    if components.dodge_character_state.distance_left <= 0 then
        return false
    end

    local current_length_sq = Vector3_length_squared(Vector3_flat(velocity))
    local slide_threshold_sq = constants.slide_move_speed_threshold_sq
    return current_length_sq > slide_threshold_sq
end

-- Check if player is sprinting or sprint-jumping
local function is_sprint_jumping()
    if is_in_hub then
        if not components.hub_jog_character_state then
            return false
        end

        return components.hub_jog_character_state.move_state == "sprint"
    else
        if not components.sprint_character_state then
            return false
        end

        return components.sprint_character_state.is_sprinting
            or components.sprint_character_state.is_sprint_jumping
    end
end

-- Check if player's move input can dodge
local function is_dodge_direction()
    local move = Vector3(move_right - move_left, move_forward - move_backward, 0)
    local normalized_move = vector3_normalize(move)
    local y = normalized_move.y
    local x = normalized_move.x
    return y < 0 or (y == 0 and x ~= 0)
        or (diagonal_forward_dodge and y > 0 and math_abs(x) > 0.707)
        or (stationary_dodge and y == 0 and x == 0)
        or (always_dodge and y > 0)
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
local function can_sprinting()
    if not player_buff_extension or not player_weapon_extesnion or not player_action_input_extension then
        return true
    end

    local weapon_action_input = player_action_input_extension:peek_next_input("weapon_action")
    if not weapon_action_input then
        return true
    end

    local action_settings = player_weapon_extesnion:action_settings_from_action_input(weapon_action_input)
    if not action_settings or not MELEE_ACTION_KINDS[action_settings.kind] then
        return true
    end

    local allowed_during_sprint, _ = ActionAvailability.available_in_sprint(action_settings, player_buff_extension)

    if allowed_during_sprint then
        return true
    end

    print_debug(action_settings.name, "will be interrupted by sprinting")
    return false
end

local function can_hold_dodge_slide()
    if not dodge_hold
        or not dodge_hold_start_time
        or dodge_press_in_dodging
        or not components.character_state
        or not components.dodge_character_state
        or not components.locomotion_steering
    then
        return false
    end

    local start_time = math_max(components.character_state.entered_t, dodge_hold_start_time)
    local hold_duration = gameplay_time() - start_time
    if hold_duration >= 0.22 then
        return true
    end

    local distance_left = components.dodge_character_state.distance_left
    local move_delta = Vector3_length(components.locomotion_steering.velocity_wanted) / TICK_RATE
    if move_delta > distance_left then
        return true
    end

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
                no_sprinting_bug_fix = false
                no_sprinting_stamina = false
            end
            if run_n_gun_need_sprint
                and attempt_sprint
                and not is_sprint_jumping()
                and has_move_input()
            then
                result = true
            end
        end
        -- cancel attempt crouch when sprint
        if mod_settings.better_toggle_crouch
            and (result or attempt_sprint)
            and current_state_name ~= "dodging"
            and has_move_input()
        then
            attempt_crouch = false
        end
        -- sprint dodge stop sprint
        if mod_settings.sprint_dodge
            and not hold_to_sprint
            and attempt_sprint_dodge
            and current_state_name == "sprinting"
        then
            return true
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
            if not mod_settings.toggle_sprint and not has_move_input() then
                attempt_sprint = false
            end
        end
        -- cancel attempt crouch when sprinting
        if mod_settings.better_toggle_crouch
            and hold_to_sprint and result
            and not (mod_settings.better_sprint and mod_settings.hold_to_walk)
            and has_move_input()
        then
            attempt_crouch = false
        end
        -- sprint dodge stop sprint
        if mod_settings.sprint_dodge
            and hold_to_sprint
            and attempt_sprint_dodge
        then
            return false
        end
        -- continous sprint for game's hold-to-sprint
        if mod_settings.better_sprint then
            return attempt_sprint and not no_sprinting_bug_fix and not no_sprinting_stamina and can_sprinting()
        end
    elseif action_name == "move_forward" then
        move_forward = result
        dodge_hold = func(self, "dodge_hold")
        if not dodge_hold then
            dodge_hold_start_time = nil
            dodge_press_in_dodging = false
        end
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
            elseif (current_state_name == "walking" or current_state_name == "sprinting") and not can_jump() then
                return false
            end
        end
    elseif action_name == "jump_held" then
        if mod_settings.auto_vault and (current_state_name == "jumping" or current_state_name == "falling") then
            return true
        end
    elseif action_name == "dodge" then
        if result then
            dodge_hold = true
            dodge_hold_start_time = gameplay_time()
            dodge_press_in_dodging = current_state_name == "dodging"
            if mod_settings.better_toggle_crouch
                and current_state_name == "walking"
                and is_dodge_direction()
            then
                attempt_crouch = false
            end
        end
        if current_state_name == "dodging" then
            if mod_settings.easy_dodge_slide then
                attempt_dodge_slide = attempt_dodge_slide or result
            end
        elseif is_sprint_jumping() then
            if mod_settings.sprint_dodge
                and current_state_name == "sprinting"
                and is_dodge_direction()
            then
                attempt_sprint_dodge = attempt_sprint_dodge or result or mod_settings.keep_dodging and dodge_hold
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
        if not result then
            crouching_override = false
        end
        -- treat holding dodge key as holding crouch key
        if current_state_name == "sliding"
            and dodge_hold
            and (hold_to_crouch or sliding_speed > 0.5)
        then
            if previous_state_name == "dodging" then
                if mod_settings.easy_dodge_slide or mod_settings.hold_dodge_slide then
                    return true
                end
            elseif mod_settings.easy_sprint_slide then
                return true
            end
        end
        if hold_to_crouch then
            if current_state_name == "dodging" then
                if (mod_settings.easy_dodge_slide and attempt_dodge_slide
                        or mod_settings.hold_dodge_slide and can_hold_dodge_slide())
                    and can_dodge_slide()
                then
                    return true
                end
            elseif is_sprint_jumping() then
                if mod_settings.easy_sprint_slide and attempt_sprint_slide then
                    return true
                end
            end
            if mod_settings.better_toggle_crouch then
                if mod_settings.keep_dodging
                    and dodge_hold
                    and current_state_name == "walking"
                    and is_dodge_direction()
                then
                    attempt_crouch = false
                end
                if (current_state_name == "walking" or current_state_name == "falling" or current_state_name == "dodging")
                    and not crouching_override
                then
                    return attempt_crouch
                end
            end
        end
    elseif action_name == "crouch" then
        if mod_settings.better_toggle_crouch and result
            and (current_state_name == "walking" or current_state_name == "dodging")
        then
            attempt_crouch = not attempt_crouch
        end
        if not hold_to_crouch then
            if current_state_name == "dodging" then
                if (mod_settings.easy_dodge_slide and attempt_dodge_slide
                        or mod_settings.hold_dodge_slide and can_hold_dodge_slide())
                    and not components.movement_state.is_crouching
                    and can_dodge_slide()
                then
                    return true
                end
            elseif is_sprint_jumping() then
                if mod_settings.easy_sprint_slide
                    and attempt_sprint_slide
                    and not components.movement_state.is_crouching
                then
                    return true
                end
            end
        end
    elseif action_name == "action_two_pressed" then
        if mod_settings.luggable_keep_push and LUGGABLE_WEAPON_NAMES[components.weapon_action and components.weapon_action.template_name] and func(self, "action_two_hold") then
            return true
        end
    end

    return result
end

-- Inpute Service Hook for fake input
mod:hook(CLASS.InputService, "_get", input_service_hook)

--  Mod Enabled
mod.on_enabled = function()
    mod_enabled = true
    init_cache()
    init_game_settings()
    init_conflict_settings()
    enable_hold_to_sprint()
    enable_hold_to_crouch()
    check_is_in_hub()
end

--  Mod Disabled
mod.on_disabled = function()
    mod_enabled = false
    reset_params()
end

mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then
            init_game_settings()
            enable_hold_to_sprint()
            enable_hold_to_crouch()
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
    if setting_id == "better_sprint" then
        if result then enable_hold_to_sprint() end
    elseif setting_id == "better_toggle_crouch" then
        if result then enable_hold_to_crouch() end
    end
end

-- HOOKS
local function on_state_change()
    if not is_sprint_jumping() then
        attempt_sprint_slide = false
    end

    if current_state_name ~= "dodging" then
        attempt_dodge_slide = false
        dodge_press_in_dodging = false
    end

    if current_state_name == "sliding" then
        attempt_sprint_slide = false
        attempt_dodge_slide = false
    else
        sliding_speed = 0
    end

    if current_state_name == "walking" then
        if previous_state_name == "sliding" then
            crouching_override = true
            if crouch_hold
                and not mod_settings.always_sprint
                and not mod_settings.toggle_sprint
                and not mod_settings.hold_to_sprint
                and not mod_settings.hold_to_walk
            then
                attempt_sprint = false
            end
        end
    else
        attempt_sprint_dodge = false
        if current_state_name ~= "falling" then
            attempt_crouch = false
        end
    end
end

-- Hook CharacterStateMachine for Movement State
mod:hook_safe(CLASS.CharacterStateMachine, "_change_state",
    function(self, unit, dt, t, next_state, params)
        if self._unit_data_extension._player.viewport_name == 'player1' then
            previous_state_name = current_state_name
            current_state_name = next_state
            on_state_change()
            print_debug("local state", current_state_name)
        end
    end)

mod:hook_safe(CLASS.CharacterStateMachine, "server_correction_occurred",
    function(self, unit)
        if self._unit_data_extension._player.viewport_name == 'player1' and current_state_name ~= self:current_state_name() then
            previous_state_name = current_state_name
            current_state_name = self:current_state_name()
            on_state_change()
            print_debug("server state", current_state_name)
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

        if wants_to_stop then
            if has_weapon_action_input then
                local action_settings = self._weapon_extension:action_settings_from_action_input(weapon_action_input)
                if action_settings and MELEE_ACTION_KINDS[action_settings.kind] then
                    sprint_action_settings = action_settings
                end
            end

            if not mod_settings.always_sprint
                and not mod_settings.toggle_sprint
                and not mod_settings.hold_to_sprint
                and not mod_settings.hold_to_walk
                and not attempt_sprint_dodge
            then
                attempt_sprint = false
                print_debug("player abort sprint")
            end
        end
    end)

-- Hook Sliding State for Current Speed
mod:hook_safe(CLASS.PlayerCharacterStateSliding, "_check_transition",
    function(self, unit, t, next_state_params, input_source, is_crouching,
             commit_period_over, max_mass_hit, current_speed)
        sliding_speed = current_speed
    end)

-- Check Crouch Exit
mod:hook_require("scripts/extension_systems/character_state_machine/character_states/utilities/crouch",
    function(instance)
        mod:hook_safe(instance, "exit",
            function(unit, first_person_extension, animation_extension, weapon_extension, movement_state_component,
                     locomotion_component, inair_state_component, sway_control_component, sway_component,
                     spread_control_component, t)
                if not player or player.player_unit ~= unit then
                    return
                end

                attempt_crouch = false
            end)
    end)

local abort_sprint_table = {}
for i = 1, #ActionHandlerSettings.abort_sprint do
    local action_kind = ActionHandlerSettings.abort_sprint[i]
    abort_sprint_table[action_kind] = true
end
local function _abort_sprint(action_settings)
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
    local requires_press = Sprint.requires_press_to_interrupt(action_settings)
    local prevent_sprint = Sprint.prevent_sprint(action_settings)
    local abort_sprint = _abort_sprint(action_settings)
    if id == "weapon_action" then
        if not buff_keyword_allows_action_during_sprint
            and (MELEE_ACTION_KINDS[action_settings.kind]
                and not allowed_during_sprint
                or prevent_sprint)
        then
            no_sprinting_bug_fix = true
        end

        if mod_settings.no_sprinting_stamina and not mod_settings.hold_to_walk and not mod_settings.hold_to_sprint then
            if sprint_action_settings == action_settings then
                no_sprinting_stamina = true
            end
            sprint_action_settings = nil
        end

        if buff_keyword_allows_action_during_sprint and requires_press then
            run_n_gun_need_sprint = true
        end
    end

    if not mod_settings.always_sprint
        and not mod_settings.hold_to_walk
        and not mod_settings.hold_to_sprint
    then
        if not buff_keyword_allows_action_during_sprint
            and (prevent_sprint or requires_press and not allowed_during_sprint or abort_sprint)
        then
            attempt_sprint = false
        end
    end
end

mod:hook_safe(CLASS.ActionHandler, "start_action",
    function(self, id, action_objects, action_name, action_params, action_settings, used_input, t, transition_type,
             condition_func_params, automatic_input, reset_combo_override)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        local handler_data = self._registered_components[id]
        local running_action = handler_data.running_action
        if running_action then
            print_debug("start", id, action_name)
            on_action_change(self, id, running_action)
        end
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
            run_n_gun_need_sprint = false
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
            run_n_gun_need_sprint = false
            if reason ~= "new_interrupting_action" then
                no_sprinting_stamina = false
            end
        end
    end)

-- Update settings when input settings changed
mod:hook_safe(CLASS.EventManager, "trigger",
    function(self, event_name)
        if event_name == "event_on_input_settings_changed" then
            print_debug("input settings changed")
            init_game_settings()
            enable_hold_to_sprint()
            enable_hold_to_crouch()
        end
    end)

-- Add dodge held input detection
mod:hook_require("scripts/settings/input/default_ingame_input_settings",
    function(instance)
        instance.settings.dodge_hold = {
            key_alias = "dodge",
            type = "held",
        }
    end)

-- Player Cache Hook
mod:hook_safe(CLASS.HumanPlayer, "init",
    function(self)
        if self.viewport_name == "player1" then
            print_debug("HumanPlayer init")
            player = self
        end
    end)

mod:hook_safe(CLASS.HumanPlayer, "destroy",
    function(self)
        if self.viewport_name == "player1" then
            print_debug("HumanPlayer destroy")
            player = nil
        end
    end)

-- Extensions Hook
mod:hook_safe(CLASS.PlayerUnitBuffExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitBuffExtension init")
            player_buff_extension = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitBuffExtension, "delete",
    function(self)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitBuffExtension delete")
            player_buff_extension = nil
        end
    end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitWeaponExtension init")
            player_weapon_extesnion = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "delete",
    function(self)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitWeaponExtension delete")
            player_weapon_extesnion = nil
        end
    end)

mod:hook_safe(CLASS.PlayerUnitActionInputExtension, "init",
    function(self)
        print_debug("PlayerUnitActionInputExtension init")
        player_action_input_extension = self
    end)

mod:hook_safe(CLASS.PlayerUnitActionInputExtension, "delete",
    function()
        print_debug("PlayerUnitActionInputExtension delete")
        player_action_input_extension = nil
    end)

-- Player Unit Data Hook
mod:hook_safe(CLASS.PlayerUnitDataExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitDataExtension init")
            init_components(self)
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "destroy",
    function(self)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitDataExtension destroy")
            table_clear(components)
        end
    end)
