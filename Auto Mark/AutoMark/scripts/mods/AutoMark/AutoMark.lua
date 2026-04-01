local mod                           = get_mod("AutoMark")
local breeds                        = require("scripts/settings/breed/breeds")
local archetypes                    = require("scripts/settings/archetype/archetypes")
local Breed                         = require("scripts/utilities/breed")
local Health                        = require("scripts/utilities/health")
local talent_settings               = require("scripts/settings/talent/talent_settings")
local veteran_talent_settings       = talent_settings.veteran
local veteran_tag_max_stacks        = veteran_talent_settings.veteran_tag.max_stacks
local veteran_tag_max_stacks_talent = veteran_talent_settings.veteran_tag.max_stacks_talent

-- Global Cache
local CLASS                         = CLASS
local HEALTH_ALIVE                  = HEALTH_ALIVE
local ScriptUnit                    = ScriptUnit
local Managers                      = Managers
local callback                      = callback
local unit_world_position           = Unit.world_position
local vector3_distance_squared      = Vector3.distance_squared
local table_clone                   = table.clone

-- Smart Tag Names
local TAG_NAMES                     = {
    ENEMY_TAG     = "enemy_over_here",
    VETERAN_TAG   = "enemy_over_here_veteran",
    COMPANION_TAG = "enemy_companion_target",
}

-- Valid Game Modes For Mark System
local VALID_GAME_MODES              = {
    training_grounds = true,
    shooting_range = true,
    survival = true,
    coop_complete_objective = true,
    expedition = true,
}

-- Additional Class Name for Arbites and Veteran
local ADAMANT_COMPANION             = "adamant_companion"
local VETERAN_FOCUS_TARGET          = "veteran_focus_target"

-- Valid Class Names
local VALID_CLASSES                 = {
    [ADAMANT_COMPANION] = true,
    [VETERAN_FOCUS_TARGET] = true,
}

for class_name, _ in pairs(archetypes) do
    VALID_CLASSES[class_name] = true
end

-- Outline Name For Execution Order Detection
local EXECUTION_ORDER_OUTLINE_NAME  = "adamant_mark_target"

-- Talent Names
local TALENT_NAMES                  = {
    LONE_WOLF = "adamant_disable_companion",
    EXECUTION_ORDER = "adamant_execution_order",
    FOCUS_TARGET = "veteran_improved_tag",
    FOCUSED_FIRE = "veteran_improved_tag_more_damage",
}

-- Delay for Server Latency, Interval for Auto Mark
local AUTO_MARK_DELAY               = 0.5
local AUTO_MARK_INTERVAL            = 0.2

-- Player Cache
local player                        = nil
local player_class_name             = nil

-- Player Component Cache
local talent_resource_component     = nil

-- Player Talent Status
local has_companion                 = false
local has_execution_order           = false
local has_focus_target              = false
local forcus_target_max_stacks      = 0

-- Extension Cache
local playerSmartTargetingExtension = nil
local companionSpawnerExtension     = nil

-- System Cache
local smartTagSystem                = nil
local outlineSystem                 = nil

-- Mod Settings
local mod_settings                  = {
    toggle_mod = mod:get("toggle_mod") or false,
    toggle_mod_notify = mod:get("toggle_mod_notify") or false,
    debug_mode = mod:get("debug_mode") or false,
    execution_order_priority = mod:get("execution_order_priority") or false,
    companion_range_limitation = mod:get("companion_range_limitation") or 0,
    companion_cancel_mark = mod:get("companion_cancel_mark") or false,
    companion_health_threshold = mod:get("companion_health_threshold") or 0,
    companion_time_threshold = mod:get("companion_time_threshold") or 0,
    focus_target_overwrite = mod:get("focus_target_overwrite") or false,
    focus_target_overwrite_delta = mod:get("focus_target_overwrite_delta") or 1,
    focus_target_switch = mod:get("focus_target_switch") or false,
}

-- Auto Mark Settings
local auto_mark_settings            = mod:get("auto_mark_settings") or {}

-- Default Class Settings
local DEFAULT_CLASS_SETTINGS        = {
    toggle_class = true,
    cooldown = 25,
    reset_cooldown = true,
    mark_limit = true,
    max_range = 100,
    override_manual = false,
    priority_switch = false,
    toggle_elite = true,
    toggle_special = true,
    toggle_boss = true,
    toggle_other = true,
    breed_priorities = {},
}

for breed_name, breed_data in pairs(breeds) do
    if Breed.is_minion(breed_data) then
        if breed_data.tags.elite then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 1
        elseif breed_data.tags.special then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 2
        elseif breed_data.is_boss then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 3
        elseif breed_data.smart_tag_target_type == "breed" then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 1
        end
    end
end

-- Game Settings
local companion_command_tap = "double"

-- Mod Status
local mod_enabled           = false
local is_game_mode_valid    = false

