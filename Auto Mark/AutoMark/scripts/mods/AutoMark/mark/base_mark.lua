---@class AutoMarkMod:DMFMod
local mod                                  = get_mod("AutoMark")
local context                              = mod.context
local mark_context                         = mod.mark_context
local TAG_NAMES                            = mod.TAG_NAMES
local mod_settings                         = mod.settings
local companion_cancel_mark_breed_settings = mod.companion_cancel_mark_breed_settings

-- Imports
local TalentSettings                       = require("scripts/settings/talent/talent_settings")
local NetworkLookup                        = require("scripts/network_lookup/network_lookup")
local cryptic_talent_settings              = TalentSettings.cryptic
local noospheric_command_duration          = cryptic_talent_settings.servo_skull_shooting_tagging.duration

-- Global Cache
local CLASS                                = CLASS
local ScriptUnit                           = ScriptUnit
local Managers                             = Managers

-- Delay for Server Latency, Interval for Auto Mark
local AUTO_MARK_DELAY                      = 1
local AUTO_MARK_INTERVAL                   = 0.2
local ENEMY_TAG_DELAY                      = 3
local PRIORITY_SWITCH_COOLDOWN             = 0.3
local FOCUS_TARGET_DELAY                   = 1.5

-- set delay and interval for auto mark
local function on_set_tag(tag_context)
    -- mark_context.auto_mark_interval = AUTO_MARK_INTERVAL
    tag_context.delay = AUTO_MARK_DELAY
    tag_context.delay_times = tag_context.delay_times + 1
end

-- record manual marked unit
function mod:on_manual_mark(tag_context, target_unit)
    mod:print_debug("manual mark unit:", target_unit)
    tag_context.manual_unit = target_unit
    tag_context.manual_unit_expired_time = mod:get_latest_fixed_time() + 1
end

-- cancel mark by tag id
function mod:cancel_mark(tag_id)
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local player = context.player
    local player_unit = player and player.player_unit
    if not player_unit then
        return
    end

    smart_tag_system:cancel_tag(tag_id, player_unit)
end

-- mark target unit with tag
function mod:set_auto_mark(tag_name, target_unit, target_tag)
    local player = context.player
    local player_unit = player and player.player_unit
    local tag_context = mark_context[tag_name]
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not target_unit or not tag_context or not smart_tag_system
    then
        return
    end

    local player_unit_id = Managers.state.unit_spawner:game_object_id(player_unit)
    if not player_unit_id then
        return
    end

    local target_unit_id = Managers.state.unit_spawner:game_object_id(target_unit)
    if not target_unit_id then
        return
    end

    if target_tag then
        if tag_name == TAG_NAMES.COMPANION_TAG or tag_name == TAG_NAMES.VETERAN_TAG or tag_name == TAG_NAMES.SERVO_SKULL_TAG then
            local template = target_tag._template
            local is_enemy_mark = template and template.name == TAG_NAMES.ENEMY_TAG
            if is_enemy_mark then
                local tagger_player = target_tag._tagger_player
                local tagger_player_unit = tagger_player and tagger_player.player_unit
                if tagger_player_unit then
                    smart_tag_system:cancel_tag(target_tag._id, tagger_player_unit, true)
                end
            end
        end
    end

    mod:print_debug("Auto Mark", tag_name, target_unit)
    on_set_tag(tag_context)
    local template_name_id = NetworkLookup.smart_tag_templates[tag_name]
    if smart_tag_system._is_server then
        local tag_id = smart_tag_system:_generate_tag_id()
        local tag = smart_tag_system:_create_tag_locally(tag_id, tag_name, player_unit, target_unit)
        smart_tag_system:_server_check_tag_group_limit(player_unit, tag:group())
        Managers.state.game_session:send_rpc_clients("rpc_set_smart_tag", tag_id, template_name_id, player_unit_id, target_unit_id)
    else
        Managers.state.game_session:send_rpc_server("rpc_request_set_smart_tag", template_name_id, player_unit_id, target_unit_id)
    end
end

