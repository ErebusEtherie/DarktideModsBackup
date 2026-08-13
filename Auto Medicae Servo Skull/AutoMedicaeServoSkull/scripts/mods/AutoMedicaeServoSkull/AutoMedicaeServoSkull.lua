---@class AutoMedicaeServoSkullMod:DMFMod
local mod                                           = get_mod("AutoMedicaeServoSkull")

local CompanionServoSkullAbility                    = require("scripts/utilities/companion/companion_servo_skull_ability")
local SmartTargetingTemplates                       = require("scripts/settings/equipment/smart_targeting_templates")
local PlayerUnitStatus                              = require("scripts/utilities/attack/player_unit_status")
local SpecialRulesSettings                          = require("scripts/settings/ability/special_rules_settings")
local special_rules                                 = SpecialRulesSettings.special_rules

local CLASS                                         = CLASS
local Managers                                      = Managers
local ScriptUnit                                    = ScriptUnit

local EMPTY_TABLE                                   = {}

---@class AutoMedicaeServoSkullModSettings
local mod_settings                                  = {
    toggle_mod                          = mod:get("toggle_mod"),
    toggle_mod_keybind                  = mod:get("toggle_mod_keybind"),
    toggle_mod_notify                   = mod:get("toggle_mod_notify"),
    debug_mode                          = mod:get("debug_mode"),
    auto_inject                         = mod:get("auto_inject"),
    auto_inject_ignore_bot              = mod:get("auto_inject_ignore_bot"),
    auto_inject_knocked_down            = mod:get("auto_inject_knocked_down"),
    auto_inject_knocked_down_threshold  = mod:get("auto_inject_knocked_down_threshold"),
    auto_inject_hogtied                 = mod:get("auto_inject_hogtied"),
    auto_inject_hogtied_threshold       = mod:get("auto_inject_hogtied_threshold"),
    auto_inject_netted                  = mod:get("auto_inject_netted"),
    auto_inject_netted_threshold        = mod:get("auto_inject_netted_threshold"),
    auto_inject_ignore_weapon_action    = mod:get("auto_inject_ignore_weapon_action"),
    auto_inject_ignore_ability_action   = mod:get("auto_inject_ignore_ability_action"),
    auto_release                        = mod:get("auto_release"),
    auto_release_ignore_bot             = mod:get("auto_release_ignore_bot"),
    auto_release_knocked_down           = mod:get("auto_release_knocked_down"),
    auto_release_knocked_down_threshold = mod:get("auto_release_knocked_down_threshold"),
    auto_release_hogtied                = mod:get("auto_release_hogtied"),
    auto_release_hogtied_threshold      = mod:get("auto_release_hogtied_threshold"),
    auto_release_netted                 = mod:get("auto_release_netted"),
    auto_release_netted_threshold       = mod:get("auto_release_netted_threshold"),
}

mod.toggle_mod                                      = function()
    if mod_settings.toggle_mod_notify then
        mod:notify("Auto Medicae Servo Skull " .. (not mod_settings.toggle_mod and "Enabled" or "Disabled"))
    end
    mod:set("toggle_mod", not mod_settings.toggle_mod, true)
end

local player                                        = nil
local class_name                                    = nil
local ally_unit                                     = nil
local targeting_data                                = {}

local is_auto_inject                                = false
local is_manual_inject                              = false
local is_manual_inject_key_held                     = false
local is_manual_inject_key_pressed                  = false

local companion_spawner_extension                   = nil
local player_talent_extension                       = nil
local player_ability_extension                      = nil

local weapon_action_component                       = EMPTY_TABLE
local combat_ability_action_component               = EMPTY_TABLE
local grenade_ability_action_component              = EMPTY_TABLE
local action_module_ability_target_finder_component = EMPTY_TABLE


local function print_debug(...)
    if mod_settings.debug_mode then
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

local function get_player_data_extension()
    player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "unit_data_system")
