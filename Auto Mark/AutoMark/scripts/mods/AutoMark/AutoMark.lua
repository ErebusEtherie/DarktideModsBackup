---@class AutoMarkMod:DMFMod
local mod                  = get_mod("AutoMark")
local breeds               = require("scripts/settings/breed/breeds")
local Breed                = require("scripts/utilities/breed")

-- Global Cache
local CLASS                = CLASS
local HEALTH_ALIVE         = HEALTH_ALIVE
local ScriptUnit_extension = ScriptUnit.extension
local table_clear          = table.clear

-- Smart Tag Names
---@class AutoMarkTagNames
local TAG_NAMES            = {
    ENEMY_TAG       = "enemy_over_here",
    VETERAN_TAG     = "enemy_over_here_veteran",
    COMPANION_TAG   = "enemy_companion_target",
    SERVO_SKULL_TAG = "servo_skull_enemy_companion_target",
}
mod.TAG_NAMES              = TAG_NAMES

-- Mod Settings
---@class AutoMarkModSettings
local mod_settings         = {
    toggle_mod                                = mod:get("toggle_mod") or false,
    toggle_mod_keybind                        = mod:get("toggle_mod_keybind") or {},
    toggle_mod_notify                         = mod:get("toggle_mod_notify") or false,
    debug_mode                                = mod:get("debug_mode") or false,
    companion_mark_keybind                    = mod:get("companion_mark_keybind") or {},
    companion_mark_ignore_unaggroed           = mod:get("companion_mark_ignore_unaggroed") or false,
    companion_range_limitation                = mod:get("companion_range_limitation") or 0,
    execution_order_priority                  = mod:get("execution_order_priority") or false,
    execution_order_force_mark                = mod:get("execution_order_force_mark") or false,
    companion_mark_sticky_targeting           = mod:get("companion_mark_sticky_targeting") or false,
    companion_mark_sticky_targeting_elite     = mod:get("companion_mark_sticky_targeting_elite") or false,
    companion_mark_sticky_targeting_special   = mod:get("companion_mark_sticky_targeting_special") or false,
    companion_mark_sticky_targeting_boss      = mod:get("companion_mark_sticky_targeting_boss") or false,
    companion_cancel_mark                     = mod:get("companion_cancel_mark") or false,
    companion_cancel_mark_human               = mod:get("companion_cancel_mark_human") or false,
    companion_cancel_mark_non_human           = mod:get("companion_cancel_mark_non_human") or false,
    companion_health_threshold                = mod:get("companion_health_threshold") or 0,
    companion_time_threshold                  = mod:get("companion_time_threshold") or 0,
    companion_distance_threshold              = mod:get("companion_distance_threshold") or 0,
    servo_skull_mark_keybind                  = mod:get("servo_skull_mark_keybind") or {},
    servo_skull_mark_ignore_unaggroed         = mod:get("servo_skull_mark_ignore_unaggroed") or false,
    servo_skull_range_limitation              = mod:get("servo_skull_range_limitation") or 0,
    hack_mark_keybind                         = mod:get("hack_mark_keybind") or {},
    auto_hack                                 = mod:get("auto_hack") or false,
    disable_auto_hack_for_noospheric_command  = mod:get("disable_auto_hack_for_noospheric_command") or false,
    noospheric_command_boost                  = mod:get("noospheric_command_boost") or false,
    noospheric_command_boost_elite            = mod:get("noospheric_command_boost_elite") or false,
    noospheric_command_boost_special          = mod:get("noospheric_command_boost_special") or false,
    noospheric_command_boost_boss             = mod:get("noospheric_command_boost_boss") or false,
    capacitance_retention                     = mod:get("capacitance_retention") or false,
    capacitance_retention_elite_threshold     = mod:get("capacitance_retention_elite_threshold") or 0,
    capacitance_retention_special_threshold   = mod:get("capacitance_retention_special_threshold") or 0,
    capacitance_retention_boss_threshold      = mod:get("capacitance_retention_boss_threshold") or 0,
    servo_skull_mark_sticky_targeting         = mod:get("servo_skull_mark_sticky_targeting") or false,
    servo_skull_mark_sticky_targeting_elite   = mod:get("servo_skull_mark_sticky_targeting_elite") or false,
    servo_skull_mark_sticky_targeting_special = mod:get("servo_skull_mark_sticky_targeting_special") or false,
    servo_skull_mark_sticky_targeting_boss    = mod:get("servo_skull_mark_sticky_targeting_boss") or false,
    servo_skull_cancel_mark                   = mod:get("servo_skull_cancel_mark") or false,
    servo_skull_cancel_mark_time_threshold    = mod:get("servo_skull_cancel_mark_time_threshold") or 0,
    servo_skull_cancel_mark_health_threshold  = mod:get("servo_skull_cancel_mark_health_threshold") or 0,
    focus_target_overwrite                    = mod:get("focus_target_overwrite") or false,
    focus_target_overwrite_delta              = mod:get("focus_target_overwrite_delta") or 5,
    focus_target_ignore_unaggroed             = mod:get("focus_target_ignore_unaggroed") or false,
    focus_target_switch                       = mod:get("focus_target_switch") or false,
    focus_target_switch_override_manual       = mod:get("focus_target_switch_override_manual") or false,
    focus_target_switch_melee                 = mod:get("focus_target_switch_melee") or false,
    focus_target_switch_range                 = mod:get("focus_target_switch_range") or false,
}
mod.settings               = mod_settings
if mod:get("capacitance_retention_elite_threshold_negative_zero") then
    mod_settings.capacitance_retention_elite_threshold = -0
    mod:set("capacitance_retention_elite_threshold", -0, false)
