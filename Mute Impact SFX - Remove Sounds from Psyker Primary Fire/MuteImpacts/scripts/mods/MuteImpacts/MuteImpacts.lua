local mod = get_mod("MuteImpacts")

-- ###################################################################
-- DATA
-- ###################################################################
mod.version = "1.2.0"
mod:info("v"..mod.version.." loaded uwu nya :3")

local audio_plugin

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
mod.on_all_mods_loaded = function()
    audio_plugin = get_mod("Audio")
    if not audio_plugin then
        mod:error(mod:localize("missing_audio_plugin_error"))
        return
    end

    for setting_name, sound_event in pairs(sound_lookup_copy) do 
        if mod:get(setting_name) then
            audio_plugin.silence_sounds(sound_event)
        end
    end
end

mod.on_setting_changed = function(setting_id)
    local mute_this = mod:get(setting_id)

    if mute_this then
        audio_plugin.silence_sounds(sound_lookup_copy[setting_id])
    else
        audio_plugin.unsilence_sounds(sound_lookup_copy[setting_id])
    end
end