-- Mark Params
local auto_mark_delay       = 0
local auto_mark_interval    = 0
local mark_infos            = {
    [TAG_NAMES.ENEMY_TAG] = {
        tag = nil,
        cooldown = 0,
        delay = 0,
        manual_target_unit = nil,
        is_manual = false,
    },
    [TAG_NAMES.VETERAN_TAG] = {
        tag = nil,
        cooldown = 0,
        delay = 0,
        manual_target_unit = nil,
        is_manual = false,
    },
    [TAG_NAMES.COMPANION_TAG] = {
        tag = nil,
        cooldown = 0,
        delay = 0,
        manual_target_unit = nil,
        is_manual = false,
        pounce_start_time = nil,
        is_cancelable = false,
        canceled_target_unit = nil,
    },
}

-- Print Debug
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

-- Time for Now
local function main_time()
    return Managers.time:time("main")
end

local function gameplay_time()
    return Managers.time:time("gameplay")
end

-- Init Auto Mark Settings
local function init_auto_mark_settings()
    for class_name, _ in pairs(VALID_CLASSES) do
        if auto_mark_settings[class_name] == nil then
            auto_mark_settings[class_name] = {}
        end
        local class_settings = auto_mark_settings[class_name]
        for setting_name, default_setting in pairs(DEFAULT_CLASS_SETTINGS) do
            if setting_name == "breed_priorities" then
                if type(default_setting) == "table" then
                    if class_settings[setting_name] == nil then
                        class_settings[setting_name] = {}
                    end
                    local breed_priorities = class_settings[setting_name]
                    for breed_name, default_priority in pairs(default_setting) do
                        if breed_priorities[breed_name] == nil then
                            breed_priorities[breed_name] = default_priority
                        end
                    end
                end
            elseif class_settings[setting_name] == nil then
                class_settings[setting_name] = default_setting
            end
        end
    end
    mod:set("auto_mark_settings", auto_mark_settings, false)
end

-- Reset Auto Mark Settings to Default
local function reset_auto_mark_settings()
    for class_name, _ in pairs(VALID_CLASSES) do
        if auto_mark_settings[class_name] == nil then
            auto_mark_settings[class_name] = {}
        end
        local class_settings = auto_mark_settings[class_name]
        for setting_name, default_setting in pairs(DEFAULT_CLASS_SETTINGS) do
            if setting_name == "breed_priorities" then
                if type(default_setting) == "table" then
                    if class_settings[setting_name] == nil then
                        class_settings[setting_name] = {}
                    end
                    local breed_priorities = class_settings[setting_name]
                    for breed_name, default_priority in pairs(default_setting) do
                        breed_priorities[breed_name] = default_priority
                    end
                end
            else
                class_settings[setting_name] = default_setting
            end
        end
    end
    mod:set("auto_mark_settings", auto_mark_settings, false)
end

-- Apply Settings to All Classes
local function apply_to_all_classes(class_name)
    for other_class_name, _ in pairs(VALID_CLASSES) do
        if other_class_name ~= class_name then
            auto_mark_settings[other_class_name] = table_clone(auto_mark_settings[class_name])
        end
    end
    mod:set("auto_mark_settings", auto_mark_settings, false)
end

-- Set Menu for Display
local function set_menu_settings(class_name)
    if not class_name then
        class_name = "adamant"
    end

    if not VALID_CLASSES[class_name] then
        return
    end

    mod:set("class_selection", class_name, false)
    if auto_mark_settings[class_name] == nil then
        auto_mark_settings[class_name] = {}
    end
    local class_settings = auto_mark_settings[class_name]
    for setting_name, default_setting in pairs(DEFAULT_CLASS_SETTINGS) do
        if setting_name == "breed_priorities" then
            if type(default_setting) == "table" then
                if class_settings[setting_name] == nil then
                    class_settings[setting_name] = {}
                end
                local breed_priorities = class_settings[setting_name]
                for breed_name, default_priority in pairs(default_setting) do
                    local breed_priority = breed_priorities[breed_name]
                    if breed_priority == nil then
                        breed_priority = default_priority
                    end
                    mod:set(breed_name, breed_priority, false)
                end
            end
        else
            local setting = class_settings[setting_name]
            if setting == nil then
                setting = default_setting
            end
            mod:set(setting_name, setting, false)
        end
    end
end

-- Get Class Settings by Tag Name
local function get_class_settings(tag_name)
    if tag_name == TAG_NAMES.ENEMY_TAG then
        return auto_mark_settings[player_class_name]
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        return auto_mark_settings[VETERAN_FOCUS_TARGET]
    elseif tag_name == TAG_NAMES.COMPANION_TAG then
        return auto_mark_settings[ADAMANT_COMPANION]
    end
end

-- Get Class Name
local function get_menu_class_name()
    if player_class_name == "adamant" and has_companion then
        return ADAMANT_COMPANION
    elseif player_class_name == "veteran" and has_focus_target then
        return VETERAN_FOCUS_TARGET
    else
        return player_class_name or "adamant"
    end
end

-- Get Extensions
local function get_player_talent_extension()
    return player and ScriptUnit.extension(player.player_unit, "talent_system")