end
if mod:get("capacitance_retention_special_threshold_negative_zero") then
    mod_settings.capacitance_retention_special_threshold = -0
    mod:set("capacitance_retention_special_threshold", -0, false)
end
if mod:get("capacitance_retention_boss_threshold_negative_zero") then
    mod_settings.capacitance_retention_boss_threshold = -0
    mod:set("capacitance_retention_boss_threshold", -0, false)
end

local noospheric_command_breed_settings = mod:get("noospheric_command_breed_settings") or {}
mod.noospheric_command_breed_settings   = noospheric_command_breed_settings
for _, breed_settings in pairs(noospheric_command_breed_settings) do
    if breed_settings.threshold_negative_zero then
        breed_settings.threshold = -0
    end
end

do
    local breed_name = mod:get("noospheric_command_boost_breed_name")
    local breed_settings = noospheric_command_breed_settings[breed_name]
    mod:set("noospheric_command_boost_breed_override", breed_settings and breed_settings.override or false, false)
    mod:set("noospheric_command_boost_breed_toggle", breed_settings and breed_settings.toggle or false, false)
    mod:set("capacitance_retention_breed_threshold", breed_settings and breed_settings.threshold or 0, false)
end

local companion_cancel_mark_breed_settings = mod:get("companion_cancel_mark_breed_settings") or {}
mod.companion_cancel_mark_breed_settings = companion_cancel_mark_breed_settings

-- Default Class Settings
---@class AutoMarkDefaultClassSettings
local DEFAULT_CLASS_SETTINGS = {
    toggle_class     = true,
    cooldown         = 25,
    reset_cooldown   = true,
    mark_limit       = true,
    min_range        = 0,
    max_range        = 100,
    max_angle        = 0,
    override_manual  = false,
    priority_switch  = false,
    toggle_elite     = true,
    toggle_special   = true,
    toggle_boss      = true,
    toggle_other     = true,
    breed_priorities = {},
}
for breed_name, breed_data in pairs(breeds) do
    if Breed.is_minion(breed_data) and breed_data.smart_tag_target_type == "breed" then
        if breed_data.tags.elite then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 0
        elseif breed_data.tags.special then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 1
        elseif breed_data.is_boss then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 1
            if breed_data.tags.witch then
                DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name .. "_passive"] = 1
            end
        elseif breed_data.faction_name ~= "imperium" then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 1
        end
    end
end
mod.DEFAULT_CLASS_SETTINGS               = DEFAULT_CLASS_SETTINGS

-- Context
---@class AutoMarkContext
local context                            = {
    mod_enabled                        = false,
    game_mode_valid                    = false,
    player                             = nil,
    class_name                         = nil,
    talent_resource_component          = nil,
    disabled_character_state_component = nil,
    has_companion                      = false,
    has_execution_order                = false,
    has_focus_target                   = false,
    focus_target_max_stacks            = 0,
    has_servo_skull                    = false,
    has_noospheric_command             = false,
    smart_targeting_extension          = nil,
    companion_spawner_extension        = nil,
    player_ability_extension           = nil,
    smart_tag_system                   = nil,
    outline_system                     = nil,
    smoke_fog_system                   = nil,
    force_field_system                 = nil,
    broadphase_system                  = nil,
    side_system                        = nil,
    hud_element_smart_tagging          = nil,
    companion_command_tap              = "double"
}
mod.context                              = context

