local mod = get_mod("AncestorsGuidance")

--[[
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Ancestor's Guidance                                                                                                    │
│ Mod Author: Brunin (brufgsilva on Nexus)																						   │
│ Version: 1.1																													   │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
--]]

-- Frequently used functions and variables
local math_random = math.random
local string_find = string.find
local ipairs = ipairs
local pairs = pairs
local type = type
local Audio = get_mod("Audio")
local Managers = Managers
local time_manager = Managers.time
local time_function = time_manager and time_manager.time or function() return 0 end

-- Sound files with pre-sized tables
local MEDICAE_FILES = {
    idle_empty = Script.new_array(49),
    idle_full = Script.new_array(12),
    recharge = Script.new_array(8),
    working = Script.new_array(80)
}

-- Audio files
for i = 1, 49 do
    MEDICAE_FILES.idle_empty[i] = "audio/medicae/empty/empty_" .. string.format("%02d", i) .. ".mp3"
end
for i = 1, 12 do
    MEDICAE_FILES.idle_full[i] = "audio/medicae/full/full_" .. string.format("%02d", i) .. ".mp3"
end
for i = 1, 8 do
    MEDICAE_FILES.recharge[i] = "audio/medicae/recharge/recharge_" .. string.format("%02d", i) .. ".mp3"
end
for i = 1, 80 do
    MEDICAE_FILES.working[i] = "audio/medicae/working/working_" .. string.format("%02d", i) .. ".mp3"
end

local ARMOURY_FILES = {
    hello = Script.new_array(28)
}
for i = 1, 28 do
    ARMOURY_FILES.hello[i] = "audio/armoury/hello_" .. string.format("%02d", i) .. ".mp3"
end

local CRAFTING_FILES = {
    crafting = Script.new_array(18)
}
for i = 1, 18 do
    CRAFTING_FILES.crafting[i] = "audio/crafting/crafting_" .. string.format("%02d", i) .. ".mp3"
end

local SEFONI_FILES = {
    sefoni = Script.new_array(37)
}
for i = 1, 37 do
    SEFONI_FILES.sefoni[i] = "audio/sefoni/sefoni_" .. string.format("%02d", i) .. ".mp3"
end

local CONTRACT_FILES = {
    melk = Script.new_array(10)
}
for i = 1, 10 do
    CONTRACT_FILES.melk[i] = "audio/contracts/melk_" .. string.format("%02d", i) .. ".mp3"
end

local PENANCE_FILES = {
    penance = Script.new_array(24)
}
for i = 1, 24 do
    PENANCE_FILES.penance[i] = "audio/penance/penance_" .. string.format("%02d", i) .. ".mp3"
end

local COMMODORE_FILES = {
    commodore = Script.new_array(5)
}
for i = 1, 5 do
    COMMODORE_FILES.commodore[i] = "audio/commodore/commodore_" .. string.format("%02d", i) .. ".mp3"
end

local BARBER_FILES = {
    barber = Script.new_array(14)
}
for i = 1, 14 do
    BARBER_FILES.barber[i] = "audio/barber/barber_" .. string.format("%02d", i) .. ".mp3"
end

local COMMISSAR_FILES = {
    commissar = Script.new_array(17)
}
for i = 1, 17 do
    COMMISSAR_FILES.commissar[i] = "audio/commissar/commissar_" .. string.format("%02d", i) .. ".mp3"
end

local BOSS_FILES = {
    boss = Script.new_array(22)
}
for i = 1, 22 do
    BOSS_FILES.boss[i] = "audio/boss/boss_" .. string.format("%02d", i) .. ".mp3"
end

local HORDE_FILES = {
    horde = Script.new_array(39)
}
for i = 1, 39 do
    HORDE_FILES.horde[i] = "audio/horde/horde_" .. string.format("%02d", i) .. ".mp3"
end

local BOSS_KILLED_FILES = {
    killed = Script.new_array(64)
}
for i = 1, 64 do
    BOSS_KILLED_FILES.killed[i] = "audio/bosskilled/killed_" .. string.format("%02d", i) .. ".mp3"
end

local INTRO_FILES = {
    intro = Script.new_array(94)
}
for i = 1, 94 do
    INTRO_FILES.intro[i] = "audio/intro/intro_" .. string.format("%02d", i) .. ".mp3"
