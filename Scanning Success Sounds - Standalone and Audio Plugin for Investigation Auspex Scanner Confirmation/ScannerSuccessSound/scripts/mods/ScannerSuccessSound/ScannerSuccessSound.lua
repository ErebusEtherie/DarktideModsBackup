local mod = get_mod("ScannerSuccessSound")
mod.version = "1.1.0"

--#################################
-- Data
--#################################
-- ################
-- Performance
-- ################
local string = string
local string_regex_match = string.gmatch
local table = table
local table_insert = table.insert

-- ################
-- Requirements
-- ################
local PlayerCharacterSoundEventAliases = require("scripts/settings/sound/player_character_sound_event_aliases")

-- ################
-- Mod Locals
-- ################
local debug
local use_audio
local replacement_sound
local replacement_table

local Audio
local audio_files
local SimpleAudio
local SimpleAudioRandom
local audio_volume

--#################################
-- Helper Functions
--#################################
local function reset_scan_sound_to_default()
    PlayerCharacterSoundEventAliases.sfx_scanning_sucess.events.scanner_equip = "wwise/events/player/play_scanner_collect_success"
end

local function replace_scan_sound()
    debug = mod:get("enable_debug_mode")
    use_audio = mod:get("use_audio")

    -- User is NOT using Audio plugin, so get option from dropdown
    -- Replace the sound then return
    -- btw, sfx_scanning_sucess is NOT a typo from my end lol
    if not use_audio then
        replacement_sound = mod:get("scan_sound")
        -- Default Case. Directly replace with the sound and gtfo
        if replacement_sound == "sfx_scanning_sucess.events.scanner_equip" then
            reset_scan_sound_to_default()
            return
        end

        replacement_table = {}
        -- Splits value into keys 
        --  %. escapes the magic character (period)
        --  [^%.] match anything that's not a period
        --  [^%.]+ match the longest string of not periods
        for v in string_regex_match(replacement_sound, "[^%.]+") do 
            table_insert(replacement_table, v)
            if debug then 
                mod:echo("Split string result: "..tostring(v)) 
            end
        end

        if debug then 
            mod:echo("Replacement Sound is: "..replacement_sound)
            mod:echo("Replacing sfx_scanning_sucess.events.scanner_equip with: "..PlayerCharacterSoundEventAliases[replacement_table[1]][replacement_table[2]][replacement_table[3]]) 
        end
        PlayerCharacterSoundEventAliases.sfx_scanning_sucess.events.scanner_equip = PlayerCharacterSoundEventAliases[replacement_table[1]][replacement_table[2]][replacement_table[3]]
        return
    else
        -- At this point in the code, the user has selected Custom Audio
        -- In either case, this will hook the sound, then play the custom sound (while silencing the original)
        Audio = get_mod("Audio")
        SimpleAudio = get_mod("SimpleAudio")
        audio_volume = mod:get("audio_volume")

        -- Setting sound back to default
        -- Since this is the one the hooks are looking for, reset it, in case this was replaced earlier
        reset_scan_sound_to_default()

        if SimpleAudio then
            if debug then mod:echo("Using SimpleAudio") end
            SimpleAudioRandom = SimpleAudio.glob("active/*")

            -- By hooking a wwise event:
            --  ^wwise/events/player/play_scanner_collect_success
            --      It plays for when all allies scan, while your scannner is out
            --  play_scanner_collect_success
            --      It plays for when all allies scan
            --  ^wwise/events/player/play_scanner_collect_success$
            --      It plays
            -- play_scanner_collect_success_husk seems to be the allied scan when your scanner is away
            SimpleAudio.hook_sound("^wwise/events/player/play_scanner_collect_success$", function(sound_type, event_name, delta, position_or_unit_or_id)
                -- This hooks a wwise event, so position_or_unit_or_id is id of the wwise source
                local playback_target

                -- mod:echo("Sound Type: "..tostring(sound_type).."; Event Name: "..tostring(event_name).."; Delta: "..tostring(delta).."; ID: ("..type(position_or_unit_or_id)..") "..tostring(position_or_unit_or_id))
                if sound_type == "3d_sound" or sound_type == "unit_sound" then
                    playback_target = position_or_unit_or_id
                end
               
                if delta == nil or delta > 0.1 then
                    SimpleAudioRandom:play({
                        audio_type = "sfx",
                        volume = audio_volume,
                    }, playback_target)
                end

                return false
            end)
        elseif Audio then
            if debug then mod:echo("Using Audio") end

            audio_files = Audio.new_files_handler()

            -- Audio only goes from 0-100, while SimpleAudio goes 0-200. I'm using the same widget for both, so this is a bit of precaution to avoid issues
            if audio_volume > 100 then 
                audio_volume = 100
            end

            -- Actual audio hooking
            -- "wwise/events/player/play_scanner_collect_success"
            Audio.hook_sound("play_scanner_collect_success", function(sound_type, sound_name, delta)
                if delta == nil or delta > 0.1 then
                    Audio.play_file(audio_files:random("active"), { 
                        audio_type = "sfx",
                        volume = audio_volume,
                    })
                end
            
                return false
            end)
        else
            mod:error(mod:localize("error_no_audio_frameworks"))
            return
        end
    end
    
end

--#################################
-- Hooks and Execution
--#################################
mod.on_all_mods_loaded = function()
    mod:info("ScannerSuccessSound v" .. mod.version .. " loaded uwu nya :3")
    replace_scan_sound()
end
mod.on_setting_changed = function()
    replace_scan_sound()
end
mod.on_disabled = function()
    reset_scan_sound_to_default()
end