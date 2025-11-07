local mod = get_mod("ReviveSuccessSound")
mod.version = "1.1.0"

local interaction_settings = mod:original_require("scripts/settings/interaction/interaction_settings")
local interaction_results = interaction_settings.results

local option_debug = mod:get("option_debug_mode")
local option_play_others = mod:get("option_play_for_others")
local option_sound = mod:get("option_completion_sound")
local option_amplify = mod:get("option_amplify")

local manager_player = Managers.player
local manager_ui = Managers.ui

mod:info("Loaded mod with version " .. mod.version .. ", debug: " .. tostring(option_debug) .. ".")

local function is_myself(unit)
    if not manager_player then
        return false
    end

    return unit == manager_player:local_player(1).player_unit
end

local function play_sound_on_revive(instance, result)
    if not manager_ui or not interaction_results or not instance then
        return
    end

    if result ~= interaction_results.success then
        return
    end

    local unit = instance._interactor_unit

    if not unit then
        return
    end

    if not option_play_others and not is_myself(unit) then
        return
    end

    local type = instance:interaction_type() or ""
    if type == "pull_up" or type == "revive" or type == "remove_net" or type == "rescue" then
        if option_debug then
            mod:info("Playing sound '" .. option_sound .. "'...")
        end

        manager_ui:play_2d_sound(option_sound)

        if option_amplify then
            manager_ui:play_unit_sound(option_sound, unit)
        end

        if option_debug then
            mod:info("Played sound.")
        end
    end
end

mod:hook(CLASS.PlayerInteracteeExtension, "stopped", function(func, instance, result, ...)
    play_sound_on_revive(instance, result)
    func(instance, result, ...)
end)

mod.on_setting_changed = function()
    local new_sound = mod:get("option_completion_sound")

    option_amplify = mod:get("option_amplify")
    option_play_others = mod:get("option_play_for_others")

    if option_sound ~= new_sound then
        option_sound = new_sound

        if option_debug then
            mod:info("Changed sound to '" .. option_sound .. "'.")
        end

        manager_ui:play_2d_sound(option_sound)

        if option_amplify and manager_ui and manager_player and manager_player:local_player(1).player_unit then
            manager_ui:play_unit_sound(option_sound, manager_player:local_player(1).player_unit)
        end
    end

    option_debug = mod:get("option_debug_mode")

    if option_debug then
        mod:info("ReviveSuccessSound (" .. mod.version .. ") reloaded.")
    end
end