-- Auto Mark Settings
local auto_mark_settings                 = mod:get("auto_mark_settings") or {}
mod.auto_mark_settings                   = auto_mark_settings

-- Mark States
---@class AutoMarkMarkContext
local mark_context                       = {
    auto_mark_interval          = 0,
    execution_order_units       = setmetatable({}, { __mode = "k" }),
    [TAG_NAMES.ENEMY_TAG]       = {
        tag                      = nil,
        cooldown                 = 0,
        priority_switch_cooldown = 0,
        delay                    = 0,
        manual_unit              = nil,
        manual_unit_expired_time = nil,
        is_manual                = false,
    },
    [TAG_NAMES.VETERAN_TAG]     = {
        tag                      = nil,
        cooldown                 = 0,
        priority_switch_cooldown = 0,
        delay                    = 0,
        manual_unit              = nil,
        manual_unit_expired_time = nil,
        is_manual                = false,
        switch_melee_unit        = nil,
        switch_range_unit        = nil,
        switch_unit_expired_time = nil,
        is_switch_melee          = false,
        is_switch_range          = false,
        removed_units            = setmetatable({}, { __mode = "k" }),
    },
    [TAG_NAMES.COMPANION_TAG]   = {
        tag                      = nil,
        cooldown                 = 0,
        priority_switch_cooldown = 0,
        delay                    = 0,
        manual_unit              = nil,
        manual_unit_expired_time = nil,
        is_manual                = false,
        pounce_start_time        = nil,
        is_cancelable            = false,
        canceled_units           = setmetatable({}, { __mode = "k" }),
        removed_units            = setmetatable({}, { __mode = "k" }),
    },
    [TAG_NAMES.SERVO_SKULL_TAG] = {
        tag                          = nil,
        cooldown                     = 0,
        priority_switch_cooldown     = 0,
        delay                        = 0,
        manual_unit                  = nil,
        manual_unit_expired_time     = nil,
        is_manual                    = false,
        noospheric_command_next_time = math.huge,
        servo_skull_lose_sight_time  = nil,
        canceled_units               = setmetatable({}, { __mode = "k" }),
        removed_units                = setmetatable({}, { __mode = "k" }),
    },
}
mod.mark_context                         = mark_context

-- Enemy Visbility Check
local visibility_cache                   = setmetatable({}, { __mode = "k" })
local visibility_check_frame             = setmetatable({}, { __mode = "k" })
mod.visibility_cache                     = visibility_cache
mod.visibility_check_frame               = visibility_check_frame
local servo_skull_visibility_cache       = setmetatable({}, { __mode = "k" })
local servo_skull_visibility_check_frame = setmetatable({}, { __mode = "k" })
mod.servo_skull_visibility_cache         = servo_skull_visibility_cache
mod.servo_skull_visibility_check_frame   = servo_skull_visibility_check_frame
mod.num_visibility_checks_this_frame     = 0

---@class AutoMarkDisablingTypes
local DISABLING_TYPES                    = {
    -- netted = true,
    pounced = true,
    warp_grabbed = true,
    mutant_charged = true,
    consumed = true,
    grabbed = true,
}
mod.DISABLING_TYPES                      = DISABLING_TYPES

-- Reset all params
local function reset_context()
    -- Reset Mark Params
    mark_context.auto_mark_interval = 0
    table_clear(mark_context.execution_order_units)
    table_clear(visibility_cache)
    table_clear(visibility_check_frame)
    table_clear(servo_skull_visibility_cache)
    table_clear(servo_skull_visibility_check_frame)
    for _, tag_name in pairs(TAG_NAMES) do
        local tag_context = mark_context[tag_name]
        tag_context.tag = nil
        tag_context.cooldown = 0
        tag_context.priority_switch_cooldown = 0
        tag_context.delay = 0
        tag_context.manual_unit = nil
        tag_context.manual_unit_expired_time = nil
        tag_context.is_manual = false
    end
    local veteran_tag_context = mark_context[TAG_NAMES.VETERAN_TAG]
    veteran_tag_context.switch_melee_unit = nil
    veteran_tag_context.switch_range_unit = nil
    veteran_tag_context.switch_unit_expired_time = nil
    veteran_tag_context.is_switch_melee = false
    veteran_tag_context.is_switch_range = false
    table_clear(veteran_tag_context.removed_units)
    local companion_tag_context = mark_context[TAG_NAMES.COMPANION_TAG]
    companion_tag_context.pounce_start_time = nil
    companion_tag_context.is_cancelable = false
    table_clear(companion_tag_context.canceled_units)
    table_clear(companion_tag_context.removed_units)
    local servo_skull_tag_context = mark_context[TAG_NAMES.SERVO_SKULL_TAG]
    servo_skull_tag_context.noospheric_command_next_time = math.huge
    servo_skull_tag_context.servo_skull_lose_sight_time = nil
    table_clear(servo_skull_tag_context.canceled_units)
    table_clear(servo_skull_tag_context.removed_units)
