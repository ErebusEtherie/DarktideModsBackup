---@class AutoMarkMod:DMFMod
local mod                                  = get_mod("AutoMark")
local context                              = mod.context
local mod_settings                         = mod.settings
local mark_context                         = mod.mark_context
local TAG_NAMES                            = mod.TAG_NAMES
local companion_cancel_mark_breed_settings = mod.companion_cancel_mark_breed_settings
local DISABLING_TYPES                      = mod.DISABLING_TYPES

-- Imports
local Health                               = require("scripts/utilities/health")

-- Global Cache
local CLASS                                = CLASS
local HEALTH_ALIVE                         = HEALTH_ALIVE
local Managers                             = Managers
local callback                             = callback
local Unit_world_position                  = Unit.world_position
local Vector3_distance_squared             = Vector3.distance_squared
local ScriptUnit_extension                 = ScriptUnit.extension

-- Outline Name For Execution Order Detection
local EXECUTION_ORDER_OUTLINE_NAME         = "adamant_mark_target"
local CANCEL_INTERVAL                      = 0.5

-- Callback Function for Companion Mark
local function companion_mark_callback()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local target_unit = mod:find_target_unit()
    if not target_unit then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    local tag_name = TAG_NAMES.COMPANION_TAG
    mod:set_manual_mark(tag_name, target_unit, target_tag)
end

-- Callback Function for Enemy Mark
local function enemy_mark_callback()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local target_unit = mod:find_target_unit()
    if not target_unit then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    if target_tag then
        return
    end

    local tag_name = TAG_NAMES.ENEMY_TAG
    mod:set_manual_mark(tag_name, target_unit, target_tag)
end

-- Companion Mark Keybind Function
mod.companion_mark = function()
    if not context.mod_enabled or not context.game_mode_valid or context.class_name ~= "adamant" or not context.has_companion then
        return
    end

    local companion_command_tap = context.companion_command_tap
    if companion_command_tap == "double" then
        local cb = callback(companion_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    elseif companion_command_tap == "single" then
        local cb = callback(enemy_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    end
end

-- Check If Target Unit Is Marked by Execution Order
local function is_marked_by_execution_order(unit)
    local outline_system = context.outline_system
    local extension = outline_system and outline_system._unit_extension_data[unit]
    local outlines = extension and extension.outlines
    if not outlines then
        return false
    end

    for i = 1, #outlines do
        if outlines[i].name == EXECUTION_ORDER_OUTLINE_NAME then
            return true
        end
    end

    return false
end

-- Cache All Units Marked by Execution Order
function mod:init_execution_order_units()
    if not context.has_execution_order then
        return
    end

    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local unit_extension_data = smart_tag_system._unit_extension_data
    if not unit_extension_data then
        return
    end

    local execution_order_units = mark_context.execution_order_units
    for unit, smart_tag_extension in pairs(unit_extension_data) do
        if HEALTH_ALIVE[unit]
            and smart_tag_extension._target_type == "breed"
            and is_marked_by_execution_order(unit)
        then
            execution_order_units[unit] = true
        end
    end
end

local cancel_interval = 0
function mod:auto_cancel_companion_mark(dt, t)
    if not mod_settings.companion_cancel_mark or context.class_name ~= "adamant" or not context.has_companion then
        return
    end

    if cancel_interval > 0 then
        cancel_interval = cancel_interval - dt
        return
    end

    local disabled_character_state_component = context.disabled_character_state_component
    if disabled_character_state_component and disabled_character_state_component.is_disabled and DISABLING_TYPES[disabled_character_state_component.disabling_type] then
        return
    end

    local tag_context = mark_context[TAG_NAMES.COMPANION_TAG]
    local marked_tag = tag_context.tag
    local marked_unit = marked_tag and marked_tag._target_unit
    if not marked_tag or not marked_unit then
        return
    end

    if tag_context.is_manual or not tag_context.is_cancelable then
        return
    end

    if not tag_context.pounce_start_time then
        return
    end

    local unit_data_extension = ScriptUnit_extension(marked_unit, "unit_data_system")
    local breed_data = unit_data_extension and unit_data_extension._breed
    local breed_name = breed_data and breed_data.name
    local breed_settings = companion_cancel_mark_breed_settings[breed_name]
    local health_threshold, time_threshold, distance_threshold
    if breed_settings and breed_settings.override then
        health_threshold = breed_settings.health_threshold or 0
        time_threshold = breed_settings.time_threshold or 0
        distance_threshold = breed_settings.distance_threshold or 0
    else
        health_threshold = mod_settings.companion_health_threshold
        time_threshold = mod_settings.companion_time_threshold
        distance_threshold = mod_settings.companion_distance_threshold
    end

    if health_threshold > 0 then
        local health_percent = Health.current_health_percent(marked_unit)
        if health_percent < health_threshold then
            mod:print_debug("cancel companion mark due to health threshold, health_percent:", health_percent)
            tag_context.canceled_units[marked_unit] = t + 3
            cancel_interval = CANCEL_INTERVAL
            mod:cancel_mark(marked_tag._id)
            return
        end
    end

    if time_threshold > 0 then
        local elapsed_time = t - tag_context.pounce_start_time
        if elapsed_time > time_threshold then
            mod:print_debug("cancel companion mark due to time threshold, elapsed_time:", elapsed_time)
            tag_context.canceled_units[marked_unit] = t + 3
            cancel_interval = CANCEL_INTERVAL
            mod:cancel_mark(marked_tag._id)
            return
        end
    end

    if distance_threshold > 0 then
        local companion_spawner_extension = context.companion_spawner_extension
        local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
        local companion_unit = companion_units and companion_units[1]
        if not companion_unit then
            goto exit
        end

        local player = context.player
        local player_unit = player and player.player_unit
        if not player_unit then
            goto exit
        end

        local POSITION_LOOKUP = POSITION_LOOKUP
        local companion_position = POSITION_LOOKUP[companion_unit] or Unit_world_position(companion_unit, 1)
        local player_position = POSITION_LOOKUP[player_unit] or Unit_world_position(player_unit, 1)
        if not companion_position or not player_position then
            goto exit
        end

        local distance_squared = Vector3_distance_squared(companion_position, player_position)
        if distance_squared > distance_threshold * distance_threshold then
            mod:print_debug("cancel companion mark due to distance threshold, distance squared:", distance_squared)
            tag_context.canceled_units[marked_unit] = t + 3
            cancel_interval = CANCEL_INTERVAL
            mod:cancel_mark(marked_tag._id)
            return
        end

        ::exit::
    end
end

-- Cache Unit Marked by Execution Order
mod:hook_safe(CLASS.OutlineSystem, "add_outline",
    function(self, unit, outline_name)
        if outline_name == EXECUTION_ORDER_OUTLINE_NAME then
            mark_context.execution_order_units[unit] = true
        end
    end)

-- Uncache Unit Unmarked by Execution Order
mod:hook_safe(CLASS.OutlineSystem, "remove_outline",
    function(self, unit, outline_name)
        if outline_name == EXECUTION_ORDER_OUTLINE_NAME then
            mark_context.execution_order_units[unit] = nil
        end
    end)

-- Uncache Unit Dead
mod:hook_safe(CLASS.OutlineSystem, "on_remove_extension",
    function(self, unit, extension_name)
        mark_context.execution_order_units[unit] = nil
    end)