end

local CHEST_FILES = {
    chest = Script.new_array(34)
}
for i = 1, 34 do
    CHEST_FILES.chest[i] = "audio/chest/chest_" .. string.format("%02d", i) .. ".mp3"
end

local TEAMMATE_DIED_FILES = {
    died = Script.new_array(12)
}
for i = 1, 12 do
    TEAMMATE_DIED_FILES.died[i] = "audio/playerdied/died_" .. string.format("%02d", i) .. ".mp3"
end

local TEAMMATE_DOWNED_FILES = {
    downed = Script.new_array(5)
}
for i = 1, 5 do
    TEAMMATE_DOWNED_FILES.downed[i] = "audio/playerdowned/downed_" .. string.format("%02d", i) .. ".mp3"
end

local MORTIS_TRIALS_FILES = {
    trials = Script.new_array(45)
}
for i = 1, 45 do
    MORTIS_TRIALS_FILES.trials[i] = "audio/mortistrials/trials_" .. string.format("%02d", i) .. ".mp3"
end

local DEFEAT_FILES = {
    defeat = Script.new_array(9)
}
for i = 1, 9 do
    DEFEAT_FILES.defeat[i] = "audio/enddefeat/defeat_" .. string.format("%02d", i) .. ".mp3"
end

local VICTORY_FILES = {
    victory = Script.new_array(8)
}
for i = 1, 8 do
    VICTORY_FILES.victory[i] = "audio/endvictory/victory_" .. string.format("%02d", i) .. ".mp3"
end

mod.volume_settings = {
    "medicae_volume",
    "armoury_volume",
    "crafting_volume",
    "sefoni_volume",
    "contract_volume",
    "penance_volume",
    "commodore_volume",
    "barber_volume",
    "commissar_volume",
    "boss_volume",
    "horde_volume",
    "kill_volume",
    "intro_volume",
    "character_select_volume",
    "chest_volume",
    "teammate_died_volume",
    "teammate_downed_volume",
    "mortis_trials_volume",
    "defeat_volume",
    "victory_volume"
}

mod.apply_master_volume = function()
    local master_value = mod:get("master_volume") or 100
    for _, setting_id in ipairs(mod.volume_settings) do
        mod:set(setting_id, master_value)
    end
end

-- Audio playback tracking
mod.currently_playing_audio = false
mod.audio_end_timer = 0
mod.audio_duration = 5

--Horde-specific cooldown tracking
mod.horde_cooldown_active = false
mod.horde_cooldown_end = 0
mod.horde_cooldown_duration = 45

-- Audio control functions
local function can_play_audio()
    return not mod.currently_playing_audio
end

local function start_audio_playback()
    mod.currently_playing_audio = true
    mod.audio_end_timer = time_function(time_manager, "main") + mod.audio_duration
end

-- Horde playback functions
local function can_play_horde_audio()
    return not mod.horde_cooldown_active
end

local function start_horde_playback()
    mod.horde_cooldown_active = true
    mod.horde_cooldown_end = time_function(time_manager, "main") + mod.horde_cooldown_duration
    start_audio_playback()  -- Also triggers the 5-sec global cooldown
end

mod.update = function(dt)
    local current_time = time_function(time_manager, "main")
    
    -- Global audio cooldown
    if mod.currently_playing_audio and current_time > mod.audio_end_timer then
        mod.currently_playing_audio = false
    end
    
    -- Horde cooldown
    if mod.horde_cooldown_active and current_time > mod.horde_cooldown_end then
        mod.horde_cooldown_active = false
    end
end

local function create_play_function(files_table, volume_setting, chance_setting)
    local count = #files_table
    return function(source_id)
        if not can_play_audio() then return end
        
        local chance = chance_setting and (mod:get(chance_setting) or 100)
        if chance and math_random(1, 100) > chance then return end
        
        start_audio_playback()
        Audio.play_file(files_table[math_random(count)], {
            audio_type = "dialogue",
            volume = mod:get(volume_setting) or 100
        }, source_id)
    end
end