end

local function get_player_data_extension()
    return player and ScriptUnit.extension(player.player_unit, "unit_data_system")
end

local function get_player_smart_targeting_extension()
    return player and ScriptUnit.extension(player.player_unit, "smart_targeting_system")
end

local function get_player_companion_spawner_extension()
    return player and ScriptUnit.extension(player.player_unit, "companion_spawner_system")
end

-- Init Player
local function init_player()
    local result = Managers.player:local_player_safe(1)
    if result then
        player = result
    end
    result = player and player:archetype_name()
    if result then
        player_class_name = result
    end
end

-- Init Player Component
local function init_player_components(playerDataExtension)
    playerDataExtension = playerDataExtension or get_player_data_extension()
    local result = playerDataExtension and playerDataExtension:read_component("talent_resource")
    if result then
        talent_resource_component = result
    end
end

-- Init Extensions
local function init_player_extensions()
    local result = get_player_smart_targeting_extension()
    if result then
        playerSmartTargetingExtension = result
    end
    result = get_player_companion_spawner_extension()
    if result then
        companionSpawnerExtension = result
    end
end

-- Init Talent Status
local function init_player_talent_status(playerTalenExtension)
    playerTalenExtension = playerTalenExtension or get_player_talent_extension()
    if not playerTalenExtension then
        return
    end

    local talents = playerTalenExtension._talents
    -- has companion
    has_companion = player_class_name == "adamant" and not talents[TALENT_NAMES.LONE_WOLF]
    -- has execution order
    has_execution_order = player_class_name == "adamant" and not not talents[TALENT_NAMES.EXECUTION_ORDER]
    -- has focus target
    has_focus_target = player_class_name == "veteran" and not not talents[TALENT_NAMES.FOCUS_TARGET]
    -- has focused fire
    local has_focused_fire = not not talents[TALENT_NAMES.FOCUSED_FIRE]
    -- focus target max stacks
    forcus_target_max_stacks =
        player_class_name == "veteran" and has_focus_target
        and (has_focused_fire and veteran_tag_max_stacks_talent or veteran_tag_max_stacks)
        or 0

    print_debug("has companion", has_companion)
    print_debug("has execution order", has_execution_order)
    print_debug("has focus target", has_focus_target)
    print_debug("focus target max stacks", forcus_target_max_stacks)
end

-- Init Systems
local function init_smart_tag_system()
    local result = Managers.state.extension and Managers.state.extension:system("smart_tag_system")
    if result then
        smartTagSystem = result
    end
end

local function init_outline_system()
    local result = Managers.state.extension and Managers.state.extension:system("outline_system")
    if result then
        outlineSystem = result
    end
end

-- Init Settings
local function init_game_settings()
    companion_command_tap = Managers.save:account_data().input_settings.companion_command_tap
end

-- Check Game Mode Valid for Mark System
local function check_game_mode()
    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    is_game_mode_valid = not not VALID_GAME_MODES[game_mode_name]
    print_debug("game mode", game_mode_name, is_game_mode_valid and "is valid" or "is not valid")
end

-- Init all params
local function init_cache()
    -- Init Player
    init_player()
    -- Init Player Components
    init_player_components()
    -- Init Extensions
    init_player_extensions()
    -- Init Talents Status
    init_player_talent_status()
    -- Init Systems
    init_smart_tag_system()
    init_outline_system()
end

-- Reset all params
local function reset_params()
    -- Reset Mod State
    is_game_mode_valid = false
    -- Reset Mark Params
    auto_mark_delay = 0
    auto_mark_interval = 0
    for _, mark_info in pairs(mark_infos) do
        mark_info.tag = nil
        mark_info.cooldown = 0
        mark_info.delay = 0
        mark_info.manual_target_unit = nil
        mark_info.is_manual = false
        mark_info.pounce_start_time = nil
        mark_info.is_cancelable = false
        mark_info.canceled_target_unit = nil
    end
end

-- Custome Templates for Smart Targeting System
local SMART_TARGETING_TEMPLATE_MELEE = {
    precision_target = {
        max_range = 5,
        min_range = 1,
        smart_tagging = true,
    },
}
local SMART_TARGETING_TEMPLATE_RANGE = {
    precision_target = {
        max_range = 100,
        min_range = 1,
        smart_tagging = true,
    },
}
local smart_targeting_template_auto = {
    precision_target = {
        max_range = nil,
        min_range = 1,
        smart_tagging = true,
        within_distance_to_box_x = math.huge,
        within_distance_to_box_y = math.huge,
    },
}
-- Find Target Unit For Mark System
local function find_target_unit(smart_targeting_template)
    if not playerSmartTargetingExtension then
        return nil
    end

    local ray_origin, forward, right, up = playerSmartTargetingExtension:_targeting_parameters()
    playerSmartTargetingExtension._precision_target_aim_assist:update_precision_target(
        playerSmartTargetingExtension._unit,
        smart_targeting_template,
        ray_origin, forward, right, up,
        playerSmartTargetingExtension._smart_tag_targeting_data,
        playerSmartTargetingExtension._latest_fixed_frame,
        playerSmartTargetingExtension._visibility_cache,
        playerSmartTargetingExtension._visibility_check_frame
    )
    local targeting_data = playerSmartTargetingExtension:smart_tag_targeting_data()
    local target_unit = targeting_data and targeting_data.unit
    return HEALTH_ALIVE[target_unit] and target_unit