end
local function get_companion_spawner_extension()
    player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "companion_spawner_system")
end
local function get_player_talent_extension()
    player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "talent_system")
end
local function get_player_ability_extension()
    player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "ability_system")
end

local function init_player()
    player = Managers.player:local_player_safe(1)
    class_name = player and player:archetype_name()
end

local function init_extensions()
    companion_spawner_extension = get_companion_spawner_extension()
    player_talent_extension = get_player_talent_extension()
    player_ability_extension = get_player_ability_extension()
end

local function init_components(player_data_extension)
    player_data_extension = player_data_extension or get_player_data_extension()
    if not player_data_extension then
        return
    end

    weapon_action_component = player_data_extension:read_component("weapon_action")
    combat_ability_action_component = player_data_extension:read_component("combat_ability_action")
    grenade_ability_action_component = player_data_extension:read_component("grenade_ability_action")
    action_module_ability_target_finder_component = player_data_extension:read_component("action_module_ability_target_finder")
end

local function reset_components()
    weapon_action_component = EMPTY_TABLE
    combat_ability_action_component = EMPTY_TABLE
    grenade_ability_action_component = EMPTY_TABLE
    action_module_ability_target_finder_component = EMPTY_TABLE
end

local function init_context()
    init_player()
    init_extensions()
    init_components()
end

local function reset_context()
    ally_unit = nil
    is_auto_inject = false
    is_manual_inject = false
    is_manual_inject_key_held = false
    is_manual_inject_key_pressed = false
end

local function destroy_reference()
    player                                        = nil
    companion_spawner_extension                   = nil
    player_talent_extension                       = nil
    player_ability_extension                      = nil
    weapon_action_component                       = EMPTY_TABLE
    combat_ability_action_component               = EMPTY_TABLE
    grenade_ability_action_component              = EMPTY_TABLE
    action_module_ability_target_finder_component = EMPTY_TABLE
end

mod.on_enabled            = function()
    init_context()
end

mod.on_disabled           = function()
    reset_context()
    destroy_reference()
end

mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then

        elseif status == "exit" then
            reset_context()
        end
    end
end

mod.on_setting_changed    = function(setting_id)
    local result = mod:get(setting_id)
    mod_settings[setting_id] = result
end

mod.manual_inject_held    = function(held)
    is_manual_inject_key_held = held
end

mod.manual_inject_press   = function()
    is_manual_inject_key_pressed = true
end

local function is_human_player(unit)
    local target_player = Managers.player:player_by_unit(unit)
    return target_player and target_player:is_human_controlled()
end

local function is_auto_inject_target_valid(target_unit, character_state_component, remaining_grenades)
    if not target_unit or not character_state_component then
        return false
    end

    if mod_settings.auto_inject_ignore_bot and not is_human_player(target_unit) then
        return false
    end

    return mod_settings.auto_inject_hogtied and PlayerUnitStatus.is_hogtied(character_state_component) and remaining_grenades >= mod_settings.auto_inject_hogtied_threshold
        or mod_settings.auto_inject_knocked_down and PlayerUnitStatus.is_knocked_down(character_state_component) and remaining_grenades >= mod_settings.auto_inject_knocked_down_threshold
        or mod_settings.auto_inject_netted and character_state_component.state_name == "netted" and remaining_grenades >= mod_settings.auto_inject_netted_threshold
end

local function is_auto_release_target_valid(target_unit, character_state_component, remaining_grenades)
    if not target_unit or not character_state_component then
        return false
    end

    if mod_settings.auto_release_ignore_bot and not is_human_player(target_unit) then
        return false
    end

    return mod_settings.auto_release_hogtied and PlayerUnitStatus.is_hogtied(character_state_component) and remaining_grenades >= mod_settings.auto_release_hogtied_threshold
        or mod_settings.auto_release_knocked_down and PlayerUnitStatus.is_knocked_down(character_state_component) and remaining_grenades >= mod_settings.auto_release_knocked_down_threshold
        or mod_settings.auto_release_netted and character_state_component.state_name == "netted" and remaining_grenades >= mod_settings.auto_release_netted_threshold
