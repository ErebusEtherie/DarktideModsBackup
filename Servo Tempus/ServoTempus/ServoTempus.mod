-- ServoTempus.mod

return {
  run = function()
    fassert(rawget(_G, "new_mod"), "`Servo Tempus` failed to find the DMF.")
    new_mod("ServoTempus", {
      mod_script       = "ServoTempus/scripts/mods/ServoTempus/ServoTempus",
      mod_data         = "ServoTempus/scripts/mods/ServoTempus/ServoTempus_data",
      mod_localization = "ServoTempus/scripts/mods/ServoTempus/ServoTempus_localization",
    })
  end,

  packages = {
    { path = "packages/ui/hud/mission_speaker_popup/mission_speaker_popup" },
  },
}