end

-- set delay and interval for auto mark
local function on_set_tag(mark_info)
    mark_info.delay = AUTO_MARK_DELAY
    auto_mark_delay = AUTO_MARK_DELAY
    auto_mark_interval = AUTO_MARK_INTERVAL
end

-- record manual marked unit
local function on_manual_mark(mark_info, target_unit)
    mark_info.manual_target_unit = target_unit
end

-- cancel mark by tag id
local function cancel_mark(tag_id)
    if not smartTagSystem then
        return
    end

    local player_unit = player and player.player_unit
    if not player_unit then
        return
    end

    smartTagSystem:cancel_tag(tag_id, player_unit)
end

-- mark target unit with tag
local function mark(tag_name, target_unit, target_tag)
    local mark_info = mark_infos[tag_name]
    local player_unit = player and player.player_unit
    if
        not player_unit
        or not target_unit
        or not mark_info
        or not smartTagSystem
    then
        return
    end

    if target_tag then
        if tag_name == TAG_NAMES.ENEMY_TAG then
            return
        elseif tag_name == TAG_NAMES.COMPANION_TAG or tag_name == TAG_NAMES.VETERAN_TAG then
            local template = target_tag._template
            local is_enemy_mark = template and template.name == TAG_NAMES.ENEMY_TAG
            if is_enemy_mark then
                local tagger_player = target_tag._tagger_player
                local tagger_player_unit = tagger_player and tagger_player.player_unit
                if tagger_player_unit then
                    smartTagSystem:cancel_tag(target_tag._id, tagger_player_unit, true)
                end
            end
        end
    end

    -- set delay and interval for auto mark
    on_set_tag(mark_info)
    smartTagSystem:set_tag(tag_name, player_unit, target_unit)
end

-- check if target unit marked by execution order by outlineSystem
local function is_marked_by_execution_order(unit)
    if unit and outlineSystem then
        return outlineSystem:has_outline(unit, EXECUTION_ORDER_OUTLINE_NAME)
    end
end

--  Mod Enabled
mod.on_enabled = function()
    mod_enabled = true
    -- init cache after mod enabled since all hooks were disabled
    init_cache()
    -- init game settings after mod enabled since all hooks were disabled
    init_game_settings()
    -- display
    set_menu_settings(get_menu_class_name())
    -- game mode validation
    check_game_mode()
end

--  Mod Disabled
mod.on_disabled = function()
    mod_enabled = false
    -- mark info rest
    reset_params()
end

-- When Mod first loaded
mod.on_all_mods_loaded = function()
    -- class cache
    init_cache()
    -- game settings cache
    init_game_settings()
    -- mod settings
    init_auto_mark_settings()
    -- display
    set_menu_settings(get_menu_class_name())
    -- game mode validation
    check_game_mode()
end

-- Enter/Exit GameplayStateRun
mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then
            print_debug("enter GameplayStateRun")
            -- game settings cache
            init_game_settings()
            -- display
            set_menu_settings(get_menu_class_name())
            -- game mode validation
            check_game_mode()
        elseif status == "exit" then
            print_debug("exit GameplayStateRun")
            -- mark info rest
            reset_params()
        end
    end
end

-- Mod Setting Change
mod.on_setting_changed = function(setting_id)
    if setting_id == "toggle_mod_keybind" or setting_id == "companion_mark_keybind" then
        return
    end

    local class_name = mod:get("class_selection")
    if mod_settings[setting_id] ~= nil then
        mod_settings[setting_id] = mod:get(setting_id)
    elseif setting_id == "apply_button" then
        if mod:get(setting_id) == "apply" then
            apply_to_all_classes(class_name)
            mod:set("apply_button", "blank", false)
        end
    elseif setting_id == "reset_button" then
        if mod:get(setting_id) == "reset" then
            reset_auto_mark_settings()
            set_menu_settings(class_name)
            mod:set("reset_button", "blank", false)
        end
    elseif setting_id == "class_selection" then
        set_menu_settings(class_name)
    else
        local class_settings = auto_mark_settings[class_name]
        if DEFAULT_CLASS_SETTINGS[setting_id] ~= nil then
            class_settings[setting_id] = mod:get(setting_id)
        else
            class_settings.breed_priorities[setting_id] = mod:get(setting_id)
        end
        mod:set("auto_mark_settings", auto_mark_settings, false)
    end
end

-- Toggle Mod Enabled/Disabled
mod.toggle_mod = function()
    if mod_settings.toggle_mod_notify then
        mod:echo("Auto Mark " .. (not mod_settings.toggle_mod and "Enabled" or "Disabled"))
    end
    mod:set("toggle_mod", not mod_settings.toggle_mod, true)