end

local function destroy_references()
    context.player                             = nil
    context.talent_resource_component          = nil
    context.disabled_character_state_component = nil
    context.smart_targeting_extension          = nil
    context.companion_spawner_extension        = nil
    context.player_ability_extension           = nil
    context.smart_tag_system                   = nil
    context.outline_system                     = nil
    context.smoke_fog_system                   = nil
    context.force_field_system                 = nil
    context.broadphase_system                  = nil
    context.side_system                        = nil
    context.hud_element_smart_tagging          = nil
    mod:destroy_visibility_raycast_objects()
end

-- Load Other Files
mod:io_dofile("AutoMark/scripts/mods/AutoMark/utils/utils")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/context/context")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/setting/class_setting")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/setting/option_setting")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/targeting/targeting")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/targeting/custom_targeting")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/mark/base_mark")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/mark/companion_mark")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/mark/focus_target_mark")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/mark/servo_skull_mark")

--  Mod Enabled
mod.on_enabled                = function(initial_call)
    context.mod_enabled = true
    mod:check_game_mode()
    mod:init_auto_mark_settings()
    -- init cache after mod enabled since all hooks were disabled
    mod:init_context()
    mod:init_execution_order_units()
    mod:init_visibility_raycast_objects()
    mod:set_menu_settings(mod:get_menu_class_name())
end

--  Mod Disabled
mod.on_disabled               = function(initial_call)
    context.mod_enabled = false
    -- mark info rest
    reset_context()
    destroy_references()
end

-- Enter/Exit GameplayStateRun
mod.on_game_state_changed     = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then
            mod:check_game_mode()
            -- game settings cache
            mod:init_game_settings()
            -- display
            mod:set_menu_settings(mod:get_menu_class_name())
        elseif status == "exit" then
            context.game_mode_valid = false
            -- menu mark info rest
            reset_context()
        end
    end
end