-- All play functions with their respective chance settings
local play_medicae_idle_empty = create_play_function(MEDICAE_FILES.idle_empty, "medicae_volume", "medicae_chance")
local play_medicae_idle_full = create_play_function(MEDICAE_FILES.idle_full, "medicae_volume", "medicae_chance")
local play_medicae_recharge = create_play_function(MEDICAE_FILES.recharge, "medicae_volume", "medicae_chance")
local play_medicae_working = create_play_function(MEDICAE_FILES.working, "medicae_volume", "medicae_chance")
local play_armoury_hello = create_play_function(ARMOURY_FILES.hello, "armoury_volume", "armoury_chance")
local play_crafting = create_play_function(CRAFTING_FILES.crafting, "crafting_volume", "crafting_chance")
local play_sefoni = create_play_function(SEFONI_FILES.sefoni, "sefoni_volume", "sefoni_chance")
local play_contract = create_play_function(CONTRACT_FILES.melk, "contract_volume", "contract_chance")
local play_penance = create_play_function(PENANCE_FILES.penance, "penance_volume", "penance_chance")
local play_commodore = create_play_function(COMMODORE_FILES.commodore, "commodore_volume", "commodore_chance")
local play_barber = create_play_function(BARBER_FILES.barber, "barber_volume", "barber_chance")
local play_commissar = create_play_function(COMMISSAR_FILES.commissar, "commissar_volume", "commissar_chance")
local play_boss = create_play_function(BOSS_FILES.boss, "boss_volume", "boss_chance")
local play_killed = create_play_function(BOSS_KILLED_FILES.killed, "kill_volume", "kill_chance")
local play_intro = create_play_function(INTRO_FILES.intro, "intro_volume", "intro_chance")
local play_chest = create_play_function(CHEST_FILES.chest, "chest_volume", "chest_chance")
local play_teammate_died = create_play_function(TEAMMATE_DIED_FILES.died, "teammate_died_volume", "teammate_died_chance")
local play_teammate_downed = create_play_function(TEAMMATE_DOWNED_FILES.downed, "teammate_downed_volume", "teammate_downed_chance")
local play_mortis_trials = create_play_function(MORTIS_TRIALS_FILES.trials, "mortis_trials_volume", "mortis_trials_chance")
local play_defeat = create_play_function(DEFEAT_FILES.defeat, "defeat_volume", "defeat_chance")
local play_victory = create_play_function(VICTORY_FILES.victory, "victory_volume", "victory_chance")
local play_character_select = create_play_function(INTRO_FILES.intro, "character_select_volume", "character_select_chance")

-- Hook creation functions not returning original sound
local function create_sound_hook_false(sound_type, play_function)
    return function(_, _, _, source_id)
        if mod._enabled and mod:get("enable_" .. sound_type .. "_sounds") then
            play_function(source_id)
            return false
        end
        return true
    end
end

-- Hook creation functions returning original sound
local function create_sound_hook_true(sound_type, play_function)
    return function(_, _, _, source_id)
        if mod._enabled and mod:get("enable_" .. sound_type .. "_sounds") then
            play_function(source_id)
            return true
        end
        return true
    end
end

function hook_medicae_servitor_voices()
    local function create_hook(sound_id, sound_type)
        local hook_func
        if sound_type == "idle_empty" then
            hook_func = create_sound_hook_false("medicae", play_medicae_idle_empty)
        elseif sound_type == "idle_full" then
            hook_func = create_sound_hook_false("medicae", play_medicae_idle_full)
        elseif sound_type == "recharge" then
            hook_func = create_sound_hook_false("medicae", play_medicae_recharge)
        elseif sound_type == "working" then
            hook_func = create_sound_hook_false("medicae", play_medicae_working)
        end
        
        Audio.hook_sound(sound_id, hook_func)
    end

    local variations = {
        {prefix = "loc_medicae_servitor_a__medicae_servitor_", count = 15, types = {
            {name = "idle_empty", count = 15},
            {name = "idle_full", count = 20},
            {name = "recharge", count = 10},
            {name = "working", count = 20}
        }},
        {prefix = "loc_medicae_servitor_b__medicae_servitor_", count = 15, types = {
            {name = "idle_empty", count = 15},
            {name = "idle_full", count = 20},
            {name = "recharge", count = 10},
            {name = "working", count = 20}
        }}
    }

    for _, servitor in ipairs(variations) do
        for _, sound_type in ipairs(servitor.types) do
            for i = 1, sound_type.count do
                local sound_id = string.format("%s%s_a_%02d", servitor.prefix, sound_type.name, i)
                create_hook(sound_id, sound_type.name)
            end
        end
    end
