-- ServoTempus_data.lua
local mod = get_mod("ServoTempus")

return {
  name         = mod:localize("mod_name"),
  description  = mod:localize("mod_description"),
  is_togglable = true,

  options = {
    widgets = {
      {
        setting_id    = "log_personal_best",
        type          = "checkbox",
        default_value = true,
        title         = "LogPBTitle",
      },
      {
        setting_id    = "show_5min_icon",
        type          = "checkbox",
        default_value = true,
        title         = "Show5MinIconTitle",
      },
      {
        setting_id    = "show_greeting",
        type          = "checkbox",
        default_value = true,
        title         = "ShowGreetingTitle",
      },
      {
        setting_id    = "silence_chat",
        type          = "checkbox",
        default_value = false,
        title         = "SilenceChatTitle",
      },
      {
        setting_id    = "icon_color",
        type          = "dropdown",
        default_value = "red",
        title         = "IconColorTitle",
        options       = {
          { text = "black",  value = "black"  },
          { text = "blue",   value = "blue"   },
          { text = "green",  value = "green"  },
          { text = "red",    value = "red"    },
          { text = "white",  value = "white"  },
          { text = "yellow", value = "yellow" },
        },
      },
      {
        setting_id    = "icon_offset_x",
        type          = "numeric",
        default_value = 0,
        title         = "AdjustXTitle",
        range         = { -650, 650 },
        step_size     = 50,
      },
      {
        setting_id    = "icon_offset_y",
        type          = "numeric",
        default_value = 0,
        title         = "AdjustYTitle",
        range         = { -450, 450 },
        step_size     = 50,
      },
    },
  },
}