end


-- Dedicate Key for Companion Mark
local function companion_mark_callback()
    if not smartTagSystem then
        return
    end

    local target_unit = find_target_unit(SMART_TARGETING_TEMPLATE_RANGE)
    if not target_unit then
        return
    end

    local target_tag = smartTagSystem:unit_tag(target_unit)
    local tag_name = TAG_NAMES.COMPANION_TAG
    on_manual_mark(mark_infos[tag_name], target_unit)
    mark(tag_name, target_unit, target_tag)
end

local function enemy_mark_callback()
    if not smartTagSystem then
        return
    end

    local target_unit = find_target_unit(SMART_TARGETING_TEMPLATE_RANGE)
    if not target_unit then
        return
    end

    local target_tag = smartTagSystem:unit_tag(target_unit)
    if target_tag then
        return
    end

    local tag_name = TAG_NAMES.ENEMY_TAG
    on_manual_mark(mark_infos[tag_name], target_unit)
    mark(tag_name, target_unit, target_tag)
end

mod.companion_mark = function()
    if not is_game_mode_valid or player_class_name ~= "adamant" or not has_companion then
        return
    end

    if companion_command_tap == "double" then
        local cb = callback(companion_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    elseif companion_command_tap == "single" then
        local cb = callback(enemy_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    end
end

-- Check if Priority Switch is Valid
local function is_priority_switch_valid(marked_tag, target_unit, target_breed_data, class_settings,
                                        is_priority_switch, is_execution_order_priority)
    local marked_unit = marked_tag and marked_tag._target_unit
    if marked_unit == target_unit then
        return false
    end

    local marked_weight = 0
    local target_weight = 0
    -- calculate breed priority weight
    if is_priority_switch then
        local breed_priorities = class_settings.breed_priorities
        local marked_breed_data = marked_tag and marked_tag._breed
        local marked_breed_name = marked_breed_data and marked_breed_data.name
        marked_weight = marked_weight + (breed_priorities[marked_breed_name] or 0)
        target_weight = target_weight + (breed_priorities[target_breed_data.name] or 0)
    end
    -- calculate execution order weight
    if is_execution_order_priority then
        marked_weight = marked_weight + (is_marked_by_execution_order(marked_unit) and 100 or 0)
        target_weight = target_weight + (is_marked_by_execution_order(target_unit) and 100 or 0)
    end

    if target_weight <= marked_weight then
        return false
    end

    return true
end

-- Check if Target Unit's Breed is Valid for Auto-Mark
local function is_breed_valid(breed_data, class_settings)
    if not breed_data or not class_settings then
        return false
    end

    -- toggle enemy by type
    if breed_data.tags.elite then
        if not class_settings.toggle_elite then
            return false
        end
    elseif breed_data.tags.special then
        if not class_settings.toggle_special then
            return false
        end
    elseif breed_data.is_boss then
        if not class_settings.toggle_boss then
            return false
        end
    elseif breed_data.smart_tag_target_type == "breed" then
        if not class_settings.toggle_other then
            return false
        end
    end

    -- toggle enemy by breed
    local breed_priority = class_settings.breed_priorities[breed_data.name] or 0
    if breed_priority <= 0 then
        return false
    end

    return true
end

-- Check if Tag is Valid for Current Class
local function is_tag_valid(tag_name)
    if tag_name == TAG_NAMES.COMPANION_TAG then
        return player_class_name == "adamant" and has_companion
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        return player_class_name == "veteran" and has_focus_target
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        return player_class_name ~= "veteran" or not has_focus_target
    end
    return false
end

-- Check if Tagged Target Unit can be Marked with Current Tag
local function is_target_valid(tag_name, target_tag, target_unit)
    if tag_name == TAG_NAMES.COMPANION_TAG then
        -- arbite shouldn't mark any arbite's prey
        if target_tag and target_tag._template.name == TAG_NAMES.COMPANION_TAG then
            return false
        end

        local companion_range_limitation = mod_settings.companion_range_limitation
        if companion_range_limitation <= 0 then
            return true
        end

        local companion_units = companionSpawnerExtension and companionSpawnerExtension:companion_units()
        local companion_unit = companion_units and companion_units[1]
        if not companion_unit then
            return false
        end

        local companion_unit_position = unit_world_position(companion_unit, 1)
        local target_unit_position = unit_world_position(target_unit, 1)
        if not companion_unit_position or not target_unit_position then
            return false
        end

        if vector3_distance_squared(companion_unit_position, target_unit_position) < companion_range_limitation * companion_range_limitation then
            return true
        end
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        local targetBuffExtension = ScriptUnit.extension(target_unit, "buff_system")
        if not targetBuffExtension then
            return false
        end

        local forcus_target_debuff = targetBuffExtension._stacking_buffs["veteran_improved_tag_debuff"]
        local target_stack_count = forcus_target_debuff and forcus_target_debuff:stack_count() or 0
        -- target does not have focus targe debuff
        if target_stack_count <= 0 then
            return true
        end

        -- focus_target_overwrite not enabled
        if not mod_settings.focus_target_overwrite then
            return false
        end

        if not talent_resource_component then
            return false
        end

        -- check if player's buff stacks greater than target's debuff stacks
        local player_stack_count = talent_resource_component.current_resource or 0
        if player_stack_count <= target_stack_count then
            return false
        end

        if player_stack_count == forcus_target_max_stacks or player_stack_count - target_stack_count >= mod_settings.focus_target_overwrite_delta then
            return true, true
        end
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        if not target_tag then
            return true
        end
    end

    return false
end

-- Auto-Mark Target Unit with the Tag
local function auto_mark_with_tag(tag_name)
    if not is_tag_valid(tag_name) then
        return false
    end

    local mark_info = mark_infos[tag_name]
    local class_settings = get_class_settings(tag_name)
    if
        not class_settings.toggle_class
        or (mark_info.is_manual and not class_settings.override_manual)
        or mark_info.delay > 0
        or not smartTagSystem
    then
        return false
    end

    local marked_tag = mark_info.tag
    -- mark when cooldown is zero
    local is_cooldown_ready = mark_info.cooldown <= 0 and (not class_settings.mark_limit or not marked_tag)
    -- mark when priority switch is on
    local is_priority_switch = marked_tag and class_settings.priority_switch
    -- mark when execution order priority is on
    local is_execution_order_priority = tag_name == TAG_NAMES.COMPANION_TAG and mod_settings.execution_order_priority
    -- mark when focus target overwrite is on
    local is_focus_target_overwrite =
        marked_tag
        and tag_name == TAG_NAMES.VETERAN_TAG
        and mod_settings.focus_target_overwrite
    -- quit if none of above conditions is true
    if
        not is_cooldown_ready
        and not is_priority_switch
        and not is_execution_order_priority
        and not is_focus_target_overwrite
    then
        return false
    end

    -- skip if no target found
    smart_targeting_template_auto.precision_target.max_range = class_settings.max_range
    local target_unit = find_target_unit(smart_targeting_template_auto)
    if not target_unit then
        return false
    end

    if mark_info.canceled_target_unit == target_unit then
        return false
    end

    -- type/breed validation under priority settings
    local targetDataExtension = ScriptUnit.extension(target_unit, "unit_data_system")
    local target_breed_data = targetDataExtension and targetDataExtension._breed
    if not target_breed_data or not is_breed_valid(target_breed_data, class_settings) then
        return false
    end

    -- skip if target tagged by invalid tag
    local target_tag = smartTagSystem:unit_tag(target_unit)
    local can_mark_target, can_overwrite_focus_target = is_target_valid(tag_name, target_tag, target_unit)
    if not can_mark_target then
        return false
    end

    if
        not is_cooldown_ready
        and not (is_focus_target_overwrite and can_overwrite_focus_target)
        and not ((is_priority_switch or is_execution_order_priority)
            and is_priority_switch_valid(marked_tag, target_unit, target_breed_data, class_settings, is_priority_switch, is_execution_order_priority))
    then
        return false
    end

    mark(tag_name, target_unit, target_tag)
    return true
end

-- Auto-Mark
local function auto_mark(dt)
    -- calculate delay
    if auto_mark_delay > 0 then
        auto_mark_delay = auto_mark_delay - dt
    end
    -- calculate interval
    if auto_mark_interval > 0 then
        auto_mark_interval = auto_mark_interval - dt
    end
    -- calculate cooldown and delay for all tags
    for _, mark_info in pairs(mark_infos) do
        if mark_info.delay > 0 then
            mark_info.delay = mark_info.delay - dt
        end
        if mark_info.cooldown > 0 then
            mark_info.cooldown = mark_info.cooldown - dt
        end
    end
    -- skip if auto mark is disabled
    if not mod_settings.toggle_mod then
        return
    end
    -- pause auto mark for a period of time after it is executed.
    if auto_mark_delay > 0 or auto_mark_interval > 0 then
        return
    end

    -- three kinds of tag to mark
    if auto_mark_with_tag(TAG_NAMES.COMPANION_TAG) then
        return
    end

    if auto_mark_with_tag(TAG_NAMES.VETERAN_TAG) then
        return
    end

    if auto_mark_with_tag(TAG_NAMES.ENEMY_TAG) then
        return
    end
end

local function cancel_companion_mark_on_condition(t)
    if not mod_settings.companion_cancel_mark then
        return
    end

    local mark_info = mark_infos[TAG_NAMES.COMPANION_TAG]
    if mark_info.is_manual then
        return
    end

    local marked_tag = mark_info.tag
    if not marked_tag or not mark_info.is_cancelable then
        return
    end

    if mod_settings.companion_health_threshold > 0 and mark_info.pounce_start_time then
        local marked_unit = marked_tag._target_unit
        local health_percent = Health.current_health_percent(marked_unit)
        if health_percent < mod_settings.companion_health_threshold then
            print_debug("cancel mark due to health threshold")
            mark_info.canceled_target_unit = marked_unit
            cancel_mark(marked_tag._id)
            return
        end
    end

    if mod_settings.companion_time_threshold > 0 and mark_info.pounce_start_time then
        if t - mark_info.pounce_start_time > mod_settings.companion_time_threshold then
            print_debug("cancel mark due to time threshold")
            mark_info.canceled_target_unit = marked_tag._target_unit
            cancel_mark(marked_tag._id)
            return
        end
    end
end

-- Main Entry For Auto Mark
mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "fixed_update",
    function(self, unit, dt, t, fixed_frame)
        if not self._player or self._player.viewport_name ~= "player1" then
            return
        end

        if not is_game_mode_valid then
            return
        end

        cancel_companion_mark_on_condition(t)
        auto_mark(dt)
    end)

-- Check Manual Input Marked Target
mod:hook(CLASS.SmartTagSystem, "set_contextual_unit_tag",
    function(func, self, tagger_unit, target_unit, alternate)
        if player and tagger_unit == player.player_unit then
            local target_extension = self._unit_extension_data[target_unit]
            local template = target_extension and target_extension:contextual_tag_template(tagger_unit, alternate)
            local tag_name = template and template.name
            local mark_info = mark_infos[tag_name]
            if mark_info ~= nil then
                print_debug("manual mark unit")
                -- thie unit is marked manually
                on_manual_mark(mark_info, target_unit)
                -- set delay and interval for auto mark
                on_set_tag(mark_info)
            end
        end
        return func(self, tagger_unit, target_unit, alternate)
    end)

mod:hook(CLASS.SmartTagSystem, "trigger_tag_interaction",
    function(func, self, tag_id, interactor_unit, target_unit, optional_alternate)
        if player and interactor_unit == player.player_unit then
            local target_extension = self._unit_extension_data[target_unit]
            local template = target_extension
                and target_extension:contextual_tag_template(interactor_unit, optional_alternate)
            local can_override = template and template.can_override
            if can_override then
                local tag_name = template and template.name
                local mark_info = mark_infos[tag_name]
                if mark_info ~= nil then
                    print_debug("manual mark unit")
                    -- thie unit is marked manually
                    on_manual_mark(mark_info, target_unit)
                    -- set delay and interval for auto mark
                    on_set_tag(mark_info)
                end
            end
        end
        return func(self, tag_id, interactor_unit, target_unit, optional_alternate)
    end)

-- Smart Tag Hook
mod:hook_safe(CLASS.SmartTag, "init",
    function(self, tag_id, template, tagger_unit, target_unit, target_location, replies, is_server)
        if not self._tagger_player or self._tagger_player.viewport_name ~= "player1" then
            return
        end

        local tag_name = template.name
        local mark_info = mark_infos[tag_name]
        if mark_info == nil then
            return
        end

        mark_info.tag = self
        mark_info.delay = 0
        auto_mark_delay = 0
        mark_info.cooldown = get_class_settings(tag_name).cooldown
        if mark_info.manual_target_unit == target_unit then
            mark_info.is_manual = true
            mark_info.manual_target_unit = nil
        else
            mark_info.is_manual = false
        end
        mark_info.pounce_start_time = nil
        mark_info.canceled_target_unit = nil

        if tag_name == TAG_NAMES.COMPANION_TAG then
            local targetDataExtension = ScriptUnit.extension(target_unit, "unit_data_system")
            local target_breed_data = targetDataExtension and targetDataExtension._breed
            if target_breed_data and target_breed_data.companion_pounce_setting.companion_pounce_action == "human" then
                mark_info.is_cancelable = true
            else
                mark_info.is_cancelable = false
            end
        end
    end)

mod:hook(CLASS.SmartTag, "destroy",
    function(func, self)
        local tag_name = self._template.name
        local mark_info = mark_infos[tag_name]
        if mark_info == nil then
            return func(self)
        end

        if mark_info.tag == self then
            if get_class_settings(tag_name).reset_cooldown then
                -- auto_mark_interval = 0
                mark_info.cooldown = 0
            end
            mark_info.tag = nil
            mark_info.is_manual = false
        end

        return func(self)
    end)

-- Hook for Companion Dog Attack Info
mod:hook_safe(CLASS.AttackReportManager, "add_attack_result",
    function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot,
             damage, attack_result, attack_type, damage_efficiency, is_critical_strike)
        if not mod_settings.companion_cancel_mark or attack_type ~= "companion_dog" or not player or attacking_unit ~= player.player_unit then
            return
        end

        local mark_info = mark_infos[TAG_NAMES.COMPANION_TAG]
        local marked_tag = mark_info.tag
        if not marked_tag or marked_tag._target_unit ~= attacked_unit or mark_info.pounce_start_time ~= nil then
            return
        end

        mark_info.pounce_start_time = gameplay_time()
    end)