end

function hook_armoury_servitor_voices()
    local hook_func = create_sound_hook_false("armoury", play_armoury_hello)
    for i = 1, 20 do
        Audio.hook_sound(string.format("loc_credit_store_servitor_b__credit_store_servitor_hello_%02d", i), hook_func)
    end
end

function hook_crafting_voices()
    local hook_func = create_sound_hook_false("crafting", play_crafting)
    for i = 1, 10 do
        Audio.hook_sound(string.format("loc_tech_priest_a__crafting_interact_%02d", i), hook_func)
        Audio.hook_sound(string.format("loc_tech_priest_a__hub_idle_crafting_%02d", i), hook_func)
    end
end

function hook_sefoni_voices()
    local hook_func = create_sound_hook_false("sefoni", play_sefoni)
    for i = 1, 20 do
        Audio.hook_sound(string.format("loc_training_ground_psyker_a__hub_interact_likes_character_%02d", i), hook_func)
        Audio.hook_sound(string.format("loc_training_ground_psyker_a__hub_interact_dislikes_character_%02d", i), hook_func)
    end
end

function hook_contract_voices()
    local hook_func = create_sound_hook_false("contract", play_contract)
    for i = 1, 20 do
        Audio.hook_sound(string.format("loc_contract_vendor_a__hub_interact_dislikes_character_%02d", i), hook_func)
    end
end

function hook_penance_voices()
    local hook_func = create_sound_hook_false("penance", play_penance)
    for i = 1, 6 do
        Audio.hook_sound(string.format("loc_boon_vendor_a__hub_interact_penance_greeting_a_%02d", i), hook_func)
    end
end

function hook_commodore_voices()
    local hook_func = create_sound_hook_false("commodore", play_commodore)
    for i = 1, 20 do
        Audio.hook_sound(string.format("loc_purser_a__hub_interact_likes_character_%02d", i), hook_func)
        Audio.hook_sound(string.format("loc_purser_a__hub_interact_dislikes_character_%02d", i), hook_func)
    end
end

function hook_barber_voices()
    local hook_func = create_sound_hook_false("barber", play_barber)
    for i = 1, 20 do
        Audio.hook_sound(string.format("loc_barber_a__barber_hello_%02d", i), hook_func)
    end
end

function hook_commissar_voices()
    local hook_func = create_sound_hook_false("commissar", play_commissar)
    for i = 1, 15 do
        Audio.hook_sound(string.format("loc_commissar_a__hub_greeting_a_%02d", i), hook_func)
    end
end

function hook_boss_voices()
    local hook_func = create_sound_hook_true("boss", play_boss)
    local boss_sounds = {
        "play_enemy_plague_ogryn_spawn",
        "play_chaos_spawn_spawn", 
        "play_beast_of_nurgle_spawn"
    }
    for _, sound_id in ipairs(boss_sounds) do
        Audio.hook_sound(sound_id, hook_func)
    end
end