end

mod:hook(CLASS.InputService, "_get",
    function(func, self, action_name)
        local result = func(self, action_name)
        if action_name == "grenade_ability_pressed" then
            if result then
                is_auto_inject = false
                is_manual_inject = false
            elseif ally_unit and not func(self, "grenade_ability_hold") then
                return true
            end
        elseif action_name == "grenade_ability_hold" then
            if (is_auto_inject or is_manual_inject or mod_settings.toggle_mod and mod_settings.auto_release)
                and class_name == "cryptic"
                and grenade_ability_action_component.template_name == "cryptic_servo_skull_order"
                and grenade_ability_action_component.current_action_name == "action_aim"
                and player_talent_extension and player_talent_extension:has_special_rule(special_rules.cryptic_servo_skull_inject_ally)
            then
                local target_unit = action_module_ability_target_finder_component.target_unit_1
                if target_unit then
                    if is_manual_inject then
                        return false
                    end

                    local unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
                    local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")
                    local remaining_grenades = player_ability_extension and player_ability_extension:remaining_ability_charges("grenade_ability") or 0
                    if is_auto_inject then
                        if is_auto_inject_target_valid(target_unit, character_state_component, remaining_grenades) then
                            return false
                        end
                    else
                        if is_auto_release_target_valid(target_unit, character_state_component, remaining_grenades) then
                            return false
                        end
                    end
                end

                if is_auto_inject or is_manual_inject then
                    return true
                end
            end
        elseif action_name == "action_two_pressed" then
            if (is_auto_inject or is_manual_inject)
                and class_name == "cryptic"
                and grenade_ability_action_component.template_name == "cryptic_servo_skull_order"
                and grenade_ability_action_component.current_action_name == "action_aim"
            then
                local target_unit = action_module_ability_target_finder_component.target_unit_1
                if is_auto_inject then
                    if target_unit then
                        local unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
                        local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")
                        local remaining_grenades = player_ability_extension and player_ability_extension:remaining_ability_charges("grenade_ability") or 0
                        if not is_auto_inject_target_valid(target_unit, character_state_component, remaining_grenades) then
                            return true
                        end
                    else
                        return true
                    end
                elseif is_manual_inject then
                    if not target_unit then
                        return true
                    end
                end
            end
        elseif action_name == "action_one_pressed" then
            if (is_auto_inject or is_manual_inject)
                and class_name == "cryptic"
                and grenade_ability_action_component.template_name == "cryptic_servo_skull_order"
                and grenade_ability_action_component.current_action_name == "action_aim"
            then
                return false
            end
        end

        return result
    end)

mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "fixed_update",
    function(self, unit, dt, t, fixed_frame)
        if self._player.viewport_name ~= "player1" then
            return
        end

        if (is_manual_inject_key_held or is_manual_inject_key_pressed
                or mod_settings.toggle_mod
                and mod_settings.auto_inject
                and (mod_settings.auto_inject_hogtied or mod_settings.auto_inject_knocked_down or mod_settings.auto_inject_netted)
                and (mod_settings.auto_inject_ignore_weapon_action or weapon_action_component.current_action_name == "none")
                and (mod_settings.auto_inject_ignore_ability_action or combat_ability_action_component.current_action_name == "none"))
            and class_name == "cryptic"
            and grenade_ability_action_component.template_name == "cryptic_servo_skull_order"
            and grenade_ability_action_component.current_action_name == "none"
            and player_talent_extension and player_talent_extension:has_special_rule(special_rules.cryptic_servo_skull_inject_ally)
        then
            local ray_origin, forward, right, up = self:_targeting_parameters()
            self._precision_target_aim_assist:update_precision_target(
                self._unit, SmartTargetingTemplates.target_servo_skull_target,
                ray_origin, forward, right, up, targeting_data,
                self._latest_fixed_frame,
                self._visibility_cache,
                self._visibility_check_frame,
                self._line_of_sight_cache
            )
            local target_unit = targeting_data.unit
            if target_unit and CompanionServoSkullAbility.can_target_unit(nil, target_unit, companion_spawner_extension, player_talent_extension, player_ability_extension) then
                if is_manual_inject_key_held or is_manual_inject_key_pressed then
                    is_auto_inject = false
                    is_manual_inject = true
                    is_manual_inject_key_pressed = false
                    ally_unit = target_unit
                    return
                end

                local unit_data_extension = ScriptUnit.has_extension(target_unit, "unit_data_system")
                local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")
                local remaining_grenades = player_ability_extension and player_ability_extension:remaining_ability_charges("grenade_ability") or 0
                if is_auto_inject_target_valid(target_unit, character_state_component, remaining_grenades) then
                    is_auto_inject = true
                    is_manual_inject = false
                    ally_unit = target_unit
                    return
                end
            end
        end

        is_manual_inject_key_pressed = false
        ally_unit = nil
    end)

local function on_action_finish(id)
    if id == "grenade_ability_action" then
        is_auto_inject = false
        is_manual_inject = false
    end
end

mod:hook_safe(CLASS.ActionHandler, "server_correction_occurred",
    function(self, id, action_objects, action_params, actions)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        local handler_data = self._registered_components[id]
        local component = handler_data.component
        local current_action_name = component.current_action_name
        if current_action_name == "none" then
            on_action_finish(id)
        end
    end)

mod:hook_safe(CLASS.ActionHandler, "_finish_action",
    function(self, handler_data, reason, data, t, next_action_params, condition_func_params)
        if self._unit_data_extension._player.viewport_name ~= 'player1' then
            return
        end

        local id = handler_data.id
        on_action_finish(id)
    end)

-- Cache Player
mod:hook_safe(CLASS.HumanPlayer, "init",
    function(self)
        if self.viewport_name == "player1" then
            player = self
        end
    end)

mod:hook_safe(CLASS.HumanPlayer, "destroy",
    function(self)
        if self.viewport_name == "player1" then
            player = nil
        end
    end)

-- Get Archetype Name When Player Set Profile
mod:hook_safe(CLASS.HumanPlayer, "set_profile",
    function(self)
        if self.viewport_name == "player1" then
            class_name = self:archetype_name()
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            init_components(self)
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "destroy",
    function(self)
        if self._player.viewport_name == "player1" then
            reset_components()
        end
    end)

mod:hook_safe(CLASS.CompanionSpawnerExtension, "init",
    function(self)
        if self._owner_player.viewport_name == "player1" then
            companion_spawner_extension = self
        end
    end)

mod:hook_safe(CLASS.CompanionSpawnerExtension, "destroy",
    function(self)
        if self._owner_player.viewport_name == "player1" then
            companion_spawner_extension = nil
        end
    end)

mod:hook_safe(CLASS.PlayerUnitAbilityExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            player_ability_extension = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitAbilityExtension, "delete",
    function(self)
        if self._player.viewport_name == "player1" then
            player_ability_extension = nil
        end
    end)

mod:hook_safe(CLASS.PlayerUnitTalentExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            player_talent_extension = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitTalentExtension, "destroy",
    function(self)
        if self._player.viewport_name == "player1" then
            player_talent_extension = nil
        end
    end)

mod:hook_safe(CLASS.PlayerHuskTalentExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            player_talent_extension = self
        end
    end)

mod:hook_safe(CLASS.PlayerHuskTalentExtension, "destroy",
    function(self)
        if self._player.viewport_name == "player1" then
            player_talent_extension = nil
        end
    end)
