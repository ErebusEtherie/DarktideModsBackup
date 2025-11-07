--[[
Title: ArtificialLatency
Author: SPEED-PRIEST
Date: 17/05/2025
Version: 1.0.1
Credit to littlemonde (fixed player rotation teleportation issues) and OvenProofMars (helped solve some issues/was generally helpful)
--]]

local mod = get_mod("ArtificialLatency")

local RenegadeSniperActions = require("scripts/settings/breed/breed_actions/renegade/renegade_sniper_actions")

local scope_reflection_vfx_name = RenegadeSniperActions.shoot.shoot_template.scope_reflection_vfx_name
local scope_reflection_timing_sfx = RenegadeSniperActions.shoot.scope_reflection_timing_sfx

local Quaternion = Quaternion

local MILLISECONDS_TO_SECONDS = 0.001

mod.settings = mod:persistent_table("settings")

local initialize_settings_cache = function ()
    mod.settings["al_ms"] = mod:get("al_ms")
end

initialize_settings_cache()

local get_player = function ()
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player(1)
    return player
end

local lag_compensation_rewind_ms = function ()
    return mod.settings["al_ms"]
end

local lag_compensation_rewind_s = function ()
    return mod.settings["al_ms"] * MILLISECONDS_TO_SECONDS
end

local del_player_props = function (player)
    player = player or get_player()
    if player and player:type() == "HumanPlayer" then
        player.remote = nil
        player.lag_compensation_rewind_ms = (function () return 0 end)-- nil
        player.lag_compensation_rewind_s = (function () return 0 end)
    end
end

local is_server = function ()
    local game_session = Managers.state.game_session
    if not game_session then
        return false
    end
    return game_session:is_server()
end

local set_player_props = function ()
    if not is_server() then
        del_player_props()
        return
    end

    local player = get_player()
    if player and player:type() == "HumanPlayer" then
        if mod.settings["al_ms"] == 0 then
            del_player_props(player)
        elseif mod.settings["al_ms"] > 0 then
            player.remote = true
            player.lag_compensation_rewind_ms = lag_compensation_rewind_ms
            player.lag_compensation_rewind_s = lag_compensation_rewind_s
        end
    end
end

mod.on_setting_changed = function (setting_name)
    mod.settings[setting_name] = mod:get(setting_name)
    set_player_props()
end

mod.on_game_state_changed = function (status, state_name)
     if status == "enter" and (state_name == "StateGameplay" or state_name == "GameplayStateRun") then
        set_player_props()
    else
        del_player_props()
    end
end


mod.on_disabled = function (initial_call)
    if not initial_call then
        del_player_props()
    end
end

mod:hook("PlayerUnitSpawnManager", "owner", function (func, self, unit)
    if not is_server() then
        return func(self, unit)
    end
    if mod.settings["al_ms"] == 0 then
        return func(self, unit)
    end
    local owner = self._unit_owners[unit]
    if owner and owner.player_unit == unit then
        local is_human = owner:type()
        if is_human and mod.settings["al_ms"] > 0 then
            if not owner.remote then
                owner.remote = true
            end
            if not owner.lag_compensation_rewind_ms then
                owner.lag_compensation_rewind_ms = lag_compensation_rewind_ms
            end
            if not owner.lag_compensation_rewind_s then
                owner.lag_compensation_rewind_s = lag_compensation_rewind_s
            end
        end
    end
    return owner
end)

mod:hook_safe("FxSystem", "trigger_vfx", function (self, vfx_name, position, optional_rotation)
    if vfx_name == scope_reflection_vfx_name then
        local wwise_world = self._wwise_world
        local source_id = wwise_world:make_auto_source(position)
        wwise_world:trigger_resource_event(scope_reflection_timing_sfx, source_id, 1)
    end
end)

--[[ Credit to littlemonde for the following code (fixes player rotation when teleporting) ]]

local PlayerMovement = require("scripts/utilities/player_movement")

mod:hook(PlayerMovement, "_teleport", function (func, player_unit, position, rotation)
    local player = Managers.state.player_unit_spawn:owner(player_unit)

    if player and player.remote and rotation then
        local pitch = Quaternion.pitch(rotation)
        local yaw = Quaternion.yaw(rotation)
        player:set_orientation(yaw, pitch, 0)
    end

    return func(player_unit, position, rotation)
end)

mod:hook("PlayerUnitSpawnManager", "_spawn", function (func, self, player, position, rotation, parent, optional_side_name, breed_name_optional, character_state_optional, optional_damage, optional_permanent_damage)
    if player then
        local pitch = Quaternion.pitch(rotation)
        local yaw = Quaternion.yaw(rotation)
        player:set_orientation(yaw, pitch, 0)
    end

    return func(self, player, position, rotation, parent, optional_side_name, breed_name_optional, character_state_optional, optional_damage, optional_permanent_damage)
end)
