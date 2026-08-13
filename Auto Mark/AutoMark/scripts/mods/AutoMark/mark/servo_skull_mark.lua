---@class AutoMarkMod:DMFMod
local mod                               = get_mod("AutoMark")
local context                           = mod.context
local mark_context                      = mod.mark_context
local TAG_NAMES                         = mod.TAG_NAMES
local mod_settings                      = mod.settings
local noospheric_command_breed_settings = mod.noospheric_command_breed_settings
local DISABLING_TYPES                   = mod.DISABLING_TYPES

-- Imports
local SpecialRulesSettings              = require("scripts/settings/ability/special_rules_settings")
local CompanionServoSkullSettings       = require("scripts/settings/companion/companion_servo_skull_settings")
local Hud                               = require("scripts/utilities/ui/hud")
local Health                            = require("scripts/utilities/health")
local special_rules                     = SpecialRulesSettings.special_rules
local servo_skull_states                = CompanionServoSkullSettings.STATES

-- Global Cache
local RESOLUTION_LOOKUP                 = RESOLUTION_LOOKUP
local Managers                          = Managers
local callback                          = callback
local GameSession                       = GameSession
local ScriptUnit_extension              = ScriptUnit.extension

local HACK_TAG_NAME                     = "hacking_over_here_companion"
local CANCEL_INTERVAL                   = 0.5

local function servo_skull_mark_callback()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local target_unit = mod:find_target_unit()
    if not target_unit then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    local tag_name = TAG_NAMES.SERVO_SKULL_TAG
    mod:set_manual_mark(tag_name, target_unit, target_tag)
end

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