-- Mod Setting Change
mod.on_setting_changed        = function(setting_id)
    local result = mod:get(setting_id)
    local class_name = mod:get("class_selection")
    -- Normal Mod Settings
    if mod_settings[setting_id] ~= nil then
        mod_settings[setting_id] = result
        if setting_id == "capacitance_retention_elite_threshold" or setting_id == "capacitance_retention_special_threshold" or setting_id == "capacitance_retention_boss_threshold" then
            if result == -0 and 1 / result < 0 then
                mod:set(setting_id .. "_negative_zero", true, false)
            else
                mod:set(setting_id .. "_negative_zero", false, false)
            end
        end
        -- Apply Class Settings to Other Classes
    elseif setting_id == "apply_button" then
        if result == "apply_to_all" then
            mod:apply_to_all_classes(class_name)
        elseif result == "apply_to_normal" then
            mod:apply_to_normal_tag(class_name)
        end
        mod:set("apply_button", "blank", false)
        -- Reset Class Settings
    elseif setting_id == "reset_button" then
        if result == "reset_all" then
            mod:reset_auto_mark_settings()
        elseif result == "reset_current" then
            mod:reset_class_settings(class_name)
        end
        mod:set_menu_settings(class_name)
        mod:set("reset_button", "blank", false)
        -- Reset Noospheric Command Breed Settings
    elseif setting_id == "noospheric_command_boost_reset" then
        if result == "reset" then
            table_clear(noospheric_command_breed_settings)
            mod:set("noospheric_command_breed_settings", noospheric_command_breed_settings, false)
            mod:set("noospheric_command_boost_breed_name", mod:get("noospheric_command_boost_breed_name"), true)
        end
        mod:set("noospheric_command_boost_reset", "blank", false)
        -- Select Noospheric Command Breed Name
    elseif setting_id == "noospheric_command_boost_breed_name" then
        local breed_settings = noospheric_command_breed_settings[result]
        mod:set("noospheric_command_boost_breed_override", breed_settings and breed_settings.override or false, false)
        mod:set("servo_skull_range_limitation_breed", breed_settings and breed_settings.range_limitation or 0, false)
        mod:set("noospheric_command_boost_breed_toggle", breed_settings and breed_settings.toggle or false, false)
        mod:set("capacitance_retention_breed_threshold", breed_settings and breed_settings.threshold or 0, false)
        mod:set("servo_skull_mark_sticky_targeting_breed", breed_settings and breed_settings.sticky_targeting or false, false)
        mod:set("servo_skull_cancel_mark_breed_time_threshold", breed_settings and breed_settings.time_threshold or 0, false)
        mod:set("servo_skull_cancel_mark_breed_health_threshold", breed_settings and breed_settings.health_threshold or 0, false)
        -- Set Noospheric Command Breed Settings
    elseif setting_id == "noospheric_command_boost_breed_override"
        or setting_id == "servo_skull_range_limitation_breed"
        or setting_id == "noospheric_command_boost_breed_toggle"
        or setting_id == "capacitance_retention_breed_threshold"
        or setting_id == "servo_skull_mark_sticky_targeting_breed"
        or setting_id == "servo_skull_cancel_mark_breed_time_threshold"
        or setting_id == "servo_skull_cancel_mark_breed_health_threshold"
    then
        local breed_name = mod:get("noospheric_command_boost_breed_name")
        if noospheric_command_breed_settings[breed_name] == nil then
            noospheric_command_breed_settings[breed_name] = { override = false, range_limitation = 0, toggle = false, threshold = 0, threshold_negative_zero = false, sticky_targeting = false, time_threshold = 0, health_threshold = 0 }
        end
        if setting_id == "noospheric_command_boost_breed_override" then
            noospheric_command_breed_settings[breed_name].override = result
        elseif setting_id == "servo_skull_range_limitation_breed" then
            noospheric_command_breed_settings[breed_name].range_limitation = result
        elseif setting_id == "noospheric_command_boost_breed_toggle" then
            noospheric_command_breed_settings[breed_name].toggle = result
        elseif setting_id == "capacitance_retention_breed_threshold" then
            noospheric_command_breed_settings[breed_name].threshold = result
            if result == -0 and 1 / result < 0 then
                noospheric_command_breed_settings[breed_name].threshold_negative_zero = true
            else
                noospheric_command_breed_settings[breed_name].threshold_negative_zero = false
            end
        elseif setting_id == "servo_skull_mark_sticky_targeting_breed" then
            noospheric_command_breed_settings[breed_name].sticky_targeting = result
        elseif setting_id == "servo_skull_cancel_mark_breed_time_threshold" then
            noospheric_command_breed_settings[breed_name].time_threshold = result
        elseif setting_id == "servo_skull_cancel_mark_breed_health_threshold" then
            noospheric_command_breed_settings[breed_name].health_threshold = result
        end
        mod:set("noospheric_command_breed_settings", noospheric_command_breed_settings, false)
        -- Reset Companion Cancel Mark Breed Settings
    elseif setting_id == "companion_cancel_mark_reset" then
        if result == "reset" then
            table_clear(companion_cancel_mark_breed_settings)
            mod:set("companion_cancel_mark_breed_settings", companion_cancel_mark_breed_settings, false)
            mod:set("companion_cancel_mark_breed_name", mod:get("companion_cancel_mark_breed_name"), true)
        end
        mod:set("companion_cancel_mark_reset", "blank", false)
        -- Select Companion Cancel Mark Breed Name
    elseif setting_id == "companion_cancel_mark_breed_name" then
        local breed_settings = companion_cancel_mark_breed_settings[result]
        mod:set("companion_cancel_mark_breed_override", breed_settings and breed_settings.override or false, false)
        mod:set("companion_range_limitation_breed", breed_settings and breed_settings.range_limitation or 0, false)
        mod:set("companion_mark_max_distance_breed", breed_settings and breed_settings.max_distance or 0, false)
        mod:set("companion_mark_sticky_targeting_breed", breed_settings and breed_settings.sticky_targeting or false, false)
        mod:set("companion_cancel_mark_breed_health_threshold", breed_settings and breed_settings.health_threshold or 0, false)
        mod:set("companion_cancel_mark_breed_time_threshold", breed_settings and breed_settings.time_threshold or 0, false)
        mod:set("companion_cancel_mark_breed_distance_threshold", breed_settings and breed_settings.distance_threshold or 0, false)
        -- Set Companion Cancel Mark Breed Settings
    elseif setting_id == "companion_cancel_mark_breed_override"
        or setting_id == "companion_range_limitation_breed"
        or setting_id == "companion_mark_max_distance_breed"
        or setting_id == "companion_mark_sticky_targeting_breed"
        or setting_id == "companion_cancel_mark_breed_health_threshold"
        or setting_id == "companion_cancel_mark_breed_time_threshold"
        or setting_id == "companion_cancel_mark_breed_distance_threshold"
    then
        local breed_name = mod:get("companion_cancel_mark_breed_name")
        if companion_cancel_mark_breed_settings[breed_name] == nil then
            companion_cancel_mark_breed_settings[breed_name] = { override = false, range_limitation = 0, max_distance = 0, sticky_targeting = false, health_threshold = 0, time_threshold = 0, distance_threshold = 0 }
        end
        if setting_id == "companion_cancel_mark_breed_override" then
            companion_cancel_mark_breed_settings[breed_name].override = result
        elseif setting_id == "companion_range_limitation_breed" then
            companion_cancel_mark_breed_settings[breed_name].range_limitation = result
        elseif setting_id == "companion_mark_max_distance_breed" then
            companion_cancel_mark_breed_settings[breed_name].max_distance = result
        elseif setting_id == "companion_mark_sticky_targeting_breed" then
            companion_cancel_mark_breed_settings[breed_name].sticky_targeting = result
        elseif setting_id == "companion_cancel_mark_breed_health_threshold" then
            companion_cancel_mark_breed_settings[breed_name].health_threshold = result
        elseif setting_id == "companion_cancel_mark_breed_time_threshold" then
            companion_cancel_mark_breed_settings[breed_name].time_threshold = result
        elseif setting_id == "companion_cancel_mark_breed_distance_threshold" then
            companion_cancel_mark_breed_settings[breed_name].distance_threshold = result
        end
        mod:set("companion_cancel_mark_breed_settings", companion_cancel_mark_breed_settings, false)
        -- Set Class Name
    elseif setting_id == "class_selection" then
        mod:set_menu_settings(class_name)
        -- Set Class Settings
    else
        local class_settings = auto_mark_settings[class_name]
        if DEFAULT_CLASS_SETTINGS[setting_id] ~= nil then
            class_settings[setting_id] = result
        elseif DEFAULT_CLASS_SETTINGS.breed_priorities[setting_id] ~= nil then
            class_settings.breed_priorities[setting_id] = result
        end
        mod:set("auto_mark_settings", auto_mark_settings, false)
    end