local play_horde = function(source_id)
    if not can_play_horde_audio() then return end
    
    local chance = mod:get("horde_chance") or 100
    if math_random(1, 100) > chance then return end
    
    start_horde_playback() -- This now applies BOTH cooldowns
    local horde_files = HORDE_FILES.horde
    Audio.play_file(horde_files[math_random(#horde_files)], {
        audio_type = "dialogue",
        volume = mod:get("horde_volume") or 100
    }, source_id)
end

function hook_horde_voices()
    local hook_func = create_sound_hook_true("horde", play_horde)
    local horde_sounds = {
        "play_minion_horde_poxwalker_ambush_3d",
        "play_horde_group_sfx_poxwalkers",
        "play_signal_horde_poxwalkers_3d"
    }
    for _, sound_id in ipairs(horde_sounds) do
        Audio.hook_sound(sound_id, hook_func)
    end
end

function hook_monster_killed_voices()
    local hook_func = create_sound_hook_true("kill", play_killed)
    Audio.hook_sound("play_monster_killed", hook_func)
end

function hook_intro_voices()
    local hook_func = create_sound_hook_true("intro", play_intro)
    Audio.hook_sound("play_mission_intro_stinger_generic", hook_func)
end

function hook_character_select_voices()
    local hook_func = create_sound_hook_true("character_select", play_character_select)
    Audio.hook_sound("play_ui_character_select_start_game", hook_func)
end

function hook_chest_voices()
    local hook_func = create_sound_hook_true("chest", play_chest)
    local chest_sounds = {
        "play_chest_sml_open",
        "play_chest_med_open",
        "play_chest_lar_open"
    }
    for _, sound_id in ipairs(chest_sounds) do
        Audio.hook_sound(sound_id, hook_func)
    end
end

function hook_teammate_died_voices()
    local hook_func = create_sound_hook_true("teammate_died", play_teammate_died)
    Audio.hook_sound("play_teammate_died", hook_func)
end

function hook_teammate_downed_voices()
    local hook_func = create_sound_hook_true("teammate_downed", play_teammate_downed)
    Audio.hook_sound("play_teammate_knocked_down", hook_func)
end

function hook_mortis_trials_voices()
    local hook_func = create_sound_hook_true("mortis_trials", play_mortis_trials)
    Audio.hook_sound("play_horde_mode_wave_start", hook_func)
    Audio.hook_sound("play_horde_mode_container_unlock", hook_func)
end

function hook_defeat_voices()
    local hook_func = create_sound_hook_true("defeat", play_defeat)
    local defeat_sounds = {
        "play_end_screen_defeat",
    }
    for _, sound_id in ipairs(defeat_sounds) do
        Audio.hook_sound(sound_id, hook_func)
    end
end

function hook_victory_voices()
    local hook_func = create_sound_hook_true("victory", play_victory)
    local victory_sounds = {
        "play_outro_win",
        "play_cin_win",
        "play_cin_heresy_win"
    }
    for _, sound_id in ipairs(victory_sounds) do
        Audio.hook_sound(sound_id, hook_func)
    end
end

local setting_handlers = {
    medicae = hook_medicae_servitor_voices,
    armoury = hook_armoury_servitor_voices,
    crafting = hook_crafting_voices,
    sefoni = hook_sefoni_voices,
    contract = hook_contract_voices,
    penance = hook_penance_voices,
    commodore = hook_commodore_voices,
    barber = hook_barber_voices,
    commissar = hook_commissar_voices,
    boss = hook_boss_voices,
    horde = hook_horde_voices,
    killed = hook_monster_killed_voices,
    intro = hook_intro_voices,
    chest = hook_chest_voices,
    teammate_died = hook_teammate_died_voices,
    teammate_downed = hook_teammate_downed_voices,
    mortis_trials = hook_mortis_trials_voices,
    defeat = hook_defeat_voices,
    victory = hook_victory_voices,
    character_select = hook_character_select_voices
}

mod.on_setting_changed = function(setting_id)
    if setting_id == "master_volume" then
        mod.apply_master_volume()
    end
    
    for prefix, handler in pairs(setting_handlers) do
        if string_find(setting_id, prefix) then
            handler()
            break
        end
    end
end

local initialization_functions = {
    hook_medicae_servitor_voices,
    hook_armoury_servitor_voices,
    hook_crafting_voices,
    hook_sefoni_voices,
    hook_contract_voices,
    hook_penance_voices,
    hook_commodore_voices,
    hook_barber_voices,
    hook_commissar_voices,
    hook_boss_voices,
    hook_horde_voices,
    hook_monster_killed_voices,
    hook_intro_voices,
    hook_character_select_voices,
    hook_chest_voices,
    hook_teammate_died_voices,
    hook_teammate_downed_voices,
    hook_mortis_trials_voices,
    hook_defeat_voices,
    hook_victory_voices
}

mod.on_all_mods_loaded = function()
    for _, func in ipairs(initialization_functions) do
        func()
    end
end

mod._enabled = true

mod.on_enabled = function()
    mod._enabled = true
end

mod.on_disabled = function()
    mod._enabled = false
end