function mod:set_manual_mark(tag_name, target_unit, target_tag)
    local player = context.player
    local player_unit = player and player.player_unit
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not target_unit or not smart_tag_system then
        return
    end

    if target_tag then
        if tag_name == TAG_NAMES.COMPANION_TAG or tag_name == TAG_NAMES.VETERAN_TAG or tag_name == TAG_NAMES.SERVO_SKULL_TAG then
            local template = target_tag._template
            local is_enemy_mark = template and template.name == TAG_NAMES.ENEMY_TAG
            if is_enemy_mark then
                local tagger_player = target_tag._tagger_player
                local tagger_player_unit = tagger_player and tagger_player.player_unit
                if tagger_player_unit then
                    smart_tag_system:cancel_tag(target_tag._id, tagger_player_unit, true)
                end
            end
        end
    end

    smart_tag_system:set_tag(tag_name, player_unit, target_unit)
end

mod:hook(CLASS.SmartTagSystem, "set_tag",
    function(func, self, template_name, tagger_unit, target_unit, ...)
        local player = context.player
        if player and tagger_unit == player.player_unit then
            local tag_context = mark_context[template_name]
            if tag_context then
                -- the unit is marked manually
                mod:on_manual_mark(tag_context, target_unit)
                -- set delay and interval for auto mark
                on_set_tag(tag_context)
            end
        end
        return func(self, template_name, tagger_unit, target_unit, ...)
    end)

local function delay_normal_tag()
    local tag_context = mark_context[TAG_NAMES.ENEMY_TAG]
    if tag_context.cooldown < ENEMY_TAG_DELAY then
        tag_context.cooldown = ENEMY_TAG_DELAY
    end
    if tag_context.priority_switch_cooldown < ENEMY_TAG_DELAY then
        tag_context.priority_switch_cooldown = ENEMY_TAG_DELAY
    end
end

-- Smart Tag Hook
mod:hook_safe(CLASS.SmartTag, "init",
    function(self, tag_id, template, tagger_unit, target_unit, target_location, replies, is_server)
        local tagger_player = self._tagger_player
        if not tagger_player or tagger_player.viewport_name ~= "player1" then
            return
        end

        local tag_name = template.name
        local tag_context = mark_context[tag_name]
        if not tag_context then
            return
        end

        mod:print_debug("init smart tag", tag_name)
        mark_context.auto_mark_interval = AUTO_MARK_INTERVAL
        -- refresh delay and set cooldown
        tag_context.tag = self
        tag_context.interval = 0
        tag_context.cooldown = mod:get_class_settings(tag_name).cooldown
        tag_context.priority_switch_cooldown = PRIORITY_SWITCH_COOLDOWN
        -- reset delay
        tag_context.delay_times = tag_context.delay_times - 1
        if tag_context.delay_times <= 0 then
            tag_context.delay = 0
            tag_context.delay_times = 0
        end
        -- check if the tag is manual
        tag_context.is_manual = tag_context.manual_unit == target_unit
        tag_context.manual_unit = nil

        if tag_name == TAG_NAMES.COMPANION_TAG then
            tag_context.pounce_start_time = nil
            local target_data_extension = ScriptUnit.extension(target_unit, "unit_data_system")
            local target_breed_data = target_data_extension and target_data_extension._breed
            local breed_name = target_breed_data and target_breed_data.name
            local breed_settings = companion_cancel_mark_breed_settings[breed_name]
            if breed_settings and breed_settings.override then
                tag_context.is_cancelable = true
            else
                local pounce_setting = target_breed_data and target_breed_data.companion_pounce_setting
                local pounce_action = pounce_setting and pounce_setting.companion_pounce_action
                if pounce_action == "human" then
                    tag_context.is_cancelable = mod_settings.companion_cancel_mark_human
                else
                    tag_context.is_cancelable = mod_settings.companion_cancel_mark_non_human
                end
            end
            delay_normal_tag()
        elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
            tag_context.shoot_start_time = nil
            if context.has_noospheric_command then
                tag_context.noospheric_command_next_time = mod:get_latest_fixed_time() + noospheric_command_duration
            else
                tag_context.noospheric_command_next_time = math.huge
            end
            delay_normal_tag()
        elseif tag_name == TAG_NAMES.VETERAN_TAG then
            if tag_context.switch_melee_unit == target_unit then
                tag_context.is_switch_melee = true
                tag_context.is_switch_range = false
            elseif tag_context.switch_range_unit == target_unit then
                tag_context.is_switch_melee = false
                tag_context.is_switch_range = true
            else
                tag_context.is_switch_melee = false
                tag_context.is_switch_range = false
            end
            tag_context.switch_melee_unit = nil
            tag_context.switch_range_unit = nil
        elseif tag_name == TAG_NAMES.ENEMY_TAG then
            if context.class_name == "veteran" and context.has_focus_target then
                local veteran_tag_context = mark_context[TAG_NAMES.VETERAN_TAG]
                veteran_tag_context.tag = self
                veteran_tag_context.interval = 0
                veteran_tag_context.cooldown = mod:get_class_settings(TAG_NAMES.VETERAN_TAG).cooldown
                veteran_tag_context.priority_switch_cooldown = PRIORITY_SWITCH_COOLDOWN
                veteran_tag_context.is_manual = tag_context.is_manual
            end
        end
    end)