-- Player Cache Hook
mod:hook_safe(CLASS.HumanPlayer, "init",
    function(self, ...)
        if self.viewport_name == "player1" then
            print_debug("Player init")
            player = self
        end
    end)

mod:hook_safe(CLASS.HumanPlayer, "destroy",
    function(self, ...)
        if self.viewport_name == "player1" then
            print_debug("Player destroy")
            player            = nil
            player_class_name = nil
        end
    end)

-- Get Archetype Name When Player Set Profile
mod:hook_safe(CLASS.HumanPlayer, "set_profile",
    function(self, ...)
        if self.viewport_name == "player1" then
            player_class_name = self:archetype_name()
            print_debug("Player class name", player_class_name)
        end
    end)

-- Player Unit Data Hook for Components
mod:hook_safe(CLASS.PlayerUnitDataExtension, "init",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitDataExtension init")
            init_player_components(self)
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "destroy",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitDataExtension destroy")
            talent_resource_component = nil
        end
    end)

-- Hook Extensions
mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "init",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitSmartTargetingExtension init")
            playerSmartTargetingExtension = self
            -- fix vanilla initialization bug
            self._num_visibility_checks_this_frame = 0
        end
    end)

mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "delete",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            print_debug("PlayerUnitSmartTargetingExtension delete")
            playerSmartTargetingExtension = nil
        end
    end)