end

-- Toggle Mod Enabled/Disabled
mod.toggle_mod                = function()
    if mod_settings.toggle_mod_notify then
        mod:notify("Auto Mark " .. (not mod_settings.toggle_mod and "Enabled" or "Disabled"))
    end
    mod:set("toggle_mod", not mod_settings.toggle_mod, true)
end

local talent_settings         = require("scripts/settings/talent/talent_settings")
local cryptic_talent_settings = talent_settings.cryptic
local function can_noospheric_command_boost()
    local player_ability_extension = context.player_ability_extension
    if not player_ability_extension then
        return false
    end

    return player_ability_extension:has_enough_ability_capacitance("combat_ability", cryptic_talent_settings.servo_skull_shooting_tagging.minimum_capacitance)
end

local function is_sticky_targeting(tag_name, marked_tag)
    if tag_name == TAG_NAMES.COMPANION_TAG then
        if not mod_settings.companion_mark_sticky_targeting then
            return false
        end

        local marked_unit = marked_tag._target_unit
        local unit_data_extension = ScriptUnit_extension(marked_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        if not breed_data then
            return false
        end

        local breed_name = breed_data.name
        local breed_settings = companion_cancel_mark_breed_settings[breed_name]
        if breed_settings and breed_settings.override then
            return breed_settings.sticky_targeting
        end

        if breed_data.is_boss then
            return mod_settings.companion_mark_sticky_targeting_boss
        elseif breed_data.tags.special then
            return mod_settings.companion_mark_sticky_targeting_special
        else
            return mod_settings.companion_mark_sticky_targeting_elite
        end
    elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
        if not mod_settings.servo_skull_mark_sticky_targeting then
            return false
        end

        local marked_unit = marked_tag._target_unit
        local unit_data_extension = ScriptUnit_extension(marked_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        if not breed_data then
            return false
        end

        local breed_name = breed_data.name
        local breed_settings = noospheric_command_breed_settings[breed_name]
        if breed_settings and breed_settings.override then
            return breed_settings.sticky_targeting
        end

        if breed_data.is_boss then
            return mod_settings.servo_skull_mark_sticky_targeting_boss
        elseif breed_data.tags.special then
            return mod_settings.servo_skull_mark_sticky_targeting_special
        else
            return mod_settings.servo_skull_mark_sticky_targeting_elite
        end
    else
        return false
    end
end

-- Check if Tag is Valid for Current Class
local function is_tag_valid(tag_name)
    if tag_name == TAG_NAMES.COMPANION_TAG then
        return context.class_name == "adamant" and context.has_companion
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        return context.class_name == "veteran" and context.has_focus_target
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        return context.class_name ~= "veteran" or not context.has_focus_target
    elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
        return context.class_name == "cryptic" and context.has_servo_skull and not mod:is_servo_skull_hacking()
    end
    return false
end

local disabled_mark_interval = 0
-- Auto-Mark Target Unit with the Tag
local function auto_mark_by_tag(tag_name, t, fixed_frame)
    if not is_tag_valid(tag_name) then
        return false
    end

    local tag_context = mark_context[tag_name]
    local marked_tag = tag_context.tag
    local marked_tag_is_manual = tag_context.is_manual
    local disabled_character_state_component = context.disabled_character_state_component
    local is_character_disabled = disabled_character_state_component and disabled_character_state_component.is_disabled and DISABLING_TYPES[disabled_character_state_component.disabling_type]
    if not is_character_disabled then
        disabled_mark_interval = 0
    end

    local target_unit, target_tag, target_is_dormant_daemonhost
    if (tag_name == TAG_NAMES.COMPANION_TAG or tag_name == TAG_NAMES.SERVO_SKULL_TAG) and is_character_disabled then
        local disabling_unit = disabled_character_state_component and disabled_character_state_component.disabling_unit
        if disabling_unit and (not marked_tag or marked_tag._target_unit ~= disabling_unit) then
            mod:print_debug("Auto Mark Disabling Unit")
            disabled_mark_interval = 3
            target_unit = disabling_unit
        end
    else
        local class_settings = mod:get_class_settings(tag_name)
        -- mark when cooldown is zero
        local is_cooldown_ready = tag_context.cooldown <= 0 and (not class_settings.mark_limit or not marked_tag)
        -- mark when priority switch is on
        local is_priority_switch = class_settings.priority_switch and marked_tag
        -- mark when execution order priority is on
        local is_execution_order_priority = mod_settings.execution_order_priority and tag_name == TAG_NAMES.COMPANION_TAG and context.has_execution_order
        if class_settings.toggle_class and (class_settings.override_manual or not marked_tag_is_manual) then
            if is_cooldown_ready then
                target_unit, target_tag, target_is_dormant_daemonhost = mod:find_target_unit_custom("auto", class_settings.min_range, class_settings.max_range, class_settings.max_angle, tag_name, tag_context, class_settings, is_execution_order_priority)
            elseif tag_context.priority_switch_cooldown <= 0 and (is_priority_switch or is_execution_order_priority and marked_tag) and not is_sticky_targeting(tag_name, marked_tag) then
                target_unit, target_tag, target_is_dormant_daemonhost = mod:find_target_unit_custom("auto", class_settings.min_range, class_settings.max_range, class_settings.max_angle, tag_name, tag_context, class_settings, is_execution_order_priority, marked_tag)
            end
        end
    end

    if target_unit then
        if tag_name == TAG_NAMES.VETERAN_TAG and target_is_dormant_daemonhost then
            mod:set_auto_mark(TAG_NAMES.ENEMY_TAG, target_unit, target_tag)
        else
            mod:set_auto_mark(tag_name, target_unit, target_tag)
        end
        return true
    end

    if tag_name == TAG_NAMES.VETERAN_TAG then
        if mod_settings.focus_target_overwrite and marked_tag then
            local marked_unit = marked_tag._target_unit
            if not mod:is_dormant_daemonhost(marked_unit) and mod:can_focus_target_overwrite(marked_unit, marked_tag) then
                mod:print_debug("Focus Target Overwrite")
                if marked_tag_is_manual then
                    mod:set_manual_mark(tag_name, marked_unit, target_tag)
                else
                    mod:set_auto_mark(tag_name, marked_unit, target_tag)
                end

                return true
            end
        end
    elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
        if mod_settings.noospheric_command_boost and context.has_noospheric_command and marked_tag and t >= tag_context.noospheric_command_next_time and can_noospheric_command_boost() then
            local marked_unit = marked_tag._target_unit
            local unit_data_extension = ScriptUnit_extension(marked_unit, "unit_data_system")
            local breed_data = unit_data_extension and unit_data_extension._breed
            if is_character_disabled or mod:is_noospheric_command_boost_breed_valid(marked_unit) and mod:is_target_valid(tag_name, nil, marked_unit, breed_data) and mod:is_servo_skull_target_visible(marked_unit, fixed_frame, true) then
                mod:print_debug("Noospheric Command Boost")
                if marked_tag_is_manual then
                    mod:set_manual_mark(tag_name, marked_unit, target_tag)
                else
                    mod:set_auto_mark(tag_name, marked_unit, target_tag)
                end

                return true
            end
        end
    end

    return false
end

-- Auto-Mark
local function auto_mark(dt, t, fixed_frame)
    -- calculate interval
    if mark_context.auto_mark_interval > 0 then
        mark_context.auto_mark_interval = mark_context.auto_mark_interval - dt
    end
    -- calculate cooldown and delay for all tags
    for _, tag_name in pairs(TAG_NAMES) do
        local tag_context = mark_context[tag_name]
        if tag_context.delay > 0 then
            tag_context.delay = tag_context.delay - dt
        end
        if tag_context.cooldown > 0 then
            tag_context.cooldown = tag_context.cooldown - dt
        end
        if tag_context.priority_switch_cooldown > 0 then
            tag_context.priority_switch_cooldown = tag_context.priority_switch_cooldown - dt
        end
    end
    if disabled_mark_interval > 0 then
        disabled_mark_interval = disabled_mark_interval - dt
    end
    -- skip if auto mark is disabled
    if not mod_settings.toggle_mod then
        return
    end
    -- pause auto mark for a period of time after it is executed.
    if mark_context.auto_mark_interval > 0 then
        return
    end
    for _, tag_name in pairs(TAG_NAMES) do
        local tag_context = mark_context[tag_name]
        if tag_context.delay > 0 then
            return
        end
    end

    -- three kinds of tag to mark
    if auto_mark_by_tag(TAG_NAMES.COMPANION_TAG, t, fixed_frame) then
        return
    end

    if auto_mark_by_tag(TAG_NAMES.SERVO_SKULL_TAG, t, fixed_frame) then
        return
    end

    if auto_mark_by_tag(TAG_NAMES.VETERAN_TAG, t, fixed_frame) then
        return
    end

    if auto_mark_by_tag(TAG_NAMES.ENEMY_TAG, t, fixed_frame) then
        return
    end
end

local function clean_visibility_cache(fixed_frame)
    if fixed_frame % 3120 == 0 then
        local frame_threshold = fixed_frame - 5
        for cached_unit, check_frame in pairs(visibility_check_frame) do
            if check_frame < frame_threshold then
                visibility_cache[cached_unit] = nil
                visibility_check_frame[cached_unit] = nil
            end
        end
        for cached_unit, check_frame in pairs(servo_skull_visibility_check_frame) do
            if check_frame < frame_threshold then
                servo_skull_visibility_cache[cached_unit] = nil
                servo_skull_visibility_check_frame[cached_unit] = nil
            end
        end
    end
end

local function clean_expired_units(t)
    for _, tag_name in pairs(TAG_NAMES) do
        local tag_context = mark_context[tag_name]
        if tag_context.manual_unit_expired_time and t >= tag_context.manual_unit_expired_time then
            tag_context.manual_unit = nil
            tag_context.manual_unit_expired_time = nil
        end
        if tag_context.switch_unit_expired_time and t >= tag_context.switch_unit_expired_time then
            tag_context.switch_melee_unit = nil
            tag_context.switch_range_unit = nil
            tag_context.switch_unit_expired_time = nil
        end
        local canceled_units = tag_context.canceled_units
        if canceled_units then
            for unit, expired_time in pairs(canceled_units) do
                if t >= expired_time or not HEALTH_ALIVE[unit] then
                    canceled_units[unit] = nil
                end
            end
        end
        local removed_units = tag_context.removed_units
        if removed_units then
            for unit, expired_time in pairs(removed_units) do
                if t >= expired_time then
                    removed_units[unit] = nil
                end
            end
        end
    end
end

-- Main Entry For Auto Mark
mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "fixed_update",
    function(self, unit, dt, t, fixed_frame)
        if self._player.viewport_name ~= "player1" then
            return
        end

        if context.game_mode_valid then
            mod.num_visibility_checks_this_frame = 0
            clean_expired_units(t)
            clean_visibility_cache(fixed_frame)
            mod:auto_cancel_companion_mark(dt, t)
            mod:auto_cancel_servo_skull_mark(dt, t, fixed_frame)
            mod:auto_hack(dt, t, fixed_frame)
            auto_mark(dt, t, fixed_frame)
        end
    end)
