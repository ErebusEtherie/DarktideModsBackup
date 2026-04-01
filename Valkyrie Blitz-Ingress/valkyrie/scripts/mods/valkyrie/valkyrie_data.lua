-- valkyrie_data.lua
local mod = get_mod("valkyrie")

return {
  name = mod:localize("mod_name"),
  description = mod:localize("mod_description"),
  is_togglable = true,

  options = {
    widgets = {
      {
        setting_id = "mute_lobby_mission",
        type = "checkbox",
        default_value = true,
        title = "MuteLobbyTitle",
      },
      {
        setting_id = "silence_expeditions",
        type = "checkbox",
        default_value = true,
        title = "SilenceExpeditionsTitle",
      },
      {
        setting_id = "report_on_skip",
        type = "checkbox",
        default_value = true,
        title = "ReportOnOffTitle",
      },
      {
        setting_id = "hide_mission_screen",
        type = "checkbox",
        default_value = true,
        title = "MissionHologramTitle",
      },
    },
  },
}