mod:hook_safe(CLASS.CompanionSpawnerExtension, "init",
    function(self, ...)
        if self._owner_player.viewport_name == "player1" then
            print_debug("CompanionSpawnerExtension init")
            companionSpawnerExtension = self
        end
    end)

mod:hook_safe(CLASS.CompanionSpawnerExtension, "destroy",
    function(self, ...)
        if self._owner_player.viewport_name == "player1" then
            print_debug("CompanionSpawnerExtension destroy")
            companionSpawnerExtension = nil
        end
    end)


-- Update Talent Status
mod:hook_safe(CLASS.PlayerUnitTalentExtension, "_apply_talents",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            init_player_talent_status(self)
        end
    end)

mod:hook_safe(CLASS.PlayerHuskTalentExtension, "_update_talents",
    function(self, ...)
        if self._player.viewport_name == "player1" then
            init_player_talent_status(self)
        end
    end)

-- System Cache Hook
mod:hook_safe(CLASS.SmartTagSystem, "init",
    function(self, ...)
        print_debug("SmartTagSystem init")
        smartTagSystem = self
    end)

mod:hook_safe(CLASS.SmartTagSystem, "destroy",
    function(self, ...)
        print_debug("SmartTagSystem destroy")
        smartTagSystem = nil
    end)

