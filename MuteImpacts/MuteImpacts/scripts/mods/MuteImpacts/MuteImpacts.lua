local mod = get_mod("MuteImpacts")

-- ###################################################################
-- DATA
-- ###################################################################
mod.version = "1.11.0"
mod:info("v"..mod.version.." loaded uwu nya :3")

local audio_framework_to_use
local audio_plugin
local simple_audio

-- ################################
-- Local References for Performance
-- ################################
local pairs = pairs

mod:io_dofile("MuteImpacts/scripts/mods/MuteImpacts/SoundsToMute")
local sounds_to_toggle = mod.sounds_to_toggle
local sound_lookup_copy = mod.sound_lookup_copy

-- ###################################################################
-- MOD LOGIC
-- ###################################################################
-- Shows error if user allows error to be shown
-- Logs error otherwise
-- This lets me know if they screwed themselves over
mod.show_error_log_if_disabled = function(event_name)
    local warning = mod:localize("warning_"..event_name)
    if mod:get("show_warning_"..event_name) then
        mod:error(warning)
    else 
        mod:info(warning)
    end
end

-- Checks mod options and highlights incompatibilities
mod.validate_mod_settings = function()
    -- Integrated Refraction Shield
    --  If muting end, must also mute start
    --  Otherwise, active loops endlessly
    local muted_starting_sound = mod:get("skitussy_bubble_wrap_start")
    local muted_ending_sound = mod:get("skitussy_bubble_wrap_stop")
    if muted_ending_sound and (not muted_starting_sound) then
        mod.show_error_log_if_disabled("skitussy_bubble_wrap")
    end
end

mod.on_all_mods_loaded = function()
    audio_plugin = get_mod("Audio")
    simple_audio = get_mod("SimpleAudio")
    if simple_audio then
        audio_framework_to_use = simple_audio
    elseif audio_plugin then
        audio_framework_to_use = audio_plugin
    else
        mod:error(mod:localize("missing_audio_plugin_error"))
        return
    end

    for setting_name, sound_event in pairs(sound_lookup_copy) do 
        if mod:get(setting_name) then
            audio_framework_to_use.silence_sounds(sound_event)
        end
    end

    mod.validate_mod_settings()
end

mod.on_setting_changed = function(setting_id)
    local mute_this = mod:get(setting_id)

    -- Making sure it's actually a sound with an associated sound_event, not just the mod options grouping
    if sound_lookup_copy[setting_id] then
        if mute_this then
            audio_framework_to_use.silence_sounds(sound_lookup_copy[setting_id])
        else
            audio_framework_to_use.unsilence_sounds(sound_lookup_copy[setting_id])
        end
    end
end

-- On closing the Mod Options menu, check for incompatible settings and display warnings if so
mod:hook_safe(CLASS.UIViewHandler, "close_view", function(self, view_name, ...)
	if view_name == "dmf_options_view" or view_name == "options_view" then
		mod.validate_mod_settings()
	end
end)