mod.servo_skull_mark = function()
    if not context.mod_enabled or not context.game_mode_valid or context.class_name ~= "cryptic" or not context.has_servo_skull then
        return
    end

    local companion_command_tap = context.companion_command_tap
    if companion_command_tap == "double" then
        local cb = callback(servo_skull_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    elseif companion_command_tap == "single" then
        local cb = callback(enemy_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    end
end

local function hack_mark_callback()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local hud_element_smart_tagging = context.hud_element_smart_tagging
    if not hud_element_smart_tagging then
        return
    end

    local player = context.player
    local player_unit = player and player.player_unit
    if not player_unit then
        return
    end

    local target_marker, _ = hud_element_smart_tagging:_find_world_marker_target()
    local target_unit = target_marker and target_marker.unit
    if not target_unit then
        return
    end

    local target_extension = smart_tag_system._unit_extension_data[target_unit]
    local template_name = target_extension and target_extension:_contextual_tag_template_name(player_unit, "companion_order")

    if template_name ~= HACK_TAG_NAME then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    local tagger_player = target_tag and target_tag._tagger_player
    local tagger_player_unit = tagger_player and tagger_player.player_unit
    if tagger_player_unit then
        smart_tag_system:cancel_tag(target_tag._id, tagger_player_unit, true)
    end

    smart_tag_system:set_tag(HACK_TAG_NAME, player_unit, target_unit)
end

mod.hack_mark = function()
    if not context.mod_enabled or not context.game_mode_valid or context.class_name ~= "cryptic" or not context.has_servo_skull then
        return
    end

    local cb = callback(hack_mark_callback)
    Managers.state.game_mode:register_physics_safe_callback(cb)
end

function mod:is_servo_skull_hacking()
    local companion_spawner_extension = context.companion_spawner_extension
    local companion_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
    if not ALIVE[companion_unit] then
        return false
    end

    local game_session = Managers.state.game_session:game_session()
    local game_object_id = Managers.state.unit_spawner:game_object_id(companion_unit)
    local game_object_exists = GameSession.game_object_exists(game_session, game_object_id)

    if not game_object_exists then
        return false
    end

    local state = GameSession.game_object_field(game_session, game_object_id, "state")
    return state == servo_skull_states.hacking
end

local find_hackable_target_unit = function()
    local hud_element_smart_tagging = context.hud_element_smart_tagging
    if not hud_element_smart_tagging then
        return
    end

    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    Managers.event:trigger("request_world_markers_list", callback(hud_element_smart_tagging, "_cb_world_markers_list_request"))
    local world_markers_list = hud_element_smart_tagging._world_markers_list
    local hud_scale = Hud.hud_scale()
    local selected_marker_distance = math.huge
    local selected_marker_unit
    local parent = hud_element_smart_tagging._parent
    local player = parent:player()
    local player_unit = player.player_unit
    local resolution_width, resolution_height = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height
    local center_x, center_y = 0.5 * resolution_width, 0.5 * resolution_height
    local radius = resolution_height / 8 * 3
    local radius_squared = radius * radius

    for i = 1, #world_markers_list do
        local marker = world_markers_list[i]
        local widget = marker.widget

        if widget then
            local distance = widget.content.distance

            if hud_element_smart_tagging:_is_marker_valid_for_tagging(player_unit, marker, distance) then
                local offset = widget.offset
                local x = offset[1] * hud_scale
                local y = offset[2] * hud_scale
                local dx = x - center_x
                local dy = y - center_y

                if dx * dx + dy * dy <= radius_squared and distance < selected_marker_distance then
                    local marker_unit = marker.unit
                    local target_extension = smart_tag_system._unit_extension_data[marker_unit]
                    local template_name = target_extension and target_extension:_contextual_tag_template_name(player_unit, "companion_order")
                    if template_name == HACK_TAG_NAME then
                        selected_marker_unit = marker_unit
                        selected_marker_distance = distance
                    end
                end
            end
        end
    end

    return selected_marker_unit, selected_marker_distance
end

local hack_interval             = 0
function mod:auto_hack(dt, t, fixed_frame)
    if not mod_settings.toggle_mod or not mod_settings.auto_hack or (mod_settings.disable_auto_hack_for_noospheric_command and context.has_noospheric_command) or context.class_name ~= "cryptic" or not context.has_servo_skull then
        return
    end

    if hack_interval > 0 then
        hack_interval = hack_interval - dt
        return
    end

    if mod:is_servo_skull_hacking() then
        return
    end

    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local player = context.player
    local player_unit = player and player.player_unit
    if not player_unit then
        return
    end

    local target_unit, _ = find_hackable_target_unit()
    if not target_unit then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    local tagger_player = target_tag and target_tag._tagger_player
    local tagger_player_unit = tagger_player and tagger_player.player_unit
    if tagger_player_unit then
        smart_tag_system:cancel_tag(target_tag._id, tagger_player_unit, true)
    end

    hack_interval = 1
    smart_tag_system:set_tag(HACK_TAG_NAME, player_unit, target_unit)
end

local cancel_interval = 0
function mod:auto_cancel_servo_skull_mark(dt, t, fixed_frame)
    if not mod_settings.toggle_mod or not mod_settings.servo_skull_cancel_mark or context.class_name ~= "cryptic" or not context.has_servo_skull then
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

    local tag_context = mark_context[TAG_NAMES.SERVO_SKULL_TAG]
    local marked_tag = tag_context.tag
    local marked_unit = marked_tag and marked_tag._target_unit
    if not marked_tag or not marked_unit then
        return
    end

    if tag_context.is_manual then
        return
    end

    local unit_data_extension = ScriptUnit_extension(marked_unit, "unit_data_system")
    local breed_data = unit_data_extension and unit_data_extension._breed
    local breed_name = breed_data and breed_data.name
    local breed_settings = noospheric_command_breed_settings[breed_name]
    local time_threshold, health_threshold
    if breed_settings and breed_settings.override then
        health_threshold = breed_settings.health_threshold or 0
        time_threshold = breed_settings.time_threshold or 0
    else
        time_threshold = mod_settings.servo_skull_cancel_mark_time_threshold
        health_threshold = mod_settings.servo_skull_cancel_mark_health_threshold
    end

    if time_threshold > 0 then
        if mod:is_servo_skull_target_visible(marked_unit, fixed_frame, true) then
            tag_context.servo_skull_lose_sight_time = nil
        elseif tag_context.servo_skull_lose_sight_time == nil then
            tag_context.servo_skull_lose_sight_time = t
        end

        if tag_context.servo_skull_lose_sight_time and t - tag_context.servo_skull_lose_sight_time > time_threshold then
            mod:print_debug("cancel servo skull mark due to time threshold")
            tag_context.canceled_units[marked_unit] = t + 0.5
            cancel_interval = CANCEL_INTERVAL
            mod:cancel_mark(marked_tag._id)
        end
    end

    if health_threshold > 0 then
        local health_percent = Health.current_health_percent(marked_unit)
        if health_percent < health_threshold then
            mod:print_debug("cancel servo skull mark due to health threshold, health_percent:", health_percent)
            tag_context.canceled_units[marked_unit] = math.huge
            cancel_interval = CANCEL_INTERVAL
            mod:cancel_mark(marked_tag._id)
            return
        end
    end
end