mod:hook(CLASS.SmartTag, "destroy",
    function(func, self, ...)
        local tag_name = self._template.name
        local tag_context = mark_context[tag_name]
        if not tag_context then
            return func(self, ...)
        end

        if tag_context.tag == self then
            mod:print_debug("destroy smart tag", tag_name)
            tag_context.tag = nil
            tag_context.is_manual = false
            local class_settings = mod:get_class_settings(tag_name)
            tag_context.interval = class_settings.interval
            if class_settings.reset_cooldown then
                tag_context.cooldown = 0
            end

            if tag_name == TAG_NAMES.COMPANION_TAG then
                tag_context.removed_units[self._target_unit] = mod:get_latest_fixed_time() + 1.5
                tag_context.pounce_start_time = nil
                tag_context.is_cancelable = false
                delay_normal_tag()
            elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
                tag_context.removed_units[self._target_unit] = mod:get_latest_fixed_time() + 1.5
                tag_context.shoot_start_time = nil
                tag_context.noospheric_command_next_time = math.huge
                delay_normal_tag()
            elseif tag_name == TAG_NAMES.VETERAN_TAG then
                tag_context.removed_units[self._target_unit] = mod:get_latest_fixed_time() + 1.5
                if tag_context.is_switch_melee and tag_context.cooldown < FOCUS_TARGET_DELAY then
                    tag_context.cooldown = FOCUS_TARGET_DELAY
                end
                tag_context.is_switch_melee = false
                tag_context.is_switch_range = false
            elseif tag_name == TAG_NAMES.ENEMY_TAG then
                if context.class_name == "veteran" and context.has_focus_target then
                    local veteran_tag_context = mark_context[TAG_NAMES.VETERAN_TAG]
                    if veteran_tag_context.tag == self then
                        veteran_tag_context.tag = nil
                        veteran_tag_context.is_manual = false
                        local veteran_class_settings = mod:get_class_settings(TAG_NAMES.VETERAN_TAG)
                        veteran_tag_context.interval = veteran_class_settings.interval
                        if veteran_class_settings.reset_cooldown then
                            veteran_tag_context.cooldown = 0
                        end
                    end
                end
            end
        end

        return func(self, ...)
    end)

local SERVO_SKULL_DAMAGE_PROFILE_NAMES = {
    default_companion_servo_skull_lasgun_killshot = true,
    improved_companion_servo_skull_lasgun_killshot = true,
}
-- Hook for Companion Dog Attack Info
mod:hook_safe(CLASS.AttackReportManager, "add_attack_result",
    function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike)
        local player = context.player
        local player_unit = player and player.player_unit
        if not player_unit or attacking_unit ~= player_unit then
            return
        end

        if attack_type == "companion_dog" then
            local tag_context = mark_context[TAG_NAMES.COMPANION_TAG]
            local marked_tag = tag_context.tag
            if marked_tag and marked_tag._target_unit == attacked_unit and not tag_context.pounce_start_time then
                tag_context.pounce_start_time = mod:get_latest_fixed_time()
                mod:print_debug("pounce start time:", tag_context.pounce_start_time)
            end
        elseif SERVO_SKULL_DAMAGE_PROFILE_NAMES[damage_profile.name] then
            local tag_context = mark_context[TAG_NAMES.SERVO_SKULL_TAG]
            local marked_tag = tag_context.tag
            if marked_tag and marked_tag._target_unit == attacked_unit and not tag_context.shoot_start_time then
                tag_context.shoot_start_time = mod:get_latest_fixed_time()
                mod:print_debug("shoot start time:", tag_context.shoot_start_time)
            end
        end
    end)