mod:hook_safe(CLASS.OutlineSystem, "init",
    function(self, ...)
        print_debug("OutlineSystem init")
        outlineSystem = self
    end)

mod:hook_safe(CLASS.OutlineSystem, "destroy",
    function(self, ...)
        print_debug("OutlineSystem destroy")
        outlineSystem = nil
    end)

-- Update settings when input settings changed
mod:hook_safe(CLASS.EventManager, "trigger", function(self, event_name, ...)
    if event_name == "event_on_input_settings_changed" then
        print_debug("input settings changed")
        init_game_settings()
    end
end)

-- Manual Focus Target Mark on Attack
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local function focus_target_switch_callback()
    if not playerSmartTargetingExtension or not smartTagSystem then
        return
    end

    local weapon_action_component = playerSmartTargetingExtension._weapon_action_component
    local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)
    local is_ranged = WeaponTemplate.is_ranged(weapon_template)
    local smart_targeting_template = is_ranged and SMART_TARGETING_TEMPLATE_RANGE or SMART_TARGETING_TEMPLATE_MELEE
    local target_unit = find_target_unit(smart_targeting_template)
    if not target_unit then
        return
    end

    local tag_name = TAG_NAMES.VETERAN_TAG
    local mark_info = mark_infos[tag_name]
    local target_tag = smartTagSystem:unit_tag(target_unit)
    if not is_target_valid(tag_name, target_tag, target_unit) then
        return
    end

    on_manual_mark(mark_info, target_unit)
    mark(tag_name, target_unit, target_tag)
end

local function focus_target_switch()
    if not is_game_mode_valid or player_class_name ~= "veteran" or not has_focus_target then
        return
    end

    local cb = callback(focus_target_switch_callback)
    Managers.state.game_mode:register_physics_safe_callback(cb)
end

local FOCUS_TARGET_SWITCH_INPUTS = {
    action_one_pressed = true,
    action_one_release = true,
}
local function input_service_hook(func, self, action_name)
    local result = func(self, action_name)
    if FOCUS_TARGET_SWITCH_INPUTS[action_name] and mod_settings.focus_target_switch and result then
        focus_target_switch()
    end
    return result
end

-- Inpute Service Hook for fake input
mod:hook(CLASS.InputService, "_get", input_service_hook)
mod:hook(CLASS.InputService, "_get_simulate", input_service_hook)
