local mod = get_mod("PsykerCriticalPerilQuiet")
local LocalServer = get_mod("DarktideLocalServer")
local Audio

mod.on_all_mods_loaded = function()
  Audio = get_mod("Audio")

  Audio.hook_sound("play_warp_charge_build_up_critical", function(sound_type, sound_name, delta)
    if delta == nil or delta > 0.1 then
      Audio.play_file("Whisper.mp3", { audio_type = "sfx" })
    end

    return false
  end)
end